const std = @import("std");

const test_targets = [_]std.Target.Query{
    .{}, // native
};

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zig-8",
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/main.zig"),
            .target = b.graph.host,
        }),
    });
    b.installArtifact(exe);

    // RUNNING
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the chip8 emulator");
    run_step.dependOn(&run_exe.step);

    // TESTING
    const test_step = b.step("test", "Run unit tests");
    for (test_targets) |target| {
        const unit_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("./src/main.zig"),
                .target = b.resolveTargetQuery(target),
            }),
        });

        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}
