//! The navigation grid: where occupants can walk.
//!
//! The layout's room rectangles rasterise into 25 cm cells. A cell is
//! walkable when its centre lies inside a room and more than the body
//! clearance outside every placement's footprint and every building's
//! shell. Seat cells, and door spans against
//! their own building's shell, are kept walkable. Walks cross between rooms
//! only through a door's span, except that outdoor rooms join along any
//! shared edge. A walk enters a seat cell only as its last cell, so an empty
//! bench is a bench, not a path. All costs are integers, so paths are the
//! same on every platform.

use crate::footprint::{self, MARGIN, Placed};
use crate::index::PlaceIndex;
use crate::placement;
use city_contracts::{PlaceId, Point, Rect};
use std::cmp::Reverse;
use std::collections::{BTreeMap, BTreeSet, BinaryHeap, VecDeque};

/// The side of one grid cell, in centimetres.
pub const CELL: i32 = 25;
const STRAIGHT: u32 = 10;
const DIAGONAL: u32 = 14;
/// How far a door's opening extends either side of its position, for a
/// door with no width of its own and no building kind to take one from.
const DOOR_HALF_WIDTH: i32 = 50;
/// How far a door's span reaches into the rooms either side of it: two
/// cells, whatever the door's width.
const DOOR_DEPTH: i32 = 2 * CELL;

/// A grid cell: column `i` (east) and row `j` (south).
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Cell {
    pub i: i32,
    pub j: i32,
}

#[derive(Debug, Clone)]
struct DoorSpan {
    rooms: (u16, u16),
    cells: BTreeSet<Cell>,
}

/// The walkable grid of a layout.
#[derive(Debug, Clone)]
pub struct NavGrid {
    origin: Point,
    cols: i32,
    rows: i32,
    room: Vec<Option<u16>>,
    /// Each cell's room before any footprint or shell is carved out, which
    /// a region is rebuilt from when placements change.
    floor: Vec<Option<u16>>,
    room_ids: Vec<PlaceId>,
    /// The first and last cell (row and column) of each room's rect, clipped
    /// to the grid: none of its cells lies outside them.
    extents: Vec<Option<(Cell, Cell)>>,
    /// How many walkable cells each room has, and had on the floor.
    counts: Vec<usize>,
    floor_counts: Vec<usize>,
    /// Whether each room is open ground; outdoor rooms join along any
    /// shared edge, without a door.
    outdoor: Vec<bool>,
    spans: Vec<DoorSpan>,
    /// Door spans each cell belongs to.
    span_of: BTreeMap<Cell, Vec<usize>>,
    /// Each room's main door span: its first door onto an outdoor room, else
    /// its door with the lowest ID.
    main_span: BTreeMap<PlaceId, usize>,
    /// Where queues form for a room with no door (open ground joined only
    /// along its edges): its first threshold cell.
    queue_origin: BTreeMap<PlaceId, Cell>,
    /// Cells no queue place lies on or runs across: the tram tracks (see
    /// `keep_queues_off`).
    no_queue: BTreeSet<Cell>,
    /// The cells holding a seat's point, in every room: no footprint blocks
    /// them, and no walk passes through them.
    seat_cells: BTreeSet<Cell>,
}

/// The eight steps, straight ones first: north, east, south, west.
pub(crate) const NEIGHBOURS: [(i32, i32); 8] = [
    (0, -1),
    (1, 0),
    (0, 1),
    (-1, 0),
    (1, -1),
    (1, 1),
    (-1, 1),
    (-1, -1),
];

/// Whether a cell centred at `q` lies in the span of a door at `p`: a cross
/// `half` either side of the door along its wall, and two cells deep into
/// the rooms either side. With no wall to go by, both arms reach `half`.
fn in_span(q: Point, p: Point, half: i32, wall: Option<placement::WallRun>) -> bool {
    let (dx, dz) = ((q.x - p.x).abs(), (q.z - p.z).abs());
    let (reach_x, reach_z) = match wall {
        Some(placement::WallRun::EastWest) => (half, DOOR_DEPTH),
        Some(placement::WallRun::NorthSouth) => (DOOR_DEPTH, half),
        None => (half, half),
    };
    dz < CELL && dx <= reach_x || dx < CELL && dz <= reach_z
}

fn octile(a: Cell, b: Cell) -> u32 {
    let dx = (a.i - b.i).unsigned_abs();
    let dz = (a.j - b.j).unsigned_abs();
    let (lo, hi) = if dx < dz { (dx, dz) } else { (dz, dx) };
    lo * DIAGONAL + (hi - lo) * STRAIGHT
}

impl NavGrid {
    /// Builds the grid of an index that has a layout: the rooms' floors,
    /// less every footprint and building shell.
    pub fn build(index: &PlaceIndex) -> NavGrid {
        Self::assemble(index, true)
    }

    /// The grid of the rooms' floors alone, before any footprint or shell
    /// is carved out: what placements are checked against.
    pub fn floor(index: &PlaceIndex) -> NavGrid {
        Self::assemble(index, false)
    }

    fn assemble(index: &PlaceIndex, carve: bool) -> NavGrid {
        let rects: Vec<_> = index
            .rooms
            .values()
            .filter_map(|r| r.rect.map(|x| (r, x)))
            .collect();
        let min_x = rects.iter().map(|(_, r)| r.x).min().unwrap_or(0);
        let min_z = rects.iter().map(|(_, r)| r.z).min().unwrap_or(0);
        let max_x = rects.iter().map(|(_, r)| r.x + r.w).max().unwrap_or(0);
        let max_z = rects.iter().map(|(_, r)| r.z + r.d).max().unwrap_or(0);
        let origin = Point { x: min_x, z: min_z };
        let cols = (max_x - min_x + CELL - 1) / CELL;
        let rows = (max_z - min_z + CELL - 1) / CELL;
        let room_ids: Vec<PlaceId> = index.rooms.keys().cloned().collect();
        let idx_of: BTreeMap<&PlaceId, u16> = room_ids
            .iter()
            .enumerate()
            .map(|(n, id)| (id, n as u16))
            .collect();
        let mut grid = NavGrid {
            origin,
            cols,
            rows,
            room: vec![None; (cols.max(0) * rows.max(0)) as usize],
            floor: Vec::new(),
            room_ids: room_ids.clone(),
            extents: vec![None; room_ids.len()],
            counts: vec![0; room_ids.len()],
            floor_counts: vec![0; room_ids.len()],
            outdoor: room_ids.iter().map(|id| index.rooms[id].outdoor).collect(),
            spans: Vec::new(),
            span_of: BTreeMap::new(),
            main_span: BTreeMap::new(),
            queue_origin: BTreeMap::new(),
            no_queue: BTreeSet::new(),
            seat_cells: BTreeSet::new(),
        };
        for (info, rect) in &rects {
            let n = idx_of[&info.id];
            let cells = grid.cells_within(*rect);
            grid.extents[n as usize] = cells.first().zip(cells.last()).map(|(a, b)| (*a, *b));
            for c in cells {
                let p = grid.centre_exact(c);
                if rect.contains(p) {
                    let k = grid.index(c).expect("in bounds");
                    grid.room[k] = Some(n);
                }
            }
        }
        grid.seat_cells = index
            .rooms
            .values()
            .flat_map(|info| &info.seats)
            .filter_map(|s| s.pos.map(|p| grid.cell_of(p)))
            .collect();
        let outdoor = |id: &PlaceId| index.rooms.get(id).is_some_and(|r| r.outdoor);
        for info in index.rooms.values() {
            // The main door, where queues form, is the first door onto an
            // outdoor room, else the door with the lowest ID.
            let mut doors: Vec<_> = info.door_list.iter().collect();
            doors.sort_by(|a, b| (!outdoor(&a.to), &a.id).cmp(&(!outdoor(&b.to), &b.id)));
            for door in doors {
                let (Some(p), Some(&to)) = (door.pos, idx_of.get(&door.to)) else {
                    continue;
                };
                let from = idx_of[&info.id];
                let key = if from < to { (from, to) } else { (to, from) };
                let half =
                    placement::door_width(index, info, door).map_or(DOOR_HALF_WIDTH, |w| w / 2);
                let wall = placement::door_wall(index, info, door);
                // Only cells this near the door can lie in its cross.
                let reach = half.max(DOOR_DEPTH) + CELL;
                let near = Rect {
                    x: p.x - reach,
                    z: p.z - reach,
                    w: 2 * reach,
                    d: 2 * reach,
                };
                let cells: BTreeSet<Cell> = grid
                    .cells_within(near)
                    .into_iter()
                    .filter(|c| {
                        let q = grid.centre_exact(*c);
                        let r = grid.room[grid.index(*c).expect("in bounds")];
                        (r == Some(from) || r == Some(to)) && in_span(q, p, half, wall)
                    })
                    .collect();
                let existing = grid
                    .spans
                    .iter()
                    .position(|s| s.rooms == key && s.cells == cells);
                let k = existing.unwrap_or_else(|| {
                    grid.spans.push(DoorSpan { rooms: key, cells });
                    grid.spans.len() - 1
                });
                grid.main_span.entry(info.id.clone()).or_insert(k);
            }
        }
        for (k, span) in grid.spans.iter().enumerate() {
            for c in &span.cells {
                grid.span_of.entry(*c).or_default().push(k);
            }
        }
        grid.floor = grid.room.clone();
        for n in grid.room.iter().flatten() {
            grid.floor_counts[*n as usize] += 1;
        }
        if carve {
            grid.carve(index);
        } else {
            grid.finish();
        }
        grid
    }

    /// Carves every placement and building shell out of a floor built by
    /// [`NavGrid::floor`], making it the grid [`NavGrid::build`] gives.
    pub(crate) fn carve(&mut self, index: &PlaceIndex) {
        self.carve_all(index);
        self.finish();
    }

    /// Counts each room's walkable cells, and finds where queues form for
    /// rooms with no door.
    fn finish(&mut self) {
        self.counts = vec![0; self.room_ids.len()];
        for n in self.room.iter().flatten() {
            self.counts[*n as usize] += 1;
        }
        self.queue_origin.clear();
        for id in self.room_ids.clone() {
            if !self.main_span.contains_key(&id)
                && let Some(&first) = self.thresholds(&id).first()
            {
                self.queue_origin.insert(id, first);
            }
        }
    }

    /// Blocks every cell whose centre lies within the body clearance of a
    /// ground-level placement's footprint or a building's shell. A seat cell
    /// stays walkable, and so does a door span against its own building's
    /// shell.
    fn carve_all(&mut self, index: &PlaceIndex) {
        let district = index
            .rooms
            .values()
            .find(|r| r.rect.is_some())
            .map(|r| &r.district);
        for p in index.placements.iter().chain(&index.seat_furniture) {
            if p.level == 0 && Some(&p.district) == district {
                self.block(&p.placed, &|_| false);
            }
        }
        for building in &index.buildings {
            let own_spans = self.own_spans(index, &building.facility);
            self.block(&placement::shell(index, building), &|c| {
                own_spans.contains(&c)
            });
        }
    }

    /// The cells of the door spans of `facility`'s rooms, which its own
    /// shell leaves open.
    fn own_spans(&self, index: &PlaceIndex, facility: &PlaceId) -> BTreeSet<Cell> {
        self.spans
            .iter()
            .filter(|span| {
                [span.rooms.0, span.rooms.1]
                    .iter()
                    .any(|&n| &index.rooms[&self.room_ids[n as usize]].facility == facility)
            })
            .flat_map(|span| span.cells.iter().copied())
            .collect()
    }

    /// Recomputes every cell of `region` from the floor, less the
    /// footprints and shells standing there now, after placements changed
    /// within it. Cells outside it are untouched, so `region` must hold the
    /// bounds, grown by the body clearance, of every footprint that came or
    /// went. Returns the cells whose walkability changed, in row then column
    /// order; the grid is then the one [`NavGrid::build`] would give.
    pub fn rebuild_region(&mut self, index: &PlaceIndex, region: Rect) -> Vec<Cell> {
        let (lo_x, lo_z) = (i64::from(region.x), i64::from(region.z));
        let (hi_x, hi_z) = (lo_x + i64::from(region.w), lo_z + i64::from(region.d));
        // Only a centre within the region can be covered by what came or
        // went, and only solids touching the region can cover it.
        let (Some((i0, i1)), Some((j0, j1))) = (
            self.centres_between(lo_x, hi_x, self.origin.x, self.cols),
            self.centres_between(lo_z, hi_z, self.origin.z, self.rows),
        ) else {
            return Vec::new();
        };
        let district = index
            .rooms
            .values()
            .find(|r| r.rect.is_some())
            .map(|r| &r.district);
        let solids: Vec<&Placed> = index
            .nearby
            .solids_within((lo_x, lo_z, hi_x, hi_z))
            .into_iter()
            .filter_map(|id| index.placed(id))
            .filter(|p| p.level == 0 && Some(&p.district) == district)
            .map(|p| &p.placed)
            .collect();
        let touches = |placed: &Placed| {
            let (x0, z0, x1, z1) = footprint::bounds_wide(placed, MARGIN);
            x0 <= hi_x && lo_x <= x1 && z0 <= hi_z && lo_z <= z1
        };
        let shells: Vec<(Placed, BTreeSet<Cell>)> = index
            .buildings
            .iter()
            .map(|b| (placement::shell(index, b), b))
            .filter(|(shell, _)| touches(shell))
            .map(|(shell, b)| (shell, self.own_spans(index, &b.facility)))
            .collect();
        let width = (i1 - i0 + 1) as usize;
        let mut covered = vec![false; width * (j1 - j0 + 1) as usize];
        let no_spans = BTreeSet::new();
        let each = solids
            .into_iter()
            .map(|s| (s, &no_spans))
            .chain(shells.iter().map(|(s, own)| (s, own)));
        for (solid, own) in each {
            let (x0, z0, x1, z1) = footprint::bounds_wide(solid, MARGIN);
            let (Some((a0, a1)), Some((b0, b1))) = (
                self.centres_between(x0.max(lo_x), x1.min(hi_x), self.origin.x, self.cols),
                self.centres_between(z0.max(lo_z), z1.min(hi_z), self.origin.z, self.rows),
            ) else {
                continue;
            };
            for j in b0..=b1 {
                for i in a0..=a1 {
                    let c = Cell { i, j };
                    let local = (j - j0) as usize * width + (i - i0) as usize;
                    if !covered[local]
                        && footprint::covers(solid, self.centre_exact(c), MARGIN)
                        && !own.contains(&c)
                    {
                        covered[local] = true;
                    }
                }
            }
        }
        let mut changed = Vec::new();
        for j in j0..=j1 {
            for i in i0..=i1 {
                let c = Cell { i, j };
                let k = self.index(c).expect("in bounds");
                let local = (j - j0) as usize * width + (i - i0) as usize;
                let now = match self.floor[k] {
                    Some(_) if covered[local] && !self.seat_cells.contains(&c) => None,
                    floor => floor,
                };
                if now != self.room[k] {
                    if let Some(n) = self.room[k] {
                        self.counts[n as usize] -= 1;
                    }
                    if let Some(n) = now {
                        self.counts[n as usize] += 1;
                    }
                    self.room[k] = now;
                    changed.push(c);
                }
            }
        }
        if !changed.is_empty() {
            self.follow_queue_origins(&changed);
        }
        changed
    }

    /// The first and last column (or row) whose centre lies within
    /// `lo..=hi` (cm) on an axis starting at `origin` with `count` cells;
    /// none when no centre does.
    fn centres_between(&self, lo: i64, hi: i64, origin: i32, count: i32) -> Option<(i32, i32)> {
        let (cell, half) = (i64::from(CELL), i64::from(CELL / 2));
        let from_origin = |v: i64| v - i64::from(origin) - half;
        let first = (-(-from_origin(lo)).div_euclid(cell)).max(0);
        let last = from_origin(hi).div_euclid(cell).min(i64::from(count) - 1);
        (first <= last).then_some((first as i32, last as i32))
    }

    /// Keeps each doorless room's queue origin, its first threshold in row
    /// then column order, after `changed` cells changed. Only cells within
    /// a step of a changed cell can have become or stopped being thresholds,
    /// so the rest of the room's edge is searched only when the old origin
    /// was lost.
    fn follow_queue_origins(&mut self, changed: &[Cell]) {
        let near = self.around(changed);
        // A cell is a threshold only beside a cell of its room, so only the
        // rooms beside `near` can have gained or lost one.
        let rooms: BTreeSet<u16> = near
            .iter()
            .flat_map(|c| {
                NEIGHBOURS[..4].iter().map(move |(di, dj)| Cell {
                    i: c.i + di,
                    j: c.j + dj,
                })
            })
            .filter_map(|m| self.index(m).and_then(|k| self.floor[k]))
            .collect();
        for n in rooms.into_iter().map(usize::from) {
            let id = self.room_ids[n].clone();
            if self.main_span.contains_key(&id) {
                continue;
            }
            let row_major = |c: &Cell| (c.j, c.i);
            let mut best = near
                .iter()
                .copied()
                .filter(|c| self.threshold_of(*c, n))
                .min_by_key(row_major);
            if let Some(&old) = self.queue_origin.get(&id) {
                let kept = if self.threshold_of(old, n) {
                    Some(old)
                } else {
                    self.edge_cells(n)
                        .into_iter()
                        .filter(|c| row_major(c) > row_major(&old))
                        .find(|c| self.threshold_of(*c, n))
                };
                best = best.into_iter().chain(kept).min_by_key(row_major);
            }
            match best {
                Some(c) => self.queue_origin.insert(id, c),
                None => self.queue_origin.remove(&id),
            };
        }
    }

    /// Every cell within one step (of eight) of `cells`, on the grid, once
    /// each, in row then column order.
    pub(crate) fn around(&self, cells: &[Cell]) -> Vec<Cell> {
        let Some(first) = cells.first() else {
            return Vec::new();
        };
        let (mut lo, mut hi) = (*first, *first);
        for c in cells {
            (lo.i, lo.j) = (lo.i.min(c.i), lo.j.min(c.j));
            (hi.i, hi.j) = (hi.i.max(c.i), hi.j.max(c.j));
        }
        let (i0, i1) = ((lo.i - 1).max(0), (hi.i + 1).min(self.cols - 1));
        let (j0, j1) = ((lo.j - 1).max(0), (hi.j + 1).min(self.rows - 1));
        if i0 > i1 || j0 > j1 {
            return Vec::new();
        }
        let width = (i1 - i0 + 1) as usize;
        let mut marked = vec![false; width * (j1 - j0 + 1) as usize];
        for c in cells {
            for j in (c.j - 1).max(j0)..=(c.j + 1).min(j1) {
                for i in (c.i - 1).max(i0)..=(c.i + 1).min(i1) {
                    marked[(j - j0) as usize * width + (i - i0) as usize] = true;
                }
            }
        }
        (j0..=j1)
            .flat_map(|j| (i0..=i1).map(move |i| Cell { i, j }))
            .filter(|c| marked[(c.j - j0) as usize * width + (c.i - i0) as usize])
            .collect()
    }

    /// The cells of room `n`'s rect and the ring round it, in row then
    /// column order: every cell of the room and every one of its
    /// thresholds lies among them.
    fn edge_cells(&self, n: usize) -> Vec<Cell> {
        let Some((lo, hi)) = self.extents[n] else {
            return Vec::new();
        };
        let (i0, i1) = ((lo.i - 1).max(0), (hi.i + 1).min(self.cols - 1));
        let (j0, j1) = ((lo.j - 1).max(0), (hi.j + 1).min(self.rows - 1));
        (j0..=j1)
            .flat_map(|j| (i0..=i1).map(move |i| Cell { i, j }))
            .collect()
    }

    /// Whether `c` lies just outside room `n`, one step from entering it.
    fn threshold_of(&self, c: Cell, n: usize) -> bool {
        let n = Some(n as u16);
        self.walkable(c)
            && self.room_index(c) != n
            && NEIGHBOURS[..4].iter().any(|(di, dj)| {
                let m = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                self.room_index(m) == n && self.can_step(c, m)
            })
    }

    /// Whether `c` is one of `room`'s thresholds (see
    /// [`NavGrid::thresholds`]).
    pub fn is_threshold(&self, c: Cell, room: &PlaceId) -> bool {
        self.room_ids
            .binary_search(room)
            .is_ok_and(|n| self.threshold_of(c, n))
    }

    /// Blocks the cells `placed` covers within the body clearance, except
    /// seat cells and cells `keep` names.
    fn block(&mut self, placed: &Placed, keep: &dyn Fn(Cell) -> bool) {
        for c in self.cells_under(placed, MARGIN) {
            let k = self.index(c).expect("in bounds");
            if self.room[k].is_some()
                && !self.seat_cells.contains(&c)
                && !keep(c)
                && footprint::covers(placed, self.centre_exact(c), MARGIN)
            {
                self.room[k] = None;
            }
        }
    }

    /// The grid's cells within `placed`'s bounds grown by `margin`, in row
    /// then column order: none when it stands wholly off the grid. The
    /// bounds are clipped to the grid before they are narrowed, so a
    /// placement however large never overflows.
    pub fn cells_under(&self, placed: &Placed, margin: i64) -> Vec<Cell> {
        let (x0, z0, x1, z1) = footprint::bounds_wide(placed, margin);
        let e = self.extent();
        let clip = |v: i64, lo: i32, len: i32| {
            v.clamp(i64::from(lo), i64::from(lo) + i64::from(len)) as i32
        };
        let (x0, x1) = (clip(x0, e.x, e.w), clip(x1, e.x, e.w));
        let (z0, z1) = (clip(z0, e.z, e.d), clip(z1, e.z, e.d));
        if x0 >= x1 || z0 >= z1 {
            return Vec::new();
        }
        self.cells_within(Rect {
            x: x0,
            z: z0,
            w: x1 - x0,
            d: z1 - z0,
        })
    }

    /// The grid's cells that `r` touches, in row then column order.
    pub fn cells_within(&self, r: Rect) -> Vec<Cell> {
        let low = self.cell_of(Point { x: r.x, z: r.z });
        let high = self.cell_of(Point {
            x: r.x + r.w,
            z: r.z + r.d,
        });
        (low.j.max(0)..=high.j.min(self.rows - 1))
            .flat_map(|j| (low.i.max(0)..=high.i.min(self.cols - 1)).map(move |i| Cell { i, j }))
            .collect()
    }

    fn all_cells(&self) -> impl Iterator<Item = Cell> + '_ {
        (0..self.rows).flat_map(move |j| (0..self.cols).map(move |i| Cell { i, j }))
    }

    fn cell_at(&self, k: usize) -> Cell {
        let k = k as i32;
        Cell {
            i: k % self.cols,
            j: k / self.cols,
        }
    }

    fn index(&self, c: Cell) -> Option<usize> {
        (c.i >= 0 && c.j >= 0 && c.i < self.cols && c.j < self.rows)
            .then(|| (c.j * self.cols + c.i) as usize)
    }

    /// A cell's centre, rounded down to whole centimetres.
    fn centre_exact(&self, c: Cell) -> Point {
        Point {
            x: self.origin.x + c.i * CELL + CELL / 2,
            z: self.origin.z + c.j * CELL + CELL / 2,
        }
    }

    pub fn cell_of(&self, p: Point) -> Cell {
        Cell {
            i: (p.x - self.origin.x).div_euclid(CELL),
            j: (p.z - self.origin.z).div_euclid(CELL),
        }
    }

    pub fn centre(&self, c: Cell) -> Point {
        self.centre_exact(c)
    }

    /// The room `c` is walkable floor of, as an index into
    /// [`NavGrid::room_ids`], or none.
    pub fn room_index(&self, c: Cell) -> Option<u16> {
        self.index(c).and_then(|k| self.room[k])
    }

    /// Every room's ID, in ID order: what room indices count into.
    pub fn room_ids(&self) -> &[PlaceId] {
        &self.room_ids
    }

    /// Whether each room, by index, is open ground.
    pub fn outdoor(&self) -> &[bool] {
        &self.outdoor
    }

    /// Every door span, in the order spans are numbered: the indices of
    /// its two rooms, lower first, and its cells.
    pub fn door_spans(&self) -> impl Iterator<Item = ([u16; 2], &BTreeSet<Cell>)> {
        self.spans
            .iter()
            .map(|s| ([s.rooms.0, s.rooms.1], &s.cells))
    }

    /// Every cell holding a seat's point.
    pub fn seat_cells(&self) -> &BTreeSet<Cell> {
        &self.seat_cells
    }

    pub fn room_at(&self, c: Cell) -> Option<&PlaceId> {
        self.room_index(c).map(|n| &self.room_ids[n as usize])
    }

    /// The room whose floor holds `c`, whether or not something now
    /// stands on it.
    pub fn floor_room_at(&self, c: Cell) -> Option<&PlaceId> {
        self.index(c)
            .and_then(|k| self.floor[k])
            .map(|n| &self.room_ids[n as usize])
    }

    /// Which rooms and entrances walks join: each pair `(a, b)`, `a < b`,
    /// shares a walk (see [`NavGrid::walks`]). Rooms are numbered in ID
    /// order, and the entrances follow them in their own order, each by the
    /// walkable cell nearest it.
    pub fn room_links(&self, entrances: &[Point]) -> BTreeSet<(usize, usize)> {
        self.links_in(&self.walks(), entrances)
    }

    /// [`NavGrid::room_links`], read off `walks`, this grid's
    /// [`NavGrid::walks`], so one labelling serves the links and the
    /// entrances' reach alike.
    pub fn links_in(&self, walks: &[u32], entrances: &[Point]) -> BTreeSet<(usize, usize)> {
        let mut members: BTreeMap<u32, BTreeSet<usize>> = BTreeMap::new();
        for (k, walk) in walks.iter().enumerate() {
            if let (true, Some(n)) = (*walk != u32::MAX, self.room[k]) {
                members.entry(*walk).or_default().insert(n as usize);
            }
        }
        for (e, at) in entrances.iter().enumerate() {
            if let Some(k) = self.snap(*at).and_then(|c| self.index(c))
                && walks[k] != u32::MAX
            {
                members
                    .entry(walks[k])
                    .or_default()
                    .insert(self.room_ids.len() + e);
            }
        }
        let mut links = BTreeSet::new();
        for nodes in members.values() {
            for a in nodes {
                for b in nodes.range(a + 1..) {
                    links.insert((*a, *b));
                }
            }
        }
        links
    }

    pub fn walkable(&self, c: Cell) -> bool {
        self.room_index(c).is_some()
    }

    pub fn in_door_span(&self, c: Cell) -> bool {
        self.span_of.contains_key(&c)
    }

    /// The area the grid covers (cm).
    pub fn extent(&self) -> Rect {
        Rect {
            x: self.origin.x,
            z: self.origin.z,
            w: self.cols * CELL,
            d: self.rows * CELL,
        }
    }

    /// The two rooms of each door span `c` lies in.
    pub fn span_rooms(&self, c: Cell) -> Vec<[&PlaceId; 2]> {
        self.span_of.get(&c).map_or_else(Vec::new, |spans| {
            spans
                .iter()
                .map(|&k| {
                    let (a, b) = self.spans[k].rooms;
                    [&self.room_ids[a as usize], &self.room_ids[b as usize]]
                })
                .collect()
        })
    }

    /// Whether `c` holds a seat's point: no footprint blocks it, and a walk
    /// enters it only as its last cell.
    pub fn is_seat_cell(&self, c: Cell) -> bool {
        self.seat_cells.contains(&c)
    }

    /// How many walkable cells each room has, for rooms with any.
    pub fn room_cell_counts(&self) -> BTreeMap<PlaceId, usize> {
        Self::by_room(&self.room_ids, &self.counts)
    }

    /// How many cells each room had on its floor, before any footprint or
    /// shell was carved out, for rooms with any.
    pub fn floor_cell_counts(&self) -> BTreeMap<PlaceId, usize> {
        Self::by_room(&self.room_ids, &self.floor_counts)
    }

    fn by_room(ids: &[PlaceId], counts: &[usize]) -> BTreeMap<PlaceId, usize> {
        ids.iter()
            .zip(counts)
            .filter(|(_, n)| **n > 0)
            .map(|(id, n)| (id.clone(), *n))
            .collect()
    }

    /// Whether one step from `a` to its neighbour `b` is allowed.
    pub fn can_step(&self, a: Cell, b: Cell) -> bool {
        let (di, dj) = (b.i - a.i, b.j - a.j);
        if (di == 0 && dj == 0) || di.abs() > 1 || dj.abs() > 1 {
            return false;
        }
        let (Some(ra), Some(rb)) = (self.room_index(a), self.room_index(b)) else {
            return false;
        };
        let open = |r: u16| self.outdoor[r as usize];
        if di != 0 && dj != 0 {
            let side1 = self.room_index(Cell { i: b.i, j: a.j });
            let side2 = self.room_index(Cell { i: a.i, j: b.j });
            let same = ra == rb && side1 == Some(ra) && side2 == Some(ra);
            let ground = [Some(ra), Some(rb), side1, side2]
                .iter()
                .all(|r| r.is_some_and(open));
            return same || ground;
        }
        if ra == rb || (open(ra) && open(rb)) {
            return true;
        }
        match (self.span_of.get(&a), self.span_of.get(&b)) {
            (Some(sa), Some(sb)) => sa.iter().any(|k| sb.contains(k)),
            _ => false,
        }
    }

    /// The total cost of walking `path` from `from`.
    pub fn cost(&self, from: Cell, path: &[Cell]) -> u32 {
        let mut at = from;
        let mut total = 0;
        for c in path {
            total += if at.i != c.i && at.j != c.j {
                DIAGONAL
            } else {
                STRAIGHT
            };
            at = *c;
        }
        total
    }

    fn search(
        &self,
        from: Cell,
        goal: &dyn Fn(Cell) -> bool,
        target: Option<Cell>,
        blocked: &dyn Fn(Cell) -> bool,
        limit: Option<usize>,
    ) -> Option<Vec<Cell>> {
        if !self.walkable(from) {
            return None;
        }
        if goal(from) {
            return Some(Vec::new());
        }
        let h = |c: Cell| target.map_or(0, |t| octile(c, t));
        let mut open = BinaryHeap::new();
        let mut best: BTreeMap<Cell, u32> = BTreeMap::new();
        let mut came: BTreeMap<Cell, Cell> = BTreeMap::new();
        best.insert(from, 0);
        open.push(Reverse((h(from), 0u32, from)));
        let mut expanded = 0usize;
        while let Some(Reverse((_, g, c))) = open.pop() {
            expanded += 1;
            if limit.is_some_and(|l| expanded > l) {
                return None;
            }
            if best.get(&c).is_some_and(|&b| b < g) {
                continue;
            }
            if goal(c) {
                let mut path = vec![c];
                let mut at = c;
                while let Some(&prev) = came.get(&at) {
                    if prev == from {
                        break;
                    }
                    path.push(prev);
                    at = prev;
                }
                path.reverse();
                return Some(path);
            }
            for (di, dj) in NEIGHBOURS {
                let n = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                // A seat is somewhere to sit, not a way through: only the
                // goal may be one.
                if !self.can_step(c, n) || ((blocked(n) || self.is_seat_cell(n)) && !goal(n)) {
                    continue;
                }
                let step = if di != 0 && dj != 0 {
                    DIAGONAL
                } else {
                    STRAIGHT
                };
                let ng = g + step;
                if best.get(&n).is_none_or(|&b| ng < b) {
                    best.insert(n, ng);
                    came.insert(n, c);
                    open.push(Reverse((ng + h(n), ng, n)));
                }
            }
        }
        None
    }

    /// The cheapest path from `from` to a cell satisfying `goal`, avoiding
    /// `blocked` cells and seat cells other than the goal itself. Excludes
    /// `from`, which may be a seat: a walk that starts on one leaves it.
    pub fn path(
        &self,
        from: Cell,
        goal: &dyn Fn(Cell) -> bool,
        blocked: &dyn Fn(Cell) -> bool,
    ) -> Option<Vec<Cell>> {
        self.search(from, goal, None, blocked, None)
    }

    /// A path to one cell, guided by the octile heuristic.
    pub fn path_to(
        &self,
        from: Cell,
        to: Cell,
        blocked: &dyn Fn(Cell) -> bool,
    ) -> Option<Vec<Cell>> {
        self.search(from, &|c| c == to, Some(to), blocked, None)
    }

    /// Like [`NavGrid::path_to`], but gives up after expanding `limit`
    /// cells: re-plans around a crowd stay cheap.
    pub fn path_bounded(
        &self,
        from: Cell,
        to: Cell,
        blocked: &dyn Fn(Cell) -> bool,
        limit: usize,
    ) -> Option<Vec<Cell>> {
        self.search(from, &|c| c == to, Some(to), blocked, Some(limit))
    }

    /// A cell's position in a field.
    pub fn slot(&self, c: Cell) -> Option<usize> {
        self.index(c)
    }

    fn step_cost(a: Cell, b: Cell) -> u32 {
        if a.i != b.i && a.j != b.j {
            DIAGONAL
        } else {
            STRAIGHT
        }
    }

    /// Every cell's walking cost to the nearest of `sources`; `u32::MAX` where
    /// none can be reached. Steps are symmetric, so descending this field
    /// from any cell walks a cheapest path to a source. A seat cell that is
    /// not a source is a sink: it gets its cost, for a walk that starts on
    /// it, but no other cell's walk passes through it.
    pub fn field_from(&self, sources: &[Cell]) -> Vec<u32> {
        let mut dist = vec![u32::MAX; self.room.len()];
        let mut open = BinaryHeap::new();
        for s in sources {
            if let Some(k) = self.index(*s)
                && self.walkable(*s)
            {
                dist[k] = 0;
                open.push(Reverse((0u32, *s)));
            }
        }
        while let Some(Reverse((d, c))) = open.pop() {
            if dist[self.index(c).expect("in bounds")] < d || (d > 0 && self.is_seat_cell(c)) {
                continue;
            }
            for (di, dj) in NEIGHBOURS {
                let n = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                if !self.can_step(c, n) {
                    continue;
                }
                let nd = d + Self::step_cost(c, n);
                let k = self.index(n).expect("walkable cells are in bounds");
                if nd < dist[k] {
                    dist[k] = nd;
                    open.push(Reverse((nd, n)));
                }
            }
        }
        dist
    }

    /// A cheapest path from `from` down `field` to one of its sources,
    /// excluding `from`; `None` where the field does not reach. It steps
    /// onto a seat cell only when that seat is a source, so it ends there.
    pub fn descend(&self, field: &[u32], from: Cell) -> Option<Vec<Cell>> {
        let mut at = from;
        let mut d = *field.get(self.index(at)?)?;
        if d == u32::MAX {
            return None;
        }
        let mut path = Vec::new();
        while d > 0 {
            let next = NEIGHBOURS.iter().find_map(|(di, dj)| {
                let n = Cell {
                    i: at.i + di,
                    j: at.j + dj,
                };
                let nd = field[self.index(n)?];
                let through_seat = nd != 0 && self.is_seat_cell(n);
                (self.can_step(at, n)
                    && !through_seat
                    && nd != u32::MAX
                    && nd + Self::step_cost(at, n) == d)
                    .then_some((n, nd))
            })?;
            path.push(next.0);
            at = next.0;
            d = next.1;
        }
        Some(path)
    }

    /// Whether a walk from `sources` reaches each cell, by slot: the cells
    /// [`NavGrid::field_from`] gives a cost, found without costing them. A
    /// seat cell is reached but never walked through.
    pub fn reach_from(&self, sources: &[Cell]) -> Vec<bool> {
        let mut reached = vec![false; self.room.len()];
        let mut open = VecDeque::new();
        for s in sources {
            if let Some(k) = self.index(*s)
                && self.walkable(*s)
                && !reached[k]
            {
                reached[k] = true;
                open.push_back((*s, true));
            }
        }
        while let Some((c, source)) = open.pop_front() {
            if !source && self.is_seat_cell(c) {
                continue;
            }
            for (di, dj) in NEIGHBOURS {
                let n = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                if let Some(k) = self.index(n)
                    && !reached[k]
                    && self.can_step(c, n)
                {
                    reached[k] = true;
                    open.push_back((n, false));
                }
            }
        }
        reached
    }

    /// [`NavGrid::reach_from`], read off `walks`, this grid's
    /// [`NavGrid::walks`], instead of a flood of its own: a walk from
    /// `sources` reaches every cell of each walk it starts in or steps into
    /// from a seat it starts on, and the seats one step from those.
    pub fn reach_in(&self, walks: &[u32], sources: &[Cell]) -> Vec<bool> {
        let mut reached = vec![false; self.room.len()];
        let mut labels = Vec::new();
        let step_from = |c: Cell, reached: &mut Vec<bool>, labels: &mut Vec<u32>| {
            for (di, dj) in NEIGHBOURS {
                let n = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                if let Some(k) = self.index(n)
                    && self.can_step(c, n)
                {
                    reached[k] = true;
                    if walks[k] != u32::MAX {
                        labels.push(walks[k]);
                    }
                }
            }
        };
        for s in sources {
            if let Some(k) = self.index(*s)
                && self.walkable(*s)
            {
                reached[k] = true;
                if walks[k] != u32::MAX {
                    labels.push(walks[k]);
                } else {
                    // A seat a walk starts on is stepped off, never through.
                    step_from(*s, &mut reached, &mut labels);
                }
            }
        }
        labels.sort_unstable();
        labels.dedup();
        if labels.is_empty() {
            return reached;
        }
        for (k, walk) in walks.iter().enumerate() {
            if *walk != u32::MAX && labels.binary_search(walk).is_ok() {
                reached[k] = true;
            }
        }
        for seat in &self.seat_cells {
            let Some(k) = self.index(*seat) else {
                continue;
            };
            if reached[k] {
                continue;
            }
            reached[k] = NEIGHBOURS.iter().any(|(di, dj)| {
                let n = Cell {
                    i: seat.i + di,
                    j: seat.j + dj,
                };
                self.index(n).is_some_and(|m| {
                    walks[m] != u32::MAX
                        && labels.binary_search(&walks[m]).is_ok()
                        && self.can_step(n, *seat)
                })
            });
        }
        reached
    }

    /// Labels every walkable cell that is not a seat with the walk it
    /// belongs to: two cells share a label when steps through cells that
    /// are not seats join them. `u32::MAX` for the rest.
    pub fn walks(&self) -> Vec<u32> {
        let mut label = vec![u32::MAX; self.room.len()];
        let mut next = 0;
        let mut open = VecDeque::new();
        for start in 0..self.room.len() {
            let c = self.cell_at(start);
            if label[start] != u32::MAX || !self.walkable(c) || self.is_seat_cell(c) {
                continue;
            }
            label[start] = next;
            open.push_back(c);
            while let Some(c) = open.pop_front() {
                for (di, dj) in NEIGHBOURS {
                    let n = Cell {
                        i: c.i + di,
                        j: c.j + dj,
                    };
                    if let Some(k) = self.index(n)
                        && label[k] == u32::MAX
                        && !self.is_seat_cell(n)
                        && self.can_step(c, n)
                    {
                        label[k] = next;
                        open.push_back(n);
                    }
                }
            }
            next += 1;
        }
        label
    }

    /// Whether steps through walkable cells that are not seats, all within
    /// `window`, join every one of `cells` (none of them a seat), and reach
    /// every one of `seats`. A cheap, local proof that nothing between them
    /// was cut; `false` says only that no such proof was found nearby.
    pub fn joined_within(&self, cells: &[Cell], seats: &[Cell], window: Rect) -> bool {
        let Some(&start) = cells.first() else {
            return seats.is_empty();
        };
        let lo = self.cell_of(Point {
            x: window.x,
            z: window.z,
        });
        let hi = self.cell_of(Point {
            x: window.x + window.w,
            z: window.z + window.d,
        });
        let width = (hi.i - lo.i + 1) as usize;
        let local = |c: Cell| -> Option<usize> {
            ((lo.i..=hi.i).contains(&c.i) && (lo.j..=hi.j).contains(&c.j))
                .then(|| (c.j - lo.j) as usize * width + (c.i - lo.i) as usize)
        };
        let Some(first) = local(start) else {
            return false;
        };
        let mut seen = vec![false; width * (hi.j - lo.j + 1) as usize];
        let mut wanted = vec![false; seen.len()];
        let mut left = 0;
        for c in cells {
            match local(*c) {
                Some(k) if !wanted[k] => {
                    wanted[k] = true;
                    left += 1;
                }
                Some(_) => {}
                None => return false,
            }
        }
        let seats_in = |seen: &[bool]| {
            seats.iter().all(|s| {
                NEIGHBOURS.iter().any(|(di, dj)| {
                    let n = Cell {
                        i: s.i + di,
                        j: s.j + dj,
                    };
                    local(n).is_some_and(|k| seen[k]) && self.can_step(n, *s)
                })
            })
        };
        seen[first] = true;
        left -= 1;
        let mut open = VecDeque::from([start]);
        while let Some(c) = open.pop_front() {
            if left == 0 && seats_in(&seen) {
                return true;
            }
            for (di, dj) in NEIGHBOURS {
                let n = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                let Some(k) = local(n) else { continue };
                if !seen[k] && !self.is_seat_cell(n) && self.can_step(c, n) {
                    seen[k] = true;
                    if wanted[k] {
                        left -= 1;
                    }
                    open.push_back(n);
                }
            }
        }
        left == 0 && seats_in(&seen)
    }

    /// Mends `field`, which [`NavGrid::field_from`] gave from its sources
    /// before `changed` cells changed walkability, so that it gives the
    /// same costs as `field_from(sources)` does now. `removed` are the
    /// sources no longer among `sources`, and `added` those new to them.
    ///
    /// Only the costs a change can reach are touched. First every cost
    /// that no longer has a neighbour one step cheaper to rest on is
    /// cleared, cheapest first, so each is judged after the neighbours it
    /// could rest on; then the cleared cells and every cell beside a change
    /// take the best cost their neighbours offer, and the cheaper costs
    /// spread from them as in `field_from`.
    pub fn repair_field(
        &self,
        field: &mut [u32],
        sources: &BTreeSet<Cell>,
        removed: &[Cell],
        added: &[Cell],
        changed: &[Cell],
    ) {
        let mut near = self.around(changed);
        near.extend(
            removed
                .iter()
                .chain(added)
                .filter(|c| self.index(**c).is_some()),
        );
        for c in changed {
            if !self.walkable(*c) {
                field[self.index(*c).expect("changed cells are on the grid")] = u32::MAX;
            }
        }
        // A cost `field` may rest on: a source's, or any other walkable
        // cell's but a seat's, which is a sink.
        let offers = |field: &[u32], n: Cell| -> Option<u32> {
            let d = *field.get(self.index(n)?)?;
            (d != u32::MAX && self.walkable(n) && (d == 0 || !self.is_seat_cell(n))).then_some(d)
        };
        let best_beside = |field: &[u32], c: Cell| -> u32 {
            NEIGHBOURS
                .iter()
                .filter_map(|(di, dj)| {
                    let n = Cell {
                        i: c.i + di,
                        j: c.j + dj,
                    };
                    let d = offers(field, n)?;
                    self.can_step(n, c).then(|| d + Self::step_cost(n, c))
                })
                .min()
                .unwrap_or(u32::MAX)
        };

        let mut doubt: BinaryHeap<Reverse<(u32, Cell)>> = near
            .iter()
            .filter_map(|c| {
                let d = field[self.index(*c)?];
                (d != u32::MAX).then_some(Reverse((d, *c)))
            })
            .collect();
        let mut cleared = Vec::new();
        while let Some(Reverse((d, c))) = doubt.pop() {
            let k = self.index(c).expect("on the grid");
            if field[k] != d || (sources.contains(&c) && self.walkable(c)) {
                continue;
            }
            // Still resting on a neighbour (a cheaper offer, from a new
            // step or source beside it, is taken below).
            if d > 0 && best_beside(field, c) <= d {
                continue;
            }
            field[k] = u32::MAX;
            cleared.push(c);
            for (di, dj) in NEIGHBOURS {
                let n = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                if let Some(m) = self.index(n)
                    && field[m] != u32::MAX
                    && field[m] > d
                {
                    doubt.push(Reverse((field[m], n)));
                }
            }
        }

        let mut open = BinaryHeap::new();
        for s in added {
            if let Some(k) = self.index(*s)
                && self.walkable(*s)
            {
                field[k] = 0;
                open.push(Reverse((0u32, *s)));
            }
        }
        for c in cleared.iter().chain(&near) {
            let k = self.index(*c).expect("on the grid");
            if !self.walkable(*c) {
                continue;
            }
            let d = best_beside(field, *c);
            if d < field[k] {
                field[k] = d;
                open.push(Reverse((d, *c)));
            }
        }
        while let Some(Reverse((d, c))) = open.pop() {
            if field[self.index(c).expect("on the grid")] < d || (d > 0 && self.is_seat_cell(c)) {
                continue;
            }
            for (di, dj) in NEIGHBOURS {
                let n = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                if !self.can_step(c, n) {
                    continue;
                }
                let nd = d + Self::step_cost(c, n);
                let k = self.index(n).expect("walkable cells are in bounds");
                if nd < field[k] {
                    field[k] = nd;
                    open.push(Reverse((nd, n)));
                }
            }
        }
    }

    /// Every cell `field` reaches, cheapest first; ties go to the lower cell
    /// (row, then column).
    pub fn cells_by_cost(&self, field: &[u32]) -> impl Iterator<Item = Cell> + use<> {
        let mut cells: Vec<(u32, Cell)> = self
            .all_cells()
            .filter_map(|c| {
                let d = *field.get(self.index(c)?)?;
                (d != u32::MAX).then_some((d, c))
            })
            .collect();
        cells.sort();
        cells.into_iter().map(|(_, c)| c)
    }

    /// The cells just outside `room` from which one step enters it.
    pub fn thresholds(&self, room: &PlaceId) -> Vec<Cell> {
        let Ok(n) = self.room_ids.binary_search(room) else {
            return Vec::new();
        };
        self.edge_cells(n)
            .into_iter()
            .filter(|c| self.threshold_of(*c, n))
            .collect()
    }

    /// A path to the threshold of `room`: the last cell outside it, one step
    /// from entering. Empty when `from` is already inside.
    pub fn threshold_into(
        &self,
        from: Cell,
        room: &PlaceId,
        blocked: &dyn Fn(Cell) -> bool,
    ) -> Option<Vec<Cell>> {
        self.threshold_search(from, room, blocked, None)
    }

    /// Like [`NavGrid::threshold_into`], giving up after `limit` cells.
    pub fn threshold_bounded(
        &self,
        from: Cell,
        room: &PlaceId,
        blocked: &dyn Fn(Cell) -> bool,
        limit: usize,
    ) -> Option<Vec<Cell>> {
        self.threshold_search(from, room, blocked, Some(limit))
    }

    fn threshold_search(
        &self,
        from: Cell,
        room: &PlaceId,
        blocked: &dyn Fn(Cell) -> bool,
        limit: Option<usize>,
    ) -> Option<Vec<Cell>> {
        if self.room_at(from) == Some(room) {
            return Some(Vec::new());
        }
        let goal = |c: Cell| {
            self.room_at(c) != Some(room)
                && NEIGHBOURS[..4].iter().any(|(di, dj)| {
                    let n = Cell {
                        i: c.i + di,
                        j: c.j + dj,
                    };
                    self.room_at(n) == Some(room) && self.can_step(c, n)
                })
        };
        self.search(from, &goal, None, blocked, limit)
    }

    /// Every walkable cell of `room`, in row then column order.
    pub fn cells_in(&self, room: &PlaceId) -> Vec<Cell> {
        let Ok(n) = self.room_ids.binary_search(room) else {
            return Vec::new();
        };
        self.edge_cells(n)
            .into_iter()
            .filter(|c| self.room_index(*c) == Some(n as u16))
            .collect()
    }

    /// Keeps every queue off `cells` (the tram tracks): no queue place lies
    /// on one, and no queue runs on across them.
    pub fn keep_queues_off(&mut self, cells: BTreeSet<Cell>) {
        self.no_queue = cells;
    }

    /// `n` queue places outside `room`'s main door (or, for a room with no
    /// door, its queue origin): the nearest walkable cells outside the room
    /// and clear of every door span and of the cells queues keep off (see
    /// `keep_queues_off`). A queue that meets those cells goes on round
    /// them where it can, never across; so it may have fewer than `n`
    /// places.
    pub fn queue_slots(&self, room: &PlaceId, n: usize) -> Vec<Cell> {
        let starts: Vec<Cell> = match (self.main_span.get(room), self.queue_origin.get(room)) {
            (Some(&k), _) => self.spans[k]
                .cells
                .iter()
                .copied()
                .filter(|c| self.room_at(*c) != Some(room))
                .collect(),
            (None, Some(&c)) => vec![c],
            (None, None) => return Vec::new(),
        };
        let mut seen: BTreeSet<Cell> = starts.iter().copied().collect();
        let mut queue: VecDeque<Cell> = starts.into_iter().collect();
        let mut out = Vec::new();
        while let Some(c) = queue.pop_front() {
            if out.len() >= n {
                break;
            }
            if !self.in_door_span(c) && !self.no_queue.contains(&c) {
                out.push(c);
            }
            for (di, dj) in NEIGHBOURS[..4].iter() {
                let nb = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                if self.can_step(c, nb)
                    && self.room_at(nb) != Some(room)
                    && !self.no_queue.contains(&nb)
                    && seen.insert(nb)
                {
                    queue.push_back(nb);
                }
            }
        }
        out
    }

    /// A walk of at most `steps` steps from `from`, through no `blocked`
    /// cell and no seat cell, to the nearest cell (by steps) that is `ok`,
    /// as the cells stepped onto (empty when `from` itself is `ok`). A seat
    /// that is `ok` may end it. Among cells as near,
    /// the first found wins: neighbours are tried straight before diagonal,
    /// north, east, south, west. `None` when none is that near.
    pub fn nearest_within(
        &self,
        from: Cell,
        steps: usize,
        blocked: &dyn Fn(Cell) -> bool,
        ok: &dyn Fn(Cell) -> bool,
    ) -> Option<Vec<Cell>> {
        let mut came_from: BTreeMap<Cell, Cell> = BTreeMap::new();
        let mut frontier = vec![from];
        let mut seen: BTreeSet<Cell> = BTreeSet::from([from]);
        for depth in 0..=steps {
            for &c in &frontier {
                if ok(c) {
                    let mut path = vec![c];
                    let mut at = c;
                    while let Some(&prev) = came_from.get(&at) {
                        path.push(prev);
                        at = prev;
                    }
                    path.pop();
                    path.reverse();
                    return Some(path);
                }
            }
            if depth == steps {
                break;
            }
            let mut next = Vec::new();
            for &c in &frontier {
                for (di, dj) in NEIGHBOURS.iter() {
                    let n = Cell {
                        i: c.i + di,
                        j: c.j + dj,
                    };
                    let passable = !blocked(n) && (!self.is_seat_cell(n) || ok(n));
                    if self.can_step(c, n) && passable && seen.insert(n) {
                        came_from.insert(n, c);
                        next.push(n);
                    }
                }
            }
            frontier = next;
        }
        None
    }

    /// The nearest walkable cell to `from` (by breadth-first steps) that is
    /// not `taken`; `from` itself if it is free.
    pub fn nearest_free(&self, from: Cell, taken: &dyn Fn(Cell) -> bool) -> Option<Cell> {
        let mut seen: BTreeSet<Cell> = BTreeSet::from([from]);
        let mut queue: VecDeque<Cell> = VecDeque::from([from]);
        while let Some(c) = queue.pop_front() {
            if self.walkable(c) && !taken(c) {
                return Some(c);
            }
            for (di, dj) in NEIGHBOURS.iter() {
                let n = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                if self.can_step(c, n) && seen.insert(n) {
                    queue.push_back(n);
                }
            }
        }
        None
    }

    /// The cell nearest `p` that satisfies `ok`, searched ring by ring
    /// outwards (by the larger of the column and row distance). Within a
    /// ring the closest centre wins, then the lowest cell. Cells outside
    /// the grid are never offered to `ok`.
    pub fn nearest(&self, p: Point, ok: &dyn Fn(Cell) -> bool) -> Option<Cell> {
        let c0 = self.cell_of(p);
        let reach = [c0.i, self.cols - 1 - c0.i, c0.j, self.rows - 1 - c0.j]
            .into_iter()
            .map(i32::abs)
            .max()
            .unwrap_or(0);
        for r in 0..=reach {
            let mut ring = Vec::new();
            if r == 0 {
                ring.push(c0);
            } else {
                for d in -r..=r {
                    ring.push(Cell {
                        i: c0.i + d,
                        j: c0.j - r,
                    });
                    ring.push(Cell {
                        i: c0.i + d,
                        j: c0.j + r,
                    });
                }
                for d in 1 - r..r {
                    ring.push(Cell {
                        i: c0.i - r,
                        j: c0.j + d,
                    });
                    ring.push(Cell {
                        i: c0.i + r,
                        j: c0.j + d,
                    });
                }
            }
            let best = ring
                .into_iter()
                .filter(|c| self.index(*c).is_some() && ok(*c))
                .map(|c| {
                    let q = self.centre(c);
                    let d = i64::from(q.x - p.x).pow(2) + i64::from(q.z - p.z).pow(2);
                    (d, c)
                })
                .min();
            if let Some((_, c)) = best {
                return Some(c);
            }
        }
        None
    }

    /// The walkable cell nearest `p`, within one cell.
    pub fn snap(&self, p: Point) -> Option<Cell> {
        let c = self.cell_of(p);
        let mut best: Option<(i64, Cell)> = None;
        for dj in -1..=1 {
            for di in -1..=1 {
                let n = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                if self.walkable(n) {
                    let q = self.centre(n);
                    let d = i64::from(q.x - p.x).pow(2) + i64::from(q.z - p.z).pow(2);
                    if best.is_none_or(|(bd, bc)| (d, n) < (bd, bc)) {
                        best = Some((d, n));
                    }
                }
            }
        }
        best.map(|(_, n)| n)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::index::{PlaceIndex, fixtures::layout_base};

    fn grid() -> NavGrid {
        NavGrid::build(&PlaceIndex::build(&layout_base()).unwrap())
    }
    fn c(i: i32, j: i32) -> Cell {
        Cell { i, j }
    }
    fn nothing(_: Cell) -> bool {
        false
    }

    #[test]
    fn reach_read_off_the_walks_is_the_reach_flooded() {
        // From every walkable cell of three fixtures as a source, alone and
        // with the next, seats and door spans among them.
        for m in [
            layout_base(),
            crate::index::fixtures::layout_streets(),
            crate::index::fixtures::line_base(),
        ] {
            let g = NavGrid::build(&PlaceIndex::build(&m).unwrap());
            let walks = g.walks();
            let cells: Vec<Cell> = (0..g.room.len())
                .map(|k| g.cell_at(k))
                .filter(|c| g.walkable(*c))
                .collect();
            assert!(cells.iter().any(|c| g.is_seat_cell(*c)), "seats among them");
            for (n, s) in cells.iter().enumerate().step_by(7) {
                let pair = [*s, cells[(n + 1) % cells.len()]];
                assert_eq!(
                    g.reach_in(&walks, &pair[..1]),
                    g.reach_from(&pair[..1]),
                    "{s:?}"
                );
                assert_eq!(g.reach_in(&walks, &pair), g.reach_from(&pair), "{pair:?}");
            }
            for s in g.seat_cells() {
                assert_eq!(g.reach_in(&walks, &[*s]), g.reach_from(&[*s]), "seat {s:?}");
            }
            assert_eq!(g.reach_in(&walks, &[]), g.reach_from(&[]));
        }
    }

    #[test]
    fn cells_are_walkable_only_inside_rooms_and_clear_of_furniture() {
        let g = grid();
        assert!(g.walkable(c(0, 0)));
        assert!(!g.walkable(c(2, 1)), "seat a1's desk");
        assert!(g.walkable(c(31, 31)), "plaza corner");
        assert!(!g.walkable(c(20, 5)), "outside every room");
        assert!(!g.walkable(c(-1, 0)));
        assert_eq!(g.room_at(c(0, 0)).map(|r| r.as_str()), Some("room:a"));
        assert_eq!(g.room_at(c(0, 16)).map(|r| r.as_str()), Some("room:p"));
        assert_eq!(g.cell_of(Point { x: 12, z: 12 }), c(0, 0));
        assert_eq!(g.centre(c(1, 2)), Point { x: 37, z: 62 });
    }

    #[test]
    fn crossing_rooms_only_through_the_door() {
        let g = grid();
        assert!(g.can_step(c(7, 15), c(7, 16)), "inside the door span");
        assert!(!g.can_step(c(1, 15), c(1, 16)), "a wall");
        assert!(
            !g.can_step(c(6, 15), c(7, 16)),
            "no diagonal through a door"
        );
        let p = g.path(c(1, 10), &|x| x == c(1, 20), &nothing).unwrap();
        assert!(p.windows(2).all(|w| g.can_step(w[0], w[1])));
        let crossing = p
            .windows(2)
            .find(|w| g.room_at(w[0]) != g.room_at(w[1]))
            .unwrap();
        assert!((6..=9).contains(&crossing[0].i));
    }

    #[test]
    fn outdoor_rooms_join_along_their_shared_edges() {
        let g =
            NavGrid::build(&PlaceIndex::build(&crate::index::fixtures::layout_streets()).unwrap());
        let at = |x, z| g.cell_of(Point { x, z });
        assert!(
            g.can_step(at(790, 600), at(810, 600)),
            "plaza to the east street, no door"
        );
        assert!(
            g.can_step(at(10, 600), at(-10, 600)),
            "plaza to the west street"
        );
        assert!(
            g.can_step(at(790, 590), at(810, 610)),
            "diagonally, all four cells open ground"
        );
        assert!(
            !g.can_step(at(10, 200), at(-10, 200)),
            "the hall's wall still stands"
        );
        assert!(
            !g.can_step(at(10, 390), at(-10, 410)),
            "no diagonal past the hall's corner"
        );
        assert!(!g.walkable(at(1210, 110)), "the house is carved out");
        let p = g
            .path(at(-700, 700), &|x| x == at(1500, 700), &nothing)
            .unwrap();
        assert!(p.windows(2).all(|w| g.can_step(w[0], w[1])));
        assert_eq!(p.len(), 88, "straight across three rooms");
    }

    #[test]
    fn astar_is_optimal_on_an_open_floor() {
        let g = grid();
        let p = g.path(c(0, 16), &|x| x == c(3, 20), &nothing).unwrap();
        assert_eq!(p.len(), 4);
        assert_eq!(g.cost(c(0, 16), &p), 52);
    }

    #[test]
    fn diagonals_never_cut_a_desks_corners() {
        // Seat a1's desk blocks (2..=5, 0..=2).
        let g = grid();
        assert!(!g.can_step(c(1, 0), c(2, 1)), "into the desk");
        assert!(!g.can_step(c(1, 3), c(2, 2)), "into the desk");
        assert!(!g.can_step(c(6, 2), c(5, 3)), "corner cut past (5,2)");
    }

    #[test]
    fn ties_are_deterministic() {
        let g = grid();
        let a = g.path(c(0, 0), &|x| x == c(30, 30), &nothing);
        let b = g.path(c(0, 0), &|x| x == c(30, 30), &nothing);
        assert_eq!(a, b);
        assert!(a.is_some());
    }

    #[test]
    fn blocked_cells_are_avoided_and_no_path_is_none() {
        let g = grid();
        let door: Vec<Cell> = (6..=9).map(|i| c(i, 15)).collect();
        assert!(
            g.path(c(1, 5), &|x| x == c(1, 20), &|x| door.contains(&x))
                .is_none()
        );
    }

    #[test]
    fn threshold_path_stops_just_outside_the_room() {
        let g = grid();
        let room = PlaceId::from("room:a");
        let p = g.threshold_into(c(20, 25), &room, &nothing).unwrap();
        let last = *p.last().unwrap();
        assert_eq!(g.room_at(last).map(|r| r.as_str()), Some("room:p"));
        assert!(g.can_step(
            last,
            Cell {
                i: last.i,
                j: last.j - 1
            }
        ));
        assert!(
            g.threshold_into(c(3, 3), &room, &nothing)
                .unwrap()
                .is_empty(),
            "already inside"
        );
    }

    #[test]
    fn queue_slots_are_outside_distinct_and_clear_of_the_door() {
        let g = grid();
        let room = PlaceId::from("room:a");
        let slots = g.queue_slots(&room, 6);
        assert_eq!(slots.len(), 6);
        let mut unique = slots.clone();
        unique.sort();
        unique.dedup();
        assert_eq!(unique.len(), 6);
        for s in &slots {
            assert_eq!(g.room_at(*s).map(|r| r.as_str()), Some("room:p"));
            assert!(!g.in_door_span(*s));
        }
        assert_eq!(g.queue_slots(&room, 6), slots);
    }

    #[test]
    fn snap_finds_the_walkable_cell_at_an_edge_point() {
        let g = grid();
        assert_eq!(g.snap(Point { x: 0, z: 600 }), Some(c(0, 24)));
        assert_eq!(g.snap(Point { x: 800, z: 600 }), Some(c(31, 24)));
        // Seat a1's desk and its 10 cm margin take six columns by three
        // rows of the workshop.
        assert_eq!(g.cells_in(&PlaceId::from("room:a")).len(), 16 * 16 - 18);
    }

    #[test]
    fn nearest_searches_outwards_and_stays_in_bounds() {
        let g = grid();
        let at = Point { x: 112, z: 112 };
        assert_eq!(g.nearest(at, &|x| g.walkable(x)), Some(c(4, 4)));
        // Seat a1's desk covers (2..=5, 0..=2); the nearest walkable cell to
        // its middle is on its edge, the closest centre first.
        let desk = Point { x: 100, z: 50 };
        let n = g.nearest(desk, &|x| g.walkable(x)).unwrap();
        assert!(g.walkable(n));
        assert!((n.i - 4).abs().max((n.j - 2).abs()) <= 2, "{n:?}");
        // Far outside the grid: the nearest in-bounds cell that passes.
        assert_eq!(
            g.nearest(Point { x: -500, z: -500 }, &|x| g.walkable(x)),
            Some(c(0, 0))
        );
        assert_eq!(g.nearest(at, &|_| false), None);
        let only = c(30, 30);
        assert_eq!(g.nearest(at, &|x| x == only), Some(only));
    }

    #[test]
    fn fields_descend_optimally_to_their_sources() {
        let g = grid();
        let room = PlaceId::from("room:a");
        let field = g.field_from(&g.thresholds(&room));
        let from = c(20, 25);
        let path = g.descend(&field, from).unwrap();
        assert!(path.windows(2).all(|w| g.can_step(w[0], w[1])));
        assert!(g.can_step(from, path[0]));
        assert_eq!(g.cost(from, &path), field[g.slot(from).unwrap()]);
        let reference = g.threshold_into(from, &room, &nothing).unwrap();
        assert_eq!(
            g.cost(from, &path),
            g.cost(from, &reference),
            "as short as a direct search"
        );
        assert!(g.thresholds(&room).contains(path.last().unwrap()));
        assert_eq!(g.descend(&field, *path.last().unwrap()), Some(vec![]));
    }

    #[test]
    fn unreachable_cells_have_no_descent() {
        let g = grid();
        let field = g.field_from(&[c(0, 0)]);
        assert_eq!(g.descend(&field, c(20, 5)), None, "outside every room");
    }

    #[test]
    fn bounded_search_gives_up_deterministically() {
        let g = grid();
        let wall: Vec<Cell> = (6..=9).map(|i| c(i, 15)).collect();
        let blocked = |x: Cell| wall.contains(&x);
        assert_eq!(g.path_bounded(c(1, 5), c(1, 20), &blocked, 50), None);
        assert!(g.path_bounded(c(0, 16), c(3, 20), &nothing, 50).is_some());
    }

    #[test]
    fn every_door_between_two_rooms_opens_its_span() {
        let mut m = layout_base();
        let rooms = &mut m.city.districts[0].facilities[0].rooms;
        let second: city_contracts::Door = serde_json::from_value(serde_json::json!(
            {"id": "door:a-p-2", "to": "room:p", "pos": {"x": 325, "z": 400}, "transit": {"min": 1, "max": 1}}
        ))
        .unwrap();
        rooms[0].doors.push(second);
        let back: city_contracts::Door = serde_json::from_value(serde_json::json!(
            {"id": "door:p-a-2", "to": "room:a", "pos": {"x": 325, "z": 400}, "transit": {"min": 1, "max": 1}}
        ))
        .unwrap();
        m.city.districts[0].facilities[1].rooms[0].doors.push(back);
        let g = NavGrid::build(&PlaceIndex::build(&m).unwrap());
        assert!(g.can_step(c(7, 15), c(7, 16)), "the first door");
        assert!(
            g.can_step(c(13, 15), c(13, 16)),
            "the second door, to the same room"
        );
    }

    /// The floor's rule, restated: the last room (by ID) whose rect holds
    /// the centre; door spans a cross 50 cm each way.
    fn assert_matches_the_floor_rule(m: &city_contracts::Manifest) {
        let index = PlaceIndex::build(m).unwrap();
        let g = NavGrid::floor(&index);
        let mut spans = BTreeSet::new();
        for room in index.rooms.values() {
            for door in &room.door_list {
                let (Some(p), Some(to)) = (door.pos, index.rooms.get(&door.to)) else {
                    continue;
                };
                for c in g.all_cells() {
                    let q = g.centre(c);
                    let r = g.room_at(c);
                    let cross = (q.z - p.z).abs() < CELL && (q.x - p.x).abs() <= 50
                        || (q.x - p.x).abs() < CELL && (q.z - p.z).abs() <= 50;
                    if cross && (r == Some(&room.id) || r == Some(&to.id)) {
                        spans.insert(c);
                    }
                }
            }
        }
        let mut walkable = 0;
        for c in g.all_cells() {
            let p = g.centre(c);
            let expected = index
                .rooms
                .values()
                .rev()
                .find(|r| r.rect.is_some_and(|x| x.contains(p)))
                .map(|r| &r.id);
            assert_eq!(g.room_at(c), expected, "{c:?}");
            assert_eq!(g.in_door_span(c), spans.contains(&c), "{c:?}");
            walkable += usize::from(g.walkable(c));
        }
        assert!(walkable > 0);
    }

    #[test]
    fn the_floor_is_the_rooms_rects_cell_for_cell() {
        // The district's building kinds widen its exterior doors, which the
        // restated rule leaves at 100 cm.
        let mut district: city_contracts::Manifest =
            serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
        for d in &mut district.city.districts {
            for f in &mut d.facilities {
                f.kind = None;
            }
        }
        for m in [
            district,
            layout_base(),
            crate::index::fixtures::layout_streets(),
            crate::index::fixtures::line_base(),
        ] {
            assert_matches_the_floor_rule(&m);
        }
    }

    /// The grid with a desk placed at `at`, and the grid without it.
    fn desk_at(at: Point, facing: i32) -> (NavGrid, NavGrid, Placed) {
        let mut index = PlaceIndex::build(&layout_base()).unwrap();
        let without = NavGrid::build(&index);
        let desk = city_contracts::Catalogue::builtin().kind("desk").unwrap();
        let placed = Placed {
            shapes: desk.footprint.clone(),
            at,
            facing,
        };
        index.placements.push(crate::placement::PlacedInfo {
            id: "placement:desk".into(),
            kind: desk,
            placed: placed.clone(),
            level: 0,
            district: "district:l".into(),
            record: Default::default(),
        });
        (NavGrid::build(&index), without, placed)
    }

    #[test]
    fn a_desk_blocks_exactly_the_cells_within_the_margin_of_its_rect() {
        let at = Point { x: 500, z: 600 };
        // Facing 0 the desk is x 435..565, z 505..575; grown by 10 cm it
        // holds the centres of columns 17..=22 and rows 20..=22.
        let (g, without, _) = desk_at(at, 0);
        let blocked: Vec<Cell> = without
            .all_cells()
            .filter(|c| without.walkable(*c) && !g.walkable(*c))
            .collect();
        let expected: Vec<Cell> = (20..=22)
            .flat_map(|j| (17..=22).map(move |i| c(i, j)))
            .collect();
        assert_eq!(blocked, expected);

        // At any facing, the rect in its own frame (x -65..65, z -95..-25),
        // grown by 10 cm, measured here in floating point. Centres within a
        // centimetre of its edge are left to the fixed table.
        for facing in [0, 90, 36] {
            let (g, without, _) = desk_at(at, facing);
            let (sin, cos) = f64::from(facing).to_radians().sin_cos();
            let mut count = 0;
            for cell in without.all_cells().filter(|x| without.walkable(*x)) {
                let q = without.centre(cell);
                let (dx, dz) = (f64::from(q.x - at.x), f64::from(q.z - at.z));
                let (x, z) = (dx * cos + dz * sin, -dx * sin + dz * cos);
                let edge = [x + 75.0, 75.0 - x, z + 105.0, -15.0 - z]
                    .into_iter()
                    .fold(f64::MAX, |m, d| m.min(d.abs()));
                if facing % 90 != 0 && edge < 1.0 {
                    continue;
                }
                let inside = (-75.0..75.0).contains(&x) && (-105.0..-15.0).contains(&z);
                assert_eq!(!g.walkable(cell), inside, "facing {facing}, {cell:?}");
                count += usize::from(inside);
            }
            assert!(count >= 9, "facing {facing}: {count}");
        }
    }

    #[test]
    fn a_seat_inside_furniture_keeps_its_cell() {
        // The catalogue's seat kinds leave their sit point clear, so a
        // table standing over the seat stands in for furniture that does not.
        let mut m = layout_base();
        let seat = Point { x: 400, z: 624 };
        m.city.districts[0].facilities[1].rooms[0].seats =
            serde_json::from_value(serde_json::json!(
                [{"id": "seat:p1", "pos": seat, "facing": 0, "kind": "desk"}]
            ))
            .unwrap();
        let mut index = PlaceIndex::build(&m).unwrap();
        let table = city_contracts::Catalogue::builtin()
            .kind("cafe-table-top")
            .unwrap();
        let placed = Placed {
            shapes: table.footprint.clone(),
            at: seat,
            facing: 0,
        };
        index.placements.push(crate::placement::PlacedInfo {
            id: "placement:table".into(),
            kind: table,
            placed: placed.clone(),
            level: 0,
            district: "district:l".into(),
            record: Default::default(),
        });
        let g = NavGrid::build(&index);
        let cell = g.cell_of(seat);
        assert!(footprint::covers(&placed, g.centre(cell), MARGIN));
        assert!(g.is_seat_cell(cell));
        assert!(g.walkable(cell), "the seat cell is kept");
        assert!(!g.walkable(c(cell.i, cell.j - 1)), "the table round it");
        assert!(!g.walkable(c(cell.i, cell.j + 1)));
    }

    #[test]
    fn a_building_shell_blocks_one_row_outside_its_rooms_and_opens_its_doors() {
        let mut m = crate::index::fixtures::layout_streets();
        let without = NavGrid::build(&PlaceIndex::build(&m).unwrap());
        m.city.districts[0].facilities[0].kind = Some("guild-hall".into());
        let index = PlaceIndex::build(&m).unwrap();
        let g = NavGrid::build(&index);
        let hall = PlaceId::from("room:a");
        assert_eq!(
            g.cells_in(&hall),
            without.cells_in(&hall),
            "never the floor"
        );
        let at = |x, z| g.cell_of(Point { x, z });
        // The west street's column against the hall's west wall, down to
        // the wall's corner; the column beyond it stays open.
        for z in (12..=412).step_by(25) {
            assert!(!g.walkable(at(-13, z)), "west wall at z {z}");
            assert!(g.walkable(at(-38, z)), "beyond the wall at z {z}");
        }
        assert!(g.walkable(at(-13, 437)), "past the corner");
        // The plaza's first row, under the hall's south wall: blocked but
        // for the door's 200 cm opening; the row below is open.
        for x in (12..=412).step_by(25) {
            let opening = (100..=300).contains(&x);
            assert_eq!(g.walkable(at(x, 412)), opening, "plaza row at x {x}");
        }
        assert!(g.walkable(at(437, 412)), "past the wall's east end");
        assert!((12..800).step_by(25).all(|x| g.walkable(at(x, 437))));
        let across: Vec<Cell> = (12..800)
            .step_by(25)
            .map(|x| at(x, 412))
            .filter(|c| g.in_door_span(*c))
            .collect();
        assert_eq!(across.len(), 8);
        assert!(across.iter().all(|c| g.walkable(*c)));
        let p = g
            .path(at(-400, 600), &|x| x == at(200, 200), &nothing)
            .unwrap();
        assert!(p.windows(2).all(|w| g.can_step(w[0], w[1])));
    }

    #[test]
    fn a_door_two_metres_wide_spans_eight_cells_along_its_wall() {
        let mut m = layout_base();
        m.city.districts[0].facilities[0].rooms[0].doors[0].width = Some(200);
        m.city.districts[0].facilities[1].rooms[0].doors[0].width = Some(200);
        let g = NavGrid::build(&PlaceIndex::build(&m).unwrap());
        let row = |j: i32| {
            (0..32)
                .filter(|i| g.in_door_span(c(*i, j)))
                .collect::<Vec<_>>()
        };
        assert_eq!(row(15), (4..=11).collect::<Vec<_>>());
        assert_eq!(row(16), (4..=11).collect::<Vec<_>>());
        // Still two cells deep either side.
        assert_eq!(row(14), [7, 8]);
        assert_eq!(row(17), [7, 8]);
        assert!(row(13).is_empty() && row(18).is_empty());
        assert!(g.can_step(c(4, 15), c(4, 16)));
        assert!(g.can_step(c(11, 15), c(11, 16)));
        assert!(!g.can_step(c(3, 15), c(3, 16)));
        // Without a width, the default stays 100 cm: four cells.
        let g = grid();
        assert_eq!((0..32).filter(|i| g.in_door_span(c(*i, 15))).count(), 4);
    }

    #[test]
    fn seat_furniture_carves_its_kinds_footprint() {
        let mut m = layout_base();
        let seat = Point { x: 400, z: 624 };
        m.city.districts[0].facilities[1].rooms[0].seats = serde_json::from_value(
            serde_json::json!([{"id": "seat:p1", "pos": seat, "facing": 0, "kind": "desk"}]),
        )
        .unwrap();
        let plaza = PlaceId::from("room:p");
        let index = PlaceIndex::build(&m).unwrap();
        let g = NavGrid::build(&index);
        let floor = NavGrid::floor(&index);
        let desk = city_contracts::Catalogue::builtin().kind("desk").unwrap();
        let placed = Placed {
            shapes: desk.footprint.clone(),
            at: seat,
            facing: 0,
        };
        let cell = g.cell_of(seat);
        let blocked: Vec<Cell> = floor
            .cells_in(&plaza)
            .into_iter()
            .filter(|c| !g.walkable(*c))
            .collect();
        let expected: Vec<Cell> = floor
            .cells_in(&plaza)
            .into_iter()
            .filter(|c| *c != cell && footprint::covers(&placed, g.centre(*c), MARGIN))
            .collect();
        assert!(!expected.is_empty());
        assert_eq!(blocked, expected);
        assert!(g.walkable(cell));

        // A seat naming one of its furniture's anchors belongs to a
        // placement of that furniture, which carves it instead.
        m.city.districts[0].facilities[1].rooms[0].seats[0].anchor = Some(0);
        let index = PlaceIndex::build(&m).unwrap();
        let furnished: Vec<&str> = index.seat_furniture.iter().map(|f| f.id.as_str()).collect();
        assert_eq!(furnished, ["seat:a1"], "the workshop's desk only");
        assert_eq!(
            NavGrid::build(&index).cells_in(&plaza),
            NavGrid::floor(&index).cells_in(&plaza)
        );
    }

    /// `layout_base` with a row of bench seats across the plaza, row 24
    /// from column 1 to column 30: the plaza's two edge columns stay open.
    fn benches() -> NavGrid {
        let mut m = layout_base();
        let seats: Vec<serde_json::Value> = (1..=30)
            .map(|i| {
                serde_json::json!({"id": format!("seat:b{i:02}"), "facing": 0,
                                   "pos": {"x": i * CELL + CELL / 2, "z": 24 * CELL + CELL / 2}})
            })
            .collect();
        m.city.districts[0].facilities[1].rooms[0].seats =
            serde_json::from_value(serde_json::Value::Array(seats)).unwrap();
        NavGrid::build(&PlaceIndex::build(&m).unwrap())
    }

    /// Whether `path`, walked from `from`, enters a seat cell anywhere but
    /// at its end.
    fn crosses_a_seat(g: &NavGrid, from: Cell, path: &[Cell]) -> bool {
        let steps = std::iter::once(from).chain(path.iter().copied());
        let mut previous = None;
        for c in steps {
            if let Some(p) = previous
                && !g.can_step(p, c)
            {
                panic!("{p:?} to {c:?} is no step");
            }
            previous = Some(c);
        }
        path.split_last()
            .is_some_and(|(_, before)| before.iter().any(|c| g.is_seat_cell(*c)))
    }

    #[test]
    fn a_walk_goes_round_a_row_of_seats_not_across_it() {
        let g = benches();
        assert!(g.is_seat_cell(c(15, 24)) && g.walkable(c(15, 24)));
        let (from, to) = (c(15, 20), c(15, 28));
        for path in [
            g.path(from, &|x| x == to, &nothing).unwrap(),
            g.path_to(from, to, &nothing).unwrap(),
            g.path_bounded(from, to, &nothing, 4_000).unwrap(),
            g.descend(&g.field_from(&[to]), from).unwrap(),
        ] {
            assert_eq!(path.last(), Some(&to));
            assert!(!crosses_a_seat(&g, from, &path), "{path:?}");
            assert!(
                path.iter().all(|x| !g.is_seat_cell(*x)),
                "round the end of the row: {path:?}"
            );
            assert!(path.len() > 8, "not straight across: {path:?}");
        }
        // A search for the nearest cell past the row goes round too.
        let past = g
            .nearest_within(from, 40, &nothing, &|x| x.j > 24 && x.i == 15)
            .unwrap();
        assert!(past.iter().all(|x| !g.is_seat_cell(*x)), "{past:?}");
    }

    #[test]
    fn a_seat_is_entered_only_as_the_last_cell_of_a_walk() {
        let g = benches();
        let (from, seat) = (c(10, 20), c(15, 24));
        // Walked to, a seat is the walk's last cell, and the walk steps on
        // no other seat on its way there.
        let to_seat = g.path_to(from, seat, &nothing).unwrap();
        assert_eq!(to_seat.last(), Some(&seat));
        assert!(!crosses_a_seat(&g, from, &to_seat), "{to_seat:?}");
        let field = g.field_from(&[seat]);
        let down = g.descend(&field, from).unwrap();
        assert_eq!(down.last(), Some(&seat));
        assert!(!crosses_a_seat(&g, from, &down), "{down:?}");
        assert_eq!(g.cost(from, &down), g.cost(from, &to_seat));
        // From the far side of the row, a walk to that seat steps up from
        // the far side: it does not climb over its neighbours.
        let behind = g.path_to(c(20, 28), seat, &nothing).unwrap();
        assert_eq!(behind.last(), Some(&seat));
        assert!(!crosses_a_seat(&g, c(20, 28), &behind), "{behind:?}");
        // A walk to another seat in the row goes round the seats between.
        let along = g.path_to(seat, c(20, 24), &nothing).unwrap();
        assert_eq!(along.last(), Some(&c(20, 24)));
        assert!(!crosses_a_seat(&g, seat, &along), "{along:?}");
        // A walk that starts on a seat leaves it.
        let away = g.path_to(seat, c(15, 28), &nothing).unwrap();
        assert_eq!(away.first(), Some(&c(15, 25)));
        assert!(away.iter().all(|x| !g.is_seat_cell(*x)));
        // In a field, a seat is reached but never passed through: its own
        // cost is finite, and descending from it steps straight off.
        let beyond = g.field_from(&[c(15, 28)]);
        assert_ne!(beyond[g.slot(seat).unwrap()], u32::MAX);
        let off = g.descend(&beyond, seat).unwrap();
        assert!(off.iter().all(|x| !g.is_seat_cell(*x)), "{off:?}");
    }

    #[test]
    fn an_interior_partition_blocks_a_row_either_side_but_for_its_door() {
        let m: city_contracts::Manifest = serde_json::from_value(serde_json::json!({
            "schema_version": 2,
            "catalogue": 1,
            "city": {"id": "city:i", "name": "I", "entrances": [{"x": 0, "z": 600}], "districts": [
                {"id": "district:i", "name": "I", "facilities": [
                    {"id": "facility:hall", "name": "Hall", "kind": "guild-hall", "rooms": [
                        {"id": "room:a", "name": "A", "capacity": 2,
                         "rect": {"x": 0, "z": 0, "w": 400, "d": 400},
                         "doors": [{"id": "door:a-b", "to": "room:b", "pos": {"x": 400, "z": 200}, "transit": {"min": 1, "max": 1}},
                                   {"id": "door:a-p", "to": "room:p", "pos": {"x": 200, "z": 400}, "transit": {"min": 1, "max": 1}}]},
                        {"id": "room:b", "name": "B", "capacity": 2,
                         "rect": {"x": 400, "z": 0, "w": 400, "d": 400},
                         "doors": [{"id": "door:b-a", "to": "room:a", "pos": {"x": 400, "z": 200}, "transit": {"min": 1, "max": 1}}]}
                    ]},
                    {"id": "facility:plaza", "name": "Plaza", "rooms": [
                        {"id": "room:p", "name": "P", "capacity": 20, "outdoor": true,
                         "rect": {"x": 0, "z": 400, "w": 800, "d": 400},
                         "doors": [{"id": "door:p-a", "to": "room:a", "pos": {"x": 200, "z": 400}, "transit": {"min": 1, "max": 1}}]}
                    ]}
                ]}
            ]}
        }))
        .unwrap();
        let g = NavGrid::build(&PlaceIndex::build(&m).unwrap());
        let at = |x, z| g.cell_of(Point { x, z });
        for z in (12..400).step_by(25) {
            let opening = (150..250).contains(&z);
            assert_eq!(
                g.walkable(at(387, z)),
                opening,
                "west of the partition at z {z}"
            );
            assert_eq!(
                g.walkable(at(412, z)),
                opening,
                "east of the partition at z {z}"
            );
            assert!(g.walkable(at(362, z)) && g.walkable(at(437, z)), "z {z}");
        }
        assert!(g.can_step(at(387, 212), at(412, 212)), "through the door");
    }
}
