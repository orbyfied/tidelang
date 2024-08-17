const std = @import("std");
const tide = @import("tidelang");
const Insn = tide.common.Insn;

//
// Type Decl: Code
//

const Code = @This();

/// The instructions in this code chunk
instructions: std.ArrayList(Insn),

pub fn init(alloc: std.mem.Allocator) Code {
    return Code{ .instructions = std.ArrayList(Insn).init(alloc) };
}

pub fn append(self: *Code, insn: Insn) !void {
    try self.instructions.append(insn);
}
