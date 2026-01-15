const CPU = @import("cpu.zig").CPU;
const Memory = @import("memory.zig").Memory;

pub fn MasterClock() type {
    return struct {
        pub const display_freq_hz = 60;
        pub const default_cpu_freq_hz = 700;

        memory: *Memory,
        cpu: *CPU,
        cpu_freq_hz: u32 = default_cpu_freq_hz,

        const Self = @This();
        pub fn init(cpu: *CPU, mem: *Memory, cpu_freq_hz: u32) Self {
            return .{
                .memory = mem,
                .cpu = cpu,
                .cpu_freq_hz = cpu_freq_hz,
            };
        }

        pub fn tick(self: *Self) !void {
            if (self.memory.delay > 0) self.memory.delay -= 1;
            if (self.memory.sound > 0) self.memory.sound -= 1;

            for (0..self.cpu_freq_hz / display_freq_hz) |_| {
                try self.cpu.cycle();
            }

            // update display
        }
    };
}
