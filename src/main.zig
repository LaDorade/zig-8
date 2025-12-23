const std = @import("std");

var RAM: [4096]u8 = undefined;
// 0x000 (0) to 0xFFF (4095).
// 0x000 to 0x1FF should be unused

var V: [16]u8 = undefined; // Vx registers
var I: u16 = undefined; // I register (only the last 12 bit are relevant)

var delay: u8 = undefined;
var sound: u8 = undefined;

var PC: u16 = 512; // program counter (starts at 0x200 (512))

var SP: u8 = undefined;
var stack: [16]u16 = undefined;

const width = 64;
const height = 32;
const display_size = width * height;
var display: [display_size]bool = .{false} ** display_size;

pub const InstructionKind = enum(u4) {
    CLS, //00E0
    RET, //00EE
    JMP, // 1NNN
};

/// Clear the display by setting all pixels to ‘off’.
fn clear_screen(dis: *[display_size]bool) void {
    @memset(dis, false);
}

/// Return from a subroutine. Pops the value at the top of the stack (indicated by the stack pointer SP) and puts it in PC.
fn ret() void {
    PC = stack[SP];
}

/// Jump to the address in NNN. Sets the PC to NNN.
fn jump(nnn: u12) void {
    PC = nnn;
}

/// Call the subroutine at address NNN. It increments SP, puts the current PC at the top of the stack and sets PC to the address NNN.
fn call(nnn: u12) void {
    SP += 1;
    stack[SP] = PC;
    PC = nnn;
}

/// Skip the next instruction if VX == NN. Compare the value of register VX with NN and if they are equal, increment PC by two.
fn skip_equal(vx: *u8, nn: u8) void {
    if (vx.* == nn) {
        PC += 2;
    }
}

/// Skip the next instruction if VX != NN. Compare the value of register VX with NN and if they are not equal, increment PC by two.
fn skip_not_equal(vx: *u8, nn: u8) void {
    if (vx.* != nn) {
        PC += 2;
    }
}

/// Skip the next instruction if VX == VY. Compare the value of register VX with the value of VY and if they are equal, increment PC by two.
fn skip_register(vx: *u8, vy: *u8) void {
    if (vx.* == vy.*) {
        PC += 2;
    }
}

/// Load the value NN into the register VX.
fn load_from_const(vx: *u8, nn: u8) void {
    vx.* = nn;
}

/// Add the value NN to the value of register VX and store the result in VX.
fn add_from_const(vx: *u8, nn: u8) void {
    vx.* = vx.* + nn;
}

/// Put the value of register VY into VX.
fn load_from_reg(vx: *u8, vy: *u8) void {
    vx.* = vy.*;
}

/// Perform a bitwise OR between the values of VX and VY and store the result in VX.
fn or_reg(vx: *u8, vy: *u8) void {
    vx.* = vx.* | vy.*;
}

/// Perform a bitwise AND between the values of VX and VY and store the result in VX.
fn and_reg(vx: *u8, vy: *u8) void {
    vx.* = vx.* & vy.*;
}

/// Perform a bitwise XOR between the values of VX and VY and store the result in VX.
fn xor_reg(vx: *u8, vy: *u8) void {
    vx.* = vx.* ^ vy.*;
}

/// Add the values of VX and VY and store the result in VX. Put the carry bit in VF (if there is overflow, set VF to 1, otherwise 0).
fn add_from_reg(vx: *u8, vy: *u8) void {
    const add = @addWithOverflow(vx.*, vy.*);
    if (add[1] != 0) {
        V[0xF] = 1;
    } else {
        V[0xF] = 0;
    }
    vx.* = add[0];
}

/// Subtract the value of VY from VX and store the result in VX. Put the borrow in VF (if there is borrow, VX > VY, set VF to 1, otherwise 0).
fn sub_from_reg(vx: *u8, vy: *u8) void {
    const sub = @subWithOverflow(vx.*, vy.*);
    if (sub[1] != 0) {
        V[0xF] = 1;
    } else {
        V[0xF] = 0;
    }
    vx.* = sub[0];
}

/// Shift right, or divide VX by two. Store the least significant bit of VX in VF, and then divide VX and store its value in VX
fn shift_right(vx: *u8) void {
    V[0xF] = vx.* & 0x01;
    vx.* = vx.* / 2;
}

/// Subtract the value of VY from VX and store the result in VX. Set VF to 1 if there is no borrow, to 0 otherwise.
fn sub_from_reg_n(vx: *u8, vy: *u8) void {
    const sub = @subWithOverflow(vy.*, vx.*);
    if (sub[1] != 0) {
        V[0xF] = 1;
    } else {
        V[0xF] = 0;
    }
    vx.* = sub[0];
}

/// Shift left, or multiply VX by two. Store the most significant bit of VX in VF, and then multiply VX and store its value in VX
fn shif_left(vx: *u8) void {
    V[0xF] = vx.* & 0x80;
    vx.* = vx.* * 2;
}

/// Skip the next instruction if the values of VX and VY are not equal.
fn skip_not_equal_reg(vx: *u8, vy: *u8) void {
    if (vx.* != vy.*) {
        PC += 2;
    }
}

/// Set the value of I to the address NNN.
fn load_I(nnn: u8) void {
    I = nnn;
}

fn jump_v0(v0: *u8, nnn: u12) void {
    PC = v0.* + nnn;
}

/// Generate a random byte (from 0 to 255), do a bitwise AND with NN and store the result to VX.
fn random(vx: *u8, nn: u8) void {
    const rand = std.crypto.random;
    vx.* = rand.int(u8) & nn;
}

// fn draw(vx: *u8, vy: *u8, n: u4) void {}

pub fn main() !void {
    std.debug.print("ROM length = {}, {}\n", .{
        .ROM = RAM.len,
        .first = RAM[0],
    });

    clear_screen(&display);
    ret();
}
