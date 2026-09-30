//! Using things, through the public API: what ends a use, how uses look in
//! projections, that boarding and going in through `Use` are `Board` and
//! `Go`, and that a session with uses replays byte for byte. The rules
//! themselves are unit-tested beside them in `src/interact.rs`.

mod common;

use city_contracts::*;
use city_core::World;
use city_core::invariants::check_world;
use common::*;
use serde_json::json;

const BENCH: Point = Point { x: 1000, z: 900 };

/// `district_small` with a bench placed on the plaza. No room seat backs
/// it, so it is a perch: open to anyone, holding no room capacity.
fn with_bench() -> Manifest {
    let mut m = district_small();
    m.city.districts[0].placements.push(
        serde_json::from_value(
            json!({"id": "placement:bench", "kind": "bench", "at": {"x": BENCH.x, "z": BENCH.z}}),
        )
        .unwrap(),
    );
    m
}

/// Three tram stops along a street (the core's `tram_three_stops`), with a
/// bench placed on the A platform.
fn tram_platform() -> Manifest {
    manifest(json!({
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
            ], "placements": [
                {"id": "placement:bench", "kind": "bench", "at": {"x": 1500, "z": 75}}
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
}

fn world(m: Manifest) -> World {
    World::new(m, feed(&[]), 3).expect("valid")
}

/// Steps once, checking every invariant, and returns the tick's events.
fn step(w: &mut World) -> Vec<Event> {
    let before = w.snapshot().clone();
    let events = w.step();
    let violations = check_world(&before, w, &events);
    assert!(
        violations.is_empty(),
        "tick {}: {violations:?}",
        w.snapshot().tick
    );
    events
}

/// Steps until `done` holds, within `limit` ticks; returns the events.
fn until(w: &mut World, limit: u64, done: impl Fn(&World) -> bool) -> Vec<Event> {
    let mut log = Vec::new();
    for _ in 0..limit {
        if done(w) {
            return log;
        }
        log.extend(step(w));
    }
    assert!(done(w), "not reached within {limit} ticks");
    log
}

fn player(id: &str) -> OccupantProfile {
    OccupantProfile {
        id: id.into(),
        kind: OccupantKind::Human {
            tier: HumanTier::Registered,
        },
        display_name: id.into(),
        role: String::new(),
        department: None,
        home: None,
        work: None,
        shared_with: Default::default(),
        appearance: Default::default(),
    }
}

/// A player joins for `room`, as the bridge's `join` does, and walks in.
fn join(w: &mut World, id: &str, room: &str) -> Vec<Event> {
    w.submit(Command::Arrive {
        occupant: id.into(),
        profile: Some(player(id)),
        room: Some(room.into()),
        player: true,
    });
    until(w, 60, |w| {
        w.snapshot()
            .occupants
            .get(&CityId::from(id))
            .is_some_and(|o| o.walk.is_none() && matches!(o.location, Location::InRoom { .. }))
    })
}

fn cell_of(w: &World, p: Point) -> city_core::nav::Cell {
    w.nav().unwrap().cell_of(p)
}

/// Walks `id` to the cell holding `p` with `Go`, and waits there.
fn walk_to(w: &mut World, id: &str, p: Point) -> Vec<Event> {
    w.submit(Command::Go {
        occupant: id.into(),
        to: Target::Point { pos: p },
    });
    until(w, 80, |w| {
        let o = &w.snapshot().occupants[&CityId::from(id)];
        o.walk.is_none() && o.pos.map(|q| cell_of(w, q)) == Some(cell_of(w, p))
    })
}

fn use_it(id: &str, target: &str, capability: &str) -> Command {
    Command::Use {
        occupant: id.into(),
        target: target.into(),
        capability: capability.into(),
        anchor: 0,
    }
}

/// The kinds of `who`'s events.
fn of(events: &[Event], who: &str) -> Vec<EventKind> {
    events
        .iter()
        .filter(|e| e.occupant.as_ref().is_some_and(|o| o.as_str() == who))
        .map(|e| e.kind.clone())
        .collect()
}

fn began(target: &str, capability: &str) -> EventKind {
    EventKind::Using {
        target: target.into(),
        capability: capability.into(),
        anchor: 0,
    }
}

fn stopped(target: &str) -> EventKind {
    EventKind::StoppedUsing {
        target: target.into(),
    }
}

fn uses(w: &World, id: &str) -> Option<Using> {
    w.snapshot().occupants[&CityId::from(id)].using.clone()
}

fn in_use(w: &World, target: &str) -> bool {
    w.snapshot().occupants.values().any(|o| {
        o.using
            .as_ref()
            .is_some_and(|u| u.target.as_str() == target)
    })
}

fn shown(w: &World, id: &str) -> Option<Using> {
    city_core::project(w.snapshot(), &Viewer::Operator)
        .rooms
        .iter()
        .flat_map(|r| &r.occupants)
        .find(|o| o.id.as_str() == id)
        .expect("shown")
        .using
        .clone()
}

fn bytes(log: &[Event]) -> Vec<String> {
    log.iter()
        .map(|e| serde_json::to_string(e).unwrap())
        .collect()
}

/// A player who joined and sat on the plaza's bench.
fn sat_on_bench() -> World {
    let mut w = world(with_bench());
    join(&mut w, "person:a", "room:plaza");
    walk_to(&mut w, "person:a", BENCH);
    w.submit(use_it("person:a", "placement:bench", "sit"));
    let events = step(&mut w);
    assert_eq!(
        of(&events, "person:a"),
        vec![began("placement:bench", "sit")]
    );
    assert_eq!(shown(&w, "person:a"), uses(&w, "person:a"));
    w
}

/// A player who took seat w1 by `Go`, walked there and sat with `Use`.
fn sat_in_w1() -> World {
    let mut w = world(with_bench());
    join(&mut w, "person:a", "room:plaza");
    w.submit(Command::Go {
        occupant: "person:a".into(),
        to: Target::Seat {
            seat: "seat:w1".into(),
        },
    });
    until(&mut w, 80, |w| {
        let o = &w.snapshot().occupants[&CityId::from("person:a")];
        o.walk.is_none()
            && matches!(&o.location, Location::InRoom { seat: Some(s), .. } if s.as_str() == "seat:w1")
    });
    w.submit(use_it("person:a", "seat:w1", "sit"));
    let events = step(&mut w);
    // Already its seat: only the use begins.
    assert_eq!(of(&events, "person:a"), vec![began("seat:w1", "sit")]);
    w
}

#[test]
fn every_move_stop_and_departure_releases_a_perch() {
    let a = CityId::from("person:a");
    let next = sat_on_bench().snapshot().occupants[&a]
        .pos
        .map(|p| Point {
            x: p.x,
            z: p.z - 25,
        })
        .unwrap();
    for command in [
        Command::StopUsing {
            occupant: a.clone(),
        },
        Command::Move {
            occupant: a.clone(),
            to: "room:work".into(),
        },
        Command::Go {
            occupant: a.clone(),
            to: Target::Point {
                pos: Point { x: 600, z: 1000 },
            },
        },
        Command::Go {
            occupant: a.clone(),
            to: Target::Room {
                room: "room:work".into(),
            },
        },
        Command::Steer {
            occupant: a.clone(),
            cells: vec![next],
        },
        // A player's disconnect is its departure at once.
        Command::Depart {
            occupant: a.clone(),
            player: true,
        },
    ] {
        let mut w = sat_on_bench();
        w.submit(command.clone());
        let events = step(&mut w);
        assert!(
            of(&events, "person:a").contains(&stopped("placement:bench")),
            "{command:?}: {events:?}"
        );
        assert_eq!(uses(&w, "person:a"), None, "{command:?}");
        assert!(!in_use(&w, "placement:bench"), "{command:?}");
    }
}

#[test]
fn stopping_nothing_emits_nothing_and_a_refused_move_keeps_the_use() {
    let mut w = sat_on_bench();
    join(&mut w, "person:b", "room:plaza");
    w.submit(Command::StopUsing {
        occupant: "person:b".into(),
    });
    // Its own room: refused, so it keeps sitting.
    w.submit(Command::Move {
        occupant: "person:a".into(),
        to: "room:plaza".into(),
    });
    let events = step(&mut w);
    assert!(of(&events, "person:b").is_empty());
    assert!(uses(&w, "person:a").is_some());
}

#[test]
fn a_room_seat_used_is_released_by_leaving_it() {
    for leave in [
        Command::Go {
            occupant: "person:a".into(),
            to: Target::Room {
                room: "room:plaza".into(),
            },
        },
        Command::Depart {
            occupant: "person:a".into(),
            player: true,
        },
        Command::Steer {
            occupant: "person:a".into(),
            cells: Vec::new(),
        },
        Command::StopUsing {
            occupant: "person:a".into(),
        },
    ] {
        let mut w = sat_in_w1();
        w.submit(leave.clone());
        let events = step(&mut w);
        let mine = of(&events, "person:a");
        let released = mine
            .iter()
            .position(|e| matches!(e, EventKind::SeatReleased { .. }))
            .unwrap_or_else(|| panic!("{leave:?}: {mine:?}"));
        assert_eq!(mine[released + 1], stopped("seat:w1"), "{leave:?}");
        assert_eq!(uses(&w, "person:a"), None);
        assert_eq!(seat_of(&w, "person:a"), None);
    }
}

#[test]
fn a_go_to_the_seat_one_sits_in_keeps_its_use() {
    let mut w = sat_in_w1();
    w.submit(Command::Go {
        occupant: "person:a".into(),
        to: Target::Seat {
            seat: "seat:w1".into(),
        },
    });
    let events = step(&mut w);
    assert!(of(&events, "person:a").is_empty());
    assert!(uses(&w, "person:a").is_some());
}

#[test]
fn moving_or_removing_a_placement_releases_its_users() {
    for command in [
        Command::MovePlacement {
            id: "placement:bench".into(),
            at: Point { x: 1000, z: 700 },
            facing: 0,
            by: None,
        },
        Command::RemovePlacement {
            id: "placement:bench".into(),
            by: None,
        },
    ] {
        let mut w = sat_on_bench();
        w.submit(command.clone());
        let events = step(&mut w);
        assert!(
            events
                .iter()
                .any(|e| matches!(e.kind, EventKind::PlacementChanged { .. })),
            "{command:?}: {events:?}"
        );
        assert_eq!(
            of(&events, "person:a"),
            vec![stopped("placement:bench")],
            "{command:?}"
        );
        assert_eq!(uses(&w, "person:a"), None);
    }
}

#[test]
fn a_seat_taken_by_the_policy_shows_as_a_use_once_sat_in() {
    // An agent arriving for the workshop is seated by the policy and walks
    // to its desk; once there, its projection shows it sitting, though no
    // `Use` began it and no event says so.
    let mut w = World::new(district_small(), feed(&[arrive(1, "agent:a")]), 3).unwrap();
    let mut log = Vec::new();
    let mut seen_walking = false;
    for _ in 0..60 {
        log.extend(step(&mut w));
        let o = &w.snapshot().occupants[&CityId::from("agent:a")];
        if matches!(o.location, Location::InRoom { seat: Some(_), .. }) && o.walk.is_some() {
            seen_walking = true;
            assert_eq!(shown(&w, "agent:a"), None, "not while walking to it");
        }
    }
    assert!(seen_walking);
    let seat = seat_of(&w, "agent:a").expect("seated");
    assert_eq!(
        shown(&w, "agent:a"),
        Some(Using {
            target: seat.as_str().into(),
            capability: "sit".into(),
            anchor: 0,
        })
    );
    assert_eq!(uses(&w, "agent:a"), None, "nothing is recorded");
    assert!(!log.iter().any(|e| matches!(
        e.kind,
        EventKind::Using { .. } | EventKind::StoppedUsing { .. }
    )));
}

#[test]
fn going_in_through_use_is_go_room() {
    let run = |command: Command| {
        let mut w = world(with_bench());
        join(&mut w, "person:a", "room:plaza");
        w.submit(command);
        let mut log = Vec::new();
        for _ in 0..20 {
            log.extend(step(&mut w));
        }
        assert_eq!(room_of(&w, "person:a").as_deref(), Some("room:work"));
        (bytes(&log), serde_json::to_string(w.snapshot()).unwrap())
    };
    let by_go = run(Command::Go {
        occupant: "person:a".into(),
        to: Target::Room {
            room: "room:work".into(),
        },
    });
    let by_use = run(use_it("person:a", "room:work", "enter"));
    assert_eq!(by_go, by_use);
}

#[test]
fn boarding_through_use_is_board() {
    let run = |command: Command| {
        let mut w = world(tram_platform());
        join(&mut w, "person:p", "room:north-a");
        w.submit(command);
        let mut log = Vec::new();
        for _ in 0..60 {
            log.extend(step(&mut w));
        }
        assert!(
            of(&log, "person:p")
                .iter()
                .any(|e| matches!(e, EventKind::Boarded { .. })),
            "{log:?}"
        );
        (bytes(&log), serde_json::to_string(w.snapshot()).unwrap())
    };
    let by_board = run(Command::Board {
        occupant: "person:p".into(),
    });
    let by_use = run(use_it("person:p", "line:boulevard", "board"));
    assert_eq!(by_board, by_use);
}

#[test]
fn a_tram_standing_there_is_boarded_by_naming_it() {
    let mut w = world(tram_platform());
    join(&mut w, "person:p", "room:north-a");
    walk_to(&mut w, "person:p", Point { x: 900, z: 100 });
    let tram = "vehicle:boulevard:east:1";
    until(&mut w, 80, |w| {
        w.snapshot()
            .vehicles
            .iter()
            .any(|v| v.id.as_str() == tram && matches!(v.status, VehicleStatus::Standing { .. }))
    });
    w.submit(use_it("person:p", tram, "board"));
    let events = step(&mut w);
    assert!(
        of(&events, "person:p")
            .iter()
            .any(|e| matches!(e, EventKind::Boarded { .. })),
        "{events:?}"
    );
}

#[test]
fn boarding_releases_a_perch_on_the_platform() {
    let mut w = world(tram_platform());
    join(&mut w, "person:p", "room:north-a");
    walk_to(&mut w, "person:p", Point { x: 1500, z: 75 });
    w.submit(use_it("person:p", "placement:bench", "sit"));
    let events = step(&mut w);
    assert_eq!(
        of(&events, "person:p"),
        vec![began("placement:bench", "sit")]
    );
    w.submit(Command::Board {
        occupant: "person:p".into(),
    });
    let events = step(&mut w);
    assert!(of(&events, "person:p").contains(&stopped("placement:bench")));
    assert_eq!(uses(&w, "person:p"), None);
    let log = until(&mut w, 80, |w| {
        matches!(
            w.snapshot().occupants[&CityId::from("person:p")].location,
            Location::Aboard { .. }
        )
    });
    assert!(!of(&log, "person:p").contains(&began("placement:bench", "sit")));
    assert_eq!(uses(&w, "person:p"), None);
}

#[test]
fn a_replay_with_uses_is_byte_identical() {
    let mut w = world(with_bench());
    let mut log = join(&mut w, "person:you", "room:plaza");
    log.extend(walk_to(&mut w, "person:you", BENCH));
    for command in [
        use_it("person:you", "placement:bench", "sit"),
        Command::StopUsing {
            occupant: "person:you".into(),
        },
        use_it("person:you", "placement:bench", "sit"),
        use_it("person:you", "room:work", "enter"),
    ] {
        w.submit(command);
        for _ in 0..3 {
            log.extend(step(&mut w));
        }
    }
    assert_eq!(
        log.iter()
            .filter(|e| matches!(e.kind, EventKind::Using { .. }))
            .count(),
        2,
        "{log:?}"
    );
    let replay = city_core::merge(feed(&[]), w.input_log_feed()).unwrap();
    let mut again = World::new(with_bench(), replay, 3).unwrap();
    let log2 = again.run(w.snapshot().tick);
    assert_eq!(bytes(&log), bytes(&log2));
    assert_eq!(
        serde_json::to_string(w.snapshot()).unwrap(),
        serde_json::to_string(again.snapshot()).unwrap()
    );
}

// ---- Workstations ----

/// `district_small` with its workshop's two desks made workstations: seat
/// w1 at (200, 150), facing north. Anchor 0 is the chair's `sit`, 1 its
/// `use`, at the same point.
fn with_workstations() -> Manifest {
    let mut m = district_small();
    for seat in &mut m.city.districts[0].facilities[0].rooms[0].seats {
        seat.kind = Some("workstation".into());
    }
    m
}

fn use_at(id: &str, target: &str, capability: &str, anchor: u32) -> Command {
    Command::Use {
        occupant: id.into(),
        target: target.into(),
        capability: capability.into(),
        anchor,
    }
}

/// A player who took seat w1 by `Go`, walked there, and used the computer
/// (the unit tests have `Use` take the seat itself).
fn using_w1(w: &mut World, id: &str) -> Vec<Event> {
    let mut log = join(w, id, "room:plaza");
    w.submit(Command::Go {
        occupant: id.into(),
        to: Target::Seat {
            seat: "seat:w1".into(),
        },
    });
    log.extend(until(w, 80, |w| {
        let o = &w.snapshot().occupants[&CityId::from(id)];
        o.walk.is_none()
            && matches!(&o.location, Location::InRoom { seat: Some(s), .. } if s.as_str() == "seat:w1")
    }));
    w.submit(use_at(id, "seat:w1", "use", 1));
    let events = step(w);
    // Already its seat: only the use begins.
    assert_eq!(
        of(&events, id),
        vec![EventKind::Using {
            target: "seat:w1".into(),
            capability: "use".into(),
            anchor: 1
        }]
    );
    assert_eq!(shown(w, id), uses(w, id));
    log.extend(events);
    log
}

#[test]
fn a_workstation_used_is_released_by_every_way_of_leaving_it() {
    let a = CityId::from("person:a");
    for leave in [
        Command::Go {
            occupant: a.clone(),
            to: Target::Room {
                room: "room:plaza".into(),
            },
        },
        Command::Go {
            occupant: a.clone(),
            to: Target::Point {
                pos: Point { x: 600, z: 1000 },
            },
        },
        Command::Move {
            occupant: a.clone(),
            to: "room:plaza".into(),
        },
        Command::Depart {
            occupant: a.clone(),
            player: true,
        },
        Command::Steer {
            occupant: a.clone(),
            cells: Vec::new(),
        },
        Command::StopUsing {
            occupant: a.clone(),
        },
    ] {
        let mut w = world(with_workstations());
        using_w1(&mut w, "person:a");
        w.submit(leave.clone());
        let events = step(&mut w);
        let mine = of(&events, "person:a");
        let released = mine
            .iter()
            .position(|e| matches!(e, EventKind::SeatReleased { .. }))
            .unwrap_or_else(|| panic!("{leave:?}: {mine:?}"));
        assert_eq!(mine[released + 1], stopped("seat:w1"), "{leave:?}");
        assert_eq!(uses(&w, "person:a"), None, "{leave:?}");
        assert_eq!(seat_of(&w, "person:a"), None, "{leave:?}");
        assert!(!in_use(&w, "seat:w1"), "{leave:?}");
    }
}

#[test]
fn an_agent_seated_at_a_workstation_by_the_policy_is_shown_sitting() {
    // Agents never send `Use`: the policy seats one at a workstation as at
    // a desk, and its projection shows it sitting, with no event of it.
    let mut w = World::new(with_workstations(), feed(&[arrive(1, "agent:a")]), 3).unwrap();
    let mut log = Vec::new();
    for _ in 0..60 {
        log.extend(step(&mut w));
    }
    let seat = seat_of(&w, "agent:a").expect("seated");
    assert_eq!(
        shown(&w, "agent:a"),
        Some(Using {
            target: seat.as_str().into(),
            capability: "sit".into(),
            anchor: 0,
        })
    );
    assert_eq!(uses(&w, "agent:a"), None, "nothing is recorded");
    assert!(!log.iter().any(|e| matches!(
        e.kind,
        EventKind::Using { .. } | EventKind::StoppedUsing { .. }
    )));
    // Its day is a desk's day, event for event.
    let mut desks = World::new(district_small(), feed(&[arrive(1, "agent:a")]), 3).unwrap();
    let mut desk_log = Vec::new();
    for _ in 0..60 {
        desk_log.extend(step(&mut desks));
    }
    assert_eq!(bytes(&log), bytes(&desk_log));
}

#[test]
fn a_replay_with_workstation_uses_is_byte_identical() {
    let mut w = world(with_workstations());
    let mut log = using_w1(&mut w, "person:you");
    for command in [
        use_at("person:you", "seat:w1", "sit", 0),
        use_at("person:you", "seat:w1", "use", 1),
        // Refused: the core keeps nothing of watching.
        use_at("person:you", "seat:w1", "watch", 3),
        Command::StopUsing {
            occupant: "person:you".into(),
        },
    ] {
        w.submit(command);
        for _ in 0..3 {
            log.extend(step(&mut w));
        }
    }
    assert_eq!(
        log.iter()
            .filter(|e| matches!(e.kind, EventKind::Using { .. }))
            .count(),
        3,
        "{log:?}"
    );
    assert_eq!(
        log.iter()
            .filter(|e| matches!(e.kind, EventKind::Seated { .. }))
            .count(),
        1,
        "switching keeps the seat: {log:?}"
    );
    let replay = city_core::merge(feed(&[]), w.input_log_feed()).unwrap();
    let mut again = World::new(with_workstations(), replay, 3).unwrap();
    let log2 = again.run(w.snapshot().tick);
    assert_eq!(bytes(&log), bytes(&log2));
    assert_eq!(
        serde_json::to_string(w.snapshot()).unwrap(),
        serde_json::to_string(again.snapshot()).unwrap()
    );
}
