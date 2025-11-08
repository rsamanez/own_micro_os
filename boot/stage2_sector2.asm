[org 0x1000]

jmp EnterProtectedMode 

%include "gdt.asm"
%include "print.asm"

EnterProtectedMode:
	call EnableA20
	cli  ;Desabilita as interrupções
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

[bits 32]

%include "CPUID.asm"
%include "SimplePaging.asm"

StartProtectedMode:
	mov ax, dataseg
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	mov [0xb8000], byte 'H'

	call DetectCPUID
	call DetectLongMode
	call SetUpIdentityPaging
	call EditGDT

	jmp codeseg:Start64Bit 

[bits 64]

Start64Bit:
	; Limpiar pantalla con azul
	mov edi, 0xb8000
	mov rax, 0x1f201f201f201f20
	mov ecx, 500 
	rep stosq
	
	; Escribir "64-BIT MODE OK!" directamente
	mov rax, 0xB8000
	
	mov byte [rax], '6'
	mov byte [rax+1], 0x0A
	mov byte [rax+2], '4'
	mov byte [rax+3], 0x0A
	mov byte [rax+4], '-'
	mov byte [rax+5], 0x0A
	mov byte [rax+6], 'B'
	mov byte [rax+7], 0x0A
	mov byte [rax+8], 'I'
	mov byte [rax+9], 0x0A
	mov byte [rax+10], 'T'
	mov byte [rax+11], 0x0A
	
	mov byte [rax+12], ' '
	mov byte [rax+13], 0x0A
	
	mov byte [rax+14], 'M'
	mov byte [rax+15], 0x0E
	mov byte [rax+16], 'O'
	mov byte [rax+17], 0x0E
	mov byte [rax+18], 'D'
	mov byte [rax+19], 0x0E
	mov byte [rax+20], 'E'
	mov byte [rax+21], 0x0E
	
	mov byte [rax+22], ' '
	mov byte [rax+23], 0x0E
	
	mov byte [rax+24], 'O'
	mov byte [rax+25], 0x0C
	mov byte [rax+26], 'K'
	mov byte [rax+27], 0x0C
	mov byte [rax+28], '!'
	mov byte [rax+29], 0x0C
	
	; Saltar al kernel cargado en 0x10000
	mov rax, 0x10000
	jmp rax
	
	; Si el kernel retorna (no debería), loop infinito
	cli
	hlt

times 8192-($-$$) db 0 ; 16 sectores = 8KB
