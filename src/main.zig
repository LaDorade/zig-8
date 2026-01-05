const std = @import("std");
const zig8 = @import("zig8");

const Display = zig8.Display;

fn sleep_ms(time_ms: u64) void {
    std.Thread.sleep(time_ms * std.time.ns_per_ms);
}

const buffer_size = Display.WIDTH * (Display.HEIGHT + 2);
var buffer: [buffer_size]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&buffer);
const stdout = &stdout_writer.interface;
fn show_display(display: *Display) !void {
    try stdout.flush();

    for (0..Display.WIDTH + 1) |_| _ = try stdout.write("_"); // top border
    _ = try stdout.write("\n");

    for (0..Display.HEIGHT) |row| {
        _ = try stdout.write("|"); // left border
        for (0..Display.WIDTH) |col| {
            const pix_val = display.pixels[Display.WIDTH * row + col];
            if (pix_val) {
                _ = try stdout.write("█");
            } else {
                _ = try stdout.write(".");
            }
        }
        _ = try stdout.write("|"); // right border
        _ = try stdout.write("\n");
    }
    for (0..Display.WIDTH) |_| _ = try stdout.write("–"); // bot border
    _ = try stdout.write("\n");

    _ = try stdout.write("\n\n");
    try stdout.flush();
}

pub fn main() !void {
    var debugAlloc = std.heap.DebugAllocator(.{}){};
    var ar = std.heap.ArenaAllocator.init(debugAlloc.allocator());
    defer ar.deinit();

    const areno = ar.allocator();

    const args = try std.process.argsAlloc(areno);
    defer std.process.argsFree(areno, args);

    if (args.len != 2) {
        std.log.err("Must provide a ROM path", .{});
        return;
    }

    const file_path = args[1];
    const rom_data = try std.fs.cwd().readFileAlloc(
        areno,
        file_path,
        4096,
    );

    var cpu = zig8.CPU{};
    try cpu.load_RAM(rom_data);

    const cycle_freq_hz = 700;
    const display_freq_hz = 60;
    const display_period_ms = std.time.ms_per_s / display_freq_hz;

    cpu.setTargetCyclePerSecond(cycle_freq_hz);
    cpu.setTargetDisplayFreq(display_freq_hz);
    var previous_ms: i64 = 0;
    while (true) {
        const current_ms = std.time.milliTimestamp();

        // match screen speed
        const delta_ms = current_ms - previous_ms;
        if (delta_ms > display_period_ms) {
            previous_ms = current_ms;

            try show_display(&cpu.display);
            try cpu.tick();
        } else {
            sleep_ms(1);
        }
    }
}
