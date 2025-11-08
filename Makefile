# Makefile para Micro OS - Bootloader 64-bit con Kernel en C

# Herramientas
NASM = nasm
GCC = x86_64-elf-gcc
LD = x86_64-elf-ld
OBJCOPY = x86_64-elf-objcopy
DD = dd
QEMU = qemu-system-x86_64

# Directorios
BUILD_DIR = build
BOOT_DIR = boot
KERNEL_DIR = kernel

# Archivos de salida
BOOT_BIN = $(BUILD_DIR)/boot.bin
STAGE2_BIN = $(BUILD_DIR)/stage2_sector2.bin
KERNEL_BIN = $(BUILD_DIR)/kernel.bin
DISK_IMG = sector2.img

# Archivos intermedios
ENTRY_OBJ = $(BUILD_DIR)/entry.o
KERNEL_OBJ = $(BUILD_DIR)/kernel.o
KERNEL_ELF = $(BUILD_DIR)/kernel.elf

# Flags de compilación
NASM_FLAGS = -f bin -I $(BOOT_DIR)/
NASM_ELF_FLAGS = -f elf64
GCC_FLAGS = -std=c11 -ffreestanding -mno-red-zone -mno-mmx -mno-sse -mno-sse2 -O2 -Wall -Wextra
LD_FLAGS = -T kernel.ld
QEMU_FLAGS = -drive format=raw,file=$(DISK_IMG)

# Colores para output
GREEN = \033[0;32m
BLUE = \033[0;34m
YELLOW = \033[0;33m
NC = \033[0m # No Color

# Target por defecto
.PHONY: all
all: $(DISK_IMG)
	@echo "$(GREEN)✓ Sistema compilado exitosamente$(NC)"
	@echo "$(BLUE)Ejecuta 'make run' para iniciar QEMU$(NC)"

# Crear directorio build
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)
	@echo "$(BLUE)✓ Directorio build/ creado$(NC)"

# Compilar Stage1 (boot.asm)
$(BOOT_BIN): $(BOOT_DIR)/boot.asm | $(BUILD_DIR)
	@echo "$(YELLOW)Compilando Stage1...$(NC)"
	$(NASM) $(NASM_FLAGS) $(BOOT_DIR)/boot.asm -o $(BOOT_BIN)
	@echo "$(GREEN)✓ Stage1 compilado$(NC)"

# Compilar Stage2 (stage2_sector2.asm)
$(STAGE2_BIN): $(BOOT_DIR)/stage2_sector2.asm $(BOOT_DIR)/ata_driver64.asm $(BOOT_DIR)/gdt.asm $(BOOT_DIR)/CPUID.asm $(BOOT_DIR)/SimplePaging.asm $(BOOT_DIR)/print.asm | $(BUILD_DIR)
	@echo "$(YELLOW)Compilando Stage2...$(NC)"
	$(NASM) $(NASM_FLAGS) $(BOOT_DIR)/stage2_sector2.asm -o $(STAGE2_BIN)
	@echo "$(GREEN)✓ Stage2 compilado$(NC)"

# Compilar entry.asm del kernel
$(ENTRY_OBJ): $(KERNEL_DIR)/entry.asm | $(BUILD_DIR)
	@echo "$(YELLOW)Compilando kernel entry point...$(NC)"
	$(NASM) $(NASM_ELF_FLAGS) $(KERNEL_DIR)/entry.asm -o $(ENTRY_OBJ)
	@echo "$(GREEN)✓ Entry point compilado$(NC)"

# Compilar kernel.c
$(KERNEL_OBJ): $(KERNEL_DIR)/kernel.c | $(BUILD_DIR)
	@echo "$(YELLOW)Compilando kernel en C...$(NC)"
	$(GCC) $(GCC_FLAGS) -c $(KERNEL_DIR)/kernel.c -o $(KERNEL_OBJ)
	@echo "$(GREEN)✓ Kernel compilado$(NC)"

# Linkar kernel
$(KERNEL_ELF): $(ENTRY_OBJ) $(KERNEL_OBJ) kernel.ld
	@echo "$(YELLOW)Linkando kernel...$(NC)"
	$(LD) $(LD_FLAGS) -o $(KERNEL_ELF) $(ENTRY_OBJ) $(KERNEL_OBJ)
	@echo "$(GREEN)✓ Kernel linkado$(NC)"

# Convertir kernel ELF a binario
$(KERNEL_BIN): $(KERNEL_ELF)
	@echo "$(YELLOW)Convirtiendo kernel a binario...$(NC)"
	$(OBJCOPY) -O binary $(KERNEL_ELF) $(KERNEL_BIN)
	@stat -f "$(GREEN)✓ Kernel binario creado (%z bytes)$(NC)" $(KERNEL_BIN)

# Crear imagen de disco
$(DISK_IMG): $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	@echo "$(YELLOW)Creando imagen de disco...$(NC)"
	@$(DD) if=/dev/zero of=$(DISK_IMG) bs=1M count=10 2>/dev/null
	@echo "$(BLUE)  → Escribiendo Stage1 en sector 0$(NC)"
	@$(DD) if=$(BOOT_BIN) of=$(DISK_IMG) conv=notrunc 2>/dev/null
	@echo "$(BLUE)  → Escribiendo Stage2 en sectores 1-16$(NC)"
	@$(DD) if=$(STAGE2_BIN) of=$(DISK_IMG) bs=512 seek=1 conv=notrunc 2>/dev/null
	@echo "$(BLUE)  → Escribiendo Kernel en sector 17+$(NC)"
	@$(DD) if=$(KERNEL_BIN) of=$(DISK_IMG) bs=512 seek=17 conv=notrunc 2>/dev/null
	@echo "$(GREEN)✓ Imagen de disco creada: $(DISK_IMG)$(NC)"

# Ejecutar en QEMU
.PHONY: run
run: $(DISK_IMG)
	@echo "$(BLUE)Iniciando QEMU...$(NC)"
	$(QEMU) $(QEMU_FLAGS)

# Ejecutar QEMU sin gráficos (solo texto)
.PHONY: run-nographic
run-nographic: $(DISK_IMG)
	@echo "$(BLUE)Iniciando QEMU (modo texto)...$(NC)"
	$(QEMU) $(QEMU_FLAGS) -nographic

# Compilar y ejecutar
.PHONY: test
test: all run

# Limpiar archivos compilados
.PHONY: clean
clean:
	@echo "$(YELLOW)Limpiando archivos compilados...$(NC)"
	@rm -rf $(BUILD_DIR)
	@rm -f $(DISK_IMG)
	@echo "$(GREEN)✓ Limpieza completa$(NC)"

# Limpiar solo archivos intermedios (mantener binarios)
.PHONY: clean-obj
clean-obj:
	@echo "$(YELLOW)Limpiando archivos objeto...$(NC)"
	@rm -f $(BUILD_DIR)/*.o $(BUILD_DIR)/*.elf
	@echo "$(GREEN)✓ Archivos objeto eliminados$(NC)"

# Mostrar información del kernel
.PHONY: info
info: $(KERNEL_BIN)
	@echo "$(BLUE)═══════════════════════════════════════$(NC)"
	@echo "$(BLUE)Información del Kernel$(NC)"
	@echo "$(BLUE)═══════════════════════════════════════$(NC)"
	@stat -f "Tamaño: %z bytes" $(KERNEL_BIN)
	@echo "Sectores necesarios: $$(echo $$(($$(stat -f%z $(KERNEL_BIN)) / 512 + 1)))"
	@echo "$(BLUE)═══════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(BLUE)Primeros bytes del kernel:$(NC)"
	@hexdump -C $(KERNEL_BIN) | head -10

# Verificar que el kernel está en el disco
.PHONY: verify
verify: $(DISK_IMG)
	@echo "$(BLUE)═══════════════════════════════════════$(NC)"
	@echo "$(BLUE)Verificando imagen de disco$(NC)"
	@echo "$(BLUE)═══════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Sector 0 (Stage1):$(NC)"
	@$(DD) if=$(DISK_IMG) bs=512 count=1 2>/dev/null | hexdump -C | head -5
	@echo ""
	@echo "$(YELLOW)Sector 17 (Kernel):$(NC)"
	@$(DD) if=$(DISK_IMG) bs=512 skip=17 count=1 2>/dev/null | hexdump -C | head -5

# Debug: ejecutar QEMU con GDB
.PHONY: debug
debug: $(DISK_IMG)
	@echo "$(BLUE)Iniciando QEMU en modo debug (puerto 1234)...$(NC)"
	@echo "$(YELLOW)Conecta GDB con: gdb -ex 'target remote localhost:1234'$(NC)"
	$(QEMU) $(QEMU_FLAGS) -s -S

# Matar todos los procesos QEMU
.PHONY: kill
kill:
	@pkill -9 qemu-system-x86_64 2>/dev/null || true
	@echo "$(GREEN)✓ Procesos QEMU terminados$(NC)"

# Ayuda
.PHONY: help
help:
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)Makefile - Micro OS Bootloader 64-bit$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Targets disponibles:$(NC)"
	@echo "  $(GREEN)make$(NC)              - Compilar todo el sistema"
	@echo "  $(GREEN)make run$(NC)          - Compilar y ejecutar en QEMU"
	@echo "  $(GREEN)make test$(NC)         - Alias de 'make run'"
	@echo "  $(GREEN)make clean$(NC)        - Limpiar todos los archivos compilados"
	@echo "  $(GREEN)make clean-obj$(NC)    - Limpiar solo archivos objeto"
	@echo "  $(GREEN)make info$(NC)         - Mostrar información del kernel"
	@echo "  $(GREEN)make verify$(NC)       - Verificar contenido de la imagen"
	@echo "  $(GREEN)make debug$(NC)        - Ejecutar QEMU con GDB server"
	@echo "  $(GREEN)make kill$(NC)         - Terminar procesos QEMU"
	@echo "  $(GREEN)make help$(NC)         - Mostrar esta ayuda"
	@echo ""
	@echo "$(YELLOW)Ejemplos:$(NC)"
	@echo "  make clean && make run    # Compilación limpia y ejecución"
	@echo "  make info                 # Ver tamaño del kernel"
	@echo "  make verify               # Verificar que el kernel está en disco"
	@echo ""
