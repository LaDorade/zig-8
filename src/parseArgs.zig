const std = @import("std");

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

pub fn parseArgs(args: []const [:0]const u8) CLIArgs {
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
