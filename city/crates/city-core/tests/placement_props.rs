//! Placement changes at runtime: after any sequence of them the grid, the
//! walking fields and the entrances' reach are what a fresh build gives,
//! and the scale the vision needs is met.

use city_contracts::*;
use city_core::invariants::check_world;
use city_core::nav::{Cell, NavGrid};
use city_core::placement::{self, Change, Layout, Reach};
use city_core::{Feed, PlaceIndex, World, validate};
use proptest::prelude::*;
use std::collections::{BTreeMap, BTreeSet};
use std::time::{Duration, Instant};

/// Kinds a generated command may place: fixtures, planting, seats with
/// anchors, a stand anchor, and the sized block, up to 40 by 30 m.
const KINDS: [&str; 10] = [
    "bollard",
    "street-lamp",
    "planter",
    "shrub",
    "street-tree",
    "bookshelf",
    "bench",
    "desk",
    "tram-shelter",
    "block-house",
];

fn room(id: &str, rect: Rect, outdoor: bool) -> Room {
    Room {
        id: id.into(),
        name: id.into(),
        capacity: 4,
        template: Some(if outdoor { "ground" } else { "workshop" }.into()),
        outdoor,
        rect: Some(rect),
        ..Default::default()
    }
}

fn door(id: String, to: &str, x: i32, z: i32) -> Door {
    Door {
        id: id.into(),
        to: to.into(),
        transit: TickRange { min: 1, max: 1 },
        pos: Some(Point { x, z }),
        width: None,
    }
}

/// A row of workshops, each with a door onto the open plaza below them and
/// a desk seat or two, and an open street east of both, joined to the
/// plaza along their shared edge. The workshops may be a guild hall, and
/// the seats furnished from the catalogue, where the layout stays valid.
fn layout(widths: &[i32], depth: i32, hall: bool, furnish: bool) -> Manifest {
    let mut x = 0;
    let mut workshops = Vec::new();
    let mut plaza_doors = Vec::new();
    for (n, w) in widths.iter().map(|w| w * 100).enumerate() {
        let id = format!("room:{n}");
        let mut r = room(&id, Rect { x, z: 0, w, d: 400 }, false);
        r.doors = vec![door(format!("door:{n}-p"), "room:p", x + w / 2, 400)];
        plaza_doors.push(door(format!("door:p-{n}"), &id, x + w / 2, 400));
        r.seats = (0..(w / 300) as usize)
            .map(|k| Seat {
                id: format!("seat:{n}:{k}").into(),
                pos: Some(Point {
                    x: x + 100 + 300 * k as i32,
                    z: 150,
                }),
                facing: Some(180),
                kind: Some("desk".into()),
                ..Default::default()
            })
            .collect();
        workshops.push(r);
        x += w;
    }
    let mut plaza = room(
        "room:p",
        Rect {
            x: 0,
            z: 400,
            w: x,
            d: depth,
        },
        true,
    );
    plaza.doors = plaza_doors;
    let street = room(
        "room:street",
        Rect {
            x,
            z: 0,
            w: 600,
            d: 400 + depth,
        },
        true,
    );
    let mut m = Manifest {
        schema_version: MANIFEST_SCHEMA_VERSION,
        city: City {
            id: "city:g".into(),
            name: "G".into(),
            districts: vec![District {
                id: "district:g".into(),
                name: "G".into(),
                facilities: vec![
                    Facility {
                        id: "facility:hall".into(),
                        name: "Hall".into(),
                        rooms: workshops,
                        ..Default::default()
                    },
                    Facility {
                        id: "facility:ground".into(),
                        name: "Ground".into(),
                        rooms: vec![plaza, street],
                        ..Default::default()
                    },
                ],
                placements: Vec::new(),
            }],
            entrances: vec![Point {
                x: 0,
                z: 400 + depth / 2,
            }],
            arrivals: Arrivals::Direct,
        },
        clock: Some(Clock {
            ticks_per_day: 600,
            start_minute: 420,
        }),
        seat_policy: SeatPolicyName::DepartmentFirst,
        occupants: Vec::new(),
        lines: Vec::new(),
        scenery: Vec::new(),
        weather: None,
        catalogue: Some(1),
    };
    if !furnish || !validate(&m).valid {
        let seats = m.city.districts[0].facilities[0]
            .rooms
            .iter_mut()
            .flat_map(|r| r.seats.iter_mut());
        for seat in seats {
            seat.kind = None;
        }
    }
    if hall {
        m.city.districts[0].facilities[0].kind = Some("guild-hall".into());
        if !validate(&m).valid {
            m.city.districts[0].facilities[0].kind = None;
        }
    }
    assert!(validate(&m).valid, "{:?}", validate(&m));
    m
}

/// (what, which, kind, x, z, facing, size)
type RawCommand = (u8, u8, u8, u16, u16, u16, (u8, u8));

/// A placement command from raw values, over `m`'s extent: a new
/// placement, or a move or removal of one placed so far (by `ids`), or of
/// one that was never placed.
fn command(raw: &RawCommand, n: usize, ids: &[PlaceId], width: i32, depth: i32) -> Command {
    let (what, which, kind, x, z, facing, (w, d)) = *raw;
    let kind = KINDS[usize::from(kind) % KINDS.len()];
    let snap = Catalogue::builtin().kind(kind).expect("a kind").snap;
    let at = Point {
        x: (i32::from(x) % (width + 400) - 200).div_euclid(snap) * snap,
        z: (i32::from(z) % (depth + 400) - 200).div_euclid(snap) * snap,
    };
    let facing = i32::from(facing) % 360;
    let target = if ids.is_empty() {
        PlaceId::from("placement:never")
    } else {
        ids[usize::from(which) % ids.len()].clone()
    };
    match what % 4 {
        0 | 1 => Command::Place {
            placement: Placement {
                id: format!("placement:g{n:02}").into(),
                kind: kind.into(),
                at,
                facing,
                size: (kind == "block-house").then_some(Size {
                    w: (1 + i32::from(w) % 20) * 200,
                    d: (1 + i32::from(d) % 15) * 200,
                }),
                ..Default::default()
            },
            by: None,
        },
        2 => Command::MovePlacement {
            id: target,
            at,
            facing,
            by: None,
        },
        _ => Command::RemovePlacement {
            id: target,
            by: None,
        },
    }
}

/// Every cell of `grid`'s extent, as the room it belongs to or none.
fn cells(grid: &NavGrid) -> Vec<Option<PlaceId>> {
    grid.cells_within(grid.extent())
        .into_iter()
        .map(|c| grid.room_at(c).cloned())
        .collect()
}

fn guild(id: &str, room: &str) -> OccupantProfile {
    OccupantProfile {
        id: id.into(),
        kind: OccupantKind::GuildAgent,
        display_name: id.into(),
        role: String::new(),
        department: None,
        home: None,
        work: Some(room.into()),
        shared_with: Default::default(),
        appearance: Default::default(),
    }
}

/// Three agents arriving over the first ticks, for placements to meet.
fn arrivals() -> Feed {
    let entries = [
        ("agent:a", "room:p"),
        ("agent:b", "room:0"),
        ("agent:c", "room:p"),
    ]
    .iter()
    .enumerate()
    .map(|(k, (id, room))| FeedEntry {
        at: 1 + k as u64,
        fixture: true,
        command: Command::Arrive {
            occupant: (*id).into(),
            profile: Some(guild(id, room)),
            room: Some((*room).into()),
            player: false,
        },
    })
    .collect();
    Feed {
        header: FeedHeader {
            schema_version: 1,
            source: "fixture:placement-props".into(),
            fixture: true,
            description: String::new(),
        },
        entries,
    }
}

fn scenario() -> impl Strategy<Value = (Manifest, Vec<RawCommand>)> {
    let raw = (
        any::<u8>(),
        any::<u8>(),
        any::<u8>(),
        any::<u16>(),
        any::<u16>(),
        any::<u16>(),
        (any::<u8>(), any::<u8>()),
    );
    (
        prop::collection::vec(3i32..=8, 1..=3),
        (8i32..=20).prop_map(|d| d * 25),
        any::<bool>(),
        any::<bool>(),
        prop::collection::vec(raw, 1..=40),
    )
        .prop_map(|(widths, depth, hall, furnish, raw)| {
            (layout(&widths, depth, hall, furnish), raw)
        })
}

fn extent(m: &Manifest) -> (i32, i32) {
    let rects: Vec<Rect> = m
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .flat_map(|f| &f.rooms)
        .filter_map(|r| r.rect)
        .collect();
    (
        rects.iter().map(|r| r.x + r.w).max().unwrap_or(1),
        rects.iter().map(|r| r.z + r.d).max().unwrap_or(1),
    )
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 48, .. ProptestConfig::default() })]

    /// Placement commands applied tick by tick while people walk: after
    /// each, the grid is the one built from scratch cell for cell, with the
    /// same queue places; every room's walking field and the exit field are
    /// the ones computed afresh; and every invariant holds.
    #[test]
    fn incremental_updates_match_a_fresh_build((manifest, raw) in scenario()) {
        let (width, depth) = extent(&manifest);
        let mut w = World::new(manifest, arrivals(), 5).expect("generated layouts are valid");
        for _ in 0..6 {
            w.step();
        }
        let mut ids: Vec<PlaceId> = Vec::new();
        for (n, r) in raw.iter().enumerate() {
            let c = command(r, n, &ids, width, depth);
            w.submit(c.clone());
            let before = w.snapshot().clone();
            let events = w.step();
            let found = check_world(&before, &w, &events);
            prop_assert!(found.is_empty(), "{c:?}: {found:?}");
            if let Command::Place { placement, .. } = &c
                && events.iter().any(|e| matches!(e.kind, EventKind::PlacementChanged { .. }))
            {
                ids.push(placement.id.clone());
            }
            if let Command::RemovePlacement { id, .. } = &c
                && events.iter().any(|e| matches!(e.kind, EventKind::PlacementChanged { .. }))
            {
                ids.retain(|x| x != id);
            }
            let nav = w.nav().expect("layout");
            let mut fresh = NavGrid::build(w.index());
            prop_assert_eq!(cells(nav), cells(&fresh), "after {:?}", c);
            prop_assert_eq!(nav.room_cell_counts(), fresh.room_cell_counts());
            prop_assert_eq!(nav.floor_cell_counts(), fresh.floor_cell_counts());
            fresh.keep_queues_off(city_core::transit::track_cells(w.index(), &fresh));
            for room in w.index().rooms.keys() {
                prop_assert_eq!(nav.queue_slots(room, 8), fresh.queue_slots(room, 8), "{}", room);
                prop_assert_eq!(
                    w.room_field(room).expect("a field"),
                    &fresh.field_from(&fresh.thresholds(room))[..],
                    "the field of {} after {:?}", room, c
                );
            }
            let exits: Vec<Cell> = w.index().entrances.iter().filter_map(|e| fresh.snap(*e)).collect();
            prop_assert_eq!(w.exit_field(), &fresh.field_from(&exits)[..]);
            let placed: BTreeSet<&PlaceId> = w.index().placements.iter().map(|p| &p.id).collect();
            let recorded: BTreeSet<&PlaceId> =
                w.snapshot().manifest.city.districts[0].placements.iter().map(|p| &p.id).collect();
            prop_assert_eq!(placed, recorded, "the snapshot carries the placements");
        }
    }

    /// The same commands straight through `placement::apply`: the reach it
    /// keeps is the reach found afresh, and every refusal leaves the index
    /// and grid exactly as they were.
    #[test]
    fn reach_follows_and_refusals_leave_nothing_changed((manifest, raw) in scenario()) {
        let (width, depth) = extent(&manifest);
        let mut index = PlaceIndex::build(&manifest).expect("valid");
        let mut grid = NavGrid::build(&index);
        let tracks = city_core::transit::track_cells(&index, &grid);
        let mut reach = Reach::of(&index, &grid);
        let mut ids: Vec<PlaceId> = Vec::new();
        for (n, r) in raw.iter().enumerate() {
            let change = match command(r, n, &ids, width, depth) {
                Command::Place { placement, .. } => Change::Place(placement),
                Command::MovePlacement { id, at, facing, .. } => Change::Move { id, at, facing },
                Command::RemovePlacement { id, .. } => Change::Remove { id },
                _ => unreachable!(),
            };
            let (index_before, cells_before) = (index.clone(), cells(&grid));
            let reach_before = reach.clone();
            let layout = Layout { index: &mut index, grid: &mut grid, tracks: &tracks, reach: &mut reach, people: &BTreeSet::new() };
            match placement::apply(layout, Catalogue::builtin(), &change, &|_, _| Ok(())) {
                Ok(_) => {
                    match &change {
                        Change::Place(p) => ids.push(p.id.clone()),
                        Change::Remove { id } => ids.retain(|x| x != id),
                        Change::Move { .. } => {}
                    }
                    prop_assert_eq!(cells(&grid), cells(&NavGrid::build(&index)));
                    prop_assert_eq!(&reach, &Reach::of(&index, &grid), "after {:?}", change);
                }
                Err(_) => {
                    prop_assert_eq!(&index, &index_before, "refused {:?}", change);
                    prop_assert_eq!(cells(&grid), cells_before.clone());
                    prop_assert_eq!(&reach, &reach_before);
                }
            }
        }
    }
}

/// A 40 × 30 m block placed, moved and removed on a 60 × 50 m open ground:
/// after each, the grid, its counts, the walking fields and the reach are
/// what a fresh build gives, cell for cell.
#[test]
fn a_large_block_placed_moved_and_removed_matches_a_fresh_build() {
    let mut ground = room(
        "room:ground",
        Rect {
            x: 0,
            z: 0,
            w: 6000,
            d: 5000,
        },
        true,
    );
    ground.capacity = 20;
    let mut m = layout(&[4], 200, false, false);
    m.city.districts[0].facilities[1].rooms = vec![ground];
    m.city.districts[0].facilities.remove(0);
    m.city.entrances = vec![Point { x: 0, z: 2500 }];
    assert!(validate(&m).valid, "{:?}", validate(&m));
    let mut w = World::new(m, arrivals_none(), 1).expect("valid");
    let original = cells(w.nav().unwrap());
    let block = Placement {
        id: "placement:block".into(),
        kind: "block-house".into(),
        at: Point { x: 3000, z: 2600 },
        size: Some(Size { w: 4000, d: 3000 }),
        ..Default::default()
    };
    let commands = [
        Command::Place {
            placement: block,
            by: None,
        },
        Command::MovePlacement {
            id: "placement:block".into(),
            at: Point { x: 3200, z: 2400 },
            facing: 0,
            by: None,
        },
        Command::RemovePlacement {
            id: "placement:block".into(),
            by: None,
        },
    ];
    for c in commands {
        w.submit(c.clone());
        let events = w.step();
        assert!(
            events
                .iter()
                .any(|e| matches!(e.kind, EventKind::PlacementChanged { .. })),
            "{c:?}: {events:?}"
        );
        let nav = w.nav().unwrap();
        let fresh = NavGrid::build(w.index());
        assert_eq!(cells(nav), cells(&fresh), "after {c:?}");
        assert_eq!(nav.room_cell_counts(), fresh.room_cell_counts());
        let room: PlaceId = "room:ground".into();
        assert_eq!(
            w.room_field(&room).unwrap(),
            &fresh.field_from(&fresh.thresholds(&room))[..]
        );
        let exits: Vec<Cell> = w
            .index()
            .entrances
            .iter()
            .filter_map(|e| fresh.snap(*e))
            .collect();
        assert_eq!(w.exit_field(), &fresh.field_from(&exits)[..]);
    }
    assert_eq!(cells(w.nav().unwrap()), original);
}

fn arrivals_none() -> Feed {
    Feed {
        header: FeedHeader {
            schema_version: 1,
            source: "fixture:placement-props".into(),
            fixture: true,
            description: String::new(),
        },
        entries: Vec::new(),
    }
}

// ---- Scale (spec §1.5) ----

/// A tiny linear congruential generator: the scene is seeded, and the core
/// draws nothing.
struct Lcg(u64);

impl Lcg {
    fn next(&mut self, n: u64) -> u64 {
        self.0 = self
            .0
            .wrapping_mul(6_364_136_223_846_793_005)
            .wrapping_add(1_442_695_040_888_963_407);
        (self.0 >> 33) % n
    }
}

/// Kinds the scale scene scatters, all small enough for a 5 m lattice.
const SCATTERED: [&str; 9] = [
    "bollard",
    "street-lamp",
    "shrub",
    "planter",
    "street-tree",
    "bench",
    "bookshelf",
    "tram-shelter",
    "block-house",
];

/// The large blocks: (x, z) of each 40 × 30 m block's centre (cm).
const LARGE: [(i32, i32); 8] = [
    (6000, 6000),
    (20000, 6000),
    (34000, 6000),
    (6000, 20000),
    (34000, 20000),
    (6000, 34000),
    (20000, 34000),
    (34000, 34000),
];

/// A 400 × 400 m district of sixteen 100 m open grounds, with entrances on
/// its west edge, eight 40 × 30 m blocks and 4,992 seeded placements on a
/// 5 m lattice: 5,000 placements in all.
fn scale_scene(seed: u64) -> Manifest {
    scene(seed, 4, &LARGE, 5000)
}

/// A district of `grounds` × `grounds` 100 m open grounds, with an entrance
/// on the west edge of each row, the 40 × 30 m blocks centred on `large`
/// and seeded placements on a 5 m lattice clear of them: `count` in all.
fn scene(seed: u64, grounds: i32, large: &[(i32, i32)], count: usize) -> Manifest {
    let mut rng = Lcg(seed);
    let mut rooms = Vec::new();
    for j in 0..grounds {
        for i in 0..grounds {
            rooms.push(room(
                &format!("room:{i}-{j}"),
                Rect {
                    x: i * 10_000,
                    z: j * 10_000,
                    w: 10_000,
                    d: 10_000,
                },
                true,
            ));
        }
    }
    let mut placements: Vec<Placement> = large
        .iter()
        .enumerate()
        .map(|(n, (x, z))| Placement {
            id: format!("placement:large-{n}").into(),
            kind: "block-house".into(),
            at: Point { x: *x, z: *z },
            size: Some(Size { w: 4000, d: 3000 }),
            ..Default::default()
        })
        .collect();
    let clear_of_large = |x: i32, z: i32| {
        large
            .iter()
            .all(|(cx, cz)| (x - cx).abs() > 2600 || (z - cz).abs() > 2100)
    };
    'lattice: for j in 0..20 * grounds {
        for i in 0..20 * grounds {
            if placements.len() == count {
                break 'lattice;
            }
            let (x, z) = (250 + 500 * i, 250 + 500 * j);
            if !clear_of_large(x, z) || x < 1000 {
                continue;
            }
            let kind = SCATTERED[rng.next(SCATTERED.len() as u64) as usize];
            let snap = Catalogue::builtin().kind(kind).expect("a kind").snap;
            // A seat's point at its cell's centre, as a seat's is, so its
            // own arms never reach the cell it is sat in from.
            let centred = if snap == 1 { 12 } else { 0 };
            placements.push(Placement {
                id: format!("placement:s{:04}", placements.len()).into(),
                kind: kind.into(),
                at: Point {
                    x: x / snap * snap + centred,
                    z: z / snap * snap + centred,
                },
                // Seats turn by right angles, where their way in is known
                // to stay open.
                facing: match kind {
                    "block-house" => 0,
                    "bench" => 90 * rng.next(4) as i32,
                    _ => rng.next(360) as i32,
                },
                size: (kind == "block-house").then_some(Size { w: 200, d: 200 }),
                ..Default::default()
            });
        }
    }
    assert_eq!(placements.len(), count);
    Manifest {
        schema_version: MANIFEST_SCHEMA_VERSION,
        catalogue: Some(1),
        city: City {
            id: "city:scale".into(),
            name: "Scale".into(),
            districts: vec![District {
                id: "district:scale".into(),
                name: "Scale".into(),
                facilities: vec![Facility {
                    id: "facility:ground".into(),
                    name: "Ground".into(),
                    rooms,
                    ..Default::default()
                }],
                placements,
            }],
            entrances: (0..grounds)
                .map(|j| Point {
                    x: 100,
                    z: 5000 + 10_000 * j,
                })
                .collect(),
            arrivals: Arrivals::Direct,
        },
        seat_policy: SeatPolicyName::DepartmentFirst,
        occupants: Vec::new(),
        lines: Vec::new(),
        scenery: Vec::new(),
        weather: None,
        clock: None,
    }
}

/// The scale gate's split, kept by plain `cargo test` (spec §1.5, as
/// amended): in a 100 × 100 m ground of 300 placements, 300 moves of up to
/// a metre, each turned any way, settle by the local proof and within the
/// local budget, all but a few tram shelters. A shelter turned a few
/// degrees off a right angle can seal a cell into a pocket inside its U,
/// which only the whole grid can judge (as `scale_district` found); that
/// count is held where it is. A footprint change that sends more moves to
/// the whole grid fails here, not only in the release-only
/// `scale_district`.
#[test]
fn ordinary_moves_settle_locally() {
    /// Shelter moves compared against the whole grid in this scene today.
    const SHELTERS_WHOLE: usize = 6;
    let manifest = scene(2026, 1, &[], 300);
    let mut index = PlaceIndex::build(&manifest).unwrap_or_else(|e| panic!("{:?}", &e[..3]));
    let mut grid = NavGrid::build(&index);
    let mut reach = Reach::of(&index, &grid);
    let (tracks, nobody) = (BTreeSet::new(), BTreeSet::new());
    let movable: Vec<PlaceId> = index
        .placements
        .iter()
        .filter(|p| p.record.kind != "block-house")
        .map(|p| p.id.clone())
        .collect();
    let mut rng = Lcg(11);
    let mut local = Vec::new();
    // Each kind's accepted moves compared against the whole grid.
    let mut whole: BTreeMap<String, usize> = BTreeMap::new();
    for _ in 0..300 {
        let id = movable[rng.next(movable.len() as u64) as usize].clone();
        let p = index.placed(&id).expect("placed").record.clone();
        let step = |r: &mut Lcg| (r.next(9) as i32 - 4) * 25;
        let (dx, dz) = (step(&mut rng), step(&mut rng));
        let change = Change::Move {
            id,
            at: Point {
                x: p.at.x + dx,
                z: p.at.z + dz,
            },
            facing: rng.next(360) as i32,
        };
        let layout = Layout {
            index: &mut index,
            grid: &mut grid,
            tracks: &tracks,
            reach: &mut reach,
            people: &nobody,
        };
        let t = Instant::now();
        let (outcome, whole_grid) =
            placement::apply_saying_path(layout, Catalogue::builtin(), &change, &|_, _| Ok(()));
        let took = t.elapsed();
        match (outcome.is_ok(), whole_grid) {
            (false, _) => {}
            (true, true) => *whole.entry(p.kind.clone()).or_default() += 1,
            (true, false) => local.push(took),
        }
    }
    let slowest = local.iter().max().copied().unwrap_or_default();
    println!(
        "ordinary moves: {} settled locally (slowest {:.3} ms); compared against the whole grid {whole:?}",
        local.len(),
        millis(slowest)
    );
    assert_eq!(reach, Reach::of(&index, &grid), "the reach kept is fresh");
    assert!(
        local.len() >= 240,
        "{} of 300 moves settled locally",
        local.len()
    );
    let shelters = whole.remove("tram-shelter").unwrap_or(0);
    assert!(
        whole.is_empty(),
        "moves compared against the whole grid: {whole:?}"
    );
    assert!(
        shelters <= SHELTERS_WHOLE,
        "{shelters} shelter moves compared against the whole grid, above {SHELTERS_WHOLE}"
    );
    // The budget is a release build's; the test profile's build is allowed
    // twenty times it.
    let budget = if cfg!(debug_assertions) { 20.0 } else { 1.0 };
    assert!(
        millis(slowest) <= budget,
        "the slowest move settled locally took {:.3} ms",
        millis(slowest)
    );
}

fn millis(d: Duration) -> f64 {
    d.as_secs_f64() * 1000.0
}

/// Spec §1.5, as amended: a 400 × 400 m district with 5,000 placements
/// loads and builds its grid in 200 ms or less; a placement change settled
/// near it updates in 1 ms or less, and one that needs the whole grid
/// compared within the full build's 200 ms, in a native release build.
/// Each change is timed by the path it took, since a random move can need
/// the whole grid too (a shelter turned so its outline seals a cell).
/// Run it with
/// `cargo test --release -p city-core -- --ignored scale_district`.
#[test]
#[ignore]
fn scale_district() {
    let manifest = scale_scene(2026);

    let t = Instant::now();
    let mut index = PlaceIndex::build(&manifest).unwrap_or_else(|e| panic!("{:?}", &e[..3]));
    let load = t.elapsed();
    assert_eq!(index.placements.len(), 5000);

    let t = Instant::now();
    let mut grid = NavGrid::build(&index);
    let build = t.elapsed();
    let e = grid.extent();
    assert_eq!((e.w, e.d), (40_000, 40_000), "2.56 million cells");

    let t = Instant::now();
    let mut reach = Reach::of(&index, &grid);
    let reach_time = t.elapsed();
    let (tracks, nobody) = (BTreeSet::new(), BTreeSet::new());

    // A hundred moves: most of a scattered placement by up to a metre and a
    // turn, and every tenth of a large block by two metres.
    let mut rng = Lcg(7);
    // Each move's time, and whether it was compared against the whole grid.
    let mut moves: Vec<(Duration, bool)> = Vec::new();
    let mut refused = 0;
    for n in 0..100 {
        let id = if n % 10 == 0 {
            index.placements[(n / 10) % LARGE.len()].id.clone()
        } else {
            index.placements[8 + rng.next(4992) as usize].id.clone()
        };
        let p = index.placed(&id).expect("placed").record.clone();
        let snap = Catalogue::builtin().kind(&p.kind).expect("a kind").snap;
        let (dx, dz, facing) = if n % 10 == 0 {
            (if n % 20 == 0 { 200 } else { -200 }, 0, 0)
        } else {
            let step = |r: &mut Lcg| (r.next(9) as i32 - 4) * 25;
            let facing = match p.kind.as_str() {
                "bench" => 90 * rng.next(4) as i32,
                _ => rng.next(360) as i32,
            };
            (step(&mut rng), step(&mut rng), facing)
        };
        let change = Change::Move {
            id,
            at: Point {
                x: p.at.x + (dx / snap) * snap,
                z: p.at.z + (dz / snap) * snap,
            },
            facing: if p.kind == "block-house" { 0 } else { facing },
        };
        let layout = Layout {
            index: &mut index,
            grid: &mut grid,
            tracks: &tracks,
            reach: &mut reach,
            people: &nobody,
        };
        let t = Instant::now();
        let (outcome, whole_grid) =
            placement::apply_saying_path(layout, Catalogue::builtin(), &change, &|_, _| Ok(()));
        moves.push((t.elapsed(), whole_grid));
        refused += usize::from(outcome.is_err());
    }
    assert!(
        refused < 10,
        "{refused} of 100 moves refused: the scene should leave room"
    );

    // Changes nothing nearby can settle, which fall back on comparing the
    // whole grid: a bollard beside each entrance, whose cell might move,
    // and a planter filling a 1 m passage 40 m long, between a new wall and
    // a large block, whose two sides meet only round its far ends.
    let bollard = |n: usize, x: i32, z: i32| Placement {
        id: format!("placement:whole-{n}").into(),
        kind: "bollard".into(),
        at: Point { x, z },
        ..Default::default()
    };
    let mut forced: Vec<Change> = (0..4)
        .map(|j| Change::Place(bollard(j, 150, 5050 + 10_000 * j as i32)))
        .collect();
    let wall = Change::Place(Placement {
        id: "placement:wall".into(),
        kind: "block-house".into(),
        at: Point { x: 6000, z: 4200 },
        size: Some(Size { w: 4000, d: 360 }),
        ..Default::default()
    });
    let layout = Layout {
        index: &mut index,
        grid: &mut grid,
        tracks: &tracks,
        reach: &mut reach,
        people: &nobody,
    };
    placement::apply(layout, Catalogue::builtin(), &wall, &|_, _| Ok(())).expect("the wall");
    forced.push(Change::Place(Placement {
        id: "placement:in-the-passage".into(),
        kind: "planter".into(),
        at: Point { x: 6000, z: 4450 },
        ..Default::default()
    }));
    let mut whole_times = Vec::new();
    for change in &forced {
        let layout = Layout {
            index: &mut index,
            grid: &mut grid,
            tracks: &tracks,
            reach: &mut reach,
            people: &nobody,
        };
        let t = Instant::now();
        let (outcome, whole_grid) =
            placement::apply_saying_path(layout, Catalogue::builtin(), change, &|_, _| Ok(()));
        whole_times.push(t.elapsed());
        assert!(outcome.is_ok(), "{change:?}: {outcome:?}");
        assert!(whole_grid, "{change:?} is compared against the whole grid");
    }
    let passage = |x: i32| grid.cell_of(Point { x, z: 4437 });
    assert!(grid.walkable(passage(5800)) && grid.walkable(passage(6200)));
    assert!(
        !grid.walkable(passage(6000)),
        "the planter fills the passage"
    );

    // The whole-grid comparison's one labelling of the walks, and the links
    // and the entrances' reach read off it.
    let t = Instant::now();
    let walks = grid.walks();
    let links = grid.links_in(&walks, &index.entrances);
    let read_off = Reach::of_walks(&index, &grid, &walks);
    let whole = t.elapsed();
    assert_eq!(read_off, reach, "the reach kept equals the reach read off");
    assert_eq!(
        Reach::of(&index, &grid),
        reach,
        "and the reach found afresh"
    );
    assert!(!links.is_empty());
    assert_eq!(
        (0..grid.extent().w / 25)
            .flat_map(|i| (0..grid.extent().d / 25).map(move |j| Cell { i, j }))
            .filter(|c| grid.walkable(*c))
            .count(),
        NavGrid::build(&index)
            .room_cell_counts()
            .values()
            .sum::<usize>(),
    );

    let rounded = |ts: &[Duration]| -> Vec<f64> {
        ts.iter()
            .map(|t| (millis(*t) * 1000.0).round() / 1000.0)
            .collect()
    };
    let local: Vec<Duration> = moves.iter().filter(|m| !m.1).map(|m| m.0).collect();
    let moved_whole: Vec<Duration> = moves.iter().filter(|m| m.1).map(|m| m.0).collect();
    let slowest_local = local.iter().max().copied().unwrap_or_default();
    let mean_local = local.iter().sum::<Duration>() / local.len().max(1) as u32;
    let slowest_whole = whole_times
        .iter()
        .chain(&moved_whole)
        .max()
        .copied()
        .unwrap_or_default();
    println!(
        "scale_district: load {:.1} ms, grid build {:.1} ms, reach {:.1} ms; \
         100 moves ({refused} refused): {} settled locally, mean {:.3} ms, slowest {:.3} ms; \
         {} compared against the whole grid, {:?} ms; \
         {} whole-grid changes {:?} ms; slowest whole-grid {:.1} ms; \
         whole-grid check alone {:.1} ms",
        millis(load),
        millis(build),
        millis(reach_time),
        local.len(),
        millis(mean_local),
        millis(slowest_local),
        moved_whole.len(),
        rounded(&moved_whole),
        whole_times.len(),
        rounded(&whole_times),
        millis(slowest_whole),
        millis(whole),
    );
    assert!(millis(load) <= 200.0, "load took {:.1} ms", millis(load));
    assert!(
        millis(build) <= 200.0,
        "the grid took {:.1} ms",
        millis(build)
    );
    assert!(
        local.len() >= 90,
        "only {} of 100 moves settled locally: the local proof should settle most",
        local.len()
    );
    assert!(
        millis(slowest_local) <= 1.0,
        "the slowest move settled locally took {:.3} ms",
        millis(slowest_local)
    );
    assert!(
        millis(slowest_whole) <= 200.0,
        "the slowest change compared against the whole grid took {:.1} ms",
        millis(slowest_whole)
    );
}
