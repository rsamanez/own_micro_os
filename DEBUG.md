# DEBUG.md - Guía de depuración del bootloader

## Problemas comunes y soluciones

### 1. Loop infinito después de "Loading kernel..."

**Causa**: Triple fault durante la transición a modo protegido/largo

**Soluciones**:
- Verificar que las direcciones GDT sean absolutas
- Verificar que el kernel esté cargado en la dirección correcta
- Verificar que la paginación esté configurada correctamente

### 2. Verificar carga del disco

```bash
# Verificar layout del disco
hexdump -C os.img | head -n 50

# Verificar que Stage 1 esté en sector 0
dd if=os.img of=/tmp/stage1_check.bin bs=512 count=1 skip=0 2>/dev/null
hexdump -C /tmp/stage1_check.bin | head

# Verificar que Stage 2 esté en sectores 1-16
dd if=os.img of=/tmp/stage2_check.bin bs=512 count=16 skip=1 2>/dev/null
xxd /tmp/stage2_check.bin | head

# Verificar que kernel esté en sector 17+
dd if=os.img of=/tmp/kernel_check.bin bs=512 count=20 skip=17 2>/dev/null
file /tmp/kernel_check.bin
```

### 3. Ejecutar con debug en QEMU

```bash
# Ver interrupciones y resets de CPU
qemu-system-x86_64 -drive format=raw,file=os.img -m 512M -d int,cpu_reset -no-reboot

# Con monitor para inspeccionar registros
qemu-system-x86_64 -drive format=raw,file=os.img -m 512M -monitor stdio

# Comandos útiles en monitor:
# info registers - ver registros
# x /10i $eip - ver instrucciones en EIP
# x /20xb 0x7c00 - ver memoria en 0x7c00
```

### 4. Depurar con GDB

Terminal 1:
```bash
qemu-system-x86_64 -drive format=raw,file=os.img -m 512M -s -S
```

Terminal 2:
```bash
gdb
(gdb) target remote localhost:1234
(gdb) set architecture i8086
(gdb) break *0x7c00
(gdb) continue
(gdb) x/10i $pc
(gdb) stepi
```

### 5. Pruebas incrementales

```bash
# Probar solo Stage 1 + Stage 2 simple
make clean
nasm -f bin boot/stage2_simple.asm -o build/stage2_test.bin
dd if=/dev/zero of=test.img bs=1M count=1 2>/dev/null
dd if=build/stage1.bin of=test.img conv=notrunc bs=512 count=1 seek=0 2>/dev/null
dd if=build/stage2_test.bin of=test.img conv=notrunc bs=512 count=16 seek=1 2>/dev/null
qemu-system-x86_64 -drive format=raw,file=test.img -m 128M
```

## Mensajes esperados

### Arranque exitoso:
```
Loading Stage 2...
OK
Stage 2 loaded
A20 enabled
Loading kernel...
Kernel loaded
Switching to 32-bit mode...
32-bit Protected Mode
64-bit Long Mode
[Kernel arranca y muestra mensajes en colores]
```

### Si falla en "Loading kernel...":
- Error de lectura de disco
- Verificar BOOT_DRIVE
- Verificar número de sectores

### Si reinicia después de "Loading kernel..." o "Switching to 32-bit mode...":
- Triple fault en transición a modo protegido
- GDT mal configurado
- Far jump con dirección incorrecta

### Si falla en "32-bit Protected Mode":
- Problema en transición a modo largo
- CPUID no soportado
- Modo largo no disponible
- Paginación mal configurada
