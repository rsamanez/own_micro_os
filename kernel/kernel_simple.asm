; ============================================================================
; KERNEL SIMPLE - Solo escribe en VGA para probar
; ============================================================================

[BITS 64]
[ORG 0x10000]

kernel_entry:
    ; Escribir "KERNEL OK!" en VGA
    mov rax, 0xB8000
    
    mov byte [rax], 'K'
    mov byte [rax+1], 0x0A
    mov byte [rax+2], 'E'
    mov byte [rax+3], 0x0A
    mov byte [rax+4], 'R'
    mov byte [rax+5], 0x0A
    mov byte [rax+6], 'N'
    mov byte [rax+7], 0x0A
    mov byte [rax+8], 'E'
    mov byte [rax+9], 0x0A
    mov byte [rax+10], 'L'
    mov byte [rax+11], 0x0A
    
    mov byte [rax+12], ' '
    mov byte [rax+13], 0x0A
    
    mov byte [rax+14], 'O'
    mov byte [rax+15], 0x0E
    mov byte [rax+16], 'K'
    mov byte [rax+17], 0x0E
    mov byte [rax+18], '!'
    mov byte [rax+19], 0x0E
    
    ; Loop infinito
    cli
    hlt
    jmp $

times 2048-($-$$) db 0
