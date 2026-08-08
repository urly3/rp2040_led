const volatileWrite = @import("std").mem.doNotOptimizeAway;

// Hardware Register Definitions
const RESETS_BASE: usize = 0x4000c000;
const RESETS_RESET: *volatile u32 = @ptrFromInt(RESETS_BASE + 0x0);
const RESETS_DONE: *volatile u32 = @ptrFromInt(RESETS_BASE + 0x8);

const SIO_BASE: usize = 0xd0000000;
const SIO_GPIO_OUT_SET: *volatile u32 = @ptrFromInt(SIO_BASE + 0x14);
const SIO_GPIO_OUT_CLR: *volatile u32 = @ptrFromInt(SIO_BASE + 0x18);
const SIO_GPIO_OE_SET: *volatile u32 = @ptrFromInt(SIO_BASE + 0x24);

const IO_BANK0_BASE: usize = 0x40014000;
const IO_BANK0_GPIO17_CTRL: *volatile u32 = @ptrFromInt(IO_BANK0_BASE + 0x8c);

const TIMER_BASE: usize = 0x40054000;

export fn _start() callconv(.c) noreturn {
    // 1. HARDWARE FIX: Take IO Bank 0 (Bit 5), PADS Bank 0 (Bit 11), AND the TIMER (Bit 21) out of reset!
    const reset_mask: u32 = (1 << 5) | (1 << 11) | (1 << 21);
    RESETS_RESET.* &= ~reset_mask;
    while ((RESETS_DONE.* & reset_mask) != reset_mask) {}

    // 2. Connect GPIO 17 to the SIO Software Matrix (Function 5)
    IO_BANK0_GPIO17_CTRL.* = 5;

    // 3. Enable output drive for the GPIO 17 LED pin
    SIO_GPIO_OE_SET.* = (1 << 17);

    // 4. Clean blink routine loop using the now-unfrozen hardware timer
    while (true) {
        // Active-LOW: Drop trace low to turn the onboard LED ON
        SIO_GPIO_OUT_CLR.* = (1 << 17);
        sleepMs(500);

        // Active-LOW: Pull trace high to turn the onboard LED OFF
        SIO_GPIO_OUT_SET.* = (1 << 17);
        sleepMs(500);
    }
}

fn sleepMs(ms: u32) void {
    const TIMER_TIMELR: *volatile u32 = @ptrFromInt(TIMER_BASE + 0x0c);
    const delay_us = ms * 1000;
    const start_time = TIMER_TIMELR.*;

    // Wrapping subtraction handles counter rolls flawlessly
    while ((TIMER_TIMELR.* -% start_time) < delay_us) {
        asm volatile ("nop");
    }
}

pub fn panic(msg: []const u8, trace: ?*@import("std").builtin.StackTrace, addr: ?usize) noreturn {
    _ = msg;
    _ = trace;
    _ = addr;
    while (true) {
        asm volatile ("nop");
    }
}
