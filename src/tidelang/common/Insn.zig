const std = @import("std");

/// An operand in an instruction, 64 bits.
pub const Operand = packed union {
    asU64: u64,
    asU32: u32,
    asI64: i64,
    asI32: i32,
    asF64: f64,
    asF32: f32,
};

pub const Opcode = enum(u16) {
    // Primitive Opcodes
    NOOP = 0x0, // Do nothing

    HI = 0x1, // Hi

    GETLOCAL = 0x12, // Get local [A] and push it onto the stack
    SETLOCAL = 0x13, // Pop a value off the stack and store it in local [A]
    PUSHI32 = 0x14,
    PUSHI64 = 0x15,
    PUSHF32 = 0x16,
    PUSHF64 = 0x17,
    PUSHC = 0x18, // Push a value from the constant pool

    POP = 0x21, // Pop one value and void it
    POP2 = 0x22, // Pop and void 2 values
    SWAP = 0x23, // Swap the top 2 stack values
    DUPT = 0x24, // Duplicate the top value
    DUPT2 = 0x25, // Duplicate the top pair of values
};

//
// Type Decl: Insn
//

/// The opcode of the instruction
opcode: Opcode,
/// Additional compile-/load-/runtime flag bit field,
/// the meaning of these flags differ per opcode.
flags: u8 = 0,

operandA: Operand = .{ .asU64 = 0 },
operandB: Operand = .{ .asU64 = 0 },
