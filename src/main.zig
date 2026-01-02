const std = @import("std");

const prog = @import("./cpu.zig");

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
    var gpallocStruct = std.heap.DebugAllocator(.{}){};
    var ar = std.heap.ArenaAllocator.init(gpallocStruct.allocator());
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

    const clock_speed = 700; // hz
    while (true) {
        try cpu.tick();
        try show_display(&cpu.display);

        std.Thread.sleep(std.time.ns_per_s / clock_speed);
    }
}
