# City World Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a headless, deterministic, style-agnostic Rust simulation of who is where in the city: occupants arriving, being seated by capacity, overflowing, waiting, moving through doors, showing honest presence and leaving. Every viewer gets a projection that enforces privacy, and a CLI and an MCP server drive and inspect it.

**Architecture:** A Cargo workspace at `city/` with four crates. `city-contracts` holds every serialisable type and exports JSON Schema. `city-core` is pure rules: it takes a manifest, a parsed feed and a seed and advances fixed integer ticks over ordered maps, with no I/O, clock or threads, and it builds for `wasm32-unknown-unknown`. `city-cli` is a library of operations plus the `city` binary. `city-mcp` exposes the same library operations as MCP tools over stdio.

**Tech Stack:**

| Area | Choice |
| --- | --- |
| Language | Rust 1.95, edition 2024 |
| Data and schemas | `serde` 1, `serde_json` 1, `schemars` 1.2 |
| Randomness | `rand_chacha` 0.10 and `rand_core` 0.10 (`default-features = false`; the trait is `rand_core::Rng`) |
| Command line | `clap` 4 (derive) |
| MCP | `rmcp` 3.4 (`server`, `macros`, `transport-io`; `client` in tests) and `tokio` |
| Testing | `proptest` 1.11 |

**Spec:** `docs/superpowers/specs/2026-09-24-city-world-core-design.md`

## Global Constraints

- The workspace lives at `city/` in the agentnagar repository, beside `prototypes/`. All commands run from `city/` unless stated.
- `city-core` has **no** file, network, clock, thread or environment use. It must build with `cargo build -p city-core --target wasm32-unknown-unknown`.
- **Determinism:**
  - Simulation time is an integer tick count (`Tick = u64`).
  - All randomness comes from one `ChaCha8Rng` seeded from the run seed.
  - Every store is a `BTreeMap`, `BTreeSet` or ordered `Vec`. Do not use `HashMap` or `HashSet` in `city-contracts` or `city-core`.
  - No `f32` or `f64` in `city-contracts` or `city-core`.
- No ECS framework.
- Every contract carries `schema_version`, with `SCHEMA_VERSION = 1`.
- **Fixtures:**
  - A feed declares `fixture` in its header, and every entry repeats it.
  - Every event is tagged `fixture`.
  - Nothing reads real agent state.
- **Occupant kinds** (exact names): `GuildAgent`, `CityRoleAgent`, `PersonalAgent`, `SimCitizen`, `Human`.
- **Presence value names** (exact):

  | Dimension | Values |
  | --- | --- |
  | Connection | `Connected`, `Disconnected`, `Unknown` |
  | Process | `Running`, `Stopped`, `Error`, `Unknown` |
  | Task | `Working`, `Waiting`, `Queued`, `Idle`, `Done`, `Unknown` |

  Each shown dimension adds `Stale`.
- **Tick order**: Ingest, Expire, Admit, Allocate, Transition, Depart, Emit.
- **Operator projection** requires an explicit operator flag on both the CLI (`--operator`) and MCP (`operator: true`).
- The CLI writes JSON to stdout. Exit codes:

  | Code | Meaning |
  | --- | --- |
  | `0` | Success |
  | `1` | Domain failure: invalid manifest, not found, refused |
  | `2` | Bad input: unreadable file, unparsable JSON, bad arguments |

- `run` writes only inside the caller-named `--out` directory.
- Validation is `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings` and `cargo test --workspace`, plus the wasm build. `city/scripts/check.sh` runs all four.
- Nothing here is player-facing or "accepted". Documentation must say that fixture feeds are fixtures and that no real agent state is read.

## Review Focus

These are situations the spec implies, but that no single spec test names:

- **An out-of-date observation arrives after a newer one.** The newer observation must stay. An older `observed_at` never overwrites a newer one. Pinned in Task 4.
- **A personal agent's existence leaks through counts.** Public projections must not reveal hidden occupants through occupancy numbers or seat holders. Projections carry no occupancy counts, and seats carry no holder. Pinned in Task 8.
- **A reserved seat's owner arrives at a room full of other people.** They must still get in: capacity is held for absent reserved owners. Pinned in Task 6.
- **Commands referring to things that do not exist.** Unknown occupants, unknown rooms, departing twice, and moving while not in a room each produce a `Rejected` event with a reason and never panic. Pinned in Tasks 6 and 7, and fuzzed in Task 10.
- **An operator view reached without the flag.** `inspect --viewer operator` without `--operator` must fail with exit 1, and MCP `inspect` must fail without `operator: true`. Pinned in Tasks 11 and 12.

---

## File structure

```
city/
  Cargo.toml                         workspace
  .gitignore                         target/
  README.md                          what this is, commands, fixture honesty, scale results
  scripts/check.sh                   fmt + clippy + test + wasm build
  fixtures/two-room/manifest.json    the gate manifest
  fixtures/two-room/feed.jsonl       the gate feed (fixture)
  crates/city-contracts/src/
    lib.rs        re-exports, SCHEMA_VERSION, all_schemas()
    ids.rs        CityId, PlaceId, Tick
    manifest.rs   Manifest, City, District, Facility, Room, Pod, Seat, Door, TickRange, SeatPolicyName
    occupant.rs   OccupantProfile, OccupantKind, HumanTier
    presence.rs   observations, shown presence, Headline, Dimension
    feed.rs       FeedHeader, FeedEntry, FeedRecord, Command, CommandType
    event.rs      Event, EventKind, RejectReason
    snapshot.rs   Snapshot, OccupantState, Location, RoomState
    projection.rs Viewer, Projection, RoomView, SeatView, OccupantView, Badge
    report.rs     ValidationReport, ValidationIssue, SnapshotDiff, Change, RunSummary
  crates/city-core/src/
    lib.rs        module wiring and re-exports
    index.rs      PlaceIndex::build — manifest structural validation
    feed.rs       parse_feed
    presence.rs   apply_observation, derive_shown
    policy.rs     choose_seat
    world.rs      World: the tick loop
    project.rs    project(snapshot, viewer)
    diff.rs       diff(a, b)
    invariants.rs check_* functions used by tests
    synth.rs      synthetic manifest + feed generator for scale runs
  crates/city-core/tests/
    scenarios.rs  named scenario tests + gate
    invariants.rs proptest of the seven invariants
  crates/city-cli/src/
    lib.rs        pub mod commands
    commands.rs   validate/run/inspect/diff/schema -> Outcome (shared with MCP)
    main.rs       clap front end
  crates/city-cli/tests/cli.rs
  crates/city-cli/examples/scale.rs
  crates/city-mcp/src/main.rs, src/lib.rs (CityServer)
  crates/city-mcp/tests/mcp.rs
```

`city-mcp` depends on the `city-cli` library, not directly on `city-core`, so the two interfaces share one implementation of every operation, including file handling. This refines the spec's crate table, which lists `city-core` for both.

---

### Task 1: Workspace and contracts

**Files:**
- Create: `city/Cargo.toml`, `city/.gitignore`, `city/crates/city-contracts/Cargo.toml`, and every `src/*.rs` listed above for city-contracts.
- Test: `city/crates/city-contracts/tests/contracts.rs`

**Interfaces:**
- Produces: every type named in the file structure, all `#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]`, plus the following:
  - `Ord` on ID types.
  - `pub fn all_schemas() -> BTreeMap<String, serde_json::Value>`, keyed by `manifest`, `feed-record`, `command`, `event`, `snapshot`, `viewer`, `projection`, `snapshot-diff`, `validation-report` and `run-summary`.
  - `pub const SCHEMA_VERSION: u32 = 1`.

- [ ] **Step 1: Workspace manifest**

`city/Cargo.toml`:

```toml
[workspace]
resolver = "3"
members = ["crates/city-contracts", "crates/city-core", "crates/city-cli", "crates/city-mcp"]

[workspace.package]
edition = "2024"
rust-version = "1.95"
license = "MIT"
publish = false

[workspace.dependencies]
city-contracts = { path = "crates/city-contracts" }
city-core = { path = "crates/city-core" }
city-cli = { path = "crates/city-cli" }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
schemars = "1.2"
rand_chacha = { version = "0.10", default-features = false }
rand_core = { version = "0.10", default-features = false }
clap = { version = "4.6", features = ["derive"] }
proptest = "1.11"
rmcp = { version = "3.4", features = ["server", "macros", "transport-io"] }
tokio = { version = "1", features = ["macros", "rt-multi-thread", "io-std", "io-util"] }
```

Create the members' `Cargo.toml` files as each task introduces them. In Task 1, list only `crates/city-contracts` in `members`, and add the others when their tasks create them.

- [ ] **Step 2: Write the failing contract tests**

`city/crates/city-contracts/tests/contracts.rs`:

```rust
use city_contracts::*;

#[test]
fn manifest_round_trips_with_defaults() {
    let json = r#"{
      "schema_version": 1,
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
    assert_eq!(k, OccupantKind::PersonalAgent { owner: CityId::from("person:asha") });
}

#[test]
fn feed_records_are_tagged() {
    let h: FeedRecord = serde_json::from_str(
        r#"{"record":"header","schema_version":1,"source":"fixture:t","fixture":true}"#,
    )
    .unwrap();
    assert!(matches!(h, FeedRecord::Header(FeedHeader { fixture: true, .. })));
    let e: FeedRecord = serde_json::from_str(
        r#"{"record":"entry","at":3,"fixture":true,
            "command":{"type":"Observe","occupant":"agent:kai",
              "observation":{"dimension":"Task","value":{"state":"Working"},
                "stamp":{"observed_at":3,"fetched_at":3,"expires_at":9,"source":"s","source_version":"1"}}}}"#,
    )
    .unwrap();
    let FeedRecord::Entry(entry) = e else { panic!("entry") };
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
    for name in ["manifest", "feed-record", "command", "event", "snapshot", "viewer",
                 "projection", "snapshot-diff", "validation-report", "run-summary"] {
        let s = schemas.get(name).unwrap_or_else(|| panic!("missing {name}"));
        assert!(s.get("$schema").is_some(), "{name} is not a schema");
    }
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `cargo test -p city-contracts`
Expected: compile errors for unresolved names (`Manifest`, `OccupantKind` and so on).

- [ ] **Step 4: Implement the contracts**

`city/crates/city-contracts/Cargo.toml`:

```toml
[package]
name = "city-contracts"
version = "0.1.0"
edition.workspace = true
rust-version.workspace = true
license.workspace = true
publish.workspace = true

[dependencies]
serde.workspace = true
serde_json.workspace = true
schemars.workspace = true
```

Implement each module with exactly these types. Every type derives `Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema`, and `Default` where one is noted. Every `Option`, `Vec`, `BTreeMap` and `BTreeSet` field and every `bool` flag carries `#[serde(default)]`, and optional fields also `skip_serializing_if` where noted.

`ids.rs`:

```rust
pub type Tick = u64;

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(transparent)]
pub struct CityId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize, JsonSchema)]
#[serde(transparent)]
pub struct PlaceId(pub String);
// For both: impl From<&str>, impl From<String>, impl Display (writes the inner string),
// and `pub fn as_str(&self) -> &str`.
```

`manifest.rs`:

```rust
pub struct Manifest { pub schema_version: u32, pub city: City,
    #[serde(default)] pub seat_policy: SeatPolicyName,
    #[serde(default)] pub occupants: Vec<OccupantProfile> }
pub struct City { pub id: PlaceId, pub name: String, pub districts: Vec<District> }
pub struct District { pub id: PlaceId, pub name: String, pub facilities: Vec<Facility> }
pub struct Facility { pub id: PlaceId, pub name: String, pub rooms: Vec<Room> }
pub struct Room { pub id: PlaceId, pub name: String, pub capacity: u32,
    #[serde(default)] pub pods: Vec<Pod>, #[serde(default)] pub seats: Vec<Seat>,
    #[serde(default)] pub overflow: Option<PlaceId>, #[serde(default)] pub doors: Vec<Door> }
pub struct Pod { pub id: PlaceId, #[serde(default)] pub department: Option<String> }
/// Hot when `reserved_for` is None; Reserved for exactly that occupant otherwise.
pub struct Seat { pub id: PlaceId, #[serde(default)] pub pod: Option<PlaceId>,
    #[serde(default)] pub reserved_for: Option<CityId> }
pub struct Door { pub id: PlaceId, pub to: PlaceId, pub transit: TickRange }
pub struct TickRange { pub min: Tick, pub max: Tick }
#[derive(Default)] #[serde(rename_all = "kebab-case")]
pub enum SeatPolicyName { #[default] DepartmentFirst }
```

`occupant.rs`:

```rust
pub struct OccupantProfile { pub id: CityId, pub kind: OccupantKind, pub display_name: String,
    #[serde(default)] pub role: String, #[serde(default)] pub department: Option<String>,
    #[serde(default)] pub home: Option<PlaceId>, #[serde(default)] pub work: Option<PlaceId>,
    #[serde(default)] pub shared_with: BTreeSet<CityId>,
    /// Opaque to the core; a style pack interprets it.
    #[serde(default)] pub appearance: BTreeMap<String, String> }
#[serde(tag = "type")]
pub enum OccupantKind { GuildAgent, CityRoleAgent, PersonalAgent { owner: CityId }, SimCitizen,
    Human { tier: HumanTier } }
pub enum HumanTier { Observer, Registered, Resident }
impl OccupantKind { pub fn is_agent(&self) -> bool /* Guild, CityRole, Personal */ }
```

`presence.rs`:

```rust
pub enum ConnectionState { Connected, Disconnected, Unknown }
pub enum ProcessState { Running, Stopped, Error, Unknown }
pub enum TaskState { Working, Waiting, Queued, Idle, Done, Unknown }
pub struct Stamp { pub observed_at: Tick, pub fetched_at: Tick, pub expires_at: Tick,
    pub source: String, pub source_version: String }
pub struct TaskReport { pub state: TaskState,
    #[serde(default, skip_serializing_if = "Option::is_none")] pub summary: Option<String>,
    #[serde(default)] pub summary_public: bool }
pub struct Observed<T> { pub value: T, pub stamp: Stamp }
#[serde(tag = "dimension")]
pub enum Observation { Connection(Observed<ConnectionState>), Process(Observed<ProcessState>),
    Task(Observed<TaskReport>) }
#[derive(Default)]
pub struct PresenceRecord {
    #[serde(default, skip_serializing_if = "Option::is_none")] pub connection: Option<Observed<ConnectionState>>,
    #[serde(default, skip_serializing_if = "Option::is_none")] pub process: Option<Observed<ProcessState>>,
    #[serde(default, skip_serializing_if = "Option::is_none")] pub task: Option<Observed<TaskReport>> }
#[derive(Default)] pub enum ShownConnection { Connected, Disconnected, #[default] Unknown, Stale }
#[derive(Default)] pub enum ShownProcess { Running, Stopped, Error, #[default] Unknown, Stale }
#[derive(Default)] pub enum ShownTask { Working, Waiting, Queued, Idle, Done, #[default] Unknown, Stale }
#[derive(Default)] pub enum Headline { Working, Waiting, Queued, Idle, Done, Present, Offline, Error,
    Stale, #[default] Unknown }
#[derive(Default)] pub struct ShownPresence { pub headline: Headline, pub connection: ShownConnection,
    pub process: ShownProcess, pub task: ShownTask }
#[derive(PartialOrd, Ord)] pub enum Dimension { Connection, Process, Task }
```

`feed.rs`:

```rust
pub struct FeedHeader { pub schema_version: u32, pub source: String, pub fixture: bool,
    #[serde(default)] pub description: String }
pub struct FeedEntry { pub at: Tick, pub fixture: bool, pub command: Command }
#[serde(tag = "record", rename_all = "lowercase")]
pub enum FeedRecord { Header(FeedHeader), Entry(FeedEntry) }
#[serde(tag = "type")]
pub enum Command {
    Arrive { occupant: CityId, #[serde(default)] profile: Option<OccupantProfile>,
             #[serde(default)] room: Option<PlaceId> },
    Depart { occupant: CityId },
    Move { occupant: CityId, to: PlaceId },
    Observe { occupant: CityId, observation: Observation },
    Share { occupant: CityId, grantee: CityId },
    Unshare { occupant: CityId, grantee: CityId },
}
#[derive(Copy)] pub enum CommandType { Arrive, Depart, Move, Observe, Share, Unshare }
impl Command { pub fn command_type(&self) -> CommandType; pub fn occupant(&self) -> &CityId }
```

`event.rs`:

```rust
pub struct Event { pub tick: Tick, pub seq: u64, pub fixture: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")] pub occupant: Option<CityId>,
    pub kind: EventKind }
#[serde(tag = "type")]
pub enum EventKind {
    Arrived { room: PlaceId }, Admitted { room: PlaceId },
    Overflowed { from: PlaceId, to: PlaceId }, Waitlisted { room: PlaceId, position: u32 },
    Seated { room: PlaceId, seat: PlaceId }, SeatReleased { room: PlaceId, seat: PlaceId },
    TransitStarted { from: PlaceId, to: PlaceId, door: PlaceId, arrives_at: Tick },
    TransitEnded { to: PlaceId },
    Departed { #[serde(default)] from: Option<PlaceId> },
    ObservationExpired { dimension: Dimension },
    PresenceChanged { shown: ShownPresence },
    Shared { grantee: CityId }, Unshared { grantee: CityId },
    Rejected { command: CommandType, reason: RejectReason },
}
pub enum RejectReason { UnknownOccupant, UnknownRoom, AlreadyPresent, NotPresent, NotInRoom,
    NoDoor, NoTargetRoom, NotPersonalAgent, InvalidObservation, ProfileMismatch }
```

`snapshot.rs`:

```rust
pub struct Snapshot { pub schema_version: u32, pub tick: Tick, pub seed: u64, pub fixture: bool,
    pub manifest: Manifest, pub occupants: BTreeMap<CityId, OccupantState>,
    pub rooms: BTreeMap<PlaceId, RoomState>, pub admission_queue: Vec<CityId>, pub next_seq: u64 }
pub struct OccupantState { pub profile: OccupantProfile, pub location: Location,
    pub presence: PresenceRecord, pub shown: ShownPresence }
#[serde(tag = "state")]
pub enum Location { Away, Arriving { room: PlaceId }, InRoom { room: PlaceId, seat: Option<PlaceId> },
    Waitlisted { room: PlaceId },
    InTransit { from: PlaceId, to: PlaceId, door: PlaceId, arrives_at: Tick } }
/// `occupants` is in admission order; `seats` maps every seat of the room to its holder.
pub struct RoomState { pub occupants: Vec<CityId>, pub seats: BTreeMap<PlaceId, Option<CityId>>,
    pub waitlist: Vec<CityId> }
```

`projection.rs`:

```rust
#[serde(tag = "type")] pub enum Viewer { Public, Person { id: CityId }, Operator }
pub struct Projection { pub schema_version: u32, pub tick: Tick, pub fixture: bool, pub viewer: Viewer,
    pub rooms: Vec<RoomView>, pub in_transit: Vec<OccupantView> }
/// No occupancy count: counts would reveal occupants this viewer may not see.
pub struct RoomView { pub id: PlaceId, pub name: String, pub facility: PlaceId, pub capacity: u32,
    pub seats: Vec<SeatView>, pub occupants: Vec<OccupantView>, pub waiting: Vec<OccupantView> }
/// No holder: seat occupancy is carried by OccupantView.seat for visible occupants only.
pub struct SeatView { pub id: PlaceId, pub pod: Option<PlaceId>, pub department: Option<String>,
    pub reserved: bool }
pub struct OccupantView { pub id: CityId, pub kind: OccupantKind, pub display_name: String,
    pub role: String, pub badge: Option<Badge>, pub appearance: BTreeMap<String, String>,
    pub seat: Option<PlaceId>, pub presence: ShownPresence,
    #[serde(default, skip_serializing_if = "Option::is_none")] pub task_summary: Option<String> }
pub enum Badge { Ai, Simulation }
```

`report.rs`:

```rust
pub struct ValidationIssue { pub code: String,
    #[serde(default, skip_serializing_if = "Option::is_none")] pub place: Option<String>,
    pub message: String }
pub struct ValidationReport { pub valid: bool, pub issues: Vec<ValidationIssue> }
pub struct SnapshotDiff { pub from_tick: Tick, pub to_tick: Tick, pub changes: Vec<Change> }
#[serde(tag = "type")]
pub enum Change {
    OccupantAdded { occupant: CityId },
    LocationChanged { occupant: CityId, from: Location, to: Location },
    PresenceChanged { occupant: CityId, from: ShownPresence, to: ShownPresence },
    ProfileChanged { occupant: CityId },
}
pub struct RunSummary { pub schema_version: u32, pub seed: u64, pub ticks: Tick, pub fixture: bool,
    pub events: u64, pub rejected: u64, pub present: u64, pub snapshots: Vec<String> }
```

`lib.rs` declares the modules, `pub use`s every type, defines `SCHEMA_VERSION`, and:

```rust
pub fn all_schemas() -> BTreeMap<String, serde_json::Value> {
    let mut m = BTreeMap::new();
    let mut put = |k: &str, s: schemars::Schema| { m.insert(k.to_string(), s.to_value()); };
    put("manifest", schemars::schema_for!(Manifest));
    put("feed-record", schemars::schema_for!(FeedRecord));
    put("command", schemars::schema_for!(Command));
    put("event", schemars::schema_for!(Event));
    put("snapshot", schemars::schema_for!(Snapshot));
    put("viewer", schemars::schema_for!(Viewer));
    put("projection", schemars::schema_for!(Projection));
    put("snapshot-diff", schemars::schema_for!(SnapshotDiff));
    put("validation-report", schemars::schema_for!(ValidationReport));
    put("run-summary", schemars::schema_for!(RunSummary));
    m
}
```

`city/.gitignore` contains `target/`.

- [ ] **Step 5: Run the tests and see them pass**

Run: `cargo test -p city-contracts`
Expected: 5 passed.

- [ ] **Step 6: Commit**

```bash
git add city/
git commit -m "feat(city): add the city contracts crate"
```

---

### Task 2: Manifest structural validation (`PlaceIndex`)

**Files:**
- Create: `city/crates/city-core/Cargo.toml`, `src/lib.rs`, `src/index.rs`
- Modify: `city/Cargo.toml` (add the `crates/city-core` member)
- Test: unit tests in `src/index.rs` (`#[cfg(test)] mod tests`)

**Interfaces:**
- Consumes: `Manifest`, `ValidationIssue`, `SCHEMA_VERSION`.
- Produces:

```rust
pub struct SeatInfo { pub id: PlaceId, pub pod: Option<PlaceId>, pub department: Option<String>,
    pub reserved_for: Option<CityId> }
pub struct DoorInfo { pub id: PlaceId, pub to: PlaceId, pub transit: TickRange }
pub struct RoomInfo { pub id: PlaceId, pub name: String, pub facility: PlaceId, pub capacity: u32,
    pub seats: Vec<SeatInfo> /* sorted by id */, pub reserved: BTreeMap<CityId, PlaceId>,
    pub doors: BTreeMap<PlaceId /* to */, DoorInfo>,
    /// This room first, then its overflow, then that room's overflow, and so on.
    pub chain: Vec<PlaceId> }
pub struct PlaceIndex { pub rooms: BTreeMap<PlaceId, RoomInfo>,
    pub occupants: BTreeMap<CityId, OccupantProfile>, pub seat_policy: SeatPolicyName }
impl PlaceIndex { pub fn build(m: &Manifest) -> Result<PlaceIndex, Vec<ValidationIssue>> }
pub fn validate(m: &Manifest) -> ValidationReport
```

The following rules apply, each with its issue `code`. Collect every issue; do not stop at the first:

| Code | Rule |
| --- | --- |
| `schema-version` | `schema_version != SCHEMA_VERSION` |
| `duplicate-id` | A place ID appears twice anywhere in the tree, counting the city, districts, facilities, rooms, pods, seats and doors |
| `duplicate-occupant` | Two manifest occupants share a city ID |
| `zero-capacity` | A room's capacity is 0 |
| `unknown-pod` | A seat names a pod not in its room |
| `unknown-occupant` | `reserved_for` names an occupant that is not in `manifest.occupants` |
| `duplicate-reservation` | One occupant has two reserved seats in one room |
| `reservations-exceed-capacity` | A room's reserved seats outnumber its capacity |
| `unknown-room` | A door's `to`, a room's `overflow`, or an occupant's `home` or `work` is not a room |
| `door-to-self` | A door leads back to its own room |
| `bad-transit` | A door's `transit.min < 1` or `max < min` |
| `overflow-cycle` | Following overflow from any room revisits a room |

`validate` returns `valid = issues.is_empty()`.

- [ ] **Step 1: Write the failing tests**

In `src/index.rs`, add `#[cfg(test)] mod tests`. Use a helper `fn base() -> Manifest` that builds the following from JSON with `serde_json::from_value(json!(...))`:

- one district and one facility, holding two rooms;
- `room:a`: capacity 2, seats `seat:a1` in pod `pod:m` (department `making`) and `seat:a2` reserved for `agent:kai`, overflow to `room:b`, and a door `door:ab` to `room:b` with transit 1..2;
- `room:b`: capacity 1, seat `seat:b1`;
- occupant `agent:kai`, a GuildAgent with `work: room:a`.

Tests:

```rust
#[test] fn valid_manifest_builds_an_index() {
    let idx = PlaceIndex::build(&base()).unwrap();
    let a = &idx.rooms[&PlaceId::from("room:a")];
    assert_eq!(a.chain, vec![PlaceId::from("room:a"), PlaceId::from("room:b")]);
    assert_eq!(a.reserved[&CityId::from("agent:kai")], PlaceId::from("seat:a2"));
    assert_eq!(a.seats[0].department.as_deref(), Some("making"));
    assert!(validate(&base()).valid);
}
fn codes(m: &Manifest) -> Vec<String> { validate(m).issues.into_iter().map(|i| i.code).collect() }
#[test] fn rejects_overflow_cycle() { let mut m = base(); room_mut(&mut m, "room:b").overflow = Some("room:a".into());
    assert!(codes(&m).contains(&"overflow-cycle".to_string())); }
#[test] fn rejects_reservation_for_unknown_occupant() { let mut m = base(); m.occupants.clear();
    assert!(codes(&m).contains(&"unknown-occupant".to_string())); }
#[test] fn rejects_door_to_missing_room() { let mut m = base(); room_mut(&mut m, "room:a").doors[0].to = "room:zz".into();
    assert!(codes(&m).contains(&"unknown-room".to_string())); }
#[test] fn rejects_seat_in_unknown_pod() { let mut m = base(); room_mut(&mut m, "room:b").seats[0].pod = Some("pod:m".into());
    assert!(codes(&m).contains(&"unknown-pod".to_string())); }
#[test] fn rejects_duplicate_ids() { let mut m = base(); room_mut(&mut m, "room:b").seats[0].id = "seat:a1".into();
    assert!(codes(&m).contains(&"duplicate-id".to_string())); }
#[test] fn rejects_too_many_reservations() { let mut m = base(); room_mut(&mut m, "room:a").capacity = 0;
    let c = codes(&m); assert!(c.contains(&"zero-capacity".to_string()));
    assert!(c.contains(&"reservations-exceed-capacity".to_string())); }
#[test] fn rejects_bad_transit_and_self_doors() { let mut m = base();
    let d = &mut room_mut(&mut m, "room:a").doors[0]; d.transit = TickRange { min: 0, max: 0 }; d.to = "room:a".into();
    let c = codes(&m); assert!(c.contains(&"bad-transit".to_string())); assert!(c.contains(&"door-to-self".to_string())); }
#[test] fn rejects_wrong_schema_version() { let mut m = base(); m.schema_version = 9;
    assert!(codes(&m).contains(&"schema-version".to_string())); }
```

`room_mut(&mut Manifest, &str) -> &mut Room` walks the tree to find a room by ID.

- [ ] **Step 2: Run and watch it fail**

Run: `cargo test -p city-core index`
Expected: compile error; `PlaceIndex` is undefined.

- [ ] **Step 3: Implement `index.rs`**

`city-core/Cargo.toml` depends on `city-contracts`, `serde`, `serde_json`, `rand_chacha` and `rand_core`, with `proptest` as a dev-dependency.

Walk the tree once. Collect place IDs into a `BTreeSet`, pushing `duplicate-id` on each repeat. Build `RoomInfo` per room: sort `seats` by ID, join each seat's pod department, fill `reserved` and `doors`. Then check references against the room set, occupant set and pod set. Compute `chain` for each room by following `overflow` with a visited set: if a room repeats, push `overflow-cycle` for the starting room and stop. Return `Err(issues)` if any issue exists. Each issue's `place` is the ID concerned, and its `message` is a plain English sentence.

- [ ] **Step 4: Run and see it pass**

Run: `cargo test -p city-core index`
Expected: 9 passed.

- [ ] **Step 5: Commit** with `feat(city): validate place manifests into a place index`.

---

### Task 3: Feed parsing

**Files:**
- Create: `city/crates/city-core/src/feed.rs`
- Test: unit tests in the same file

**Interfaces:**
- Produces:

```rust
pub struct Feed { pub header: FeedHeader, pub entries: Vec<FeedEntry> }
pub struct FeedError { pub line: usize /* 1-based */, pub message: String }
pub fn parse_feed(text: &str) -> Result<Feed, FeedError>
```

Parsing rules:

- Skip blank lines.
- The first record must be a header, and only one header is allowed.
- `header.schema_version == SCHEMA_VERSION`.
- Every entry's `fixture` equals the header's `fixture`, so fixture and real data can never mix in one feed.
- `at` is non-decreasing.

- [ ] **Step 1: Write the failing tests**

```rust
const H: &str = r#"{"record":"header","schema_version":1,"source":"fixture:t","fixture":true}"#;
fn arrive(at: u64, fixture: bool) -> String { format!(
  r#"{{"record":"entry","at":{at},"fixture":{fixture},"command":{{"type":"Depart","occupant":"agent:kai"}}}}"#) }
#[test] fn parses_header_and_entries() {
    let f = parse_feed(&format!("{H}\n\n{}\n{}\n", arrive(0, true), arrive(2, true))).unwrap();
    assert!(f.header.fixture); assert_eq!(f.entries.len(), 2); assert_eq!(f.entries[1].at, 2); }
#[test] fn requires_header_first() { let e = parse_feed(&arrive(0, true)).unwrap_err(); assert_eq!(e.line, 1); }
#[test] fn rejects_mixed_fixture_flags() {
    let e = parse_feed(&format!("{H}\n{}", arrive(0, false))).unwrap_err();
    assert_eq!(e.line, 2); assert!(e.message.contains("fixture")); }
#[test] fn rejects_out_of_order_ticks() {
    let e = parse_feed(&format!("{H}\n{}\n{}", arrive(5, true), arrive(4, true))).unwrap_err(); assert_eq!(e.line, 3); }
#[test] fn rejects_second_header_and_bad_json() {
    assert_eq!(parse_feed(&format!("{H}\n{H}")).unwrap_err().line, 2);
    assert_eq!(parse_feed(&format!("{H}\nnot json")).unwrap_err().line, 2); }
```

- [ ] **Step 2: Run and watch it fail.** Run `cargo test -p city-core feed`; it should fail to compile.
- [ ] **Step 3: Implement.** Iterate `text.lines().enumerate()`, parse each non-blank line as `FeedRecord` with `serde_json::from_str`, and apply the rules above. The message for a mismatched fixture flag must contain the word "fixture".
- [ ] **Step 4: Run and see it pass.** Expect 5 passed.
- [ ] **Step 5: Commit** with `feat(city): parse labelled presence feeds`.

---

### Task 4: Honest presence

**Files:**
- Create: `city/crates/city-core/src/presence.rs`
- Test: unit tests in the same file

**Interfaces:**
- Produces:

```rust
/// Validates the stamp and stores the observation unless a newer one (by observed_at) is held.
pub fn apply_observation(rec: &mut PresenceRecord, obs: Observation, now: Tick) -> Result<bool, RejectReason>
pub fn derive_shown(kind: &OccupantKind, rec: &PresenceRecord, now: Tick) -> ShownPresence
pub fn is_expired(stamp: &Stamp, now: Tick) -> bool   // now >= expires_at
```

Stamp validation (`InvalidObservation`): `observed_at <= fetched_at < expires_at` and `observed_at <= now`. `Ok(true)` means stored, `Ok(false)` means ignored because it is older than the observation already held. When the `observed_at` values are equal, the later arrival wins.

The `expires_at` bound is **exclusive**: at `now == expires_at` the dimension is already `Stale`.

`derive_shown` maps each dimension: `None` becomes `Unknown`, an expired observation becomes `Stale`, and anything else becomes the matching shown value. The headline is derived by these rules:

- **Human:** `Connected` gives `Present`, `Disconnected` gives `Offline`, `Stale` gives `Stale`, `Unknown` gives `Unknown`.
- **Everyone else:** apply the first matching rule, in order.
  1. connection `Disconnected` gives `Offline`
  2. process `Stopped` gives `Offline`
  3. process `Error` gives `Error`
  4. any dimension `Stale` gives `Stale`
  5. process not `Running` gives `Unknown`
  6. task `Unknown` gives `Unknown`
  7. otherwise the task state (`Working`, `Waiting`, `Queued`, `Idle` or `Done`)

- [ ] **Step 1: Write the failing tests**

```rust
fn st(o: u64, e: u64) -> Stamp { Stamp { observed_at: o, fetched_at: o, expires_at: e, source: "fixture".into(), source_version: "1".into() } }
fn agent() -> OccupantKind { OccupantKind::GuildAgent }
fn running(o: u64, e: u64) -> Observation { Observation::Process(Observed { value: ProcessState::Running, stamp: st(o, e) }) }
fn task(s: TaskState, o: u64, e: u64) -> Observation { Observation::Task(Observed { value: TaskReport { state: s, summary: None, summary_public: false }, stamp: st(o, e) }) }

#[test] fn running_without_task_is_unknown_not_working() {
    let mut r = PresenceRecord::default(); apply_observation(&mut r, running(0, 10), 0).unwrap();
    let s = derive_shown(&agent(), &r, 1);
    assert_eq!(s.task, ShownTask::Unknown); assert_eq!(s.headline, Headline::Unknown); }
#[test] fn running_and_working_is_working() {
    let mut r = PresenceRecord::default(); apply_observation(&mut r, running(0, 10), 0).unwrap();
    apply_observation(&mut r, task(TaskState::Working, 0, 10), 0).unwrap();
    assert_eq!(derive_shown(&agent(), &r, 1).headline, Headline::Working); }
#[test] fn expired_task_is_stale_never_last_value() {
    let mut r = PresenceRecord::default(); apply_observation(&mut r, running(0, 100), 0).unwrap();
    apply_observation(&mut r, task(TaskState::Working, 0, 5), 0).unwrap();
    assert_eq!(derive_shown(&agent(), &r, 4).task, ShownTask::Working);
    let s = derive_shown(&agent(), &r, 5); assert_eq!(s.task, ShownTask::Stale); assert_eq!(s.headline, Headline::Stale); }
#[test] fn idle_stale_offline_unknown_are_distinct() {
    let mut idle = PresenceRecord::default(); apply_observation(&mut idle, running(0, 9), 0).unwrap();
    apply_observation(&mut idle, task(TaskState::Idle, 0, 9), 0).unwrap();
    let mut off = PresenceRecord::default();
    apply_observation(&mut off, Observation::Connection(Observed { value: ConnectionState::Disconnected, stamp: st(0, 9) }), 0).unwrap();
    let hs = [derive_shown(&agent(), &idle, 1).headline, derive_shown(&agent(), &idle, 9).headline,
              derive_shown(&agent(), &off, 1).headline, derive_shown(&agent(), &PresenceRecord::default(), 1).headline];
    assert_eq!(hs, [Headline::Idle, Headline::Stale, Headline::Offline, Headline::Unknown]); }
#[test] fn older_observation_never_overwrites_newer() {
    let mut r = PresenceRecord::default(); apply_observation(&mut r, running(0, 50), 6).unwrap();
    apply_observation(&mut r, task(TaskState::Done, 6, 50), 6).unwrap();
    assert_eq!(apply_observation(&mut r, task(TaskState::Working, 3, 50), 7), Ok(false));
    assert_eq!(derive_shown(&agent(), &r, 7).task, ShownTask::Done); }
#[test] fn rejects_impossible_stamps() {
    let mut r = PresenceRecord::default();
    assert_eq!(apply_observation(&mut r, running(5, 5), 5), Err(RejectReason::InvalidObservation));
    assert_eq!(apply_observation(&mut r, running(9, 20), 5), Err(RejectReason::InvalidObservation)); }
#[test] fn humans_show_present_from_connection() {
    let mut r = PresenceRecord::default();
    apply_observation(&mut r, Observation::Connection(Observed { value: ConnectionState::Connected, stamp: st(0, 9) }), 0).unwrap();
    let h = OccupantKind::Human { tier: HumanTier::Registered };
    assert_eq!(derive_shown(&h, &r, 1).headline, Headline::Present);
    assert_eq!(derive_shown(&h, &r, 9).headline, Headline::Stale); }
```

- [ ] **Step 2: Run and watch it fail.** Run `cargo test -p city-core presence`.
- [ ] **Step 3: Implement** using the rules above, with a small generic helper `fn store<T>(slot: &mut Option<Observed<T>>, new: Observed<T>) -> bool` for the newer-wins rule.
- [ ] **Step 4: Run and see it pass.** Expect 7 passed.
- [ ] **Step 5: Commit** with `feat(city): derive honest shown presence`.

---

### Task 5: Seat policy

**Files:**
- Create: `city/crates/city-core/src/policy.rs`
- Test: unit tests in the same file

**Interfaces:**
- Consumes: `SeatInfo` (Task 2) and `SeatPolicyName`.
- Produces:

```rust
/// `free` = the room's hot seats with no holder, in seat-ID order.
pub fn choose_seat(policy: SeatPolicyName, department: Option<&str>, free: &[&SeatInfo]) -> Option<PlaceId>
```

`DepartmentFirst` works as follows:

- If any free seat is in a pod whose department equals the occupant's, restrict the candidates to those seats.
- For each candidate, count the free seats in its pod among the candidates. A seat with no pod counts as a pod of 1.
- Choose the minimum by `(Reverse(free_in_pod), seat_id)`.

- [ ] **Step 1: Write the failing tests**

```rust
fn s(id: &str, pod: Option<&str>, dept: Option<&str>) -> SeatInfo { SeatInfo { id: id.into(), pod: pod.map(Into::into), department: dept.map(Into::into), reserved_for: None } }
#[test] fn prefers_own_department_pod() {
    let (a, b, c) = (s("seat:1", Some("pod:k"), Some("knowledge")), s("seat:2", Some("pod:m"), Some("making")), s("seat:3", Some("pod:k"), Some("knowledge")));
    assert_eq!(choose_seat(SeatPolicyName::DepartmentFirst, Some("making"), &[&a, &b, &c]), Some("seat:2".into())); }
#[test] fn otherwise_pod_with_most_free_seats() {
    let (a, b, c) = (s("seat:1", Some("pod:x"), None), s("seat:2", Some("pod:y"), None), s("seat:3", Some("pod:y"), None));
    assert_eq!(choose_seat(SeatPolicyName::DepartmentFirst, Some("making"), &[&a, &b, &c]), Some("seat:2".into())); }
#[test] fn ties_break_on_lowest_seat_id() {
    let (a, b) = (s("seat:2", None, None), s("seat:1", None, None));
    assert_eq!(choose_seat(SeatPolicyName::DepartmentFirst, None, &[&a, &b]), Some("seat:1".into())); }
#[test] fn no_free_seat_means_none() { assert_eq!(choose_seat(SeatPolicyName::DepartmentFirst, None, &[]), None); }
```

- [ ] **Step 2: Run and watch it fail.** Run `cargo test -p city-core policy`.
- [ ] **Step 3: Implement** the policy as specified above.
- [ ] **Step 4: Run and see it pass.** Expect 4 passed.
- [ ] **Step 5: Commit** with `feat(city): add the department-first seat policy`.

---

### Task 6: The world — arrival, admission, seating, overflow, waitlist, departure

**Files:**
- Create: `city/crates/city-core/src/world.rs`
- Create: `city/crates/city-core/tests/scenarios.rs`, with a shared test helper module `tests/common/mod.rs`

**Interfaces:**
- Consumes: `PlaceIndex`, `Feed`, `apply_observation`, `derive_shown`, `choose_seat`.
- Produces:

```rust
pub struct World { /* index, state: Snapshot, rng: ChaCha8Rng, entries: Vec<FeedEntry>, cursor: usize */ }
impl World {
    pub fn new(manifest: Manifest, feed: Feed, seed: u64) -> Result<World, Vec<ValidationIssue>>;
    /// Advances one tick (tick numbers start at 1) and returns that tick's events in order.
    pub fn step(&mut self) -> Vec<Event>;
    pub fn run(&mut self, ticks: Tick) -> Vec<Event>;
    pub fn snapshot(&self) -> &Snapshot;
    pub fn index(&self) -> &PlaceIndex;
}
```

`World::new` sets the state as follows:

- `tick = 0`;
- `fixture = feed.header.fixture`;
- `occupants`: each manifest occupant, with `Location::Away`, a default presence and a default shown presence;
- `rooms`: every room, with every seat set to `None`.

`step` increments `tick` to `t` and then runs the seven phases:

1. **Ingest.** Apply every entry with `at <= t`, in feed order. Each command either updates state and queues work, or emits `Rejected`:
   - `Arrive`:
     - If the occupant is unknown, register its profile; with no profile, reject `UnknownOccupant`.
     - If the occupant is known, a supplied profile must have the same `id` (otherwise reject `ProfileMismatch`) and replaces the stored one.
     - If the occupant is not `Away`, reject `AlreadyPresent`.
     - The target is `room`, falling back to `profile.work`. With neither, reject `NoTargetRoom`. If the target is not a room, reject `UnknownRoom`.
     - On success: `Location::Arriving{room}`, push onto `admission_queue`, emit `Arrived{room}`.
   - `Depart`:
     - Unknown occupant: reject `UnknownOccupant`.
     - Occupant is `Away`: reject `NotPresent`.
     - Otherwise, push the occupant onto the departures list for this tick (once only).
   - `Move`:
     - Unknown occupant: reject `UnknownOccupant`.
     - Not `InRoom`: reject `NotInRoom`.
     - `to` is not a room: reject `UnknownRoom`.
     - No door from the current room to `to`: reject `NoDoor`.
     - Otherwise, push the move onto this tick's moves list.
   - `Observe`:
     - Unknown occupant: reject `UnknownOccupant`.
     - Occupant is `Away`: reject `NotPresent`.
     - Otherwise, apply the observation with `apply_observation`. An `Err` is rejected with the returned reason.
   - `Share` and `Unshare`:
     - Unknown occupant: reject `UnknownOccupant`.
     - Not a `PersonalAgent`: reject `NotPersonalAgent`.
     - Otherwise, insert or remove the grantee in `shared_with`, and emit `Shared` or `Unshared`.
2. **Expire.** For each occupant not `Away`, in ID order, and each dimension in `Dimension` order: if the observation is expired at `t` and the cached shown value for that dimension is not `Stale`, emit `ObservationExpired{dimension}`.
3. **Admit.** Work in two stages.
   - First, for each room in ID order, serve its waitlist from the front: while the head `has_room`, pop it, place it, and emit `Admitted`.
   - Then take `admission_queue`. For each occupant still `Arriving{room: target}`, find the first room in `index.rooms[target].chain` for which `has_room` is true:
     - If there is one, place the occupant there. If it differs from `target`, emit `Overflowed{from: target, to}`, then `Admitted{room}`.
     - If there is none, append the occupant to `target`'s waitlist, set `Location::Waitlisted{room: target}`, and emit `Waitlisted{room, position}` with a 1-based position.
4. **Allocate.** For each room in ID order, go through its occupants in admission order. For each one holding no seat:
   - If the occupant has a reserved seat in this room, take it.
   - Otherwise, choose from the free hot seats with `choose_seat`.
   - On success, set the seat's holder and the location's seat, and emit `Seated{room, seat}`. An occupant who gets no seat stands, with seat `None`.
5. **Transition.** This task handles moves in Task 7. Here, leave a no-op function `fn transition(&mut self, t)`.
6. **Depart.** For each queued departure: release the seat (emitting `SeatReleased`) and leave the room; or leave the waitlist; or drop from `admission_queue`. Set `Location::Away`, reset `presence` and `shown` to their defaults, and emit `Departed{from}`. `from` is the room left, or `None` if the occupant was in transit or arriving.
7. **Emit.** For each occupant not `Away`, in ID order: compute `derive_shown`. If it differs from the cached `shown`, store it and emit `PresenceChanged{shown}`.

Every event gets `tick = t`, `seq = next_seq++` and `fixture = state.fixture`.

The capacity rule:

```rust
fn has_room(&self, room: &PlaceId, occ: &CityId) -> bool {
    let info = &self.index.rooms[room];
    let state = &self.state.rooms[room];
    let present = state.occupants.len() as u32;
    if info.reserved.contains_key(occ) { return present < info.capacity; }
    let unclaimed = info.reserved.keys().filter(|o| !state.occupants.contains(o)).count() as u32;
    present + unclaimed < info.capacity
}
```

Capacity is held for absent reserved-seat owners, so an owner is never turned away by strangers, and a room never exceeds its capacity.

- [ ] **Step 1: Write the failing scenario tests**

`tests/common/mod.rs` provides:
- `fn manifest(v: serde_json::Value) -> Manifest`;
- `fn feed(lines: &[serde_json::Value]) -> Feed`, which prepends a fixture header and sets `"record":"entry","fixture":true` on each entry value;
- `fn room_of(w: &World, id: &str) -> Option<String>`, the room for `InRoom`;
- `fn seat_of(w: &World, id: &str) -> Option<String>`;
- `fn kinds(events: &[Event], id: &str) -> Vec<String>`, the type names of that occupant's events;
- `fn guild(id: &str, dept: Option<&str>) -> Value`.

`tests/scenarios.rs` uses a shared manifest `hall()`:
- `room:work`: capacity 3, pod `pod:make` (department `making`) with seats `seat:w1` and `seat:w2`, and seat `seat:w3` reserved for `agent:kai`; overflow to `room:annex`; a door to `room:annex` with transit 1..1.
- `room:annex`: capacity 1, seat `seat:x1`, and a door back.
- Occupants: `agent:kai` (making), plus `agent:a`, `agent:b`, `agent:c` and `agent:d` (no department). All are GuildAgents with `work: room:work`.

```rust
fn arrive(at: u64, id: &str) -> Value { json!({"at": at, "command": {"type": "Arrive", "occupant": id}}) }
fn depart(at: u64, id: &str) -> Value { json!({"at": at, "command": {"type": "Depart", "occupant": id}}) }

#[test] fn reserved_seat_stays_empty_while_owner_is_away() {
    let mut w = World::new(hall(), feed(&[arrive(0, "agent:a"), arrive(0, "agent:b"), arrive(0, "agent:c")]), 1).unwrap();
    w.run(3);
    // capacity 3 with kai's seat held: only two strangers fit; the third overflows to the annex
    assert_eq!(room_of(&w, "agent:a").as_deref(), Some("room:work"));
    assert_eq!(room_of(&w, "agent:b").as_deref(), Some("room:work"));
    assert_eq!(room_of(&w, "agent:c").as_deref(), Some("room:annex"));
    assert_eq!(w.snapshot().rooms[&PlaceId::from("room:work")].seats[&PlaceId::from("seat:w3")], None); }

#[test] fn reserved_owner_gets_in_even_when_strangers_filled_the_room() {
    let mut w = World::new(hall(), feed(&[arrive(0, "agent:a"), arrive(0, "agent:b"), arrive(0, "agent:c"), arrive(1, "agent:kai")]), 1).unwrap();
    w.run(3);
    assert_eq!(seat_of(&w, "agent:kai").as_deref(), Some("seat:w3")); }

#[test] fn overflow_then_waitlist_in_fifo_order_then_drain() {
    let f = feed(&[arrive(0, "agent:a"), arrive(0, "agent:b"), arrive(0, "agent:c"), arrive(0, "agent:d"),
                   depart(3, "agent:a"), depart(5, "agent:b")]);
    let mut w = World::new(hall(), f, 1).unwrap();
    let ev = w.run(2);
    assert_eq!(kinds(&ev, "agent:c"), ["Arrived", "Overflowed", "Admitted", "Seated", "PresenceChanged"].map(String::from).to_vec()
        .into_iter().filter(|k| k != "PresenceChanged").collect::<Vec<_>>());
    assert!(kinds(&ev, "agent:d").contains(&"Waitlisted".to_string()));
    w.run(2); // tick 3: a departs; the room frees at the end of tick 3; d is admitted at tick 4
    assert_eq!(room_of(&w, "agent:d").as_deref(), Some("room:work"));
    let seated_w: Vec<_> = w.snapshot().rooms[&PlaceId::from("room:work")].occupants.clone();
    assert!(seated_w.len() <= 3); }

#[test] fn departure_releases_the_held_seat() {
    let mut w = World::new(hall(), feed(&[arrive(0, "agent:kai"), depart(2, "agent:kai")]), 1).unwrap();
    w.run(1); assert_eq!(seat_of(&w, "agent:kai").as_deref(), Some("seat:w3"));
    let ev = w.run(1);
    assert!(ev.iter().any(|e| matches!(&e.kind, EventKind::SeatReleased { seat, .. } if seat.as_str() == "seat:w3")));
    assert!(matches!(w.snapshot().occupants[&CityId::from("agent:kai")].location, Location::Away)); }

#[test] fn department_pod_is_preferred() {
    let mut w = World::new(hall(), feed(&[arrive(0, "agent:a"), arrive(1, "agent:kai")]), 1).unwrap();
    w.run(2); assert_eq!(seat_of(&w, "agent:a").as_deref(), Some("seat:w1")); }

#[test] fn bad_commands_are_rejected_not_panics() {
    let f = feed(&[arrive(0, "agent:nobody"), depart(0, "agent:a"),
                   json!({"at": 0, "command": {"type": "Arrive", "occupant": "agent:a", "room": "room:nowhere"}}),
                   arrive(1, "agent:b"), arrive(1, "agent:b")]);
    let mut w = World::new(hall(), f, 1).unwrap();
    let ev = w.run(2);
    let reasons: Vec<_> = ev.iter().filter_map(|e| match &e.kind { EventKind::Rejected { reason, .. } => Some(*reason), _ => None }).collect();
    assert_eq!(reasons, vec![RejectReason::UnknownOccupant, RejectReason::NotPresent, RejectReason::UnknownRoom, RejectReason::AlreadyPresent]); }

#[test] fn newcomer_registers_with_a_profile() {
    let f = feed(&[json!({"at": 0, "command": {"type": "Arrive", "occupant": "person:asha", "room": "room:annex",
        "profile": {"id": "person:asha", "kind": {"type": "Human", "tier": "Registered"}, "display_name": "Asha"}}})]);
    let mut w = World::new(hall(), f, 1).unwrap(); w.run(1);
    assert_eq!(room_of(&w, "person:asha").as_deref(), Some("room:annex")); }
```

`RejectReason` needs `Copy`, so add `Copy` to its derive list in contracts.

When writing `overflow_then_waitlist...`, simplify the first assertion to `assert_eq!(filtered_kinds(&ev, "agent:c"), ["Arrived","Overflowed","Admitted","Seated"])`, where `filtered_kinds` drops `PresenceChanged`. Put that helper in `common`.

- [ ] **Step 2: Run and watch it fail.** Run `cargo test -p city-core --test scenarios`; it should fail to compile.
- [ ] **Step 3: Implement `world.rs`** as specified. Mark the Transition phase with the comment `// Task 7`.
- [ ] **Step 4: Run and see it pass.** Expect 7 passed.
- [ ] **Step 5: Commit** with `feat(city): seat, overflow, waitlist and release occupants tick by tick`.

---

### Task 7: Transitions, seeded timing and presence over time

**Files:**
- Modify: `city/crates/city-core/src/world.rs`
- Test: `city/crates/city-core/tests/scenarios.rs`

**Interfaces:**
- Produces: no new public API. `step` now also moves occupants.

The Transition phase works in two passes.

**Pass 1, completions.** For each occupant in ID order that is `InTransit` with `arrives_at <= t`:
- set `Location::Arriving{room: to}`;
- push the occupant onto `admission_queue`, to be admitted at the next tick's Admit phase;
- emit `TransitEnded{to}`.

**Pass 2, starts.** For each queued move, in feed order, whose occupant is still `InRoom{room: from}`:
- release the seat (emitting `SeatReleased`) and remove the occupant from `from`'s occupants;
- compute `d = min + rng.next_u64() % (max - min + 1)` from the door's `transit`, and set `arrives_at = t + d`;
- set `Location::InTransit`;
- emit `TransitStarted`.

The RNG is `ChaCha8Rng::seed_from_u64(seed)`, created in `World::new`. It is drawn from only here.

A departure of an occupant who is in transit sets them `Away` with `from: None`.

- [ ] **Step 1: Write the failing tests** (append to `scenarios.rs`)

```rust
fn mv(at: u64, id: &str, to: &str) -> Value { json!({"at": at, "command": {"type": "Move", "occupant": id, "to": to}}) }
fn obs(at: u64, id: &str, dim: &str, value: Value, exp: u64) -> Value { json!({"at": at, "command": {"type": "Observe", "occupant": id,
    "observation": {"dimension": dim, "value": value, "stamp": {"observed_at": at, "fetched_at": at, "expires_at": exp, "source": "fixture", "source_version": "1"}}}}) }

#[test] fn move_goes_through_the_door_and_is_admitted_next_tick() {
    let mut w = World::new(hall(), feed(&[arrive(0, "agent:a"), mv(2, "agent:a", "room:annex")]), 1).unwrap();
    w.run(2);
    assert!(matches!(w.snapshot().occupants[&CityId::from("agent:a")].location, Location::InTransit { arrives_at: 3, .. }));
    w.run(1); // tick 3: transit ends
    w.run(1); // tick 4: admitted
    assert_eq!(room_of(&w, "agent:a").as_deref(), Some("room:annex"));
    assert_eq!(seat_of(&w, "agent:a").as_deref(), Some("seat:x1")); }

#[test] fn move_without_a_door_is_rejected() {
    let mut m = hall(); /* remove the annex's door back */ strip_doors(&mut m, "room:annex");
    let mut w = World::new(m, feed(&[json!({"at":0,"command":{"type":"Arrive","occupant":"agent:a","room":"room:annex"}}),
                                     mv(1, "agent:a", "room:work")]), 1).unwrap();
    let ev = w.run(2);
    assert!(ev.iter().any(|e| matches!(e.kind, EventKind::Rejected { reason: RejectReason::NoDoor, .. }))); }

#[test] fn presence_goes_working_then_stale_then_idle() {
    let f = feed(&[arrive(0, "agent:a"),
        obs(0, "agent:a", "Process", json!("Running"), 100),
        obs(0, "agent:a", "Task", json!({"state": "Working"}), 3),
        obs(6, "agent:a", "Task", json!({"state": "Idle"}), 50)]);
    let mut w = World::new(hall(), f, 1).unwrap();
    let headline = |w: &World| w.snapshot().occupants[&CityId::from("agent:a")].shown.headline;
    w.run(1); assert_eq!(headline(&w), Headline::Working);
    w.run(2); assert_eq!(headline(&w), Headline::Stale); // tick 3 = expires_at
    w.run(3); assert_eq!(headline(&w), Headline::Idle); }

#[test] fn same_seed_same_log_and_seed_drives_transit_time() {
    let mut m = hall(); set_transit(&mut m, "room:work", 1, 50);
    let f = || feed(&[arrive(0, "agent:a"), mv(1, "agent:a", "room:annex")]);
    let log = |seed| { let mut w = World::new(m.clone(), f(), seed).unwrap();
        w.run(60).iter().map(|e| serde_json::to_string(e).unwrap()).collect::<Vec<_>>().join("\n") };
    assert_eq!(log(7), log(7));
    let arrivals: std::collections::BTreeSet<String> = (0..8).map(log).collect();
    assert!(arrivals.len() > 1, "seed must influence transit timing"); }
```

Add the helpers `strip_doors(&mut Manifest, room)` and `set_transit(&mut Manifest, room, min, max)` to `common`.

- [ ] **Step 2: Run and watch it fail.** Run `cargo test -p city-core --test scenarios`. The move and seed tests should fail: the occupant never leaves the room.
- [ ] **Step 3: Implement the Transition phase.**
- [ ] **Step 4: Run and see it pass.** Expect 11 passed.
- [ ] **Step 5: Commit** with `feat(city): move occupants through doors on seeded timing`.

---

### Task 8: Viewer projections

**Files:**
- Create: `city/crates/city-core/src/project.rs`
- Test: `city/crates/city-core/tests/scenarios.rs`

**Interfaces:**
- Produces:

```rust
pub fn visible(viewer: &Viewer, occ: &OccupantState) -> bool
pub fn project(snapshot: &Snapshot, viewer: &Viewer) -> Projection
```

Visibility (`visible`):

- `Operator` sees everyone.
- A `PersonalAgent{owner}` is visible only to `Person{id}` where `id == owner` or `id` is in `shared_with`.
- A `Human{tier: Observer}` is visible only to `Person{id}` where `id` is the observer's own ID (the RD03 default).
- All other occupants are visible to everyone.

Projection fields:

| Field | Source |
| --- | --- |
| `badge` | `Some(Ai)` for GuildAgent, CityRoleAgent and PersonalAgent; `Some(Simulation)` for SimCitizen; `None` for Human |
| `task_summary` | The task observation's summary, shown only when the observation is not expired and one of these holds: the viewer is `Operator`; the viewer is the owner of this personal agent; `summary_public` is true. Otherwise `None` |
| `presence` | The cached `shown` |
| Rooms | Rooms in ID order, each with its facility (from the index built over `snapshot.manifest`) |
| Room occupants and `waiting` | Visible occupants only, in city-ID order |
| `in_transit` | Visible occupants that are `InTransit`, in city-ID order |

A redacted summary and an absent one are both `None`: no flag distinguishes them.

- [ ] **Step 1: Write the failing tests**

```rust
fn personal_feed() -> Feed { feed(&[
    json!({"at":0,"command":{"type":"Arrive","occupant":"pa:helper","room":"room:work","profile":{"id":"pa:helper","display_name":"Helper","kind":{"type":"PersonalAgent","owner":"person:asha"}}}}),
    json!({"at":0,"command":{"type":"Arrive","occupant":"person:obs","room":"room:work","profile":{"id":"person:obs","display_name":"O","kind":{"type":"Human","tier":"Observer"}}}}),
    arrive(0, "agent:a"),
    obs(0, "agent:a", "Process", json!("Running"), 99),
    obs(0, "agent:a", "Task", json!({"state":"Working","summary":"secret plan"}), 99),
    obs(0, "pa:helper", "Process", json!("Running"), 99),
    obs(0, "pa:helper", "Task", json!({"state":"Working","summary":"asha's errand"}), 99)]) }
fn ids(p: &Projection) -> Vec<String> { p.rooms.iter().flat_map(|r| r.occupants.iter().map(|o| o.id.to_string())).collect() }

#[test] fn personal_agent_is_visible_to_its_owner_only() {
    let mut w = World::new(hall(), personal_feed(), 1).unwrap(); w.run(1);
    let s = w.snapshot();
    assert!(!ids(&project(s, &Viewer::Public)).contains(&"pa:helper".into()));
    assert!(!ids(&project(s, &Viewer::Person { id: "person:bo".into() })).contains(&"pa:helper".into()));
    let own = project(s, &Viewer::Person { id: "person:asha".into() });
    let helper = own.rooms.iter().flat_map(|r| &r.occupants).find(|o| o.id.as_str() == "pa:helper").unwrap();
    assert_eq!(helper.task_summary.as_deref(), Some("asha's errand")); }

#[test] fn sharing_grants_presence_but_not_the_summary() {
    let mut f = personal_feed();
    f.entries.push(FeedEntry { at: 1, fixture: true, command: Command::Share { occupant: "pa:helper".into(), grantee: "person:bo".into() } });
    let mut w = World::new(hall(), f, 1).unwrap(); w.run(2);
    let p = project(w.snapshot(), &Viewer::Person { id: "person:bo".into() });
    let h = p.rooms.iter().flat_map(|r| &r.occupants).find(|o| o.id.as_str() == "pa:helper").unwrap();
    assert_eq!(h.task_summary, None); assert_eq!(h.presence.headline, Headline::Working); }

#[test] fn observers_are_hidden_from_everyone_but_themselves() {
    let mut w = World::new(hall(), personal_feed(), 1).unwrap(); w.run(1);
    assert!(!ids(&project(w.snapshot(), &Viewer::Public)).contains(&"person:obs".into()));
    assert!(ids(&project(w.snapshot(), &Viewer::Person { id: "person:obs".into() })).contains(&"person:obs".into())); }

#[test] fn private_summaries_are_closed_by_default_and_public_views_carry_no_counts() {
    let mut w = World::new(hall(), personal_feed(), 1).unwrap(); w.run(1);
    let p = project(w.snapshot(), &Viewer::Public);
    let a = p.rooms.iter().flat_map(|r| &r.occupants).find(|o| o.id.as_str() == "agent:a").unwrap();
    assert_eq!(a.task_summary, None);
    let json = serde_json::to_value(&p).unwrap().to_string();
    assert!(!json.contains("pa:helper") && !json.contains("occupancy") && !json.contains("holder"));
    let op = project(w.snapshot(), &Viewer::Operator);
    assert_eq!(ids(&op).len(), 3); }
```

- [ ] **Step 2: Run and watch it fail.** Run `cargo test -p city-core --test scenarios`; `project` is undefined.
- [ ] **Step 3: Implement `project.rs`.** It rebuilds the room-to-facility map by walking `snapshot.manifest`; this is cheap, and no index is needed.
- [ ] **Step 4: Run and see it pass.** Expect 15 passed.
- [ ] **Step 5: Commit** with `feat(city): project the world per viewer, private by construction`.

---

### Task 9: Snapshot diff, invariant checkers and the synthetic generator

**Files:**
- Create: `city/crates/city-core/src/diff.rs`, `src/invariants.rs` and `src/synth.rs`
- Test: unit tests in each file

**Interfaces:**
- Produces:

```rust
pub fn diff(a: &Snapshot, b: &Snapshot) -> SnapshotDiff   // occupants in ID order; Added, then Location, Presence, Profile
pub struct Violation { pub invariant: u8, pub tick: Tick, pub detail: String }
pub fn check_capacity(s: &Snapshot) -> Vec<Violation>                     // 1
pub fn check_reserved(s: &Snapshot) -> Vec<Violation>                     // 2
pub fn check_privacy(s: &Snapshot) -> Vec<Violation>                      // 3: Public + every Person id seen in any profile/owner/grant
pub fn check_expiry(s: &Snapshot) -> Vec<Violation>                       // 4
pub fn check_unknown_task(s: &Snapshot) -> Vec<Violation>                 // 5
pub fn check_release(before: &Snapshot, after: &Snapshot, events: &[Event]) -> Vec<Violation> // 7
pub fn check_consistency(s: &Snapshot) -> Vec<Violation>                  // 0: seat holders ↔ locations agree
pub fn check_all(before: &Snapshot, after: &Snapshot, events: &[Event]) -> Vec<Violation>
pub fn synthetic(occupants: u32, seed: u64) -> (Manifest, Feed)
```

Invariant 6, determinism, is checked by running a world twice, not by a function.

What each checker verifies:

| # | Checker | Verifies |
| --- | --- | --- |
| 1 | `check_capacity` | Every room's `occupants.len() <= capacity` |
| 2 | `check_reserved` | For each manifest seat with `reserved_for = Some(o)`, the holder is `None` or `Some(o)` |
| 3 | `check_privacy` | For each viewer, every `PersonalAgent` in the projection (rooms, waiting and in transit) has `owner == viewer` or the viewer in `shared_with`; the `Public` projection holds none |
| 4 | `check_expiry` | For each non-Away occupant and each observed dimension expired at `s.tick`, the shown dimension is `Stale` |
| 5 | `check_unknown_task` | If process is shown `Running` and no task observation is held, then `shown.task != Working` and `headline != Working` |
| 7 | `check_release` | For each occupant with a `Departed` event: the seats named in its `SeatReleased` events this tick equal the seat it held in `before` (0 or 1 seat); after the tick no seat holds it; and no other occupant's release names that seat this tick |
| 0 | `check_consistency` | Every `Some(holder)` in `rooms[r].seats` has `InRoom{room: r, seat: Some(that seat)}`, and vice versa |

`synthetic(n, seed)` builds one city with one district and `max(1, n/200)` facilities, each with 4 rooms. Each room has capacity 60 and 50 seats in 5 pods of 10, with departments cycling through `making`, `knowledge`, `civic` and `play`. The rooms overflow along a chain within the facility, and doors join consecutive rooms with transit 1..4.

It adds `n` occupants, cycling kinds in the ratio of 6 GuildAgent, 1 CityRoleAgent, 1 PersonalAgent, 1 SimCitizen and 1 Human. Personal agents are owned by `person:0`, and humans cycle through tiers. Each occupant's work room is picked by a `ChaCha8Rng(seed)`.

The generated feed is a fixture. Each occupant arrives at a tick in `0..20`, gets Process and Task observations, possibly moves once, and departs at a tick in `40..80`. The feed is sorted by `at` and stable.

- [ ] **Step 1: Write the failing tests**

```rust
// diff.rs
#[test] fn diff_reports_location_and_presence_changes() { /* build World on synthetic(20, 1); a = snapshot at 0; run(10); b = snapshot;
   assert!(diff(&a,&b).changes.iter().any(|c| matches!(c, Change::LocationChanged{..})));
   assert!(diff(&b,&b).changes.is_empty()); */ }
// invariants.rs
#[test] fn checkers_catch_a_planted_violation() { /* synthetic(20,1), run(10), clone snapshot; push an extra id into a room's occupants beyond capacity
   → check_capacity non-empty; set a reserved seat's holder to a stranger → check_reserved non-empty */ }
#[test] fn clean_synthetic_run_has_no_violations() { /* step 100 times, check_all each tick, assert empty */ }
// synth.rs
#[test] fn synthetic_is_valid_and_deterministic() { let (m, f) = synthetic(250, 3);
   assert!(crate::index::validate(&m).valid); assert!(f.header.fixture); assert_eq!(synthetic(250, 3).1.entries, f.entries);
   assert_eq!(m.city.districts[0].facilities.len(), 1); }
```

Write these out in full with real code in each file. The comments above state exactly what each assertion is. For the planted reserved violation, find the first seat with `reserved_for` in `snapshot.manifest`. `synthetic` adds no reservations, so first add one: build a manifest from `synthetic`, set `seats[0].reserved_for = Some(first GuildAgent)`, and validate that it is still valid.

- [ ] **Step 2: Run and watch it fail.** Run `cargo test -p city-core --lib`.
- [ ] **Step 3: Implement** the three modules.
- [ ] **Step 4: Run and see it pass** (every lib test).
- [ ] **Step 5: Commit** with `feat(city): add snapshot diff, invariant checkers and a synthetic city`.

---

### Task 10: Property tests of the seven invariants

**Files:**
- Create: `city/crates/city-core/tests/invariants.rs`

**Interfaces:**
- Consumes: `World`, `check_all`, contracts.

Strategy:
- **Rooms:** `room:0..room:{n}` with `n` in 1..=4, capacity 1..=5, and 0..=capacity+1 seats. Seats are in pods `pod:{r}:{0|1}` (departments drawn from `making`, `knowledge` or none) or have no pod.
- **Overflow:** room `i` may overflow to a room `j > i` only, so no cycle is possible.
- **Doors:** a random subset of ordered room pairs, with transit `1..=3`.
- **Manifest occupants:** `agent:0..agent:5`, GuildAgents with a random department. Each room reserves 0..=min(2, capacity) seats, each for a distinct manifest occupant.
- **Feed-only occupants:** `pa:0` (owner `person:0`), `pa:1` (owner `person:1`, shared with `person:2`), `person:0..person:2` (Registered, Resident or Observer) and `sim:0`.
- **Commands:** 0..60 commands, each with `at` in 0..30. Choose each command from:
  - Arrive with profile, to a random room;
  - Depart;
  - Move to a random room;
  - Observe a random dimension, with a random value and random `observed_at <= at` and `expires_at` in `at+1..at+10`;
  - Share and Unshare.
- Sort by `at` (stable).

- [ ] **Step 1: Write the property test**

```rust
proptest! {
    #![proptest_config(ProptestConfig { cases: 256, .. ProptestConfig::default() })]
    #[test]
    fn invariants_hold_every_tick((manifest, feed, seed) in world_strategy()) {
        let mut w = World::new(manifest.clone(), feed.clone(), seed).expect("generated manifests are valid");
        let mut log = Vec::new();
        for _ in 0..40 {
            let before = w.snapshot().clone();
            let ev = w.step();
            let v = check_all(&before, w.snapshot(), &ev);
            prop_assert!(v.is_empty(), "tick {}: {:?}", w.snapshot().tick, v);
            log.extend(ev);
        }
        // invariant 6
        let mut again = World::new(manifest, feed, seed).unwrap();
        let log2: Vec<_> = (0..40).flat_map(|_| again.step()).collect();
        let bytes = |l: &[Event]| l.iter().map(|e| serde_json::to_string(e).unwrap()).collect::<Vec<_>>().join("\n");
        prop_assert_eq!(bytes(&log), bytes(&log2));
    }
}
```

Build `world_strategy()` with `prop_flat_map` from a room count, then per-room parameters, then commands. Because arbitrary index choices are made with `any::<prop::sample::Index>()`, every reference is valid by construction. Assert that `city_core::validate(&manifest).valid` holds inside the strategy's `prop_map` with `debug_assert!`, and rely on `expect` above.

- [ ] **Step 2: Run it.**
Run: `cargo test -p city-core --test invariants --release`
Expected: PASS. If a counterexample appears, it is a real bug in `world.rs`. Fix the rule, and add the minimised case as a named test in `scenarios.rs`. Never weaken a checker.

- [ ] **Step 3: Temporarily break a rule to prove the test bites.** In `has_room`, change `<` to `<=` and confirm the property test fails on invariant 1. Then revert the change and do not commit it.
- [ ] **Step 4: Commit** with `test(city): property-test the seven invariants`.

---

### Task 11: The `city` command line

**Files:**
- Create: `city/crates/city-cli/Cargo.toml`, `src/lib.rs`, `src/commands.rs` and `src/main.rs`
- Test: `city/crates/city-cli/tests/cli.rs`
- Modify: `city/Cargo.toml` (add the member)

**Interfaces:**
- Produces, used by city-mcp:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)] pub enum Status { Ok, Failed, BadInput }
impl Status { pub fn exit_code(self) -> i32 /* 0, 1, 2 */ }
pub struct Outcome { pub status: Status, pub body: serde_json::Value }
pub fn validate(manifest: &Path) -> Outcome
pub struct RunArgs { pub manifest: PathBuf, pub feed: PathBuf, pub seed: u64, pub ticks: u64,
    pub snapshot_every: Option<u64>, pub out: PathBuf }
pub fn run(a: &RunArgs) -> Outcome
pub struct InspectArgs { pub snapshot: PathBuf, pub viewer: String, pub operator: bool,
    pub room: Option<String>, pub occupant: Option<String> }
pub fn inspect(a: &InspectArgs) -> Outcome
pub fn diff(a: &Path, b: &Path) -> Outcome
pub fn schema(out: Option<&Path>) -> Outcome
pub fn parse_viewer(s: &str) -> Viewer  // "public" | "operator" | otherwise Person{id: s}
```

Error bodies look like `{"error": {"code": "...", "message": "..."}}`.

| Command | Behaviour |
| --- | --- |
| `validate` | Outputs a `ValidationReport`. Status `Ok` if valid, otherwise `Failed`. An unreadable file or bad JSON gives `BadInput` with code `bad-input`. |
| `run` | Refuses `ticks == 0` or `snapshot_every == Some(0)` with `BadInput`. A bad feed gives `BadInput`, code `bad-feed`, with the line number in the message. An invalid manifest gives `Failed` with its issues. Otherwise it creates `out`, then writes `events.jsonl` (one event per line with a trailing newline), `snapshots/tick-{:06}.json` every K ticks, `final.json` and `summary.json` (a `RunSummary`). The body is the summary. |
| `inspect` | A `viewer` of `operator` with `!operator` gives `Failed`, code `operator-flag-required`. `room` and `occupant` together give `BadInput`. `room` gives that `RoomView`, and `occupant` searches rooms, waiting and in transit. A miss gives `Failed`, code `not-found`, which is identical for a hidden occupant and a missing one. |
| `diff` | Outputs a `SnapshotDiff`. |
| `schema` | Outputs the `all_schemas()` map. With `out`, it writes `<name>.schema.json` per contract and outputs `{"written": [...]}`. |

`main.rs` defines a clap `Parser` with subcommands matching the spec: `validate <MANIFEST>`, `run --manifest --feed --seed --ticks [--snapshot-every] --out`, `inspect <SNAPSHOT> [--viewer V (default public)] [--operator] [--room R | --occupant O]`, `diff <A> <B>` and `schema [--out DIR]`. It prints `serde_json::to_string_pretty(&outcome.body)` and exits with `outcome.status.exit_code()`.

- [ ] **Step 1: Write the failing end-to-end tests**

`tests/cli.rs` uses `env!("CARGO_BIN_EXE_city")` and a temporary directory under `std::env::temp_dir()`. Each test gets a unique subdirectory named from its test name, removed at the end. It uses the gate fixtures from `../../fixtures/two-room/`, which are written in Task 13. For this task, write a minimal pair inline into the temporary directory: the `hall()` manifest from Task 6 and a four-line feed.

```rust
fn city(args: &[&str]) -> (i32, serde_json::Value) { let o = Command::new(env!("CARGO_BIN_EXE_city")).args(args).output().unwrap();
    (o.status.code().unwrap(), serde_json::from_slice(&o.stdout).unwrap_or(serde_json::Value::Null)) }
#[test] fn validate_ok_and_invalid() { /* ok → (0, valid true); overflow cycle → (1, valid false); missing file → 2 */ }
#[test] fn run_writes_log_snapshots_and_summary() { /* run --ticks 6 --snapshot-every 3 → 0; files events.jsonl, snapshots/tick-000003.json, tick-000006.json, final.json, summary.json exist; summary.fixture == true; every events.jsonl line parses as Event with fixture true */ }
#[test] fn run_is_byte_identical_for_the_same_seed() { /* two runs → identical events.jsonl bytes */ }
#[test] fn inspect_views_and_operator_flag() { /* --viewer public → 0 with "rooms"; --viewer operator without --operator → 1, error.code operator-flag-required; with --operator → 0; --room room:work → id room:work; --occupant agent:nobody → 1 not-found */ }
#[test] fn diff_and_schema() { /* diff tick-000003 final → 0, has "changes"; schema --out dir → 0 and dir/manifest.schema.json exists */ }
```

Write each test fully. The comments give the exact assertions.

- [ ] **Step 2: Run and watch it fail.** Run `cargo test -p city-cli`.
- [ ] **Step 3: Implement** `commands.rs` and `main.rs`.
- [ ] **Step 4: Run and see it pass.** Expect 5 passed.
- [ ] **Step 5: Commit** with `feat(city): add the city command line`.

---

### Task 12: The MCP server

**Files:**
- Create: `city/crates/city-mcp/Cargo.toml`, `src/lib.rs` (`CityServer`) and `src/main.rs`
- Test: `city/crates/city-mcp/tests/mcp.rs`
- Modify: `city/Cargo.toml` (add the member)

**Interfaces:**
- Consumes: `city_cli::commands::*`.
- Produces: `CityServer`, with the tools `validate`, `run`, `inspect`, `diff` and `schema`.

Tool parameters:

| Tool | Parameters |
| --- | --- |
| `validate` | `{manifest_path}` |
| `run` | `{manifest_path, feed_path, seed, ticks, snapshot_every?, out_dir}` |
| `inspect` | `{snapshot_path, viewer?, operator?, room?, occupant?}` |
| `diff` | `{a_path, b_path}` |
| `schema` | `{out_dir?}` |

Each tool calls the matching `commands::` function. It returns `CallToolResult::success(vec![Content::text(pretty_json)])` when the status is `Ok`, and `CallToolResult::error(...)` with the same JSON body otherwise. Parameter structs derive `serde::Deserialize` and `rmcp::schemars::JsonSchema`.

`main.rs`:

```rust
#[tokio::main] async fn main() -> anyhow::Result<()> { let s = city_mcp::CityServer::new().serve(rmcp::transport::stdio()).await?; s.waiting().await?; Ok(()) }
```

Use `#[tool_router]` together with `#[tool_handler(name = "agentnagar-city", version = env!("CARGO_PKG_VERSION"), instructions = "...")]`. If the `version` argument does not accept `env!`, use a literal `"0.1.0"`.

- [ ] **Step 1: Write the failing test** (in-process, over `tokio::io::duplex`)

```rust
#[tokio::test] async fn tools_list_and_call_through_mcp() {
    let (a, b) = tokio::io::duplex(1 << 20);
    tokio::spawn(async move { let s = city_mcp::CityServer::new().serve(a).await.unwrap(); let _ = s.waiting().await; });
    let client = ().serve(b).await.unwrap();
    let names: Vec<String> = client.list_all_tools().await.unwrap().into_iter().map(|t| t.name.to_string()).collect();
    for n in ["validate", "run", "inspect", "diff", "schema"] { assert!(names.contains(&n.to_string())); }
    // write hall manifest + feed to a temp dir; call run → is_error false; call inspect viewer=operator without operator → is_error true;
    // with operator=true → is_error false and text contains "rooms". Compare run's text body with city_cli::commands::run output for the same args
    // (different out dirs) → equal JSON except the snapshot paths field.
}
```

Write it out fully. Look up the exact client call names, such as `call_tool` with `CallToolRequestParams` or `CallToolRequestParam`, in the rmcp 3.4 sources under `~/.cargo/registry/src/*/rmcp-3.4*/`. Use what exists; do not guess.

- [ ] **Step 2: Run and watch it fail.** Run `cargo test -p city-mcp`.
- [ ] **Step 3: Implement** `CityServer`.
- [ ] **Step 4: Run and see it pass.**
- [ ] **Step 5: Commit** with `feat(city): expose the city operations over MCP`.

---

### Task 13: The gate — two-room fixture, gate test, scale runs, wasm check, documentation

**Files:**
- Create: `city/fixtures/two-room/manifest.json`, `city/fixtures/two-room/feed.jsonl`
- Modify: `city/crates/city-core/tests/scenarios.rs` (the gate test)
- Create: `city/crates/city-cli/examples/scale.rs`, `city/scripts/check.sh`, `city/README.md`
- Modify: `README.md` (repository root: one row in the prototypes/tools section and a sentence in Current direction), `docs/superpowers/specs/2026-09-24-city-world-core-design.md` (only if the implementation settled something the spec left open, recorded as a dated note)

**Interfaces:**
- Consumes: everything above.

The gate fixture is a Guild-hall scene. The rooms:

| Room | Capacity | Seats | Links |
| --- | --- | --- | --- |
| `room:workshop` | 4 | pod `pod:making` (department `making`) with `seat:w1` and `seat:w2`; `seat:w3` reserved for `agent:kai`; hot seat `seat:w4` | overflow to `room:commons`; door `door:workshop-commons` (transit 2..4) |
| `room:commons` | 2 | `seat:c1` and `seat:c2` | door back |

The occupants:

- **In the manifest:** Guild agents `agent:kai` (making), `agent:lyra` (making), `agent:echo` (knowledge) and `agent:theo`, plus `city:librarian`, a CityRoleAgent.
- **Arriving through the feed:** `person:asha` (Registered), `person:guest` (Observer) and `pa:asha-notes` (PersonalAgent, owner `person:asha`).

The feed header reads `{"record":"header","schema_version":1,"source":"fixture:two-room","fixture":true,"description":"Scripted gate scene. Not real agent state."}`. It must tell this story across 40 ticks:

1. Lyra, Echo, Theo and Asha arrive at the workshop.
2. Kai's seat stays held, so Asha overflows to the commons.
3. The librarian and the observer arrive at the commons: the librarian overflows, if the chain allows, or waitlists.
4. Kai arrives and takes w3.
5. Asha's personal agent arrives.
6. Kai and Lyra report `Running` and `Working`. Echo reports `Running` and `Idle`. Theo reports `Running` with no task.
7. Lyra's task expires, so she becomes `Stale`.
8. Asha moves back to the workshop through the door once Theo leaves.
9. The observer is served from the waitlist.
10. Everyone departs by tick 36.

The gate test (`gate_two_room_story` in `scenarios.rs`) loads both files with `include_str!("../../../fixtures/two-room/...")`. It runs 40 ticks, calling `check_all` after every step. It asserts:

- the event kinds seen include `Arrived`, `Overflowed`, `Waitlisted`, `Seated`, `TransitStarted`, `ObservationExpired` and `Departed`;
- presence headlines seen include `Working`, `Idle`, `Unknown` and `Stale`;
- no `Rejected` events occur;
- kai only ever sits in `seat:w3`;
- the public projection never contains `pa:asha-notes` or `person:guest`;
- every event is `fixture: true`;
- a second run gives a byte-identical log;
- everyone is `Away` at the end.

Tune the fixture's ticks until the story holds, keeping the assertions as they are. If a story beat is impossible under the rules, the rules win: change the fixture, not the rules.

`examples/scale.rs` runs `synthetic(n, 1)` for `n` in `[100, 1000, 10000]` (or the numbers from `std::env::args`) for 100 ticks. It times every `step` with `std::time::Instant`, which is allowed in the CLI crate but never in core. It prints JSON `{occupants, ticks, mean_us, p95_us, max_us}`. Record the results in `city/README.md`, together with the machine description from `uname -m` and the CPU model.

`scripts/check.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cargo build -p city-core --target wasm32-unknown-unknown
echo "city: all checks passed"
```

`city/README.md` covers:
- what the core is, and that it is not player-facing;
- the crates;
- every command, with an example against the two-room fixture;
- how to register `city-mcp` with an MCP client;
- the tick order;
- the viewer rules;
- fixture honesty: feeds declare `fixture` and no real agent state is read;
- the scale table;
- what later sub-projects add.

- [ ] **Step 1: Write the gate test first** (the fixture files do not exist yet).
- [ ] **Step 2: Run and watch it fail.** `include_str!` fails to find the file.
- [ ] **Step 3: Write the fixture files** and tune them until the gate passes, with `check_all` clean on every tick.
- [ ] **Step 4: Run the CLI and MCP against the fixture by hand.** Run `cargo run -p city-cli -- run --manifest fixtures/two-room/manifest.json --feed fixtures/two-room/feed.jsonl --seed 7 --ticks 40 --snapshot-every 10 --out target/gate`, then `inspect` with each of the public, `person:asha` and operator viewers. Confirm that the output makes sense.
- [ ] **Step 5: Scale runs.** Run `cargo run -p city-cli --release --example scale` and record the output.
- [ ] **Step 6: Run `scripts/check.sh`.** Every check must pass, including wasm.
- [ ] **Step 7: Write the documentation** (`city/README.md` and the root README lines).
- [ ] **Step 8: Commit** with `feat(city): gate fixture, scale runs and documentation for the world core`.

---

## Spec coverage map

| Spec requirement | Task |
| --- | --- |
| Four-crate workspace, `city-core` pure and wasm | 1, 2, 13 |
| Stable city IDs; opaque appearance | 1 |
| Occupant kinds and default visibility | 1, 8 |
| Place tree, rooms, seats (Hot/Reserved), pods, departments, doors, overflow | 1, 2 |
| Presence: three dimensions, stamps, Stale, Unknown-not-Working, distinct states, closed summaries | 4, 8 |
| Tick order of seven phases | 6, 7 |
| Seat allocation: reserved held, department-first named policy, overflow chain, no cycles, FIFO waitlist on the original room, capacity never exceeded | 2, 5, 6 |
| Departure releases the seat; re-arrival is new presence | 6 |
| Views per viewer; operator only with a flag | 8, 11, 12 |
| Determinism: ticks, seeded ChaCha, ordered maps, no floats, no ECS | 1, 6, 7, 10 |
| Contracts with schema version and JSON Schema export | 1, 11 |
| Labelled fixture feeds | 3, 13 |
| CLI commands and structural validation | 2, 11 |
| MCP tools over the same functions | 12 |
| Seven invariants under property testing | 9, 10 |
| Scenario tests (overflow/drain, waitlist order, reserved empty, stale feed, owner-only personal agent) | 6, 7, 8 |
| Scale runs at 100, 1,000 and 10,000 | 9, 13 |
| Gate | 13 |
| RD03 default: observers hidden from each other | 8 |
| RD12 minimal grant: presence only | 8 |
