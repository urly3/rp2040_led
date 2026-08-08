MEMORY
{
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 264K
}

SECTIONS
{
    /* Keep everything tightly bound sequentially from the base RAM address */
    .text : {
        *(.text*)
        *(.rodata*)
    } > RAM

    /* Force the compiler to discard all extra diagnostic layout info */
    /DISCARD/ : {
        *(.ARM.exidx*)
        *(.ARM.extab*)
        *(.comment)
        *(.note*)
    }
}
