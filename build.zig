const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const zig8 = b.addModule("zig8", .{
        .root_source_file = b.path("./src/lib/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zig-8",
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/main.zig"),
            .target = b.graph.host,
            .imports = &.{
                .{
                    .name = "zig8",
                    .module = zig8,
                },
            },
        }),
    });
    b.installArtifact(exe);

    // RUNNING
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the chip8 emulator");

    {
        // I like this but the next option is cleaner
        // Ex: zig build run -DROM_Path=./ROMs...
        // const rom_path = b.option(
        //     []const u8,
        //     "ROM_Path",
        //     "Relative path to your rom",
        // );
        // if (rom_path) |path| {
        //     run_exe.addArg(path);
        //     run_step.dependOn(&run_exe.step);
        // } else {
        //     run_step.dependOn(
        //         &b.addFail("The -DROM_Path=... option is required for the run step").step,
        //     );
        // }

        // Ex: zig build -- ./ROMs/...
        if (b.args) |args| {
            run_exe.addArgs(args);
        }
        run_step.dependOn(&run_exe.step);
    }

    // TESTING
    const test_step = b.step("test", "Run unit tests");
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/main.zig"),
            .target = target,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}
