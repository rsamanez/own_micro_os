[BITS 16]

Print:
    pusha
    mov ah, 0x0E
.Loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .Loop
.done:
    popa
    ret
