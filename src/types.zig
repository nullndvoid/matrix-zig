pub const UserId = @import("types/UserId.zig");
pub const RoomId = @import("types/RoomId.zig");
pub const ServerName = UserId.ServerName;

test {
    _ = UserId;
    _ = RoomId;
    _ = ServerName;
}
