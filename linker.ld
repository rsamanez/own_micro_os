/* Linker script para el microkernel x86_64 */

ENTRY(_start)

SECTIONS
{
    /* El kernel será cargado en 1MB */
    . = 1M;

    /* Primero el encabezado multiboot */
    .boot :
    {
        *(.multiboot)
    }

    /* Sección de texto (código) */
    .text BLOCK(4K) : ALIGN(4K)
    {
        *(.text)
    }

    /* Sección de datos de solo lectura */
    .rodata BLOCK(4K) : ALIGN(4K)
    {
        *(.rodata)
    }

    /* Sección de datos inicializados */
    .data BLOCK(4K) : ALIGN(4K)
    {
        *(.data)
    }

    /* Sección BSS (datos no inicializados) */
    .bss BLOCK(4K) : ALIGN(4K)
    {
        *(COMMON)
        *(.bss)
    }

    /* Descartar secciones innecesarias */
    /DISCARD/ :
    {
        *(.comment)
        *(.eh_frame)
        *(.note.gnu.build-id)
    }
}
