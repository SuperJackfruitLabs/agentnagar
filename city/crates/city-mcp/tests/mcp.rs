//! The MCP server lists the city tools and answers through them exactly as
//! the command line does.

use city_cli::commands::{self, RunArgs};
use rmcp::ServiceExt;
use rmcp::model::{CallToolRequestParams, CallToolResult};
use serde_json::{Value, json};
use std::path::{Path, PathBuf};

fn dir(name: &str) -> PathBuf {
    let d = Path::new(env!("CARGO_TARGET_TMPDIR"))
        .join("mcp")
        .join(name);
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    d
}

fn write_inputs(d: &Path) -> (PathBuf, PathBuf) {
    let manifest = json!({
        "schema_version": 2,
        "catalogue": 1,
        "city": {"id": "city:t", "name": "T", "districts": [
            {"id": "district:d", "name": "D", "facilities": [
                {"id": "facility:hall", "name": "Hall", "rooms": [
                    {"id": "room:work", "name": "Work", "capacity": 2,
                     "seats": [{"id": "seat:w1"}, {"id": "seat:w2"}]}
                ]}
            ]}
        ]},
        "occupants": [
            {"id": "agent:a", "kind": {"type": "GuildAgent"}, "display_name": "A", "work": "room:work"}
        ]
    });
    let feed = concat!(
        r#"{"record":"header","schema_version":1,"source":"fixture:mcp","fixture":true}"#,
        "\n",
        r#"{"record":"entry","at":0,"fixture":true,"command":{"type":"Arrive","occupant":"agent:a"}}"#,
        "\n",
    );
    let m = d.join("manifest.json");
    let f = d.join("feed.jsonl");
    std::fs::write(&m, manifest.to_string()).unwrap();
    std::fs::write(&f, feed).unwrap();
    (m, f)
}

fn text(r: &CallToolResult) -> Value {
    let t = &r.content[0].as_text().expect("text content").text;
    serde_json::from_str(t).expect("tool bodies are JSON")
}

fn args(v: Value) -> CallToolRequestParams {
    CallToolRequestParams::new("placeholder").with_arguments(v.as_object().unwrap().clone())
}

fn call(name: &'static str, v: Value) -> CallToolRequestParams {
    let mut p = args(v);
    p.name = name.into();
    p
}

#[tokio::test]
async fn tools_list_and_call_through_mcp() {
    let (server_io, client_io) = tokio::io::duplex(1 << 20);
    tokio::spawn(async move {
        let server = city_mcp::CityServer::new().serve(server_io).await.unwrap();
        let _ = server.waiting().await;
    });
    let client = ().serve(client_io).await.unwrap();

    let names: Vec<String> = client
        .list_all_tools()
        .await
        .unwrap()
        .into_iter()
        .map(|t| t.name.to_string())
        .collect();
    for n in [
        "validate",
        "run",
        "inspect",
        "diff",
        "schema",
        "catalogue",
        "check_placement",
    ] {
        assert!(names.contains(&n.to_string()), "{n} missing from {names:?}");
    }

    let d = dir("tools");
    let (m, f) = write_inputs(&d);
    let r = client
        .call_tool(call("validate", json!({"manifest_path": m})))
        .await
        .unwrap();
    assert_eq!(r.is_error, Some(false));
    assert_eq!(text(&r)["valid"], true);

    let out = d.join("mcp-out");
    let r = client
        .call_tool(call(
            "run",
            json!({"manifest_path": m, "feed_path": f, "seed": 3,
                                      "ticks": 4, "snapshot_every": 2, "out_dir": out}),
        ))
        .await
        .unwrap();
    assert_eq!(r.is_error, Some(false), "{:?}", r.content);
    let via_cli = commands::run(&RunArgs {
        manifest: m.clone(),
        feed: f.clone(),
        seed: 3,
        ticks: 4,
        snapshot_every: Some(2),
        out: d.join("cli-out"),
        crowd: 0,
    });
    assert_eq!(text(&r), via_cli.body, "MCP and CLI must agree");
    assert_eq!(
        std::fs::read(out.join("events.jsonl")).unwrap(),
        std::fs::read(d.join("cli-out/events.jsonl")).unwrap()
    );

    let snap = out.join("final.json");
    let r = client
        .call_tool(call(
            "inspect",
            json!({"snapshot_path": snap, "viewer": "operator"}),
        ))
        .await
        .unwrap();
    assert_eq!(r.is_error, Some(true));
    assert_eq!(text(&r)["error"]["code"], "operator-flag-required");
    let r = client
        .call_tool(call(
            "inspect",
            json!({"snapshot_path": snap, "viewer": "operator", "operator": true}),
        ))
        .await
        .unwrap();
    assert_eq!(r.is_error, Some(false));
    assert!(text(&r)["rooms"].is_array());
    let r = client
        .call_tool(call(
            "inspect",
            json!({"snapshot_path": snap, "occupant": "agent:a"}),
        ))
        .await
        .unwrap();
    assert_eq!(text(&r)["id"], "agent:a");

    let diff_args = json!({"a_path": out.join("snapshots/tick-000002.json"), "b_path": snap});
    let r = client
        .call_tool(call("diff", diff_args.clone()))
        .await
        .unwrap();
    assert_eq!(r.is_error, Some(true), "diff is full state: operator only");
    assert_eq!(text(&r)["error"]["code"], "operator-flag-required");
    let mut with_flag = diff_args;
    with_flag["operator"] = json!(true);
    let r = client.call_tool(call("diff", with_flag)).await.unwrap();
    assert_eq!(r.is_error, Some(false));
    assert_eq!(text(&r)["to_tick"], 4);

    let r = client.call_tool(call("schema", json!({}))).await.unwrap();
    assert!(text(&r)["projection"].is_object());

    client.cancel().await.unwrap();
}

#[tokio::test]
async fn inspect_takes_a_vehicle_as_the_command_line_does() {
    use city_cli::commands::InspectArgs;
    let (server_io, client_io) = tokio::io::duplex(1 << 20);
    tokio::spawn(async move {
        let server = city_mcp::CityServer::new().serve(server_io).await.unwrap();
        let _ = server.waiting().await;
    });
    let client = ().serve(client_io).await.unwrap();

    let tools = client.list_all_tools().await.unwrap();
    let inspect = tools
        .iter()
        .find(|t| t.name == "inspect")
        .expect("inspect is listed");
    assert!(
        inspect.input_schema["properties"].get("vehicle").is_some(),
        "inspect takes a vehicle: {:?}",
        inspect.input_schema
    );

    // The one-stop tram street at tick 20, west:1 standing with riders.
    let snap =
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../city-cli/tests/fixtures/tram-snapshot.json");
    let vehicle = "vehicle:boulevard:west:1";
    for viewer in ["public", "person:owner"] {
        let r = client
            .call_tool(call(
                "inspect",
                json!({"snapshot_path": snap, "viewer": viewer, "vehicle": vehicle}),
            ))
            .await
            .unwrap();
        assert_eq!(r.is_error, Some(false), "{:?}", r.content);
        let via_cli = commands::inspect(&InspectArgs {
            snapshot: snap.clone(),
            viewer: viewer.into(),
            operator: false,
            room: None,
            occupant: None,
            vehicle: Some(vehicle.into()),
        });
        assert_eq!(text(&r), via_cli.body, "MCP and CLI must agree");
        assert_eq!(text(&r)["vehicle"]["id"], vehicle);
    }
    let r = client
        .call_tool(call(
            "inspect",
            json!({"snapshot_path": snap, "vehicle": "vehicle:boulevard:east:9"}),
        ))
        .await
        .unwrap();
    assert_eq!(r.is_error, Some(true));
    assert_eq!(text(&r)["error"]["code"], "not-found");

    let r = client.call_tool(call("schema", json!({}))).await.unwrap();
    assert!(text(&r)["vehicle-detail"].is_object());

    client.cancel().await.unwrap();
}

/// A four-metre workshop above an eight-metre plaza, a door both ways and a
/// desk seat: the same small layout `city-cli`'s tests grid and place on.
fn layout_manifest_path(d: &Path) -> PathBuf {
    let manifest = json!({
        "schema_version": 2,
        "catalogue": 1,
        "catalogue": 1,
        "city": {"id": "city:g", "name": "G", "entrances": [{"x": 0, "z": 600}], "districts": [
            {"id": "district:g", "name": "G", "facilities": [
                {"id": "facility:hall", "name": "Hall", "rooms": [
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
            ]}
        ]}
    });
    let m = d.join("layout.json");
    std::fs::write(&m, manifest.to_string()).unwrap();
    m
}

#[tokio::test]
async fn catalogue_and_check_placement_match_the_command_line() {
    use city_cli::commands::{CheckPlacementArgs, check_placement};

    let (server_io, client_io) = tokio::io::duplex(1 << 20);
    tokio::spawn(async move {
        let server = city_mcp::CityServer::new().serve(server_io).await.unwrap();
        let _ = server.waiting().await;
    });
    let client = ().serve(client_io).await.unwrap();

    let r = client
        .call_tool(call("catalogue", json!({})))
        .await
        .unwrap();
    assert_eq!(r.is_error, Some(false), "{:?}", r.content);
    let via_cli = commands::catalogue(None);
    assert_eq!(text(&r), via_cli.body, "MCP and CLI must agree");

    let r = client
        .call_tool(call("catalogue", json!({"kind": "street-lamp"})))
        .await
        .unwrap();
    assert_eq!(text(&r)["id"], "street-lamp");

    let d = dir("check-placement");
    let manifest = layout_manifest_path(&d);
    let before = std::fs::read_to_string(&manifest).unwrap();
    let placement = json!({"id": "placement:bollard-700-500", "kind": "bollard",
                            "at": {"x": 700, "z": 500}});

    let r = client
        .call_tool(call(
            "check_placement",
            json!({"manifest_path": manifest, "placement": placement}),
        ))
        .await
        .unwrap();
    assert_eq!(r.is_error, Some(false), "{:?}", r.content);
    assert_eq!(text(&r)["ok"], true);
    let via_cli = check_placement(&CheckPlacementArgs {
        manifest: manifest.clone(),
        placement: serde_json::from_value(placement).unwrap(),
    });
    assert_eq!(text(&r), via_cli.body, "MCP and CLI must agree");
    assert_eq!(
        std::fs::read_to_string(&manifest).unwrap(),
        before,
        "check_placement never writes"
    );

    // Off the fixture's snap: refused, with the core's reason.
    let bad = json!({"id": "placement:bollard-703-500", "kind": "bollard",
                      "at": {"x": 703, "z": 500}});
    let r = client
        .call_tool(call(
            "check_placement",
            json!({"manifest_path": manifest, "placement": bad}),
        ))
        .await
        .unwrap();
    assert_eq!(r.is_error, Some(true));
    assert_eq!(text(&r)["reason"]["PlacementInvalid"]["code"], "off-snap");

    client.cancel().await.unwrap();
}
