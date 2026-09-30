//! Walking: arrival through entrances, admission at doors, seats, queues,
//! moves between rooms and departure, in a manifest with a layout.

mod common;

use city_contracts::*;
use city_core::nav::{CELL, Cell};
use city_core::{World, project};
use common::*;
use serde_json::json;

fn world(lines: &[serde_json::Value]) -> World {
    World::new(district_small(), feed(lines), 3).unwrap()
}

fn cell(w: &World, p: Point) -> Cell {
    w.nav().unwrap().cell_of(p)
}

fn room_at(w: &World, p: Point) -> Option<String> {
    w.nav()
        .unwrap()
        .room_at(cell(w, p))
        .map(ToString::to_string)
}

/// Steps until `done` holds or `limit` ticks pass; returns all events.
fn run_until(w: &mut World, limit: u64, done: impl Fn(&World) -> bool) -> Vec<Event> {
    let mut all = Vec::new();
    for _ in 0..limit {
        if done(w) {
            break;
        }
        all.extend(w.step());
    }
    assert!(done(w), "condition not reached within {limit} ticks");
    all
}

fn settled(w: &World, id: &str) -> bool {
    let Some(o) = w.snapshot().occupants.get(&CityId::from(id)) else {
        return false;
    };
    o.walk.is_none() && matches!(o.location, Location::InRoom { .. })
}

#[test]
fn arrival_walks_from_the_entrance_and_is_admitted_at_the_door() {
    let mut w = world(&[arrive(1, "agent:a")]);
    let door = Point { x: 400, z: 400 };
    let mut last_distance = i64::MAX;
    let mut admitted_from = None;
    for _ in 0..40 {
        let before = w.snapshot().clone();
        let ev = w.step();
        if ev
            .iter()
            .any(|e| matches!(e.kind, EventKind::Admitted { .. }))
        {
            admitted_from = before.occupants[&CityId::from("agent:a")].pos;
            break;
        }
        let p = pos_of(&w, "agent:a").expect("walking occupants have a position");
        let d = i64::from(p.x - door.x).pow(2) + i64::from(p.z - door.z).pow(2);
        assert!(d <= last_distance, "walking away from the door");
        last_distance = d;
    }
    let at = admitted_from.expect("admitted");
    assert_eq!(
        room_at(&w, at).as_deref(),
        Some("room:plaza"),
        "admitted at the threshold"
    );
    run_until(&mut w, 40, |w| settled(w, "agent:a"));
    assert_eq!(seat_of(&w, "agent:a").as_deref(), Some("seat:w1"));
    let seat_cell = w.nav().unwrap().cell_of(Point { x: 200, z: 150 });
    assert_eq!(
        pos_of(&w, "agent:a"),
        Some(w.nav().unwrap().centre(seat_cell))
    );
}

#[test]
fn each_step_moves_at_most_five_cells() {
    let mut w = world(&[
        arrive(1, "agent:a"),
        arrive(1, "agent:b"),
        arrive(2, "agent:c"),
    ]);
    let mut last: std::collections::BTreeMap<String, Point> = Default::default();
    for _ in 0..60 {
        w.step();
        for (id, o) in &w.snapshot().occupants {
            if let Some(p) = o.pos {
                if let Some(q) = last.get(id.as_str()) {
                    assert!((p.x - q.x).abs() <= 5 * CELL && (p.z - q.z).abs() <= 5 * CELL);
                }
                assert!(w.nav().unwrap().walkable(cell(&w, p)), "{id} off the grid");
                last.insert(id.to_string(), p);
            }
        }
    }
}

#[test]
fn overflow_walks_on_to_the_next_room() {
    let mut w = world(&[
        arrive(1, "agent:a"),
        arrive(3, "agent:b"),
        arrive(5, "agent:c"),
    ]);
    let ev = run_until(&mut w, 80, |w| {
        ["agent:a", "agent:b", "agent:c"]
            .iter()
            .all(|id| settled(w, id))
    });
    assert!(ev.iter().any(
        |e| e.occupant.as_ref().is_some_and(|o| o.as_str() == "agent:c")
            && matches!(&e.kind, EventKind::Overflowed { to, .. } if to.as_str() == "room:commons")
    ));
    assert_eq!(seat_of(&w, "agent:c").as_deref(), Some("seat:c1"));
    assert_eq!(
        room_at(&w, pos_of(&w, "agent:c").unwrap()).as_deref(),
        Some("room:commons")
    );
}

#[test]
fn a_queue_forms_outside_the_full_room_and_advances_in_order() {
    let mut w = world(&[
        arrive(1, "agent:a"),
        arrive(1, "agent:b"),
        arrive(1, "agent:c"),
        arrive(3, "agent:d"),
        arrive(5, "agent:e"),
    ]);
    run_until(&mut w, 80, |w| {
        let o = &w.snapshot().occupants;
        ["agent:d", "agent:e"].iter().all(|id| {
            let s = &o[&CityId::from(*id)];
            matches!(s.location, Location::Waitlisted { .. }) && s.walk.is_none()
        })
    });
    let work = &w.snapshot().rooms[&PlaceId::from("room:work")];
    assert_eq!(
        work.waitlist,
        vec![CityId::from("agent:d"), CityId::from("agent:e")]
    );
    let (pd, pe) = (
        pos_of(&w, "agent:d").unwrap(),
        pos_of(&w, "agent:e").unwrap(),
    );
    assert_ne!(pd, pe);
    for p in [pd, pe] {
        assert_eq!(
            room_at(&w, p).as_deref(),
            Some("room:plaza"),
            "queues form outside"
        );
    }
    let slots = w.nav().unwrap().queue_slots(&PlaceId::from("room:work"), 2);
    assert_eq!(cell(&w, pd), slots[0]);
    assert_eq!(cell(&w, pe), slots[1]);
}

#[test]
fn the_queue_head_is_admitted_when_someone_leaves() {
    let mut w = world(&[
        arrive(1, "agent:a"),
        arrive(3, "agent:b"),
        arrive(5, "agent:c"),
        arrive(7, "agent:d"),
        arrive(9, "agent:e"),
        depart(60, "agent:a"),
    ]);
    run_until(&mut w, 120, |w| settled(w, "agent:d"));
    assert_eq!(room_of(&w, "agent:d").as_deref(), Some("room:work"));
    run_until(&mut w, 40, |w| {
        w.snapshot().occupants[&CityId::from("agent:e")]
            .walk
            .is_none()
    });
    let slots = w.nav().unwrap().queue_slots(&PlaceId::from("room:work"), 1);
    assert_eq!(
        cell(&w, pos_of(&w, "agent:e").unwrap()),
        slots[0],
        "e moved up"
    );
}

#[test]
fn move_between_rooms_walks_through_doors() {
    let mut w = world(&[arrive(1, "agent:a"), mv(40, "agent:a", "room:commons")]);
    let mut rooms_seen = Vec::new();
    for _ in 0..120 {
        w.step();
        if let Some(p) = pos_of(&w, "agent:a") {
            let r = room_at(&w, p).unwrap();
            if rooms_seen.last() != Some(&r) {
                rooms_seen.push(r);
            }
        }
    }
    assert_eq!(room_of(&w, "agent:a").as_deref(), Some("room:commons"));
    assert_eq!(seat_of(&w, "agent:a").as_deref(), Some("seat:c1"));
    assert_eq!(rooms_seen.last().map(String::as_str), Some("room:commons"));
    assert!(rooms_seen.contains(&"room:work".to_string()));
}

#[test]
fn departure_releases_the_seat_once_and_walks_out() {
    let mut w = world(&[arrive(1, "agent:a"), depart(40, "agent:a")]);
    let mut ev = w.run(5);
    ev.extend(run_until(&mut w, 120, |w| {
        matches!(
            w.snapshot().occupants[&CityId::from("agent:a")].location,
            Location::Away
        )
    }));
    let of_a = |k: &str| {
        ev.iter()
            .filter(|e| e.occupant.as_ref().is_some_and(|o| o.as_str() == "agent:a"))
            .filter(|e| type_name(&e.kind) == k)
            .collect::<Vec<_>>()
    };
    assert_eq!(of_a("SeatReleased").len(), 1);
    assert_eq!(of_a("Departed").len(), 1);
    assert_eq!(of_a("SeatReleased")[0].tick, 40);
    assert!(of_a("Departed")[0].tick > 40, "walks to the exit first");
    assert_eq!(pos_of(&w, "agent:a"), None);
    let seats = &w.snapshot().rooms[&PlaceId::from("room:work")].seats;
    assert!(seats.values().all(Option::is_none));
}

#[test]
fn departure_while_queued_or_walking_in_leaves_once() {
    let mut w = world(&[
        arrive(1, "agent:a"),
        arrive(1, "agent:b"),
        arrive(1, "agent:c"),
        arrive(3, "agent:d"),
        arrive(4, "agent:e"),
        depart(5, "agent:e"),
        depart(40, "agent:d"),
    ]);
    let ev = w.run(150);
    for id in ["agent:d", "agent:e"] {
        let departed = ev
            .iter()
            .filter(|e| e.occupant.as_ref().is_some_and(|o| o.as_str() == id))
            .filter(|e| matches!(e.kind, EventKind::Departed { .. }))
            .count();
        assert_eq!(departed, 1, "{id}");
        assert!(matches!(location(&w, id), Location::Away));
    }
    assert!(
        w.snapshot().rooms[&PlaceId::from("room:work")]
            .waitlist
            .is_empty()
    );
}

#[test]
fn unreachable_target_is_rejected() {
    let mut w = world(&[
        json!({"at": 1, "command": {"type": "Arrive", "occupant": "agent:a", "room": "room:island"}}),
    ]);
    let ev = w.run(1);
    assert!(ev.iter().any(|e| matches!(
        e.kind,
        EventKind::Rejected {
            reason: RejectReason::Unreachable,
            ..
        }
    )));
}

#[test]
fn layoutless_worlds_have_no_positions() {
    let mut w = World::new(
        hall(),
        feed(&[arrive(1, "agent:a"), arrive(1, "agent:b")]),
        1,
    )
    .unwrap();
    w.run(5);
    assert!(w.nav().is_none());
    assert!(
        w.snapshot()
            .occupants
            .values()
            .all(|o| o.pos.is_none() && o.walk.is_none())
    );
}

// ---- Avoidance and overlays (A5) ----

fn visitor(at: u64, id: &str, room: &str, tier: &str) -> serde_json::Value {
    json!({"at": at, "command": {"type": "Arrive", "occupant": id, "room": room,
        "profile": {"id": id, "display_name": id, "kind": {"type": "Human", "tier": tier}}}})
}

fn private_agent(at: u64, id: &str, room: &str) -> serde_json::Value {
    json!({"at": at, "command": {"type": "Arrive", "occupant": id, "room": room,
        "profile": {"id": id, "display_name": id,
                    "kind": {"type": "PersonalAgent", "owner": "person:v0"}}}})
}

fn visible_cells_are_unique(w: &World) {
    let mut seen = std::collections::BTreeMap::new();
    for (id, o) in &w.snapshot().occupants {
        let hidden = matches!(
            o.profile.kind,
            OccupantKind::PersonalAgent { .. }
                | OccupantKind::Human {
                    tier: HumanTier::Observer
                }
        );
        if let (Some(p), false) = (o.pos, hidden) {
            let c = cell(w, p);
            if let Some(other) = seen.insert(c, id.clone()) {
                panic!("tick {}: {id} and {other} share {c:?}", w.snapshot().tick);
            }
        }
    }
}

#[test]
fn walkers_never_share_a_cell() {
    let lines: Vec<_> = (0..12)
        .map(|n| visitor(1, &format!("person:v{n}"), "room:plaza", "Registered"))
        .chain([
            arrive(1, "agent:a"),
            arrive(1, "agent:b"),
            arrive(1, "agent:c"),
        ])
        .collect();
    let mut w = world(&lines);
    for _ in 0..80 {
        w.step();
        visible_cells_are_unique(&w);
    }
    assert!(settled(&w, "agent:a") && settled(&w, "agent:b"));
    for n in 0..12 {
        assert!(settled(&w, &format!("person:v{n}")), "v{n} still walking");
    }
}

#[test]
fn meeting_at_a_door_resolves() {
    let mut w = world(&[
        arrive(1, "agent:a"),
        arrive(1, "agent:b"),
        depart(30, "agent:a"),
        depart(30, "agent:b"),
        arrive(30, "agent:c"),
        arrive(30, "agent:d"),
    ]);
    w.run(30);
    let ev = run_until(&mut w, 60, |w| {
        settled(w, "agent:c")
            && settled(w, "agent:d")
            && ["agent:a", "agent:b"]
                .iter()
                .all(|id| matches!(location(w, id), Location::Away))
    });
    let _ = ev;
    visible_cells_are_unique(&w);
}

fn visible_trace(lines: &[serde_json::Value], ticks: u64) -> Vec<String> {
    let mut w = world(lines);
    let mut trace = Vec::new();
    for _ in 0..ticks {
        for e in w.step() {
            if e.occupant
                .as_ref()
                .is_some_and(|o| !o.as_str().starts_with("pa:"))
            {
                trace.push(format!(
                    "{} {:?} {}",
                    e.tick,
                    e.occupant,
                    serde_json::to_string(&e.kind).unwrap()
                ));
            }
        }
        for (id, o) in &w.snapshot().occupants {
            if !id.as_str().starts_with("pa:") {
                trace.push(format!(
                    "{} {id} {:?} {:?}",
                    w.snapshot().tick,
                    o.pos,
                    o.walk.as_ref().map(|x| &x.path)
                ));
            }
        }
    }
    trace
}

#[test]
fn hidden_overlays_never_divert_visible_walkers() {
    let base: Vec<_> = (0..6)
        .map(|n| visitor(2, &format!("person:v{n}"), "room:plaza", "Registered"))
        .chain([
            arrive(2, "agent:a"),
            arrive(2, "agent:b"),
            arrive(3, "agent:c"),
            depart(40, "agent:a"),
        ])
        .collect();
    let mut with_hidden = vec![
        private_agent(1, "pa:0", "room:plaza"),
        private_agent(1, "pa:1", "room:work"),
        private_agent(1, "pa:2", "room:plaza"),
    ];
    with_hidden.extend(base.clone());
    assert_eq!(visible_trace(&base, 80), visible_trace(&with_hidden, 80));
}

#[test]
fn arrivals_start_on_free_cells_near_the_entrance() {
    let lines: Vec<_> = (0..4)
        .map(|n| visitor(1, &format!("person:v{n}"), "room:work", "Registered"))
        .collect();
    let mut w = world(&lines);
    w.run(1);
    visible_cells_are_unique(&w);
}

// ---- Projections of motion (A6) ----

fn find_view<'a>(p: &'a Projection, id: &str) -> Option<&'a OccupantView> {
    p.rooms
        .iter()
        .flat_map(|r| r.occupants.iter().chain(&r.waiting))
        .chain(&p.in_transit)
        .find(|o| o.id.as_str() == id)
}

#[test]
fn projection_carries_positions_and_paths() {
    let mut w = world(&[arrive(1, "agent:a")]);
    w.run(2);
    let p = project(w.snapshot(), &Viewer::Public);
    let a = find_view(&p, "agent:a").expect("visible while walking");
    assert!(a.moving);
    assert_eq!(a.pos, pos_of(&w, "agent:a"));
    let walk = w.snapshot().occupants[&CityId::from("agent:a")]
        .walk
        .clone()
        .unwrap();
    assert_eq!(
        a.path_ahead,
        walk.path.iter().take(5).copied().collect::<Vec<_>>()
    );
    assert!(!a.path_ahead.is_empty());
    run_until(&mut w, 60, |w| settled(w, "agent:a"));
    let p = project(w.snapshot(), &Viewer::Public);
    let a = find_view(&p, "agent:a").unwrap();
    assert!(!a.moving && a.path_ahead.is_empty());
}

#[test]
fn walkers_are_listed_in_transit_until_admitted() {
    let mut w = world(&[arrive(1, "agent:a")]);
    w.run(1);
    let p = project(w.snapshot(), &Viewer::Public);
    assert!(p.in_transit.iter().any(|o| o.id.as_str() == "agent:a"));
    run_until(&mut w, 60, |w| settled(w, "agent:a"));
    let p = project(w.snapshot(), &Viewer::Public);
    assert!(p.in_transit.is_empty());
}

#[test]
fn queued_occupants_show_their_place() {
    let mut w = world(&[
        arrive(1, "agent:a"),
        arrive(3, "agent:b"),
        arrive(5, "agent:c"),
        arrive(7, "agent:d"),
        arrive(9, "agent:e"),
    ]);
    run_until(&mut w, 80, |w| {
        w.snapshot().rooms[&PlaceId::from("room:work")]
            .waitlist
            .len()
            == 2
    });
    let p = project(w.snapshot(), &Viewer::Public);
    let q = |id| find_view(&p, id).and_then(|o| o.queue.clone());
    assert_eq!(
        q("agent:d"),
        Some(QueueSpot {
            room: "room:work".into(),
            position: 1
        })
    );
    assert_eq!(
        q("agent:e"),
        Some(QueueSpot {
            room: "room:work".into(),
            position: 2
        })
    );
}

#[test]
fn time_of_day_advances_and_wraps() {
    let mut w = world(&[]);
    assert_eq!(
        project(w.snapshot(), &Viewer::Public).time_of_day,
        Some(420)
    );
    w.run(300);
    assert_eq!(
        project(w.snapshot(), &Viewer::Public).time_of_day,
        Some(1140)
    );
    w.run(300);
    assert_eq!(
        project(w.snapshot(), &Viewer::Public).time_of_day,
        Some(420)
    );
    let layoutless = World::new(hall(), feed(&[]), 1).unwrap();
    assert_eq!(
        project(layoutless.snapshot(), &Viewer::Public).time_of_day,
        None
    );
}

#[test]
fn public_projection_never_contains_hidden_walkers() {
    let mut w = world(&[
        private_agent(1, "pa:0", "room:work"),
        visitor(1, "person:obs", "room:plaza", "Observer"),
        arrive(1, "agent:a"),
    ]);
    for _ in 0..40 {
        w.step();
        let p = project(w.snapshot(), &Viewer::Public);
        assert!(find_view(&p, "pa:0").is_none() && find_view(&p, "person:obs").is_none());
        let owner = project(
            w.snapshot(),
            &Viewer::Person {
                id: "person:v0".into(),
            },
        );
        assert!(
            find_view(&owner, "pa:0").is_some(),
            "the owner sees it at tick {}",
            w.snapshot().tick
        );
    }
}

// ---- What actually happened last tick (review fix) ----

#[test]
fn the_trail_is_the_cells_actually_crossed_last_tick() {
    let mut w = world(&[arrive(1, "agent:a")]);
    w.run(1);
    let before = pos_of(&w, "agent:a").unwrap();
    w.step();
    let p = project(w.snapshot(), &Viewer::Public);
    let a = find_view(&p, "agent:a").unwrap();
    assert!(!a.trail.is_empty() && a.trail.len() <= 5);
    assert_eq!(
        a.trail.last().copied(),
        a.pos,
        "the trail ends where the walker is"
    );
    let first = w.nav().unwrap().cell_of(a.trail[0]);
    let start = w.nav().unwrap().cell_of(before);
    assert!(
        (first.i - start.i).abs() <= 1 && (first.j - start.j).abs() <= 1,
        "it starts next to where it was"
    );
}

#[test]
fn a_blocked_or_settled_walker_has_no_trail() {
    let mut w = world(&[arrive(1, "agent:a")]);
    run_until(&mut w, 60, |w| settled(w, "agent:a"));
    w.step();
    let p = project(w.snapshot(), &Viewer::Public);
    assert!(find_view(&p, "agent:a").unwrap().trail.is_empty());
}

// ---- Players: Go (Stage 5) ----

fn go(at: u64, id: &str, to: serde_json::Value) -> serde_json::Value {
    json!({"at": at, "command": {"type": "Go", "occupant": id, "to": to}})
}

fn point(x: i32, z: i32) -> serde_json::Value {
    json!({"type": "Point", "pos": {"x": x, "z": z}})
}

fn seat(id: &str) -> serde_json::Value {
    json!({"type": "Seat", "seat": id})
}

fn to_room(id: &str) -> serde_json::Value {
    json!({"type": "Room", "room": id})
}

/// Steps once and asserts every invariant, movement included.
fn step_checked(w: &mut World) -> Vec<Event> {
    let before = w.snapshot().clone();
    let ev = w.step();
    let v = city_core::invariants::check_world(&before, w, &ev);
    assert!(v.is_empty(), "tick {}: {v:?}", w.snapshot().tick);
    ev
}

fn run_checked(w: &mut World, ticks: u64) -> Vec<Event> {
    (0..ticks).flat_map(|_| step_checked(w)).collect()
}

fn run_checked_until(w: &mut World, limit: u64, done: impl Fn(&World) -> bool) -> Vec<Event> {
    let mut all = Vec::new();
    for _ in 0..limit {
        if done(w) {
            break;
        }
        all.extend(step_checked(w));
    }
    assert!(done(w), "condition not reached within {limit} ticks");
    all
}

fn rejections(ev: &[Event], id: &str) -> Vec<(CommandType, RejectReason)> {
    ev.iter()
        .filter(|e| e.occupant.as_ref().is_some_and(|o| o.as_str() == id))
        .filter_map(|e| match &e.kind {
            EventKind::Rejected { command, reason } => Some((*command, reason.clone())),
            _ => None,
        })
        .collect()
}

fn centre_of(w: &World, p: Point) -> Point {
    w.nav().unwrap().centre(cell(w, p))
}

fn goal_of(w: &World, id: &str) -> Option<Target> {
    w.snapshot().occupants[&CityId::from(id)].goal.clone()
}

/// `district_small` with seat w2 reserved for agent:b.
fn reserved_district() -> Manifest {
    let mut m = district_small();
    m.city.districts[0].facilities[0].rooms[0].seats[1].reserved_for = Some("agent:b".into());
    m
}

#[test]
fn go_point_in_room() {
    let mut w = world(&[arrive(1, "agent:a"), go(60, "agent:a", point(412, 262))]);
    run_checked(&mut w, 59);
    assert_eq!(seat_of(&w, "agent:a").as_deref(), Some("seat:w1"));
    let ev = run_checked(&mut w, 1);
    assert!(rejections(&ev, "agent:a").is_empty(), "{ev:?}");
    assert!(filtered_kinds(&ev, "agent:a").contains(&"SeatReleased".to_string()));
    run_checked_until(&mut w, 20, |w| settled(w, "agent:a"));
    let there = centre_of(&w, Point { x: 412, z: 262 });
    assert_eq!(pos_of(&w, "agent:a"), Some(there));
    run_checked(&mut w, 30);
    assert_eq!(
        pos_of(&w, "agent:a"),
        Some(there),
        "it stays where it chose"
    );
    assert_eq!(room_of(&w, "agent:a").as_deref(), Some("room:work"));
    assert_eq!(
        seat_of(&w, "agent:a"),
        None,
        "no policy seat overrides the choice"
    );
    assert_eq!(goal_of(&w, "agent:a"), Some(Target::Point { pos: there }));
}

#[test]
fn go_point_other_room_goes_through_admission() {
    let mut w = world(&[arrive(1, "agent:a"), go(60, "agent:a", point(1012, 262))]);
    run_checked(&mut w, 59);
    let ev = run_checked_until(&mut w, 60, |w| {
        settled(w, "agent:a") && room_of(w, "agent:a").as_deref() == Some("room:commons")
    });
    assert!(rejections(&ev, "agent:a").is_empty());
    let kinds = filtered_kinds(&ev, "agent:a");
    assert!(kinds.contains(&"SeatReleased".to_string()));
    assert!(kinds.contains(&"Admitted".to_string()), "{kinds:?}");
    assert!(
        !kinds.contains(&"Seated".to_string()),
        "c1 is free but not chosen"
    );
    let there = centre_of(&w, Point { x: 1012, z: 262 });
    assert_eq!(pos_of(&w, "agent:a"), Some(there));
    assert_eq!(seat_of(&w, "agent:a"), None);
}

#[test]
fn go_seat_free_hot_seat() {
    let mut w = world(&[
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", seat("seat:w2")),
    ]);
    let ev = run_checked_until(&mut w, 100, |w| {
        settled(w, "person:v0") && room_of(w, "person:v0").as_deref() == Some("room:work")
    });
    assert!(rejections(&ev, "person:v0").is_empty());
    assert_eq!(seat_of(&w, "person:v0").as_deref(), Some("seat:w2"));
    assert_eq!(
        pos_of(&w, "person:v0"),
        Some(centre_of(&w, Point { x: 600, z: 150 }))
    );
    assert_eq!(goal_of(&w, "person:v0"), None, "the goal is used up");
}

#[test]
fn go_seat_taken_is_refused() {
    let mut w = world(&[
        arrive(1, "agent:a"),
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", seat("seat:w1")),
    ]);
    run_checked(&mut w, 39);
    assert_eq!(seat_of(&w, "agent:a").as_deref(), Some("seat:w1"));
    let ev = run_checked(&mut w, 1);
    assert_eq!(
        rejections(&ev, "person:v0"),
        vec![(CommandType::Go, RejectReason::SeatTaken)]
    );
    run_checked(&mut w, 20);
    assert_eq!(room_of(&w, "person:v0").as_deref(), Some("room:plaza"));
}

#[test]
fn go_seat_reserved_for_other_is_refused() {
    let lines = [
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", seat("seat:w2")),
    ];
    let mut w = World::new(reserved_district(), feed(&lines), 3).unwrap();
    let ev = run_checked(&mut w, 40);
    assert_eq!(
        rejections(&ev, "person:v0"),
        vec![(CommandType::Go, RejectReason::NotYourSeat)]
    );
}

#[test]
fn go_own_reserved_seat() {
    let lines = [
        json!({"at": 1, "command": {"type": "Arrive", "occupant": "agent:b", "room": "room:plaza"}}),
        go(40, "agent:b", seat("seat:w2")),
    ];
    let mut w = World::new(reserved_district(), feed(&lines), 3).unwrap();
    run_checked(&mut w, 39);
    assert_eq!(room_of(&w, "agent:b").as_deref(), Some("room:plaza"));
    let ev = run_checked_until(&mut w, 60, |w| {
        settled(w, "agent:b") && room_of(w, "agent:b").as_deref() == Some("room:work")
    });
    assert!(rejections(&ev, "agent:b").is_empty());
    assert_eq!(seat_of(&w, "agent:b").as_deref(), Some("seat:w2"));
}

#[test]
fn go_room_full_queues() {
    let mut w = world(&[
        arrive(1, "agent:a"),
        arrive(1, "agent:b"),
        arrive(1, "agent:c"),
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", to_room("room:work")),
    ]);
    run_checked(&mut w, 39);
    let rooms = &w.snapshot().rooms;
    assert_eq!(rooms[&PlaceId::from("room:work")].occupants.len(), 2);
    assert_eq!(rooms[&PlaceId::from("room:commons")].occupants.len(), 1);
    let ev = run_checked_until(
        &mut w,
        40,
        |w| matches!(location(w, "person:v0"), Location::Waitlisted { room } if room.as_str() == "room:work"),
    );
    assert!(
        rejections(&ev, "person:v0").is_empty(),
        "a full room is not a refusal"
    );
    assert!(filtered_kinds(&ev, "person:v0").contains(&"Waitlisted".to_string()));
}

#[test]
fn go_point_on_door_moves_to_nearest_valid() {
    let mut w = world(&[
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(400, 400)),
    ]);
    run_checked(&mut w, 40);
    run_checked_until(&mut w, 40, |w| settled(w, "person:v0"));
    let nav = w.nav().unwrap();
    let at = cell(&w, pos_of(&w, "person:v0").unwrap());
    let door = cell(&w, Point { x: 400, z: 400 });
    assert!(!nav.in_door_span(at), "not in a door span");
    for r in ["room:work", "room:commons", "room:plaza"] {
        assert!(
            !nav.queue_slots(&PlaceId::from(r), 8).contains(&at),
            "not a queue place of {r}"
        );
    }
    for s in [
        Point { x: 200, z: 150 },
        Point { x: 600, z: 150 },
        Point { x: 1200, z: 150 },
    ] {
        assert_ne!(at, cell(&w, s), "not a seat");
    }
    assert_eq!(room_of(&w, "person:v0").as_deref(), Some("room:plaza"));
    assert!(
        (at.i - door.i).abs().max((at.j - door.j).abs()) <= 4,
        "{at:?} is near the door {door:?}"
    );
}

#[test]
fn observer_go_takes_no_seat() {
    let mut w = world(&[
        visitor(1, "person:obs", "room:plaza", "Observer"),
        go(40, "person:obs", seat("seat:w1")),
    ]);
    run_checked(&mut w, 39);
    let ev = run_checked_until(&mut w, 60, |w| {
        settled(w, "person:obs") && room_of(w, "person:obs").as_deref() == Some("room:work")
    });
    assert!(rejections(&ev, "person:obs").is_empty());
    assert_eq!(seat_of(&w, "person:obs"), None);
    assert!(
        w.snapshot().rooms[&PlaceId::from("room:work")]
            .seats
            .values()
            .all(Option::is_none)
    );
    let at = cell(&w, pos_of(&w, "person:obs").unwrap());
    let s = cell(&w, Point { x: 200, z: 150 });
    assert_ne!(at, s, "not on the seat");
    assert!((at.i - s.i).abs().max((at.j - s.j).abs()) <= 2, "beside it");
    run_checked(&mut w, 20);
    assert_eq!(seat_of(&w, "person:obs"), None);
}

#[test]
fn go_where_no_path_leads_is_refused() {
    let mut w = world(&[
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", to_room("room:island")),
        go(41, "person:v0", point(1812, 212)),
        go(42, "person:v0", to_room("room:nowhere")),
    ]);
    let ev = run_checked(&mut w, 42);
    assert_eq!(
        rejections(&ev, "person:v0"),
        vec![
            (CommandType::Go, RejectReason::Unreachable),
            (CommandType::Go, RejectReason::Unreachable),
            (CommandType::Go, RejectReason::UnknownRoom),
        ]
    );
    assert_eq!(room_of(&w, "person:v0").as_deref(), Some("room:plaza"));
}

#[test]
fn a_seat_taken_before_admission_is_refused_then_and_policy_applies() {
    let mut w = world(&[
        visitor(1, "person:v0", "room:plaza", "Registered"),
        visitor(1, "person:v1", "room:plaza", "Registered"),
        go(40, "person:v0", seat("seat:w2")),
        go(40, "person:v1", seat("seat:w2")),
    ]);
    let ev = run_checked_until(&mut w, 100, |w| {
        ["person:v0", "person:v1"]
            .iter()
            .all(|id| settled(w, id) && room_of(w, id).as_deref() == Some("room:work"))
    });
    let mut seats = [seat_of(&w, "person:v0"), seat_of(&w, "person:v1")];
    seats.sort();
    assert_eq!(
        seats,
        [Some("seat:w1".to_string()), Some("seat:w2".to_string())]
    );
    let loser = if seat_of(&w, "person:v0").as_deref() == Some("seat:w1") {
        "person:v0"
    } else {
        "person:v1"
    };
    assert_eq!(
        rejections(&ev, loser),
        vec![(CommandType::Go, RejectReason::SeatTaken)]
    );
}

// ---- Players: Steer (Stage 5) ----

/// The centre of cell (i, j) in `district_small`, whose grid starts at 0, 0.
fn cc(i: i32, j: i32) -> Point {
    Point {
        x: i * CELL + CELL / 2,
        z: j * CELL + CELL / 2,
    }
}

fn steer(at: u64, id: &str, cells: &[(i32, i32)]) -> serde_json::Value {
    let cells: Vec<Point> = cells.iter().map(|(i, j)| cc(*i, *j)).collect();
    json!({"at": at, "command": {"type": "Steer", "occupant": id, "cells": cells}})
}

fn trail_of(w: &World, id: &str) -> Vec<Point> {
    w.snapshot().occupants[&CityId::from(id)].trail.clone()
}

/// Runs `lines` to just before `at`, then steps the tick at which `id`
/// steers along `cells`; asserts it stood at `from` first.
fn steer_from(
    lines: &[serde_json::Value],
    id: &str,
    from: (i32, i32),
    at: u64,
    cells: &[(i32, i32)],
) -> (World, Vec<Event>) {
    let mut lines = lines.to_vec();
    lines.push(steer(at, id, cells));
    let mut w = world(&lines);
    run_checked(&mut w, at - 1);
    assert_eq!(pos_of(&w, id), Some(cc(from.0, from.1)), "{id} is in place");
    let ev = step_checked(&mut w);
    (w, ev)
}

#[test]
fn steer_moves_exact_cells() {
    let lines = [
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(812, 812)),
    ];
    let (w, ev) = steer_from(
        &lines,
        "person:v0",
        (32, 32),
        70,
        &[(33, 32), (34, 33), (35, 33)],
    );
    assert!(rejections(&ev, "person:v0").is_empty());
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(35, 33)));
    assert_eq!(
        trail_of(&w, "person:v0"),
        vec![cc(33, 32), cc(34, 33), cc(35, 33)]
    );
    let o = &w.snapshot().occupants[&CityId::from("person:v0")];
    assert!(o.walk.is_none());
    assert_eq!(o.facing, 90);
    assert_eq!(room_of(&w, "person:v0").as_deref(), Some("room:plaza"));
}

#[test]
fn steer_stops_at_wall() {
    let lines = [
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(112, 462)),
    ];
    let (w, ev) = steer_from(
        &lines,
        "person:v0",
        (4, 18),
        70,
        &[(4, 17), (4, 16), (4, 15), (4, 14)],
    );
    assert_eq!(
        rejections(&ev, "person:v0"),
        vec![(CommandType::Steer, RejectReason::BlockedStep)]
    );
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(4, 16)));
    assert_eq!(trail_of(&w, "person:v0"), vec![cc(4, 17), cc(4, 16)]);
    assert_eq!(room_of(&w, "person:v0").as_deref(), Some("room:plaza"));
}

#[test]
fn steer_stops_at_person() {
    let lines = [
        visitor(1, "person:v0", "room:plaza", "Registered"),
        visitor(1, "person:v1", "room:plaza", "Registered"),
        go(40, "person:v0", point(812, 812)),
        go(40, "person:v1", point(762, 812)),
    ];
    let (w, ev) = steer_from(
        &lines,
        "person:v1",
        (30, 32),
        70,
        &[(31, 32), (32, 32), (33, 32)],
    );
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(32, 32)));
    assert_eq!(
        rejections(&ev, "person:v1"),
        vec![(CommandType::Steer, RejectReason::BlockedStep)]
    );
    assert_eq!(pos_of(&w, "person:v1"), Some(cc(31, 32)));
}

#[test]
fn steer_through_door_triggers_admission() {
    let lines = [
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(412, 512)),
    ];
    let (mut w, ev) = steer_from(
        &lines,
        "person:v0",
        (16, 20),
        70,
        &[(16, 19), (16, 18), (16, 17), (16, 16), (16, 15)],
    );
    assert!(rejections(&ev, "person:v0").is_empty());
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(16, 15)));
    assert!(
        w.nav().unwrap().in_door_span(cell(&w, cc(16, 15))),
        "on the work room's door span"
    );
    // A steered entry is admitted on the step onto the span, so nothing
    // admitted later can send it elsewhere.
    assert!(filtered_kinds(&ev, "person:v0").contains(&"Admitted".to_string()));
    assert_eq!(room_of(&w, "person:v0").as_deref(), Some("room:work"));
    run_checked(&mut w, 20);
    assert_eq!(
        pos_of(&w, "person:v0"),
        Some(cc(16, 15)),
        "it stays where it stepped"
    );
    assert_eq!(
        seat_of(&w, "person:v0"),
        None,
        "no policy seat pulls it away"
    );
}

#[test]
fn steer_into_a_full_room_is_refused_at_its_door() {
    // The work room and the commons it overflows to are full. A steered
    // entry tries only the room it walks into: the step onto the work
    // room's span is refused, and the player stays outside, at the
    // threshold, neither queued nor overflowed.
    let lines = [
        arrive(1, "agent:a"),
        arrive(1, "agent:b"),
        arrive(1, "agent:c"),
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(412, 512)),
    ];
    let (mut w, ev) = steer_from(
        &lines,
        "person:v0",
        (16, 20),
        70,
        &[(16, 19), (16, 18), (16, 17), (16, 16), (16, 15)],
    );
    assert_eq!(
        rejections(&ev, "person:v0"),
        vec![(
            CommandType::Steer,
            RejectReason::RoomFull {
                room: "room:work".into()
            }
        )]
    );
    assert_eq!(
        pos_of(&w, "person:v0"),
        Some(cc(16, 16)),
        "at the threshold"
    );
    let ev = run_checked(&mut w, 20);
    let kinds = filtered_kinds(&ev, "person:v0");
    assert!(
        !kinds
            .iter()
            .any(|k| ["Waitlisted", "Overflowed", "Admitted"].contains(&k.as_str())),
        "{kinds:?}"
    );
    assert_eq!(room_of(&w, "person:v0").as_deref(), Some("room:plaza"));
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(16, 16)));
}

/// `district_small` with `room:terrace`, an open-air room of capacity 1
/// east of the plaza (1600,400 400×800), joined to it along the whole
/// shared edge and by no door. `person:v1` fills it; `person:v0` stands on
/// the plaza at cell (61, 32), three cells from the edge, by tick 70.
fn beside_a_full_terrace() -> World {
    let mut m = district_small();
    let terrace: Room = serde_json::from_value(json!({
        "id": "room:terrace", "name": "Terrace", "capacity": 1, "outdoor": true,
        "rect": {"x": 1600, "z": 400, "w": 400, "d": 800}
    }))
    .unwrap();
    m.city.districts[0].facilities[1].rooms.push(terrace);
    let lines = [
        visitor(1, "person:v1", "room:plaza", "Registered"),
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(10, "person:v1", point(1812, 812)),
        go(10, "person:v0", point(1537, 812)),
    ];
    let mut w = World::new(m, feed(&lines), 3).unwrap();
    run_checked(&mut w, 69);
    assert_eq!(room_of(&w, "person:v1").as_deref(), Some("room:terrace"));
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(61, 32)), "in place");
    w
}

#[test]
fn steer_across_an_open_edge_into_a_full_room_says_it_is_full() {
    // Open-air rooms join along any edge, so there is no door span to be
    // refused on: the step over the edge is where the room turns you away.
    let mut w = beside_a_full_terrace();
    w.submit(Command::Steer {
        occupant: "person:v0".into(),
        cells: vec![cc(62, 32), cc(63, 32), cc(64, 32), cc(65, 32)],
    });
    let ev = step_checked(&mut w);
    assert_eq!(
        rejections(&ev, "person:v0"),
        vec![(
            CommandType::Steer,
            RejectReason::RoomFull {
                room: "room:terrace".into()
            }
        )]
    );
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(63, 32)), "at the edge");
}

#[test]
fn steer_at_45_degrees_into_a_full_room_says_it_is_full() {
    let mut w = beside_a_full_terrace();
    w.submit(Command::Steer {
        occupant: "person:v0".into(),
        cells: vec![cc(62, 33), cc(63, 34), cc(64, 35)],
    });
    let ev = step_checked(&mut w);
    assert_eq!(
        rejections(&ev, "person:v0"),
        vec![(
            CommandType::Steer,
            RejectReason::RoomFull {
                room: "room:terrace".into()
            }
        )]
    );
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(63, 34)), "at the edge");
}

#[test]
fn a_full_room_s_own_occupant_steers_about_it_freely() {
    // Full closes a room to those outside it, never to those admitted.
    let mut w = beside_a_full_terrace();
    let at = cell(&w, pos_of(&w, "person:v1").unwrap());
    let next = cc(at.i + 1, at.j);
    w.submit(Command::Steer {
        occupant: "person:v1".into(),
        cells: vec![next],
    });
    let ev = step_checked(&mut w);
    assert!(rejections(&ev, "person:v1").is_empty(), "{ev:?}");
    assert_eq!(pos_of(&w, "person:v1"), Some(next));
}

#[test]
fn go_into_a_full_room_queues() {
    let lines = [
        arrive(1, "agent:a"),
        arrive(1, "agent:b"),
        arrive(1, "agent:c"),
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(412, 512)),
        go(70, "person:v0", to_room("room:work")),
    ];
    let mut w = world(&lines);
    let ev = run_checked(&mut w, 75);
    assert!(filtered_kinds(&ev, "person:v0").contains(&"Waitlisted".to_string()));
    run_checked_until(&mut w, 20, |w| {
        w.snapshot().occupants[&CityId::from("person:v0")]
            .walk
            .is_none()
    });
    assert!(matches!(
        location(&w, "person:v0"),
        Location::Waitlisted { .. }
    ));
    let slot = w.nav().unwrap().queue_slots(&PlaceId::from("room:work"), 1)[0];
    assert_eq!(
        cell(&w, pos_of(&w, "person:v0").unwrap()),
        slot,
        "walked to its queue place"
    );
}

#[test]
fn a_queued_player_cannot_steer_into_the_full_room() {
    // Entering a room means admission: a full room is queued for, never
    // walked into, so the step onto its door span is refused.
    let lines = [
        arrive(1, "agent:a"),
        arrive(1, "agent:b"),
        arrive(1, "agent:c"),
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(412, 512)),
        go(70, "person:v0", to_room("room:work")),
    ];
    let mut w = world(&lines);
    run_checked_until(&mut w, 120, |w| {
        w.snapshot()
            .occupants
            .get(&CityId::from("person:v0"))
            .is_some_and(|o| matches!(o.location, Location::Waitlisted { .. }) && o.walk.is_none())
    });
    // From its queue place, it steers straight at the door and on into the
    // room, a tick at a time.
    let mut refused = Vec::new();
    for _ in 0..8 {
        let nav = w.nav().unwrap();
        let here = cell(&w, pos_of(&w, "person:v0").unwrap());
        let path = nav
            .path_to(here, cell(&w, cc(16, 5)), &|_| false)
            .expect("a way in");
        w.submit(Command::Steer {
            occupant: "person:v0".into(),
            cells: path.iter().take(5).map(|c| nav.centre(*c)).collect(),
        });
        let ev = step_checked(&mut w);
        refused.extend(rejections(&ev, "person:v0"));
        let here = cell(&w, pos_of(&w, "person:v0").unwrap());
        assert_ne!(
            w.nav().unwrap().room_at(here).map(PlaceId::as_str),
            Some("room:work"),
            "tick {}: on the full room's floor at {here:?}",
            w.snapshot().tick
        );
    }
    assert!(
        matches!(location(&w, "person:v0"), Location::Waitlisted { .. }),
        "still queued"
    );
    assert!(
        refused.contains(&(
            CommandType::Steer,
            RejectReason::RoomFull {
                room: "room:work".into()
            }
        )),
        "the step onto the door span was refused: {refused:?}"
    );
}

#[test]
fn steer_more_than_five_rejected_after_five() {
    let lines = [
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(812, 812)),
    ];
    let cells: Vec<(i32, i32)> = (33..40).map(|i| (i, 32)).collect();
    let (w, ev) = steer_from(&lines, "person:v0", (32, 32), 70, &cells);
    assert_eq!(
        rejections(&ev, "person:v0"),
        vec![(CommandType::Steer, RejectReason::BlockedStep)]
    );
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(37, 32)));
    assert_eq!(trail_of(&w, "person:v0").len(), 5);
}

#[test]
fn steer_from_seat_releases_it() {
    let lines = [arrive(1, "agent:a")];
    let (mut w, ev) = steer_from(&lines, "agent:a", (8, 6), 60, &[(8, 7)]);
    assert!(rejections(&ev, "agent:a").is_empty());
    let kinds = filtered_kinds(&ev, "agent:a");
    assert!(kinds.contains(&"SeatReleased".to_string()), "{kinds:?}");
    assert_eq!(
        pos_of(&w, "agent:a"),
        Some(cc(8, 7)),
        "standing up cost no step"
    );
    assert_eq!(trail_of(&w, "agent:a"), vec![cc(8, 7)]);
    run_checked(&mut w, 20);
    assert_eq!(seat_of(&w, "agent:a"), None);
    assert_eq!(pos_of(&w, "agent:a"), Some(cc(8, 7)));
    assert!(
        w.snapshot().rooms[&PlaceId::from("room:work")]
            .seats
            .values()
            .all(Option::is_none)
    );
}

#[test]
fn standing_up_in_place_steps_off_the_seat() {
    // An empty steer from a seat stands up beside it, freeing the seat's
    // cell for whoever sits there next.
    let lines = [arrive(1, "agent:a"), steer(60, "agent:a", &[])];
    let mut w = world(&lines);
    run_checked(&mut w, 59);
    assert_eq!(pos_of(&w, "agent:a"), Some(cc(8, 6)), "seated");
    let ev = step_checked(&mut w);
    assert!(filtered_kinds(&ev, "agent:a").contains(&"SeatReleased".to_string()));
    let here = cell(&w, pos_of(&w, "agent:a").unwrap());
    assert_ne!(here, cell(&w, cc(8, 6)), "stood up off the seat's cell");
    assert!(
        (here.i - 8).abs() <= 1 && (here.j - 6).abs() <= 1,
        "beside it: {here:?}"
    );
    run_checked(&mut w, 10);
    assert_eq!(
        cell(&w, pos_of(&w, "agent:a").unwrap()),
        here,
        "and stays there"
    );
}

#[test]
fn a_tap_while_queued_keeps_the_place_and_walking_off_leaves_it() {
    let lines = [
        arrive(1, "agent:a"),
        arrive(1, "agent:b"),
        arrive(1, "agent:c"),
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(412, 512)),
        go(70, "person:v0", to_room("room:work")),
    ];
    let mut w = world(&lines);
    run_checked_until(&mut w, 120, |w| {
        w.snapshot()
            .occupants
            .get(&CityId::from("person:v0"))
            .is_some_and(|o| matches!(o.location, Location::Waitlisted { .. }) && o.walk.is_none())
            && w.snapshot().tick > 72
    });
    let slot = cell(&w, pos_of(&w, "person:v0").unwrap());
    // A one-cell tap aside keeps the place, and the queue draws them back.
    let t = w.snapshot().tick + 1;
    let mut lines2 = lines.to_vec();
    let side = (slot.i + 1, slot.j);
    lines2.push(steer(t, "person:v0", &[side]));
    let mut w2 = world(&lines2);
    run_checked(&mut w2, t);
    assert!(
        matches!(location(&w2, "person:v0"), Location::Waitlisted { .. }),
        "a tap aside keeps the queue place: {:?}",
        location(&w2, "person:v0")
    );
    // Walking well away (four metres) leaves the queue.
    let mut lines3 = lines.to_vec();
    let far: Vec<(i32, i32)> = (1..=5).map(|k| (slot.i + k, slot.j)).collect();
    let farther: Vec<(i32, i32)> = (6..=10).map(|k| (slot.i + k, slot.j)).collect();
    let farthest: Vec<(i32, i32)> = (11..=15).map(|k| (slot.i + k, slot.j)).collect();
    lines3.push(steer(t, "person:v0", &far));
    lines3.push(steer(t + 1, "person:v0", &farther));
    lines3.push(steer(t + 2, "person:v0", &farthest));
    let mut w3 = world(&lines3);
    run_checked(&mut w3, t + 2);
    assert!(
        !matches!(location(&w3, "person:v0"), Location::Waitlisted { .. }),
        "walking off leaves the queue: {:?}",
        location(&w3, "person:v0")
    );
}

#[test]
fn observer_steer_passes_people() {
    let lines = [
        visitor(1, "person:v0", "room:plaza", "Registered"),
        visitor(1, "person:obs", "room:plaza", "Observer"),
        go(40, "person:v0", point(812, 812)),
        go(40, "person:obs", point(762, 812)),
    ];
    let (w, ev) = steer_from(
        &lines,
        "person:obs",
        (30, 32),
        70,
        &[(31, 32), (32, 32), (33, 32)],
    );
    assert!(rejections(&ev, "person:obs").is_empty());
    assert_eq!(pos_of(&w, "person:obs"), Some(cc(33, 32)));
    assert_eq!(
        pos_of(&w, "person:v0"),
        Some(cc(32, 32)),
        "the person is not moved"
    );
}

#[test]
fn steering_clears_the_walk_and_goal_in_progress() {
    let lines = [
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(812, 812)),
        // The Go runs at Ingest and sets off for w2; the Steer runs later
        // in the same tick, before anyone walks.
        go(71, "person:v0", seat("seat:w2")),
    ];
    let (mut w, ev) = steer_from(&lines, "person:v0", (32, 32), 71, &[(31, 31)]);
    assert!(filtered_kinds(&ev, "person:v0").contains(&"TransitStarted".to_string()));
    assert!(rejections(&ev, "person:v0").is_empty());
    let o = &w.snapshot().occupants[&CityId::from("person:v0")];
    assert!(o.walk.is_none(), "the walk to w2 is cleared");
    assert!(
        !matches!(o.goal, Some(Target::Seat { .. })),
        "and so is the seat goal"
    );
    run_checked(&mut w, 20);
    assert_eq!(room_of(&w, "person:v0").as_deref(), Some("room:plaza"));
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(31, 31)));
    assert!(
        w.snapshot().rooms[&PlaceId::from("room:work")]
            .seats
            .values()
            .all(Option::is_none)
    );
}

// ---- Seats are destinations, not paths ----

/// `district_small` with a row of bench seats across the plaza: row 36,
/// columns 8 to 55, `seat:b08` to `seat:b55`.
fn benched_world(lines: &[serde_json::Value]) -> World {
    let mut m = district_small();
    let seats: Vec<serde_json::Value> = (8..=55)
        .map(|i| json!({"id": format!("seat:b{i:02}"), "pos": cc(i, 36), "facing": 0}))
        .collect();
    m.city.districts[0].facilities[1].rooms[0].seats =
        serde_json::from_value(serde_json::Value::Array(seats)).unwrap();
    World::new(m, feed(lines), 3).unwrap()
}

#[test]
fn a_go_to_a_seat_in_a_row_arrives_without_crossing_the_others() {
    let lines = [
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(512, 1012)),
        go(80, "person:v0", seat("seat:b30")),
    ];
    let mut w = benched_world(&lines);
    let mut all = Vec::new();
    for _ in 0..160 {
        // `step_checked` holds invariant 24: no trail crosses a seat.
        all.extend(step_checked(&mut w));
        if w.snapshot().tick == 79 {
            assert_eq!(
                pos_of(&w, "person:v0"),
                Some(cc(20, 40)),
                "south-west of the seat"
            );
        }
    }
    assert!(rejections(&all, "person:v0").is_empty(), "{all:?}");
    assert!(settled(&w, "person:v0"));
    assert_eq!(seat_of(&w, "person:v0").as_deref(), Some("seat:b30"));
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(30, 36)));
}

#[test]
fn a_steer_onto_an_empty_seat_is_refused() {
    let lines = [
        visitor(1, "person:v0", "room:plaza", "Registered"),
        go(40, "person:v0", point(762, 937)),
        steer(80, "person:v0", &[(30, 36)]),
        steer(81, "person:v0", &[(31, 37), (31, 36), (31, 35)]),
    ];
    let mut w = benched_world(&lines);
    run_checked(&mut w, 79);
    assert_eq!(
        pos_of(&w, "person:v0"),
        Some(cc(30, 37)),
        "just south of b30"
    );
    assert!(
        w.snapshot().rooms[&PlaceId::from("room:plaza")]
            .seats
            .values()
            .all(Option::is_none),
        "every seat is empty"
    );
    let ev = step_checked(&mut w);
    assert_eq!(
        rejections(&ev, "person:v0"),
        vec![(CommandType::Steer, RejectReason::Seat)]
    );
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(30, 37)), "it stays put");
    assert!(trail_of(&w, "person:v0").is_empty());
    // The step beside it is taken; the step onto the seat ends the steer.
    let ev = step_checked(&mut w);
    assert_eq!(
        rejections(&ev, "person:v0"),
        vec![(CommandType::Steer, RejectReason::Seat)]
    );
    assert_eq!(pos_of(&w, "person:v0"), Some(cc(31, 37)));
    assert_eq!(seat_of(&w, "person:v0"), None);
}

// ---- Live input and replay (Stage 5) ----

fn command(v: serde_json::Value) -> Command {
    serde_json::from_value(v).unwrap()
}

fn you() -> Command {
    command(
        json!({"type": "Arrive", "occupant": "person:you", "room": "room:plaza",
        "profile": {"id": "person:you", "display_name": "You",
                    "kind": {"type": "Human", "tier": "Registered"}}}),
    )
}

#[test]
fn live_commands_apply_next_tick_and_are_logged() {
    let mut w = world(&[]);
    w.run(4);
    w.submit(you());
    assert!(
        !w.snapshot()
            .occupants
            .contains_key(&CityId::from("person:you")),
        "not before the next tick"
    );
    let ev = w.step();
    assert_eq!(ev[0].tick, 5);
    assert!(matches!(ev[0].kind, EventKind::Arrived { .. }));
    assert_eq!(
        ev[0].occupant.as_ref().map(CityId::as_str),
        Some("person:you")
    );
    assert!(
        ev.iter().all(|e| e.fixture),
        "a fixture world labels live events too"
    );
    assert_eq!(
        w.input_log(),
        &[FeedEntry {
            at: 5,
            fixture: true,
            command: you()
        }]
    );
    let next = w.step();
    assert!(
        next.iter()
            .all(|e| !matches!(e.kind, EventKind::Arrived { .. })),
        "applied once"
    );
    assert_eq!(w.input_log().len(), 1);
    let f = w.input_log_feed();
    assert!(f.header.fixture);
    assert_eq!(f.header.schema_version, SCHEMA_VERSION);
    assert_eq!(f.entries, w.input_log());
}

#[test]
fn feed_entries_of_a_tick_run_before_live_commands() {
    let mut w = world(&[arrive(3, "agent:a")]);
    w.run(2);
    w.submit(command(json!({"type": "Arrive", "occupant": "agent:a"})));
    let ev = w.step();
    let kinds: Vec<String> = ev.iter().map(|e| type_name(&e.kind)).collect();
    assert_eq!(kinds[0], "Arrived", "the feed's arrival comes first");
    assert!(matches!(
        ev[1].kind,
        EventKind::Rejected {
            command: CommandType::Arrive,
            reason: RejectReason::AlreadyPresent
        }
    ));
}

fn event_bytes(ev: &[Event]) -> Vec<String> {
    ev.iter()
        .map(|e| serde_json::to_string(e).unwrap())
        .collect()
}

#[test]
fn replaying_the_feed_with_the_input_log_is_byte_identical() {
    let lines = vec![
        arrive(1, "agent:a"),
        visitor(1, "person:obs", "room:plaza", "Observer"),
        json!({"at": 2, "command": {"type": "Arrive", "occupant": "agent:b", "room": "room:plaza"}}),
        depart(70, "agent:a"),
    ];
    let mut w = world(&lines);
    let mut log = Vec::new();
    let mut snaps = Vec::new();
    for t in 0..100u64 {
        match t {
            0 => w.submit(you()),
            19 => w.submit(command(json!({"type": "Go", "occupant": "person:you",
                "to": {"type": "Seat", "seat": "seat:w1"}}))),
            20 => w.submit(command(json!({"type": "Go", "occupant": "person:you",
                "to": {"type": "Seat", "seat": "seat:w2"}}))),
            21 => w.submit(command(json!({"type": "Go", "occupant": "person:obs",
                "to": {"type": "Point", "pos": {"x": 1012, "z": 262}}}))),
            50 => {
                // Step towards the plaza from wherever the player stands.
                let at = cell(&w, pos_of(&w, "person:you").unwrap());
                let cells: Vec<Point> = (1..=4).map(|k| cc(at.i, at.j + k)).collect();
                w.submit(command(
                    json!({"type": "Steer", "occupant": "person:you", "cells": cells}),
                ));
            }
            60 => w.submit(command(json!({"type": "Depart", "occupant": "person:you"}))),
            _ => {}
        }
        log.extend(w.step());
        snaps.push(serde_json::to_string(w.snapshot()).unwrap());
    }
    assert_eq!(w.input_log().len(), 6);
    let replay_feed = city_core::merge(feed(&lines), w.input_log_feed()).unwrap();
    let mut again = World::new(district_small(), replay_feed, 3).unwrap();
    let mut log2 = Vec::new();
    for snap in &snaps {
        log2.extend(again.step());
        assert_eq!(&serde_json::to_string(again.snapshot()).unwrap(), snap);
    }
    assert_eq!(event_bytes(&log), event_bytes(&log2));
    let you_events = filtered_kinds(&log, "person:you");
    for k in [
        "Arrived",
        "Admitted",
        "Rejected",
        "Seated",
        "SeatReleased",
        "Departed",
    ] {
        assert!(
            you_events.contains(&k.to_string()),
            "the session never shows {k}: {you_events:?}"
        );
    }
}

// ---- The whole city (open ground) ----

fn district_world(lines: &[serde_json::Value]) -> World {
    let m: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    World::new(m, feed(lines), 5).unwrap()
}

fn where_is(w: &World, id: &str) -> Option<Location> {
    w.snapshot()
        .occupants
        .get(&CityId::from(id))
        .map(|o| o.location.clone())
}

#[test]
fn no_queue_place_lies_on_the_tram_tracks() {
    // A room's queue fans out from its door: the tram stop's and the
    // Avenue tramway's used to reach the rails from their 40th and 27th
    // places. Queue places now keep off the track, however long the queue.
    let w = district_world(&[]);
    let nav = w.nav().unwrap();
    let track = city_core::transit::track_cells(w.index(), nav);
    for room in [
        "room:tram-stop",
        "room:tram-stop-south",
        "room:avenue-tramway",
        "room:tram-street",
        "room:avenue-stop-north",
        "room:avenue-stop-south",
    ] {
        let slots = nav.queue_slots(&PlaceId::from(room), 120);
        let on_track: Vec<usize> = slots
            .iter()
            .enumerate()
            .filter(|(_, c)| track.contains(c))
            .map(|(k, _)| k)
            .collect();
        assert!(
            on_track.is_empty(),
            "{room}'s queue places {on_track:?} (of {}) are on the track",
            slots.len()
        );
    }
}

#[test]
fn a_go_walks_from_the_square_to_the_edge_of_the_city() {
    let mut w = district_world(&[
        visitor(1, "person:you", "room:plaza", "Registered"),
        go(40, "person:you", point(-250, -6600)),
    ]);
    run_checked_until(&mut w, 300, |w| {
        matches!(where_is(w, "person:you"), Some(Location::InRoom { ref room, .. }) if room.as_str() == "room:uptown")
            && pos_of(w, "person:you")
                .is_some_and(|p| (p.x + 250).abs() <= 25 && (p.z + 6600).abs() <= 25)
    });
}

#[test]
fn steering_crosses_from_the_square_onto_open_ground_without_a_door() {
    let mut w = district_world(&[visitor(1, "person:you", "room:plaza", "Registered")]);
    run_checked_until(&mut w, 120, |w| settled(w, "person:you"));
    // Up off the bench, whose back now stands north of its seat, to a
    // column of the square that is clear to its north edge and on between
    // the street trees beyond it.
    let start = Point { x: -288, z: -988 };
    w.submit(
        serde_json::from_value(json!({"type": "Go", "occupant": "person:you",
                                      "to": {"type": "Point", "pos": start}}))
        .unwrap(),
    );
    run_checked_until(&mut w, 120, |w| {
        settled(w, "person:you") && pos_of(w, "person:you") == Some(start)
    });
    let at = pos_of(&w, "person:you").unwrap();
    // Walk north in steered steps (five a tick) until off the square.
    let mut ticks = 0;
    while room_at(&w, pos_of(&w, "person:you").unwrap()).as_deref() == Some("room:plaza")
        && ticks < 40
    {
        let c = cell(&w, pos_of(&w, "person:you").unwrap());
        let nav = w.nav().unwrap();
        let cells: Vec<Point> = (1..=5)
            .map(|k| nav.centre(Cell { i: c.i, j: c.j - k }))
            .collect();
        w.submit(
            serde_json::from_value(
                json!({"type": "Steer", "occupant": "person:you", "cells": cells}),
            )
            .unwrap(),
        );
        step_checked(&mut w);
        ticks += 1;
    }
    let now = pos_of(&w, "person:you").unwrap();
    assert!(now.z < at.z, "it walked north");
    assert_eq!(
        room_at(&w, now).as_deref(),
        Some("room:uptown"),
        "onto uptown's open ground"
    );
}

#[test]
fn a_full_doorless_room_queues_you_outside_it_not_on_its_floor() {
    let mut m: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    for r in m
        .city
        .districts
        .iter_mut()
        .flat_map(|d| d.facilities.iter_mut())
        .flat_map(|f| f.rooms.iter_mut())
    {
        if r.id.as_str() == "room:tram-street" {
            r.capacity = 1;
        }
    }
    let mut w = World::new(
        m,
        feed(&[
            visitor(1, "person:a", "room:tram-street", "Registered"),
            visitor(1, "person:you", "room:plaza", "Registered"),
        ]),
        5,
    )
    .unwrap();
    run_checked_until(&mut w, 200, |w| {
        settled(w, "person:you") && settled(w, "person:a")
    });
    // Walk south across the (full) tram street, and ask for it half way.
    w.submit(
        serde_json::from_value(json!({"type": "Go", "occupant": "person:you",
        "to": {"type": "Point", "pos": {"x": 1900, "z": 4500}}}))
        .unwrap(),
    );
    run_checked_until(&mut w, 60, |w| {
        room_at(w, pos_of(w, "person:you").unwrap()).as_deref() == Some("room:tram-street")
    });
    w.submit(
        serde_json::from_value(json!({"type": "Go", "occupant": "person:you",
        "to": {"type": "Room", "room": "room:tram-street"}}))
        .unwrap(),
    );
    run_checked(&mut w, 30);
    assert!(matches!(
        where_is(&w, "person:you"),
        Some(Location::Waitlisted { .. })
    ));
    assert_ne!(
        room_at(&w, pos_of(&w, "person:you").unwrap()).as_deref(),
        Some("room:tram-street"),
        "it waits outside the room it queues for"
    );
}
