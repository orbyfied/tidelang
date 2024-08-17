const std = @import("std");
const tide = @import("tidelang");
const Insn = tide.common.Insn;

pub fn main() !void {
    var backendAlloc = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = backendAlloc.allocator();

    var code = tide.common.Code.init(alloc);
    try code.append(.{ .opcode = Insn.Opcode.PUSHI64, .operandA = .{ .asI64 = 69 } });
    try code.append(.{ .opcode = Insn.Opcode.HI });

    const vm = try tide.vm.createVM(alloc);
    const mainThread = vm.mainThread;
    var mainThreadInterpreter = tide.vm.Interpreter{ .vm = vm, .thread = mainThread };
    _ = mainThreadInterpreter.invokeCode(&code);
}
