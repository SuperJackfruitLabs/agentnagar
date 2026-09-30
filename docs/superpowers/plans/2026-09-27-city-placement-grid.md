# City placement grid: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One catalogue of kinds and one list of placements become the only solid things in the city. The core derives the walkable grid from rooms minus footprints, and every style draws each thing inside its footprint. Doors work the way they look, and the collision audit reports zero in every style.

**Architecture:**
- **Contracts and core.** `city-contracts` gains the catalogue types and schema 2 of the manifest (placements, building kinds, door widths, levels, instance state and binding). `city-core` gains `footprint.rs` (exact integer geometry) and `placement.rs` (validation, `apply_placement` and incremental updates). `nav.rs` builds the grid from rooms minus footprints.
- **The client** loads the core's grid through the bridge instead of rasterising its own. Packs draw placements from the catalogue's kinds.
- **The change runs expand–migrate–contract:**
  - placements are added beside today's obstacles and props;
  - the fixture and packs move to them;
  - the old fields are removed, and schema 2 becomes mandatory.
- **The collision audit becomes a ratcheting test.** Its per-style budget is lowered to zero, pack by pack.

**Tech Stack:** Rust (`city-contracts`, `city-core`, `city-cli`, `city-mcp`, and `city-godot` via gdext), Godot 4.6.3 GDScript, and Python for the fixture generator and the audit composer.

**Spec:** `docs/superpowers/specs/2026-09-27-city-placement-grid-design.md`. It is binding; read it before any task. The interactions spec (`2026-09-27-city-interactions-design.md`) explains why anchors, capabilities, `state` and `binding` exist, but this plan builds none of their behaviour.

## Global Constraints

- **Workspace.** Work in a dedicated git worktree, on branch `feat/city-placement-grid`. The branch already carries the spike's probes (`city/godot/tools/probes/`) and the audit tool (`city/godot/tools/collision_audit.gd` and `tools/collision_audit/`). Never use a bare `git stash`.
- **Commit messages** end with:
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01JKP5riujFNbo1iL4Yjv4qQ
  ```
- **Rust checks,** from `city/`: `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace` and `cargo build -p city-core --target wasm32-unknown-unknown`. All four stay green after every task.
- **Godot suite,** from `city/godot`:
  - Run `../scripts/build-godot.sh` whenever Rust changes, then `godot --headless --path . --script res://tests/run_all.gd`. It stays green; record the baseline count in the ledger before Task 1.
  - Run `godot --headless --path . --import --quit` after adding `class_name` scripts or assets.
- **Determinism** (README "Determinism"):
  - no floating point in the rules;
  - every store ordered;
  - placements processed in ID order;
  - no new RNG draws.
  - A manifest with no placements, no building kinds and no door widths keeps a byte-identical event log until Task 9 removes schema 1.
- **Values** (spec §2–3), used verbatim:
  - cells stay 25 cm, with the centre at the corner plus 12 cm;
  - the body clearance margin is **10 cm**;
  - the walking band is **25–190 cm** above the ground stood on;
  - building `wall` defaults to **25 cm**;
  - exterior `door_width` is **200 cm**, and interior doors **100 cm**;
  - the tram kind's `width` is **250 cm**, so `HALF_WIDTH` is 125;
  - snaps: architecture 200, buildings 100, street furniture 25, seats 1;
  - the sine and cosine table covers whole degrees, scaled to **65,536** (2¹⁶) and rounded once;
  - the catalogue version is **1**, and the manifest `schema_version` becomes **2** in Task 9;
  - placement IDs are `placement:<slug>`.
- **Anchor types:** `enter`, `sit`, `use`, `display` and `stand`. **Capability names** accepted by validation: `inspect`, `sit`, `use`, `read`, `open`, `board`, `carry`, `store` and `write`. Only `sit` and `board` have behaviour, and it is today's behaviour.
- **Levels:** every non-zero `level` is refused with the message `levels above the ground arrive with rooftops`.
- **Scale targets** (spec §1.5), in a native release build: a 400 × 400 m synthetic district with 5,000 placements builds in **200 ms** or less; one placement change updates in **1 ms** or less.
- **Tests never write** the real `user://settings.cfg`. Live infrastructure is never touched.
- **Code voice:**
  - plain-sentence doc comments (`///` in Rust, `##` in GDScript);
  - tabs in GDScript, rustfmt in Rust;
  - names spelled out;
  - comments explain why, not what.
- **Evidence** is committed under `city/godot/evidence/placement-*`. Visual baselines are never overwritten to make a test pass; a failed frame is inspected and its cause stated.

## Review Focus

1. **A placement change under someone's feet or path during play.** It is refused when it would cover a held cell. Otherwise walkers whose path crosses a newly blocked cell re-plan on the next tick, with no one inside a solid, and the replay is byte-identical. Task 4 tests this.
2. **A player steering straight at a 2 m door from 90 cm off its centre, or at exactly 45° in pixel art.** They get in, in every style. Tasks 2 and 15 test this.
3. **A full room entered by steering.** The step is refused with a notice, not a silent queue or overflow. Go still queues or overflows, and says so. Task 14 tests this.
4. **The client and core disagreeing about a cell after a placement change.** It never happens, because the client applies `grid_changes` to the grid it loaded. Task 5 tests this.
5. **A style drawing a kit wider than its footprint after a later art change.** The audit test fails and names the mesh, kind and position. Task 10 tests this.

---

### Task 1: The catalogue and footprint geometry

**Files:**
- Create: `city/catalogue/catalogue.json`, `city/crates/city-contracts/src/catalogue.rs`, `city/crates/city-core/src/footprint.rs`
- Modify: `city/crates/city-contracts/src/lib.rs` (export, `all_schemas()`), `city/crates/city-core/src/lib.rs`
- Test: `city/crates/city-contracts/tests/contracts.rs`, unit tests in `footprint.rs`

**Interfaces:**
- **`catalogue.rs`:**
  - `Catalogue { version: u32, kinds: Vec<Kind> }`
  - `Kind { id: String, name: String, description: String, class: Class, footprint: Vec<Shape>, soft: Vec<Shape>, sized: bool, snap: i32, anchors: Vec<Anchor>, capabilities: Vec<Capability>, state: Vec<StateField>, height: i32, wall: Option<i32>, door_width: Option<i32>, width: Option<i32> }`
  - `Class { Furniture, Seat, Fixture, Planting, Block, Building, Vehicle }`, kebab-case.
  - `Shape` is tagged by field: `Rect { x, z, w, d }` or `Disc { x, z, r }`, in cm, in the kind's frame (origin at the placement point, facing 0 = north, x east, z south).
  - `Anchor { kind: AnchorType, at: Point, facing: i32, height: Option<i32>, size: Option<Size> }` with `AnchorType { Enter, Sit, Use, Display, Stand }`. The JSON key is `type`.
  - `Capability { name: String, at: AnchorType }`
  - `StateField { name: String, ty: StateType, default: serde_json::Value }` with `StateType { Bool, Int, Text, Ref }`. The JSON key is `type`.
  - `Size { w: i32, d: i32 }`
  - `Catalogue::builtin() -> &'static Catalogue` parses `include_str!("../../../catalogue/catalogue.json")` once, using `std::sync::OnceLock`.
  - `Catalogue::kind(&self, id: &str) -> Option<&Kind>`
- **`catalogue.json`,** version 1, has every kind in spec §2's "first catalogue" list, plus `street-lamp`, `catenary-pole` and `bollard`.
  - Footprints start **provisional**, taken from the manifest's current obstacles, where one exists, or from the audit's measured sizes in `.superpowers/collision-audit/*-report.json`. Task 10 replaces them with measured values.
  - Buildings: `wall: 25`, `door_width: 200`. `tram`: `width: 250`.
  - `name` and `description` are one short plain sentence each.
- **`footprint.rs`:**
  - `pub const MARGIN: i64 = 10;`
  - `pub fn sin_cos(deg: i32) -> (i64, i64)`: a table of 360 entries scaled to 65,536, using `rem_euclid(360)`.
  - `pub struct Placed { shapes: Vec<Shape>, at: Point, facing: i32 }`
  - `pub fn covers(placed: &Placed, p: Point, margin: i64) -> bool`: true when `p` lies inside a shape grown by `margin`. A rect's inside includes its minimum edges and excludes its maximum edges, matching `Rect::contains`. A disc compares `dx² + dz² < (r + margin)²` in `i64`. To test a rotated rect, rotate `p - at` by `-facing` using the table: `x' = (dx·cos + dz·sin) >> 16` and `z' = (−dx·sin + dz·cos) >> 16`, with an arithmetic shift, then test the unrotated rect.
  - `pub fn bounds(placed: &Placed, margin: i64) -> Rect`: an axis-aligned box covering the shape at any facing (the rotated corners, plus the margin, rounded outward).
- **Test additions:**
  - Contract tests: the catalogue round-trips as JSON; every kind's anchors, capabilities and state use known names; `all_schemas()` contains `"Catalogue"`.
  - `footprint` tests:
    - `sin_cos(0) == (0, 65536)`, `sin_cos(90) == (65536, 0)`, `sin_cos(-90) == sin_cos(270)`;
    - a 100 × 60 rect at facing 90 covers a point that facing 0 does not;
    - the margin grows a rect by exactly 10 cm on each side (a point 9 cm outside is covered, one 10 cm outside is not);
    - a disc's boundary uses strict `<`;
    - `bounds` contains every covered point, on a 1 cm sweep of a small shape at facing 37.
  - The wasm32 build compiles `footprint.rs`, with no floats.

- [ ] **Step 1: Write the failing contract and footprint tests listed above.**
- [ ] **Step 2: Run them.** `cargo test -p city-contracts -p city-core footprint` fails, because the types are not defined.
- [ ] **Step 3: Implement the types, the JSON and `footprint.rs`.**
- [ ] **Step 4: Run all the Rust checks.** They pass.
- [ ] **Step 5: Commit** with `feat(city): the catalogue and exact footprint geometry`.

---

### Task 2: Placements in the manifest, and the grid built from them

**Files:**
- Modify:
  - `city/crates/city-contracts/src/manifest.rs`
  - `city/crates/city-core/src/index.rs` (`RoomInfo`, the validation pass, and a new `placements` field on `PlaceIndex`)
  - `city/crates/city-core/src/nav.rs` (`build`, door spans)
  - every compile fix in city-cli, city-mcp and city-godot
- Create: `city/crates/city-core/src/placement.rs` (validation only in this task)
- Test: unit tests in `nav.rs` and `placement.rs`; `city/crates/city-core/tests/invariants.rs` (generated layouts gain random placements)

**Interfaces:**
- **`manifest.rs`,** all new fields optional or defaulted and skipped when empty, so schema 1 files still parse byte-for-byte:
  - `Placement { id: PlaceId, kind: String, at: Point, facing: i32, level: i32, size: Option<Size>, state: BTreeMap<String, serde_json::Value>, binding: Option<Binding> }` and `Binding { source: String, reference: String }`. The JSON key for `reference` is `ref`.
  - `District.placements: Vec<Placement>`, `Facility.kind: Option<String>`, `Door.width: Option<i32>`, `Seat.anchor: Option<u32>`, `Room.level: i32`, and `Manifest.catalogue: Option<u32>`.
- **`PlaceIndex.placements: Vec<PlacedInfo>`,** in ID order, where `PlacedInfo { id, kind: &'static Kind, placed: footprint::Placed, level, district: PlaceId }`, plus `PlaceIndex.buildings: Vec<BuildingInfo { facility, kind, rooms: Vec<PlaceId>, wall, door_width }>`.
- **`placement::validate(m: &Manifest, cat: &Catalogue, out: &mut Vec<ValidationIssue>)`,** called from the existing validation. The issue codes:
  - `unknown-kind`
  - `level-not-supported` (message verbatim from the Global Constraints)
  - `off-snap`
  - `size-missing`, `size-not-allowed`
  - `placement-covers-seat`, `placement-covers-door`, `placement-covers-track`, `placement-covers-anchor`
  - `anchor-unreachable`, which names the anchor type
  - `room-too-small`, when a room keeps fewer walkable cells than `max(seats, capacity)`
  - `bad-state`, `bad-binding`: only kinds with a `display` anchor may be bound
  - `catalogue-version`
  - `one-district-layout`, when more than one district has rooms with rects
- **`NavGrid::build(index)`:** a cell is walkable when rule 1 holds (the room rect, as today) and **no placement's `covers(placed, centre, MARGIN)`** holds, among placements of the same level (0), and the old obstacles still exclude it. There are three exceptions:
  - A **seat cell** (the cell of a seat's `pos`) is never blocked by any footprint.
  - **Door-span cells** are never blocked by their own building's shell.
  - A **building shell** is a set of `Placed` rects: each room rect of a facility with `kind`, grown outward by `wall`, minus the room rect itself (four side rects), less an opening centred on each door, `door.width.unwrap_or(kind.door_width)` wide for doors to rooms outside the facility and 100 wide for doors inside it. Interior partitions are a rect `wall` thick centred on each shared edge, with the same openings.
- **Door spans** use the door's width, `half = width / 2`, in place of `DOOR_HALF_WIDTH`. The depth stays two cells either side. `DOOR_HALF_WIDTH` remains only as the default for a door with no width and no building kind.

- [ ] **Step 1: Write the failing tests.**
  - A schema 1 manifest (the two-room gate fixture) parses, validates, and gives a grid identical cell for cell to today's.
  - A `desk` placement blocks exactly the cells whose centres lie within 10 cm of its rect, at facings 0, 90 and 36.
  - A seat whose furniture footprint covers its own cell still has a walkable seat cell.
  - A facility with `kind: "guild-hall"` blocks one row of outdoor cells around its rooms, never its rooms' own cells, and leaves each exterior door's opening walkable across 200 cm.
  - A door with `width: 200` has a span of eight cells along the wall.
  - One test per validation code.
  - A property test: generated layouts with random placements never have a walkable cell whose centre lies within `MARGIN` of a footprint, except seat and door-span cells.
- [ ] **Step 2: Run them.** They fail.
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run all the Rust checks and both scenario gates.** The district fixture has no placements yet, so its log is unchanged. Confirm this by comparing the replay checksum before and after.
- [ ] **Step 5: Commit** with `feat(city): placements and building shells carve the walkable grid`.

---

### Task 3: Seat cells, tram width and the door step in the core's pathing

**Files:**
- Modify: `city/crates/city-core/src/nav.rs` (`can_step`, `path*`), `walk.rs` and `world.rs` (Steer refusal), `transit.rs` (`HALF_WIDTH` from the kind), `city-contracts/src/event.rs` (`RejectReason::Seat`)
- Test: `nav.rs` and `transit.rs` unit tests, and `city/crates/city-core/tests/`

**Interfaces:**
- `NavGrid::is_seat_cell(c) -> bool`
- **Paths:**
  - A path may enter a seat cell only as its final cell.
  - A path starting on a seat cell may leave it.
  - `field_from` and `descend` treat seat cells as sinks: they are reached, but not passed through.
- **Steer:** a steered step onto a seat cell is refused with `RejectReason::Seat`.
- **Tram width:** `transit::HALF_WIDTH` becomes `fn half_width(line) -> i64`, which reads the catalogue kind named by `VehicleSpec.kind: Option<String>`, defaulting to `"tram"`: 250 / 2 = 125. Line validation keeps its 150 cm platform rule and adds `platform-in-vehicle-clearance`, raised when `half_width + MARGIN > 150`.

- [ ] **Step 1: Write the failing tests.**
  - A path between two points on either side of a row of bench seats goes round, not across.
  - A Go to a seat still arrives.
  - A Steer onto an empty seat cell is refused with `Seat`.
  - The footprint test in `transit.rs` (`a_footprint_is_the_track_cells_along_the_vehicle_two_metres_wide`) is renamed and asserts 2.5 m.
  - A platform 150 cm from its track stays clear of the footprint.
- [ ] **Step 2: Run them.** They fail.
- [ ] **Step 3: Implement it.** Regenerate the core's replay and scenario fixtures that change, in the same commit. The invariants hold on every tick of both gates. Ledger the fixture files changed, with the reason: the tram footprint widened.
- [ ] **Step 4: Run the Rust checks.**
- [ ] **Step 5: Commit** with `feat(city): seats are destinations and trams are 2.5 m wide`.

---

### Task 4: Placement commands and incremental updates

**Files:**
- Modify: `city/crates/city-core/src/placement.rs`, `world.rs` (operator input), `nav.rs` (`rebuild_region`), `project.rs`, `city-contracts/src/{feed,projection,event}.rs`
- Test: `placement.rs` unit tests; `city/crates/city-core/tests/placement_props.rs` (new, proptest); `city/crates/city-core/benches/` or an `#[ignore]` release test `scale_district`

**Interfaces:**
- **Commands:** `Command::Place { placement: Placement }`, `Command::Move { id, at, facing }` and `Command::Remove { id }`, with `CommandType`s. They are operator commands, refused for players with `RejectReason::NotOperator`.
- **`World::apply_placement(cmd) -> Result<Vec<Cell>, RejectReason>`:**
  - runs `placement::validate_one` against the current index;
  - refuses with `PlacementCoversOccupant` when a newly blocked cell is held or reserved;
  - refuses with `PlacementDisconnects` when two rooms connected before are no longer connected, checked by a flood fill over room adjacency;
  - on success, updates `index.placements` and calls `NavGrid::rebuild_region(bounds)` over the union of the old and new `footprint::bounds(…, MARGIN)`;
  - returns the cells whose walkability changed.
  - It is applied between ticks, in the Ingest order, and recorded in the input log.
- **Loading** applies every authored placement through `validate_one` in ID order, so authored and runtime placements share one validator.
- **After a change:**
  - walkers whose remaining path crosses a changed cell re-plan on the next tick;
  - queue slots are recomputed for rooms owning changed cells;
  - events: `PlacementChanged { id, change: Placed | Moved | Removed }`.
- **`Projection.grid_changes: Vec<GridChange { i, j, walkable: bool }>`,** for the tick of the change only, skipped when empty.

- [ ] **Step 1: Write the failing tests.**
  - Place, move and remove a bench.
  - Refusals: covering a standing walker, disconnecting the plaza from the workshop, an off-snap point, a non-zero level.
  - A walker whose path crosses a new placement re-plans and arrives.
  - A proptest over random sequences of 1–40 commands on generated layouts: the grid after incremental updates equals `NavGrid::build` from scratch, cell for cell.
  - A replay with placement commands is byte-identical.
  - `scale_district` (`#[ignore]`, run with `cargo test --release -- --ignored scale_district`) builds a 400 × 400 m grid with 5,000 seeded placements in 200 ms or less, and applies 100 moves at 1 ms or less each. It prints the timings; ledger them.
- [ ] **Step 2: Run them.** They fail.
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the Rust checks, plus `scale_district` in release.**
- [ ] **Step 5: Commit** with `feat(city): placements change at runtime, and the grid follows`.

---

### Task 5: The client loads the core's grid

**Files:**
- Modify: `city/crates/city-godot/src/bridge.rs` (`layout_json` gains `grid`; `catalogue_json`), `city/godot/core/nav_query.gd` (load, not rasterise), `city/godot/core/city_geometry.gd` (`clear_of_walkable`), `city/godot/main.gd` (apply `grid_changes`)
- Test: `city/godot/tests/test_nav_query.gd` (adapt), `test_bridge.gd`, and the bridge's Rust tests

**Interfaces:**
- **`layout_json().grid`:** `{ origin: {x, z}, cols, rows, levels: [{ level: 0, rooms: "<RLE>" }], rooms: [ids…], outdoor: [bool…], spans: [{ rooms: [a, b], cells: [[i, j]…] }], seats: [[i, j]…] }`.
  - The RLE is a flat list of `[room_index_or_-1, run_length]` pairs over rows, then columns.
- **`catalogue_json()`** returns `Catalogue::builtin()`.
- **`NavQuery.from_layout(layout)`** reads `layout.grid`. The rasterising `_build`, `_lay`, `DOOR_HALF_WIDTH` and the room-rect rules are deleted. `seats`, `_held` and `_closed` stay as they are.
- **`NavQuery.apply_changes(changes: Array)`** is called from the projection path in `main.gd`.
- **`CityGeometry.clear_of_walkable(nav: NavQuery, rect_cm: Rect2i, margin_cm := 10) -> bool`**

- [ ] **Step 1: Write the failing tests.**
  - For the district fixture, the bridge-loaded `NavQuery` agrees with the core on every cell: `walkable`, `room_at`, `in_door_span`, and `can_step` for every neighbour pair of every 7th cell.
  - `apply_changes` flips exactly the listed cells.
  - `clear_of_walkable` is true on water and false on the plaza.
- [ ] **Step 2: Run them.** They fail.
- [ ] **Step 3: Implement it.** Rebuild the extension and run the import.
- [ ] **Step 4: Run the Godot suite and the Rust checks.** The probes in `tools/probes/` that call `from_layout` still run: run `door_probe.gd` once and confirm it still produces its table.
- [ ] **Step 5: Commit** with `feat(city): the client walks on the core's grid`.

---

### Task 6: Catalogue and placement tools

**Files:**
- Modify: `city/crates/city-cli/src/{main,commands}.rs`, `city/crates/city-mcp/src/lib.rs`, `city/README.md` (the Tools section)
- Test: `city/crates/city-cli/tests/`, and the MCP tool tests

**Interfaces:**
- **`city-cli catalogue [--kind <id>]`:** lists kinds as a table, or one kind's JSON.
- **`city-cli grid <manifest> [--png <out>]`:** prints the cell count, walkable count, and blocked-by-placement count per kind. With `--png`, it writes a 1 px-per-cell image: walkable white, rooms tinted, footprints red, door spans green, seat cells blue.
- **`city-cli place <manifest> --kind <k> --at <x,z> [--facing <deg>] [--size <w,d>] [--id <id>] [--write]`:** validates through `apply_placement` on a loaded world and prints the result. `--write` rewrites the manifest with the placement added, keeping key order, and exits non-zero with the core's reason when it is refused.
- **`city-cli validate`** reports every new issue code.
- **MCP tools:** `catalogue`, and `check_placement { manifest, placement }` returning `{ ok, reason?, changed_cells }`. `validate` is unchanged in form.

- [ ] **Step 1: Write the failing CLI and MCP tests.** Cover each command's success and refusal, `--png` dimensions, and `--write` round-tripping.
- [ ] **Step 2: Run them.** They fail.
- [ ] **Step 3: Implement the commands and tools, and document them in the README.**
- [ ] **Step 4: Run the Rust checks.**
- [ ] **Step 5: Commit** with `feat(city): catalogue, grid and place in the CLI and MCP`.

---

### Task 7: The fixture moves to placements

**Files:**
- Modify: `city/fixtures/district/generate.py`, `city/fixtures/district/manifest.json` (regenerated), the fixture test that checks the generator's output
- Test: `cargo test --workspace` (scenario gates), and `city-cli validate`

**Interfaces:** the generator emits, per spec §5:
- facility `kind`s;
- door `width`s, where they differ from the default;
- seat `kind`s and `anchor`s;
- `district.placements` for every row of the spec §5 table;
- one planting, lamp and catenary-pole arrangement. It takes today's solarpunk pack as its source, because it has the most complete set: read `_plant` in `styles/pack_3d.gd` and the solarpunk lamp code for positions. It lays everything on verges and lawns, never on a cell within 10 cm of a walkable cell centre.

It **keeps** `obstacles`, `props`, `exterior`, `TreeRow` and `Block` for the packs until Task 8, but drops each obstacle that a placement now covers exactly. It validates by calling `city-cli validate`, and, where a building shell covers an outdoor room's cells, moves the nearby placement or seat and records the move in a comment.

- [ ] **Step 1: Write the fixture checks, which fail.**
  - Every facility has a kind.
  - The guild hall's and library's exterior doors are 200 wide.
  - Every seat has a kind from the catalogue.
  - The placement count per kind matches a table in the test.
  - `city-cli validate` is clean.
- [ ] **Step 2: Run them.** They fail.
- [ ] **Step 3: Implement the generator, and regenerate.**
- [ ] **Step 4: Run the Rust checks and both scenario gates.** Regenerate the replay fixtures that change, and ledger them. Every invariant holds on every tick. The tram scenario still delivers every arrival and departure.
- [ ] **Step 5: Run the Godot suite.** Packs still draw from the old fields, so nothing visible changes, but the grid has. Tests asserting old cell counts are updated, with the reason ledgered.
- [ ] **Step 6: Commit** with `feat(city): the district is laid out as placements`.

---

### Task 8: Packs draw placements

**Files:**
- Modify:
  - `city/godot/styles/style_pack.gd` (`REQUIRED["props"]` becomes the catalogue's kind IDs)
  - `city/godot/core/city_geometry.gd`: `placements(manifest) -> Array`, each `{id, kind, pos: Vector2 m, facing, size, level}`, and `building_kind(facility)`
  - `city/godot/styles/pack_3d.gd`, `city/godot/styles/pixel_art/pack.gd` and each style's `style.json`
- Test: `test_style_pack.gd`, the pack suites (`lit_pack_suite.gd`, `test_anime_pack.gd`, `test_pixel_pack.gd` and the rest), and `test_city_geometry.gd`

**Interfaces:**
- Packs draw every placement's kit from `placements()`. They stop reading `r.props`, `r.obstacles`, `exterior`, `tree-row` and `block`.
- `_plant` (in `pack_3d.gd`) and `_grove` (in pixel art) stop scattering over rooms. Planting comes from placements, and any pure-decor scatter a pack keeps must pass `CityGeometry.clear_of_walkable`.
- Solarpunk's and neon's lamps and every pack's catenary poles come from placements.
- Every kind is mapped in every `style.json`, or declared a placeholder, as today.

- [ ] **Step 1: Write the failing tests.**
  - For each pack, every placement in the district gets one drawn node or sprite, keyed by placement ID.
  - No pack reads `props` or `obstacles`: a test loads the fixture with both fields stripped and gets the same node count.
  - Each pack's decor scatter lies clear of walkable cells.
- [ ] **Step 2: Run them.** They fail.
- [ ] **Step 3: Implement it.** Re-import.
- [ ] **Step 4: Run the Godot suite.** Capture one street view per style with `tools/capture` (as the evidence scripts do), and compare by eye with v0.0.3's evidence. Differences are expected only in planting and lamp positions. Ledger what changed.
- [ ] **Step 5: Commit** with `feat(city): every style draws the catalogue's placements`.

---

### Task 9: Schema 2, and the old fields removed

**Files:**
- Modify: `manifest.rs` (remove `Room.obstacles`, `Room.props`, `Facility.exterior`, `Scenery::TreeRow` and `Scenery::Block`), `index.rs` (`SCHEMA_VERSION = 2`, and a v1 message), `nav.rs` (remove obstacle rules), `generate.py` (stop emitting them), the fixture, every in-code test manifest, and the CLI test fixtures
- Test: the full Rust suite and the Godot suite

**Interfaces:**
- **A schema 1 manifest is refused** with `schema-version`, message: `This manifest is schema 1. Regenerate it with city/fixtures/district/generate.py, or move its obstacles and props into district placements (docs/superpowers/specs/2026-09-27-city-placement-grid-design.md §3).`
- **Scenery overlap validation** keeps its rules for `Water`, `Street`, `Bridge` and `Fence`. Block placements are covered by `placement-*` issues.

- [ ] **Step 1: Write the failing tests.** Schema 1 is refused with that message. `Scenery` no longer accepts `tree-row` or `block`.
- [ ] **Step 2: Run them.** They fail.
- [ ] **Step 3: Remove the old fields everywhere.** Convert every in-code test manifest to placements. The two-room gate's obstacles become `desk` or `workbench` placements, or a sized `planter` where no kind fits; ledger each conversion. Regenerate the fixtures.
- [ ] **Step 4: Run the Rust checks, both scenario gates and the Godot suite.**
- [ ] **Step 5: Commit** with `feat(city)!: manifest schema 2 — placements replace obstacles and props`.

---

### Task 10: The collision audit becomes a ratcheting test, and footprints are measured

**Files:**
- Create: `city/godot/tests/test_collision_audit.gd`, `city/godot/evidence/placement-budget.json`
- Modify: `city/godot/tools/collision_audit.gd` and its `collision_audit/` helpers (a library entry point, `--measure-kinds`), `city/catalogue/catalogue.json` (measured footprints), `city/godot/tests/run_all.gd`
- Test: the new test, and the Rust suite (the catalogue changed)

**Interfaces:**
- **`CollisionAudit.run(style: String, opts := {}) -> Dictionary`**, a callable library the test uses. It returns the spec §1.1 counts, each with a list of offenders `{ kind, placement_id or mesh path, cell, depth_cm }`:
  - `through`
  - `within_10cm`, excluding seat cells
  - `walker_pass`
  - `player_pass`
  - `tram_overlap`
  - `reverse_blocked`, excluding ground outside every room
  - It **classifies drawn geometry by placement ID** (every drawn node is tagged with its placement's ID in Task 8), not by name heuristics. Untagged geometry is reported as `untagged` and counts as an offender.
- **`--measure-kinds`** writes, for each kind, the widest walking-band silhouette across all six styles, rounded up to 5 cm, as rects and discs in the kind's frame, to `evidence/placement-kind-sizes.json`.
- **`placement-budget.json`:** `{ "<style>": { "through": n, "within_10cm": n, … } }`. The test fails when any count exceeds its budget, **or is below it**, so budgets are lowered in the same commit that earns them.

- [ ] **Step 1: Write the test.** It runs `CollisionAudit.run` for each of the six styles, compares against the budget, and prints every offender over budget.
- [ ] **Step 2: Measure.** Run `--measure-kinds`. Set each kind's catalogue footprint to the measured size, except where the spec §2 rule applies (a kit well outside the common size is trimmed in its pack task instead). Ledger each such kind.
- [ ] **Step 3: Rebuild, regenerate the fixture, and run the Rust checks and scenario gates.**
- [ ] **Step 4: Run the audit for the six styles.** Write the current counts as the budget, then run the Godot suite, including the new test. It passes.
- [ ] **Step 5: Commit** with `test(city): the collision audit gates every style`.

---

### Task 11: The shared 3D kit fits its footprints (low-poly, anime, solarpunk, neon)

**Files:**
- Modify:
  - `city/godot/styles/pack_3d.gd`
  - `city/godot/styles/kit_town.gd`
  - `city/godot/styles/lowpoly_tropical/townscape.gd`
  - the lit styles' kit scripts and assets (`styles/lit/`, `anime_cel/`, `solarpunk/` and `neon_noir/`), including `lib_entrance`
  - the tram layout: `styles/tram_layout.json`, and each pack's tram body
  - `evidence/placement-budget.json`
- Test: `test_collision_audit.gd` and the pack suites

**Interfaces:**
- **Shells.** Walls stand outside the room rects at the kind's `wall` thickness. Openings are drawn at each door's width: `KitTown.bays` takes the door width from the manifest instead of `HALL_BAY`. Interior partitions straddle the shared edge. The library entrance's lit panel is removed and its leaves are drawn open.
- **The bridge** draws parapets outside the deck.
- **Blocks** draw buildings, porches and steps inside the block's size.
- **Trams** are drawn 250 cm wide.
- **Every kit** stays inside its footprint in the walking band. Anything that must stay larger is trimmed: benches' ends, the banyan's roots, the shelters' posts.

- [ ] **Step 1: Set the four styles' budgets to zero.** The audit test fails, listing offenders.
- [ ] **Step 2: Fix offenders, kind by kind, re-running the audit for one style at a time.** Commit per kind group if useful: shells and doors; furniture; planting and fixtures; bridge, blocks and trams.
- [ ] **Step 3: Run the Godot suite and the frame bench** (`tests/test_frame_cost.gd` and the bench from the README), from a GPU below 60 °C, under `system76-power profile performance`, fullscreen at native resolution. Each style stays within noise of v0.0.3's recorded figures; ledger the numbers.
- [ ] **Step 4: Capture evidence.** For each of the four styles: an audit overlay after the fix, and door captures (`tools/probes/capture_doors.gd`) into `evidence/placement-<style>-*.png`.
- [ ] **Step 5: Commit** with `feat(city): the 3D styles draw inside their footprints`.

---

### Task 12: Voxel fits its footprints

**Files:** `city/godot/styles/voxel/` (townscape, kit, tram), and `evidence/placement-budget.json`
**Interfaces:**
- The same rules as Task 11, in voxel's builder.
- Voxel's `DOOR_W = 4.0` is replaced by each door's width.
- The great tree fills its footprint; it is no longer a thin trunk on open paving.

- [ ] **Step 1: Set voxel's budget to zero,** and watch the audit fail.
- [ ] **Step 2: Fix the offenders.**
- [ ] **Step 3: Run the suite and the bench,** under the Task 11 conditions.
- [ ] **Step 4: Capture evidence.**
- [ ] **Step 5: Commit** with `feat(city): voxel draws inside its footprints`.

---

### Task 13: Pixel art fits its footprints

**Files:** `city/godot/styles/pixel_art/` (`pack.gd`, `townscape.gd`, the sprite render pipeline and its sources, and the regenerated sprites), and `evidence/placement-budget.json`
**Interfaces:**
- Each sprite's ground footprint (the model it was rendered from) fits its kind's footprint.
- Door sprites are drawn at each door's width. The partition gap in `townscape.gd` is 100 cm.
- Sprites whose model changed are regenerated with the existing pipeline, and the rest are left untouched.

- [ ] **Step 1: Set pixel art's budget to zero,** and watch the audit fail.
- [ ] **Step 2: Fix the offenders, and regenerate the changed sprites.**
- [ ] **Step 3: Run the suite, including `test_pixel_pack.gd`'s snapshot checks.** Where a snapshot differs, inspect the frame and state the cause in the ledger. A baseline is updated only when the change is the intended refit.
- [ ] **Step 4: Capture evidence.**
- [ ] **Step 5: Commit** with `feat(city): pixel art draws inside its footprints`.

---

### Task 14: Doors: steered entries and notices (core and client)

**Files:**
- Modify: `city/crates/city-core/src/world.rs` (steered admission), `event.rs`, `city/godot/main.gd` (`_notice_events`, the prompt), `city/godot/core/player.gd` (`closed_rooms` on the prompt)
- Test: the core's admission tests, `test_notices.gd` (or its current equivalent), and `test_player.gd`

**Interfaces:**
- **A steered step onto the span of a room that is full, or queued for by others,** is refused with `RejectReason::RoomFull { room }`. It is never waitlisted and never overflowed.
- **Go and Room** keep waitlisting and overflow.
- **Notices** (`main.gd`), verbatim with the room's name:
  - on `RoomFull`: `The <room> is full — choose Go in to queue.`
  - on `Waitlisted`: `You're next in line for the <room>.` When the player is not first: `You're in line for the <room>.`
  - on `Overflowed`: `The <room> is full; you've been let into the <overflow room>.`
- **The prompt** shows `Full` beside the door's caption when the room is in `Player.closed_rooms`.

- [ ] **Step 1: Write the failing tests.**
  - Core: at tick 108 of the fixture, when the workshop is full, a Steer into its span is refused with `RoomFull`, and no `Waitlisted` or `Overflowed` event follows. A Go to the workshop at the same tick still waitlists.
  - Client: each notice's text, and the `Full` prompt.
- [ ] **Step 2: Run them.** They fail.
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the Rust checks, the scenario gates and the Godot suite.** Agents' admission logs are unchanged, because agents never Steer. Verify with the district replay, where only player-steer lines may differ.
- [ ] **Step 5: Commit** with `feat(city): walking into a full room says so`.

---

### Task 15: Doors: the approach step, "Go in" and "Walk here" (client), and the entry test

**Files:**
- Modify: `city/godot/core/player.gd` (`_next_cell`), `city/godot/main.gd` (`_interact`: the "Go in" room), `city/godot/core/fpv_camera.gd` (aiming inside a building)
- Create: `city/godot/tests/test_door_entry.gd`, a library form of `tools/probes/door_probe.gd`
- Test: `test_player.gd` and the new test

**Interfaces:**
- **`_next_cell`:** when the line's preferred step is refused, take an allowed candidate that crosses into another room before any step along the wall. It still respects `enterable`, held cells and seat cells. This is the rule in `tools/probes/door_seeking_player.gd`, moved into production and cleaned up.
- **"Go in"** targets the room whose door span is nearest the crosshair's hit on the building. It falls back to the building's first room only when no door is within 3 m.
- **"Walk here" inside a building** snaps to the nearest walkable cell of that building's rooms, never to ground beyond its walls.
- **`test_door_entry.gd`** runs, for every building door in every style, in pure logic on the loaded client:
  - the straight-in family across the drawn opening (−100…+100 cm);
  - the angled sweep from −80° to +80° in 5° steps;
  - pixel art's four keys, each at exactly 45°;
  - first-person "Go in".

  It asserts **100%** entry for each, and prints its table.

- [ ] **Step 1: Write the failing tests.**
  - `test_player.gd`: at each door orientation, the ±45°, 50° and 60° approaches get in.
  - `test_door_entry.gd`, as above.
- [ ] **Step 2: Run them.** They fail. Record the failure counts in the ledger.
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the Godot suite.** Every entry is 100%.
- [ ] **Step 5: Commit** with `feat(city): doors let you in from any reasonable approach`.

---

### Task 16: Evidence, docs and the spec's amendments

**Files:**
- Modify: `city/README.md` (the grid, the catalogue, placements, tools and budgets), `docs/superpowers/specs/2026-09-27-city-placement-grid-design.md` (a dated Amendments section recording the ledger's rulings), `city/godot/evidence/placement-notes.md` (new)
- Test: everything, once more

**Interfaces:**
- **`placement-notes.md`** records:
  - the audit's before and after for each style (the spike's numbers against zero);
  - the door-entry table;
  - the scale timings;
  - the frame bench against v0.0.3;
  - links to each evidence image.
- **The README's tests section** names `test_collision_audit.gd`, `test_door_entry.gd` and `scale_district`.

- [ ] **Step 1: Run every check.** That is the Rust checks, `scale_district` in release, both scenario gates, and the Godot suite.
- [ ] **Step 2: Write the notes, the README and the amendments.**
- [ ] **Step 3: Commit** with `docs(city): placement grid evidence and notes`.
