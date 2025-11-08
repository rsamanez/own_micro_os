/* Linker script para el kernel x86_64 (sin Multiboot) */

ENTRY(kernel_entry)

SECTIONS
{
    /* El kernel será cargado en 0x10000 (64KB) */
    . = 0x10000;

    .text : ALIGN(4K)
    {
        *(.text.entry)
        *(.text)
    }

    .rodata : ALIGN(4K)
    {
        *(.rodata)
    }

    .data : ALIGN(4K)
    {
        *(.data)
    }

    .bss : ALIGN(4K)
    {
        *(COMMON)
        *(.bss)
    }

    /DISCARD/ :
    {
        *(.comment)
        *(.eh_frame)
        *(.note.gnu.build-id)
    }
}
