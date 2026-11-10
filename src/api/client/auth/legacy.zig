const std = @import("std");

const common = @import("../common.zig");
const definitions = @import("../definitions.zig");

pub const LoginFlows = struct {
    pub const method: std.http.Method = .GET;
    pub const base: common.BaseKind = .homeserver;
    pub const path = "/_matrix/client/v3/login";
    pub const auth: common.Auth = .none;
    pub const added_in: ?common.SpecVersion = null;
    pub const rate_limited = true;

    pub const Path = void;
    pub const Query = void;
    pub const Body = void;
    pub const Response = struct {
        flows: []const LoginFlow,
    };

    pub const LoginFlow = struct {
        /// If type is `m.login.token`, an optional field to indicate to the
        /// unauthenticated client that the homeserver supports the
        /// POST /login/get_token endpoint. Note that supporting the
        /// endpoint does not necessarily indicate that the user
        /// attempting to log in will be able to generate such a token.
        get_login_token: ?bool = null,

        /// **Required:** The login type. This is supplied as the type
        /// when logging in.
        type: []const u8,
    };
};

pub const Login = struct {
    pub const method: std.http.Method = .POST;
    pub const base: common.BaseKind = .homeserver;
    pub const path = "/_matrix/client/v3/login";
    pub const auth: common.Auth = .none;
    pub const added_in: ?common.SpecVersion = null;
    pub const rate_limited = true;

    pub const Path = void;
    pub const Query = void;
    pub const Body = struct {
        auth: Auth,
        device_id: ?[]const u8 = null,

        /// I should remember to skip optional fields.
        pub fn jsonStringify(self: @This(), jws: anytype) !void {
            try jws.beginObject();

            try common.writeTypedFieldsJson(jws, "m.login.", self.auth);

            if (self.device_id) |id| {
                try jws.objectField("device_id");
                try jws.write(id);
            }

            try jws.endObject();
        }
    };

    pub const Response = struct {};

    pub const Auth = union(enum) {
        password: struct {
            identifier: UserIdentifier,
            password: []const u8,
        },
        token: struct {
            token: []const u8,
        },
    };

    pub const UserIdentifier = union(enum) {
        user: []const u8,
        thirdparty: struct {
            medium: []const u8,
            address: []const u8,
        },
        phone: struct {
            country: []const u8,
            phone: []const u8,
        },

        pub fn jsonStringify(self: @This(), jws: anytype) !void {
            try jws.beginObject();
            try common.writeTypedFieldsJson(jws, "m.id.", self);
            try jws.endObject();
        }
    };
};

test "UserIdentifier json" {
    const gpa = std.testing.allocator;
    const cases = .{
        .{
            Login.UserIdentifier{ .user = "jacob" },
            \\{"type":"m.id.user","user":"jacob"}
        },
        .{
            Login.UserIdentifier{ .thirdparty = .{ .medium = "email", .address = "a@b.c" } },
            \\{"type":"m.id.thirdparty","medium":"email","address":"a@b.c"}
        },
        .{
            Login.UserIdentifier{ .phone = .{ .country = "GB", .phone = "0123" } },
            \\{"type":"m.id.phone","country":"GB","phone":"0123"}
        },
    };
    inline for (cases) |c| {
        const out = try std.json.Stringify.valueAlloc(gpa, c[0], .{});
        defer gpa.free(out);
        try std.testing.expectEqualStrings(c[1], out);
    }
}
