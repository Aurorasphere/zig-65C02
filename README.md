# CPU65C02 - 65C02 CPU Emulator

A 65C02 microprocessor emulator library written in Zig.

## Features

- **Complete 65C02 instruction set** support
- **Accurate cycle counting** 
- **Interrupt handling** (NMI, IRQ)
- **Memory interface** abstraction
- **Native Zig** library
- **Tests included**

## Installation

### Adding as a dependency

Add to your `build.zig.zon` file:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .cpu65c02 = .{
            .url = "https://github.com/your-username/cpu65c02/archive/main.tar.gz",
            .hash = "your-hash-here",
        },
    },
}
```

Add to your `build.zig` file:

```zig
const cpu65c02 = b.dependency("cpu65c02", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("cpu65c02", cpu65c02.module("cpu65c02"));
```

## Usage

### Basic Usage

```zig
const std = @import("std");
const cpu65c02 = @import("cpu65c02");

// Memory implementation
const SimpleMemory = struct {
    memory: [65536]u8 = [_]u8{0} ** 65536,

    fn read(self: *@This(), address: u16) u8 {
        return self.memory[address];
    }

    fn write(self: *@This(), address: u16, value: u8) void {
        self.memory[address] = value;
    }
};

fn memory_read(ctx: *anyopaque, address: u16) u8 {
    const mem = @as(*SimpleMemory, @ptrCast(@alignCast(ctx)));
    return mem.read(address);
}

fn memory_write(ctx: *anyopaque, address: u16, value: u8) void {
    const mem = @as(*SimpleMemory, @ptrCast(@alignCast(ctx)));
    mem.write(address, value);
}

pub fn main() !void {
    // Initialize memory
    var memory = SimpleMemory{};
    
    // Load program
    memory.memory[0xFFFC] = 0x00; // Reset vector low
    memory.memory[0xFFFD] = 0x80; // Reset vector high
    memory.memory[0x8000] = 0xA9; // LDA #$42
    memory.memory[0x8001] = 0x42; // #$42
    memory.memory[0x8002] = 0x8D; // STA $0200
    memory.memory[0x8003] = 0x00; // $0200 low
    memory.memory[0x8004] = 0x02; // $0200 high
    memory.memory[0x8005] = 0x00; // BRK

    // Initialize CPU
    const memory_interface = cpu65c02.memory_interface{
        .ctx = &memory,
        .readFn = memory_read,
        .writeFn = memory_write,
    };

    var cpu = cpu65c02.cpu65c02.init(memory_interface);
    cpu.reset();

    // Execute program
    while (!cpu.isHalted()) {
        const cycles = cpu.step();
        if (cycles == 0) break;
        
        std.debug.print("PC=0x{X:04X}, A=0x{X:02X}, Cycles={}\n", .{
            cpu.getPC(),
            cpu.getAccumulator(),
            cycles
        });
    }
}
```

### Advanced Usage

#### Interrupt Handling

```zig
// Trigger NMI interrupt
cpu.NMI();

// Trigger IRQ interrupt
cpu.interrupt();
```

#### Register Access

```zig
// Read registers
const acc = cpu.getAccumulator();
const x = cpu.getXRegister();
const y = cpu.getYRegister();
const sp = cpu.getStackPointer();
const pc = cpu.getPC();

// Write registers
cpu.setAccumulator(0x42);
cpu.setXRegister(0x10);
cpu.setYRegister(0x20);
cpu.setStackPointer(0xFF);
cpu.setProgramCounter(0x8000);
```

#### Status Register

```zig
// Read/write status register
const status = cpu.getStatusRegister();
cpu.setStatusRegister(0x20); // Set N flag

// Access individual flags (using StatusRegister struct)
const status_struct = cpu.status_register;
std.debug.print("Carry: {}, Zero: {}, Negative: {}\n", .{
    status_struct.carry,
    status_struct.zero,
    status_struct.negative
});
```

#### CPU State Checking

```zig
// Check if CPU is halted (STP instruction)
if (cpu.isHalted()) {
    std.debug.print("CPU is halted\n");
}

// Check if CPU is waiting (WAI instruction)
if (cpu.isWaiting()) {
    std.debug.print("CPU is waiting for interrupt\n");
}

// Total cycle count
const total_cycles = cpu.getCycles();
```

## API Reference

### Memory Interface

```zig
pub const memory_interface = struct {
    ctx: *anyopaque,
    readFn: *const fn (*anyopaque, u16) u8,
    writeFn: *const fn (*anyopaque, u16, u8) void,
};
```

### CPU Structure

```zig
pub const cpu65c02 = struct {
    // CPU Control
    pub fn init(memory: memory_interface) cpu65c02
    pub fn reset(self: *@This()) void
    pub fn step(self: *@This()) u64
    pub fn run(self: *@This()) void
    
    // Interrupts
    pub fn NMI(self: *@This()) void
    pub fn interrupt(self: *@This()) void
    
    // Register Access
    pub fn getAccumulator(self: *@This()) u8
    pub fn setAccumulator(self: *@This(), value: u8) void
    pub fn getXRegister(self: *@This()) u8
    pub fn setXRegister(self: *@This(), value: u8) void
    pub fn getYRegister(self: *@This()) u8
    pub fn setYRegister(self: *@This(), value: u8) void
    pub fn getStackPointer(self: *@This()) u8
    pub fn setStackPointer(self: *@This(), value: u8) void
    pub fn getProgramCounter(self: *@This()) u16
    pub fn setProgramCounter(self: *@This(), value: u16) void
    
    // Status Register
    pub fn getStatusRegister(self: *@This()) u8
    pub fn setStatusRegister(self: *@This(), value: u8) void
    
    // State Checking
    pub fn isHalted(self: *@This()) bool
    pub fn isWaiting(self: *@This()) bool
    pub fn getCycles(self: *@This()) u64
    pub fn getCurrentOpcode(self: *@This()) u8
};
```

## Supported Instructions

### Basic 6502 Instructions
- **Arithmetic/Logic**: ADC, AND, ASL, BIT, CMP, CPX, CPY, DEC, DEX, DEY, EOR, INC, INX, INY, LDA, LDX, LDY, LSR, ORA, ROL, ROR, SBC
- **Transfer**: STA, STX, STY, TAX, TAY, TSX, TXA, TXS, TYA
- **Stack**: PHA, PHP, PLA, PLP
- **Branch**: BCC, BCS, BEQ, BMI, BNE, BPL, BVC, BVS
- **Jump/Subroutine**: JMP, JSR, RTS, RTI
- **Other**: BRK, CLC, CLD, CLI, CLV, NOP, SEC, SED, SEI

### 65C02 Additional Instructions
- **Bit Manipulation**: BBR0-7, BBS0-7, RMB0-7, SMB0-7
- **Branch**: BRA
- **Stack**: PHX, PHY, PLX, PLY
- **Other**: STP, STZ, TRB, TSB, WAI

## Building

```bash
# Build library
zig build

# Run tests
zig build test

# Release build
zig build -Doptimize=ReleaseFast
```

## License

MIT License

## Contributing

Bug reports and feature requests are welcome through GitHub Issues.

## References

- [65C02 Datasheet](https://www.westerndesigncenter.com/wdc/documentation/w65c02s.pdf)
- [6502 Instruction Reference](http://www.6502.org/tutorials/6502opcodes.html)
