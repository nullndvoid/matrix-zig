# matrix-zig: Matrix Client-Server API bindings for Zig

This is work in progress, but I would like a nice simple set of bindings for use in implementing Matrix clients.

I may later add other APIs from the specs on matrix.org.

I feel free to write rough notes in here for my own understanding.

## Sans-I/O

I want this to be a testable library that is flexible between various different clients using it, so I will try to stay
sans-I/O.

I can make a nicer client wrapper around this later.

- Events are extensible JSON objects
- We sync comms history with the homeserver (E2EE, TODO: impl e2ee)
- Clients talk in a "room", emitting events.
- Each homeserver stores comms history and account info for all clients. -> synced with other homeservers and their clients

- Homeserver models comms history as partially ordered events in rooms "event graph" -> Synced using server-server API (currently out of scope but I would be happy to impl at a later date, s.t. I can write my own homeserver implementation, because I am not a huge fan of Synapse)
- Syncing between homeservers is known as "federation"

For Alice to message Bob:

Alice issues a PUT with required event to her HS over client-server API
HS signs and issues to Bob's HS
Bobs client recieves the event via long-lived GET request.

Done

## Users

A client is associated with an account i.e. `@jacob:nullndvoid.xyz` (how repetitive). ID is namespaced to its homeserver.

## Devices

Devices manage keys used for E2EE (each _device_ gets its own copy of keys, think WhatsApp). They also help users manage keys i.e. revocation of compromised keys.

Not the same as a client, but in initial setup, the client will register itself as a device on the user's account.

Identified by a `device_id`. Users can give these human readable names.

If a user session expires, on a desktop client or mobile app we may reuse the device provided the user is the same user.

## Events

All data exchanged over Matrix is an "event". Typically each client action issues 1 event (e.g. sending a message).

Events have types, which MUST follow java namespace convention e.g. m.room.message.

Event fields are not trusted by homeservers, but this is fine so long as we only care about writing clients.

Events are typically sent in the context of a "room".

https://www.matrix.org/docs/matrix-concepts/rooms_and_events/

### Event Graphs

Events are stored in a DAG called an "event graph". The partial ordering of the graph gives the chronological ordering of events in the room.

An event in the list has 0 or more "parent" events, which refer to events that have no chronological successor from the perspective of the HS which created the event.

An event typically has one parent, i.e. the most recent message in the room at the point at which it was sent.

Homeservers could race with one another, thus events will have depths on the HS, which should be larger than 1 (the root event's depth). Larger depth means it happened later on.

## Rooms

A room is a place where users can send and recieve events. `!opaque_id:domain`.

The domain is used for namespacing, but does not live on the domain specified.

Federation maintains shared data structures between various HSs.

> Split into `message events` and `state events`.

Message events are one-off events i.e. messages, VoIP call starts

State events are 'persistent', usually a lookup table of KV pairs per room.

State of a room at a given point is calculated by considering all events prior to and including an event at a certain point in the graph. If events describe the same state, merge conflict res algo is applied.

State res algo is transitive i.e. A -> B -> C is akin to updating A -> C?

### Room Aliases

Rooms can be aliased like `#room_alias:domain`. This is subject to changes if room owners decide to change the alias, so clients SHOULD (possibly caching this information) resolve alias to `rid` once. This `rid` is fixed and will not change.

## Identity

We have users id'ed by their Matrix user ID. A Matrix "identity" describes both the user ID and ID from other places (3PIDs) that can be linked.

"Identity servers" (IS) federate, verifying and providing mappings to/from 3PIDs.

Usage of an IS is not required for clients to use Matrix, but users will not be able to lookup user IDs using 3PIDs.

## Profiles

Users can publish arbitrary KV pairs with their account

- Could this be used for swanky nitro-like features for supported clients?
  - Furthermore could be an extension or Matrix spec request?

## Private User Data

Users can store arbitrary KV data in their account. This is symmetrical to profile data management, except these are marked as private. (Could they be encrypted??)

- Can be used to sync client prefs, which could be cool as a cross-platform feature.

## Common Things

Events are namespaced. Spec events MUST start with an `m.`. Custom events MUST start with java namespacing i.e. `xyz.nullndvoid`.

Timestamps are ms elapsed since UNIX epoch, not including leap seconds. Should be standard for Zig anyway.

Spec versions are vX.Y. X increments may have large breaking changes.

Y's are managed or back-compat. I plan to start with current spec version at this time (v.1.19).

Deprecations can go into effect after a version bump has passed.

API endpoints will be versioned, and the version shall be bumped if the API usage is changed.

## Types of events a client may encounter

Event DAGs get linearised by the HS.

- `ClientEvent`
- `ClientEventWithoutRoomID`
- `StrippedStateEvent`
- `Event`
- `ToDeviceEvent`

StrippedState could be used when the client should not yet have the full state i.e. on invitation, you only need some room metadata like the name, image etc. Once the full state is availiable, the Stripped State SHOULD be discarded.

If the client has any archived state e.g. after being kicked, stripped state should take precedence until fresh state is supplied.

Stripped state SHOULD contain some events as per spec.

Stripped state COULD be invalid, and is unsigned so shouldn't really be trusted for anything critical.

Servers need to prune state changes from other HSes into proper stripped state events



# TODOs

- Enumerate standard error types?
- Model events

## Authors

- nullndvoid
