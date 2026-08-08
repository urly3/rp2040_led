const volatileWrite = @import("std").mem.doNotOptimizeAway;

const ResetsRegs = packed struct(u32) {
    g0: u1,
    g1: u1,
    g2: u1,
    g3: u1,
    g4: u1,
    io_bank0: u1,
    g6: u1,
    g7: u1,
    g8: u1,
    g9: u1,
    g10: u1,
    pads_bank0: u1,
    g12: u1,
    g13: u1,
    g14: u1,
    g15: u1,
    g16: u1,
    g17: u1,
    g18: u1,
    g19: u1,
    g20: u1,
    timer: u1,
    g22: u1,
    g23: u1,
    g24: u1,
    g25: u1,
    g26: u1,
    g27: u1,
    g28: u1,
    g29: u1,
    g30: u1,
    g31: u1,
};

const GpioCtrlReg = packed struct(u32) {
    funcsel: u5,
    reserved1: u3,
    outover: u2,
    reserved2: u2,
    oeover: u2,
    reserved3: u2,
    inover: u2,
    reserved4: u14,
};

const PadsQspiSsReg = packed struct(u32) {
    reserved1: u1,
    slewfast: u1,
    reserved2: u2,
    pue: u1,
    pde: u1,
    drive: u2,
    ie: u1,
    od: u1,
    reserved3: u22,
};

const SioRegs = extern struct {
    cpuid: u32, // 0x000
    gpio_in: u32, // 0x004
    gpio_hi_in: u32, // 0x008
    reserved1: u32, // 0x00c
    gpio_out: u32, // 0x010
    gpio_out_set: u32, // 0x014
    gpio_out_clr: u32, // 0x018
    gpio_out_xor: u32, // 0x01c
    gpio_oe: u32, // 0x020
    gpio_oe_set: u32, // 0x024
    gpio_oe_clr: u32, // 0x028
    gpio_oe_xor: u32, // 0x02c
    gpio_hi_out: u32, // 0x030
    gpio_hi_out_set: u32, // 0x034
    gpio_hi_out_clr: u32, // 0x038
    gpio_hi_out_xor: u32, // 0x03c
    gpio_hi_oe: u32, // 0x040
    gpio_hi_oe_set: u32, // 0x044
    gpio_hi_oe_clr: u32, // 0x048
    gpio_hi_oe_xor: u32, // 0x04c
};

const TimerRegs = extern struct {
    timehw: u32,
    timelw: u32,
    timehr: u32,
    timelr: u32,
};

export fn _start() callconv(.c) noreturn {
    const resets_reset: *volatile ResetsRegs = @ptrFromInt(0x4000c000);
    const resets_done: *volatile ResetsRegs = @ptrFromInt(0x4000c008);
    const sio: *volatile SioRegs = @ptrFromInt(0xd0000000);
    const io_bank0_gpio17_ctrl: *volatile GpioCtrlReg = @ptrFromInt(0x4001408c);
    const qspi_ss_ctrl: *volatile GpioCtrlReg = @ptrFromInt(0x4001800c);
    const pads_qspi_ss: *volatile PadsQspiSsReg = @ptrFromInt(0x40020008);
    const timer: *volatile TimerRegs = @ptrFromInt(0x40054000);

    resets_reset.io_bank0 = 0;
    resets_reset.pads_bank0 = 0;
    resets_reset.timer = 0;
    while (resets_done.io_bank0 == 0 or resets_done.pads_bank0 == 0 or resets_done.timer == 0) {}

    io_bank0_gpio17_ctrl.funcsel = 5;
    sio.gpio_oe_set = (1 << 17);

    var blink_interval_us: u32 = 500_000;
    var target_time = timer.timelr +% blink_interval_us;
    var was_pressed: bool = false;

    pads_qspi_ss.pue = 1;
    qspi_ss_ctrl.oeover = 2;

    while (true) {
        const is_pressed = (sio.gpio_hi_in & (1 << 1)) == 0;

        if (is_pressed and !was_pressed) {
            blink_interval_us ^= 403_328;
            was_pressed = true;
            target_time = timer.timelr +% blink_interval_us;
        } else if (!is_pressed) {
            was_pressed = false;
        }

        const current_time = timer.timelr;
        if ((current_time -% target_time) < 0x80000000) {
            sio.gpio_out_xor = 1 << 17;
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
