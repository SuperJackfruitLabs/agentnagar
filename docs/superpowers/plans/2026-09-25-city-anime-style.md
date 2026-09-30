# Cel-shaded Anime Style Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** add a fourth style pack, Cel-shaded anime (study 06), that matches its concept sheets and holds 360 fps in normal play at 1920 × 1080. Deterministic rain is added to the world for every style.

**Architecture:**
- The core gains a presentation-only weather schedule, projected as a rain percentage.
- The client eases it and hands it to packs.
- The anime pack is a `Pack3D` with its own `KitTown` townscape, and a kit built by a new Blender generator that reuses the low-poly rig and animations.
- Toon materials use Godot's native toon modes, applied through one new `Pack3D` hook.
- Character outlines are inverted hulls; the city's lines are one screen-space pass.
- A benchmark tool gates frame time.

**Tech stack:**
- Rust (`city-core`, `city-contracts`);
- Godot 4.6 GDScript, Forward+;
- Blender 5.2 Python for the kit;
- Python 3 with Pillow for the face art.

**Spec:** `docs/superpowers/specs/2026-09-25-city-anime-style-design.md`

## Global Constraints

- Core is deterministic: integer maths, no floats, no `HashMap`, no clock.
- Weather is presentation-only. No rule reads it, and the invariants are unchanged.
- Performance at 1920 × 1080, measured uncapped as p99 over 5 s:
  - normal play (three presets and first person, crowd of 60): ≤ 2.78 ms;
  - heaviest scene (street, night, rain, crowd of 300): ≤ 4.17 ms.
- A person looks the same in every style: outfit k, hair h, and the shared colour lists (`test_looks.gd`).
- City Agent A1:
  - navy hair tied up with loose strands;
  - blue eyes;
  - a white jacket over a blue shirt, and the leaf badge.
- Palette: warm whites, blues, indigo and vermilion. Shadows are cool indigo; ink is never pure black.
- Every kit asset is built by the generator, with a spec entry. `test_assets.py` runs in `check.sh`.
- No temporal AA. 4× MSAA, or SMAA if MSAA breaks the line pass.

## Review Focus

1. **Style switching.** Switching into and out of the anime style mid-session with rain falling: rain state, outlines and LOD must carry over with no stale nodes.
2. **Night glow.** Night glow must still reach glass and lamp materials after toon conversion, in every building.
3. **First-person close-ups.** Outline width and face readability of A1 at 1–2 m, with no hull artefacts on the face.
4. **Crowd of 300.** Staggered animation must not freeze visible near characters or pop them.
5. **Rain across midnight.** A spell crossing midnight, rain at tick 0, and a leap in time (restart) must never flash from full rain to none.

---

### Task 1: Weather in the world

**Files:**
- Modify:
  - `city/crates/city-contracts/src/manifest.rs` (`Weather`, `RainSpell`, a `Manifest.weather` field);
  - `city/crates/city-contracts/src/projection.rs` (`rain: Option<u8>`);
  - `city/crates/city-core/src/project.rs` (`rain_at`, projection);
  - `city/crates/city-core/src/index.rs` (validation);
  - `city/fixtures/district/generate.py` (an evening spell);
  - `godot/core/scene_model.gd` (a `rain` change);
  - `godot/core/style_host.gd` (ease, `set_rain`);
  - `godot/styles/style_pack.gd` (a `set_rain` no-op);
  - `godot/styles/pack_3d.gd` (shared 3D rain);
  - `godot/styles/pixel_art/pack.gd` (2D rain).
- Test:
  - `crates/city-core/src/project.rs` (unit tests);
  - `crates/city-core/src/index.rs` (validation tests);
  - `godot/tests/test_weather.gd`.

**Interfaces:**
- Produces:
  - `city_core::project::rain_at(clock: Clock, weather: &Weather, tick: Tick) -> u8`;
  - `Projection.rain: Option<u8>`;
  - `StylePack.set_rain(amount: float)`, with amount between 0 and 1;
  - `StyleHost.rain: float` (the eased value).

- [ ] **Step 1: Write the failing core tests.**

```rust
#[test]
fn rain_ramps_in_and_out_over_twenty_minutes_and_crosses_midnight() {
    let clock = Clock { ticks_per_day: 1440, start_minute: 0 };
    let w = Weather { rain: vec![RainSpell { from: 1380, to: 60, peak: 80 }] };
    assert_eq!(rain_at(clock, &w, 1370), 0);
    assert_eq!(rain_at(clock, &w, 1390), 40);
    assert_eq!(rain_at(clock, &w, 1400), 80);
    assert_eq!(rain_at(clock, &w, 10), 80);
    assert_eq!(rain_at(clock, &w, 50), 40);
    assert_eq!(rain_at(clock, &w, 60), 0);
}
```

Plus validation tests:
- `bad-weather` when `from == to`;
- `bad-weather` when `peak` is 0 or over 100;
- `bad-weather` when weather is present with no clock.

- [ ] **Step 2:** run `cargo test -p city-core rain`. Expected: it fails to compile, because `rain_at` and `Weather` are missing.
- [ ] **Step 3: Implement.**
  - The intensity is the peak times the ramp: `min(minutes since from, minutes until to, 20) / 20`, in integer maths.
  - Spells overlap by taking the maximum.
  - The projection sets `rain` when both a clock and weather are present.
- [ ] **Step 4:** run `cargo test -p city-core`. Expected: pass.
- [ ] **Step 5: Fixture.** Add `"weather": {"rain": [{"from": 1140, "to": 1290, "peak": 80}]}` to `generate.py`, regenerate, then run `cargo test --workspace`. Expected: pass.
- [ ] **Step 6: Write the failing Godot test** in `test_weather.gd`. It asserts:
  - a projection with `rain: 60` makes `SceneModel.apply` emit `{"type": "rain", "percent": 60}`;
  - `StyleHost` eases toward 0.6 over frames, and never jumps more than 0.05 in a 1/60 s frame;
  - every discovered pack accepts `set_rain(0.8)` and shows something: 3D packs a visible "Rain" node, pixel art a visible rain overlay.
- [ ] **Step 7:** run the suite. Expected: fail.
- [ ] **Step 8: Implement.**
  - `SceneModel` emits `rain` changes.
  - `StyleHost` keeps `_rain_target` and eases `rain` by 0.5 per second, clamped. `tick_frame` calls `pack.set_rain(rain)`; `activate` re-applies it.
  - `Pack3D.set_rain` drives a `GPUParticles3D` "Rain" that follows the camera: streaks with an amount proportional to the rain, and a greyer sky blended by the amount.
  - The pixel pack draws a `CanvasLayer` "Rain" of drifting streaks and darkens by up to 25%.
- [ ] **Step 9:** run the suite. Expected: pass.
- [ ] **Step 10: Commit** `feat(city): deterministic rain in the world, drawn by every style`.

### Task 2: The frame-time benchmark and gate

**Files:**
- Create: `godot/tools/bench.gd`, `scripts/bench.sh`.
- Modify: `scripts/check.sh` (run the bench when a display is present), `godot/core/args.gd` (`--bench-out=`).
- Test: `godot/tests/test_bench.gd` (the scene list, the p99 maths and budget parsing, with no GPU).

**Interfaces:**
- Produces `bench.gd` scenes, each `{style, name, preset | "fpv", crowd, minutes, rain}`, and `bench.json`, which records `[{style, scene, p50, p99, max, frames}]` per scene.
- `style.json` may declare `"budget": {"normal_ms": 2.78, "heavy_ms": 4.17}`; a style without one is reported but not gated.

- [ ] **Step 1: Failing test.** `Bench.p99([...])` returns the nearest-rank 99th percentile, and `Bench.check(results, budgets)` returns the breaches.
- [ ] **Step 2:** run it. Expected: fail.
- [ ] **Step 3: Implement.**
  - `bench.gd` boots with `--fps=1000`, V-Sync off, 1920 × 1080, and a crowd of 60 or 300.
  - For each style and scene: 60 warm-up frames, then 5 s of samples.
  - It writes JSON under `$HOME/.cache/agentnagar-bench/`.
- [ ] **Step 4:** `bench.sh` runs it windowed (`godot --path godot --resolution 1920x1080 --script res://tools/bench.gd`) and exits non-zero on a breach. `check.sh` runs it if `$WAYLAND_DISPLAY` or `$DISPLAY` is set, and prints a skip note otherwise.
- [ ] **Step 5:** run the tests and `scripts/bench.sh`, and record the existing styles' baseline numbers in the ledger.
- [ ] **Step 6: Commit** `feat(city-godot): frame-time benchmark and budget gate`.

### Task 3: The rendering foundation (spike first)

**Files:**
- Create:
  - `godot/styles/anime_cel/toon.gd` (`class_name Toon`);
  - `godot/styles/anime_cel/shaders/outline.gdshader`;
  - `godot/styles/anime_cel/shaders/lines.gdshader`;
  - `godot/styles/anime_cel/shaders/face.gdshader`.
- Modify: `godot/styles/pack_3d.gd` (the `_style_node` hook and its call sites), `godot/core/orbit_rig.gd` (an optional line-pass quad).
- Test: `godot/tests/test_toon.gd`.

**Interfaces:**
- Produces:
  - `Toon.apply(node: Node, palette: Dictionary)`, which converts every `BaseMaterial3D` in place, once;
  - `Toon.outline(mi: MeshInstance3D, ink: Color, width_px: float)`;
  - `Toon.line_pass(camera: Camera3D) -> MeshInstance3D`;
  - `Pack3D._style_node(node: Node)` (virtual).

- [ ] **Step 1: Spike.** In a throwaway scene, check a box, a sphere and a thin post under 4× MSAA through the lines shader. Capture it and check that lines appear on silhouettes and creases with no MSAA artefacts. If MSAA breaks `hint_normal_roughness_texture`, switch to SMAA. Ledger the ruling.
- [ ] **Step 2: Failing tests.**
  - `Toon.apply` sets `DIFFUSE_TOON`, `SPECULAR_TOON` and rim on every `BaseMaterial3D` in a nested tree: surface materials, `material_override`, MultiMesh meshes.
  - It is idempotent: a second call changes nothing.
  - Glass materials registered with `KitTown` keep their identity, so night emission still reaches them.
  - `Toon.outline` adds a `next_pass` with front culling and the ink colour.
- [ ] **Step 3:** run them. Expected: fail.
- [ ] **Step 4: Implement** `Toon` and the shaders.
  - The outline shader grows along normals by `width_px` at the camera's projection scale, clamped between 0.004 and 0.03 m.
  - The lines shader uses a depth Laplacian plus a normal difference, with distance fade from 60 m to 140 m.
- [ ] **Step 5:** add the `_style_node` hook at build and paint sites, a no-op in `Pack3D`.
- [ ] **Step 6:** run the suite. Expected: pass.
- [ ] **Step 7: Commit.**

### Task 4: The anime kit generator: city pieces

**Files:**
- Create `city/tools/styles/anime/`:
  - `build.py`;
  - `lib.py` (importing the low-poly `lib.Mesh` helpers);
  - `palette.py`;
  - `buildings.py`, `scenery.py`, `props.py`, `interiors.py`;
  - `specs/*.json`;
  - `test_assets.py`;
  - `render_preview.py`;
  - `validate.sh`.
- Output: `godot/styles/anime_cel/assets/`.

**Interfaces:**
- Produces GLBs, each with a named `body` node plus the named glow nodes (`glass*`, `lamp_glow`):
  - building modules: `hall_bay`, `hall_door_bay`, `hall_corner`, `hall_roof_bay`, `lib_bay`, `lib_entrance`, `lib_vault`, `lib_end`;
  - `tower_a` and `tower_b`, with roof gardens; `house_a` to `house_c`; `shop_a`, with a shopfront and balconies;
  - streets and water: `road_tile`, `kerb`, `paving_tile`, `bridge_span`, `bridge_pier`, `water_tile`;
  - transit and railings: `tram`, `tram_shelter`, `railing`, `railing_post`;
  - trees: `tree_great`, `tree_round_a` and `tree_round_b`, `palm_a` and `palm_b`, `shrub`;
  - props: `lamp_post`, `bench`, `umbrella`, `bollard`, `planter`;
  - interiors: `workbench`, `pegboard`, `pendant_lamp`, `bookshelf`, `reading_table`, and seats `desk`, `bench`, `cafe-table`, `reading-chair`.

- [ ] **Step 1: Failing tests.** `test_assets.py`:
  - every spec'd asset exists and meets its size (±10%) and triangle budget;
  - every GLB passes the Khronos validator;
  - every `style.json` reference exists;
  - building a named asset twice gives identical bytes.
- [ ] **Step 2:** run it. Expected: fail, because nothing has been built.
- [ ] **Step 3: Build.** Build the pieces family by family, rendering previews after each (`render_preview.py`) and comparing them against the sheet crops. Faithful features:
  - red-brick sawtooth bays with tall dark mullioned windows and steel glazing strips;
  - a silver standing-seam barrel vault over a two-storey arcade of warm glass;
  - pale glass towers stepping back with planted terraces;
  - warm cream and terracotta houses with balconies;
  - a pale grey stone three-arch bridge;
  - a cream tram with a coral stripe;
  - clumped broadleaf canopies in two greens.
- [ ] **Step 4:** run `python3 -m unittest tools/styles/anime/test_assets.py`. Expected: pass.
- [ ] **Step 5: Commit** in family-sized commits.

### Task 5: The anime kit generator: characters

**Files:**
- Create `city/tools/styles/anime/characters.py` and `faces.py`.
- Modify the specs and `test_assets.py` (the character checks mirror the low-poly character checks).

**Interfaces:**
- **Consumes** from the low-poly `characters.py`: `build_rig`, `bind`, the pose functions and the action baking, imported by path.
- **Produces:**
  - `character_anime.glb`: one armature and the parts `skin`, `top`, `jacket`, `bottom`, `shoes`, `hair_0` to `hair_3`, `backpack`, `umbrella` and `face`, with a UV rectangle on the face atlas, plus the actions `walk`, `idle`, `sit`, `typing`;
  - `character_anime_far.glb`: the same rig with one merged low-poly body;
  - `agent_anime.glb`: the uniform (`jacket` white, `top` blue), the `badge` and four agent hairstyles;
  - `a1_anime.glb`: A1;
  - `face_atlas.png`: 5 expressions × 4 face variants, 256 px cells.

- [ ] **Step 1: Failing tests.**
  - The character GLBs have the named parts and actions.
  - The walk loops seamlessly, and the feet stay on the floor while seated, as in the low-poly checks.
  - The face atlas has 20 cells of the expected size, and is deterministic.
- [ ] **Step 2:** run them. Expected: fail.
- [ ] **Step 3: Implement.**
  - **Proportions:** about 6.5 heads tall on the shared skeleton, a slimmer torso, smooth shading.
  - **Clothes:** loft layers offset from the body rings.
  - **Hair:** swept tapered locks along bezier paths:
    - 0: short and tousled;
    - 1: a long ponytail;
    - 2: a tied-up bun with loose strands, A1's family;
    - 3: a bob.
  - **Faces:** drawn at 1024 px with Pillow polygons and ellipses (eyes with iris gradient bands and highlights, brows, mouth shapes, blush), then downsampled with LANCZOS to 256 px.
  - **Previews:** render close-ups at 1 m and 3 m, and iterate until faces read as the sheets' characters.
- [ ] **Step 4:** run the tests. Expected: pass.
- [ ] **Step 5: Commit.**

### Task 6: The anime pack

**Files:**
- Create `godot/styles/anime_cel/`: `pack.gd`, `townscape.gd`, `style.json`.
- Modify `godot/tests/test_pack_contract.gd` only if the contract needs anime-specific assertions.
- Test: `godot/tests/test_anime_pack.gd`.

**Interfaces:**
- **Consumes:** Task 3's `Toon`, Tasks 4 and 5's kit, and Task 1's `set_rain`.
- **Produces:** the pack, discovered in `order` 4.

- [ ] **Step 1: Failing tests.** `test_anime_pack.gd`:
  - the pack builds and honours the contract (discovery runs the contract suite on it);
  - every material is toon;
  - characters have outline passes;
  - faces use the atlas shader with an instance expression;
  - A1 maps `by_id` to `a1_anime.glb`;
  - the far crowd switches to the far mesh beyond 45 m;
  - night lights the glass;
  - `set_rain(0.8)` shows streaks, wet ground and umbrellas outdoors, but not indoors.
- [ ] **Step 2:** run them. Expected: fail.
- [ ] **Step 3: Implement.**
  - The pack overrides `_make_town`, `_style_node` (`Toon.apply`), `make_occupant` (the face instance, outlines, LOD, umbrella), `set_rain` (streaks, a wet ground material, reflection streak sprites under lamps and windows), environment keys (indigo ambient, bright sky), toon water and a player marker.
  - The townscape assembles buildings and scenery from the kit.
- [ ] **Step 4:** run the suite. Expected: pass.
- [ ] **Step 5: Commit.**

### Task 7: Sheet evidence and visual iteration

**Files:**
- Create: `godot/tools/sheet_compare.py`, which composes captures beside sheet panel crops.
- Modify: `godot/tools/audit.gd`, which adds rain scenes for every style.
- Produce: `godot/evidence/anime-*.png`, `anime-vs-sheet.png`, `anime-notes.md`.

- [ ] **Step 1:** capture the eight views.
- [ ] **Step 2:** compose them beside the sheets and inspect every panel.
- [ ] **Step 3:** for each gap, fix it test-first where it's a behaviour (a missing prop or a wrong mapping), or regenerate the asset where it's art. Repeat until the remaining gaps are only ones the notes can honestly call minor.
- [ ] **Step 4: Commit.**

### Task 8: Performance to budget

- [ ] **Step 1:** run `scripts/bench.sh`, and record every scene's p99 against its budget.
- [ ] **Step 2:** for each breach, profile (the visual profiler monitors, draw calls, primitives) and apply the spec's measures (MultiMesh batching, merged bays, LOD, staggered animation, shadow-less lamps) until every scene meets its budget. Fix shared `Pack3D` wins for all styles.
- [ ] **Step 3:** run `check.sh`, which includes the bench, and commit.
