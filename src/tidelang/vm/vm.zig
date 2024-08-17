const std = @import("std");

//
// Submodules
//

/// The execution value/frame stack of a thread
pub const ThreadStack = @import("./ThreadStack.zig");
pub const Interpreter = @import("./Interpreter.zig");

const tide = @import("tidelang");

/// A VM thread
pub const Thread = struct {
    vm: *VM,

    /// The VM thread ID
    id: usize,
    /// The name of the thread
    name: tide.oop.ObjRef(tide.String),

    /// The current stack
    stack: ThreadStack,
};

/// The global VM state
pub const VM = struct {
    /// The system and VM resource allocator
    alloc: std.mem.Allocator,
    /// All registered modules
    modules: std.StringHashMap(*tide.runtime.Module) = .{},
    /// All registered classes
    classes: std.StringHashMap(*tide.oop.Class) = .{},
    /// All threads in this VM
    threads: std.ArrayList(*Thread) = .{},
    /// The main thread
    mainThread: *Thread,

    pub fn findClassOrNull(self: *VM, name: []const u8) ?*tide.oop.Class {
        return self.classes.get(name);
    }
};

pub fn createVM(alloc: std.mem.Allocator) anyerror!*VM {
    var vm: *VM = try alloc.create(VM);
    vm.alloc = alloc;

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
