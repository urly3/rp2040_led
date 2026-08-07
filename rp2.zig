const volatileWrite = @import("std").mem.doNotOptimizeAway;

// Memory Mapped Registers
const RESETS_RESET: *volatile u32 = @ptrFromInt(0x4000c000 + 0x0);
const RESETS_DONE: *volatile u32 = @ptrFromInt(0x4000c000 + 0x8);
const SIO_GPIO_OUT_SET: *volatile u32 = @ptrFromInt(0xd0000000 + 0x14);
const SIO_GPIO_OUT_CLR: *volatile u32 = @ptrFromInt(0xd0000000 + 0x18);
const SIO_GPIO_OE_SET: *volatile u32 = @ptrFromInt(0xd0000000 + 0x24);
const IO_BANK0_GPIO17_CTRL: *volatile u32 = @ptrFromInt(0x40014000 + 0x88 + 4);

export fn main() callconv(.c) noreturn {
    // 1. Reset IO peripherals
    RESETS_RESET.* &= ~(@as(u32, (1 << 5) | (1 << 11)));
    while ((RESETS_DONE.* & ((1 << 5) | (1 << 11))) == 0) {}

    // 2. Route GPIO 17 to SIO and enable output
    IO_BANK0_GPIO17_CTRL.* = 5;
    SIO_GPIO_OE_SET.* = (1 << 17);

    // 3. Simple high/low pulse toggle
    while (true) {
        SIO_GPIO_OUT_SET.* = (1 << 17);
        delayLoops(300000);
        SIO_GPIO_OUT_CLR.* = (1 << 17);
        delayLoops(300000);
    }
}

fn delayLoops(iterations: u32) void {
    var i = iterations;
    while (i > 0) : (i -= 1) {
        asm volatile ("nop");
    }
}

pub fn panic(msg: []const u8, error_return_trace: ?*@import("std").builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = error_return_trace;
    _ = ret_addr;
    while (true) {
        asm volatile ("nop");
    }
}

const VectorTable = extern struct {
    initial_stack_pointer: *anyopaque,
    reset_handler: *const fn () callconv(.c) noreturn,
};

export const vector_table linksection(".vectors") = VectorTable{
    .initial_stack_pointer = @ptrFromInt(0x20041000), // Top of SRAM Bank 5
    .reset_handler = &main,
};
