const std = @import("std");

const zig8 = @import("zig8");
const Term = @import("term").Term();
const rl = @cImport({
    @cInclude("raylib.h");
});

const termLoop = @import("termLoop.zig").loop;

const parseArgs = @import("./parseArgs.zig").parseArgs;

const Display = zig8.Display;

var run = std.atomic.Value(bool).init(true);

fn handleSig(_: c_int) callconv(.c) void {
    run.store(false, .unordered);
}

// Signals handlers
fn setupSig() void {
    const action = std.posix.Sigaction{
        .handler = .{ .handler = handleSig },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };

    std.posix.sigaction(std.posix.SIG.INT, &action, null);
    std.posix.sigaction(std.posix.SIG.TERM, &action, null);
}

pub fn main() !void {
    setupSig();

    var debugAlloc = std.heap.DebugAllocator(.{}){};
    var ar = std.heap.ArenaAllocator.init(debugAlloc.allocator());
    defer ar.deinit();
    const areno = ar.allocator();

    var cliArgs = try parseArgs(areno);
    defer cliArgs.free();

    const rom_data = try std.fs.cwd().readFileAlloc(
        areno,
        cliArgs.rom_path,
        4096,
    );

    var cpu = zig8.CPU{};
    try cpu.load_RAM(rom_data);

    const cycle_freq_hz = cliArgs.cycle;
    const display_freq_hz = 60;
    cpu.setTargetCyclePerSecond(cycle_freq_hz);
    cpu.setTargetDisplayFreq(display_freq_hz);

    const scale = cliArgs.scale;
    rl.InitWindow(
        @as(c_int, Display.WIDTH * scale),
        @as(c_int, Display.HEIGHT * scale),
        "snoup !",
    );
    rl.SetTargetFPS(display_freq_hz);

    // raylib loop
    while (!rl.WindowShouldClose() and run.load(.unordered)) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.BROWN);

        try cpu.tick(); // raylib handles the 60 fps

        if (rl.IsKeyPressed(rl.KEY_A)) { // its qwerty -> need to press q
            std.debug.print("A pressed !", .{});
        }
        if (rl.IsKeyReleased(rl.KEY_A)) { // its qwerty -> need to press q
            std.debug.print("A released !", .{});
        }

        for (0..Display.HEIGHT) |row| {
            for (0..Display.WIDTH) |col| {
                const pix_val = cpu.display.pixels[Display.WIDTH * row + col];
                if (pix_val) {
                    rl.DrawRectangle(
                        @as(u16, @truncate(col)) * scale,
                        @as(u16, @truncate(row)) * scale,
                        scale,
                        scale,
                        rl.ORANGE,
                    );
                } else {}
            }
        }
    }

    // tui loop
    {
        // try termLoop(&cpu, &run);
    }
}
