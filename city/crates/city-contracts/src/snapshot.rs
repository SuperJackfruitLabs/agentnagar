//! A snapshot of full world state. Operator-level: never player-facing.

use crate::{
    CityId, GridChange, Manifest, OccupantProfile, PlaceId, Point, PresenceRecord, ShownPresence,
    Target, Tick,
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Snapshot {
    pub schema_version: u32,
    /// The last completed tick; 0 before the first.
    pub tick: Tick,
    pub seed: u64,
    pub fixture: bool,
    pub manifest: Manifest,
    pub occupants: BTreeMap<CityId, OccupantState>,
    pub rooms: BTreeMap<PlaceId, RoomState>,
    /// Occupants waiting for the next Admit phase, in order.
    pub admission_queue: Vec<CityId>,
    pub next_seq: u64,
    /// The vehicles on the lines, in vehicle order: by line, then direction
    /// (east first), then the number ending the ID, compared as a number.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub vehicles: Vec<VehicleState>,
    /// The walkable cells placement commands changed during the last tick,
    /// in row then column order. `manifest` carries the placements as they
    /// now stand.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub grid_changes: Vec<GridChange>,
}

/// A vehicle on a line, from the tick it enters at one portal until it
/// passes the other.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct VehicleState {
    /// Such as `vehicle:boulevard:east:1`.
    pub id: CityId,
    pub line: PlaceId,
    pub direction: Direction,
    /// How far along the centreline its front is (cm).
    pub along: i32,
    pub status: VehicleStatus,
    /// The riders aboard, in boarding order.
    pub riders: Vec<CityId>,
    /// Where its front was at the start of the last tick and where it is
    /// now, when it moved during that tick; empty when it stood still or
    /// has only just entered.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub trail: Vec<i32>,
}

/// Which way a vehicle runs along its line.
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize, JsonSchema,
)]
#[serde(rename_all = "lowercase")]
pub enum Direction {
    /// West to east, on the first track.
    East,
    /// East to west, on the second track.
    West,
}

impl Direction {
    /// The index of this direction's track, platform and offset: 0 for east,
    /// 1 for west.
    pub fn index(self) -> usize {
        match self {
            Self::East => 0,
            Self::West => 1,
        }
    }
}

/// What a vehicle is doing this tick.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "type")]
pub enum VehicleStatus {
    /// Moving along its track.
    Running,
    /// At `stop` with its doors open until `doors_open_until`.
    Standing {
        stop: PlaceId,
        doors_open_until: Tick,
    },
    /// Stopped because a walker holds the cells ahead.
    Held,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct OccupantState {
    pub profile: OccupantProfile,
    pub location: Location,
    pub presence: PresenceRecord,
    pub shown: ShownPresence,
    /// Position on the ground plane, when the world has a layout.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub pos: Option<Point>,
    /// Degrees clockwise from north.
    #[serde(default, skip_serializing_if = "crate::is_zero")]
    pub facing: i32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub walk: Option<Walk>,
    /// The cells actually crossed during the last tick, in order.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub trail: Vec<Point>,
    /// The occupant's own target from `Go` or `Steer`: pending while it
    /// walks to a door or waits to be admitted, and, for a point, kept once
    /// it is there, so no policy seat or standing spot overrides the choice.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub goal: Option<Target>,
    /// What the occupant began using with `Command::Use`, until it moves,
    /// leaves, boards, sends `StopUsing` or disconnects. A seat taken any
    /// other way is not recorded here; projections show it from the seat.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub using: Option<crate::Using>,
}

/// A walk in progress: the cells still to cross, as centre points.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Walk {
    pub path: Vec<Point>,
    pub purpose: WalkPurpose,
    /// Consecutive ticks the walker could not move.
    #[serde(default)]
    pub blocked: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "type")]
pub enum WalkPurpose {
    /// To the threshold of `target`, to be admitted there.
    ToDoor {
        target: PlaceId,
    },
    ToSeat,
    ToSpot,
    ToQueue,
    ToExit,
    /// To a platform of `stop`, to wait there for a vehicle.
    ToPlatform {
        stop: PlaceId,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "state")]
pub enum Location {
    Away,
    Arriving {
        room: PlaceId,
    },
    InRoom {
        room: PlaceId,
        seat: Option<PlaceId>,
    },
    Waitlisted {
        room: PlaceId,
    },
    InTransit {
        from: PlaceId,
        to: PlaceId,
        door: PlaceId,
        arrives_at: Tick,
    },
    /// Walking to an exit after leaving `from`.
    Leaving {
        #[serde(default)]
        from: Option<PlaceId>,
    },
    /// Queued on a platform of `stop` for a vehicle running in `direction`,
    /// or for the next one either way when it is absent.
    WaitingFor {
        stop: PlaceId,
        #[serde(default)]
        direction: Option<Direction>,
    },
    /// Riding `vehicle` in `slot`.
    Aboard {
        vehicle: CityId,
        slot: u32,
    },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct RoomState {
    /// In admission order.
    pub occupants: Vec<CityId>,
    /// Every seat of the room and its holder.
    pub seats: BTreeMap<PlaceId, Option<CityId>>,
    /// First in, first out.
    pub waitlist: Vec<CityId>,
}
