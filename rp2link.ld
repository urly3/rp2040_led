MEMORY
{
    SRAM4 (rwx) : ORIGIN = 0x20040000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        KEEP(*(.vectors))
        *(.text*)
        *(.rodata*)
    } > SRAM4

    /DISCARD/ : {
        *(.ARM.exidx*)
        *(.ARM.extab*)
    }
}

