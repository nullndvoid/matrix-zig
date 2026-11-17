//! Output by the state machine. Indicates that the overlying I/O layer should
//! issue a HTTP request.
const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;

const common = @import("common.zig");

const ServerName = @import("../../types.zig").ServerName;

const Request = @This();

/// We can store request IDs to map them to correct handlers later.
pub const RequestId = struct {
    n: u64,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{d}", .{self.n});
    }
};

/// Attempts to convert an endpoints Query/Path value to a string.
///
/// For simplicity, URL-encoding is not done in this function.
fn valToString(comptime Q: type, val: anytype, arena: Allocator) ![]const u8 {
    return switch (@typeInfo(@TypeOf(val))) {
        .pointer => |ptr| if (ptr.size == .slice and ptr.child == u8)
            val
        else
            @compileError(@typeName(Q) ++ ": query/path strings must be []const u8"),
        .@"enum" => if (@hasDecl(@TypeOf(val), "format"))
            try arena.print("{f}", .{val})
        else
            @tagName(val),
        .bool => if (val) "true" else "false",
        .int => try arena.print("{d}", .{val}),
        .@"struct", .@"union" => try arena.print("{f}", .{val}),
        else => @compileError("Unsupported value type for " ++ @typeName(Q)),
    };
}

/// Copied from the standard library. This means we will escape if reserved.
fn isUnreserved(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '.', '_', '~' => true,
        else => false,
    };
}

/// A HTTP query parameter. `val` should be URL-encoded.
pub const QueryParam = struct {
    key: []const u8,
    val: []const u8,

    fn encodeQueryValue(arena: Allocator, raw: []const u8) ![]const u8 {
        var aw: std.Io.Writer.Allocating = .init(arena);

        std.Uri.Component.percentEncode(&aw.writer, raw, isUnreserved) catch
            return error.OutOfMemory;

        return aw.written();
    }

    pub fn from(Q: type, comptime key: []const u8, val: anytype, arena: Allocator) !QueryParam {
        const val_str = try valToString(Q, val, arena);

        return .{
            .key = key,
            .val = try encodeQueryValue(arena, val_str),
        };
    }
};

fn buildPath(comptime E: type, arena: Allocator, path: E.Path) ![]const u8 {
    if (E.Path == void) return E.path;

    var aw: std.Io.Writer.Allocating = .init(arena);
    inline for (comptime common.parsePathTemplate(E.path)) |part| switch (part) {
        .literal => |l| aw.writer.writeAll(l) catch return error.OutOfMemory,
        .param => |name| {
            const raw = try valToString(E.Path, @field(path, name), arena);

            std.Uri.Component.percentEncode(&aw.writer, raw, isUnreserved) catch
                return error.OutOfMemory;
        },
    };

    return aw.written();
}

id: RequestId,
method: http.Method,
auth: common.Auth,
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
    ///
    /// Ignore a port if given. Port 443 should be used for the lookup.
    server_name: ServerName,
};

fn queryParams(comptime E: type, query: E.Query, arena: Allocator) ![]const QueryParam {
    return switch (@typeInfo(E.Query)) {
        .void => &.{},
        .@"struct" => |s| try queryParamsStruct(E, query, arena, s),
        else => @compileError("Expected either a struct or void for " ++
            @typeName(E) ++ ".Query."),
    };
}

fn queryParamsStruct(
    comptime E: type,
    query: E.Query,
    arena: Allocator,
    comptime s: std.lang.Type.Struct,
) ![]const QueryParam {
    const out = try arena.alloc(QueryParam, s.field_names.len);
    var len: usize = 0;

    inline for (s.field_names, s.field_types) |n, t| {
        const v = @field(query, n);

        if (comptime @typeInfo(t) == .optional) {
            if (v) |inner| {
                out[len] = try QueryParam.from(E.Query, n, inner, arena);
                len += 1;
            }
        } else {
            out[len] = try QueryParam.from(E.Query, n, v, arena);
            len += 1;
        }
    }

    return out[0..len];
}

pub fn init(
    comptime E: type,
    arena: Allocator,
    id: RequestId,
    path: E.Path,
    query: E.Query,
    body: E.Body,
    server_name: if (E.base == .server_name) ServerName else void,
) !Request {
    const request_body = if (E.Body == void) null else try std.json.Stringify.valueAlloc(
        arena,
        body,
        common.serialise_options,
    );

    const request_query: []const QueryParam = try queryParams(E, query, arena);

    const request_path = try buildPath(E, arena, path);

    return .{
        .id = id,
        .method = E.method,
        .auth = E.auth,
        .base = switch (E.base) {
            .homeserver => .homeserver,
            .server_name => .{ .server_name = server_name },
        },
        .path = request_path,
        .query = request_query,
        .body = request_body,
    };
}

test "Request.init handles Query correctly" {
    const namespace = struct {
        pub const Endpoint = struct {
            pub const method: std.http.Method = .GET;
            pub const base: common.BaseKind = .homeserver;
            pub const path = "/_matrix/client/v3/fakestub/{q}/{t}";
            pub const auth: common.Auth = .none;
            pub const added_in: ?common.SpecVersion = null;
            pub const rate_limited = true;

            pub const Path = struct {
                q: []const u8,
                t: u64,
            };
            pub const Query = struct {
                name: []const u8,
                age: u8,
                favourite_colour: FaveColour,
                foo: Foo = .{},
                works: bool = true,

                pub const FaveColour = enum { blue, red, other };
                pub const Foo = struct {
                    wtf: u8 = 0,

                    pub fn format(
                        self: @This(),
                        writer: *std.Io.Writer,
                    ) std.Io.Writer.Error!void {
                        try writer.print("{d}", .{self.wtf});
                    }
                };
            };
            pub const Body = void;
            pub const Response = void;
        };

        test {
            common.checkEndpoints(@This());
        }
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const request = try Request.init(
        namespace.Endpoint,
        arena.allocator(),
        .{ .n = 0 },
        .{
            .q = "100% legit CS:GO cheats",
            .t = 12345,
        },
        .{
            .name = "Alice Smith",
            .age = 20,
            .favourite_colour = .blue,
        },
        {},
        {},
    );

    const expected = [_]QueryParam{
        .{ .key = "name", .val = "Alice%20Smith" },
        .{ .key = "age", .val = "20" },
        .{ .key = "favourite_colour", .val = "blue" },
        .{ .key = "foo", .val = "0" },
        .{ .key = "works", .val = "true" },
    };

    try std.testing.expectEqual(expected.len, request.query.len);
    for (expected, request.query) |want, got| {
        try std.testing.expectEqualStrings(want.key, got.key);
        try std.testing.expectEqualStrings(want.val, got.val);
    }
}

test {
    std.testing.refAllDecls(@This());
}
