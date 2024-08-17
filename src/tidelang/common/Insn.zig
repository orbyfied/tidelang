const std = @import("std");

/// An operand in an instruction, 64 bits.
pub const Operand = packed union {
    asU64: u64,
    asU32: u32,
    asI64: i64,
    asI32: i32,
};

pub const Opcode = enum(u16) {
    // Primitive Opcodes
    NOOP = 0x0, // Do nothing

    HI = 0x1, // Hi
};

//
// Type Decl: Insn
//

/// The opcode of the instruction
opcode: Opcode,
/// Additional compile-/load-/runtime flag bit field,
/// the meaning of these flags differ per opcode.
flags: u8,

operandA: Operand,
operandB: Operand,
