; ============================================================================
; STAGE 2 BOOTLOADER - Modo protegido a modo largo (CORREGIDO)
; ============================================================================

[BITS 16]
[ORG 0x1000]

KERNEL_OFFSET equ 0x10000
KERNEL_SECTORS equ 20

start:
    ; Configurar segmentos
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    
    mov [BOOT_DRIVE], dl
    
    mov si, msg_stage2
    call print16
    
    call enable_a20
    call load_kernel
    
    mov si, msg_switch
    call print16
    
    ; === CAMBIAR A MODO PROTEGIDO ===
    cli
    lgdt [gdtr]
    
    mov eax, cr0
    or al, 1
    mov cr0, eax
    
    ; Far jump a código de 32 bits
    jmp 0x08:start32

; === MODO REAL - FUNCIONES ===
enable_a20:
    in al, 0x92
    or al, 2
    out 0x92, al
    mov si, msg_a20
    call print16
    ret

load_kernel:
    mov si, msg_loading
    call print16
    
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
    jc .error
    
    mov si, msg_loaded
    call print16
    ret

.error:
    mov si, msg_error
    call print16
    jmp $

print16:
    pusha
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    popa
    ret

; === MODO PROTEGIDO (32 bits) ===
[BITS 32]
start32:
    ; Configurar segmentos de datos
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    
    ; Mensaje en VGA
    mov esi, msg_32bit
    mov edi, 0xB8000
    call print32
    
    ; Verificar CPUID y modo largo
    call check_cpuid
    call check_long_mode
    
    ; Configurar paginación
    call setup_paging
    
    ; Mensaje antes de 64 bits
    mov esi, msg_entering64
    mov edi, 0xB80A0
    call print32
    
    ; Habilitar modo largo
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr
    
    ; Habilitar paginación
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    
    ; Cargar GDT de 64 bits
    lgdt [gdtr64]
    
    ; Saltar a modo largo
    jmp 0x08:start64

check_cpuid:
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 0x200000
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    cmp eax, ecx
    je .no_cpuid
    ret
.no_cpuid:
    mov esi, msg_no_cpuid
    mov edi, 0xB8140
    call print32
    hlt
    jmp $

check_long_mode:
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_long
    mov eax, 0x80000001
    cpuid
    test edx, 0x20000000
    jz .no_long
    ret
.no_long:
    mov esi, msg_no_long
    mov edi, 0xB8140
    call print32
    hlt
    jmp $

setup_paging:
    ; Limpiar área de paginación
    mov edi, 0x70000
    mov cr3, edi
    xor eax, eax
    mov ecx, 4096
    rep stosd
    mov edi, cr3
    
    ; PML4[0] -> PDPT
    mov dword [edi], 0x71003
    
    ; PDPT[0] -> PDT  
    mov dword [edi + 0x1000], 0x72003
    
    ; PDT: mapear primeros 8MB con páginas de 2MB
    mov dword [edi + 0x2000], 0x000083
    mov dword [edi + 0x2008], 0x200083
    mov dword [edi + 0x2010], 0x400083
    mov dword [edi + 0x2018], 0x600083
    
    ; Habilitar PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax
    
    ret

print32:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0F
    stosw
    jmp .loop
.done:
    popa
    ret

; === MODO LARGO (64 bits) ===
[BITS 64]
start64:
    ; Limpiar segmentos
    xor ax, ax
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    ; Mensaje en 64 bits
    mov rsi, msg_64bit
    mov rdi, 0xB8140
    call print64
    
    ; Saltar al kernel
    mov rax, KERNEL_OFFSET
    jmp rax
    
    ; Si el kernel retorna
    hlt
    jmp $

print64:
    push rax
    push rdi
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0A
    stosw
    jmp .loop
.done:
    pop rdi
    pop rax
    ret

; === DATOS ===
BOOT_DRIVE: db 0

msg_stage2:      db "Stage2 OK", 0x0D, 0x0A, 0
msg_a20:         db "A20 OK", 0x0D, 0x0A, 0
msg_loading:     db "Loading kernel...", 0x0D, 0x0A, 0
msg_loaded:      db "Loaded OK", 0x0D, 0x0A, 0
msg_switch:      db "Switching...", 0x0D, 0x0A, 0
msg_error:       db "Load ERROR!", 0x0D, 0x0A, 0
msg_32bit:       db "32-bit OK", 0
msg_entering64:  db "Entering 64-bit...", 0
msg_64bit:       db "64-bit OK", 0
msg_no_cpuid:    db "No CPUID!", 0
msg_no_long:     db "No 64-bit!", 0

; === GDT para modo protegido ===
align 16
gdt:
    dq 0x0000000000000000    ; Null
    dq 0x00CF9A000000FFFF    ; Code 32
    dq 0x00CF92000000FFFF    ; Data 32
gdt_end:

gdtr:
    dw gdt_end - gdt - 1
    dd gdt

; === GDT para modo largo ===
align 16
gdt64:
    dq 0x0000000000000000    ; Null
    dq 0x00209A0000000000    ; Code 64
    dq 0x0000920000000000    ; Data 64
gdt64_end:

gdtr64:
    dw gdt64_end - gdt64 - 1
    dd gdt64

times 8192-($-$$) db 0
