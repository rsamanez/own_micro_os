; ============================================================================
; STAGE 2 BOOTLOADER - VERSION DEBUG
; Muestra mensajes detallados en cada paso
; ============================================================================

[BITS 16]
[ORG 0x1000]

KERNEL_OFFSET equ 0x10000
KERNEL_SECTORS equ 4        ; Solo 4 sectores para el kernel simple

start:
    ; Guardar el número de drive que viene en DL desde Stage1
    mov [BOOT_DRIVE], dl
    
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    
    mov [BOOT_DRIVE], dl
    
    mov si, msg_1
    call print
    call delay              ; Delay después del primer mensaje
    
    ; Habilitar A20
    in al, 0x92
    or al, 2
    out 0x92, al
    
    mov si, msg_2
    call print
    call delay              ; Delay después del segundo mensaje
    
    ; Cargar kernel
    xor ax, ax
    mov dl, [BOOT_DRIVE]
    int 0x13
    
    mov ah, 0x02
    mov al, KERNEL_SECTORS
    mov ch, 0
    mov cl, 18
    mov dh, 0
    mov dl, [BOOT_DRIVE]
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    int 0x13
    jc error
    
    mov si, msg_3
    call print
    call delay              ; Delay después del tercer mensaje
    
    ; === MODO PROTEGIDO ===
    mov si, msg_4
    call print
    call delay              ; Delay después del cuarto mensaje
    
    cli
    
    ; Cargar GDT
    lgdt [gdt_descriptor]
    
    mov eax, cr0
    or al, 1
    mov cr0, eax
    
    ; Mostrar mensaje después de activar PE bit
    mov si, msg_4b
    call print
    call delay
    
    ; Far jump a modo protegido
    jmp codeseg:pm_entry

error:
    mov si, msg_err
    call print
    hlt
    jmp $

print:
    pusha
    mov ah, 0x0E
.l:
    lodsb
    test al, al
    jz .d
    int 0x10
    jmp .l
.d:
    popa
    ret

; Delay de aproximadamente 1-2 segundos
delay:
    push cx
    push dx
    mov cx, 0xFF        ; Outer loop (MÁXIMO)
.outer:
    mov dx, 0xFFFF      ; Inner loop
.inner:
    dec dx
    jnz .inner
    dec cx
    jnz .outer
    pop dx
    pop cx
    ret

BOOT_DRIVE: db 0
msg_1: db "1.Start", 0x0D, 0x0A, 0
msg_2: db "2.A20", 0x0D, 0x0A, 0
msg_3: db "3.Loaded", 0x0D, 0x0A, 0
msg_4: db "4.PM...", 0x0D, 0x0A, 0
msg_4b: db "4b.PE", 0x0D, 0x0A, 0
msg_err: db "ERROR!", 0x0D, 0x0A, 0

gdt_nulldesc:
    dd 0
    dd 0

gdt_codedesc:
    dw 0xFFFF       ; Limit 
    dw 0x0000       ; Base(low)
    db 0x00         ; base(medium)
    db 10011010b    ; Flags
    db 11001111b    ; Flags + upper limit
    db 0x00         ; Base(high)
    
gdt_datadesc:
    dw 0xFFFF   
    dw 0x0000   
    db 0x00
    db 10010010b
    db 11001111b
    db 0x00

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_nulldesc - 1
    dd gdt_nulldesc

codeseg equ gdt_codedesc - gdt_nulldesc
dataseg equ gdt_datadesc - gdt_nulldesc

; === 32 BITS ===
[BITS 32]
pm_entry:
    mov ax, dataseg
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    
    ; Escribir "5" en VGA
    mov byte [0xB8000], '5'
    mov byte [0xB8001], 0x0F
    mov byte [0xB8002], '.'
    mov byte [0xB8003], 0x0F
    mov byte [0xB8004], 'P'
    mov byte [0xB8005], 0x0F
    mov byte [0xB8006], 'M'
    mov byte [0xB8007], 0x0F
    
    call delay32            ; DELAY DESPUÉS DE "5.PM"
    
    ; Verificar CPUID
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 0x200000
    push eax
    popfd
    pushfd
    pop eax
    xor eax, ecx
    jz .no_cpuid
    
    ; Escribir "6" - CPUID OK
    mov byte [0xB8008], ' '
    mov byte [0xB8009], 0x0F
    mov byte [0xB800A], '6'
    mov byte [0xB800B], 0x0E
    mov byte [0xB800C], '.'
    mov byte [0xB800D], 0x0E
    
    call delay32            ; Delay después de mostrar "6"
    
    ; Verificar Long Mode
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_long
    
    mov eax, 0x80000001
    cpuid
    test edx, (1 << 29)
    jz .no_long
    
    ; Escribir "7" - Long Mode disponible
    mov byte [0xB800E], 'L'
    mov byte [0xB800F], 0x0E
    mov byte [0xB8010], 'M'
    mov byte [0xB8011], 0x0E
    
    call delay32            ; Delay después de mostrar "LM"
    
    ; Setup paging
    call setup_paging
    
    ; Escribir "8" - Paging OK
    mov byte [0xB8014], '8'
    mov byte [0xB8015], 0x0A
    mov byte [0xB8016], '.'
    mov byte [0xB8017], 0x0A
    
    call delay32            ; Delay después de mostrar "8"
    
    ; Cargar GDT64
    lgdt [gdt64_ptr]
    
    ; Habilitar Long Mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, (1 << 8)
    wrmsr
    
    ; Habilitar paging
    mov eax, cr0
    or eax, (1 << 31)
    mov cr0, eax
    
    ; Escribir "9" - Antes de saltar a 64 bits
    mov byte [0xB8018], '9'
    mov byte [0xB8019], 0x0C
    mov byte [0xB801A], '.'
    mov byte [0xB801B], 0x0C
    
    call delay32            ; Delay antes del salto a 64-bits
    
    ; Saltar a 64 bits
    jmp 0x08:lm_entry
    
.no_cpuid:
    mov byte [0xB8008], 'N'
    mov byte [0xB8009], 0x0C
    mov byte [0xB800A], 'C'
    mov byte [0xB800B], 0x0C
    hlt
    jmp $
    
.no_long:
    mov byte [0xB8008], 'N'
    mov byte [0xB8009], 0x0C
    mov byte [0xB800A], 'L'
    mov byte [0xB800B], 0x0C
    hlt
    jmp $

; Delay de ~1-2 segundos para modo de 32 bits
delay32:
    push ecx
    push edx
    mov ecx, 0xFF        ; Outer loop (MÁXIMO)
.outer:
    mov edx, 0xFFFF      ; Inner loop
.inner:
    dec edx
    jnz .inner
    dec ecx
    jnz .outer
    pop edx
    pop ecx
    ret

setup_paging:
    mov edi, 0x70000
    mov cr3, edi
    xor eax, eax
    mov ecx, 4096
    rep stosd
    mov edi, 0x70000
    mov dword [edi], 0x71003
    mov dword [edi + 0x1000], 0x72003
    mov dword [edi + 0x2000], 0x000083
    mov dword [edi + 0x2008], 0x200083
    mov dword [edi + 0x2010], 0x400083
    mov dword [edi + 0x2018], 0x600083
    mov eax, cr4
    or eax, (1 << 5)
    mov cr4, eax
    ret

align 16
gdt64:
    dq 0
    dq 0x00209A0000000000
    dq 0x0000920000000000
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dd gdt64

; === 64 BITS ===
[BITS 64]
lm_entry:
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    ; Escribir "10" - Estamos en 64 bits!
    mov byte [0xB8020], '1'
    mov byte [0xB8021], 0x0A
    mov byte [0xB8022], '0'
    mov byte [0xB8023], 0x0A
    mov byte [0xB8024], '.'
    mov byte [0xB8025], 0x0A
    
    ; Escribir "JMP" antes de saltar al kernel
    mov byte [0xB8028], 'J'
    mov byte [0xB8029], 0x0E
    mov byte [0xB802A], 'M'
    mov byte [0xB802B], 0x0E
    mov byte [0xB802C], 'P'
    mov byte [0xB802D], 0x0E
    
    ; Saltar al kernel
    mov rax, KERNEL_OFFSET
    call rax
    
    ; Si regresa, mostrar "RET"
    mov byte [0xB8030], 'R'
    mov byte [0xB8031], 0x0C
    mov byte [0xB8032], 'E'
    mov byte [0xB8033], 0x0C
    mov byte [0xB8034], 'T'
    mov byte [0xB8035], 0x0C
    
    hlt
    jmp $

times 8192-($-$$) db 0
