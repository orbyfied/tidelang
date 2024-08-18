const std = @import("std");
const tide = @import("tidelang");
const Insn = tide.common.Insn;

pub fn main() !void {
    var backendAlloc = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = backendAlloc.allocator();

    var code = tide.common.Code.init(alloc);
    try code.append(.{ .opcode = Insn.Opcode.PUSHI64, .operandA = .{ .asI64 = 69 } });
    try code.append(.{ .opcode = Insn.Opcode.DUPT });
    try code.append(.{ .opcode = Insn.Opcode.PUSHI32, .operandA = .{ .asI32 = 44 } });
    try code.append(.{ .opcode = Insn.Opcode.SWAP });
    try code.append(.{ .opcode = Insn.Opcode.HI });

    const vm = try tide.vm.createVM(alloc);
    const mainThread = vm.mainThread;
    var mainThreadInterpreter = tide.vm.Interpreter{ .vm = vm, .thread = mainThread };
    const mainFunction = tide.runtime.CallSite{ .code = &code, .insnOffset = 0, .reservedLocals = 2, .identifier = try tide.String.new(alloc, "main") };
    _ = mainThreadInterpreter.beginExecution(&mainFunction);
}
