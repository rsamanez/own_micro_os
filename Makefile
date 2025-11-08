# Makefile para MicroKernel OS x86_64 - Bootloader desde cero

# Compilador y herramientas
AS = nasm
CC = x86_64-elf-gcc
LD = x86_64-elf-ld
OBJCOPY = x86_64-elf-objcopy

# Flags de compilación
ASFLAGS_BIN = -f bin
ASFLAGS_ELF = -f elf64
CFLAGS = -std=c11 -ffreestanding -O2 -Wall -Wextra -nostdlib -mcmodel=large -mno-red-zone -mno-mmx -mno-sse -mno-sse2
LDFLAGS = -n -T kernel_linker.ld -nostdlib

# Directorios
BUILD_DIR = build
BOOT_DIR = boot
KERNEL_DIR = kernel

# Archivos
BOOT_STAGE1 = $(BOOT_DIR)/boot.asm
BOOT_STAGE2 = $(BOOT_DIR)/stage2.asm
KERNEL_ENTRY = $(KERNEL_DIR)/entry.asm
KERNEL_SRC = $(KERNEL_DIR)/kernel.c

STAGE1_BIN = $(BUILD_DIR)/stage1.bin
STAGE2_BIN = $(BUILD_DIR)/stage2.bin
KERNEL_ENTRY_OBJ = $(BUILD_DIR)/entry.o
KERNEL_OBJ = $(BUILD_DIR)/kernel.o
KERNEL_BIN = $(BUILD_DIR)/kernel.bin

OS_IMG = os.img

# Target principal
all: $(OS_IMG)

# Compilar Stage 1 (bootloader MBR - 512 bytes)
$(STAGE1_BIN): $(BOOT_STAGE1)
	@mkdir -p $(BUILD_DIR)
	$(AS) $(ASFLAGS_BIN) $< -o $@
	@echo "Stage 1 bootloader compiled"

# Compilar Stage 2 (bootloader extendido)
$(STAGE2_BIN): $(BOOT_STAGE2)
	@mkdir -p $(BUILD_DIR)
	$(AS) $(ASFLAGS_BIN) $< -o $@
	@echo "Stage 2 bootloader compiled"

# Compilar punto de entrada del kernel
$(KERNEL_ENTRY_OBJ): $(KERNEL_ENTRY)
	@mkdir -p $(BUILD_DIR)
	$(AS) $(ASFLAGS_ELF) $< -o $@

# Compilar kernel
$(KERNEL_OBJ): $(KERNEL_SRC)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Linkear kernel
$(KERNEL_BIN): $(KERNEL_ENTRY_OBJ) $(KERNEL_OBJ)
	$(LD) $(LDFLAGS) $^ -o $(BUILD_DIR)/kernel.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/kernel.elf $@
	@echo "Kernel linked and converted to binary"

# Crear imagen de disco booteable
$(OS_IMG): $(STAGE1_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	@# Crear imagen de disco de 10MB
	dd if=/dev/zero of=$(OS_IMG) bs=1M count=10 2>/dev/null
	@# Escribir Stage 1 en el sector de boot (sector 0)
	dd if=$(STAGE1_BIN) of=$(OS_IMG) conv=notrunc bs=512 count=1 seek=0 2>/dev/null
	@# Escribir Stage 2 comenzando en el sector 1 (16 sectores = 8KB)
	dd if=$(STAGE2_BIN) of=$(OS_IMG) conv=notrunc bs=512 count=16 seek=1 2>/dev/null
	@# Escribir kernel comenzando en el sector 17 (después de stage1 + stage2)
	dd if=$(KERNEL_BIN) of=$(OS_IMG) conv=notrunc bs=512 seek=17 2>/dev/null
	@echo "===================================="
	@echo "OS image created: $(OS_IMG)"
	@echo "Disk layout:"
	@echo "  Sector 0:     Stage 1 (512 bytes)"
	@echo "  Sectors 1-16: Stage 2 (8KB)"
	@echo "  Sector 17+:   Kernel ($(shell stat -f%z $(KERNEL_BIN)) bytes)"
	@echo "===================================="
	@ls -lh $(OS_IMG)

# Ejecutar en QEMU
run: $(OS_IMG)
	qemu-system-x86_64 -drive format=raw,file=$(OS_IMG) -m 512M

# Ejecutar con más opciones de debug
debug: $(OS_IMG)
	qemu-system-x86_64 -drive format=raw,file=$(OS_IMG) -m 512M -d int,cpu_reset -no-reboot

# Limpiar archivos generados
clean:
	rm -rf $(BUILD_DIR) $(OS_IMG)

# Limpiar y recompilar
rebuild: clean all

# Información del proyecto
info:
	@echo "=== MicroKernel OS Build System (100% desde cero) ==="
	@echo "Targets disponibles:"
	@echo "  make         - Compila el sistema operativo"
	@echo "  make run     - Compila y ejecuta en QEMU"
	@echo "  make debug   - Ejecuta con opciones de debug"
	@echo "  make clean   - Limpia archivos generados"
	@echo "  make rebuild - Limpia y recompila"
	@echo "  make info    - Muestra esta información"
	@echo ""
	@echo "Componentes:"
	@echo "  - Stage 1: Bootloader MBR (512 bytes)"
	@echo "  - Stage 2: Modo protegido -> Modo largo"
	@echo "  - Kernel: 100% en C (64 bits)"
	@echo "  - SIN GRUB - Todo desde cero"

.PHONY: all run debug clean rebuild info
