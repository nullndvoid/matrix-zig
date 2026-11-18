//! Server Discovery.
//!
//! https://spec.matrix.org/v1.19/client-server-api/#server-discovery
//!
//! The `/.well-known/` endpoints are issued against the *server name*, not the
//! homeserver URL (`Request.Base.server_name`), and are not necessarily served
//! by the homeserver itself.

const std = @import("std");
const Allocator = std.mem.Allocator;

const common = @import("common.zig");
const endpoint = @import("Endpoint.zig");
const Endpoint = endpoint.Endpoint;

const definitions = @import("definitions.zig");

/// Gets discovery information about the domain. The file may include
/// additional keys, which MUST follow the Java package naming convention.
///
/// https://spec.matrix.org/v1.19/client-server-api/#getwell-knownmatrixclient
///
/// # Notes
///
/// - `404` should be ignored, setting the server name to the homeserver.
pub const WellKnownClient = struct {
    pub const method: std.http.Method = .GET;
    pub const base: common.BaseKind = .server_name;
    pub const path = "/.well-known/matrix/client";
    pub const auth: common.Auth = .none;
    pub const added_in: ?common.SpecVersion = null;
    pub const rate_limited = false;

    pub const Path = void;
    pub const Query = void;
    pub const Body = void;
    pub const Response = ?definitions.DiscoveryInformation;

    const E = Endpoint(@This());

    pub fn parse(arena: Allocator, status: u16, body: []const u8) Allocator.Error!E.Outcome {
        return switch (status) {
            200 => blk: {
                const resp = try endpoint.parseJson(
                    // Override the optional response type since the request
                    // succeeded.
                    definitions.DiscoveryInformation,
                    arena,
                    body,
                    status,
                );

                break :blk switch (resp) {
                    .ok => |info| .{ .ok = info },
                    .err => |fail| .{ .err = fail },
                };
            },
            404 => .{ .ok = null },
            else => E.defaultParse(arena, status, body),
        };
    }
};

/// Gets server admin contact and support page of the domain.
///
/// https://spec.matrix.org/v1.19/client-server-api/#getwell-knownmatrixsupport
///
/// # Errors
///
/// - `404` no server support information available.
pub const WellKnownSupport = struct {
    pub const method: std.http.Method = .GET;
    pub const base: common.BaseKind = .server_name;
    pub const path = "/.well-known/matrix/support";
    pub const auth: common.Auth = .none;
    pub const added_in: ?common.SpecVersion = .from(1, 10);
    pub const rate_limited = false;

    pub const Path = void;
    pub const Query = void;
    pub const Body = void;
    pub const Response = struct {
        /// Ways to contact the server administrator. At least one of
        /// `contacts` or `support_page` is required. If only `contacts` is
        /// set, it must contain at least one item.
        contacts: ?[]const Contact = null,
        /// The URL of a page to give users help specific to the homeserver,
        /// like extra login/registration steps.
        support_page: ?[]const u8 = null,

        pub const Contact = struct {
            /// An email address to reach the administrator. At least one of
            /// `matrix_id` or `email_address` is required.
            email_address: ?[]const u8 = null,
            /// A Matrix user ID representing the administrator. It could be
            /// an account registered on a different homeserver so the
            /// administrator can be contacted when the homeserver is down.
            matrix_id: ?[]const u8 = null,
            /// An informal description of what the contact methods are used
            /// for. `m.role.admin` is a catch-all role for any queries and
            /// `m.role.security` is intended for sensitive requests.
            /// Unspecified, namespaced roles are permitted.
            role: []const u8,

            pub const role_admin = "m.role.admin";
            pub const role_security = "m.role.security";
        };
    };
};

/// Gets public key information for a Policy Server. Accessed with the
/// hostname of the *Policy Server's* server name.
///
/// https://spec.matrix.org/v1.19/client-server-api/#getwell-knownmatrixpolicy_server
///
/// # Errors
///
/// - `404` no policy server information available.
pub const WellKnownPolicyServer = struct {
    pub const method: std.http.Method = .GET;
    pub const base: common.BaseKind = .server_name;
    pub const path = "/.well-known/matrix/policy_server";
    pub const auth: common.Auth = .none;
    pub const added_in: ?common.SpecVersion = .from(1, 18);
    pub const rate_limited = false;

    pub const Path = void;
    pub const Query = void;
    pub const Body = void;
    pub const Response = struct {
        /// The unpadded base64-encoded public keys for the Policy Server,
        /// keyed by key algorithm. MUST contain at least `ed25519`. Can be
        /// supplied to the `m.room.policy` state event.
        public_keys: std.json.ArrayHashMap([]const u8),
    };
};

/// Gets the versions of the specification supported by the server.
///
/// Values take the form `vX.Y`, or `rX.Y.Z` in historical cases. The server
/// may additionally advertise experimental features through
/// `unstable_features`. Servers can enable some features only for some users,
/// so clients should include authentication to get all features available to
/// the logged-in user; without it only features available to all users are
/// returned.
///
/// https://spec.matrix.org/v1.19/client-server-api/#get_matrixclientversions
///
/// Changed in v1.10: this endpoint can behave differently when authentication
/// is provided.
pub const Versions = struct {
    pub const method: std.http.Method = .GET;
    pub const base: common.BaseKind = .homeserver;
    pub const path = "/_matrix/client/versions";
    pub const auth: common.Auth = .optional;
    pub const added_in: ?common.SpecVersion = null;
    pub const rate_limited = false;

    pub const Path = void;
    pub const Query = void;
    pub const Body = void;
    pub const Response = struct {
        /// The supported versions.
        versions: []const []const u8,
        /// Experimental features the server supports, mapped to whether the
        /// namespaced feature is supported. Features not listed here, or the
        /// lack of this property altogether, indicate that a feature is not
        /// supported.
        unstable_features: ?std.json.ArrayHashMap(bool) = null,
    };
};

test "parse well-known client response" {
    const json =
        \\{"m.homeserver":{"base_url":"https://matrix.example.com"},
        \\ "m.identity_server":{"base_url":"https://identity.example.com"},
        \\ "com.example.custom":1}
    ;
    const parsed = try std.json.parseFromSlice(
        WellKnownClient.Response,
        std.testing.allocator,
        json,
        common.parse_options,
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings(
        "https://matrix.example.com",
        parsed.value.?.@"m.homeserver".base_url,
    );
    try std.testing.expectEqualStrings(
        "https://identity.example.com",
        parsed.value.?.@"m.identity_server".?.base_url,
    );
}

test "well-known client - Endpoint parse" {
    const E = Endpoint(WellKnownClient);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    // Status, Body, Expected.
    const cases = .{
        .{
            200,
            \\{"m.homeserver":{"base_url":"https://matrix.org"}}
            ,
            E.Outcome{ .ok = .{ .@"m.homeserver" = .{ .base_url = "https://matrix.org" } } },
        },
        .{ 404, "", E.Outcome{ .ok = null } },
        .{
            200, "<html><p>This ain't right...</p></html>",
            E.Outcome{
                .err = .{
                    .status = 200,
                    .what = .{ .malformed = "<html><p>This ain't right...</p></html>" },
                },
            },
        },
        .{
            200, "",
            E.Outcome{ .err = .{
                .status = 200,
                .what = .{ .malformed = "" },
            } },
        },
        .{
            500, "",
            E.Outcome{
                .err = .{
                    .status = 500,
                    .what = .{ .other = "" },
                },
            },
        },
    };

    inline for (cases) |c| {
        const status, const body, const expected = c;

        const got = try E.parse(arena.allocator(), status, body);

        try std.testing.expectEqualDeep(expected, got);
    }
}

test "parse versions response" {
    const json =
        \\{"versions":["v1.18","v1.19"],"unstable_features":{"org.example.feature":true}}
    ;
    const parsed = try std.json.parseFromSlice(
        Versions.Response,
        std.testing.allocator,
        json,
        common.parse_options,
    );
    defer parsed.deinit();

    try std.testing.expectEqual(2, parsed.value.versions.len);
    try std.testing.expectEqualStrings("v1.19", parsed.value.versions[1]);
    try std.testing.expectEqual(
        true,
        parsed.value.unstable_features.?.map.get("org.example.feature").?,
    );
}

test {
    endpoint.checkAll(@This());

    std.testing.refAllDecls(@This());
}
