//! The session behind the Godot `CityWorld` class, in plain Rust so it is
//! tested without Godot. Everything crosses the boundary as JSON, with the
//! same contracts the CLI and MCP use.

use city_contracts::{
    Arrivals, Catalogue, CityId, Command, CommandType, Event, FeedRecord, HumanTier, Manifest,
    OccupantKind, OccupantProfile, Panel, Viewer,
};
use city_core::index::unparsed_schema_issue;
use city_core::invariants::check_world;
use city_core::nav::{CELL, Cell, NavGrid};
use city_core::{Feed, World, crowd, merge, parse_feed, project};
use serde_json::json;
use std::collections::BTreeMap;

/// One loaded world, or none yet, and the local player once joined.
#[derive(Default)]
pub struct Session {
    world: Option<World>,
    operator: bool,
    crowd: u32,
    /// The occupant this session commands.
    player: Option<CityId>,
    /// Whose view the client shows: the player's own once it joins.
    viewer: Option<CityId>,
    /// What the world was built from (manifest, feed with any crowd, seed),
    /// for replaying the session.
    source: Option<(Manifest, Feed, u64)>,
    /// Whether every step runs the core's invariant checks.
    checking: bool,
    /// Every invariant violation found while checking.
    violations: Vec<String>,
    /// The player's own events not yet taken (see `take_player_events_json`),
    /// at most `PLAYER_EVENTS_KEPT` of the latest.
    player_events: Vec<Event>,
}

/// How many of the player's own events are kept for the client to take.
const PLAYER_EVENTS_KEPT: usize = 256;

/// The city ID of a registered local player.
pub const PLAYER_ID: &str = "person:you";
/// The city ID of an anonymous observer.
pub const OBSERVER_ID: &str = "person:observer-1";

fn error(code: &str, message: impl Into<String>) -> String {
    json!({"error": {"code": code, "message": message.into()}}).to_string()
}

impl Session {
    /// Loads a world from a manifest, a feed and a seed, plus an optional
    /// generated fixture crowd. Returns `{"ok": bool, "issues": [...]}` or
    /// `{"ok": false, "error": "..."}`.
    pub fn load(
        &mut self,
        manifest_json: &str,
        feed_jsonl: &str,
        seed: u64,
        crowd_size: u32,
    ) -> String {
        self.world = None;
        self.player = None;
        self.viewer = None;
        self.player_events.clear();
        let manifest: Manifest = match serde_json::from_str(manifest_json) {
            Ok(m) => m,
            // A schema 1 manifest's tree rows and blocks no longer parse; it
            // is refused for its version, as validation refuses one that does.
            Err(e) => match unparsed_schema_issue(manifest_json) {
                Some(issue) => return json!({"ok": false, "issues": [issue]}).to_string(),
                None => return json!({"ok": false, "error": format!("manifest: {e}")}).to_string(),
            },
        };
        let mut feed = match parse_feed(feed_jsonl) {
            Ok(f) => f,
            Err(e) => return json!({"ok": false, "error": format!("feed: {e}")}).to_string(),
        };
        if crowd_size > 0 {
            let merged = crowd(&manifest, crowd_size, seed).and_then(|c| merge(feed.clone(), c));
            match merged {
                Ok(f) => feed = f,
                Err(e) => return json!({"ok": false, "error": e}).to_string(),
            }
        }
        self.violations.clear();
        match World::new(manifest.clone(), feed.clone(), seed) {
            Ok(w) => {
                self.world = Some(w);
                self.source = Some((manifest, feed, seed));
                self.crowd = crowd_size;
                json!({"ok": true, "issues": []}).to_string()
            }
            Err(issues) => json!({"ok": false, "issues": issues}).to_string(),
        }
    }

    /// Advances one tick; returns the new tick, or -1 if nothing is loaded.
    /// While checking, the tick is held to every invariant.
    pub fn step(&mut self) -> i64 {
        match &mut self.world {
            Some(w) => {
                let before = self.checking.then(|| w.snapshot().clone());
                let events = w.step();
                if let Some(before) = before {
                    let found = check_world(&before, w, &events);
                    self.violations.extend(found.iter().map(|v| {
                        format!("tick {}: invariant {}: {}", v.tick, v.invariant, v.detail)
                    }));
                }
                if let Some(player) = &self.player {
                    self.player_events.extend(
                        events
                            .into_iter()
                            .filter(|e| e.occupant.as_ref() == Some(player)),
                    );
                    let over = self.player_events.len().saturating_sub(PLAYER_EVENTS_KEPT);
                    self.player_events.drain(..over);
                }
                w.snapshot().tick as i64
            }
            None => -1,
        }
    }

    /// The player's own events since they were last taken, oldest first, as
    /// a JSON array of events: its refusals, boarding, stepping off, being
    /// left behind by a full tram. Only events about the player itself, and
    /// without their `seq` (their place in the whole run's log, which would
    /// tell how much else happened), so nothing here reveals anyone else.
    /// Taking them empties the list.
    pub fn take_player_events_json(&mut self) -> String {
        let events: Vec<serde_json::Value> = std::mem::take(&mut self.player_events)
            .iter()
            .map(|e| {
                let mut v = serde_json::to_value(e).expect("events serialise");
                if let Some(fields) = v.as_object_mut() {
                    fields.remove("seq");
                }
                v
            })
            .collect();
        serde_json::Value::from(events).to_string()
    }

    /// Holds every following step to the core's invariants (a diagnostic
    /// for tests and gates; it clones the snapshot each tick).
    pub fn set_checking(&mut self, on: bool) {
        self.checking = on;
    }

    /// Every invariant violation found while checking, as a JSON array of
    /// strings.
    pub fn violations_json(&self) -> String {
        json!(self.violations).to_string()
    }

    /// Rebuilds the world from what it was loaded from plus the input log,
    /// runs it to the current tick and compares the two snapshots byte for
    /// byte: `{"tick": n, "identical": bool}`.
    pub fn replay_json(&self) -> String {
        let (Some(w), Some((manifest, feed, seed))) = (&self.world, &self.source) else {
            return error("not-loaded", "load a world first");
        };
        let replayed = match merge(feed.clone(), w.input_log_feed()) {
            Ok(f) => f,
            Err(e) => return error("replay", e),
        };
        let mut again = match World::new(manifest.clone(), replayed, *seed) {
            Ok(a) => a,
            Err(issues) => return error("replay", format!("{issues:?}")),
        };
        while again.snapshot().tick < w.snapshot().tick {
            again.step();
        }
        let a = serde_json::to_string(w.snapshot()).expect("snapshots serialise");
        let b = serde_json::to_string(again.snapshot()).expect("snapshots serialise");
        json!({"tick": w.snapshot().tick, "identical": a == b}).to_string()
    }

    pub fn tick(&self) -> i64 {
        self.world.as_ref().map_or(-1, |w| w.snapshot().tick as i64)
    }

    /// Allows the operator viewer, and placement commands sent as the
    /// operator's. The client does this only when launched with
    /// `--operator`.
    pub fn set_operator(&mut self, on: bool) {
        self.operator = on;
    }

    pub fn crowd_size(&self) -> u32 {
        self.crowd
    }

    /// The projection for `viewer`: `public`, `operator` or a person's city ID.
    pub fn project_json(&self, viewer: &str) -> String {
        let Some(w) = &self.world else {
            return error("not-loaded", "load a world first");
        };
        let viewer = match viewer {
            "public" => Viewer::Public,
            "operator" if !self.operator => {
                return error(
                    "operator-flag-required",
                    "the operator view is diagnostic; launch with --operator",
                );
            }
            "operator" => Viewer::Operator,
            id => Viewer::Person { id: id.into() },
        };
        serde_json::to_string(&project(w.snapshot(), &viewer)).expect("projections serialise")
    }

    /// Joins the world as the local player: `as_` is `registered` (a
    /// visible person, `person:you`) or `observer` (an overlay only the
    /// player sees, `person:observer-1`), and `look` is `"OUTFIT,HAIR"`.
    /// Registers the profile by submitting `Arrive` at the tram stop, and
    /// makes the player's own ID the viewer. With `arrivals = "tram"` the
    /// player rides in aboard the next vehicle from its portal and steps off
    /// at the stop nearest the tram stop (its own platform); otherwise the
    /// world picks the nearest entrance. Returns `{"ok": true, "id": ...}`.
    pub fn join(&mut self, as_: &str, look: &str) -> String {
        let Some(w) = &mut self.world else {
            return error("not-loaded", "load a world first");
        };
        if self.player.is_some() {
            return error("already-joined", "this session already has a player");
        }
        let (id, name, tier) = match as_ {
            "registered" => (PLAYER_ID, "You", HumanTier::Registered),
            "observer" => (OBSERVER_ID, "Observer", HumanTier::Observer),
            _ => return error("bad-join", "join as `registered` or `observer`"),
        };
        let mut appearance = BTreeMap::new();
        let mut parts = look.split(',').map(str::trim);
        for key in ["outfit", "hair"] {
            if let Some(v) = parts.next().filter(|v| !v.is_empty()) {
                appearance.insert(key.to_string(), v.to_string());
            }
        }
        let id = CityId::from(id);
        let profile = OccupantProfile {
            id: id.clone(),
            kind: OccupantKind::Human { tier },
            display_name: name.into(),
            role: String::new(),
            department: None,
            home: None,
            work: None,
            shared_with: Default::default(),
            appearance,
        };
        let room = arrival_room(&w.snapshot().manifest);
        w.submit(Command::Arrive {
            occupant: id.clone(),
            profile: Some(profile),
            room,
            player: true,
        });
        self.player = Some(id.clone());
        self.viewer = Some(id.clone());
        json!({"ok": true, "id": id}).to_string()
    }

    /// Submits a command for the next tick. Only `Go`, `Steer`, `Depart`,
    /// `Board`, `Alight`, `Use` and `StopUsing` for the session's own
    /// occupant are accepted: the authority rule. A placement command (`Place`, `MovePlacement`,
    /// `RemovePlacement`) is accepted too, but only a session launched with
    /// `--operator` (see `set_operator`) sends it as the operator's: any
    /// other sends it in the player's name, and the world refuses it
    /// (`NotOperator`), which the player's events then carry.
    pub fn command(&mut self, command_json: &str) -> String {
        let (Some(w), Some(player)) = (&mut self.world, &self.player) else {
            return error("not-joined", "join first");
        };
        let Ok(command) = serde_json::from_str::<Command>(command_json) else {
            return error("bad-command", "not a command");
        };
        let command = if is_placement(&command) {
            sent_by(command, (!self.operator).then(|| player.clone()))
        } else {
            if !matches!(
                command.command_type(),
                CommandType::Go
                    | CommandType::Steer
                    | CommandType::Depart
                    | CommandType::Board
                    | CommandType::Alight
                    | CommandType::Use
                    | CommandType::StopUsing
            ) {
                return error(
                    "bad-command",
                    "a player may only Go, Steer, Depart, Board, Alight, Use or StopUsing",
                );
            }
            if command.occupant() != Some(player) {
                return error("not-yours", "a session commands only its own occupant");
            }
            command
        };
        w.submit(command);
        json!({"ok": true}).to_string()
    }

    /// Submits `Board` for the player: on a platform, wait for the next
    /// vehicle there, or board the one standing there with its doors open.
    pub fn board(&mut self) -> String {
        let (Some(w), Some(player)) = (&mut self.world, &self.player) else {
            return error("not-joined", "join first");
        };
        w.submit(Command::Board {
            occupant: player.clone(),
        });
        json!({"ok": true}).to_string()
    }

    /// Submits `Alight` for the player: step off the vehicle standing at a
    /// stop with its doors open.
    pub fn alight(&mut self) -> String {
        let (Some(w), Some(player)) = (&mut self.world, &self.player) else {
            return error("not-joined", "join first");
        };
        w.submit(Command::Alight {
            occupant: player.clone(),
        });
        json!({"ok": true}).to_string()
    }

    /// Submits `Depart` for the player, and ends its command of it. A
    /// player's `Depart` (`player`) leaves at once, from wherever it is: so
    /// Quit to title and then Explore joins again straight away.
    pub fn leave(&mut self) -> String {
        let (Some(w), Some(player)) = (&mut self.world, self.player.take()) else {
            return error("not-joined", "join first");
        };
        w.submit(Command::Depart {
            occupant: player,
            player: true,
        });
        json!({"ok": true}).to_string()
    }

    /// The world's live commands so far as a JSON Lines feed, header first.
    /// Merged with the original feed it replays the session.
    pub fn input_log_jsonl(&self) -> String {
        let Some(w) = &self.world else {
            return error("not-loaded", "load a world first");
        };
        let feed = w.input_log_feed();
        std::iter::once(FeedRecord::Header(feed.header))
            .chain(feed.entries.into_iter().map(FeedRecord::Entry))
            .map(|r| serde_json::to_string(&r).expect("feed records serialise") + "\n")
            .collect()
    }

    /// The viewer the client shows: `public`, or the player's own ID.
    pub fn viewer(&self) -> String {
        self.viewer
            .as_ref()
            .map_or_else(|| "public".to_string(), ToString::to_string)
    }

    /// The places only: the manifest without its occupant roster or seat
    /// reservations, so a style pack learns nothing about who exists.
    pub fn layout_json(&self) -> String {
        match &self.world {
            Some(w) => {
                let mut places = w.snapshot().manifest.clone();
                places.occupants.clear();
                for room in places
                    .city
                    .districts
                    .iter_mut()
                    .flat_map(|d| d.facilities.iter_mut())
                    .flat_map(|f| f.rooms.iter_mut())
                {
                    for seat in &mut room.seats {
                        seat.reserved_for = None;
                    }
                }
                let mut v = serde_json::to_value(&places).expect("manifests serialise");
                if let Some(obj) = v.as_object_mut() {
                    obj.remove("occupants");
                    if let Some(nav) = w.nav() {
                        obj.insert("grid".into(), grid_json(nav));
                    }
                }
                v.to_string()
            }
            None => error("not-loaded", "load a world first"),
        }
    }

    /// The built-in catalogue of kinds, as JSON: how much ground each kind
    /// of thing takes and how tall it stands.
    pub fn catalogue_json(&self) -> String {
        serde_json::to_string(Catalogue::builtin()).expect("the catalogue serialises")
    }

    /// [`Session::panel_json`], its refs read inside the fixture folder
    /// `dir` (where the manifest was read from) by `read_file`, which gives
    /// the text of a file by its path. With no folder set it reads nothing
    /// and returns a `not-configured` error JSON: a ref joined to an empty
    /// folder would be read from `/panels/` at the filesystem root.
    pub fn panel_json_in(
        &self,
        target: &str,
        dir: &str,
        read_file: &dyn Fn(&str) -> Option<String>,
    ) -> String {
        if dir.is_empty() {
            return error(
                "not-configured",
                "no fixture folder is set to read panels from",
            );
        }
        let dir = dir.trim_end_matches('/');
        self.panel_json(target, &|reference| {
            read_file(&format!("{dir}/{reference}"))
        })
    }

    /// The panel a display shows: the bound placement `target`'s own entry
    /// in its sample panel file, as JSON (a `Panel`). `read` gives the text
    /// of a file by its ref, relative to the folder the manifest was read
    /// from (the client reads it with Godot's own file access, which also
    /// reads a packaged `res://` folder). Only the `sample` source is
    /// served, from `panels/<name>.json` (a lowercase, hyphenated name), so
    /// no binding reads anything outside that folder. Returns an error
    /// JSON: `not-loaded`; `unknown-target` for an ID no placement or seat
    /// has; `unbound` for a placement with no binding, or a seat (seats
    /// carry none); `unsupported-source`; `bad-ref`; `panel-missing` when
    /// the file is absent or keys no panel by the placement; `bad-panel`
    /// when it does not parse.
    pub fn panel_json(&self, target: &str, read: &dyn Fn(&str) -> Option<String>) -> String {
        let Some((manifest, _, _)) = &self.source else {
            return error("not-loaded", "load a world first");
        };
        let districts = &manifest.city.districts;
        let placement = districts
            .iter()
            .flat_map(|d| &d.placements)
            .find(|p| p.id.as_str() == target);
        let Some(placement) = placement else {
            let seat = districts
                .iter()
                .flat_map(|d| &d.facilities)
                .flat_map(|f| &f.rooms)
                .flat_map(|r| &r.seats)
                .any(|s| s.id.as_str() == target);
            return if seat {
                error(
                    "unbound",
                    format!("{target} is a seat, which shows nothing"),
                )
            } else {
                error(
                    "unknown-target",
                    format!("no placement or seat is {target}"),
                )
            };
        };
        let Some(binding) = &placement.binding else {
            return error("unbound", format!("{target} shows nothing"));
        };
        if binding.source != "sample" {
            return error(
                "unsupported-source",
                format!(
                    "{target} is bound to {}; only sample panels are served",
                    binding.source
                ),
            );
        }
        let reference = binding.reference.as_str();
        let named = reference
            .strip_prefix("panels/")
            .and_then(|r| r.strip_suffix(".json"))
            .is_some_and(|name| {
                !name.is_empty()
                    && name
                        .bytes()
                        .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
            });
        if !named {
            return error(
                "bad-ref",
                format!("{target}'s sample ref {reference} is not panels/<name>.json"),
            );
        }
        let Some(text) = read(reference) else {
            return error("panel-missing", format!("{reference} cannot be read"));
        };
        let panels: BTreeMap<String, Panel> = match serde_json::from_str(&text) {
            Ok(p) => p,
            Err(e) => return error("bad-panel", format!("{reference}: {e}")),
        };
        match panels.get(target) {
            Some(panel) => serde_json::to_string(panel).expect("panels serialise"),
            None => error(
                "panel-missing",
                format!("{reference} has no panel for {target}"),
            ),
        }
    }

    /// The core's own answers for every cell of the walkable grid, row by
    /// row, for checking a client's copy of it: bits 0-15 hold the room
    /// index plus one (0 off the floor), bit 16 whether the cell is in a
    /// door span, bit 17 whether it holds a seat, and bits 18-25 whether a
    /// step to each neighbour in [`STEPS`] order is allowed. Empty with no
    /// world or no layout.
    pub fn grid_answers(&self) -> Vec<i32> {
        let Some(nav) = self.world.as_ref().and_then(World::nav) else {
            return Vec::new();
        };
        let extent = nav.extent();
        let (cols, rows) = (extent.w / CELL, extent.d / CELL);
        let mut answers = Vec::with_capacity((cols * rows) as usize);
        for j in 0..rows {
            for i in 0..cols {
                let c = Cell { i, j };
                let mut a = nav.room_index(c).map_or(0, |n| i32::from(n) + 1);
                a |= i32::from(nav.in_door_span(c)) << 16;
                a |= i32::from(nav.is_seat_cell(c)) << 17;
                for (k, (di, dj)) in STEPS.iter().enumerate() {
                    let to = Cell {
                        i: i + di,
                        j: j + dj,
                    };
                    a |= i32::from(nav.can_step(c, to)) << (18 + k);
                }
                answers.push(a);
            }
        }
        answers
    }
}

/// The eight neighbours [`Session::grid_answers`] reports steps to, as
/// (column, row) offsets: north, east, south, west, then north-east,
/// south-east, south-west, north-west.
pub const STEPS: [(i32, i32); 8] = [
    (0, -1),
    (1, 0),
    (0, 1),
    (-1, 0),
    (1, -1),
    (1, 1),
    (-1, 1),
    (-1, -1),
];

/// The walkable grid as clients load it (`layout_json`'s `grid`): its
/// origin, size, each level's cells as runs of `[room index or -1, length]`
/// row by row, the rooms in index order and whether each is open ground,
/// the door spans by number, and the seat cells. Only the ground level
/// exists until rooftops arrive.
fn grid_json(nav: &NavGrid) -> serde_json::Value {
    let extent = nav.extent();
    let (cols, rows) = (extent.w / CELL, extent.d / CELL);
    let mut runs: Vec<[i64; 2]> = Vec::new();
    for j in 0..rows {
        for i in 0..cols {
            let room = nav.room_index(Cell { i, j }).map_or(-1, i64::from);
            match runs.last_mut() {
                Some(run) if run[0] == room => run[1] += 1,
                _ => runs.push([room, 1]),
            }
        }
    }
    let cell = |c: &Cell| [c.i, c.j];
    json!({
        "origin": {"x": extent.x, "z": extent.z},
        "cols": cols,
        "rows": rows,
        "levels": [{"level": 0, "rooms": runs}],
        "rooms": nav.room_ids(),
        "outdoor": nav.outdoor(),
        "spans": nav
            .door_spans()
            .map(|(rooms, cells)| json!({"rooms": rooms, "cells": cells.iter().map(cell).collect::<Vec<_>>()}))
            .collect::<Vec<_>>(),
        "seats": nav.seat_cells().iter().map(cell).collect::<Vec<_>>(),
    })
}

/// Whether `command` changes the city's placements.
fn is_placement(command: &Command) -> bool {
    matches!(
        command.command_type(),
        CommandType::Place | CommandType::MovePlacement | CommandType::RemovePlacement
    )
}

/// A placement command as sent by `by`: the operator's when none.
fn sent_by(command: Command, by: Option<CityId>) -> Command {
    match command {
        Command::Place { placement, .. } => Command::Place { placement, by },
        Command::MovePlacement { id, at, facing, .. } => {
            Command::MovePlacement { id, at, facing, by }
        }
        Command::RemovePlacement { id, .. } => Command::RemovePlacement { id, by },
        other => other,
    }
}

/// Where a joining player arrives: the tram stop, else the first outdoor
/// room, else the first room. With arrivals by tram, the tram stop must be
/// a platform (the player steps off onto it); without one there, the first
/// platform of the first stop.
fn arrival_room(m: &Manifest) -> Option<city_contracts::PlaceId> {
    let rooms: Vec<&city_contracts::Room> = m
        .city
        .districts
        .iter()
        .flat_map(|d| &d.facilities)
        .flat_map(|f| &f.rooms)
        .collect();
    let tram_stop = rooms
        .iter()
        .find(|r| r.template.as_deref() == Some("tram-stop"));
    if m.city.arrivals == Arrivals::Tram && !m.lines.is_empty() {
        let platforms: Vec<&city_contracts::PlaceId> = m
            .lines
            .iter()
            .flat_map(|l| &l.stops)
            .flat_map(|s| s.platforms.iter())
            .collect();
        if let Some(r) = tram_stop.filter(|r| platforms.contains(&&r.id)) {
            return Some(r.id.clone());
        }
        if let Some(p) = platforms.first() {
            return Some((*p).clone());
        }
    }
    tram_stop
        .or_else(|| rooms.iter().find(|r| r.is_outdoor()))
        .or_else(|| rooms.first())
        .map(|r| r.id.clone())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;
    use std::collections::BTreeSet;

    const MANIFEST: &str = include_str!("../../../fixtures/district/manifest.json");
    const FEED: &str = include_str!("../../../fixtures/district/feed.jsonl");

    fn json(s: &str) -> Value {
        serde_json::from_str(s).unwrap()
    }

    #[test]
    fn load_reports_issues() {
        let mut s = Session::default();
        let r = json(&s.load(
            r#"{"schema_version":9,"city":{"id":"c","name":"C","districts":[]}}"#,
            FEED,
            1,
            0,
        ));
        assert_eq!(r["ok"], false);
        assert!(
            r["issues"]
                .as_array()
                .unwrap()
                .iter()
                .any(|i| i["code"] == "schema-version")
        );
        let r = json(&s.load("not json", FEED, 1, 0));
        assert_eq!(r["ok"], false);
        assert!(r["error"].is_string());
        // A schema 1 manifest is refused for its version, though its tree
        // rows no longer parse.
        let r = json(&s.load(
            r#"{"schema_version":1,"city":{"id":"c","name":"C","districts":[]},
                "scenery":[{"kind":"tree-row","points":[],"spacing":600}]}"#,
            FEED,
            1,
            0,
        ));
        assert_eq!(r["ok"], false);
        assert_eq!(r["issues"][0]["code"], "schema-version", "{r}");
        // A schema 2 manifest still carrying tree rows is refused for them.
        let r = json(&s.load(
            r#"{"schema_version":2,"city":{"id":"c","name":"C","districts":[]},
                "scenery":[{"kind":"tree-row","points":[],"spacing":600}]}"#,
            FEED,
            1,
            0,
        ));
        assert_eq!(r["ok"], false);
        assert_eq!(r["issues"][0]["code"], "removed-field", "{r}");
        let r = json(&s.load(MANIFEST, FEED, 1, 0));
        assert_eq!(r["ok"], true, "{r}");
    }

    #[test]
    fn project_before_load_errors() {
        let s = Session::default();
        assert_eq!(
            json(&s.project_json("public"))["error"]["code"],
            "not-loaded"
        );
        assert_eq!(s.tick(), -1);
    }

    #[test]
    fn operator_needs_enable() {
        let mut s = Session::default();
        s.load(MANIFEST, FEED, 1, 0);
        assert_eq!(
            json(&s.project_json("operator"))["error"]["code"],
            "operator-flag-required"
        );
        s.set_operator(true);
        assert_eq!(
            json(&s.project_json("operator"))["viewer"]["type"],
            "Operator"
        );
        assert_eq!(
            json(&s.project_json("person:asha"))["viewer"]["id"],
            "person:asha"
        );
    }

    #[test]
    fn step_advances_and_projects_time() {
        let mut s = Session::default();
        assert_eq!(s.step(), -1);
        s.load(MANIFEST, FEED, 1, 0);
        assert_eq!(s.tick(), 0);
        for _ in 0..5 {
            s.step();
        }
        assert_eq!(s.tick(), 5);
        let p = json(&s.project_json("public"));
        assert!(p["rooms"].is_array());
        assert!(p["time_of_day"].is_number());
    }

    #[test]
    fn layout_carries_places_but_no_people() {
        let mut s = Session::default();
        s.load(MANIFEST, FEED, 1, 0);
        let text = s.layout_json();
        let m = json(&text);
        assert!(m["city"]["districts"].is_array() && m["city"]["entrances"].is_array());
        assert!(m.get("occupants").is_none(), "no occupant roster");
        assert!(
            !text.contains("agent:") && !text.contains("person:"),
            "no occupant IDs anywhere"
        );
        let seats = m["city"]["districts"][0]["facilities"][0]["rooms"][0]["seats"]
            .as_array()
            .unwrap();
        assert!(
            seats.iter().all(|s| s["reserved_for"].is_null()),
            "no reservations"
        );
    }

    #[test]
    fn crowd_merges_and_layout_is_the_manifest() {
        let mut s = Session::default();
        s.load(MANIFEST, FEED, 1, 30);
        let m = json(&s.layout_json());
        assert_eq!(m["city"]["id"], "city:agentnagar");
        assert!(m["clock"].is_object());
        for _ in 0..600 {
            s.step();
        }
        let log = json(&s.project_json("public")).to_string();
        assert!(log.contains("time_of_day"));
        assert_eq!(s.crowd_size(), 30);
    }

    // ---- Panels ----

    /// Reads a sample panel file from the district fixture's folder, as the
    /// client reads it beside the manifest.
    fn fixture_file(reference: &str) -> Option<String> {
        let dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/district");
        std::fs::read_to_string(dir.join(reference)).ok()
    }

    fn error_code(s: &str) -> String {
        json(s)["error"]["code"].as_str().unwrap_or("").to_owned()
    }

    #[test]
    fn panel_json_gives_the_squares_notices() {
        let s = loaded();
        let panel = json(&s.panel_json("placement:square-noticeboard", &fixture_file));
        assert_eq!(panel["type"], "Notices", "{panel}");
        assert_eq!(panel["sample"], true);
        let items = panel["items"].as_array().unwrap();
        assert_eq!(items.len(), 3);
        assert!(items[0]["headline"].as_str().unwrap().starts_with("v0.0.3"));
        // Each shelf its own spines, from one file keyed by placement.
        let first = json(&s.panel_json("placement:reading-shelf-1", &fixture_file));
        let second = json(&s.panel_json("placement:reading-shelf-2", &fixture_file));
        assert_eq!(
            (&first["type"], &second["type"]),
            (&json!("Shelf"), &json!("Shelf"))
        );
        assert_ne!(first["spines"], second["spines"]);
    }

    /// The client reads panels from the folder the manifest came from. With
    /// none set it reads nothing (never `/panels/<name>.json` at the
    /// filesystem root) and says the folder is not configured; with one
    /// set, the ref is read inside it.
    #[test]
    fn panel_json_in_reads_nothing_until_a_fixture_folder_is_set() {
        let s = loaded();
        let read = std::cell::RefCell::new(Vec::new());
        let reader = |path: &str| -> Option<String> {
            read.borrow_mut().push(path.to_owned());
            None
        };
        let answer = s.panel_json_in("placement:square-noticeboard", "", &reader);
        assert_eq!(error_code(&answer), "not-configured", "{answer}");
        assert!(read.borrow().is_empty(), "read {:?}", read.borrow());
        s.panel_json_in(
            "placement:square-noticeboard",
            "res://fixtures/district/",
            &reader,
        );
        assert_eq!(
            *read.borrow(),
            ["res://fixtures/district/panels/square-notices.json"]
        );
    }

    #[test]
    fn panel_json_refuses_what_is_unbound_unknown_or_not_sample() {
        let none = |_: &str| -> Option<String> { panic!("nothing is read") };
        assert_eq!(
            error_code(&Session::default().panel_json("placement:square-noticeboard", &none)),
            "not-loaded"
        );
        let s = loaded();
        // A display with no binding, a seat (which has none), and anything
        // else the manifest does not name.
        assert_eq!(
            error_code(&s.panel_json("placement:commons-bookshelf", &none)),
            "unbound"
        );
        assert_eq!(error_code(&s.panel_json("seat:r1", &none)), "unbound");
        assert_eq!(
            error_code(&s.panel_json("placement:nowhere", &none)),
            "unknown-target"
        );
        // Any source but `sample`, and any ref but panels/<name>.json, is
        // refused before anything is read.
        for (source, reference, code) in [
            ("superpipeline", "board:guild", "unsupported-source"),
            ("sample", "../manifest.json", "bad-ref"),
            ("sample", "/etc/passwd", "bad-ref"),
            ("sample", "panels/../feed.jsonl", "bad-ref"),
            ("sample", "panels/Notices.json", "bad-ref"),
        ] {
            let mut m: Manifest = serde_json::from_str(MANIFEST).unwrap();
            let board = m.city.districts[0]
                .placements
                .iter_mut()
                .find(|p| p.id.as_str() == "placement:square-noticeboard")
                .unwrap();
            board.binding.as_mut().unwrap().source = source.into();
            board.binding.as_mut().unwrap().reference = reference.into();
            let mut s = Session::default();
            let r = json(&s.load(&serde_json::to_string(&m).unwrap(), FEED, 1, 0));
            assert_eq!(r["ok"], true, "{r}");
            assert_eq!(
                error_code(&s.panel_json("placement:square-noticeboard", &none)),
                code,
                "{source} {reference}"
            );
        }
        // A bound file that is missing, unparsable, or keys no panel by the
        // placement.
        let missing = |_: &str| None;
        let garbled = |_: &str| Some("{".to_owned());
        let other = |_: &str| {
            Some(r#"{"placement:else": {"type": "Plaque", "title": "T", "text": "X", "sample": true}}"#.to_owned())
        };
        assert_eq!(
            error_code(&s.panel_json("placement:square-noticeboard", &missing)),
            "panel-missing"
        );
        assert_eq!(
            error_code(&s.panel_json("placement:square-noticeboard", &garbled)),
            "bad-panel"
        );
        assert_eq!(
            error_code(&s.panel_json("placement:square-noticeboard", &other)),
            "panel-missing"
        );
    }

    // ---- Sessions and authority (Stage 5) ----

    fn loaded() -> Session {
        let mut s = Session::default();
        let r = json(&s.load(MANIFEST, FEED, 1, 0));
        assert_eq!(r["ok"], true, "{r}");
        s
    }

    /// Every occupant view in a projection, wherever it is listed, riders
    /// aboard a tram included.
    fn views(p: &Value) -> Vec<Value> {
        let mut out: Vec<Value> = p["in_transit"].as_array().unwrap().clone();
        if let Some(aboard) = p["aboard"].as_array() {
            out.extend(aboard.iter().cloned());
        }
        for r in p["rooms"].as_array().unwrap() {
            out.extend(r["occupants"].as_array().unwrap().iter().cloned());
            out.extend(r["waiting"].as_array().unwrap().iter().cloned());
        }
        out
    }

    fn find(p: &Value, id: &str) -> Option<Value> {
        views(p).into_iter().find(|v| v["id"] == id)
    }

    fn room_holding(p: &Value, id: &str) -> Option<String> {
        p["rooms"].as_array().unwrap().iter().find_map(|r| {
            r["occupants"]
                .as_array()
                .unwrap()
                .iter()
                .any(|v| v["id"] == id)
                .then(|| r["id"].as_str().unwrap().to_string())
        })
    }

    #[test]
    fn joining_as_registered_is_visible_in_public() {
        let mut s = loaded();
        assert_eq!(s.viewer(), "public");
        let r = json(&s.join("registered", "3,1"));
        assert_eq!(r["ok"], true, "{r}");
        assert_eq!(r["id"], "person:you");
        assert_eq!(s.viewer(), "person:you");
        // The district's arrivals ride in: joining at tick 1, the player
        // takes east:1, the tram that reaches the Square first, and steps
        // off it at 35.
        for _ in 0..40 {
            s.step();
        }
        let p = json(&s.project_json("public"));
        let you = find(&p, "person:you").expect("a registered player is public");
        assert_eq!(you["display_name"], "You");
        assert_eq!(you["kind"]["tier"], "Registered");
        assert_eq!(you["appearance"]["outfit"], "3");
        assert_eq!(you["appearance"]["hair"], "1");
        assert_eq!(
            room_holding(&p, "person:you").as_deref(),
            Some("room:tram-stop"),
            "it arrives at the tram stop"
        );
    }

    #[test]
    fn joining_as_observer_is_absent_from_public_but_seen_by_itself() {
        let mut s = loaded();
        let r = json(&s.join("observer", "0,0"));
        assert_eq!(r["id"], "person:observer-1");
        assert_eq!(s.viewer(), "person:observer-1");
        // Through the whole ride in on east:1 (stepping off at 35) and
        // after it.
        for _ in 0..40 {
            s.step();
            let p = json(&s.project_json("public"));
            assert!(find(&p, "person:observer-1").is_none());
        }
        let own = json(&s.project_json(&s.viewer()));
        let me = find(&own, "person:observer-1").expect("the observer sees itself");
        assert_eq!(me["kind"]["tier"], "Observer");
    }

    #[test]
    fn commands_are_for_the_players_own_occupant_only() {
        let mut s = loaded();
        let go = |who: &str| {
            json!({"type": "Go", "occupant": who, "to": {"type": "Room", "room": "room:plaza"}})
                .to_string()
        };
        assert_eq!(
            json(&s.command(&go("person:you")))["error"]["code"],
            "not-joined"
        );
        assert_eq!(json(&s.leave())["error"]["code"], "not-joined");
        s.join("registered", "1,1");
        assert_eq!(
            json(&s.command(&go("agent:kai")))["error"]["code"],
            "not-yours"
        );
        assert_eq!(json(&s.command("not json"))["error"]["code"], "bad-command");
        let arrive = json!({"type": "Arrive", "occupant": "person:you"}).to_string();
        assert_eq!(json(&s.command(&arrive))["error"]["code"], "bad-command");
        let mv = json!({"type": "Move", "occupant": "person:you", "to": "room:plaza"}).to_string();
        assert_eq!(json(&s.command(&mv))["error"]["code"], "bad-command");
        assert_eq!(json(&s.command(&go("person:you"))), json!({"ok": true}));
        let steer = json!({"type": "Steer", "occupant": "person:you", "cells": []}).to_string();
        assert_eq!(json(&s.command(&steer)), json!({"ok": true}));
        let log = s.input_log_jsonl();
        let feed = city_core::parse_feed(&log).expect("the input log is a feed");
        assert_eq!(feed.entries.len(), 3, "the arrival, the Go and the Steer");
        assert!(
            feed.entries
                .iter()
                .all(|e| e.command.occupant().map(|o| o.as_str()) == Some("person:you"))
        );
    }

    /// A player uses things through `Use` and `StopUsing`, for its own
    /// occupant only; the core then decides whether the use is allowed.
    #[test]
    fn a_player_may_use_and_stop_using_for_itself_only() {
        let mut s = loaded();
        let use_ = |who: &str| {
            json!({"type": "Use", "occupant": who, "target": "placement:square-noticeboard",
                "capability": "read", "anchor": 0})
            .to_string()
        };
        let stop = |who: &str| json!({"type": "StopUsing", "occupant": who}).to_string();
        assert_eq!(
            json(&s.command(&use_(PLAYER_ID)))["error"]["code"],
            "not-joined"
        );
        s.join("registered", "1,1");
        assert_eq!(
            json(&s.command(&use_("agent:kai")))["error"]["code"],
            "not-yours"
        );
        assert_eq!(
            json(&s.command(&stop("agent:kai")))["error"]["code"],
            "not-yours"
        );
        assert_eq!(json(&s.command(&use_(PLAYER_ID))), json!({"ok": true}));
        assert_eq!(json(&s.command(&stop(PLAYER_ID))), json!({"ok": true}));
        let feed = city_core::parse_feed(&s.input_log_jsonl()).expect("a feed");
        let types: Vec<CommandType> = feed
            .entries
            .iter()
            .map(|e| e.command.command_type())
            .collect();
        assert_eq!(
            types,
            [
                CommandType::Arrive,
                CommandType::Use,
                CommandType::StopUsing
            ]
        );
    }

    #[test]
    fn only_an_operator_session_changes_placements() {
        let mut s = loaded();
        s.join("registered", "1,1");
        let place = json!({"type": "Place", "placement":
            {"id": "placement:planter", "kind": "planter", "at": {"x": 1000, "z": 1000}}})
        .to_string();
        assert_eq!(json(&s.command(&place)), json!({"ok": true}));
        s.step();
        let events = json(&s.take_player_events_json());
        assert!(
            events.as_array().unwrap().iter().any(|e| e["kind"]
                == json!({"type": "Rejected", "command": "Place", "reason": "NotOperator"})),
            "the player is refused: {events}"
        );
        assert!(
            json(&s.project_json("public"))
                .get("grid_changes")
                .is_none()
        );

        s.set_operator(true);
        assert_eq!(json(&s.command(&place)), json!({"ok": true}));
        s.step();
        let changes = json(&s.project_json("public"))["grid_changes"].clone();
        assert!(
            changes.as_array().is_some_and(|c| !c.is_empty()),
            "the operator's planter changes the grid: {changes}"
        );
        assert!(
            changes
                .as_array()
                .unwrap()
                .iter()
                .all(|c| c["walkable"] == false && c.get("room").is_none()),
            "a cell that closes names no room: {changes}"
        );
        s.step();
        assert!(
            json(&s.project_json("public"))
                .get("grid_changes")
                .is_none()
        );
        let remove = json!({"type": "RemovePlacement", "id": "placement:planter"}).to_string();
        assert_eq!(json(&s.command(&remove)), json!({"ok": true}));
        s.step();
        let reopened = json(&s.project_json("public"))["grid_changes"].clone();
        let nav = s.world.as_ref().unwrap().nav().unwrap();
        assert!(
            reopened.as_array().is_some_and(|c| !c.is_empty()
                && c.iter().all(|c| {
                    let cell = city_core::nav::Cell {
                        i: c["i"].as_i64().unwrap() as i32,
                        j: c["j"].as_i64().unwrap() as i32,
                    };
                    c["walkable"] == true && c["room"] == json!(nav.room_index(cell))
                })),
            "the cells it opens name the room whose floor they are: {reopened}"
        );
        assert_eq!(json(&s.replay_json())["identical"], true);
    }

    // ---- The grid and the catalogue, for clients ----

    /// Each cell's room number (-1 for none), row by row, from the
    /// run-length-encoded level of a layout's `grid`.
    fn decoded_rooms(level: &Value) -> Vec<i64> {
        let mut rooms = Vec::new();
        for run in level["rooms"].as_array().unwrap() {
            let (room, length) = (run[0].as_i64().unwrap(), run[1].as_u64().unwrap());
            assert!(length > 0, "no empty runs");
            rooms.extend(std::iter::repeat_n(room, length as usize));
        }
        rooms
    }

    fn cells_of(list: &Value) -> BTreeSet<Cell> {
        list.as_array()
            .unwrap()
            .iter()
            .map(|c| Cell {
                i: c[0].as_i64().unwrap() as i32,
                j: c[1].as_i64().unwrap() as i32,
            })
            .collect()
    }

    #[test]
    fn the_layout_carries_the_cores_grid() {
        let s = loaded();
        let grid = json(&s.layout_json())["grid"].clone();
        let nav = s.world.as_ref().unwrap().nav().unwrap();
        let extent = nav.extent();
        assert_eq!(grid["origin"], json!({"x": extent.x, "z": extent.z}));
        let (cols, rows) = (extent.w / CELL, extent.d / CELL);
        assert_eq!(
            (grid["cols"].clone(), grid["rows"].clone()),
            (json!(cols), json!(rows))
        );
        let levels = grid["levels"].as_array().unwrap();
        assert_eq!(levels.len(), 1, "only the ground level exists");
        assert_eq!(levels[0]["level"], 0);
        let rooms = decoded_rooms(&levels[0]);
        assert_eq!(rooms.len(), (cols * rows) as usize, "one room per cell");
        let ids = grid["rooms"].as_array().unwrap();
        let outdoor = grid["outdoor"].as_array().unwrap();
        assert_eq!(ids.len(), outdoor.len());
        let (mut spans_seen, mut seats_seen) = (BTreeSet::new(), BTreeSet::new());
        for j in 0..rows {
            for i in 0..cols {
                let c = Cell { i, j };
                let room = rooms[(j * cols + i) as usize];
                assert_eq!(room, nav.room_index(c).map_or(-1, i64::from), "{c:?}");
                assert_eq!(
                    (room >= 0).then(|| ids[room as usize].as_str().unwrap()),
                    nav.room_at(c).map(|r| r.as_str()),
                    "{c:?}"
                );
                if room >= 0 {
                    let id = nav.room_at(c).unwrap();
                    let open = s.world.as_ref().unwrap().index().rooms[id].outdoor;
                    assert_eq!(outdoor[room as usize], open, "{id}");
                }
                if nav.in_door_span(c) {
                    spans_seen.insert(c);
                }
                if nav.is_seat_cell(c) {
                    seats_seen.insert(c);
                }
            }
        }
        let spans = grid["spans"].as_array().unwrap();
        let mut span_cells = BTreeSet::new();
        for span in spans {
            let pair = span["rooms"].as_array().unwrap();
            let (a, b) = (pair[0].as_u64().unwrap(), pair[1].as_u64().unwrap());
            let named = [
                ids[a as usize].as_str().unwrap(),
                ids[b as usize].as_str().unwrap(),
            ];
            for c in cells_of(&span["cells"]) {
                assert!(
                    nav.span_rooms(c)
                        .iter()
                        .any(|r| [r[0].as_str(), r[1].as_str()] == named),
                    "{c:?} is in a span between {named:?}"
                );
                span_cells.insert(c);
            }
        }
        assert!(!spans_seen.is_empty(), "the district has doors");
        assert_eq!(
            span_cells, spans_seen,
            "every door span's cells, and no others"
        );
        assert!(!seats_seen.is_empty(), "the district has seats");
        assert_eq!(cells_of(&grid["seats"]), seats_seen, "every seat cell");
    }

    #[test]
    fn no_grid_is_given_before_a_world_is_loaded() {
        let s = Session::default();
        assert_eq!(json(&s.layout_json())["error"]["code"], "not-loaded");
        assert!(s.grid_answers().is_empty());
    }

    #[test]
    fn the_cores_answers_cover_every_cell() {
        let s = loaded();
        let nav = s.world.as_ref().unwrap().nav().unwrap();
        let extent = nav.extent();
        let (cols, rows) = (extent.w / CELL, extent.d / CELL);
        let answers = s.grid_answers();
        assert_eq!(answers.len(), (cols * rows) as usize);
        for j in 0..rows {
            for i in 0..cols {
                let c = Cell { i, j };
                let a = answers[(j * cols + i) as usize];
                assert_eq!(
                    a & 0xffff,
                    nav.room_index(c).map_or(0, |n| i32::from(n) + 1)
                );
                assert_eq!(a >> 16 & 1 == 1, nav.in_door_span(c));
                assert_eq!(a >> 17 & 1 == 1, nav.is_seat_cell(c));
                for (k, (di, dj)) in STEPS.iter().enumerate() {
                    let to = Cell {
                        i: i + di,
                        j: j + dj,
                    };
                    assert_eq!(
                        a >> (18 + k) & 1 == 1,
                        nav.can_step(c, to),
                        "{c:?} to {to:?}"
                    );
                }
            }
        }
    }

    #[test]
    fn the_catalogue_is_the_built_in_one() {
        let s = Session::default();
        assert_eq!(
            json(&s.catalogue_json()),
            serde_json::to_value(city_contracts::Catalogue::builtin()).unwrap()
        );
    }

    #[test]
    fn a_players_go_walks_it_there() {
        let mut s = loaded();
        s.join("registered", "2,2");
        // Until the player has ridden in and stepped off (at 35): aboard,
        // a Go is refused.
        for _ in 0..40 {
            s.step();
        }
        let go = json!({"type": "Go", "occupant": "person:you",
            "to": {"type": "Room", "room": "room:plaza"}});
        assert_eq!(json(&s.command(&go.to_string())), json!({"ok": true}));
        for _ in 0..60 {
            s.step();
        }
        let p = json(&s.project_json("public"));
        assert_eq!(
            room_holding(&p, "person:you").as_deref(),
            Some("room:plaza")
        );
    }

    #[test]
    fn leave_departs() {
        let mut s = loaded();
        s.join("registered", "1,2");
        // Leaves from the ground: once it has ridden in and stepped off.
        let mut arrived = false;
        for _ in 0..60 {
            s.step();
            if room_holding(&json(&s.project_json("public")), "person:you").is_some() {
                arrived = true;
                break;
            }
        }
        assert!(arrived, "it rides in and steps off");
        assert_eq!(json(&s.leave()), json!({"ok": true}));
        // A player leaving leaves at once: it never rides out, and a new
        // join (Quit to title, then Explore) must not wait for it to walk
        // to a platform and ride away.
        s.step();
        let p = json(&s.project_json("public"));
        assert!(find(&p, "person:you").is_none(), "gone on the next tick");
        assert!(matches!(
            s.world.as_ref().unwrap().snapshot().occupants[&CityId::from(PLAYER_ID)].location,
            city_contracts::Location::Away
        ));
        assert!(s.input_log_jsonl().contains("\"Depart\""));
        assert!(s.input_log_jsonl().contains("\"player\":true"));
        assert_eq!(json(&s.leave())["error"]["code"], "not-joined");
    }

    #[test]
    fn a_player_leaving_while_queued_or_aboard_leaves_at_once_and_can_join_again() {
        for leave_at in [1, 31] {
            let mut s = tram_session();
            s.join("registered", "1,1");
            // At 1 it waits at the portal for east:1 (entering at 30); at 31
            // it rides east:1 towards A.
            step_to(&mut s, leave_at);
            let before = player_location(&s);
            s.leave();
            step_to(&mut s, leave_at + 1);
            assert_eq!(
                player_location(&s),
                city_contracts::Location::Away,
                "left from {before:?}"
            );
            let world = s.world.as_ref().unwrap();
            assert!(
                world
                    .snapshot()
                    .vehicles
                    .iter()
                    .all(|v| v.riders.is_empty()),
                "no vehicle still carries it"
            );
            assert!(
                world.riders().arrival_queues.is_empty(),
                "no portal queues it"
            );
            // The next visit joins at once.
            assert_eq!(json(&s.join("registered", "1,1"))["ok"], true);
            step_to(&mut s, leave_at + 2);
            assert!(!matches!(
                player_location(&s),
                city_contracts::Location::Away
            ));
            assert_eq!(json(&s.violations_json()), json!([]));
            assert_eq!(json(&s.replay_json())["identical"], true);
        }
    }

    #[test]
    fn joining_needs_a_world_and_happens_once() {
        let mut s = Session::default();
        assert_eq!(
            json(&s.join("registered", "1,1"))["error"]["code"],
            "not-loaded"
        );
        let mut s = loaded();
        assert_eq!(json(&s.join("pilot", "1,1"))["error"]["code"], "bad-join");
        s.join("registered", "1,1");
        assert_eq!(
            json(&s.join("observer", "1,1"))["error"]["code"],
            "already-joined"
        );
        s.load(MANIFEST, FEED, 1, 0);
        assert_eq!(s.viewer(), "public", "a new world starts without a player");
    }

    #[test]
    fn replaying_the_input_log_reproduces_the_session() {
        let mut s = loaded();
        s.join("registered", "3,1");
        let mut log = Vec::new();
        for t in 0..90 {
            if t == 25 {
                let go = json!({"type": "Go", "occupant": "person:you",
                    "to": {"type": "Room", "room": "room:plaza"}});
                s.command(&go.to_string());
            }
            if t == 70 {
                s.leave();
            }
            s.step();
            log.push(s.project_json(&s.viewer()));
        }
        let replay = city_core::merge(
            parse_feed(FEED).unwrap(),
            parse_feed(&s.input_log_jsonl()).unwrap(),
        )
        .unwrap();
        let manifest: Manifest = serde_json::from_str(MANIFEST).unwrap();
        let mut w = World::new(manifest, replay, 1).unwrap();
        let mut again = Vec::new();
        for _ in 0..90 {
            w.step();
            again.push(
                serde_json::to_string(&project(
                    w.snapshot(),
                    &Viewer::Person {
                        id: "person:you".into(),
                    },
                ))
                .unwrap(),
            );
        }
        assert_eq!(log, again);
    }

    #[test]
    fn checking_finds_no_violations_and_the_session_replays_identically() {
        let mut s = Session::default();
        s.load(MANIFEST, FEED, 7, 40);
        s.set_checking(true);
        assert_eq!(json(&s.join("registered", "2,1"))["ok"], true);
        for t in 0..60 {
            if t == 20 {
                let go = json!({"type": "Go", "occupant": "person:you",
                    "to": {"type": "Room", "room": "room:workshop"}});
                assert!(json(&s.command(&go.to_string())).get("error").is_none());
            }
            s.step();
        }
        assert_eq!(
            json(&s.violations_json()),
            json!([]),
            "every invariant held"
        );
        let r = json(&s.replay_json());
        assert_eq!(r["tick"], 60);
        assert_eq!(r["identical"], true, "{r}");
    }

    // ---- Riding the tram (city tram, Task 5) ----

    /// A 60 m tram street with arrivals by tram and three stops, A, B and
    /// C, each with its own north (eastbound) platform; A's is the tram
    /// stop. The south platform serves every stop westbound.
    fn tram_manifest() -> String {
        let platform = |id: &str, x: i32, template: &str| {
            json!({"id": id, "name": id, "capacity": 50, "template": template, "outdoor": true,
                   "rect": {"x": x, "z": 0, "w": 2000, "d": 150}})
        };
        json!({
            "schema_version": 2,
            "catalogue": 1,
            "clock": {"ticks_per_day": 600, "start_minute": 420},
            "city": {"id": "city:t", "name": "T", "arrivals": "tram",
                     "entrances": [{"x": 0, "z": 100}], "districts": [
                {"id": "district:t", "name": "T", "facilities": [
                    {"id": "facility:ground", "name": "Ground", "rooms": [
                        platform("room:north-a", 0, "tram-stop"),
                        platform("room:north-b", 2000, "ground"),
                        platform("room:north-c", 4000, "ground"),
                        {"id": "room:street", "name": "Street", "capacity": 50, "template": "ground",
                         "outdoor": true, "rect": {"x": 0, "z": 150, "w": 6000, "d": 600}},
                        {"id": "room:south", "name": "South", "capacity": 50, "template": "ground",
                         "outdoor": true, "rect": {"x": 0, "z": 750, "w": 6000, "d": 200}}
                    ]}
                ]}
            ]},
            "lines": [{
                "id": "line:boulevard", "name": "Boulevard tram", "mode": "tram",
                "points": [{"x": 0, "z": 450}, {"x": 6000, "z": 450}],
                "tracks": [-150, 150],
                "stops": [
                    {"id": "stop:a", "name": "A", "at": 1000, "platforms": ["room:north-a", "room:south"]},
                    {"id": "stop:b", "name": "B", "at": 3000, "platforms": ["room:north-b", "room:south"]},
                    {"id": "stop:c", "name": "C", "at": 5000, "platforms": ["room:north-c", "room:south"]}
                ],
                "timetable": {"headway": 30, "offset": [0, 15], "speed": 28, "dwell": 12},
                "vehicle": {"capacity": 40, "length": 1200, "doors": [200, 600, 1000]}
            }]
        })
        .to_string()
    }

    const TRAM_FEED: &str = "{\"record\": \"header\", \"schema_version\": 1, \"source\": \"fixture:tram\", \"fixture\": true}\n";

    fn tram_session() -> Session {
        let mut s = Session::default();
        let r = json(&s.load(&tram_manifest(), TRAM_FEED, 1, 0));
        assert_eq!(r["ok"], true, "{r}");
        s.set_checking(true);
        s
    }

    fn player_location(s: &Session) -> city_contracts::Location {
        s.world.as_ref().unwrap().snapshot().occupants[&CityId::from(PLAYER_ID)]
            .location
            .clone()
    }

    fn step_to(s: &mut Session, tick: i64) {
        while s.tick() < tick {
            s.step();
        }
    }

    fn in_room(room: &str) -> city_contracts::Location {
        city_contracts::Location::InRoom {
            room: room.into(),
            seat: None,
        }
    }

    /// The district: joining on the first tick, the player boards east:1
    /// as it enters and steps off at the Square at 6. Joining later in the
    /// first 15 ticks, east:1 has gone, and the tram that reaches the
    /// Square first is east:2 (entering at 31, it stands there at 36;
    /// west:1, entering at 16, stands at the Avenue stop first and reaches
    /// the Square at 39). The player steps off onto the tram stop.
    #[test]
    fn joining_the_district_early_rides_the_first_eastbound_tram_to_the_tram_stop() {
        for join_at in 1..=15 {
            let mut s = loaded();
            s.set_checking(true);
            step_to(&mut s, join_at - 1);
            s.join("registered", "1,1");
            // (the tick it is first on the ground, the vehicle it rode).
            let (mut rode, mut stepped_off) = (None, None);
            while s.tick() < 50 {
                s.step();
                match player_location(&s) {
                    city_contracts::Location::Aboard { vehicle, .. } => rode = Some(vehicle),
                    city_contracts::Location::InRoom { .. } if stepped_off.is_none() => {
                        stepped_off = Some((s.tick(), rode.clone()));
                    }
                    _ => {}
                }
            }
            let expected = if join_at == 1 {
                (6, "vehicle:boulevard:east:1")
            } else {
                (36, "vehicle:boulevard:east:2")
            };
            assert_eq!(
                stepped_off,
                Some((expected.0, Some(expected.1.into()))),
                "joining at {join_at}"
            );
            assert_eq!(
                player_location(&s),
                in_room("room:tram-stop"),
                "joining at {join_at}"
            );
            assert_eq!(json(&s.violations_json()), json!([]));
        }
    }

    /// A player joining at launch must not stand about for half a minute
    /// with nothing to see: a tram enters at the start of the day, the
    /// player boards it at once, and it steps off at the Square within ten
    /// ticks.
    #[test]
    fn a_launch_join_steps_off_at_the_square_within_ten_ticks() {
        let mut s = loaded();
        s.set_checking(true);
        s.join("registered", "1,1");
        let mut stepped_off = None;
        while s.tick() < 60 && stepped_off.is_none() {
            s.step();
            if matches!(player_location(&s), city_contracts::Location::InRoom { .. }) {
                stepped_off = Some(s.tick());
            }
        }
        let tick = stepped_off.expect("it stepped off");
        assert!(tick <= 10, "stepped off at tick {tick}");
        assert_eq!(player_location(&s), in_room("room:tram-stop"));
        assert_eq!(json(&s.violations_json()), json!([]));
    }

    #[test]
    fn joining_by_tram_rides_in_and_steps_off_at_the_tram_stop() {
        let mut s = tram_session();
        assert_eq!(json(&s.join("registered", "1,1"))["ok"], true);
        step_to(&mut s, 1);
        assert_eq!(
            player_location(&s),
            city_contracts::Location::Arriving {
                room: "room:north-a".into()
            }
        );
        // At 1, west:1 enters first (15), but east:1 (entering at 30) stands
        // at A from 33, long before west:1 has run the line to it: the
        // player rides east:1 and steps off on A's north platform, the tram
        // stop. It sits mid-car, in the seat nearest the tram's middle.
        step_to(&mut s, 30);
        assert_eq!(
            player_location(&s),
            city_contracts::Location::Aboard {
                vehicle: "vehicle:boulevard:east:1".into(),
                slot: 16
            }
        );
        step_to(&mut s, 90);
        assert_eq!(player_location(&s), in_room("room:north-a"));
        assert_eq!(json(&s.violations_json()), json!([]));
        assert_eq!(json(&s.replay_json())["identical"], true);
    }

    #[test]
    fn a_joining_player_takes_the_soonest_tram_whatever_the_crowd() {
        let mut s = Session::default();
        let r = json(&s.load(&tram_manifest(), TRAM_FEED, 1, 100));
        assert_eq!(r["ok"], true, "{r}");
        s.set_checking(true);
        step_to(&mut s, 16);
        // Three of the crowd have come by tram so far, so taking turns at
        // the portals would send the next arrival west, on west:2 at 45.
        assert_eq!(s.world.as_ref().unwrap().riders().arrival_counts[0] % 2, 1);
        s.join("registered", "1,1");
        // At 17, east:1 (entering at 30) is the first to reach A, at 33.
        step_to(&mut s, 30);
        assert!(matches!(
            player_location(&s),
            city_contracts::Location::Aboard { vehicle, .. }
                if vehicle.as_str() == "vehicle:boulevard:east:1"
        ));
        step_to(&mut s, 17 + 30);
        assert_eq!(player_location(&s), in_room("room:north-a"));
        assert_eq!(json(&s.violations_json()), json!([]));
    }

    #[test]
    fn a_player_boards_and_alights_from_its_session() {
        let mut s = tram_session();
        // The player rides in on east:1, the first to reach A.
        s.join("registered", "1,1");
        step_to(&mut s, 40);
        // East:1 still stands at A (doors open until 45): Board takes the
        // player aboard at once.
        assert_eq!(json(&s.board()), json!({"ok": true}));
        step_to(&mut s, 41);
        assert!(matches!(
            player_location(&s),
            city_contracts::Location::Aboard { .. }
        ));
        // At B (doors open from 47) the player steps off on request.
        step_to(&mut s, 47);
        assert_eq!(json(&s.alight()), json!({"ok": true}));
        step_to(&mut s, 48);
        assert_eq!(player_location(&s), in_room("room:north-b"));
        assert_eq!(json(&s.violations_json()), json!([]));
        assert_eq!(json(&s.replay_json())["identical"], true);
        let log = s.input_log_jsonl();
        assert!(log.contains("\"Board\"") && log.contains("\"Alight\""));
    }

    #[test]
    fn board_and_alight_follow_the_authority_rule() {
        let mut s = tram_session();
        assert_eq!(json(&s.board())["error"]["code"], "not-joined");
        assert_eq!(json(&s.alight())["error"]["code"], "not-joined");
        s.join("registered", "1,1");
        let board = |who: &str| json!({"type": "Board", "occupant": who}).to_string();
        let alight = |who: &str| json!({"type": "Alight", "occupant": who}).to_string();
        assert_eq!(
            json(&s.command(&board("agent:kai")))["error"]["code"],
            "not-yours"
        );
        assert_eq!(
            json(&s.command(&alight("agent:kai")))["error"]["code"],
            "not-yours"
        );
        assert_eq!(json(&s.command(&board(PLAYER_ID))), json!({"ok": true}));
        assert_eq!(json(&s.command(&alight(PLAYER_ID))), json!({"ok": true}));
        let feed = city_core::parse_feed(&s.input_log_jsonl()).expect("a feed");
        let types: Vec<CommandType> = feed
            .entries
            .iter()
            .map(|e| e.command.command_type())
            .collect();
        assert_eq!(
            types,
            [CommandType::Arrive, CommandType::Board, CommandType::Alight]
        );
    }

    #[test]
    fn the_players_own_events_are_taken_once_each() {
        let mut s = tram_session();
        assert_eq!(json(&s.take_player_events_json()), json!([]));
        s.join("registered", "1,1");
        step_to(&mut s, 10);
        // Still waiting beyond the city for its tram in: not aboard.
        assert_eq!(json(&s.alight()), json!({"ok": true}));
        step_to(&mut s, 11);
        let events = json(&s.take_player_events_json());
        let events = events.as_array().expect("an array");
        assert!(
            events.iter().all(|e| e["occupant"] == PLAYER_ID),
            "only the player's own: {events:?}"
        );
        assert!(
            events.iter().all(|e| e.get("seq").is_none()),
            "no place in the whole run's log: {events:?}"
        );
        assert!(
            events.iter().any(|e| e["kind"]
                == json!({"type": "Rejected", "command": "Alight", "reason": "NotAboard"})),
            "the refusal is there: {events:?}"
        );
        assert_eq!(json(&s.take_player_events_json()), json!([]), "taken once");
        // Riding in and stepping off at A are the player's own events too.
        step_to(&mut s, 40);
        let kinds: Vec<Value> = json(&s.take_player_events_json())
            .as_array()
            .unwrap()
            .iter()
            .map(|e| e["kind"]["type"].clone())
            .collect();
        assert!(kinds.contains(&json!("Alighted")), "{kinds:?}");
    }

    #[test]
    fn a_broken_replay_is_reported() {
        let s = Session::default();
        assert_eq!(json(&s.replay_json())["error"]["code"], "not-loaded");
        assert_eq!(json(&s.violations_json()), json!([]));
    }
}
