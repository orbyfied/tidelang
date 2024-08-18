const std = @import("std");
const tide = @import("tidelang");
const vm = @import("vm.zig");
const Insn = tide.common.Insn;
const ThreadStack = tide.vm.ThreadStack;
const Value = ThreadStack.Value;
const ValueUnion = ThreadStack.ValueUnion;
const ValueType = ThreadStack.ValueType;

/// The result of the interpreter running
pub const InterpreterResult = struct {};

//
// Type Decl: Interpreter
//

const Interpreter = @This();

vm: *vm.VM,
thread: *vm.Thread,

pub fn beginExecution(self: *Interpreter, callSite: *const tide.runtime.CallSite) InterpreterResult {
    const frame = vm.ThreadStack.Frame{ .callSite = callSite, .code = callSite.code, .pc = callSite.insnOffset, .reservedLocals = callSite.reservedLocals };
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

            Insn.Opcode.GETLOCAL => {
                stack.push(stack.getLocal(insn.operandA.asU64));
            },

            Insn.Opcode.SETLOCAL => {
                stack.setLocal(insn.operandA.asU64, stack.pop());
            },

            Insn.Opcode.PUSHI32 => {
                stack.push(.{ .type = ValueType.Int32, .value = .{ .asI32 = insn.operandA.asI32 } });
            },

            Insn.Opcode.PUSHI64 => {
                stack.push(.{ .type = ValueType.Int64, .value = .{ .asI64 = insn.operandA.asI64 } });
            },

            Insn.Opcode.PUSHF32 => {
                stack.push(.{ .type = ValueType.Float32, .value = .{ .asF32 = insn.operandA.asF32 } });
            },

            Insn.Opcode.PUSHF64 => {
                stack.push(.{ .type = ValueType.Float64, .value = .{ .asF64 = insn.operandA.asF64 } });
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

            Insn.Opcode.HI => {
                std.debug.print("[HI] from pc=0x{x} stack(ptr={} frame={} frameStart={} frameStackStart={})\n", .{ frame.pc, stack.ptr, stack.frameIndex, frame.startIndex, frame.stackStartIndex });
                std.debug.print("     Value Stack ({}):\n", .{stack.ptr - frame.stackStartIndex + 1});
                var i: isize = stack.ptr;
                while (i >= frame.stackStartIndex) {
                    const v = stack.at(@intCast(i));
                    std.debug.print("       0x{x} type({s}) asI64={}\n", .{ i, @tagName(v.type), v.value.asI64 });
                    i -= 1;
                }

                std.debug.print("     Locals ({}):\n", .{frame.stackStartIndex - frame.startIndex});
                i = frame.stackStartIndex - 1;
                while (i >= frame.startIndex) {
                    const v = stack.at(i);
                    std.debug.print("       0x{x} type({s}) asI64={}\n", .{ i, @tagName(v.type), v.value.asI64 });
                    i -= 1;
                }

                std.debug.print("     Trace:\n", .{});
                i = stack.frameIndex;
                while (i >= 0) {
                    const frame1 = stack.getFrame(@intCast(i));
                    std.debug.print("       '{s}' pc=0x{x}", .{ frame1.callSite.identifier.data, frame1.pc });
                    i -= 1;
                }
            },
        }

        frame.pc += 1;
    }

    return InterpreterResult{};
}
