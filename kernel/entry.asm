; ============================================================================
; KERNEL ENTRY POINT - Punto de entrada del kernel en 64 bits
; ============================================================================

[BITS 64]
[SECTION .text.entry]

extern kernel_main

global kernel_entry

kernel_entry:
    ; Ya estamos en modo de 64 bits gracias al bootloader
    
    ; Configurar stack
    mov rsp, 0x90000
    
    ; Limpiar la dirección de retorno (no hay nada a lo que volver)
    xor rbp, rbp
    
    ; Llamar a la función principal del kernel en C
    call kernel_main
    
    ; Si el kernel retorna, detener CPU
.hang:
    cli
    hlt
    jmp .hang
