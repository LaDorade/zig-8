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

var PROGRAM_NAME: []const u8 = undefined;
const USAGE_FMT =
    \\
    \\Usage: {s} ROM_PATH [--cycle=freq]
    \\
    \\Arguments:
    \\  ROM_PATH    relative or absolute path to the ROM you want to play
    \\
    \\Options:
    \\  --cycle=freq number of instruction processed each second by the cpu
    \\      Defaults to 700
    \\
;

fn display_usage() noreturn {
    std.log.info(USAGE_FMT, .{PROGRAM_NAME});
    std.process.exit(0);
}

const CLIArgs = struct {
    rom_path: []const u8 = undefined,
    cycle: u32 = 700,
};

fn parseArgs(args: []const [:0]const u8) CLIArgs {
    var cliArgs = CLIArgs{};
    PROGRAM_NAME = std.fs.path.basename(args[0]);

    if (args.len < 2) {
        std.log.err("Missing ROM_PATH arg", .{});
        display_usage();
    }

    cliArgs.rom_path = args[1];
    var index: usize = 2;
    while (index < args.len) {
        if (std.mem.startsWith(u8, args[index], "--cycle")) {
            var cycleIter = std.mem.splitAny(u8, args[index], "=");

            _ = cycleIter.next() orelse unreachable;
            const cycleVal = cycleIter.next() orelse {
                std.log.err("Not enough arguments for cycle frequency", .{});
                display_usage();
            };

            const cycleValInt = std.fmt.parseInt(u32, cycleVal, 10) catch {
                std.log.err("Invalid number \"{s}\" for cycle frequency", .{cycleVal});
                display_usage();
            };
            cliArgs.cycle = cycleValInt;
        }
        index += index;
    }
    return cliArgs;
}

pub fn main() !void {
    var debugAlloc = std.heap.DebugAllocator(.{}){};
    var ar = std.heap.ArenaAllocator.init(debugAlloc.allocator());
    defer ar.deinit();

    const areno = ar.allocator();

    const args = try std.process.argsAlloc(areno);
    defer std.process.argsFree(areno, args);

    const parsed_args = parseArgs(args);

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
