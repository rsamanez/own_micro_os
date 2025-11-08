/* Linker script para el kernel en modo 64-bit */

ENTRY(kernel_entry)

SECTIONS
{
    /* El kernel se carga en 0x10000 */
    . = 0x10000;

    /* Sección de entrada del kernel (entry.asm) */
    .text.entry : {
        *(.text.entry)
    }

    /* Código del kernel */
    .text : {
        *(.text)
    }

    /* Datos de solo lectura */
    .rodata : {
        *(.rodata)
    }

    /* Datos inicializados */
    .data : {
        *(.data)
    }

    /* Datos no inicializados (BSS) */
    .bss : {
        *(COMMON)
        *(.bss)
    }
}
