//! The presence feed and the commands it carries.

use crate::{CityId, Observation, OccupantProfile, PlaceId, Placement, Point, Tick};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

/// The first record of every feed. A fixture feed says so here, and every
/// entry repeats the flag, so fixture and real state can never mix.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct FeedHeader {
    pub schema_version: u32,
    pub source: String,
    pub fixture: bool,
    #[serde(default)]
    pub description: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct FeedEntry {
    pub at: Tick,
    pub fixture: bool,
    pub command: Command,
}

/// One line of a JSON Lines feed.
// A record lives only while one line is parsed, so the variant size gap costs nothing.
#[allow(clippy::large_enum_variant)]
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "record", rename_all = "lowercase")]
pub enum FeedRecord {
    Header(FeedHeader),
    Entry(FeedEntry),
}

/// A request to the world.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "type")]
pub enum Command {
    /// Begin a presence. `profile` registers a newcomer; `room` defaults to
    /// the occupant's work place.
    Arrive {
        occupant: CityId,
        #[serde(default)]
        profile: Option<OccupantProfile>,
        #[serde(default)]
        room: Option<PlaceId>,
        /// A player joining from a client. With arrivals by tram it rides
        /// in on whichever vehicle brings it soonest (for a platform, the
        /// first to stand at its stop), rather than taking its turn at the
        /// portals, and steps off at the stop of its room when that room is
        /// a platform.
        #[serde(default, skip_serializing_if = "crate::is_false")]
        player: bool,
    },
    /// End a presence. With a layout the occupant walks out, or, with
    /// arrivals by tram, walks to a platform and rides out.
    Depart {
        occupant: CityId,
        /// A player leaving from a client (its session's `leave`, as Quit
        /// to title does). It leaves at once from wherever it is, on the
        /// ground, waiting or aboard: players never ride out, and the next
        /// visit must not wait for this one to walk away. The one exception
        /// to departures walking or riding out.
        #[serde(default, skip_serializing_if = "crate::is_false")]
        player: bool,
    },
    /// Walk through a door from the current room to `to`.
    Move {
        occupant: CityId,
        to: PlaceId,
    },
    Observe {
        occupant: CityId,
        observation: Observation,
    },
    Share {
        occupant: CityId,
        grantee: CityId,
    },
    Unshare {
        occupant: CityId,
        grantee: CityId,
    },
    /// Walk to a target. The core plans the path; a target in another room
    /// goes through that room's admission first.
    Go {
        occupant: CityId,
        to: Target,
    },
    /// Predicted walking: the cells the client walked this tick, each one
    /// step from the last, at most five. The core accepts them in order and
    /// stops at the first it refuses.
    Steer {
        occupant: CityId,
        cells: Vec<Point>,
    },
    /// Board the vehicle standing at this platform with its doors open, or,
    /// with none there yet, wait for the next one.
    Board {
        occupant: CityId,
    },
    /// Step off the vehicle while it stands at a stop with its doors open.
    Alight {
        occupant: CityId,
    },
    /// Add a placement to the laid-out district. Operators and tools send
    /// it; see `by`.
    Place {
        placement: Placement,
        /// The player who asked, when one did. Players may not change the
        /// city, so the world refuses it (`NotOperator`); operators and
        /// tools leave it out.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        by: Option<CityId>,
    },
    /// Move a placement to a new point and facing, keeping everything else.
    MovePlacement {
        id: PlaceId,
        at: Point,
        #[serde(default, skip_serializing_if = "crate::is_zero")]
        facing: i32,
        /// As for `Place`.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        by: Option<CityId>,
    },
    /// Take a placement away.
    RemovePlacement {
        id: PlaceId,
        /// As for `Place`.
        #[serde(default, skip_serializing_if = "Option::is_none")]
        by: Option<CityId>,
    },
    /// Use a capability at one of a placement's anchors. `target` is a
    /// placement ID or a seat ID (a seat is its furniture's own instance),
    /// and `anchor` is the index of the anchor within that placement's kind.
    Use {
        occupant: CityId,
        target: PlaceId,
        capability: String,
        anchor: u32,
    },
    /// Stop using whatever the occupant is using, as leaving a seat does
    /// today.
    StopUsing {
        occupant: CityId,
    },
}

/// Where a `Go` command leads.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "type")]
pub enum Target {
    /// Stand at this point; one that is not a fine place to stand moves to
    /// the nearest cell that is.
    Point { pos: Point },
    /// Sit in this seat: a free hot seat, or the occupant's own reserved one.
    Seat { seat: PlaceId },
    /// Enter this room, from anywhere.
    Room { room: PlaceId },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum CommandType {
    Arrive,
    Depart,
    Move,
    Observe,
    Share,
    Unshare,
    Go,
    Steer,
    Board,
    Alight,
    Place,
    MovePlacement,
    RemovePlacement,
    Use,
    StopUsing,
}

impl Command {
    pub fn command_type(&self) -> CommandType {
        match self {
            Self::Arrive { .. } => CommandType::Arrive,
            Self::Depart { .. } => CommandType::Depart,
            Self::Move { .. } => CommandType::Move,
            Self::Observe { .. } => CommandType::Observe,
            Self::Share { .. } => CommandType::Share,
            Self::Unshare { .. } => CommandType::Unshare,
            Self::Go { .. } => CommandType::Go,
            Self::Steer { .. } => CommandType::Steer,
            Self::Board { .. } => CommandType::Board,
            Self::Alight { .. } => CommandType::Alight,
            Self::Place { .. } => CommandType::Place,
            Self::MovePlacement { .. } => CommandType::MovePlacement,
            Self::RemovePlacement { .. } => CommandType::RemovePlacement,
            Self::Use { .. } => CommandType::Use,
            Self::StopUsing { .. } => CommandType::StopUsing,
        }
    }

    /// The occupant a command is for or from: none for a placement command
    /// an operator or tool sent.
    pub fn occupant(&self) -> Option<&CityId> {
        match self {
            Self::Arrive { occupant, .. }
            | Self::Depart { occupant, .. }
            | Self::Move { occupant, .. }
            | Self::Observe { occupant, .. }
            | Self::Share { occupant, .. }
            | Self::Unshare { occupant, .. }
            | Self::Go { occupant, .. }
            | Self::Steer { occupant, .. }
            | Self::Board { occupant }
            | Self::Alight { occupant }
            | Self::Use { occupant, .. }
            | Self::StopUsing { occupant } => Some(occupant),
            Self::Place { by, .. }
            | Self::MovePlacement { by, .. }
            | Self::RemovePlacement { by, .. } => by.as_ref(),
        }
    }
}
