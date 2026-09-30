//! A viewer's view of the world. The only world data a client receives.

use crate::{CityId, Direction, OccupantKind, PlaceId, Point, ShownPresence, Tick};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "type")]
pub enum Viewer {
    /// An anonymous observer.
    Public,
    /// A registered person; sees their own personal agents and those shared
    /// with them.
    Person { id: CityId },
    /// Diagnostics only, behind an explicit flag; never player-facing.
    Operator,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Projection {
    pub schema_version: u32,
    pub tick: Tick,
    pub fixture: bool,
    pub viewer: Viewer,
    pub rooms: Vec<RoomView>,
    pub in_transit: Vec<OccupantView>,
    /// Minutes after midnight, when the manifest has a clock.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub time_of_day: Option<u32>,
    /// How hard it is raining, 0 to 100 percent, when the manifest has a
    /// clock and weather.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rain: Option<u8>,
    /// Every vehicle on the lines, in vehicle order: by line, then direction
    /// (east first), then the number ending the ID, compared as a number.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub vehicles: Vec<VehicleView>,
    /// The riders this viewer may see, aboard the vehicles.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub aboard: Vec<OccupantView>,
    /// The walkable grid's cells that placement commands changed this tick,
    /// in row then column order: clients apply them to the grid they
    /// loaded. Present only on the tick of a change.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub grid_changes: Vec<GridChange>,
}

/// One cell of the walkable grid that changed: column `i` (east) and row
/// `j` (south), counted from the grid's origin, and whether it is now
/// walkable.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct GridChange {
    pub i: i32,
    pub j: i32,
    pub walkable: bool,
    /// For a cell now walkable, the room whose floor it is, as an index
    /// into the grid's rooms (in ID order), so a client's copy of the grid
    /// can take it back without the room rectangles. None for a cell that
    /// closed.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub room: Option<u16>,
}

/// A vehicle as a viewer sees it. Carries no rider count: a count would
/// reveal riders this viewer may not see.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct VehicleView {
    pub id: CityId,
    pub line: PlaceId,
    pub direction: Direction,
    /// The centre of the vehicle's front, on its track (cm), carried
    /// straight on past a portal. Standing at a stop, a vehicle is centred
    /// on the stop's `at`, so its front is half its length past it.
    pub pos: Point,
    /// Degrees clockwise from north.
    pub heading: i32,
    /// How far along the centreline its front is (cm).
    pub along: i32,
    /// The `along` values crossed last tick, ending at `along`: where its
    /// front was at the start of the tick, then `along`. Empty when it
    /// stood still or has only just entered.
    pub trail: Vec<i32>,
    /// One of `running`, `standing` or `held`.
    pub status: String,
    pub doors_open: bool,
    /// The stop it stands at.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stop: Option<PlaceId>,
}

/// A place in the queue outside a room's door.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct QueueSpot {
    pub room: PlaceId,
    /// 1-based.
    pub position: u32,
}

/// Carries no occupancy count: a count would reveal occupants this viewer
/// may not see.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct RoomView {
    pub id: PlaceId,
    pub name: String,
    pub facility: PlaceId,
    pub capacity: u32,
    pub seats: Vec<SeatView>,
    pub occupants: Vec<OccupantView>,
    pub waiting: Vec<OccupantView>,
}

/// Carries no holder: seat use is shown through visible occupants only.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct SeatView {
    pub id: PlaceId,
    pub pod: Option<PlaceId>,
    pub department: Option<String>,
    pub reserved: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct OccupantView {
    pub id: CityId,
    pub kind: OccupantKind,
    pub display_name: String,
    pub role: String,
    pub badge: Option<Badge>,
    pub appearance: BTreeMap<String, String>,
    pub seat: Option<PlaceId>,
    pub presence: ShownPresence,
    /// Absent when there is none and when it is withheld; the two are
    /// indistinguishable by design.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub task_summary: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub pos: Option<Point>,
    #[serde(default, skip_serializing_if = "crate::is_zero")]
    pub facing: i32,
    #[serde(default, skip_serializing_if = "crate::is_false")]
    pub moving: bool,
    /// Where the walker plans to go next tick. A plan, not a promise:
    /// walkers can be held up.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub path_ahead: Vec<Point>,
    /// The cells actually crossed last tick, ending at `pos`. Clients replay
    /// this to animate movement truthfully, one tick behind.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub trail: Vec<Point>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub queue: Option<QueueSpot>,
    /// The vehicle this rider is aboard.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub vehicle: Option<CityId>,
    /// The rider's place in the vehicle: absent for a rider who takes no
    /// place (a hidden one), who is drawn at the vehicle's centre.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub slot: Option<u32>,
    /// Set for an occupant standing on a platform waiting for a vehicle.
    /// Such an occupant is listed among its platform room's occupants.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub waiting_for: Option<PlatformWait>,
    /// What the occupant is using, while it lasts: everyone sees this, as
    /// "sitting", "reading" or "at a workstation".
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub using: Option<Using>,
}

/// What an occupant is doing at a placement's anchor. Mirrors `Command::Use`,
/// minus the occupant it belongs to.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Using {
    pub target: PlaceId,
    pub capability: String,
    pub anchor: u32,
}

/// What a platform waiter is waiting for.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct PlatformWait {
    pub stop: PlaceId,
    /// The direction of the vehicle it waits for; absent when it takes the
    /// next either way.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub direction: Option<Direction>,
}

/// One vehicle and the riders aboard it that a viewer may see, in slot
/// order, as `inspect --vehicle` gives it. Carries no rider count.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct VehicleDetail {
    pub vehicle: VehicleView,
    pub riders: Vec<OccupantView>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub enum Badge {
    Ai,
    Simulation,
}
