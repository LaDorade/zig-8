const std = @import("std");

var run = std.atomic.Value(bool).init(true);

fn handleSigInt(sig_num: c_int) callconv(.c) void {
    std.log.debug("SIGNAL {d}", .{sig_num});

    if (sig_num == 15) { // SIGTERM
        run.store(false, .unordered);
    }
}

pub fn main() !void {
    std.log.debug("pid: {d}\n", .{std.posix.geteuid()});

    const action = std.posix.Sigaction{
        .handler = .{ .handler = handleSigInt },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };

    std.posix.sigaction(std.posix.SIG.INT, &action, null);
    std.posix.sigaction(std.posix.SIG.TERM, &action, null);

    defer std.log.debug("Je defer", .{});

    while (run.raw) {
        std.log.debug("running, pid = {d}", .{std.posix.geteuid()});
        std.Thread.sleep(5 * std.time.ns_per_s);
    }
}
