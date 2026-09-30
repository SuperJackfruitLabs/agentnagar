//! End-to-end tests of the `city` binary.

use serde_json::{Value, json};
use std::path::{Path, PathBuf};
use std::process::Command;

fn dir(name: &str) -> PathBuf {
    let d = Path::new(env!("CARGO_TARGET_TMPDIR"))
        .join("cli")
        .join(name);
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    d
}

fn city(args: &[&str]) -> (i32, Value) {
    let o = Command::new(env!("CARGO_BIN_EXE_city"))
        .args(args)
        .output()
        .unwrap();
    let body = serde_json::from_slice(&o.stdout).unwrap_or(Value::Null);
    (o.status.code().unwrap(), body)
}

fn manifest() -> Value {
    json!({
        "schema_version": 2,
        "catalogue": 1,
        "city": {"id": "city:t", "name": "T", "districts": [
            {"id": "district:d", "name": "D", "facilities": [
                {"id": "facility:hall", "name": "Hall", "rooms": [
                    {"id": "room:work", "name": "Work", "capacity": 2,
                     "seats": [{"id": "seat:w1"}, {"id": "seat:w2"}],
                     "overflow": "room:annex",
                     "doors": [{"id": "door:wa", "to": "room:annex", "transit": {"min": 1, "max": 3}}]},
                    {"id": "room:annex", "name": "Annex", "capacity": 1, "seats": [{"id": "seat:x1"}]}
                ]}
            ]}
        ]},
        "occupants": [
            {"id": "agent:a", "kind": {"type": "GuildAgent"}, "display_name": "A", "work": "room:work"},
            {"id": "agent:b", "kind": {"type": "GuildAgent"}, "display_name": "B", "work": "room:work"},
            {"id": "agent:c", "kind": {"type": "GuildAgent"}, "display_name": "C", "work": "room:work"}
        ]
    })
}

const FEED: &str = r#"{"record":"header","schema_version":1,"source":"fixture:cli","fixture":true}
{"record":"entry","at":0,"fixture":true,"command":{"type":"Arrive","occupant":"agent:a"}}
{"record":"entry","at":0,"fixture":true,"command":{"type":"Arrive","occupant":"agent:b"}}
{"record":"entry","at":1,"fixture":true,"command":{"type":"Arrive","occupant":"agent:c"}}
{"record":"entry","at":4,"fixture":true,"command":{"type":"Depart","occupant":"agent:a"}}
"#;

/// Writes the manifest and feed into `d` and returns their paths.
fn inputs(d: &Path) -> (String, String) {
    let m = d.join("manifest.json");
    let f = d.join("feed.jsonl");
    std::fs::write(&m, manifest().to_string()).unwrap();
    std::fs::write(&f, FEED).unwrap();
    (m.display().to_string(), f.display().to_string())
}

fn run_into(d: &Path, out: &str) -> (i32, Value) {
    let (m, f) = inputs(d);
    let out = d.join(out).display().to_string();
    city(&[
        "run",
        "--manifest",
        &m,
        "--feed",
        &f,
        "--seed",
        "7",
        "--ticks",
        "6",
        "--snapshot-every",
        "3",
        "--out",
        &out,
    ])
}

#[test]
fn validate_ok_and_invalid() {
    let d = dir("validate");
    let (m, _) = inputs(&d);
    let (code, body) = city(&["validate", &m]);
    assert_eq!(code, 0);
    assert_eq!(body["valid"], true);

    let mut bad = manifest();
    bad["city"]["districts"][0]["facilities"][0]["rooms"][1]["overflow"] = json!("room:work");
    let bad_path = d.join("bad.json");
    std::fs::write(&bad_path, bad.to_string()).unwrap();
    let (code, body) = city(&["validate", bad_path.to_str().unwrap()]);
    assert_eq!(code, 1);
    assert_eq!(body["valid"], false);
    assert!(
        body["issues"]
            .as_array()
            .unwrap()
            .iter()
            .any(|i| i["code"] == "overflow-cycle")
    );

    let (code, body) = city(&["validate", d.join("missing.json").to_str().unwrap()]);
    assert_eq!(code, 2);
    assert_eq!(body["error"]["code"], "bad-input");
}

#[test]
fn a_schema_one_manifest_is_refused_for_its_version() {
    // Its tree rows no longer parse, but the refusal names the version and
    // the generator, not the tree rows.
    let d = dir("schema-one");
    let mut old = manifest();
    old["schema_version"] = json!(1);
    old["scenery"] = json!([{"kind": "tree-row", "spacing": 600,
        "points": [{"x": 0, "z": 0}, {"x": 600, "z": 0}]}]);
    let path = d.join("old.json");
    std::fs::write(&path, old.to_string()).unwrap();
    let path = path.to_str().unwrap();
    let (code, body) = city(&["validate", path]);
    assert_eq!((code, &body["valid"]), (1, &json!(false)), "{body}");
    assert_eq!(body["issues"].as_array().unwrap().len(), 1);
    assert_eq!(body["issues"][0]["code"], "schema-version");
    assert!(
        body["issues"][0]["message"]
            .as_str()
            .unwrap()
            .contains("city/fixtures/district/generate.py"),
        "{body}"
    );
    let (code, body) = city(&["grid", path]);
    assert_eq!(code, 1);
    assert_eq!(body["error"]["code"], "invalid-manifest");
    assert_eq!(body["issues"][0]["code"], "schema-version");
}

#[test]
fn a_schema_two_manifest_with_room_obstacles_is_refused_naming_them() {
    let d = dir("removed-field");
    let mut m = manifest();
    m["city"]["districts"][0]["facilities"][0]["rooms"][0]["obstacles"] =
        json!([{"x": 0, "z": 0, "w": 100, "d": 100}]);
    let path = d.join("obstacles.json");
    std::fs::write(&path, m.to_string()).unwrap();
    let path = path.to_str().unwrap();
    let (code, body) = city(&["validate", path]);
    assert_eq!((code, &body["valid"]), (1, &json!(false)), "{body}");
    assert_eq!(body["issues"][0]["code"], "removed-field", "{body}");
    assert_eq!(body["issues"][0]["place"], "room:work", "{body}");
    let (code, body) = city(&["grid", path]);
    assert_eq!(code, 1);
    assert_eq!(body["error"]["code"], "invalid-manifest");
    assert_eq!(body["issues"][0]["code"], "removed-field");
}

#[test]
fn run_writes_log_snapshots_and_summary() {
    let d = dir("run");
    let (code, body) = run_into(&d, "out");
    assert_eq!(code, 0, "{body}");
    assert_eq!(body["fixture"], true);
    assert_eq!(body["ticks"], 6);
    let out = d.join("out");
    for f in [
        "events.jsonl",
        "snapshots/tick-000003.json",
        "snapshots/tick-000006.json",
        "final.json",
        "summary.json",
    ] {
        assert!(out.join(f).exists(), "{f} missing");
    }
    let log = std::fs::read_to_string(out.join("events.jsonl")).unwrap();
    assert!(log.ends_with('\n'));
    for line in log.lines() {
        let e: Value = serde_json::from_str(line).unwrap();
        assert_eq!(e["fixture"], true);
    }
    assert!(log.contains("\"Overflowed\""));
}

#[test]
fn run_refuses_bad_arguments_and_bad_feeds() {
    let d = dir("run-bad");
    let (m, f) = inputs(&d);
    let out = d.join("out").display().to_string();
    let (code, _) = city(&[
        "run",
        "--manifest",
        &m,
        "--feed",
        &f,
        "--seed",
        "1",
        "--ticks",
        "0",
        "--out",
        &out,
    ]);
    assert_eq!(code, 2);
    let bad_feed = d.join("bad.jsonl");
    std::fs::write(&bad_feed, "{\"record\":\"entry\"}\n").unwrap();
    let (code, body) = city(&[
        "run",
        "--manifest",
        &m,
        "--feed",
        bad_feed.to_str().unwrap(),
        "--seed",
        "1",
        "--ticks",
        "2",
        "--out",
        &out,
    ]);
    assert_eq!(code, 2);
    assert_eq!(body["error"]["code"], "bad-feed");
    assert!(
        body["error"]["message"]
            .as_str()
            .unwrap()
            .contains("line 1")
    );
}

#[test]
fn run_is_byte_identical_for_the_same_seed() {
    let d = dir("determinism");
    assert_eq!(run_into(&d, "one").0, 0);
    assert_eq!(run_into(&d, "two").0, 0);
    let a = std::fs::read(d.join("one/events.jsonl")).unwrap();
    let b = std::fs::read(d.join("two/events.jsonl")).unwrap();
    assert!(!a.is_empty());
    assert_eq!(a, b);
}

#[test]
fn inspect_views_and_operator_flag() {
    let d = dir("inspect");
    assert_eq!(run_into(&d, "out").0, 0);
    let snap = d.join("out/final.json").display().to_string();
    let (code, body) = city(&["inspect", &snap]);
    assert_eq!(code, 0);
    assert!(body["rooms"].is_array());
    assert_eq!(body["viewer"]["type"], "Public");

    let (code, body) = city(&["inspect", &snap, "--viewer", "operator"]);
    assert_eq!(code, 1);
    assert_eq!(body["error"]["code"], "operator-flag-required");
    let (code, body) = city(&["inspect", &snap, "--viewer", "operator", "--operator"]);
    assert_eq!(code, 0);
    assert_eq!(body["viewer"]["type"], "Operator");

    let (code, body) = city(&["inspect", &snap, "--room", "room:work"]);
    assert_eq!(code, 0);
    assert_eq!(body["id"], "room:work");
    let (code, body) = city(&["inspect", &snap, "--occupant", "agent:b"]);
    assert_eq!(code, 0);
    assert_eq!(body["id"], "agent:b");
    let (code, body) = city(&["inspect", &snap, "--occupant", "agent:nobody"]);
    assert_eq!(code, 1);
    assert_eq!(body["error"]["code"], "not-found");
    let (code, _) = city(&[
        "inspect",
        &snap,
        "--room",
        "room:work",
        "--occupant",
        "agent:b",
    ]);
    assert_eq!(code, 2);
}

#[test]
fn diff_and_schema() {
    let d = dir("diff");
    assert_eq!(run_into(&d, "out").0, 0);
    let a = d
        .join("out/snapshots/tick-000003.json")
        .display()
        .to_string();
    let b = d.join("out/final.json").display().to_string();
    let (code, body) = city(&["diff", &a, &b]);
    assert_eq!(code, 1, "diff is full state: operator only");
    assert_eq!(body["error"]["code"], "operator-flag-required");
    let (code, body) = city(&["diff", &a, &b, "--operator"]);
    assert_eq!(code, 0);
    assert_eq!(body["from_tick"], 3);
    assert!(!body["changes"].as_array().unwrap().is_empty());

    let (code, body) = city(&["schema"]);
    assert_eq!(code, 0);
    assert!(body["manifest"].is_object());
    let out = d.join("schemas");
    let (code, _) = city(&["schema", "--out", out.to_str().unwrap()]);
    assert_eq!(code, 0);
    assert!(out.join("manifest.schema.json").exists());
    assert!(out.join("projection.schema.json").exists());
}

#[test]
fn run_with_a_crowd_on_the_district() {
    let d = dir("crowd");
    let fixtures = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/district");
    let out = d.join("out").display().to_string();
    let (code, body) = city(&[
        "run",
        "--manifest",
        fixtures.join("manifest.json").to_str().unwrap(),
        "--feed",
        fixtures.join("feed.jsonl").to_str().unwrap(),
        "--seed",
        "7",
        "--ticks",
        "600",
        "--crowd",
        "5",
        "--out",
        &out,
    ]);
    assert_eq!(code, 0, "{body}");
    let log = std::fs::read_to_string(d.join("out/events.jsonl")).unwrap();
    assert!(
        log.contains("\"crowd:"),
        "crowd arrivals are spread over the day"
    );

    let (code, body) = city(&[
        "run",
        "--manifest",
        &inputs(&d).0,
        "--feed",
        &inputs(&d).1,
        "--seed",
        "1",
        "--ticks",
        "2",
        "--crowd",
        "3",
        "--out",
        &out,
    ]);
    assert_eq!(code, 1, "a crowd needs a layout");
    assert_eq!(body["error"]["code"], "crowd-needs-layout");
}

#[test]
fn district_fixture_matches_its_generator() {
    let script = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/district/generate.py");
    let status = Command::new("python3")
        .arg(script)
        .arg("--check")
        .status()
        .unwrap();
    assert!(
        status.success(),
        "fixtures/district is stale; run generate.py"
    );
}

fn district_path() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/district/manifest.json")
}

fn district() -> city_contracts::Manifest {
    serde_json::from_str(&std::fs::read_to_string(district_path()).unwrap()).unwrap()
}

/// How many of the planting's placements stand inside the land, on its
/// lawns, park, garden and quay: street trees, palms, shrubs, and the
/// quay's planters.
const PLANTED_IN_THE_LAND: usize = 25 + 17 + 11 + 7;

/// How many placements of each kind the district holds (spec §5): the
/// manifest's own things, the blocks, the tree rows' 66 palms, 22 street
/// lamps and 12 catenary poles, and the planting: 60 plants inside the
/// land and 599 on the lawns beyond the fence. (The library steps and the
/// park's walls and meadows took the places of two street trees and a
/// shrub.)
const DISTRICT_PLACEMENTS: &[(&str, usize)] = &[
    ("block-house", 22),
    ("block-shop", 2),
    ("block-tower", 3),
    ("bollard", 8),
    ("bookshelf", 1 + 3),
    ("cafe-table-top", 4),
    ("catenary-pole", 12),
    ("flowerbed", 2 + 1),
    ("fountain-rim", 1),
    ("great-tree", 1),
    ("kiosk", 1),
    ("low-wall", 2),
    ("meadow", 3),
    ("noticeboard", 1),
    ("palm", 66 + 6 + 17 + 210),
    ("path", 1),
    ("planter", 4 + 7),
    ("plaque", 1),
    ("shrub", 11 + 105),
    ("steps", 1),
    ("street-lamp", 6 + 22),
    ("street-tree", 25 + 284),
    ("tram-shelter", 5),
    ("umbrella", 4),
    ("workbench", 1),
];

#[test]
fn district_fixture_is_laid_out_as_placements() {
    use city_contracts::{Catalogue, Class};
    use city_core::PlaceIndex;
    use city_core::nav::NavGrid;
    use city_core::placement::door_width;
    use std::collections::BTreeMap;

    let m = district();
    let catalogue = Catalogue::builtin();
    assert_eq!(m.catalogue, Some(1), "written against catalogue 1");
    let facilities: Vec<_> = m
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .collect();

    // The enclosed buildings, the guild hall and the library, have a
    // building kind, and nothing else has one: the café terrace is open,
    // with no café building behind it yet.
    for f in &facilities {
        if let Some(kind) = &f.kind {
            assert_eq!(catalogue.kind(kind).unwrap().class, Class::Building);
        }
    }
    let buildings: Vec<&str> = facilities
        .iter()
        .filter(|f| f.kind.is_some())
        .map(|f| f.id.as_str())
        .collect();
    assert_eq!(buildings, ["facility:guild-hall", "facility:library"]);

    // The guild hall's and library's exterior doors open 200 cm wide.
    let index = PlaceIndex::build(&m).unwrap();
    let mut exterior = 0;
    for room in index.rooms.values() {
        if !buildings.contains(&room.facility.as_str()) {
            continue;
        }
        for door in &room.door_list {
            if index.rooms[&door.to].facility != room.facility {
                exterior += 1;
                assert_eq!(door_width(&index, room, door), Some(200), "{}", door.id);
            }
        }
    }
    assert_eq!(
        exterior, 3,
        "workshop, commons and reading room onto the plaza"
    );

    // Every seat is a seat kind of the catalogue.
    for room in index.rooms.values() {
        for seat in &room.seats {
            let kind = seat
                .kind
                .as_deref()
                .unwrap_or_else(|| panic!("{} has a kind", seat.id));
            assert_eq!(
                catalogue.kind(kind).unwrap().class,
                Class::Seat,
                "{}",
                seat.id
            );
        }
    }

    // The placements, kind by kind.
    let mut counts: BTreeMap<&str, usize> = BTreeMap::new();
    for p in m.city.districts.iter().flat_map(|d| &d.placements) {
        assert!(p.id.as_str().starts_with("placement:"), "{}", p.id);
        *counts.entry(p.kind.as_str()).or_default() += 1;
    }
    let expected: BTreeMap<&str, usize> = DISTRICT_PLACEMENTS.iter().copied().collect();
    assert_eq!(counts, expected);

    // Planting stands on the lawns inside the land as well as beyond its
    // fence.
    let planted = |p: &&city_contracts::Placement| p.id.as_str().starts_with("placement:planting");
    let in_land = |p: &&city_contracts::Placement| {
        (-4400..6800).contains(&p.at.x) && (-6650..5100).contains(&p.at.z)
    };
    let placements = || m.city.districts.iter().flat_map(|d| &d.placements);
    assert_eq!(
        placements().filter(planted).filter(in_land).count(),
        PLANTED_IN_THE_LAND
    );

    // And neither it nor the flower beds (which people walk round) cut a
    // route: the grid without them joins the same rooms and entrances,
    // every cell reached from an entrance without them is reached with
    // them, and every room's queue forms where it did.
    let mut bare = m.clone();
    for d in &mut bare.city.districts {
        d.placements
            .retain(|p| !p.id.as_str().starts_with("placement:planting") && p.kind != "flowerbed");
    }
    let planted_grid = NavGrid::build(&index);
    let bare_grid = NavGrid::build(&PlaceIndex::build(&bare).unwrap());
    let entrances = &m.city.entrances;
    assert_eq!(
        planted_grid.room_links(entrances),
        bare_grid.room_links(entrances)
    );
    let sources: Vec<_> = entrances
        .iter()
        .filter_map(|e| bare_grid.snap(*e))
        .collect();
    let (with, without) = (
        planted_grid.reach_from(&sources),
        bare_grid.reach_from(&sources),
    );
    for c in planted_grid.cells_within(planted_grid.extent()) {
        if let (true, Some(k)) = (planted_grid.walkable(c), planted_grid.slot(c)) {
            assert!(with[k] || !without[k], "planting shuts {c:?} off");
        }
    }
    for room in index.rooms.values().filter(|r| !r.door_list.is_empty()) {
        assert_eq!(
            planted_grid.queue_slots(&room.id, 40),
            bare_grid.queue_slots(&room.id, 40),
            "{}'s queue",
            room.id
        );
    }

    // And the core finds nothing wrong with it.
    let (code, body) = city(&["validate", district_path().to_str().unwrap()]);
    assert_eq!(body["issues"], json!([]));
    assert_eq!((code, &body["valid"]), (0, &json!(true)));
}

/// The district's things to use, by placement: the displays and perches
/// the spec's first capabilities name, and where each stands.
const THINGS_TO_USE: &[(&str, &str, &str)] = &[
    ("placement:square-noticeboard", "noticeboard", "room:plaza"),
    ("placement:square-fountain", "fountain-rim", "room:plaza"),
    ("placement:guild-hall-plaque", "plaque", "room:plaza"),
    ("placement:library-kiosk", "kiosk", "room:reading"),
    ("placement:reading-shelf-1", "bookshelf", "room:reading"),
    ("placement:reading-shelf-2", "bookshelf", "room:reading"),
    ("placement:reading-shelf-3", "bookshelf", "room:reading"),
    ("placement:commons-bookshelf", "bookshelf", "room:commons"),
    ("placement:library-steps", "steps", "room:library-garden"),
    ("placement:park-wall-1", "low-wall", "room:park"),
    ("placement:park-wall-2", "low-wall", "room:park"),
    (
        "placement:shelter-square-north-1",
        "tram-shelter",
        "room:tram-stop",
    ),
    (
        "placement:shelter-square-north-2",
        "tram-shelter",
        "room:tram-stop",
    ),
    (
        "placement:shelter-square-south-1",
        "tram-shelter",
        "room:tram-stop-south",
    ),
    (
        "placement:shelter-avenue-north-1",
        "tram-shelter",
        "room:avenue-stop-north",
    ),
    (
        "placement:shelter-avenue-south-1",
        "tram-shelter",
        "room:avenue-stop-south",
    ),
];

/// A tram shelter's bench can be sat on (spec section 1, criterion 2):
/// two or three `sit` anchors 60 cm or more apart, along the front of its
/// bench (the footprint's rect from x -65 to 175, its face at z -15), each
/// sat facing the platform in front of it; and the kind offers `sit` there.
#[test]
fn a_tram_shelters_bench_is_sat_on_along_its_front() {
    use city_contracts::{AnchorType, Catalogue};

    let kind = Catalogue::builtin().kind("tram-shelter").unwrap();
    assert!(
        kind.capabilities
            .iter()
            .any(|c| c.name == "sit" && c.at == Some(AnchorType::Sit)),
        "the shelter offers sit at its sit anchors"
    );
    let sits: Vec<_> = kind
        .anchors
        .iter()
        .filter(|a| a.kind == AnchorType::Sit)
        .collect();
    assert!((2..=3).contains(&sits.len()), "{} sit anchors", sits.len());
    for (k, a) in sits.iter().enumerate() {
        assert!(
            (-65..=175).contains(&a.at.x),
            "anchor {k} is along the bench"
        );
        assert!(
            (-15..=15).contains(&a.at.z),
            "anchor {k} is just in front of the bench"
        );
        assert_eq!(a.facing, 180, "anchor {k} is sat facing the platform");
        for b in &sits[k + 1..] {
            assert!((a.at.x - b.at.x).abs() >= 60, "anchors 60 cm or more apart");
        }
    }
}

#[test]
fn every_anchor_of_the_districts_things_to_use_is_reached_where_it_stands() {
    use city_contracts::{AnchorType, Catalogue};
    use city_core::PlaceIndex;
    use city_core::footprint::world_point;
    use city_core::nav::NavGrid;

    let m = district();
    let index = PlaceIndex::build(&m).unwrap();
    let grid = NavGrid::build(&index);
    let sources: Vec<_> = m
        .city
        .entrances
        .iter()
        .filter_map(|e| grid.snap(*e))
        .collect();
    let reached = grid.reach_from(&sources);
    let placements: Vec<_> = m
        .city
        .districts
        .iter()
        .flat_map(|d| &d.placements)
        .collect();
    for (id, kind_id, room) in THINGS_TO_USE {
        let p = placements
            .iter()
            .find(|p| p.id.as_str() == *id)
            .unwrap_or_else(|| panic!("{id} is placed"));
        assert_eq!(p.kind, *kind_id, "{id}");
        let kind = Catalogue::builtin().kind(kind_id).unwrap();
        assert!(!kind.anchors.is_empty(), "{kind_id} has anchors");
        for a in kind
            .anchors
            .iter()
            .filter(|a| a.kind != AnchorType::Display)
        {
            let cell = grid.cell_of(world_point(p.at, p.facing, a.at));
            assert!(
                grid.walkable(cell),
                "{id}'s {:?} anchor at {cell:?} is walkable",
                a.kind
            );
            let slot = grid.slot(cell).unwrap();
            assert!(
                reached[slot],
                "{id}'s {:?} anchor is reached from an entrance",
                a.kind
            );
            assert_eq!(
                grid.room_at(cell).map(|r| r.as_str()),
                Some(*room),
                "{id}'s {:?} anchor stands in {room}",
                a.kind
            );
        }
    }
    // The meadows are soft ground on the park's lawn, and block nothing.
    let meadows: Vec<_> = placements.iter().filter(|p| p.kind == "meadow").collect();
    assert_eq!(meadows.len(), 3);
    let park = index.rooms[&city_contracts::PlaceId::from("room:park")]
        .rect
        .unwrap();
    for p in meadows {
        let size = p.size.unwrap_or_else(|| panic!("{} is sized", p.id));
        assert!(
            park.x <= p.at.x - size.w / 2
                && p.at.x + size.w / 2 <= park.x + park.w
                && park.z <= p.at.z - size.d / 2
                && p.at.z + size.d / 2 <= park.z + park.d,
            "{} lies on the park's lawn",
            p.id
        );
        assert!(
            index.placed(&p.id).unwrap().placed.shapes.is_empty(),
            "{}",
            p.id
        );
    }
}

#[test]
fn the_districts_displays_show_sample_panels_beside_the_manifest() {
    use city_contracts::Panel;
    use std::collections::BTreeMap;

    let m = district();
    let folder = district_path().parent().unwrap().to_path_buf();
    let mut bound = BTreeMap::new();
    for p in m.city.districts.iter().flat_map(|d| &d.placements) {
        if let Some(b) = &p.binding {
            assert_eq!(b.source, "sample", "{}", p.id);
            bound.insert(p.id.as_str().to_owned(), b.reference.clone());
        }
    }
    let expected: BTreeMap<String, String> = [
        ("placement:square-noticeboard", "panels/square-notices.json"),
        ("placement:guild-hall-plaque", "panels/guild-hall.json"),
        ("placement:reading-shelf-1", "panels/library-shelves.json"),
        ("placement:reading-shelf-2", "panels/library-shelves.json"),
        ("placement:reading-shelf-3", "panels/library-shelves.json"),
    ]
    .into_iter()
    .map(|(a, b)| (a.to_owned(), b.to_owned()))
    .collect();
    assert_eq!(bound, expected);
    for (id, reference) in &bound {
        let text = std::fs::read_to_string(folder.join(reference)).unwrap();
        let panels: BTreeMap<String, Panel> = serde_json::from_str(&text).unwrap();
        let panel = panels
            .get(id)
            .unwrap_or_else(|| panic!("{reference} keys a panel by {id}"));
        let sample = match panel {
            Panel::Notices { sample, .. }
            | Panel::Shelf { sample, .. }
            | Panel::Plaque { sample, .. } => *sample,
        };
        assert!(sample, "{id}'s panel is marked Sample");
    }
    // The Square's notices are the city's own releases, newest first.
    let text = std::fs::read_to_string(folder.join("panels/square-notices.json")).unwrap();
    let panels: BTreeMap<String, Panel> = serde_json::from_str(&text).unwrap();
    let Panel::Notices { items, .. } = &panels["placement:square-noticeboard"] else {
        panic!("the noticeboard carries notices");
    };
    let headlines: Vec<&str> = items.iter().map(|n| &n.headline[..6]).collect();
    assert_eq!(headlines, ["v0.0.3", "v0.0.2", "v0.0.1"]);
    // The shelves' spines are the vision's documents, each one there.
    let text = std::fs::read_to_string(folder.join("panels/library-shelves.json")).unwrap();
    let panels: BTreeMap<String, Panel> = serde_json::from_str(&text).unwrap();
    for panel in panels.values() {
        let Panel::Shelf { spines, .. } = panel else {
            panic!("a shelf carries spines");
        };
        for s in spines {
            assert!(
                folder.join("../../..").join(&s.subtitle).exists(),
                "{} exists",
                s.subtitle
            );
        }
    }
}

/// A snapshot of the one-stop tram street at tick 20: `west:1` stands at
/// `stop:mid` with its doors open, carrying `person:rider` (slot 0),
/// `person:second` (slot 1) and `pa:helper`, `person:owner`'s private agent.
fn tram_snapshot() -> String {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests/fixtures/tram-snapshot.json")
        .display()
        .to_string()
}

const WEST_1: &str = "vehicle:boulevard:west:1";

fn rider_ids(body: &Value) -> Vec<&str> {
    body["riders"]
        .as_array()
        .unwrap()
        .iter()
        .map(|r| r["id"].as_str().unwrap())
        .collect()
}

#[test]
fn inspect_a_vehicle_shows_it_and_the_riders_this_viewer_may_see() {
    let snap = tram_snapshot();
    let (code, body) = city(&["inspect", &snap, "--vehicle", WEST_1]);
    assert_eq!(code, 0, "{body}");
    assert_eq!(
        body.as_object().unwrap().keys().collect::<Vec<_>>(),
        ["riders", "vehicle"]
    );
    assert_eq!(
        body["vehicle"],
        json!({"id": WEST_1, "line": "line:boulevard", "direction": "west",
               "pos": {"x": 1400, "z": 600}, "heading": 270, "along": 1400, "trail": [],
               "status": "standing", "doors_open": true, "stop": "stop:mid"})
    );
    assert_eq!(rider_ids(&body), ["person:rider", "person:second"]);
    let rider = &body["riders"][0];
    assert_eq!(rider["vehicle"], WEST_1);
    assert_eq!(rider["slot"], 0);
    // 30 cm behind the front, half a metre to the left of the way it runs.
    assert_eq!(rider["pos"], json!({"x": 1430, "z": 650}));
    assert_eq!(body["riders"][1]["pos"], json!({"x": 1430, "z": 550}));

    let (code, body) = city(&[
        "inspect",
        &snap,
        "--vehicle",
        WEST_1,
        "--viewer",
        "person:owner",
    ]);
    assert_eq!(code, 0);
    assert_eq!(
        rider_ids(&body),
        ["person:rider", "person:second", "pa:helper"]
    );
    let helper = &body["riders"][2];
    assert_eq!(helper["pos"], json!({"x": 2000, "z": 600}), "at the centre");
    assert!(helper.get("slot").is_none());

    let (code, body) = city(&["inspect", &snap, "--vehicle", "vehicle:boulevard:east:9"]);
    assert_eq!(code, 1);
    assert_eq!(body["error"]["code"], "not-found");
    let (code, _) = city(&[
        "inspect",
        &snap,
        "--vehicle",
        WEST_1,
        "--room",
        "room:north",
    ]);
    assert_eq!(code, 2, "a vehicle or a room, not both");
    let (code, _) = city(&[
        "inspect",
        &snap,
        "--vehicle",
        WEST_1,
        "--occupant",
        "person:rider",
    ]);
    assert_eq!(code, 2, "a vehicle or an occupant, not both");
}

#[test]
fn inspect_lists_vehicles_and_finds_a_rider_by_id() {
    let snap = tram_snapshot();
    let (code, body) = city(&["inspect", &snap]);
    assert_eq!(code, 0, "{body}");
    assert_eq!(body["vehicles"].as_array().unwrap().len(), 1);
    assert_eq!(body["vehicles"][0]["id"], WEST_1);
    let aboard: Vec<&str> = body["aboard"]
        .as_array()
        .unwrap()
        .iter()
        .map(|r| r["id"].as_str().unwrap())
        .collect();
    assert_eq!(aboard, ["person:rider", "person:second"]);
    let (code, body) = city(&["inspect", &snap, "--occupant", "person:second"]);
    assert_eq!(code, 0, "{body}");
    assert_eq!(body["vehicle"], WEST_1);
    let (code, body) = city(&["inspect", &snap, "--occupant", "pa:helper"]);
    assert_eq!(code, 1, "hidden from the public: {body}");
}

#[test]
fn inspect_a_vehicle_is_the_same_library_call() {
    use city_cli::commands::{InspectArgs, inspect};
    let args = InspectArgs {
        snapshot: tram_snapshot().into(),
        viewer: "public".into(),
        operator: false,
        room: None,
        occupant: None,
        vehicle: Some(WEST_1.into()),
    };
    let (code, body) = city(&["inspect", &tram_snapshot(), "--vehicle", WEST_1]);
    let direct = inspect(&args);
    assert_eq!((code, body), (direct.status.exit_code(), direct.body));
    let both = inspect(&InspectArgs {
        room: Some("room:north".into()),
        ..args
    });
    assert_eq!(both.body["error"]["code"], "bad-input");
}

// ---- Catalogue, grid and place ----

/// A four-metre workshop (`room:a`) above an eight-metre plaza (`room:p`),
/// a door both ways, a desk seat in the workshop and one `street-lamp`
/// placement in the plaza: enough of a layout to grid and place things on.
/// The workshop's facility carries a `guild-hall` kind, so its shell (grown
/// outward by the kind's 25 cm wall, less the door's own opening) reaches
/// past the workshop's own floor into the plaza's, along the plaza's row of
/// cells just south of the door: exactly the `grid --png` case where a
/// blocked cell's floor still belongs to a room but is not under any
/// placement's own footprint.
fn layout_manifest() -> Value {
    json!({
        "schema_version": 2,
        "catalogue": 1,
        "catalogue": 1,
        "city": {"id": "city:g", "name": "G", "entrances": [{"x": 0, "z": 600}], "districts": [
            {"id": "district:g", "name": "G", "facilities": [
                {"id": "facility:hall", "name": "Hall", "kind": "guild-hall", "rooms": [
                    {"id": "room:a", "name": "A", "capacity": 2, "template": "workshop",
                     "rect": {"x": 0, "z": 0, "w": 400, "d": 400},
                     "seats": [{"id": "seat:a1", "pos": {"x": 100, "z": 100}, "facing": 0, "kind": "desk"}],
                     "doors": [{"id": "door:a-p", "to": "room:p", "pos": {"x": 200, "z": 400},
                                "transit": {"min": 1, "max": 1}}]}
                ]},
                {"id": "facility:plaza", "name": "Plaza", "rooms": [
                    {"id": "room:p", "name": "P", "capacity": 20, "template": "plaza",
                     "rect": {"x": 0, "z": 400, "w": 800, "d": 400},
                     "doors": [{"id": "door:p-a", "to": "room:a", "pos": {"x": 200, "z": 400},
                                "transit": {"min": 1, "max": 1}}]}
                ]}
            ],
            "placements": [
                {"id": "placement:lamp1", "kind": "street-lamp", "at": {"x": 600, "z": 600}, "facing": 0}
            ]}
        ]}
    })
}

fn layout_path(d: &Path) -> String {
    let m = d.join("layout.json");
    std::fs::write(&m, layout_manifest().to_string()).unwrap();
    m.display().to_string()
}

#[test]
fn catalogue_lists_kinds_and_one_kind() {
    let (code, body) = city(&["catalogue"]);
    assert_eq!(code, 0, "{body}");
    assert_eq!(body["version"], 1);
    let kinds = body["kinds"].as_array().unwrap();
    assert!(kinds.len() > 10, "the built-in catalogue lists many kinds");
    let lamp = kinds.iter().find(|k| k["id"] == "street-lamp").unwrap();
    assert_eq!(lamp["class"], "fixture");
    assert_eq!(lamp["snap"], 25);

    let (code, body) = city(&["catalogue", "--kind", "street-lamp"]);
    assert_eq!(code, 0, "{body}");
    assert_eq!(body["id"], "street-lamp");
    assert_eq!(body["footprint"][0]["r"], 20);

    let (code, body) = city(&["catalogue", "--kind", "no-such-kind"]);
    assert_eq!(code, 1);
    assert_eq!(body["error"]["code"], "not-found");
}

#[test]
fn grid_reports_counts_and_a_dimensioned_png() {
    let d = dir("grid");
    let m = layout_path(&d);
    let (code, body) = city(&["grid", &m]);
    assert_eq!(code, 0, "{body}");
    // 800 x 800 cm at 25 cm cells is 32 x 32.
    assert_eq!(body["cells"], 1024);
    assert!(body["walkable"].as_u64().unwrap() > 0);
    assert_eq!(body["blocked_by_kind"]["desk"], 18);
    assert_eq!(body["blocked_by_kind"]["street-lamp"], 4);

    let png = d.join("grid.png");
    let (code, body) = city(&["grid", &m, "--png", png.to_str().unwrap()]);
    assert_eq!(code, 0, "{body}");
    assert_eq!(body["png"], png.display().to_string());
    let bytes = std::fs::read(&png).unwrap();
    assert_eq!(
        &bytes[0..8],
        &[0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A]
    );
    let width = u32::from_be_bytes(bytes[16..20].try_into().unwrap());
    let height = u32::from_be_bytes(bytes[20..24].try_into().unwrap());
    assert_eq!((width, height), (32, 32), "one pixel per cell");

    // Decode the real PNG the CLI wrote (the encoder's own reader, not a
    // rebuilt classification) and check one cell of every colour, at
    // coordinates worked out from the fixture's geometry and confirmed by
    // running `grid --png` on it:
    //   - (i=4, j=4): the desk seat's own cell (100, 100) -> blue;
    //   - (i=24, j=24): under the street-lamp's footprint (600, 600) -> red;
    //   - (i=8, j=16): the door's span, just south of (200, 400) -> green;
    //   - (i=20, j=20): open plaza floor, away from everything -> white;
    //   - (i=0, j=16): the guild-hall's shell, one row south of the
    //     workshop (z 400-425), west of the door's own opening: the
    //     plaza's own floor, blocked by the shell, not by a placement ->
    //     tinted.
    let (w, _h, pixels) = city_cli::png::decode_rgb8(&bytes);
    let at = |i, j| city_cli::png::pixel_at(w, &pixels, i, j);
    assert_eq!(at(4, 4), city_cli::png::BLUE, "the seat's own cell");
    assert_eq!(at(24, 24), city_cli::png::RED, "the lamp's footprint");
    assert_eq!(at(8, 16), city_cli::png::GREEN, "the door's span");
    assert_eq!(at(20, 20), city_cli::png::WHITE, "open plaza floor");
    assert_eq!(
        at(0, 16),
        city_cli::png::TINT,
        "the shell over the plaza's own floor"
    );
}

#[test]
fn place_validates_refuses_and_writes() {
    let d = dir("place");
    let m = layout_path(&d);

    // A bollard on its snap, clear of the seat, door and lamp: accepted.
    let (code, body) = city(&["place", &m, "--kind", "bollard", "--at", "700,500"]);
    assert_eq!(code, 0, "{body}");
    assert_eq!(body["ok"], true);
    assert!(!body["changed_cells"].as_array().unwrap().is_empty());
    assert!(body.get("written").is_none(), "no --write, no rewrite");

    // Off the fixture's snap (25 cm): refused, non-zero, with the core's
    // reason and the default ID (kind and point, with no --id given).
    let (code, body) = city(&["place", &m, "--kind", "bollard", "--at", "703,500"]);
    assert_eq!(code, 1, "{body}");
    assert_eq!(body["ok"], false);
    assert_eq!(body["reason"]["PlacementInvalid"]["code"], "off-snap");
    assert_eq!(
        body["reason"]["PlacementInvalid"]["place"],
        "placement:bollard-703-500"
    );

    // An unknown kind: refused with `unknown-kind`.
    let (code, body) = city(&["place", &m, "--kind", "no-such-kind", "--at", "700,500"]);
    assert_eq!(code, 1, "{body}");
    assert_eq!(body["reason"]["PlacementInvalid"]["code"], "unknown-kind");

    // --write on a refused placement changes nothing: the manifest stays
    // byte-identical, the process still exits non-zero, and the body still
    // carries the reason, not a "written" path.
    let before = std::fs::read_to_string(&m).unwrap();
    let (code, body) = city(&[
        "place", &m, "--kind", "bollard", "--at", "703,500", "--write",
    ]);
    assert_eq!(code, 1, "{body}");
    assert_eq!(body["ok"], false);
    assert_eq!(body["reason"]["PlacementInvalid"]["code"], "off-snap");
    assert!(
        body.get("written").is_none(),
        "a refused placement is never written"
    );
    assert_eq!(
        std::fs::read_to_string(&m).unwrap(),
        before,
        "--write on a refusal leaves the manifest untouched"
    );

    // --write rewrites the manifest with the placement added, and the
    // result still validates and can be placed on again (round trip).
    let (code, body) = city(&[
        "place",
        &m,
        "--kind",
        "bollard",
        "--at",
        "700,500",
        "--id",
        "placement:post",
        "--write",
    ]);
    assert_eq!(code, 0, "{body}");
    assert_eq!(body["written"], m);
    let written: Value = serde_json::from_str(&std::fs::read_to_string(&m).unwrap()).unwrap();
    let placements = written["city"]["districts"][0]["placements"]
        .as_array()
        .unwrap();
    assert!(placements.iter().any(|p| p["id"] == "placement:post"));
    assert!(placements.iter().any(|p| p["id"] == "placement:lamp1"));
    let (code, body) = city(&["validate", &m]);
    assert_eq!(code, 0, "the rewritten manifest still validates: {body}");

    // Placing the same ID again is refused: it is already in use.
    let (code, body) = city(&[
        "place",
        &m,
        "--kind",
        "bollard",
        "--at",
        "600, 500",
        "--id",
        "placement:post",
    ]);
    assert_eq!(code, 1, "{body}");
    assert_eq!(body["reason"]["PlacementInvalid"]["code"], "duplicate-id");
}

#[test]
fn check_placement_matches_place_without_writing() {
    use city_cli::commands::{CheckPlacementArgs, check_placement};
    let d = dir("check-placement");
    let m = layout_path(&d);
    let before = std::fs::read_to_string(&m).unwrap();

    let (code, body) = city(&["place", &m, "--kind", "bollard", "--at", "700,500"]);
    let placement =
        json!({"id": "placement:bollard-700-500", "kind": "bollard", "at": {"x": 700, "z": 500}});
    let direct = check_placement(&CheckPlacementArgs {
        manifest: m.clone().into(),
        placement: serde_json::from_value(placement).unwrap(),
    });
    assert_eq!(code, direct.status.exit_code());
    assert_eq!(body, direct.body);
    assert_eq!(
        std::fs::read_to_string(&m).unwrap(),
        before,
        "check_placement never writes"
    );
}
