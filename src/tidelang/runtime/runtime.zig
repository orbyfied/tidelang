const std = @import("std");

pub const oop = @import("oop.zig");
pub const functional = @import("functional.zig");
pub const CallSite = functional.CallSite;

/// A runtime module. A module is an organizational unit
/// which is used to namespace classes.
pub const Module = @import("Module.zig");
