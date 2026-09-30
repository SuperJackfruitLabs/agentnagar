//! One function per operation. Each returns an [`Outcome`]: a JSON body and
//! a status that maps to the process exit code.

use city_contracts::{
    Catalogue, CityId, Command, Event, EventKind, FeedHeader, GridChange, Location, Manifest,
    PlaceId, Placement, Point, RejectReason, RunSummary, SCHEMA_VERSION, Size, Snapshot,
    ValidationIssue, ValidationReport, VehicleDetail, Viewer, all_schemas,
};
use city_core::footprint::MARGIN;
use city_core::index::unparsed_schema_issue;
use city_core::nav::{CELL, Cell};
use city_core::{Feed, World, parse_feed, project, validate as validate_manifest};
use serde::Serialize;
use serde_json::{Value, json};
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    /// The operation succeeded.
    Ok,
    /// The input was understood but the answer is no: an invalid manifest,
    /// something not found, a refused request.
    Failed,
    /// The input could not be used: unreadable, unparsable or contradictory.
    BadInput,
}

impl Status {
    pub fn exit_code(self) -> i32 {
        match self {
            Status::Ok => 0,
            Status::Failed => 1,
            Status::BadInput => 2,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct Outcome {
    pub status: Status,
    pub body: Value,
}

impl Outcome {
    fn ok(body: impl Serialize) -> Outcome {
        Outcome {
            status: Status::Ok,
            body: serde_json::to_value(body).expect("contracts serialise"),
        }
    }

    fn error(status: Status, code: &str, message: impl Into<String>) -> Outcome {
        Outcome {
            status,
            body: json!({"error": {"code": code, "message": message.into()}}),
        }
    }
}

fn read(path: &Path) -> Result<String, Outcome> {
    fs::read_to_string(path).map_err(|e| {
        Outcome::error(
            Status::BadInput,
            "bad-input",
            format!("cannot read {}: {e}", path.display()),
        )
    })
}

fn read_json<T: serde::de::DeserializeOwned>(path: &Path, what: &str) -> Result<T, Outcome> {
    let text = read(path)?;
    serde_json::from_str(&text).map_err(|e| {
        Outcome::error(
            Status::BadInput,
            "bad-input",
            format!("{} is not a valid {what}: {e}", path.display()),
        )
    })
}

/// A manifest file, or why it cannot be one: its `schema-version` issue
/// when it does not parse and names another version (a schema 1
/// manifest's tree rows and blocks no longer parse), else bad input.
fn load_manifest(path: &Path) -> Result<Manifest, Result<ValidationIssue, Outcome>> {
    let text = read(path).map_err(Err)?;
    serde_json::from_str(&text).map_err(|e| match unparsed_schema_issue(&text) {
        Some(issue) => Ok(issue),
        None => Err(Outcome::error(
            Status::BadInput,
            "bad-input",
            format!("{} is not a valid manifest: {e}", path.display()),
        )),
    })
}

/// A manifest file, refused as `invalid-manifest` for its schema version
/// when it is another's.
fn read_manifest(path: &Path) -> Result<Manifest, Outcome> {
    load_manifest(path).map_err(|e| e.map_or_else(|o| o, |issue| invalid_manifest(vec![issue])))
}

fn write(path: &Path, contents: &str) -> Result<(), Outcome> {
    write_bytes(path, contents.as_bytes())
}

fn write_bytes(path: &Path, contents: &[u8]) -> Result<(), Outcome> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| io_error(parent, e))?;
    }
    fs::write(path, contents).map_err(|e| io_error(path, e))
}

fn io_error(path: &Path, e: std::io::Error) -> Outcome {
    Outcome::error(
        Status::BadInput,
        "io-error",
        format!("cannot write {}: {e}", path.display()),
    )
}

fn pretty(v: &impl Serialize) -> String {
    let mut s = serde_json::to_string_pretty(v).expect("contracts serialise");
    s.push('\n');
    s
}

/// Checks a manifest against its structural rules.
pub fn validate(manifest: &Path) -> Outcome {
    let report = match load_manifest(manifest) {
        Ok(m) => validate_manifest(&m),
        Err(Ok(issue)) => ValidationReport {
            valid: false,
            issues: vec![issue],
        },
        Err(Err(o)) => return o,
    };
    let mut out = Outcome::ok(&report);
    if !report.valid {
        out.status = Status::Failed;
    }
    out
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RunArgs {
    pub manifest: PathBuf,
    pub feed: PathBuf,
    pub seed: u64,
    pub ticks: u64,
    pub snapshot_every: Option<u64>,
    pub out: PathBuf,
    /// Adds a generated fixture crowd of this many occupants (layout only).
    pub crowd: u32,
}

/// Runs a world headless and writes, inside `out` only: `events.jsonl`,
/// `snapshots/tick-NNNNNN.json` every K ticks if asked, `final.json` and
/// `summary.json`.
pub fn run(a: &RunArgs) -> Outcome {
    match run_inner(a) {
        Ok(o) | Err(o) => o,
    }
}

fn run_inner(a: &RunArgs) -> Result<Outcome, Outcome> {
    if a.ticks == 0 {
        return Err(Outcome::error(
            Status::BadInput,
            "bad-input",
            "ticks must be at least 1",
        ));
    }
    if a.snapshot_every == Some(0) {
        return Err(Outcome::error(
            Status::BadInput,
            "bad-input",
            "snapshot-every must be at least 1",
        ));
    }
    let manifest = read_manifest(&a.manifest)?;
    let mut feed = parse_feed(&read(&a.feed)?).map_err(|e| {
        Outcome::error(
            Status::BadInput,
            "bad-feed",
            format!("{}: {e}", a.feed.display()),
        )
    })?;
    if a.crowd > 0 {
        let crowd = city_core::crowd(&manifest, a.crowd, a.seed)
            .map_err(|e| Outcome::error(Status::Failed, "crowd-needs-layout", e))?;
        feed = city_core::merge(feed, crowd)
            .map_err(|e| Outcome::error(Status::BadInput, "bad-feed", e))?;
    }
    let mut world = World::new(manifest, feed, a.seed).map_err(|issues| Outcome {
        status: Status::Failed,
        body: json!({"error": {"code": "invalid-manifest",
            "message": "the manifest failed validation"}, "issues": issues}),
    })?;

    let mut log = String::new();
    let mut events = 0u64;
    let mut rejected = 0u64;
    let mut snapshots = Vec::new();
    let mut record = |batch: Vec<Event>, log: &mut String| {
        for e in batch {
            events += 1;
            if matches!(e.kind, EventKind::Rejected { .. }) {
                rejected += 1;
            }
            log.push_str(&serde_json::to_string(&e).expect("events serialise"));
            log.push('\n');
        }
    };
    for _ in 0..a.ticks {
        let batch = world.step();
        record(batch, &mut log);
        let tick = world.snapshot().tick;
        if a.snapshot_every.is_some_and(|k| tick % k == 0) {
            let rel = format!("snapshots/tick-{tick:06}.json");
            write(&a.out.join(&rel), &pretty(world.snapshot()))?;
            snapshots.push(rel);
        }
    }
    let snapshot = world.snapshot();
    let present = snapshot
        .occupants
        .values()
        .filter(|o| !matches!(o.location, Location::Away))
        .count() as u64;
    let summary = RunSummary {
        schema_version: SCHEMA_VERSION,
        seed: a.seed,
        ticks: a.ticks,
        fixture: snapshot.fixture,
        events,
        rejected,
        present,
        snapshots,
    };
    write(&a.out.join("events.jsonl"), &log)?;
    write(&a.out.join("final.json"), &pretty(snapshot))?;
    write(&a.out.join("summary.json"), &pretty(&summary))?;
    Ok(Outcome::ok(&summary))
}

/// Reads `public`, `operator`, or otherwise a person's city ID.
pub fn parse_viewer(s: &str) -> Viewer {
    match s {
        "public" => Viewer::Public,
        "operator" => Viewer::Operator,
        id => Viewer::Person { id: id.into() },
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InspectArgs {
    pub snapshot: PathBuf,
    pub viewer: String,
    /// Required to use the operator viewer.
    pub operator: bool,
    pub room: Option<String>,
    pub occupant: Option<String>,
    pub vehicle: Option<String>,
}

/// A viewer's projection of a snapshot, or one room, occupant or vehicle in
/// it. A vehicle comes with the riders aboard it this viewer may see, as a
/// [`VehicleDetail`]. A hidden occupant and a missing one give the same
/// `not-found`.
pub fn inspect(a: &InspectArgs) -> Outcome {
    let chosen = [&a.room, &a.occupant, &a.vehicle]
        .iter()
        .filter(|c| c.is_some())
        .count();
    if chosen > 1 {
        return Outcome::error(
            Status::BadInput,
            "bad-input",
            "choose one of a room, an occupant or a vehicle",
        );
    }
    let viewer = parse_viewer(&a.viewer);
    if viewer == Viewer::Operator && !a.operator {
        return operator_required();
    }
    let snapshot: Snapshot = match read_json(&a.snapshot, "snapshot") {
        Ok(s) => s,
        Err(o) => return o,
    };
    let p = project(&snapshot, &viewer);
    if let Some(room) = &a.room {
        let id = PlaceId::from(room.as_str());
        return match p.rooms.iter().find(|r| r.id == id) {
            Some(r) => Outcome::ok(r),
            None => Outcome::error(Status::Failed, "not-found", format!("no room {room}")),
        };
    }
    if let Some(occupant) = &a.occupant {
        let id = CityId::from(occupant.as_str());
        let found = p
            .rooms
            .iter()
            .flat_map(|r| r.occupants.iter().chain(&r.waiting))
            .chain(&p.in_transit)
            .chain(&p.aboard)
            .find(|o| o.id == id);
        return match found {
            Some(o) => Outcome::ok(o),
            None => Outcome::error(
                Status::Failed,
                "not-found",
                format!("no occupant {occupant} in this view"),
            ),
        };
    }
    if let Some(vehicle) = &a.vehicle {
        let id = CityId::from(vehicle.as_str());
        let Some(shown) = p.vehicles.iter().find(|v| v.id == id) else {
            return Outcome::error(Status::Failed, "not-found", format!("no vehicle {vehicle}"));
        };
        return Outcome::ok(VehicleDetail {
            vehicle: shown.clone(),
            riders: p
                .aboard
                .iter()
                .filter(|o| o.vehicle.as_ref() == Some(&id))
                .cloned()
                .collect(),
        });
    }
    Outcome::ok(&p)
}

fn operator_required() -> Outcome {
    Outcome::error(
        Status::Failed,
        "operator-flag-required",
        "this is a diagnostic view of full state; pass the operator flag to use it",
    )
}

/// What changed between two snapshots. Snapshots hold full state, so this is
/// an operator view and needs the operator flag.
pub fn diff(a: &Path, b: &Path, operator: bool) -> Outcome {
    if !operator {
        return operator_required();
    }
    let sa: Snapshot = match read_json(a, "snapshot") {
        Ok(s) => s,
        Err(o) => return o,
    };
    let sb: Snapshot = match read_json(b, "snapshot") {
        Ok(s) => s,
        Err(o) => return o,
    };
    Outcome::ok(city_core::diff(&sa, &sb))
}

/// JSON Schema for every contract; with `out`, also written as
/// `<name>.schema.json` files.
pub fn schema(out: Option<&Path>) -> Outcome {
    let schemas = all_schemas();
    let Some(dir) = out else {
        return Outcome::ok(&schemas);
    };
    let mut written = Vec::new();
    for (name, s) in &schemas {
        let file = format!("{name}.schema.json");
        if let Err(o) = write(&dir.join(&file), &pretty(s)) {
            return o;
        }
        written.push(file);
    }
    Outcome::ok(json!({ "written": written }))
}

// ---- Catalogue ----

/// Every kind as a table (`id`, `name`, `class`, `snap`, `height`), or, with
/// `kind`, that one kind's full JSON.
pub fn catalogue(kind: Option<&str>) -> Outcome {
    let cat = Catalogue::builtin();
    let Some(id) = kind else {
        let table: Vec<Value> = cat
            .kinds
            .iter()
            .map(|k| {
                json!({
                    "id": k.id,
                    "name": k.name,
                    "class": k.class,
                    "snap": k.snap,
                    "height": k.height,
                })
            })
            .collect();
        return Outcome::ok(json!({"version": cat.version, "kinds": table}));
    };
    match cat.kind(id) {
        Some(k) => Outcome::ok(k),
        None => Outcome::error(Status::Failed, "not-found", format!("no kind {id}")),
    }
}

// ---- Grid ----

pub struct GridArgs {
    pub manifest: PathBuf,
    /// Also render the walkable grid, 1 px per cell, to this PNG file.
    pub png: Option<PathBuf>,
}

/// A fixture-free feed for an operation that only loads a manifest and asks
/// the world one question: no occupant ever arrives.
fn empty_feed(source: &str) -> Feed {
    Feed {
        header: FeedHeader {
            schema_version: SCHEMA_VERSION,
            source: source.into(),
            fixture: false,
            description: String::new(),
        },
        entries: Vec::new(),
    }
}

fn invalid_manifest(issues: Vec<ValidationIssue>) -> Outcome {
    Outcome {
        status: Status::Failed,
        body: json!({"error": {"code": "invalid-manifest",
            "message": "the manifest failed validation"}, "issues": issues}),
    }
}

/// The grid's cell count, walkable count, and the cells each catalogue kind
/// blocks (a placement's footprint, or a seat's furniture), grown by the
/// body clearance. With `png`, also renders the grid: walkable white, a
/// blocked room cell tinted, a placement's footprint red, a door span
/// green, a seat's own cell blue.
pub fn grid(a: &GridArgs) -> Outcome {
    match grid_inner(a) {
        Ok(o) | Err(o) => o,
    }
}

fn grid_inner(a: &GridArgs) -> Result<Outcome, Outcome> {
    let manifest = read_manifest(&a.manifest)?;
    let world = World::new(manifest, empty_feed("city-cli:grid"), 0).map_err(invalid_manifest)?;
    let Some(grid) = world.nav() else {
        return Err(Outcome::error(
            Status::Failed,
            "no-layout",
            "the manifest has no layout to grid",
        ));
    };
    let extent = grid.extent();
    let cols = extent.w / CELL;
    let rows = extent.d / CELL;
    let cells = cols as usize * rows as usize;
    let walkable: usize = grid.room_cell_counts().values().sum();

    let index = world.index();
    let mut by_kind: BTreeMap<&str, BTreeSet<Cell>> = BTreeMap::new();
    for info in index.placements.iter().chain(&index.seat_furniture) {
        let blocked_here = by_kind.entry(info.kind.id.as_str()).or_default();
        for c in grid.cells_under(&info.placed, MARGIN) {
            if !grid.walkable(c) {
                blocked_here.insert(c);
            }
        }
    }
    let blocked_by_kind: serde_json::Map<String, Value> = by_kind
        .iter()
        .map(|(k, cells)| (k.to_string(), json!(cells.len())))
        .collect();
    let mut body = json!({
        "cells": cells,
        "walkable": walkable,
        "blocked_by_kind": Value::Object(blocked_by_kind),
    });

    if let Some(path) = &a.png {
        let blocked: BTreeSet<Cell> = by_kind.values().flatten().copied().collect();
        let png = crate::png::render(grid, &blocked, cols, rows);
        write_bytes(path, &png)?;
        body["png"] = json!(path.display().to_string());
    }
    Ok(Outcome::ok(body))
}

// ---- Placements ----

/// What trying a placement command found: whether it was carried out, its
/// refusal reason otherwise, the cells it changed (from the tick's
/// `grid_changes`), and the manifest as the world now holds it (with the
/// placement recorded, when it was carried out).
struct PlacementTry {
    ok: bool,
    reason: Option<RejectReason>,
    changed_cells: Vec<GridChange>,
    manifest: Manifest,
}

/// Loads `manifest` into a world, submits `placement` as the operator
/// (`by: None`), and steps once: the same path a runtime placement change
/// takes, so the CLI, MCP and the world agree on every refusal.
fn attempt_placement(manifest: Manifest, placement: Placement) -> Result<PlacementTry, Outcome> {
    let mut world =
        World::new(manifest, empty_feed("city-cli:place"), 0).map_err(invalid_manifest)?;
    world.submit(Command::Place {
        placement,
        by: None,
    });
    let events = world.step();
    let mut ok = false;
    let mut reason = None;
    for e in &events {
        match &e.kind {
            EventKind::PlacementChanged { .. } => ok = true,
            EventKind::Rejected {
                reason: r,
                command: city_contracts::CommandType::Place,
            } => reason = Some(r.clone()),
            _ => {}
        }
    }
    let changed_cells = if ok {
        world.snapshot().grid_changes.clone()
    } else {
        Vec::new()
    };
    Ok(PlacementTry {
        ok,
        reason,
        changed_cells,
        manifest: world.snapshot().manifest.clone(),
    })
}

fn placement_body(result: &PlacementTry) -> Value {
    let mut body = json!({
        "ok": result.ok,
        "changed_cells": result.changed_cells,
    });
    if let Some(reason) = &result.reason {
        body["reason"] = serde_json::to_value(reason).expect("a reject reason serialises");
    }
    body
}

fn parse_point(what: &str, s: &str) -> Result<Point, Outcome> {
    let bad = || {
        Outcome::error(
            Status::BadInput,
            "bad-input",
            format!("{what} must be \"x,z\", got {s:?}"),
        )
    };
    let (x, z) = s.split_once(',').ok_or_else(bad)?;
    let x: i32 = x.trim().parse().map_err(|_| bad())?;
    let z: i32 = z.trim().parse().map_err(|_| bad())?;
    Ok(Point { x, z })
}

fn parse_size(what: &str, s: &str) -> Result<Size, Outcome> {
    let bad = || {
        Outcome::error(
            Status::BadInput,
            "bad-input",
            format!("{what} must be \"w,d\", got {s:?}"),
        )
    };
    let (w, d) = s.split_once(',').ok_or_else(bad)?;
    let w: i32 = w.trim().parse().map_err(|_| bad())?;
    let d: i32 = d.trim().parse().map_err(|_| bad())?;
    Ok(Size { w, d })
}

pub struct PlaceArgs {
    pub manifest: PathBuf,
    pub kind: String,
    /// "x,z", in centimetres.
    pub at: String,
    pub facing: i32,
    /// "w,d", in centimetres; only for a sized kind.
    pub size: Option<String>,
    /// Defaults to `placement:<kind>-<x>-<z>`.
    pub id: Option<String>,
    /// Rewrite the manifest with the placement added, once it is accepted.
    pub write: bool,
}

/// Validates a placement through [`attempt_placement`] and prints the
/// result: `PlacementChanged` gives `ok: true` and the cells it changed;
/// `Rejected` gives `ok: false` and the core's reason, and the process
/// exits non-zero. With `--write` and an accepted placement, rewrites the
/// manifest with the placement added, re-serialised from the `Manifest`
/// type. That is canonical form, not a copy of the file's own key order:
/// fields come out in the contract's declared order, and a default is
/// omitted or filled exactly as the contract already serialises every
/// manifest elsewhere. A hand-edited manifest will therefore show a
/// reformatting diff alongside the placement. This is a ruling, not an
/// oversight: `serde_json`'s `preserve_order` feature is not enabled in
/// this workspace, and it stays off here too, because turning it on would
/// change the map order of every `serde_json::Value` in the CLI's build
/// graph, risking the byte-identical event logs the core promises
/// elsewhere. Manifests in this project are generated (`generate.py` is
/// the source of truth), so canonical form is the right default, not a
/// gap to close later.
pub fn place(a: &PlaceArgs) -> Outcome {
    match place_inner(a) {
        Ok(o) | Err(o) => o,
    }
}

fn place_inner(a: &PlaceArgs) -> Result<Outcome, Outcome> {
    let manifest = read_manifest(&a.manifest)?;
    let at = parse_point("--at", &a.at)?;
    let size = a
        .size
        .as_deref()
        .map(|s| parse_size("--size", s))
        .transpose()?;
    let id =
        a.id.clone()
            .unwrap_or_else(|| format!("placement:{}-{}-{}", a.kind, at.x, at.z));
    let placement = Placement {
        id: id.into(),
        kind: a.kind.clone(),
        at,
        facing: a.facing,
        size,
        ..Default::default()
    };
    let result = attempt_placement(manifest, placement)?;
    let mut body = placement_body(&result);
    if result.ok && a.write {
        write(&a.manifest, &pretty(&result.manifest))?;
        body["written"] = json!(a.manifest.display().to_string());
    }
    let status = if result.ok {
        Status::Ok
    } else {
        Status::Failed
    };
    Ok(Outcome { status, body })
}

/// Validates a proposed placement against a manifest without writing it:
/// the MCP tool's dry check, and the same [`attempt_placement`] the CLI's
/// `place` command uses.
pub struct CheckPlacementArgs {
    pub manifest: PathBuf,
    pub placement: Placement,
}

pub fn check_placement(a: &CheckPlacementArgs) -> Outcome {
    match check_placement_inner(a) {
        Ok(o) | Err(o) => o,
    }
}

fn check_placement_inner(a: &CheckPlacementArgs) -> Result<Outcome, Outcome> {
    let manifest = read_manifest(&a.manifest)?;
    let result = attempt_placement(manifest, a.placement.clone())?;
    let status = if result.ok {
        Status::Ok
    } else {
        Status::Failed
    };
    Ok(Outcome {
        status,
        body: placement_body(&result),
    })
}
