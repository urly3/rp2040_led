const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .abi = .eabi,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0plus },
    });

    const exe = b.addExecutable(.{
        .name = "blink",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = .ReleaseSmall,
            .strip = true,
        }),
    });

    exe.entry = .{ .symbol_name = "_start" };
    exe.setLinkerScript(b.path("linker.ld"));

    const bin_conversion = exe.addObjCopy(.{ .format = .bin });
    const install_bin = b.addInstallFile(bin_conversion.getOutput(), "blink.bin");

    const uf2_step = b.step("make_uf2", "");
    uf2_step.makeFn = &uf2_make_fn;

    uf2_step.dependOn(&install_bin.step);

    b.getInstallStep().dependOn(uf2_step);
}

fn uf2_make_fn(step: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
    _ = options;
    make_uf2(step.owner.allocator, step.owner.graph.io, step.owner.install_path) catch {};
}

fn make_uf2(
    allocator: std.mem.Allocator,
    io: std.Io,
    output_path: []const u8,
) !void {
    const base_addr = 0x20000000;

    const HeaderBlock = packed struct {
        m_start_0: u32 = 0x0a324655,
        m_start_1: u32 = 0x9e5d5157,
        flags: u32 = 0x00002000,
        addr: u32,
        size: u32 = 256,
        block_no: u32,
        num_blocks: u32,
        family: u32 = 0xe48bff56,
    };

    const zig_out = try std.Io.Dir.openDirAbsolute(io, output_path, .{});
    defer zig_out.close(io);

    const bin_file = try zig_out.openFile(io, "blink.bin", .{ .mode = .read_only });
    var bin_reader = bin_file.reader(io, &.{});
    var bin_data = try bin_reader.interface.allocRemaining(allocator, .unlimited);

    const old_len = bin_data.len;
    if (old_len % 256 != 0) {
        bin_data = try allocator.realloc(bin_data, bin_data.len + (256 - (bin_data.len % 256)));
        @memset(bin_data[old_len..], 0);
    }

    const out_file = try zig_out.createFile(io, "blink.uf2", .{});
    defer out_file.close(io);

    var writer_buf: [512]u8 = @splat(0);
    var writer = out_file.writer(io, &writer_buf);

    const num_blocks: u32 = @intCast(bin_data.len / 256);
    var window_iter = std.mem.window(u8, bin_data, 256, 256);
    var idx: u32 = 0;
    while (window_iter.next()) |chunk| : (idx += 1) {
        const header: HeaderBlock = .{
            .addr = base_addr + (idx * 256),
            .block_no = idx,
            .num_blocks = num_blocks,
        };

        try writer.interface.writeStruct(header, .little);
        try writer.interface.writeAll(chunk);
        try writer.interface.splatByteAll(0, 220);
        try writer.interface.writeInt(u32, 0x0ab16f30, .little);
        try writer.flush();
    }
}
