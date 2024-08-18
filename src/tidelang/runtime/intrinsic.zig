const std = @import("std");
const oop = @import("oop.zig");
const Class = oop.Class;
const ObjectHeader = oop.ObjectHeader;
const tide = @import("tidelang");

pub const IntrinsicClasses = struct { stdString: *Class, stdClass: *Class, stdThread: *Class, stdSystem: *Class, stdThrowable: *Class };

/// std.String
pub const StringObj = struct {
    /// The header required to make the object valid
    header: ObjectHeader,
    /// The actual object data struct
    data: tide.String,

    pub fn newUnmanaged(vm: *tide.vm.VM, str: []const u8) !*StringObj {
        var ref = try vm.objectAlloc.create(StringObj);
        ref.data = tide.String.slice(str);
        ref.header.flags.managed = false;
        ref.header.class = vm.intrinsicClasses.stdString;
        return ref;
    }
};

pub const BaseThrowableData = struct { message: *StringObj };

// std.Throwable
pub const ThrowableObj = struct {
    /// The header required to make the object valid
    header: ObjectHeader,
    /// The actual object data struct
    data: BaseThrowableData,

    pub fn newUnmanaged(vm: *tide.vm.VM, o: BaseThrowableData) !*ThrowableObj {
        var ref = try vm.objectAlloc.create(ThrowableObj);
        ref.data = o;
        ref.header.flags.managed = false;
        ref.header.class = vm.intrinsicClasses.stdThrowable;
        return ref;
    }
};
