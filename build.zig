const std = @import("std");
const Scanner = @import("wayland").Scanner;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const scanner = Scanner.create(b, .{});
    const wayland = b.createModule(.{ .root_source_file = scanner.result });

    scanner.addCustomProtocol(b.path("./protocols/input-method-unstable-v2.xml"));
    scanner.addCustomProtocol(b.path("./protocols/text-input-unstable-v3.xml"));

    scanner.generate("wl_seat", 1);
    scanner.generate("zwp_input_method_manager_v2", 1);
    scanner.generate("zwp_text_input_manager_v3", 1);

    const exe = b.addExecutable(.{
        .name = "zig_wayland_testbed",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.linkLibC();
    exe.root_module.addImport("wayland", wayland);
    exe.linkSystemLibrary("wayland-client");

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the program");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
