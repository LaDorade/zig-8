const std = @import("std");

var PROGRAM_NAME: []const u8 = undefined;
const USAGE_FMT =
    \\
    \\Usage: {s} ROM_PATH [--cycle=freq] [--scale=scale]
    \\
    \\Arguments:
    \\  ROM_PATH    relative or absolute path to the ROM you want to play
    \\
    \\Options:
    \\  --cycle=freq number of instruction processed each second by the cpu
    \\      Defaults to 700
    \\  --scale=scale scale multiplicator for pixels
    \\      Default to 10
    \\
;

fn display_usage() noreturn {
    std.log.info(USAGE_FMT, .{PROGRAM_NAME});
    std.process.exit(0);
}

const CLIArgs = struct {
    allocator: std.mem.Allocator,
    rom_path: []u8 = undefined,
    cycle: u32 = 700,
    scale: u16 = 10,

    const Self = @This();
    pub fn free(self: *Self) void {
        self.allocator.free(self.rom_path);
    }
};

/// Alloc the rom_path on the heap
pub fn parseArgs(allocator: std.mem.Allocator) !CLIArgs {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var cliArgs = CLIArgs{
        .allocator = allocator,
    };
    PROGRAM_NAME = std.fs.path.basename(args[0]);

    if (args.len < 2) {
        std.log.err("Missing ROM_PATH arg", .{});
        display_usage();
    }

    cliArgs.rom_path = try allocator.alloc(u8, args[1].len);
    @memcpy(cliArgs.rom_path, args[1]);
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
        } else if (std.mem.startsWith(u8, args[index], "--scale")) {
            var scaleIter = std.mem.splitAny(u8, args[index], "=");

            _ = scaleIter.next() orelse unreachable;
            const scaleVal = scaleIter.next() orelse {
                std.log.err("Not enough arguments for scale", .{});
                display_usage();
            };

            const scaleValint = std.fmt.parseInt(u16, scaleVal, 10) catch {
                std.log.err("Invalid number \"{s}\" for scale", .{scaleVal});
                display_usage();
            };
            cliArgs.scale = scaleValint;
        }
        index += 1;
    }
    return cliArgs;
}
