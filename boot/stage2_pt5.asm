; ============================================================================
; STAGE 2 BOOTLOADER - Basado en pt5 de rsamanez/os-dev
; ============================================================================

[ORG 0x1000]
[BITS 16]

jmp EnterProtectedMode 

%include "gdt_pt5.asm"
%include "print_pt5.asm"

EnterProtectedMode:
    call EnableA20
    cli  ; Desabilita as interrupções
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp codeseg:StartProtectedMode

EnableA20:
    in al, 0x92
    or al, 2
    out 0x92, al
    ret

[BITS 32]

%include "CPUID_pt5.asm"
%include "SimplePaging_pt5.asm"

StartProtectedMode:
    mov ax, dataseg
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov byte [0xb8000], 'H'

    call DetectCPUID
    call DetectLongMode
    call SetUpIdentityPaging
    call EditGDT

    jmp codeseg:Start64Bit 

[BITS 64]

Start64Bit:
    mov edi, 0xb8000
    mov rax, 0x1f201f201f201f20
    mov ecx, 500 
    rep stosq
    
    ; Saltar al kernel en 0x10000
    jmp 0x08:0x10000

times 8192-($-$$) db 0 ; 16 sectores = 8KB
