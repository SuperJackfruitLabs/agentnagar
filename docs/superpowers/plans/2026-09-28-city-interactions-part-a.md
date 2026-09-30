# City interactions, Part A: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Any placement whose kind offers a capability can be used the same way in every style and on every input. That covers sitting on seats and perches, inspecting anything, reading noticeboards, plaques, bookshelves and kiosks, boarding and going in. Plants part and sway as people pass.

**Architecture:**

- **One core command.** A new `Command::Use` checks the anchor, the occupancy of that anchor and the capability's own rule. A new `interact.rs` in `city-core` owns those rules. Seats, boarding and entering keep their existing machinery but are reached through `Use`. Projections carry `using`.
- **One client path.** A new `core/interact.gd` owns targeting, the prompt, capability cycling and Go-then-Use. `main.gd` loses its per-kind cases.
- **Displays.** Their content is sample panels bundled with the fixture, shown in a `PanelScreen` overlay and drawn at distance-appropriate detail on the surfaces.
- **Swaying plants.** New soft kinds sway through `core/soft_contacts.gd`, client-side only.

**Tech Stack:** Rust (`city-contracts`, `city-core`, `city-godot`), Godot 4.6.3 GDScript, and the Python and Blender kit builders under `city/tools/styles/`.

**Spec:** `docs/superpowers/specs/2026-09-27-city-interactions-design.md`, Part A (§1–§3, and §7's Part A tests). It builds on `2026-09-27-city-placement-grid-design.md`, including its §12 amendments.

## Global Constraints

- **Worktree.** Work in a dedicated worktree (`agentnagar-interactions`), on branch `feat/city-interactions`. It is stacked on `feat/city-placement-grid` (PR #33). Never use a bare `git stash`.
- **Commit messages** end with:
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01JKP5riujFNbo1iL4Yjv4qQ
  ```
- **Checks,** from `city/`, after every task:
  - `cargo fmt --all --check`
  - `cargo clippy --workspace --all-targets -- -D warnings`
  - `cargo test --workspace`
  - `cargo build -p city-core --target wasm32-unknown-unknown`
  - `python3 fixtures/district/generate.py --check`
  - the kit tests: `for t in tools/styles/*/test_*.py; do python3 -m unittest "$t"; done`
  - after Rust changes, `scripts/build-godot.sh`, then the Godot suite from `city/godot`: `godot --headless --path . --script res://tests/run_all.gd`. Its baseline is 604/604.

  All of these stay green, and the collision audit stays at 0 in all six styles.
- **Determinism** (README "Determinism"):
  - no floats in the rules;
  - ordered stores;
  - no new RNG draws;
  - `Use` is applied at Ingest in command order and replays byte-identically.
- **Values** from spec §2, verbatim:
  - first-person reach **3 m**;
  - overhead and pixel-art reach **1.5 m** within **60°** of facing;
  - near level of detail **within 8 m**;
  - soft contacts computed only for people within **15 m** of the camera;
  - sway springs back within **1 s**;
  - sway costs **≤ 0.3 ms** a frame on the bench scene;
  - pixel art rustles over **three frames**.
- **Anchor capacity:** `sit` and `use` anchors hold one person. `stand` anchors hold one each, and their neighbours take the overflow.
- **Perches** (`steps`, `low-wall`, `fountain-rim`):
  - open to anyone;
  - do not count against room capacity;
  - agents never pick them (the seat policy chooses only seats).
- **Sample panel content** is marked "Sample" in every view, and panels are keyed by placement ID.
- **Tests never write** the real `user://settings.cfg`. Live infrastructure is never touched.
- **Code voice:**
  - plain-sentence doc comments;
  - tabs in GDScript, rustfmt in Rust;
  - names spelled out;
  - comments say why.

## Review Focus

1. **A player uses something while someone else takes its anchor in the same tick.** Exactly one wins, deterministically, and the other gets a clear refusal notice. Task 2 tests this.
2. **A seated or reading player is pushed, disconnects, or boards a tram.** `using` is released and no anchor stays held. Task 2 tests this.
3. **Targeting in a crowded plaza,** with several anchors within reach. The prompt names the one the reticle or crosshair shows, and cycling never picks an anchor out of reach. Task 4 tests this.
4. **Opening a noticeboard's overlay, then leaving it with B or Esc while a tram arrives.** Focus returns to the world, and the tram prompt shows. Task 5 tests this.
5. **Swaying plants at night and in rain, with 60 people crossing the park.** They stay within budget and never pop. Task 8 tests this.

---

### Task 1: Contracts: Use, using, and panels

**Files:**
- `city/crates/city-contracts/src/{feed,event,projection,lib}.rs`
- a new `city/crates/city-contracts/src/panel.rs`
- `tests/contracts.rs`
- compile fixes in city-core, city-cli, city-mcp and city-godot

**Interfaces:**
- **Commands:**
  - `Command::Use { occupant: CityId, target: PlaceId, capability: String, anchor: u32 }`
  - `Command::StopUsing { occupant: CityId }`
  - their `CommandType`s
  - `target` is a placement ID or a seat ID; a seat is its furniture's instance.
- **Projection:** `OccupantView.using: Option<Using { target: PlaceId, capability: String, anchor: u32 }>`, skipped when `None`.
- **Events:** `EventKind::Using { target, capability, anchor }` and `EventKind::StoppedUsing { target }`.
- **Refusals:** `RejectReason::{UnknownTarget, NoSuchCapability, AnchorTaken, NotAtAnchor}`.
- **Panels:** `panel.rs` defines the `sample` panel format as a tagged enum, `Panel::{Notices { title, items: Vec<Notice { date, headline, body }> }, Shelf { title, spines: Vec<Spine { title, subtitle }> }, Plaque { title, text }}`, and each carries `sample: bool`.

- [ ] **Step 1: Write the failing contract tests.** Cover round trips for every new type, `using` skipped when `None`, the schema containing `"Use"`, `"using"` and `"Panel"`, and the old commands unchanged.
- [ ] **Step 2: Watch them fail, then implement.** Placeholders in city-core refuse `Use` with `NoSuchCapability` until Task 2.
- [ ] **Step 3: Run all checks.**
- [ ] **Step 4: Commit:** `feat(city): contracts for using things`.

---

### Task 2: The core's Use rules

**Files:**
- a new `city/crates/city-core/src/interact.rs`
- `world.rs` (Ingest dispatch; release hooks in `stand_up`, moves, Go, leave and board)
- `project.rs`, `invariants.rs`, `lib.rs`
- tests: unit tests in `interact.rs`, and `tests/walking.rs` or a new `tests/interact.rs`

**Interfaces:**
- **`interact::apply(world, occupant, target, capability, anchor) -> Result<Vec<EventKind>, RejectReason>`** checks, in this order:
  1. **The target resolves** to a placement or seat and its catalogue kind.
  2. **The kind offers the capability** at that anchor's type.
  3. **The occupant is at the anchor:**
     - for `sit`, on the anchor's cell;
     - for `read` and `use`, on the anchor cell or a walkable neighbour facing it;
     - for `stand`, on the anchor cell.
  4. **The anchor is free,** within its capacity.
  5. **The capability's own rule allows it:**
     - `sit` on a room seat calls the existing `take_seat` (reservations, pods and capacity unchanged);
     - `sit` on a perch just sets `using` and pose, with no room capacity;
     - `read` sets `using`;
     - `board` calls `transit::board`;
     - `enter` calls the existing Go Room admission.
- **Releasing `using`** happens on:
  - any Move, Steer or Go;
  - `StopUsing`;
  - Depart or leave;
  - boarding;
  - disconnect.

  A seat's existing `SeatReleased` still fires. `StoppedUsing` fires for every release.
- **Seats:** a seated occupant's projection carries `using { target: seat, capability: "sit", anchor }`. Agents seated by the policy show it too. Their events are unchanged.
- **Invariants:**
  - an anchor never holds more than its capacity;
  - `using` always names a target whose anchor cell (or a facing neighbour, for read and use) the occupant stands on;
  - no occupant is both `using` and aboard.

- [ ] **Step 1: Write the failing tests.**
  - Sit on a perch; a second person is refused `AnchorTaken`.
  - Sit on a room seat through Use; the reservation is refused as today.
  - Read a noticeboard from a facing neighbour; refused from two cells away.
  - Board and enter through Use, with the same events as Board and Go Room.
  - Every release path clears `using` and the anchor.
  - Two Uses of one anchor in one tick: the first in command order wins.
  - A replay with Use commands is byte-identical.
  - The district replay with no players is unchanged, because agents never Use.
- [ ] **Step 2: Watch them fail, then implement.**
- [ ] **Step 3: Run the checks,** including both scenario gates.
- [ ] **Step 4: Commit:** `feat(city): one Use for sitting, reading, boarding and going in`.

---

### Task 3: New kinds, the fixture, and sample panels

**Files:**
- `city/catalogue/catalogue.json`
- `city/fixtures/district/generate.py`, `manifest.json` (regenerated), and a new `fixtures/district/panels/*.json`
- `city/crates/city-godot/src/bridge.rs` (`panel_json(target)`)
- the fixture test

**Interfaces:**
- **New kinds,** each with `name`, `description`, footprint, anchors and capabilities, where the capability names the anchor type it happens at:

  | Kind | Anchors and capabilities | Other |
  | --- | --- | --- |
  | `noticeboard` | a `display` anchor and a `stand` anchor in front; `read` and `inspect` | |
  | `plaque` | `display` and `stand`; `read` and `inspect` | |
  | `kiosk` | `display` and `stand`; `read` (Browse) and `inspect` | |
  | `steps` | two to four `sit` anchors along the top step; `sit` and `inspect` | a perch |
  | `low-wall` | `sit` anchors every 60 cm; `sit` and `inspect` | a perch, sized |
  | `fountain-rim` | a basin with `sit` anchors round the rim at even angles; `sit` and `inspect` | a perch |
  | `meadow` | empty footprint; `inspect` | sized, with `soft` shapes filling its size (tall grass and flowers) |

- **Kinds that gain capabilities:**
  - `bookshelf` gains `display` and `stand` anchors in front, and `read`;
  - every existing kind gains `inspect`, at the anchor type `stand` or none.

  The catalogue contract allows `inspect` with no anchor. Update the validation rule accordingly.
- **The generator places:**
  - the Square noticeboard, bound to `panels/square-notices.json` (dated notices for v0.0.1–v0.0.3, marked Sample);
  - a plaque at the guild hall;
  - a kiosk in the library;
  - the reading-room bookshelves bound to `panels/library-shelves.json` (spines titled from the vision documents);
  - steps at the library garden;
  - two low walls in the park;
  - one fountain on the Square;
  - three meadow patches on the park's lawns.

  Every anchor must be reachable, no route may be cut, and `city-cli validate` must be clean.
- **Bridge:** `CityWorld.panel_json(target: String) -> String` returns the bound panel for a placement or seat with `binding.source == "sample"`, read from the fixture's `panels/` folder next to the manifest. It returns an error JSON for any other source.

- [ ] **Step 1: Write the failing tests.**
  - Fixture per-kind counts.
  - Every new anchor reachable.
  - `panel_json` returns the Square's notices and refuses an unbound or non-sample target.
  - Catalogue contract tests for the new kinds.
- [ ] **Step 2: Implement it and regenerate the fixture.** Run the Rust checks and gates.
- [ ] **Step 3: Draw the new kinds as placeholders in every style,** so the suite stays green; real art comes in Tasks 6 and 7. Run the Godot suite and the collision audit. Placeholders must fit their footprints, so the audit stays at 0.
- [ ] **Step 4: Commit:** `feat(city): noticeboards, plaques, kiosks, perches and meadows`.

---

### Task 4: The client's one interaction path

**Files:**
- a new `city/godot/core/interact.gd`
- `main.gd` (remove `_caption` per-kind cases; route act and alt through `Interact`)
- `core/player.gd` (`target_seat` generalised to anchors)
- `core/fpv_camera.gd` (aim at anchors)
- `core/input_router.gd` and `project.godot` (a new `interact_alt` action: E on keyboard, Y on controller, with a glyph in `InputGlyphs`)
- `core/ui/play_hud.gd` (prompt shows the verb and the "E/Y: more" hint)
- tests: a new `tests/test_interact.gd`, plus adapted `test_first_person.gd` and `test_player.gd`

**Interfaces:**
- **`Interact.targets(view_state) -> Array`** returns candidate anchors in reach:
  - first person: under the crosshair, within 3 m;
  - overhead and pixel art: the nearest within 1.5 m and 60° of facing;
  - touch: tapping a placement targets it.

  Each candidate is `{target, kind, anchor, capabilities: Array[String], pos}`. Buildings (enter), ground (Walk here, not a capability) and the tram (board) take part as targets of the same shape.
- **`Interact.verbs(target) -> Array[String]`** gives the capability verbs, with `inspect` always last. The verbs are: Sit, Read, Browse, Board, Go in, Inspect, Stand up, Stop reading.
- **Acting:**
  - `act` performs the first verb;
  - `interact_alt` cycles the verb shown;
  - out of reach, act sends Go to the anchor cell, then Use on arrival;
  - `inspect` and `read` open the overlay from Task 5.
- **The existing behaviours keep their tests,** now through this path:
  - the seat reticle;
  - "Go in · Full";
  - the faced door;
  - "Walk here" inside;
  - boarding;
  - the tram prompt precedence.

- [ ] **Step 1: Write the failing tests.**
  - Targeting in each view (first person, overhead, pixel art, touch), including the crowded-plaza Review Focus 3 case.
  - The verb order and cycling.
  - Go-then-Use.
  - Every existing first-person, seat and tram prompt test still passes, unchanged in intent.
- [ ] **Step 2: Implement it.** Delete the per-kind cases in `main.gd` and record the lines removed in the report.
- [ ] **Step 3: Run the Godot suite.**
- [ ] **Step 4: Commit:** `feat(city): one way to use anything`.

---

### Task 5: Inspect and read: the overlay and the surfaces

**Files:**
- a new `city/godot/core/ui/panel_screen.gd`, a Screen skinned by `UiTheme`
- `main.gd` (open it)
- each style's `style.json`: a new `surfaces` block (`far`: icon key; `near`: text colour, font scale and max lines; `open`: overlay)
- `styles/style_pack.gd` (`REQUIRED` gains `surfaces`), `styles/pack_3d.gd`, `styles/pixel_art/pack.gd`
- the map's List tab (read and inspect entries appear as text)
- tests: a new `tests/test_panels.gd`, plus `test_pack_contract.gd`

**Interfaces:**
- **`PanelScreen.open(target, panel: Dictionary, kind: Dictionary)`:**
  - inspect shows the kind's name, description and capabilities, and the source when bound;
  - read renders `Notices`, `Shelf` or `Plaque`;
  - "Sample" shows on every view;
  - it is scrollable and navigable by controller.
- **Surfaces:** each display placement draws three levels:
  - **far:** the icon or chip;
  - **within 8 m:** headlines, the first three items;
  - **open:** the overlay.

  3D styles draw with a `Label3D` or text texture on the display anchor. Pixel art uses its whole-number-scale pixel font for near text, falling back to the overlay face.
- **The occupant's `using`** shows on their name tag as "reading", "sitting" and so on.

- [ ] **Step 1: Write the failing tests.**
  - Overlay content for each panel type.
  - The Sample label.
  - Leaving with B or Esc returns focus to the world while a tram arrives (Review Focus 4).
  - The surface level of detail at 20 m, 6 m and open.
  - Every style declares `surfaces`.
- [ ] **Step 2: Implement it.**
- [ ] **Step 3: Run the Godot suite and the collision audit.**
- [ ] **Step 4: Commit:** `feat(city): read what the city shows, and inspect anything`.

---

### Task 6: The new kinds drawn in the 3D styles

**Files:**
- the kit builders under `city/tools/styles/{lowpoly,anime,solarpunk,neon,voxel}/` (props and scenery modules, plus specs)
- the regenerated GLBs
- each style's `style.json` `props` entries
- evidence images

**Interfaces:**
- **Each style draws** the noticeboard, plaque, kiosk, steps, low wall, fountain (with its rim) and meadow in its own idiom, inside each kind's footprint in the walking band. Displays expose a `display` node where the surface text mounts.
- **Meadow** is drawn as tall grass and flowers built for sway (Task 8): vertex colour or UV2 marks the bend weight at the tips.

- [ ] **Step 1: Build the kits.** The kit tests must pass, including the Khronos validator where CI runs it.
- [ ] **Step 2: Map every kind** in each style, replacing Task 3's placeholders.
- [ ] **Step 3: Check the audit and the suite.** The collision audit stays at 0 in every 3D style, and the Godot suite passes.
- [ ] **Step 4: Capture evidence** into `city/godot/evidence/interact-<style>-*.png`: sitting on each kind of seat and perch, and a noticeboard far, near and open. Look at the images and describe them in the report.
- [ ] **Step 5: Commit:** `feat(city): the 3D styles draw the new things to use`.

---

### Task 7: The new kinds drawn in pixel art

**Files:** `city/tools/styles/pixel/` (models and build), the regenerated sprites, `styles/pixel_art/style.json`, `solids_2d.gd` (`FOOT` entries for the new kinds), and the evidence.

**Interfaces:**
- **The same kinds** as Task 6, drawn as sprites rendered from their models.
- **Meadow** gets three rustle frames per variant.
- **`solids_2d.gd`** reads each new sprite's ground footprint, so the audit stays honest.

- [ ] **Step 1: Build the sprites.** The kit tests must pass, including byte reproducibility.
- [ ] **Step 2: Map every kind.** The collision audit stays at 0 for pixel art, and the suite passes.
- [ ] **Step 3: Capture evidence.**
- [ ] **Step 4: Commit:** `feat(city): pixel art draws the new things to use`.

---

### Task 8: Plants that sway

**Files:**
- a new `city/godot/core/soft_contacts.gd`
- `styles/kit_town.gd` (MultiMesh `use_custom_data` for soft kinds)
- a sway shader shared by the 3D styles (`styles/shaders/sway.gdshader`, with a per-style tint and stiffness set through the style's `sway` block)
- `styles/pixel_art/pack.gd` (the rustle)
- tests: a new `tests/test_sway.gd`, plus `test_frame_cost.gd`

**Interfaces:**
- **`SoftContacts`:**
  - builds a per-district spatial hash of soft shapes from placements and the catalogue;
  - each frame, for people within 15 m of the camera, finds the soft instances their body circle overlaps;
  - writes a bend impulse (direction and strength) into each instance's custom data;
  - the impulse springs back within 1 s.
- **The shader** bends vertices by that data, weighted by height.
- **Pixel art** plays the three-frame rustle on contact.
- **Performance:** there is no per-frame allocation, and nothing is computed beyond 15 m.

- [ ] **Step 1: Write the failing tests.**
  - A scripted walker through a meadow bends the instances it passes, and they settle within 1 s.
  - Instances beyond 15 m are untouched.
  - A frame-cost test with 60 walkers crossing the park stays within 0.3 ms of CPU a frame (Review Focus 5).
  - Pixel art rustles and returns.
- [ ] **Step 2: Implement it.**
- [ ] **Step 3: Run the suite.** Capture before-and-after evidence of grass parting per style.
- [ ] **Step 4: Commit:** `feat(city): grass and flowers part as people pass`.

---

### Task 9: Evidence, docs and amendments

**Files:**
- `city/README.md` (interactions: controls, capabilities, panels, sway)
- the spec (a dated §10 Amendments section, recording the ledger's rulings)
- a new `city/godot/evidence/interact-notes.md`

- [ ] **Step 1: Run every check,** including the collision audit and the door-entry test.
- [ ] **Step 2: Write the notes, the README section and the amendments.**
- [ ] **Step 3: Commit:** `docs(city): interactions evidence and notes`.
