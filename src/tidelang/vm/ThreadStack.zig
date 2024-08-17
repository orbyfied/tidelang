const std = @import("std");
const tide = @import("tidelang");

/// All stack value types
pub const Type = enum {
    VOID, // An empty slot in the stack which is to be ignored
    BOOL, // A true or false value (bool)
    INT64, // A signed 64 bit integer (long)
    INT32, // A signed 32 bit integer (int)
    FLOAT64, // An IEEE 754 binary64 floating point number
    FLOAT32, // An IEEE 754 binary32 floating point number
    REFERENCE, // An object reference
};

/// A value on the VM stack.
/// Stack values consist of a one byte type tag, then a 64-bit value
pub const Value = union(Type) {
    asU64: u64,
    asU32: u32,
    asI64: i64,
    asI32: i32,
    asPtr: *anyopaque,
};

/// A frame on the value stack.
pub const Frame = struct {
    callSite: *tide.runtime.CallSite, // The called method/closure/function
    startIndex: usize = 0, // The start index of the locals of the frame on the value stack
    reservedLocals: usize, // The amount of local variables before the start index
    stackStartIndex: usize = 0, // The start index of the operand stack, after the locals
    endIndex: usize = 0, // The end index of the frame on the value stack, or 0 if not closed [Inclusive]
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

pub fn fixed(allocator: std.mem.Allocator, maxValues: usize, maxFrames: usize) Self {
    const dataArray: []Value = allocator.alloc(Value, maxValues);
    const frames: []Frame = allocator.alloc(Frame, maxFrames);
    return .{ .data = dataArray, .ptr = -1, .frames = frames, .frameIndex = -1 };
}

//////////////

pub fn pushFrame(self: *Self, frame: Frame) void {
    // handle last frame
    self.ptr += 1;
    if (self.inFrame()) {
        self.currentFrame().endIndex = self.ptr;
    }

    // set up value stack
    self.ensureRemainingCapacity(frame.reservedLocals);
    frame.startIndex = self.ptr;
    frame.stackStartIndex = frame.startIndex + frame.reservedLocals;
    frame.endIndex = 0;

    // push frame info
    self.frameIndex += 1;
    self.frames[self.frameIndex] = frame;
}

pub fn popFrame(self: *Self) Frame {
    // pop frame info
    const frame = self.frames[self.frameIndex];
    self.frameIndex -= 1;

    // restore value stack
    self.ptr = frame.startIndex - 1;

    // restore last frame
    if (self.inFrame()) {
        self.currentFrame().endIndex = 0;
    }
}

inline fn hasCapacityFor(self: *Self, amount: usize) bool {
    return self.ptr + amount < self.data.len;
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
        return self.ptr - self.currentFrame().stackStartIndex;
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
    return &self.frames[self.frameIndex];
}

pub inline fn getLocal(self: *Self, index: usize) Value {
    const frame = self.currentFrame();
    return self.data[frame.startIndex + index];
}

pub inline fn push(self: *Self, val: Value) void {
    self.ensureRemainingCapacity(1);
    self.ptr += 1;
    self.data[self.ptr] = val;
}

pub inline fn pop(self: *Self) Value {
    self.ensureNotEmpty();
    const v = self.data[self.ptr];
    self.ptr -= 1;
    return v;
}

pub inline fn peek(self: *Self) Value {
    self.ensureNotEmpty();
    return self.data[self.ptr];
}

pub inline fn at(self: *Self, off: isize) Value {
    // todo: bounds
    if (off < 0) {
        return self.data[self.ptr + off + 1]; // +1 because otherwise there is no way to reference the top of the stack
    } else {
        return self.data[off];
    }
}

pub inline fn dupT(self: *Self) void {
    self.ensureHas(1);
    self.push(self.peek());
}

pub inline fn dupT2(self: *Self) void {
    self.ensureRemainingCapacity(2);
    self.data[self.ptr + 1] = self.data[self.ptr - 1];
    self.data[self.ptr + 2] = self.data[self.ptr];
    self.ptr += 2;
}

pub inline fn swapT2(self: *Self) void {
    self.ensureHas(2);
    const top = self.data[self.ptr];
    self.data[self.ptr] = self.data[self.ptr - 1];
    self.data[self.ptr - 1] = top;
}
