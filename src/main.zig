const std = @import("std");

const zig8 = @import("zig8");
const Term = @import("term").Term();
const parseArgs = @import("./parseArgs.zig").parseArgs;

const Display = zig8.Display;

fn sleep_ms(time_ms: u64) void {
    std.Thread.sleep(time_ms * std.time.ns_per_ms);
}
fn show_display(term: *Term, display: *Display) !void {
    _ = try term.write("\x1B[H");
    try term.flush();

    for (0..Display.WIDTH + 1) |_| _ = try term.write("_"); // top border
    _ = try term.writeLn("");

    for (0..Display.HEIGHT) |row| {
        _ = try term.write("|"); // left border
        for (0..Display.WIDTH) |col| {
            const pix_val = display.pixels[Display.WIDTH * row + col];
            if (pix_val) {
                _ = try term.write("█");
            } else {
                _ = try term.write(".");
            }
        }
        _ = try term.write("|"); // right border
        _ = try term.writeLn("");
    }
    for (0..Display.WIDTH) |_| _ = try term.write("–"); // bot border
    _ = try term.writeLn("");
    _ = try term.writeLn("");
    try term.flush();
}

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
    const parsed_args = try parseArgs(areno);

    const rom_data = try std.fs.cwd().readFileAlloc(
        areno,
        parsed_args.rom_path,
        4096,
    );

    var cpu = zig8.CPU{};
    try cpu.load_RAM(rom_data);

    const cycle_freq_hz = parsed_args.cycle;
    const display_freq_hz = 60;
    const display_period_ms = std.time.ms_per_s / display_freq_hz;

    // tty gestion
    var tty = try std.fs.cwd().openFile("/dev/tty", .{
        .mode = .read_write,
    });
    defer tty.close();

    const buffer_size = Display.WIDTH * (Display.HEIGHT + 2); // length of a display-print
    var buffer: [buffer_size]u8 = undefined;
    var writer = tty.writer(&buffer);
    const stdout = &writer.interface;

    var term = Term.init(tty, stdout);
    try term.uncook(.{
        .TIME = 0, // don't wait input
        .MIN = 0, // no minima input to continue the loop
    });
    defer term.cook() catch {};

    cpu.setTargetCyclePerSecond(cycle_freq_hz);
    cpu.setTargetDisplayFreq(display_freq_hz);

    var previous_ms: i64 = 0;
    var input_buffer: [1]u8 = undefined;
    @memset(&input_buffer, 0);
    while (run.load(.unordered)) {
        const current_ms = std.time.milliTimestamp();

        // input handling
        _ = try tty.read(&input_buffer);
        defer @memset(&input_buffer, 0x0);
        if (input_buffer[0] == 'q' or (input_buffer[0] == 'c' & '\x1F')) { // q or ctrl+c
            return;
        }

        // match screen speed
        const delta_ms = current_ms - previous_ms;
        if (delta_ms > display_period_ms) {
            previous_ms = current_ms;

            try show_display(&term, &cpu.display);
            try cpu.tick();
        } else {
            sleep_ms(1);
        }
    }
}
