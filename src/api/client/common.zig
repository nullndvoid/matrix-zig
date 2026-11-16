const std = @import("std");

/// The auth-level required for a given API operation.
pub const Auth = enum {
    none,
    /// Usually this means that authentication is suggested.
    optional,
    access_token,
    appservice_token,
};

pub const BaseKind = enum {
    /// Used before server discovery.
    server_name,
    homeserver,
};

pub const parse_options = std.json.ParseOptions{
    .ignore_unknown_fields = true,
};

pub const serialise_options = std.json.Stringify.Options{
    .emit_null_optional_fields = false,
};

pub const Bytes = struct {
    content_type: []const u8,
    content_disposition: ?[]const u8 = null,
    body: []const u8,
};

pub const Error = struct {
    errcode: []const u8,
    @"error": []const u8,
    retry_after_ms: ?u64 = null,
    soft_logout: ?bool = null,

    /// Classifies `errcode`. Returns `error.Other` for codes not known to
    /// this library (including non-`M_` namespaced codes); the raw string is
    /// still available in `errcode`.
    pub fn code(self: Error) ErrorCode {
        return ERROR_CODE_MAP.get(self.errcode) orelse error.Other;
    }
};

/// The standard error codes (`M_*`) as of spec v1.19.
///
/// https://spec.matrix.org/v1.19/client-server-api/#standard-error-response
pub const ErrorCode = error{
    // Common error codes.
    Forbidden,
    UnknownToken,
    MissingToken,
    UserLocked,
    UserSuspended,
    BadJSON,
    NotJSON,
    NotFound,
    LimitExceeded,
    Unrecognized,
    Unknown,
    // Other error codes.
    Unauthorized,
    UserDeactivated,
    UserInUse,
    InvalidUsername,
    RoomInUse,
    InvalidRoomState,
    ThreePIDInUse,
    ThreePIDNotFound,
    ThreePIDAuthFailed,
    ThreePIDDenied,
    ServerNotTrusted,
    UnsupportedRoomVersion,
    IncompatibleRoomVersion,
    BadState,
    GuestAccessForbidden,
    CaptchaNeeded,
    CaptchaInvalid,
    MissingParam,
    InvalidParam,
    TooLarge,
    Exclusive,
    ResourceLimitExceeded,
    CannotLeaveServerNoticeRoom,
    ThreePIDMediumNotSupported,
    UserLimitExceeded,
    UnknownDevice,
    WeakPassword,
    // Codes defined only in individual endpoint descriptions.
    InviteBlocked,
    InvalidSignature,
    WrongRoomKeysVersion,
    BadStatus,
    AppserviceLoginUnsupported,
    UrlNotSet,
    ConnectionTimeout,
    ConnectionFailed,
    CannotOverwriteMedia,
    NotYetUploaded,
    BadAlias,
    ProfileTooLarge,
    KeyTooLarge,
    DuplicateAnnotation,
    /// Another error code was returned.
    ///
    /// See `errcode` if you have an `Error`.
    Other,
};

const ERROR_CODE_MAP = std.StaticStringMap(ErrorCode).initComptime(.{
    .{ "M_FORBIDDEN", error.Forbidden },
    .{ "M_UNKNOWN_TOKEN", error.UnknownToken },
    .{ "M_MISSING_TOKEN", error.MissingToken },
    .{ "M_USER_LOCKED", error.UserLocked },
    .{ "M_USER_SUSPENDED", error.UserSuspended },
    .{ "M_BAD_JSON", error.BadJSON },
    .{ "M_NOT_JSON", error.NotJSON },
    .{ "M_NOT_FOUND", error.NotFound },
    .{ "M_LIMIT_EXCEEDED", error.LimitExceeded },
    .{ "M_UNRECOGNIZED", error.Unrecognized },
    .{ "M_UNKNOWN", error.Unknown },
    .{ "M_UNAUTHORIZED", error.Unauthorized },
    .{ "M_USER_DEACTIVATED", error.UserDeactivated },
    .{ "M_USER_IN_USE", error.UserInUse },
    .{ "M_INVALID_USERNAME", error.InvalidUsername },
    .{ "M_ROOM_IN_USE", error.RoomInUse },
    .{ "M_INVALID_ROOM_STATE", error.InvalidRoomState },
    .{ "M_THREEPID_IN_USE", error.ThreePIDInUse },
    .{ "M_THREEPID_NOT_FOUND", error.ThreePIDNotFound },
    .{ "M_THREEPID_AUTH_FAILED", error.ThreePIDAuthFailed },
    .{ "M_THREEPID_DENIED", error.ThreePIDDenied },
    .{ "M_SERVER_NOT_TRUSTED", error.ServerNotTrusted },
    .{ "M_UNSUPPORTED_ROOM_VERSION", error.UnsupportedRoomVersion },
    .{ "M_INCOMPATIBLE_ROOM_VERSION", error.IncompatibleRoomVersion },
    .{ "M_BAD_STATE", error.BadState },
    .{ "M_GUEST_ACCESS_FORBIDDEN", error.GuestAccessForbidden },
    .{ "M_CAPTCHA_NEEDED", error.CaptchaNeeded },
    .{ "M_CAPTCHA_INVALID", error.CaptchaInvalid },
    .{ "M_MISSING_PARAM", error.MissingParam },
    .{ "M_INVALID_PARAM", error.InvalidParam },
    .{ "M_TOO_LARGE", error.TooLarge },
    .{ "M_EXCLUSIVE", error.Exclusive },
    .{ "M_RESOURCE_LIMIT_EXCEEDED", error.ResourceLimitExceeded },
    .{ "M_CANNOT_LEAVE_SERVER_NOTICE_ROOM", error.CannotLeaveServerNoticeRoom },
    .{ "M_THREEPID_MEDIUM_NOT_SUPPORTED", error.ThreePIDMediumNotSupported },
    .{ "M_USER_LIMIT_EXCEEDED", error.UserLimitExceeded },
    .{ "M_UNKNOWN_DEVICE", error.UnknownDevice },
    .{ "M_WEAK_PASSWORD", error.WeakPassword },
    .{ "M_INVITE_BLOCKED", error.InviteBlocked },
    .{ "M_INVALID_SIGNATURE", error.InvalidSignature },
    .{ "M_WRONG_ROOM_KEYS_VERSION", error.WrongRoomKeysVersion },
    .{ "M_BAD_STATUS", error.BadStatus },
    .{ "M_APPSERVICE_LOGIN_UNSUPPORTED", error.AppserviceLoginUnsupported },
    .{ "M_URL_NOT_SET", error.UrlNotSet },
    .{ "M_CONNECTION_TIMEOUT", error.ConnectionTimeout },
    .{ "M_CONNECTION_FAILED", error.ConnectionFailed },
    .{ "M_CANNOT_OVERWRITE_MEDIA", error.CannotOverwriteMedia },
    .{ "M_NOT_YET_UPLOADED", error.NotYetUploaded },
    .{ "M_BAD_ALIAS", error.BadAlias },
    .{ "M_PROFILE_TOO_LARGE", error.ProfileTooLarge },
    .{ "M_KEY_TOO_LARGE", error.KeyTooLarge },
    .{ "M_DUPLICATE_ANNOTATION", error.DuplicateAnnotation },
});

test "error code classification" {
    const known = Error{ .errcode = "M_FORBIDDEN", .@"error" = "nope" };
    try std.testing.expectEqual(error.Forbidden, known.code());

    const custom = Error{ .errcode = "COM_EXAMPLE_CUSTOM", .@"error" = "?" };
    try std.testing.expectEqual(error.Other, custom.code());

    // Every error in the set except `Other` must be reachable from the map.
    comptime {
        const names = @typeInfo(ErrorCode).error_set.error_names.?;
        if (ERROR_CODE_MAP.values().len != names.len - 1)
            @compileError("ERROR_CODE_MAP does not cover every ErrorCode");
    }
}

/// A released specification version. I see no point in supporting beta/rc
/// versions at this moment.
pub const SpecVersion = struct {
    major: u8,
    minor: u8,

    pub fn from(major: u8, minor: u8) SpecVersion {
        return .{ .major = major, .minor = minor };
    }

    pub const SpecVersionError = error{InvalidSpecVersion};

    /// Attempts to parse a slice `s` into a `SpecVersion`.
    ///
    /// If parsing fails, the given `s` should be skipped.
    ///
    /// It is likely an old version or a beta which is not claimed to be
    /// supported.
    pub fn parse(s: []const u8) SpecVersionError!SpecVersion {
        // Shortest version is "vX.Y".
        if (s.len < 4) return error.InvalidSpecVersion;

        if (s[0] != 'v') return error.InvalidSpecVersion;

        const dot = std.mem.findScalar(u8, s, '.') orelse
            return error.InvalidSpecVersion;

        if (dot == 1) return error.InvalidSpecVersion;

        const major = s[1..dot];

        if (std.mem.findScalarPos(u8, s, dot + 1, '.')) |_| {
            return error.InvalidSpecVersion;
        }

        if (dot == s.len - 1) return error.InvalidSpecVersion;

        const minor = s[dot + 1 ..];

        for (major) |d| if (!std.ascii.isDigit(d)) return error.InvalidSpecVersion;
        for (minor) |d| if (!std.ascii.isDigit(d)) return error.InvalidSpecVersion;

        return .{
            .major = std.fmt.parseUnsigned(u8, major, 10) catch
                return error.InvalidSpecVersion,
            .minor = std.fmt.parseUnsigned(u8, minor, 10) catch
                return error.InvalidSpecVersion,
        };
    }

    /// Returns the ordering between `self` and `other`, relative to `self`.
    pub fn order(self: SpecVersion, other: SpecVersion) std.math.Order {
        if (self.major > other.major) return .gt;
        if (self.major < other.major) return .lt;

        if (self.minor > other.minor) return .gt;
        if (self.minor < other.minor) return .lt;

        return .eq;
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("v{d}.{d}", .{ self.major, self.minor });
    }

    test "parse valid spec versions" {
        const one_one = try parse("v1.01");
        const another_version = try parse("v1.19");

        try std.testing.expectEqualDeep(SpecVersion{
            .major = 1,
            .minor = 1,
        }, one_one);

        try std.testing.expectEqualDeep(SpecVersion{
            .major = 1,
            .minor = 19,
        }, another_version);
    }

    test "fail on invalid spec versions" {
        const failing = &[_][]const u8{
            "",
            "v1.1f",
            "1.234",
            "NOT A VERSION",
            "v1.19.2",
        };

        for (failing) |f|
            try std.testing.expectError(error.InvalidSpecVersion, parse(f));
    }
};

/// Helper function. Returns true if the endpoint is supported.
pub fn supports(comptime Endpoint: type, server: []const SpecVersion) bool {
    const needed = Endpoint.added_in orelse return true;
    for (server) |v| if (v.order(needed) != .lt) return true;
    return false;
}

/// Stringifies structs and tagged unions. Add a
/// `pub const flatten = .{ .field_name = "m.prefix" };`
/// field to structs to flatten tagged unions matrix style.
///
/// Add a `type_prefix` decl to tagged unions when you need.
///
/// The compiler should guide you to the right path, but unit
/// tests can enforce this.
///
/// _This should be used instead of manual `jsonStringify`_.
///
/// _Additionally, I will make it a requirement that all `Body` types
/// declare a `jsonStringify` if not present._
pub fn stringify(self: anytype, jws: anytype) !void {
    const T = @TypeOf(self);

    try jws.beginObject();

    switch (@typeInfo(T)) {
        .@"union" => {
            if (comptime !@hasDecl(T, "type_prefix"))
                @compileError(@typeName(T) ++ " is a union; declare `pub const type_prefix = \"...\";`");
            try writeTypedFieldsJson(jws, T.type_prefix, self);
        },
        .@"struct" => {
            const flatten = comptime if (@hasDecl(T, "flatten")) T.flatten else .{};
            const names = @typeInfo(@TypeOf(flatten)).@"struct".field_names;

            comptime for (names) |n| {
                if (!@hasField(T, n))
                    @compileError(@typeName(T) ++ " has no field '" ++ n ++ "' but it is named in `flatten`");
                if (@typeInfo(@TypeOf(@field(flatten, n))) != .pointer)
                    @compileError(@typeName(T) ++ ".flatten." ++ n ++ " must be a type prefix string");
            };

            try writeFields(jws, self, names);

            inline for (names) |n| {
                const v = @field(self, n);
                const prefix = @field(flatten, n);
                if (@typeInfo(@TypeOf(v)) == .optional) {
                    if (v) |inner| try writeTypedFieldsJson(jws, prefix, inner);
                } else {
                    try writeTypedFieldsJson(jws, prefix, v);
                }
            }
        },
        else => @compileError("stringify only supports structs and tagged unions, got " ++ @typeName(T)),
    }

    try jws.endObject();
}

/// Writes `"type": "<prefix><tag>"`, then flattens the active payload into an
/// object the caller has already opened. Use this in `jsonStringify` where you
/// have a field that is a tagged union.
fn writeTypedFieldsJson(jws: anytype, comptime prefix: []const u8, val: anytype) !void {
    switch (val) {
        inline else => |payload, tag| {
            const P = @TypeOf(payload);

            try jws.objectField("type");
            try jws.write(prefix ++ @tagName(tag));

            switch (@typeInfo(P)) {
                .@"struct" => {
                    if (comptime @hasField(P, "type"))
                        @compileError("variant '" ++ @tagName(tag) ++ "': " ++ @typeName(P) ++
                            " has a `type` field, which would duplicate the discriminator");
                    try writeFields(jws, payload, &.{});
                },
                .void => {},
                .optional => @compileError("variant '" ++ @tagName(tag) ++ "' has optional payload " ++
                    @typeName(P) ++ "; use void or split it into separate variants"),
                else => {
                    comptime checkFlattenable(P, "variant '" ++ @tagName(tag) ++ "'");
                    try jws.objectField(@tagName(tag));
                    try jws.write(payload);
                },
            }
        },
    }
}

/// Writes every field of a struct into an already-open object, skipping null optionals.
fn writeFields(jws: anytype, val: anytype, comptime skip: []const []const u8) !void {
    const T = @TypeOf(val);

    comptime for (skip) |name| {
        if (!@hasField(T, name)) @compileError(@typeName(T) ++ " has no field '" ++ name ++ "'");
    };

    inline for (@typeInfo(T).@"struct".field_names) |f| {
        const v = @field(val, f);
        const FT = @TypeOf(v);

        if (comptime contains(skip, f)) continue;

        comptime checkFlattenable(FT, @typeName(T) ++ "." ++ f);

        if (@typeInfo(FT) == .optional) {
            if (v) |inner| {
                try jws.objectField(f);
                try jws.write(inner);
            }
        } else {
            try jws.objectField(f);
            try jws.write(v);
        }
    }
}

fn contains(comptime list: []const []const u8, comptime name: []const u8) bool {
    for (list) |s| if (std.mem.eql(u8, s, name)) return true;
    return false;
}

/// A union without its own jsonStringify would be written in std.json's
/// `{"tag": payload}` form instead of Matrix's flat `{"type": ...}` form.
fn checkFlattenable(comptime T: type, comptime where: []const u8) void {
    const U = switch (@typeInfo(T)) {
        .optional => |o| o.child,
        else => T,
    };

    if (@typeInfo(U) == .@"union" and !std.meta.hasFn(U, "jsonStringify"))
        @compileError(where ++ ": union " ++ @typeName(U) ++
            " needs a jsonStringify, or it will serialise as {\"tag\": ...}" ++ "\n\n" ++
            "Hint: Add the field containing this tagged union to `pub const flatten`.");
}

test {
    std.testing.refAllDecls(@This());
}

test "supports works with endpoint with no added_in" {
    const versions = &.{
        SpecVersion.from(1, 19),
        SpecVersion.from(1, 18),
    };

    const Endpoint = struct {
        pub const added_in: ?SpecVersion = null;
    };

    try std.testing.expect(
        supports(Endpoint, versions),
    );
}

test "supports works with endpoint with lower/eq added_in" {
    const versions = &.{
        SpecVersion.from(1, 19),
        SpecVersion.from(1, 18),
    };

    const Endpoint = struct {
        pub const added_in: ?SpecVersion = .from(1, 18);
    };

    try std.testing.expect(
        supports(Endpoint, versions),
    );
}

test "writeTypedFieldsJson" {
    const gpa = std.testing.allocator;

    const U = union(enum) {
        dummy: void,
        bare: []const u8,
        fields: struct { a: []const u8, b: ?[]const u8 = null },
    };
    const W = struct {
        u: U,
        pub fn jsonStringify(self: @This(), jws: anytype) !void {
            try jws.beginObject();
            try writeTypedFieldsJson(jws, "m.test.", self.u);
            try jws.endObject();
        }
    };

    const cases = .{
        .{
            W{ .u = .dummy },
            \\{"type":"m.test.dummy"}
        },
        .{
            W{ .u = .{ .bare = "x" } },
            \\{"type":"m.test.bare","bare":"x"}
        },
        .{
            W{ .u = .{ .fields = .{ .a = "x" } } },
            \\{"type":"m.test.fields","a":"x"}
        },
    };

    inline for (cases) |c| {
        const out = try std.json.Stringify.valueAlloc(gpa, c[0], serialise_options);
        defer gpa.free(out);
        try std.testing.expectEqualStrings(c[1], out);
    }
}

test "stringify some type" {
    const gpa = std.testing.allocator;

    const T = struct {
        name: []const u8,
        auth: union(enum) {
            login: struct { email: []const u8, password: []const u8 },
            token: []const u8,
        },

        pub const flatten = .{
            .auth = "",
        };

        pub fn jsonStringify(self: @This(), jws: anytype) !void {
            try stringify(self, jws);
        }
    };

    const cases = .{
        .{
            T{
                .name = "Jacob",
                .auth = .{ .login = .{
                    .email = "jacob@nullndvoid.xyz",
                    .password = "1234",
                } },
            },
            "{\"name\":\"Jacob\",\"type\":\"login\",\"email\":\"jacob@nullndvoid.xyz\",\"password\":\"1234\"}",
        },
    };

    inline for (cases) |c| {
        const out = try std.json.Stringify.valueAlloc(gpa, c[0], serialise_options);
        defer gpa.free(out);
        try std.testing.expectEqualStrings(c[1], out);
    }
}
