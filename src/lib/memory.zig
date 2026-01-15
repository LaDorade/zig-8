pub const Memory = struct {
    /// 0x000 (0) to 0xFFF (4095).
    /// 0x000 to 0x1FF should be unused.
    RAM: [4096]u8 = .{0} ** 4096,

    delay: u8 = 0,
    sound: u8 = 0,

    const Self = @This();

    pub fn get(self: *Self, addr: u16) u8 {
        return self.RAM[addr];
    }

    pub fn set(self: *Self, addr: u16, val: u8) void {
        self.RAM[addr] = val;
    }

    pub fn load_RAM(self: *Self, data: []const u8) !void {
        if (data.len > (self.RAM.len - 0x200)) {
            return error.DATA_TOO_BIG;
        }
        // copy into ram
        for (data, 0..) |byte, i| {
            self.RAM[0x200 + i] = byte;
        }
    }

    /// Refactor, return the ram instead of just printing it
    pub fn dump_RAM(self: *Self) void {
        const print = @import("std").debug.print;
        for (self.RAM, 0..) |byte, i| {
            if (byte == 0x0) {
                continue;
            }
            if (i % 8 == 0) {
                print("\n", .{});
            }
            print("0x{X:0>4} ", .{byte});
            print("{c} ", .{byte});
        }
    }
};
