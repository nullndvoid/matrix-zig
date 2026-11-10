const std = @import("std");

pub const client = @import("api/client.zig");

test {
    std.testing.refAllDecls(@This());
}
