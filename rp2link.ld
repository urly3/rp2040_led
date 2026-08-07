MEMORY
{
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 264K
}

SECTIONS
{
    .text : {
        KEEP(*(.vectors))   /* Place vector table at absolute start */
        *(.text*)           /* Program code execution statements */
        *(.rodata*)         /* Constants, strings, and read-only vars */
    } > RAM

    /* ARM stack unwinding and exception tracking tables */
    .ARM.extab : { *(.ARM.extab* .gnu.linkonce.armextab.*) } > RAM
    .ARM.exidx : { *(.ARM.exidx* .gnu.linkonce.armexidx.*) } > RAM

    /* Handle standard uninitialised global data areas */
    .data : { *(.data*) } > RAM
    .bss  : { *(.bss*)  } > RAM
}
