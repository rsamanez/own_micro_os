# Micro OS - Bootloader 64-bit con Kernel en C

Sistema operativo minimalista que arranca en modo real (16-bit), pasa por modo protegido (32-bit) y finalmente entra en modo largo (64-bit) para ejecutar un kernel escrito en C.

## 🎯 Objetivo del Proyecto

Crear un bootloader personalizado capaz de:
1. Arrancar desde el MBR (Master Boot Record)
2. Transicionar a través de los modos: 16-bit → 32-bit → 64-bit
3. Cargar el kernel desde disco **en modo 64-bit** (sin BIOS)
4. Ejecutar código en C con acceso directo a memoria VGA

## 📋 Arquitectura del Sistema

### Distribución en Disco (sector2.img)
```
Sector 0      : Stage1 (boot.asm) - MBR bootloader
Sectores 1-16 : Stage2 (stage2_sector2.asm) - Transición a 64-bit
Sector 17+    : Kernel (kernel.c + entry.asm) - Kernel en C
```

### Mapa de Memoria
```
0x00007C00  : Stage1 (cargado por BIOS)
0x00001000  : Stage2 (cargado por Stage1)
0x00010000  : Kernel (cargado por Stage2 con driver ATA)
0x00070000  : Page Tables (identity paging)
0x00090000  : Stack del kernel
0x000B8000  : Memoria VGA text mode
```

## 🚀 Paso a Paso: Cómo se Logró la Carga del Kernel en C

### **Paso 1: Stage1 - Bootloader MBR (boot.asm)**

El BIOS carga el primer sector (512 bytes) en `0x7C00` y lo ejecuta.

**Responsabilidades:**
- Iniciar en modo real (16-bit)
- Cargar Stage2 desde disco usando INT 0x13 (BIOS)
- Transferir control a Stage2

```assembly
; Lee 16 sectores de Stage2 desde disco
mov ah, 0x02        ; Función BIOS: leer sectores
mov al, 16          ; Cantidad de sectores
mov ch, 0           ; Cilindro 0
mov cl, 2           ; Sector 2 (después del MBR)
mov dh, 0           ; Cabeza 0
mov bx, 0x1000      ; Destino: 0x1000
int 0x13            ; Interrupción BIOS
```

**Importante:** Stage1 **NO** carga el kernel. Solo carga Stage2.

---

### **Paso 2: Stage2 - Transición a 64-bit (stage2_sector2.asm)**

Stage2 realiza la transición completa de modos y carga el kernel.

#### 2.1 Modo Protegido (32-bit)
- Deshabilita interrupciones
- Configura GDT (Global Descriptor Table)
- Habilita A20 line
- Entra en modo protegido

#### 2.2 Preparación para Modo Largo (64-bit)
- Verifica soporte CPUID
- Verifica soporte de Long Mode
- Configura identity paging en `0x70000`:
  - PML4 → PDPT → PD → PT (4 niveles de paginación)
  - Mapeo identidad: dirección virtual = dirección física

#### 2.3 Entrada a Modo Largo
```assembly
; Habilitar PAE (Physical Address Extension)
mov eax, cr4
or eax, 1 << 5
mov cr4, eax

; Cargar PML4 en CR3
mov eax, 0x70000
mov cr3, eax

; Habilitar Long Mode en EFER MSR
mov ecx, 0xC0000080
rdmsr
or eax, 1 << 8
wrmsr

; Habilitar paginación
mov eax, cr0
or eax, 1 << 31
mov cr0, eax
```

#### 2.4 **CLAVE: Carga del Kernel en 64-bit**

Una vez en modo 64-bit, Stage2 utiliza el **driver ATA** para leer el kernel desde disco.

**¿Por qué no usar BIOS INT 0x13?**
- Las interrupciones BIOS **solo funcionan en modo real (16-bit)**
- En modo 64-bit no hay acceso a BIOS
- Solución: acceso directo al controlador ATA por I/O ports

```assembly
; Cargar kernel desde disco usando driver ATA
mov rdi, 0x10000        ; Destino en memoria
mov rsi, 17             ; LBA sector 17
mov rdx, 8              ; 8 sectores (4KB)
call ata_read_sectors   ; Driver ATA personalizado
```

---

### **Paso 3: Driver ATA en 64-bit (ata_driver64.asm)**

El driver ATA permite leer sectores del disco directamente desde modo 64-bit sin depender del BIOS.

#### Puertos ATA (Primary IDE Controller)
```
0x1F0 : Data port (lectura/escritura de datos)
0x1F2 : Sector count
0x1F3 : LBA low byte
0x1F4 : LBA mid byte
0x1F5 : LBA high byte
0x1F6 : Drive select + LBA bits 24-27
0x1F7 : Command/Status port
```

#### Proceso de Lectura
```assembly
ata_read_sectors:
    ; 1. Esperar a que el disco esté listo
    mov dx, 0x1F7
.wait_ready:
    in al, dx
    test al, 0x80        ; BSY bit
    jnz .wait_ready
    
    ; 2. Configurar sector count
    mov dx, 0x1F2
    mov al, [sector_count]
    out dx, al
    
    ; 3. Configurar LBA (28-bit addressing)
    mov dx, 0x1F3
    mov al, [lba_low]
    out dx, al
    ; ... (continúa con LBA mid, high)
    
    ; 4. Enviar comando READ (0x20)
    mov dx, 0x1F7
    mov al, 0x20
    out dx, al
    
    ; 5. Leer datos word por word (512 bytes por sector)
    mov dx, 0x1F0
    mov rcx, 256         ; 256 words = 512 bytes
.read_loop:
    in ax, dx
    mov [rdi], ax
    add rdi, 2
    loop .read_loop
```

**Ventaja crítica:** Funciona en cualquier modo (16, 32, 64 bits) ya que usa I/O ports directamente.

---

### **Paso 4: Kernel en C (kernel.c + entry.asm)**

#### 4.1 Entry Point en Assembly (entry.asm)
```assembly
[BITS 64]
extern kernel_main

global _start
_start:
    ; Configurar stack
    mov rsp, 0x90000
    xor rbp, rbp
    
    ; Llamar función en C
    call kernel_main
    
    ; Halt si regresa
.halt:
    hlt
    jmp .halt
```

#### 4.2 Kernel Principal en C (kernel.c)
```c
// Acceso directo a memoria VGA
volatile unsigned short* vga = (unsigned short*)0xB8000;

void kernel_main(void) {
    // Color: fondo azul (1), texto blanco (15)
    unsigned char color = (1 << 4) | 15;
    
    const char* message = "Kernel en C funcionando!";
    for (int i = 0; message[i] != 0; i++) {
        vga[i] = (color << 8) | message[i];
    }
    
    while(1) { __asm__("hlt"); }
}
```

#### 4.3 Compilación del Kernel
```bash
# Compilar entry point
nasm -f elf64 kernel/entry.asm -o build/entry.o

# Compilar kernel en C
x86_64-elf-gcc -std=c11 -ffreestanding \
    -mno-red-zone -mno-mmx -mno-sse -mno-sse2 \
    -c kernel/kernel.c -o build/kernel.o

# Linkar con script personalizado
x86_64-elf-ld -T kernel.ld -o build/kernel.elf \
    build/entry.o build/kernel.o

# Convertir ELF a binario plano
x86_64-elf-objcopy -O binary build/kernel.elf build/kernel.bin
```

#### 4.4 Linker Script (kernel.ld)
```ld
OUTPUT_FORMAT(elf64-x86-64)
ENTRY(_start)

SECTIONS {
    . = 0x10000;
    
    .text.entry : { *(.text.entry) }
    .text : { *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) }
    .bss : { *(.bss) }
}
```

---

### **Paso 5: Ensamblado Final del Sistema**

```bash
# 1. Compilar Stage1
nasm -f bin -I boot/ boot/boot.asm -o build/boot.bin

# 2. Compilar Stage2
nasm -f bin -I boot/ boot/stage2_sector2.asm -o build/stage2_sector2.bin

# 3. Compilar Kernel (ver Paso 4.3)

# 4. Crear imagen de disco
dd if=/dev/zero of=sector2.img bs=1M count=10

# 5. Escribir Stage1 en sector 0
dd if=build/boot.bin of=sector2.img conv=notrunc

# 6. Escribir Stage2 en sectores 1-16
dd if=build/stage2_sector2.bin of=sector2.img bs=512 seek=1 conv=notrunc

# 7. Escribir Kernel en sector 17+
dd if=build/kernel.bin of=sector2.img bs=512 seek=17 conv=notrunc

# 8. Ejecutar en QEMU
qemu-system-x86_64 -drive format=raw,file=sector2.img
```

---

## 🔑 Conceptos Clave Aprendidos

### 1. **Limitaciones del BIOS**
- INT 0x13 solo funciona en modo real (16-bit)
- Al entrar en modo protegido/largo, se pierde acceso al BIOS
- Solución: drivers nativos que accedan hardware directamente

### 2. **Por Qué Cargar el Kernel en 64-bit (no en Stage1)**
- **Escalabilidad**: Stage1 tiene solo 512 bytes, muy limitado
- **Flexibilidad**: Stage2 puede cargar kernels de cualquier tamaño
- **Arquitectura limpia**: Separación de responsabilidades
  - Stage1: bootstrapping mínimo
  - Stage2: configuración del sistema
  - Kernel: lógica del OS

### 3. **Identity Paging**
```
Virtual Address = Physical Address
Ejemplo: 0x10000 (virtual) → 0x10000 (física)
```
Necesario para que las direcciones del código sigan siendo válidas después de habilitar paginación.

### 4. **Flags de Compilación para Kernel**
- `-ffreestanding`: No asumir funciones estándar de C
- `-mno-red-zone`: Deshabilitar red zone (requerido para kernel)
- `-mno-sse`: Sin instrucciones SSE (requieren inicialización extra)

---

## 📁 Estructura del Proyecto

```
.
├── boot/
│   ├── boot.asm              # Stage1: MBR bootloader
│   ├── stage2_sector2.asm    # Stage2: transición 16→32→64 bit
│   ├── ata_driver64.asm      # Driver ATA para lectura de disco
│   ├── gdt.asm               # Global Descriptor Table
│   ├── CPUID.asm             # Detección de características CPU
│   ├── SimplePaging.asm      # Configuración de paginación
│   └── print.asm             # Funciones de impresión 16-bit
├── kernel/
│   ├── entry.asm             # Entry point del kernel (64-bit)
│   └── kernel.c              # Kernel principal en C
├── build/
│   ├── boot.bin              # Stage1 compilado
│   ├── stage2_sector2.bin    # Stage2 compilado
│   └── kernel.bin            # Kernel compilado
├── kernel.ld                 # Linker script
├── sector2.img               # Imagen de disco final
└── README.md                 # Este archivo
```

---

## 🛠️ Requisitos

- **NASM**: Ensamblador para x86/x86-64
- **GCC Cross-Compiler**: `x86_64-elf-gcc`, `x86_64-elf-ld`, `x86_64-elf-objcopy`
- **QEMU**: `qemu-system-x86_64`
- **dd**: Herramienta para escribir en disco (incluido en Unix/Linux/macOS)
- **Make**: Sistema de construcción (incluido en Unix/Linux/macOS)

---

## 🔧 Compilación y Ejecución

### Usando Make (Recomendado)

El proyecto incluye un Makefile que simplifica el proceso de compilación:

```bash
# Compilar todo el sistema
make

# Compilar y ejecutar en QEMU
make run

# Compilar desde cero y ejecutar
make clean && make run
```

### Comandos Make Disponibles

| Comando | Descripción |
|---------|-------------|
| `make` | Compila todo el sistema (Stage1, Stage2, Kernel e imagen de disco) |
| `make run` | Compila y ejecuta en QEMU |
| `make clean` | Limpia todos los archivos compilados |
| `make clean-obj` | Limpia solo archivos objeto (mantiene binarios) |
| `make info` | Muestra información del kernel (tamaño, primeros bytes) |
| `make verify` | Verifica que el kernel esté correctamente en el disco |
| `make debug` | Inicia QEMU con servidor GDB para debugging |
| `make kill` | Termina procesos QEMU colgados |
| `make help` | Muestra ayuda completa con todos los comandos |

### Compilación Manual (Opcional)

Si prefieres compilar manualmente sin Make:

```bash
# 1. Compilar Stage1
nasm -f bin -I boot/ boot/boot.asm -o build/boot.bin

# 2. Compilar Stage2
nasm -f bin -I boot/ boot/stage2_sector2.asm -o build/stage2_sector2.bin

# 3. Compilar Kernel
nasm -f elf64 kernel/entry.asm -o build/entry.o
x86_64-elf-gcc -std=c11 -ffreestanding -mno-red-zone -mno-mmx -mno-sse -mno-sse2 \
    -c kernel/kernel.c -o build/kernel.o
x86_64-elf-ld -T kernel.ld -o build/kernel.elf build/entry.o build/kernel.o
x86_64-elf-objcopy -O binary build/kernel.elf build/kernel.bin

# 4. Crear imagen de disco
dd if=/dev/zero of=sector2.img bs=1M count=10
dd if=build/boot.bin of=sector2.img conv=notrunc
dd if=build/stage2_sector2.bin of=sector2.img bs=512 seek=1 conv=notrunc
dd if=build/kernel.bin of=sector2.img bs=512 seek=17 conv=notrunc

# 5. Ejecutar en QEMU
qemu-system-x86_64 -drive format=raw,file=sector2.img
```

### Debugging con GDB

Para hacer debugging del kernel:

```bash
# Terminal 1: Iniciar QEMU en modo debug
make debug

# Terminal 2: Conectar GDB
gdb -ex 'target remote localhost:1234' \
    -ex 'break *0x10000' \
    -ex 'continue'
```

---

## 🎓 Próximos Pasos

1. **IDT (Interrupt Descriptor Table)**: Manejo de interrupciones y excepciones
2. **Memoria dinámica**: Implementar kalloc/kfree
3. **Scheduler**: Multitarea cooperativa/preemptiva
4. **Drivers**: Teclado, timer, etc.
5. **IPC**: Comunicación entre procesos para arquitectura microkernel

---

## 📚 Referencias

- [OSDev Wiki](https://wiki.osdev.org/)
- [Intel® 64 and IA-32 Architectures Software Developer's Manual](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
- [ATA PIO Mode](https://wiki.osdev.org/ATA_PIO_Mode)

---

**Autor**: Rommel Samanez (rsamanez@gmail.com)  
**Fecha**: Noviembre 2025  
**Licencia**: MIT
