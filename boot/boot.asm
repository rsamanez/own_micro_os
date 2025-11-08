; ============================================================================
; STAGE 1 BOOTLOADER - Sector de arranque (512 bytes)
; Carga el Stage 2 desde disco y le pasa el control
; ============================================================================

[BITS 16]               ; Iniciar en modo real de 16 bits
[ORG 0x7C00]            ; BIOS carga el bootloader en 0x7C00

STAGE2_OFFSET equ 0x1000    ; Dónde cargar el Stage 2 en memoria
STAGE2_SECTORS equ 16       ; Cuántos sectores leer (8KB)

KERNEL_OFFSET equ 0x10000   ; Dónde cargar el kernel
KERNEL_SECTOR equ 17        ; Sector donde inicia el kernel
KERNEL_SECTORS equ 4        ; Cuántos sectores del kernel

start:
    ; Limpiar registros de segmento
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00      ; Stack crece hacia abajo desde bootloader
    
    ; Guardar número de drive en memoria fija
    mov [BOOT_DRIVE], dl
    mov [0x1000], dl    ; También guardarlo donde Stage 2 pueda leerlo
    
    ; Mostrar mensaje de inicio
    mov si, msg_loading
    call print_string
    
    ; Cargar Stage 2 desde disco
    call load_stage2
    
    ; Cargar Kernel desde disco
    call load_kernel
    
    ; Pasar el drive a Stage 2
    mov dl, [BOOT_DRIVE]
    
    ; Saltar al Stage 2
    jmp STAGE2_OFFSET

; ----------------------------------------------------------------------------
; load_stage2: Carga el segundo stage del bootloader desde disco
; ----------------------------------------------------------------------------
load_stage2:
    mov ah, 0x02            ; Función de BIOS: leer sectores
    mov al, STAGE2_SECTORS  ; Número de sectores a leer
    mov ch, 0               ; Cilindro 0
    mov cl, 2               ; Sector 2 (el sector 1 es este bootloader)
    mov dh, 0               ; Cabeza 0
    mov dl, [BOOT_DRIVE]    ; Drive desde el cual arrancar
    
    mov bx, STAGE2_OFFSET   ; Dónde cargar en memoria (ES:BX)
    
    int 0x13                ; Llamada a BIOS
    jc disk_error           ; Si carry flag está set, hubo error
    
    ; Verificar que se leyeron todos los sectores
    cmp al, STAGE2_SECTORS
    jne disk_error
    
    mov si, msg_success
    call print_string
    ret

; ----------------------------------------------------------------------------
; load_kernel: Carga el kernel desde disco
; ----------------------------------------------------------------------------
load_kernel:
    mov ah, 0x02            ; Función de BIOS: leer sectores
    mov al, KERNEL_SECTORS  ; Número de sectores
    mov ch, 0               ; Cilindro 0
    mov cl, KERNEL_SECTOR   ; Sector inicial del kernel
    mov dh, 0               ; Cabeza 0
    mov dl, [BOOT_DRIVE]    ; Drive
    
    ; Configurar ES:BX para 0x10000 (ES=0x1000, BX=0)
    mov bx, 0x1000
    mov es, bx
    xor bx, bx              ; Offset 0
    
    int 0x13
    jc disk_error
    
    ; Restaurar ES
    xor ax, ax
    mov es, ax
    
    mov si, msg_kernel
    call print_string
    ret

disk_error:
    mov si, msg_disk_error
    call print_string
    jmp $                   ; Loop infinito

; ----------------------------------------------------------------------------
; print_string: Imprime string terminado en null (SI apunta al string)
; ----------------------------------------------------------------------------
print_string:
    pusha
    mov ah, 0x0E            ; Función de BIOS: teletype output
.loop:
    lodsb                   ; Cargar byte de [SI] en AL, incrementar SI
    cmp al, 0               ; ¿Es null?
    je .done
    int 0x10                ; Llamada a BIOS para imprimir carácter
    jmp .loop
.done:
    popa
    ret

; ----------------------------------------------------------------------------
; Datos
; ----------------------------------------------------------------------------
BOOT_DRIVE:     db 0
msg_loading:    db "Loading Stage 2...", 0x0D, 0x0A, 0
msg_success:    db "OK", 0x0D, 0x0A, 0
msg_kernel:     db "Kernel loaded", 0x0D, 0x0A, 0
msg_disk_error: db "Disk error!", 0x0D, 0x0A, 0

; ----------------------------------------------------------------------------
; Rellenar con ceros hasta el final del sector y firma de boot
; ----------------------------------------------------------------------------
times 510-($-$$) db 0   ; Rellenar con ceros
dw 0xAA55               ; Firma de boot (little endian)
