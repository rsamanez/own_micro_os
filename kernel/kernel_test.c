// Test kernel minimalista

void kernel_main(void) {
    // Escribir directamente en memoria VGA
    unsigned short* vga = (unsigned short*)0xB8000;
    
    // Limpiar pantalla con fondo azul
    for (int i = 0; i < 80 * 25; i++) {
        vga[i] = 0x1F20;  // Espacio blanco en fondo azul
    }
    
    // Escribir "C KERNEL OK!"
    const char* message = "C KERNEL OK!";
    for (int i = 0; message[i] != '\0'; i++) {
        vga[i] = 0x0A00 | message[i];  // Verde brillante
    }
    
    // Loop infinito
    while (1) {
        __asm__ volatile ("hlt");
    }
}
