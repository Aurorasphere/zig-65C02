const IRQVector: u16 = 0xFFFE;
const NMIVector: u16 = 0xFFFA;
const ResetVector: u16 = 0xFFFC;

pub const memory_interface = struct {
    ctx: *anyopaque,
    readFn: *const fn (*anyopaque, u16) u8,
    writeFn: *const fn (*anyopaque, u16, u8) void,

    fn read(self: @This(), address: u16) u8 {
        return self.readFn(self.ctx, address);
    }

    fn write(self: @This(), address: u16, value: u8) void {
        self.writeFn(self.ctx, address, value);
    }
};

pub const StatusRegister = packed struct {
    carry: bool = false,
    zero: bool = false,
    intmask: bool = false,
    decimal: bool = false,
    break_flag: bool = false,
    unused: bool = true,
    overflow: bool = false,
    negative: bool = false,

    pub fn toByte(self: @This()) u8 {
        var b: u8 = @bitCast(self);
        b |= 0b0010_0000;
        return b;
    }

    pub fn fromByte(value: u8) @This() {
        const forced: u8 = value | 0b0010_0000;
        return @bitCast(forced);
    }
};

pub const AddressingMode = enum {
    ACC, // Accumulator
    ABS, // Absolute
    ABSX, // Absolute X
    ABSY, // Absolute Y
    IMM, // Immediate
    IMPL, // Implied
    IND, // Indirect
    XIND, // Indirect X
    INDY, // Indirect Y
    REL, // Relative
    ZPG, // Zero Page
    ZPGX, // Zero Page X
    ZPGY, // Zero Page Y
    INDZPG, // Zero Page Indirect, 65C02 only
    ABSXIND, // Absolute Indexed Indirect, 65C02 only
    ZPGREL, // Only for BBS/BBR instructions
};

pub const mnemonic65C02 = enum {
    ADC,
    AND,
    ASL,
    BCC,
    BCS,
    BEQ,
    BIT,
    BMI,
    BNE,
    BPL,
    BRK,
    BVC,
    BVS,
    CLC,
    CLD,
    CLI,
    CLV,
    CMP,
    CPX,
    CPY,
    DEC,
    DEX,
    DEY,
    EOR,
    INC,
    INX,
    INY,
    JMP,
    JSR,
    LDA,
    LDX,
    LDY,
    LSR,
    NOP,
    ORA,
    PHA,
    PHP,
    PLA,
    PLP,
    ROL,
    ROR,
    RTI,
    RTS,
    SBC,
    SEC,
    SED,
    SEI,
    STA,
    STX,
    STY,
    TAX,
    TAY,
    TSX,
    TXA,
    TXS,
    TYA,
    // 65C02 additional instructions
    BBR0,
    BBR1,
    BBR2,
    BBR3,
    BBR4,
    BBR5,
    BBR6,
    BBR7,
    BBS0,
    BBS1,
    BBS2,
    BBS3,
    BBS4,
    BBS5,
    BBS6,
    BBS7,
    BRA,
    PHX,
    PHY,
    PLX,
    PLY,
    RMB0,
    RMB1,
    RMB2,
    RMB3,
    RMB4,
    RMB5,
    RMB6,
    RMB7,
    SMB0,
    SMB1,
    SMB2,
    SMB3,
    SMB4,
    SMB5,
    SMB6,
    SMB7,
    STP,
    STZ,
    TRB,
    TSB,
    WAI,
};

pub const cpu65c02 = struct {
    accumulator: u8 = 0,
    x_register: u8 = 0,
    y_register: u8 = 0,
    stack_pointer: u8 = 0,
    pch: u8 = 0,
    pcl: u8 = 0,
    status_register: StatusRegister = StatusRegister.fromByte(0),
    memory: memory_interface,
    STP: bool = false,
    WAIT: bool = false,
    current_opcode: u8 = 0,
    cycles: u64 = 0,

    // =============== INSTRUCTION HANDLERS ===============
    const instrInfo = struct {
        mnemonic: mnemonic65C02,
        address_mode: AddressingMode,
        cycles: u64,
    };

    const opcode65C02: [256]instrInfo = blk: {
        var opcodes: [256]instrInfo = undefined;

        for (&opcodes) |*opcode| {
            opcode.* = instrInfo{
                .mnemonic = .NOP,
                .address_mode = .IMPL,
                .cycles = 2,
            };
        }

        // Row 0_
        opcodes[0x00] = instrInfo{ .mnemonic = .BRK, .address_mode = .IMPL, .cycles = 7 };
        opcodes[0x01] = instrInfo{ .mnemonic = .ORA, .address_mode = .XIND, .cycles = 6 };
        opcodes[0x02] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x03] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x04] = instrInfo{ .mnemonic = .TSB, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x05] = instrInfo{ .mnemonic = .ORA, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0x06] = instrInfo{ .mnemonic = .ASL, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x07] = instrInfo{ .mnemonic = .RMB0, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x08] = instrInfo{ .mnemonic = .PHP, .address_mode = .IMPL, .cycles = 3 };
        opcodes[0x09] = instrInfo{ .mnemonic = .ORA, .address_mode = .IMM, .cycles = 2 };
        opcodes[0x0A] = instrInfo{ .mnemonic = .ASL, .address_mode = .ACC, .cycles = 2 };
        opcodes[0x0B] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x0C] = instrInfo{ .mnemonic = .TSB, .address_mode = .ABS, .cycles = 6 };
        opcodes[0x0D] = instrInfo{ .mnemonic = .ORA, .address_mode = .ABS, .cycles = 4 };
        opcodes[0x0E] = instrInfo{ .mnemonic = .ASL, .address_mode = .ABS, .cycles = 6 };
        opcodes[0x0F] = instrInfo{ .mnemonic = .BBR0, .address_mode = .ZPGREL, .cycles = 5 };

        // Row 1_
        opcodes[0x10] = instrInfo{ .mnemonic = .BPL, .address_mode = .REL, .cycles = 2 };
        opcodes[0x11] = instrInfo{ .mnemonic = .ORA, .address_mode = .INDY, .cycles = 5 };
        opcodes[0x12] = instrInfo{ .mnemonic = .ORA, .address_mode = .INDZPG, .cycles = 5 };
        opcodes[0x13] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x14] = instrInfo{ .mnemonic = .TRB, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x15] = instrInfo{ .mnemonic = .ORA, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0x16] = instrInfo{ .mnemonic = .ASL, .address_mode = .ZPGX, .cycles = 6 };
        opcodes[0x17] = instrInfo{ .mnemonic = .RMB1, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x18] = instrInfo{ .mnemonic = .CLC, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x19] = instrInfo{ .mnemonic = .ORA, .address_mode = .ABSY, .cycles = 4 };
        opcodes[0x1A] = instrInfo{ .mnemonic = .INC, .address_mode = .ACC, .cycles = 2 };
        opcodes[0x1B] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x1C] = instrInfo{ .mnemonic = .TRB, .address_mode = .ABS, .cycles = 6 };
        opcodes[0x1D] = instrInfo{ .mnemonic = .ORA, .address_mode = .ABSX, .cycles = 4 };
        opcodes[0x1E] = instrInfo{ .mnemonic = .ASL, .address_mode = .ABSX, .cycles = 6 };
        opcodes[0x1F] = instrInfo{ .mnemonic = .BBR1, .address_mode = .ZPGREL, .cycles = 5 };

        // Row 2_
        opcodes[0x20] = instrInfo{ .mnemonic = .JSR, .address_mode = .ABS, .cycles = 6 };
        opcodes[0x21] = instrInfo{ .mnemonic = .AND, .address_mode = .XIND, .cycles = 6 };
        opcodes[0x22] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x23] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x24] = instrInfo{ .mnemonic = .BIT, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0x25] = instrInfo{ .mnemonic = .AND, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0x26] = instrInfo{ .mnemonic = .ROL, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x27] = instrInfo{ .mnemonic = .RMB2, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x28] = instrInfo{ .mnemonic = .PLP, .address_mode = .IMPL, .cycles = 4 };
        opcodes[0x29] = instrInfo{ .mnemonic = .AND, .address_mode = .IMM, .cycles = 2 };
        opcodes[0x2A] = instrInfo{ .mnemonic = .ROL, .address_mode = .ACC, .cycles = 2 };
        opcodes[0x2B] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x2C] = instrInfo{ .mnemonic = .BIT, .address_mode = .ABS, .cycles = 4 };
        opcodes[0x2D] = instrInfo{ .mnemonic = .AND, .address_mode = .ABS, .cycles = 4 };
        opcodes[0x2E] = instrInfo{ .mnemonic = .ROL, .address_mode = .ABS, .cycles = 6 };
        opcodes[0x2F] = instrInfo{ .mnemonic = .BBR2, .address_mode = .ZPGREL, .cycles = 5 };

        // Row 3_
        opcodes[0x30] = instrInfo{ .mnemonic = .BMI, .address_mode = .REL, .cycles = 2 };
        opcodes[0x31] = instrInfo{ .mnemonic = .AND, .address_mode = .INDY, .cycles = 5 };
        opcodes[0x32] = instrInfo{ .mnemonic = .AND, .address_mode = .INDZPG, .cycles = 5 };
        opcodes[0x33] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x34] = instrInfo{ .mnemonic = .BIT, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0x35] = instrInfo{ .mnemonic = .AND, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0x36] = instrInfo{ .mnemonic = .ROL, .address_mode = .ZPGX, .cycles = 6 };
        opcodes[0x37] = instrInfo{ .mnemonic = .RMB3, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x38] = instrInfo{ .mnemonic = .SEC, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x39] = instrInfo{ .mnemonic = .AND, .address_mode = .ABSY, .cycles = 4 };
        opcodes[0x3A] = instrInfo{ .mnemonic = .DEC, .address_mode = .ACC, .cycles = 2 };
        opcodes[0x3B] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x3C] = instrInfo{ .mnemonic = .BIT, .address_mode = .ABSX, .cycles = 4 };
        opcodes[0x3D] = instrInfo{ .mnemonic = .AND, .address_mode = .ABSX, .cycles = 4 };
        opcodes[0x3E] = instrInfo{ .mnemonic = .ROL, .address_mode = .ABSX, .cycles = 6 };
        opcodes[0x3F] = instrInfo{ .mnemonic = .BBR3, .address_mode = .ZPGREL, .cycles = 5 };

        // Row 4_
        opcodes[0x40] = instrInfo{ .mnemonic = .RTI, .address_mode = .IMPL, .cycles = 6 };
        opcodes[0x41] = instrInfo{ .mnemonic = .EOR, .address_mode = .XIND, .cycles = 6 };
        opcodes[0x42] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x43] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x44] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x45] = instrInfo{ .mnemonic = .EOR, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0x46] = instrInfo{ .mnemonic = .LSR, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x47] = instrInfo{ .mnemonic = .RMB4, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x48] = instrInfo{ .mnemonic = .PHA, .address_mode = .IMPL, .cycles = 3 };
        opcodes[0x49] = instrInfo{ .mnemonic = .EOR, .address_mode = .IMM, .cycles = 2 };
        opcodes[0x4A] = instrInfo{ .mnemonic = .LSR, .address_mode = .ACC, .cycles = 2 };
        opcodes[0x4B] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x4C] = instrInfo{ .mnemonic = .JMP, .address_mode = .ABS, .cycles = 3 };
        opcodes[0x4D] = instrInfo{ .mnemonic = .EOR, .address_mode = .ABS, .cycles = 4 };
        opcodes[0x4E] = instrInfo{ .mnemonic = .LSR, .address_mode = .ABS, .cycles = 6 };
        opcodes[0x4F] = instrInfo{ .mnemonic = .BBR4, .address_mode = .ZPGREL, .cycles = 5 };

        // Row 5_
        opcodes[0x50] = instrInfo{ .mnemonic = .BVC, .address_mode = .REL, .cycles = 2 };
        opcodes[0x51] = instrInfo{ .mnemonic = .EOR, .address_mode = .INDY, .cycles = 5 };
        opcodes[0x52] = instrInfo{ .mnemonic = .EOR, .address_mode = .INDZPG, .cycles = 5 };
        opcodes[0x53] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x54] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x55] = instrInfo{ .mnemonic = .EOR, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0x56] = instrInfo{ .mnemonic = .LSR, .address_mode = .ZPGX, .cycles = 6 };
        opcodes[0x57] = instrInfo{ .mnemonic = .RMB5, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x58] = instrInfo{ .mnemonic = .CLI, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x59] = instrInfo{ .mnemonic = .EOR, .address_mode = .ABSY, .cycles = 4 };
        opcodes[0x5A] = instrInfo{ .mnemonic = .PHY, .address_mode = .IMPL, .cycles = 3 };
        opcodes[0x5B] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x5C] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x5D] = instrInfo{ .mnemonic = .EOR, .address_mode = .ABSX, .cycles = 4 };
        opcodes[0x5E] = instrInfo{ .mnemonic = .LSR, .address_mode = .ABSX, .cycles = 6 };
        opcodes[0x5F] = instrInfo{ .mnemonic = .BBR5, .address_mode = .ZPGREL, .cycles = 5 };

        // Row 6_
        opcodes[0x60] = instrInfo{ .mnemonic = .RTS, .address_mode = .IMPL, .cycles = 6 };
        opcodes[0x61] = instrInfo{ .mnemonic = .ADC, .address_mode = .XIND, .cycles = 6 };
        opcodes[0x62] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x63] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x64] = instrInfo{ .mnemonic = .STZ, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0x65] = instrInfo{ .mnemonic = .ADC, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0x66] = instrInfo{ .mnemonic = .ROR, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x67] = instrInfo{ .mnemonic = .RMB6, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x68] = instrInfo{ .mnemonic = .PLA, .address_mode = .IMPL, .cycles = 4 };
        opcodes[0x69] = instrInfo{ .mnemonic = .ADC, .address_mode = .IMM, .cycles = 2 };
        opcodes[0x6A] = instrInfo{ .mnemonic = .ROR, .address_mode = .ACC, .cycles = 2 };
        opcodes[0x6B] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x6C] = instrInfo{ .mnemonic = .JMP, .address_mode = .IND, .cycles = 6 };
        opcodes[0x6D] = instrInfo{ .mnemonic = .ADC, .address_mode = .ABS, .cycles = 4 };
        opcodes[0x6E] = instrInfo{ .mnemonic = .ROR, .address_mode = .ABS, .cycles = 6 };
        opcodes[0x6F] = instrInfo{ .mnemonic = .BBR6, .address_mode = .ZPGREL, .cycles = 5 };

        // Row 7_
        opcodes[0x70] = instrInfo{ .mnemonic = .BVS, .address_mode = .REL, .cycles = 2 };
        opcodes[0x71] = instrInfo{ .mnemonic = .ADC, .address_mode = .INDY, .cycles = 5 };
        opcodes[0x72] = instrInfo{ .mnemonic = .ADC, .address_mode = .INDZPG, .cycles = 5 };
        opcodes[0x73] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x74] = instrInfo{ .mnemonic = .STZ, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0x75] = instrInfo{ .mnemonic = .ADC, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0x76] = instrInfo{ .mnemonic = .ROR, .address_mode = .ZPGX, .cycles = 6 };
        opcodes[0x77] = instrInfo{ .mnemonic = .RMB7, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x78] = instrInfo{ .mnemonic = .SEI, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x79] = instrInfo{ .mnemonic = .ADC, .address_mode = .ABSY, .cycles = 4 };
        opcodes[0x7A] = instrInfo{ .mnemonic = .PLY, .address_mode = .IMPL, .cycles = 4 };
        opcodes[0x7B] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x7C] = instrInfo{ .mnemonic = .JMP, .address_mode = .ABSXIND, .cycles = 6 };
        opcodes[0x7D] = instrInfo{ .mnemonic = .ADC, .address_mode = .ABSX, .cycles = 4 };
        opcodes[0x7E] = instrInfo{ .mnemonic = .ROR, .address_mode = .ABSX, .cycles = 6 };
        opcodes[0x7F] = instrInfo{ .mnemonic = .BBR7, .address_mode = .ZPGREL, .cycles = 5 };

        // Row 8_
        opcodes[0x80] = instrInfo{ .mnemonic = .BRA, .address_mode = .REL, .cycles = 2 };
        opcodes[0x81] = instrInfo{ .mnemonic = .STA, .address_mode = .XIND, .cycles = 6 };
        opcodes[0x82] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x83] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x84] = instrInfo{ .mnemonic = .STY, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0x85] = instrInfo{ .mnemonic = .STA, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0x86] = instrInfo{ .mnemonic = .STX, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0x87] = instrInfo{ .mnemonic = .SMB0, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x88] = instrInfo{ .mnemonic = .DEY, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x89] = instrInfo{ .mnemonic = .BIT, .address_mode = .IMM, .cycles = 2 };
        opcodes[0x8A] = instrInfo{ .mnemonic = .TXA, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x8B] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x8C] = instrInfo{ .mnemonic = .STY, .address_mode = .ABS, .cycles = 4 };
        opcodes[0x8D] = instrInfo{ .mnemonic = .STA, .address_mode = .ABS, .cycles = 4 };
        opcodes[0x8E] = instrInfo{ .mnemonic = .STX, .address_mode = .ABS, .cycles = 4 };
        opcodes[0x8F] = instrInfo{ .mnemonic = .BBS0, .address_mode = .ZPGREL, .cycles = 5 };

        // Row 9_
        opcodes[0x90] = instrInfo{ .mnemonic = .BCC, .address_mode = .REL, .cycles = 2 };
        opcodes[0x91] = instrInfo{ .mnemonic = .STA, .address_mode = .INDY, .cycles = 6 };
        opcodes[0x92] = instrInfo{ .mnemonic = .STA, .address_mode = .INDZPG, .cycles = 5 };
        opcodes[0x93] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x94] = instrInfo{ .mnemonic = .STY, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0x95] = instrInfo{ .mnemonic = .STA, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0x96] = instrInfo{ .mnemonic = .STX, .address_mode = .ZPGY, .cycles = 4 };
        opcodes[0x97] = instrInfo{ .mnemonic = .SMB1, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0x98] = instrInfo{ .mnemonic = .TYA, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x99] = instrInfo{ .mnemonic = .STA, .address_mode = .ABSY, .cycles = 5 };
        opcodes[0x9A] = instrInfo{ .mnemonic = .TXS, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x9B] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0x9C] = instrInfo{ .mnemonic = .STZ, .address_mode = .ABS, .cycles = 4 };
        opcodes[0x9D] = instrInfo{ .mnemonic = .STA, .address_mode = .ABSX, .cycles = 5 };
        opcodes[0x9E] = instrInfo{ .mnemonic = .STZ, .address_mode = .ABSX, .cycles = 5 };
        opcodes[0x9F] = instrInfo{ .mnemonic = .BBS1, .address_mode = .ZPGREL, .cycles = 5 };

        // Row A_
        opcodes[0xA0] = instrInfo{ .mnemonic = .LDY, .address_mode = .IMM, .cycles = 2 };
        opcodes[0xA1] = instrInfo{ .mnemonic = .LDA, .address_mode = .XIND, .cycles = 6 };
        opcodes[0xA2] = instrInfo{ .mnemonic = .LDX, .address_mode = .IMM, .cycles = 2 };
        opcodes[0xA3] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xA4] = instrInfo{ .mnemonic = .LDY, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0xA5] = instrInfo{ .mnemonic = .LDA, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0xA6] = instrInfo{ .mnemonic = .LDX, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0xA7] = instrInfo{ .mnemonic = .SMB2, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0xA8] = instrInfo{ .mnemonic = .TAY, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xA9] = instrInfo{ .mnemonic = .LDA, .address_mode = .IMM, .cycles = 2 };
        opcodes[0xAA] = instrInfo{ .mnemonic = .TAX, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xAB] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xAC] = instrInfo{ .mnemonic = .LDY, .address_mode = .ABS, .cycles = 4 };
        opcodes[0xAD] = instrInfo{ .mnemonic = .LDA, .address_mode = .ABS, .cycles = 4 };
        opcodes[0xAE] = instrInfo{ .mnemonic = .LDX, .address_mode = .ABS, .cycles = 4 };
        opcodes[0xAF] = instrInfo{ .mnemonic = .BBS2, .address_mode = .ZPGREL, .cycles = 5 };

        // Row B_
        opcodes[0xB0] = instrInfo{ .mnemonic = .BCS, .address_mode = .REL, .cycles = 2 };
        opcodes[0xB1] = instrInfo{ .mnemonic = .LDA, .address_mode = .INDY, .cycles = 5 };
        opcodes[0xB2] = instrInfo{ .mnemonic = .LDA, .address_mode = .INDZPG, .cycles = 5 };
        opcodes[0xB3] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xB4] = instrInfo{ .mnemonic = .LDY, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0xB5] = instrInfo{ .mnemonic = .LDA, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0xB6] = instrInfo{ .mnemonic = .LDX, .address_mode = .ZPGY, .cycles = 4 };
        opcodes[0xB7] = instrInfo{ .mnemonic = .SMB3, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0xB8] = instrInfo{ .mnemonic = .CLV, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xB9] = instrInfo{ .mnemonic = .LDA, .address_mode = .ABSY, .cycles = 4 };
        opcodes[0xBA] = instrInfo{ .mnemonic = .TSX, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xBB] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xBC] = instrInfo{ .mnemonic = .LDY, .address_mode = .ABSX, .cycles = 4 };
        opcodes[0xBD] = instrInfo{ .mnemonic = .LDA, .address_mode = .ABSX, .cycles = 4 };
        opcodes[0xBE] = instrInfo{ .mnemonic = .LDX, .address_mode = .ABSY, .cycles = 4 };
        opcodes[0xBF] = instrInfo{ .mnemonic = .BBS3, .address_mode = .ZPGREL, .cycles = 5 };

        // Row C_
        opcodes[0xC0] = instrInfo{ .mnemonic = .CPY, .address_mode = .IMM, .cycles = 2 };
        opcodes[0xC1] = instrInfo{ .mnemonic = .CMP, .address_mode = .XIND, .cycles = 6 };
        opcodes[0xC2] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xC3] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xC4] = instrInfo{ .mnemonic = .CPY, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0xC5] = instrInfo{ .mnemonic = .CMP, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0xC6] = instrInfo{ .mnemonic = .DEC, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0xC7] = instrInfo{ .mnemonic = .SMB4, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0xC8] = instrInfo{ .mnemonic = .INY, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xC9] = instrInfo{ .mnemonic = .CMP, .address_mode = .IMM, .cycles = 2 };
        opcodes[0xCA] = instrInfo{ .mnemonic = .DEX, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xCB] = instrInfo{ .mnemonic = .WAI, .address_mode = .IMPL, .cycles = 3 };
        opcodes[0xCC] = instrInfo{ .mnemonic = .CPY, .address_mode = .ABS, .cycles = 4 };
        opcodes[0xCD] = instrInfo{ .mnemonic = .CMP, .address_mode = .ABS, .cycles = 4 };
        opcodes[0xCE] = instrInfo{ .mnemonic = .DEC, .address_mode = .ABS, .cycles = 6 };
        opcodes[0xCF] = instrInfo{ .mnemonic = .BBS4, .address_mode = .ZPGREL, .cycles = 5 };

        // Row D_
        opcodes[0xD0] = instrInfo{ .mnemonic = .BNE, .address_mode = .REL, .cycles = 2 };
        opcodes[0xD1] = instrInfo{ .mnemonic = .CMP, .address_mode = .INDY, .cycles = 5 };
        opcodes[0xD2] = instrInfo{ .mnemonic = .CMP, .address_mode = .INDZPG, .cycles = 5 };
        opcodes[0xD3] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xD4] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xD5] = instrInfo{ .mnemonic = .CMP, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0xD6] = instrInfo{ .mnemonic = .DEC, .address_mode = .ZPGX, .cycles = 6 };
        opcodes[0xD7] = instrInfo{ .mnemonic = .SMB5, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0xD8] = instrInfo{ .mnemonic = .CLD, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xD9] = instrInfo{ .mnemonic = .CMP, .address_mode = .ABSY, .cycles = 4 };
        opcodes[0xDA] = instrInfo{ .mnemonic = .PHX, .address_mode = .IMPL, .cycles = 3 };
        opcodes[0xDB] = instrInfo{ .mnemonic = .STP, .address_mode = .IMPL, .cycles = 3 };
        opcodes[0xDC] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xDD] = instrInfo{ .mnemonic = .CMP, .address_mode = .ABSX, .cycles = 4 };
        opcodes[0xDE] = instrInfo{ .mnemonic = .DEC, .address_mode = .ABSX, .cycles = 7 };
        opcodes[0xDF] = instrInfo{ .mnemonic = .BBS5, .address_mode = .ZPGREL, .cycles = 5 };

        // Row E_
        opcodes[0xE0] = instrInfo{ .mnemonic = .CPX, .address_mode = .IMM, .cycles = 2 };
        opcodes[0xE1] = instrInfo{ .mnemonic = .SBC, .address_mode = .XIND, .cycles = 6 };
        opcodes[0xE2] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xE3] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xE4] = instrInfo{ .mnemonic = .CPX, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0xE5] = instrInfo{ .mnemonic = .SBC, .address_mode = .ZPG, .cycles = 3 };
        opcodes[0xE6] = instrInfo{ .mnemonic = .INC, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0xE7] = instrInfo{ .mnemonic = .SMB6, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0xE8] = instrInfo{ .mnemonic = .INX, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xE9] = instrInfo{ .mnemonic = .SBC, .address_mode = .IMM, .cycles = 2 };
        opcodes[0xEA] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xEB] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xEC] = instrInfo{ .mnemonic = .CPX, .address_mode = .ABS, .cycles = 4 };
        opcodes[0xED] = instrInfo{ .mnemonic = .SBC, .address_mode = .ABS, .cycles = 4 };
        opcodes[0xEE] = instrInfo{ .mnemonic = .INC, .address_mode = .ABS, .cycles = 6 };
        opcodes[0xEF] = instrInfo{ .mnemonic = .BBS6, .address_mode = .ZPGREL, .cycles = 5 };

        // Row F_
        opcodes[0xF0] = instrInfo{ .mnemonic = .BEQ, .address_mode = .REL, .cycles = 2 };
        opcodes[0xF1] = instrInfo{ .mnemonic = .SBC, .address_mode = .INDY, .cycles = 5 };
        opcodes[0xF2] = instrInfo{ .mnemonic = .SBC, .address_mode = .INDZPG, .cycles = 5 };
        opcodes[0xF3] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xF4] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xF5] = instrInfo{ .mnemonic = .SBC, .address_mode = .ZPGX, .cycles = 4 };
        opcodes[0xF6] = instrInfo{ .mnemonic = .INC, .address_mode = .ZPGX, .cycles = 6 };
        opcodes[0xF7] = instrInfo{ .mnemonic = .SMB7, .address_mode = .ZPG, .cycles = 5 };
        opcodes[0xF8] = instrInfo{ .mnemonic = .SED, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xF9] = instrInfo{ .mnemonic = .SBC, .address_mode = .ABSY, .cycles = 4 };
        opcodes[0xFA] = instrInfo{ .mnemonic = .PLX, .address_mode = .IMPL, .cycles = 4 };
        opcodes[0xFB] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xFC] = instrInfo{ .mnemonic = .NOP, .address_mode = .IMPL, .cycles = 2 };
        opcodes[0xFD] = instrInfo{ .mnemonic = .SBC, .address_mode = .ABSX, .cycles = 4 };
        opcodes[0xFE] = instrInfo{ .mnemonic = .INC, .address_mode = .ABSX, .cycles = 7 };
        opcodes[0xFF] = instrInfo{ .mnemonic = .BBS7, .address_mode = .ZPGREL, .cycles = 5 };

        break :blk opcodes;
    };

    fn fetchInstruction(self: *@This()) void {
        self.current_opcode = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
    }

    fn fetchAbsolute(self: *@This()) u16 {
        const low_byte = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
        const high_byte = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
        return @as(u16, high_byte) << 8 | @as(u16, low_byte);
    }

    fn fetchAbsoluteX(self: *@This()) u16 {
        const base_addr = self.fetchAbsolute();
        return base_addr + @as(u16, self.x_register);
    }

    fn fetchAbsoluteY(self: *@This()) u16 {
        const base_addr = self.fetchAbsolute();
        return base_addr + @as(u16, self.y_register);
    }

    fn fetchImmediate(self: *@This()) u8 {
        const value = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
        return value;
    }

    fn fetchZeroPage(self: *@This()) u16 {
        const addr = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
        return @as(u16, addr);
    }

    fn fetchZeroPageX(self: *@This()) u16 {
        const base_addr = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
        return @as(u16, base_addr +% self.x_register);
    }

    fn fetchZeroPageY(self: *@This()) u16 {
        const base_addr = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
        return @as(u16, base_addr +% self.y_register);
    }

    fn fetchRelative(self: *@This()) u16 {
        const offset = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
        const current_pc = self.getPC();

        // Sign extend 8-bit offset to 16-bit
        const signed_offset = @as(i16, @as(i8, @bitCast(offset)));
        return @as(u16, @intCast(@as(i32, current_pc) +% signed_offset));
    }

    fn fetchIndirect(self: *@This()) u16 {
        const indirect_addr = self.fetchAbsolute();
        const low_byte = self.memory.read(indirect_addr);
        const high_byte = self.memory.read(indirect_addr + 1);
        return @as(u16, high_byte) << 8 | @as(u16, low_byte);
    }

    fn fetchIndirectX(self: *@This()) u16 {
        const base_addr = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
        const indirect_addr = @as(u16, base_addr + self.x_register);
        const low_byte = self.memory.read(indirect_addr);
        const high_byte = self.memory.read(indirect_addr + 1);
        return @as(u16, high_byte) << 8 | @as(u16, low_byte);
    }

    fn fetchIndirectY(self: *@This()) u16 {
        const base_addr = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
        const low_byte = self.memory.read(@as(u16, base_addr));
        const high_byte = self.memory.read(@as(u16, base_addr) + 1);
        const indirect_addr = @as(u16, high_byte) << 8 | @as(u16, low_byte);
        return indirect_addr +% @as(u16, self.y_register);
    }

    fn fetchZeroPageIndirect(self: *@This()) u16 {
        const base_addr = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
        const low_byte = self.memory.read(@as(u16, base_addr));
        const high_byte = self.memory.read(@as(u16, base_addr) + 1);
        return @as(u16, high_byte) << 8 | @as(u16, low_byte);
    }

    fn fetchAbsoluteIndexedIndirect(self: *@This()) u16 {
        const base_addr = self.fetchAbsolute() +% @as(u16, self.x_register);
        const low_byte = self.memory.read(base_addr);
        const high_byte = self.memory.read(base_addr + 1);
        return @as(u16, high_byte) << 8 | @as(u16, low_byte);
    }

    fn fetchZeroPageRelative(self: *@This()) ZeroPageRelative {
        // First byte: zero page address
        const zp_addr = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);

        // Second byte: relative offset
        const offset = self.memory.read(self.getPC());
        self.setPC(self.getPC() +% 1);
        const current_pc = self.getPC();

        // Sign extend 8-bit offset to 16-bit
        const signed_offset = @as(i16, @as(i8, @bitCast(offset)));
        const rel_addr = @as(u16, @bitCast(@as(i16, @as(i16, @bitCast(current_pc))) +% signed_offset));

        return .{ .zp_addr = zp_addr, .rel_addr = rel_addr };
    }

    // =============== UNIFIED OPERAND FETCHER ===============
    const ZeroPageRelative = struct { zp_addr: u8, rel_addr: u16 };

    pub const OperandResult = union(enum) {
        address_16: u16,
        immediate: u8,
        zpg_relative: ZeroPageRelative,
    };

    fn fetchOperand(self: *@This(), mode: AddressingMode) OperandResult {
        return switch (mode) {
            .ACC => OperandResult{ .immediate = 0 }, // Accumulator mode doesn't fetch operand
            .ABS => OperandResult{ .address_16 = self.fetchAbsolute() },
            .ABSX => OperandResult{ .address_16 = self.fetchAbsoluteX() },
            .ABSY => OperandResult{ .address_16 = self.fetchAbsoluteY() },
            .IMM => OperandResult{ .immediate = self.fetchImmediate() },
            .IMPL => OperandResult{ .immediate = 0 }, // Implied mode doesn't fetch operand
            .IND => OperandResult{ .address_16 = self.fetchIndirect() },
            .XIND => OperandResult{ .address_16 = self.fetchIndirectX() },
            .INDY => OperandResult{ .address_16 = self.fetchIndirectY() },
            .REL => OperandResult{ .address_16 = self.fetchRelative() },
            .ZPG => OperandResult{ .address_16 = self.fetchZeroPage() },
            .ZPGX => OperandResult{ .address_16 = self.fetchZeroPageX() },
            .ZPGY => OperandResult{ .address_16 = self.fetchZeroPageY() },
            .INDZPG => OperandResult{ .address_16 = self.fetchZeroPageIndirect() },
            .ABSXIND => OperandResult{ .address_16 = self.fetchAbsoluteIndexedIndirect() },
            .ZPGREL => blk: {
                const result = self.fetchZeroPageRelative();
                break :blk OperandResult{ .zpg_relative = result };
            },
        };
    }

    fn getOperandValue(self: *@This(), mode: AddressingMode) u8 {
        const operand_result = self.fetchOperand(mode);

        switch (operand_result) {
            .immediate => |value| {
                return value;
            },
            .address_16 => |addr| {
                return self.memory.read(addr);
            },
            else => unreachable, // Most instructions don't use zpg_relative mode
        }
    }

    // =============== INSTRUCTION EXECUTE ===============
    // Returns 64-bit cycle count
    fn executeADC(self: *@This(), mode: AddressingMode) u64 {
        var base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            .ABSX => 4,
            .ABSY => 4,
            .XIND => 6,
            .INDY => 5,
            .INDZPG => 5,
            else => unreachable,
        };

        var page_crossed = false;
        const operand = switch (mode) {
            .ABSX => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.x_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .ABSY => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .INDY => blk: {
                const base_addr = self.memory.read(self.getPC());
                self.setPC(self.getPC() + 1);
                const low_byte = self.memory.read(@as(u16, base_addr));
                const high_byte = self.memory.read(@as(u16, base_addr) + 1);
                const indirect_addr = @as(u16, high_byte) << 8 | @as(u16, low_byte);
                const final_addr = indirect_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(indirect_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            else => self.fetchOperand(mode),
        };

        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };
        const carry_in = if (self.status_register.carry) @as(u16, 1) else 0;
        const tmp_value: u16 = @as(u16, self.accumulator) +% @as(u16, value) +% carry_in;
        const result: u8 = @truncate(tmp_value);

        self.status_register.carry = tmp_value > 0xFF;

        const a_sign = self.accumulator & 0x80;
        const v_sign = value & 0x80;
        const r_sign = result & 0x80;
        self.status_register.overflow = (a_sign == v_sign) and (a_sign != r_sign);

        self.accumulator = result;
        self.updateNZ(self.accumulator);

        if (page_crossed) {
            base_cycles += 1;
        }

        return base_cycles;
    }

    fn executeAND(self: *@This(), mode: AddressingMode) u64 {
        var base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            .ABSX => 4,
            .ABSY => 4,
            .XIND => 6,
            .INDY => 5,
            .INDZPG => 5,
            else => unreachable,
        };

        var page_crossed = false;
        const operand = switch (mode) {
            .ABSX => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.x_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .ABSY => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .INDY => blk: {
                const base_addr = self.memory.read(self.getPC());
                self.setPC(self.getPC() + 1);
                const low_byte = self.memory.read(@as(u16, base_addr));
                const high_byte = self.memory.read(@as(u16, base_addr) + 1);
                const indirect_addr = @as(u16, high_byte) << 8 | @as(u16, low_byte);
                const final_addr = indirect_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(indirect_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            else => self.fetchOperand(mode),
        };

        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };
        self.accumulator &= value;
        self.updateNZ(self.accumulator);

        if (page_crossed) {
            base_cycles += 1;
        }

        return base_cycles;
    }

    fn executeASL(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ACC => 2,
            .ZPG => 5,
            .ZPGX => 6,
            .ABS => 6,
            .ABSX => 7,
            else => unreachable,
        };

        switch (mode) {
            .ACC => {
                self.status_register.carry = (self.accumulator & 0x80) != 0;
                self.accumulator <<= 1;
                self.updateNZ(self.accumulator);
            },
            else => {
                const operand = self.fetchOperand(mode);
                const addr = switch (operand) {
                    .address_16 => |addr| addr,
                    else => unreachable,
                };

                const value = self.memory.read(addr);
                self.status_register.carry = (value & 0x80) != 0;
                const result = value << 1;
                self.memory.write(addr, result);
                self.updateNZ(result);
            },
        }
        return base_cycles;
    }

    fn executeBCC(self: *@This(), mode: AddressingMode) u64 {
        const operand = self.fetchOperand(mode);
        const target_addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        if (!self.status_register.carry) {
            const current_pc = self.getPC();
            self.setPC(target_addr);

            return if (self.isPageCrossed(current_pc, target_addr)) 4 else 3;
        }
        return 2;
    }

    fn executeBCS(self: *@This(), mode: AddressingMode) u64 {
        const operand = self.fetchOperand(mode);
        const target_addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        if (self.status_register.carry) {
            const current_pc = self.getPC();
            self.setPC(target_addr);

            return if (self.isPageCrossed(current_pc, target_addr)) 4 else 3;
        }
        return 2;
    }

    fn executeBEQ(self: *@This(), mode: AddressingMode) u64 {
        const operand = self.fetchOperand(mode);
        const target_addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        if (self.status_register.zero) {
            const current_pc = self.getPC();
            self.setPC(target_addr);

            return if (self.isPageCrossed(current_pc, target_addr)) 4 else 3;
        }
        return 2;
    }

    fn executeBIT(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            .ABSX => 4,
            else => unreachable,
        };

        const operand = self.fetchOperand(mode);
        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };

        const result = self.accumulator & value;

        if (mode == .IMM) {
            self.status_register.zero = (result == 0);
        } else {
            self.status_register.zero = (result == 0);
            self.status_register.negative = (value & 0x80) != 0; // Memory value bit 7
            self.status_register.overflow = (value & 0x40) != 0; // Memory value bit 6
        }

        return base_cycles;
    }

    fn executeBMI(self: *@This(), mode: AddressingMode) u64 {
        const operand = self.fetchOperand(mode);
        const target_addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        if (self.status_register.negative) {
            const current_pc = self.getPC();
            self.setPC(target_addr);

            return if (self.isPageCrossed(current_pc, target_addr)) 4 else 3;
        }
        return 2;
    }

    fn executeBNE(self: *@This(), mode: AddressingMode) u64 {
        const operand = self.fetchOperand(mode);
        const target_addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        if (!self.status_register.zero) {
            const current_pc = self.getPC();
            self.setPC(target_addr);

            return if (self.isPageCrossed(current_pc, target_addr)) 4 else 3;
        }
        return 2;
    }

    fn executeBPL(self: *@This(), mode: AddressingMode) u64 {
        const operand = self.fetchOperand(mode);
        const target_addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        if (!self.status_register.negative) {
            const current_pc = self.getPC();
            self.setPC(target_addr);

            return if (self.isPageCrossed(current_pc, target_addr)) 4 else 3;
        }
        return 2;
    }

    fn executeBRK(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        const return_pc = self.getPC() + 1;
        self.stackPush(@as(u8, @truncate(return_pc >> 8))); // PCH
        self.stackPush(@as(u8, @truncate(return_pc))); // PCL

        var status_with_break = self.status_register.toByte();
        status_with_break |= 0x10;
        self.stackPush(status_with_break);

        self.status_register.intmask = true;

        const irq_vector_low = self.memory.read(IRQVector);
        const irq_vector_high = self.memory.read(IRQVector + 1);
        const irq_vector = @as(u16, irq_vector_high) << 8 | @as(u16, irq_vector_low);
        self.setPC(irq_vector);

        return 7;
    }

    fn executeBVC(self: *@This(), mode: AddressingMode) u64 {
        const operand = self.fetchOperand(mode);
        const target_addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        if (!self.status_register.overflow) {
            const current_pc = self.getPC();
            self.setPC(target_addr);

            return if (self.isPageCrossed(current_pc, target_addr)) 4 else 3;
        }
        return 2;
    }

    fn executeBVS(self: *@This(), mode: AddressingMode) u64 {
        const operand = self.fetchOperand(mode);
        const target_addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        if (self.status_register.overflow) {
            const current_pc = self.getPC();
            self.setPC(target_addr);

            return if (self.isPageCrossed(current_pc, target_addr)) 4 else 3;
        }
        return 2;
    }

    fn executeCLC(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.status_register.carry = false;
        return 2;
    }

    fn executeCLD(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.status_register.decimal = false;
        return 2;
    }

    fn executeCLI(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.status_register.intmask = false;
        return 2;
    }

    fn executeCLV(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.status_register.overflow = false;
        return 2;
    }

    fn executeCMP(self: *@This(), mode: AddressingMode) u64 {
        var base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            .ABSX => 4,
            .ABSY => 4,
            .XIND => 6,
            .INDY => 5,
            .INDZPG => 5,
            else => unreachable,
        };

        var page_crossed = false;
        const operand = switch (mode) {
            .ABSX => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.x_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .ABSY => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .INDY => blk: {
                const base_addr = self.memory.read(self.getPC());
                self.setPC(self.getPC() + 1);
                const low_byte = self.memory.read(@as(u16, base_addr));
                const high_byte = self.memory.read(@as(u16, base_addr) + 1);
                const indirect_addr = @as(u16, high_byte) << 8 | @as(u16, low_byte);
                const final_addr = indirect_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(indirect_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            else => self.fetchOperand(mode),
        };

        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };

        const result = self.accumulator -% value;

        self.status_register.carry = self.accumulator >= value;
        self.status_register.zero = (result == 0);
        self.status_register.negative = (result & 0x80) != 0;

        if (page_crossed) {
            base_cycles += 1;
        }

        return base_cycles;
    }

    fn executeCPX(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ABS => 4,
            else => unreachable,
        };

        const operand = self.fetchOperand(mode);
        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };

        // X register - value
        const result = self.x_register -% value;

        self.status_register.carry = self.x_register >= value;
        self.status_register.zero = (result == 0);
        self.status_register.negative = (result & 0x80) != 0;

        return base_cycles;
    }

    fn executeCPY(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ABS => 4,
            else => unreachable,
        };

        const operand = self.fetchOperand(mode);
        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };

        // Y register - value
        const result = self.y_register -% value;

        self.status_register.carry = self.y_register >= value;
        self.status_register.zero = (result == 0);
        self.status_register.negative = (result & 0x80) != 0;

        return base_cycles;
    }

    fn executeDEC(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ACC => 2,
            .ZPG => 5,
            .ZPGX => 6,
            .ABS => 6,
            .ABSX => 7,
            else => unreachable,
        };

        switch (mode) {
            .ACC => {
                self.accumulator -%= 1;
                self.updateNZ(self.accumulator);
            },
            else => {
                const operand = self.fetchOperand(mode);
                const addr = switch (operand) {
                    .address_16 => |addr| addr,
                    else => unreachable,
                };

                const value = self.memory.read(addr);
                const result = value -% 1;
                self.memory.write(addr, result);
                self.updateNZ(result);
            },
        }

        return base_cycles;
    }

    fn executeDEX(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        self.x_register -%= 1;
        self.updateNZ(self.x_register);

        return 2;
    }

    fn executeDEY(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        self.y_register -%= 1;
        self.updateNZ(self.y_register);

        return 2;
    }

    fn executeEOR(self: *@This(), mode: AddressingMode) u64 {
        var base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            .ABSX => 4,
            .ABSY => 4,
            .XIND => 6,
            .INDY => 5,
            .INDZPG => 5,
            else => unreachable,
        };

        var page_crossed = false;
        const operand = switch (mode) {
            .ABSX => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.x_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .ABSY => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .INDY => blk: {
                const base_addr = self.memory.read(self.getPC());
                self.setPC(self.getPC() + 1);
                const low_byte = self.memory.read(@as(u16, base_addr));
                const high_byte = self.memory.read(@as(u16, base_addr) + 1);
                const indirect_addr = @as(u16, high_byte) << 8 | @as(u16, low_byte);
                const final_addr = indirect_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(indirect_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            else => self.fetchOperand(mode),
        };

        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };

        self.accumulator ^= value;
        self.updateNZ(self.accumulator);

        if (page_crossed) {
            base_cycles += 1;
        }

        return base_cycles;
    }

    fn executeINC(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ACC => 2,
            .ZPG => 5,
            .ZPGX => 6,
            .ABS => 6,
            .ABSX => 7,
            else => unreachable,
        };

        switch (mode) {
            .ACC => {
                self.accumulator +%= 1;
                self.updateNZ(self.accumulator);
            },
            else => {
                const operand = self.fetchOperand(mode);
                const addr = switch (operand) {
                    .address_16 => |addr| addr,
                    else => unreachable,
                };

                const value = self.memory.read(addr);
                const result = value +% 1;
                self.memory.write(addr, result);
                self.updateNZ(result);
            },
        }

        return base_cycles;
    }

    fn executeINX(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        self.x_register +%= 1;
        self.updateNZ(self.x_register);

        return 2;
    }

    fn executeINY(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        self.y_register +%= 1;
        self.updateNZ(self.y_register);

        return 2;
    }

    fn executeJMP(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ABS => 3,
            .IND => 6,
            .ABSXIND => 6,
            else => unreachable,
        };

        const operand = self.fetchOperand(mode);
        const target_addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        self.setPC(target_addr);

        return base_cycles;
    }

    fn executeJSR(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        const return_addr = self.getPC() + 1;

        const target_addr = self.fetchAbsolute();

        self.stackPush(@as(u8, @truncate(return_addr >> 8))); // PCH
        self.stackPush(@as(u8, @truncate(return_addr))); // PCL

        self.setPC(target_addr);

        return 6;
    }

    fn executeLDA(self: *@This(), mode: AddressingMode) u64 {
        var base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            .ABSX => 4,
            .ABSY => 4,
            .XIND => 6,
            .INDY => 5,
            .INDZPG => 5,
            else => unreachable,
        };

        var page_crossed = false;
        const operand = switch (mode) {
            .ABSX => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.x_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .ABSY => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .INDY => blk: {
                const base_addr = self.memory.read(self.getPC());
                self.setPC(self.getPC() + 1);
                const low_byte = self.memory.read(@as(u16, base_addr));
                const high_byte = self.memory.read(@as(u16, base_addr) + 1);
                const indirect_addr = @as(u16, high_byte) << 8 | @as(u16, low_byte);
                const final_addr = indirect_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(indirect_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            else => self.fetchOperand(mode),
        };

        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };

        self.accumulator = value;
        self.updateNZ(self.accumulator);

        if (page_crossed) {
            base_cycles += 1;
        }

        return base_cycles;
    }

    fn executeLDX(self: *@This(), mode: AddressingMode) u64 {
        var base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ZPGY => 4,
            .ABS => 4,
            .ABSY => 4,
            else => unreachable,
        };

        var page_crossed = false;
        const operand = switch (mode) {
            .ABSY => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            else => self.fetchOperand(mode),
        };

        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };

        self.x_register = value;
        self.updateNZ(self.x_register);

        if (page_crossed) {
            base_cycles += 1;
        }

        return base_cycles;
    }

    fn executeLDY(self: *@This(), mode: AddressingMode) u64 {
        var base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            .ABSX => 4,
            else => unreachable,
        };

        var page_crossed = false;
        const operand = switch (mode) {
            .ABSX => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.x_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            else => self.fetchOperand(mode),
        };

        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };

        self.y_register = value;
        self.updateNZ(self.y_register);

        if (page_crossed) {
            base_cycles += 1;
        }

        return base_cycles;
    }

    fn executeLSR(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ACC => 2,
            .ZPG => 5,
            .ZPGX => 6,
            .ABS => 6,
            .ABSX => 7,
            else => unreachable,
        };

        switch (mode) {
            .ACC => {
                self.status_register.carry = (self.accumulator & 0x01) != 0;
                self.accumulator >>= 1;
                self.updateNZ(self.accumulator);
            },
            else => {
                const operand = self.fetchOperand(mode);
                const addr = switch (operand) {
                    .address_16 => |addr| addr,
                    else => unreachable,
                };

                const value = self.memory.read(addr);
                self.status_register.carry = (value & 0x01) != 0;
                const result = value >> 1;
                self.memory.write(addr, result);
                self.updateNZ(result);
            },
        }
        return base_cycles;
    }

    fn executeNOP(self: *@This(), mode: AddressingMode) u64 {
        _ = self;
        _ = mode;

        return 2;
    }

    fn executeORA(self: *@This(), mode: AddressingMode) u64 {
        var base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            .ABSX => 4,
            .ABSY => 4,
            .XIND => 6,
            .INDY => 5,
            .INDZPG => 5,
            else => unreachable,
        };

        var page_crossed = false;
        const operand = switch (mode) {
            .ABSX => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.x_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .ABSY => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .INDY => blk: {
                const base_addr = self.memory.read(self.getPC());
                self.setPC(self.getPC() + 1);
                const low_byte = self.memory.read(@as(u16, base_addr));
                const high_byte = self.memory.read(@as(u16, base_addr) + 1);
                const indirect_addr = @as(u16, high_byte) << 8 | @as(u16, low_byte);
                const final_addr = indirect_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(indirect_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            else => self.fetchOperand(mode),
        };

        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };

        self.accumulator |= value;
        self.updateNZ(self.accumulator);

        if (page_crossed) {
            base_cycles += 1;
        }

        return base_cycles;
    }

    fn executePHA(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        self.stackPush(self.accumulator);

        return 3;
    }

    fn executePHP(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        self.stackPush(self.status_register.toByte());

        return 3;
    }

    fn executePLA(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        self.accumulator = self.stackPop();
        self.updateNZ(self.accumulator);

        return 4;
    }

    fn executePLP(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        self.status_register = StatusRegister.fromByte(self.stackPop());

        return 4;
    }

    fn executeROL(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ACC => 2,
            .ZPG => 5,
            .ZPGX => 6,
            .ABS => 6,
            .ABSX => 7,
            else => unreachable,
        };

        switch (mode) {
            .ACC => {
                const old_carry = if (self.status_register.carry) @as(u8, 1) else 0;
                self.status_register.carry = (self.accumulator & 0x80) != 0;
                self.accumulator = (self.accumulator << 1) | old_carry;
                self.updateNZ(self.accumulator);
            },
            else => {
                const operand = self.fetchOperand(mode);
                const addr = switch (operand) {
                    .address_16 => |addr| addr,
                    else => unreachable,
                };

                const value = self.memory.read(addr);
                const old_carry = if (self.status_register.carry) @as(u8, 1) else 0;
                self.status_register.carry = (value & 0x80) != 0;
                const result = (value << 1) | old_carry;
                self.memory.write(addr, result);
                self.updateNZ(result);
            },
        }

        return base_cycles;
    }

    fn executeROR(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ACC => 2,
            .ZPG => 5,
            .ZPGX => 6,
            .ABS => 6,
            .ABSX => 7,
            else => unreachable,
        };

        switch (mode) {
            .ACC => {
                const old_carry = if (self.status_register.carry) @as(u8, 0x80) else 0;
                self.status_register.carry = (self.accumulator & 0x01) != 0;
                self.accumulator = (self.accumulator >> 1) | old_carry;
                self.updateNZ(self.accumulator);
            },
            else => {
                const operand = self.fetchOperand(mode);
                const addr = switch (operand) {
                    .address_16 => |addr| addr,
                    else => unreachable,
                };

                const value = self.memory.read(addr);
                const old_carry = if (self.status_register.carry) @as(u8, 0x80) else 0;
                self.status_register.carry = (value & 0x01) != 0;
                const result = (value >> 1) | old_carry;
                self.memory.write(addr, result);
                self.updateNZ(result);
            },
        }

        return base_cycles;
    }

    fn executeRTI(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        const status = self.stackPop();
        self.status_register = StatusRegister.fromByte(status);

        const pcl = self.stackPop();
        const pch = self.stackPop();
        self.setPC(@as(u16, pch) << 8 | @as(u16, pcl));

        return 6;
    }

    fn executeRTS(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;

        const pcl = self.stackPop();
        const pch = self.stackPop();
        const return_addr = @as(u16, pch) << 8 | @as(u16, pcl);

        self.setPC(return_addr + 1);

        return 6;
    }

    fn executeSBC(self: *@This(), mode: AddressingMode) u64 {
        var base_cycles: u64 = switch (mode) {
            .IMM => 2,
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            .ABSX => 4,
            .ABSY => 4,
            .XIND => 6,
            .INDY => 5,
            .INDZPG => 5,
            else => unreachable,
        };

        var page_crossed = false;
        const operand = switch (mode) {
            .ABSX => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.x_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .ABSY => blk: {
                const base_addr = self.fetchAbsolute();
                const final_addr = base_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(base_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            .INDY => blk: {
                const base_addr = self.memory.read(self.getPC());
                self.setPC(self.getPC() + 1);
                const low_byte = self.memory.read(@as(u16, base_addr));
                const high_byte = self.memory.read(@as(u16, base_addr) + 1);
                const indirect_addr = @as(u16, high_byte) << 8 | @as(u16, low_byte);
                const final_addr = indirect_addr +% @as(u16, self.y_register);
                page_crossed = self.isPageCrossed(indirect_addr, final_addr);
                break :blk OperandResult{ .address_16 = final_addr };
            },
            else => self.fetchOperand(mode),
        };

        const value = switch (operand) {
            .immediate => |value| value,
            .address_16 => |addr| self.memory.read(addr),
            else => unreachable,
        };

        const carry_in = if (self.status_register.carry) @as(u16, 0) else 1;
        const tmp_value: u16 = @as(u16, self.accumulator) -% @as(u16, value) -% carry_in;
        const result: u8 = @truncate(tmp_value);

        self.status_register.carry = tmp_value <= 0xFF; // No borrow means carry = 1

        const a_sign = self.accumulator & 0x80;
        const v_sign = value & 0x80;
        const r_sign = result & 0x80;
        self.status_register.overflow = (a_sign != v_sign) and (a_sign != r_sign);

        self.accumulator = result;
        self.updateNZ(self.accumulator);

        if (page_crossed) {
            base_cycles += 1;
        }

        return base_cycles;
    }

    fn executeSEC(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.status_register.carry = true;
        return 2;
    }

    fn executeSED(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.status_register.decimal = true;
        return 2;
    }

    fn executeSEI(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.status_register.intmask = true;
        return 2;
    }

    fn executeSTA(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            .ABSX => 5,
            .ABSY => 5,
            .XIND => 6,
            .INDY => 6,
            .INDZPG => 5,
            else => unreachable,
        };

        const operand = self.fetchOperand(mode);
        const addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        self.memory.write(addr, self.accumulator);

        return base_cycles;
    }

    fn executeSTX(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ZPG => 3,
            .ZPGY => 4,
            .ABS => 4,
            else => unreachable,
        };

        const operand = self.fetchOperand(mode);
        const addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        self.memory.write(addr, self.x_register);
        return base_cycles;
    }

    fn executeSTY(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            else => unreachable,
        };

        const operand = self.fetchOperand(mode);
        const addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        self.memory.write(addr, self.y_register);
        return base_cycles;
    }

    fn executeTAX(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.x_register = self.accumulator;
        self.updateNZ(self.x_register);
        return 2;
    }

    fn executeTAY(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.y_register = self.accumulator;
        self.updateNZ(self.y_register);
        return 2;
    }

    fn executeTSX(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.x_register = self.stack_pointer;
        self.updateNZ(self.x_register);
        return 2;
    }

    fn executeTXA(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.accumulator = self.x_register;
        self.updateNZ(self.accumulator);
        return 2;
    }

    fn executeTXS(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.stack_pointer = self.x_register;
        return 2;
    }

    fn executeTYA(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.accumulator = self.y_register;
        self.updateNZ(self.accumulator);
        return 2;
    }

    // 65C02 additional instructions
    fn executeBBR(self: *@This(), bit_num: u3, mode: AddressingMode) u64 {
        var base_cycles: u64 = 5;

        const operand = self.fetchOperand(mode); // ZPGREL mode
        const zp_rel = switch (operand) {
            .zpg_relative => |data| data,
            else => unreachable,
        };

        const value = self.memory.read(@as(u16, zp_rel.zp_addr));
        const bit_mask: u8 = @as(u8, 1) << bit_num;

        if ((value & bit_mask) == 0) {
            const current_pc = self.getPC();

            base_cycles += 1;

            if (self.isPageCrossed(current_pc, zp_rel.rel_addr)) {
                base_cycles += 1;
            }

            self.setPC(zp_rel.rel_addr);
        }

        return base_cycles;
    }

    fn executeBBR0(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBR(0, mode);
    }

    fn executeBBR1(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBR(1, mode);
    }

    fn executeBBR2(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBR(2, mode);
    }

    fn executeBBR3(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBR(3, mode);
    }

    fn executeBBR4(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBR(4, mode);
    }

    fn executeBBR5(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBR(5, mode);
    }

    fn executeBBR6(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBR(6, mode);
    }

    fn executeBBR7(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBR(7, mode);
    }

    fn executeBBS(self: *@This(), bit_num: u3, mode: AddressingMode) u64 {
        var base_cycles: u64 = 5;

        const operand = self.fetchOperand(mode); // ZPGREL mode
        const zp_rel = switch (operand) {
            .zpg_relative => |data| data,
            else => unreachable,
        };

        const value = self.memory.read(@as(u16, zp_rel.zp_addr));
        const bit_mask: u8 = @as(u8, 1) << bit_num;

        if ((value & bit_mask) != 0) {
            const current_pc = self.getPC();

            base_cycles += 1;

            if (self.isPageCrossed(current_pc, zp_rel.rel_addr)) {
                base_cycles += 1;
            }

            self.setPC(zp_rel.rel_addr);
        }

        return base_cycles;
    }

    fn executeBBS0(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBS(0, mode);
    }

    fn executeBBS1(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBS(1, mode);
    }

    fn executeBBS2(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBS(2, mode);
    }

    fn executeBBS3(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBS(3, mode);
    }

    fn executeBBS4(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBS(4, mode);
    }

    fn executeBBS5(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBS(5, mode);
    }

    fn executeBBS6(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBS(6, mode);
    }

    fn executeBBS7(self: *@This(), mode: AddressingMode) u64 {
        return self.executeBBS(7, mode);
    }

    fn executeBRA(self: *@This(), mode: AddressingMode) u64 {
        var base_cycles: u64 = 3;

        const operand = self.fetchOperand(mode);
        const target_addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        const current_pc = self.getPC();

        if (self.isPageCrossed(current_pc, target_addr)) {
            base_cycles += 1;
        }

        self.setPC(target_addr);

        return base_cycles;
    }

    fn executePHX(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.stackPush(self.x_register);
        return 3;
    }

    fn executePHY(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.stackPush(self.y_register);
        return 3;
    }

    fn executePLX(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.x_register = self.stackPop();
        return 4;
    }

    fn executePLY(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.y_register = self.stackPop();
        return 4;
    }

    fn executeRMB(self: *@This(), bit_num: u3, mode: AddressingMode) u64 {
        const operand = self.fetchOperand(mode); // Only ZPG mode used
        const addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        const value = self.memory.read(addr);

        const bit_mask: u8 = ~(@as(u8, 1) << bit_num);
        const result = value & bit_mask;

        self.memory.write(addr, result);

        return 5;
    }

    fn executeRMB0(self: *@This(), mode: AddressingMode) u64 {
        return self.executeRMB(0, mode);
    }

    fn executeRMB1(self: *@This(), mode: AddressingMode) u64 {
        return self.executeRMB(1, mode);
    }

    fn executeRMB2(self: *@This(), mode: AddressingMode) u64 {
        return self.executeRMB(2, mode);
    }

    fn executeRMB3(self: *@This(), mode: AddressingMode) u64 {
        return self.executeRMB(3, mode);
    }

    fn executeRMB4(self: *@This(), mode: AddressingMode) u64 {
        return self.executeRMB(4, mode);
    }

    fn executeRMB5(self: *@This(), mode: AddressingMode) u64 {
        return self.executeRMB(5, mode);
    }

    fn executeRMB6(self: *@This(), mode: AddressingMode) u64 {
        return self.executeRMB(6, mode);
    }

    fn executeRMB7(self: *@This(), mode: AddressingMode) u64 {
        return self.executeRMB(7, mode);
    }

    fn executeSMB(self: *@This(), bit_num: u3, mode: AddressingMode) u64 {
        const operand = self.fetchOperand(mode); // Only ZPG mode used
        const addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        const value = self.memory.read(addr);

        const bit_mask: u8 = @as(u8, 1) << bit_num;
        const result = value | bit_mask;

        self.memory.write(addr, result);

        return 5;
    }

    fn executeSMB0(self: *@This(), mode: AddressingMode) u64 {
        return self.executeSMB(0, mode);
    }

    fn executeSMB1(self: *@This(), mode: AddressingMode) u64 {
        return self.executeSMB(1, mode);
    }

    fn executeSMB2(self: *@This(), mode: AddressingMode) u64 {
        return self.executeSMB(2, mode);
    }

    fn executeSMB3(self: *@This(), mode: AddressingMode) u64 {
        return self.executeSMB(3, mode);
    }

    fn executeSMB4(self: *@This(), mode: AddressingMode) u64 {
        return self.executeSMB(4, mode);
    }

    fn executeSMB5(self: *@This(), mode: AddressingMode) u64 {
        return self.executeSMB(5, mode);
    }

    fn executeSMB6(self: *@This(), mode: AddressingMode) u64 {
        return self.executeSMB(6, mode);
    }

    fn executeSMB7(self: *@This(), mode: AddressingMode) u64 {
        return self.executeSMB(7, mode);
    }

    fn executeSTP(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.STP = true;
        return 4;
    }

    fn executeSTZ(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ZPG => 3,
            .ZPGX => 4,
            .ABS => 4,
            .ABSX => 5,
            else => unreachable,
        };

        const operand = self.fetchOperand(mode);
        const addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        self.memory.write(addr, 0);

        return base_cycles;
    }

    fn executeTRB(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ZPG => 5,
            .ABS => 6,
            else => unreachable,
        };

        const operand = self.fetchOperand(mode);
        const addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        const value = self.memory.read(addr);

        const test_result = self.accumulator & value;
        self.status_register.zero = (test_result == 0);

        const cleared_value = value & (~self.accumulator);
        self.memory.write(addr, cleared_value);

        return base_cycles;
    }

    fn executeTSB(self: *@This(), mode: AddressingMode) u64 {
        const base_cycles: u64 = switch (mode) {
            .ZPG => 5,
            .ABS => 6,
            else => unreachable,
        };

        const operand = self.fetchOperand(mode);
        const addr = switch (operand) {
            .address_16 => |addr| addr,
            else => unreachable,
        };

        const value = self.memory.read(addr);

        const test_result = self.accumulator & value;
        self.status_register.zero = (test_result == 0);

        const set_value = value | self.accumulator;
        self.memory.write(addr, set_value);

        return base_cycles;
    }

    fn executeWAI(self: *@This(), mode: AddressingMode) u64 {
        _ = mode;
        self.WAIT = true;
        return 3;
    }

    fn executeInstruction(self: *@This(), mnemonic: mnemonic65C02, mode: AddressingMode) u64 {
        return switch (mnemonic) {
            .ADC => self.executeADC(mode),
            .AND => self.executeAND(mode),
            .ASL => self.executeASL(mode),
            .BCC => self.executeBCC(mode),
            .BCS => self.executeBCS(mode),
            .BEQ => self.executeBEQ(mode),
            .BIT => self.executeBIT(mode),
            .BMI => self.executeBMI(mode),
            .BNE => self.executeBNE(mode),
            .BPL => self.executeBPL(mode),
            .BRK => self.executeBRK(mode),
            .BVC => self.executeBVC(mode),
            .BVS => self.executeBVS(mode),
            .CLC => self.executeCLC(mode),
            .CLD => self.executeCLD(mode),
            .CLI => self.executeCLI(mode),
            .CLV => self.executeCLV(mode),
            .CMP => self.executeCMP(mode),
            .CPX => self.executeCPX(mode),
            .CPY => self.executeCPY(mode),
            .DEC => self.executeDEC(mode),
            .DEX => self.executeDEX(mode),
            .DEY => self.executeDEY(mode),
            .EOR => self.executeEOR(mode),
            .INC => self.executeINC(mode),
            .INX => self.executeINX(mode),
            .INY => self.executeINY(mode),
            .JMP => self.executeJMP(mode),
            .JSR => self.executeJSR(mode),
            .LDA => self.executeLDA(mode),
            .LDX => self.executeLDX(mode),
            .LDY => self.executeLDY(mode),
            .LSR => self.executeLSR(mode),
            .NOP => self.executeNOP(mode),
            .ORA => self.executeORA(mode),
            .PHA => self.executePHA(mode),
            .PHP => self.executePHP(mode),
            .PLA => self.executePLA(mode),
            .PLP => self.executePLP(mode),
            .ROL => self.executeROL(mode),
            .ROR => self.executeROR(mode),
            .RTI => self.executeRTI(mode),
            .RTS => self.executeRTS(mode),
            .SBC => self.executeSBC(mode),
            .SEC => self.executeSEC(mode),
            .SED => self.executeSED(mode),
            .SEI => self.executeSEI(mode),
            .STA => self.executeSTA(mode),
            .STX => self.executeSTX(mode),
            .STY => self.executeSTY(mode),
            .TAX => self.executeTAX(mode),
            .TAY => self.executeTAY(mode),
            .TSX => self.executeTSX(mode),
            .TXA => self.executeTXA(mode),
            .TXS => self.executeTXS(mode),
            .TYA => self.executeTYA(mode),
            // 65C02 additional instructions
            .BBR0 => self.executeBBR0(mode),
            .BBR1 => self.executeBBR1(mode),
            .BBR2 => self.executeBBR2(mode),
            .BBR3 => self.executeBBR3(mode),
            .BBR4 => self.executeBBR4(mode),
            .BBR5 => self.executeBBR5(mode),
            .BBR6 => self.executeBBR6(mode),
            .BBR7 => self.executeBBR7(mode),
            .BBS0 => self.executeBBS0(mode),
            .BBS1 => self.executeBBS1(mode),
            .BBS2 => self.executeBBS2(mode),
            .BBS3 => self.executeBBS3(mode),
            .BBS4 => self.executeBBS4(mode),
            .BBS5 => self.executeBBS5(mode),
            .BBS6 => self.executeBBS6(mode),
            .BBS7 => self.executeBBS7(mode),
            .BRA => self.executeBRA(mode),
            .PHX => self.executePHX(mode),
            .PHY => self.executePHY(mode),
            .PLX => self.executePLX(mode),
            .PLY => self.executePLY(mode),
            .RMB0 => self.executeRMB0(mode),
            .RMB1 => self.executeRMB1(mode),
            .RMB2 => self.executeRMB2(mode),
            .RMB3 => self.executeRMB3(mode),
            .RMB4 => self.executeRMB4(mode),
            .RMB5 => self.executeRMB5(mode),
            .RMB6 => self.executeRMB6(mode),
            .RMB7 => self.executeRMB7(mode),
            .SMB0 => self.executeSMB0(mode),
            .SMB1 => self.executeSMB1(mode),
            .SMB2 => self.executeSMB2(mode),
            .SMB3 => self.executeSMB3(mode),
            .SMB4 => self.executeSMB4(mode),
            .SMB5 => self.executeSMB5(mode),
            .SMB6 => self.executeSMB6(mode),
            .SMB7 => self.executeSMB7(mode),
            .STP => self.executeSTP(mode),
            .STZ => self.executeSTZ(mode),
            .TRB => self.executeTRB(mode),
            .TSB => self.executeTSB(mode),
            .WAI => self.executeWAI(mode),
        };
    }

    /// Execute a single instruction and return cycle count
    /// Returns 0 if CPU is halted (STP) or waiting (WAI)
    pub fn step(self: *@This()) u64 {
        // Check if CPU is halted by STP instruction
        if (self.STP) {
            return 0;
        }

        // Check if CPU is waiting for interrupt (WAI instruction)
        if (self.WAIT) {
            return 0;
        }

        // Fetch instruction from memory
        self.fetchInstruction();

        // Get instruction information from opcode table
        const instruction_info = opcode65C02[self.current_opcode];

        // Execute the instruction
        const cycles = self.executeInstruction(instruction_info.mnemonic, instruction_info.address_mode);

        // Update total cycle count
        self.cycles += cycles;

        return cycles;
    }

    /// Run CPU continuously until halted or waiting
    /// Exits when STP instruction is executed or WAI instruction is executed
    /// Use NMI() or interrupt() to wake up from WAI state
    pub fn run(self: *@This()) void {
        while (true) {
            // Check if CPU is halted by STP instruction
            if (self.STP) {
                break;
            }

            // Check if CPU is waiting for interrupt (WAI instruction)
            if (self.WAIT) {
                // CPU is waiting for interrupt - external code should call
                // NMI() or interrupt() to wake up the CPU
                continue;
            }

            // Execute single instruction
            const cycles = self.step();

            // If step() returns 0 (halted or waiting), exit loop
            if (cycles == 0) {
                break;
            }
        }
    }

    /// Execute a single instruction (useful for debugging)
    /// Returns cycle count consumed by the instruction
    pub fn stepOnce(self: *@This()) u64 {
        return self.step();
    }

    /// Check if CPU is halted by STP instruction
    pub fn isHalted(self: *@This()) bool {
        return self.STP;
    }

    /// Check if CPU is waiting for interrupt (WAI instruction)
    pub fn isWaiting(self: *@This()) bool {
        return self.WAIT;
    }

    // =============== FUNCTIONS FOR EXTERNAL CODE ===============
    pub fn reset(self: *@This()) void {
        self.resetHandler();
    }

    /// Handle Non-Maskable Interrupt (NMI)
    /// Clears WAIT state if CPU is waiting for interrupt
    pub fn NMI(self: *@This()) void {
        // Clear WAIT state if CPU is waiting for interrupt
        if (self.WAIT) {
            self.WAIT = false;
        }
        self.nmiHandler();
    }

    /// Handle Interrupt Request (IRQ)
    /// Clears WAIT state if CPU is waiting for interrupt
    pub fn interrupt(self: *@This()) void {
        // Clear WAIT state if CPU is waiting for interrupt
        if (self.WAIT) {
            self.WAIT = false;
        }
        self.irqHandler();
    }

    /// Get total cycle count since reset
    pub fn getCycles(self: *@This()) u64 {
        return self.cycles;
    }

    /// Get current Program Counter value
    pub fn getPC(self: *@This()) u16 {
        return @as(u16, self.pch) << 8 | @as(u16, self.pcl);
    }

    /// Set Program Counter value
    pub fn setPC(self: *@This(), value: u16) void {
        self.pch = @as(u8, @truncate(value >> 8));
        self.pcl = @as(u8, @truncate(value));
    }

    /// Get Accumulator register value
    pub fn getAccumulator(self: *@This()) u8 {
        return self.accumulator;
    }

    /// Set Accumulator register value
    pub fn setAccumulator(self: *@This(), value: u8) void {
        self.accumulator = value;
    }

    /// Get X register value
    pub fn getXRegister(self: *@This()) u8 {
        return self.x_register;
    }

    /// Set X register value
    pub fn setXRegister(self: *@This(), value: u8) void {
        self.x_register = value;
    }

    /// Get Y register value
    pub fn getYRegister(self: *@This()) u8 {
        return self.y_register;
    }

    /// Set Y register value
    pub fn setYRegister(self: *@This(), value: u8) void {
        self.y_register = value;
    }

    /// Get Stack Pointer value
    pub fn getStackPointer(self: *@This()) u8 {
        return self.stack_pointer;
    }

    /// Set Stack Pointer value
    pub fn setStackPointer(self: *@This(), value: u8) void {
        self.stack_pointer = value;
    }

    /// Get Status Register value as byte
    pub fn getStatusRegister(self: *@This()) u8 {
        return self.status_register.toByte();
    }

    /// Set Status Register value from byte
    pub fn setStatusRegister(self: *@This(), value: u8) void {
        self.status_register = StatusRegister.fromByte(value);
    }

    /// Get current opcode being executed
    pub fn getCurrentOpcode(self: *@This()) u8 {
        return self.current_opcode;
    }

    // =============== HELPER FUNCTIONS ===============
    /// Initialize a new CPU instance with memory interface
    pub fn init(memory: memory_interface) cpu65c02 {
        return cpu65c02{
            .memory = memory,
        };
    }

    fn updateNZ(self: *@This(), value: u8) void {
        self.status_register.negative = value & 0x80 != 0;
        self.status_register.zero = value == 0;
    }

    fn stackPush(self: *@This(), value: u8) void {
        self.memory.write(@as(u16, 0x0100) + @as(u16, self.stack_pointer), value);
        self.stack_pointer -%= 1;
    }

    fn stackPop(self: *@This()) u8 {
        self.stack_pointer +%= 1;
        return self.memory.read(@as(u16, 0x0100) + @as(u16, self.stack_pointer));
    }

    fn isPageCrossed(self: *@This(), base_addr: u16, final_addr: u16) bool {
        _ = self;
        return (base_addr & 0xFF00) != (final_addr & 0xFF00);
    }

    // =============== Interrupt Handlers ===============
    fn resetHandler(self: *@This()) void {
        self.accumulator = 0;
        self.x_register = 0;
        self.y_register = 0;
        self.stack_pointer = 0xFD;
        self.pcl = self.memory.read(ResetVector);
        self.pch = self.memory.read(ResetVector + 1);
        self.status_register = StatusRegister{};
        self.cycles = 7;
        self.STP = false;
        self.WAIT = false;
    }

    fn interruptHandler(self: *@This(), vector: u16) void {
        self.stackPush(self.pch);
        self.stackPush(self.pcl);
        const p: u8 = self.status_register.toByte() & ~@as(u8, 0x10); // Break flag is 0 when pushing to stack at interrupt
        self.stackPush(p);
        self.status_register.intmask = true;
        self.pcl = self.memory.read(vector);
        self.pch = self.memory.read(vector + 1);
    }

    fn irqHandler(self: *@This()) void {
        if (self.status_register.intmask) {
            return;
        }
        self.interruptHandler(IRQVector);
    }

    fn nmiHandler(self: *@This()) void {
        self.interruptHandler(NMIVector);
    }
};
