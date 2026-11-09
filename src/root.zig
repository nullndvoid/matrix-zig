const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const ClientEventSansRoomID = struct {};

/// A room ID.
///
/// This is intended to accept a maximal amount of valid room IDs.
///
/// Note that the [Room Versions Specification](https://spec.matrix.org/latest/rooms/)
/// defines what a valid room ID should be for a particular room version, so this may
/// matter if the client must submit valid room IDs.
pub const RoomId = struct {
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
};

/// A User ID.
///
/// Note that historically users were allowed characters that are
/// no longer accepted. This will not be enforced here so as to accept
/// older user IDs if sent from a server, but take note of this.
///
/// Perhaps I will add a stricter validatedInit method tracking the latest spec.
pub const UserId = struct {
    /// This is just a reference. Take care with ownership.
    data: []const u8,
    /// Slices the hostname inside `data`. May store a port if given.
    server_name: ServerName,

    pub const Error = error{InvalidUserId} || ServerName.ServerNameError;

    /// Attempts to parse a string into a `UserId`.
    ///
    /// Note that `s` is not copied, merely stored by reference.
    ///
    /// # Errors
    ///
    /// Returns `InvalidUserId` if `s` did not start with a '@' followed by some
    /// ~~valid~~ local part, followed by a ':', followed by a valid server name.
    ///
    /// If the server name part is invalid, returns `InvalidServerName`.
    ///
    /// # Notes
    ///
    /// The validity of local part is **not** checked, in order to allow older,
    /// previously valid user IDs.
    pub fn init(s: []const u8) Error!UserId {
        // Check the minimum length to allow checking first char is '@'.
        if (s.len < 1 or s.len > 255) return error.InvalidUserId;

        if (s[0] != '@') return error.InvalidUserId;

        // Must contain a domain part, which starts after the first ':'.
        // It must not be empty either i.e. idx should not equal s.len - 1.
        const idx = std.mem.findScalar(u8, s, ':') orelse
            return error.InvalidUserId;

        // This allows us to at least read idx + 1. `server_part` should not be
        // empty. `local_part` should also be non-empty.
        if (idx == s.len - 1 or idx == 1) return error.InvalidUserId;

        // Check for a valid server name.
        const server_part = s[idx + 1 ..];

        return .{
            .data = s,
            .server_name = try ServerName.init(server_part),
        };
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("{s}", .{self.data});
    }

    /// Parsed server name.
    pub const ServerName = struct {
        /// This is just a slice. Be wary with ownership.
        host: []const u8,
        port: ?u16,

        pub const ServerNameError = error{InvalidServerName};

        /// Attempts to parse a string into a `ServerName`.
        ///
        /// # Errors
        ///
        /// Returns errors for all strings not valid under the specification.
        pub fn init(s: []const u8) ServerNameError!ServerName {
            if (s.len < 1) return error.InvalidServerName;

            if (s[0] == '[') {
                const end_bracket_idx = std.mem.findScalar(u8, s, ']') orelse
                    return error.InvalidServerName;
                const host = s[1..end_bracket_idx];

                if (host.len < 2 or host.len > 45) return error.InvalidServerName;

                // Inner characters should be hex / ':' / '.'.
                for (host) |c| {
                    switch (c) {
                        ':', '.', '0'...'9', 'a'...'f', 'A'...'F' => {},
                        else => return error.InvalidServerName,
                    }
                }

                // After the host, we expect either nothing, or a ':' followed
                // by a port.
                if (end_bracket_idx == s.len - 1)
                    return .{ .host = host, .port = null };

                if (s[end_bracket_idx + 1] != ':')
                    return error.InvalidServerName;

                const port = try parsePort(s[end_bracket_idx + 2 ..]);

                return .{ .host = host, .port = port };
            }

            const port_start = std.mem.findScalar(u8, s, ':');

            const port: ?u16 = p: {
                const start = port_start orelse break :p null;

                // Another ':' is an error.
                const another = std.mem.findScalarPos(u8, s, start + 1, ':');
                if (another != null)
                    return error.InvalidServerName;

                break :p try parsePort(s[start + 1 ..]);
            };

            const host = s[0 .. port_start orelse s.len];
            if (host.len < 1 or host.len > 255) return error.InvalidServerName;

            for (host) |c| {
                if (std.ascii.isAlphanumeric(c) or c == '-' or c == '.')
                    continue;

                return error.InvalidServerName;
            }

            return .{ .host = host, .port = port };
        }

        fn parsePort(s: []const u8) ServerNameError!u16 {
            if (s.len < 1 or s.len > 5) return error.InvalidServerName;
            for (s) |c| if (!std.ascii.isDigit(c)) return error.InvalidServerName;

            return std.fmt.parseInt(u16, s, 10) catch error.InvalidServerName;
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try writer.print("{s}", .{self.data});
        }

        test "parse server names" {
            const valid_inputs = &[_][]const u8{
                "matrix.org",
                "matrix.org:8888",
                "1.2.3.4",
                "1.2.3.4:1234",
                "[1234:5678::abcd]",
                "[1234:5678::abcd]:5678",
                "[::1]:5",
            };

            for (valid_inputs) |input| {
                _ = try ServerName.init(input);
            }
        }

        test "reject invalid server names" {
            const invalid_inputs = &[_][]const u8{
                "",
                ":8080",
                "matrix.org:",
                "matrix.org:999999",
                "matrix.org:65536",
                "a:b:c",
                "[::1",
                "[]",
                "[::1]x",
                " ",
                "[]",
                "[::g]",
                "exam\nple.org",
                "matrix.org:8_0",
                "___-1234:5678::abcd]:5678",
                "@__@ hello!",
            };

            for (invalid_inputs) |input| {
                try std.testing.expectError(
                    error.InvalidServerName,
                    ServerName.init(input),
                );
            }
        }
    };

    test "parse user ids" {
        const valid_inputs = &[_][]const u8{
            "@nullndvoid:matrix.org",
            "@abcd:matrix.org:8888",
            "@foobar:1.2.3.4",
            "@joe:[1234:5678::abcd]",
            "@mike:[1234:5678::abcd]:5678",
            "@alice:[::1]:5",
            "@bob:bob.com",
        };

        for (valid_inputs) |input| {
            _ = try UserId.init(input);
        }
    }

    test "parse invalid user ids: local part" {
        // Notice we don't check much besides requiring non-empty and '@' at start.
        // Oh, we also require there to be a server name after a colon.
        const invalid_inputs = &[_][]const u8{
            "alice",
            "@:",
            "a:example.org",
            "bob:matrix.org",
        };

        for (invalid_inputs) |input| {
            try std.testing.expectError(
                error.InvalidUserId,
                UserId.init(input),
            );
        }
    }

    test "parse invalid user ids: server name" {
        // Note: Empty local part is going to return InvalidUserId.
        const invalid_inputs = &[_][]const u8{
            "@alice:[bullshit]",
            "@a:example.org:",
            "@bob:matrix.org+1",
        };

        for (invalid_inputs) |input| {
            try std.testing.expectError(
                error.InvalidServerName,
                UserId.init(input),
            );
        }
    }
};

test {
    std.testing.refAllDecls(@This());
}
