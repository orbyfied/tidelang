const std = @import("std");
const tide = @import("tidelang");

/// Represents a registered class
pub const Class = struct {
    objectHeader: ObjectHeader, // The object header so this struct can be interpreted as a runtime object

    /// The full name of this class
    name: tide.oop.ObjRef(tide.String),
};

pub const ObjectFlags = packed struct {
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
