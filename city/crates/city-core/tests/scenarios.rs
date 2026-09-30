//! Named scenarios for the world rules.

mod common;

use city_contracts::*;
use city_core::{World, project};
use common::*;
use serde_json::json;

#[test]
fn reserved_seat_stays_empty_while_owner_is_away() {
    let f = feed(&[
        arrive(0, "agent:a"),
        arrive(0, "agent:b"),
        arrive(0, "agent:c"),
    ]);
    let mut w = World::new(hall(), f, 1).unwrap();
    w.run(3);
    // Capacity 3 with kai's seat held: two strangers fit, the third overflows.
    assert_eq!(room_of(&w, "agent:a").as_deref(), Some("room:work"));
    assert_eq!(room_of(&w, "agent:b").as_deref(), Some("room:work"));
    assert_eq!(room_of(&w, "agent:c").as_deref(), Some("room:annex"));
    assert_eq!(
        w.snapshot().rooms[&PlaceId::from("room:work")].seats[&PlaceId::from("seat:w3")],
        None
    );
}

#[test]
fn reserved_owner_gets_in_even_when_strangers_filled_the_room() {
    let f = feed(&[
        arrive(0, "agent:a"),
        arrive(0, "agent:b"),
        arrive(0, "agent:c"),
        arrive(1, "agent:kai"),
    ]);
    let mut w = World::new(hall(), f, 1).unwrap();
    w.run(3);
    assert_eq!(seat_of(&w, "agent:kai").as_deref(), Some("seat:w3"));
}

#[test]
fn overflow_then_waitlist_in_fifo_order_then_drain() {
    let f = feed(&[
        arrive(0, "agent:a"),
        arrive(0, "agent:b"),
        arrive(0, "agent:c"),
        arrive(0, "agent:d"),
        depart(3, "agent:a"),
        depart(5, "agent:b"),
    ]);
    let mut w = World::new(hall(), f, 1).unwrap();
    let ev = w.run(2);
    assert_eq!(
        filtered_kinds(&ev, "agent:c"),
        ["Arrived", "Overflowed", "Admitted", "Seated"]
    );
    assert_eq!(filtered_kinds(&ev, "agent:d"), ["Arrived", "Waitlisted"]);
    w.run(1); // tick 3: a departs at the end of the tick
    assert!(matches!(
        location(&w, "agent:d"),
        Location::Waitlisted { .. }
    ));
    w.run(1); // tick 4: d is served from the waitlist
    assert_eq!(room_of(&w, "agent:d").as_deref(), Some("room:work"));
    assert!(
        w.snapshot().rooms[&PlaceId::from("room:work")]
            .waitlist
            .is_empty()
    );
}

#[test]
fn waitlist_is_served_first_in_first_out() {
    let mut m = hall();
    // Make the annex a dead end so the waitlist fills.
    for r in m.city.districts[0].facilities[0].rooms.iter_mut() {
        if r.id.as_str() == "room:work" {
            r.overflow = None;
        }
    }
    let f = feed(&[
        arrive(0, "agent:a"),
        arrive(0, "agent:b"),
        arrive(1, "agent:c"),
        arrive(2, "agent:d"),
        depart(4, "agent:a"),
        depart(6, "agent:b"),
    ]);
    let mut w = World::new(m, f, 1).unwrap();
    w.run(3);
    assert_eq!(
        w.snapshot().rooms[&PlaceId::from("room:work")].waitlist,
        vec![CityId::from("agent:c"), CityId::from("agent:d")]
    );
    w.run(2); // a leaves at 4; c enters at 5
    assert_eq!(room_of(&w, "agent:c").as_deref(), Some("room:work"));
    assert!(matches!(
        location(&w, "agent:d"),
        Location::Waitlisted { .. }
    ));
    w.run(2); // b leaves at 6; d enters at 7
    assert_eq!(room_of(&w, "agent:d").as_deref(), Some("room:work"));
}

#[test]
fn departure_releases_the_held_seat() {
    let f = feed(&[arrive(0, "agent:kai"), depart(2, "agent:kai")]);
    let mut w = World::new(hall(), f, 1).unwrap();
    w.run(1);
    assert_eq!(seat_of(&w, "agent:kai").as_deref(), Some("seat:w3"));
    let ev = w.run(1);
    assert!(ev.iter().any(|e| matches!(&e.kind,
        EventKind::SeatReleased { seat, .. } if seat.as_str() == "seat:w3")));
    assert!(matches!(location(&w, "agent:kai"), Location::Away));
    assert_eq!(
        w.snapshot().rooms[&PlaceId::from("room:work")].seats[&PlaceId::from("seat:w3")],
        None
    );
}

#[test]
fn department_pod_is_preferred() {
    let f = feed(&[arrive(0, "agent:a"), arrive(1, "agent:kai")]);
    let mut w = World::new(hall(), f, 1).unwrap();
    w.run(2);
    assert_eq!(seat_of(&w, "agent:a").as_deref(), Some("seat:w1"));
}

#[test]
fn bad_commands_are_rejected_not_panics() {
    let f = feed(&[
        arrive(0, "agent:nobody"),
        depart(0, "agent:a"),
        json!({"at": 0, "command": {"type": "Arrive", "occupant": "agent:a", "room": "room:nowhere"}}),
        arrive(1, "agent:b"),
        arrive(1, "agent:b"),
    ]);
    let mut w = World::new(hall(), f, 1).unwrap();
    let ev = w.run(2);
    let reasons: Vec<_> = ev
        .iter()
        .filter_map(|e| match &e.kind {
            EventKind::Rejected { reason, .. } => Some(reason.clone()),
            _ => None,
        })
        .collect();
    assert_eq!(
        reasons,
        vec![
            RejectReason::UnknownOccupant,
            RejectReason::NotPresent,
            RejectReason::UnknownRoom,
            RejectReason::AlreadyPresent
        ]
    );
}

#[test]
fn newcomer_registers_with_a_profile() {
    let f = feed(&[
        json!({"at": 0, "command": {"type": "Arrive", "occupant": "person:asha",
        "room": "room:annex", "profile": {"id": "person:asha",
        "kind": {"type": "Human", "tier": "Registered"}, "display_name": "Asha"}}}),
    ]);
    let mut w = World::new(hall(), f, 1).unwrap();
    w.run(1);
    assert_eq!(room_of(&w, "person:asha").as_deref(), Some("room:annex"));
}

#[test]
fn rearrival_is_a_new_presence() {
    let f = feed(&[
        arrive(0, "agent:a"),
        obs(0, "agent:a", "Process", json!("Running"), 50),
        depart(2, "agent:a"),
        arrive(3, "agent:a"),
    ]);
    let mut w = World::new(hall(), f, 1).unwrap();
    w.run(4);
    let a = &w.snapshot().occupants[&CityId::from("agent:a")];
    assert_eq!(room_of(&w, "agent:a").as_deref(), Some("room:work"));
    assert!(
        a.presence.process.is_none(),
        "old observations do not survive departure"
    );
    assert_eq!(a.shown.process, ShownProcess::Unknown);
}

#[test]
fn move_goes_through_the_door_and_is_admitted_on_arrival() {
    let f = feed(&[arrive(0, "agent:a"), mv(2, "agent:a", "room:annex")]);
    let mut w = World::new(hall(), f, 1).unwrap();
    let ev = w.run(2);
    assert!(matches!(
        location(&w, "agent:a"),
        Location::InTransit { arrives_at: 3, .. }
    ));
    assert!(ev.iter().any(|e| matches!(&e.kind,
        EventKind::SeatReleased { seat, .. } if seat.as_str() == "seat:w1")));
    w.run(1); // tick 3: the transit ends and the occupant is admitted
    assert_eq!(room_of(&w, "agent:a").as_deref(), Some("room:annex"));
    assert_eq!(seat_of(&w, "agent:a").as_deref(), Some("seat:x1"));
}

#[test]
fn move_without_a_door_is_rejected() {
    let mut m = hall();
    strip_doors(&mut m, "room:annex");
    let f = feed(&[
        json!({"at": 0, "command": {"type": "Arrive", "occupant": "agent:a", "room": "room:annex"}}),
        mv(2, "agent:a", "room:work"),
        mv(2, "agent:b", "room:work"),
    ]);
    let mut w = World::new(m, f, 1).unwrap();
    let ev = w.run(2);
    let reasons: Vec<_> = ev
        .iter()
        .filter_map(|e| match &e.kind {
            EventKind::Rejected { reason, .. } => Some(reason.clone()),
            _ => None,
        })
        .collect();
    assert_eq!(reasons, vec![RejectReason::NoDoor, RejectReason::NotInRoom]);
}

#[test]
fn presence_goes_working_then_stale_then_idle() {
    let f = feed(&[
        arrive(0, "agent:a"),
        obs(0, "agent:a", "Process", json!("Running"), 100),
        obs(0, "agent:a", "Task", json!({"state": "Working"}), 3),
        obs(6, "agent:a", "Task", json!({"state": "Idle"}), 50),
    ]);
    let mut w = World::new(hall(), f, 1).unwrap();
    let headline = |w: &World| {
        w.snapshot().occupants[&CityId::from("agent:a")]
            .shown
            .headline
    };
    w.run(1);
    assert_eq!(headline(&w), Headline::Working);
    let ev = w.run(2); // tick 3 = expires_at
    assert_eq!(headline(&w), Headline::Stale);
    assert!(ev.iter().any(|e| matches!(
        e.kind,
        EventKind::ObservationExpired {
            dimension: Dimension::Task
        }
    )));
    w.run(3);
    assert_eq!(headline(&w), Headline::Idle);
}

#[test]
fn departing_mid_transit_leaves_from_nowhere() {
    let f = feed(&[
        arrive(0, "agent:a"),
        mv(2, "agent:a", "room:annex"),
        depart(2, "agent:a"),
    ]);
    let mut w = World::new(hall(), f, 1).unwrap();
    let ev = w.run(2);
    assert!(ev.iter().any(|e| matches!(
        e.kind,
        EventKind::Departed {
            from: None,
            via: None
        }
    )));
    assert!(matches!(location(&w, "agent:a"), Location::Away));
}

#[test]
fn board_and_alight_are_refused_away_from_a_line() {
    let f = feed(&[
        arrive(0, "agent:a"),
        json!({"at": 1, "command": {"type": "Board", "occupant": "agent:a"}}),
        json!({"at": 1, "command": {"type": "Alight", "occupant": "agent:a"}}),
    ]);
    let mut w = World::new(hall(), f, 1).unwrap();
    let rejected: Vec<(CommandType, RejectReason)> = w
        .run(2)
        .iter()
        .filter_map(|e| match &e.kind {
            EventKind::Rejected { command, reason } => Some((*command, reason.clone())),
            _ => None,
        })
        .collect();
    assert_eq!(
        rejected,
        [
            (CommandType::Board, RejectReason::NotOnPlatform),
            (CommandType::Alight, RejectReason::NotAboard),
        ]
    );
}

/// FNV-1a (64-bit) over `bytes`.
fn fnv1a(bytes: &[u8]) -> u64 {
    bytes.iter().fold(0xcbf2_9ce4_8422_2325, |h, b| {
        (h ^ u64::from(*b)).wrapping_mul(0x0000_0100_0000_01b3)
    })
}

/// `"direct"` arrivals are the old world, byte for byte: the two-room
/// gate's event log, written as `city run --seed 7 --ticks 40` writes
/// `events.jsonl`, hashes to what it did before trams carried anyone
/// (recorded from that command's output before the change).
#[test]
fn the_direct_gate_log_is_unchanged_by_the_tram() {
    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/two-room/manifest.json")).unwrap();
    assert_eq!(manifest.city.arrivals, Arrivals::Direct);
    let feed =
        city_core::parse_feed(include_str!("../../../fixtures/two-room/feed.jsonl")).unwrap();
    let mut w = World::new(manifest, feed, 7).unwrap();
    let mut log = String::new();
    for e in w.run(40) {
        log.push_str(&serde_json::to_string(&e).unwrap());
        log.push('\n');
    }
    assert_eq!(log.len(), 7633);
    assert_eq!(fnv1a(log.as_bytes()), 0x2c82_de65_ee48_e52b);
}

/// Agents never send `Use`, so giving it rules left the district's day
/// unchanged, byte for byte: its event log (the district gate's run, written
/// as `events.jsonl` lines) hashes to what the core gave before `Use` had
/// rules (recorded at commit 474e529: 132,121 bytes, 0x8da2_74c8_a681_be8d).
/// The district's things to use (its displays, perches and meadows) then
/// changed the fixture, not the rules: that manifest still gives the old
/// log, and this one walks a little differently round the new things (two
/// more presence changes, one more expiry), recorded when they were added.
/// The workstations changed the fixture again (132,609 bytes,
/// 0xd68e_fd2c_48db_ba24, before them), and the rules that let one be used
/// still give that log on the manifest before them. On this one, the
/// reading room's two desks sort after its chairs (`seat:rw1` after
/// `seat:r8`), so the policy seats everyone where it did before and no one
/// at a desk; one crowd member walks out round the desks and leaves 6 ticks
/// sooner (tick 446, not 452): the same 998 events, one moved.
#[test]
fn the_district_log_is_unchanged_by_use() {
    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    let story =
        city_core::parse_feed(include_str!("../../../fixtures/district/feed.jsonl")).unwrap();
    let feed = city_core::merge(story, city_core::crowd(&manifest, 60, 7).unwrap()).unwrap();
    let mut w = World::new(manifest, feed, 7).unwrap();
    let mut log = String::new();
    for e in w.run(600) {
        log.push_str(&serde_json::to_string(&e).unwrap());
        log.push('\n');
    }
    assert_eq!(log.len(), 132_609);
    assert_eq!(fnv1a(log.as_bytes()), 0xd0d0_b07b_a6ae_eab9);
}

#[test]
fn same_seed_same_log_and_seed_drives_transit_time() {
    let mut m = hall();
    set_transit(&mut m, "room:work", 1, 50);
    let f = || feed(&[arrive(0, "agent:a"), mv(2, "agent:a", "room:annex")]);
    let log = |seed| {
        let mut w = World::new(m.clone(), f(), seed).unwrap();
        w.run(60)
            .iter()
            .map(|e| serde_json::to_string(e).unwrap())
            .collect::<Vec<_>>()
            .join("\n")
    };
    assert_eq!(log(7), log(7));
    let logs: std::collections::BTreeSet<String> = (0..8).map(log).collect();
    assert!(logs.len() > 1, "the seed must influence transit timing");
}

fn personal_feed_lines() -> Vec<serde_json::Value> {
    vec![
        json!({"at": 0, "command": {"type": "Arrive", "occupant": "pa:helper", "room": "room:work",
            "profile": {"id": "pa:helper", "display_name": "Helper",
                        "kind": {"type": "PersonalAgent", "owner": "person:asha"}}}}),
        json!({"at": 0, "command": {"type": "Arrive", "occupant": "person:obs", "room": "room:work",
            "profile": {"id": "person:obs", "display_name": "O",
                        "kind": {"type": "Human", "tier": "Observer"}}}}),
        arrive(0, "agent:kai"),
        obs(0, "agent:kai", "Process", json!("Running"), 99),
        obs(
            0,
            "agent:kai",
            "Task",
            json!({"state": "Working", "summary": "secret plan"}),
            99,
        ),
        obs(0, "pa:helper", "Process", json!("Running"), 99),
        obs(
            0,
            "pa:helper",
            "Task",
            json!({"state": "Working", "summary": "asha's errand"}),
            99,
        ),
    ]
}

fn ids(p: &Projection) -> Vec<String> {
    p.rooms
        .iter()
        .flat_map(|r| r.occupants.iter().chain(&r.waiting))
        .chain(&p.in_transit)
        .map(|o| o.id.to_string())
        .collect()
}

fn find<'a>(p: &'a Projection, id: &str) -> &'a OccupantView {
    p.rooms
        .iter()
        .flat_map(|r| &r.occupants)
        .find(|o| o.id.as_str() == id)
        .unwrap_or_else(|| panic!("{id} not in projection"))
}

#[test]
fn personal_agent_is_visible_to_its_owner_only() {
    let mut w = World::new(hall(), feed(&personal_feed_lines()), 1).unwrap();
    w.run(1);
    let s = w.snapshot();
    assert!(!ids(&project(s, &Viewer::Public)).contains(&"pa:helper".into()));
    let bo = Viewer::Person {
        id: "person:bo".into(),
    };
    assert!(!ids(&project(s, &bo)).contains(&"pa:helper".into()));
    let own = project(
        s,
        &Viewer::Person {
            id: "person:asha".into(),
        },
    );
    assert_eq!(
        find(&own, "pa:helper").task_summary.as_deref(),
        Some("asha's errand")
    );
    assert_eq!(find(&own, "pa:helper").badge, Some(Badge::Ai));
}

#[test]
fn sharing_grants_presence_but_not_the_summary() {
    let mut lines = personal_feed_lines();
    lines.push(json!({"at": 1, "command": {"type": "Share", "occupant": "pa:helper", "grantee": "person:bo"}}));
    let mut w = World::new(hall(), feed(&lines), 1).unwrap();
    w.run(2);
    let p = project(
        w.snapshot(),
        &Viewer::Person {
            id: "person:bo".into(),
        },
    );
    let h = find(&p, "pa:helper");
    assert_eq!(h.task_summary, None);
    assert_eq!(h.presence.headline, Headline::Working);
}

#[test]
fn observers_are_hidden_from_everyone_but_themselves() {
    let mut w = World::new(hall(), feed(&personal_feed_lines()), 1).unwrap();
    w.run(1);
    assert!(!ids(&project(w.snapshot(), &Viewer::Public)).contains(&"person:obs".into()));
    let me = Viewer::Person {
        id: "person:obs".into(),
    };
    assert!(ids(&project(w.snapshot(), &me)).contains(&"person:obs".into()));
}

#[test]
fn private_summaries_are_closed_by_default_and_public_views_carry_no_counts() {
    let mut w = World::new(hall(), feed(&personal_feed_lines()), 1).unwrap();
    w.run(1);
    let p = project(w.snapshot(), &Viewer::Public);
    assert_eq!(find(&p, "agent:kai").task_summary, None);
    let json = serde_json::to_value(&p).unwrap().to_string();
    assert!(!json.contains("pa:helper"));
    assert!(!json.contains("occupancy") && !json.contains("holder"));
    assert_eq!(ids(&project(w.snapshot(), &Viewer::Operator)).len(), 3);
    assert_eq!(
        find(&project(w.snapshot(), &Viewer::Operator), "agent:kai")
            .task_summary
            .as_deref(),
        Some("secret plan")
    );
}

#[test]
fn public_summary_is_shown_when_marked_public_and_not_when_stale() {
    let f = feed(&[
        arrive(0, "agent:kai"),
        obs(0, "agent:kai", "Process", json!("Running"), 99),
        obs(
            0,
            "agent:kai",
            "Task",
            json!({"state": "Working", "summary": "fixing the kiln", "summary_public": true}),
            3,
        ),
    ]);
    let mut w = World::new(hall(), f, 1).unwrap();
    w.run(1);
    let p = project(w.snapshot(), &Viewer::Public);
    assert_eq!(
        find(&p, "agent:kai").task_summary.as_deref(),
        Some("fixing the kiln")
    );
    w.run(2);
    let p = project(w.snapshot(), &Viewer::Public);
    assert_eq!(find(&p, "agent:kai").task_summary, None);
}

/// The gate: a scripted run across two rooms in which agents and humans
/// arrive, are seated by capacity, go idle and stale, overflow and leave;
/// deterministic from its seed, with every invariant holding on every tick.
#[test]
fn gate_two_room_story() {
    use city_core::invariants::check_all;
    use std::collections::BTreeSet;

    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/two-room/manifest.json")).unwrap();
    let feed_text = include_str!("../../../fixtures/two-room/feed.jsonl");
    let run = || {
        let feed = city_core::parse_feed(feed_text).unwrap();
        assert!(feed.header.fixture, "the gate feed is a labelled fixture");
        let mut w = World::new(manifest.clone(), feed, 7).unwrap();
        let mut log = Vec::new();
        let mut headlines = BTreeSet::new();
        for _ in 0..40 {
            let before = w.snapshot().clone();
            let ev = w.step();
            let v = check_all(&before, w.snapshot(), &ev);
            assert!(v.is_empty(), "tick {}: {v:?}", w.snapshot().tick);
            let public = project(w.snapshot(), &Viewer::Public);
            let json = serde_json::to_string(&public).unwrap();
            assert!(!json.contains("pa:asha-notes") && !json.contains("person:guest"));
            for e in &ev {
                if let EventKind::PresenceChanged { shown } = &e.kind {
                    headlines.insert(format!("{:?}", shown.headline));
                }
            }
            log.extend(ev);
        }
        (w, log, headlines)
    };
    let (w, log, headlines) = run();

    let kinds: BTreeSet<String> = log.iter().map(|e| type_name(&e.kind)).collect();
    for k in [
        "Arrived",
        "Overflowed",
        "Waitlisted",
        "Seated",
        "TransitStarted",
        "ObservationExpired",
        "Departed",
    ] {
        assert!(kinds.contains(k), "the story never shows {k}: {kinds:?}");
    }
    for h in ["Working", "Idle", "Unknown", "Stale"] {
        assert!(
            headlines.contains(h),
            "the story never shows {h}: {headlines:?}"
        );
    }
    assert!(
        !kinds.contains("Rejected"),
        "the script issues only valid commands"
    );
    assert!(log.iter().all(|e| e.fixture));
    for e in &log {
        if e.occupant
            .as_ref()
            .is_some_and(|o| o.as_str() == "agent:kai")
            && let EventKind::Seated { seat, .. } = &e.kind
        {
            assert_eq!(
                seat.as_str(),
                "seat:w3",
                "kai only ever sits in his reserved seat"
            );
        }
    }
    assert!(
        w.snapshot()
            .occupants
            .values()
            .all(|o| matches!(o.location, Location::Away)),
        "everyone has left by the end"
    );

    let (_, again, _) = run();
    let bytes = |l: &[Event]| {
        l.iter()
            .map(|e| serde_json::to_string(e).unwrap())
            .collect::<Vec<_>>()
    };
    assert_eq!(bytes(&log), bytes(&again));
}

// ---- Final-review fixes ----

fn chain_manifest() -> Manifest {
    // room:a (capacity 1) overflows to room:b (capacity 1); no reservations.
    manifest(json!({
        "schema_version": 2,
        "catalogue": 1,
        "city": {"id": "city:c", "name": "C", "districts": [
            {"id": "district:c", "name": "C", "facilities": [
                {"id": "facility:c", "name": "C", "rooms": [
                    {"id": "room:a", "name": "A", "capacity": 1, "seats": [{"id": "seat:a1"}],
                     "overflow": "room:b",
                     "doors": [{"id": "door:ab", "to": "room:b", "transit": {"min": 1, "max": 1}}]},
                    {"id": "room:b", "name": "B", "capacity": 1, "seats": [{"id": "seat:b1"}]}
                ]}
            ]}
        ]},
        "occupants": (["x", "y", "z", "w"].iter().map(|n| json!({"id": format!("agent:{n}"),
            "kind": {"type": "GuildAgent"}, "display_name": n, "work": "room:a"})).collect::<Vec<_>>())
    }))
}

#[test]
fn waitlisted_occupant_takes_a_freed_overflow_room_before_newcomers() {
    let f = feed(&[
        arrive(1, "agent:x"),
        arrive(1, "agent:y"),
        arrive(1, "agent:z"),
        depart(3, "agent:y"),
        arrive(5, "agent:w"),
    ]);
    let mut w = World::new(chain_manifest(), f, 1).unwrap();
    w.run(4);
    assert_eq!(
        room_of(&w, "agent:z").as_deref(),
        Some("room:b"),
        "z uses the freed overflow room"
    );
    w.run(1);
    assert!(matches!(
        location(&w, "agent:w"),
        Location::Waitlisted { .. }
    ));
}

#[test]
fn newcomers_do_not_overtake_a_waitlist() {
    let f = feed(&[
        arrive(1, "agent:x"),
        arrive(1, "agent:y"),
        arrive(2, "agent:z"),
        arrive(3, "agent:w"),
        depart(5, "agent:x"),
    ]);
    let mut w = World::new(chain_manifest(), f, 1).unwrap();
    w.run(6);
    assert_eq!(
        room_of(&w, "agent:z").as_deref(),
        Some("room:a"),
        "z was first in line"
    );
    assert!(matches!(
        location(&w, "agent:w"),
        Location::Waitlisted { .. }
    ));
}

#[test]
fn door_transit_never_makes_an_occupant_vanish() {
    let f = feed(&[arrive(0, "agent:a"), mv(2, "agent:a", "room:annex")]);
    let mut w = World::new(hall(), f, 1).unwrap();
    for _ in 0..6 {
        w.step();
        let p = project(w.snapshot(), &Viewer::Public);
        let seen = p
            .rooms
            .iter()
            .flat_map(|r| r.occupants.iter().chain(&r.waiting))
            .chain(&p.in_transit)
            .any(|o| o.id.as_str() == "agent:a");
        assert!(seen, "agent:a vanished at tick {}", w.snapshot().tick);
    }
    assert_eq!(room_of(&w, "agent:a").as_deref(), Some("room:annex"));
}

#[test]
fn projected_waiting_list_keeps_queue_order() {
    let mut m = hall();
    for r in m.city.districts[0].facilities[0].rooms.iter_mut() {
        r.overflow = None;
    }
    let f = feed(&[
        arrive(1, "agent:a"),
        arrive(1, "agent:b"),
        arrive(2, "agent:d"),
        arrive(3, "agent:c"),
    ]);
    let mut w = World::new(m, f, 1).unwrap();
    w.run(3);
    let p = project(w.snapshot(), &Viewer::Public);
    let work = p
        .rooms
        .iter()
        .find(|r| r.id.as_str() == "room:work")
        .unwrap();
    let order: Vec<_> = work.waiting.iter().map(|o| o.id.to_string()).collect();
    assert_eq!(order, ["agent:d", "agent:c"]);
}

#[test]
fn hidden_occupants_take_no_shared_capacity_or_seats() {
    // Work holds 3 with kai's seat held: two public strangers fit. A private
    // agent and an anonymous observer are present too, but must not shape
    // anything the public can see.
    let mut lines = personal_feed_lines();
    lines.retain(|l| l["command"]["occupant"] != "agent:kai");
    lines.push(arrive(1, "agent:a"));
    lines.push(arrive(1, "agent:b"));
    lines.push(arrive(1, "agent:c"));
    let mut w = World::new(hall(), feed(&lines), 1).unwrap();
    w.run(2);
    assert_eq!(room_of(&w, "pa:helper").as_deref(), Some("room:work"));
    assert_eq!(seat_of(&w, "pa:helper"), None);
    assert_eq!(room_of(&w, "person:obs").as_deref(), Some("room:work"));
    assert_eq!(seat_of(&w, "person:obs"), None);
    assert_eq!(room_of(&w, "agent:a").as_deref(), Some("room:work"));
    assert_eq!(room_of(&w, "agent:b").as_deref(), Some("room:work"));
    assert_eq!(room_of(&w, "agent:c").as_deref(), Some("room:annex"));
    let before = w.snapshot().clone();
    let ev = w.step();
    assert!(city_core::invariants::check_all(&before, w.snapshot(), &ev).is_empty());
}

/// The district gate: the scripted story plus a crowd of 60 over one day,
/// with every invariant, movement included, holding on every tick, and
/// the comings and goings riding the boulevard tram (spec §1, criterion
/// 2): every public arrival steps off a tram before it is admitted
/// anywhere, every public departure rides out on one, and no public
/// occupant appears on the ground or leaves it but by stepping off or
/// boarding.
#[test]
fn district_gate() {
    use city_core::invariants::check_world;
    use city_core::project::shares_capacity;
    use std::collections::BTreeSet;

    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    let story =
        city_core::parse_feed(include_str!("../../../fixtures/district/feed.jsonl")).unwrap();
    assert!(story.header.fixture);
    let run = || {
        let feed =
            city_core::merge(story.clone(), city_core::crowd(&manifest, 60, 7).unwrap()).unwrap();
        let mut w = World::new(manifest.clone(), feed, 7).unwrap();
        let mut log = Vec::new();
        let mut longest_queue = 0;
        let mut times = BTreeSet::new();
        for _ in 0..600 {
            let before = w.snapshot().clone();
            let ev = w.step();
            let v = check_world(&before, &w, &ev);
            assert!(v.is_empty(), "tick {}: {v:?}", w.snapshot().tick);
            // A public occupant comes onto the ground only by stepping off
            // a tram and leaves it only by boarding one.
            let did = |id: &CityId, what: &str| {
                ev.iter()
                    .any(|e| e.occupant.as_ref() == Some(id) && type_name(&e.kind) == what)
            };
            for (id, o) in &w.snapshot().occupants {
                if !shares_capacity(&o.profile.kind) {
                    continue;
                }
                let was = before.occupants.get(id).and_then(|b| b.pos).is_some();
                let is = o.pos.is_some();
                assert!(
                    was || !is || did(id, "Alighted"),
                    "tick {}: {id} appeared on the ground",
                    w.snapshot().tick
                );
                assert!(
                    !was || is || did(id, "Boarded"),
                    "tick {}: {id} vanished from the ground",
                    w.snapshot().tick
                );
            }
            longest_queue = longest_queue.max(
                w.snapshot().rooms[&PlaceId::from("room:workshop")]
                    .waitlist
                    .len(),
            );
            if let Some(t) = project(w.snapshot(), &Viewer::Public).time_of_day {
                times.insert(t / 60);
            }
            log.extend(ev);
        }
        let public: BTreeSet<CityId> = w
            .snapshot()
            .occupants
            .iter()
            .filter(|(_, o)| shares_capacity(&o.profile.kind))
            .map(|(id, _)| id.clone())
            .collect();
        let riding_in: BTreeSet<CityId> = w
            .snapshot()
            .occupants
            .iter()
            .filter(|(_, o)| {
                matches!(
                    o.location,
                    Location::Arriving { .. } | Location::Aboard { .. }
                )
            })
            .map(|(id, _)| id.clone())
            .collect();
        (log, longest_queue, times, public, riding_in)
    };
    let (log, longest_queue, hours, public, riding_in) = run();
    // Agents never send `Use`, so the district's log has no uses in it: a
    // seat is still taken and left by `Seated` and `SeatReleased` alone.
    assert!(
        !log.iter().any(|e| matches!(
            e.kind,
            EventKind::Using { .. } | EventKind::StoppedUsing { .. }
        )),
        "no one uses anything in the district's day"
    );
    // Criterion 2, from the log: each public presence starts with
    // `Arrived`, then `Alighted` before any admission, seat or walk, and
    // ends with a `Departed` that names the tram it rode out on.
    let mut stepped_off: std::collections::BTreeMap<&CityId, bool> = Default::default();
    let (mut arrivals, mut departures) = (0, 0);
    for e in &log {
        let Some(id) = e.occupant.as_ref().filter(|id| public.contains(*id)) else {
            continue;
        };
        match &e.kind {
            EventKind::Arrived { .. } => {
                arrivals += 1;
                stepped_off.insert(id, false);
            }
            EventKind::Alighted { .. } => {
                stepped_off.insert(id, true);
            }
            EventKind::Admitted { .. }
            | EventKind::Seated { .. }
            | EventKind::TransitStarted { .. } => assert!(
                stepped_off.get(id) == Some(&true),
                "tick {}: {id} was {} without stepping off a tram",
                e.tick,
                type_name(&e.kind)
            ),
            EventKind::Departed { via, .. } => {
                departures += 1;
                assert!(via.is_some(), "tick {}: {id} departed on foot", e.tick);
                stepped_off.remove(id);
            }
            _ => {}
        }
    }
    for (id, off) in &stepped_off {
        assert!(
            *off || riding_in.contains(*id),
            "{id} arrived but never stepped off, and is not riding in"
        );
    }
    assert!(
        arrivals >= 60 && departures >= 30,
        "the day's comings ({arrivals}) and goings ({departures}) ride the tram"
    );
    let kinds: BTreeSet<String> = log.iter().map(|e| type_name(&e.kind)).collect();
    for k in [
        "Arrived",
        "Overflowed",
        "Waitlisted",
        "Seated",
        "TransitStarted",
        "ObservationExpired",
        "Departed",
    ] {
        assert!(kinds.contains(k), "the district never shows {k}");
    }
    assert!(
        longest_queue >= 2,
        "a queue of two or more forms outside the workshop"
    );
    assert!(
        hours.contains(&12) && hours.contains(&20),
        "the day passes noon and evening"
    );
    assert!(log.iter().all(|e| e.fixture));
    let (again, _, _, _, _) = run();
    let bytes = |l: &[Event]| {
        l.iter()
            .map(|e| serde_json::to_string(e).unwrap())
            .collect::<Vec<_>>()
    };
    assert_eq!(bytes(&log), bytes(&again));
}

/// The longest any public walker stays on one position while it still has
/// somewhere to go, over `ticks` of the district with a crowd.
fn longest_stall(crowd: u32, seed: u64, ticks: u64) -> (u64, String) {
    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    let story =
        city_core::parse_feed(include_str!("../../../fixtures/district/feed.jsonl")).unwrap();
    let feed = city_core::merge(story, city_core::crowd(&manifest, crowd, seed).unwrap()).unwrap();
    let mut w = World::new(manifest, feed, seed).unwrap();
    let mut still: std::collections::BTreeMap<CityId, (Point, u64)> = Default::default();
    let mut worst = (0, String::new());
    for _ in 0..ticks {
        w.step();
        let t = w.snapshot().tick;
        for (id, o) in &w.snapshot().occupants {
            let public = !matches!(
                o.profile.kind,
                OccupantKind::PersonalAgent { .. }
                    | OccupantKind::Human {
                        tier: HumanTier::Observer
                    }
            );
            match (o.pos, &o.walk) {
                (Some(p), Some(_)) if public => {
                    let entry = still.entry(id.clone()).or_insert((p, t));
                    if entry.0 != p {
                        *entry = (p, t);
                    }
                    if t - entry.1 > worst.0 {
                        worst = (t - entry.1, format!("{id} at tick {t}"));
                    }
                }
                _ => {
                    still.remove(id);
                }
            }
        }
    }
    worst
}

#[test]
fn walkers_are_never_stuck_long_in_the_gate_district() {
    let (ticks, who) = longest_stall(60, 7, 900);
    assert!(ticks <= 60, "{who} waited {ticks} ticks");
}

#[test]
fn a_crowded_district_does_not_gridlock_at_its_entrances() {
    let (ticks, who) = longest_stall(300, 11, 900);
    assert!(ticks <= 120, "{who} waited {ticks} ticks");
}

#[test]
fn the_district_follows_the_sheets_composition() {
    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    let kinds: std::collections::BTreeSet<String> = manifest
        .scenery
        .iter()
        .map(|s| {
            serde_json::to_value(s).unwrap()["kind"]
                .as_str()
                .unwrap()
                .to_string()
        })
        .collect();
    for k in ["water", "bridge", "street", "fence"] {
        assert!(kinds.contains(k), "scenery has no {k}");
    }
    // Blocks and the rows of palms are placements.
    let placed: std::collections::BTreeSet<&str> = manifest.city.districts[0]
        .placements
        .iter()
        .map(|p| p.kind.as_str())
        .collect();
    for k in ["block-house", "block-shop", "block-tower", "palm"] {
        assert!(placed.contains(k), "nothing is placed as {k}");
    }
    let outdoor: Vec<String> = manifest
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .flat_map(|f| &f.rooms)
        .filter(|r| r.is_outdoor())
        .map(|r| r.id.to_string())
        .collect();
    // The boulevard tram's platforms are outdoor rooms: the Square stop's
    // south platform and the Avenue stop's two. The ground they were carved
    // from is split round them: the tram street keeps the tracks with a
    // lane south of its platform, and the avenue gives up its south to
    // the platforms, the tracks between them and a corner beyond.
    assert_eq!(
        outdoor,
        [
            "room:cafe-terrace",
            "room:plaza",
            "room:park",
            "room:tram-stop",
            "room:tram-stop-south",
            "room:avenue-stop-north",
            "room:avenue-stop-south",
            "room:bridge",
            "room:quay",
            "room:uptown",
            "room:avenue",
            "room:avenue-south",
            "room:avenue-tramway",
            "room:avenue-end",
            "room:library-lane",
            "room:library-garden",
            "room:tram-street",
            "room:south-lane",
            "room:south-streets"
        ]
    );
    let crowd = city_core::crowd(&manifest, 200, 1).unwrap();
    let targets: std::collections::BTreeSet<String> = crowd
        .entries
        .iter()
        .filter_map(|e| match &e.command {
            Command::Arrive { room: Some(r), .. } | Command::Move { to: r, .. } => {
                Some(r.to_string())
            }
            _ => None,
        })
        .collect();
    for r in [
        "room:park",
        "room:cafe-terrace",
        "room:reading",
        "room:plaza",
    ] {
        assert!(targets.contains(r), "the crowd never visits {r}");
    }
}

/// The district runs the boulevard tram (spec §2): its line along the tram
/// street to the district's east edge, the Square and Avenue stops, and
/// platforms a tram's arrivals can always step off onto and leave without
/// crossing the tracks.
#[test]
fn the_district_runs_the_boulevard_tram() {
    use city_core::nav::NavGrid;
    use city_core::transit::band_cells;
    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    assert_eq!(manifest.city.arrivals, Arrivals::Tram);
    assert_eq!(manifest.lines.len(), 1);
    let line = &manifest.lines[0];
    assert_eq!(line.id.as_str(), "line:boulevard");
    assert_eq!(
        line.points,
        [Point { x: -1800, z: 2050 }, Point { x: 6800, z: 2050 }],
        "from the tram street's west edge to the district's east edge"
    );
    // Three metres apart, so the kits' 2.47 m trams pass each other clear
    // (they were 2 m apart, and trams passing touched).
    assert_eq!(line.tracks, [-150, 150]);
    // The first eastbound tram enters on the first tick, so a player
    // joining at launch rides in at once (it waited 30 ticks at the portal
    // with an offset of 0, since ticks run from 1).
    assert_eq!(
        (line.timetable.headway, line.timetable.offset),
        (30, [1, 16])
    );
    assert_eq!((line.timetable.speed, line.timetable.dwell), (28, 12));
    // The kits' 20.6 m tram, to the nearest 50 cm, doors at 20, 50 and 80%.
    assert_eq!(line.vehicle.capacity, 40);
    assert_eq!(line.vehicle.length, 2050);
    assert_eq!(line.vehicle.doors, [410, 1025, 1640]);
    let stops: Vec<(&str, i32, [&str; 2])> = line
        .stops
        .iter()
        .map(|s| {
            (
                s.id.as_str(),
                s.at,
                [s.platforms[0].as_str(), s.platforms[1].as_str()],
            )
        })
        .collect();
    assert_eq!(
        stops,
        [
            (
                "stop:square",
                1800,
                ["room:tram-stop", "room:tram-stop-south"]
            ),
            (
                "stop:avenue",
                7550,
                ["room:avenue-stop-north", "room:avenue-stop-south"]
            ),
        ]
    );
    let facilities = &manifest.city.districts[0].facilities;
    let facility = |id: &str| facilities.iter().find(|f| f.id.as_str() == id).unwrap();
    let rooms =
        |id: &str| -> Vec<&str> { facility(id).rooms.iter().map(|r| r.id.as_str()).collect() };
    assert_eq!(
        rooms("facility:tram-stop"),
        ["room:tram-stop", "room:tram-stop-south"]
    );
    assert_eq!(
        rooms("facility:avenue-stop"),
        ["room:avenue-stop-north", "room:avenue-stop-south"]
    );
    for id in ["facility:tram-stop", "facility:avenue-stop"] {
        assert_eq!(
            serde_json::to_value(facility(id)).unwrap()["category"],
            "transit"
        );
    }

    let index = city_core::PlaceIndex::build(&manifest).unwrap();
    let nav = NavGrid::build(&index);
    let info = &index.lines[&line.id];
    let track: std::collections::BTreeSet<_> = info
        .tracks
        .iter()
        .flat_map(|t| {
            band_cells(
                t,
                0,
                info.length,
                city_core::transit::half_width(info),
                &nav,
            )
        })
        .collect();
    // From each platform, the way off to the street or square beyond it
    // never crosses a track.
    for (platform, beyond) in [
        ("room:tram-stop", "room:plaza"),
        ("room:tram-stop-south", "room:south-lane"),
        ("room:avenue-stop-north", "room:avenue"),
        ("room:avenue-stop-south", "room:avenue-end"),
    ] {
        let room = facilities
            .iter()
            .flat_map(|f| &f.rooms)
            .find(|r| r.id.as_str() == platform)
            .unwrap();
        assert!(room.is_outdoor() && room.template.as_deref() == Some("tram-stop"));
        assert!(
            room.capacity >= line.vehicle.capacity * 3 / 2,
            "{platform} holds a full tram's riders and half as many again"
        );
        let rect = room.rect.unwrap();
        assert!(
            manifest.city.districts[0]
                .placements
                .iter()
                .any(|p| p.kind == "tram-shelter" && rect.contains(p.at)),
            "{platform} has a shelter"
        );
        let cells = nav.cells_in(&PlaceId::from(platform));
        assert!(
            cells.iter().all(|c| !track.contains(c)),
            "{platform} lies off the tracks"
        );
        let goal = nav.cells_in(&PlaceId::from(beyond))[0];
        assert!(
            nav.path_to(cells[0], goal, &|c| track.contains(&c))
                .is_some(),
            "{platform} leads to {beyond} without crossing a track"
        );
    }
}

/// The kits' shared tram layout (tools/styles/shared/tram_layout.py, written
/// to godot/styles/tram_layout.json) agrees with the core: the district
/// line's tram length, capacity and doors, and every slot where the core
/// draws its rider, `slot_along` behind the front and `SLOT_ACROSS` to the
/// left for an even slot or the right for an odd one.
#[test]
fn the_kits_tram_layout_agrees_with_the_cores_slots() {
    use city_core::project::SLOT_ACROSS;
    use city_core::transit::slot_along;
    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    let spec = &manifest.lines[0].vehicle;
    let layout: serde_json::Value =
        serde_json::from_str(include_str!("../../../godot/styles/tram_layout.json")).unwrap();
    assert_eq!(layout["length_cm"], spec.length, "the line's tram length");
    assert_eq!(layout["capacity"], spec.capacity);
    assert_eq!(
        layout["doors_cm"],
        json!(spec.doors),
        "doors at 20, 50 and 80%"
    );
    let slots = layout["slots"].as_array().unwrap();
    assert!(
        slots.len() >= spec.capacity as usize,
        "a slot for every rider"
    );
    for (k, s) in slots.iter().enumerate() {
        let slot = u32::try_from(k).unwrap();
        assert_eq!(s["slot"], slot);
        assert_eq!(
            s["along_cm"],
            slot_along(spec, slot),
            "slot {slot} along the tram"
        );
        let across = if slot.is_multiple_of(2) {
            SLOT_ACROSS
        } else {
            -SLOT_ACROSS
        };
        assert_eq!(s["across_cm"], across, "slot {slot} across it");
    }
}

/// The whole city is open ground, walkable from the square to every edge
/// and out along the bridge, and fenced wherever the ground ends.
#[test]
fn the_district_city_is_walkable_to_its_fenced_edges() {
    use city_core::nav::NavGrid;
    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    let nav = NavGrid::build(&city_core::PlaceIndex::build(&manifest).unwrap());
    let at = |x, z| nav.cell_of(Point { x, z });
    let square = at(-1000, 1000);
    assert!(nav.walkable(square), "the square's paving");
    for (x, z, edge) in [
        (-250, -6640, "the north edge"),
        (5200, -6640, "the north end of the avenue"),
        (6790, 4600, "the east edge"),
        (550, 5090, "the south edge"),
        (-4390, 0, "the quay"),
        (-7190, 2300, "the far end of the bridge"),
        (4400, 3300, "the southern blocks"),
    ] {
        let goal = at(x, z);
        assert!(nav.walkable(goal), "{edge} is open ground");
        let path = nav.path_to(square, goal, &|_| false);
        assert!(path.is_some(), "walkable from the square to {edge}");
    }
    for (x, z, beyond) in [
        (-4410, 0, "the river"),
        (0, -6660, "past the north edge"),
        (6810, 0, "past the east edge"),
        (0, 5110, "past the south edge"),
        (-6000, 2050, "the river beside the bridge"),
    ] {
        assert!(!nav.walkable(at(x, z)), "{beyond} is not walkable");
    }
    // Every metre of the land's edge and the bridge's far end is fenced,
    // but for where the bridge meets the quay (its parapets fence its
    // sides) and where the tracks leave at the east edge, which opens for
    // the trams from 16.5 m to 24.5 m, round both tracks.
    let fences: Vec<Vec<Point>> = manifest
        .scenery
        .iter()
        .filter_map(|s| match s {
            Scenery::Fence { points } => Some(points.clone()),
            _ => None,
        })
        .collect();
    let fenced = |p: Point| {
        fences.iter().any(|f| {
            f.windows(2).any(|w| {
                let (a, b) = (w[0], w[1]);
                (a.x == b.x && p.x == a.x && a.z.min(b.z) <= p.z && p.z <= a.z.max(b.z))
                    || (a.z == b.z && p.z == a.z && a.x.min(b.x) <= p.x && p.x <= a.x.max(b.x))
            })
        })
    };
    let mut edge = Vec::new();
    for x in (-4400..=6800).step_by(100) {
        edge.push(Point { x, z: -6650 });
        edge.push(Point { x, z: 5100 });
    }
    for z in (-6650..=5100).step_by(50) {
        if !(1700..=2400).contains(&z) {
            edge.push(Point { x: 6800, z });
        }
        if !(2100..=2500).contains(&z) {
            edge.push(Point { x: -4400, z });
        }
    }
    for z in (2100..=2500).step_by(50) {
        edge.push(Point { x: -7200, z });
    }
    for p in edge {
        assert!(fenced(p), "({}, {}) is unfenced", p.x, p.z);
    }
    // The trams fade out over their last 10 m at the portals, reaching up
    // to half their length past them: the fence opens where the tracks
    // leave at the east edge, and the park keeps its palms, flowerbed and
    // benches off their way west (the trams' bodies span z 17.8–23.2 m;
    // a path, flat on the ground, may run under them).
    for z in (1700..=2400).step_by(50) {
        assert!(
            !fenced(Point { x: 6800, z }),
            "the tracks leave through the fence at z {z}"
        );
    }
    let park = manifest.city.districts[0]
        .facilities
        .iter()
        .flat_map(|f| &f.rooms)
        .find(|r| r.id.as_str() == "room:park")
        .unwrap();
    // The park's own palms and flowerbed, which schema 1 listed as its
    // props.
    let points = manifest.city.districts[0]
        .placements
        .iter()
        .filter(|p| p.id.as_str().starts_with("placement:park-") && p.kind != "path")
        .map(|p| p.at)
        .chain(park.seats.iter().filter_map(|s| s.pos));
    for p in points {
        assert!(
            p.x < -3000 || !(1750..=2350).contains(&p.z),
            "({}, {}) stands in the trams' way out west",
            p.x,
            p.z
        );
    }
}

/// The district's story (seed 7, no crowd) with the player joined, sent at
/// tick 40 to stand just outside the workshop's plaza door, and run to the
/// end of tick 107. Then the workshop holds its eight and others queue at
/// that door. Also returns the steps from where the player stands to the
/// workshop's door span, the last of them onto the span, at the end of the
/// span away from the queue.
fn at_the_full_workshops_door() -> (World, Vec<Point>) {
    use city_core::invariants::check_world;
    use city_core::nav::Cell;
    use city_core::project::shares_capacity;

    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    let story =
        city_core::parse_feed(include_str!("../../../fixtures/district/feed.jsonl")).unwrap();
    let mut w = World::new(manifest, story, 7).unwrap();
    w.submit(
        serde_json::from_value(json!({"type": "Arrive", "occupant": "person:you",
            "room": "room:plaza", "player": true,
            "profile": {"id": "person:you", "kind": {"type": "Human", "tier": "Registered"},
                "display_name": "You"}}))
        .unwrap(),
    );
    let workshop = PlaceId::from("room:workshop");
    let plaza = PlaceId::from("room:plaza");
    let nav = w.nav().unwrap();
    let ids = nav.room_ids();
    let (_, span) = nav
        .door_spans()
        .find(|(rooms, _)| {
            let named: Vec<&PlaceId> = rooms.iter().map(|k| &ids[*k as usize]).collect();
            named.contains(&&workshop) && named.contains(&&plaza)
        })
        .expect("the workshop's plaza door");
    // The door is in the workshop's east wall, and its queue forms from
    // the north end of the span: the south end is clear.
    let inside = *span
        .iter()
        .filter(|c| nav.room_at(**c) == Some(&workshop))
        .max_by_key(|c| (c.j, c.i))
        .unwrap();
    let threshold = Cell {
        i: inside.i + 1,
        j: inside.j,
    };
    assert!(nav.in_door_span(threshold) && nav.room_at(threshold) == Some(&plaza));
    // Asked for a point by the door, Go stands the player on the nearest
    // good place to stand, off the span.
    let stand_at = nav.centre(Cell {
        i: inside.i + 2,
        j: inside.j,
    });
    for _ in 0..107 {
        if w.snapshot().tick == 39 {
            w.submit(
                serde_json::from_value(json!({"type": "Go", "occupant": "person:you",
                    "to": {"type": "Point", "pos": stand_at}}))
                .unwrap(),
            );
        }
        let before = w.snapshot().clone();
        let ev = w.step();
        let v = check_world(&before, &w, &ev);
        assert!(v.is_empty(), "tick {}: {v:?}", w.snapshot().tick);
    }
    assert_eq!(w.snapshot().tick, 107);
    assert_eq!(room_of(&w, "person:you").as_deref(), Some("room:plaza"));
    let nav = w.nav().unwrap();
    let here = nav.cell_of(pos_of(&w, "person:you").unwrap());
    let mut steps = nav
        .path_to(here, threshold, &|c| nav.in_door_span(c) && c != threshold)
        .expect("a way to the threshold");
    assert!(steps.len() <= 3, "standing by the door: {here:?}");
    steps.push(inside);
    let steps: Vec<Point> = steps.into_iter().map(|c| nav.centre(c)).collect();
    let s = w.snapshot();
    let state = &s.rooms[&workshop];
    let public = state
        .occupants
        .iter()
        .filter(|o| shares_capacity(&s.occupants[*o].profile.kind))
        .count();
    assert_eq!(public, 8, "the workshop is at its capacity of eight");
    assert!(!state.waitlist.is_empty(), "and others queue for it");
    (w, steps)
}

/// Walking into a full room (spec §6, "Full rooms"): at tick 108, with the
/// workshop full and queued for, a steer onto its door span is refused
/// with `RoomFull` at the threshold, and nothing waitlists or overflows
/// the player afterwards. A `Go` to the workshop at the same tick still
/// queues for it.
#[test]
fn a_steer_into_a_full_room_is_refused_at_its_door_and_go_still_queues() {
    use city_core::invariants::check_world;
    let you = CityId::from("person:you");
    let workshop = PlaceId::from("room:workshop");
    let theirs = |ev: &[Event]| -> Vec<EventKind> {
        ev.iter()
            .filter(|e| e.occupant.as_ref() == Some(&you))
            .map(|e| e.kind.clone())
            .collect()
    };

    let (mut w, steps) = at_the_full_workshops_door();
    let threshold_at = steps[steps.len() - 2];
    w.submit(Command::Steer {
        occupant: you.clone(),
        cells: steps,
    });
    let ev = w.step();
    assert_eq!(w.snapshot().tick, 108);
    assert_eq!(
        theirs(&ev),
        vec![EventKind::Rejected {
            command: CommandType::Steer,
            reason: RejectReason::RoomFull {
                room: workshop.clone()
            },
        }],
        "the step onto the workshop's span is refused"
    );
    assert_eq!(
        pos_of(&w, "person:you"),
        Some(threshold_at),
        "outside, at the threshold"
    );
    let mut after = Vec::new();
    for _ in 0..30 {
        let before = w.snapshot().clone();
        let ev = w.step();
        let v = check_world(&before, &w, &ev);
        assert!(v.is_empty(), "tick {}: {v:?}", w.snapshot().tick);
        after.extend(theirs(&ev));
    }
    assert!(
        after.is_empty(),
        "nothing waitlists, overflows or admits it: {after:?}"
    );
    assert_eq!(room_of(&w, "person:you").as_deref(), Some("room:plaza"));
    assert_eq!(pos_of(&w, "person:you"), Some(threshold_at));

    let (mut w, _) = at_the_full_workshops_door();
    w.submit(Command::Go {
        occupant: you.clone(),
        to: Target::Room {
            room: workshop.clone(),
        },
    });
    let mut events = Vec::new();
    for _ in 0..20 {
        events.extend(theirs(&w.step()));
        if events
            .iter()
            .any(|e| matches!(e, EventKind::Waitlisted { .. }))
        {
            break;
        }
    }
    assert!(
        events
            .iter()
            .any(|e| matches!(e, EventKind::Waitlisted { room, .. } if *room == workshop)),
        "Go queues for the full workshop: {events:?}"
    );
    assert!(
        !events
            .iter()
            .any(|e| matches!(e, EventKind::Overflowed { .. } | EventKind::Rejected { .. })),
        "{events:?}"
    );
}

/// The district's workstations: the workshop's eight desks, with their
/// pods and Kai's reservation as they were, and two public hot desks in the
/// reading room, whose capacity stays 8. Every anchor one stands or sits at
/// can be walked to from the district's entrances.
#[test]
fn the_district_works_at_workstations_it_can_reach() {
    use city_core::footprint::world_point;
    use city_core::placement::Reach;
    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    let rooms: Vec<&Room> = manifest.city.districts[0]
        .facilities
        .iter()
        .flat_map(|f| &f.rooms)
        .collect();
    let room = |id: &str| *rooms.iter().find(|r| r.id.as_str() == id).unwrap();
    let workshop = room("room:workshop");
    assert_eq!(workshop.seats.len(), 8);
    for (n, seat) in workshop.seats.iter().enumerate() {
        assert_eq!(seat.id.as_str(), format!("seat:w{}", n + 1));
        assert_eq!(seat.kind.as_deref(), Some("workstation"), "{}", seat.id);
        let pod = if n < 4 {
            "pod:making-1"
        } else {
            "pod:making-2"
        };
        assert_eq!(seat.pod.as_ref().map(|p| p.as_str()), Some(pod));
        let reserved = (n == 0).then_some("agent:kai");
        assert_eq!(seat.reserved_for.as_ref().map(|r| r.as_str()), reserved);
    }
    let reading = room("room:reading");
    assert_eq!(reading.capacity, 8);
    let desks: Vec<&Seat> = reading
        .seats
        .iter()
        .filter(|s| s.kind.as_deref() == Some("workstation"))
        .collect();
    let ids: Vec<&str> = desks.iter().map(|s| s.id.as_str()).collect();
    assert_eq!(ids, ["seat:rw1", "seat:rw2"]);
    for desk in &desks {
        assert_eq!(
            (desk.pod.as_ref(), desk.reserved_for.as_ref()),
            (None, None),
            "{}",
            desk.id
        );
    }

    let w = World::new(manifest.clone(), feed(&[]), 1).unwrap();
    let (index, grid) = (w.index(), w.nav().unwrap());
    let reach = Reach::of(index, grid);
    let kind = Catalogue::builtin().kind("workstation").unwrap();
    for seat in workshop.seats.iter().chain(desks.iter().copied()) {
        let (at, facing) = (seat.pos.unwrap(), seat.facing.unwrap_or(0));
        for anchor in kind
            .anchors
            .iter()
            .filter(|a| a.kind != AnchorType::Display)
        {
            let cell = grid.cell_of(world_point(at, facing, anchor.at));
            assert!(
                grid.walkable(cell) && reach.reaches(grid, cell),
                "{}'s {:?} anchor",
                seat.id,
                anchor.kind
            );
        }
    }
}

/// The reading room's workstations are public hot desks (interactions
/// spec §6): through the district's day (its story and crowd, as the
/// replay pin runs it), the seat policy puts no one at one while a reading
/// chair is free, agents above all. Holdings are followed event by event,
/// in the order the core took and released the seats.
#[test]
fn the_district_seats_no_one_at_a_reading_room_workstation_while_a_chair_is_free() {
    let manifest: Manifest =
        serde_json::from_str(include_str!("../../../fixtures/district/manifest.json")).unwrap();
    let reading = manifest.city.districts[0]
        .facilities
        .iter()
        .flat_map(|f| &f.rooms)
        .find(|r| r.id.as_str() == "room:reading")
        .unwrap()
        .clone();
    let kind_of = |seat: &PlaceId| {
        reading
            .seats
            .iter()
            .find(|s| &s.id == seat)
            .and_then(|s| s.kind.clone())
    };
    let chairs: Vec<PlaceId> = reading
        .seats
        .iter()
        .filter(|s| s.kind.as_deref() == Some("reading-chair"))
        .map(|s| s.id.clone())
        .collect();
    assert_eq!(chairs.len(), 8);
    let agents: Vec<CityId> = manifest
        .occupants
        .iter()
        .filter(|o| {
            !matches!(
                o.kind,
                OccupantKind::Human { .. } | OccupantKind::SimCitizen
            )
        })
        .map(|o| o.id.clone())
        .collect();
    let story =
        city_core::parse_feed(include_str!("../../../fixtures/district/feed.jsonl")).unwrap();
    let feed = city_core::merge(story, city_core::crowd(&manifest, 60, 7).unwrap()).unwrap();
    let mut w = World::new(manifest, feed, 7).unwrap();
    let mut held: std::collections::BTreeSet<PlaceId> = Default::default();
    let mut agents_seated = 0;
    for e in w.run(600) {
        match &e.kind {
            EventKind::Seated { room, seat } if room.as_str() == "room:reading" => {
                let who = e.occupant.as_ref().unwrap();
                agents_seated += usize::from(agents.contains(who));
                if kind_of(seat).as_deref() == Some("workstation") {
                    let free: Vec<_> = chairs.iter().filter(|c| !held.contains(*c)).collect();
                    assert!(
                        free.is_empty(),
                        "tick {}: {who} took {seat} while {free:?} was free",
                        e.tick
                    );
                }
                held.insert(seat.clone());
            }
            EventKind::SeatReleased { room, seat } if room.as_str() == "room:reading" => {
                held.remove(seat);
            }
            _ => {}
        }
    }
    assert!(agents_seated >= 2, "the reading room's agents sat down");
}
