; Test bootloader - Salta directamente a 0x10000 en modo real
; Para verificar que el kernel está en el lugar correcto

[BITS 16]
[ORG 0x7C00]

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    
    ; Cargar 20 sectores desde sector 1 a 0x1000:0
    mov ah, 0x02
    mov al, 20
    mov ch, 0
    mov cl, 2           ; Sector 2 (saltamos stage2, cargamos kernel directo)
    mov dh, 0
    mov dl, 0x80
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    int 0x13
    
    ; Mostrar mensaje
    mov si, msg
    call print
    
    ; Saltar directo a kernel cargado en 0x10000
    jmp 0x1000:0
    
print:
    mov ah, 0x0E
.l:
    lodsb
    test al, al
    jz .d
    int 0x10
    jmp .l
.d:
    ret

msg: db "Jump to kernel...", 0x0D, 0x0A, 0

times 510-($-$$) db 0
dw 0xAA55
