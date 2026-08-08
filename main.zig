const volatileWrite = @import("std").mem.doNotOptimizeAway;

// Memory Mapped Registers Base Definitions
const RESETS_BASE: usize = 0x4000c000;
const RESETS_RESET: *volatile u32 = @ptrFromInt(RESETS_BASE + 0x0);
const RESETS_DONE: *volatile u32 = @ptrFromInt(RESETS_BASE + 0x8);

const SIO_BASE: usize = 0xd0000000;
const SIO_GPIO_OUT_SET: *volatile u32 = @ptrFromInt(SIO_BASE + 0x14);
const SIO_GPIO_OUT_CLR: *volatile u32 = @ptrFromInt(SIO_BASE + 0x18);
const SIO_GPIO_OE_SET: *volatile u32 = @ptrFromInt(SIO_BASE + 0x24);
const SIO_GPIO_IN: *volatile u32 = @ptrFromInt(SIO_BASE + 0x28); // Real-time Pin State Vector

const IO_BANK0_BASE: usize = 0x40014000;
const IO_BANK0_GPIO17_CTRL: *volatile u32 = @ptrFromInt(IO_BANK0_BASE + 0x8c); // LED Pin Control
const IO_BANK0_GPIO0_CTRL: *volatile u32 = @ptrFromInt(IO_BANK0_BASE + 0x04); // FIX: GPIO 0 Control

const PADS_BANK0_BASE: usize = 0x4001c000;
const PADS_BANK0_GPIO0: *volatile u32 = @ptrFromInt(PADS_BANK0_BASE + 0x04); // FIX: GPIO 0 Pad Configuration

const TIMER_BASE: usize = 0x40054000;
const TIMER_TIMELR: *volatile u32 = @ptrFromInt(TIMER_BASE + 0x0c); // Raw running uS counter register

export fn _start() callconv(.c) noreturn {
    // 1. Unfreeze IO Bank 0 (Bit 5), PADS Bank 0 (Bit 11), and Hardware TIMER (Bit 21) from reset
    const reset_mask: u32 = (1 << 5) | (1 << 11) | (1 << 21);
    RESETS_RESET.* &= ~reset_mask;
    while ((RESETS_DONE.* & reset_mask) != reset_mask) {}

    // 2. Connect GPIO 17 (LED) and GPIO 0 (Jumper Line) to SIO matrix (Function 5)
    IO_BANK0_GPIO17_CTRL.* = 5;
    IO_BANK0_GPIO0_CTRL.* = 5;

    // 3. Configure physical pad attributes for GPIO 0
    // Bit 3 = Pull-up enable (PUE), Bit 2 = Pull-down disable (PDE), Bit 6 = Input Enable (IE)
    PADS_BANK0_GPIO0.* = (1 << 3) | (1 << 6);

    // 4. Enable hardware output drive onto the LED trace
    SIO_GPIO_OE_SET.* = (1 << 17);

    // Dynamic Tracking Configuration State Machine
    var blink_interval_us: u32 = 500_000; // Baseline: 500ms (500,000 uS)
    var target_time = TIMER_TIMELR.* +% blink_interval_us;
    var led_state: bool = false;
    var wire_was_grounded: bool = false;

    // 5. Asynchronous High-Speed Processing Polling Loop
    while (true) {
        // Read input state vector and mask specifically for Bit 0 (GPIO 0)
        // When your jumper touches a GND pin, Bit 0 drops instantly to a logic 0.
        const wire_is_grounded = (SIO_GPIO_IN.* & (1 << 0)) == 0;

        if (wire_is_grounded and !wire_was_grounded) {
            // Edge Transition Detected! Toggle between 500ms (Slow) and 100ms (Fast)
            blink_interval_us = if (blink_interval_us == 500_000) 100_000 else 500_000;
            wire_was_grounded = true;

            // Recalculate target slice boundaries instantly to remove toggle switching latency
            target_time = TIMER_TIMELR.* +% blink_interval_us;
        } else if (!wire_is_grounded) {
            // Unlatch edge tracking the moment the jumper wire breaks contact with GND
            wire_was_grounded = false;
        }

        // NON-BLOCKING CLOCK POLICING MAP:
        const current_time = TIMER_TIMELR.*;
        if ((current_time -% target_time) < 0x80000000) {
            // Interval threshold breached! Flip electrical logic drives
            if (led_state) {
                SIO_GPIO_OUT_SET.* = (1 << 17); // Drive track high -> LED OFF (Active-LOW)
                led_state = false;
            } else {
                SIO_GPIO_OUT_CLR.* = (1 << 17); // Sink track low -> LED ON (Active-LOW)
                led_state = true;
            }
            // Commit exact microsecond index checkpoint target for the upcoming cycle pass
            target_time = current_time +% blink_interval_us;
        }
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
