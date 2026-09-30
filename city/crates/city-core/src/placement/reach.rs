//! Where the entrances reach, and whether a change cut a walk: the local
//! proof, and the whole-grid comparison it stands in for.

use super::*;

/// The cells a walk from the district's entrances starts from: each
/// entrance's walkable cell, or with none, the first outdoor room.
fn reach_sources(index: &PlaceIndex, grid: &NavGrid) -> Vec<Cell> {
    if index.entrances.is_empty() {
        index
            .rooms
            .values()
            .find(|r| r.outdoor && r.rect.is_some())
            .map(|r| grid.cells_in(&r.id))
            .unwrap_or_default()
    } else {
        index
            .entrances
            .iter()
            .filter_map(|e| grid.snap(*e))
            .collect()
    }
}

/// Which cells a walk from the district's entrances reaches, kept up to
/// date as placements change, so a moved or new placement's anchors are
/// checked without searching the whole grid.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Reach {
    cells: Vec<bool>,
}

impl Reach {
    pub fn of(index: &PlaceIndex, grid: &NavGrid) -> Reach {
        Reach {
            cells: grid.reach_from(&reach_sources(index, grid)),
        }
    }

    /// [`Reach::of`], read off `walks`, the grid's [`NavGrid::walks`],
    /// which a whole-grid comparison has labelled anyway.
    pub fn of_walks(index: &PlaceIndex, grid: &NavGrid, walks: &[u32]) -> Reach {
        Reach {
            cells: grid.reach_in(walks, &reach_sources(index, grid)),
        }
    }

    pub fn reaches(&self, grid: &NavGrid, c: Cell) -> bool {
        grid.slot(c).is_some_and(|k| self.cells[k])
    }

    /// Marks the cells a change newly reaches, spreading from the reached
    /// cells beside `changed`, and unmarks the newly blocked ones. Right
    /// only when the change cut nothing (see `may_disconnect`), since cells
    /// it cut off are not unmarked. Returns each slot it flipped, to undo.
    pub(super) fn follow(&mut self, grid: &NavGrid, changed: &[Cell]) -> Vec<usize> {
        let mut flipped = Vec::new();
        for c in changed {
            let k = grid.slot(*c).expect("changed cells are on the grid");
            if !grid.walkable(*c) && self.cells[k] {
                self.cells[k] = false;
                flipped.push(k);
            }
        }
        let mut open: std::collections::VecDeque<Cell> = grid
            .around(changed)
            .into_iter()
            .filter(|c| self.reaches(grid, *c) && !grid.is_seat_cell(*c))
            .collect();
        while let Some(c) = open.pop_front() {
            for (di, dj) in crate::nav::NEIGHBOURS {
                let n = Cell {
                    i: c.i + di,
                    j: c.j + dj,
                };
                if let Some(k) = grid.slot(n)
                    && !self.cells[k]
                    && grid.can_step(c, n)
                {
                    self.cells[k] = true;
                    flipped.push(k);
                    if !grid.is_seat_cell(n) {
                        open.push_back(n);
                    }
                }
            }
        }
        flipped
    }

    /// Flips back the slots [`Reach::follow`] flipped.
    pub(super) fn flip_back(&mut self, slots: Vec<usize>) {
        for k in slots {
            self.cells[k] = !self.cells[k];
        }
    }
}

/// How far round the cells a change blocked the local proof of
/// `may_disconnect` looks for a way round them (cm).
const LOCAL_REACH: i32 = 400;

/// Whether blocking `blocked` might have cut a walk, judged near them:
/// `false` proves it cut none, since every walkable cell beside them is
/// still joined to every other, within a few metres, and every seat beside
/// them still has a way in; `true` says only that the whole grid must be
/// compared. A change near an entrance, whose cell may have moved, or one
/// that takes the last cells a room had near it, is always compared.
pub(super) fn may_disconnect(
    index: &PlaceIndex,
    grid: &NavGrid,
    blocked: &[Cell],
    changed: &[Cell],
) -> bool {
    let near_entrance = index.entrances.iter().any(|e| {
        let at = grid.cell_of(*e);
        changed
            .iter()
            .any(|c| (c.i - at.i).abs().max((c.j - at.j).abs()) <= 2)
    });
    if near_entrance {
        return true;
    }
    let ring: Vec<Cell> = grid
        .around(blocked)
        .into_iter()
        .filter(|c| grid.walkable(*c))
        .collect();
    let (seats, cells): (Vec<Cell>, Vec<Cell>) =
        ring.into_iter().partition(|c| grid.is_seat_cell(*c));
    let rooms_left: BTreeSet<&PlaceId> = cells.iter().filter_map(|c| grid.room_at(*c)).collect();
    if blocked
        .iter()
        .filter_map(|c| grid.floor_room_at(*c))
        .any(|r| !rooms_left.contains(r))
    {
        return true;
    }
    let (mut x0, mut z0, mut x1, mut z1) = (i32::MAX, i32::MAX, i32::MIN, i32::MIN);
    for c in blocked {
        let p = grid.centre(*c);
        (x0, z0, x1, z1) = (x0.min(p.x), z0.min(p.z), x1.max(p.x), z1.max(p.z));
    }
    let window = Rect {
        x: x0 - LOCAL_REACH,
        z: z0 - LOCAL_REACH,
        w: x1 - x0 + 2 * LOCAL_REACH,
        d: z1 - z0 + 2 * LOCAL_REACH,
    };
    !grid.joined_within(&cells, &seats, window)
}

/// The cells nothing may cut off: every seat, and every standing anchor of
/// every placement and seat's furniture.
fn kept_open(index: &PlaceIndex, grid: &NavGrid) -> Vec<Cell> {
    let district = laid_out(index);
    let seats = index
        .rooms
        .values()
        .filter(|r| r.rect.is_some() && r.level == 0)
        .flat_map(|r| r.seats.iter().filter_map(|s| s.pos));
    let anchors = index
        .placements
        .iter()
        .chain(&index.seat_furniture)
        .filter(|p| p.level == 0 && Some(&p.district) == district)
        .flat_map(anchor_points)
        .map(|(at, _)| at);
    seats.chain(anchors).map(|p| grid.cell_of(p)).collect()
}

/// Whether the change the grid went through, from `before` (the links it
/// had) to `after` (the links it has), cut a walk: two rooms, or a room and
/// an entrance, joined before and not now, or a seat, an anchor, or one of
/// `people`'s cells the entrances reached that they no longer reach.
pub(super) fn cut_anything(
    index: &PlaceIndex,
    grid: &NavGrid,
    people: &BTreeSet<Cell>,
    before: &BTreeSet<(usize, usize)>,
    after: &BTreeSet<(usize, usize)>,
    reach_before: &Reach,
    reach_after: &Reach,
) -> bool {
    !before.is_subset(after)
        || kept_open(index, grid)
            .into_iter()
            .chain(people.iter().copied())
            .any(|c| {
                reach_before.reaches(grid, c) && grid.walkable(c) && !reach_after.reaches(grid, c)
            })
}

/// The local proof `apply` uses to skip the whole-grid comparison never
/// decides differently from that comparison.
#[cfg(test)]
mod proof_tests {
    use super::super::apply::apply_checked;
    use super::*;
    use crate::index::fixtures::{layout_streets, line_base};
    use proptest::prelude::*;

    const KINDS: [&str; 8] = [
        "bollard",
        "planter",
        "street-tree",
        "bookshelf",
        "bench",
        "workbench",
        "great-tree",
        "block-house",
    ];

    /// (what, which, kind, x, z, facing, size)
    type Raw = (u8, u8, u8, u16, u16, u16, u8);

    fn change(raw: &Raw, n: usize, ids: &[PlaceId], extent: Rect) -> Change {
        let (what, which, kind, x, z, facing, size) = *raw;
        let kind = KINDS[usize::from(kind) % KINDS.len()];
        let snap = Catalogue::builtin().kind(kind).expect("a kind").snap;
        let at = Point {
            x: (extent.x + i32::from(x) % extent.w).div_euclid(snap) * snap,
            z: (extent.z + i32::from(z) % extent.d).div_euclid(snap) * snap,
        };
        let facing = i32::from(facing) % 360;
        let target = ids
            .get(usize::from(which) % ids.len().max(1))
            .cloned()
            .unwrap_or_else(|| "placement:never".into());
        match what % 5 {
            0..=2 => Change::Place(Placement {
                id: format!("placement:p{n:02}").into(),
                kind: kind.into(),
                at,
                facing,
                size: (kind == "block-house").then_some(city_contracts::Size {
                    w: 200 + 200 * i32::from(size % 8),
                    d: 200 + 200 * i32::from(size / 32),
                }),
                ..Default::default()
            }),
            3 => Change::Move {
                id: target,
                at,
                facing,
            },
            _ => Change::Remove { id: target },
        }
    }

    proptest! {
        #![proptest_config(ProptestConfig { cases: 128, .. ProptestConfig::default() })]

        #[test]
        fn the_local_proof_agrees_with_the_whole_grid(
            streets in any::<bool>(),
            raw in prop::collection::vec(
                (any::<u8>(), any::<u8>(), any::<u8>(), any::<u16>(), any::<u16>(), any::<u16>(), any::<u8>()),
                1..=30,
            ),
            standing in prop::collection::vec((any::<u16>(), any::<u16>()), 0..6),
        ) {
            let m = if streets { layout_streets() } else { line_base() };
            let mut index = PlaceIndex::build(&m).expect("valid");
            let mut grid = NavGrid::build(&index);
            let tracks = crate::transit::track_cells(&index, &grid);
            let mut reach = Reach::of(&index, &grid);
            let extent = grid.extent();
            let mut ids: Vec<PlaceId> = Vec::new();
            // A few people standing about, whom no change may shut in.
            let people: BTreeSet<Cell> = standing
                .iter()
                .map(|(i, j)| Cell {
                    i: i32::from(*i) % (extent.w / CELL),
                    j: i32::from(*j) % (extent.d / CELL),
                })
                .filter(|c| grid.walkable(*c))
                .collect();
            for (n, r) in raw.iter().enumerate() {
                let c = change(r, n, &ids, extent);
                let (mut index2, mut grid2, mut reach2) = (index.clone(), grid.clone(), reach.clone());
                let quick = apply_checked(
                    Layout { index: &mut index, grid: &mut grid, tracks: &tracks, reach: &mut reach, people: &people },
                    Catalogue::builtin(), &c, &|_, _| Ok(()), false,
                );
                let whole = apply_checked(
                    Layout { index: &mut index2, grid: &mut grid2, tracks: &tracks, reach: &mut reach2, people: &people },
                    Catalogue::builtin(), &c, &|_, _| Ok(()), true,
                );
                prop_assert_eq!(&quick, &whole, "{:?}", c);
                prop_assert_eq!(&index, &index2);
                prop_assert_eq!(&reach, &reach2);
                if quick.is_ok() {
                    match &c {
                        Change::Place(p) => ids.push(p.id.clone()),
                        Change::Remove { id } => ids.retain(|x| x != id),
                        Change::Move { .. } => {}
                    }
                }
            }
        }
    }
}
