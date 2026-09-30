//! Events: what changed, the world's output.

use crate::{CityId, CommandType, Dimension, PlaceId, Point, ShownPresence, Tick};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Event {
    pub tick: Tick,
    /// Position in the whole run's log.
    pub seq: u64,
    /// True when the run was driven by a fixture feed.
    pub fixture: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub occupant: Option<CityId>,
    pub kind: EventKind,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "type")]
pub enum EventKind {
    Arrived {
        room: PlaceId,
    },
    Admitted {
        room: PlaceId,
    },
    Overflowed {
        from: PlaceId,
        to: PlaceId,
    },
    Waitlisted {
        room: PlaceId,
        position: u32,
    },
    Seated {
        room: PlaceId,
        seat: PlaceId,
    },
    SeatReleased {
        room: PlaceId,
        seat: PlaceId,
    },
    TransitStarted {
        from: PlaceId,
        to: PlaceId,
        door: PlaceId,
        arrives_at: Tick,
    },
    TransitEnded {
        to: PlaceId,
    },
    Departed {
        #[serde(default)]
        from: Option<PlaceId>,
        /// The vehicle the occupant rode out on.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        via: Option<CityId>,
    },
    ObservationExpired {
        dimension: Dimension,
    },
    PresenceChanged {
        shown: ShownPresence,
    },
    Shared {
        grantee: CityId,
    },
    Unshared {
        grantee: CityId,
    },
    Rejected {
        command: CommandType,
        reason: RejectReason,
    },
    /// A vehicle entered its line at a portal.
    VehicleEntered {
        vehicle: CityId,
    },
    /// A vehicle stopped because a walker holds the cells ahead.
    VehicleHeld {
        vehicle: CityId,
    },
    /// The occupant stood in a vehicle's way long enough to hold it (five
    /// ticks): the world stepped it from `from` to the nearest good place
    /// to stand off the track, `to`, so the vehicle can move on.
    SteppedAside {
        from: Point,
        to: Point,
    },
    DoorsOpened {
        vehicle: CityId,
        stop: PlaceId,
    },
    DoorsClosed {
        vehicle: CityId,
        stop: PlaceId,
    },
    /// A vehicle passed the far portal and left the line.
    VehicleLeft {
        vehicle: CityId,
    },
    Boarded {
        vehicle: CityId,
    },
    Alighted {
        vehicle: CityId,
        stop: PlaceId,
    },
    /// The occupant was waiting at `stop` when `vehicle` closed its doors
    /// full.
    LeftBehind {
        stop: PlaceId,
        vehicle: CityId,
    },
    /// A placement command was carried out: the grid changed with it, and
    /// the tick's projections carry the cells that changed.
    PlacementChanged {
        id: PlaceId,
        change: PlacementChange,
    },
    /// The occupant began using a capability at a placement's anchor. It
    /// carries `using` in its projection until it moves, leaves, sends
    /// `StopUsing`, or disconnects.
    Using {
        target: PlaceId,
        capability: String,
        anchor: u32,
    },
    /// The occupant stopped using `target`, as `SeatReleased` does for a
    /// seat.
    StoppedUsing {
        target: PlaceId,
    },
}

/// What a placement command did.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum PlacementChange {
    Placed,
    Moved,
    Removed,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum RejectReason {
    UnknownOccupant,
    UnknownRoom,
    AlreadyPresent,
    NotPresent,
    NotInRoom,
    NoDoor,
    NoTargetRoom,
    NotPersonalAgent,
    InvalidObservation,
    ProfileMismatch,
    /// No walking path leads there.
    Unreachable,
    /// The seat is held by someone else.
    SeatTaken,
    /// The seat is reserved for someone else.
    NotYourSeat,
    /// A steered step was refused: not adjacent, not walkable, through a
    /// wall, onto a person, or past the tick's five cells.
    BlockedStep,
    /// Not standing on a platform of a stop.
    NotOnPlatform,
    /// The vehicle carries as many public riders as it can. (`Board` no
    /// longer gives it: on a full tram the player waits for the next, and
    /// is left behind by the full one.)
    VehicleFull,
    /// The vehicle at the platform runs the other way: no stop, or not
    /// the stop asked for, lies ahead of it.
    NotYourDirection,
    /// The vehicle is not standing at a stop with its doors open, or no
    /// platform cell by its doors is free to step off onto.
    NotStanding,
    /// Not riding a vehicle.
    NotAboard,
    /// A steered step onto a seat's cell: seats are sat in by `Go`, never
    /// walked across.
    Seat,
    /// A steered step from outside into `room`, onto its door span or over
    /// an open-air edge, a room the occupant is not admitted to that is
    /// full or that others queue for. A steered
    /// entry tries only the room it walks into: it never waits and never
    /// overflows. `Go` queues for the room instead.
    RoomFull {
        room: PlaceId,
    },
    /// A placement command from a player: only operators and tools change
    /// the city.
    NotOperator,
    /// No placement has that ID.
    UnknownPlacement,
    /// The placement fails validation: an unknown kind, a level above the
    /// ground, a point off its snap, a footprint over a seat, door, track
    /// or anchor, an unreachable anchor, a room left too small, a platform
    /// left nowhere to stand, an ID already in use, or no layout to place
    /// it in. `code` is the validation issue's code (as `city validate`
    /// reports it), and `place` the place it concerns: the placement, or
    /// the room or platform it would leave too small.
    PlacementInvalid {
        code: String,
        place: PlaceId,
    },
    /// The placement would cover a cell someone stands on or a vehicle
    /// covers.
    PlacementCoversOccupant,
    /// The placement would cut the last walkable route between two rooms,
    /// or a room and an entrance, that had one, or cut off a seat or an
    /// anchor the entrances reached.
    PlacementDisconnects,
    /// No placement or seat has that ID.
    UnknownTarget,
    /// The target's kind offers no such capability, or (until Task 2) no
    /// capability is implemented yet.
    NoSuchCapability,
    /// The anchor is already held by someone else.
    AnchorTaken,
    /// The occupant is not standing where the anchor requires.
    NotAtAnchor,
}
