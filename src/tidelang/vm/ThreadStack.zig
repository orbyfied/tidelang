const std = @import("std");
const tide = @import("tidelang");

/// All stack value types
pub const ValueType = enum(u8) {
    Void = 0, // An empty slot in the stack which is to be ignored
    Bool,
    Byte,
    Char,
    Short,
    Int64, // A signed 64 bit integer (long)
    Int32, // A signed 32 bit integer (int)
    Float64, // An IEEE 754 binary64 floating point number
    Float32, // An IEEE 754 binary32 floating point number
    Reference, // An object reference
};

/// A value on the VM stack.
/// Stack values consist of a one byte type tag, then a 64-bit value
pub const Value = packed struct { type: ValueType, value: packed union { asU64: u64, asU32: u32, asI64: i64, asI32: i32, asF64: f64, asF32: f32, asPtr: *anyopaque, asU8: u8 } };

/// A frame on the value stack.
pub const Frame = struct {
    callSite: *const tide.runtime.CallSite, // The called method/closure/function
    reservedLocals: u16, // The amount of local variables before the start index

    code: *tide.common.Code, // The current chunk of code being executed
    pc: usize, // The current program counter/instruction of execution

    startIndex: u32 = 0, // The start index of the locals of the frame on the value stack
    stackStartIndex: u32 = 0, // The start index of the operand stack, after the locals
    endIndex: u32 = 0, // The end index of the frame on the value stack, or 0 if not closed [Inclusive]
};

//
// Type Decl: (VM) ValueStack
//

const Self = @This();

/// The array backing the stack
data: []Value,
/// The current stack pointer as an index into the backing array
/// The stack pointer points to the last pushed element, so if the stack is empty
/// the pointer will be -1.
ptr: isize,

/// The data array of stack frames
frames: []Frame,
/// The index of the current stack frame
frameIndex: isize,

pub fn fixed(allocator: std.mem.Allocator, maxValues: usize, maxFrames: usize) !Self {
    const dataArray: []Value = try allocator.alloc(Value, maxValues);
    const frames: []Frame = try allocator.alloc(Frame, maxFrames);
    return .{ .data = dataArray, .ptr = -1, .frames = frames, .frameIndex = -1 };
}

//////////////

pub fn pushFrame(self: *Self, frame: Frame) void {
    // handle last frame
    self.ptr += 1;
    if (self.inFrame()) {
        self.currentFrame().endIndex = @intCast(self.ptr);
    }

    // push frame info
    self.frameIndex += 1;
    var f: *Frame = &self.frames[@intCast(self.frameIndex)];
    f.* = frame;

    // set up value stack
    self.ensureRemainingCapacity(frame.reservedLocals);
    f.startIndex = @intCast(self.ptr);
    f.stackStartIndex = frame.startIndex + frame.reservedLocals;
    f.endIndex = 0;
    self.ptr = f.stackStartIndex - 1;

    // empty locals
    @memset(self.data[f.startIndex..f.stackStartIndex], Value{ .type = ValueType.Void, .value = .{ .asU8 = 0 } });
}

pub fn popFrame(self: *Self) Frame {
    // pop frame info
    const frame = self.frames[@intCast(self.frameIndex)];
    self.frameIndex -= 1;

    // restore value stack
    self.ptr = frame.startIndex - 1;

    // restore last frame
    if (self.inFrame()) {
        self.currentFrame().endIndex = 0;
    }
}

inline fn hasCapacityFor(self: *Self, amount: usize) bool {
    const p: usize = @bitCast(self.ptr);
    return p + amount < self.data.len;
}

inline fn ensureRemainingCapacity(self: *Self, extra: usize) void {
    if (!hasCapacityFor(self, extra)) {
        // todo: resize maybe or throw err
    }
}

inline fn ensureNotEmpty(self: *Self) void {
    if (self.isEmpty()) {
        // todo: throw err
    }
}

inline fn ensureHas(self: *Self, amount: usize) void {
    if (self.has(amount)) {
        // todo: throw err
    }
}

inline fn relativePointer(self: *Self) isize {
    if (self.inFrame()) {
        const ssi: isize = @intCast(self.currentFrame().stackStartIndex);
        return self.ptr - ssi;
    } else {
        return self.ptr;
    }
}

inline fn isEmpty(self: *Self) bool {
    return self.relativePointer() == -1;
}

inline fn has(self: *Self, amount: usize) bool {
    return self.relativePointer() < amount - 1;
}

pub inline fn inFrame(self: *Self) bool {
    return self.frameIndex != -1;
}

pub inline fn getFrame(self: *Self, index: usize) *Frame {
    return &self.frames[index];
}

pub inline fn currentFrame(self: *Self) *Frame {
    return &self.frames[@intCast(self.frameIndex)];
}

pub inline fn getLocal(self: *Self, index: usize) Value {
    const frame = self.currentFrame();
    return self.data[frame.startIndex + index];
}

pub inline fn setLocal(self: *Self, index: usize, val: Value) void {
    const frame = self.currentFrame();
    self.data[frame.startIndex + index] = val;
}

pub inline fn push(self: *Self, val: Value) void {
    self.ensureRemainingCapacity(1);
    self.ptr += 1;
    self.data[@intCast(self.ptr)] = val;
}

pub inline fn pop(self: *Self) Value {
    self.ensureNotEmpty();
    const v = self.data[@intCast(self.ptr)];
    self.ptr -= 1;
    return v;
}

pub inline fn peek(self: *Self) Value {
    self.ensureNotEmpty();
    return self.data[@intCast(self.ptr)];
}

pub inline fn peekOpt(self: *Self) ?Value {
    if (!self.isEmpty()) {
        return self.data[@intCast(self.ptr)];
    }

    return null;
}

pub inline fn at(self: *Self, off: isize) Value {
    // todo: bounds
    if (off < 0) {
        return self.data[@intCast(self.ptr + off + 1)]; // +1 because otherwise there is no way to reference the top of the stack
    } else {
        return self.data[@intCast(off)];
    }
}

pub inline fn dupT(self: *Self) void {
    self.ensureHas(1);
    self.push(self.peek());
}

pub inline fn dupT2(self: *Self) void {
    self.ensureRemainingCapacity(2);
    self.data[@intCast(self.ptr + 1)] = self.data[@intCast(self.ptr - 1)];
    self.data[@intCast(self.ptr + 2)] = self.data[@intCast(self.ptr)];
    self.ptr += 2;
}

pub inline fn swapT2(self: *Self) void {
    self.ensureHas(2);
    const top = self.data[@intCast(self.ptr)];
    self.data[@intCast(self.ptr)] = self.data[@intCast(self.ptr - 1)];
    self.data[@intCast(self.ptr - 1)] = top;
}
