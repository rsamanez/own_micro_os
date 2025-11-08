# MicroKernel OS - x86_64

Un sistema operativo con arquitectura de microkernel inspirado en MINIX, diseñado para x86_64.

## 🎯 Características

- **Arquitectura**: x86-64 (64 bits)
- **Filosofía**: Microkernel (inspirado en MINIX)
- **Bootloader**: Multiboot2 compatible con GRUB
- **Modo de operación**: Long Mode (64 bits) desde el inicio

## 📁 Estructura del Proyecto

```
own_micro_os/
├── boot/           # Bootloader en Assembly
│   └── boot.asm    # Código que cambia a modo 64 bits
├── kernel/         # Código del kernel
│   └── kernel.c    # Kernel básico con salida VGA
├── build/          # Archivos compilados
├── iso/            # Directorio para la imagen ISO
├── linker.ld       # Script del linker
├── Makefile        # Sistema de compilación
├── run.sh          # Script para ejecutar en QEMU
└── README.md       # Este archivo
```

## 🚀 Compilación y Ejecución

### Requisitos

- **macOS**: 
  - `nasm` (ensamblador)
  - `gcc` (compilador C)
  - `qemu` (emulador)
  - `grub` (para crear ISO booteable)

Instalar con Homebrew:
```bash
brew install nasm qemu grub i686-elf-gcc
brew install --cask xquartz  # Necesario para GRUB
```

### Compilar

```bash
make
```

### Ejecutar en QEMU

```bash
make run
```

O usando el script:
```bash
./run.sh           # Ejecución normal
./run.sh debug     # Con debug y monitor
./run.sh serial    # Con salida serial
./run.sh gdb       # Espera conexión GDB en puerto 1234
```

### Limpiar archivos generados

```bash
make clean
```

## 🏗️ Proceso de Boot

1. **BIOS/UEFI**: Carga el bootloader desde la ISO
2. **Bootloader** (`boot.asm`):
   - Inicia en modo real (16 bits)
   - Cambia a modo protegido (32 bits)
   - Configura paginación (PAE)
   - Habilita modo largo (64 bits)
   - Salta al kernel
3. **Kernel** (`kernel.c`):
   - Inicializa VGA text mode
   - Muestra información del sistema
   - Entra en loop infinito

## 🎨 Filosofía de Microkernel

El objetivo es mantener el kernel lo más pequeño posible, siguiendo estos principios:

### En el Kernel (modo privilegiado):
- ✅ Gestión básica de memoria
- ✅ Scheduling de procesos
- ✅ IPC (Inter-Process Communication)
- ✅ Gestión de interrupciones

### En Userspace (modo usuario):
- 🔄 Drivers de dispositivos
- 🔄 Sistema de archivos
- 🔄 Servicios de red
- 🔄 Gestores de ventanas

## 📚 Próximos Pasos

### Fase 1: Fundamentos
- [x] Bootloader con cambio a modo 64 bits
- [x] Kernel básico con salida VGA
- [ ] Tabla de Descriptores de Interrupción (IDT)
- [ ] Manejo de excepciones y interrupciones

### Fase 2: Memoria
- [ ] Gestión de memoria física (PMM)
- [ ] Gestión de memoria virtual (VMM)
- [ ] Heap del kernel
- [ ] Allocator de memoria

### Fase 3: Procesos
- [ ] Estructuras de datos para procesos
- [ ] Context switching
- [ ] Scheduler básico (round-robin)
- [ ] Creación/destrucción de procesos

### Fase 4: IPC
- [ ] Mecanismo de mensajes
- [ ] Puertos de comunicación
- [ ] Shared memory

### Fase 5: Userspace
- [ ] Cambio a ring 3
- [ ] System calls
- [ ] Primeros servidores en userspace
- [ ] Driver framework

## 🔧 Debugging

Para depurar con GDB:

Terminal 1:
```bash
./run.sh gdb
```

Terminal 2:
```bash
gdb build/kernel.bin
(gdb) target remote localhost:1234
(gdb) break kernel_main
(gdb) continue
```

## 📖 Referencias

- [OSDev Wiki](https://wiki.osdev.org/)
- [MINIX Operating System](https://www.minix3.org/)
- [Intel 64 and IA-32 Architectures Software Developer Manuals](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
- [AMD64 Architecture Programmer's Manual](https://www.amd.com/en/support/tech-docs)

## 📝 Licencia

Este proyecto es de código abierto para propósitos educativos.

---

**Nota**: Este es un proyecto educativo para aprender sobre desarrollo de sistemas operativos.
