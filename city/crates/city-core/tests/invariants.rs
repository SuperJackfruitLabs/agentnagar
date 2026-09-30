//! Property tests: the seven invariants hold after every tick of generated
//! worlds, and the same inputs always give the same event log.

use city_contracts::*;
use city_core::footprint::{MARGIN, Placed, covers};
use city_core::invariants::{check_all, check_world};
use city_core::nav::NavGrid;
use city_core::{Feed, PlaceIndex, World, merge, placement, project, validate};
use proptest::prelude::*;

type RawRoom = (u32, Vec<u8>, Vec<u8>, u8, Vec<(u8, u64, u64)>, (u8, u8));
type RawCommand = (u64, u8, u8, u8, u8, u8, u64, u64);

const POOL: [&str; 12] = [
    "agent:0", "agent:1", "agent:2", "agent:3", "agent:4", "agent:5", "pa:0", "pa:1", "person:0",
    "person:1", "person:2", "sim:0",
];
const DEPTS: [Option<&str>; 3] = [Some("making"), Some("knowledge"), None];

fn feed_profile(id: &str) -> Option<OccupantProfile> {
    let kind = match id {
        "pa:0" => OccupantKind::PersonalAgent {
            owner: "person:0".into(),
        },
        "pa:1" => OccupantKind::PersonalAgent {
            owner: "person:1".into(),
        },
        "person:0" => OccupantKind::Human {
            tier: HumanTier::Registered,
        },
        "person:1" => OccupantKind::Human {
            tier: HumanTier::Resident,
        },
        "person:2" => OccupantKind::Human {
            tier: HumanTier::Observer,
        },
        "sim:0" => OccupantKind::SimCitizen,
        _ => return None,
    };
    let mut p = OccupantProfile {
        id: id.into(),
        kind,
        display_name: id.into(),
        role: String::new(),
        department: None,
        home: None,
        work: None,
        shared_with: Default::default(),
        appearance: Default::default(),
    };
    if id == "pa:1" {
        p.shared_with.insert("person:2".into());
    }
    Some(p)
}

fn build(raw_rooms: Vec<RawRoom>, depts: Vec<u8>, raw_cmds: Vec<RawCommand>) -> (Manifest, Feed) {
    let n = raw_rooms.len();
    let room_id = |i: usize| PlaceId::from(format!("room:{i}"));
    let mut rooms = Vec::new();
    for (i, (capacity, seat_codes, reserve, overflow, doors, (d0, d1))) in
        raw_rooms.into_iter().enumerate()
    {
        let pods = vec![
            Pod {
                id: format!("pod:{i}:0").into(),
                department: DEPTS[d0 as usize].map(Into::into),
            },
            Pod {
                id: format!("pod:{i}:1").into(),
                department: DEPTS[d1 as usize].map(Into::into),
            },
        ];
        let mut owners: Vec<u8> = Vec::new();
        for r in reserve {
            if !owners.contains(&r) && owners.len() < (capacity as usize).min(2) {
                owners.push(r);
            }
        }
        let count = seat_codes
            .len()
            .min(capacity as usize + 1)
            .max(owners.len());
        let seats = (0..count)
            .map(|j| Seat {
                id: format!("seat:{i}:{j}").into(),
                pod: match seat_codes.get(j).copied().unwrap_or(0) {
                    1 => Some(pods[0].id.clone()),
                    2 => Some(pods[1].id.clone()),
                    _ => None,
                },
                reserved_for: owners.get(j).map(|o| CityId::from(format!("agent:{o}"))),
                ..Default::default()
            })
            .collect();
        let overflow = (i + 1 < n && overflow % 2 == 0)
            .then(|| room_id(i + 1 + (overflow as usize / 2) % (n - i - 1)));
        let mut targets = Vec::new();
        let doors = doors
            .into_iter()
            .filter_map(|(t, min, extra)| {
                let t = t as usize % n;
                (t != i && !targets.contains(&t)).then(|| {
                    targets.push(t);
                    Door {
                        id: format!("door:{i}-{t}").into(),
                        to: room_id(t),
                        transit: TickRange {
                            min,
                            max: min + extra,
                        },
                        ..Default::default()
                    }
                })
            })
            .collect();
        rooms.push(Room {
            id: room_id(i),
            name: format!("Room {i}"),
            capacity,
            pods,
            seats,
            overflow,
            doors,
            ..Default::default()
        });
    }
    let occupants = (0..6)
        .map(|i| OccupantProfile {
            id: format!("agent:{i}").into(),
            kind: OccupantKind::GuildAgent,
            display_name: format!("Agent {i}"),
            role: String::new(),
            department: DEPTS[depts[i] as usize].map(Into::into),
            home: None,
            work: Some(room_id(0)),
            shared_with: Default::default(),
            appearance: Default::default(),
        })
        .collect();
    let manifest = Manifest {
        weather: None,
        lines: Vec::new(),
        schema_version: MANIFEST_SCHEMA_VERSION,
        city: City {
            id: "city:p".into(),
            name: "P".into(),
            districts: vec![District {
                id: "district:p".into(),
                name: "P".into(),
                facilities: vec![Facility {
                    id: "facility:p".into(),
                    name: "P".into(),
                    rooms,
                    ..Default::default()
                }],
                placements: Vec::new(),
            }],
            ..Default::default()
        },
        seat_policy: SeatPolicyName::DepartmentFirst,
        occupants,
        clock: None,
        scenery: Vec::new(),
        catalogue: Some(1),
    };

    let ids: Vec<PlaceId> = (0..n).map(room_id).collect();
    (manifest, feed_from(raw_cmds, &ids))
}

/// A fixture feed from raw generated commands over `rooms`.
fn feed_from(raw_cmds: Vec<RawCommand>, rooms: &[PlaceId]) -> Feed {
    let mut entries: Vec<FeedEntry> = raw_cmds
        .into_iter()
        .map(|(at, kind, occ, room, dim, value, back, ahead)| {
            let id = POOL[occ as usize % POOL.len()];
            let to = rooms[room as usize % rooms.len()].clone();
            let command = match kind {
                0 => Command::Arrive {
                    occupant: id.into(),
                    profile: feed_profile(id),
                    room: (room % 4 != 0).then_some(to),
                    player: false,
                },
                1 => Command::Depart {
                    occupant: id.into(),
                    player: false,
                },
                2 => Command::Move {
                    occupant: id.into(),
                    to,
                },
                3 => {
                    let observed_at = at.saturating_sub(back);
                    let stamp = Stamp {
                        observed_at,
                        fetched_at: observed_at,
                        expires_at: at + ahead,
                        source: "fixture:proptest".into(),
                        source_version: "1".into(),
                    };
                    let observation = match dim % 3 {
                        0 => Observation::Connection(Observed {
                            value: [
                                ConnectionState::Connected,
                                ConnectionState::Disconnected,
                                ConnectionState::Unknown,
                            ][value as usize % 3],
                            stamp,
                        }),
                        1 => Observation::Process(Observed {
                            value: [
                                ProcessState::Running,
                                ProcessState::Stopped,
                                ProcessState::Error,
                                ProcessState::Unknown,
                            ][value as usize % 4],
                            stamp,
                        }),
                        _ => Observation::Task(Observed {
                            value: TaskReport {
                                state: [
                                    TaskState::Working,
                                    TaskState::Waiting,
                                    TaskState::Queued,
                                    TaskState::Idle,
                                    TaskState::Done,
                                    TaskState::Unknown,
                                ][value as usize % 6],
                                summary: Some(format!("summary {value}")),
                                summary_public: value % 2 == 0,
                            },
                            stamp,
                        }),
                    };
                    Command::Observe {
                        occupant: id.into(),
                        observation,
                    }
                }
                4 => Command::Share {
                    occupant: ["pa:0", "pa:1"][occ as usize % 2].into(),
                    grantee: format!("person:{}", room % 3).into(),
                },
                _ => Command::Unshare {
                    occupant: ["pa:0", "pa:1"][occ as usize % 2].into(),
                    grantee: format!("person:{}", room % 3).into(),
                },
            };
            FeedEntry {
                at,
                fixture: true,
                command,
            }
        })
        .collect();
    entries.sort_by_key(|e| e.at);
    Feed {
        header: FeedHeader {
            schema_version: SCHEMA_VERSION,
            source: "fixture:proptest".into(),
            fixture: true,
            description: "Generated by proptest. Not real agent state.".into(),
        },
        entries,
    }
}

fn world_strategy() -> impl Strategy<Value = (Manifest, Feed, u64)> {
    let room = (
        1u32..=5,
        prop::collection::vec(0u8..3, 0..7),
        prop::collection::vec(0u8..6, 0..3),
        any::<u8>(),
        prop::collection::vec((any::<u8>(), 1u64..=3, 0u64..=2), 0..3),
        (0u8..3, 0u8..3),
    );
    // Commands lean towards arrivals so rooms actually fill.
    let command = (
        0u64..30,
        prop_oneof![4 => Just(0u8), 2 => Just(1u8), 2 => Just(2u8), 3 => Just(3u8), 1 => Just(4u8), 1 => Just(5u8)],
        any::<u8>(),
        any::<u8>(),
        any::<u8>(),
        any::<u8>(),
        0u64..5,
        1u64..10,
    );
    (
        prop::collection::vec(room, 1..=4),
        prop::collection::vec(0u8..3, 6),
        prop::collection::vec(command, 0..60),
        any::<u64>(),
    )
        .prop_map(|(rooms, depts, cmds, seed)| {
            let (m, f) = build(rooms, depts, cmds);
            debug_assert!(validate(&m).valid, "{:?}", validate(&m));
            (m, f, seed)
        })
}

fn bytes(log: &[Event]) -> String {
    log.iter()
        .map(|e| serde_json::to_string(e).unwrap())
        .collect::<Vec<_>>()
        .join("\n")
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 256, .. ProptestConfig::default() })]

    #[test]
    fn invariants_hold_every_tick((manifest, feed, seed) in world_strategy()) {
        let mut w = World::new(manifest.clone(), feed.clone(), seed)
            .expect("generated manifests are valid");
        let mut log = Vec::new();
        for _ in 0..40 {
            let before = w.snapshot().clone();
            let ev = w.step();
            let v = check_all(&before, w.snapshot(), &ev);
            prop_assert!(v.is_empty(), "tick {}: {:?}", w.snapshot().tick, v);
            log.extend(ev);
        }
        // Invariant 6: the same manifest, feed and seed give a byte-identical log.
        let mut again = World::new(manifest, feed, seed).unwrap();
        let log2: Vec<Event> = (0..40).flat_map(|_| again.step()).collect();
        prop_assert_eq!(bytes(&log), bytes(&log2));
    }
}

type RawLayoutRoom = (i32, u32, Vec<u8>, bool, u8);

/// (headway, eastbound offset, westbound offset, speed, dwell, length in
/// 25 cm steps, stop position in eighths of the line)
type RawLine = (u32, u32, u32, u32, u32, i32, u8);

/// Rooms in a row along x (widths 300–800 cm, depth 400 cm) above a plaza
/// spanning them all. Each room has a door to the plaza at its middle and
/// may have a door to its east neighbour; seats sit in the lower half,
/// desks in the upper half, so neither blocks a door. (Each desk stands
/// where schema 1 put an obstacle of its size, 100 by 60 cm.)
///
/// With a line, a tram street runs east–west below the plaza: a north
/// platform (2 m deep), the street with both tracks (4 m), and a south
/// platform (2 m), all open ground joined along their edges. The line's
/// one stop serves both platforms, and walkers heading for the south
/// platform cross both tracks.
fn build_layout(
    raw_rooms: Vec<RawLayoutRoom>,
    plaza_depth: i32,
    raw_line: Option<RawLine>,
    raw_cmds: Vec<RawCommand>,
) -> (Manifest, Feed) {
    let n = raw_rooms.len();
    let room_id = |i: usize| PlaceId::from(format!("room:{i}"));
    let door = |id: String, to: PlaceId, x: i32, z: i32| Door {
        id: id.into(),
        to,
        transit: TickRange { min: 1, max: 1 },
        pos: Some(Point { x, z }),
        width: None,
    };
    let mut x = 0;
    let mut rooms = Vec::new();
    let mut plaza_doors = Vec::new();
    let widths: Vec<i32> = raw_rooms.iter().map(|r| r.0 * 100).collect();
    let mut desks = Vec::new();
    for (i, (w100, capacity, seat_slots, east_door, desk_count)) in
        raw_rooms.into_iter().enumerate()
    {
        let w = w100 * 100;
        let mid = x + w / 2;
        let mut doors = vec![door(format!("door:{i}-p"), "room:p".into(), mid, 400)];
        plaza_doors.push(door(format!("door:p-{i}"), room_id(i), mid, 400));
        if east_door && i + 1 < n {
            doors.push(door(
                format!("door:{i}-{}", i + 1),
                room_id(i + 1),
                x + w,
                200,
            ));
        }
        if i > 0
            && rooms
                .last()
                .is_some_and(|r: &Room| r.doors.iter().any(|d| d.to == room_id(i)))
        {
            doors.push(door(format!("door:{i}-{}", i - 1), room_id(i - 1), x, 200));
        }
        let slots = (w / 100) as usize;
        let mut seen = std::collections::BTreeSet::new();
        let seats = seat_slots
            .into_iter()
            .map(|k| k as usize % slots)
            .filter(|k| seen.insert(*k))
            .map(|k| Seat {
                id: format!("seat:{i}:{k}").into(),
                pos: Some(Point {
                    x: x + 50 + 100 * k as i32,
                    z: 275,
                }),
                ..Default::default()
            })
            .collect();
        // A desk's footprint is 100 by 60 cm, 24 to 84 cm north of its
        // point: from 134 cm down, it covers z 50 to 110.
        desks.extend(
            (0..i32::from(desk_count % 3))
                .filter(|k| 50 + 150 * k + 100 <= w)
                .map(|k| Placement {
                    id: format!("placement:desk-{i}-{k}").into(),
                    kind: "desk".into(),
                    at: Point {
                        x: x + 100 + 150 * k,
                        z: 134,
                    },
                    ..Default::default()
                }),
        );
        rooms.push(Room {
            id: room_id(i),
            name: format!("Room {i}"),
            capacity,
            seats,
            doors,
            overflow: (i + 1 < n).then(|| room_id(i + 1)),
            template: Some("workshop".into()),
            rect: Some(Rect { x, z: 0, w, d: 400 }),
            ..Default::default()
        });
        x += w;
    }
    let _ = widths;
    rooms.push(Room {
        id: "room:p".into(),
        name: "Plaza".into(),
        capacity: 12,
        doors: plaza_doors,
        template: Some("plaza".into()),
        rect: Some(Rect {
            x: 0,
            z: 400,
            w: x,
            d: plaza_depth,
        }),
        ..Default::default()
    });
    let band = 400 + plaza_depth;
    let mut lines = Vec::new();
    let mut band_rooms = Vec::new();
    if let Some((headway, offset_east, offset_west, speed, dwell, length, stop_at)) = raw_line {
        let ground = |id: &str, z: i32, d: i32| Room {
            id: id.into(),
            name: id.into(),
            capacity: 50,
            template: Some("ground".into()),
            outdoor: true,
            rect: Some(Rect { x: 0, z, w: x, d }),
            ..Default::default()
        };
        // Each platform's edge stands 150 cm from its track.
        band_rooms.push(ground("room:platform-n", band, 150));
        band_rooms.push(ground("room:street", band + 150, 600));
        band_rooms.push(ground("room:platform-s", band + 750, 200));
        lines.push(Line {
            id: "line:test".into(),
            name: "Test tram".into(),
            mode: LineMode::Tram,
            points: vec![
                Point {
                    x: 0,
                    z: band + 450,
                },
                Point { x, z: band + 450 },
            ],
            tracks: [-150, 150],
            stops: vec![Stop {
                id: "stop:test".into(),
                name: "Test".into(),
                at: x * i32::from(stop_at) / 8,
                platforms: ["room:platform-n".into(), "room:platform-s".into()],
            }],
            timetable: Timetable {
                headway,
                offset: [offset_east % headway, offset_west % headway],
                speed,
                dwell: 1 + dwell % ((headway - 1) / 2),
            },
            vehicle: VehicleSpec {
                capacity: 40,
                length: length * 25,
                doors: vec![length * 25 / 2],
                kind: None,
            },
        });
    }
    let occupants = (0..6)
        .map(|i| OccupantProfile {
            id: format!("agent:{i}").into(),
            kind: OccupantKind::GuildAgent,
            display_name: format!("Agent {i}"),
            role: String::new(),
            department: None,
            home: None,
            work: Some(room_id(0)),
            shared_with: Default::default(),
            appearance: Default::default(),
        })
        .collect();
    let manifest = Manifest {
        weather: None,
        lines,
        schema_version: MANIFEST_SCHEMA_VERSION,
        city: City {
            id: "city:l".into(),
            name: "L".into(),
            districts: vec![District {
                id: "district:l".into(),
                name: "L".into(),
                facilities: vec![
                    Facility {
                        id: "facility:l".into(),
                        name: "L".into(),
                        rooms,
                        ..Default::default()
                    },
                    Facility {
                        id: "facility:transit".into(),
                        name: "Transit".into(),
                        rooms: band_rooms,
                        ..Default::default()
                    },
                ],
                placements: desks,
            }],
            entrances: vec![Point {
                x: 0,
                z: 400 + plaza_depth / 2,
            }],
            arrivals: Arrivals::Direct,
        },
        seat_policy: SeatPolicyName::DepartmentFirst,
        occupants,
        clock: Some(Clock {
            ticks_per_day: 600,
            start_minute: 420,
        }),
        scenery: Vec::new(),
        catalogue: Some(1),
    };
    let mut ids: Vec<PlaceId> = (0..n).map(room_id).collect();
    ids.push("room:p".into());
    if !manifest.lines.is_empty() {
        ids.push("room:platform-n".into());
        ids.push("room:platform-s".into());
    }
    (manifest, feed_from(raw_cmds, &ids))
}

/// (kind, x, z, facing)
type RawPlacement = (u8, u16, u16, u16);

/// Kinds a generated layout may place, one of them sized and two with
/// anchors.
const PLACEABLE: [&str; 12] = [
    "bollard",
    "street-lamp",
    "shrub",
    "planter",
    "palm",
    "bookshelf",
    "cafe-table-top",
    "umbrella",
    "catenary-pole",
    "tram-shelter",
    "desk",
    "block-house",
];

/// Seat kinds a generated seat may be.
const SEAT_KINDS: [&str; 4] = ["desk", "bench", "cafe-table", "reading-chair"];

/// `m` with its seats furnished from the catalogue when `furnish`,
/// the workshops' facility made a guild hall when `building`, and each of
/// `raw` placed in turn where the manifest stays valid with it.
fn with_placements(
    mut m: Manifest,
    furnish: bool,
    building: bool,
    raw: Vec<RawPlacement>,
) -> Manifest {
    if furnish {
        let unfurnished = m.clone();
        let seats = m.city.districts[0]
            .facilities
            .iter_mut()
            .flat_map(|f| f.rooms.iter_mut())
            .flat_map(|r| r.seats.iter_mut());
        for (n, seat) in seats.enumerate() {
            seat.kind = Some(SEAT_KINDS[n % SEAT_KINDS.len()].into());
        }
        if !validate(&m).valid {
            m = unfurnished;
        }
    }
    if building {
        m.city.districts[0].facilities[0].kind = Some("guild-hall".into());
        if !validate(&m).valid {
            m.city.districts[0].facilities[0].kind = None;
        }
    }
    let rects: Vec<Rect> = m
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .flat_map(|f| &f.rooms)
        .filter_map(|r| r.rect)
        .collect();
    let width = rects.iter().map(|r| r.x + r.w).max().unwrap_or(1);
    let depth = rects.iter().map(|r| r.z + r.d).max().unwrap_or(1);
    for (n, (kind, x, z, facing)) in raw.into_iter().enumerate() {
        let kind = PLACEABLE[usize::from(kind) % PLACEABLE.len()];
        let snap = Catalogue::builtin()
            .kind(kind)
            .expect("a catalogue kind")
            .snap;
        let placement = Placement {
            id: format!("placement:{n:02}").into(),
            kind: kind.into(),
            at: Point {
                x: i32::from(x) % width / snap * snap,
                z: i32::from(z) % depth / snap * snap,
            },
            facing: i32::from(facing) % 360,
            size: (kind == "block-house").then_some(Size { w: 200, d: 200 }),
            ..Default::default()
        };
        m.city.districts[0].placements.push(placement);
        if !validate(&m).valid {
            m.city.districts[0].placements.pop();
        }
    }
    m
}

fn layout_world_strategy() -> impl Strategy<Value = (Manifest, Feed, u64)> {
    let room = (
        3i32..=8,
        1u32..=4,
        prop::collection::vec(any::<u8>(), 0..6),
        any::<bool>(),
        any::<u8>(),
    );
    let command = (
        0u64..30,
        prop_oneof![5 => Just(0u8), 2 => Just(1u8), 2 => Just(2u8), 2 => Just(3u8), 1 => Just(4u8)],
        any::<u8>(),
        any::<u8>(),
        any::<u8>(),
        any::<u8>(),
        0u64..5,
        1u64..10,
    );
    // Most layouts carry a line, with timetables that bring several
    // vehicles through the run.
    let line = prop::option::weighted(
        0.75,
        (
            8u32..=40,
            0u32..40,
            0u32..40,
            2u32..=28,
            any::<u32>(),
            8i32..=48,
            1u8..=7,
        ),
    );
    let placement = (any::<u8>(), any::<u16>(), any::<u16>(), any::<u16>());
    (
        prop::collection::vec(room, 1..=3),
        (8i32..=20).prop_map(|d| d * 25),
        line,
        prop::collection::vec(command, 0..50),
        any::<u64>(),
        (any::<bool>(), any::<bool>()),
        prop::collection::vec(placement, 0..8),
    )
        .prop_map(
            |(rooms, depth, line, cmds, seed, (furnish, building), placements)| {
                let (m, f) = build_layout(rooms, depth, line, cmds);
                let m = with_placements(m, furnish, building, placements);
                assert!(validate(&m).valid, "{:?}", validate(&m));
                (m, f, seed)
            },
        )
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 128, .. ProptestConfig::default() })]

    #[test]
    fn movement_invariants_hold_every_tick((manifest, feed, seed) in layout_world_strategy()) {
        let mut w = World::new(manifest.clone(), feed.clone(), seed).expect("generated layouts are valid");
        let mut log = Vec::new();
        for _ in 0..60 {
            let before = w.snapshot().clone();
            let ev = w.step();
            let v = check_world(&before, &w, &ev);
            prop_assert!(v.is_empty(), "tick {}: {:?}", w.snapshot().tick, v);
            log.extend(ev);
        }
        let mut again = World::new(manifest, feed, seed).unwrap();
        let log2: Vec<Event> = (0..60).flat_map(|_| again.step()).collect();
        prop_assert_eq!(bytes(&log), bytes(&log2));
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 128, .. ProptestConfig::default() })]

    /// No walkable cell's centre lies within the body clearance of a
    /// footprint or a building's shell, but for seat cells and door spans;
    /// and nothing else is carved out of the floor.
    #[test]
    fn walkable_cells_keep_clear_of_every_footprint((manifest, _, _) in layout_world_strategy()) {
        let index = PlaceIndex::build(&manifest).unwrap();
        let grid = NavGrid::build(&index);
        let floor = NavGrid::floor(&index);
        let shells: Vec<Placed> = index
            .buildings
            .iter()
            .map(|b| placement::shell(&index, b))
            .collect();
        let solids: Vec<&Placed> = index
            .placements
            .iter()
            .chain(&index.seat_furniture)
            .map(|p| &p.placed)
            .chain(&shells)
            .collect();
        let everywhere = Rect { x: -1000, z: -1000, w: 100_000, d: 100_000 };
        for c in floor.cells_within(everywhere) {
            let centre = grid.centre(c);
            let covered = solids.iter().any(|s| covers(s, centre, MARGIN));
            if grid.walkable(c) && !grid.is_seat_cell(c) && !grid.in_door_span(c) {
                prop_assert!(!covered, "{c:?} is walkable inside a footprint");
            }
            if floor.walkable(c) && !grid.walkable(c) {
                prop_assert!(covered, "{c:?} is blocked by nothing");
            }
        }
    }
}

// ---- Players: random live Go and Steer (Stage 5) ----

/// (tick, who, kind, a, b, steer directions)
type RawLive = (u64, u8, u8, u16, u16, Vec<u8>);

const PLAYERS: [(&str, HumanTier); 2] = [
    ("person:you", HumanTier::Registered),
    ("person:observer-1", HumanTier::Observer),
];

/// Eight single steps, then a jump of two cells that must be refused.
const DIRS: [(i32, i32); 9] = [
    (0, -1),
    (1, -1),
    (1, 0),
    (1, 1),
    (0, 1),
    (-1, 1),
    (-1, 0),
    (-1, -1),
    (2, 0),
];

fn player_arrival(who: usize, room: PlaceId) -> Command {
    let (id, tier) = PLAYERS[who];
    Command::Arrive {
        occupant: id.into(),
        profile: Some(OccupantProfile {
            id: id.into(),
            kind: OccupantKind::Human { tier },
            display_name: id.into(),
            role: String::new(),
            department: None,
            home: None,
            work: None,
            shared_with: Default::default(),
            appearance: Default::default(),
        }),
        room: Some(room),
        player: true,
    }
}

/// A live command for one of the players, built against the world as it
/// stands, so a steer starts from where the player is.
fn live_command(w: &World, m: &Manifest, raw: &RawLive) -> Command {
    let (_, who, kind, a, b, dirs) = raw;
    let who = *who as usize % PLAYERS.len();
    let occupant = CityId::from(PLAYERS[who].0);
    let rooms: Vec<&Room> = m
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .flat_map(|f| &f.rooms)
        .collect();
    let seats: Vec<PlaceId> = rooms
        .iter()
        .flat_map(|r| &r.seats)
        .map(|s| s.id.clone())
        .collect();
    let room = |k: u16| rooms[k as usize % rooms.len()].id.clone();
    let width = rooms
        .iter()
        .filter_map(|r| r.rect)
        .map(|r| r.x + r.w)
        .max()
        .unwrap_or(0);
    let depth = rooms
        .iter()
        .filter_map(|r| r.rect)
        .map(|r| r.z + r.d)
        .max()
        .unwrap_or(0);
    match kind {
        0 => player_arrival(who, room(*a)),
        1 => Command::Go {
            occupant,
            // Some points fall outside every room, on walls or on doors.
            to: Target::Point {
                pos: Point {
                    x: i32::from(*a) % (width + 400) - 200,
                    z: i32::from(*b) % (depth + 400) - 200,
                },
            },
        },
        2 if !seats.is_empty() => Command::Go {
            occupant,
            to: Target::Seat {
                seat: seats[*a as usize % seats.len()].clone(),
            },
        },
        2 | 3 => Command::Go {
            occupant,
            to: Target::Room { room: room(*a) },
        },
        4 => {
            let start = w
                .snapshot()
                .occupants
                .get(&occupant)
                .and_then(|o| o.pos)
                .unwrap_or_default();
            let mut at = start;
            let cells = dirs
                .iter()
                .map(|d| {
                    let (di, dj) = DIRS[*d as usize % DIRS.len()];
                    at = Point {
                        x: at.x + di * 25,
                        z: at.z + dj * 25,
                    };
                    at
                })
                .collect();
            Command::Steer { occupant, cells }
        }
        _ => Command::Depart {
            occupant,
            player: false,
        },
    }
}

fn live_strategy() -> impl Strategy<Value = Vec<RawLive>> {
    let raw = (
        0u64..60,
        0u8..2,
        prop_oneof![1 => Just(0u8), 3 => Just(1u8), 2 => Just(2u8), 2 => Just(3u8), 5 => Just(4u8), 1 => Just(5u8)],
        any::<u16>(),
        any::<u16>(),
        prop::collection::vec(0u8..9, 0..8),
    );
    prop::collection::vec(raw, 0..40).prop_map(|mut v| {
        v.sort_by_key(|r| r.0);
        v
    })
}

struct PlayerRun {
    log: Vec<Event>,
    public: Vec<String>,
    input: Feed,
    violations: Vec<String>,
}

/// Runs 60 ticks with both players joining at the plaza and their live
/// commands submitted as generated; `observer` false leaves the observer
/// out entirely.
fn run_players(
    manifest: &Manifest,
    feed: &Feed,
    seed: u64,
    live: &[RawLive],
    observer: bool,
) -> PlayerRun {
    let mut w = World::new(manifest.clone(), feed.clone(), seed).expect("valid");
    let plaza = PlaceId::from("room:p");
    w.submit(player_arrival(0, plaza.clone()));
    if observer {
        w.submit(player_arrival(1, plaza));
    }
    let mut run = PlayerRun {
        log: Vec::new(),
        public: Vec::new(),
        input: w.input_log_feed(),
        violations: Vec::new(),
    };
    for t in 0..60 {
        for raw in live.iter().filter(|r| r.0 == t) {
            if raw.1 % 2 == 1 && !observer {
                continue;
            }
            let c = live_command(&w, manifest, raw);
            w.submit(c);
        }
        let before = w.snapshot().clone();
        let ev = w.step();
        for v in check_world(&before, &w, &ev) {
            run.violations
                .push(format!("tick {}: {v:?}", w.snapshot().tick));
        }
        run.public
            .push(serde_json::to_string(&project(w.snapshot(), &Viewer::Public)).unwrap());
        run.log.extend(ev);
    }
    run.input = w.input_log_feed();
    run
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 128, .. ProptestConfig::default() })]

    #[test]
    fn players_keep_every_invariant(
        (manifest, feed, seed) in layout_world_strategy(),
        live in live_strategy(),
    ) {
        let full = run_players(&manifest, &feed, seed, &live, true);
        prop_assert!(full.violations.is_empty(), "{:?}", full.violations);

        // Replaying the feed merged with the input log is byte-identical.
        let replay = merge(feed.clone(), full.input.clone()).unwrap();
        let mut again = World::new(manifest.clone(), replay, seed).unwrap();
        let log2: Vec<Event> = (0..60).flat_map(|_| again.step()).collect();
        prop_assert_eq!(bytes(&full.log), bytes(&log2));

        // The observer leaves no trace in public: every public projection is
        // the same as in a run where it never came.
        let without = run_players(&manifest, &feed, seed, &live, false);
        prop_assert!(without.violations.is_empty(), "{:?}", without.violations);
        prop_assert_eq!(full.public, without.public);
    }
}
