; ============================================================================
; STAGE 2 ULTRA SIMPLE - Sin modo protegido, directo a kernel en modo real
; ============================================================================

[BITS 16]
[ORG 0x1000]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x9000
    sti
    
    mov [BOOT_DRIVE], dl
    
    ; Mensaje
    mov si, msg_1
    call print
    
    ; Habilitar A20
    in al, 0x92
    or al, 2
    out 0x92, al
    
    mov si, msg_2
    call print
    
    ; Cargar kernel
    xor ax, ax
    mov dl, [BOOT_DRIVE]
    int 0x13
    
    mov ah, 0x02
    mov al, 4
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
    
    ; Escribir en VGA directamente desde modo real
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov byte [es:di], 'O'
    mov byte [es:di+1], 0x0A
    mov byte [es:di+2], 'K'
    mov byte [es:di+3], 0x0A
    
    ; Detener aquí para verificar
    hlt
    jmp $

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

BOOT_DRIVE: db 0
msg_1: db "Stage2", 0x0D, 0x0A, 0
msg_2: db "A20", 0x0D, 0x0A, 0
msg_3: db "Loaded", 0x0D, 0x0A, 0
msg_err: db "ERROR", 0x0D, 0x0A, 0

times 8192-($-$$) db 0
