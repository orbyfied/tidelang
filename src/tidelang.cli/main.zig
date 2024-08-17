const std = @import("std");
const tide = @import("tidelang");

pub fn main() !void {
    var backendAlloc = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = backendAlloc.allocator();

    const hi = tide.String.term("hello \"hello world'");
    var reader = tide.StringReader.new(alloc, &hi);
    const collected = try reader.collect(struct {
        fn pred(char: u16) bool {
            return char != '\'';
        }
    }.pred);
    std.debug.print("collected: '{s}'\n", .{collected.data});
    var builder = try tide.StringBuilder.empty(alloc);
    _ = builder.appendFormatted("a {} b {} c {s}", .{ u72, 5.32, "hi guy" });
    std.debug.print("built: '{s}'\n", .{try builder.toUTF8Alloc(alloc)});
}
