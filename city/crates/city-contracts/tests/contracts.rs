use city_contracts::*;
use serde_json::json;

#[test]
fn manifest_round_trips_with_defaults() {
    let json = r#"{
      "schema_version": 2,
      "city": {"id": "city:a", "name": "A", "districts": [
        {"id": "district:d", "name": "D", "facilities": [
          {"id": "facility:f", "name": "F", "rooms": [
            {"id": "room:r", "name": "R", "capacity": 2,
             "seats": [{"id": "seat:1"}, {"id": "seat:2", "reserved_for": "agent:kai"}]}
          ]}
        ]}
      ]},
      "occupants": [{"id": "agent:kai", "kind": {"type": "GuildAgent"}, "display_name": "Kai"}]
    }"#;
    let m: Manifest = serde_json::from_str(json).unwrap();
    assert_eq!(m.seat_policy, SeatPolicyName::DepartmentFirst);
    let room = &m.city.districts[0].facilities[0].rooms[0];
    assert_eq!(room.seats[1].reserved_for, Some(CityId::from("agent:kai")));
    assert!(room.overflow.is_none() && room.doors.is_empty() && room.pods.is_empty());
    let back: Manifest = serde_json::from_str(&serde_json::to_string(&m).unwrap()).unwrap();
    assert_eq!(back, m);
}

#[test]
fn personal_agent_kind_carries_owner() {
    let k: OccupantKind =
        serde_json::from_str(r#"{"type":"PersonalAgent","owner":"person:asha"}"#).unwrap();
    assert_eq!(
        k,
        OccupantKind::PersonalAgent {
            owner: CityId::from("person:asha")
        }
    );
}

#[test]
fn feed_records_are_tagged() {
    let h: FeedRecord = serde_json::from_str(
        r#"{"record":"header","schema_version":1,"source":"fixture:t","fixture":true}"#,
    )
    .unwrap();
    assert!(matches!(
        h,
        FeedRecord::Header(FeedHeader { fixture: true, .. })
    ));
    let e: FeedRecord = serde_json::from_str(
        r#"{"record":"entry","at":3,"fixture":true,
            "command":{"type":"Observe","occupant":"agent:kai",
              "observation":{"dimension":"Task","value":{"state":"Working"},
                "stamp":{"observed_at":3,"fetched_at":3,"expires_at":9,"source":"s","source_version":"1"}}}}"#,
    )
    .unwrap();
    let FeedRecord::Entry(entry) = e else {
        panic!("entry")
    };
    assert_eq!(entry.command.command_type(), CommandType::Observe);
}

#[test]
fn shown_presence_defaults_to_unknown() {
    let s = ShownPresence::default();
    assert_eq!(s.headline, Headline::Unknown);
    assert_eq!(s.task, ShownTask::Unknown);
}

#[test]
fn every_contract_exports_a_schema() {
    let schemas = all_schemas();
    for name in [
        "catalogue",
        "manifest",
        "feed-record",
        "command",
        "event",
        "snapshot",
        "viewer",
        "projection",
        "snapshot-diff",
        "validation-report",
        "run-summary",
        "vehicle-detail",
    ] {
        let s = schemas
            .get(name)
            .unwrap_or_else(|| panic!("missing {name}"));
        assert!(s.get("$schema").is_some(), "{name} is not a schema");
    }
}

#[test]
fn layout_fields_are_optional_and_round_trip() {
    let old = r#"{"id":"room:r","name":"R","capacity":2}"#;
    let r: Room = serde_json::from_str(old).unwrap();
    assert!(r.rect.is_none() && r.template.is_none());
    let new = r#"{"id":"room:r","name":"R","capacity":2,"template":"workshop",
        "rect":{"x":0,"z":0,"w":400,"d":300}}"#;
    let r: Room = serde_json::from_str(new).unwrap();
    assert_eq!(
        r.rect,
        Some(Rect {
            x: 0,
            z: 0,
            w: 400,
            d: 300
        })
    );
    assert_eq!(
        serde_json::from_str::<Room>(&serde_json::to_string(&r).unwrap()).unwrap(),
        r
    );
}

#[test]
fn old_room_serialises_without_layout_keys() {
    let r: Room = serde_json::from_str(r#"{"id":"room:r","name":"R","capacity":2}"#).unwrap();
    let v = serde_json::to_value(&r).unwrap();
    for k in ["rect", "template"] {
        assert!(v.get(k).is_none(), "{k} should be omitted");
    }
}

#[test]
fn old_projection_shape_is_unchanged_without_layout() {
    let o = OccupantView {
        id: "a:1".into(),
        kind: OccupantKind::GuildAgent,
        display_name: "A".into(),
        role: String::new(),
        badge: None,
        appearance: Default::default(),
        seat: None,
        presence: ShownPresence::default(),
        task_summary: None,
        pos: None,
        facing: 0,
        moving: false,
        path_ahead: vec![],
        trail: vec![],
        queue: None,
        vehicle: None,
        slot: None,
        waiting_for: None,
        using: None,
    };
    let v = serde_json::to_value(&o).unwrap();
    for k in [
        "pos",
        "path_ahead",
        "queue",
        "facing",
        "moving",
        "vehicle",
        "slot",
        "waiting_for",
        "using",
    ] {
        assert!(v.get(k).is_none(), "{k} should be omitted");
    }
}

#[test]
fn leaving_location_walks_and_clock_serialise() {
    let l: Location = serde_json::from_str(r#"{"state":"Leaving","from":"room:a"}"#).unwrap();
    assert_eq!(
        l,
        Location::Leaving {
            from: Some("room:a".into())
        }
    );
    let w = Walk {
        path: vec![Point { x: 1, z: 2 }],
        purpose: WalkPurpose::ToDoor {
            target: "room:a".into(),
        },
        blocked: 0,
    };
    assert_eq!(
        serde_json::from_str::<Walk>(&serde_json::to_string(&w).unwrap()).unwrap(),
        w
    );
    let m: Manifest = serde_json::from_str(
        r#"{"schema_version":2,"city":{"id":"c","name":"C","districts":[],"entrances":[{"x":0,"z":5}]},
            "clock":{"ticks_per_day":600,"start_minute":420}}"#,
    )
    .unwrap();
    assert_eq!(
        m.clock,
        Some(Clock {
            ticks_per_day: 600,
            start_minute: 420
        })
    );
    assert_eq!(m.city.entrances, vec![Point { x: 0, z: 5 }]);
    assert!(!m.has_layout());
    assert_eq!(
        serde_json::from_str::<RejectReason>("\"Unreachable\"").unwrap(),
        RejectReason::Unreachable
    );
}

#[test]
fn scenery_kinds_round_trip() {
    let json = r#"[
      {"kind":"water","rect":{"x":0,"z":0,"w":10,"d":10}},
      {"kind":"bridge","from":{"x":0,"z":0},"to":{"x":100,"z":0},"width":40},
      {"kind":"street","points":[{"x":0,"z":0},{"x":50,"z":0}],"width":60},
      {"kind":"fence","points":[{"x":0,"z":0},{"x":50,"z":0}]}
    ]"#;
    let s: Vec<Scenery> = serde_json::from_str(json).unwrap();
    assert_eq!(s.len(), 4);
    let back: Vec<Scenery> = serde_json::from_str(&serde_json::to_string(&s).unwrap()).unwrap();
    assert_eq!(back, s);
}

#[test]
fn scenery_no_longer_accepts_tree_rows_or_blocks() {
    // Schema 2 lays tree rows out as tree placements and blocks as sized
    // block placements.
    for item in [
        r#"{"kind":"tree-row","points":[{"x":0,"z":0},{"x":50,"z":0}],"spacing":600}"#,
        r#"{"kind":"block","rect":{"x":0,"z":0,"w":10,"d":10},"height_class":"tower"}"#,
    ] {
        assert!(serde_json::from_str::<Scenery>(item).is_err(), "{item}");
    }
}

#[test]
fn the_manifest_schema_version_is_two() {
    assert_eq!(MANIFEST_SCHEMA_VERSION, 2);
}

#[test]
fn shells_and_outdoor_are_optional() {
    let f: Facility = serde_json::from_str(
        r#"{"id":"facility:f","name":"F","rooms":[],"roof":"sawtooth","storeys":2}"#,
    )
    .unwrap();
    assert_eq!((f.roof, f.storeys), (Some(Roof::Sawtooth), Some(2)));
    let r: Room =
        serde_json::from_str(r#"{"id":"room:r","name":"R","capacity":1,"outdoor":true}"#).unwrap();
    assert!(r.outdoor);
    let old: Room = serde_json::from_str(r#"{"id":"room:r","name":"R","capacity":1}"#).unwrap();
    assert!(!old.outdoor);
    let v = serde_json::to_value(&old).unwrap();
    assert!(v.get("outdoor").is_none());
    let m: Manifest =
        serde_json::from_str(r#"{"schema_version":2,"city":{"id":"c","name":"C","districts":[]}}"#)
            .unwrap();
    assert!(m.scenery.is_empty() && serde_json::to_value(&m).unwrap().get("scenery").is_none());
}

#[test]
fn go_and_steer_round_trip_with_their_types() {
    let go: Command = serde_json::from_str(
        r#"{"type":"Go","occupant":"person:you","to":{"type":"Point","pos":{"x":100,"z":250}}}"#,
    )
    .unwrap();
    assert_eq!(
        go,
        Command::Go {
            occupant: "person:you".into(),
            to: Target::Point {
                pos: Point { x: 100, z: 250 }
            },
        }
    );
    assert_eq!(go.command_type(), CommandType::Go);
    assert_eq!(go.occupant().map(|o| o.as_str()), Some("person:you"));
    for to in [
        Target::Seat {
            seat: "seat:w1".into(),
        },
        Target::Room {
            room: "room:work".into(),
        },
    ] {
        let c = Command::Go {
            occupant: "person:you".into(),
            to,
        };
        let back: Command = serde_json::from_str(&serde_json::to_string(&c).unwrap()).unwrap();
        assert_eq!(back, c);
    }
    let seat: Target = serde_json::from_str(r#"{"type":"Seat","seat":"seat:w1"}"#).unwrap();
    assert_eq!(
        seat,
        Target::Seat {
            seat: "seat:w1".into()
        }
    );

    let steer: Command = serde_json::from_str(
        r#"{"type":"Steer","occupant":"person:you","cells":[{"x":12,"z":12},{"x":37,"z":12}]}"#,
    )
    .unwrap();
    assert_eq!(steer.command_type(), CommandType::Steer);
    assert_eq!(steer.occupant().map(|o| o.as_str()), Some("person:you"));
    let Command::Steer { cells, .. } = &steer else {
        panic!("steer")
    };
    assert_eq!(cells.len(), 2);
    assert_eq!(
        serde_json::from_str::<Command>(&serde_json::to_string(&steer).unwrap()).unwrap(),
        steer
    );
    for (text, reason) in [
        ("\"SeatTaken\"", RejectReason::SeatTaken),
        ("\"NotYourSeat\"", RejectReason::NotYourSeat),
        ("\"BlockedStep\"", RejectReason::BlockedStep),
        ("\"Seat\"", RejectReason::Seat),
        (
            r#"{"RoomFull":{"room":"room:workshop"}}"#,
            RejectReason::RoomFull {
                room: "room:workshop".into(),
            },
        ),
    ] {
        assert_eq!(serde_json::from_str::<RejectReason>(text).unwrap(), reason);
        assert_eq!(
            serde_json::from_str::<serde_json::Value>(text).unwrap(),
            serde_json::to_value(&reason).unwrap()
        );
    }
    for (text, kind) in [
        ("\"Go\"", CommandType::Go),
        ("\"Steer\"", CommandType::Steer),
    ] {
        assert_eq!(serde_json::from_str::<CommandType>(text).unwrap(), kind);
    }
    let schema = all_schemas()["command"].to_string();
    assert!(schema.contains("Steer") && schema.contains("Seat"));
}

#[test]
fn occupant_goal_is_optional_and_omitted_when_absent() {
    let state = serde_json::json!({
        "profile": {"id": "person:you", "kind": {"type": "Human", "tier": "Registered"}, "display_name": "You"},
        "location": {"state": "Away"},
        "presence": PresenceRecord::default(),
        "shown": ShownPresence::default(),
    });
    let mut o: OccupantState = serde_json::from_value(state).unwrap();
    assert_eq!(o.goal, None);
    assert!(serde_json::to_value(&o).unwrap().get("goal").is_none());
    o.goal = Some(Target::Point {
        pos: Point { x: 1, z: 2 },
    });
    let v = serde_json::to_value(&o).unwrap();
    assert_eq!(v["goal"]["type"], "Point");
    assert_eq!(serde_json::from_value::<OccupantState>(v).unwrap(), o);
}

#[test]
fn a_facility_category_round_trips_and_is_optional() {
    let with: Facility =
        serde_json::from_str(r#"{"id":"facility:w","name":"W","rooms":[],"category":"workshop"}"#)
            .unwrap();
    assert_eq!(with.category, Some(Category::Workshop));
    let back = serde_json::to_value(&with).unwrap();
    assert_eq!(back["category"], "workshop");
    let without: Facility =
        serde_json::from_str(r#"{"id":"facility:w","name":"W","rooms":[]}"#).unwrap();
    assert_eq!(without.category, None);
    assert!(
        serde_json::to_value(&without)
            .unwrap()
            .get("category")
            .is_none()
    );
}

#[test]
fn the_manifest_schema_names_the_four_categories() {
    let s = serde_json::to_string(&all_schemas()["manifest"]).unwrap();
    for c in ["workshop", "library", "transit", "park"] {
        assert!(s.contains(c), "{c} missing from the schema");
    }
}

#[test]
fn a_kind_round_trips_with_every_field() {
    let json = r#"{
      "id": "guild-hall", "name": "Guild hall", "description": "Where the makers work.",
      "class": "building",
      "footprint": [{"x": -800, "z": -800, "w": 1600, "d": 1600}],
      "soft": [{"x": 0, "z": 0, "r": 40}],
      "sized": false, "snap": 100,
      "anchors": [{"type": "enter", "at": {"x": 0, "z": -800}, "facing": 0, "height": 220}],
      "capabilities": [{"name": "open", "at": "enter"}],
      "state": [{"name": "lit", "type": "bool", "default": true}],
      "height": 500, "wall": 25, "door_width": 200
    }"#;
    let k: Kind = serde_json::from_str(json).unwrap();
    assert_eq!(k.class, Class::Building);
    assert_eq!(k.wall, Some(25));
    assert_eq!(k.door_width, Some(200));
    assert_eq!(k.width, None);
    assert_eq!(
        k.footprint[0],
        Shape::Rect {
            x: -800,
            z: -800,
            w: 1600,
            d: 1600
        }
    );
    assert_eq!(k.soft[0], Shape::Disc { x: 0, z: 0, r: 40 });
    assert_eq!(k.anchors[0].kind, AnchorType::Enter);
    assert_eq!(k.anchors[0].height, Some(220));
    assert_eq!(
        k.capabilities[0],
        Capability {
            name: "open".into(),
            at: Some(AnchorType::Enter),
        }
    );
    assert_eq!(k.state[0].ty, StateType::Bool);
    assert_eq!(k.state[0].default, serde_json::json!(true));
    let back: Kind = serde_json::from_str(&serde_json::to_string(&k).unwrap()).unwrap();
    assert_eq!(back, k);
    let v = serde_json::to_value(&k).unwrap();
    assert_eq!(v["anchors"][0]["type"], "enter");
    assert_eq!(v["state"][0]["type"], "bool");
}

#[test]
fn a_catalogue_round_trips_as_json() {
    let json = r#"{
      "version": 1,
      "kinds": [
        {"id": "desk", "name": "Desk", "description": "A workbench desk.", "class": "seat",
         "footprint": [{"x": -50, "z": -80, "w": 100, "d": 60}], "sized": false, "snap": 1,
         "anchors": [{"type": "sit", "at": {"x": 0, "z": 0}, "facing": 0}],
         "capabilities": [{"name": "sit", "at": "sit"}], "height": 75},
        {"id": "tram", "name": "Tram", "description": "A three-car tram.", "class": "vehicle",
         "sized": false, "snap": 25, "height": 450, "width": 250}
      ]
    }"#;
    let c: Catalogue = serde_json::from_str(json).unwrap();
    assert_eq!(c.version, 1);
    assert_eq!(c.kind("desk").unwrap().class, Class::Seat);
    assert_eq!(c.kind("tram").unwrap().width, Some(250));
    assert!(c.kind("missing").is_none());
    let back: Catalogue = serde_json::from_str(&serde_json::to_string(&c).unwrap()).unwrap();
    assert_eq!(back, c);
}

#[test]
fn the_builtin_catalogue_has_no_issues() {
    let catalogue = Catalogue::builtin();
    assert_eq!(catalogue.version, 1);
    assert!(!catalogue.kinds.is_empty());
    assert_eq!(catalogue.issues(), Vec::<String>::new());
    assert!(catalogue.kind("desk").is_some());
    assert!(catalogue.kind("tram").is_some());
}

#[test]
fn only_inspect_may_name_no_anchor() {
    let kind = |capabilities: serde_json::Value| -> Kind {
        serde_json::from_value(json!({
            "id": "thing", "name": "Thing", "description": "A thing.", "class": "fixture",
            "snap": 25, "height": 100,
            "anchors": [{"type": "stand", "at": {"x": 0, "z": 50}, "facing": 180}],
            "capabilities": capabilities
        }))
        .unwrap()
    };
    let k = kind(json!([{"name": "inspect"}]));
    assert_eq!(k.capabilities[0].at, None);
    assert_eq!(k.issues(), Vec::<String>::new());
    // None is left out when written, as it was read.
    let written = serde_json::to_value(&k).unwrap();
    assert_eq!(written["capabilities"], json!([{"name": "inspect"}]));
    assert_eq!(serde_json::from_value::<Kind>(written).unwrap(), k);

    assert!(
        kind(json!([{"name": "inspect", "at": "stand"}]))
            .issues()
            .is_empty()
    );
    let issues = kind(json!([{"name": "read"}])).issues();
    assert_eq!(issues.len(), 1, "{issues:?}");
    assert!(
        issues[0].contains("only inspect may name none"),
        "{issues:?}"
    );
    let issues = kind(json!([{"name": "read", "at": "display"}])).issues();
    assert_eq!(issues.len(), 1, "an anchor type the kind lacks: {issues:?}");
    let issues = kind(json!([{"name": "juggle", "at": "stand"}])).issues();
    assert_eq!(issues.len(), 1, "an unknown name: {issues:?}");
}

#[test]
fn a_catalogue_refuses_a_kind_listed_twice_and_a_sized_kind_with_anchors() {
    let mut c = Catalogue::builtin().clone();
    let mut wall = c.kind("low-wall").unwrap().clone();
    wall.sized = true;
    c.kinds.push(wall);
    let issues = c.issues();
    assert_eq!(issues.len(), 2, "{issues:?}");
    assert!(issues[0].contains("listed twice"), "{issues:?}");
    assert!(issues[1].contains("sized and has anchors"), "{issues:?}");
}

#[test]
fn every_kind_offers_inspect_last_at_a_stand_anchor_or_none() {
    for kind in &Catalogue::builtin().kinds {
        let inspect: Vec<_> = kind
            .capabilities
            .iter()
            .filter(|c| c.name == "inspect")
            .collect();
        assert_eq!(inspect.len(), 1, "{} offers inspect once", kind.id);
        assert_eq!(
            kind.capabilities.last().unwrap().name,
            "inspect",
            "{}: inspect is last",
            kind.id
        );
        let has_stand = kind.anchors.iter().any(|a| a.kind == AnchorType::Stand);
        let expected = has_stand.then_some(AnchorType::Stand);
        assert_eq!(inspect[0].at, expected, "{}", kind.id);
        assert!(
            !kind.name.is_empty() && !kind.description.is_empty(),
            "{}",
            kind.id
        );
    }
}

/// The anchor types of `kind`, in order, and its capabilities as
/// (name, anchor type).
fn anchors_and_capabilities(kind: &Kind) -> (Vec<AnchorType>, Vec<(&str, Option<AnchorType>)>) {
    (
        kind.anchors.iter().map(|a| a.kind).collect(),
        kind.capabilities
            .iter()
            .map(|c| (c.name.as_str(), c.at))
            .collect(),
    )
}

#[test]
fn the_displays_are_read_at_their_display_and_stood_at_in_front() {
    use AnchorType::{Display, Stand};
    let catalogue = Catalogue::builtin();
    for id in ["noticeboard", "plaque", "kiosk", "bookshelf"] {
        let kind = catalogue.kind(id).unwrap_or_else(|| panic!("{id}"));
        let (anchors, capabilities) = anchors_and_capabilities(kind);
        assert_eq!(anchors, [Display, Stand], "{id}");
        assert_eq!(
            capabilities,
            [("read", Some(Display)), ("inspect", Some(Stand))],
            "{id}"
        );
        let (display, stand) = (&kind.anchors[0], &kind.anchors[1]);
        assert!(display.size.is_some(), "{id}'s surface has a size");
        // The surface faces north in the kind's frame, the way a placement
        // faces (its normal, the display's facing), and the stand anchor is
        // in front of it, where the reader faces the other way, towards it.
        assert_eq!(display.facing, 0, "{id}'s surface faces the kind's front");
        assert!(stand.at.z < display.at.z, "{id} is stood at in front");
        assert_eq!(stand.at.x, display.at.x, "{id}");
        assert_eq!(stand.facing, 180, "{id}'s reader faces it");
        // The stand anchor's cell (its centre within 13 cm of the anchor) is
        // clear of the footprint grown by the body clearance, so it is
        // walkable wherever the kind stands.
        for shape in &kind.footprint {
            if let Shape::Rect { z, .. } = *shape {
                assert!(stand.at.z + 14 < z - 10, "{id}: stand clear of {shape:?}");
            }
        }
    }
}

#[test]
fn a_workstation_is_a_desk_sat_at_and_used_at_one_place() {
    use AnchorType::{Display, Sit, Stand, Use};
    let catalogue = Catalogue::builtin();
    let kind = catalogue.kind("workstation").expect("a workstation kind");
    let desk = catalogue.kind("desk").unwrap();
    assert_eq!(
        kind.class,
        Class::Seat,
        "a room's seat, under the seat rules"
    );
    assert_eq!(kind.footprint, desk.footprint, "a desk's footprint");
    assert_eq!(kind.height, 75);
    assert_eq!(
        (kind.name.as_str(), kind.description.as_str()),
        ("Workstation", "A desk with a computer on it.")
    );
    let (anchors, capabilities) = anchors_and_capabilities(kind);
    assert_eq!(anchors, [Sit, Use, Display, Stand]);
    // The client's verbs follow this order: "Use computer" first, then
    // "Sit"; "Look at screen" only from behind the chair; Inspect last.
    assert_eq!(
        capabilities,
        [
            ("use", Some(Use)),
            ("sit", Some(Sit)),
            ("watch", Some(Stand)),
            ("inspect", Some(Stand))
        ]
    );
    let [sit, using, display, stand] = [0, 1, 2, 3].map(|k| kind.anchors[k]);
    // Sitting and using are one place, facing the monitor.
    assert_eq!((sit.at, sit.facing), (Point { x: 0, z: 0 }, 0));
    assert_eq!((using.at, using.facing), (sit.at, sit.facing));
    // The monitor stands on the desk's far edge, its screen facing the
    // chair; one looks over the shoulder from 60 cm behind the chair.
    let Shape::Rect { z: far, .. } = kind.footprint[0] else {
        panic!("a desk's top is a rect");
    };
    assert_eq!((display.at, display.facing), (Point { x: 0, z: far }, 180));
    assert!(display.size.is_some(), "the screen has a size");
    assert_eq!((stand.at, stand.facing), (Point { x: 0, z: 60 }, 0));
}

#[test]
fn the_perches_are_sat_on_outside_their_solid_part() {
    let catalogue = Catalogue::builtin();
    for (id, seats) in [("steps", 3), ("low-wall", 5), ("fountain-rim", 8)] {
        let kind = catalogue.kind(id).unwrap_or_else(|| panic!("{id}"));
        let (anchors, capabilities) = anchors_and_capabilities(kind);
        assert_eq!(anchors, vec![AnchorType::Sit; seats], "{id}");
        assert_eq!(
            capabilities,
            [("sit", Some(AnchorType::Sit)), ("inspect", None)],
            "{id}"
        );
        assert!(!kind.sized, "{id} is a fixed module");
        assert_eq!(kind.class, Class::Fixture, "{id} is no room seat");
        // A sitter's cell (its centre within 13 cm of the anchor, and a
        // centimetre more once turned) stays clear of the footprint grown
        // by the body clearance.
        for a in &kind.anchors {
            for shape in &kind.footprint {
                let (x, z) = (a.at.x, a.at.z);
                let clear = match *shape {
                    Shape::Rect { x: rx, z: rz, w, d } => {
                        let dx = (rx - x).max(x - (rx + w)).max(0);
                        let dz = (rz - z).max(z - (rz + d)).max(0);
                        dx.max(dz) >= 10 + 14
                    }
                    Shape::Disc { x: cx, z: cz, r } => {
                        let (dx, dz) = (i64::from(x - cx), i64::from(z - cz));
                        dx * dx + dz * dz >= i64::from(r + 10 + 14).pow(2)
                    }
                };
                assert!(clear, "{id}: the sit anchor at {:?} is in {shape:?}", a.at);
            }
        }
    }
    let wall = catalogue.kind("low-wall").unwrap();
    let xs: Vec<i32> = wall.anchors.iter().map(|a| a.at.x).collect();
    assert_eq!(xs, [-120, -60, 0, 60, 120], "every 60 cm along the wall");
    let rim = catalogue.kind("fountain-rim").unwrap();
    let facings: Vec<i32> = rim.anchors.iter().map(|a| a.facing).collect();
    assert_eq!(
        facings,
        [0, 45, 90, 135, 180, 225, 270, 315],
        "even angles, facing out"
    );
}

#[test]
fn a_meadow_is_sized_soft_ground() {
    let meadow = Catalogue::builtin().kind("meadow").unwrap();
    assert!(meadow.footprint.is_empty());
    assert!(!meadow.soft.is_empty());
    assert!(meadow.sized && meadow.sized_soft());
    assert_eq!(meadow.capabilities.len(), 1);
    assert_eq!(meadow.capabilities[0].name, "inspect");
    let block = Catalogue::builtin().kind("block-house").unwrap();
    assert!(block.sized && !block.sized_soft(), "a block's lot is solid");
}

fn boulevard() -> Line {
    Line {
        id: "line:boulevard".into(),
        name: "Boulevard tram".into(),
        mode: LineMode::Tram,
        points: vec![Point { x: -2000, z: 2050 }, Point { x: 6000, z: 2050 }],
        tracks: [-150, 150],
        stops: vec![
            Stop {
                id: "stop:square".into(),
                name: "Square".into(),
                at: 2000,
                platforms: ["room:tram-stop".into(), "room:tram-stop-south".into()],
            },
            Stop {
                id: "stop:avenue".into(),
                name: "Avenue".into(),
                at: 6500,
                platforms: [
                    "room:avenue-stop-north".into(),
                    "room:avenue-stop-south".into(),
                ],
            },
        ],
        timetable: Timetable {
            headway: 30,
            offset: [0, 15],
            speed: 28,
            dwell: 12,
        },
        vehicle: VehicleSpec {
            capacity: 40,
            length: 2400,
            doors: vec![400, 1200, 2000],
            kind: None,
        },
    }
}

#[test]
fn a_line_round_trips_as_json() {
    let line = boulevard();
    let v = serde_json::to_value(&line).unwrap();
    assert_eq!(v["mode"], "tram");
    assert_eq!(v["tracks"], serde_json::json!([-150, 150]));
    assert!(
        v["vehicle"].get("kind").is_none(),
        "a line with no vehicle kind runs trams and writes none"
    );
    let mut named = line.clone();
    named.vehicle.kind = Some("tram".into());
    let text = serde_json::to_string(&named).unwrap();
    assert_eq!(serde_json::from_str::<Line>(&text).unwrap(), named);
    assert_eq!(v["stops"][0]["platforms"][1], "room:tram-stop-south");
    assert_eq!(v["timetable"]["offset"], serde_json::json!([0, 15]));
    assert_eq!(serde_json::from_value::<Line>(v).unwrap(), line);
    for (text, mode) in [
        ("\"tram\"", LineMode::Tram),
        ("\"bus\"", LineMode::Bus),
        ("\"ferry\"", LineMode::Ferry),
    ] {
        assert_eq!(serde_json::from_str::<LineMode>(text).unwrap(), mode);
    }
}

#[test]
fn a_manifest_without_lines_or_arrivals_parses_and_omits_them() {
    let m: Manifest =
        serde_json::from_str(r#"{"schema_version":2,"city":{"id":"c","name":"C","districts":[]}}"#)
            .unwrap();
    assert!(m.lines.is_empty());
    assert_eq!(m.city.arrivals, Arrivals::Direct);
    let v = serde_json::to_value(&m).unwrap();
    assert!(v.get("lines").is_none());
    assert!(v["city"].get("arrivals").is_none());

    let mut with = m.clone();
    with.lines = vec![boulevard()];
    with.city.arrivals = Arrivals::Tram;
    let v = serde_json::to_value(&with).unwrap();
    assert_eq!(v["lines"][0]["id"], "line:boulevard");
    assert_eq!(v["city"]["arrivals"], "tram");
    assert_eq!(serde_json::from_value::<Manifest>(v).unwrap(), with);
    let direct: City =
        serde_json::from_str(r#"{"id":"c","name":"C","districts":[],"arrivals":"direct"}"#)
            .unwrap();
    assert_eq!(direct.arrivals, Arrivals::Direct);
}

#[test]
fn board_and_alight_round_trip_with_their_types() {
    for (json, kind) in [
        (
            r#"{"type":"Board","occupant":"person:you"}"#,
            CommandType::Board,
        ),
        (
            r#"{"type":"Alight","occupant":"person:you"}"#,
            CommandType::Alight,
        ),
    ] {
        let c: Command = serde_json::from_str(json).unwrap();
        assert_eq!(c.command_type(), kind);
        assert_eq!(c.occupant().map(|o| o.as_str()), Some("person:you"));
        assert_eq!(
            serde_json::from_str::<Command>(&serde_json::to_string(&c).unwrap()).unwrap(),
            c
        );
    }
    assert_eq!(
        serde_json::from_str::<CommandType>("\"Board\"").unwrap(),
        CommandType::Board
    );
}

#[test]
fn the_schemas_name_the_transit_contracts() {
    let schemas = all_schemas();
    let text = |name: &str| serde_json::to_string(&schemas[name]).unwrap();
    let manifest = text("manifest");
    for word in ["\"lines\"", "\"tram\"", "\"arrivals\""] {
        assert!(manifest.contains(word), "{word} missing from the manifest");
    }
    assert!(text("event").contains("\"Boarded\""));
    assert!(text("projection").contains("\"aboard\""));
    for (name, defs) in [
        (
            "manifest",
            &[
                "Line",
                "LineMode",
                "Stop",
                "Timetable",
                "VehicleSpec",
                "Arrivals",
            ][..],
        ),
        (
            "snapshot",
            &["VehicleState", "VehicleStatus", "Direction"][..],
        ),
        ("projection", &["VehicleView", "PlatformWait"][..]),
        ("vehicle-detail", &["VehicleView", "OccupantView"][..]),
    ] {
        for def in defs {
            assert!(
                schemas[name]["$defs"].get(*def).is_some(),
                "{def} missing from the {name} schema"
            );
        }
    }
    let command = text("command");
    assert!(command.contains("\"Board\"") && command.contains("\"Alight\""));
}

#[test]
fn the_old_tram_line_scenery_kind_is_rejected() {
    let err = serde_json::from_str::<Scenery>(
        r#"{"kind":"tram-line","points":[{"x":0,"z":0},{"x":50,"z":0}]}"#,
    )
    .unwrap_err()
    .to_string();
    assert!(
        err.contains("unknown variant `tram-line`"),
        "unclear error: {err}"
    );
}

#[test]
fn vehicles_riders_and_platform_waiters_round_trip() {
    let vehicle = VehicleState {
        id: "vehicle:boulevard:east:1".into(),
        line: "line:boulevard".into(),
        direction: Direction::East,
        along: 2000,
        status: VehicleStatus::Standing {
            stop: "stop:square".into(),
            doors_open_until: 42,
        },
        riders: vec!["person:you".into()],
        trail: vec![1300, 2000],
    };
    let v = serde_json::to_value(&vehicle).unwrap();
    assert_eq!(v["direction"], "east");
    assert_eq!(v["trail"], json!([1300, 2000]));
    let still = VehicleState {
        trail: vec![],
        ..vehicle.clone()
    };
    let v = serde_json::to_value(&still).unwrap();
    assert!(v.get("trail").is_none(), "a still vehicle omits its trail");
    assert_eq!(serde_json::from_value::<VehicleState>(v).unwrap(), still);
    let v = serde_json::to_value(&vehicle).unwrap();
    assert_eq!(v["status"]["type"], "Standing");
    assert_eq!(serde_json::from_value::<VehicleState>(v).unwrap(), vehicle);
    assert_eq!(Direction::East.index(), 0);
    assert_eq!(Direction::West.index(), 1);

    for location in [
        Location::WaitingFor {
            stop: "stop:square".into(),
            direction: Some(Direction::West),
        },
        Location::WaitingFor {
            stop: "stop:square".into(),
            direction: None,
        },
        Location::Aboard {
            vehicle: "vehicle:boulevard:east:1".into(),
            slot: 3,
        },
    ] {
        let back: Location =
            serde_json::from_str(&serde_json::to_string(&location).unwrap()).unwrap();
        assert_eq!(back, location);
    }
    let waiting: Location =
        serde_json::from_str(r#"{"state":"WaitingFor","stop":"stop:square"}"#).unwrap();
    assert_eq!(
        waiting,
        Location::WaitingFor {
            stop: "stop:square".into(),
            direction: None
        }
    );
    let purpose = WalkPurpose::ToPlatform {
        stop: "stop:avenue".into(),
    };
    assert_eq!(
        serde_json::from_str::<WalkPurpose>(&serde_json::to_string(&purpose).unwrap()).unwrap(),
        purpose
    );
}

#[test]
fn a_snapshot_without_vehicles_omits_them() {
    let s = Snapshot {
        schema_version: 1,
        tick: 0,
        seed: 1,
        fixture: true,
        manifest: serde_json::from_str(
            r#"{"schema_version":2,"city":{"id":"c","name":"C","districts":[]}}"#,
        )
        .unwrap(),
        occupants: Default::default(),
        rooms: Default::default(),
        admission_queue: vec![],
        next_seq: 0,
        vehicles: vec![],
        grid_changes: vec![],
    };
    let v = serde_json::to_value(&s).unwrap();
    assert!(v.get("vehicles").is_none());
    assert!(v.get("grid_changes").is_none());
    assert_eq!(serde_json::from_value::<Snapshot>(v).unwrap(), s);
}

#[test]
fn transit_events_and_reasons_round_trip() {
    let vehicle = CityId::from("vehicle:boulevard:west:2");
    let stop = PlaceId::from("stop:avenue");
    for kind in [
        EventKind::VehicleEntered {
            vehicle: vehicle.clone(),
        },
        EventKind::VehicleHeld {
            vehicle: vehicle.clone(),
        },
        EventKind::DoorsOpened {
            vehicle: vehicle.clone(),
            stop: stop.clone(),
        },
        EventKind::DoorsClosed {
            vehicle: vehicle.clone(),
            stop: stop.clone(),
        },
        EventKind::VehicleLeft {
            vehicle: vehicle.clone(),
        },
        EventKind::Boarded {
            vehicle: vehicle.clone(),
        },
        EventKind::Alighted {
            vehicle: vehicle.clone(),
            stop: stop.clone(),
        },
        EventKind::LeftBehind {
            stop: stop.clone(),
            vehicle: vehicle.clone(),
        },
        EventKind::SteppedAside {
            from: Point { x: 2012, z: 212 },
            to: Point { x: 2012, z: 187 },
        },
        EventKind::Departed {
            from: None,
            via: Some(vehicle.clone()),
        },
    ] {
        let back: EventKind = serde_json::from_str(&serde_json::to_string(&kind).unwrap()).unwrap();
        assert_eq!(back, kind);
    }
    let plain = EventKind::Departed {
        from: Some("room:a".into()),
        via: None,
    };
    assert_eq!(
        serde_json::to_string(&plain).unwrap(),
        r#"{"type":"Departed","from":"room:a"}"#
    );
    assert_eq!(
        serde_json::from_str::<EventKind>(r#"{"type":"Departed","from":"room:a"}"#).unwrap(),
        plain
    );
    for (text, reason) in [
        ("\"NotOnPlatform\"", RejectReason::NotOnPlatform),
        ("\"VehicleFull\"", RejectReason::VehicleFull),
        ("\"NotYourDirection\"", RejectReason::NotYourDirection),
        ("\"NotStanding\"", RejectReason::NotStanding),
        ("\"NotAboard\"", RejectReason::NotAboard),
    ] {
        assert_eq!(serde_json::from_str::<RejectReason>(text).unwrap(), reason);
    }
}

#[test]
fn a_players_depart_says_so_and_anyone_elses_omits_it() {
    let plain: Command =
        serde_json::from_str(r#"{"type":"Depart","occupant":"person:a"}"#).unwrap();
    assert_eq!(
        plain,
        Command::Depart {
            occupant: "person:a".into(),
            player: false
        }
    );
    assert_eq!(
        serde_json::to_string(&plain).unwrap(),
        r#"{"type":"Depart","occupant":"person:a"}"#
    );
    let player = Command::Depart {
        occupant: "person:you".into(),
        player: true,
    };
    let text = serde_json::to_string(&player).unwrap();
    assert_eq!(
        text,
        r#"{"type":"Depart","occupant":"person:you","player":true}"#
    );
    assert_eq!(serde_json::from_str::<Command>(&text).unwrap(), player);
}

#[test]
fn vehicle_views_and_riders_serialise() {
    let view = VehicleView {
        id: "vehicle:boulevard:east:1".into(),
        line: "line:boulevard".into(),
        direction: Direction::East,
        pos: Point { x: 400, z: 1900 },
        heading: 90,
        along: 2400,
        trail: vec![2372, 2400],
        status: "running".into(),
        doors_open: false,
        stop: None,
    };
    let v = serde_json::to_value(&view).unwrap();
    assert_eq!(v["direction"], "east");
    assert_eq!(serde_json::from_value::<VehicleView>(v).unwrap(), view);

    let projection = Projection {
        schema_version: 1,
        tick: 1,
        fixture: true,
        viewer: Viewer::Public,
        rooms: vec![],
        in_transit: vec![],
        time_of_day: None,
        rain: None,
        vehicles: vec![],
        aboard: vec![],
        grid_changes: vec![],
    };
    let v = serde_json::to_value(&projection).unwrap();
    assert!(v.get("vehicles").is_none() && v.get("aboard").is_none());
    assert!(v.get("grid_changes").is_none());
    let old: Projection = serde_json::from_str(
        r#"{"schema_version":1,"tick":1,"fixture":true,"viewer":{"type":"Public"},"rooms":[],"in_transit":[]}"#,
    )
    .unwrap();
    assert_eq!(old, projection);
}

#[test]
fn a_platform_waiter_and_a_vehicle_detail_serialise() {
    let wait = PlatformWait {
        stop: "stop:square".into(),
        direction: Some(Direction::West),
    };
    let v = serde_json::to_value(&wait).unwrap();
    assert_eq!(v, json!({"stop": "stop:square", "direction": "west"}));
    assert_eq!(serde_json::from_value::<PlatformWait>(v).unwrap(), wait);

    let detail = VehicleDetail {
        vehicle: VehicleView {
            id: "vehicle:boulevard:west:1".into(),
            line: "line:boulevard".into(),
            direction: Direction::West,
            pos: Point { x: 1400, z: 500 },
            heading: 270,
            along: 1400,
            trail: vec![],
            status: "standing".into(),
            doors_open: true,
            stop: Some("stop:mid".into()),
        },
        riders: vec![],
    };
    let v = serde_json::to_value(&detail).unwrap();
    assert_eq!(v["vehicle"]["status"], "standing");
    assert_eq!(v["riders"], json!([]));
    assert_eq!(serde_json::from_value::<VehicleDetail>(v).unwrap(), detail);
}

#[test]
fn placement_commands_round_trip_and_name_only_a_player_who_sent_one() {
    let place: Command = serde_json::from_value(json!({
        "type": "Place",
        "placement": {"id": "placement:bench-1", "kind": "bench", "at": {"x": 500, "z": 600}}
    }))
    .unwrap();
    assert_eq!(place.command_type(), CommandType::Place);
    assert_eq!(place.occupant(), None, "an operator's command names no one");
    let moved: Command = serde_json::from_value(json!({
        "type": "MovePlacement", "id": "placement:bench-1", "at": {"x": 300, "z": 650},
        "facing": 90, "by": "person:you"
    }))
    .unwrap();
    assert_eq!(moved.command_type(), CommandType::MovePlacement);
    assert_eq!(moved.occupant().map(|o| o.as_str()), Some("person:you"));
    let removed: Command =
        serde_json::from_value(json!({"type": "RemovePlacement", "id": "placement:bench-1"}))
            .unwrap();
    assert_eq!(removed.command_type(), CommandType::RemovePlacement);
    for c in [place, moved, removed] {
        let v = serde_json::to_value(&c).unwrap();
        assert_eq!(serde_json::from_value::<Command>(v.clone()).unwrap(), c);
        if c.occupant().is_none() {
            assert!(v.get("by").is_none(), "no `by` is written for an operator");
        }
    }
}

#[test]
fn placement_events_reasons_and_grid_changes_round_trip() {
    let kind = EventKind::PlacementChanged {
        id: "placement:bench-1".into(),
        change: PlacementChange::Moved,
    };
    let v = serde_json::to_value(&kind).unwrap();
    assert_eq!(
        v,
        json!({"type": "PlacementChanged", "id": "placement:bench-1", "change": "Moved"})
    );
    assert_eq!(serde_json::from_value::<EventKind>(v).unwrap(), kind);
    for reason in [
        RejectReason::NotOperator,
        RejectReason::UnknownPlacement,
        RejectReason::PlacementInvalid {
            code: "off-snap".into(),
            place: "placement:bench-1".into(),
        },
        RejectReason::PlacementCoversOccupant,
        RejectReason::PlacementDisconnects,
    ] {
        let v = serde_json::to_value(&reason).unwrap();
        assert_eq!(serde_json::from_value::<RejectReason>(v).unwrap(), reason);
    }
    assert_eq!(
        serde_json::to_value(RejectReason::PlacementInvalid {
            code: "off-snap".into(),
            place: "placement:bench-1".into(),
        })
        .unwrap(),
        json!({"PlacementInvalid": {"code": "off-snap", "place": "placement:bench-1"}}),
        "the refusal names the issue and the placement"
    );
    assert_eq!(
        serde_json::to_value(RejectReason::NotOperator).unwrap(),
        json!("NotOperator")
    );
    let change = GridChange {
        i: 4,
        j: 7,
        walkable: false,
        room: None,
    };
    let v = serde_json::to_value(change).unwrap();
    assert_eq!(v, json!({"i": 4, "j": 7, "walkable": false}));
    assert_eq!(serde_json::from_value::<GridChange>(v).unwrap(), change);
    let opened = GridChange {
        i: 4,
        j: 7,
        walkable: true,
        room: Some(3),
    };
    let v = serde_json::to_value(opened).unwrap();
    assert_eq!(
        v,
        json!({"i": 4, "j": 7, "walkable": true, "room": 3}),
        "a cell that opens names the room whose floor it is"
    );
    assert_eq!(serde_json::from_value::<GridChange>(v).unwrap(), opened);
}

#[test]
fn trees_and_palms_take_their_trunks_and_the_great_tree_its_roots() {
    // Foliage stands above the walking band, so a planted tree takes only
    // the ground its trunk stands on, 25 cm round: no cell centre of a
    // 25 cm-snapped tree's grid lies within the body clearance of it but
    // the four round its point. The great tree's roots spread in the
    // band, so they are its footprint.
    let catalogue = Catalogue::builtin();
    let footprint = |id: &str| catalogue.kind(id).unwrap().footprint.clone();
    assert_eq!(
        footprint("street-tree"),
        [Shape::Disc { x: 0, z: 0, r: 25 }]
    );
    assert_eq!(footprint("palm"), [Shape::Disc { x: 0, z: 0, r: 25 }]);
    assert_eq!(
        footprint("great-tree"),
        [Shape::Rect {
            x: -260,
            z: -255,
            w: 520,
            d: 510
        }]
    );
}

#[test]
fn flower_beds_take_their_bed_and_paths_nothing() {
    // Every style draws a bed's kerb and flowers in the walking band, and
    // people walk round it; a path is flat.
    let catalogue = Catalogue::builtin();
    assert_eq!(
        catalogue.kind("flowerbed").unwrap().footprint,
        [Shape::Rect {
            x: -155,
            z: -55,
            w: 310,
            d: 110
        }]
    );
    assert!(catalogue.kind("path").unwrap().footprint.is_empty());
}

#[test]
fn use_and_stop_using_round_trip_with_their_type() {
    let using: Command = serde_json::from_value(json!({
        "type": "Use",
        "occupant": "person:you",
        "target": "placement:bench-1",
        "capability": "sit",
        "anchor": 0
    }))
    .unwrap();
    assert_eq!(
        using,
        Command::Use {
            occupant: "person:you".into(),
            target: "placement:bench-1".into(),
            capability: "sit".into(),
            anchor: 0,
        }
    );
    assert_eq!(using.command_type(), CommandType::Use);
    assert_eq!(using.occupant().map(|o| o.as_str()), Some("person:you"));
    assert_eq!(
        serde_json::from_str::<Command>(&serde_json::to_string(&using).unwrap()).unwrap(),
        using
    );

    let stop: Command =
        serde_json::from_value(json!({"type": "StopUsing", "occupant": "person:you"})).unwrap();
    assert_eq!(
        stop,
        Command::StopUsing {
            occupant: "person:you".into(),
        }
    );
    assert_eq!(stop.command_type(), CommandType::StopUsing);
    assert_eq!(stop.occupant().map(|o| o.as_str()), Some("person:you"));
    assert_eq!(
        serde_json::from_str::<Command>(&serde_json::to_string(&stop).unwrap()).unwrap(),
        stop
    );

    for (text, kind) in [
        ("\"Use\"", CommandType::Use),
        ("\"StopUsing\"", CommandType::StopUsing),
    ] {
        assert_eq!(serde_json::from_str::<CommandType>(text).unwrap(), kind);
    }
}

#[test]
fn using_events_and_reasons_round_trip() {
    let kind = EventKind::Using {
        target: "placement:desk-1".into(),
        capability: "use".into(),
        anchor: 2,
    };
    let v = serde_json::to_value(&kind).unwrap();
    assert_eq!(
        v,
        json!({"type": "Using", "target": "placement:desk-1", "capability": "use", "anchor": 2})
    );
    assert_eq!(serde_json::from_value::<EventKind>(v).unwrap(), kind);

    let stopped = EventKind::StoppedUsing {
        target: "placement:desk-1".into(),
    };
    let v = serde_json::to_value(&stopped).unwrap();
    assert_eq!(
        v,
        json!({"type": "StoppedUsing", "target": "placement:desk-1"})
    );
    assert_eq!(serde_json::from_value::<EventKind>(v).unwrap(), stopped);

    for (text, reason) in [
        ("\"UnknownTarget\"", RejectReason::UnknownTarget),
        ("\"NoSuchCapability\"", RejectReason::NoSuchCapability),
        ("\"AnchorTaken\"", RejectReason::AnchorTaken),
        ("\"NotAtAnchor\"", RejectReason::NotAtAnchor),
    ] {
        assert_eq!(serde_json::from_str::<RejectReason>(text).unwrap(), reason);
        assert_eq!(
            serde_json::to_value(&reason).unwrap(),
            serde_json::from_str::<serde_json::Value>(text).unwrap()
        );
    }
}

#[test]
fn an_occupant_views_using_is_skipped_when_none_and_round_trips_when_set() {
    let base = json!({
        "id": "a:1", "kind": {"type": "GuildAgent"}, "display_name": "A", "role": "",
        "appearance": {}, "seat": null, "presence": ShownPresence::default(),
    });
    let without: OccupantView = serde_json::from_value(base.clone()).unwrap();
    assert_eq!(without.using, None);
    assert!(
        serde_json::to_value(&without)
            .unwrap()
            .get("using")
            .is_none(),
        "using should be omitted when none"
    );

    let with = OccupantView {
        using: Some(Using {
            target: "placement:desk-1".into(),
            capability: "use".into(),
            anchor: 0,
        }),
        ..without.clone()
    };
    let v = serde_json::to_value(&with).unwrap();
    assert_eq!(
        v["using"],
        json!({"target": "placement:desk-1", "capability": "use", "anchor": 0})
    );
    assert_eq!(serde_json::from_value::<OccupantView>(v).unwrap(), with);
}

#[test]
fn sample_panels_round_trip_with_their_sample_flag() {
    let notices = Panel::Notices {
        title: "Square noticeboard".into(),
        items: vec![Notice {
            date: "v0.0.1".into(),
            headline: "The Square opens".into(),
            body: "The city's first release.".into(),
        }],
        sample: true,
    };
    let v = serde_json::to_value(&notices).unwrap();
    assert_eq!(v["type"], "Notices");
    assert_eq!(v["items"][0]["headline"], "The Square opens");
    assert_eq!(v["sample"], true);
    assert_eq!(serde_json::from_value::<Panel>(v).unwrap(), notices);

    let shelf = Panel::Shelf {
        title: "Reading room".into(),
        spines: vec![Spine {
            title: "Vision".into(),
            subtitle: "What the city is for".into(),
        }],
        sample: true,
    };
    let v = serde_json::to_value(&shelf).unwrap();
    assert_eq!(v["type"], "Shelf");
    assert_eq!(v["spines"][0]["subtitle"], "What the city is for");
    assert_eq!(serde_json::from_value::<Panel>(v).unwrap(), shelf);

    let plaque = Panel::Plaque {
        title: "Founding plaque".into(),
        text: "Built by Super Jackfruit Labs.".into(),
        sample: true,
    };
    let v = serde_json::to_value(&plaque).unwrap();
    assert_eq!(v["type"], "Plaque");
    assert_eq!(serde_json::from_value::<Panel>(v).unwrap(), plaque);

    for panel in [notices, shelf, plaque] {
        let back: Panel = serde_json::from_str(&serde_json::to_string(&panel).unwrap()).unwrap();
        assert_eq!(back, panel);
    }
}

#[test]
fn the_schemas_name_use_using_and_panel_and_old_commands_are_unchanged() {
    let schemas = all_schemas();
    assert!(
        schemas.contains_key("panel"),
        "panel is missing from all_schemas"
    );
    let command = serde_json::to_string(&schemas["command"]).unwrap();
    for word in ["\"Use\"", "\"StopUsing\""] {
        assert!(
            command.contains(word),
            "{word} missing from the command schema"
        );
    }
    // Old commands still export unchanged: still named in the schema, and
    // an old feed line still parses and round-trips, unaffected by the new
    // variants.
    for word in [
        "\"Arrive\"",
        "\"Depart\"",
        "\"Move\"",
        "\"Observe\"",
        "\"Share\"",
        "\"Unshare\"",
        "\"Go\"",
        "\"Steer\"",
        "\"Board\"",
        "\"Alight\"",
        "\"Place\"",
        "\"MovePlacement\"",
        "\"RemovePlacement\"",
    ] {
        assert!(
            command.contains(word),
            "{word} missing from the command schema"
        );
    }
    let old: Command = serde_json::from_str(r#"{"type":"Depart","occupant":"person:a"}"#).unwrap();
    assert_eq!(
        old,
        Command::Depart {
            occupant: "person:a".into(),
            player: false,
        }
    );

    let projection = serde_json::to_string(&schemas["projection"]).unwrap();
    assert!(
        projection.contains("\"using\""),
        "using missing from the projection schema"
    );
    assert!(
        schemas["projection"]["$defs"].get("Using").is_some(),
        "Using missing from the projection schema's defs"
    );

    let event = serde_json::to_string(&schemas["event"]).unwrap();
    for word in ["\"Using\"", "\"StoppedUsing\""] {
        assert!(event.contains(word), "{word} missing from the event schema");
    }
    let panel = serde_json::to_string(&schemas["panel"]).unwrap();
    for word in ["\"Notices\"", "\"Shelf\"", "\"Plaque\"", "\"sample\""] {
        assert!(panel.contains(word), "{word} missing from the panel schema");
    }
}
