const std = @import("std");

/// Represents a registered class
pub const Class = struct {
    objectHeader: ObjectHeader, // The object header so this struct can be interpreted as a runtime object
};

pub const ObjectFlags = packed struct {
    persistent: bool, // Whether to exclude the object from garbage collection
};

/// The header at the start of every runtime object
pub const ObjectHeader = packed struct {
    /// The pointer to the class type of this object
    class: *Class,
    /// Additional object flags and data
    flags: ObjectFlags,
};
