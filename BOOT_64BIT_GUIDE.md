# Guía Técnica: Transición a Modo 64-bit en x86_64

Este documento explica en detalle cómo implementar un bootloader que transite desde el modo real (16-bit) hasta el modo largo (64-bit) en arquitecturas x86_64.

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Modos de Operación del Procesador](#modos-de-operación-del-procesador)
3. [Requisitos Previos](#requisitos-previos)
4. [Fase 1: Modo Real (16-bit)](#fase-1-modo-real-16-bit)
5. [Fase 2: Modo Protegido (32-bit)](#fase-2-modo-protegido-32-bit)
6. [Fase 3: Modo Largo (64-bit)](#fase-3-modo-largo-64-bit)
7. [Código Completo Explicado](#código-completo-explicado)
8. [Depuración y Problemas Comunes](#depuración-y-problemas-comunes)

---

## Introducción

Al encender una computadora x86_64, el procesador inicia en **modo real** (16-bit), un modo compatible con los procesadores Intel 8086 de 1978. Para aprovechar las capacidades de 64-bit, debemos realizar dos transiciones:

```
Modo Real (16-bit) → Modo Protegido (32-bit) → Modo Largo (64-bit)
```

**No es posible saltar directamente de 16-bit a 64-bit.** El modo protegido de 32-bit es obligatorio como paso intermedio.

---

## Modos de Operación del Procesador

### Modo Real (16-bit)
- **Segmentación**: Usa segmentos de 64KB
- **Memoria direccionable**: 1MB (20 bits)
- **BIOS**: Disponible para servicios básicos
- **Direccionamiento**: Segmento:Offset (`CS:IP`)
- **Inicio**: El procesador siempre inicia aquí

### Modo Protegido (32-bit)
- **Segmentación**: Descriptores en GDT/LDT
- **Memoria direccionable**: 4GB (32 bits)
- **BIOS**: No disponible
- **Paginación**: Opcional pero recomendada
- **Protección**: Anillos de privilegio (Ring 0-3)

### Modo Largo (64-bit)
- **Submodos**: 
  - **Compatibility Mode**: Ejecuta código de 32-bit
  - **64-bit Mode**: Modo nativo de 64 bits
- **Memoria direccionable**: 256TB (48 bits en práctica)
- **Paginación**: Obligatoria (PAE + Long Mode)
- **Registros**: RAX, RBX, RCX, RDX, RSI, RDI, R8-R15
- **Segmentación**: Prácticamente deshabilitada

---

## Requisitos Previos

Para entrar a modo 64-bit, el procesador debe cumplir:

1. ✅ Soportar instrucciones CPUID
2. ✅ Soportar Long Mode (verificable con CPUID)
3. ✅ Tener la línea A20 habilitada
4. ✅ Tener una GDT configurada
5. ✅ Tener paginación configurada (PAE + Long Mode)

---

## Fase 1: Modo Real (16-bit)

### 1.1 Habilitar la Línea A20

La línea A20 es el bit 20 de la dirección de memoria. En modo real está deshabilitada para compatibilidad con el 8086.

**¿Por qué es necesaria?**
- Sin A20: Solo se pueden direccionar 1MB de memoria (bits 0-19)
- Con A20: Se pueden direccionar los 4GB completos

**Métodos para habilitar A20:**

#### Método Fast A20 (recomendado)
```asm
EnableA20:
    in al, 0x92          ; Leer el puerto del System Control
    or al, 2             ; Establecer el bit 1 (A20)
    out 0x92, al         ; Escribir de vuelta
    ret
```

#### Método del Teclado (más compatible pero más lento)
```asm
EnableA20_Keyboard:
    call wait_8042
    mov al, 0xAD
    out 0x64, al         ; Deshabilitar teclado

    call wait_8042
    mov al, 0xD0
    out 0x64, al         ; Leer Output Port

    call wait_8042_data
    in al, 0x60
    push ax

    call wait_8042
    mov al, 0xD1
    out 0x64, al         ; Escribir Output Port

    call wait_8042
    pop ax
    or al, 2             ; Habilitar A20
    out 0x60, al

    call wait_8042
    mov al, 0xAE
    out 0x64, al         ; Habilitar teclado
    ret

wait_8042:
    in al, 0x64
    test al, 2
    jnz wait_8042
    ret

wait_8042_data:
    in al, 0x64
    test al, 1
    jz wait_8042_data
    ret
```

### 1.2 Verificar Capacidades del Procesador

Antes de continuar, debemos verificar que el CPU soporta Long Mode:

```asm
DetectCPUID:
    ; Verificar si CPUID está disponible
    pushfd                  ; Guardar EFLAGS
    pop eax                 ; EAX = EFLAGS
    mov ecx, eax            ; ECX = copia de EFLAGS
    xor eax, 1 << 21        ; Invertir bit ID (bit 21)
    push eax
    popfd                   ; Cargar EFLAGS modificado
    pushfd
    pop eax                 ; EAX = EFLAGS nuevamente
    push ecx
    popfd                   ; Restaurar EFLAGS original
    xor eax, ecx            ; Si son diferentes, CPUID está disponible
    jz NoCPUID              ; Si son iguales, no hay CPUID
    ret

DetectLongMode:
    ; Verificar si Long Mode está disponible
    mov eax, 0x80000000     ; Función extendida más alta
    cpuid
    cmp eax, 0x80000001     ; Verificar si 0x80000001 está disponible
    jb NoLongMode
    
    mov eax, 0x80000001     ; Función para características extendidas
    cpuid
    test edx, 1 << 29       ; Verificar bit LM (Long Mode)
    jz NoLongMode
    ret

NoCPUID:
    ; Manejar error: CPU sin CPUID
    mov si, msg_no_cpuid
    call print_string
    hlt

NoLongMode:
    ; Manejar error: CPU sin Long Mode
    mov si, msg_no_longmode
    call print_string
    hlt
```

---

## Fase 2: Modo Protegido (32-bit)

### 2.1 Configurar la GDT (Global Descriptor Table)

La GDT define los segmentos de memoria. En modo 64-bit, la segmentación está prácticamente deshabilitada, pero aún necesitamos una GDT.

**Estructura de un Descriptor de Segmento (8 bytes):**

```
Bits 63-56: Base[31:24]
Bits 55-52: Flags (G, D/B, L, AVL)
Bits 51-48: Limit[19:16]
Bits 47-40: Access Byte
Bits 39-16: Base[23:0]
Bits 15-0:  Limit[15:0]
```

**Estructura de la GDT:**

```asm
gdt_nulldesc:
    dq 0                    ; Descriptor nulo (obligatorio)

gdt_codedesc:               ; Descriptor de código (offset 0x08)
    dw 0xFFFF               ; Limit (bits 0-15)
    dw 0                    ; Base (bits 0-15)
    db 0                    ; Base (bits 16-23)
    db 0b10011010           ; Access Byte: Present, Ring 0, Code, Readable
    db 0b11001111           ; Flags + Limit: Granularity, 32-bit, Limit[19:16]
    db 0                    ; Base (bits 24-31)

gdt_datadesct:              ; Descriptor de datos (offset 0x10)
    dw 0xFFFF               ; Limit
    dw 0                    ; Base (bits 0-15)
    db 0                    ; Base (bits 16-23)
    db 0b10010010           ; Access Byte: Present, Ring 0, Data, Writable
    db 0b11001111           ; Flags + Limit
    db 0                    ; Base (bits 24-31)

gdt_end:

; Puntero a la GDT (6 bytes)
gdt_descriptor:
    dw gdt_end - gdt_nulldesc - 1    ; Tamaño - 1
    dd gdt_nulldesc                   ; Dirección base (4 bytes en 32-bit)

; Selectores de segmento (offsets en la GDT)
codeseg equ gdt_codedesc - gdt_nulldesc    ; 0x08
dataseg equ gdt_datadesct - gdt_nulldesc   ; 0x10
```

**Access Byte desglosado:**

```
Bit 7:   Present (P)          - 1 = Segmento presente
Bits 6-5: Privilege Level (DPL) - 00 = Ring 0 (kernel)
Bit 4:   Descriptor Type (S)  - 1 = Segmento de código/datos
Bits 3-0: Type
    Para código: 1010 = Executable, Readable
    Para datos:  0010 = Writable
```

**Flags desglosados:**

```
Bit 7: Granularity (G)     - 1 = Límite en páginas de 4KB
Bit 6: Size (D/B)          - 1 = Segmento de 32-bit
Bit 5: Long Mode (L)       - 0 = No es código de 64-bit (aún)
Bit 4: Available (AVL)     - 0 = Para uso del sistema
```

### 2.2 Cargar la GDT y Entrar a Modo Protegido

```asm
[bits 16]
EnterProtectedMode:
    cli                     ; Deshabilitar interrupciones
    lgdt [gdt_descriptor]   ; Cargar la GDT
    
    ; Activar modo protegido (establecer bit 0 de CR0)
    mov eax, cr0
    or eax, 1               ; Establecer PE (Protection Enable)
    mov cr0, eax
    
    ; Far jump para cargar CS con el selector de código
    jmp codeseg:StartProtectedMode

[bits 32]
StartProtectedMode:
    ; Cargar selectores de segmento de datos
    mov ax, dataseg
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    ; Ahora estamos en modo protegido de 32-bit
    ; Continuar hacia modo 64-bit...
```

**Explicación del Far Jump:**

El `jmp codeseg:StartProtectedMode` es crucial porque:
1. Limpia el pipeline de instrucciones
2. Carga CS con el selector de código (0x08)
3. Actualiza el modo del procesador

---

## Fase 3: Modo Largo (64-bit)

### 3.1 Configurar Paginación (Identity Paging)

El modo 64-bit **requiere** que la paginación esté habilitada. Usaremos "identity paging" donde las direcciones virtuales son iguales a las físicas.

**Jerarquía de Paginación en Long Mode:**

```
PML4 (Page Map Level 4)
  ↓
PDPT (Page Directory Pointer Table)
  ↓
PDT (Page Directory Table)
  ↓
PT (Page Table) [opcional si usamos páginas de 2MB]
```

**Configuración de Identity Paging (mapea primeros 2MB):**

```asm
PageTableEntry equ 0x70000      ; Ubicación de las tablas de página

SetUpIdentityPaging:
    ; Limpiar el área de las tablas de página (16KB)
    mov edi, PageTableEntry
    mov cr3, edi                ; CR3 apunta a PML4
    xor eax, eax
    mov ecx, 4096               ; 4096 dwords = 16KB
    rep stosd                   ; Llenar con ceros
    
    mov edi, PageTableEntry     ; Resetear EDI
    
    ; Configurar PML4[0] -> PDPT
    mov dword [edi], 0x71003    ; PDPT en 0x71000, Present+Writable
    add edi, 0x1000             ; Avanzar a PDPT (0x71000)
    
    ; Configurar PDPT[0] -> PDT
    mov dword [edi], 0x72003    ; PDT en 0x72000, Present+Writable
    add edi, 0x1000             ; Avanzar a PDT (0x72000)
    
    ; Configurar PDT[0] -> PT
    mov dword [edi], 0x73003    ; PT en 0x73000, Present+Writable
    add edi, 0x1000             ; Avanzar a PT (0x73000)
    
    ; Mapear las primeras 512 páginas (2MB) con identity mapping
    mov ebx, 0x00000003         ; Present + Writable
    mov ecx, 512                ; 512 entradas de 4KB = 2MB
    
.SetEntry:
    mov dword [edi], ebx        ; Escribir entrada de página
    add ebx, 0x1000             ; Siguiente página física (4KB)
    add edi, 8                  ; Siguiente entrada (8 bytes)
    loop .SetEntry
    
    ret
```

**Flags de las Entradas de Página:**

```
Bit 0: Present (P)       - 1 = Página presente en memoria
Bit 1: Read/Write (R/W)  - 1 = Página escribible
Bit 2: User/Supervisor   - 0 = Solo kernel
Bits 3-11: Disponibles
Bits 12-51: Dirección física de la página
```

### 3.2 Modificar la GDT para Modo Largo

En modo 64-bit, necesitamos cambiar el descriptor de código para activar el bit L (Long Mode):

```asm
EditGDT:
    ; Modificar el descriptor de código para Long Mode
    ; Cambiar el byte de flags: establecer L=1, D/B=0
    mov byte [gdt_codedesc + 6], 0b10101111
    ; Bits: G=1, L=1(64-bit), AVL=0, Limit[19:16]=1111
    ret
```

**Diferencia entre 32-bit y 64-bit en la GDT:**

| Modo | Bit G | Bit D/B | Bit L | Valor |
|------|-------|---------|-------|-------|
| 32-bit | 1 | 1 | 0 | 0b11001111 (0xCF) |
| 64-bit | 1 | 0 | 1 | 0b10101111 (0xAF) |

### 3.3 Habilitar Long Mode y Entrar a 64-bit

```asm
[bits 32]
EnterLongMode:
    ; 1. Configurar paginación
    call SetUpIdentityPaging
    
    ; 2. Habilitar PAE (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5              ; Establecer bit PAE (bit 5)
    mov cr4, eax
    
    ; 3. Establecer el bit LME (Long Mode Enable) en el MSR EFER
    mov ecx, 0xC0000080         ; MSR EFER (Extended Feature Enable Register)
    rdmsr                       ; Leer MSR en EDX:EAX
    or eax, 1 << 8              ; Establecer bit LME (bit 8)
    wrmsr                       ; Escribir MSR
    
    ; 4. Habilitar paginación (activa Long Mode)
    mov eax, cr0
    or eax, 1 << 31             ; Establecer bit PG (Paging, bit 31)
    mov cr0, eax
    
    ; En este punto, el CPU está en "compatibility mode" (64-bit pero ejecutando código de 32-bit)
    
    ; 5. Modificar GDT para modo 64-bit
    call EditGDT
    
    ; 6. Far jump para entrar completamente a modo 64-bit
    jmp codeseg:Start64Bit

[bits 64]
Start64Bit:
    ; ¡Ahora estamos en modo 64-bit!
    ; Los registros son ahora RAX, RBX, RCX, etc.
    
    ; Limpiar segmentos de datos
    mov ax, dataseg
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Configurar stack (si es necesario)
    mov rsp, 0x90000
    
    ; Tu código de 64-bit aquí...
```

**Registros de Control Importantes:**

- **CR0**: Control Register 0
  - Bit 0 (PE): Protection Enable (modo protegido)
  - Bit 31 (PG): Paging Enable
  
- **CR3**: Apunta a la PML4 (raíz de las tablas de página)
  
- **CR4**: Control Register 4
  - Bit 5 (PAE): Physical Address Extension
  
- **EFER MSR (0xC0000080)**: Extended Feature Enable Register
  - Bit 8 (LME): Long Mode Enable
  - Bit 10 (LMA): Long Mode Active (solo lectura, se activa cuando PG=1)

---

## Código Completo Explicado

### Stage 1: MBR Bootloader (boot.asm)

```asm
[BITS 16]
[ORG 0x7C00]

STAGE2_OFFSET equ 0x1000
STAGE2_SECTORS equ 16
KERNEL_OFFSET equ 0x10000
KERNEL_SECTOR equ 17
KERNEL_SECTORS equ 4

start:
    ; 1. Inicializar segmentos
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; Stack crece hacia abajo
    
    ; 2. Guardar drive number
    mov [BOOT_DRIVE], dl
    
    ; 3. Cargar Stage2 desde disco
    mov ah, 0x02            ; BIOS int 0x13, función 02h: Leer sectores
    mov al, STAGE2_SECTORS  ; Número de sectores
    mov ch, 0               ; Cilindro 0
    mov cl, 2               ; Sector 2 (el 1 es el MBR)
    mov dh, 0               ; Cabeza 0
    mov dl, [BOOT_DRIVE]
    mov bx, STAGE2_OFFSET   ; ES:BX = destino
    int 0x13
    jc disk_error
    
    ; 4. Cargar Kernel desde disco
    mov ah, 0x02
    mov al, KERNEL_SECTORS
    mov ch, 0
    mov cl, KERNEL_SECTOR
    mov dh, 0
    mov dl, [BOOT_DRIVE]
    
    ; Calcular segmento para 0x10000 (ES = 0x1000, BX = 0)
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    int 0x13
    jc disk_error
    
    ; 5. Saltar a Stage2
    mov dl, [BOOT_DRIVE]
    jmp STAGE2_OFFSET

disk_error:
    mov si, msg_error
    call print_string
    hlt

print_string:
    pusha
    mov ah, 0x0E
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    popa
    ret

BOOT_DRIVE: db 0
msg_error: db "Disk Error!", 0

times 510-($-$$) db 0
dw 0xAA55               ; Boot signature
```

### Stage 2: Transición a 64-bit (stage2_sector2.asm)

```asm
[org 0x1000]

jmp EnterProtectedMode

%include "gdt.asm"
%include "print.asm"

EnterProtectedMode:
    call EnableA20
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp codeseg:StartProtectedMode

EnableA20:
    in al, 0x92
    or al, 2
    out 0x92, al
    ret

[bits 32]

%include "CPUID.asm"
%include "SimplePaging.asm"

StartProtectedMode:
    ; Cargar segmentos
    mov ax, dataseg
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    ; Verificar CPU
    call DetectCPUID
    call DetectLongMode
    
    ; Configurar paginación
    call SetUpIdentityPaging
    
    ; Habilitar PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    
    ; Habilitar Long Mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr
    
    ; Habilitar paginación
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax
    
    ; Modificar GDT
    call EditGDT
    
    ; Saltar a 64-bit
    jmp codeseg:Start64Bit

EditGDT:
    mov byte [gdt_codedesc + 6], 0b10101111
    ret

[bits 64]

Start64Bit:
    ; Configurar segmentos
    mov ax, dataseg
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Stack
    mov rsp, 0x90000
    
    ; Limpiar pantalla con color azul
    mov edi, 0xb8000
    mov rax, 0x1f201f201f201f20    ; Espacio con fondo azul
    mov ecx, 500
    rep stosq
    
    ; Mostrar mensaje "64-BIT MODE OK!"
    mov rax, 0xB8000
    mov byte [rax], '6'
    mov byte [rax+1], 0x0A          ; Verde brillante
    mov byte [rax+2], '4'
    mov byte [rax+3], 0x0A
    ; ... (resto del mensaje)
    
    ; Saltar al kernel
    mov rax, 0x10000
    jmp rax

times 8192-($-$$) db 0  ; 16 sectores = 8KB
```

---

## Depuración y Problemas Comunes

### Problema 1: Triple Fault / Reset del Sistema

**Síntomas**: El sistema se reinicia inmediatamente después de entrar a modo protegido o 64-bit.

**Causas comunes**:
1. GDT mal configurada o no cargada correctamente
2. Far jump con selector incorrecto
3. Paginación mal configurada (tablas incorrectas)
4. Stack no configurado o apuntando a memoria inválida

**Soluciones**:
```asm
; Verificar que la GDT esté en memoria accesible
; Usar QEMU con -d int para ver interrupciones
; Verificar que CR3 apunte a memoria válida
; Asegurar que el stack no colisione con otras estructuras
```

### Problema 2: El CPU no Soporta Long Mode

**Síntomas**: Se muestra mensaje de error o el sistema se detiene.

**Verificación**:
```asm
DetectLongMode:
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb NoLongMode           ; CPU muy antiguo
    
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz NoLongMode           ; No soporta Long Mode
    ret
```

### Problema 3: Far Jump No Funciona

**Síntomas**: El procesador se queda en loop o reset.

**Causa**: Sintaxis incorrecta del far jump.

**Correcto**:
```asm
codeseg equ gdt_codedesc - gdt_nulldesc    ; Definir como constante
jmp codeseg:StartProtectedMode             ; Usar constante
```

**Incorrecto**:
```asm
jmp 0x08:StartProtectedMode    ; Hardcoded (puede funcionar pero no es portátil)
jmp [codeseg]:StartProtectedMode    ; Sintaxis incorrecta
```

### Problema 4: Paginación Causa Page Fault

**Síntomas**: Exception 14 (Page Fault) o triple fault.

**Soluciones**:
1. Verificar que las tablas estén en memoria no usada (ej: 0x70000)
2. Asegurar que todas las entradas tengan el bit Present (bit 0)
3. Mapear suficiente memoria (al menos donde está el código)
4. No olvidar cargar CR3 antes de habilitar paginación

```asm
; Verificar que no hay conflictos de memoria
; Stage1: 0x7C00
; Stage2: 0x1000 - 0x2FFF (8KB)
; Kernel: 0x10000+
; Page Tables: 0x70000 - 0x73FFF (16KB)
; Stack: 0x90000+
```

### Problema 5: Acceso a VGA en 64-bit No Funciona

**Síntomas**: No se ve texto en pantalla.

**Causas**:
1. Memoria VGA no mapeada en tablas de página
2. Dirección VGA incorrecta
3. Segmentos no configurados

**Solución**:
```asm
; Asegurar que 0xB8000 está en los primeros 2MB mapeados
; O extender el mapeo de paginación:

; Mapear más memoria si es necesario
mov ecx, 1024        ; Mapear 4MB en lugar de 2MB
; ... resto del código de paginación
```

### Problema 6: GDT Descriptor Incorrecto

**Síntomas**: Triple fault al cargar GDT.

**Causa**: Tamaño o dirección incorrecta en el descriptor.

**Correcto** (32-bit):
```asm
gdt_descriptor:
    dw gdt_end - gdt_nulldesc - 1    ; Tamaño - 1 (2 bytes)
    dd gdt_nulldesc                   ; Dirección (4 bytes)
```

**Incorrecto**:
```asm
gdt_descriptor:
    dw gdt_end - gdt_nulldesc        ; Falta el -1
    dq gdt_nulldesc                  ; 8 bytes (incorrecto para 32-bit)
```

### Debugging con QEMU

```bash
# Ver interrupciones y excepciones
qemu-system-x86_64 -drive format=raw,file=sector2.img -d int

# Ver traducciones de direcciones
qemu-system-x86_64 -drive format=raw,file=sector2.img -d cpu_reset

# Monitor interactivo
qemu-system-x86_64 -drive format=raw,file=sector2.img -monitor stdio

# GDB debugging
qemu-system-x86_64 -drive format=raw,file=sector2.img -s -S
# En otra terminal:
gdb
(gdb) target remote localhost:1234
(gdb) set architecture i386:x86-64
(gdb) break *0x7C00
(gdb) continue
```

---

## Resumen del Proceso Completo

### Checklist para Transición a 64-bit

- [ ] **Paso 1**: Habilitar línea A20
- [ ] **Paso 2**: Crear y cargar GDT con descriptores de código y datos
- [ ] **Paso 3**: Entrar a modo protegido (establecer CR0.PE = 1)
- [ ] **Paso 4**: Far jump para actualizar CS
- [ ] **Paso 5**: Cargar segmentos de datos con selector apropiado
- [ ] **Paso 6**: Verificar soporte de CPUID
- [ ] **Paso 7**: Verificar soporte de Long Mode
- [ ] **Paso 8**: Configurar tablas de paginación (PML4, PDPT, PDT, PT)
- [ ] **Paso 9**: Cargar CR3 con dirección de PML4
- [ ] **Paso 10**: Habilitar PAE (CR4.PAE = 1)
- [ ] **Paso 11**: Habilitar Long Mode (EFER.LME = 1)
- [ ] **Paso 12**: Habilitar paginación (CR0.PG = 1)
- [ ] **Paso 13**: Modificar GDT para establecer bit L en descriptor de código
- [ ] **Paso 14**: Far jump para entrar completamente a modo 64-bit
- [ ] **Paso 15**: Actualizar segmentos y configurar stack

### Orden Crítico de Operaciones

```
1. A20 Enable
2. GDT Setup
3. CR0.PE = 1 (Modo Protegido)
4. Far Jump (actualizar CS)
5. Paging Tables Setup
6. CR3 = PML4 Address
7. CR4.PAE = 1
8. EFER.LME = 1
9. CR0.PG = 1
10. GDT Edit (Long Mode flag)
11. Far Jump (entrar 64-bit)
```

**IMPORTANTE**: El orden no puede cambiarse. Cada paso depende del anterior.

---

## Referencias

- [Intel 64 and IA-32 Architectures Software Developer's Manual](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
- [AMD64 Architecture Programmer's Manual](https://www.amd.com/en/support/tech-docs)
- [OSDev Wiki - Setting Up Long Mode](https://wiki.osdev.org/Setting_Up_Long_Mode)
- [OSDev Wiki - GDT](https://wiki.osdev.org/GDT)
- [OSDev Wiki - Paging](https://wiki.osdev.org/Paging)

---

**Autor**: Sistema de documentación técnica  
**Fecha**: Noviembre 2025  
**Versión**: 1.0
