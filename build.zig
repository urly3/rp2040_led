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

    const run_packer = b.addSystemCommand(&.{ "python", "make_uf2.py" });

    run_packer.step.dependOn(&install_bin.step);

    b.getInstallStep().dependOn(&run_packer.step);
}
