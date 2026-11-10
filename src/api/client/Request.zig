//! Output by the state machine. Indicates that the overlying I/O layer should
//! issue a HTTP request.
const std = @import("std");
const http = std.http;

const ServerName = @import("../../types.zig").ServerName;

const Request = @This();

/// We can store request IDs to map them to correct handlers later.
/// Clients are recommended to concatenate a monotonically increasing
/// integer with the current timestamp.
pub const RequestId = struct {
    ts: i64,
    n: u64,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{d}{d}", .{ self.ts, self.n });
    }
};

/// A HTTP query parameter. `val` will be URL-encoded.
pub const QueryParam = struct {
    key: []const u8,
    val: []const u8,
};

id: RequestId,
method: http.Method,
/// One of `.server_name` or `.homeserver`. If the homesever URL is not yet
/// known, this can be used to discover the right URL.
base: Base,
/// Already URL-encoded.
path: []const u8,
query: []const QueryParam = &.{},
/// JSON-encoded.
body: ?[]const u8 = null,

pub const Base = union(enum) {
    homeserver,
    /// Used before discovery finds the homeserver URL.
    server_name: ServerName,
};
