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

%include "ata_driver64.asm"

KERNEL_LBA equ 17           ; Sector donde inicia el kernel
KERNEL_SECTORS equ 8        ; Cuántos sectores del kernel
KERNEL_DEST equ 0x10000     ; Dónde cargar el kernel

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
	
	; ===== CARGAR KERNEL DESDE DISCO EN MODO 64-BIT =====
	; Mensaje de carga
	mov rax, 0xB8000 + 160
	mov byte [rax], 'L'
	mov byte [rax+1], 0x0E
	mov byte [rax+2], 'o'
	mov byte [rax+3], 0x0E
	mov byte [rax+4], 'a'
	mov byte [rax+5], 0x0E
	mov byte [rax+6], 'd'
	mov byte [rax+7], 0x0E
	mov byte [rax+8], 'i'
	mov byte [rax+9], 0x0E
	mov byte [rax+10], 'n'
	mov byte [rax+11], 0x0E
	mov byte [rax+12], 'g'
	mov byte [rax+13], 0x0E
	mov byte [rax+14], '.'
	mov byte [rax+15], 0x0E
	mov byte [rax+16], '.'
	mov byte [rax+17], 0x0E
	mov byte [rax+18], '.'
	mov byte [rax+19], 0x0E
	
	; Cargar kernel usando driver ATA
	mov rax, KERNEL_LBA         ; LBA inicial
	mov rcx, KERNEL_SECTORS     ; Número de sectores
	mov rdi, KERNEL_DEST        ; Dirección de destino
	call ata_read_sectors
	
	; Verificar si hubo error
	test rax, rax
	jnz .load_error
	
	; Mensaje de éxito
	mov rax, 0xB8000 + 320
	mov byte [rax], 'K'
	mov byte [rax+1], 0x0A
	mov byte [rax+2], 'e'
	mov byte [rax+3], 0x0A
	mov byte [rax+4], 'r'
	mov byte [rax+5], 0x0A
	mov byte [rax+6], 'n'
	mov byte [rax+7], 0x0A
	mov byte [rax+8], 'e'
	mov byte [rax+9], 0x0A
	mov byte [rax+10], 'l'
	mov byte [rax+11], 0x0A
	mov byte [rax+12], ' '
	mov byte [rax+13], 0x0A
	mov byte [rax+14], 'O'
	mov byte [rax+15], 0x0A
	mov byte [rax+16], 'K'
	mov byte [rax+17], 0x0A
	mov byte [rax+18], '!'
	mov byte [rax+19], 0x0A
	
	; Saltar al kernel
	mov rax, KERNEL_DEST
	jmp rax
	
.load_error:
	; Mensaje de error
	mov rax, 0xB8000 + 320
	mov byte [rax], 'E'
	mov byte [rax+1], 0x0C
	mov byte [rax+2], 'R'
	mov byte [rax+3], 0x0C
	mov byte [rax+4], 'R'
	mov byte [rax+5], 0x0C
	mov byte [rax+6], 'O'
	mov byte [rax+7], 0x0C
	mov byte [rax+8], 'R'
	mov byte [rax+9], 0x0C
	mov byte [rax+10], '!'
	mov byte [rax+11], 0x0C
	
	; Loop infinito si hay error
	cli
	hlt

times 8192-($-$$) db 0 ; 16 sectores = 8KB
