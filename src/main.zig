const std = @import("std");

var RAM: [4096]u8 = .{0} ** 4096;
// 0x000 (0) to 0xFFF (4095).
// 0x000 to 0x1FF should be unused

var V: [16]u8 = .{0} ** 16; // Vx registers
var I: u16 = 0; // I register (only the last 12 bit are relevant)

var delay: u8 = 0;
var sound: u8 = 0;

var PC: u16 = 0x200; // program counter (starts at 0x200 (512))

var SP: u8 = 0;
var stack: [16]u16 = .{0} ** 16;

const DISPLAY_WIDTH = 64;
const DISPLAY_HEIGHT = 32;
const display_size = DISPLAY_WIDTH * DISPLAY_HEIGHT;
var display: [display_size]bool = .{false} ** display_size;

/// sets a pixel to (x,y) coordinates (0 based).
/// Does XOR.
/// @returns: true if collision
fn set_pixel(x: u8, y: u8, state: bool) bool {
    const pos = (@as(u32, DISPLAY_WIDTH) * y) + x;
    const pixel_on = display[pos];
    if (pixel_on) {
        if (state) { // colision
            display[pos] = false;
            return true;
        } else {
            display[pos] = true;
            return false;
        }
    } else {
        display[pos] = state;
        return false;
    }
    return false;
}

fn show_display() !void {
    const stdout = std.fs.File.stdout();

    for (0..DISPLAY_HEIGHT) |row| {
        for (0..DISPLAY_WIDTH) |col| {
            const pix_val = display[DISPLAY_WIDTH * row + col];
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

var keypad: [16]bool = .{false} ** 16;
var is_waiting_for_key = false;

pub const InstructionKind = enum(u8) {
    /// 00E0
    CLS,
    /// 00EE
    RET,
    /// 1NNN
    JMP,
    /// 2NNN
    CALL,
    /// 3XNN
    SEXN,
    /// 4XNN
    SNEX,
    /// 5XY0
    SEXY,
    /// 6XNN
    LDXN,
    /// 7XNN
    ADXN,
    /// 8XY0
    LDXY,
    /// 8XY1
    ORXY,
    /// 8XY2
    ANXY,
    /// 8XY3
    XORX,
    /// 8XY4
    ADXY,
    /// 8XY5
    SUBX,
    /// 8XY6
    SHRX,
    /// 8XY7
    SUBY,
    /// 8XYE
    SHL,
    /// 9XY0
    SNEY,
    /// ANNN
    LDIN,
    /// BNNN
    JMP0,
    /// CXNN
    RND,
    /// DXYN
    DRW,
    /// EX9E
    SKP,
    /// EXA1
    SKNP,
    /// FX07
    LDTX,
    /// FX0A
    LDKX,
    /// FX15
    LD,
    /// FX18
    ST,
    /// FX1E
    ADI,
    /// FX29
    LDF,
    /// FX33
    LDB,
    /// FX55
    LDM,
    /// FX65
    LMR,
};

/// Clear the display by setting all pixels to ‘off’.
fn clear_screen() void {
    @memset(&display, false);
}

/// Return from a subroutine. Pops the value at the top of the stack (indicated by the stack pointer SP) and puts it in PC.
fn ret() void {
    PC = stack[SP];
    SP -= 1;
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
fn skip_equal_reg(vx: *u8, vy: *u8) void {
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
    const res = @addWithOverflow(vx.*, nn);
    vx.* = res[0];
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
    vx.* = add[0];
    if (add[1] != 0) {
        V[0xF] = 1;
    } else {
        V[0xF] = 0;
    }
}

/// Subtract the value of VY from VX and store the result in VX. Put the borrow in VF (if there is no borrow, VX > VY, set VF to 1, otherwise 0).
fn sub_from_reg(vx: *u8, vy: *u8) void {
    const sub = @subWithOverflow(vx.*, vy.*);
    vx.* = sub[0];
    if (sub[1] != 0) {
        V[0xF] = 0;
    } else {
        V[0xF] = 1;
    }
}

/// Shift right, or divide VX by two. Store the least significant bit of VX in VF, and then divide VX and store its value in VX
fn shift_right(vx: *u8, vy: *u8) void {
    V[0xF] = vx.* & 0x01;
    vx.* = vy.*;
    vx.* >>= 1;
}

/// Subtract the value of VY from VX and store the result in VX. Set VF to 1 if there is no borrow, to 0 otherwise.
fn sub_from_reg_n(vx: *u8, vy: *u8) void {
    const sub = @subWithOverflow(vy.*, vx.*);
    vx.* = sub[0];
    if (sub[1] != 0) {
        V[0xF] = 0;
    } else {
        V[0xF] = 1;
    }
}

/// If the most-significant bit of Vx is 1, then VF is set to 1, otherwise to 0. Then Vx is multiplied by 2.
fn shift_left(vx: *u8, vy: *u8) void {
    V[0xF] = (vx.* & 0x80) >> 7;
    vx.* = vy.*;
    vx.* <<= 1;
}

/// Skip the next instruction if the values of VX and VY are not equal.
fn skip_not_equal_reg(vx: *u8, vy: *u8) void {
    if (vx.* != vy.*) {
        PC += 2;
    }
}

/// Set the value of I to the address NNN.
fn load_I(nnn: u12) void {
    I = nnn & 0xFFF;
}

fn jump_v0(nnn: u12) void {
    PC = @as(u16, V[0]) + nnn;
}

/// Generate a random byte (from 0 to 255), do a bitwise AND with NN and store the result to VX.
fn random(vx: *u8, nn: u8) void {
    const rand = std.crypto.random;
    vx.* = rand.int(u8) & nn;
}

/// The draw instruction. This is arguably the most involved operation. The n-byte sprite starting at the address I is drawn to the display at the coordinates [VX, VY]. Then, set VF to 1 if there has been a collision (a display bit was changed from 1 to 0).
/// The interpreter must read N bytes from the I address in memory. These bytes are interpreted as a sprite and drawn at the display coordinates [VX, VY]. The bits are set using an XOR with the current display state.
fn draw(vx: *const u8, vy: *const u8, n: u4) void {
    const x_coord = vx.* % DISPLAY_WIDTH;
    const y_coord = vy.* % DISPLAY_HEIGHT;
    for (0..n) |row| {
        const bits = RAM[I + row];

        for (0..8) |col| {
            const x = (x_coord + @as(u8, @truncate(col))) % DISPLAY_WIDTH;
            const y = (y_coord + @as(u8, @truncate(row))) % DISPLAY_HEIGHT;
            const bit: u1 = @truncate((bits >> (7 - @as(u3, @truncate(col)))) & 0x01);
            const collision = set_pixel(x, y, bit == 1);

            if ((V[0xF] == 0) and collision) {
                V[0xF] = 1;
            }
        }
    }
}

/// Skip the next instruction if the key with the value of VX is currently pressed. Basically, increase PC by two if the key corresponding to the value in VX is pressed.
fn skip_pressed(vx: *u8) void {
    if (keypad[vx.*]) {
        PC += 2;
    }
}

/// Skip the next instruction if the key with the value of VX is currently not pressed. Basically, increase PC by two if the key corresponding to the value in VX is not pressed.
fn skip_not_pressed(vx: *u8) void {
    if (!keypad[vx.*]) {
        PC += 2;
    }
}

/// Read the delay timer register value into VX.
fn load_delay(vx: *u8) void {
    vx.* = delay;
}

/// Wait for a key press, and then store the value of the key to VX.
fn wait_key(_: *u8) void {
    is_waiting_for_key = true;
    unreachable;
}

/// Load the value of VX into the delay timer DT.
fn upload_delay(vx: *u8) void {
    delay = vx.*;
}

/// Load the value of VX into the sound time ST.
fn upload_sound(vx: *u8) void {
    sound = vx.*;
}

///Add the values of I and VX, and store the result in I.
fn add_to_i(vx: *u8) void {
    I = I + vx.*;
}

/// Set the location of the sprite for the digit VX to I. The font sprites start at address 0x000, and contain the hexadecimal digits from 1..F. Each font has a length of 0x05 bytes. The memory address for the value in VX is put in I. See the display section.
fn load_sprite(vx: *u8) void {
    I = vx.* * 0x05;
}

/// Store the binary-coded decimal in VX and put it in three consecutive memory slots starting at I. VX is a byte, so it is in 0…255. The interpreter takes the value in VX (for example the decimal value 174, or 0xAE in hex), converts it into a decimal and separates the hundreds, the tens and the ones (1, 7 and 4 respectively). Then, it stores them in three memory locations starting at I (1 to I, 7 to I+1 and 4 to I+2).
fn load_number(vx: *u8) void {
    // get hundreds, tens and ones
    const h = vx.* / 100;
    const t = (vx.* - h * 100) / 10;
    const o = vx.* - h * 100 - t * 10;

    // store to memory
    RAM[I] = h;
    RAM[I + 1] = t;
    RAM[I + 2] = o;
}

/// Store registers from V0 to VX in the main memory, starting at location I. Note that X is the number of the register, so we can use it in the loop. In the following pseudo-code, V[i] allows for indexed register access, so that VX == V[X].
fn load_memory_from_reg(registerIndex: u4) void {
    for (0..registerIndex + 1) |index| {
        RAM[I + index] = V[index];
    }
}
/// Load the memory data starting at address I into the registers V0 to VX.
fn load_memory_to_reg(registerIndex: u4) void {
    for (0..registerIndex + 1) |index| {
        V[index] = RAM[I + index];
    }
}

fn fetch() u16 {
    var instVal: u16 = RAM[PC];
    instVal = instVal << 8;
    instVal = instVal ^ RAM[PC + 1];

    PC += 2; // increment the pointer

    // std.debug.print("Fetched instruction: {x}\n", .{instVal});

    return instVal;
}

const Instruction = struct {
    kind: InstructionKind,
    X: u4,
    Y: u4,
    N: u4,
    NN: u8,
    NNN: u12,
};

fn decode_and_execute(instVal: u16) Instruction {
    var inst: Instruction = .{
        .kind = undefined,
        .X = @truncate((instVal & 0x0F00) >> 8),
        .Y = @truncate((instVal & 0x00F0) >> 4),
        .N = @truncate(instVal & 0x000F),
        .NN = @truncate(instVal & 0x00FF),
        .NNN = @truncate(instVal & 0x0FFF),
    };

    switch ((instVal & 0xF000) >> 12) { // first part of the inst (X...)
        0x0 => { // 00E.
            switch (instVal & 0x000F) {
                0x0 => { // 00E0
                    inst.kind = InstructionKind.CLS;
                    clear_screen();
                },
                0xE => { // 00EE
                    inst.kind = InstructionKind.RET;
                    ret();
                },
                else => @panic("Impossible instruction"),
            }
        },
        0x1 => { // 1NNN
            inst.kind = InstructionKind.JMP;
            jump(inst.NNN);
        },
        0x2 => { // 2NNN
            inst.kind = InstructionKind.CALL;
            call(inst.NNN);
        },
        0x3 => { // 3XNN
            inst.kind = InstructionKind.SEXN;
            skip_equal(&V[inst.X], inst.NN);
        },
        0x4 => { // 4XNN
            inst.kind = InstructionKind.SNEX;
            skip_not_equal(&V[inst.X], inst.NN);
        },
        0x5 => { // 5XY0
            inst.kind = InstructionKind.SEXY;
            skip_equal_reg(&V[inst.X], &V[inst.Y]);
        },
        0x6 => { // 6XNN
            inst.kind = InstructionKind.LDXN;
            load_from_const(&V[inst.X], inst.NN);
        },
        0x7 => { // 7XNN
            inst.kind = InstructionKind.ADXN;
            add_from_const(&V[inst.X], inst.NN);
        },
        0x8 => { // 8XY.
            switch (instVal & 0x000F) {
                0x0 => { // 8XY0
                    inst.kind = InstructionKind.LDXY;
                    load_from_reg(&V[inst.X], &V[inst.Y]);
                },
                0x1 => { // 8XY1
                    inst.kind = InstructionKind.ORXY;
                    or_reg(&V[inst.X], &V[inst.Y]);
                },
                0x2 => { // 8XY2
                    inst.kind = InstructionKind.ANXY;
                    and_reg(&V[inst.X], &V[inst.Y]);
                },
                0x3 => { // 8XY3
                    inst.kind = InstructionKind.XORX;
                    xor_reg(&V[inst.X], &V[inst.Y]);
                },
                0x4 => { // 8XY4
                    inst.kind = InstructionKind.ADXY;
                    add_from_reg(&V[inst.X], &V[inst.Y]);
                },
                0x5 => { // 8XY5
                    inst.kind = InstructionKind.SUBX;
                    sub_from_reg(&V[inst.X], &V[inst.Y]);
                },
                0x6 => { // 8XY6
                    inst.kind = InstructionKind.SHRX;
                    shift_right(&V[inst.X], &V[inst.Y]);
                },
                0x7 => { // 8XY7
                    inst.kind = InstructionKind.SUBY;
                    sub_from_reg_n(&V[inst.X], &V[inst.Y]);
                },
                0xE => { // 8XYE
                    inst.kind = InstructionKind.SHL;
                    shift_left(&V[inst.X], &V[inst.Y]);
                },
                else => @panic("Impossible 8XY. instruction"),
            }
        },
        0x9 => { // 9XY0
            inst.kind = InstructionKind.SNEY;
            skip_not_equal_reg(&V[inst.X], &V[inst.Y]);
        },
        0xA => { // ANNN
            inst.kind = InstructionKind.LDIN;
            load_I(inst.NNN);
        },
        0xB => { // BNNN
            inst.kind = InstructionKind.JMP0;
            jump_v0(inst.NNN);
        },
        0xC => { // CXNN
            inst.kind = InstructionKind.RND;
            random(&V[inst.X], inst.NN);
        },
        0xD => { // DXYN
            inst.kind = InstructionKind.DRW;
            draw(&V[inst.X], &V[inst.Y], inst.N);
            _ = show_display() catch {};
        },
        0xE => { // EX..
            switch (instVal & 0x00FF) {
                0x9E => { // EX9E
                    inst.kind = InstructionKind.SKP;
                    skip_pressed(&V[inst.X]);
                },
                0xA1 => { // EXA1
                    inst.kind = InstructionKind.SKNP;
                    skip_not_pressed(&V[inst.X]);
                },
                else => {
                    @panic("Impossible EX.. instruction");
                },
            }
        },
        0xF => { // FX..
            switch (instVal & 0x00FF) {
                0x07 => {
                    inst.kind = InstructionKind.LDTX;
                    load_delay(&V[inst.X]);
                },
                0x0A => {
                    inst.kind = InstructionKind.LDKX;
                    wait_key(&V[inst.X]);
                },
                0x15 => {
                    inst.kind = InstructionKind.LD;
                    upload_delay(&V[inst.X]);
                },
                0x18 => {
                    inst.kind = InstructionKind.ST;
                    upload_sound(&V[inst.X]);
                },
                0x1E => {
                    inst.kind = InstructionKind.ADI;
                    add_to_i(&V[inst.X]);
                },
                0x29 => {
                    inst.kind = InstructionKind.LDF;
                    load_sprite(&V[inst.X]);
                },
                0x33 => {
                    inst.kind = InstructionKind.LDB;
                    load_number(&V[inst.X]);
                },
                0x55 => {
                    inst.kind = InstructionKind.LDM;
                    load_memory_from_reg(@as(u4, inst.X));
                },
                0x65 => {
                    inst.kind = InstructionKind.LMR;
                    load_memory_to_reg(@as(u4, inst.X));
                },
                else => {
                    @panic("Impossible FX.. instruction");
                },
            }
        },
        else => @panic("Impossible instruction"),
    }
    return inst;
}

fn loop() !void {
    const val = fetch();

    _ = decode_and_execute(val);
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

    // Load ROM into memory starting at 0x200, as per CHIP-8 convention
    if (rom_data.len > (RAM.len - 0x200)) {
        std.log.err("ROM too large: {} bytes", .{rom_data.len});
        return;
    }
    for (rom_data, 0..) |byte, i| {
        RAM[0x200 + i] = byte;
    }

    while (true) {
        try loop();
    }
}
