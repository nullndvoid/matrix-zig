//! A room ID.
//!
//! This is intended to accept a maximal amount of valid room IDs.
//!
//! Note that the [Room Versions Specification](https://spec.matrix.org/latest/rooms/)
//! defines what a valid room ID should be for a particular room version, so this may
//! matter if the client must submit valid room IDs.

const std = @import("std");

const RoomId = @This();

/// This is just a reference. Take care with ownership.
data: []const u8,

pub const Error = error{InvalidRoomId};

/// Attempts to parse a string into a `RoomId`.
///
/// Note that `s` is not copied, merely stored by reference.
///
/// # Errors
///
/// Returns `InvalidRoomId` if `s` did not start with a '!' followed by some
/// opaque character sequence. Note this means '!0' would be a valid room ID, per
/// the specification.
pub fn init(s: []const u8) Error!RoomId {
    if (s.len < 2 or (s.len > 0 and s[0] != '!'))
        return error.InvalidRoomId;

    return .{ .data = s };
}

pub fn format(
    self: @This(),
    writer: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try writer.print("{s}", .{self.data});
}

pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!RoomId {
    const s = try std.json.innerParse([]const u8, allocator, source, options);

    return RoomId.init(s) catch error.InvalidCharacter;
}

pub fn jsonParseFromValue(
    allocator: std.mem.Allocator,
    source: std.json.Value,
    options: std.json.ParseOptions,
) std.json.ParseFromValueError!RoomId {
    const s = try std.json.innerParseFromValue(
        []const u8,
        allocator,
        source,
        options,
    );

    return RoomId.init(s) catch error.InvalidCharacter;
}

pub fn jsonStringify(self: @This(), jws: anytype) !void {
    try jws.write(self.data);
}

test "parse room id" {
    _ = try RoomId.init("!0");
    try std.testing.expectError(
        error.InvalidRoomId,
        RoomId.init("foobar"),
    );
}

test "json" {
    const parsed = try std.json.parseFromSlice(RoomId, std.testing.allocator, "\"!1234abcd\"", .{});
    defer parsed.deinit();

    try std.testing.expectEqualStrings("!1234abcd", parsed.value.data);
}
