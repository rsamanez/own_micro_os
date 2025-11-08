[BITS 32]

DetectCPUID:
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 << 21
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    xor eax, ecx
    jz .NoCPUID
    ret
.NoCPUID:
    mov byte [0xb8000], 'N'
    mov byte [0xb8001], 0x0C
    mov byte [0xb8002], 'O'
    mov byte [0xb8003], 0x0C
    hlt

DetectLongMode:
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .NoLongMode
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz .NoLongMode
    ret
.NoLongMode:
    mov byte [0xb8000], 'N'
    mov byte [0xb8001], 0x0C
    mov byte [0xb8002], 'L'
    mov byte [0xb8003], 0x0C
    hlt
