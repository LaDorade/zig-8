const std = @import("std");

var ROM: [4096]u8 = undefined;
// 0x000 (0) to 0xFFF (4095).
// 0x000 to 0x1FF should be unused

var V: [16]u8 = undefined; // Vx registers
var I: u16 = undefined; // I register

var delay: u8 = undefined;
var sound: u8 = undefined;

var PC: u16 = 512; // program counter (starts at 0x200 (512))
var SP: u8 = undefined;

var stack: [16]u16 = undefined;

pub fn main() !void {
    std.debug.print("ROM length = {}, {}\n", .{
        .ROM = ROM.len,
        .first = ROM[0],
    });
}
