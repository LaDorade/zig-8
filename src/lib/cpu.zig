const std = @import("std");

const Display = @import("./display.zig").Display;
const Stack = @import("./stack.zig").Stack;
const InstructionKind = @import("./instruction.zig").InstructionKind;
const Instruction = @import("./instruction.zig").Instruction;
const Memory = @import("./memory.zig").Memory;

pub const CPU = struct {
    memory: *Memory,
    /// program counter (starts at 0x200 (512))
    PC: u16 = 0x200,

    /// Vx registers
    V: [16]u8 = .{0} ** 16,
    /// I register
    I: u12 = 0,

    stack: Stack(u16) = Stack(u16).init(),

    display: Display = .{},

    keypad: [16]bool = .{false} ** 16,
    waiting_release_key: ?u4 = null,

    /// Fetch the two next value to compose the instruction
    fn next(self: *CPU) [2]u8 {
        const instVals: [2]u8 = .{
            self.memory.get(self.PC),
            self.memory.get(self.PC + 1),
        };
        self.PC += 2;

        return instVals;
    }

    fn fetch(self: *CPU) u16 {
        const insts = self.next();

        var instVal: u16 = insts[0];
        instVal = instVal << 8;
        instVal = instVal ^ insts[1];

        return instVal;
    }

    /// Run the fetch-decode-execute loop
    pub fn cycle(self: *CPU) !void {
        const instVal = self.fetch();
        try self.decode_and_execute(instVal);
    }

    const DecodeError = error{
        Unknown_0x0XXX_Instruction,
        Unknown_0x8XYI_Instruction,
        Unknown_0xEXXX_Instruction,
        Unknown_0xF0XX_Instruction,
        Unknown_Instruction,
    };

    /// Checks if any key is pressed, then return it index
    fn isKeyPressed(self: *CPU) ?u4 {
        for (self.keypad, 0..) |val, index| {
            if (val) {
                return @truncate(index);
            }
        }
        return null;
    }

    fn decode_and_execute(self: *CPU, instVal: u16) !void {
        var inst: Instruction = .{
            .kind = undefined,
            .X = @truncate((instVal & 0x0F00) >> 8),
            .Y = @truncate((instVal & 0x00F0) >> 4),
            .N = @truncate(instVal & 0x000F),
            .NN = @truncate(instVal & 0x00FF),
            .NNN = @truncate(instVal & 0x0FFF),
        };

        switch ((instVal & 0xF000) >> 12) { // first part of the inst (I...)
            0x0 => { // 00E.
                switch (instVal & 0x000F) {
                    0x0 => { // 00E0
                        inst.kind = InstructionKind.CLS;
                        self.display.clear();
                    },
                    0xE => { // 00EE
                        inst.kind = InstructionKind.RET;
                        self.PC = try self.stack.pop();
                    },
                    else => {
                        std.log.err("Unknown 0x0 instruction '0x{X:4}'", .{instVal});
                        return DecodeError.Unknown_0x0XXX_Instruction;
                    },
                }
            },
            0x1 => { // 1NNN
                inst.kind = InstructionKind.JMP;
                self.PC = inst.NNN;
            },
            0x2 => { // 2NNN
                inst.kind = InstructionKind.CALL;
                try self.stack.add(self.PC);
                self.PC = inst.NNN;
            },
            0x3 => { // 3XNN
                inst.kind = InstructionKind.SEXN;
                if (self.V[inst.X] == inst.NN) {
                    _ = self.next();
                }
            },
            0x4 => { // 4XNN
                inst.kind = InstructionKind.SNEX;
                if (self.V[inst.X] != inst.NN) {
                    _ = self.next();
                }
            },
            0x5 => { // 5XY0
                inst.kind = InstructionKind.SEXY;
                if (self.V[inst.X] == self.V[inst.Y]) {
                    _ = self.next();
                }
            },
            0x6 => { // 6XNN
                inst.kind = InstructionKind.LDXN;
                self.V[inst.X] = inst.NN;
            },
            0x7 => { // 7XNN
                inst.kind = InstructionKind.ADXN;
                const res = @addWithOverflow(self.V[inst.X], inst.NN);
                self.V[inst.X] = res[0];
            },
            0x8 => { // 8XY.
                switch (instVal & 0x000F) {
                    0x0 => { // 8XY0
                        inst.kind = InstructionKind.LDXY;
                        self.V[inst.X] = self.V[inst.Y];
                    },
                    0x1 => { // 8XY1
                        inst.kind = InstructionKind.ORXY;
                        self.V[inst.X] |= self.V[inst.Y];

                        // chip8 specific:
                        self.V[0xF] = 0;
                    },
                    0x2 => { // 8XY2
                        inst.kind = InstructionKind.ANXY;
                        self.V[inst.X] &= self.V[inst.Y];

                        // chip8 specific:
                        self.V[0xF] = 0;
                    },
                    0x3 => { // 8XY3
                        inst.kind = InstructionKind.XORX;
                        self.V[inst.X] ^= self.V[inst.Y];

                        // chip8 specific:
                        self.V[0xF] = 0;
                    },
                    0x4 => { // 8XY4
                        inst.kind = InstructionKind.ADXY;
                        const add = @addWithOverflow(self.V[inst.X], self.V[inst.Y]);
                        self.V[inst.X] = add[0];
                        if (add[1] != 0) {
                            self.V[0xF] = 1;
                        } else {
                            self.V[0xF] = 0;
                        }
                    },
                    0x5 => { // 8XY5
                        inst.kind = InstructionKind.SUBX;
                        const sub = @subWithOverflow(self.V[inst.X], self.V[inst.Y]);
                        self.V[inst.X] = sub[0];
                        if (sub[1] != 0) {
                            self.V[0xF] = 0;
                        } else {
                            self.V[0xF] = 1;
                        }
                    },
                    0x6 => { // 8XY6
                        inst.kind = InstructionKind.SHRX;
                        self.V[0xF] = self.V[inst.X] & 0x01;
                        self.V[inst.X] = self.V[inst.Y];
                        self.V[inst.X] >>= 1;
                    },
                    0x7 => { // 8XY7
                        inst.kind = InstructionKind.SUBY;
                        const sub = @subWithOverflow(self.V[inst.Y], self.V[inst.X]);
                        self.V[inst.X] = sub[0];
                        if (sub[1] != 0) {
                            self.V[0xF] = 0;
                        } else {
                            self.V[0xF] = 1;
                        }
                    },
                    0xE => { // 8XYE
                        inst.kind = InstructionKind.SHL;
                        self.V[0xF] = (self.V[inst.X] & 0x80) >> 7;
                        self.V[inst.X] = self.V[inst.Y];
                        self.V[inst.X] <<= 1;
                    },
                    else => return DecodeError.Unknown_0x8XYI_Instruction,
                }
            },
            0x9 => { // 9XY0
                inst.kind = InstructionKind.SNEY;
                if (self.V[inst.X] != self.V[inst.Y]) {
                    _ = self.next();
                }
            },
            0xA => { // ANNN
                inst.kind = InstructionKind.LDIN;
                self.I = inst.NNN;
            },
            0xB => { // BNNN
                inst.kind = InstructionKind.JMP0;
                self.PC = @as(u16, self.V[0]) + inst.NNN;
            },
            0xC => { // CXNN
                inst.kind = InstructionKind.RND;
                // TODO: improve to run instane only once
                // Maybe ask the user to provide a way to get random ?
                // remove dep to std
                const rand = std.crypto.random;
                self.V[inst.X] = rand.int(u8) & inst.NN;
            },
            0xD => { // DXYN
                inst.kind = InstructionKind.DRW;

                self.V[0xF] = 0; // somehow, nobody mentionned that

                const x_coord = self.V[inst.X] % Display.WIDTH;
                const y_coord = self.V[inst.Y] % Display.HEIGHT;
                for (0..inst.N) |row| {
                    const bits = self.memory.get(@truncate(self.I + row));

                    const y = (y_coord + @as(u8, @truncate(row)));
                    // chip8 specific
                    if (y >= Display.HEIGHT) {
                        continue;
                    }

                    for (0..8) |col| {
                        const x = (x_coord + @as(u8, @truncate(col)));
                        // chip8 specific
                        if (x >= Display.WIDTH) {
                            continue;
                        }

                        const bit: u1 = @truncate((bits >> (7 - @as(u3, @truncate(col)))) & 0x01);
                        const collision = self.display.set_pixel(x, y, bit == 1);

                        if ((self.V[0xF] == 0) and collision) {
                            self.V[0xF] = 1;
                        }
                    }
                }
            },
            0xE => { // EX..
                switch (instVal & 0x00FF) {
                    0x9E => { // EX9E
                        inst.kind = InstructionKind.SKP;
                        if (self.keypad[self.V[inst.X]]) {
                            _ = self.next();
                        }
                    },
                    0xA1 => { // EXA1
                        inst.kind = InstructionKind.SKNP;
                        if (!self.keypad[self.V[inst.X]]) {
                            _ = self.next();
                        }
                    },
                    else => return DecodeError.Unknown_0xEXXX_Instruction,
                }
            },
            0xF => { // FX..
                switch (instVal & 0x00FF) {
                    0x07 => {
                        inst.kind = InstructionKind.LDTX;
                        self.V[inst.X] = self.memory.delay;
                    },
                    0x0A => {
                        inst.kind = InstructionKind.LDKX;
                        if (self.waiting_release_key) |k| {
                            if (!self.keypad[k]) {
                                self.V[inst.X] = k;
                                self.waiting_release_key = null;
                            } else {
                                self.PC -= 2; // loop on this instruction
                            }
                        } else {
                            if (self.isKeyPressed()) |k| {
                                self.waiting_release_key = k;
                            }
                            self.PC -= 2; // loop on this instruction
                        }
                    },
                    0x15 => {
                        inst.kind = InstructionKind.LD;
                        self.memory.delay = self.V[inst.X];
                    },
                    0x18 => {
                        inst.kind = InstructionKind.ST;
                        self.memory.sound = self.V[inst.X];
                    },
                    0x1E => {
                        inst.kind = InstructionKind.ADI;
                        self.I = @addWithOverflow(self.I, self.V[inst.X])[0];
                    },
                    0x29 => {
                        inst.kind = InstructionKind.LDF;
                        self.I = self.V[inst.X] * 0x05;
                    },
                    0x33 => {
                        inst.kind = InstructionKind.LDB;
                        // get hundreds, tens and ones
                        const h = self.V[inst.X] / 100;
                        const t = (self.V[inst.X] - h * 100) / 10;
                        const o = self.V[inst.X] - h * 100 - t * 10;

                        // store to memory
                        self.memory.set(self.I, h);
                        self.memory.set(self.I + 1, t);
                        self.memory.set(self.I + 2, o);
                    },
                    0x55 => {
                        inst.kind = InstructionKind.LDM;
                        for (0..@as(u32, inst.X) + 1) |index| {
                            // self.bus.set(self.I + index, self.V[index]);

                            // chip8 "memory quirk"
                            self.memory.set(self.I, self.V[index]);
                            self.I += 1;
                        }
                    },
                    0x65 => {
                        inst.kind = InstructionKind.LMR;
                        for (0..@as(u32, inst.X) + 1) |index| {
                            // self.V[index] = self.bus.get(self.I + index);

                            // chip8 "memory quirk"
                            self.V[index] = self.memory.get(self.I);
                            self.I += 1;
                        }
                    },
                    else => return DecodeError.Unknown_0xF0XX_Instruction,
                }
            },
            else => return DecodeError.Unknown_Instruction,
        }
    }
};
