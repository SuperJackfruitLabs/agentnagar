//! Shared helpers for the city-core integration tests.
#![allow(dead_code)]

use city_contracts::*;
use city_core::{Feed, World};
use serde_json::{Value, json};

pub fn manifest(v: Value) -> Manifest {
    serde_json::from_value(v).expect("test manifest parses")
}

/// A fixture feed: prepends the header and marks every entry as a fixture.
pub fn feed(lines: &[Value]) -> Feed {
    let mut text = String::from(
        r#"{"record":"header","schema_version":1,"source":"fixture:test","fixture":true}"#,
    );
    for l in lines {
        let mut l = l.clone();
        l["record"] = json!("entry");
        l["fixture"] = json!(true);
        text.push('\n');
        text.push_str(&l.to_string());
    }
    city_core::parse_feed(&text).expect("test feed parses")
}

pub fn guild(id: &str, dept: Option<&str>) -> Value {
    json!({"id": id, "kind": {"type": "GuildAgent"}, "display_name": id,
           "department": dept, "work": "room:work"})
}

/// `room:work` (capacity 3; pod making with w1, w2; w3 reserved for kai;
/// overflows to the annex) and `room:annex` (capacity 1), joined both ways.
pub fn hall() -> Manifest {
    manifest(json!({
        "schema_version": 2,
        "catalogue": 1,
        "city": {"id": "city:t", "name": "T", "districts": [
            {"id": "district:d", "name": "D", "facilities": [
                {"id": "facility:hall", "name": "Hall", "rooms": [
                    {"id": "room:work", "name": "Work", "capacity": 3,
                     "pods": [{"id": "pod:make", "department": "making"}],
                     "seats": [{"id": "seat:w1", "pod": "pod:make"},
                               {"id": "seat:w2", "pod": "pod:make"},
                               {"id": "seat:w3", "reserved_for": "agent:kai"}],
                     "overflow": "room:annex",
                     "doors": [{"id": "door:work-annex", "to": "room:annex", "transit": {"min": 1, "max": 1}}]},
                    {"id": "room:annex", "name": "Annex", "capacity": 1,
                     "seats": [{"id": "seat:x1"}],
                     "doors": [{"id": "door:annex-work", "to": "room:work", "transit": {"min": 1, "max": 1}}]}
                ]}
            ]}
        ]},
        "occupants": [guild("agent:kai", Some("making")), guild("agent:a", None),
                      guild("agent:b", None), guild("agent:c", None), guild("agent:d", None)]
    }))
}

fn rooms_mut(m: &mut Manifest) -> impl Iterator<Item = &mut Room> {
    m.city
        .districts
        .iter_mut()
        .flat_map(|d| d.facilities.iter_mut())
        .flat_map(|f| f.rooms.iter_mut())
}

pub fn strip_doors(m: &mut Manifest, room: &str) {
    for r in rooms_mut(m).filter(|r| r.id.as_str() == room) {
        r.doors.clear();
    }
}

pub fn set_transit(m: &mut Manifest, room: &str, min: u64, max: u64) {
    for r in rooms_mut(m).filter(|r| r.id.as_str() == room) {
        for d in &mut r.doors {
            d.transit = TickRange { min, max };
        }
    }
}

pub fn arrive(at: u64, id: &str) -> Value {
    json!({"at": at, "command": {"type": "Arrive", "occupant": id}})
}

pub fn depart(at: u64, id: &str) -> Value {
    json!({"at": at, "command": {"type": "Depart", "occupant": id}})
}

pub fn mv(at: u64, id: &str, to: &str) -> Value {
    json!({"at": at, "command": {"type": "Move", "occupant": id, "to": to}})
}

pub fn obs(at: u64, id: &str, dim: &str, value: Value, exp: u64) -> Value {
    json!({"at": at, "command": {"type": "Observe", "occupant": id, "observation": {
        "dimension": dim, "value": value,
        "stamp": {"observed_at": at, "fetched_at": at, "expires_at": exp,
                  "source": "fixture", "source_version": "1"}}}})
}

pub fn location<'a>(w: &'a World, id: &str) -> &'a Location {
    &w.snapshot().occupants[&CityId::from(id)].location
}

pub fn room_of(w: &World, id: &str) -> Option<String> {
    match location(w, id) {
        Location::InRoom { room, .. } => Some(room.to_string()),
        _ => None,
    }
}

pub fn seat_of(w: &World, id: &str) -> Option<String> {
    match location(w, id) {
        Location::InRoom { seat, .. } => seat.as_ref().map(ToString::to_string),
        _ => None,
    }
}

pub fn type_name(k: &EventKind) -> String {
    serde_json::to_value(k).unwrap()["type"]
        .as_str()
        .unwrap()
        .to_string()
}

/// That occupant's event type names, leaving out presence changes.
pub fn filtered_kinds(events: &[Event], id: &str) -> Vec<String> {
    events
        .iter()
        .filter(|e| e.occupant.as_ref().is_some_and(|o| o.as_str() == id))
        .map(|e| type_name(&e.kind))
        .filter(|k| k != "PresenceChanged")
        .collect()
}

/// A small walking district. `room:work` (0,0 800×400; capacity 2; seats w1,
/// w2; overflows to the commons) and `room:commons` (800,0 800×400;
/// capacity 1; seat c1) sit above `room:plaza` (0,400 1600×800). Doors join
/// every pair. One entrance is on the plaza's west edge, and `room:island`
/// (1600,0 400×400) has no doors.
pub fn district_small() -> Manifest {
    let door = |id: &str, to: &str, x: i32, z: i32| json!({"id": id, "to": to, "pos": {"x": x, "z": z}, "transit": {"min": 1, "max": 1}});
    let occupant = |id: &str| json!({"id": id, "kind": {"type": "GuildAgent"}, "display_name": id, "work": "room:work"});
    manifest(json!({
        "schema_version": 2,
        "catalogue": 1,
        "clock": {"ticks_per_day": 600, "start_minute": 420},
        "city": {"id": "city:w", "name": "W", "entrances": [{"x": 0, "z": 800}], "districts": [
            {"id": "district:w", "name": "W", "facilities": [
                {"id": "facility:hall", "name": "Hall", "rooms": [
                    {"id": "room:work", "name": "Work", "capacity": 2, "template": "workshop",
                     "rect": {"x": 0, "z": 0, "w": 800, "d": 400}, "overflow": "room:commons",
                     "seats": [{"id": "seat:w1", "pos": {"x": 200, "z": 150}, "kind": "desk"},
                               {"id": "seat:w2", "pos": {"x": 600, "z": 150}, "kind": "desk"}],
                     "doors": [door("door:work-plaza", "room:plaza", 400, 400),
                               door("door:work-commons", "room:commons", 800, 200)]},
                    {"id": "room:commons", "name": "Commons", "capacity": 1, "template": "commons",
                     "rect": {"x": 800, "z": 0, "w": 800, "d": 400},
                     "seats": [{"id": "seat:c1", "pos": {"x": 1200, "z": 150}, "kind": "bench"}],
                     "doors": [door("door:commons-plaza", "room:plaza", 1200, 400),
                               door("door:commons-work", "room:work", 800, 200)]},
                    {"id": "room:island", "name": "Island", "capacity": 4, "template": "commons",
                     "rect": {"x": 1600, "z": 0, "w": 400, "d": 400}}
                ]},
                {"id": "facility:plaza", "name": "Plaza", "rooms": [
                    {"id": "room:plaza", "name": "Plaza", "capacity": 20, "template": "plaza",
                     "rect": {"x": 0, "z": 400, "w": 1600, "d": 800},
                     "doors": [door("door:plaza-work", "room:work", 400, 400),
                               door("door:plaza-commons", "room:commons", 1200, 400)]}
                ]}
            ]}
        ]},
        "occupants": [occupant("agent:a"), occupant("agent:b"), occupant("agent:c"),
                      occupant("agent:d"), occupant("agent:e")]
    }))
}

pub fn pos_of(w: &World, id: &str) -> Option<Point> {
    w.snapshot().occupants[&CityId::from(id)].pos
}
