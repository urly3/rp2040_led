// Force volatile memory access using builtins
const volatileWrite = @import("std").mem.doNotOptimizeAway;

// Memory Mapped Registers from RP2040 Datasheet
const RESETS_RESET: *volatile u32 = @ptrFromInt(0x4000c000 + 0x0);
const RESETS_DONE: *volatile u32 = @ptrFromInt(0x4000c000 + 0x8);

const SIO_GPIO_OUT_SET: *volatile u32 = @ptrFromInt(0xd0000000 + 0x14);
const SIO_GPIO_OUT_CLR: *volatile u32 = @ptrFromInt(0xd0000000 + 0x18);
const SIO_GPIO_OE_SET: *volatile u32 = @ptrFromInt(0xd0000000 + 0x24);

// GPIO 17 control register address: 0x40014000 + (17 * 8) = 0x40014088
const IO_BANK0_GPIO17_CTRL: *volatile u32 = @ptrFromInt(0x40014000 + 0x88);

export fn _start() callconv(.c) noreturn {
    // 1. Take IO Bank 0 and PADS Bank 0 out of reset
    // Bit 5 = IO_BANK0, Bit 11 = PADS_BANK0
    RESETS_RESET.* &= ~(@as(u32, (1 << 5) | (1 << 11)));

    // Wait until peripherals are ready
    while ((RESETS_DONE.* & ((1 << 5) | (1 << 11))) == 0) {}

    // 2. Set GPIO 17 function code to 5 (SIO Software IO)
    IO_BANK0_GPIO17_CTRL.* = 5;

    // 3. Enable output drive for GPIO 17
    SIO_GPIO_OE_SET.* = (1 << 17);

    // 4. Infinite Loop
    while (true) {
        // LED On
        SIO_GPIO_OUT_SET.* = (1 << 17);
        delay(500000);

        // LED Off
        SIO_GPIO_OUT_CLR.* = (1 << 17);
        delay(500000);
    }
}

fn delay(cycles: u32) void {
    var i: u32 = 0;
    while (i < cycles) : (i += 1) {
        asm volatile ("nop");
    }
}

// Vector Table configuration
const VectorTable = extern struct {
    initial_stack_pointer: *anyopaque,
    reset_handler: *const fn () callconv(.c) noreturn,
};

export const vector_table linksection(".vectors") = VectorTable{
    .initial_stack_pointer = @ptrFromInt(0x20040000), // Top of RAM
    .reset_handler = &_start,
};

// Custom Panic Handler required for -O ReleaseSmall
pub fn panic(msg: []const u8, error_return_trace: ?*@import("std").builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = error_return_trace;
    _ = ret_addr;
    while (true) {
        asm volatile ("nop");
    }
}
