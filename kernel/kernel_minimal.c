// Kernel minimalista sin variables globales

#define VGA_MEMORY ((unsigned short*)0xB8000)
#define VGA_WIDTH 80
#define VGA_HEIGHT 25

void kernel_main(void) {
    unsigned short* vga = VGA_MEMORY;
    
    // Limpiar pantalla con fondo negro
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
        vga[i] = 0x0F20;  // Espacio blanco en fondo negro
    }
    
    // Escribir mensaje
    const char* msg = "=== C Kernel OK! ===";
    int col = 0;
    
    while (*msg) {
        vga[col] = 0x0A00 | *msg;  // Verde brillante
        msg++;
        col++;
    }
    
    // Loop infinito
    while (1) {
        __asm__ volatile ("hlt");
    }
}
