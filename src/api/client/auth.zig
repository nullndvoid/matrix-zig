const std = @import("std");

pub const legacy = @import("auth/legacy.zig");

test {
    std.testing.refAllDecls(@This());
}
