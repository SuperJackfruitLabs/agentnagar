# Walk the City in Style — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the district's composition, buildings, scenery, light and art to the quality of the three style sheets. Then add a player: registered or observer, controlled by click, WASD or game controller, with prediction and a first-person view.

**Architecture:** Scenery and building shells are presentation-only manifest data. Cut-away is a client rule applied by every pack. Art comes from in-house Blender and Pillow generators:
- low-poly: faceted meshes with skinned characters;
- pixel: sprites pre-rendered from Blender models, then palette-quantised, outlined and dithered;
- voxel: meshes generated from voxel grids.

Players act only through two new core commands, `Go` and `Steer`, submitted as live input through a per-player session in the bridge. The core validates every step. The client predicts only the player's own avatar, and replays the trail for everyone else.

**Tech Stack:** Rust 1.95 (existing workspace); Godot 4.6.3 with the Forward+ renderer (Vulkan) and GDScript; Blender 5.2.2 (bpy, bmesh, armatures and actions; Workbench for pixel pre-renders); Python 3 with Pillow 10.2; Khronos gltf-validator 2.0.0-dev.3.10.

**Spec:** `docs/superpowers/specs/2026-09-24-city-walk-in-style-design.md`

## Global Constraints

- **Rules and contracts:** everything from PR #24 holds. No floats, HashMap or clock in contracts or the core, and positions are integer centimetres. Every contract addition is optional and `SCHEMA_VERSION` stays 1.
- **Scenery is never read by the rules.** It affects validation only (`scenery-over-walkable`).
- **The same full check runs at the end of every task:**
  - `city/scripts/check.sh`, which covers fmt, clippy `-D warnings`, cargo tests, wasm, Python asset tests and the Godot headless tests;
  - graphical capture runs for any task that changes art.
- **Godot:** the renderer is Forward+ (`rendering_method="forward_plus"`); headless tests use the dummy driver. Projects and extension binaries live under the home directory, never `/tmp`.
- **Assets:**
  - **Generation:** all art comes from generators under `city/tools/styles/<pack>/`, deterministic and reproducible.
  - **GLB:** every GLB passes the Khronos validator with no errors and no warnings.
  - **Pixel sprites:** palette-only colours, on the grid, reproducible.
  - **Transform and sidecars:** Blender objects face +Y, which becomes Godot −Z; units are metres. `.import` sidecars are committed, with LOD generation off for voxel meshes.
- **Art quality** is judged against the sheet panels in `docs/vision/style-studies/styles/{11,08,02}-…/sheets/`. Every art task ends with captures at matching camera presets and a written comparison. Nothing is "done" while a visible gap to the sheet remains that the generator could close.
- **Privacy:**
  - packs receive places only (`layout_json`) and projections;
  - observers are overlays;
  - a session commands only its own occupant.
- **Honesty:** the fixture banner stays on every screen, and the HUD labels the player "You (local player)".
- **Delivery:** one PR per stage. Stage branches stack: stage 1 is on `feat/city-walk-in-style`, and later stages continue on the same branch as additional commit series. They are split into PRs at finish, unless the user merges between stages.

## Review Focus

- **The player breaks privacy.** An observer's position, queue place or seat must never appear in any public projection. `Steer` must never move another occupant. The test is pinned in 5.5 and 5.6.
- **Prediction drift.** A player who holds WASD against a wall or a crowd must not drift away from the core's position by more than one tick of walking, and must ease back, never teleport. The test is pinned in 6.2.
- **Cut-away flicker.** A building must not toggle open and closed every frame while the camera sits at the threshold distance. Hysteresis is required. The test is pinned in 1.3.
- **Controller hot-plug.** Connecting or disconnecting a pad mid-walk must not strand the avatar mid-steer. The test is pinned in 6.1.
- **Art regressions.** New assets must keep every `style.json` key mapped and pass the validator. Pixel sprites must stay palette-exact after the pre-render pipeline. The tests are pinned in 2.x, 3.x and 4.x.

---

## Stage 1 — Composition, scenery, whole buildings, cut-away, Forward+, camera presets

### Task 1.1: Scenery and building-shell contracts, with validation

**Files:** `city/crates/city-contracts/src/manifest.rs`, `city/crates/city-core/src/index.rs`, and tests in `contracts.rs` and `index.rs`.

**Produces:**

```rust
#[serde(tag = "kind", rename_all = "kebab-case")]
pub enum Scenery {
    Water { rect: Rect },
    Bridge { from: Point, to: Point, width: i32 },
    Street { points: Vec<Point>, width: i32 },
    TramLine { points: Vec<Point> },
    Block { rect: Rect, height_class: HeightClass },
    TreeRow { points: Vec<Point>, spacing: i32 },
}
#[serde(rename_all = "kebab-case")] pub enum HeightClass { House, Shop, Tower }
#[serde(rename_all = "kebab-case")] pub enum Roof { Sawtooth, Dome, Vault, Pitched, Flat }
Manifest += #[serde(default, skip_serializing_if = "Vec::is_empty")] pub scenery: Vec<Scenery>
Room += #[serde(default, skip_serializing_if = "is_false")] pub outdoor: bool  // outdoor rooms: entrances, main doors, packs; templates "plaza"/"outdoor" also count, for old manifests
Facility += #[serde(default, skip...)] pub roof: Option<Roof>, #[serde(default, skip...)] pub storeys: Option<u8>
```

**Validation:** `scenery-over-walkable` fires when any of the following holds:
- a `water` or `block` rect intersects a room rect;
- a `street`, `tram-line` or `tree-row` segment's width-expanded bounding box intersects a room rect;
- a bridge segment's box intersects a room rect.

Checking segment boxes is conservative on purpose. The one exception: a street may touch the outer edge of an outdoor room, with zero-area contact.

**Steps:**
- [ ] **Write failing tests:**
  - round-trip of every scenery kind, and old manifests keeping the same shape;
  - validation: water over a room is rejected, a block beside a room is accepted, and a street ending on a plaza edge is accepted.
- [ ] Run the tests and watch them fail.
- [ ] Implement.
- [ ] Watch them pass.
- [ ] Commit: `feat(city): scenery and building-shell contracts`.

### Task 1.2: The district re-laid to the sheets

**Files:** `city/fixtures/district/generate.py`, `manifest.json`, `feed.jsonl`; `city/crates/city-core/src/crowd.rs` (template preferences); tests `scenarios.rs` (`district_gate`, liveness tests) and `cli.rs` (generator check).

**Layout:** in centimetres, x east and z south. Rooms tile edge to edge. The
coordinates have been checked against the validation rules.

| Room | Rect (x, z, w, d) | Doors (position → to) | Contents |
| --- | --- | --- | --- |
| `room:plaza` (tree square, outdoor) | (−1800, −1400, 3600, 2800) | (−1800, −600) → workshop; (−1800, 600) → commons; (−1800, 1200) → café terrace; (1800, −200) → reading; (−600, 1400), (0, 1400), (600, 1400) → tram stop | Tree obstacle (−200, −200, 400, 400) with prop `tree`; 10 bench seats in a ring at radius 450; planters at the four corners; 6 lamps; bollards; capacity 50 |
| `room:workshop` | (−3400, −1400, 1600, 1600) | (−1800, −600) → plaza; (−2600, 200) → commons | 8 desks in pods `making-1` and `making-2`; Kai's desk reserved; capacity 8; overflows to the commons |
| `room:commons` | (−3400, 200, 1600, 800) | (−1800, 600) → plaza; (−2600, 200) → workshop | 4 benches; capacity 4 |
| `room:cafe-terrace` (outdoor) | (−3400, 1000, 1600, 600) | (−1800, 1200) → plaza; (−2600, 1600) → park | 4 table obstacles, 8 `cafe-table` seats, 4 `umbrella` props; capacity 10; overflows to the plaza |
| `room:reading` | (1800, −1200, 1800, 2000) | (1800, −200) → plaza | 8 reading chairs; bookshelves as obstacles and props; capacity 8 |
| `room:park` (outdoor) | (−3400, 1600, 1600, 1400) | (−2600, 1600) → café terrace; (−1800, 1700) → tram stop | 6 palms; 4 bench seats; path props; capacity 20 |
| `room:tram-stop` (outdoor) | (−1800, 1400, 3600, 400) | the three plaza doors; (−1800, 1700) → park | Shelter props; capacity 30 |

**Facilities:**
- Guild hall: workshop and commons, roof `sawtooth`, 1 storey.
- Library: reading room, roof `dome`, 2 storeys.
- Café: the café terrace.
- The plaza, park and tram stop are outdoor facilities.

**Entrances:** (−600, 1800) and (600, 1800) on the tram stop's south edge;
(−3400, 2300) on the park's west edge; (0, −1400) on the square's north edge;
(1800, 1100) on the square's east edge, below the library.

**Scenery:**

| Kind | Geometry |
| --- | --- |
| `water` | (−7000, −4000, 2600, 9000) |
| `bridge` | (−7200, 2300) → (−4200, 2300), width 400 |
| `street` | (−4200, 2300) → (−3400, 2300), width 300: the bridge approach to the park entrance |
| `street` | (−4400, −1900) → (5000, −1900), width 600: north |
| `street` | (−1700, 2300) → (5000, 2300), width 600: south |
| `tram-line` | (−1600, 2050) → (5000, 2050) |
| `block` | Houses (−4300, −1400, 800, 1000), (−1000, 2700, 1200, 900), (800, 2700, 1200, 900) and (2600, 2700, 1200, 900); shops (3700, −1200, 1000, 900) and (3700, −200, 1000, 900); towers (−2000, −4200, 1500, 1500), (0, −4200, 1500, 1500) and (2000, −4200, 1500, 1500) |
| `tree-row` | Along z −1500 (x −1700..1700) and along z 2650 (x −1500..4800), spacing 600 |

**Story:** the same beats as today:
- overflow into the commons;
- a queue of two or more outside the full workshop;
- a stale task and a process with no task;
- Asha's private agent and the guest observer as overlays;
- Asha moving to the café terrace;
- everyone leaving by tick 190.

**Crowd preferences:**

| Hours | Rooms |
| --- | --- |
| 11:00–14:00 | `cafe`, `cafe-terrace` |
| 14:00–18:00 | `reading-room`, `park` |
| Otherwise | `plaza`, `commons`, `park` |

**Steps:**
- [ ] **Update tests first:**
  - `district_gate` asserts the new beats and room IDs: `room:workshop`, the queue outside the workshop, and `room:cafe-terrace`;
  - the liveness tests keep their bounds, 60 ticks at crowd 60 and 120 at crowd 300;
  - a new scenario asserts that every scenery kind is present and the manifest validates.
- [ ] Run the tests and watch them fail.
- [ ] Implement `generate.py` and the crowd preferences, and regenerate.
- [ ] Run everything until it passes. Tune the story, never the rules.
- [ ] Commit: `feat(city): district re-laid to the style sheets' composition, with scenery`.

### Task 1.3: Client — Forward+, camera presets, the cut-away rule, and the pack contract for scenery and shells

**Files:** `city/godot/project.godot`; new `city/godot/core/cutaway.gd`; `city/godot/styles/style_pack.gd`; `city/godot/core/style_host.gd`; `city/godot/main.gd`, `hud.gd`; tests `test_cutaway.gd` and `test_pack_contract.gd` (extended).

**Produces:**

- **`CutawayRule` (RefCounted):**
  - `func open_set(avatar_room, selected_room, camera_inside: Array, open_all: bool, facilities_of: Dictionary) -> Dictionary`, returning `{facility_id: true}` for each facility to open.
  - **Hysteresis:** a facility opened because the camera is inside stays open until the camera is more than 150 cm outside its footprint.
- **`StylePack` additions:**
  - `build_scenery(scenery: Array)` is called by the host after `build_world`.
  - `set_open(facility_id: String, open: bool)`.
  - `facility_ids() -> Array`.
  - `camera_presets() -> Array`, returning `["topdown", "diagonal", "street"]`; 3D packs also return `"fpv"` in stage 7.
  - `set_camera_preset(name: String) -> bool`.
  - `camera_ground_pos() -> Vector2`, in centimetres, for the cut-away rule.
- **The host** applies `CutawayRule` every frame, calling `set_open` only on changes.
- **HUD:** X toggles "open all", and T, G and Y choose camera presets.
- **`main.gd`:** `--camera=topdown|diagonal|street` applies a preset before capture.

**Steps:**
- [ ] **Write failing tests:**
  - **Cut-away:** a building opens when the avatar is inside, when the selected occupant is inside, and on open-all. The camera-inside hysteresis holds: no flip-flop across a ±10 cm jitter at the boundary.
  - **Pack contract:** every pack builds the scenery; `facility_ids()` equals the manifest's facilities; `set_open` works both ways without errors; every preset in `camera_presets()` applies.
- [ ] Run them and watch them fail.
- [ ] Implement the core scripts, and a minimal `set_open` and `build_scenery` in each pack. Task 1.4 does it properly.
- [ ] Watch them pass.
- [ ] Commit: `feat(city-godot): cut-away rule, camera presets, Forward+`.

### Task 1.4: Packs draw scenery and whole buildings, coherently, at their current fidelity

**Files:** the three `pack.gd` files; generators where a stage-1 shell or scenery asset is needed; evidence captures.

- **Low-poly:**
  - facility shells from the footprint: full-height façade walls with window cut-outs, and a roof by type (sawtooth, dome, flat) built as meshes in `pack.gd`;
  - scenery: water plane, stone bridge, street strips, the tram line with an animated tram (box-built for now), blocks as simple roofed boxes, tree rows using the palm and tree props.
- **Pixel:** roof and façade sprites composited per facility from generated parts; scenery sprites (water tiles, street tiles, block boxes, a tram). Kept simple; stage 3 replaces them.
- **Voxel:** shells from the pilot's wall, window and roof modules; scenery as voxel boxes.
- **Cut-away:** each pack implements `set_open` by fading the roof and hiding the near façade (3D), or hiding the roof and front-wall sprites (2D).

**Steps:**
- [ ] Contract tests from 1.3 pass for every pack.
- [ ] Take captures per pack at the Top-down, Diagonal and Street presets.
- [ ] Commit: `feat(city-godot): scenery and whole buildings in every pack`.

---

## Stage 2 — Low-poly tropical at sheet quality

**Reference:** `11-low-poly-tropical-diorama` sheets 00, 01, 02 and 03. Target look:
- warm limewash and terracotta, with jackfruit-yellow accents;
- faceted foliage, with smoothly painted building volumes;
- chunky stylised people;
- a white-and-yellow robot with a black face and glowing cyan eyes;
- golden-hour light.

### Task 2.1: Kit v2 — shared library, buildings, bridge, tram

**Files:** `city/tools/styles/lowpoly/{lib.py, buildings.py, scenery.py, build.py}`, and `test_assets.py` (extended).

- **`lib.py`:**
  - the palette, with sRGB-to-linear conversion;
  - material helpers: roughness, and emission for windows and lamps;
  - bmesh builders: extruded polygons, bevelled boxes, arched window cut-outs by boolean or inset, faceted "noise" displacement for foliage, and array helpers;
  - `export(name)`, with validator-safe settings.
- **Buildings,** as modular pieces in GLB, sized by `pack.gd` from the footprint:
  - `hall_sawtooth_bay` (4 m bay): a terracotta sawtooth roof over a glazed clerestory and timber trusses;
  - `hall_wall`, `hall_window_wall`, `hall_door_wall`, `hall_corner`;
  - library: `lib_wall_arch` (an arched window with limewash, cornice and plinth), `lib_column`, `lib_entrance` (steps, lit doors, banner mounts), `lib_dome` (a green-copper ribbed dome with lantern and drum), `lib_banner` (yellow, with a book emblem);
  - `tram_shelter`: a canopy with a bench and a timetable sign.
- **Scenery:**
  - blocks: `house_a` and `house_b` (limewash, terracotta hip roof, balcony, window shutters); `shop_a` (ground-floor awning); `tower_a` (a stepped limewash tower with window bands and rooftop greenery);
  - `bridge_span` (a stone arch with balustrade, 4 m module) and `bridge_pier`;
  - `street_tile`, `tram_track`, `water_tile` (faceted, with gentle vertex undulation);
  - `tram` (cream and red, three cars, with windows and pantograph).

**Tests:** these are extended to cover:
- node names;
- a bounding size per asset within ±10% of its target (for example, a house under 9 m tall);
- validator-clean output;
- a triangle budget per asset (house ≤ 3k, tree ≤ 4k, tower ≤ 6k), for performance.

- [ ] Write the failing tests.
- [ ] Build the recipes and generate.
- [ ] Pass the tests.
- [ ] Review each asset visually in a Blender turntable capture (`render_preview.py`, which renders PNG previews into `city/tools/styles/lowpoly/previews/`, gitignored). Fix what looks off.
- [ ] Commit.

### Task 2.2: Vegetation, ground and props v2

Everything here is faceted and low-poly, with 2–3 greens:
- **Banyan (`tree_banyan`):** a flared trunk with aerial roots, 8–10 canopy lobes, and paper lanterns (emissive yellow).
- **Palms:** three sizes.
- **Shrubs:** `shrub_round` and `shrub_leafy`; `flowerbed` (a stone-edged bed with pink, yellow and white flowers).
- **Planters:** `planter_square` (limewash) and `planter_pot` (terracotta).
- **Street furniture:** `bench_park`, `bollard`, and `lamp_post` (with an ornate lantern whose emissive node is named `light`).
- **Café:** `umbrella_yellow`, and `cafe_table_set` (a round table with 2 chairs).
- **Workshop and library interiors:** `workbench` (tools, a bridge model, a screen); `bookshelf_v2`; `reading_chair_v2`; and a `desk_v2` set (desk, chair and terminal).
- **Paving:** `paving_tile` in 1 m sandstone, three patterned variants chosen by hash, so the square shows the sheet's paving pattern.
- **Tests and review:** same as 2.1. Commit.

### Task 2.3: Characters v2, skinned and animated

- **Rig:** one armature, `rig_human`, with bones hips, spine, chest, neck, head, and for each side upper arm, forearm, hand, thigh, shin and foot.
- **Bodies:**
  - mesh parts are rigid-skinned to bones, with stylised proportions (head about a sixth of the height, broad shoulders);
  - body variants come as material slots: skin, top, bottom, shoes;
  - four hair meshes are separate child objects, `hair_0` to `hair_3`;
  - accessory options: `hat_sun` (straw) and a backpack.
- **Robot:** `rig_robot`, with the same bone names; a white shell with yellow panels, a black glossy face plate, emissive cyan eye arcs (`eyes`), ear discs and a leaf badge.
- **Actions,** exported as glTF animations: `walk` (1 s loop), `sit` (a loop that holds a seated pose), `idle` (breathing), `typing` (seated arms and hands).
- **Tests:**
  - skin joints exist;
  - the animation names `{walk, sit, idle, typing}` are present on both GLBs;
  - the validator is clean;
  - the character's height is 1.65–1.8 m (human) or 1.55–1.7 m (robot).
- **Review:** turntable previews of each action. Commit.

### Task 2.4: Low-poly pack v2 — assembly, lighting and polish

**Files:** `city/godot/styles/lowpoly_tropical/{pack.gd, style.json, environment.tres}`.

- **Buildings:** assembled from the modules along each facility footprint:
  - sawtooth bays along the hall;
  - arched walls, columns, the entrance and the dome on the library;
  - windows emissive at night.
- **Cut-away:** the roof fades (alpha tween) and the near façade drops, as in 1.3.
- **Ground:** paving tiled with variants; flower beds and planters placed from props; scenery from the v2 assets.
- **Characters:**
  - skinned GLBs driven by an `AnimationPlayer`: walk while moving, sit or typing when seated, idle otherwise;
  - `AnimationTree` blending, 0.2 s crossfades;
  - variants set by material overrides from `appearance`, with the hair mesh chosen.
- **Environment:**
  - a procedural sky with cloud layers (a `ProceduralSkyMaterial` plus billboard cloud meshes);
  - SSAO and glow on;
  - an ACES tonemapper with a warm grade;
  - `DirectionalLight3D` shadows with 4 splits;
  - golden-hour colour ramps across the day, and blue nights with warm windows and lamps.
- **Presence:** icon billboards, redrawn at 128 px in the palette.
- **Captures and comparison:**
  - take Top-down, Diagonal and Street captures by day and night;
  - put them beside `00-city-perspectives` (Top-down, Diagonal, Street) and `02-creating-exploring` (Night and rain) in a comparison sheet, `evidence/lowpoly-vs-sheet.png`;
  - write the remaining gaps in `evidence/lowpoly-notes.md`;
  - iterate until no fixable gap remains.
- [ ] Commit: `feat(city-godot): low-poly tropical at sheet quality`.

---

## Stage 3 — Pixel art at sheet quality, pre-rendered

**Reference:** the `08-pixel-art` sheets. Target look:
- a navy outline and a controlled palette;
- brick-red and sandstone buildings, with a navy sawtooth roof and a domed library;
- dense, dithered green canopies and flower beds;
- characters with readable outfits;
- lit windows at night.

### Task 3.1: Pixel model kit and the pre-render pipeline

**Files:** `city/tools/styles/pixel/{models.py, render.py, post.py, build.py, palette.py}`, and `test_sprites.py` (extended).

- **`models.py`** builds Blender scenes per sprite:
  - buildings as roof and façade pieces per footprint module: hall bays, library segments and dome;
  - props: trees, flower beds, lamps, benches, planters, café sets, the tram, blocks, and the bridge.
- **`render.py`:**
  - Workbench engine, orthographic camera at the 2:1 isometric angle (30° elevation and 45° yaw), anti-aliasing off;
  - a scale of 32 px per metre horizontally along the iso axes, matching the tile grid;
  - flat colour with the model's material colours, plus a studio light for shading bands;
  - renders a PNG per sprite per facing.
- **`post.py`:**
  - quantise to `palette.DAY` by nearest colour in Lab space;
  - apply 1 px outlines in `outline` on alpha edges;
  - dither selectively where the material says so: foliage and water;
  - produce night twins through `NIGHT_MAP`;
  - write the anchors.
- **Tests:**
  - palette-only colours and grid sizes, as today;
  - reproducible: two runs are byte-identical, which needs Workbench with no AA and a fixed viewport size;
  - every `style.json` reference exists;
  - the anchor JSON is complete.
- [ ] Write the failing tests.
- [ ] Build the pipeline.
- [ ] Pass the tests.
- [ ] Review the contact-sheet preview against the sheets, and iterate.
- [ ] Commit.

### Task 3.2: Characters rendered in 8 directions

- The low-poly rig and actions are reused with pixel-pack materials: palette outfits, with no facets visible after quantisation.
- **Rendering:** 8 yaws × frames: walk ×6, sit ×1, idle ×2, typing ×2.
  - Characters are 32 px tall (to the head top).
  - Sheets are 32 × 40 per frame, one row per direction.
  - There are 8 human outfit variants, plus muted, plus robot variants (guild, city, personal).
- **Tests:** frame grid, palette, reproducibility.
- [ ] Commit.

### Task 3.3: Pixel pack v2

- **Assembly:**
  - buildings from the pre-rendered roof and façade sprites along each footprint, with roof and front-wall sprites hidden on cut-away;
  - scenery: water tiles with animated shimmer (2 frames), streets, the bridge, blocks, tree rows, and the tram sliding along its line (Y-sorted, flipped per direction).
- **Characters:** 8-direction animation from the sheets, chosen from the walk direction or seat facing.
- **Night:** night twins, plus `PointLight2D` lamp glows.
- **Captures:** Top-down and Diagonal compared against sheet `00`; the Street preset in 2D shows a closer zoom (3×) over the square. Write a comparison sheet and notes, and iterate.
- [ ] Commit: `feat(city-godot): pixel art at sheet quality`.

---

## Stage 4 — Voxel extended to the city

**Reference:** the `02-voxel` sheets. Target look:
- a yellow workshop with a sawtooth roof and an orange barrel-vault library;
- blocky trees, a white-and-orange tram, white and blue towers;
- a grey paved square;
- blocky people.

### Task 4.1: Voxel builder and recipes

**Files:** `city/tools/styles/voxel/{voxel.py, recipes.py, build.py, test_assets.py}`.

- **`voxel.py`** turns a 3D grid of palette indices into a mesh of only the exposed faces, merged per colour and greedy-meshed. It is exported as a GLB with vertex colours or one material per colour, at a voxel size of 10 cm.
- **Recipes:**
  - workshop: yellow sawtooth bay modules;
  - library: an orange barrel-vault module, glass and entrance;
  - trees in three sizes;
  - planters, benches, lamps, bollards;
  - café table and umbrella;
  - reading chair and bookshelf;
  - blocks: house, shop, and a tower with rooftop greenery;
  - bridge and tram;
  - humans rigged with the shared rig (blocky meshes skinned to the bones, reusing the stage 2 actions);
  - street, water and paving tiles.
- **Tests:** validator-clean, size targets, animation names, reproducible.
- [ ] Commit.

### Task 4.2: Voxel pack v2

- **Assembly:** the new pieces are used everywhere. The pilot's robots, desk, chair and terminal stay.
- **Placeholders:** `declared_placeholders` becomes `[]`.
- **Captures:** compared with sheet `00` and iterated.
- [ ] Commit: `feat(city-godot): voxel city`.

---

## Stage 5 — Player core

### Task 5.1: Contracts for `Go` and `Steer`

```rust
#[serde(tag = "type")] pub enum Target { Point { pos: Point }, Seat { seat: PlaceId }, Room { room: PlaceId } }
Command += Go { occupant: CityId, to: Target }, Steer { occupant: CityId, cells: Vec<Point> }
CommandType += Go, Steer
RejectReason += SeatTaken, NotYourSeat, BlockedStep
```

Tests cover the round-trip and the command type. Commit.

### Task 5.2: `Go` in the world

**Rules:** see spec Section 1.

**New state:** `OccupantState.goal: Option<Target>`, a pending post-admission target (serde default). Admission uses it for the walk after placement: a seat or point instead of a policy seat or standing spot. Refusals:

| Refusal | When |
| --- | --- |
| `SeatTaken` | The target seat is held |
| `NotYourSeat` | The target seat is reserved for someone else |
| `Unreachable` | No path leads to the target |

A point that is invalid is moved to the nearest valid cell.

**Tests:** `walking.rs` gains:
- `go_point_in_room`;
- `go_point_other_room_goes_through_admission`;
- `go_seat_free_hot_seat`;
- `go_seat_taken_is_refused`;
- `go_seat_reserved_for_other_is_refused`;
- `go_own_reserved_seat`;
- `go_room_full_queues`;
- `go_point_on_door_moves_to_nearest_valid`;
- `observer_go_takes_no_seat`.

Commit.

### Task 5.3: `Steer` in the world

**Rules:** accept the listed cells in order while each step holds:
- adjacent to the last, and not more than 5 in total;
- walkable;
- not held by a public occupant, unless the stepper is hidden;
- through a door span when crossing rooms.

Leaving a room releases the occupant's seat and place. Entering a room triggers admission at the threshold, as a walk arriving would. The walker stops at the first refusal, which emits `Rejected BlockedStep`. The walk and goal are cleared. Steering while seated stands the occupant up first; it costs no step. `trail` records the accepted cells.

**Tests:**
- `steer_moves_exact_cells`;
- `steer_stops_at_wall`;
- `steer_stops_at_person`;
- `steer_through_door_triggers_admission`;
- `steer_more_than_five_rejected_after_five`;
- `steer_from_seat_releases_it`;
- `observer_steer_passes_people`.

Commit.

### Task 5.4: Live input and input-log replay

**Produces:**

```rust
World::submit(&mut self, command: Command)
World::input_log(&self) -> &[FeedEntry]
World::input_log_feed(&self) -> Feed
```

Submitted commands apply at the next tick's Ingest, after the feed entries.

**Tests:**
- live commands apply next tick;
- ordering: feed first, then live;
- replaying feed + `input_log_feed()` gives a byte-identical event log and snapshots.

Commit.

### Task 5.5: Sessions and authority in the bridge

**Produces:** in `city-godot/src/bridge.rs`:

```rust
join(as: &str, look: &str) -> String  // {"ok":..,"id":..} ; registers profile, submits Arrive at the tram-stop-nearest entrance
command(json: &str) -> String         // {"ok":true} | {"error":{"code":"not-yours"|"bad-command"|"not-joined"}}
leave() -> String
input_log_jsonl() -> String
```

The viewer is set to the player's ID. The gdext wrappers carry the same names.

**Tests:**
- joining as a registered player makes the occupant visible in the public projection;
- joining as an observer makes the occupant absent from the public projection but present in the player's own view;
- a command for another occupant returns `not-yours`;
- malformed JSON returns `bad-command`;
- `leave` departs.

Commit.

### Task 5.6: Invariants and property tests with players

- The property strategies gain a player (`person:you`) and an observer, with random `Go` and `Steer` live commands.
- **New checkers:**
  - `check_steer`: no occupant moves more than 5 cells, and the path has no wall crossing;
  - `check_observer_private`: an observer never appears in the public projection and holds no seat, cell or queue place;
  - `check_reserved` is extended to cover players.
- The liveness tests are unchanged and must pass.
- [ ] Commit.

---

## Stage 6 — Avatar, controls and prediction

### Task 6.1: Input actions and the router

**Files:** `city/godot/core/input_router.gd`, `project.godot` (the input map), and `tests/test_input.gd`.

- **Actions:**
  - `walk_target`
  - `move_forward`, `move_back`, `move_left`, `move_right`: WASD and the left stick axis
  - `look_x`, `look_y`: right stick
  - `interact`
  - `cancel`
  - `names`
  - `open_all`
  - `style_prev`, `style_next`
  - `zoom_in`, `zoom_out`
  - `speed_up`, `speed_down`
  - `viewer_prev`, `viewer_next`
  - `toggle_fpv`
  - `pause`
  - `cam_topdown`, `cam_diagonal`, `cam_street`
- **`InputRouter`** turns events into intents:
  - `walk_to(screen_pos)`
  - `steer(vector2)`
  - `interact()`
  - and the others
- **Hot-plug:** on `Input.joy_connection_changed`, a disconnected pad zeroes its steering at once.

**Tests:** synthesised `InputEventKey`, `InputEventMouseButton`, `InputEventJoypadButton` and `InputEventJoypadMotion` sequences give identical intents. Hot-plug mid-steer zeroes steering.

Commit.

### Task 6.2: Player controller with prediction

**Files:** `city/godot/core/player.gd` and `tests/test_player.gd`.

**`Player` (RefCounted):**
- `join(world, as, look)`
- `predict(delta, steer_vec, nav_query) -> Vector2`: moves at 125 cm per tick-second along walkable cells, using the layout rects and door spans the client already knows, plus obstacles.
- `cells_this_tick() -> Array`: sent as `Steer` on each tick boundary.
- `reconcile(core_pos)`: if the core's position differs, the display eases toward it over 0.25 s, and the prediction rebases.
- **Clicks** send `Go` with no prediction; the player follows the trail like everyone else.

**Tests:**
- predicted cells for a straight walk equal what the core accepts;
- walking into a wall does not move;
- a correction eases, and never jumps more than one frame's worth;
- drift stays within one tick of walking.

Commit.

### Task 6.3: The avatar in the scene, HUD and look

- **In every pack,** the player's own occupant gets a "you" ring or marker (a 3D ring decal; a 2D pixel arrow) and is drawn at the predicted position.
- **HUD:** "You (local player)", with the state: walking, queued at N, sitting, or observer.
- **Look:** L cycles it by re-joining with a new look. `--as` and `--look` are launch options.
- **Main** wires it together: the router, then the player, then the session commands.

**Tests:**
- a registered join shows in the public projection;
- the HUD status follows the queue;
- an observer join is marked "observer" in the HUD and absent from public.

Commit.

---

## Stage 7 — First-person view and the final gate

### Task 7.1: First-person camera

- **Camera:**
  - eye height 160 cm on the predicted avatar;
  - mouse or right-stick look, with pitch clamped to ±80° and yaw free;
  - the mouse is captured, and Esc releases it;
  - the avatar body is hidden, but its shadow is kept;
  - the crosshair targets a ground point, seat or building for `interact`.
- **Buildings** open when the avatar is inside, through the cut-away rule.
- **Pixel pack:** F shows the note "First-person view is available in the 3D styles", with an option to switch to low-poly.

**Tests:**
- F enters and leaves first-person view;
- the camera stays at eye height;
- the crosshair target resolves to a seat when one is aimed at;
- the pixel pack refuses first-person view gracefully.

Commit.

### Task 7.2: Final gate, captures and docs

The gate, `test_gate_player.gd`, runs the player's route:
1. Join as a registered player and click-walk from the tram stop to the Guild hall.
2. Queue, because the hall is full.
3. Get in and sit at a free desk.
4. Stand, and steer in first-person view with WASD, then with a synthesised stick.
5. Cross the square and enter the library.
6. Switch styles at the hall and at the library.

Throughout:
- every invariant holds;
- `input_log` replay is byte-identical;
- repeated as an observer, no public projection contains the player.

**Captures:** each pack's Top-down, Diagonal, Street and first-person views by day and night, beside the sheet panels.

**Docs:** `city/godot/README.md` (controls, controller, player, first-person view) and `city/README.md`.

- [ ] Commit: `docs(city): player, controls, first-person view and the final gate`.
