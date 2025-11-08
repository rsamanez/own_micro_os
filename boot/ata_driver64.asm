; ============================================================================
; Driver ATA en modo 64-bit usando PIO (Programmed I/O)
; Para leer sectores desde disco sin BIOS
; ============================================================================

; Puertos ATA primario
ATA_PRIMARY_DATA       equ 0x1F0
ATA_PRIMARY_ERR        equ 0x1F1
ATA_PRIMARY_SECCOUNT   equ 0x1F2
ATA_PRIMARY_LBA_LO     equ 0x1F3
ATA_PRIMARY_LBA_MID    equ 0x1F4
ATA_PRIMARY_LBA_HI     equ 0x1F5
ATA_PRIMARY_DRIVE_HEAD equ 0x1F6
ATA_PRIMARY_STATUS     equ 0x1F7
ATA_PRIMARY_COMMAND    equ 0x1F7

; Comandos ATA
ATA_CMD_READ_PIO       equ 0x20

; Bits de status
ATA_SR_BSY   equ 0x80  ; Busy
ATA_SR_DRDY  equ 0x40  ; Drive ready
ATA_SR_DRQ   equ 0x08  ; Data request ready
ATA_SR_ERR   equ 0x01  ; Error

[bits 64]

; ============================================================================
; ata_wait_bsy: Espera hasta que el disco no esté ocupado
; ============================================================================
ata_wait_bsy:
    push rax
    push rdx
.loop:
    mov dx, ATA_PRIMARY_STATUS
    in al, dx
    test al, ATA_SR_BSY
    jnz .loop
    pop rdx
    pop rax
    ret

; ============================================================================
; ata_wait_drq: Espera hasta que el disco esté listo para transferir datos
; ============================================================================
ata_wait_drq:
    push rax
    push rdx
.loop:
    mov dx, ATA_PRIMARY_STATUS
    in al, dx
    test al, ATA_SR_DRQ
    jz .loop
    pop rdx
    pop rax
    ret

; ============================================================================
; ata_read_sector_pio: Lee un sector usando PIO mode en 64-bit
; Entrada:
;   RAX = LBA del sector (28-bit LBA)
;   RDI = Dirección de destino
; Salida:
;   RAX = 0 si éxito, != 0 si error
; ============================================================================
ata_read_sector_pio:
    push rbx
    push rcx
    push rdx
    push rdi
    
    mov rbx, rax            ; Guardar LBA en RBX
    
    ; 1. Esperar a que el disco no esté ocupado
    call ata_wait_bsy
    
    ; 2. Seleccionar drive y configurar modo LBA
    mov dx, ATA_PRIMARY_DRIVE_HEAD
    mov al, bl              ; Bits 24-27 del LBA
    shr al, 24
    and al, 0x0F            ; Solo bits 24-27
    or al, 0xE0             ; Modo LBA + Drive 0 (master)
    out dx, al
    
    ; 3. Escribir el número de sectores (1 sector)
    mov dx, ATA_PRIMARY_SECCOUNT
    mov al, 1
    out dx, al
    
    ; 4. Escribir LBA (bits 0-7)
    mov dx, ATA_PRIMARY_LBA_LO
    mov al, bl
    out dx, al
    
    ; 5. Escribir LBA (bits 8-15)
    mov dx, ATA_PRIMARY_LBA_MID
    mov rax, rbx
    shr rax, 8
    out dx, al
    
    ; 6. Escribir LBA (bits 16-23)
    mov dx, ATA_PRIMARY_LBA_HI
    mov rax, rbx
    shr rax, 16
    out dx, al
    
    ; 7. Enviar comando READ
    mov dx, ATA_PRIMARY_COMMAND
    mov al, ATA_CMD_READ_PIO
    out dx, al
    
    ; 8. Esperar a que el disco esté listo
    call ata_wait_bsy
    call ata_wait_drq
    
    ; 9. Leer 256 words (512 bytes) desde el puerto de datos
    mov rcx, 256            ; 256 words = 512 bytes
    mov dx, ATA_PRIMARY_DATA
    
.read_loop:
    in ax, dx               ; Leer word (16 bits)
    stosw                   ; Guardar en [RDI] y avanzar RDI
    loop .read_loop
    
    ; 10. Verificar errores
    mov dx, ATA_PRIMARY_STATUS
    in al, dx
    test al, ATA_SR_ERR
    jnz .error
    
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    xor rax, rax            ; Retornar 0 (éxito)
    ret

.error:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    mov rax, 1              ; Retornar 1 (error)
    ret

; ============================================================================
; ata_read_sectors: Lee múltiples sectores en 64-bit
; Entrada:
;   RAX = LBA inicial
;   RCX = Número de sectores
;   RDI = Dirección de destino
; Salida:
;   RAX = 0 si éxito, != 0 si error
; ============================================================================
ata_read_sectors:
    push rbx
    push rcx
    push rdi
    
    mov rbx, rax            ; RBX = LBA actual
    mov r8, rcx             ; R8 = contador de sectores
    
.loop:
    ; Leer un sector
    mov rax, rbx
    call ata_read_sector_pio
    
    ; Verificar error
    test rax, rax
    jnz .error
    
    ; Actualizar variables
    inc rbx                 ; Siguiente sector
    add rdi, 512            ; Siguiente bloque de 512 bytes
    dec r8
    jnz .loop
    
    pop rdi
    pop rcx
    pop rbx
    xor rax, rax
    ret

.error:
    pop rdi
    pop rcx
    pop rbx
    mov rax, 1
    ret
