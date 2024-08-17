const std = @import("std");

inline fn memcopy(T: type, dst: [*]T, src: [*]T, sourceIndex: usize, destIndex: usize, count: usize) void {
    @memcpy(dst[destIndex .. destIndex + count], src[sourceIndex .. sourceIndex + count]);
}

/// A Java-like String object/struct which stores UTF-8 encoded strings
pub const String = struct {
    /// The data array/pointer
    data: []const u8,
    /// The length of the string in characters
    len: usize,
    /// Whether the data array is terminated with a null value
    terminated: bool,

    pub fn new(alloc: std.mem.Allocator, utf8Data: []const u8) *String {
        var str = try alloc.create(String);
        str.data = utf8Data;
        str.len = std.unicode.calcUtf16LeLen(utf8Data) catch 0;
        str.terminated = utf8Data[utf8Data.len - 1] == 0;
        return str;
    }

    pub fn slice(utf8Data: []const u8) String {
        return .{ .data = utf8Data, .len = (std.unicode.calcUtf16LeLen(utf8Data) catch 0), .terminated = utf8Data[utf8Data.len - 1] == 0 };
    }

    pub fn term(utf8Data: [:0]const u8) String {
        if (utf8Data[utf8Data.len] != 0) {
            unreachable;
        }

        return .{ .data = utf8Data, .len = (std.unicode.calcUtf16LeLen(utf8Data) catch 0), .terminated = true };
    }

    ////////////////////

    pub inline fn toU16LEAlloc(self: *const String, alloc: std.mem.Allocator) []u16 {
        return std.unicode.utf8ToUtf16LeAlloc(alloc, self.data) catch unreachable;
    }

    pub inline fn length(self: *const String) usize {
        return self.len;
    }

    pub inline fn isLatin1(self: *const String) bool {
        return self.len == self.size;
    }

    pub inline fn isNullTerminated(self: *const String) bool {
        return self.terminated;
    }

    pub inline fn subSlice(self: *const String, start: usize, end: usize) []const u8 {
        return self.data[start..end];
    }

    pub fn release(self: *String) void {
        self.alloc.free(self.data);
        self.data = null;
        self.len = 0;
    }
};

/// Utility to incrementally build strings
pub const StringBuilder = struct {
    /// The allocator to be used
    alloc: std.mem.Allocator,
    /// The current UTF-16 data array
    data: []u16,
    /// The allocated capacity of the array
    cap: usize,
    /// The current length of the string
    len: usize,

    pub fn empty(alloc: std.mem.Allocator) !StringBuilder {
        return .{ .alloc = alloc, .data = try alloc.alloc(u16, 8), .cap = 8, .len = 0 };
    }

    //////////////////////////////////

    fn _writeToBuilder(b: *StringBuilder, data: []const u8) anyerror!usize {
        _ = try b.appendUTF8Slice(data);
        return data.len;
    }

    pub const Writer = std.io.Writer(*StringBuilder, anyerror, _writeToBuilder);

    pub fn appendU16(self: *StringBuilder, char: u16) !*StringBuilder {
        try self.ensureCap(self.len + 1);
        self.data[self.len] = char;
        self.len += 1;
        return self;
    }

    pub fn appendUTF8Slice(self: *StringBuilder, slice: []const u8) !*StringBuilder {
        try self.ensureCap(self.len + slice.len);
        const enc = std.unicode.utf8ToUtf16Le(self.data[self.len..self.cap], slice) catch unreachable;
        self.len += enc;
        return self;
    }

    pub fn appendString(self: *StringBuilder, str: *String) *StringBuilder {
        self.ensureCap(self.len + str.len) catch unreachable;
        std.unicode.utf8ToUtf16Le(self.data[self.len..self.cap], str.data) catch unreachable;
        self.len += str.len;
        return self;
    }

    pub fn createWriter(self: *StringBuilder) Writer {
        return Writer{ .context = self };
    }

    pub fn appendFormatted(self: *StringBuilder, comptime fmt: []const u8, args: anytype) *StringBuilder {
        std.fmt.format(createWriter(self).any(), fmt, args) catch unreachable;
        return self;
    }

    fn reallocPrecise(self: *StringBuilder, cap: usize) std.mem.Allocator.Error!void {
        const newData = try self.alloc.alloc(u16, cap);

        // try and copy old data
        if (self.cap > 0 and self.len > 0) {
            memcopy(u16, newData.ptr, self.data.ptr, 0, 0, self.len);
            self.alloc.free(self.data);
        }

        self.data = newData;
        self.cap = cap;
    }

    fn ensureCap(self: *StringBuilder, cap: usize) std.mem.Allocator.Error!void {
        if (self.cap < cap) {
            try self.reallocPrecise(cap * 2);
        }
    }

    pub fn toUTF8Alloc(self: *StringBuilder, alloc: std.mem.Allocator) ![]u8 {
        return try std.unicode.utf16LeToUtf8Alloc(alloc, self.data[0..self.len]);
    }

    pub fn toStringAlloc(self: *StringBuilder, alloc: std.mem.Allocator) !String {
        return String.slice(try std.unicode.utf16LeToUtf8Alloc(alloc, self.data[0..self.len]));
    }

    pub fn release(self: *StringBuilder) void {
        self.alloc.free(self.data);
        self.cap = 0;
        self.len = 0;
    }
};

/// Utility to parse strings sequentially
pub const StringReader = struct {
    /// The allocator to be used for tasks which may require it
    alloc: std.mem.Allocator,
    /// The pointer to the string data being parsed, encoded in LE UTF-16
    str: []const u16,
    /// The length of the string being parsed
    len: usize,
    /// The current index/cursor into the string
    idx: usize,

    pub fn new(alloc: std.mem.Allocator, s: *const String) StringReader {
        return .{ .alloc = alloc, .str = s.toU16LEAlloc(alloc), .len = s.length(), .idx = 0 };
    }

    pub fn newMoved(alloc: std.mem.Allocator, s: *const String, idx: usize) StringReader {
        return .{ .alloc = alloc, .str = s.toU16LE(), .len = s.length(), .idx = idx };
    }

    /////////////////////////

    pub inline fn clamp(self: *const StringReader, index: usize) usize {
        if (index < 0) {
            return 0;
        }

        if (index >= self.len) {
            return self.len; // ended
        }

        return index;
    }

    pub inline fn advance(self: *StringReader, amount: usize) *StringReader {
        self.idx += amount;
        self.idx = self.clamp(self.idx);
        return self;
    }

    pub inline fn ended(self: *const StringReader) bool {
        return self.idx >= self.len;
    }

    pub inline fn hasNext(self: *const StringReader) bool {
        return self.idx < self.len;
    }

    pub inline fn current(self: *const StringReader) u16 {
        if (self.idx >= self.len or self.idx < 0) {
            return 0xFFFF;
        } else {
            return self.str[self.idx];
        }
    }

    pub inline fn at(self: *const StringReader, idx: usize) u16 {
        if (idx >= self.len or idx < 0) {
            return 0xFFFF;
        } else {
            return self.str[idx];
        }
    }

    pub inline fn skip(self: *StringReader) *StringReader {
        self.idx += 1;
        return self;
    }

    pub inline fn take(self: *StringReader) u16 {
        const c = self.current();
        _ = self.advance(1);
        return c;
    }

    pub inline fn next(self: *StringReader) u16 {
        _ = self.advance(1);
        return self.current();
    }

    pub inline fn move(self: *StringReader, index: usize) *StringReader {
        self.idx = self.clamp(index);
        return self;
    }

    pub fn collectInto(self: *StringReader, b: *StringBuilder, pred: fn (c: u16) bool) !void {
        while (!self.ended()) {
            const char = self.take();
            if (!pred(char)) {
                return;
            }

            _ = try b.appendU16(char);
        }
    }

    pub fn collect(self: *StringReader, pred: fn (c: u16) bool) !String {
        var b = try StringBuilder.empty(self.alloc);
        defer b.release();
        try self.collectInto(&b, pred);
        return b.toStringAlloc(self.alloc);
    }

    pub fn consume(self: *StringReader, pred: fn (c: u16) bool) usize {
        var count: usize = 0;
        while (!self.ended()) {
            const char = self.take();
            if (!pred(char)) {
                return count;
            }

            count += 1;
        }

        return count;
    }
};
