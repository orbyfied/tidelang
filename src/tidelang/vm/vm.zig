const std = @import("std");

const tide = @import("tidelang");
const oop = tide.oop;
const ObjectHeader = tide.oop.ObjectHeader;

//
// Submodules
//

/// The execution value/frame stack of a thread
pub const ThreadStack = @import("./ThreadStack.zig");
pub const Interpreter = @import("./Interpreter.zig");

/// A VM thread
pub const Thread = struct {
    vm: *VM,

    /// The VM thread ID
    id: usize,
    /// The name of the thread
    name: *oop.intrinsic.StringObj,

    /// The current stack
    stack: ThreadStack,
    /// Whether the thread can currently execute
    canExecute: bool,
    /// The exception currently being handled
    currentThrowable: ?*oop.intrinsic.ThrowableObj,

    pub fn throwException(self: *Thread, t: *oop.intrinsic.ThrowableObj) void {
        self.currentThrowable = t;
        self.canExecute = false;
    }
};

/// The global VM state
pub const VM = struct {
    /// The system and VM resource allocator
    alloc: std.mem.Allocator,
    /// The object allocator
    objectAlloc: std.mem.Allocator,
    /// All registered modules
    modules: std.StringHashMap(*tide.runtime.Module) = .{},
    /// All registered classes
    classes: std.StringHashMap(*tide.oop.Class) = .{},
    /// All threads in this VM
    threads: std.ArrayList(*Thread) = .{},
    /// The main thread
    mainThread: *Thread,

    intrinsicClasses: oop.intrinsic.IntrinsicClasses,

    pub fn findClassOrNull(self: *VM, name: []const u8) ?*tide.oop.Class {
        return self.classes.get(name);
    }

    pub fn destroyObjectInternal(self: *VM, header: *ObjectHeader) void {
        header.flags.alive = false;
        self.objectAlloc.free(header);
    }
};

pub fn createVM(alloc: std.mem.Allocator) anyerror!*VM {
    var vm: *VM = try alloc.create(VM);
    vm.alloc = alloc;
    vm.objectAlloc = alloc;

    // initialize runtime
    vm.classes = @TypeOf(vm.classes).init(alloc);
    vm.modules = @TypeOf(vm.modules).init(alloc);
    vm.threads = @TypeOf(vm.threads).init(alloc);

    // create main thread
    var mainThread: *Thread = try alloc.create(Thread);
    mainThread.id = 0;
    // mainThread.name = try tide.oop.wrapAlloc(alloc, tide.String.term("Main"), vm.findClassOrNull("tide.String").?);
    mainThread.vm = vm;
    mainThread.stack = try ThreadStack.fixed(alloc, 2048, 256);
    try vm.threads.append(mainThread);
    vm.mainThread = mainThread;

    return vm;
}
