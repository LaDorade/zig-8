const std = @import("std");

const prog = @import("./cpu.zig");

fn sleep_ms(time_ms: u64) void {
    std.Thread.sleep(time_ms * std.time.ns_per_ms);
}

fn show_display(display: *prog.Display) !void {
    const stdout = std.fs.File.stdout();

    for (0..prog.Display.HEIGHT) |row| {
        for (0..prog.Display.WIDTH) |col| {
            const pix_val = display.pixels[prog.Display.WIDTH * row + col];
            if (pix_val) {
                _ = try stdout.write("█");
            } else {
                _ = try stdout.write(".");
            }
        }
        _ = try stdout.write("\n");
    }
    _ = try stdout.writeAll("\n\n");
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

    var cpu = prog.cpu;
    try cpu.load_RAM(rom_data);

    // TODO: make variable
    const clock_freq_hz = 700;
    const display_freq_hz = 60;
    const display_period_ms = std.time.ms_per_s / display_freq_hz;

    var previous_ms: i64 = 0;
    while (true) {
        const current_ms = std.time.milliTimestamp();

        // match screen speed
        const delta_ms = current_ms - previous_ms;
        if (delta_ms > display_period_ms) {
            previous_ms = current_ms;

            try show_display(&cpu.display);
            // TODO: update timers

            // number of cpu tick per screen tick
            for (0..(clock_freq_hz / display_freq_hz)) |_| {
                try cpu.tick();
            }
        } else {
            sleep_ms(1);
        }
    }
}
