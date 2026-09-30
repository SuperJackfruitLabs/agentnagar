# City style packs and movement — one world, three styles, walking occupants

Design specification · 2026-09-24 · sub-projects 2 and 3 of the "next level",
combined

## Approved direction

The [world core](2026-09-24-city-world-core-design.md) (merged as PR #23)
simulates who is where, but it can only be seen as JSON and text. RD18 asks for
game mechanics that work with **any visual style**. That is proven only when the
same simulation is rendered in very different styles.

In the design conversation, Rakesh decided the following:

| Topic | Decision |
| --- | --- |
| Client | **Godot**, rather than the browser |
| The proof | A **live style switch**: one running simulation, and a key swaps the style at the same tick |
| Pixel art | Built as **true 2D sprites**, not pixel-styled 3D |
| Scene | A **small district**, not two rooms |
| Styles | **11 low-poly tropical diorama** and **08 pixel art**, plus the existing **voxel** style as a **third pack, added last** |
| Also in scope | **Pathfinding with avoidance** (formerly sub-project 2) and **day and night** |
| Deferred | Audio, and web and mobile export, to a later platform sub-project |
| Bridge | The Rust core runs **in-process through a gdext extension** |
| Geometry | **Layout lives in the manifest** |

Anything not listed above is a proposal in this document, open to change at
review.

## What this proves

- **Style independence.** In all three styles, the same tick, the same viewer
  and the same seed put the same occupants in the same places and states.
- **Styles are data plus one script.** The voxel pack is added after the client
  is finished. Its commit touches nothing outside its own folder.
- **Movement belongs to the core.** Paths, queues and avoidance are simulated
  deterministically in Rust. Clients only interpolate between ticks.
- **Privacy survives presentation.** No pack is ever given a hidden occupant,
  and no visible behaviour, such as capacity, seats, queues or walking around
  obstacles, reveals one.

## Scope

**In scope:**

- layout, a clock and movement in the contracts and core;
- a district fixture and a synthetic crowd over any manifest;
- the `city-godot` extension;
- the Godot client, with three style packs;
- asset generators;
- tests and the gate.

**Out of scope:**

| Item | Where it goes |
| --- | --- |
| Audio | Later platform sub-project |
| Web and mobile export | Later platform sub-project |
| The network room server | Sub-project 4 |
| Avatar customisation | Sub-project 5 |
| Build mode | Later |
| The Severance office skin | A room-template skin in a later pack; this sub-project makes that possible |

## Workspace

```
city/
  crates/city-contracts   + layout, clock, positions in projections
  crates/city-core        + nav grid, walking, door admission, queues, avoidance,
                            time of day, crowd generator
  crates/city-cli         + crowd flag on run; validate checks layout
  crates/city-godot       NEW: gdext 0.5 extension exposing CityWorld
  fixtures/district/      NEW: district manifest and scripted story feed
  godot/                  NEW: Godot 4.6 client project
    core/                 style-agnostic client logic (GDScript)
    styles/lowpoly_tropical/   style.json, GLBs, pack.gd
    styles/pixel_art/          style.json, sprite sheets, pack.gd
    styles/voxel/              style.json, pilot GLBs, pack.gd (last)
  tools/styles/           asset generators: Blender (low-poly), Python + Pillow (pixel)
```

The voxel pilot in `prototypes/voxel-work-bay/` stays untouched. The voxel
pack copies the pilot GLBs it uses and records their source hashes.

## Contracts

All additions are optional fields. Every existing manifest, feed and snapshot
stays valid, and `SCHEMA_VERSION` stays 1.

### Layout

Positions are **integer centimetres** on a ground plane (x east, z south).
Facings are **integer degrees**, clockwise from north.

| Node | New fields | Meaning |
| --- | --- | --- |
| City | `entrances: [Point]` | Where arrivals appear and departures leave |
| Facility | `exterior: Option<String>` | Building-shell template, such as `guild-hall`, `library` or `cafe` |
| Room | `template: Option<String>`, `rect: Option<Rect>`, `obstacles: [Rect]` | Furniture set, floor area, and blocked footprints such as desks, tables, counters and the tree trunk |
| Seat | `pos: Option<Point>`, `facing: Option<i32>`, `kind: Option<String>` | Seat position and furniture, such as `desk`, `bench`, `cafe-table` or `reading-chair` |
| Door | `pos: Option<Point>` | Where a walk crosses between rooms |

A manifest either has layout **everywhere** or **nowhere**. When layout is
present, every room has a `rect`, every seat a `pos` and every door a `pos`.
`city validate` adds these checks:

- layout is complete, or absent throughout;
- seats and obstacles lie inside their room, and no seat lies inside an obstacle;
- rooms do not overlap;
- each door lies on the shared edge of the two rooms it joins;
- each entrance lies on an outdoor room's edge.

Outdoor places, such as the plaza, are ordinary rooms whose template is
`plaza`.

### Clock

`Manifest.clock: Option<Clock { ticks_per_day: u32, start_minute: u32 }>`.
A projection's `time_of_day` is:

```
(start_minute + tick * 1440 / ticks_per_day) % 1440
```

This uses integer arithmetic. The time of day is presentation data; no rule
reads it.

### Projections

Each `OccupantView` gains:

- `pos` and `facing`;
- `moving: bool`;
- `path_ahead`: up to 4 upcoming waypoints, for smooth interpolation;
- `queue: Option<{ room, position }>`, when waiting at a door.

`Projection` gains `time_of_day: Option<u32>`.

`Snapshot` gains each occupant's position, facing, current path and pending
target, plus the reservation state the rules need.

## Movement rules

Movement applies only when the manifest has a layout. Without a layout, the
rules are exactly as in the world core, with door transit timers, so the
synthetic scale city is unchanged.

### Navigation grid

The layout rasterises into a grid of **25 cm cells**:

- a cell is walkable if its centre lies inside a room's rect and outside its obstacles;
- a door opens the cells along its edge segment;
- walls are room edges that have no door.

The grid is built once per world. Paths come from **A\*** with integer costs:

| Step | Cost |
| --- | --- |
| Straight | 10 |
| Diagonal | 14 |

Ties break on the lower cell index. A diagonal step may not cut a wall corner.

### Walking

- At 1× speed a tick is one second.
- A walker advances **up to 5 cells (125 cm)** per tick along its path.
- Facing follows the direction of the last step, rounded to 45°.

### The life of an occupant

1. **Arrive.** The occupant appears at an entrance: the one nearest the target
   room by path length, with ties broken by entrance order. They walk to the
   target room's door.
2. **Admission at the door.** When a walker reaches its target door, admission
   uses the world core's rules: capacity held for reserved seats, the overflow
   chain, and never overtaking a queue.
   - **Admitted:** they walk to the seat the policy assigned and sit. With no
     free seat, they walk to a standing spot: a free walkable cell of the room,
     outside door cells, chosen by a hash of the seed, the occupant and the
     tick (not the shared RNG, so no one's choice can shift another's).
   - **Room full:** they walk on to the next room in the overflow chain, and
     are admitted at that room's door.
   - **Whole chain full:** they join the original room's **queue**.
3. **Queue.** Queue slots are cells laid out outside the door, filled in
   order, and the queue advances as people are admitted. The waitlist and the
   queue are one ordered list.
4. **Move between rooms.** The occupant stands (the seat is released), walks
   through the connecting doors, and is admitted at the target room's door as
   above.
5. **Depart.** The occupant stands (the seat is released), walks to the
   nearest entrance, and is removed on reaching it. The `Departed` event fires
   on arrival at the entrance; `SeatReleased` fires when they stand. A
   `Depart` command for someone already walking out is ignored, with a
   `Rejected` event.

Occupants hidden from the public, meaning private personal agents and
anonymous observers, follow the same paths but are **overlays**:

- they take no capacity and no seat (as in the world core);
- they join no queue;
- they reserve no cells;
- they never block or divert anyone.

An overlay may therefore be drawn overlapping others. Only its owner, its
grantees and the operator can see it, and nothing visible can react to it.

Nothing about a visible walker can reveal a hidden one.

### Avoidance

Each tick:

1. Walkers step one at a time, in city-ID order.
2. A walker's next cell must be free of any other visible walker's reserved
   cell. Seated and queued occupants reserve their cells.
3. A blocked walker waits in place.
4. After **3 consecutive blocked ticks**, it re-plans with currently reserved
   cells treated as walls.
5. If no path exists, it keeps waiting and re-plans every 3 ticks.

The result is deterministic by construction, and simple enough to verify.

### Tick order

The world core's seven phases remain. Movement adds work inside them:

| Phase | Movement work |
| --- | --- |
| Ingest | Commands start walks: arrive, move, depart |
| Admit | Walkers who reached a target door are admitted, redirected, or queued |
| Allocate | Admitted walkers get a seat and a path to it |
| Transition | Walkers step, in order, with avoidance |
| Depart | Walkers who reached an entrance leave |

### Randomness

With a layout the world draws nothing from its ChaCha RNG: path lengths
replace door transit timers, and standing spots come from a per-occupant hash.
The crowd generator has its own seeded RNG.

## Crowd

`city_core::crowd(manifest, count, seed) -> Feed` generates a fixture feed of
`count` occupants over any manifest with a layout:

- a mix of kinds;
- arrivals through entrances, spread over the day;
- visits to rooms by template, such as the café at lunch and the library in
  the afternoon;
- presence observations;
- departures.

`city run --crowd N` merges the crowd feed with the scripted feed. Entries at
the same tick keep scripted-first order.

## District fixture

`city/fixtures/district/` holds the manifest and the scripted story.

| Facility | Rooms | Notes |
| --- | --- | --- |
| Guild hall | Workshop (making pods; Kai's reserved desk), Commons | Workshop overflows to Commons |
| Library | Reading room (reading chairs) | Echo and the Librarian work here |
| Café | Café floor (café tables) | Overflows to the Plaza |
| Plaza | Outdoor room with the central tree, benches | Every building's door opens onto it; entrances on its edges |

**Clock:** one day is 600 ticks (10 minutes at 1×), starting at 07:00. A
40-minute run therefore shows four days and nights.

**The scripted story** repeats the gate beats:

- overflow;
- a queue outside the full workshop;
- a stale task;
- a running agent with no task;
- Asha's private agent;
- an anonymous observer;
- a walk between buildings;
- everyone leaving.

About **60 crowd occupants** come and go around it.

## The Godot bridge

The `city-godot` crate (gdext 0.5, `api-4-6`) builds a cdylib that the client
loads as a GDExtension.

| Method | Returns |
| --- | --- |
| `load(manifest_json, feed_jsonl, seed, crowd)` | `{ok, issues}` |
| `step()` | The new tick |
| `tick()` | The current tick |
| `project_json(viewer)` | A projection as JSON. `viewer` is `public`, `person:<id>` or `operator` |
| `layout_json()` | The layout as JSON |

The logic lives in a plain Rust module that is tested without Godot; the gdext
layer only wraps it. JSON strings cross the boundary, using the same contract
as the CLI and MCP.

The client offers the operator viewer only when launched with `--operator`,
the same rule as the CLI and MCP.

## The Godot client

### Client core

`godot/core/` is style-agnostic GDScript.

| Unit | Does |
| --- | --- |
| `world_driver.gd` | Owns `CityWorld`; steps at 1× (one tick per second), 2×, 4× or 8×; pause and single-step |
| `scene_model.gd` | Diffs successive projections into changes: appeared, left, walking (with path), sat, stood, headline changed, queued or advanced, time of day |
| `motion.gd` | Interpolates each walker between its tick positions along `path_ahead`; no path-finding of its own |
| `hud.gd` | Style switch (1, 2, 3 or a menu); viewer switch; time controls; name tags (N); the fixture banner, always visible |

Godot never writes simulation state.

**Style switching** tears down the active pack and calls `build_world`, then
`spawn` for every current occupant. The new pack shows the same tick, the same
occupants, the same seats and the same states.

### The style-pack interface

`styles/style_pack.gd` defines the interface every pack implements:

```
build_world(layout, style_json)   teardown()
spawn(occupant)   despawn(id)   update(occupant, interpolated_pos, facing)
set_pose(id, pose)            # walking | sitting | standing | queued
set_presence(id, headline)    set_badge(id, badge)
show_names(bool)   set_selected(id)   set_time_of_day(minutes)
```

`style.json` maps every semantic key the scene model can emit to an asset or
treatment:

- occupant kind and role;
- seat kind;
- room template;
- facility exterior;
- headline state;
- badge;
- name-tag look;
- day and night treatment.

A missing key renders a **marked placeholder**, a magenta box or sprite, and is
logged. A pack never borrows another pack's art.

### 11 Low-poly tropical diorama (3D)

- **Assets:** generated by Blender scripts. The GLBs are validated with the
  Khronos validator and reproducible from source.
  - **Buildings:** limewash walls, terracotta roofs, a green-copper library
    dome, jackfruit-yellow café awnings.
  - **Outdoors:** a faceted central tree, palms, benches, lamps.
- **Interiors:** shown cut-away, with no front walls or roofs over them.
- **Characters:** one modular faceted humanoid, with colours and hair from
  opaque `appearance` parameters. Agents are a white-and-yellow robot with a
  dark visor. Each has walk, sit and idle clips.
- **Presence:** shown with a pose and a small floating icon:

  | Headline | Shown as |
  | --- | --- |
  | Working | Typing |
  | Idle | Leaning back |
  | Stale | Greyed icon with a clock |
  | Unknown | Question mark |
  | Offline | Dimmed |

- **Camera:** an orbiting diorama camera with an overview preset, and
  click-to-focus on a building.
- **Day and night:** the sun angle and colour follow the time of day, and lamps
  and windows glow at night.

### 08 Pixel art (2D)

- **Assets:** sprites generated by Python and Pillow.
  - **Tiles:** a 2:1 isometric grid with tiles 32 px wide.
  - **Palette:** one fixed palette of at most 32 colours, drawn from the
    pixel-art concept sheets.
  - **Dithering:** selective, on foliage and water only.
  - **Buildings:** a brick workshop with a sawtooth roof, a domed library, a
    café awning.
  - **Outdoors:** a big tree, benches, lamps.
- **Characters:** 16×24 sprites with 4 facings and walk, sit and idle
  animations, in palette-swapped outfits. Agents are compact robots with a
  visor.
- **Presence:** a pixel icon bubble above the head.
- **Camera:** pan, with integer zoom only (1×, 2×, 3×) and nearest-neighbour
  filtering.
- **Draw order:** Y-sorted, so occupants pass behind furniture and walls.
- **Day and night:** the palette shifts toward the night palette, and windows
  and lamps light up.

### Voxel (3D, added last)

- **Real voxel art** for the Guild hall and the robot agents: the pilot's
  environment kit, desk, chair, terminal, and the Kai and Lyra rigs with their
  walk, sit, stand, typing and seated-idle clips.
- **Placeholders** for the library, café, plaza tree and human characters,
  which have no voxel art yet. These are listed in the pack's `style.json`
  under `declared_placeholders`, so the gap is explicit.
- **Scope of the commit:** it changes only `godot/styles/voxel/`.

### Shared presentation rules

- **Name tags** are hidden by default. N, or the HUD button, shows them all;
  hovering over or selecting one occupant shows only theirs.
- **Tag contents:** the display name and a badge (`AI`, `simulation`, or
  `your agent` for the viewer's own). A task summary appears only if the
  projection carries one.
- **The fixture banner** is always visible: "Fixture data — not real agent
  state."

### Failure behaviour

- **The extension is missing or fails to load:** the client shows an error
  screen with the build command, never a blank window.
- **The manifest is invalid:** its validation issues are listed.
- **A style fails to build:** the previous style stays active, and the error is
  shown.

## Testing

### Rust

- **Layout validation:** every new rule, with a failing case for each.
- **Navigation:**
  - A\* optimality on small hand-drawn grids;
  - a diagonal never cuts a corner;
  - tie-breaks are deterministic.
- **Walking scenarios:**
  - an arrival walks from an entrance and is admitted at the door;
  - overflow walks on to the next room;
  - a queue forms outside the full room and advances in order;
  - a walk between buildings goes through doors;
  - a departure leaves by the nearest entrance;
  - two walkers meeting in a corridor never share a cell and both get through;
  - a hidden overlay never blocks a visible walker.
- **Property tests:** the world core's seven invariants plus the following,
  checked after every tick over generated manifests with layouts:
  - no two visible occupants (walking, seated, standing or queued) share a cell;
  - every position is walkable;
  - no step exceeds 5 cells;
  - a queue exists only outside a room whose chain is full;
  - hidden occupants reserve nothing;
  - byte-identical logs for the same inputs.
- **Crowd:** deterministic from its seed, and the invariants hold over the
  district for a full day.
- **Bridge:** its logic module is tested in plain Rust.
- **Scale:** tick time for the district with 60, 300 and 1,000 walkers,
  recorded as evidence and not as a promise.

### Godot (headless, like the pilot's tests)

- **Scene model:** canned projection pairs produce the right changes.
- **Motion:** interpolation stays on the path segment and reaches the tick
  position exactly at the tick.
- **Pack contract,** run against every pack:
  - it builds the district;
  - it spawns every occupant kind;
  - it shows every headline and pose;
  - it applies the time of day;
  - it tears down cleanly.
- **Style switch:** the same set of occupants, seats, poses and states before
  and after.
- **Privacy:** under the public viewer, no node exists for a hidden occupant.
- **Name tags:** hidden by default; N shows them; the summary appears only
  when present.
- **Mapping coverage:** every semantic key the district emits is mapped in
  each pack. Voxel instead lists its declared placeholders.
- **Assets:**
  - every GLB passes the Khronos validator;
  - pixel sprites use only palette colours and sit on the fixed grid.

### Evidence, not acceptance

- Captures of the same tick in all three styles, by day and by night, in a
  graphical session.
- Frame time at district scale.

## Delivery

One specification, delivered as four stages. Each stage is its own pull
request, and each is reviewable and green on its own:

| Stage | Delivers | Visible result |
| --- | --- | --- |
| A. Movement core | Layout, clock and movement in the contracts and core; validation; crowd; the district fixture; property tests | The `city` CLI and the text view show walking, queues and time of day |
| B. Bridge and low-poly | `city-godot`, the client core, the style-pack interface, the low-poly pack and its generators | The district live in Godot, in one style |
| C. Pixel art | The pixel pack and its sprite generator; the live style switch | Two styles, switching live |
| D. Voxel | The voxel pack only | Three styles; the style boundary is proven |

## Gate

This sub-project is complete when **all** of the following hold:

- **The district runs live** in the Godot client.
- **Arrivals walk in from the entrances.** A queue forms outside the full
  workshop and advances in order. Walkers never overlap.
- **Switching style live** among low-poly, pixel art and voxel shows the same
  tick, the same occupants, the same seats and poses, and the same states.
- **Switching viewer changes what exists:**
  - Asha sees her private agent;
  - the public never does;
  - nothing visible bends around a hidden occupant.
- **Day turns to night** in each style.
- **Name tags appear only on demand,** and the fixture banner is always
  visible.
- **The voxel commit touches nothing outside `godot/styles/voxel/`.**
- **Determinism and invariants:** the same seed gives a byte-identical event
  log, and every invariant holds on every tick of the gate run.

## Acceptance boundary

Nothing here is a player-facing feature, and nothing is accepted by being
built:

- all feeds are labelled fixtures;
- all art is generated or taken from the voxel pilot, and none of it is a
  production style decision;
- captures are evidence for Rakesh's judgement, not approval.

## Open questions this sub-project does not settle

- **Production style.** Three packs are rendered to prove independence; none
  is selected.
- **RD03.** Whether observers become visible to each other. If they do, they
  would take capacity and reserve cells again.
- **Web and mobile export, and audio.** These wait for a platform sub-project.
  The core already builds for wasm; the gdext extension's wasm support is
  experimental.
- **The network server (sub-project 4).** The client consumes projections only,
  so a WebSocket source can later replace the in-process `CityWorld` without
  changing any pack.

## Settled during implementation (2026-09-24)

These refine this specification. Each is open to Rakesh's review.

- **Rooms can carry props** (`tree`, `lamp`, `palm`, `bookshelf`). These are
  presentation data that rules never read. Landmarks like the central tree need
  a position a pack can draw.
- **A room's main door**, where its queue forms, is its first door onto an
  outdoor room. Only when it has none is it the door with the lowest ID. This
  keeps queues outside, not in a neighbouring room.
- **Walks descend precomputed distance fields**: one per room threshold, and
  one to the entrances. Re-plans around a crowd use a bounded search. The
  paths are equally short and far cheaper.
- **Queue fairness.** No capacity sits idle while a queue could use it. Two
  queues competing for one room are served in room-ID order.
- **Arrivals and seating.**
  - Public arrivals appear on the free cell nearest their entrance.
  - Standing spots avoid the first eight queue places of every room.
  - Walkers finish on the seat's cell centre, facing the seat's way.
- **Movement is not synchronous with every event:**
  - `Seated` fires when a seat is assigned, before the walk there.
  - `SeatReleased` fires on the departure tick.
  - `Departed` fires on reaching the exit.
- **A move with a layout** needs a reachable path, not a direct door; an
  unreachable room is rejected as `Unreachable`.
- **`path_ahead`** carries one tick of walking, which is up to five cells.
- **Pixel art** is drawn two ways per sprite: front (down-right) and back
  (up-right). Horizontal flips give the other two facings.
- **Low-poly floors and walls** are built from the layout by the pack.
  Blender generates the furniture, props, building accents and characters.
- **The voxel pack** also uses the pilot's workshop kit: floors, walls,
  windows, doors, lawn, paths, tree, bench, shelf, awning and sign. Its
  declared placeholders are limited to the following:
  - human characters;
  - café and reading chairs;
  - the library dome;
  - lamps and palms.

  With no lamp art, voxel nights have no lamp light.

### After the final review (2026-09-24)

- **Two walkers who want each other's cell swap places.** Head-on meetings in
  a doorway always resolve, and the five-cell limit still holds.
- **A walker held up within three cells of its door has arrived.** It is
  admitted or queued there, rather than waiting behind the crowd on the
  threshold.
- **Blocked walkers re-plan with A\*** toward where they were going.
- **Leavers leave the city within a metre of an entrance.** Unseated
  occupants never stand on a door, seat, queue place or entrance approach.
- **Projections carry `trail`:** the cells actually crossed last tick. Clients
  replay it, one tick behind, instead of animating `path_ahead`, which is
  only a plan. A held-up walker therefore stands still on screen.
- **Style packs receive places only.** They get the manifest without its
  occupant roster or seat reservations.

