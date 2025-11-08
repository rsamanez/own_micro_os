; ============================================================================
; STAGE 2 BOOTLOADER - Versión de prueba sin cambio de modo
; Solo carga el kernel y muestra información
; ============================================================================

[BITS 16]
[ORG 0x1000]

KERNEL_OFFSET equ 0x10000
KERNEL_SECTORS equ 20

start:
    mov [BOOT_DRIVE], dl
    
    mov si, msg_stage2
    call print
    
    call enable_a20
    
    mov si, msg_loading
    call print
    
    call load_kernel
    
    ; Verificar que el kernel se cargó mostrando primeros bytes
    mov si, msg_verify
    call print
    
    ; Mostrar primeros 4 bytes del kernel en 0x10000
    mov ax, 0x1000
    mov ds, ax
    xor si, si
    mov cx, 4
.show_bytes:
    lodsb
    call print_hex_al
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    loop .show_bytes
    
    mov ax, 0
    mov ds, ax
    
    mov si, msg_done
    call print
    
    jmp $

enable_a20:
    in al, 0x92
    or al, 2
    out 0x92, al
    
    mov si, msg_a20
    call print
    ret

load_kernel:
    ; Reset disco
    xor ax, ax
    mov dl, [BOOT_DRIVE]
    int 0x13
    
    ; Leer kernel
    mov ah, 0x02
    mov al, KERNEL_SECTORS
    mov ch, 0
    mov cl, 18           ; Sector 18
    mov dh, 0
    mov dl, [BOOT_DRIVE]
    
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    
    int 0x13
    jc .error
    
    cmp al, KERNEL_SECTORS
    jne .error
    
    mov si, msg_loaded
    call print
    ret

.error:
    mov si, msg_error
    call print
    mov al, ah
    call print_hex_al
    jmp $

print:
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

print_hex_al:
    pusha
    mov cx, 2
    mov bl, al
.loop:
    rol bl, 4
    mov al, bl
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .print
    add al, 7
.print:
    mov ah, 0x0E
    int 0x10
    dec cx
    jnz .loop
    popa
    ret

BOOT_DRIVE: db 0
msg_stage2: db "Stage2 OK", 0x0D, 0x0A, 0
msg_a20: db "A20 OK", 0x0D, 0x0A, 0
msg_loading: db "Loading...", 0x0D, 0x0A, 0
msg_loaded: db "Loaded OK", 0x0D, 0x0A, 0
msg_verify: db "First bytes: ", 0
msg_done: db 0x0D, 0x0A, "All OK! System halted.", 0x0D, 0x0A, 0
msg_error: db "ERROR: ", 0

times 8192-($-$$) db 0
