; ============================================================================
; STAGE 2 BOOTLOADER SIMPLE - Para depuración
; ============================================================================

[BITS 16]
[ORG 0x1000]

start:
    ; Guardar drive
    mov [BOOT_DRIVE], dl
    
    ; Mensaje
    mov si, msg_stage2
    call print
    
    ; Test: solo mostrar mensaje y detenerse
    mov si, msg_test
    call print
    
    ; Detener aquí para verificar que funciona
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

BOOT_DRIVE: db 0
msg_stage2: db "Stage 2: OK", 0x0D, 0x0A, 0
msg_test: db "Test: bootloader working!", 0x0D, 0x0A, 0

times 8192-($-$$) db 0
