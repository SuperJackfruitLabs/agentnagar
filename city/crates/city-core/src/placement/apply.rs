//! Runtime placement changes: one change carried out on a layout, its
//! grid rebuilt only where the footprints moved.

use super::reach::{cut_anything, may_disconnect};
use super::*;

/// How to put [`Reach`] back when a change is refused after it moved.
enum ReachUndo {
    /// Flip these slots back.
    Flips(Vec<usize>),
    /// Restore this whole.
    Whole(Reach),
}

/// A last check the caller makes on the cells a change blocked or opened,
/// on the grid as it would be: the world refuses one that covers someone.
pub type Allow<'a> = dyn Fn(&NavGrid, &[Cell]) -> Result<(), RejectReason> + 'a;

/// A change to the laid-out district's placements, as a command asks it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Change {
    Place(Placement),
    Move { id: PlaceId, at: Point, facing: i32 },
    Remove { id: PlaceId },
}

/// What a runtime change works on: the index, the grid built from it, the
/// cells the trams run over, and where the entrances reach. Each is left
/// as the others require, whether the change is made or refused. `people`
/// are the cells people stand on or walk to, which a change may not cut
/// off from the entrances.
pub struct Layout<'a> {
    pub index: &'a mut PlaceIndex,
    pub grid: &'a mut NavGrid,
    pub tracks: &'a BTreeSet<Cell>,
    pub reach: &'a mut Reach,
    pub people: &'a BTreeSet<Cell>,
}

/// Whether a new placement's ID would name something already there.
fn id_in_use(index: &PlaceIndex, id: &PlaceId) -> bool {
    index.placed(id).is_some()
        || index.lines.contains_key(id)
        || index
            .lines
            .values()
            .any(|l| l.stops.iter().any(|s| &s.id == id))
        || index.rooms.values().any(|r| {
            &r.id == id
                || &r.facility == id
                || &r.district == id
                || r.seats
                    .iter()
                    .any(|s| &s.id == id || s.pod.as_ref() == Some(id))
                || r.door_list.iter().any(|d| &d.id == id)
        })
}

/// The cells within the body clearance of `placed`, as the grid's region
/// they lie in; none when they lie wholly off it.
fn region_of(grid: &NavGrid, placed: &[&Placed]) -> Option<Rect> {
    let e = grid.extent();
    let (mut x0, mut z0, mut x1, mut z1) = (i64::MAX, i64::MAX, i64::MIN, i64::MIN);
    for p in placed {
        let (a, b, c, d) = footprint::bounds_wide(p, MARGIN);
        (x0, z0, x1, z1) = (x0.min(a), z0.min(b), x1.max(c), z1.max(d));
    }
    let clip =
        |v: i64, lo: i32, len: i32| v.clamp(i64::from(lo), i64::from(lo) + i64::from(len)) as i32;
    let (x0, x1) = (clip(x0, e.x, e.w), clip(x1, e.x, e.w));
    let (z0, z1) = (clip(z0, e.z, e.d), clip(z1, e.z, e.d));
    (x0 < x1 && z0 < z1).then_some(Rect {
        x: x0,
        z: z0,
        w: x1 - x0,
        d: z1 - z0,
    })
}

/// Carries out one placement change on a layout, between ticks: the one
/// function runtime changes go through, checking each by the same
/// [`validate_one`] that loading does. Only the cells within the old and
/// new footprints' bounds, grown by the body clearance, are rebuilt.
///
/// The change is refused, and the layout left exactly as it was, when:
/// - it names no placement there is (`UnknownPlacement`);
/// - it places one whose ID is not `placement:<slug>`, or is in use
///   (`PlacementInvalid`);
/// - it fails validation, or leaves a room too small, or leaves one of its
///   own anchors where the entrances do not reach (`PlacementInvalid`);
/// - `allow` refuses the cells it changed, which the world uses to keep
///   the cells people stand on;
/// - it cuts a walk, or shuts someone in, or off from where they are
///   going (`PlacementDisconnects`; see `cut_anything`).
///
/// Returns the cells whose walkability changed, in row then column order.
pub fn apply(
    layout: Layout<'_>,
    cat: &'static Catalogue,
    change: &Change,
    allow: &Allow<'_>,
) -> Result<Vec<Cell>, RejectReason> {
    apply_checked(layout, cat, change, allow, false)
}

/// [`apply`], also saying whether the change was judged against the whole
/// grid, because the local proof could not settle it. The two paths have
/// budgets of their own (the design's amendments), and `scale_district`
/// times each against its own; nothing else needs to know.
#[doc(hidden)]
pub fn apply_saying_path(
    layout: Layout<'_>,
    cat: &'static Catalogue,
    change: &Change,
    allow: &Allow<'_>,
) -> (Result<Vec<Cell>, RejectReason>, bool) {
    let mut whole_grid = false;
    let outcome = apply_judged(layout, cat, change, allow, false, &mut whole_grid);
    (outcome, whole_grid)
}

/// [`apply`], judging every change that blocks a cell against the whole
/// grid when `exhaustive`, never by the local proof: the tests hold the one
/// to the other.
pub(super) fn apply_checked(
    layout: Layout<'_>,
    cat: &'static Catalogue,
    change: &Change,
    allow: &Allow<'_>,
    exhaustive: bool,
) -> Result<Vec<Cell>, RejectReason> {
    apply_judged(layout, cat, change, allow, exhaustive, &mut false)
}

/// [`apply_checked`], setting `whole_grid` when the change was compared
/// against the whole grid.
fn apply_judged(
    layout: Layout<'_>,
    cat: &'static Catalogue,
    change: &Change,
    allow: &Allow<'_>,
    exhaustive: bool,
    whole_grid: &mut bool,
) -> Result<Vec<Cell>, RejectReason> {
    let Layout {
        index,
        grid,
        tracks,
        reach,
        people,
    } = layout;
    let id = match change {
        Change::Place(p) => &p.id,
        Change::Move { id, .. } | Change::Remove { id } => id,
    };
    let invalid = |code: &str, place: &PlaceId| RejectReason::PlacementInvalid {
        code: code.into(),
        place: place.clone(),
    };
    let district = laid_out(index)
        .cloned()
        .ok_or_else(|| invalid("no-layout", id))?;
    let (old, record) = match change {
        Change::Place(p) => {
            if !is_placement_id(&p.id) {
                return Err(invalid("bad-placement-id", id));
            }
            if id_in_use(index, &p.id) {
                return Err(invalid("duplicate-id", id));
            }
            (None, Some(p.clone()))
        }
        Change::Move { id, at, facing } => {
            let old = index
                .placements
                .binary_search_by(|p| p.id.cmp(id))
                .map(|k| index.placements[k].clone())
                .map_err(|_| RejectReason::UnknownPlacement)?;
            let moved = Placement {
                at: *at,
                facing: *facing,
                ..old.record.clone()
            };
            (Some(old), Some(moved))
        }
        Change::Remove { id } => (
            Some(
                index
                    .placements
                    .binary_search_by(|p| p.id.cmp(id))
                    .map(|k| index.placements[k].clone())
                    .map_err(|_| RejectReason::UnknownPlacement)?,
            ),
            None,
        ),
    };
    // A moved placement is checked where it goes against everything but
    // itself: validation passes over the placement with its own ID.
    let new = match &record {
        Some(p) => {
            let floor = Floor {
                grid: &*grid,
                tracks,
            };
            let mut issues = Vec::new();
            let accepted = validate_one(index, Some(&floor), cat, &district, p, &mut issues);
            Some(accepted.ok_or_else(|| {
                let first = &issues[0];
                invalid(
                    &first.code,
                    &first.place.as_deref().unwrap_or(id.as_str()).into(),
                )
            })?)
        }
        None => None,
    };
    index.swap_placement(old.as_ref(), new.clone());
    let footprints: Vec<&Placed> = old.iter().chain(&new).map(|p| &p.placed).collect();
    let region = region_of(grid, &footprints);
    let counts = grid.room_cell_counts();
    let changed = region.map_or_else(Vec::new, |r| grid.rebuild_region(index, r));

    let undo = |index: &mut PlaceIndex, grid: &mut NavGrid| {
        index.swap_placement(new.as_ref(), old.clone());
        if let Some(r) = region {
            grid.rebuild_region(index, r);
        }
    };
    let redo = |index: &mut PlaceIndex, grid: &mut NavGrid| {
        index.swap_placement(old.as_ref(), new.clone());
        if let Some(r) = region {
            grid.rebuild_region(index, r);
        }
    };
    let refuse = |index: &mut PlaceIndex, grid: &mut NavGrid, reason| {
        undo(index, grid);
        Err(reason)
    };

    let floor_counts = grid.floor_cell_counts();
    let now = grid.room_cell_counts();
    let too_small = index.rooms.values().find(|room| {
        let kept = now.get(&room.id).copied().unwrap_or(0);
        let had = floor_counts.get(&room.id).copied().unwrap_or(0);
        let needed = room.seats.len().max(room.capacity as usize);
        kept < counts.get(&room.id).copied().unwrap_or(0) && kept < had && kept < needed
    });
    if let Some(room) = too_small {
        let reason = invalid("room-too-small", &room.id);
        return refuse(index, grid, reason);
    }
    if let Err(reason) = allow(grid, &changed) {
        return refuse(index, grid, reason);
    }

    let blocked: Vec<Cell> = changed
        .iter()
        .copied()
        .filter(|c| !grid.walkable(*c))
        .collect();
    let compare =
        !blocked.is_empty() && (exhaustive || may_disconnect(index, grid, &blocked, &changed));
    *whole_grid = compare;
    let reach_undo = if compare {
        // One labelling of the grid's walks gives both the links now and
        // where the entrances reach, the costliest part of this path.
        let walks = grid.walks();
        let after = grid.links_in(&walks, &index.entrances);
        let reach_after = Reach::of_walks(index, grid, &walks);
        drop(walks);
        undo(index, grid);
        let before = grid.room_links(&index.entrances);
        redo(index, grid);
        if cut_anything(index, grid, people, &before, &after, reach, &reach_after) {
            return refuse(index, grid, RejectReason::PlacementDisconnects);
        }
        ReachUndo::Whole(std::mem::replace(reach, reach_after))
    } else if index.entrances.is_empty() {
        // Walks then start from a whole room, whose cells come and go
        // with the change: find the reach afresh.
        ReachUndo::Whole(std::mem::replace(reach, Reach::of(index, grid)))
    } else {
        ReachUndo::Flips(reach.follow(grid, &changed))
    };
    let stranded = new.as_ref().is_some_and(|p| {
        anchor_points(p).any(|(at, _)| {
            let c = grid.cell_of(at);
            !(grid.walkable(c) && reach.reaches(grid, c))
        })
    });
    if stranded {
        match reach_undo {
            ReachUndo::Flips(slots) => reach.flip_back(slots),
            ReachUndo::Whole(before) => *reach = before,
        }
        return refuse(index, grid, invalid("anchor-unreachable", id));
    }
    Ok(changed)
}
/// Placement commands carried out between ticks: the grid follows each
/// change, and refusals leave everything as it was.
#[cfg(test)]
mod change_tests {
    use crate::feed::Feed;
    use crate::index::fixtures::layout_base;
    use crate::invariants::check_world;
    use crate::nav::{Cell, NavGrid};
    use crate::{World, merge, project};
    use city_contracts::*;

    fn feed(entries: Vec<FeedEntry>) -> Feed {
        Feed {
            header: FeedHeader {
                schema_version: 1,
                source: "fixture:test".into(),
                fixture: true,
                description: String::new(),
            },
            entries,
        }
    }

    fn world() -> World {
        World::new(layout_base(), feed(Vec::new()), 7).expect("valid")
    }

    fn placement(id: &str, kind: &str, x: i32, z: i32, facing: i32) -> Placement {
        Placement {
            id: id.into(),
            kind: kind.into(),
            at: Point { x, z },
            facing,
            ..Default::default()
        }
    }

    fn place(p: Placement) -> Command {
        Command::Place {
            placement: p,
            by: None,
        }
    }

    /// Submits `command`, runs the tick it is carried out in, and returns
    /// that tick's events.
    fn run(w: &mut World, command: Command) -> Vec<Event> {
        w.submit(command);
        w.step()
    }

    fn refusal(events: &[Event]) -> Option<RejectReason> {
        events.iter().find_map(|e| match &e.kind {
            EventKind::Rejected { reason, .. } => Some(reason.clone()),
            _ => None,
        })
    }

    fn invalid(code: &str, place: &str) -> Option<RejectReason> {
        Some(RejectReason::PlacementInvalid {
            code: code.into(),
            place: place.into(),
        })
    }

    fn changed(events: &[Event]) -> Option<PlacementChange> {
        events.iter().find_map(|e| match e.kind {
            EventKind::PlacementChanged { change, .. } => Some(change),
            _ => None,
        })
    }

    /// Every cell of `grid`'s extent, as the room it belongs to or none.
    fn cells(grid: &NavGrid) -> Vec<Option<PlaceId>> {
        grid.cells_within(grid.extent())
            .into_iter()
            .map(|c| grid.room_at(c).cloned())
            .collect()
    }

    fn matches_a_fresh_build(w: &World) -> bool {
        cells(w.nav().expect("layout")) == cells(&NavGrid::build(w.index()))
    }

    fn at(w: &World, x: i32, z: i32) -> Cell {
        w.nav().expect("layout").cell_of(Point { x, z })
    }

    fn walkable(w: &World, c: Cell) -> bool {
        w.nav().expect("layout").walkable(c)
    }

    fn placements(w: &World) -> &[Placement] {
        &w.snapshot().manifest.city.districts[0].placements
    }

    fn guild(id: &str) -> OccupantProfile {
        OccupantProfile {
            id: id.into(),
            kind: OccupantKind::GuildAgent,
            display_name: id.into(),
            role: String::new(),
            department: None,
            home: None,
            work: Some("room:p".into()),
            shared_with: Default::default(),
            appearance: Default::default(),
        }
    }

    /// A world with `agent:a` arrived on the plaza and standing still.
    fn with_a_stander() -> World {
        let arrive = FeedEntry {
            at: 1,
            fixture: true,
            command: Command::Arrive {
                occupant: "agent:a".into(),
                profile: Some(guild("agent:a")),
                room: Some("room:p".into()),
                player: false,
            },
        };
        let mut w = World::new(layout_base(), feed(vec![arrive]), 7).expect("valid");
        for _ in 0..40 {
            w.step();
        }
        let a = &w.snapshot().occupants[&CityId::from("agent:a")];
        assert!(a.walk.is_none() && matches!(a.location, Location::InRoom { .. }));
        w
    }

    #[test]
    fn a_bench_is_placed_moved_and_removed() {
        let mut w = world();
        let original = cells(w.nav().unwrap());
        let (back, sit) = (at(&w, 500, 632), at(&w, 500, 600));
        assert!(walkable(&w, back));

        let events = run(
            &mut w,
            place(placement("placement:bench", "bench", 500, 600, 0)),
        );
        assert_eq!(refusal(&events), None);
        assert_eq!(changed(&events), Some(PlacementChange::Placed));
        assert!(!walkable(&w, back), "the bench's back blocks its cell");
        assert!(walkable(&w, sit), "its sit anchor stays open");
        assert!(matches_a_fresh_build(&w));
        assert_eq!(placements(&w).len(), 1);
        let view = project(w.snapshot(), &Viewer::Public);
        assert!(
            view.grid_changes
                .iter()
                .any(|g| (g.i, g.j, g.walkable) == (back.i, back.j, false))
        );
        let nav = w.nav().unwrap();
        assert!(
            view.grid_changes
                .iter()
                .all(|g| nav.walkable(Cell { i: g.i, j: g.j }) == g.walkable)
        );
        w.step();
        assert!(
            project(w.snapshot(), &Viewer::Public)
                .grid_changes
                .is_empty(),
            "the changes are carried on the tick of the change only"
        );

        let events = run(
            &mut w,
            Command::MovePlacement {
                id: "placement:bench".into(),
                at: Point { x: 300, z: 650 },
                facing: 90,
                by: None,
            },
        );
        assert_eq!(refusal(&events), None);
        assert_eq!(changed(&events), Some(PlacementChange::Moved));
        assert!(walkable(&w, back), "the old place is open again");
        let nav = w.nav().unwrap();
        let reopened = project(w.snapshot(), &Viewer::Public).grid_changes;
        assert!(reopened.iter().any(|g| (g.i, g.j) == (back.i, back.j)));
        assert!(
            reopened.iter().all(|g| g.room
                == g.walkable
                    .then(|| nav.room_index(Cell { i: g.i, j: g.j }))
                    .flatten()),
            "a cell that opens names its room, and one that closes none: {reopened:?}"
        );
        assert!(
            !walkable(&w, at(&w, 268, 650)),
            "facing east, its back stands to the west"
        );
        assert!(matches_a_fresh_build(&w));
        assert_eq!(
            (placements(&w)[0].at, placements(&w)[0].facing),
            (Point { x: 300, z: 650 }, 90)
        );

        let events = run(
            &mut w,
            Command::RemovePlacement {
                id: "placement:bench".into(),
                by: None,
            },
        );
        assert_eq!(changed(&events), Some(PlacementChange::Removed));
        assert_eq!(cells(w.nav().unwrap()), original);
        assert!(placements(&w).is_empty());
    }

    #[test]
    fn a_change_that_fails_validation_or_comes_from_a_player_is_refused() {
        let mut w = world();
        let original = cells(w.nav().unwrap());
        let off_snap = placement("placement:planter", "planter", 510, 600, 0);
        let events = run(&mut w, place(off_snap));
        assert_eq!(refusal(&events), invalid("off-snap", "placement:planter"));
        let mut upstairs = placement("placement:planter", "planter", 500, 600, 0);
        upstairs.level = 1;
        let events = run(&mut w, place(upstairs));
        assert_eq!(
            refusal(&events),
            invalid("level-not-supported", "placement:planter")
        );
        let events = run(
            &mut w,
            Command::MovePlacement {
                id: "placement:nothing".into(),
                at: Point { x: 500, z: 600 },
                facing: 0,
                by: None,
            },
        );
        assert_eq!(refusal(&events), Some(RejectReason::UnknownPlacement));
        let events = run(
            &mut w,
            Command::Place {
                placement: placement("placement:planter", "planter", 500, 600, 0),
                by: Some("person:you".into()),
            },
        );
        assert_eq!(refusal(&events), Some(RejectReason::NotOperator));
        assert_eq!(
            events[0].occupant.as_ref().map(|o| o.as_str()),
            Some("person:you"),
            "the player is told"
        );
        assert!(
            events
                .iter()
                .all(|e| changed(std::slice::from_ref(e)).is_none())
        );
        assert_eq!(cells(w.nav().unwrap()), original);
        assert!(placements(&w).is_empty());

        let planter = placement("placement:planter", "planter", 500, 600, 0);
        assert_eq!(refusal(&run(&mut w, place(planter.clone()))), None);
        let events = run(&mut w, place(planter));
        assert_eq!(
            refusal(&events),
            invalid("duplicate-id", "placement:planter"),
            "an ID already in use"
        );
        for bad in [
            "planter",
            "placement:",
            "placement:Big Planter",
            "seat:planter",
        ] {
            let events = run(&mut w, place(placement(bad, "planter", 700, 600, 0)));
            assert_eq!(
                refusal(&events),
                invalid("bad-placement-id", bad),
                "{bad} is not placement:<slug>"
            );
        }
    }

    #[test]
    fn a_placement_over_someone_standing_is_refused() {
        let mut w = with_a_stander();
        let original = cells(w.nav().unwrap());
        let pos = w.snapshot().occupants[&CityId::from("agent:a")]
            .pos
            .expect("standing");
        let bollard = placement(
            "placement:bollard",
            "bollard",
            pos.x.div_euclid(25) * 25,
            pos.z.div_euclid(25) * 25,
            0,
        );
        let events = run(&mut w, place(bollard));
        assert_eq!(
            refusal(&events),
            Some(RejectReason::PlacementCoversOccupant)
        );
        assert_eq!(cells(w.nav().unwrap()), original);
        assert!(placements(&w).is_empty());
    }

    /// Moves `agent:a`, standing still, to the centre of cell `(i, j)`.
    fn stand_at(w: &mut World, i: i32, j: i32) {
        let centre = w.nav().unwrap().centre(Cell { i, j });
        let a = w
            .state
            .occupants
            .get_mut(&CityId::from("agent:a"))
            .expect("agent:a");
        (a.pos, a.walk, a.goal) = (Some(centre), None, None);
    }

    /// A planter turned 45° across the plaza's south-east corner: it shuts
    /// the corner cell (31, 31) off from the rest of the plaza, though the
    /// plaza itself stays joined to every room and the entrance.
    fn across_the_corner() -> Command {
        place(placement("placement:planter", "planter", 725, 725, 45))
    }

    #[test]
    fn a_placement_shutting_someone_in_a_corner_is_refused() {
        let mut w = with_a_stander();
        stand_at(&mut w, 31, 31);
        let original = cells(w.nav().unwrap());
        let events = run(&mut w, across_the_corner());
        assert_eq!(refusal(&events), Some(RejectReason::PlacementDisconnects));
        assert_eq!(cells(w.nav().unwrap()), original);
        assert!(placements(&w).is_empty());

        // With no one in the corner the same planter is taken, and the
        // corner is indeed shut off.
        stand_at(&mut w, 16, 24);
        assert_eq!(refusal(&run(&mut w, across_the_corner())), None);
        let nav = w.nav().unwrap();
        let entrance = nav.snap(Point { x: 0, z: 600 }).unwrap();
        assert!(nav.walkable(Cell { i: 31, j: 31 }));
        assert!(
            nav.path_to(entrance, Cell { i: 31, j: 31 }, &|_| false)
                .is_none()
        );
    }

    #[test]
    fn a_placement_sealing_off_where_a_walker_goes_is_refused() {
        let mut w = with_a_stander();
        stand_at(&mut w, 16, 24);
        let a = CityId::from("agent:a");
        let corner = w.nav().unwrap().centre(Cell { i: 31, j: 31 });
        run(
            &mut w,
            Command::Go {
                occupant: a.clone(),
                to: Target::Point { pos: corner },
            },
        );
        let walk = w.snapshot().occupants[&a].walk.clone().expect("walking");
        assert_eq!(walk.path.last(), Some(&corner));
        let original = cells(w.nav().unwrap());
        let events = run(&mut w, across_the_corner());
        assert_eq!(refusal(&events), Some(RejectReason::PlacementDisconnects));
        assert_eq!(cells(w.nav().unwrap()), original);
    }

    #[test]
    fn a_placement_cutting_a_street_off_from_the_plaza_is_refused() {
        // The east street meets the rest of the city only along the
        // plaza's east edge; a 10 m workbench turned along that edge parts
        // the two rooms.
        let mut w = World::new(
            crate::index::fixtures::layout_streets(),
            feed(Vec::new()),
            7,
        )
        .expect("valid");
        let original = cells(w.nav().unwrap());
        let events = run(
            &mut w,
            place(placement("placement:workbench", "workbench", 825, 600, 90)),
        );
        assert_eq!(refusal(&events), Some(RejectReason::PlacementDisconnects));
        assert_eq!(cells(w.nav().unwrap()), original);
        let ids: Vec<&str> = placements(&w).iter().map(|p| p.id.as_str()).collect();
        assert_eq!(ids, ["placement:house"], "only the street's house");
    }

    #[test]
    fn a_placement_cutting_the_workshop_off_from_the_entrance_is_refused() {
        // A 10 m workbench across the plaza, just south of the door's
        // span: the workshop keeps the plaza's strip by its door, but no
        // longer the entrance on the plaza's west edge.
        let mut w = world();
        let original = cells(w.nav().unwrap());
        let events = run(
            &mut w,
            place(placement("placement:workbench", "workbench", 400, 525, 0)),
        );
        assert_eq!(refusal(&events), Some(RejectReason::PlacementDisconnects));
        assert_eq!(cells(w.nav().unwrap()), original);
        assert!(placements(&w).is_empty());
    }

    #[test]
    fn a_walker_whose_path_a_new_placement_crosses_replans_and_arrives() {
        let mut w = with_a_stander();
        let a = CityId::from("agent:a");
        // The plaza's far corner from where it stands.
        let pos = w.snapshot().occupants[&a].pos.expect("standing");
        let target = Point {
            x: if pos.x > 400 { 112 } else { 762 },
            z: if pos.z > 600 { 462 } else { 762 },
        };
        run(
            &mut w,
            Command::Go {
                occupant: a.clone(),
                to: Target::Point { pos: target },
            },
        );
        let path = w.snapshot().occupants[&a]
            .walk
            .as_ref()
            .expect("walking")
            .path
            .clone();
        assert!(path.len() > 10, "a walk long enough to cross: {path:?}");
        let ahead = path[8];
        let goal = *path.last().expect("a path");
        let bollard = placement(
            "placement:bollard",
            "bollard",
            ahead.x.div_euclid(25) * 25,
            ahead.z.div_euclid(25) * 25,
            0,
        );
        w.submit(place(bollard));
        let mut arrived = false;
        for _ in 0..60 {
            let before = w.snapshot().clone();
            let events = w.step();
            assert_eq!(refusal(&events), None);
            let found = check_world(&before, &w, &events);
            assert!(found.is_empty(), "{found:?}");
            let o = &w.snapshot().occupants[&a];
            let nav = w.nav().unwrap();
            if let Some(walk) = &o.walk {
                assert!(
                    walk.path.iter().all(|p| nav.walkable(nav.cell_of(*p))),
                    "the walk goes round the bollard"
                );
            }
            if o.walk.is_none() && o.pos == Some(goal) {
                arrived = true;
                break;
            }
        }
        assert!(!walkable(&w, at(&w, ahead.x, ahead.z)));
        assert!(arrived, "it went round and arrived");
    }

    #[test]
    fn a_run_with_placement_commands_replays_byte_for_byte() {
        let arrive = |at, id: &str| FeedEntry {
            at,
            fixture: true,
            command: Command::Arrive {
                occupant: id.into(),
                profile: Some(guild(id)),
                room: Some("room:p".into()),
                player: false,
            },
        };
        let original = feed(vec![arrive(1, "agent:a"), arrive(4, "agent:b")]);
        let mut w = World::new(layout_base(), original.clone(), 11).expect("valid");
        let mut log = Vec::new();
        for t in 1..=40u64 {
            match t {
                3 => w.submit(place(placement("placement:bench", "bench", 500, 700, 0))),
                9 => w.submit(place(placement(
                    "placement:lamp",
                    "street-lamp",
                    650,
                    500,
                    0,
                ))),
                14 => w.submit(Command::MovePlacement {
                    id: "placement:bench".into(),
                    at: Point { x: 300, z: 700 },
                    facing: 180,
                    by: None,
                }),
                20 => w.submit(place(placement(
                    "placement:workbench",
                    "workbench",
                    400,
                    525,
                    0,
                ))),
                27 => w.submit(Command::RemovePlacement {
                    id: "placement:lamp".into(),
                    by: None,
                }),
                _ => {}
            }
            log.extend(w.step());
        }
        assert!(
            log.iter()
                .filter(|e| matches!(e.kind, EventKind::PlacementChanged { .. }))
                .count()
                >= 3
        );
        let replayed = merge(original, w.input_log_feed()).unwrap();
        let mut again = World::new(layout_base(), replayed, 11).unwrap();
        let log2: Vec<Event> = (0..40).flat_map(|_| again.step()).collect();
        assert_eq!(
            serde_json::to_string(&log).unwrap(),
            serde_json::to_string(&log2).unwrap()
        );
        assert_eq!(
            serde_json::to_string(w.snapshot()).unwrap(),
            serde_json::to_string(again.snapshot()).unwrap()
        );
        assert!(matches_a_fresh_build(&again));
    }
}
