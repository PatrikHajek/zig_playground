pub fn main() !void {}

test "All" {
    @import("std").testing.refAllDecls(@This());
}
