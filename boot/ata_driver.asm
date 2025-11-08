; ============================================================================
; Driver ATA básico usando PIO (Programmed I/O)
; Para leer sectores desde disco sin BIOS en modo protegido/64-bit
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

; ============================================================================
; ata_wait_bsy: Espera hasta que el disco no esté ocupado
; ============================================================================
[bits 32]
ata_wait_bsy:
    push eax
.loop:
    mov dx, ATA_PRIMARY_STATUS
    in al, dx
    test al, ATA_SR_BSY
    jnz .loop
    pop eax
    ret

; ============================================================================
; ata_wait_drq: Espera hasta que el disco esté listo para transferir datos
; ============================================================================
ata_wait_drq:
    push eax
.loop:
    mov dx, ATA_PRIMARY_STATUS
    in al, dx
    test al, ATA_SR_DRQ
    jz .loop
    pop eax
    ret

; ============================================================================
; ata_read_sector_pio: Lee un sector usando PIO mode
; Entrada:
;   EAX = LBA del sector (28-bit LBA)
;   EDI = Dirección de destino (debe ser válida y alineada)
; Salida:
;   EAX = 0 si éxito, != 0 si error
; ============================================================================
ata_read_sector_pio:
    pushad
    
    ; 1. Esperar a que el disco no esté ocupado
    call ata_wait_bsy
    
    ; 2. Seleccionar drive y configurar modo LBA
    mov dx, ATA_PRIMARY_DRIVE_HEAD
    mov bl, al              ; Guardar bits 24-27 del LBA
    shr bl, 24
    and bl, 0x0F           ; Solo bits 24-27
    or bl, 0xE0            ; Modo LBA + Drive 0 (master)
    mov al, bl
    out dx, al
    
    ; 3. Escribir el número de sectores (1 sector)
    mov dx, ATA_PRIMARY_SECCOUNT
    mov al, 1
    out dx, al
    
    ; 4. Escribir LBA (bits 0-7)
    mov dx, ATA_PRIMARY_LBA_LO
    pop eax                 ; Recuperar EAX original
    push eax
    out dx, al
    
    ; 5. Escribir LBA (bits 8-15)
    mov dx, ATA_PRIMARY_LBA_MID
    shr eax, 8
    out dx, al
    
    ; 6. Escribir LBA (bits 16-23)
    mov dx, ATA_PRIMARY_LBA_HI
    shr eax, 8
    out dx, al
    
    ; 7. Enviar comando READ
    mov dx, ATA_PRIMARY_COMMAND
    mov al, ATA_CMD_READ_PIO
    out dx, al
    
    ; 8. Esperar a que el disco esté listo
    call ata_wait_bsy
    call ata_wait_drq
    
    ; 9. Leer 256 words (512 bytes) desde el puerto de datos
    mov ecx, 256            ; 256 words = 512 bytes
    mov dx, ATA_PRIMARY_DATA
    pop edi                 ; Dirección de destino
    push edi
    
.read_loop:
    in ax, dx               ; Leer word (16 bits)
    stosw                   ; Guardar en [EDI] y avanzar EDI
    loop .read_loop
    
    ; 10. Verificar errores
    mov dx, ATA_PRIMARY_STATUS
    in al, dx
    test al, ATA_SR_ERR
    jnz .error
    
    popad
    xor eax, eax            ; Retornar 0 (éxito)
    ret

.error:
    popad
    mov eax, 1              ; Retornar 1 (error)
    ret

; ============================================================================
; ata_read_sectors: Lee múltiples sectores
; Entrada:
;   EAX = LBA inicial
;   ECX = Número de sectores
;   EDI = Dirección de destino
; Salida:
;   EAX = 0 si éxito, != 0 si error
; ============================================================================
ata_read_sectors:
    pushad
    
    mov [.lba], eax
    mov [.count], ecx
    mov [.dest], edi
    
.loop:
    ; Leer un sector
    mov eax, [.lba]
    mov edi, [.dest]
    call ata_read_sector_pio
    
    ; Verificar error
    test eax, eax
    jnz .error
    
    ; Actualizar variables
    inc dword [.lba]        ; Siguiente sector
    add dword [.dest], 512  ; Siguiente bloque de 512 bytes
    dec dword [.count]
    jnz .loop
    
    popad
    xor eax, eax
    ret

.error:
    popad
    mov eax, 1
    ret

; Variables temporales
align 4
.lba:   dd 0
.count: dd 0
.dest:  dd 0
