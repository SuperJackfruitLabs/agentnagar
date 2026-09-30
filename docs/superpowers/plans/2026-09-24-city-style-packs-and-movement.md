# City Style Packs and Movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the city world core deterministic walking (layout, navigation grid, door admission, queues, avoidance) and a clock, then render one live district in a Godot client with three swappable style packs: low-poly tropical, pixel art and voxel.

**Architecture:** Movement, layout and time are simulation data in Rust (`city-contracts`, `city-core`), with integer centimetres and no floats in rules. A gdext extension (`city-godot`) exposes the world to Godot as JSON projections. The Godot client (`city/godot/`) has a style-agnostic core that turns projections into semantic changes, and style packs that render them. A pack is a folder under `styles/` with `style.json`, assets and `pack.gd`; the client discovers packs by scanning that folder.

**Tech Stack:**
- Rust 1.95 workspace (existing), plus `godot` 0.5.5 (`api-4-6`)
- Godot 4.6.3 (flatpak, gl_compatibility), GDScript
- Blender 5.2.2 (bpy, low-poly GLBs)
- Python 3 with Pillow 10.2 (pixel sprites)
- Khronos `gltf-validator` 2.0.0-dev.3.10 (pinned in `prototypes/voxel-work-bay/tools`)

**Spec:** `docs/superpowers/specs/2026-09-24-city-style-packs-and-movement-design.md`

## Global Constraints

- **No floats in rules.** `city-contracts` and `city-core` use no floats, `HashMap` or clocks. Positions are integer centimetres (`i32`), facings are integer degrees (`i32`, clockwise from north), and the ground plane is x east, z south.
- **Backward compatibility.** Every contract addition is optional (`#[serde(default)]`) and `SCHEMA_VERSION` stays 1. Every existing test must keep passing unchanged, except where a task says otherwise.
- **No layout means old behaviour.** A manifest without layout behaves exactly as before (door transit timers). A manifest with layout has it everywhere.
- **Grid and walking constants:** cell size 25 cm; A* costs 10 straight and 14 diagonal; up to 5 cells per tick; re-plan after 3 blocked ticks.
- **Hidden occupants are overlays.** Private personal agents and anonymous observers take no capacity, no seat, no queue place and no cell reservation, and their choices never draw from shared random state.
- **Godot runs as a flatpak and can only see the home directory.** Godot projects and extension binaries must live under the worktree, never under `/tmp`.
- **Godot headless test command:** `godot --headless --path city/godot --script res://tests/run_all.gd` must exit 0.
- **Build the extension** with `city/scripts/build-godot.sh`. It runs `cargo build -p city-godot --release` and copies `libcity_godot.so` to `city/godot/bin/`, which is gitignored.
- **Every screen shows the fixture banner:** "Fixture data — not real agent state".
- **Voxel isolation.** The stage D (voxel) commit changes files only under `city/godot/styles/voxel/`.
- **Full check.** `city/scripts/check.sh` must pass at the end of every stage. It is extended to run the Godot tests when `godot` is present.
- **Nothing is player-facing or accepted.** Captures are evidence.
- **Git history.** Commits are on `feat/city-style-packs`, with one commit series per stage; stages are split into PRs at finish.

## Review Focus

- **A hidden occupant influences visible motion.** A private agent standing in a doorway, or drawing from the RNG, must never change a visible walker's path, timing or standing spot. The test is pinned in A5.
- **Walker deadlock at a busy door.** Two groups meet at a 1 m door. Everyone must get through within a bounded number of ticks, and no one may be stuck forever in the gate run. The test is pinned in A5.
- **A style switch mid-walk.** Switching packs while occupants are walking must resume them at the same interpolated position and pose, with no teleport to a seat. The test is pinned in B4 and C2.
- **Extension missing or stale.** If the `.so` is absent or built for another API, the client shows the error screen with the build command, never a blank or crashed window. The test is pinned in B5.
- **Departure during a walk or while queued.** It must release the seat or queue place exactly once, walk to an exit, and emit `Departed` once. The test is pinned in A4.

---

## Stage A — Movement core (Rust)

### Task A1: Contracts for layout, clock, props and positions

**Files:**
- Modify: `city/crates/city-contracts/src/manifest.rs`, `projection.rs`, `snapshot.rs`, `event.rs`, `lib.rs`
- Test: `city/crates/city-contracts/tests/contracts.rs`

**Interfaces (Produces):**

```rust
// manifest.rs
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize, JsonSchema)]
pub struct Point { pub x: i32, pub z: i32 }
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct Rect { pub x: i32, pub z: i32, pub w: i32, pub d: i32 } // min corner + size, cm
pub struct Clock { pub ticks_per_day: u32, pub start_minute: u32 }
pub struct Prop { pub kind: String, pub pos: Point, #[serde(default)] pub facing: i32 }
City     += #[serde(default)] pub entrances: Vec<Point>
Facility += #[serde(default)] pub exterior: Option<String>
Room     += #[serde(default)] pub template: Option<String>, #[serde(default)] pub rect: Option<Rect>,
            #[serde(default)] pub obstacles: Vec<Rect>, #[serde(default)] pub props: Vec<Prop>
Seat     += #[serde(default)] pub pos: Option<Point>, #[serde(default)] pub facing: Option<i32>,
            #[serde(default)] pub kind: Option<String>
Door     += #[serde(default)] pub pos: Option<Point>
Manifest += #[serde(default)] pub clock: Option<Clock>
impl Manifest { pub fn has_layout(&self) -> bool }  // true if any room has a rect
// snapshot.rs
Location += Leaving { #[serde(default)] from: Option<PlaceId> }   // walking to an exit
pub struct Walk { pub path: Vec<Point>, pub purpose: WalkPurpose, pub blocked: u32 }
#[serde(tag = "type")] pub enum WalkPurpose { ToDoor { target: PlaceId }, ToSeat, ToSpot, ToQueue, ToExit }
OccupantState += #[serde(default)] pub pos: Option<Point>, #[serde(default)] pub facing: i32,
                 #[serde(default)] pub walk: Option<Walk>
// event.rs
RejectReason += Unreachable
// projection.rs
pub struct QueueSpot { pub room: PlaceId, pub position: u32 }
OccupantView += pos: Option<Point>, facing: i32, moving: bool, path_ahead: Vec<Point>, queue: Option<QueueSpot>
Projection += time_of_day: Option<u32>
```

Every new field carries `#[serde(default)]`. The `Option` fields also carry `skip_serializing_if = "Option::is_none"`, and the `Vec` fields `skip_serializing_if = "Vec::is_empty"`. This keeps old snapshots byte-identical wherever layout is absent.

- [ ] **Step 1: Write the failing tests** in `contracts.rs`:

```rust
#[test]
fn layout_fields_are_optional_and_round_trip() {
    let old = r#"{"id":"room:r","name":"R","capacity":2}"#;
    let r: Room = serde_json::from_str(old).unwrap();
    assert!(r.rect.is_none() && r.obstacles.is_empty() && r.props.is_empty() && r.template.is_none());
    let new = r#"{"id":"room:r","name":"R","capacity":2,"template":"workshop",
        "rect":{"x":0,"z":0,"w":400,"d":300},"obstacles":[{"x":10,"z":10,"w":100,"d":60}],
        "props":[{"kind":"tree","pos":{"x":200,"z":150}}]}"#;
    let r: Room = serde_json::from_str(new).unwrap();
    assert_eq!(r.rect, Some(Rect { x: 0, z: 0, w: 400, d: 300 }));
    assert_eq!(r.props[0].facing, 0);
    assert_eq!(serde_json::from_str::<Room>(&serde_json::to_string(&r).unwrap()).unwrap(), r);
}

#[test]
fn old_snapshot_shape_is_unchanged_without_layout() {
    let o = OccupantView { id: "a:1".into(), kind: OccupantKind::GuildAgent, display_name: "A".into(),
        role: String::new(), badge: None, appearance: Default::default(), seat: None,
        presence: ShownPresence::default(), task_summary: None, pos: None, facing: 0,
        moving: false, path_ahead: vec![], queue: None };
    let v = serde_json::to_value(&o).unwrap();
    assert!(v.get("pos").is_none() && v.get("path_ahead").is_none() && v.get("queue").is_none());
}

#[test]
fn leaving_location_and_walks_serialise() {
    let l: Location = serde_json::from_str(r#"{"state":"Leaving","from":"room:a"}"#).unwrap();
    assert_eq!(l, Location::Leaving { from: Some("room:a".into()) });
    let w = Walk { path: vec![Point { x: 1, z: 2 }], purpose: WalkPurpose::ToDoor { target: "room:a".into() }, blocked: 0 };
    assert_eq!(serde_json::from_str::<Walk>(&serde_json::to_string(&w).unwrap()).unwrap(), w);
}
```

- [ ] **Step 2: Run the tests** with `cargo test -p city-contracts`. They should fail to compile.
- [ ] **Step 3: Add the types and fields.** Then fix every construction site of `OccupantView` and `OccupantState` across the workspace:
  - `city-core/src/project.rs`: `pos: occ.pos`, `facing: occ.facing`, `moving: occ.walk.is_some()`, `path_ahead: vec![]` for now, `queue: None` for now.
  - `world.rs` `fresh()`: `pos: None`, `facing: 0`, `walk: None`.
  - `Projection { time_of_day: None }`.
  - Add `Location::Leaving` arms everywhere `Location` is matched, treating it like `InTransit` for now.
- [ ] **Step 4: Run** `cargo test --workspace`. Everything should pass, old tests included.
- [ ] **Step 5: Commit** with message `feat(city): add layout, clock, props and positions to the contracts`.

### Task A2: Layout validation

**Files:**
- Modify: `city/crates/city-core/src/index.rs`
- Test: unit tests in `index.rs`

**Interfaces (Produces):** `RoomInfo` gains `rect: Option<Rect>`, `obstacles: Vec<Rect>`, `template: Option<String>`, and seat positions and facings on `SeatInfo`. `PlaceIndex` gains `layout: bool`, `entrances: Vec<Point>` and `clock: Option<Clock>`.

**New issue codes:**

| Code | When it fires |
| --- | --- |
| `incomplete-layout` | Some rooms have a rect and others don't; a seat or door lacks `pos` in a layout manifest; or there are no entrances |
| `seat-outside-room` | A seat lies outside its room |
| `seat-in-obstacle` | A seat lies inside one of its room's obstacles |
| `obstacle-outside-room` | An obstacle lies outside its room |
| `rooms-overlap` | Two room rects intersect with positive area |
| `door-not-on-shared-edge` | A door's `pos` is not on the shared edge of its room and its `to` room. The two rects must touch along an edge and the point must lie on that segment, excluding its two end cells |
| `entrance-not-on-outdoor-edge` | An entrance is not on the outer edge of a room with template `plaza` or `outdoor`, where no other room touches |
| `bad-clock` | `ticks_per_day == 0` or `start_minute >= 1440` |
| `bad-rect` | `w <= 0` or `d <= 0` |

A point is inside a rect when `x <= p.x < x+w` and `z <= p.z < z+d`.

- [ ] **Step 1: Write failing tests.** Start from `layout_base()`, a two-room layout:
  - `room:a`: rect (0, 0, 400, 400), template `workshop`;
  - `room:p`: rect (0, 400, 800, 400), template `plaza`;
  - doors `a→p` and `p→a`, both at (200, 400);
  - one seat in `room:a` at (100, 100), facing 0, kind `desk`;
  - obstacle (50, 20, 100, 60);
  - entrance (0, 600), on the plaza's west edge;
  - clock 600/420.

  Test that the valid base produces no issues, then write one test per code by mutating the base. For example: move the seat to (500, 100) for `seat-outside-room`; move the door to (200, 100) for `door-not-on-shared-edge`; set `ticks_per_day = 0` for `bad-clock`. Also check that a manifest without any layout is still valid (the existing `base()`).
- [ ] **Step 2: Run** `cargo test -p city-core index`. The new tests should fail.
- [ ] **Step 3: Implement the checks** in `PlaceIndex::build`. Add them to the existing issue list, and only when any room has a rect. Record the fields in the index.
- [ ] **Step 4: Run the tests** until they pass, then commit with message `feat(city): validate district layouts`.

### Task A3: Navigation grid and A*

**Files:**
- Create: `city/crates/city-core/src/nav.rs`
- Test: unit tests in `nav.rs`

**Interfaces (Produces):**

```rust
pub const CELL: i32 = 25;
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)] pub struct Cell { pub i: i32, pub j: i32 } // column, row
pub struct NavGrid { origin: Point, cols: i32, rows: i32, room: Vec<Option<u16>>, room_ids: Vec<PlaceId>, door_span: Vec<(u16,u16,Vec<Cell>)> }
impl NavGrid {
    pub fn build(index: &PlaceIndex) -> NavGrid;            // only when index.layout
    pub fn cell_of(&self, p: Point) -> Cell;                // floor((p - origin) / CELL)
    pub fn centre(&self, c: Cell) -> Point;                 // origin + c*CELL + CELL/2
    pub fn room_at(&self, c: Cell) -> Option<&PlaceId>;
    pub fn walkable(&self, c: Cell) -> bool;
    pub fn can_step(&self, a: Cell, b: Cell) -> bool;       // 8-neighbour, same room or door crossing, no corner cutting
    pub fn path(&self, from: Cell, goal: &dyn Fn(Cell) -> bool, blocked: &dyn Fn(Cell) -> bool) -> Option<Vec<Cell>>; // excludes `from`
    pub fn threshold_into(&self, from: Cell, room: &PlaceId, blocked: &dyn Fn(Cell)->bool) -> Option<Vec<Cell>>; // path ending on the last cell OUTSIDE `room` before entering it
    pub fn cells_in(&self, room: &PlaceId) -> Vec<Cell>;    // walkable, in (j, i) order
    pub fn queue_slots(&self, room: &PlaceId, n: usize) -> Vec<Cell>; // BFS from the main door's outside cells, excluding `room` and door-span cells, deterministic
}
```

**Grid rules:**

| Rule | Definition |
| --- | --- |
| Bounds | The bounding box of all room rects |
| Walkable cell | Its centre is inside a room rect and outside that room's obstacles |
| Door span | For each door (a→b) at position p, the cells within 50 cm of p along the shared edge, on both sides |
| Stepping | Allowed from a to an 8-neighbour b if both are walkable. Allowed across rooms only if both are in the same door's span and the step is orthogonal. A diagonal is allowed only if both orthogonal intermediates are walkable and in the same room |
| A* cost | 10 for straight steps, 14 for diagonals |
| A* heuristic | Octile, multiplied by 10 |
| Open-set ordering | `(f, g_reversed, cell)`, with `BinaryHeap<Reverse<(u32, u32, Cell)>>`, which gives deterministic ties |
| Main door | The room's door with the lowest ID that has a `pos` |

- [ ] **Step 1: Write failing tests.** Use `layout_base()` from A2 (copy it into a `#[cfg(test)]` helper module; `index.rs` can expose `pub(crate) fn layout_base()` under `#[cfg(test)]`).
  - `cells_are_walkable_only_inside_rooms_and_outside_obstacles`
  - `crossing_rooms_only_through_the_door`: a path from inside `room:a` to the plaza passes through the door span; direct crossing elsewhere is refused.
  - `astar_is_optimal_on_an_open_floor`: the path length from (0, 0) to (3, 4) in cells is 4 moves (3 diagonal and 1 straight), with cost 52.
  - `diagonals_never_cut_obstacle_corners`
  - `ties_are_deterministic`: the same query twice gives identical paths.
  - `threshold_path_stops_just_outside_the_room`
  - `queue_slots_are_outside_and_distinct`
- [ ] **Step 2: Run** `cargo test -p city-core nav`. It should fail.
- [ ] **Step 3: Implement `nav.rs`.** Add `pub mod nav;` in `lib.rs`.
- [ ] **Step 4: Run the tests** until they pass, then commit with message `feat(city): add a deterministic navigation grid`.

### Task A4: Walking — arrival, door admission, seats, queues, moves, departure

**Files:**
- Modify: `city/crates/city-core/src/world.rs`
- Create: `city/crates/city-core/src/walk.rs` (helpers: facing from step, spot choice hash)
- Test: `city/crates/city-core/tests/walking.rs`, plus `tests/common/mod.rs` (add `district_small()`)

**Interfaces (Produces):**
- `World` has `nav: Option<NavGrid>`, built when `index.layout`.
- `pub fn spot_hash(seed: u64, id: &CityId, tick: Tick) -> u64`, using FNV-1a 64 over `seed`, the ID bytes and `tick`. It picks standing spots without touching the shared RNG, so hidden occupants can't influence visible ones.

**Rules with layout** (without layout, every existing code path is untouched):

1. **Ingest.**
   - `Arrive`: validated as today. Set `pos` to the centre of the entrance nearest the target room by path length (ties go to the lowest entrance index) and `Location::Arriving{room}`. Set `walk = ToDoor{target: room}`, with path = `threshold_into(entrance, room)`, ignoring reservations. Emit `Arrived`. If no path exists, reject with `Unreachable`.
   - `Move`: needs `InRoom`, and `to` must be a room reachable by some path (`Unreachable` otherwise). Door adjacency is not required when there is a layout. Leave the room immediately: release the seat and emit `SeatReleased`. Then `Arriving{room: to}`, with walk `ToDoor{target: to}` from the current position. Emit `TransitStarted{from, to, door: <first door on the path, or the room's main door>, arrives_at: t + ceil(path_len/5)}` as an estimate.
   - `Depart`:
     - from `InRoom`: release the seat, leave the room, set `Leaving{from: Some(room)}` and walk `ToExit`;
     - from `Waitlisted{room}`: leave the waitlist, set `Leaving{from: None}` and walk `ToExit`;
     - from `Arriving` (walking): drop any pending admission, set `Leaving{from: None}` and walk `ToExit`;
     - from `Leaving`: reject with `NotPresent`;
     - the exit is the entrance nearest the current position by path.
2. **Admit.**
   - Serve waitlists first, as today. When a waitlisted occupant is placed, give them a walk to the placed room: `ToSeat` or `ToSpot` is set at Allocate.
   - Then take the occupants who reached their threshold last tick (`admission_queue`, pushed by Transition when a `ToDoor` walk finishes), and apply today's placement logic: chain, owner exception, never overtake.
   - A placed occupant goes `InRoom{room, seat: None}` with pending walk, and is placed at once so capacity is reserved.
   - An occupant who can't be placed goes `Waitlisted{room: target}` with walk `ToQueue`, heading to `queue_slots(target, len)[position-1]`.
   - Hidden overlays are always placed in their target and walk `ToSpot`.
3. **Allocate.** For each placed occupant with `walk` `None` or pending placement and `seat == None`: choose a seat as today. Hidden occupants never get one.
   - With a seat: walk `ToSeat` along a path to the seat cell (the seat's `pos` cell).
   - Without a seat: walk `ToSpot` to a standing cell:
     - candidates are `cells_in(room)`, minus door-span cells, minus seat cells, minus cells reserved by visible occupants;
     - pick index `spot_hash(seed, id, t) % candidates.len()`.
   - When a queue advances (a waitlist position changes), re-walk the queued occupants to their new slots.
4. **Transition.** Handled in A5 (stepping and avoidance). For A4, implement stepping **without** avoidance: each walker moves up to 5 cells along its path, and facing is set from the last step's direction (`walk::facing(dx, dz)`, rounded to 45°).
   - When a path is exhausted:
     - `ToDoor`: push to `admission_queue` and clear `walk`;
     - `ToSeat` or `ToSpot`: clear `walk`; the occupant is now sitting or standing;
     - `ToQueue`: clear `walk`;
     - `ToExit`: mark for removal at Depart.
   - Door timers (`InTransit`) apply only without a layout.
5. **Depart.** `Leaving` occupants whose walk is finished become `Away`: presence is cleared, `pos = None`, and `Departed{from}` is emitted.

- [ ] **Step 1: Write the failing scenario tests** in `tests/walking.rs`, using `district_small()`. It has a plaza with one entrance; a workshop with capacity 2, seats w1 and w2, and overflow to a commons; a commons with capacity 1 and seat c1; each room with a door to the plaza; and a door between the workshop and commons. Each test asserts real positions and locations over ticks:
  - `arrival_walks_from_the_entrance_and_is_admitted_at_the_door`: the position starts at the entrance centre, the distance to the door shrinks each tick, `Admitted` fires only after the threshold is reached, and then the occupant walks to w1 and sits (`walk == None` and `pos == seat centre`).
  - `each_step_moves_at_most_five_cells`
  - `overflow_walks_on_to_the_next_room`: the third arrival is placed in the commons at the workshop door, then walks there.
  - `a_queue_forms_outside_the_full_room_and_advances_in_order`: with commons capacity set to 0 via the chain being full, the 4th and 5th arrivals queue; queue slot cells lie outside the workshop and are distinct; when one seated occupant departs, the queue head is admitted and the second moves up a slot.
  - `move_between_rooms_walks_through_doors`
  - `departure_releases_the_seat_once_and_walks_out`: `SeatReleased` fires on the Depart tick, `Departed` fires only when the entrance is reached, and each fires exactly once. Also cover departure while queued and while walking in.
  - `unreachable_target_is_rejected`
  - `layoutless_worlds_are_unchanged`: run the existing `hall()` scenario from `scenarios.rs` and confirm `pos` stays `None`.
- [ ] **Step 2: Run** `cargo test -p city-core --test walking`. It should fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `cargo test -p city-core`. The new tests and every existing test should pass.
- [ ] **Step 5: Commit** with message `feat(city): walk occupants in, between rooms and out`.

### Task A5: Avoidance and hidden overlays

**Files:**
- Modify: `city/crates/city-core/src/world.rs`
- Test: `tests/walking.rs`

**Rules for the Transition step:**

1. Build `reserved: BTreeMap<Cell, CityId>` from every **visible** present occupant's current cell. Visible means `shares_capacity(kind)` (equivalently, visible to Public). This covers seated, standing and queued occupants, and walkers.
2. Walkers step in city-ID order. For each of up to 5 moves, the next cell is taken if it isn't reserved by another visible occupant; update the reservation as the walker moves.
3. Hidden walkers ignore `reserved` and never reserve.
4. A walker that could not make its first move increments `walk.blocked`, otherwise it resets to 0.
5. When `blocked >= 3`, re-plan to the same goal with other visible occupants' cells treated as blocked. Use `threshold_into` or `path` with a `blocked` closure. If a path is found, reset `blocked`; if not, keep waiting and try again after 3 more ticks.

- [ ] **Step 1: Write failing tests.**
  - `walkers_never_share_a_cell`: 12 arrivals at once through one entrance; after every tick, no two visible occupants share a cell.
  - `meeting_at_a_door_resolves`: 4 people leave the workshop while 4 arrive. Everyone reaches their goal within 60 ticks.
  - `hidden_overlays_never_divert_visible_walkers`: run the same feed twice, once with an extra private agent standing on the path (arriving first and targeting the plaza). Visible occupants' positions, events and log bytes, restricted to visible IDs, are identical.
  - `standing_spots_do_not_depend_on_hidden_occupants`: a capacity-full room forces standing, with and without a hidden overlay present. Same spots.
- [ ] **Step 2: Run the tests** and watch them fail. The share-cell test fails without avoidance.
- [ ] **Step 3: Implement avoidance.**
- [ ] **Step 4: Run** `cargo test -p city-core` until everything passes.
- [ ] **Step 5: Commit** with message `feat(city): deterministic avoidance; hidden occupants are overlays`.

### Task A6: Projections of motion, queues and time of day

**Files:**
- Modify: `city/crates/city-core/src/project.rs`
- Test: `tests/walking.rs`

**Projection rules:**

| Field | Value |
| --- | --- |
| `pos` | The occupant's position |
| `facing` | The occupant's facing |
| `moving` | `walk.is_some()` |
| `path_ahead` | The next up to 5 path cells as centre points: the positions the walker will reach next tick, for smooth interpolation |
| `queue` | `Some({room, position})` for waitlisted occupants, from the waitlist index |
| `in_transit` | Every visible occupant that is `Arriving`, `InTransit` or `Leaving` |
| `time_of_day` | `(start_minute + tick*1440/ticks_per_day) % 1440`, computed with `u64` arithmetic, when a clock is present |

- [ ] **Step 1: Write failing tests.**
  - `projection_carries_positions_and_paths`
  - `walkers_are_listed_in_transit_until_admitted`
  - `queued_occupants_show_their_place`
  - `time_of_day_advances_and_wraps`: with 600 ticks per day starting at 420, tick 300 gives 1140 and tick 600 gives 420.
  - `public_projection_never_contains_hidden_walkers`
- [ ] **Step 2: Run the tests** and watch them fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests** until they pass, then commit with message `feat(city): project positions, paths, queues and time of day`.

### Task A7: Movement invariants under property tests

**Files:**
- Modify: `city/crates/city-core/src/invariants.rs`, `tests/invariants.rs`

**Interfaces (Produces):**

```rust
pub fn check_cells(s: &Snapshot, nav: &NavGrid) -> Vec<Violation>      // 8: no two visible occupants share a cell; 9: every pos walkable
pub fn check_steps(before: &Snapshot, after: &Snapshot, nav: &NavGrid) -> Vec<Violation> // 10: Chebyshev cell distance <= 5
pub fn check_queues(s: &Snapshot, index: &PlaceIndex) -> Vec<Violation> // 11: a waitlist is non-empty only if every room in its chain is full for its head
pub fn check_all_with_nav(before, after, events, nav: Option<&NavGrid>, index: &PlaceIndex) -> Vec<Violation>
```

Hidden occupants reserving nothing is structural: they are skipped in reservations. `check_cells` covers it indirectly, because hidden occupants are excluded from the shared-cell check. A5's scenario pins the behaviour.

`World` exposes `pub fn nav(&self) -> Option<&NavGrid>`.

- [ ] **Step 1: Write the checker tests.** Plant violations: two occupants on one cell; a position set into a wall; a jump of 20 cells. Each should be caught. Then extend the property test with a second strategy, `layout_world_strategy()`:
  - 1 to 3 rooms tiled in a row along x, each 300–800 cm wide and 400 cm deep;
  - a plaza row below spanning all of them, with a door from each room to the plaza at the room's mid-x;
  - one entrance on the plaza's west edge;
  - 0 to 2 obstacles per room, kept away from doors and seats;
  - seats placed on free cells.

  Commands are the same as today. Run 60 ticks and apply `check_all_with_nav` after every tick, plus the byte-identical log check.
- [ ] **Step 2: Run** `cargo test -p city-core --test invariants --release`. Any counterexample is a real bug: fix the rule, and add the minimised case to `walking.rs`.
- [ ] **Step 3: Mutation check.** Disable avoidance temporarily and confirm invariant 8 fails, then revert.
- [ ] **Step 4: Commit** with message `test(city): property-test movement invariants`.

### Task A8: Crowd, district fixture, CLI flag, gate and scale

**Files:**
- Create: `city/crates/city-core/src/crowd.rs`; `city/fixtures/district/generate.py`, `manifest.json`, `feed.jsonl`
- Modify: `city/crates/city-cli/src/{commands.rs,main.rs}`, `city/crates/city-cli/tests/cli.rs`, `city/crates/city-core/tests/scenarios.rs` (district gate), `city/crates/city-cli/examples/scale.rs` (a layout scale mode), `city/README.md`

**Interfaces (Produces):**

```rust
pub fn crowd(manifest: &Manifest, count: u32, seed: u64) -> Result<Feed, String> // Err if no layout
pub fn merge(a: Feed, b: Feed) -> Feed   // stable by `at`; entries of `a` first on ties; header from `a`
// commands.rs
RunArgs += pub crowd: u32   // `--crowd N`, default 0
```

**Crowd rules.** Use its own `ChaCha8Rng::seed_from_u64(seed ^ 0xC20D)`.

- **Kinds by index mod 20:** 12 SimCitizen, 4 Human Registered, 2 Human Resident, 1 Human Observer, 1 PersonalAgent (owned by the preceding human).
- **IDs:** `crowd:NNNN`; display names `Visitor N`.
- **Appearance:** `appearance` gets `palette` (0–7) and `hair` (0–3) from the RNG.
- **Arrival:** at a tick in `[0, ticks_per_day)` (600 when there is no clock), at a room chosen by hour of arrival:

  | Hours | Preferred templates |
  | --- | --- |
  | 11:00–14:00 | `cafe` |
  | 14:00–18:00 | `reading-room` |
  | Otherwise | `plaza`, `commons` |

  Fall back to any room with a matching template, or else the plaza.
- **Stay:** 60–300 ticks. Half of the crowd `Move` once, midway, to another room chosen the same way.
- **Presence:** humans get a Connected observation (expires at the departure tick + 10). Personal agents get Running plus a Working task with a private summary.
- **Fixture flag:** every entry has `fixture: true`.

**The district** comes from `generate.py`, a stdlib-only script that writes `manifest.json` with `sort_keys` and a 2-space indent. It's reproducible and checked by a test that runs the script and diffs its output. Coordinates are in cm:

| Area | Rect (x, z, w, d) | Details |
| --- | --- | --- |
| Plaza (`plaza`) | (0, 0, 4000, 3000) | Tree obstacle (1850, 1350, 300, 300) with prop `tree`; 8 bench seats in a ring at 350 cm radius; props `lamp` ×4 and `palm` ×4; capacity 40 |
| Guild hall (`guild-hall`) workshop (`workshop`) | (400, −1200, 1200, 1200) | 6 desk seats in two pods of 3 (`making`); desk obstacles 100×60 in front of each seat; Kai's desk reserved; capacity 6; overflows to the commons |
| Guild hall commons (`commons`) | (1600, −1200, 800, 1200) | 4 seats (`bench`); capacity 4 |
| Library (`library`) reading room (`reading-room`) | (4000, 600, 1200, 1400) | 6 `reading-chair` seats; bookshelf props and obstacles along the back wall; capacity 6 |
| Café (`cafe`) floor (`cafe`) | (1200, 3000, 1200, 800) | 4 `cafe-table` obstacles with 2 seats each; capacity 8; overflows to the plaza |

**Doors:**
- workshop ↔ plaza at (1000, 0)
- commons ↔ plaza at (2000, 0)
- workshop ↔ commons at (1600, −600)
- library ↔ plaza at (4000, 1300)
- café ↔ plaza at (1800, 3000)

**Entrances:** (0, 1500), (4000, 2600), (3200, 3000) and (3000, 0).

**Clock:** 600 ticks per day, starting at minute 420.

**Occupants:**
- The Guild agents in the manifest: kai, lyra, theo and quill (work in the workshop), echo (reading room), and `city:librarian` (reading room).
- The story feed adds `person:asha`, `person:guest` (Observer) and `pa:asha-notes`.

**The story feed** (`feed.jsonl`) is hand-written by `generate.py` too, over 200 ticks:
1. Agents arrive and walk to their desks.
2. Asha finds the workshop full for strangers and is placed in the commons.
3. Two crowd-independent visitors queue outside the full workshop.
4. Lyra's task goes stale.
5. Theo runs with no task.
6. Asha's agent and the guest walk around as overlays.
7. Asha moves to the café.
8. Everyone leaves by tick 190.

**Tests:**
- `crowd_is_deterministic_and_fixture_labelled`
- `district_gate`:
  - load the district plus `crowd(60, 7)`, merged, and run 600 ticks (one day);
  - apply `check_all_with_nav` every tick;
  - assert that the event kinds include `Arrived`, `Overflowed`, `Waitlisted`, `Seated`, `TransitStarted`, `ObservationExpired` and `Departed`;
  - assert a queue of 2 or more is observed outside `room:workshop`;
  - assert `time_of_day` passes both 12:00 and 20:00;
  - assert no hidden ID ever appears in a public projection;
  - assert the log is byte-identical across two runs.
- **CLI:** `run --crowd 5` writes a log with `crowd:` entries.
- **Generator test:** runs `python3 fixtures/district/generate.py --check`.

**Scale:** the example gains `--district N`, which runs the district with `crowd(N)` for 600 ticks. Record 60, 300 and 1,000 in the README.

- [ ] **Step 1: Write the failing tests** listed above.
- [ ] **Step 2: Run the tests** and watch them fail.
- [ ] **Step 3: Implement** `crowd.rs`, `generate.py`, the fixture and the CLI flag. Tune the story until the gate holds; the rules win.
- [ ] **Step 4: Run** `city/scripts/check.sh` until it passes. Record scale, and update `city/README.md` with layout, movement, crowd and the district.
- [ ] **Step 5: Commit** with message `feat(city): district fixture, crowd and movement gate`.

---

## Stage B — Godot bridge, client core and low-poly pack

### Task B1: `city-godot` extension and Godot project skeleton

**Files:**
- Create: `city/crates/city-godot/{Cargo.toml,src/lib.rs,src/bridge.rs}`, `city/scripts/build-godot.sh`, `city/godot/project.godot`, `city/godot/city.gdextension`, `city/godot/.gitignore` (`bin/`, `.godot/`), `city/godot/tests/run_all.gd`, `city/godot/tests/test_bridge.gd`
- Modify: `city/Cargo.toml` (member; `godot = { version = "0.5.5", features = ["api-4-6"] }`), `city/scripts/check.sh` (build the extension and run the Godot tests when `command -v godot` succeeds)

**Interfaces (Produces):**

```rust
// bridge.rs (plain Rust, tested without Godot)
pub struct Session { world: Option<World>, operator: bool }
impl Session {
  pub fn load(&mut self, manifest_json: &str, feed_jsonl: &str, seed: u64, crowd: u32) -> String; // {"ok":bool,"issues":[...],"error":?}
  pub fn step(&mut self) -> i64;   // -1 if not loaded
  pub fn tick(&self) -> i64;
  pub fn set_operator(&mut self, on: bool);
  pub fn project_json(&self, viewer: &str) -> String; // {"error":{"code":"operator-flag-required"}} for operator unless enabled; {"error":{"code":"not-loaded"}}
  pub fn layout_json(&self) -> String; // the manifest (it carries all layout)
}
// lib.rs (gdext): #[class(init, base=RefCounted)] struct CityWorld { s: Session } with #[func] wrappers of the same names.
```

**GDScript test harness.** `run_all.gd` extends `SceneTree`. It loads every `res://tests/test_*.gd`, instantiates each, and calls every method starting with `test_`. Helpers are `assert_true(cond, msg)` and `assert_eq(a, b, msg)`; failures are collected. It prints `PASS n` or `FAIL name: msg` and quits with 0 on success, 1 on any failure.

The bridge reads fixture files through `city/godot/core/paths.gd`, which uses `ProjectSettings.globalize_path("res://") + "/../fixtures/district/..."` (FileAccess, host path).

- [ ] **Step 1: Write failing Rust tests** in `bridge.rs`:
  - `load_reports_issues`
  - `project_before_load_errors`
  - `operator_needs_enable`
  - `step_advances`
  - `crowd_merges`
- [ ] **Step 2: Write the failing Godot test** `test_bridge.gd`:
  - `test_extension_loads`: `ClassDB.class_exists("CityWorld")`;
  - `test_load_and_project`: load the district, step 5 times, parse the projection, and check it has `rooms` and `time_of_day`.
- [ ] **Step 3: Run** `cargo test -p city-godot`. It fails. Run `city/scripts/build-godot.sh && godot --headless --path city/godot --script res://tests/run_all.gd`. That fails too.
- [ ] **Step 4: Implement.** Before the tests, run `godot --headless --path city/godot --import --quit` once so the extension is registered.
- [ ] **Step 5: Run both suites** until they pass, then commit with message `feat(city): godot extension exposing the city world`.

### Task B2: Scene model

**Files:**
- Create: `city/godot/core/scene_model.gd`
- Test: `city/godot/tests/test_scene_model.gd`

**Interfaces (Produces):** `class_name SceneModel extends RefCounted`.

- `func apply(p: Dictionary) -> Array` returns change dictionaries in this order:
  1. `left`
  2. `appeared`
  3. `pose` (`walking`, `sitting`, `standing` or `queued`)
  4. `moved` (with `pos`, `facing`, `path_ahead`)
  5. `presence` (headline)
  6. `time` (minutes)
- `var occupants := {}` maps id to `{view, pose, room}`.
- `func current() -> Array` returns an `appeared`-style snapshot of every current occupant, used by style switching.

Pose is derived as follows:

| Condition | Pose |
| --- | --- |
| `moving` | `walking` |
| Listed in `waiting` | `queued` |
| `seat != null` and not moving | `sitting` |
| Otherwise | `standing` |

- [ ] **Step 1: Write failing tests** with canned dictionaries:
  - `test_first_projection_appears_everyone`
  - `test_leaving_emits_left`
  - `test_walk_then_sit`
  - `test_headline_change_only_when_changed`
  - `test_time_change`
  - `test_current_matches_state`
- [ ] **Step 2: Run the tests** and watch them fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests** until they pass, then commit with message `feat(city-godot): scene model diffs projections into changes`.

### Task B3: Motion interpolation

**Files:**
- Create: `city/godot/core/motion.gd`
- Test: `city/godot/tests/test_motion.gd`

**Interfaces (Produces):** `class_name Motion extends RefCounted`.

- `func set_track(id, pos: Vector2, path_ahead: Array)` takes centimetres, as a `Vector2(x, z)`.
- `func sample(id, t: float) -> Dictionary` returns `{pos: Vector2, dir: Vector2}`. `t` runs from 0 to 1 across one tick, and the position moves along the polyline `[pos] + path_ahead` by arc length. With an empty path it returns `pos`.
- `func clear(id)`.

- [ ] **Step 1: Write failing tests:**
  - `test_starts_at_pos`
  - `test_ends_at_last_waypoint`
  - `test_stays_on_segments` (sample 11 points and check each lies on the polyline)
  - `test_empty_path_is_still`
- [ ] **Step 2: Run the tests** and watch them fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests** until they pass, then commit with message `feat(city-godot): interpolate walkers between ticks`.

### Task B4: Style-pack interface, discovery, placeholders and switching

**Files:**
- Create: `city/godot/styles/style_pack.gd`, `city/godot/core/style_host.gd`, `city/godot/tests/fixtures/fake_pack/{style.json,pack.gd}`
- Test: `city/godot/tests/test_style_host.gd`

**Interfaces (Produces):**

- `style_pack.gd` is `class_name StylePack extends Node`. Its methods are:
  - `build_world(manifest: Dictionary, style: Dictionary)`
  - `teardown()`
  - `spawn(o: Dictionary)`
  - `despawn(id)`
  - `place(id, pos_cm: Vector2, dir: Vector2)`
  - `set_pose(id, pose)`
  - `set_presence(id, headline)`
  - `show_names(on)`
  - `set_selected(id)`
  - `set_time_of_day(minutes)`
  - `resolve(section: String, key: String) -> Dictionary`, which returns the entry, or `{"placeholder": true}` after appending `section/key` to `missing`
  - `var missing: PackedStringArray`
  - `var nodes: Dictionary`, mapping id to its root node, used by tests
- `style_host.gd` is `class_name StyleHost extends Node`. Its methods are:
  - `func discover(root := "res://styles") -> Array`, which returns the style dirs that contain a `style.json`, sorted by its `order`, then name
  - `func activate(dir: String, manifest, model: SceneModel, motion: Motion) -> bool`, which tears down the current pack, builds the new one, spawns `model.current()`, applies poses, presence, time and names, and places each walker at `motion.sample(id, last_t)`. On failure it keeps the old pack and returns false
  - `func apply_changes(changes: Array)`
  - `func tick_frame(t: float)`
- The keys `style.json` must cover are:

  | Section | Keys |
  | --- | --- |
  | `occupants` | `GuildAgent`, `CityRoleAgent`, `PersonalAgent`, `SimCitizen`, `Human` |
  | `seats` | `desk`, `bench`, `cafe-table`, `reading-chair` |
  | `rooms` | `workshop`, `commons`, `reading-room`, `cafe`, `plaza` |
  | `exteriors` | `guild-hall`, `library`, `cafe` |
  | `props` | `tree`, `lamp`, `palm`, `bookshelf` |
  | `headlines` | all 10 |
  | `badges` | `Ai`, `Simulation` |
  | `day_night` | — |

  It also carries `order`, `name` and `declared_placeholders: []`.

- [ ] **Step 1: Write failing tests** with the fake pack (a plain `Node2D`-based pack under `tests/fixtures`):
  - `test_discover_finds_real_styles_only_under_root`
  - `test_switch_preserves_occupants_poses_and_states`
  - `test_switch_mid_walk_keeps_interpolated_position`
  - `test_failed_build_keeps_previous_pack`
  - `test_missing_key_renders_placeholder_and_is_logged`
  - `test_public_viewer_creates_no_node_for_hidden_ids`: drive the model with a public projection and an operator projection from the bridge on the district, and check that the pack's `nodes` never contains `pa:asha-notes` under public
- [ ] **Step 2: Run the tests** and watch them fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests** until they pass, then commit with message `feat(city-godot): style packs are discovered, switched and checked`.

### Task B5: World driver, HUD, main scene and error screen

**Files:**
- Create: `city/godot/core/{world_driver.gd,hud.gd,paths.gd,args.gd}`, `city/godot/main.gd`, `city/godot/main.tscn`
- Test: `city/godot/tests/test_driver.gd`, `test_hud.gd`, `test_main.gd`

**Interfaces (Produces):**

`WorldDriver extends Node`:
- `signal projected(p: Dictionary)`
- `func start(manifest_path, feed_path, seed, crowd, operator) -> Dictionary`, returning `{ok, error}`
- `set_viewer(v)`, which re-projects the same tick
- `pause()`, `resume()`, `step_once()`, `set_speed(x)` (1, 2, 4 or 8)
- `var tick_time := 0.0`, the fraction through the current tick, from 0 to 1
- `_process` accumulates time and steps when a tick elapses

`Hud extends CanvasLayer`:
- the style buttons from `StyleHost.discover()`, with key bindings 1–9
- a viewer option (public, `person:asha`, and `operator` only when `--operator`)
- pause, step and speed controls
- a Names toggle (N)
- the fixture banner, a `Label` that is always visible
- the error panel

`main.gd` parses these arguments (`args.gd`):
- `--style=<name>`
- `--viewer=`
- `--operator`
- `--seed=`
- `--crowd=` (default 60)
- `--ticks=N` (advance N ticks at start)
- `--capture=<abs path>` (render one frame after N ticks, save a PNG, quit)
- `--speed=`

If `ClassDB.class_exists("CityWorld")` is false, the error panel shows: "The city extension is not built. Run: city/scripts/build-godot.sh". The client then stops; it never crashes.

**Keys:**

| Key | Action |
| --- | --- |
| N | Toggle names |
| Space | Pause |
| `.` | Step |
| `+` / `-` | Speed |
| V | Cycle viewer |
| 1–9 | Styles |
| Click | Select an occupant |

- [ ] **Step 1: Write failing tests:**
  - `test_driver_steps_at_speed` (simulate `_process` deltas)
  - `test_viewer_switch_reprojects_same_tick`
  - `test_operator_hidden_without_flag`
  - `test_names_hidden_by_default_and_toggle`
  - `test_fixture_banner_always_visible`
  - `test_error_screen_when_extension_missing`, which instantiates `main` with an injected `class_exists` stub returning false
- [ ] **Step 2: Run the tests** and watch them fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests** until they pass, then commit with message `feat(city-godot): driver, HUD and main scene`.

### Task B6: Low-poly asset generators

**Files:**
- Create: `city/tools/styles/lowpoly/{build.py,kit.py,characters.py,icons.py,validate.sh}`, `city/godot/styles/lowpoly_tropical/assets/*`
- Test: `city/tools/styles/lowpoly/test_assets.py` (stdlib `unittest`)

**What `build.py` does.** Run it as `blender --background --factory-startup --python-exit-code 1 --python build.py -- <out>`. It generates GLBs with flat-shaded, faceted materials in the palette below:

| Colour | Hex |
| --- | --- |
| Limewash | `#EFE6D2` |
| Terracotta | `#C4623A` |
| Copper green | `#5E9E8A` |
| Jackfruit yellow | `#F2B632` |
| Teal | `#2F8C8C` |
| Leaf greens | `#3F8F3A` and `#6DB33F` |
| Wood | `#8A5A3B` |

The assets are:
- **Floors:** `floor_<template>.glb`, a 1 × 1 m tile per template.
- **Walls:** `wall.glb` (1 m segment, 2.4 m high, 0.2 m thick) and `wall_low.glb`, a 1 m cut-away segment for camera-facing walls.
- **Roof and exteriors:** `roof_trim.glb`, plus `exterior_<name>.glb` for each exterior: a terracotta roof edge strip, the library's copper dome, and the café's yellow awning.
- **Seats:** `seat_<kind>.glb` for each seat kind.
- **Props:** `prop_<kind>.glb` for each prop kind.
- **Characters** (`characters.py`), as rigid-part GLBs whose parts are named nodes:
  - `human.glb`: `torso`, `head`, `hair_0` to `hair_3`, `arm_l`, `arm_r`, `leg_l`, `leg_r`;
  - `robot.glb`: white and yellow body with a dark visor, same part names, no hair.
  - Pivots sit at the joints, so the pack animates them procedurally.

`icons.py` (Pillow) writes one 64×64 PNG per headline and badge to `assets/icons/`.

`validate.sh` runs the pinned Khronos validator (`prototypes/voxel-work-bay/tools`) over every GLB and fails on errors or warnings.

- [ ] **Step 1: Write failing asset tests:**
  - every key in `style.json` references an existing file;
  - every GLB has the expected node names (parse the GLB JSON chunk);
  - the character part set is complete;
  - `validate.sh` exits 0.
- [ ] **Step 2: Run** `python3 -m unittest city/tools/styles/lowpoly/test_assets.py`. It should fail.
- [ ] **Step 3: Implement the generators** and run them. Write `style.json` for `lowpoly_tropical` (order 1).
- [ ] **Step 4: Run the tests** until they pass, then commit the generators and the generated assets with message `feat(city): low-poly tropical asset kit`.

### Task B7: Low-poly pack

**Files:**
- Create: `city/godot/styles/lowpoly_tropical/pack.gd`
- Test: `city/godot/tests/test_pack_contract.gd` (runs against every discovered pack)

**Behaviour:**

- **World:**
  - rooms become floor tiles over each rect, in metres (cm / 100);
  - walls go on rect edges without doors: full height on north and west edges, `wall_low` on south and east edges (cut-away);
  - exteriors attach to each facility's rooms;
  - seats and props go at their positions and facings.
- **Occupants:** occupants of kind `Human` use `human.glb`, agents use `robot.glb`, and SimCitizens use `human.glb` with a muted palette.
- **Colour:** `appearance.palette` (0–7) picks the outfit colour, and `appearance.hair` (0–3) shows one `hair_n`.
- **Poses:**

  | Pose | What the parts do |
  | --- | --- |
  | Walking | Legs and arms swing by `sin(phase)` at 2 Hz |
  | Sitting | Thighs at 90°, lowered to seat height 0.45 m |
  | Standing | Neutral, with a gentle idle breathing scale |
  | Queued | Standing, facing the door |

- **Presence:** a `Sprite3D` billboard icon 2.1 m up, for agents only. Humans show nothing unless selected; SimCitizens show nothing.
- **Names:** a `Label3D` billboard at 1.9 m, hidden unless `show_names`, or the occupant is selected or hovered. It shows the display name and badge; "your agent" when a personal agent's owner is the viewer; and `task_summary` when present.
- **Camera:** an orbit camera (right-drag to orbit, wheel to zoom, O for overview). Clicking a building focuses it.
- **Day and night:** the `DirectionalLight3D` angle is `(minutes/1440)*360 − 90`. Colour lerps between warm day and blue night. Lamp props gain an `OmniLight3D` whose energy is above 0 between 18:30 and 06:30, and window emission comes up at night.

The contract test works on every discovered pack:
- **Build:** build the district manifest.
- **Spawn:** spawn one of each kind, set every pose and every headline, and set the time to 06:00, 12:00 and 21:00.
- **Names:** assert no errors, `show_names(false)` by default, and `show_names(true)` makes the labels visible.
- **Teardown:** leaves zero children.
- **Coverage:** `missing` is empty, except for keys in `declared_placeholders`.

- [ ] **Step 1: Write the failing test** `test_pack_contract.gd`, parameterised over `StyleHost.discover()`.
- [ ] **Step 2: Run the tests** and watch them fail. No pack exists yet, so assert `discover()` returns at least 1.
- [ ] **Step 3: Implement** `pack.gd`.
- [ ] **Step 4: Run** the Godot tests and `check.sh` until they pass.
- [ ] **Step 5: Captures.** In a graphical session, run `godot --path city/godot -- --style=lowpoly_tropical --ticks=120 --capture=$PWD/city/godot/evidence/lowpoly-day.png`, and again with `--ticks=500 --capture=…-night.png`. Read the PNGs, check they show the district, and fix what is visibly wrong.
- [ ] **Step 6: Commit** with message `feat(city-godot): low-poly tropical style pack`.

---

## Stage C — Pixel art

### Task C1: Pixel sprite generator

**Files:**
- Create: `city/tools/styles/pixel/{build.py,palette.py}`, `city/godot/styles/pixel_art/assets/*`
- Test: `city/tools/styles/pixel/test_sprites.py`

**Palette.** `palette.py` defines 32 RGB colours, drawn by eye from the 08 concept sheets: navy outline, brick reds, warm sandstone, leaf greens (3), water blues (3), night blues, lamp yellow, skin tones (4), outfit colours (8), and greys. It also defines a night palette: the same indices, shifted.

**What `build.py` does:**
- **Tiles:** isometric 2:1, 32×16 px per 1 m tile, one per room template. Foliage and water get selective dithering.
- **Walls:** back-wall segments, 32×40.
- **Seats and props:** one sprite each, anchored at the bottom centre.
- **Exteriors:** a brick workshop with a sawtooth roof, a domed library, and a café awning.
- **Characters:** 16×24 sheets for human and robot. Each sheet has 4 facings (NE, NW, SE, SW) × (walk 4 frames + sit 1 + idle 2), and there are 8 palette-swapped outfit variants.
- **Icons:** 8×8, one per headline and badge.
- **Night variants:** each sprite gets a night variant, produced by palette mapping.

- [ ] **Step 1: Write failing tests:**
  - every PNG uses only palette or night-palette colours, plus transparency;
  - dimensions are multiples of the grid (tiles 32×16, characters 16×24 per frame);
  - every `style.json` reference exists;
  - generation is byte-reproducible (run twice and hash).
- [ ] **Step 2: Run the tests** and watch them fail.
- [ ] **Step 3: Implement** the generator, run it, and write `style.json` (order 2).
- [ ] **Step 4: Run the tests** until they pass, then commit with message `feat(city): pixel-art sprite kit`.

### Task C2: Pixel pack and live style switching

**Files:**
- Create: `city/godot/styles/pixel_art/pack.gd`
- Test: the existing contract test now covers two packs. Add `test_switch_live.gd`.

**Behaviour:**
- **Projection:** a `Node2D` with `y_sort_enabled`. Isometric screen position, with `m = cm / 100`, is:
  - `sx = (m.x − m.z) * 16`
  - `sy = (m.x + m.z) * 8`
- **Filtering and camera:** textures use nearest filtering. The `Camera2D` zoom is only 1, 2 or 3 (wheel), panning is right-drag, and the camera position snaps to whole pixels.
- **Occupants:** `AnimatedSprite2D` from the sheets, with the facing chosen from `dir`.
- **Presence and names:** a presence bubble sprite above the head; name tags use a pixel font `Label` with an integer scale.
- **Day and night:** swap to the night-variant textures between 19:00 and 06:00. Lamps get `PointLight2D`, and windows use their lit night tiles.

`test_switch_live.gd` runs the real district through the driver for 50 ticks. It then switches lowpoly → pixel → lowpoly and asserts that, after each switch:
- the same ID set is present;
- the same poses are applied;
- the same presence is applied;
- the time of day is the same.

**HUD wiring:** keys 1 and 2 activate the discovered styles.

- [ ] **Step 1: Write the failing tests.**
- [ ] **Step 2: Run the tests** and watch them fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the Godot tests and `check.sh` until they pass.
- [ ] **Step 5: Captures.** Take pixel day and night captures, plus a same-tick pair (lowpoly and pixel at tick 120). Inspect them and fix anything visibly wrong.
- [ ] **Step 6: Commit** with message `feat(city-godot): pixel-art style pack and live switching`.

---

## Stage D — Voxel (added last)

### Task D1: Voxel pack from the pilot's assets

**Files (all under `city/godot/styles/voxel/`):**
- `style.json`
- `pack.gd`
- `assets/` (copies of the pilot's `desk.glb`, `chair.glb`, `terminal.glb`, `environment.glb` and the 14 robot GLBs, with their `.import` files regenerated)
- `SOURCES.md` (source path and sha256 of each copied file)

**Behaviour:**
- **Robots:** agents use the robot GLBs. Guild agents map by ID suffix to their named robot when one exists (`agent:kai` → `kai.glb`); other agents use `super-chotu.glb`.
- **Clips:**

  | Pose | Clip |
  | --- | --- |
  | Walking | `walk` |
  | Sitting | `seated_idle`, or `typing` when the headline is Working |
  | Standing | `idle` |

- **Furniture and floors:** desks are `desk.glb` plus `chair.glb` plus `terminal.glb`. Floors are voxel-coloured box slabs built in `pack.gd`.
- **Placeholders:** humans, the library, café, tree, palm, lamp, bookshelf, bench, reading chair and café table are magenta placeholder boxes, listed in `declared_placeholders`.
- **Presence and names:** presence uses `Label3D` glyph icons; names use the same `Label3D` rule as low-poly.
- **Day and night:** the same light rule as low-poly.

- [ ] **Step 1: Run the existing contract test** to confirm voxel is discovered and fails. Create a `style.json` with only `order: 3` first; the test must then fail on missing keys and on the pack script.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** the Godot tests and `check.sh` until they pass.
- [ ] **Step 4: Captures:** voxel day and night, plus a three-style triptych at the same tick.
- [ ] **Step 5: Verify isolation** before committing. `git diff --cached --name-only` must list only `city/godot/styles/voxel/**`.
- [ ] **Step 6: Commit** with message `feat(city-godot): voxel style pack from the pilot's assets`.

### Task D2: Gate record and documentation

**Files:**
- Modify: `city/README.md` (Godot client section: build, run, keys, packs, evidence), `README.md` (one line), and `docs/superpowers/specs/…-design.md` ("Settled during implementation" section, if needed)
- Create: `city/godot/README.md`

The gate check is a headless test, `test_gate.gd`. It runs the district for 600 ticks through the driver and switches through every pack at ticks 100, 300 and 500. It asserts:
- the same ID sets;
- no hidden IDs in public;
- the names start hidden;
- the banner is visible;
- the time passes 12:00 and 20:00.

- [ ] **Step 1: Write the failing** `test_gate.gd`.
- [ ] **Step 2: Run it**, and make it pass.
- [ ] **Step 3: Write the docs.**
- [ ] **Step 4: Run** `check.sh` until it passes, then commit with message `docs(city): Godot client, style packs and gate`.
