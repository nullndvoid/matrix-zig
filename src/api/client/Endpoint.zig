//! Generic definition of an endpoint. Contains methods for converting to a `Request` and handling responses.
//!
//! Provides a generic interface.

const std = @import("std");
const Allocator = std.mem.Allocator;

const common = @import("common.zig");
const Request = @import("Request.zig");
const ServerName = @import("../../types.zig").ServerName;

/// Validates the endpoint, including checking path and query param templates and schema.
pub fn Endpoint(comptime E: type) type {
    comptime validate(E);

    return struct {
        pub const Def = E;

        pub const display = @tagName(E.method) ++ " " ++ E.path;

        pub const Outcome = union(enum) {
            ok: E.Response,
            err: Failure,
        };

        pub fn format(w: *std.Io.Writer) std.Io.Writer.Error!void {
            try w.writeAll(display);
        }

        pub fn supports(server: []const common.SpecVersion) bool {
            const needed = E.added_in orelse return true;
            for (server) |v| if (v.order(needed) != .lt) return true;
            return false;
        }

        /// Builds a request for the given `Endpoint`.
        pub fn request(
            arena: Allocator,
            id: Request.RequestId,
            path: E.Path,
            query: E.Query,
            body: E.Body,
            server_name: if (E.base == .server_name) ServerName else void,
        ) !Request {
            return .{
                .id = id,
                .method = E.method,
                .auth = E.auth,
                .base = switch (E.base) {
                    .homeserver => .homeserver,
                    .server_name => .{ .server_name = server_name },
                },
                .path = try buildPath(E, arena, path),
                .query = try buildQuery(E, arena, query),
                .body = try buildBody(E, arena, body),
            };
        }

        /// Parses a response and body into an `Outcome`.
        ///
        /// # Notes
        ///
        /// Endpoints may override this using the `parse` method. This is useful
        /// when error codes such as `404` are not to be treated as errors.
        ///
        /// The returned `Outcome` lives as long as `body` and `arena` do.
        pub fn parse(arena: Allocator, status: u16, body: []const u8) !Outcome {
            const json = if (body.len == 0) "{}" else body;

            if (comptime @hasDecl(E, "parse")) return E.parse(arena, status, json);

            if (status < 200 or status >= 300) {
                return .{ .err = .{
                    .status = status,
                    .what = if (try parseError(arena, json)) |e|
                        .{ .matrix = e }
                    else
                        .{ .other = body },
                } };
            }

            if (E.Response == void) return .{ .ok = {} };

            return .{ .ok = try std.json.parseFromSliceLeaky(
                E.Response,
                arena,
                json,
                common.parse_options,
            ) };
        }
    };
}

/// Either a Matrix error, or the body of a failing `Request`.
pub const FailureReason = union(enum) {
    matrix: common.MatrixError,
    other: []const u8,
};

pub const Failure = struct {
    status: u16,
    /// Either a Matrix error, or the body of a failing `Request`.
    what: FailureReason,
};

/// Checks all endpoints defined in the namespace struct `N`.
///
/// # Notes
///
/// Any shared schema in a file should be moved under `definitions.zig`
/// and imported.
///
/// This should be in a test block next to `refAllDecls`.
pub fn checkAll(comptime N: type) void {
    inline for (@typeInfo(N).@"struct".decl_names) |name| {
        const decl = @field(N, name);
        if (@TypeOf(decl) == type and @typeInfo(decl) == .@"struct")
            _ = Endpoint(decl);
    }
}

/// Fails if an endpoint definition is incomplete.
fn validate(comptime E: type) void {
    if (@typeInfo(E) != .@"struct")
        @compileError("Endpoint expects a struct, got " ++ @typeName(E));

    checkDecls(E);
    checkPath(E);
    checkQuery(E);
}

fn checkDecls(comptime E: type) void {
    inline for (.{
        "method",
        "base",
        "path",
        "auth",
        "added_in",
        "rate_limited",
        "Path",
        "Query",
        "Body",
        "Response",
    }) |d|
        if (!@hasDecl(E, d))
            @compileError("Endpoint " ++ @typeName(E) ++
                " is missing `" ++ d ++ "`");
}

/// Validates the path template and Path struct fields match.
fn checkPath(comptime E: type) void {
    const parts = comptime parsePathTemplate(E.path);
    inline for (parts) |p| if (p == .param) {
        if (E.Path == void or !@hasField(E.Path, p.param))
            @compileError(@typeName(E) ++ ": path placeholder {" ++ p.param ++
                "} has no field in Path");
    };

    if (E.Path != void) inline for (@typeInfo(E.Path).@"struct".field_names) |f| {
        if (comptime !templateHas(parts, f))
            @compileError(@typeName(E) ++ ": Path." ++ f ++
                " is not used in the path template");

        if (@typeInfo(@FieldType(E.Path, f)) == .optional)
            @compileError(@typeName(E) ++ ": Path." ++ f ++
                " may not be optional in the path template");
    };
}

fn checkQuery(comptime E: type) void {
    switch (@typeInfo(E.Query)) {
        .void, .@"struct" => {},
        else => @compileError("Expected either a struct or void for " ++
            @typeName(E) ++ ".Query."),
    }
}

const Part = union(enum) { literal: []const u8, param: []const u8 };

/// Given a path template with variables in curly braces,
/// parses into a list of literals/params.
fn parsePathTemplate(comptime template: []const u8) []const Part {
    comptime {
        var parts: []const Part = &.{};
        var i: usize = 0;

        while (i < template.len) {
            if (template[i] == '{') {
                const end = std.mem.findScalarPos(u8, template, i, '}') orelse
                    @compileError("Unclosed '{' in path " ++ template);

                parts = parts ++ .{Part{ .param = template[i + 1 .. end] }};
                i = end + 1;
            } else {
                const end = std.mem.findScalarPos(u8, template, i, '{') orelse
                    template.len;
                parts = parts ++ .{Part{ .literal = template[i..end] }};
                i = end;
            }
        }

        return parts;
    }
}

/// Returns true if `field_name` appears as a `{param}` in the template parts.
fn templateHas(comptime parts: []const Part, comptime field_name: []const u8) bool {
    for (parts) |p| switch (p) {
        .param => |name| if (std.mem.eql(u8, name, field_name)) return true,
        .literal => {},
    };

    return false;
}

fn buildPath(comptime E: type, arena: Allocator, path: E.Path) ![]const u8 {
    if (E.Path == void) return E.path;

    var aw: std.Io.Writer.Allocating = .init(arena);
    inline for (comptime parsePathTemplate(E.path)) |part| switch (part) {
        .literal => |l| aw.writer.writeAll(l) catch return error.OutOfMemory,
        .param => |name| {
            const raw = try valToString(E.Path, @field(
                path,
                name,
            ), arena);

            std.Uri.Component.percentEncode(&aw.writer, raw, isUnreserved) catch
                return error.OutOfMemory;
        },
    };

    return aw.written();
}

fn buildQuery(comptime E: type, arena: Allocator, query: E.Query) ![]const Request.QueryParam {
    if (E.Query == void) return &.{};

    const names = @typeInfo(E.Query).@"struct".field_names;
    const out = try arena.alloc(Request.QueryParam, names.len);
    var len: usize = 0;

    inline for (names) |n| {
        const v = @field(query, n);

        if (comptime @typeInfo(@TypeOf(v)) == .optional) {
            if (v) |inner| {
                out[len] = try queryParam(E.Query, n, inner, arena);
                len += 1;
            }
        } else {
            out[len] = try queryParam(E.Query, n, v, arena);
            len += 1;
        }
    }

    return out[0..len];
}

fn queryParam(
    comptime Q: type,
    comptime key: []const u8,
    val: anytype,
    arena: Allocator,
) !Request.QueryParam {
    const val_str = try valToString(Q, val, arena);

    return .{
        .key = key,
        .val = try percentEncodeAlloc(arena, val_str),
    };
}

fn buildBody(comptime E: type, arena: Allocator, body: E.Body) !?[]const u8 {
    if (E.Body == void) return null;

    return try std.json.Stringify.valueAlloc(
        arena,
        body,
        common.serialise_options,
    );
}

fn parseError(arena: Allocator, body: []const u8) !?common.MatrixError {
    return std.json.parseFromSliceLeaky(
        common.MatrixError,
        arena,
        body,
        common.parse_options,
    ) catch |err|
        switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => null,
        };
}

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

fn percentEncodeAlloc(arena: Allocator, raw: []const u8) ![]const u8 {
    var aw: std.Io.Writer.Allocating = .init(arena);

    std.Uri.Component.percentEncode(&aw.writer, raw, isUnreserved) catch
        return error.OutOfMemory;

    return aw.written();
}

/// Copied from the standard library. This means we will escape if reserved.
fn isUnreserved(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '.', '_', '~' => true,
        else => false,
    };
}

fn TestEndpoint(comptime since: ?common.SpecVersion) type {
    return struct {
        pub const method: std.http.Method = .GET;
        pub const base: common.BaseKind = .homeserver;
        pub const path = "/_matrix/client/v3/fakestub/{q}/{t}";
        pub const auth: common.Auth = .none;
        pub const added_in: ?common.SpecVersion = since;
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
            missing: ?[]const u8 = null,

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
        pub const Response = struct { n: u8 };
    };
}

test "request builds path and query" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const request = try Endpoint(TestEndpoint(null)).request(
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

    const expected = [_]Request.QueryParam{
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

    const expected_path = "/_matrix/client/v3/fakestub/100%25%20legit%20CS%3AGO%20cheats/12345";
    try std.testing.expectEqualStrings(expected_path, request.path);
    try std.testing.expectEqual(null, request.body);
}

test "parse classifies responses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const E = Endpoint(TestEndpoint(null));

    const ok = try E.parse(arena.allocator(), 200, "{\"n\":7}");
    try std.testing.expectEqual(7, ok.ok.n);

    const matrix = try E.parse(arena.allocator(), 403,
        \\{"errcode":"M_FORBIDDEN","error":"nope"}
    );
    try std.testing.expectEqual(403, matrix.err.status);
    try std.testing.expectEqual(error.Forbidden, matrix.err.what.matrix.code());

    const proxy = try E.parse(arena.allocator(), 502, "<html>Bad Gateway</html>");
    try std.testing.expectEqual(502, proxy.err.status);
    try std.testing.expect(proxy.err.what == .other);
    try std.testing.expectEqualStrings("<html>Bad Gateway</html>", proxy.err.what.other);
}

test "supports compares added_in against server versions" {
    const versions = &.{
        common.SpecVersion.from(1, 19),
        common.SpecVersion.from(1, 18),
    };

    try std.testing.expect(Endpoint(TestEndpoint(null)).supports(versions));
    try std.testing.expect(Endpoint(TestEndpoint(.from(1, 18))).supports(versions));
    try std.testing.expect(!Endpoint(TestEndpoint(.from(1, 20))).supports(versions));
}

test "format writes method and path template" {
    var buf: [128]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);

    try Endpoint(TestEndpoint(null)).format(&w);
    try std.testing.expectEqualStrings("GET /_matrix/client/v3/fakestub/{q}/{t}", w.buffered());
}

test {
    std.testing.refAllDecls(@This());
}
