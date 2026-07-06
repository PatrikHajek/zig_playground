const std = @import("std");

pub fn main() !void {}

// List:

fn list() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var l = try List(i32).init(allocator);
    // Not necessary when using ArenaAllocator.
    defer l.deinit();
    try l.add(5);

    var i: u32 = 0;
    while (i < l.count) : (i += 1) {
        std.debug.print("{}", .{l.get(i)});
    }
}

fn List(T: type) type {
    return struct {
        gpa: std.mem.Allocator,
        buffer: []T,
        /// Count of currently allocated items.
        count: u32,

        const LEN = 4;

        const Self = List(T);

        const empty: Self = .{
            .gpa = undefined,
            .buffer = &.{},
            .count = 0,
        };

        fn init(gpa: std.mem.Allocator) !Self {
            var self: Self = .empty;
            self.buffer = try gpa.alloc(T, LEN);
            return self;
        }

        fn deinit(self: *Self) void {
            self.gpa.free(self.buffer);
        }

        fn add(self: *Self, value: T) !void {
            if (self.count < self.buffer.len) {
                self.buffer[self.count] = value;
            } else {
                self.buffer = try self.gpa.realloc(self.buffer, self.buffer.len * 2);
            }
            self.count += 1;
        }

        fn get(self: *Self, index: u32) T {
            return self.buffer[index];
        }
    };
}

// Array:

fn array() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const x = try allocator.alloc(i32, 8);
    std.debug.print("{}", .{x.len});
}
