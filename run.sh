#!/bin/bash

# Script para ejecutar el MicroKernel OS en QEMU (100% desde cero - sin GRUB)

echo "=== MicroKernel OS - QEMU Launcher ==="
echo ""

# Verificar si existe la imagen
if [ ! -f "os.img" ]; then
    echo "Imagen de disco no encontrada. Compilando..."
    make
    if [ $? -ne 0 ]; then
        echo "Error: Falló la compilación"
        exit 1
    fi
fi

# Opciones de QEMU
QEMU_CMD="qemu-system-x86_64"
IMG_FILE="os.img"
MEMORY="512M"

# Verificar si QEMU está instalado
if ! command -v $QEMU_CMD &> /dev/null; then
    echo "Error: QEMU no está instalado"
    echo "Instala con: brew install qemu"
    exit 1
fi

# Parsear argumentos
case "$1" in
    "debug")
        echo "Ejecutando en modo debug..."
        $QEMU_CMD -drive format=raw,file=$IMG_FILE -m $MEMORY -d int,cpu_reset -no-reboot -monitor stdio
        ;;
    "serial")
        echo "Ejecutando con salida serial..."
        $QEMU_CMD -drive format=raw,file=$IMG_FILE -m $MEMORY -serial stdio
        ;;
    "gdb")
        echo "Ejecutando con soporte para GDB (puerto 1234)..."
        $QEMU_CMD -drive format=raw,file=$IMG_FILE -m $MEMORY -s -S
        ;;
    *)
        echo "Ejecutando MicroKernel OS (bootloader desde cero)..."
        $QEMU_CMD -drive format=raw,file=$IMG_FILE -m $MEMORY
        ;;
esac
