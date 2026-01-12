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

/// Row by row, following COSMAC VIP Keypad, to left qwerty
/// [1, 2, 3, C] -> 1, 2, 3, 4
/// [4, 5, 6, D] -> q, w, e, r
/// [7, 8, 9, E] -> a, s, d, f
/// [A, 0, B, F] -> z, x, c, v
const cosmacToQwerty = .{
    .ONE = rl.KEY_ONE, // 0x1
    .TWO = rl.KEY_TWO, // 0x2
    .THREE = rl.KEY_THREE, // 0x3
    .C = rl.KEY_FOUR, // 0x4

    .FOUR = rl.KEY_Q, // 0x4
    .FIVE = rl.KEY_W, // 0x5
    .SIX = rl.KEY_E, // 0x6
    .D = rl.KEY_R, // 0xD

    .SEVEN = rl.KEY_A, // 0x7
    .EIGHT = rl.KEY_S, // 0x8
    .NINE = rl.KEY_D, // 0x9
    .E = rl.KEY_F, // 0xE

    .A = rl.KEY_Z, // 0xA
    .ZERO = rl.KEY_X, // 0x0
    .B = rl.KEY_C, // 0xB
    .F = rl.KEY_V, // 0xF
};

fn setKeys(cpu: *zig8.CPU) void {
    cpu.keypad = .{
        rl.IsKeyDown(cosmacToQwerty.ZERO),
        rl.IsKeyDown(cosmacToQwerty.ONE),
        rl.IsKeyDown(cosmacToQwerty.TWO),
        rl.IsKeyDown(cosmacToQwerty.THREE),
        rl.IsKeyDown(cosmacToQwerty.FOUR),
        rl.IsKeyDown(cosmacToQwerty.FIVE),
        rl.IsKeyDown(cosmacToQwerty.SIX),
        rl.IsKeyDown(cosmacToQwerty.SEVEN),
        rl.IsKeyDown(cosmacToQwerty.EIGHT),
        rl.IsKeyDown(cosmacToQwerty.NINE),
        rl.IsKeyDown(cosmacToQwerty.A),
        rl.IsKeyDown(cosmacToQwerty.B),
        rl.IsKeyDown(cosmacToQwerty.C),
        rl.IsKeyDown(cosmacToQwerty.D),
        rl.IsKeyDown(cosmacToQwerty.E),
        rl.IsKeyDown(cosmacToQwerty.F),
    };
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
    defer rl.CloseWindow();
    rl.SetTargetFPS(display_freq_hz);

    rl.InitAudioDevice();
    defer rl.CloseAudioDevice();

    const sound = rl.LoadSound("./assets/oneC4.wav");
    defer rl.UnloadSound(sound);

    // raylib loop
    while (!rl.WindowShouldClose() and run.load(.unordered)) {
        // input handling
        setKeys(&cpu);

        // drawing management
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.BROWN);

        // cpu
        try cpu.tick(); // raylib handles the 60 fps

        // dipslay
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

        // sound
        if (cpu.sound > 0) {
            if (!rl.IsSoundPlaying(sound)) {
                rl.PlaySound(sound);
            }
        } else {
            rl.StopSound(sound);
        }
    }

    // tui loop
    {
        // try termLoop(&cpu, &run);
    }
}
