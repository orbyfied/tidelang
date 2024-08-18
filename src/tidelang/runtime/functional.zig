const std = @import("std");
const tide = @import("tidelang");

/// Represents a callable function/method
pub const CallSite = struct {
    /// The code object which contains the bytecode to be executed
    /// when calling this function.
    code: *tide.common.Code,
    insnOffset: usize, // Where in the instructions does the block corresponding to this call begin.
    /// The amount of space to reserve for locals for this function
    reservedLocals: u16,

    /// A full identifier of this call site
    identifier: *tide.String,
};
