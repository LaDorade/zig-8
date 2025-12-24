const std = @import("std");

const prog = @import("./cpu.zig");

fn show_display(display: *prog.display.Display) !void {
    const stdout = std.fs.File.stdout();

    for (0..prog.display.DISPLAY_HEIGHT) |row| {
        for (0..prog.display.DISPLAY_WIDTH) |col| {
            const pix_val = display.pixels[prog.display.DISPLAY_WIDTH * row + col];
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
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len != 2) {
        std.log.err("Must provide a ROM path", .{});
        return;
    }

    const file_path = args[1];
    const rom_data = try std.fs.cwd().readFileAlloc(gpa, file_path, 4096);
    defer gpa.free(rom_data);

    var cpu = prog.cpu;
    try cpu.load_RAM(rom_data);

    while (true) {
        try cpu.tick();
        try show_display(&cpu.display);
    }
}
