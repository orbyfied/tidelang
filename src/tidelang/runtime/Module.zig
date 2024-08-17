const std = @import("std");
const tide = @import("tidelang");

usingnamespace tide;

//
// Type Decl: Module
//

/// The fully qualified name of the module
name: tide.String,
/// All classes defined by the module
classes: std.ArrayList(*tide.runtime.oop.Class),
