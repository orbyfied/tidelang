const std = @import("std");

//
// Submodules
//

/// The execution value/frame stack of a thread
pub const ThreadStack = @import("./ThreadStack.zig");

const tide = @import("tidelang");

/// A VM thread
pub const Thread = struct {
    vm: *VM,

    /// The current stack
    stack: ThreadStack,

    pub fn executeInterpreter() void {}
};

/// The global VM state
pub const VM = struct {
    /// All registered modules
    modules: std.StringHashMap(*tide.runtime.Module),
    /// All registered classes
    classes: std.StringHashMap(*tide.oop.Class),
    /// All threads in this VM
    threads: std.ArrayList(*Thread),
};
