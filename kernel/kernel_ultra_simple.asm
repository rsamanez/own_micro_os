[BITS 64]
[ORG 0x10000]

; Kernel ultra simple que solo escribe en VGA
start:
    ; Escribir "K!" en rojo en la posición 0
    mov rax, 0xB8000
    mov byte [rax], 'K'
    mov byte [rax+1], 0x0C  ; Rojo
    mov byte [rax+2], '!'
    mov byte [rax+3], 0x0C
    
    ; Loop infinito
    cli
    hlt
    jmp $
