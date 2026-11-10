//! For schemas reused by more than one file in a section. Can be expanded as I
//! fill out the endpoints.

/// Used by clients to discover homeserver and identity server URLs. Returned by
/// `GET /.well-known/matrix/client` and optionally in the `POST /login`
/// response (`well_known`).
pub const DiscoveryInformation = struct {
    /// Used by clients to discover homeserver information.
    @"m.homeserver": HomeserverInformation,
    /// Used by clients to discover identity server information.
    @"m.identity_server": ?IdentityServerInformation = null,

    pub const HomeserverInformation = struct {
        /// The base URL for the homeserver for client-server connections.
        base_url: []const u8,
    };

    pub const IdentityServerInformation = struct {
        /// The base URL for the identity server for client-server connections.
        base_url: []const u8,
    };
};
