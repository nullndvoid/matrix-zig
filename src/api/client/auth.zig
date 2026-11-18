const std = @import("std");

const common = @import("common.zig");
const endpoint = @import("Endpoint.zig");
const Endpoint = endpoint.Endpoint;

pub const legacy = @import("auth/legacy.zig");

pub const WhoAmI = struct {
    pub const method: std.http.Method = .GET;
    pub const base: common.BaseKind = .homeserver;
    pub const path = "/_matrix/client/v3/account/whoami";
    pub const auth: common.Auth = .access_token;
    pub const added_in: ?common.SpecVersion = null;
    pub const rate_limited: bool = true;

    pub const Path = void;
    pub const Query = void;
    pub const Body = void;
    pub const Response = struct {
        device_id: ?[]const u8 = null,
        is_guest: bool = false,
        user_id: []const u8,
    };
};

test {
    endpoint.checkAll(@This());

    std.testing.refAllDecls(@This());
}
