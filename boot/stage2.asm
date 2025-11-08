; ============================================================================
; STAGE 2 BOOTLOADER SIMPLE - Salto directo al kernel en modo real
; Para depuración: no cambiamos de modo, solo saltamos al kernel
; ============================================================================

[BITS 16]
[ORG 0x1000]

KERNEL_OFFSET equ 0x10000
KERNEL_SECTORS equ 20

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x9000
    sti
    
    mov [BOOT_DRIVE], dl
    
    mov si, msg_stage2
    call print
    
    ; Habilitar A20
    in al, 0x92
    or al, 2
    out 0x92, al
    
    mov si, msg_a20
    call print
    
    ; Cargar kernel
    mov si, msg_loading
    call print
    
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
    
    mov si, msg_loaded
    call print
    
    ; ============================================
    ; CAMBIAR A MODO PROTEGIDO DE FORMA SEGURA
    ; ============================================
    cli
    
    ; Cargar GDT usando dirección absoluta
    lgdt [gdt_ptr + 0x1000]
    
    ; Activar bit PE (Protected Mode Enable)
    mov eax, cr0
    or al, 1
    mov cr0, eax
    
    ; Far jump a modo protegido - CLAVE: usar dirección absoluta
    db 0x66          ; Prefix de 32 bits
    db 0xEA          ; Far jump opcode
    dd pm_start + 0x1000  ; Offset (32 bits)
    dw 0x08          ; Selector de código

error:
    mov si, msg_error
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

; === DATOS ===
align 4
BOOT_DRIVE: db 0
msg_stage2:  db "Stage2", 0x0D, 0x0A, 0
msg_a20:     db "A20", 0x0D, 0x0A, 0
msg_loading: db "Load...", 0x0D, 0x0A, 0
msg_loaded:  db "OK!", 0x0D, 0x0A, 0
msg_error:   db "ERR!", 0x0D, 0x0A, 0

; === GDT ===
align 16
gdt:
    ; Null descriptor
    dq 0
    
    ; Code segment (base=0, limit=4GB, 32-bit, executable, readable)
    dw 0xFFFF         ; Limit 0:15
    dw 0x0000         ; Base 0:15
    db 0x00           ; Base 16:23
    db 10011010b      ; Access: Present, Ring 0, Code, Executable, Readable
    db 11001111b      ; Flags: 4K granular, 32-bit, Limit 16:19
    db 0x00           ; Base 24:31
    
    ; Data segment (base=0, limit=4GB, 32-bit, writable)
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b      ; Access: Present, Ring 0, Data, Writable
    db 11001111b
    db 0x00

gdt_end:

gdt_ptr:
    dw gdt_end - gdt - 1    ; Limit
    dd gdt + 0x1000         ; Base (dirección absoluta)

; ============================================
; MODO PROTEGIDO (32 bits)
; ============================================
[BITS 32]
pm_start:
    ; Configurar segmentos de datos
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    
    ; Escribir mensaje en VGA
    mov byte [0xB8000], '3'
    mov byte [0xB8001], 0x0F
    mov byte [0xB8002], '2'
    mov byte [0xB8003], 0x0F
    
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
    jz no_cpuid
    
    ; Verificar Long Mode
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb no_long_mode
    
    mov eax, 0x80000001
    cpuid
    test edx, (1 << 29)
    jz no_long_mode
    
    ; Escribir OK
    mov byte [0xB8004], 'O'
    mov byte [0xB8005], 0x0A
    mov byte [0xB8006], 'K'
    mov byte [0xB8007], 0x0A
    
    ; Configurar paginación para Long Mode
    call setup_paging
    
    ; Cargar GDT de 64 bits
    lgdt [gdt64_ptr]
    
    ; Habilitar Long Mode en EFER
    mov ecx, 0xC0000080
    rdmsr
    or eax, (1 << 8)      ; LME bit
    wrmsr
    
    ; Habilitar paging
    mov eax, cr0
    or eax, (1 << 31)     ; PG bit
    mov cr0, eax
    
    ; Far jump a Long Mode
    jmp 0x08:long_mode_start

no_cpuid:
    mov byte [0xB8004], 'N'
    mov byte [0xB8005], 0x0C
    mov byte [0xB8006], 'C'
    mov byte [0xB8007], 0x0C
    hlt
    jmp $

no_long_mode:
    mov byte [0xB8004], 'N'
    mov byte [0xB8005], 0x0C
    mov byte [0xB8006], 'L'
    mov byte [0xB8007], 0x0C
    hlt
    jmp $

setup_paging:
    ; Limpiar 16KB para las tablas de páginas
    mov edi, 0x70000
    mov cr3, edi
    xor eax, eax
    mov ecx, 4096
    rep stosd
    
    ; Setup page tables
    mov edi, 0x70000
    
    ; PML4[0] -> PDPT at 0x71000
    mov dword [edi], 0x71003
    
    ; PDPT[0] -> PD at 0x72000
    mov dword [edi + 0x1000], 0x72003
    
    ; PD: mapear primeros 4 x 2MB = 8MB con huge pages
    mov dword [edi + 0x2000], 0x000083
    mov dword [edi + 0x2008], 0x200083
    mov dword [edi + 0x2010], 0x400083
    mov dword [edi + 0x2018], 0x600083
    
    ; Habilitar PAE en CR4
    mov eax, cr4
    or eax, (1 << 5)
    mov cr4, eax
    
    ret

; === GDT de 64 bits ===
align 16
gdt64:
    dq 0                            ; Null
    dq 0x00209A0000000000          ; Code (execute/read)
    dq 0x0000920000000000          ; Data (read/write)

gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dd gdt64

; ============================================
; MODO LARGO (64 bits)
; ============================================
[BITS 64]
long_mode_start:
    ; Limpiar segmentos
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    ; Mensaje en VGA
    mov byte [0xB8080], '6'
    mov byte [0xB8081], 0x0A
    mov byte [0xB8082], '4'
    mov byte [0xB8083], 0x0A
    
    ; Saltar al kernel en 0x10000
    mov rax, KERNEL_OFFSET
    jmp rax
    
    ; Si regresa, loop
    hlt
    jmp $

times 8192-($-$$) db 0
