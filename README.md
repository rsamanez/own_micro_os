# MicroKernel OS - x86_64

Un sistema operativo con arquitectura de microkernel inspirado en MINIX, diseñado para x86_64 desde cero (sin GRUB).

## 🎯 Características

- **Arquitectura**: x86-64 (64 bits)
- **Filosofía**: Microkernel (inspirado en MINIX)
- **Bootloader**: 100% custom, escrito desde cero en Assembly (2 etapas)
- **Modo de operación**: Long Mode (64 bits)
- **Sin dependencias**: No usa GRUB ni ningún bootloader externo

## 📁 Estructura del Proyecto

```
own_micro_os/
├── boot/                    # Bootloader custom de 2 etapas
│   ├── boot.asm            # Stage1: MBR bootloader (512 bytes)
│   ├── stage2_sector2.asm  # Stage2: Transición a 64-bit mode
│   ├── gdt.asm             # Tabla de Descriptores Globales
│   ├── CPUID.asm           # Detección de capacidades del CPU
│   ├── SimplePaging.asm    # Configuración de paginación identidad
│   └── print.asm           # Funciones de impresión en modo real
├── kernel/                  # Código del kernel
│   ├── kernel_simple.asm   # Kernel simple en Assembly (funcional)
│   ├── kernel.c            # Kernel en C (en desarrollo)
│   └── entry.asm           # Punto de entrada del kernel
├── build/                   # Archivos compilados
├── sector2.img             # Imagen de disco booteable (10MB)
└── README.md               # Este archivo
```

## 🚀 Compilación y Ejecución

### Requisitos

- **macOS con Apple Silicon**: 
  - `nasm` (ensamblador)
  - `x86_64-elf-gcc` (cross-compiler para x86_64)
  - `qemu-system-x86_64` (emulador)

Instalar con Homebrew:
```bash
brew install nasm qemu
brew install x86_64-elf-gcc  # Cross-compiler necesario para Apple Silicon
```

### Compilar y Ejecutar

Compilación completa y ejecución:
```bash
pkill -9 qemu-system-x86_64 2>/dev/null
nasm -f bin -I boot/ boot/boot.asm -o build/boot.bin
nasm -f bin -I boot/ boot/stage2_sector2.asm -o build/stage2_sector2.bin
nasm -f bin kernel/kernel_simple.asm -o build/kernel_simple.bin

dd if=/dev/zero of=sector2.img bs=1M count=10 2>/dev/null
dd if=build/boot.bin of=sector2.img conv=notrunc 2>/dev/null
dd if=build/stage2_sector2.bin of=sector2.img bs=512 seek=1 conv=notrunc 2>/dev/null
dd if=build/kernel_simple.bin of=sector2.img bs=512 seek=17 conv=notrunc 2>/dev/null

qemu-system-x86_64 -drive format=raw,file=sector2.img
```

### Layout del Disco

La imagen `sector2.img` tiene la siguiente distribución:

| Sector(es) | Contenido | Dirección de carga | Tamaño |
|------------|-----------|-------------------|--------|
| 0 | Stage1 (MBR) | 0x7C00 | 512 bytes |
| 1-16 | Stage2 | 0x1000 | 8 KB |
| 17+ | Kernel | 0x10000 | ~2 KB |

## 🏗️ Proceso de Boot (Custom Bootloader)

### Stage 1 (boot.asm)
1. **BIOS** carga el MBR en 0x7C00
2. **Stage1** se ejecuta:
   - Limpia registros de segmento
   - Guarda el número de drive
   - Muestra "Loading Stage 2..."
   - Carga 16 sectores (Stage2) desde sector 1 a 0x1000
   - Carga 4 sectores (Kernel) desde sector 17 a 0x10000
   - Salta a Stage2 en 0x1000

### Stage 2 (stage2_sector2.asm)
3. **Stage2** se ejecuta en modo real (16-bit):
   - Habilita línea A20
   - Carga GDT (Global Descriptor Table)
   - **Entra a modo protegido (32-bit)**
   
4. En modo protegido (32-bit):
   - Detecta CPUID y Long Mode (64-bit)
   - Configura paginación identidad (0x70000)
   - Modifica GDT para modo largo
   - **Entra a modo largo (64-bit)**

5. En modo largo (64-bit):
   - Muestra "64-BIT MODE OK!" en pantalla azul
   - **Salta al kernel** en 0x10000

### Kernel (kernel_simple.asm)
6. **Kernel** se ejecuta en modo 64-bit:
   - Escribe "KERNEL OK!" directamente en VGA (0xB8000)
   - Entra en loop infinito (cli/hlt)

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

## 📚 Estado Actual y Próximos Pasos

### ✅ Completado
- [x] Bootloader custom Stage1 (MBR)
- [x] Bootloader custom Stage2 (transición a 64-bit)
- [x] Detección de CPUID y Long Mode
- [x] Configuración de GDT
- [x] Paginación identidad
- [x] Transición completa: 16-bit → 32-bit → 64-bit
- [x] Carga del kernel desde disco
- [x] Ejecución del kernel en modo 64-bit
- [x] Driver VGA básico en Assembly

### 🔄 En Progreso
- [ ] Kernel en C con driver VGA
- [ ] Tabla de Descriptores de Interrupción (IDT)
- [ ] Manejo de excepciones y interrupciones

### 📋 Próximas Fases

#### Fase 2: Memoria
- [ ] Gestión de memoria física (PMM)
- [ ] Gestión de memoria virtual (VMM)
- [ ] Heap del kernel
- [ ] Allocator de memoria

#### Fase 3: Procesos
- [ ] Estructuras de datos para procesos
- [ ] Context switching
- [ ] Scheduler básico (round-robin)
- [ ] Creación/destrucción de procesos

#### Fase 4: IPC
- [ ] Mecanismo de mensajes
- [ ] Puertos de comunicación
- [ ] Shared memory

#### Fase 5: Userspace
- [ ] Cambio a ring 3
- [ ] System calls
- [ ] Primeros servidores en userspace
- [ ] Driver framework

## � Detalles Técnicos

### Memoria Layout
```
0x00000000 - 0x000003FF : Tabla de vectores de interrupción (IVT)
0x00000400 - 0x000004FF : BIOS Data Area (BDA)
0x00000500 - 0x00007BFF : Libre (usable)
0x00007C00 - 0x00007DFF : Stage1 Bootloader (MBR)
0x00001000 - 0x00002FFF : Stage2 Bootloader (8KB)
0x00010000 - 0x0001FFFF : Kernel (cargado aquí)
0x00070000 - 0x00073FFF : Page Tables (16KB)
0x00090000 - 0x0009FFFF : Stack
0x000A0000 - 0x000FFFFF : VGA y BIOS ROM
0x000B8000             : VGA Text Mode Buffer
```

### GDT Configuration
```
Descriptor 0 (Null): 0x0000000000000000
Descriptor 1 (Code): Base=0, Limit=0xFFFFF, Flags=9A (Executable, Readable)
Descriptor 2 (Data): Base=0, Limit=0xFFFFF, Flags=92 (Writable)
```

### Paging Setup
- Usa identity paging (dirección virtual = dirección física)
- Mapea los primeros 2MB de memoria
- Page tables en 0x70000 (evita conflicto con Stage2 en 0x1000)

## 🔧 Debugging

Para ver el estado del sistema en cada etapa, el bootloader muestra mensajes:
- "Loading Stage 2..." (Stage1, modo real)
- "OK" (Stage2 cargado)
- "Kernel loaded" (Kernel cargado)
- "64-BIT MODE OK!" (Stage2, modo 64-bit)
- "KERNEL OK!" (Kernel ejecutándose)

Para debugging más profundo con QEMU:
```bash
qemu-system-x86_64 -drive format=raw,file=sector2.img -monitor stdio
```

Para ver la salida serial:
```bash
qemu-system-x86_64 -drive format=raw,file=sector2.img -serial stdio
```

## 📖 Referencias

- [OSDev Wiki](https://wiki.osdev.org/)
- [MINIX Operating System](https://www.minix3.org/)
- [Intel 64 and IA-32 Architectures Software Developer Manuals](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
- [AMD64 Architecture Programmer's Manual](https://www.amd.com/en/support/tech-docs)
- [Repositorio base usado como referencia](https://github.com/rsamanez/os-dev)

## 📝 Licencia

Este proyecto es de código abierto para propósitos educativos.

---

**Nota**: Este es un proyecto educativo para aprender sobre desarrollo de sistemas operativos desde cero, incluyendo el bootloader completo.
- [MINIX Operating System](https://www.minix3.org/)
- [Intel 64 and IA-32 Architectures Software Developer Manuals](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
- [AMD64 Architecture Programmer's Manual](https://www.amd.com/en/support/tech-docs)

## 📝 Licencia

Este proyecto es de código abierto para propósitos educativos.

---

**Nota**: Este es un proyecto educativo para aprender sobre desarrollo de sistemas operativos.
