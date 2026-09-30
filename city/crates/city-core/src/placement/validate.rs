//! Checking placements: every authored one at load, and each runtime one
//! through [`validate_one`], against the grid's geometry and the
//! placements filed [`Nearby`].

use super::*;

/// The side of a bucket in [`Nearby`] (cm).
const BUCKET: i64 = 800;
/// The most buckets one placement's footprint is filed under; a larger one
/// is checked against every new placement instead.
const MOST_BUCKETS: i64 = 4096;

/// Where the accepted placements stand, filed in square buckets, so a new
/// placement is checked only against the few whose footprint could cover
/// its anchors, or whose anchors it could cover, not against them all.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Nearby {
    /// The placements whose footprint's bounds, with the clearance, touch
    /// each bucket.
    solids: BTreeMap<(i64, i64), BTreeSet<PlaceId>>,
    /// Placements too large to file, checked against everything.
    large: BTreeSet<PlaceId>,
    /// The placements with a standing anchor in each bucket.
    anchors: BTreeMap<(i64, i64), BTreeSet<PlaceId>>,
}

/// The buckets a box `(x0, z0, x1, z1)` touches, or none when there are more
/// than [`MOST_BUCKETS`].
fn buckets((x0, z0, x1, z1): (i64, i64, i64, i64)) -> Option<Vec<(i64, i64)>> {
    let (bx0, bx1) = (x0.div_euclid(BUCKET), x1.div_euclid(BUCKET));
    let (bz0, bz1) = (z0.div_euclid(BUCKET), z1.div_euclid(BUCKET));
    ((bx1 - bx0 + 1) * (bz1 - bz0 + 1) <= MOST_BUCKETS).then(|| {
        (bz0..=bz1)
            .flat_map(|z| (bx0..=bx1).map(move |x| (x, z)))
            .collect()
    })
}

fn bucket_of(p: Point) -> (i64, i64) {
    (
        i64::from(p.x).div_euclid(BUCKET),
        i64::from(p.z).div_euclid(BUCKET),
    )
}

impl Nearby {
    /// Files `p`.
    pub fn add(&mut self, p: &PlacedInfo) {
        match buckets(footprint::bounds_wide(&p.placed, MARGIN)) {
            Some(keys) => {
                for key in keys {
                    self.solids.entry(key).or_default().insert(p.id.clone());
                }
            }
            None => {
                self.large.insert(p.id.clone());
            }
        }
        for (at, _) in anchor_points(p) {
            self.anchors
                .entry(bucket_of(at))
                .or_default()
                .insert(p.id.clone());
        }
    }

    /// Unfiles `p`, filed as it stands.
    pub fn remove(&mut self, p: &PlacedInfo) {
        let drop = |map: &mut BTreeMap<(i64, i64), BTreeSet<PlaceId>>, key| {
            if let Some(ids) = map.get_mut(&key) {
                ids.remove(&p.id);
                if ids.is_empty() {
                    map.remove(&key);
                }
            }
        };
        match buckets(footprint::bounds_wide(&p.placed, MARGIN)) {
            Some(keys) => keys.into_iter().for_each(|k| drop(&mut self.solids, k)),
            None => {
                self.large.remove(&p.id);
            }
        }
        for (at, _) in anchor_points(p) {
            drop(&mut self.anchors, bucket_of(at));
        }
    }

    /// The placements whose footprint might cover `p`.
    fn solids_at(&self, p: Point) -> impl Iterator<Item = &PlaceId> {
        self.solids
            .get(&bucket_of(p))
            .into_iter()
            .flatten()
            .chain(&self.large)
    }

    /// The placements whose footprint might reach into the box.
    pub fn solids_within(&self, (x0, z0, x1, z1): (i64, i64, i64, i64)) -> BTreeSet<&PlaceId> {
        let (bx0, bx1) = (x0.div_euclid(BUCKET), x1.div_euclid(BUCKET));
        let (bz0, bz1) = (z0.div_euclid(BUCKET), z1.div_euclid(BUCKET));
        if (bx1 - bx0 + 1) * (bz1 - bz0 + 1) > MOST_BUCKETS {
            return self.solids.values().flatten().chain(&self.large).collect();
        }
        (bz0..=bz1)
            .flat_map(|z| (bx0..=bx1).map(move |x| (x, z)))
            .filter_map(|key| self.solids.get(&key))
            .flatten()
            .chain(&self.large)
            .collect()
    }

    /// The placements with a standing anchor within the box.
    fn anchors_within(&self, (x0, z0, x1, z1): (i64, i64, i64, i64)) -> BTreeSet<&PlaceId> {
        let (bx0, bx1) = (x0.div_euclid(BUCKET), x1.div_euclid(BUCKET));
        let (bz0, bz1) = (z0.div_euclid(BUCKET), z1.div_euclid(BUCKET));
        if (bx1 - bx0 + 1) * (bz1 - bz0 + 1) > MOST_BUCKETS {
            return self.anchors.values().flatten().collect();
        }
        (bz0..=bz1)
            .flat_map(|z| (bx0..=bx1).map(move |x| (x, z)))
            .filter_map(|key| self.anchors.get(&key))
            .flatten()
            .collect()
    }
}

/// Checks the placements and building kinds of `m` against `cat`, and
/// records the accepted ones in `index`. The geometric checks run only on an
/// otherwise valid layout, since they need its grid.
pub fn validate(
    m: &Manifest,
    cat: &'static Catalogue,
    index: &mut PlaceIndex,
    out: &mut Vec<ValidationIssue>,
) {
    let clean = out.is_empty();
    match m.catalogue {
        Some(version) if version != cat.version => out.push(issue(
            "catalogue-version",
            &m.city.id,
            format!(
                "The manifest names catalogue {version}, but this core carries catalogue {}.",
                cat.version
            ),
        )),
        // A schema 1 manifest is refused for its version alone.
        None if m.schema_version == MANIFEST_SCHEMA_VERSION => out.push(issue(
            "catalogue-version",
            &m.city.id,
            format!(
                "The manifest names no catalogue; schema {MANIFEST_SCHEMA_VERSION} names the one \
                 it was written against, and this core carries catalogue {}.",
                cat.version
            ),
        )),
        _ => {}
    }
    let laid_out: Vec<&PlaceId> = m
        .city
        .districts
        .iter()
        .filter(|d| {
            d.facilities
                .iter()
                .flat_map(|f| &f.rooms)
                .any(|r| r.rect.is_some())
        })
        .map(|d| &d.id)
        .collect();
    if let [first, second, ..] = laid_out[..] {
        out.push(issue(
            "one-district-layout",
            second,
            format!(
                "Districts {first} and {second} both have a layout; only one district may be laid out."
            ),
        ));
    }
    for r in m
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .flat_map(|f| &f.rooms)
        .filter(|r| r.level != 0)
    {
        out.push(issue("level-not-supported", &r.id, LEVEL_MESSAGE.into()));
    }
    door_width_issues(index, out);
    index.buildings = buildings(m, cat, out);

    let mut placements: Vec<(&PlaceId, &Placement)> = m
        .city
        .districts
        .iter()
        .flat_map(|d| d.placements.iter().map(move |p| (&d.id, p)))
        .collect();
    placements.sort_by(|a, b| a.1.id.cmp(&b.1.id));
    let furniture = seat_furniture(index);
    // A layout with nothing placed, no building kind and no furnished seat
    // has nothing to check against the grid, so it is spared building it.
    let carved = !(placements.is_empty() && index.buildings.is_empty() && furniture.is_empty());
    let mut grid =
        (clean && out.is_empty() && index.layout && carved).then(|| NavGrid::floor(index));
    let tracks = grid
        .as_ref()
        .map(|g| crate::transit::track_cells(index, g))
        .unwrap_or_default();
    let floor = grid.as_ref().map(|grid| Floor {
        grid,
        tracks: &tracks,
    });
    if let Some(floor) = &floor {
        for building in &index.buildings {
            shell_issues(index, floor, building, out);
        }
    }
    for (district, seat) in furniture {
        if !cat.kind(&seat.kind).is_some_and(|k| k.class == Class::Seat) {
            out.push(issue(
                "unknown-kind",
                &seat.id,
                format!(
                    "Seat {} names {}, which is not a seat kind in catalogue {}.",
                    seat.id, seat.kind, cat.version
                ),
            ));
            continue;
        }
        if let Some(info) = validate_one(index, floor.as_ref(), cat, &district, &seat, out) {
            index.nearby.add(&info);
            index.seat_furniture.push(info);
        }
    }
    for (district, p) in placements {
        if let Some(bad) = placement_id_issue(&p.id) {
            out.push(bad);
            continue;
        }
        if let Some(info) = validate_one(index, floor.as_ref(), cat, district, p, out) {
            index.add_placement(info);
        }
    }
    // The floor's checks are done: carve it into the grid itself.
    if let Some(grid) = &mut grid
        && out.is_empty()
    {
        grid.carve(index);
        grid_issues(index, grid, out);
    }
}

/// Every seat with a position and a kind, as a placement of its furniture
/// at the seat's point and facing, with its room's district, in seat ID
/// order. A seat that names one of its furniture's anchors belongs to a
/// placement of that furniture instead, which carves it.
fn seat_furniture(index: &PlaceIndex) -> Vec<(PlaceId, Placement)> {
    let mut found: Vec<(PlaceId, Placement)> = index
        .rooms
        .values()
        .filter(|r| r.rect.is_some())
        .flat_map(|r| r.seats.iter().map(move |s| (r, s)))
        .filter(|(_, s)| s.anchor.is_none())
        .filter_map(|(r, s)| {
            Some((
                r.district.clone(),
                Placement {
                    id: s.id.clone(),
                    kind: s.kind.clone()?,
                    at: s.pos?,
                    facing: s.facing,
                    level: r.level,
                    ..Default::default()
                },
            ))
        })
        .collect();
    found.sort_by(|a, b| a.1.id.cmp(&b.1.id));
    found
}

/// A door's width must be positive, and the two records of one doorway (a
/// door each way, at one point) may not give it different widths.
fn door_width_issues(index: &PlaceIndex, out: &mut Vec<ValidationIssue>) {
    for room in index.rooms.values() {
        for door in &room.door_list {
            let Some(width) = door.width else { continue };
            if width <= 0 {
                out.push(issue(
                    "bad-door-width",
                    &door.id,
                    format!("Door {} needs a positive width, not {width}.", door.id),
                ));
            }
            let Some(other) = index.rooms.get(&door.to) else {
                continue;
            };
            for back in &other.door_list {
                if back.to == room.id
                    && back.pos == door.pos
                    && door.id < back.id
                    && back.width.is_some_and(|w| w != width)
                {
                    out.push(issue(
                        "bad-door-width",
                        &door.id,
                        format!(
                            "Doors {} and {} are one doorway but give it different widths.",
                            door.id, back.id
                        ),
                    ));
                }
            }
        }
    }
}

/// A building's shell may not cover a track cell or the span of a door
/// that is not its own.
fn shell_issues(
    index: &PlaceIndex,
    floor: &Floor<'_>,
    building: &BuildingInfo,
    out: &mut Vec<ValidationIssue>,
) {
    let shell = shell(index, building);
    let grid = floor.grid;
    let (mut door, mut track) = (false, false);
    for c in grid.cells_under(&shell, MARGIN) {
        let foreign = grid
            .span_rooms(c)
            .iter()
            .any(|rooms| !rooms.iter().any(|r| building.rooms.contains(r)));
        let on_track = floor.tracks.contains(&c);
        if (foreign || on_track) && footprint::covers(&shell, grid.centre(c), MARGIN) {
            door |= foreign;
            track |= on_track;
        }
    }
    let id = &building.facility;
    if door {
        out.push(issue(
            "placement-covers-door",
            id,
            format!("The shell of {id} covers the span of a door not its own."),
        ));
    }
    if track {
        out.push(issue(
            "placement-covers-track",
            id,
            format!("The shell of {id} covers a tram track."),
        ));
    }
}

/// The facilities with a building kind, in facility ID order. A kind the
/// catalogue lacks, or one that is not a building, is refused.
fn buildings(
    m: &Manifest,
    cat: &'static Catalogue,
    out: &mut Vec<ValidationIssue>,
) -> Vec<BuildingInfo> {
    let mut found = Vec::new();
    for f in m.city.districts.iter().flat_map(|d| &d.facilities) {
        let Some(id) = &f.kind else { continue };
        match cat.kind(id) {
            Some(kind) if kind.class == Class::Building => found.push(BuildingInfo {
                facility: f.id.clone(),
                kind,
                rooms: f.rooms.iter().map(|r| r.id.clone()).collect(),
                wall: kind.wall.unwrap_or(DEFAULT_WALL),
                door_width: kind.door_width.unwrap_or(DEFAULT_DOOR_WIDTH),
            }),
            _ => out.push(issue(
                "unknown-kind",
                &f.id,
                format!(
                    "Facility {} names {id}, which is not a building kind in catalogue {}.",
                    f.id, cat.version
                ),
            )),
        }
    }
    found.sort_by(|a, b| a.facility.cmp(&b.facility));
    found
}

/// Checks one placement in `district` against the index as it stands (its
/// rooms, seats, doors, tracks and the placements already accepted) and,
/// when `floor` is given, against the floor's geometry. Returns the
/// placement ready to add when it raised no issue.
pub fn validate_one(
    index: &PlaceIndex,
    floor: Option<&Floor<'_>>,
    cat: &'static Catalogue,
    district: &PlaceId,
    p: &Placement,
    out: &mut Vec<ValidationIssue>,
) -> Option<PlacedInfo> {
    let before = out.len();
    let Some(kind) = cat.kind(&p.kind) else {
        out.push(issue(
            "unknown-kind",
            &p.id,
            format!(
                "Placement {} names {}, which catalogue {} does not carry.",
                p.id, p.kind, cat.version
            ),
        ));
        return None;
    };
    if p.level != 0 {
        out.push(issue("level-not-supported", &p.id, LEVEL_MESSAGE.into()));
    }
    let snap = kind.snap.max(1);
    if p.at.x.rem_euclid(snap) != 0 || p.at.z.rem_euclid(snap) != 0 {
        out.push(issue(
            "off-snap",
            &p.id,
            format!(
                "Placement {} at ({}, {}) is off the {snap} cm snap of {}.",
                p.id, p.at.x, p.at.z, kind.id
            ),
        ));
    }
    let shapes = match (kind.sized, p.size) {
        // Soft ground (a meadow): its size is where its soft shapes grow,
        // and soft shapes never block walking.
        (true, Some(size)) if size.w > 0 && size.d > 0 && kind.sized_soft() => Vec::new(),
        (true, Some(size)) if size.w > 0 && size.d > 0 => vec![Shape::Rect {
            x: -size.w / 2,
            z: -size.d / 2,
            w: size.w,
            d: size.d,
        }],
        (true, _) => {
            out.push(issue(
                "size-missing",
                &p.id,
                format!(
                    "Placement {} is a {}, which needs a positive size.",
                    p.id, kind.id
                ),
            ));
            Vec::new()
        }
        (false, Some(_)) => {
            out.push(issue(
                "size-not-allowed",
                &p.id,
                format!(
                    "Placement {} gives a size, but {} has a fixed footprint.",
                    p.id, kind.id
                ),
            ));
            kind.footprint.clone()
        }
        (false, None) => kind.footprint.clone(),
    };
    for (name, value) in &p.state {
        let fits = kind
            .state
            .iter()
            .find(|f| &f.name == name)
            .map(|f| match f.ty {
                StateType::Bool => value.is_boolean(),
                StateType::Int => value.as_i64().is_some(),
                StateType::Text | StateType::Ref => value.is_string(),
            });
        match fits {
            None => out.push(issue(
                "bad-state",
                &p.id,
                format!(
                    "Placement {} sets {name}, which {} does not declare.",
                    p.id, kind.id
                ),
            )),
            Some(false) => out.push(issue(
                "bad-state",
                &p.id,
                format!(
                    "Placement {} sets {name} to {value}, which is not its declared type.",
                    p.id
                ),
            )),
            Some(true) => {}
        }
    }
    if let Some(binding) = &p.binding {
        if !kind.anchors.iter().any(|a| a.kind == AnchorType::Display) {
            out.push(issue(
                "bad-binding",
                &p.id,
                format!(
                    "Placement {} is bound, but {} has no display to show a record on.",
                    p.id, kind.id
                ),
            ));
        } else if binding.source.is_empty() || binding.reference.is_empty() {
            out.push(issue(
                "bad-binding",
                &p.id,
                format!("Placement {} needs a binding source and ref.", p.id),
            ));
        }
    }
    let placed = Placed {
        shapes,
        at: p.at,
        facing: p.facing,
    };
    let laid_out = index
        .rooms
        .values()
        .any(|r| r.rect.is_some() && &r.district == district);
    if let Some(floor) = floor
        && p.level == 0
        && laid_out
    {
        // Content off every room is still the world, and simply touches no
        // cell; only a point so far off that the cell arithmetic could
        // overflow is refused.
        let origin = floor.grid.extent();
        let far = |v: i32, o: i32| (i64::from(v) - i64::from(o)).abs() > MAX_REACH;
        if far(p.at.x, origin.x) || far(p.at.z, origin.z) {
            out.push(issue(
                "placement-off-grid",
                &p.id,
                format!(
                    "Placement {} at ({}, {}) lies more than {} km from the district's grid.",
                    p.id,
                    p.at.x,
                    p.at.z,
                    MAX_REACH / 100_000
                ),
            ));
        } else {
            cover_issues(index, floor, district, &p.id, kind, &placed, out);
        }
    }
    (out.len() == before).then(|| PlacedInfo {
        id: p.id.clone(),
        kind,
        placed,
        level: p.level,
        district: district.clone(),
        record: p.clone(),
    })
}

/// Whether the seat in `cell` is this seat-class placement's own: one of its
/// `sit` anchors lies in that cell, so its furniture may surround it.
fn own_seat(kind: &Kind, placed: &Placed, grid: &NavGrid, cell: Cell) -> bool {
    kind.class == Class::Seat
        && kind.anchors.iter().any(|a| {
            a.kind == AnchorType::Sit
                && grid.cell_of(footprint::world_point(placed.at, placed.facing, a.at)) == cell
        })
}

/// The footprint of a placement must leave clear every seat cell (but its
/// own), door span, track cell and other placement's anchor, and no other
/// placement may cover one of its anchors.
fn cover_issues(
    index: &PlaceIndex,
    floor: &Floor<'_>,
    district: &PlaceId,
    id: &PlaceId,
    kind: &Kind,
    placed: &Placed,
    out: &mut Vec<ValidationIssue>,
) {
    let grid = floor.grid;
    let covered = |by: &Placed, c: Cell| footprint::covers(by, grid.centre(c), MARGIN);
    for room in index
        .rooms
        .values()
        .filter(|r| r.rect.is_some() && r.level == 0)
    {
        for seat in &room.seats {
            let Some(pos) = seat.pos else { continue };
            let cell = grid.cell_of(pos);
            if covered(placed, cell) && !own_seat(kind, placed, grid, cell) {
                out.push(issue(
                    "placement-covers-seat",
                    id,
                    format!("Placement {id} covers seat {}.", seat.id),
                ));
            }
        }
    }
    let (mut door, mut track) = (false, false);
    for c in grid.cells_under(placed, MARGIN) {
        let (in_door, in_track) = (grid.in_door_span(c), floor.tracks.contains(&c));
        if (in_door || in_track) && covered(placed, c) {
            door |= in_door;
            track |= in_track;
        }
    }
    if door {
        out.push(issue(
            "placement-covers-door",
            id,
            format!("Placement {id} covers a door's span."),
        ));
    }
    if track {
        out.push(issue(
            "placement-covers-track",
            id,
            format!("Placement {id} covers a tram track."),
        ));
    }
    let anchor_cell =
        |p: &Placed, a: &Anchor| grid.cell_of(footprint::world_point(p.at, p.facing, a.at));
    // Only neighbours can meet: those with an anchor within this
    // footprint's reach (an anchor's cell centre lies within a cell of the
    // anchor), and those whose footprint reaches one of its anchors.
    let (x0, z0, x1, z1) = footprint::bounds_wide(placed, MARGIN);
    let cell = i64::from(CELL);
    let mut near: BTreeSet<&PlaceId> =
        index
            .nearby
            .anchors_within((x0 - cell, z0 - cell, x1 + cell, z1 + cell));
    for a in standing_anchors(kind) {
        near.extend(index.nearby.solids_at(grid.centre(anchor_cell(placed, a))));
    }
    let mut others: Vec<&PlacedInfo> = near
        .into_iter()
        .filter_map(|other| index.placed(other))
        .collect();
    // Placements before seat furniture, each in ID order, as ever.
    others.sort_by_key(|o| {
        (
            index
                .seat_furniture
                .binary_search_by(|f| f.id.cmp(&o.id))
                .is_ok(),
            &o.id,
        )
    });
    for other in others
        .into_iter()
        .filter(|o| &o.district == district && o.level == 0 && &o.id != id)
    {
        for a in standing_anchors(other.kind) {
            if covered(placed, anchor_cell(&other.placed, a)) {
                out.push(issue(
                    "placement-covers-anchor",
                    id,
                    format!(
                        "Placement {id} covers the {} anchor of {}.",
                        anchor_name(a.kind),
                        other.id
                    ),
                ));
            }
        }
        for a in standing_anchors(kind) {
            if covered(&other.placed, anchor_cell(placed, a)) {
                out.push(issue(
                    "placement-covers-anchor",
                    id,
                    format!(
                        "Placement {} covers the {} anchor of {id}.",
                        other.id,
                        anchor_name(a.kind)
                    ),
                ));
            }
        }
    }
}

/// Checks the finished grid: every placement's standing anchors are
/// reachable from the district's entrances, and no room a footprint ate
/// into keeps fewer cells than it has seats or places.
pub fn grid_issues(index: &PlaceIndex, grid: &NavGrid, out: &mut Vec<ValidationIssue>) {
    let reach = Reach::of(index, grid);
    let district = index
        .rooms
        .values()
        .find(|r| r.rect.is_some())
        .map(|r| &r.district);
    for p in index
        .placements
        .iter()
        .chain(&index.seat_furniture)
        .filter(|p| p.level == 0 && Some(&p.district) == district)
    {
        for a in standing_anchors(p.kind) {
            let at = footprint::world_point(p.placed.at, p.placed.facing, a.at);
            let cell = grid.cell_of(at);
            let reached = grid.walkable(cell) && reach.reaches(grid, cell);
            if !reached {
                out.push(issue(
                    "anchor-unreachable",
                    &p.id,
                    format!(
                        "The {} anchor of {} at ({}, {}) cannot be reached from the district's entrances.",
                        anchor_name(a.kind),
                        p.id,
                        at.x,
                        at.z
                    ),
                ));
            }
        }
    }
    let before = grid.floor_cell_counts();
    let after = grid.room_cell_counts();
    for room in index.rooms.values().filter(|r| r.rect.is_some()) {
        let had = before.get(&room.id).copied().unwrap_or(0);
        let kept = after.get(&room.id).copied().unwrap_or(0);
        let needed = room.seats.len().max(room.capacity as usize);
        if kept < had && kept < needed {
            out.push(issue(
                "room-too-small",
                &room.id,
                format!(
                    "Room {} keeps {kept} walkable cells, fewer than its {needed} seats and places.",
                    room.id
                ),
            ));
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::index::fixtures::layout_base;
    use crate::validate as validate_manifest;
    use city_contracts::{District, Room};
    use serde_json::json;

    fn with(mut m: Manifest, placements: serde_json::Value) -> Manifest {
        m.city.districts[0].placements = serde_json::from_value(placements).unwrap();
        m
    }

    fn issues(m: &Manifest) -> Vec<ValidationIssue> {
        validate_manifest(m).issues
    }

    fn codes(m: &Manifest) -> Vec<String> {
        issues(m).into_iter().map(|i| i.code).collect()
    }

    fn has(m: &Manifest, code: &str) -> bool {
        codes(m).iter().any(|c| c == code)
    }

    fn room<'a>(m: &'a mut Manifest, id: &str) -> &'a mut Room {
        m.city
            .districts
            .iter_mut()
            .flat_map(|d| d.facilities.iter_mut())
            .flat_map(|f| f.rooms.iter_mut())
            .find(|r| r.id.as_str() == id)
            .unwrap()
    }

    #[test]
    fn accepted_placements_are_indexed_in_id_order() {
        let m = with(
            layout_base(),
            json!([
                {"id": "placement:lamp-b", "kind": "street-lamp", "at": {"x": 600, "z": 700}},
                {"id": "placement:lamp-a", "kind": "street-lamp", "at": {"x": 500, "z": 700}, "state": {"lit": false}}
            ]),
        );
        let index = PlaceIndex::build(&m).unwrap();
        let ids: Vec<&str> = index.placements.iter().map(|p| p.id.as_str()).collect();
        assert_eq!(ids, ["placement:lamp-a", "placement:lamp-b"]);
        let a = &index.placements[0];
        assert_eq!(a.kind.id, "street-lamp");
        assert_eq!(a.placed.at, Point { x: 500, z: 700 });
        assert_eq!(a.district.as_str(), "district:l");
    }

    #[test]
    fn an_unknown_kind_is_refused() {
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "spaceship", "at": {"x": 500, "z": 700}}]),
        );
        assert!(has(&m, "unknown-kind"));
        let mut m = layout_base();
        m.city.districts[0].facilities[0].kind = Some("desk".into());
        assert!(
            has(&m, "unknown-kind"),
            "a facility's kind must be a building"
        );
        m.city.districts[0].facilities[0].kind = Some("guild-hall".into());
        assert!(validate_manifest(&m).valid);
        // A seat's kind must be a seat kind.
        let mut m = layout_base();
        assert!(validate_manifest(&m).valid);
        room(&mut m, "room:a").seats[0].kind = Some("planter".into());
        let found = issues(&m);
        assert!(
            found
                .iter()
                .any(|i| i.code == "unknown-kind" && i.place.as_deref() == Some("seat:a1")),
            "{found:?}"
        );
    }

    #[test]
    fn only_the_ground_level_is_accepted() {
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "bollard", "at": {"x": 500, "z": 700}, "level": 1}]),
        );
        let found = issues(&m);
        let level = found
            .iter()
            .find(|i| i.code == "level-not-supported")
            .unwrap();
        assert_eq!(level.message, LEVEL_MESSAGE);
        assert_eq!(
            level.message,
            "levels above the ground arrive with rooftops"
        );
        assert_eq!(level.place.as_deref(), Some("placement:x"));
        let mut m = layout_base();
        room(&mut m, "room:p").level = -1;
        assert!(has(&m, "level-not-supported"), "rooms too");
    }

    #[test]
    fn a_point_off_the_kind_snap_is_refused() {
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "bollard", "at": {"x": 510, "z": 700}}]),
        );
        assert!(has(&m, "off-snap"));
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "bollard", "at": {"x": 525, "z": 700}}]),
        );
        assert!(validate_manifest(&m).valid, "{:?}", issues(&m));
    }

    #[test]
    fn sized_kinds_need_a_size_and_others_refuse_one() {
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "block-house", "at": {"x": 600, "z": 600}}]),
        );
        assert!(has(&m, "size-missing"));
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "block-house", "at": {"x": 600, "z": 600}, "size": {"w": 0, "d": 100}}]),
        );
        assert!(has(&m, "size-missing"));
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "bollard", "at": {"x": 500, "z": 700}, "size": {"w": 50, "d": 50}}]),
        );
        assert!(has(&m, "size-not-allowed"));
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "block-house", "at": {"x": 600, "z": 600}, "size": {"w": 100, "d": 100}}]),
        );
        let index = PlaceIndex::build(&m).unwrap();
        assert_eq!(
            index.placements[0].placed.shapes,
            [Shape::Rect {
                x: -50,
                z: -50,
                w: 100,
                d: 100
            }],
            "the size replaces the footprint, centred on the point"
        );
    }

    #[test]
    fn a_sized_meadow_blocks_no_cell_while_a_sized_block_blocks_its_lot() {
        // Both 2 by 2 m on the plaza (x 0..800, z 400..800).
        let plaza = PlaceId::from("room:p");
        for (kind, blocks) in [("meadow", false), ("block-house", true)] {
            let m = with(
                layout_base(),
                json!([{"id": "placement:x", "kind": kind, "at": {"x": 600, "z": 600},
                        "size": {"w": 200, "d": 200}}]),
            );
            assert!(validate_manifest(&m).valid, "{kind}: {:?}", issues(&m));
            let index = PlaceIndex::build(&m).unwrap();
            let (grid, floor) = (NavGrid::build(&index), NavGrid::floor(&index));
            let blocked = floor
                .cells_in(&plaza)
                .into_iter()
                .filter(|c| !grid.walkable(*c))
                .count();
            if blocks {
                // Its 8 by 8 cells: the next cells' centres out lie 13 cm
                // beyond it, outside the body clearance.
                assert_eq!(blocked, 64, "{kind} blocks its lot");
            } else {
                assert_eq!(blocked, 0, "{kind} is soft ground");
                assert!(index.placements[0].placed.shapes.is_empty(), "{kind}");
            }
        }
    }

    #[test]
    fn a_footprint_may_not_cover_a_seat() {
        // Seat a1 sits at (100, 100) in the workshop.
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "bollard", "at": {"x": 100, "z": 100}}]),
        );
        let found = issues(&m);
        let seat = found
            .iter()
            .find(|i| i.code == "placement-covers-seat")
            .unwrap();
        assert!(seat.message.contains("seat:a1"), "{}", seat.message);
    }

    #[test]
    fn a_seat_class_placement_may_surround_its_own_seat() {
        let mut m = layout_base();
        room(&mut m, "room:p").seats = serde_json::from_value(json!([
            {"id": "seat:p1", "pos": {"x": 400, "z": 624}, "facing": 0, "kind": "desk"}
        ]))
        .unwrap();
        let own = with(
            m.clone(),
            json!([{"id": "placement:desk", "kind": "desk", "at": {"x": 400, "z": 624}}]),
        );
        assert!(validate_manifest(&own).valid, "{:?}", issues(&own));
        let other = with(
            m,
            json!([{"id": "placement:desk", "kind": "desk", "at": {"x": 400, "z": 700}}]),
        );
        assert!(
            has(&other, "placement-covers-seat"),
            "a desk whose own chair is elsewhere"
        );
    }

    #[test]
    fn a_footprint_may_not_cover_a_door_span() {
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "bollard", "at": {"x": 200, "z": 425}}]),
        );
        assert!(has(&m, "placement-covers-door"));
    }

    #[test]
    fn a_footprint_may_not_cover_a_track() {
        // A bollard on the tram street, on the eastbound track at z = 300.
        let m = with(
            crate::index::fixtures::tram_street(),
            json!([{"id": "placement:x", "kind": "bollard", "at": {"x": 1000, "z": 300}}]),
        );
        assert!(has(&m, "placement-covers-track"), "{:?}", codes(&m));
    }

    #[test]
    fn a_footprint_may_not_cover_another_placements_anchor() {
        // The shelter's stand anchor is 110 cm in front of it, at (400, 710).
        let shelter = json!({"id": "placement:a-shelter", "kind": "tram-shelter", "at": {"x": 400, "z": 600}});
        let alone = with(layout_base(), json!([shelter]));
        assert!(validate_manifest(&alone).valid, "{:?}", issues(&alone));
        for bollard in ["placement:b-bollard", "placement:0-bollard"] {
            let m = with(
                layout_base(),
                json!([shelter, {"id": bollard, "kind": "bollard", "at": {"x": 400, "z": 725}}]),
            );
            let found = issues(&m);
            let covered = found
                .iter()
                .find(|i| i.code == "placement-covers-anchor")
                .unwrap_or_else(|| panic!("{found:?}"));
            assert!(covered.message.contains("stand"), "{}", covered.message);
        }
    }

    #[test]
    fn an_anchor_must_be_reachable() {
        // Turned to face south, the shelter's stand anchor falls at
        // (600, 340): on the grid, but on no room's floor.
        let m = with(
            layout_base(),
            json!([{"id": "placement:shelter", "kind": "tram-shelter", "at": {"x": 600, "z": 450}, "facing": 180}]),
        );
        let found = issues(&m);
        let unreachable = found
            .iter()
            .find(|i| i.code == "anchor-unreachable")
            .unwrap_or_else(|| panic!("{found:?}"));
        assert!(
            unreachable.message.contains("stand anchor"),
            "{}",
            unreachable.message
        );
        // Walled in: the pocket in front of the shelter, round its stand
        // anchor at (600, 710) and its bench's three sit anchors at z 610,
        // is closed by bookshelves turned end on to the west and east,
        // reaching back to the shelter, and a row of three across it to
        // the south, each facing out of the pocket, so their own stand
        // anchors lie outside it. The plaza is made deeper and wider to
        // hold them.
        let mut m = layout_base();
        room(&mut m, "room:p").rect = Some(Rect {
            x: 0,
            z: 400,
            w: 1200,
            d: 800,
        });
        let shelter =
            json!({"id": "placement:shelter", "kind": "tram-shelter", "at": {"x": 600, "z": 600}});
        let alone = with(m.clone(), json!([shelter]));
        assert!(validate_manifest(&alone).valid, "{:?}", issues(&alone));
        let m = with(
            m,
            json!([
                shelter,
                {"id": "placement:west", "kind": "bookshelf", "at": {"x": 350, "z": 650}, "facing": 270},
                {"id": "placement:east", "kind": "bookshelf", "at": {"x": 850, "z": 650}, "facing": 90},
                {"id": "placement:south-1", "kind": "bookshelf", "at": {"x": 450, "z": 800}, "facing": 180},
                {"id": "placement:south-2", "kind": "bookshelf", "at": {"x": 650, "z": 800}, "facing": 180},
                {"id": "placement:south-3", "kind": "bookshelf", "at": {"x": 850, "z": 800}, "facing": 180}
            ]),
        );
        let found = issues(&m);
        assert_eq!(codes(&m), ["anchor-unreachable"; 4], "{found:?}");
        assert!(
            found.iter().any(|i| i.message.contains("stand anchor")),
            "{found:?}"
        );
    }

    #[test]
    fn a_room_a_footprint_eats_into_must_keep_its_places() {
        // The plaza has 512 cells; a planter takes about 36 of them.
        let mut m = layout_base();
        room(&mut m, "room:p").capacity = 500;
        assert!(validate_manifest(&m).valid, "untouched, it may keep fewer");
        let m = with(
            m,
            json!([{"id": "placement:x", "kind": "planter", "at": {"x": 600, "z": 600}}]),
        );
        let found = issues(&m);
        let small = found
            .iter()
            .find(|i| i.code == "room-too-small")
            .unwrap_or_else(|| panic!("{found:?}"));
        assert_eq!(small.place.as_deref(), Some("room:p"));
    }

    #[test]
    fn a_placement_id_is_placement_and_a_slug() {
        let planter = |id: &str| {
            with(
                layout_base(),
                json!([{"id": id, "kind": "planter", "at": {"x": 600, "z": 600}}]),
            )
        };
        assert!(validate_manifest(&planter("placement:planter-2")).valid);
        for bad in [
            "planter",
            "placement:",
            "placement:Planter",
            "placement:big planter",
            "placement:a:b",
            "room:planter",
        ] {
            let found = issues(&planter(bad));
            let issue = found
                .iter()
                .find(|i| i.code == "bad-placement-id")
                .unwrap_or_else(|| panic!("{bad}: {found:?}"));
            assert_eq!(issue.place.as_deref(), Some(bad));
        }
    }

    #[test]
    fn state_must_be_declared_and_typed() {
        let lamp = |state: serde_json::Value| {
            with(
                layout_base(),
                json!([{"id": "placement:x", "kind": "street-lamp", "at": {"x": 500, "z": 700}, "state": state}]),
            )
        };
        assert!(validate_manifest(&lamp(json!({"lit": false}))).valid);
        assert!(has(&lamp(json!({"lit": 3})), "bad-state"));
        assert!(has(&lamp(json!({"colour": "red"})), "bad-state"));
    }

    #[test]
    fn only_a_display_may_be_bound() {
        let bound = json!({"source": "superpipeline", "ref": "board:guild"});
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "street-lamp", "at": {"x": 500, "z": 700}, "binding": bound}]),
        );
        assert!(has(&m, "bad-binding"));

        let mut cat = Catalogue::builtin().clone();
        cat.kinds.push(
            serde_json::from_value(json!({
                "id": "noticeboard", "name": "Noticeboard", "description": "A board.",
                "class": "fixture", "snap": 25, "height": 180,
                "footprint": [{"x": -50, "z": -10, "w": 100, "d": 20}],
                "anchors": [{"type": "display", "at": {"x": 0, "z": 10}, "facing": 0,
                             "size": {"w": 100, "d": 80}}]
            }))
            .unwrap(),
        );
        let cat: &'static Catalogue = Box::leak(Box::new(cat));
        let check = |binding: serde_json::Value| {
            let m = with(
                layout_base(),
                json!([{"id": "placement:x", "kind": "noticeboard", "at": {"x": 500, "z": 700}, "binding": binding}]),
            );
            let mut index = PlaceIndex::build(&layout_base()).unwrap();
            let mut out = Vec::new();
            validate(&m, cat, &mut index, &mut out);
            out.into_iter().map(|i| i.code).collect::<Vec<_>>()
        };
        assert_eq!(check(bound), Vec::<String>::new());
        assert_eq!(
            check(json!({"source": "", "ref": "board:guild"})),
            ["bad-binding"]
        );
    }

    #[test]
    fn the_catalogue_version_must_be_carried() {
        let mut m = layout_base();
        m.catalogue = Some(1);
        assert!(validate_manifest(&m).valid);
        m.catalogue = Some(2);
        assert!(has(&m, "catalogue-version"));
        m.catalogue = None;
        assert!(has(&m, "catalogue-version"), "schema 2 names its catalogue");
    }

    #[test]
    fn only_one_district_may_be_laid_out() {
        let mut m = layout_base();
        let far: District = serde_json::from_value(json!(
            {"id": "district:far", "name": "Far", "facilities": [
                {"id": "facility:far", "name": "Far", "rooms": [
                    {"id": "room:far", "name": "Far", "capacity": 4, "outdoor": true,
                     "rect": {"x": 5000, "z": 5000, "w": 400, "d": 400}}
                ]}
            ]}
        ))
        .unwrap();
        m.city.districts.push(far);
        assert!(has(&m, "one-district-layout"));
    }

    /// The keys `written` carries with a value that `original` lacks. Empty
    /// values were written before placements too, so they do not count.
    fn added(written: &serde_json::Value, original: &serde_json::Value) -> Vec<String> {
        use serde_json::Value;
        match (written, original) {
            (Value::Object(w), Value::Object(o)) => w
                .iter()
                .flat_map(|(k, v)| match o.get(k) {
                    Some(ov) => added(v, ov),
                    None if v.is_null() || v == &json!([]) || v == &json!({}) => Vec::new(),
                    None => vec![k.clone()],
                })
                .collect(),
            (Value::Array(w), Value::Array(o)) => {
                w.iter().zip(o).flat_map(|(a, b)| added(a, b)).collect()
            }
            _ => Vec::new(),
        }
    }

    #[test]
    fn the_fixtures_are_schema_two_and_write_back_nothing_new() {
        // The district is laid out as placements; the two-room gate has no
        // layout, so nothing to place.
        for (text, laid_out) in [
            (
                include_str!("../../../../fixtures/two-room/manifest.json"),
                false,
            ),
            (
                include_str!("../../../../fixtures/district/manifest.json"),
                true,
            ),
        ] {
            let m: Manifest = serde_json::from_str(text).unwrap();
            assert!(validate_manifest(&m).valid);
            assert_eq!((m.schema_version, m.catalogue), (2, Some(1)));
            let original: serde_json::Value = serde_json::from_str(text).unwrap();
            let written = serde_json::to_value(&m).unwrap();
            assert_eq!(added(&written, &original), Vec::<String>::new());
            assert_eq!(
                added(&original, &written),
                Vec::<String>::new(),
                "nothing dropped"
            );
            let index = PlaceIndex::build(&m).unwrap();
            assert_eq!(!index.placements.is_empty(), laid_out);
            assert_eq!(!index.buildings.is_empty(), laid_out);
        }
    }

    #[test]
    fn a_placement_serialises_its_binding_ref() {
        let p: Placement = serde_json::from_value(json!({
            "id": "placement:board", "kind": "noticeboard", "at": {"x": 0, "z": 0},
            "binding": {"source": "superpipeline", "ref": "board:guild"}
        }))
        .unwrap();
        assert_eq!(p.binding.as_ref().unwrap().reference, "board:guild");
        assert_eq!(
            serde_json::to_value(&p).unwrap(),
            json!({"id": "placement:board", "kind": "noticeboard", "at": {"x": 0, "z": 0},
                   "binding": {"source": "superpipeline", "ref": "board:guild"}})
        );
    }

    #[test]
    fn each_seat_kind_leaves_its_way_in_open_at_every_right_angle() {
        // Wherever the sit point falls in its cell, the anchor's cell and the
        // cell the sitter steps in from stay walkable: in front for a bench
        // or armchair, behind for a desk or café chair, whose table stands
        // in front.
        let base = Point { x: 400, z: 600 };
        let mut stood = 0;
        for (kind, way_in) in [
            ("bench", -25),
            ("cafe-table", 25),
            ("reading-chair", -25),
            ("desk", 25),
        ] {
            for facing in [0, 90, 180, 270] {
                for (dx, dz) in [(0, 0), (7, 13), (13, 24), (24, 7), (19, 19)] {
                    let at = Point {
                        x: base.x + dx,
                        z: base.z + dz,
                    };
                    let m = with(
                        layout_base(),
                        json!([{"id": "placement:seat", "kind": kind, "at": at, "facing": facing}]),
                    );
                    let index = PlaceIndex::build(&m)
                        .unwrap_or_else(|e| panic!("{kind} {facing} {at:?}: {e:?}"));
                    let grid = NavGrid::build(&index);
                    let anchor = grid.cell_of(at);
                    let entry = grid.cell_of(footprint::world_point(
                        at,
                        facing,
                        Point { x: 0, z: way_in },
                    ));
                    assert!(grid.walkable(anchor), "{kind} {facing} {at:?}");
                    assert!(grid.walkable(entry), "{kind} {facing} {at:?} way in");
                    let floor = NavGrid::floor(&index);
                    let blocked = floor
                        .cells_under(&index.placements[0].placed, MARGIN)
                        .into_iter()
                        .filter(|c| floor.walkable(*c) && !grid.walkable(*c))
                        .count();
                    // A café chair stands within its sitter's square but
                    // for its sides' last centimetres, so where the point
                    // falls on a cell's corner it blocks nothing beside it.
                    let least = if kind == "cafe-table" { 0 } else { 3 };
                    assert!(blocked >= least, "{kind} {facing}: the furniture stands");
                    stood += usize::from(blocked > 0);
                }
            }
        }
        assert!(stood >= 70, "the furniture stands at {stood} of 80 points");
    }

    #[test]
    fn a_door_needs_a_positive_width_agreed_by_both_sides() {
        let mut m = layout_base();
        m.city.districts[0].facilities[0].rooms[0].doors[0].width = Some(0);
        let found = issues(&m);
        let bad = found
            .iter()
            .find(|i| i.code == "bad-door-width")
            .unwrap_or_else(|| panic!("{found:?}"));
        assert_eq!(bad.place.as_deref(), Some("door:a-p"));
        let mut m = layout_base();
        m.city.districts[0].facilities[0].rooms[0].doors[0].width = Some(200);
        m.city.districts[0].facilities[1].rooms[0].doors[0].width = Some(150);
        let found = issues(&m);
        let bad = found
            .iter()
            .find(|i| i.code == "bad-door-width")
            .unwrap_or_else(|| panic!("{found:?}"));
        assert!(
            bad.message.contains("door:a-p") && bad.message.contains("door:p-a"),
            "{}",
            bad.message
        );
        m.city.districts[0].facilities[1].rooms[0].doors[0].width = Some(200);
        assert!(validate_manifest(&m).valid);
        m.city.districts[0].facilities[1].rooms[0].doors[0].width = None;
        assert!(
            validate_manifest(&m).valid,
            "one side may leave it to the other"
        );
    }

    #[test]
    fn a_shell_may_not_cover_a_track() {
        // The ground's rooms made one building, with the eastbound track
        // moved 15 cm north to z = 285, just clear of the north platform
        // (135 cm): the partition between that platform and the street,
        // centred on z = 150, stands within a tram's width of it.
        let mut m = crate::index::fixtures::tram_street();
        m.city.districts[0].facilities[0].kind = Some("guild-hall".into());
        m.lines[0].tracks = [-165, 150];
        let found = issues(&m);
        let track = found
            .iter()
            .find(|i| i.code == "placement-covers-track")
            .unwrap_or_else(|| panic!("{found:?}"));
        assert_eq!(track.place.as_deref(), Some("facility:ground"));
    }

    #[test]
    fn a_shell_may_not_cover_another_door_span() {
        // A yard south of the plaza, with a door near the plaza's east end,
        // and a shop east of the plaza whose west wall reaches that door.
        let mut m = layout_base();
        let yard: city_contracts::Facility = serde_json::from_value(json!(
            {"id": "facility:yard", "name": "Yard", "rooms": [
                {"id": "room:q", "name": "Q", "capacity": 10, "outdoor": true,
                 "rect": {"x": 0, "z": 800, "w": 800, "d": 400},
                 "doors": [{"id": "door:q-p", "to": "room:p", "pos": {"x": 775, "z": 800},
                            "transit": {"min": 1, "max": 1}}]}
            ]}
        ))
        .unwrap();
        m.city.districts[0].facilities.push(yard);
        let back: city_contracts::Door = serde_json::from_value(json!(
            {"id": "door:p-q", "to": "room:q", "pos": {"x": 775, "z": 800}, "transit": {"min": 1, "max": 1}}
        ))
        .unwrap();
        room(&mut m, "room:p").doors.push(back);
        assert!(validate_manifest(&m).valid, "{:?}", issues(&m));
        let shop: city_contracts::Facility = serde_json::from_value(json!(
            {"id": "facility:shop", "name": "Shop", "kind": "cafe", "rooms": [
                {"id": "room:r", "name": "R", "capacity": 10,
                 "rect": {"x": 800, "z": 400, "w": 400, "d": 400}}
            ]}
        ))
        .unwrap();
        m.city.districts[0].facilities.push(shop);
        let found = issues(&m);
        let door = found
            .iter()
            .find(|i| i.code == "placement-covers-door")
            .unwrap_or_else(|| panic!("{found:?}"));
        assert_eq!(door.place.as_deref(), Some("facility:shop"));
    }

    #[test]
    fn a_placement_kilometres_off_the_grid_is_refused() {
        for (x, z) in [(i32::MAX - 10, 600), (400, i32::MIN + 10), (1_000_025, 600)] {
            let m = with(
                layout_base(),
                json!([{"id": "placement:x", "kind": "planter", "at": {"x": x / 25 * 25, "z": z / 25 * 25}}]),
            );
            assert_eq!(codes(&m), ["placement-off-grid"], "({x}, {z})");
        }
        let m = with(
            layout_base(),
            json!([{"id": "placement:x", "kind": "planter", "at": {"x": 1_000_000, "z": 600}}]),
        );
        assert!(validate_manifest(&m).valid, "10 km out is still the world");
    }

    #[test]
    fn world_content_off_the_rooms_is_valid_and_clipped_to_the_grid() {
        // A street tree 3 m east of the plaza, beyond every room and the
        // grid: valid, and it blocks nothing.
        let m = with(
            layout_base(),
            json!([{"id": "placement:tree", "kind": "street-tree", "at": {"x": 1100, "z": 600}}]),
        );
        let index = PlaceIndex::build(&m).unwrap_or_else(|e| panic!("{e:?}"));
        let plaza = PlaceId::from("room:p");
        assert_eq!(
            NavGrid::build(&index).cells_in(&plaza),
            NavGrid::floor(&index).cells_in(&plaza)
        );
        // A planter straddling the plaza's west edge: valid, and it blocks
        // only the plaza cells within its reach.
        let at = Point { x: -50, z: 600 };
        let m = with(
            layout_base(),
            json!([{"id": "placement:planter", "kind": "planter", "at": at}]),
        );
        let index = PlaceIndex::build(&m).unwrap_or_else(|e| panic!("{e:?}"));
        let (grid, floor) = (NavGrid::build(&index), NavGrid::floor(&index));
        let blocked: Vec<Cell> = floor
            .cells_in(&plaza)
            .into_iter()
            .filter(|c| !grid.walkable(*c))
            .collect();
        assert!(!blocked.is_empty());
        assert!(blocked.iter().all(|c| footprint::covers(
            &index.placements[0].placed,
            grid.centre(*c),
            MARGIN
        )));
    }
}
