pub const Instruction = struct {
    kind: InstructionKind,
    X: u4,
    Y: u4,
    N: u4,
    NN: u8,
    NNN: u12,
};

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
