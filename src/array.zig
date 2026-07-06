const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const x = try allocator.alloc(i32, 8);
    std.debug.print("{}", .{x.len});
}
