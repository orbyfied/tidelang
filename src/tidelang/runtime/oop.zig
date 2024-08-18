const std = @import("std");
const tide = @import("tidelang");

pub const intrinsic = @import("intrinsic.zig");

/// Represents a registered class
pub const Class = struct {
    objectHeader: ObjectHeader, // The object header so this struct can be interpreted as a runtime object

    /// The full name of this class
    name: *tide.oop.intrinsic.StringObj,
};

pub const ObjectFlags = packed struct {
    alive: bool = true, // Whether this object is valid
    managed: bool = false, // Whether the object should be tracked by the GC
    persistent: bool = false, // Whether to exclude the object from garbage collection
};

/// The header at the start of every runtime object
pub const ObjectHeader = packed struct {
    /// The pointer to the class type of this object
    class: *Class,
    /// Additional object flags and data
    flags: ObjectFlags,
};

pub fn ObjRef(comptime T: type) type {
    return *Obj(T);
}

pub fn Obj(comptime T: type) type {
    return struct {
        /// The header required to make the object valid
        header: ObjectHeader,
        /// The actual object data struct
        data: T,
    };
}

pub fn wrap(val: anytype, class: *Class) Obj(@TypeOf(val)) {
    return Obj(@TypeOf(val)){ .header = .{ .class = class, .flags = .{} }, .data = val };
}

pub fn wrapAlloc(alloc: std.mem.Allocator, val: anytype, class: *Class) !ObjRef(@TypeOf(val)) {
    var ref = @as(ObjRef(@TypeOf(val)), try alloc.create(Obj(@TypeOf(val))));
    ref.header = .{ .class = class, .flags = .{} };
    ref.data = val;
    return ref;
}