//! The place manifest: the tree of places a world is built from.

use crate::{CityId, OccupantProfile, PlaceId, Size, Tick};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Manifest {
    /// [`crate::MANIFEST_SCHEMA_VERSION`]; validation refuses any other.
    pub schema_version: u32,
    pub city: City,
    #[serde(default)]
    pub seat_policy: SeatPolicyName,
    /// Occupants known before any feed runs, such as the Guild agents.
    /// Others register themselves when they first arrive.
    #[serde(default)]
    pub occupants: Vec<OccupantProfile>,
    /// Simulation time of day; presentation only, no rule reads it.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub clock: Option<Clock>,
    /// Daily weather on the clock; presentation only, no rule reads it.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub weather: Option<Weather>,
    /// Presentation-only surroundings: water, bridges, streets and fences.
    /// No rule reads them; validation keeps water off walkable floors but
    /// where a bridge crosses it, and the rest off indoor ones.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub scenery: Vec<Scenery>,
    /// The transit lines the core runs. Their tracks are drawn from here.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub lines: Vec<Line>,
    /// The catalogue version the manifest was written against. Validation
    /// refuses a manifest that names none, or a version the core does not
    /// carry.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub catalogue: Option<u32>,
}

/// A transit line the core runs: vehicles travel its tracks between two
/// portals, stop at its stops and carry riders.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Line {
    /// Such as `line:boulevard`.
    pub id: PlaceId,
    pub name: String,
    pub mode: LineMode,
    /// The centreline, west to east (cm). Its ends are the portals, where
    /// vehicles enter from and leave to the rest of the city.
    pub points: Vec<Point>,
    /// The two tracks' offsets from the centreline (cm, positive to the
    /// south): eastbound first, then westbound.
    pub tracks: [i32; 2],
    pub stops: Vec<Stop>,
    pub timetable: Timetable,
    pub vehicle: VehicleSpec,
}

/// What runs on a line. Only trams run today; buses and ferries are
/// reserved.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "lowercase")]
pub enum LineMode {
    Tram,
    Bus,
    Ferry,
}

/// A place on a line where vehicles stand and riders board and alight.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Stop {
    /// Such as `stop:square`.
    pub id: PlaceId,
    pub name: String,
    /// Where vehicles stand, as a distance along the centreline (cm).
    pub at: i32,
    /// The platform rooms: the eastbound side first, then the westbound.
    pub platforms: [PlaceId; 2],
}

/// When vehicles enter a line and how they run along it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Timetable {
    /// A vehicle enters each direction every `headway` ticks, starting at
    /// `offset[direction]`.
    pub headway: u32,
    /// The first entry tick of each direction: eastbound, then westbound.
    pub offset: [u32; 2],
    /// Cells a vehicle advances each tick.
    pub speed: u32,
    /// Ticks a vehicle stands with its doors open at a stop.
    pub dwell: u32,
}

/// The vehicles a line runs.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct VehicleSpec {
    /// The most public riders a vehicle carries.
    pub capacity: u32,
    /// The vehicle's length (cm).
    pub length: i32,
    /// Door positions along the vehicle (cm from its front), on the
    /// platform side.
    pub doors: Vec<i32>,
    /// The catalogue's `vehicle`-class kind the line runs, which gives the
    /// vehicle's width. Absent, it is `tram`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub kind: Option<String>,
}

/// How arrivals reach the city and departures leave it.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "lowercase")]
pub enum Arrivals {
    /// Arrivals appear at an entrance and departures walk out of one.
    #[default]
    Direct,
    /// Arrivals ride in on a line's vehicles and departures ride out.
    Tram,
}

impl Arrivals {
    /// Whether this is the default, `direct`.
    pub fn is_direct(&self) -> bool {
        *self == Self::Direct
    }
}

/// Something drawn around the walkable city.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "kind", rename_all = "kebab-case")]
pub enum Scenery {
    Water {
        rect: Rect,
    },
    Bridge {
        from: Point,
        to: Point,
        width: i32,
    },
    Street {
        points: Vec<Point>,
        width: i32,
    },
    /// A railing or fence where walkable ground ends: the city's edge, a
    /// quay, the far end of a bridge.
    Fence {
        points: Vec<Point>,
    },
}

/// The shape of a building's roof, for packs that draw whole buildings.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "kebab-case")]
pub enum Roof {
    Sawtooth,
    Dome,
    Vault,
    Pitched,
    Flat,
}

impl Manifest {
    /// Whether this manifest carries a layout (any room has a floor rect).
    pub fn has_layout(&self) -> bool {
        self.city
            .districts
            .iter()
            .flat_map(|d| &d.facilities)
            .flat_map(|f| &f.rooms)
            .any(|r| r.rect.is_some())
    }
}

/// A point on the ground plane in integer centimetres: x east, z south.
#[derive(
    Debug,
    Clone,
    Copy,
    Default,
    PartialEq,
    Eq,
    PartialOrd,
    Ord,
    Hash,
    Serialize,
    Deserialize,
    JsonSchema,
)]
pub struct Point {
    pub x: i32,
    pub z: i32,
}

/// An axis-aligned rectangle in centimetres: its minimum corner and size.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
pub struct Rect {
    pub x: i32,
    pub z: i32,
    pub w: i32,
    pub d: i32,
}

impl Rect {
    /// Whether `p` lies inside, counting the minimum edges and not the maximum.
    pub fn contains(&self, p: Point) -> bool {
        self.x <= p.x && p.x < self.x + self.w && self.z <= p.z && p.z < self.z + self.d
    }
}

/// How ticks map to a time of day.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Clock {
    pub ticks_per_day: u32,
    /// Minutes after midnight at tick 0.
    pub start_minute: u32,
}

/// The city's daily weather: spells of rain by the clock.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Weather {
    #[serde(default)]
    pub rain: Vec<RainSpell>,
}

/// Rain from `from` to `to` (minutes after midnight, crossing midnight when
/// `to` is earlier), rising to `peak` percent over its first twenty minutes
/// and easing off over its last twenty.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct RainSpell {
    pub from: u32,
    pub to: u32,
    pub peak: u8,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
pub struct City {
    pub id: PlaceId,
    pub name: String,
    pub districts: Vec<District>,
    /// Where arrivals appear and departures leave, when there is a layout.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub entrances: Vec<Point>,
    /// How arrivals reach the city: directly at an entrance, or by tram.
    #[serde(default, skip_serializing_if = "Arrivals::is_direct")]
    pub arrivals: Arrivals,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
pub struct District {
    pub id: PlaceId,
    pub name: String,
    pub facilities: Vec<Facility>,
    /// The catalogue kinds placed in this district, in district coordinates.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub placements: Vec<Placement>,
}

/// An instance of a catalogue kind: a thing standing at a point with a
/// facing.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
pub struct Placement {
    /// Such as `placement:great-tree`. Stable, so later commands can name it.
    pub id: PlaceId,
    /// The catalogue kind, such as `bench` or `street-lamp`.
    pub kind: String,
    /// The placement point (cm), which must lie on the kind's snap.
    pub at: Point,
    /// Whole degrees clockwise from north.
    #[serde(default, skip_serializing_if = "crate::is_zero")]
    pub facing: i32,
    /// The storey index. Only the ground, 0, is accepted until rooftops.
    #[serde(default, skip_serializing_if = "crate::is_zero")]
    pub level: i32,
    /// A sized kind's own footprint: one rect of this size centred on `at`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub size: Option<Size>,
    /// Values for the kind's declared state fields; the rest take the kind's
    /// defaults.
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub state: BTreeMap<String, serde_json::Value>,
    /// The outside record a display shows. Nothing reads it yet.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub binding: Option<Binding>,
}

/// An outside record a display placement shows, such as a published
/// Superpipeline board.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Binding {
    pub source: String,
    #[serde(rename = "ref")]
    pub reference: String,
}

/// Unknown fields are refused, so a field schema 1 had (`exterior`) is
/// never silently dropped.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct Facility {
    pub id: PlaceId,
    pub name: String,
    pub rooms: Vec<Room>,
    /// A `building`-class catalogue kind. Its shell stands outside the
    /// rooms' floors and blocks walking, except at the doors.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub kind: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub roof: Option<Roof>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub storeys: Option<u8>,
    /// What the place is on the map: its colour, icon and legend entry.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub category: Option<Category>,
}

/// What a place is on the map: its colour, icon and legend entry.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "lowercase")]
pub enum Category {
    Workshop,
    Library,
    Transit,
    Park,
}

/// Unknown fields are refused, so a field schema 1 had (`obstacles`,
/// `props`) is never silently dropped.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
#[serde(deny_unknown_fields)]
pub struct Room {
    pub id: PlaceId,
    pub name: String,
    /// The most occupants the room may hold, seated or standing.
    pub capacity: u32,
    #[serde(default)]
    pub pods: Vec<Pod>,
    #[serde(default)]
    pub seats: Vec<Seat>,
    /// Where arrivals go when this room is full.
    #[serde(default)]
    pub overflow: Option<PlaceId>,
    #[serde(default)]
    pub doors: Vec<Door>,
    /// Furniture set, such as `workshop` or `plaza`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub template: Option<String>,
    /// Floor area, when the manifest has a layout.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rect: Option<Rect>,
    /// An open-air room: a square, park or terrace. Entrances sit on outdoor
    /// edges and queues form on the outdoor side of a door.
    #[serde(default, skip_serializing_if = "crate::is_false")]
    pub outdoor: bool,
    /// The storey index. Only the ground, 0, is accepted until rooftops.
    #[serde(default, skip_serializing_if = "crate::is_zero")]
    pub level: i32,
}

impl Room {
    /// Outdoor by flag, or by the older `plaza` and `outdoor` templates.
    pub fn is_outdoor(&self) -> bool {
        self.outdoor || matches!(self.template.as_deref(), Some("plaza" | "outdoor"))
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
pub struct Pod {
    pub id: PlaceId,
    /// A department tag such as `making`. Departments are data, not code.
    #[serde(default)]
    pub department: Option<String>,
}

/// A seat is hot when `reserved_for` is absent, and reserved for exactly that
/// occupant otherwise.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
pub struct Seat {
    pub id: PlaceId,
    #[serde(default)]
    pub pod: Option<PlaceId>,
    #[serde(default)]
    pub reserved_for: Option<CityId>,
    /// Where the occupant sits.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub pos: Option<Point>,
    /// Degrees clockwise from north.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub facing: Option<i32>,
    /// Furniture, such as `desk`, `bench`, `cafe-table` or `reading-chair`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub kind: Option<String>,
    /// Which of its furniture's `sit` anchors this seat is, for furniture
    /// with several, such as a long bench.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub anchor: Option<u32>,
}

/// A one-way link from the room that lists it to the room `to`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
pub struct Door {
    pub id: PlaceId,
    pub to: PlaceId,
    pub transit: TickRange,
    /// Where a walk crosses between the two rooms.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub pos: Option<Point>,
    /// The opening's width (cm). Absent, it is the building kind's
    /// `door_width` for an exterior door and 100 otherwise.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub width: Option<i32>,
}

/// An inclusive range of ticks.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema, Default)]
pub struct TickRange {
    pub min: Tick,
    pub max: Tick,
}

/// The named rule that assigns hot seats.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "kebab-case")]
pub enum SeatPolicyName {
    /// Prefer the occupant's department pod, then the pod with most free
    /// seats, then the lowest seat ID.
    #[default]
    DepartmentFirst,
}
