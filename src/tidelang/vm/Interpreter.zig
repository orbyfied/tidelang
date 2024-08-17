const std = @import("std");
const tide = @import("tidelang");
const vm = @import("vm.zig");
const Insn = tide.common.Insn;

/// The result of the interpreter running
pub const InterpreterResult = struct {};

//
// Type Decl: Interpreter
//

const Interpreter = @This();

vm: *vm.VM,
thread: *vm.Thread,

pub fn invokeCode(self: *Interpreter, code: *tide.common.Code) InterpreterResult {
    var site = tide.runtime.CallSite{};
    const frame = vm.ThreadStack.Frame{ .callSite = &site, .code = code, .pc = 0, .reservedLocals = 0 };
    self.thread.stack.pushFrame(frame);
    return self.continueExecution();
}

/// Continue execution
pub fn continueExecution(self: *Interpreter) InterpreterResult {
    // unwrap context
    var stack = self.thread.stack;
    var frame = stack.currentFrame();
    const code = frame.code;
    const codeLen = code.instructions.items.len;

    //
    // main execution loop
    //
    while (frame.pc < codeLen) {
        // get instruction as a mutable insn pointer,
        // mutable because we might set some runtime flags
        const insn = code.instructions.items[frame.pc];

        switch (insn.opcode) {
            Insn.Opcode.NOOP => {},
            Insn.Opcode.HI => {
                std.debug.print("hi from pc=0x{x} stack(top={} ptr={} frame={})\n", .{ frame.pc, stack.peekOpt().?.Int64 orelse 0, stack.ptr, stack.frameIndex });
            },

            Insn.Opcode.GETLOCAL => {
                stack.push(stack.getLocal(insn.operandA.asU64));
            },

            Insn.Opcode.SETLOCAL => {
                stack.setLocal(insn.operandA.asU64, stack.pop());
            },

            Insn.Opcode.PUSHI32 => {
                stack.push(.{ .Int32 = insn.operandA.asI32 });
            },

            Insn.Opcode.PUSHI64 => {
                stack.push(.{ .Int64 = insn.operandA.asI64 });
            },

            Insn.Opcode.PUSHF32 => {
                stack.push(.{ .Float32 = insn.operandA.asF32 });
            },

            Insn.Opcode.PUSHF64 => {
                stack.push(.{ .Float64 = insn.operandA.asF64 });
            },

            Insn.Opcode.PUSHC => {
                // todo
            },

            Insn.Opcode.POP => {
                stack.ptr -= 1;
            },

            Insn.Opcode.POP2 => {
                stack.ptr -= 2;
            },

            Insn.Opcode.SWAP => {
                stack.swapT2();
            },

            Insn.Opcode.DUPT => {
                stack.dupT();
            },

            Insn.Opcode.DUPT2 => {
                stack.dupT2();
            },
        }

        frame.pc += 1;
    }

    return InterpreterResult{};
}
