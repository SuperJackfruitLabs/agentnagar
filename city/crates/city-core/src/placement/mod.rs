//! Placements: instances of catalogue kinds standing in a district, and the
//! building shells facilities take from their kinds.
//!
//! Every authored placement is checked here in ID order, against the rooms'
//! floors and the placements accepted before it, by the one function
//! ([`validate_one`]) a runtime placement also goes through: authored and
//! runtime placements obey one set of rules. A runtime change ([`apply`])
//! then rebuilds only the grid's cells within the footprints it moved, and
//! is refused if it would cut a walk that was there.

mod apply;
mod reach;
mod validate;

pub use apply::{Allow, Change, Layout, apply, apply_saying_path};
pub use reach::Reach;
pub use validate::{Nearby, grid_issues, validate, validate_one};

use crate::footprint::{self, MARGIN, Placed};
use crate::index::{DoorInfo, PlaceIndex, RoomInfo};
use crate::nav::{CELL, Cell, NavGrid};
use city_contracts::{
    Anchor, AnchorType, Catalogue, Class, Kind, MANIFEST_SCHEMA_VERSION, Manifest, PlaceId,
    Placement, Point, Rect, RejectReason, Shape, StateType, ValidationIssue,
};
use std::collections::{BTreeMap, BTreeSet};

/// The message for any level but the ground.
pub const LEVEL_MESSAGE: &str = "levels above the ground arrive with rooftops";
/// A building's shell thickness when its kind gives none (cm).
pub const DEFAULT_WALL: i32 = 25;
/// A building's exterior opening when its kind gives none (cm).
pub const DEFAULT_DOOR_WIDTH: i32 = 200;
/// The opening between two rooms of one building (cm).
pub const INTERIOR_DOOR_WIDTH: i32 = 100;
/// How far from the grid's origin a placement may stand, on either axis
/// (cm): 10 km, well inside the range where cell arithmetic is safe.
pub const MAX_REACH: i64 = 1_000_000;

/// An accepted placement, with its footprint ready to test.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlacedInfo {
    pub id: PlaceId,
    pub kind: &'static Kind,
    pub placed: Placed,
    pub level: i32,
    pub district: PlaceId,
    /// The placement as it was accepted, so a move keeps its size, state
    /// and binding.
    pub record: Placement,
}

/// A facility with a building kind, whose shell stands round its rooms.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BuildingInfo {
    pub facility: PlaceId,
    pub kind: &'static Kind,
    /// The facility's rooms, in the manifest's order.
    pub rooms: Vec<PlaceId>,
    /// The shell's thickness (cm).
    pub wall: i32,
    /// The width of an exterior opening (cm).
    pub door_width: i32,
}

/// Which way the wall a door stands in runs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WallRun {
    EastWest,
    NorthSouth,
}

/// What a placement is checked against: the grid's geometry and door
/// spans, and the cells the trams run over. Neither depends on the
/// placements, so the floor and the carved grid serve alike.
pub struct Floor<'a> {
    pub grid: &'a NavGrid,
    pub tracks: &'a BTreeSet<Cell>,
}

fn anchor_points(p: &PlacedInfo) -> impl Iterator<Item = (Point, &Anchor)> {
    standing_anchors(p.kind).map(|a| {
        (
            footprint::world_point(p.placed.at, p.placed.facing, a.at),
            a,
        )
    })
}

fn issue(code: &str, place: impl ToString, message: String) -> ValidationIssue {
    ValidationIssue {
        code: code.to_string(),
        place: Some(place.to_string()),
        message,
    }
}

/// Whether `id` has the form placement IDs take, `placement:<slug>`: a
/// slug of lowercase letters, digits and hyphens, so later commands and
/// undo can name it in any tool.
fn is_placement_id(id: &PlaceId) -> bool {
    id.as_str().strip_prefix("placement:").is_some_and(|slug| {
        !slug.is_empty()
            && slug
                .bytes()
                .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
    })
}

/// The `bad-placement-id` issue for a placement whose ID is not
/// `placement:<slug>`.
fn placement_id_issue(id: &PlaceId) -> Option<ValidationIssue> {
    (!is_placement_id(id)).then(|| {
        issue(
            "bad-placement-id",
            id,
            format!(
                "Placement ID {id} is not placement:<slug>, a slug of lowercase letters, digits \
                 and hyphens."
            ),
        )
    })
}

fn anchor_name(kind: AnchorType) -> &'static str {
    match kind {
        AnchorType::Enter => "enter",
        AnchorType::Sit => "sit",
        AnchorType::Use => "use",
        AnchorType::Display => "display",
        AnchorType::Stand => "stand",
    }
}

/// The anchors someone must be able to stand on: every one but a display,
/// which is a surface.
fn standing_anchors(kind: &Kind) -> impl Iterator<Item = &Anchor> {
    kind.anchors
        .iter()
        .filter(|a| a.kind != AnchorType::Display)
}

/// The district a layout's placements stand in.
fn laid_out(index: &PlaceIndex) -> Option<&PlaceId> {
    index
        .rooms
        .values()
        .find(|r| r.rect.is_some())
        .map(|r| &r.district)
}

/// A door's opening width: its own, else for a door out of a building its
/// kind's exterior width (the wider, between two buildings), else for a
/// door within a building the interior width. `None` for a door between
/// rooms of no building kind, which keeps the grid's own default.
pub fn door_width(index: &PlaceIndex, from: &RoomInfo, door: &DoorInfo) -> Option<i32> {
    if door.width.is_some() {
        return door.width;
    }
    let to = index.rooms.get(&door.to)?;
    let exterior = |facility: &PlaceId| {
        index
            .buildings
            .iter()
            .find(|b| &b.facility == facility)
            .map(|b| b.door_width)
    };
    if from.facility == to.facility {
        exterior(&from.facility).map(|_| INTERIOR_DOOR_WIDTH)
    } else {
        exterior(&from.facility).max(exterior(&to.facility))
    }
}

/// Which way the edge a door stands on runs, from the two rooms' rects.
pub fn door_wall(index: &PlaceIndex, from: &RoomInfo, door: &DoorInfo) -> Option<WallRun> {
    let p = door.pos?;
    let a = from.rect?;
    let b = index.rooms.get(&door.to)?.rect?;
    if (a.z + a.d == b.z && p.z == b.z) || (b.z + b.d == a.z && p.z == a.z) {
        Some(WallRun::EastWest)
    } else if (a.x + a.w == b.x && p.x == b.x) || (b.x + b.w == a.x && p.x == a.x) {
        Some(WallRun::NorthSouth)
    } else {
        None
    }
}

/// `r` less `cut`: the up to four rects of `r` round it.
fn subtract(r: Rect, cut: &Rect) -> Vec<Rect> {
    let overlaps =
        r.x < cut.x + cut.w && cut.x < r.x + r.w && r.z < cut.z + cut.d && cut.z < r.z + r.d;
    if !overlaps {
        return vec![r];
    }
    let top = cut.z.max(r.z);
    let bottom = (cut.z + cut.d).min(r.z + r.d);
    let right = (cut.x + cut.w).min(r.x + r.w);
    [
        Rect {
            x: r.x,
            z: r.z,
            w: r.w,
            d: cut.z - r.z,
        },
        Rect {
            x: r.x,
            z: cut.z + cut.d,
            w: r.w,
            d: r.z + r.d - (cut.z + cut.d),
        },
        Rect {
            x: r.x,
            z: top,
            w: cut.x - r.x,
            d: bottom - top,
        },
        Rect {
            x: right,
            z: top,
            w: r.x + r.w - right,
            d: bottom - top,
        },
    ]
    .into_iter()
    .filter(|q| q.w > 0 && q.d > 0)
    .collect()
}

fn subtract_all(pieces: Vec<Rect>, cuts: &[Rect]) -> Vec<Rect> {
    cuts.iter().fold(pieces, |pieces, cut| {
        pieces.into_iter().flat_map(|p| subtract(p, cut)).collect()
    })
}

/// A wall `wall` thick centred on the edge two rooms share, if they share
/// one of any length.
fn partition(a: &Rect, b: &Rect, wall: i32) -> Option<Rect> {
    let across = |lo: i32, hi: i32| (hi > lo).then_some((lo, hi));
    if a.z + a.d == b.z || b.z + b.d == a.z {
        let edge = if a.z + a.d == b.z { b.z } else { a.z };
        let (lo, hi) = across(a.x.max(b.x), (a.x + a.w).min(b.x + b.w))?;
        return Some(Rect {
            x: lo,
            z: edge - wall / 2,
            w: hi - lo,
            d: wall,
        });
    }
    if a.x + a.w == b.x || b.x + b.w == a.x {
        let edge = if a.x + a.w == b.x { b.x } else { a.x };
        let (lo, hi) = across(a.z.max(b.z), (a.z + a.d).min(b.z + b.d))?;
        return Some(Rect {
            x: edge - wall / 2,
            z: lo,
            w: wall,
            d: hi - lo,
        });
    }
    None
}

/// A building's shell, as world rects: the union of its rooms grown outward
/// by `wall`, less the rooms themselves, plus a partition centred on each
/// edge two of its rooms share, less an opening at every door into or out
/// of its rooms.
pub fn shell(index: &PlaceIndex, building: &BuildingInfo) -> Placed {
    let wall = building.wall;
    let rects: Vec<Rect> = building
        .rooms
        .iter()
        .filter_map(|id| index.rooms.get(id).and_then(|r| r.rect))
        .collect();
    let mut openings = Vec::new();
    for room in index.rooms.values() {
        for door in &room.door_list {
            let touches = building.rooms.contains(&room.id) || building.rooms.contains(&door.to);
            let (Some(p), true) = (door.pos, touches) else {
                continue;
            };
            let width = door_width(index, room, door).unwrap_or(INTERIOR_DOOR_WIDTH);
            match door_wall(index, room, door) {
                Some(WallRun::EastWest) => openings.push(Rect {
                    x: p.x - width / 2,
                    z: p.z - wall,
                    w: width,
                    d: 2 * wall,
                }),
                Some(WallRun::NorthSouth) => openings.push(Rect {
                    x: p.x - wall,
                    z: p.z - width / 2,
                    w: 2 * wall,
                    d: width,
                }),
                None => {}
            }
        }
    }
    let mut pieces = Vec::new();
    for r in &rects {
        let sides = vec![
            Rect {
                x: r.x - wall,
                z: r.z - wall,
                w: r.w + 2 * wall,
                d: wall,
            },
            Rect {
                x: r.x - wall,
                z: r.z + r.d,
                w: r.w + 2 * wall,
                d: wall,
            },
            Rect {
                x: r.x - wall,
                z: r.z,
                w: wall,
                d: r.d,
            },
            Rect {
                x: r.x + r.w,
                z: r.z,
                w: wall,
                d: r.d,
            },
        ];
        pieces.extend(subtract_all(sides, &rects));
    }
    for (i, a) in rects.iter().enumerate() {
        pieces.extend(rects[i + 1..].iter().filter_map(|b| partition(a, b, wall)));
    }
    Placed {
        shapes: subtract_all(pieces, &openings)
            .into_iter()
            .map(|r| Shape::Rect {
                x: r.x,
                z: r.z,
                w: r.w,
                d: r.d,
            })
            .collect(),
        at: Point { x: 0, z: 0 },
        facing: 0,
    }
}
