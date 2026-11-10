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
