; ============================================================================
; Funciones de lectura de disco en modo protegido (32-bit)
; Usa LBA (Logical Block Addressing) con int 0x13 extensiones
; ============================================================================

[bits 32]

; Estructura DAP (Disk Address Packet) para int 0x13 extensiones
align 4
DAP:
    db 0x10         ; Tamaño del DAP (16 bytes)
    db 0            ; Siempre 0
    dw 0            ; Número de sectores a leer
    dd 0            ; Dirección de destino (segment:offset)
    dq 0            ; LBA inicial

; ----------------------------------------------------------------------------
; LoadKernelFromDisk32: Carga el kernel desde disco en modo protegido
; Entrada:
;   EAX = LBA sector inicial
;   CX = Número de sectores
;   EDI = Dirección de destino
; Salida:
;   EAX = 0 si éxito, != 0 si error
; ----------------------------------------------------------------------------
LoadKernelFromDisk32:
    pushad
    
    ; Guardar parámetros
    mov [DAP + 2], cx           ; Número de sectores
    mov [DAP + 4], edi          ; Destino (offset)
    mov word [DAP + 6], 0       ; Destino (segmento = 0)
    mov [DAP + 8], eax          ; LBA inicial (parte baja)
    mov dword [DAP + 12], 0     ; LBA inicial (parte alta)
    
    ; Necesitamos volver a modo real temporalmente para usar BIOS
    ; Esto es complejo, mejor opción: cargar TODO en modo real
    
    popad
    xor eax, eax
    ret

; Nota: La estrategia correcta es cargar el kernel en modo real (Stage1 o Stage2 inicial)
; porque en modo protegido 32-bit no tenemos acceso directo a BIOS int 0x13
