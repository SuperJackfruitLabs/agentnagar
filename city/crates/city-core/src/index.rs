//! Structural validation of a place manifest into a lookup index.

pub use crate::placement::{BuildingInfo, PlacedInfo};
use crate::walk::heading_of;
use city_contracts::{
    Catalogue, CityId, Clock, Direction, Line, LineMode, MANIFEST_SCHEMA_VERSION, Manifest,
    OccupantProfile, PlaceId, Point, Rect, Scenery, SeatPolicyName, Tick, TickRange, Timetable,
    ValidationIssue, ValidationReport, VehicleSpec,
};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SeatInfo {
    pub id: PlaceId,
    pub pod: Option<PlaceId>,
    pub department: Option<String>,
    pub reserved_for: Option<CityId>,
    pub pos: Option<Point>,
    pub facing: i32,
    pub kind: Option<String>,
    /// Which of its furniture's `sit` anchors this seat is.
    pub anchor: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DoorInfo {
    pub id: PlaceId,
    pub to: PlaceId,
    pub transit: TickRange,
    pub pos: Option<Point>,
    /// The opening's width (cm), when the manifest gives one.
    pub width: Option<i32>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RoomInfo {
    pub id: PlaceId,
    pub name: String,
    pub facility: PlaceId,
    pub district: PlaceId,
    /// The storey index; only the ground, 0, is accepted until rooftops.
    pub level: i32,
    pub capacity: u32,
    /// Sorted by seat ID.
    pub seats: Vec<SeatInfo>,
    /// Occupant to the seat reserved for them in this room.
    pub reserved: BTreeMap<CityId, PlaceId>,
    /// Keyed by destination room.
    pub doors: BTreeMap<PlaceId, DoorInfo>,
    /// Every door of the room, several to one room included, by ID.
    pub door_list: Vec<DoorInfo>,
    /// This room first, then its overflow, then that room's overflow, and so on.
    pub chain: Vec<PlaceId>,
    pub template: Option<String>,
    pub rect: Option<Rect>,
    /// An open-air room (see `Room::is_outdoor`).
    pub outdoor: bool,
}

/// The longest door transit a manifest may declare, in ticks.
pub const MAX_TRANSIT: Tick = 1_000_000;

/// A validated manifest, indexed for the rules.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlaceIndex {
    pub rooms: BTreeMap<PlaceId, RoomInfo>,
    pub occupants: BTreeMap<CityId, OccupantProfile>,
    pub seat_policy: SeatPolicyName,
    /// Whether the manifest carries a layout, so occupants walk.
    pub layout: bool,
    pub entrances: Vec<Point>,
    pub clock: Option<Clock>,
    /// Every validated transit line, with its track geometry precomputed.
    pub lines: BTreeMap<PlaceId, LineInfo>,
    /// Every accepted placement, in ID order.
    pub placements: Vec<PlacedInfo>,
    /// The furniture of every seat whose kind is a seat kind, in seat ID
    /// order, when the manifest declares its catalogue.
    pub seat_furniture: Vec<PlacedInfo>,
    /// Every facility with a building kind, in facility ID order.
    pub buildings: Vec<BuildingInfo>,
    /// Where the placements and seat furniture stand, for checking a new
    /// placement against its neighbours. [`PlaceIndex::add_placement`] and
    /// [`PlaceIndex::remove_placement`] keep it.
    pub nearby: crate::placement::Nearby,
}

/// One track's polyline (the centreline offset by `tracks[d]`) and its
/// cumulative length at each vertex, ready for Task 3's vehicle movement.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrackGeometry {
    /// Vertices west to east, offset from the line's centreline.
    pub points: Vec<Point>,
    /// Cumulative length (cm) at each vertex: `lengths[0] == 0`, and
    /// `lengths.last()` is the track's total length.
    pub lengths: Vec<i64>,
}

impl TrackGeometry {
    /// The point `along` cm from the west end, clamped to the track's
    /// extent and linearly interpolated between the two vertices that
    /// bracket it. See `offset_polyline` for the rounding rule that shaped
    /// this track's vertices.
    pub fn point_at(&self, along: i64) -> Point {
        let total = *self.lengths.last().expect("a track has at least one point");
        let along = along.clamp(0, total);
        if self.points.len() == 1 {
            return self.points[0];
        }
        let mut i = 0;
        while i + 1 < self.lengths.len() && self.lengths[i + 1] < along {
            i += 1;
        }
        let seg_len = self.lengths[i + 1] - self.lengths[i];
        if seg_len == 0 {
            return self.points[i];
        }
        let t = along - self.lengths[i];
        let a = self.points[i];
        let b = self.points[i + 1];
        Point {
            x: a.x + round_div(i64::from(b.x - a.x) * t, seg_len) as i32,
            z: a.z + round_div(i64::from(b.z - a.z) * t, seg_len) as i32,
        }
    }

    /// The track of a line whose centreline is `points`, offset `offset` cm
    /// to the south.
    pub fn of(points: &[Point], offset: i32) -> TrackGeometry {
        let points = offset_polyline(points, offset);
        let lengths = cumulative_lengths(&points);
        TrackGeometry { points, lengths }
    }

    /// The point `along` cm from the west end, like [`Self::point_at`],
    /// but carried straight on past either end along the end segment: a
    /// vehicle part way through a portal is drawn where it is.
    pub fn point_extended(&self, along: i64) -> Point {
        let total = *self.lengths.last().expect("a track has at least one point");
        let n = self.points.len();
        if n < 2 || (0..=total).contains(&along) {
            return self.point_at(along);
        }
        let (i, from, past) = if along < 0 {
            (0, self.points[0], along)
        } else {
            (n - 2, self.points[n - 1], along - total)
        };
        let (a, b) = (self.points[i], self.points[i + 1]);
        let seg_len = self.lengths[i + 1] - self.lengths[i];
        if seg_len == 0 {
            return from;
        }
        Point {
            x: from.x + round_div(i64::from(b.x - a.x) * past, seg_len) as i32,
            z: from.z + round_div(i64::from(b.z - a.z) * past, seg_len) as i32,
        }
    }

    /// The segment (by its first vertex) a point `along` cm from the west
    /// end lies on, for something running `direction`: at a vertex, the
    /// one it has just come along. Past either end, the end segment.
    pub fn segment_at(&self, along: i64, direction: Direction) -> usize {
        let last = self.points.len().saturating_sub(2);
        match direction {
            Direction::East => (0..last)
                .find(|&i| self.lengths[i + 1] >= along)
                .unwrap_or(last),
            Direction::West => (1..=last)
                .rev()
                .find(|&i| self.lengths[i] <= along)
                .unwrap_or(0),
        }
    }

    /// The way something running `direction` faces `along` cm from the
    /// west end, in degrees clockwise from north.
    pub fn heading_at(&self, along: i64, direction: Direction) -> i32 {
        let (dx, dz) = self.travel_at(along, direction);
        heading_of(dx, dz)
    }

    /// The vector (cm) of the segment `along` lies on (see
    /// [`Self::segment_at`]), pointing the way `direction` runs.
    pub fn travel_at(&self, along: i64, direction: Direction) -> (i64, i64) {
        if self.points.len() < 2 {
            return (0, 0);
        }
        let i = self.segment_at(along, direction);
        let (a, b) = (self.points[i], self.points[i + 1]);
        let s = match direction {
            Direction::East => 1,
            Direction::West => -1,
        };
        (s * i64::from(b.x - a.x), s * i64::from(b.z - a.z))
    }

    /// The length (cm) of the segment `along` lies on, as `lengths` measures
    /// it.
    pub fn segment_length_at(&self, along: i64, direction: Direction) -> i64 {
        if self.points.len() < 2 {
            return 0;
        }
        let i = self.segment_at(along, direction);
        self.lengths[i + 1] - self.lengths[i]
    }
}

/// A validated stop, with its standing point on each track precomputed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StopInfo {
    pub id: PlaceId,
    pub name: String,
    pub at: i32,
    /// The platform rooms: the eastbound side first, then the westbound.
    pub platforms: [PlaceId; 2],
    /// Where a vehicle running each direction stands: the point on that
    /// direction's track at `at` cm from the west end.
    pub stand: [Point; 2],
}

/// A validated line, with its track geometry precomputed for Task 3's
/// vehicle movement.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LineInfo {
    pub id: PlaceId,
    pub name: String,
    pub mode: LineMode,
    /// The centreline's total length (cm).
    pub length: i64,
    /// The two tracks, eastbound then westbound.
    pub tracks: [TrackGeometry; 2],
    /// In the manifest's own order (not necessarily sorted by `at`).
    pub stops: Vec<StopInfo>,
    pub timetable: Timetable,
    pub vehicle: VehicleSpec,
    /// Half its vehicles' width (cm), from their catalogue kind: see
    /// [`crate::transit::half_width`].
    pub half_width: i64,
}

fn issue(code: &str, place: impl ToString, message: String) -> ValidationIssue {
    ValidationIssue {
        code: code.to_string(),
        place: Some(place.to_string()),
        message,
    }
}

/// What validation says to a manifest of schema 1, which carried room
/// obstacles and props where schema 2 carries placements.
pub const SCHEMA_ONE_MESSAGE: &str = "This manifest is schema 1. Regenerate it with \
    city/fixtures/district/generate.py, or move its obstacles and props into district \
    placements (docs/superpowers/specs/2026-09-27-city-placement-grid-design.md §3).";

/// The `schema-version` issue for a manifest of `version`, if it is not the
/// one this core reads.
pub fn schema_version_issue(version: u32) -> Option<ValidationIssue> {
    let message = match version {
        MANIFEST_SCHEMA_VERSION => return None,
        1 => SCHEMA_ONE_MESSAGE.to_string(),
        _ => format!(
            "Schema version {version} is not the supported version {MANIFEST_SCHEMA_VERSION}."
        ),
    };
    Some(ValidationIssue {
        code: "schema-version".into(),
        place: None,
        message,
    })
}

/// The issue of manifest text that does not parse as a manifest, when its
/// schema says why:
/// - `schema-version`, when it names a version other than this core's. A
///   schema 1 manifest's tree rows and blocks no longer parse, and it is
///   refused for its version, not for them;
/// - `removed-field`, when a manifest of this version still carries a
///   field schema 1 had and schema 2 replaced with placements: a
///   facility's `exterior`, a room's `obstacles` or `props`, or `tree-row`
///   or `block` scenery. The first found is named, facilities and rooms in
///   order, then the scenery.
pub fn unparsed_schema_issue(text: &str) -> Option<ValidationIssue> {
    let value: serde_json::Value = serde_json::from_str(text).ok()?;
    let version = u32::try_from(value.get("schema_version")?.as_u64()?).ok()?;
    schema_version_issue(version).or_else(|| removed_field_issue(&value))
}

/// Where each field schema 2 removed went, for the `removed-field` issue.
fn removed_field_issue(m: &serde_json::Value) -> Option<ValidationIssue> {
    let removed = |field: &str, place: &serde_json::Value, instead: &str| ValidationIssue {
        code: "removed-field".into(),
        place: Some(place.as_str().unwrap_or("?").to_string()),
        message: format!(
            "`{field}` is a schema 1 field. Schema 2 describes what stands in the city \
             with catalogue kinds and district placements: {instead} \
             (docs/superpowers/specs/2026-09-27-city-placement-grid-design.md §3)."
        ),
    };
    let list = |v: &serde_json::Value, key: &str| {
        v.get(key)
            .and_then(serde_json::Value::as_array)
            .cloned()
            .unwrap_or_default()
    };
    for district in list(&m["city"], "districts") {
        for facility in list(&district, "facilities") {
            if facility.get("exterior").is_some() {
                return Some(removed(
                    "exterior",
                    &facility["id"],
                    "give the facility a building `kind` from the catalogue instead",
                ));
            }
            for room in list(&facility, "rooms") {
                for field in ["obstacles", "props"] {
                    if room.get(field).is_some() {
                        return Some(removed(
                            field,
                            &room["id"],
                            "move each into the district's `placements`",
                        ));
                    }
                }
            }
        }
    }
    list(m, "scenery").iter().find_map(|s| {
        let kind = s.get("kind")?.as_str()?;
        ["tree-row", "block"].contains(&kind).then(|| {
            removed(
                kind,
                &serde_json::Value::from("scenery"),
                "move its trees or buildings into the district's `placements`",
            )
        })
    })
}

impl PlaceIndex {
    /// Checks every structural rule and collects every issue found.
    pub fn build(m: &Manifest) -> Result<PlaceIndex, Vec<ValidationIssue>> {
        let mut issues = Vec::new();
        issues.extend(schema_version_issue(m.schema_version));

        let mut seen = BTreeSet::new();
        let mut note = |id: &PlaceId, issues: &mut Vec<ValidationIssue>| {
            if !seen.insert(id.clone()) {
                issues.push(issue(
                    "duplicate-id",
                    id,
                    format!("Place ID {id} is used more than once."),
                ));
            }
        };

        let mut occupants = BTreeMap::new();
        for o in &m.occupants {
            if occupants.insert(o.id.clone(), o.clone()).is_some() {
                issues.push(issue(
                    "duplicate-occupant",
                    &o.id,
                    format!("Occupant {} is listed more than once.", o.id),
                ));
            }
        }

        let mut rooms = BTreeMap::new();
        let mut overflow = BTreeMap::new();
        note(&m.city.id, &mut issues);
        for d in &m.city.districts {
            note(&d.id, &mut issues);
            for f in &d.facilities {
                note(&f.id, &mut issues);
                for r in &f.rooms {
                    note(&r.id, &mut issues);
                    if r.capacity == 0 {
                        issues.push(issue(
                            "zero-capacity",
                            &r.id,
                            format!("Room {} has a capacity of zero.", r.id),
                        ));
                    }
                    let mut pods = BTreeMap::new();
                    for p in &r.pods {
                        note(&p.id, &mut issues);
                        pods.insert(p.id.clone(), p.department.clone());
                    }
                    let mut seats = Vec::new();
                    let mut reserved = BTreeMap::new();
                    for s in &r.seats {
                        note(&s.id, &mut issues);
                        let department = match &s.pod {
                            Some(pod) => match pods.get(pod) {
                                Some(dep) => dep.clone(),
                                None => {
                                    issues.push(issue(
                                        "unknown-pod",
                                        &s.id,
                                        format!(
                                            "Seat {} names pod {pod}, which is not in room {}.",
                                            s.id, r.id
                                        ),
                                    ));
                                    None
                                }
                            },
                            None => None,
                        };
                        if let Some(o) = &s.reserved_for {
                            if let Some(p) = occupants.get(o)
                                && !crate::project::shares_capacity(&p.kind)
                            {
                                issues.push(issue(
                                    "reserved-for-hidden",
                                    &s.id,
                                    format!("Seat {} is reserved for {o}, who is hidden from the public and takes no seat.", s.id),
                                ));
                            }
                            if !occupants.contains_key(o) {
                                issues.push(issue(
                                    "unknown-occupant",
                                    &s.id,
                                    format!("Seat {} is reserved for {o}, who is not a manifest occupant.", s.id),
                                ));
                            }
                            if reserved.insert(o.clone(), s.id.clone()).is_some() {
                                issues.push(issue(
                                    "duplicate-reservation",
                                    &s.id,
                                    format!(
                                        "{o} has more than one reserved seat in room {}.",
                                        r.id
                                    ),
                                ));
                            }
                        }
                        seats.push(SeatInfo {
                            id: s.id.clone(),
                            pod: s.pod.clone(),
                            department,
                            reserved_for: s.reserved_for.clone(),
                            pos: s.pos,
                            facing: s.facing.unwrap_or(0),
                            kind: s.kind.clone(),
                            anchor: s.anchor,
                        });
                    }
                    seats.sort_by(|a, b| a.id.cmp(&b.id));
                    let reserved_count =
                        r.seats.iter().filter(|s| s.reserved_for.is_some()).count();
                    if reserved_count as u64 > u64::from(r.capacity) {
                        issues.push(issue(
                            "reservations-exceed-capacity",
                            &r.id,
                            format!(
                                "Room {} reserves {reserved_count} seats but holds only {}.",
                                r.id, r.capacity
                            ),
                        ));
                    }
                    let mut doors = BTreeMap::new();
                    let mut door_list = Vec::new();
                    for door in &r.doors {
                        note(&door.id, &mut issues);
                        if door.to == r.id {
                            issues.push(issue(
                                "door-to-self",
                                &door.id,
                                format!("Door {} leads back into room {}.", door.id, r.id),
                            ));
                        }
                        if door.transit.min < 1
                            || door.transit.max < door.transit.min
                            || door.transit.max > MAX_TRANSIT
                        {
                            issues.push(issue(
                                "bad-transit",
                                &door.id,
                                format!("Door {} needs a transit from 1 to {MAX_TRANSIT} ticks, with max no less than min.", door.id),
                            ));
                        }
                        let info = DoorInfo {
                            id: door.id.clone(),
                            to: door.to.clone(),
                            transit: door.transit,
                            pos: door.pos,
                            width: door.width,
                        };
                        doors.entry(door.to.clone()).or_insert(info.clone());
                        door_list.push(info);
                    }
                    overflow.insert(r.id.clone(), r.overflow.clone());
                    rooms.insert(
                        r.id.clone(),
                        RoomInfo {
                            id: r.id.clone(),
                            name: r.name.clone(),
                            facility: f.id.clone(),
                            district: d.id.clone(),
                            level: r.level,
                            capacity: r.capacity,
                            seats,
                            reserved,
                            doors,
                            chain: Vec::new(),
                            template: r.template.clone(),
                            rect: r.rect,
                            door_list: {
                                door_list.sort_by(|a: &DoorInfo, b: &DoorInfo| a.id.cmp(&b.id));
                                door_list
                            },
                            outdoor: r.is_outdoor(),
                        },
                    );
                }
            }
        }

        for room in rooms.values() {
            for to in room.doors.keys() {
                if !rooms.contains_key(to) {
                    issues.push(issue(
                        "unknown-room",
                        &room.doors[to].id,
                        format!(
                            "Door {} leads to {to}, which is not a room.",
                            room.doors[to].id
                        ),
                    ));
                }
            }
            if let Some(Some(o)) = overflow.get(&room.id)
                && !rooms.contains_key(o)
            {
                issues.push(issue(
                    "unknown-room",
                    &room.id,
                    format!("Room {} overflows to {o}, which is not a room.", room.id),
                ));
            }
        }
        for o in occupants.values() {
            for place in [&o.home, &o.work].into_iter().flatten() {
                if !rooms.contains_key(place) {
                    issues.push(issue(
                        "unknown-room",
                        &o.id,
                        format!(
                            "Occupant {} names {place} as home or work, which is not a room.",
                            o.id
                        ),
                    ));
                }
            }
        }

        let ids: Vec<PlaceId> = rooms.keys().cloned().collect();
        for id in ids {
            let mut chain = vec![id.clone()];
            let mut at = id.clone();
            while let Some(Some(next)) = overflow.get(&at) {
                if !rooms.contains_key(next) {
                    break;
                }
                if chain.contains(next) {
                    issues.push(issue(
                        "overflow-cycle",
                        &id,
                        format!("Overflow from room {id} returns to {next}."),
                    ));
                    break;
                }
                chain.push(next.clone());
                at = next.clone();
            }
            rooms.get_mut(&id).expect("room exists").chain = chain;
        }

        if let Some(c) = m.clock
            && (c.ticks_per_day == 0 || c.start_minute >= 1440)
        {
            issues.push(ValidationIssue {
                code: "bad-clock".into(),
                place: None,
                message: "A clock needs at least one tick per day and a start minute below 1440."
                    .into(),
            });
        }
        if let Some(w) = &m.weather {
            let bad = m.clock.is_none()
                || w.rain.iter().any(|s| {
                    s.from >= 1440 || s.to >= 1440 || s.from == s.to || s.peak == 0 || s.peak > 100
                });
            if bad {
                issues.push(ValidationIssue {
                    code: "bad-weather".into(),
                    place: None,
                    message: "Weather needs a clock, and each rain spell a start and end below 1440 that differ and a peak from 1 to 100."
                        .into(),
                });
            }
        }
        let layout = m.has_layout();
        if layout {
            issues.extend(layout_issues(m, &rooms));
        }

        let mut lines = BTreeMap::new();
        for line in &m.lines {
            note(&line.id, &mut issues);
            for s in &line.stops {
                note(&s.id, &mut issues);
            }
            let (info, mut line_issues) = build_line(line, &rooms, layout);
            issues.append(&mut line_issues);
            if let Some(info) = info {
                lines.insert(line.id.clone(), info);
            }
        }
        for p in m.city.districts.iter().flat_map(|d| &d.placements) {
            note(&p.id, &mut issues);
        }

        let mut index = PlaceIndex {
            rooms,
            occupants,
            seat_policy: m.seat_policy,
            layout,
            entrances: m.city.entrances.clone(),
            clock: m.clock,
            lines,
            placements: Vec::new(),
            seat_furniture: Vec::new(),
            buildings: Vec::new(),
            nearby: Default::default(),
        };
        crate::placement::validate(m, Catalogue::builtin(), &mut index, &mut issues);
        if issues.is_empty() {
            Ok(index)
        } else {
            Err(issues)
        }
    }
}

impl PlaceIndex {
    /// The accepted placement or seat furniture with this ID.
    pub fn placed(&self, id: &PlaceId) -> Option<&PlacedInfo> {
        fn find<'a>(list: &'a [PlacedInfo], id: &PlaceId) -> Option<&'a PlacedInfo> {
            list.binary_search_by(|p| p.id.cmp(id))
                .ok()
                .map(|k| &list[k])
        }
        find(&self.placements, id).or_else(|| find(&self.seat_furniture, id))
    }

    /// Adds an accepted placement in its place in ID order.
    pub fn add_placement(&mut self, info: PlacedInfo) {
        let k = self
            .placements
            .binary_search_by(|p| p.id.cmp(&info.id))
            .unwrap_or_else(|k| k);
        self.nearby.add(&info);
        self.placements.insert(k, info);
    }

    /// Puts `after` where `before` stood: adds it, takes `before` out, or,
    /// both given (a move, under one ID), replaces it where it lies.
    pub fn swap_placement(&mut self, before: Option<&PlacedInfo>, after: Option<PlacedInfo>) {
        match (before, after) {
            (None, Some(after)) => self.add_placement(after),
            (Some(before), None) => {
                self.remove_placement(&before.id);
            }
            (Some(before), Some(after)) => {
                let k = self
                    .placements
                    .binary_search_by(|p| p.id.cmp(&before.id))
                    .expect("the placement replaced is there");
                self.nearby.remove(&self.placements[k]);
                self.nearby.add(&after);
                self.placements[k] = after;
            }
            (None, None) => {}
        }
    }

    /// Takes the placement with this ID out, if there is one.
    pub fn remove_placement(&mut self, id: &PlaceId) -> Option<PlacedInfo> {
        let k = self.placements.binary_search_by(|p| p.id.cmp(id)).ok()?;
        let info = self.placements.remove(k);
        self.nearby.remove(&info);
        Some(info)
    }
}

fn overlaps(a: &Rect, b: &Rect) -> bool {
    a.x < b.x + b.w && b.x < a.x + a.w && a.z < b.z + b.d && b.z < a.z + a.d
}

/// Whether `p` lies on the edge `a` and `b` share, at least one grid cell
/// away from either end of that edge.
fn on_shared_edge(a: &Rect, b: &Rect, p: Point) -> bool {
    const MARGIN: i32 = crate::nav::CELL;
    let horizontal = |z: i32| {
        let lo = a.x.max(b.x);
        let hi = (a.x + a.w).min(b.x + b.w);
        p.z == z && lo + MARGIN <= p.x && p.x <= hi - MARGIN
    };
    let vertical = |x: i32| {
        let lo = a.z.max(b.z);
        let hi = (a.z + a.d).min(b.z + b.d);
        p.x == x && lo + MARGIN <= p.z && p.z <= hi - MARGIN
    };
    (a.z + a.d == b.z && horizontal(b.z))
        || (b.z + b.d == a.z && horizontal(a.z))
        || (a.x + a.w == b.x && vertical(b.x))
        || (b.x + b.w == a.x && vertical(a.x))
}

fn layout_issues(m: &Manifest, rooms: &BTreeMap<PlaceId, RoomInfo>) -> Vec<ValidationIssue> {
    let mut out = Vec::new();
    let incomplete = |place: &dyn ToString, what: &str| {
        issue(
            "incomplete-layout",
            place.to_string(),
            format!(
                "{} has no {what}; a layout must be complete.",
                place.to_string()
            ),
        )
    };
    if m.city.entrances.is_empty() {
        out.push(incomplete(&m.city.id, "entrances"));
    }
    let all: Vec<&city_contracts::Room> = m
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .flat_map(|f| &f.rooms)
        .collect();
    for r in &all {
        let Some(rect) = r.rect else {
            out.push(incomplete(&r.id, "rect"));
            continue;
        };
        if rect.w <= 0 || rect.d <= 0 {
            out.push(issue(
                "bad-rect",
                &r.id,
                format!("Room {} needs a positive width and depth.", r.id),
            ));
            continue;
        }
        for seat in &r.seats {
            let Some(p) = seat.pos else {
                out.push(incomplete(&seat.id, "position"));
                continue;
            };
            if !rect.contains(p) {
                out.push(issue(
                    "seat-outside-room",
                    &seat.id,
                    format!("Seat {} lies outside room {}.", seat.id, r.id),
                ));
            }
        }
        for door in &r.doors {
            let Some(p) = door.pos else {
                out.push(incomplete(&door.id, "position"));
                continue;
            };
            let other = rooms.get(&door.to).and_then(|o| o.rect);
            if !other.is_some_and(|o| on_shared_edge(&rect, &o, p)) {
                out.push(issue(
                    "door-not-on-shared-edge",
                    &door.id,
                    format!(
                        "Door {} is not on the edge {} shares with {}.",
                        door.id, r.id, door.to
                    ),
                ));
            }
        }
    }
    let rects: Vec<(&PlaceId, Rect)> = all
        .iter()
        .filter_map(|r| r.rect.map(|x| (&r.id, x)))
        .collect();
    for (i, (a_id, a)) in rects.iter().enumerate() {
        for (b_id, b) in &rects[i + 1..] {
            if a.w > 0 && a.d > 0 && b.w > 0 && b.d > 0 && overlaps(a, b) {
                out.push(issue(
                    "rooms-overlap",
                    a_id,
                    format!("Rooms {a_id} and {b_id} overlap."),
                ));
            }
        }
    }
    // Entrances lie on open ground, between outdoor rooms or at their
    // edges, and never on an indoor room's floor or wall.
    for e in &m.city.entrances {
        let touching = all
            .iter()
            .filter(|r| r.rect.is_some_and(|x| on_or_in(&x, *e)));
        let outdoor = touching.clone().any(|r| r.is_outdoor());
        let indoor = touching.clone().any(|r| !r.is_outdoor());
        if !outdoor || indoor {
            out.push(issue(
                "entrance-not-on-outdoor-edge",
                &m.city.id,
                format!("Entrance ({}, {}) is not on an outdoor room.", e.x, e.z),
            ));
        }
    }
    // Water stands off every floor: where it overlaps a room, a bridge
    // covers the overlap. Surfaces (streets, bridges, fences) may lie on
    // open ground, but not on an indoor room. Blocks are placements now,
    // checked with the rest.
    let bridges: Vec<Rect> = m
        .scenery
        .iter()
        .filter(|s| matches!(s, Scenery::Bridge { .. }))
        .flat_map(scenery_boxes)
        .collect();
    for item in &m.scenery {
        let footprints = scenery_boxes(item);
        let water = matches!(item, Scenery::Water { .. });
        for r in &all {
            let Some(room) = r.rect else { continue };
            let over = footprints.iter().any(|b| {
                if !overlaps(b, &room) {
                    return false;
                }
                if !water {
                    return !r.is_outdoor();
                }
                !covered(&intersection(b, &room), &bridges)
            });
            if over {
                out.push(issue(
                    "scenery-over-walkable",
                    &r.id,
                    format!("A scenery item overlaps the floor of room {}.", r.id),
                ));
                break;
            }
        }
    }
    out
}

/// Whether `p` lies inside `r` or on its boundary.
fn on_or_in(r: &Rect, p: Point) -> bool {
    r.x <= p.x && p.x <= r.x + r.w && r.z <= p.z && p.z <= r.z + r.d
}

/// The overlap of two overlapping rectangles.
fn intersection(a: &Rect, b: &Rect) -> Rect {
    let x = a.x.max(b.x);
    let z = a.z.max(b.z);
    Rect {
        x,
        z,
        w: (a.x + a.w).min(b.x + b.w) - x,
        d: (a.z + a.d).min(b.z + b.d) - z,
    }
}

/// Whether the union of `covers` covers all of `r`: `r` minus each cover in
/// turn, split into the up to four rectangles around it, leaves nothing.
fn covered(r: &Rect, covers: &[Rect]) -> bool {
    let mut left = vec![*r];
    for c in covers {
        let mut next = Vec::new();
        for p in left {
            if !overlaps(&p, c) {
                next.push(p);
                continue;
            }
            let x1 = (p.x + p.w).min(c.x + c.w);
            let pieces = [
                Rect {
                    x: p.x,
                    z: p.z,
                    w: p.w,
                    d: c.z - p.z,
                },
                Rect {
                    x: p.x,
                    z: c.z + c.d,
                    w: p.w,
                    d: p.z + p.d - (c.z + c.d),
                },
                Rect {
                    x: p.x,
                    z: p.z.max(c.z),
                    w: c.x - p.x,
                    d: (p.z + p.d).min(c.z + c.d) - p.z.max(c.z),
                },
                Rect {
                    x: x1,
                    z: p.z.max(c.z),
                    w: p.x + p.w - x1,
                    d: (p.z + p.d).min(c.z + c.d) - p.z.max(c.z),
                },
            ];
            next.extend(pieces.into_iter().filter(|q| q.w > 0 && q.d > 0));
        }
        left = next;
    }
    left.is_empty()
}

/// Conservative footprints of a scenery item: its rect, or each segment's
/// bounding box widened by half its width.
/// A conservative bounding box for the segment `a`–`b` widened by `width`.
/// Widening only crosses the segment, not along it, when the segment runs
/// along an axis, so a street may end exactly on a room's edge; a diagonal
/// segment widens in both directions, a looser approximation.
fn segment_box(a: Point, b: Point, width: i32) -> Rect {
    let h = width / 2;
    let (hx, hz) = match (a.x == b.x, a.z == b.z) {
        (false, true) => (0, h),
        (true, false) => (h, 0),
        _ => (h, h),
    };
    Rect {
        x: a.x.min(b.x) - hx,
        z: a.z.min(b.z) - hz,
        w: (a.x - b.x).abs() + 2 * hx,
        d: (a.z - b.z).abs() + 2 * hz,
    }
}

fn scenery_boxes(item: &Scenery) -> Vec<Rect> {
    let line = |points: &[Point], width: i32| -> Vec<Rect> {
        points
            .windows(2)
            .map(|w| segment_box(w[0], w[1], width))
            .collect()
    };
    match item {
        Scenery::Water { rect } => vec![*rect],
        Scenery::Bridge { from, to, width } => vec![segment_box(*from, *to, *width)],
        Scenery::Street { points, width } => line(points, *width),
        Scenery::Fence { points } => line(points, 0),
    }
}

// ---- Transit lines ----

/// Divides `n` by `d` (both possibly negative), rounding to the nearest
/// integer with ties away from zero. Used to keep every offset and
/// interpolated track point an exact integer.
pub(crate) fn round_div(n: i64, d: i64) -> i64 {
    if d == 0 {
        return 0;
    }
    let (n, d) = if d < 0 { (-n, -d) } else { (n, d) };
    if n >= 0 {
        (n + d / 2) / d
    } else {
        -((-n + d / 2) / d)
    }
}

/// The cumulative length (cm) at each vertex of `points`: `[0] == 0`, and
/// the last entry is the polyline's total length. A diagonal segment's
/// length is its integer square root, rounded down, so a polyline with
/// diagonal segments can measure up to a centimetre short per segment.
fn cumulative_lengths(points: &[Point]) -> Vec<i64> {
    let mut out = vec![0i64];
    let mut total = 0i64;
    for w in points.windows(2) {
        let dx = i64::from(w[1].x - w[0].x);
        let dz = i64::from(w[1].z - w[0].z);
        let mag_sq = dx * dx + dz * dz;
        total += (mag_sq as u64).isqrt() as i64;
        out.push(total);
    }
    out
}

/// The perpendicular offset (cm) of the segment `a`–`b`, south-positive:
/// the sign convention `Line::tracks` uses. Rotating the segment's own
/// direction a quarter turn counter-clockwise, then scaling it to `offset`
/// cm, is exact for an axis-aligned segment (no division at all, since one
/// component is zero and the other a sign); a diagonal one normalises its
/// direction with the integer square root and rounds to the nearest
/// centimetre, ties away from zero.
fn segment_perp_offset(a: Point, b: Point, offset: i32) -> (i64, i64) {
    let dx = i64::from(b.x - a.x);
    let dz = i64::from(b.z - a.z);
    let mag_sq = dx * dx + dz * dz;
    if mag_sq == 0 {
        return (0, 0);
    }
    let mag = (mag_sq as u64).isqrt() as i64;
    let raw_x = -dz;
    let raw_z = dx;
    (
        round_div(raw_x * i64::from(offset), mag),
        round_div(raw_z * i64::from(offset), mag),
    )
}

/// Offsets a polyline by `offset` cm, positive to the south (+z). An
/// endpoint moves along its one adjacent segment's own perpendicular
/// (`segment_perp_offset`), exact for an axis-aligned segment.
///
/// An interior vertex gets a true miter join: each neighbouring segment
/// defines its own offset line (the segment translated by its own
/// perpendicular), and the vertex moves to where those two lines cross —
/// an exact 2D line intersection, found with one integer division rounded
/// to the nearest centimetre (ties away from zero). This lands the vertex
/// on both offset lines, `offset / cos(θ/2)` cm from the original vertex
/// for a bend of angle θ (a 90° bend at 100 cm lands about 141 cm out, not
/// the roughly 71 cm an unscaled average of the two perpendiculars would
/// give). When the two segments run parallel — a straight-through vertex,
/// or the degenerate case of a segment doubling straight back on itself —
/// there is no unique crossing, so the vertex falls back to the incoming
/// segment's own offset point; a straight polyline is therefore offset
/// exactly, and a straight reversal stays a bounded, if arbitrary, choice
/// rather than an undefined one.
///
/// A sharp enough bend sends the miter arbitrarily far out (its length
/// grows without bound as θ approaches a full reversal), so it is capped
/// at `4 * offset` cm from the original vertex, scaled back along its own
/// direction using the integer square root. Nothing in this codebase
/// exercises a bend that sharp today; the cap only guards Task 3's
/// geometry against a future manifest that does.
fn offset_polyline(points: &[Point], offset: i32) -> Vec<Point> {
    let n = points.len();
    if n < 2 {
        return points.to_vec();
    }
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let (dx, dz) = if i == 0 {
            segment_perp_offset(points[0], points[1], offset)
        } else if i + 1 == n {
            segment_perp_offset(points[i - 1], points[i], offset)
        } else {
            let (ox_in, oz_in) = segment_perp_offset(points[i - 1], points[i], offset);
            let (ox_out, oz_out) = segment_perp_offset(points[i], points[i + 1], offset);
            let dx_in = i64::from(points[i].x - points[i - 1].x);
            let dz_in = i64::from(points[i].z - points[i - 1].z);
            let dx_out = i64::from(points[i + 1].x - points[i].x);
            let dz_out = i64::from(points[i + 1].z - points[i].z);
            // The two segments' own offset lines: one through
            // points[i] + off_in with direction d_in, the other through
            // points[i] + off_out with direction d_out. Solve for where
            // they cross (see the doc comment above).
            let denom = dx_in * dz_out - dz_in * dx_out;
            if denom == 0 {
                (ox_in, oz_in)
            } else {
                let diff_x = ox_out - ox_in;
                let diff_z = oz_out - oz_in;
                let numer = diff_x * dz_out - diff_z * dx_out;
                let mx = ox_in + round_div(numer * dx_in, denom);
                let mz = oz_in + round_div(numer * dz_in, denom);
                let cap = 4 * i64::from(offset.abs());
                let disp_sq = mx * mx + mz * mz;
                if cap > 0 && disp_sq > cap * cap {
                    let mag = (disp_sq as u64).isqrt() as i64;
                    (round_div(mx * cap, mag), round_div(mz * cap, mag))
                } else {
                    (mx, mz)
                }
            }
        };
        out.push(Point {
            x: points[i].x + dx as i32,
            z: points[i].z + dz as i32,
        });
    }
    out
}

/// How far (cm) a stop's platform may stand from its track's window.
const PLATFORM_REACH: i64 = 150;

/// Whether `a` and `b` come within [`PLATFORM_REACH`] of each other
/// (compared by the squared distance, so no integer square root is needed).
fn within_150(a: &Rect, b: &Rect) -> bool {
    let gap_x = if a.x + a.w <= b.x {
        b.x - (a.x + a.w)
    } else if b.x + b.w <= a.x {
        a.x - (b.x + b.w)
    } else {
        0
    };
    let gap_z = if a.z + a.d <= b.z {
        b.z - (a.z + a.d)
    } else if b.z + b.d <= a.z {
        a.z - (b.z + b.d)
    } else {
        0
    };
    let (gap_x, gap_z) = (i64::from(gap_x), i64::from(gap_z));
    gap_x * gap_x + gap_z * gap_z <= PLATFORM_REACH * PLATFORM_REACH
}

/// The stretch `lo .. hi` (cm along `track`) of one vehicle length
/// (`length` cm) centred on `at`, clamped to the track's own extent: where a
/// vehicle stands at a stop there.
fn window(track: &TrackGeometry, at: i64, length: i64) -> Option<(i64, i64)> {
    if length <= 0 {
        return None;
    }
    let total = *track
        .lengths
        .last()
        .expect("a track has at least one point");
    let half = length / 2;
    let lo = (at - half).clamp(0, total);
    let hi = (at + half).clamp(0, total);
    Some(if lo <= hi { (lo, hi) } else { (hi, lo) })
}

/// A bounding box of `track` over one vehicle length (`length` cm) centred
/// on `at`, clamped to the track's own extent (so a stop near an end gets a
/// shorter window rather than one that runs off the track).
fn window_box(track: &TrackGeometry, at: i64, length: i64) -> Option<Rect> {
    let (lo, hi) = window(track, at, length)?;
    let p_lo = track.point_at(lo);
    let p_hi = track.point_at(hi);
    let mut xs = vec![p_lo.x, p_hi.x];
    let mut zs = vec![p_lo.z, p_hi.z];
    for (i, &l) in track.lengths.iter().enumerate() {
        if l > lo && l < hi {
            xs.push(track.points[i].x);
            zs.push(track.points[i].z);
        }
    }
    let (x0, x1) = (
        *xs.iter().min().expect("non-empty"),
        *xs.iter().max().expect("non-empty"),
    );
    let (z0, z1) = (
        *zs.iter().min().expect("non-empty"),
        *zs.iter().max().expect("non-empty"),
    );
    Some(Rect {
        x: x0,
        z: z0,
        w: x1 - x0,
        d: z1 - z0,
    })
}

fn dir_name(d: usize) -> &'static str {
    if d == 0 { "eastbound" } else { "westbound" }
}

/// Room (cm) between two passing vehicles beyond their width: two cells,
/// so every cell a vehicle covers lies within one tick's steps (five) of a
/// cell off both tracks, where a walker in its way is stepped aside.
const PASSING_GAP: i64 = 50;

/// The issues with a line's vehicle width: its kind must be a vehicle the
/// catalogue carries with a width, and passing vehicles must clear each
/// other with room between them for a walker to be stepped aside.
fn vehicle_width_issues(
    line: &Line,
    half_width: Result<i64, crate::transit::VehicleKindError>,
) -> Vec<ValidationIssue> {
    use crate::transit::VehicleKindError;
    let mut issues = Vec::new();
    let kind = line
        .vehicle
        .kind
        .as_deref()
        .unwrap_or(crate::transit::DEFAULT_VEHICLE_KIND);
    let half_width = match half_width {
        Ok(half_width) => half_width,
        Err(error) => {
            let why = match error {
                VehicleKindError::NotInCatalogue => "is not in the catalogue",
                VehicleKindError::NotAVehicle => "is not a vehicle kind",
                VehicleKindError::NoWidth => "is a vehicle kind with no width",
            };
            issues.push(issue(
                "unknown-vehicle-kind",
                &line.id,
                format!("Line {}'s vehicle kind {kind} {why}.", line.id),
            ));
            return issues;
        }
    };
    // Vehicles are twice their half width wide, centred on their track.
    let spacing = 2 * half_width + PASSING_GAP;
    if (i64::from(line.tracks[0]) - i64::from(line.tracks[1])).abs() < spacing {
        issues.push(issue(
            "line-tracks-too-close",
            &line.id,
            format!(
                "Line {}'s tracks must be at least {spacing} cm apart: a vehicle's width ({} cm) and {PASSING_GAP} cm between passing vehicles.",
                line.id,
                2 * half_width
            ),
        ));
    }
    issues
}

/// Whether `track`, over `lo .. hi` cm along it, comes nearer `rect` than
/// `reach` cm anywhere, compared exactly in integers.
fn track_near_rect(track: &TrackGeometry, lo: i64, hi: i64, rect: &Rect, reach: i64) -> bool {
    let mut points = vec![track.point_at(lo)];
    for (i, &l) in track.lengths.iter().enumerate() {
        if l > lo && l < hi {
            points.push(track.points[i]);
        }
    }
    points.push(track.point_at(hi));
    points
        .windows(2)
        .any(|w| segment_near_rect(w[0], w[1], rect, reach))
}

/// Whether the segment `a`–`b` comes nearer `rect` (its edges included)
/// than `reach` cm. Disjoint, a segment and a rect are nearest at an end of
/// the segment or a corner of the rect, so those are all that are measured.
fn segment_near_rect(a: Point, b: Point, rect: &Rect, reach: i64) -> bool {
    let (x0, z0) = (i128::from(rect.x), i128::from(rect.z));
    let (x1, z1) = (x0 + i128::from(rect.w), z0 + i128::from(rect.d));
    let reach = i128::from(reach);
    let to_rect = |p: Point| {
        let (px, pz) = (i128::from(p.x), i128::from(p.z));
        let dx = (x0 - px).max(0).max(px - x1);
        let dz = (z0 - pz).max(0).max(pz - z1);
        dx * dx + dz * dz < reach * reach
    };
    let (ax, az) = (i128::from(a.x), i128::from(a.z));
    let (vx, vz) = (i128::from(b.x) - ax, i128::from(b.z) - az);
    let squared = vx * vx + vz * vz;
    let to_segment = |(px, pz): (i128, i128)| {
        let (wx, wz) = (px - ax, pz - az);
        let t = wx * vx + wz * vz;
        if squared == 0 || t <= 0 {
            wx * wx + wz * wz < reach * reach
        } else if t >= squared {
            let (ux, uz) = (px - ax - vx, pz - az - vz);
            ux * ux + uz * uz < reach * reach
        } else {
            let cross = wx * vz - wz * vx;
            cross * cross < reach * reach * squared
        }
    };
    let corners = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)];
    // The segment crosses the rect when their boxes overlap and the rect's
    // corners do not all lie strictly on one side of the segment's line.
    let side = |(px, pz): (i128, i128)| ((px - ax) * vz - (pz - az) * vx).signum();
    let boxes_overlap = ax.min(ax + vx) <= x1
        && ax.max(ax + vx) >= x0
        && az.min(az + vz) <= z1
        && az.max(az + vz) >= z0;
    let sides: Vec<i128> = corners.iter().map(|c| side(*c)).collect();
    let crosses = boxes_overlap && !(sides.iter().all(|s| *s > 0) || sides.iter().all(|s| *s < 0));
    crosses || to_rect(a) || to_rect(b) || corners.iter().any(|c| to_segment(*c))
}

/// Validates one line and, unless its centreline is unusable, precomputes
/// its track geometry.
fn build_line(
    line: &Line,
    rooms: &BTreeMap<PlaceId, RoomInfo>,
    layout: bool,
) -> (Option<LineInfo>, Vec<ValidationIssue>) {
    let mut issues = Vec::new();
    if line.points.len() < 2 {
        issues.push(issue(
            "line-too-short",
            &line.id,
            format!("Line {} needs at least two centreline points.", line.id),
        ));
        return (None, issues);
    }
    let mut zero_segment = false;
    for w in line.points.windows(2) {
        if w[0] == w[1] {
            zero_segment = true;
            issues.push(issue(
                "line-zero-length-segment",
                &line.id,
                format!(
                    "Line {} has a zero-length segment at ({}, {}).",
                    line.id, w[0].x, w[0].z
                ),
            ));
        }
    }
    if zero_segment {
        return (None, issues);
    }

    let centre_lengths = cumulative_lengths(&line.points);
    let total_length = *centre_lengths.last().expect("checked above");

    let tracks: [TrackGeometry; 2] =
        std::array::from_fn(|d| TrackGeometry::of(&line.points, line.tracks[d]));

    if layout {
        for (d, track) in tracks.iter().enumerate() {
            for w in track.points.windows(2) {
                let track_box = segment_box(w[0], w[1], 0);
                for room in rooms.values() {
                    if room.outdoor {
                        continue;
                    }
                    let Some(rect) = room.rect else { continue };
                    if overlaps(&track_box, &rect) {
                        issues.push(issue(
                            "line-crosses-room",
                            &line.id,
                            format!(
                                "Line {}'s {} track crosses room {}, which is indoor.",
                                line.id,
                                dir_name(d),
                                room.id
                            ),
                        ));
                    }
                }
            }
        }
    }

    let t = &line.timetable;
    let v = &line.vehicle;
    if t.headway == 0 {
        issues.push(issue(
            "line-non-positive-number",
            &line.id,
            format!("Line {}'s timetable headway must be positive.", line.id),
        ));
    }
    if t.speed == 0 {
        issues.push(issue(
            "line-non-positive-number",
            &line.id,
            format!("Line {}'s timetable speed must be positive.", line.id),
        ));
    }
    if t.dwell == 0 {
        issues.push(issue(
            "line-non-positive-number",
            &line.id,
            format!("Line {}'s timetable dwell must be positive.", line.id),
        ));
    }
    if v.length <= 0 {
        issues.push(issue(
            "line-non-positive-number",
            &line.id,
            format!("Line {}'s vehicle length must be positive.", line.id),
        ));
    }
    if u64::from(t.dwell) * 2 >= u64::from(t.headway) {
        issues.push(issue(
            "line-dwell-too-long",
            &line.id,
            format!(
                "Line {}'s dwell, doubled, must be less than its headway.",
                line.id
            ),
        ));
    }
    if v.capacity == 0 {
        issues.push(issue(
            "line-zero-capacity",
            &line.id,
            format!("Line {}'s vehicle capacity must be at least one.", line.id),
        ));
    }
    let half_width = crate::transit::vehicle_half_width(Catalogue::builtin(), v);
    issues.extend(vehicle_width_issues(line, half_width));
    if v.length > 0 && v.doors.iter().any(|d| !(0..=v.length).contains(d)) {
        issues.push(issue(
            "line-door-outside-vehicle",
            &line.id,
            format!(
                "Line {}'s vehicle doors must lie within its length (0 to {} cm from its front).",
                line.id, v.length
            ),
        ));
    }

    let mut stop_infos = Vec::with_capacity(line.stops.len());
    let mut ats: Vec<(PlaceId, i32)> = Vec::with_capacity(line.stops.len());
    for s in &line.stops {
        if s.at < 0 || i64::from(s.at) > total_length {
            issues.push(issue(
                "stop-outside-line",
                &s.id,
                format!("Stop {} lies outside line {}.", s.id, line.id),
            ));
        }
        ats.push((s.id.clone(), s.at));

        let stand: [Point; 2] = std::array::from_fn(|d| tracks[d].point_at(i64::from(s.at)));

        for (d, platform) in s.platforms.iter().enumerate() {
            match rooms.get(platform) {
                None => {
                    issues.push(issue(
                        "line-missing-platform",
                        &s.id,
                        format!(
                            "Stop {}'s {} platform {} is not a room.",
                            s.id,
                            dir_name(d),
                            platform
                        ),
                    ));
                }
                Some(room) => {
                    if !room.outdoor {
                        issues.push(issue(
                            "line-indoor-platform",
                            &s.id,
                            format!(
                                "Stop {}'s {} platform {} is not outdoor.",
                                s.id,
                                dir_name(d),
                                room.id
                            ),
                        ));
                    }
                    // A vehicle standing here reaches its half width from
                    // its track; a waiter at the platform's edge stands the
                    // body clearance beyond that.
                    if let (Some(rect), Ok(half_width)) = (room.rect, half_width)
                        && let Some((lo, hi)) =
                            window(&tracks[d], i64::from(s.at), i64::from(v.length))
                        && track_near_rect(
                            &tracks[d],
                            lo,
                            hi,
                            &rect,
                            half_width + crate::footprint::MARGIN,
                        )
                    {
                        issues.push(issue(
                            "platform-in-vehicle-clearance",
                            &s.id,
                            format!(
                                "Stop {}'s {} platform {} stands within {} cm of its track, inside a {} cm vehicle and the body clearance.",
                                s.id,
                                dir_name(d),
                                room.id,
                                half_width + crate::footprint::MARGIN,
                                2 * half_width
                            ),
                        ));
                    }
                    if let Some(rect) = room.rect
                        && let Some(wbox) =
                            window_box(&tracks[d], i64::from(s.at), i64::from(v.length))
                        && !within_150(&rect, &wbox)
                    {
                        issues.push(issue(
                            "line-platform-not-adjoining",
                            &s.id,
                            format!(
                                "Stop {}'s {} platform {} does not adjoin its track.",
                                s.id,
                                dir_name(d),
                                room.id
                            ),
                        ));
                    }
                }
            }
        }

        stop_infos.push(StopInfo {
            id: s.id.clone(),
            name: s.name.clone(),
            at: s.at,
            platforms: s.platforms.clone(),
            stand,
        });
    }

    let mut sorted = ats.clone();
    sorted.sort_by_key(|(_, at)| *at);
    for w in sorted.windows(2) {
        let gap = i64::from(w[1].1 - w[0].1);
        if v.length > 0 && gap < i64::from(v.length) {
            issues.push(issue(
                "stops-too-close",
                &line.id,
                format!(
                    "Stops {} and {} on line {} stand closer than one vehicle length apart.",
                    w[0].0, w[1].0, line.id
                ),
            ));
        }
    }

    let info = LineInfo {
        id: line.id.clone(),
        name: line.name.clone(),
        mode: line.mode,
        length: total_length,
        tracks,
        stops: stop_infos,
        timetable: *t,
        vehicle: v.clone(),
        // A kind with no width is refused above, so no world runs with 0.
        half_width: half_width.unwrap_or(0),
    };
    (Some(info), issues)
}

/// Validates a manifest and reports every issue.
pub fn validate(m: &Manifest) -> ValidationReport {
    match PlaceIndex::build(m) {
        Ok(_) => ValidationReport {
            valid: true,
            issues: Vec::new(),
        },
        Err(issues) => ValidationReport {
            valid: false,
            issues,
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use city_contracts::*;
    use serde_json::json;

    fn base() -> Manifest {
        serde_json::from_value(json!({
            "schema_version": 2,
            "catalogue": 1,
            "city": {"id": "city:t", "name": "T", "districts": [
                {"id": "district:d", "name": "D", "facilities": [
                    {"id": "facility:f", "name": "F", "rooms": [
                        {"id": "room:a", "name": "A", "capacity": 2,
                         "pods": [{"id": "pod:m", "department": "making"}],
                         "seats": [{"id": "seat:a1", "pod": "pod:m"},
                                   {"id": "seat:a2", "reserved_for": "agent:kai"}],
                         "overflow": "room:b",
                         "doors": [{"id": "door:ab", "to": "room:b", "transit": {"min": 1, "max": 2}}]},
                        {"id": "room:b", "name": "B", "capacity": 1,
                         "seats": [{"id": "seat:b1"}]}
                    ]}
                ]}
            ]},
            "occupants": [{"id": "agent:kai", "kind": {"type": "GuildAgent"},
                           "display_name": "Kai", "work": "room:a"}]
        }))
        .unwrap()
    }

    fn room_mut<'a>(m: &'a mut Manifest, id: &str) -> &'a mut Room {
        m.city
            .districts
            .iter_mut()
            .flat_map(|d| d.facilities.iter_mut())
            .flat_map(|f| f.rooms.iter_mut())
            .find(|r| r.id.as_str() == id)
            .unwrap()
    }

    fn codes(m: &Manifest) -> Vec<String> {
        validate(m).issues.into_iter().map(|i| i.code).collect()
    }

    fn has(m: &Manifest, code: &str) -> bool {
        codes(m).iter().any(|c| c == code)
    }

    #[test]
    fn valid_manifest_builds_an_index() {
        let idx = PlaceIndex::build(&base()).unwrap();
        let a = &idx.rooms[&PlaceId::from("room:a")];
        assert_eq!(
            a.chain,
            vec![PlaceId::from("room:a"), PlaceId::from("room:b")]
        );
        assert_eq!(
            a.reserved[&CityId::from("agent:kai")],
            PlaceId::from("seat:a2")
        );
        assert_eq!(a.seats[0].department.as_deref(), Some("making"));
        assert_eq!(a.facility, PlaceId::from("facility:f"));
        assert!(validate(&base()).valid);
    }

    #[test]
    fn rejects_overflow_cycle() {
        let mut m = base();
        room_mut(&mut m, "room:b").overflow = Some("room:a".into());
        assert!(has(&m, "overflow-cycle"));
    }

    #[test]
    fn rejects_reservation_for_unknown_occupant() {
        let mut m = base();
        m.occupants.clear();
        assert!(has(&m, "unknown-occupant"));
    }

    #[test]
    fn rejects_door_to_missing_room() {
        let mut m = base();
        room_mut(&mut m, "room:a").doors[0].to = "room:zz".into();
        assert!(has(&m, "unknown-room"));
    }

    #[test]
    fn rejects_seat_in_unknown_pod() {
        let mut m = base();
        room_mut(&mut m, "room:b").seats[0].pod = Some("pod:m".into());
        assert!(has(&m, "unknown-pod"));
    }

    #[test]
    fn rejects_duplicate_ids() {
        let mut m = base();
        room_mut(&mut m, "room:b").seats[0].id = "seat:a1".into();
        assert!(has(&m, "duplicate-id"));
    }

    #[test]
    fn rejects_too_many_reservations() {
        let mut m = base();
        room_mut(&mut m, "room:a").capacity = 0;
        assert!(has(&m, "zero-capacity"));
        assert!(has(&m, "reservations-exceed-capacity"));
    }

    #[test]
    fn rejects_bad_transit_and_self_doors() {
        let mut m = base();
        let d = &mut room_mut(&mut m, "room:a").doors[0];
        d.transit = TickRange { min: 0, max: 0 };
        d.to = "room:a".into();
        assert!(has(&m, "bad-transit"));
        assert!(has(&m, "door-to-self"));
    }

    #[test]
    fn rejects_wrong_schema_version() {
        let mut m = base();
        m.schema_version = 9;
        assert!(has(&m, "schema-version"));
    }

    #[test]
    fn refuses_schema_one_naming_the_generator() {
        let mut m = base();
        m.schema_version = 1;
        let issues = PlaceIndex::build(&m).unwrap_err();
        let found: Vec<&ValidationIssue> = issues
            .iter()
            .filter(|i| i.code == "schema-version")
            .collect();
        assert_eq!(found.len(), 1);
        assert_eq!(
            found[0].message,
            "This manifest is schema 1. Regenerate it with city/fixtures/district/generate.py, \
             or move its obstacles and props into district placements \
             (docs/superpowers/specs/2026-09-27-city-placement-grid-design.md §3)."
        );
    }

    #[test]
    fn a_schema_two_manifest_with_a_field_schema_one_had_is_refused_by_name() {
        // Each removed field, where schema 1 carried it: never silently
        // dropped, and refused naming the field and where it goes now.
        type Add = fn(&mut serde_json::Value);
        let cases: [(&str, Add, &str); 5] = [
            (
                "exterior",
                |m| m["city"]["districts"][0]["facilities"][0]["exterior"] = json!("guild-hall"),
                "facility:f",
            ),
            (
                "obstacles",
                |m| {
                    m["city"]["districts"][0]["facilities"][0]["rooms"][0]["obstacles"] =
                        json!([{"x": 0, "z": 0, "w": 100, "d": 100}])
                },
                "room:a",
            ),
            (
                "props",
                |m| {
                    m["city"]["districts"][0]["facilities"][0]["rooms"][1]["props"] =
                        json!([{"kind": "lamp", "pos": {"x": 0, "z": 0}}])
                },
                "room:b",
            ),
            (
                "tree-row",
                |m| {
                    m["scenery"] = json!([{"kind": "tree-row", "spacing": 600,
                        "points": [{"x": 0, "z": 0}, {"x": 600, "z": 0}]}])
                },
                "scenery",
            ),
            (
                "block",
                |m| {
                    m["scenery"] = json!([{"kind": "block", "height_class": "shop",
                        "rect": {"x": 0, "z": 0, "w": 10, "d": 10}}])
                },
                "scenery",
            ),
        ];
        for (field, add, place) in cases {
            let mut m = serde_json::to_value(base()).unwrap();
            add(&mut m);
            let text = m.to_string();
            assert!(
                serde_json::from_str::<Manifest>(&text).is_err(),
                "{field}: not silently ignored"
            );
            let issue = unparsed_schema_issue(&text).unwrap_or_else(|| panic!("{field}: an issue"));
            assert_eq!(issue.code, "removed-field", "{field}");
            assert_eq!(issue.place.as_deref(), Some(place), "{field}");
            assert!(
                issue.message.contains(&format!("`{field}`"))
                    && issue.message.contains("placements"),
                "{field}: {}",
                issue.message
            );
        }
    }

    #[test]
    fn text_that_no_longer_parses_is_refused_for_its_version() {
        let old = r#"{"schema_version": 1, "city": {"id": "c", "name": "C", "districts": []},
            "scenery": [{"kind": "block", "rect": {"x": 0, "z": 0, "w": 10, "d": 10}, "height_class": "shop"}]}"#;
        assert!(serde_json::from_str::<Manifest>(old).is_err());
        let issue = unparsed_schema_issue(old).unwrap();
        assert_eq!(issue.code, "schema-version");
        assert_eq!(issue.message, SCHEMA_ONE_MESSAGE);
        let current = old
            .replace("\"schema_version\": 1", "\"schema_version\": 2")
            .replace("\"block\"", "\"tower\"");
        assert_eq!(
            unparsed_schema_issue(&current),
            None,
            "broken, but not by its version or a removed field"
        );
        assert_eq!(unparsed_schema_issue("not json"), None);
    }

    #[test]
    fn rejects_duplicate_reservation_and_occupant() {
        let mut m = base();
        room_mut(&mut m, "room:a").seats[0].reserved_for = Some("agent:kai".into());
        let kai = m.occupants[0].clone();
        m.occupants.push(kai);
        assert!(has(&m, "duplicate-reservation"));
        assert!(has(&m, "duplicate-occupant"));
    }

    #[test]
    fn rejects_transit_long_enough_to_overflow_time() {
        let mut m = base();
        room_mut(&mut m, "room:a").doors[0].transit = TickRange {
            min: u64::MAX,
            max: u64::MAX,
        };
        assert!(has(&m, "bad-transit"));
    }

    #[test]
    fn rejects_seat_reserved_for_a_hidden_occupant() {
        let mut m = base();
        m.occupants[0].kind = OccupantKind::PersonalAgent {
            owner: "person:x".into(),
        };
        assert!(has(&m, "reserved-for-hidden"));
    }

    // ---- Layout ----

    fn layout_codes(m: &Manifest) -> Vec<String> {
        codes(m)
    }

    fn lroom<'a>(m: &'a mut Manifest, id: &str) -> &'a mut Room {
        room_mut(m, id)
    }

    #[test]
    fn valid_layout_builds() {
        let m = super::fixtures::layout_base();
        assert!(validate(&m).valid, "{:?}", validate(&m).issues);
        let idx = PlaceIndex::build(&m).unwrap();
        assert!(idx.layout);
        assert_eq!(idx.entrances, vec![Point { x: 0, z: 600 }]);
        let a = &idx.rooms[&PlaceId::from("room:a")];
        assert_eq!(
            a.rect,
            Some(Rect {
                x: 0,
                z: 0,
                w: 400,
                d: 400
            })
        );
        assert_eq!(a.seats[0].pos, Some(Point { x: 100, z: 100 }));
        assert_eq!(a.template.as_deref(), Some("workshop"));
    }

    #[test]
    fn layoutless_manifests_stay_valid() {
        assert!(validate(&base()).valid);
        assert!(!PlaceIndex::build(&base()).unwrap().layout);
    }

    #[test]
    fn rejects_incomplete_layout() {
        let mut m = super::fixtures::layout_base();
        lroom(&mut m, "room:a").seats[0].pos = None;
        assert!(layout_codes(&m).contains(&"incomplete-layout".into()));
        let mut m = super::fixtures::layout_base();
        m.city.entrances.clear();
        assert!(layout_codes(&m).contains(&"incomplete-layout".into()));
    }

    #[test]
    fn rejects_seat_outside_room() {
        let mut m = super::fixtures::layout_base();
        lroom(&mut m, "room:a").seats[0].pos = Some(Point { x: 500, z: 100 });
        assert!(layout_codes(&m).contains(&"seat-outside-room".into()));
    }

    #[test]
    fn rejects_overlapping_rooms_and_bad_rects() {
        let mut m = super::fixtures::layout_base();
        lroom(&mut m, "room:p").rect = Some(Rect {
            x: 0,
            z: 300,
            w: 800,
            d: 400,
        });
        assert!(layout_codes(&m).contains(&"rooms-overlap".into()));
        let mut m = super::fixtures::layout_base();
        lroom(&mut m, "room:a").rect = Some(Rect {
            x: 0,
            z: 0,
            w: 0,
            d: 400,
        });
        assert!(layout_codes(&m).contains(&"bad-rect".into()));
    }

    #[test]
    fn rejects_door_off_the_shared_edge() {
        let mut m = super::fixtures::layout_base();
        lroom(&mut m, "room:a").doors[0].pos = Some(Point { x: 200, z: 100 });
        assert!(layout_codes(&m).contains(&"door-not-on-shared-edge".into()));
        let mut m = super::fixtures::layout_base();
        lroom(&mut m, "room:a").doors[0].pos = Some(Point { x: 600, z: 400 });
        assert!(layout_codes(&m).contains(&"door-not-on-shared-edge".into()));
    }

    #[test]
    fn rejects_entrance_off_an_outdoor_edge() {
        let mut m = super::fixtures::layout_base();
        m.city.entrances = vec![Point { x: 0, z: 100 }];
        assert!(layout_codes(&m).contains(&"entrance-not-on-outdoor-edge".into()));
        let mut m = super::fixtures::layout_base();
        m.city.entrances = vec![Point { x: 200, z: 400 }];
        assert!(layout_codes(&m).contains(&"entrance-not-on-outdoor-edge".into()));
    }

    #[test]
    fn rejects_bad_weather() {
        let spell = |from: u32, to: u32, peak: u8| Weather {
            rain: vec![RainSpell { from, to, peak }],
        };
        for w in [
            spell(600, 600, 50),
            spell(600, 700, 0),
            spell(600, 700, 101),
            spell(1440, 60, 50),
        ] {
            let mut m = super::fixtures::layout_base();
            m.weather = Some(w.clone());
            assert!(layout_codes(&m).contains(&"bad-weather".into()), "{w:?}");
        }
        let mut m = super::fixtures::layout_base();
        m.clock = None;
        m.weather = Some(spell(600, 700, 50));
        assert!(
            layout_codes(&m).contains(&"bad-weather".into()),
            "weather needs a clock"
        );
        let mut m = super::fixtures::layout_base();
        m.weather = Some(spell(1380, 60, 80));
        assert!(validate(&m).valid, "{:?}", validate(&m).issues);
    }

    #[test]
    fn rejects_bad_clock() {
        let mut m = super::fixtures::layout_base();
        m.clock = Some(Clock {
            ticks_per_day: 0,
            start_minute: 0,
        });
        assert!(layout_codes(&m).contains(&"bad-clock".into()));
        let mut m = base();
        m.clock = Some(Clock {
            ticks_per_day: 600,
            start_minute: 1440,
        });
        assert!(layout_codes(&m).contains(&"bad-clock".into()));
    }

    // ---- Scenery and outdoor flags ----

    fn with_scenery(v: serde_json::Value) -> Manifest {
        let mut m = super::fixtures::layout_base();
        m.scenery = serde_json::from_value(v).unwrap();
        m
    }

    #[test]
    fn scenery_off_the_floors_is_valid() {
        let m = with_scenery(json!([
            {"kind": "street", "points": [{"x": -600, "z": 600}, {"x": 0, "z": 600}], "width": 200},
            {"kind": "water", "rect": {"x": -2000, "z": 0, "w": 1000, "d": 800}}
        ]));
        assert!(validate(&m).valid, "{:?}", validate(&m).issues);
    }

    #[test]
    fn scenery_over_a_floor_is_rejected() {
        for item in [
            json!({"kind": "water", "rect": {"x": 100, "z": 100, "w": 100, "d": 100}}),
            json!({"kind": "water", "rect": {"x": 700, "z": 500, "w": 300, "d": 100}}),
            json!({"kind": "street", "points": [{"x": -600, "z": 200}, {"x": 200, "z": 200}], "width": 200}),
            json!({"kind": "bridge", "from": {"x": 100, "z": 100}, "to": {"x": 300, "z": 100}, "width": 100}),
            json!({"kind": "fence", "points": [{"x": 100, "z": 300}, {"x": 300, "z": 300}]}),
        ] {
            let m = with_scenery(json!([item]));
            assert!(
                layout_codes(&m).contains(&"scenery-over-walkable".into()),
                "{item}"
            );
        }
    }

    fn streets_with(v: serde_json::Value) -> Manifest {
        let mut m = super::fixtures::layout_streets();
        m.scenery = serde_json::from_value(v).unwrap();
        m
    }

    #[test]
    fn open_ground_may_carry_streets_fences_and_a_bridge() {
        let m = streets_with(json!([
            {"kind": "street", "points": [{"x": -800, "z": 600}, {"x": 1600, "z": 600}], "width": 300},
            {"kind": "fence", "points": [{"x": -800, "z": 0}, {"x": -800, "z": 800}]},
            {"kind": "bridge", "from": {"x": 900, "z": 500}, "to": {"x": 1500, "z": 500}, "width": 200}
        ]));
        assert!(validate(&m).valid, "{:?}", validate(&m).issues);
    }

    #[test]
    fn water_must_be_bridged_over_open_ground() {
        let m = streets_with(json!([
            {"kind": "water", "rect": {"x": -700, "z": 100, "w": 200, "d": 200}}
        ]));
        assert!(layout_codes(&m).contains(&"scenery-over-walkable".into()));
        // A placement standing in the water covers none of it: only a
        // bridge does.
        let mut m = streets_with(json!([
            {"kind": "water", "rect": {"x": 1100, "z": 100, "w": 200, "d": 200}}
        ]));
        assert!(!m.city.districts[0].placements.is_empty(), "the house");
        assert!(layout_codes(&m).contains(&"scenery-over-walkable".into()));
        m.scenery.clear();
        assert!(validate(&m).valid, "{:?}", validate(&m).issues);
        // Water is crossed only on a bridge.
        let m = streets_with(json!([
            {"kind": "water", "rect": {"x": -700, "z": 100, "w": 200, "d": 200}},
            {"kind": "bridge", "from": {"x": -800, "z": 200}, "to": {"x": -400, "z": 200}, "width": 250}
        ]));
        assert!(validate(&m).valid, "{:?}", validate(&m).issues);
    }

    #[test]
    fn entrances_may_sit_between_outdoor_rooms_but_never_on_an_indoor_one() {
        let mut m = super::fixtures::layout_streets();
        m.city.entrances = vec![
            Point { x: 0, z: 600 },
            Point { x: 800, z: 500 },
            Point { x: -400, z: 400 },
        ];
        assert!(validate(&m).valid, "{:?}", validate(&m).issues);
        m.city.entrances = vec![Point { x: 0, z: 200 }];
        assert!(
            layout_codes(&m).contains(&"entrance-not-on-outdoor-edge".into()),
            "the hall's wall"
        );
    }

    #[test]
    fn outdoor_flag_allows_entrances_on_new_templates() {
        let mut m = super::fixtures::layout_base();
        let p = lroom(&mut m, "room:p");
        p.template = Some("park".into());
        p.outdoor = true;
        assert!(validate(&m).valid, "{:?}", validate(&m).issues);
        let mut m = super::fixtures::layout_base();
        lroom(&mut m, "room:p").template = Some("park".into());
        assert!(layout_codes(&m).contains(&"entrance-not-on-outdoor-edge".into()));
    }

    // ---- Transit lines ----

    #[test]
    fn valid_line_builds_track_geometry() {
        let m = super::fixtures::line_base();
        assert!(validate(&m).valid, "{:?}", validate(&m).issues);
        let idx = PlaceIndex::build(&m).unwrap();
        let line = &idx.lines[&PlaceId::from("line:boulevard")];
        assert_eq!(line.length, 2000);
        assert_eq!(
            line.tracks[0].points,
            vec![Point { x: -1000, z: -550 }, Point { x: 1000, z: -550 }]
        );
        assert_eq!(
            line.tracks[1].points,
            vec![Point { x: -1000, z: -250 }, Point { x: 1000, z: -250 }]
        );
        assert_eq!(line.tracks[0].lengths, vec![0, 2000]);
        assert_eq!(
            line.stops[0].stand,
            [Point { x: 0, z: -550 }, Point { x: 0, z: -250 }]
        );
    }

    // ---- offset_polyline: the miter join at a bend ----

    /// Whether `p` lies within `max_cm` of the infinite line through `a`
    /// with direction `dir`, compared by squared distance (a cross product
    /// over the squared direction length) so no square root is needed.
    fn near_line(p: Point, a: Point, dir: (i64, i64), max_cm: i64) -> bool {
        let (dx, dz) = dir;
        let px = i64::from(p.x - a.x);
        let pz = i64::from(p.z - a.z);
        let cross = px * dz - pz * dx;
        let dir_sq = dx * dx + dz * dz;
        cross * cross <= max_cm * max_cm * dir_sq
    }

    /// Asserts that offsetting `points` by `offset` lands the interior
    /// vertex within `max_cm` of both neighbouring segments' own offset
    /// lines (the standard miter-join property), and returns the offset
    /// polyline for any further checks.
    fn assert_miters_onto_both_lines(points: &[Point], offset: i32, max_cm: i64) -> Vec<Point> {
        let out = offset_polyline(points, offset);
        let mid = points.len() / 2;
        let d_in = (
            i64::from(points[mid].x - points[mid - 1].x),
            i64::from(points[mid].z - points[mid - 1].z),
        );
        let d_out = (
            i64::from(points[mid + 1].x - points[mid].x),
            i64::from(points[mid + 1].z - points[mid].z),
        );
        assert!(
            near_line(out[mid], out[0], d_in, max_cm),
            "{:?} not within {max_cm} cm of the incoming segment's offset line",
            out[mid]
        );
        assert!(
            near_line(out[mid], out[points.len() - 1], d_out, max_cm),
            "{:?} not within {max_cm} cm of the outgoing segment's offset line",
            out[mid]
        );
        out
    }

    #[test]
    fn a_track_extends_past_its_ends_and_heads_the_way_it_runs() {
        let track = TrackGeometry::of(
            &[
                Point { x: 0, z: 0 },
                Point { x: 1000, z: 0 },
                Point { x: 1000, z: 1000 },
            ],
            0,
        );
        let p = |x, z| Point { x, z };
        assert_eq!(track.point_extended(500), track.point_at(500));
        assert_eq!(track.point_extended(-300), p(-300, 0), "west of the portal");
        assert_eq!(
            track.point_extended(2500),
            p(1000, 1500),
            "past the far end"
        );
        // At the bend, each direction takes the segment it has come along.
        assert_eq!(track.heading_at(1000, Direction::East), 90);
        assert_eq!(track.heading_at(1000, Direction::West), 0);
        assert_eq!(track.heading_at(1500, Direction::East), 180);
        assert_eq!(track.heading_at(500, Direction::West), 270);
        assert_eq!(track.heading_at(-300, Direction::West), 270);
        assert_eq!(track.heading_at(2500, Direction::East), 180);
        assert_eq!(track.travel_at(1500, Direction::West), (0, -1000));
        assert_eq!(track.segment_length_at(1500, Direction::West), 1000);
    }

    #[test]
    fn offset_polyline_miters_a_right_angle_bend() {
        // East, then turning south: a clean case with no rounding at all,
        // so the exact expected point is worth pinning down too. The old,
        // buggy average-of-perpendiculars join would have landed here at
        // (-50, 50) relative to the vertex (about 71 cm out); the correct
        // miter is (-100, 100) (about 141 cm out, `100 / cos(45°)`).
        let points = [
            Point { x: 0, z: 0 },
            Point { x: 100, z: 0 },
            Point { x: 100, z: 100 },
        ];
        let out = assert_miters_onto_both_lines(&points, 100, 2);
        assert_eq!(out[1], Point { x: 0, z: 100 });
        let disp = (i64::from(out[1].x - 100), i64::from(out[1].z));
        let disp_sq = disp.0 * disp.0 + disp.1 * disp.1;
        assert_eq!(disp_sq, 100 * 100 * 2); // exactly 100 * sqrt(2) out
    }

    #[test]
    fn offset_polyline_miters_a_45_degree_bend() {
        let points = [
            Point { x: 0, z: 0 },
            Point { x: 100, z: 0 },
            Point { x: 200, z: 100 },
        ];
        assert_miters_onto_both_lines(&points, 100, 2);
    }

    #[test]
    fn offset_polyline_leaves_a_straight_line_unchanged() {
        // Three collinear points: the interior vertex is a straight-through
        // join, so every point moves by exactly the same perpendicular.
        let points = [
            Point { x: 0, z: 0 },
            Point { x: 100, z: 0 },
            Point { x: 300, z: 0 },
        ];
        let out = offset_polyline(&points, 100);
        assert_eq!(
            out,
            vec![
                Point { x: 0, z: 100 },
                Point { x: 100, z: 100 },
                Point { x: 300, z: 100 },
            ]
        );
    }

    #[test]
    fn offset_polyline_caps_a_hairpin_bend() {
        // Almost a full reversal: the true miter would be enormous, so the
        // capped displacement should sit at, or very near, 4 * offset from
        // the original vertex.
        let points = [
            Point { x: 0, z: 0 },
            Point { x: 1000, z: 0 },
            Point { x: -1000, z: 10 },
        ];
        let out = offset_polyline(&points, 100);
        let disp = (i64::from(out[1].x - 1000), i64::from(out[1].z));
        let disp_sq = disp.0 * disp.0 + disp.1 * disp.1;
        let cap = 4 * 100i64;
        assert!(
            disp_sq <= cap * cap + 1,
            "displacement {disp:?} exceeds the {cap} cm cap"
        );
        assert!(
            disp_sq >= (cap - 2) * (cap - 2),
            "displacement {disp:?} is far short of the {cap} cm cap"
        );
    }

    #[test]
    fn offset_polyline_falls_back_on_an_exact_reversal() {
        // A segment that doubles straight back on itself: no unique
        // crossing exists, so the vertex takes the incoming segment's own
        // offset point, at exactly one offset's distance from the vertex.
        let points = [
            Point { x: 0, z: 0 },
            Point { x: 100, z: 0 },
            Point { x: 0, z: 0 },
        ];
        let out = offset_polyline(&points, 100);
        assert_eq!(out[1], Point { x: 100, z: 100 });
    }

    #[test]
    fn rejects_line_with_fewer_than_two_points() {
        let mut m = super::fixtures::line_base();
        m.lines[0].points = vec![Point { x: 0, z: 0 }];
        assert!(has(&m, "line-too-short"));
    }

    #[test]
    fn rejects_line_with_a_zero_length_segment() {
        let mut m = super::fixtures::line_base();
        m.lines[0].points = vec![Point { x: 0, z: 0 }, Point { x: 0, z: 0 }];
        assert!(has(&m, "line-zero-length-segment"));
    }

    #[test]
    fn rejects_stop_outside_the_line() {
        let mut m = super::fixtures::line_base();
        m.lines[0].stops[0].at = 5000;
        assert!(has(&m, "stop-outside-line"));
    }

    #[test]
    fn rejects_stops_closer_than_one_vehicle_length() {
        let mut m = super::fixtures::line_base();
        let mut second = m.lines[0].stops[0].clone();
        second.id = "stop:b".into();
        second.at = m.lines[0].stops[0].at + 100; // vehicle length is 400
        m.lines[0].stops.push(second);
        assert!(has(&m, "stops-too-close"));
    }

    #[test]
    fn rejects_a_missing_platform() {
        let mut m = super::fixtures::line_base();
        m.lines[0].stops[0].platforms[0] = "room:nope".into();
        assert!(has(&m, "line-missing-platform"));
    }

    #[test]
    fn rejects_an_indoor_platform() {
        let mut m = super::fixtures::line_base();
        m.lines[0].stops[0].platforms[0] = "room:a".into();
        assert!(has(&m, "line-indoor-platform"));
    }

    #[test]
    fn rejects_a_platform_that_does_not_adjoin_its_track() {
        let mut m = super::fixtures::line_base();
        m.lines[0].stops[0].platforms[0] = "room:s".into();
        assert!(has(&m, "line-platform-not-adjoining"));
    }

    #[test]
    fn rejects_a_track_crossing_an_indoor_room() {
        let mut m = super::fixtures::line_base();
        let blocker: Room = serde_json::from_value(json!({
            "id": "room:blocker", "name": "Blocker", "capacity": 10,
            "rect": {"x": -900, "z": -600, "w": 200, "d": 100}
        }))
        .unwrap();
        m.city.districts[0]
            .facilities
            .last_mut()
            .unwrap()
            .rooms
            .push(blocker);
        assert!(has(&m, "line-crosses-room"));
    }

    #[test]
    fn rejects_non_positive_timetable_and_vehicle_numbers() {
        let mut m = super::fixtures::line_base();
        m.lines[0].timetable.speed = 0;
        assert!(has(&m, "line-non-positive-number"));
        let mut m = super::fixtures::line_base();
        m.lines[0].vehicle.length = -1;
        assert!(has(&m, "line-non-positive-number"), "a negative number");
    }

    #[test]
    fn rejects_dwell_not_under_half_the_headway() {
        let mut m = super::fixtures::line_base();
        m.lines[0].timetable.dwell = 16; // doubled, 32 >= headway 30
        assert!(has(&m, "line-dwell-too-long"));
    }

    #[test]
    fn rejects_zero_capacity() {
        let mut m = super::fixtures::line_base();
        m.lines[0].vehicle.capacity = 0;
        assert!(has(&m, "line-zero-capacity"));
    }

    #[test]
    fn rejects_tracks_closer_than_a_vehicles_width_and_a_step_aside() {
        // Two trams 2.5 m wide pass, and leave between them room for a
        // walker on either track to be stepped off it within one tick,
        // only on tracks 3 m apart or more.
        let mut m = super::fixtures::line_base();
        m.lines[0].tracks = [-150, 150];
        assert!(!has(&m, "line-tracks-too-close"), "a width and 50 cm apart");
        m.lines[0].tracks = [-149, 150];
        assert!(has(&m, "line-tracks-too-close"));
        m.lines[0].tracks = [-125, 125];
        assert!(
            has(&m, "line-tracks-too-close"),
            "only a width apart: the middle rows are out of reach"
        );
        m.lines[0].tracks = [100, 100];
        assert!(has(&m, "line-tracks-too-close"), "one track for both ways");
    }

    #[test]
    fn a_line_runs_a_vehicle_kind_the_catalogue_carries() {
        let mut m = super::fixtures::line_base();
        m.lines[0].vehicle.kind = Some("tram".into());
        assert!(validate(&m).valid, "{:?}", validate(&m).issues);
        for (kind, says) in [
            ("hovercraft", "is not in the catalogue"),
            ("bench", "is not a vehicle"),
        ] {
            m.lines[0].vehicle.kind = Some(kind.into());
            let found: Vec<_> = validate(&m)
                .issues
                .into_iter()
                .filter(|i| i.code == "unknown-vehicle-kind")
                .collect();
            assert_eq!(found.len(), 1, "{kind}");
            assert_eq!(found[0].place.as_deref(), Some("line:boulevard"));
            assert!(found[0].message.contains(kind), "{}", found[0].message);
            assert!(found[0].message.contains(says), "{}", found[0].message);
        }
        // A vehicle kind the catalogue gives no width.
        let line = &super::fixtures::line_base().lines[0];
        let found = vehicle_width_issues(line, Err(crate::transit::VehicleKindError::NoWidth));
        assert_eq!(found.len(), 1);
        assert_eq!(found[0].code, "unknown-vehicle-kind");
        assert!(
            found[0].message.contains("a vehicle kind with no width"),
            "{}",
            found[0].message
        );
    }

    /// `line_base` with one platform's edge `gap` cm from its track: the
    /// east platform north of the eastbound track (z = -550), or the west
    /// platform south of the westbound one (z = -250).
    fn platform_at(east: bool, gap: i32) -> Manifest {
        let mut m = super::fixtures::line_base();
        let transit = m.city.districts[0].facilities.last_mut().unwrap();
        let (k, z) = if east {
            (0, -550 - gap - 90)
        } else {
            (1, -250 + gap)
        };
        transit.rooms[k].rect = Some(Rect {
            x: -200,
            z,
            w: 400,
            d: 90,
        });
        m
    }

    #[test]
    fn a_platform_must_stand_clear_of_its_vehicles() {
        // A tram reaches 125 cm either side of its track; a platform's edge
        // must stand at least the body clearance beyond that, 135 cm.
        for east in [true, false] {
            for (gap, refused) in [(150, false), (135, false), (134, true), (130, true)] {
                let m = platform_at(east, gap);
                let found: Vec<_> = validate(&m)
                    .issues
                    .into_iter()
                    .filter(|i| i.code == "platform-in-vehicle-clearance")
                    .collect();
                assert_eq!(!found.is_empty(), refused, "east {east}, {gap} cm");
                if refused {
                    assert_eq!(found.len(), 1);
                    assert_eq!(found[0].place.as_deref(), Some("stop:a"));
                } else {
                    assert!(validate(&m).valid, "{:?}", validate(&m).issues);
                }
            }
        }
    }

    #[test]
    fn rejects_a_door_outside_the_vehicle() {
        let mut m = super::fixtures::line_base();
        m.lines[0].vehicle.doors = vec![0, 200, 400];
        assert!(!has(&m, "line-door-outside-vehicle"), "at either end");
        m.lines[0].vehicle.doors = vec![-1, 200];
        assert!(has(&m, "line-door-outside-vehicle"), "ahead of its front");
        m.lines[0].vehicle.doors = vec![200, 401];
        assert!(has(&m, "line-door-outside-vehicle"), "behind its rear");
    }
}

/// Small manifests shared by unit tests across the crate.
#[cfg(test)]
pub(crate) mod fixtures {
    use city_contracts::Manifest;
    use serde_json::json;

    /// `layout_base` with open ground: `room:w`, a street west of the hall
    /// and the plaza, and `room:s`, a street east of the plaza with a house
    /// standing on it. Neither has a door; outdoor rooms join along their
    /// shared edges.
    pub(crate) fn layout_streets() -> Manifest {
        let mut m = layout_base();
        let streets: Vec<city_contracts::Room> = serde_json::from_value(json!([
            {"id": "room:s", "name": "East street", "capacity": 50, "template": "ground", "outdoor": true,
             "rect": {"x": 800, "z": 0, "w": 800, "d": 800}},
            {"id": "room:w", "name": "West street", "capacity": 50, "template": "ground", "outdoor": true,
             "rect": {"x": -800, "z": 0, "w": 800, "d": 800}}
        ]))
        .unwrap();
        m.city.districts[0].facilities.push(
            serde_json::from_value(
                json!({"id": "facility:streets", "name": "Streets", "rooms": streets}),
            )
            .unwrap(),
        );
        // The house: a 2 m block on the architecture snap, at x 1100–1300,
        // z 100–300. (Schema 1 carved it out of the street as an obstacle a
        // metre further east, off the snap.)
        m.city.districts[0].placements.push(
            serde_json::from_value(json!({"id": "placement:house", "kind": "block-house",
                "at": {"x": 1200, "z": 200}, "size": {"w": 200, "d": 200}}))
            .unwrap(),
        );
        m
    }

    /// `layout_streets` with `line:boulevard`: a straight east–west line
    /// north of every existing room (negative z, so nothing overlaps),
    /// centreline at z = -400, tracks at z = -550 (eastbound) and z = -250
    /// (westbound), one stop at the midpoint (x = 0) with an outdoor
    /// platform 150 cm off each track.
    pub(crate) fn line_base() -> Manifest {
        use city_contracts::{Line, LineMode, Point, Stop, Timetable, VehicleSpec};

        let mut m = layout_streets();
        let platforms: Vec<city_contracts::Room> = serde_json::from_value(json!([
            {"id": "room:platform-e", "name": "Platform east", "capacity": 20,
             "template": "ground", "outdoor": true,
             "rect": {"x": -200, "z": -790, "w": 400, "d": 90}},
            {"id": "room:platform-w", "name": "Platform west", "capacity": 20,
             "template": "ground", "outdoor": true,
             "rect": {"x": -200, "z": -100, "w": 400, "d": 90}}
        ]))
        .unwrap();
        m.city.districts[0]
            .facilities
            .push(city_contracts::Facility {
                id: "facility:transit".into(),
                name: "Transit".into(),
                rooms: platforms,
                ..Default::default()
            });
        m.lines.push(Line {
            id: "line:boulevard".into(),
            name: "Boulevard tram".into(),
            mode: LineMode::Tram,
            points: vec![Point { x: -1000, z: -400 }, Point { x: 1000, z: -400 }],
            tracks: [-150, 150],
            stops: vec![Stop {
                id: "stop:a".into(),
                name: "A".into(),
                at: 1000,
                platforms: ["room:platform-e".into(), "room:platform-w".into()],
            }],
            timetable: Timetable {
                headway: 30,
                offset: [0, 15],
                speed: 28,
                dwell: 12,
            },
            vehicle: VehicleSpec {
                capacity: 40,
                length: 400,
                doors: vec![80, 200, 320],
                kind: None,
            },
        });
        m
    }

    /// A tram street between two platforms, 40 m long. `room:north`
    /// (z 0–150) is the eastbound platform and `room:south` (z 750–950) the
    /// westbound one; `room:street` (z 150–750) carries the tracks, the
    /// eastbound at z = 300 and the westbound at z = 600, each 150 cm from
    /// its platform's edge, so a 2.5 m tram clears it by 25 cm. One stop,
    /// `stop:mid`, stands at 20 m. The only entrance is on the north
    /// platform's west edge, so no one needs to cross the tracks.
    pub(crate) fn tram_street() -> Manifest {
        serde_json::from_value(json!({
            "schema_version": 2,
            "catalogue": 1,
            "clock": {"ticks_per_day": 600, "start_minute": 420},
            "city": {"id": "city:t", "name": "T", "entrances": [{"x": 0, "z": 100}], "districts": [
                {"id": "district:t", "name": "T", "facilities": [
                    {"id": "facility:ground", "name": "Ground", "rooms": [
                        {"id": "room:north", "name": "North platform", "capacity": 50,
                         "template": "ground", "outdoor": true,
                         "rect": {"x": 0, "z": 0, "w": 4000, "d": 150}},
                        {"id": "room:street", "name": "Tram street", "capacity": 50,
                         "template": "ground", "outdoor": true,
                         "rect": {"x": 0, "z": 150, "w": 4000, "d": 600}},
                        {"id": "room:south", "name": "South platform", "capacity": 50,
                         "template": "ground", "outdoor": true,
                         "rect": {"x": 0, "z": 750, "w": 4000, "d": 200}}
                    ]}
                ]}
            ]},
            "lines": [{
                "id": "line:boulevard", "name": "Boulevard tram", "mode": "tram",
                "points": [{"x": 0, "z": 450}, {"x": 4000, "z": 450}],
                "tracks": [-150, 150],
                "stops": [{"id": "stop:mid", "name": "Mid", "at": 2000,
                           "platforms": ["room:north", "room:south"]}],
                "timetable": {"headway": 30, "offset": [0, 15], "speed": 28, "dwell": 12},
                "vehicle": {"capacity": 40, "length": 1200, "doors": [200, 600, 1000]}
            }]
        }))
        .expect("the tram street parses")
    }

    /// A tram street 60 m long with three stops, for boarding and alighting.
    /// The tracks run at z = 300 (eastbound) and z = 600 (westbound) along
    /// `room:street` (z 150–750); `room:south` (z 750–950) is every stop's
    /// westbound platform. The eastbound platforms are separate rooms north
    /// of the street, 150 deep: `room:north-a` (x 0–2400) for `stop:a` at
    /// 10 m, `room:north-c` (x 3600–6000) for `stop:c` at 50 m, and, for
    /// `stop:b` at 30 m, `room:tiny`, 2 m by 50 cm (16 cells) beside the
    /// front door of an eastbound tram standing there. Every platform's
    /// edge is 150 cm from its track. The only entrance is on
    /// `room:north-a`'s west edge.
    pub(crate) fn tram_three_stops() -> Manifest {
        serde_json::from_value(json!({
            "schema_version": 2,
            "catalogue": 1,
            "clock": {"ticks_per_day": 600, "start_minute": 420},
            "city": {"id": "city:t", "name": "T", "entrances": [{"x": 0, "z": 100}], "districts": [
                {"id": "district:t", "name": "T", "facilities": [
                    {"id": "facility:ground", "name": "Ground", "rooms": [
                        {"id": "room:north-a", "name": "A platform", "capacity": 50,
                         "template": "ground", "outdoor": true,
                         "rect": {"x": 0, "z": 0, "w": 2400, "d": 150}},
                        {"id": "room:tiny", "name": "B platform", "capacity": 50,
                         "template": "ground", "outdoor": true,
                         "rect": {"x": 3300, "z": 100, "w": 200, "d": 50}},
                        {"id": "room:north-c", "name": "C platform", "capacity": 50,
                         "template": "ground", "outdoor": true,
                         "rect": {"x": 3600, "z": 0, "w": 2400, "d": 150}},
                        {"id": "room:street", "name": "Tram street", "capacity": 50,
                         "template": "ground", "outdoor": true,
                         "rect": {"x": 0, "z": 150, "w": 6000, "d": 600}},
                        {"id": "room:south", "name": "South platform", "capacity": 50,
                         "template": "ground", "outdoor": true,
                         "rect": {"x": 0, "z": 750, "w": 6000, "d": 200}}
                    ]}
                ]}
            ]},
            "lines": [{
                "id": "line:boulevard", "name": "Boulevard tram", "mode": "tram",
                "points": [{"x": 0, "z": 450}, {"x": 6000, "z": 450}],
                "tracks": [-150, 150],
                "stops": [
                    {"id": "stop:a", "name": "A", "at": 1000,
                     "platforms": ["room:north-a", "room:south"]},
                    {"id": "stop:b", "name": "B", "at": 3000,
                     "platforms": ["room:tiny", "room:south"]},
                    {"id": "stop:c", "name": "C", "at": 5000,
                     "platforms": ["room:north-c", "room:south"]}
                ],
                "timetable": {"headway": 30, "offset": [0, 15], "speed": 28, "dwell": 12},
                "vehicle": {"capacity": 40, "length": 1200, "doors": [200, 600, 1000]}
            }]
        }))
        .expect("the three-stop street parses")
    }

    /// `tram_three_stops` with `arrivals: "tram"`, and `room:shop`, an open
    /// yard (x 4400–5200, z -400–0) just north of the C platform, for
    /// arrivals to be bound for.
    pub(crate) fn tram_arrivals() -> Manifest {
        let mut m = tram_three_stops();
        m.city.arrivals = city_contracts::Arrivals::Tram;
        let shop: city_contracts::Room = serde_json::from_value(json!(
            {"id": "room:shop", "name": "Shop", "capacity": 20,
             "template": "ground", "outdoor": true,
             "rect": {"x": 4400, "z": -400, "w": 800, "d": 400}}
        ))
        .unwrap();
        m.city.districts[0].facilities[0].rooms.push(shop);
        m
    }

    /// `room:a` (a 4 × 4 m workshop) above `room:p` (an 8 × 4 m plaza), with a
    /// door both ways at (200, 400) and one entrance on the plaza's west edge.
    /// Seat a1's desk stands where schema 1 put an obstacle of its size.
    pub(crate) fn layout_base() -> Manifest {
        serde_json::from_value(json!({
            "schema_version": 2,
            "catalogue": 1,
            "clock": {"ticks_per_day": 600, "start_minute": 420},
            "city": {"id": "city:l", "name": "L", "entrances": [{"x": 0, "z": 600}], "districts": [
                {"id": "district:l", "name": "L", "facilities": [
                    {"id": "facility:hall", "name": "Hall", "rooms": [
                        {"id": "room:a", "name": "A", "capacity": 2, "template": "workshop",
                         "rect": {"x": 0, "z": 0, "w": 400, "d": 400},
                         "seats": [{"id": "seat:a1", "pos": {"x": 100, "z": 100}, "facing": 0, "kind": "desk"}],
                         "doors": [{"id": "door:a-p", "to": "room:p", "pos": {"x": 200, "z": 400},
                                    "transit": {"min": 1, "max": 1}}]}
                    ]},
                    {"id": "facility:plaza", "name": "Plaza", "rooms": [
                        {"id": "room:p", "name": "P", "capacity": 20, "template": "plaza",
                         "rect": {"x": 0, "z": 400, "w": 800, "d": 400},
                         "doors": [{"id": "door:p-a", "to": "room:a", "pos": {"x": 200, "z": 400},
                                    "transit": {"min": 1, "max": 1}}]}
                    ]}
                ]}
            ]}
        }))
        .unwrap()
    }
}
