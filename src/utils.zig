const std = @import("std");

pub fn sleep_ms(time_ms: u64) void {
    std.Thread.sleep(time_ms * std.time.ns_per_ms);
}
