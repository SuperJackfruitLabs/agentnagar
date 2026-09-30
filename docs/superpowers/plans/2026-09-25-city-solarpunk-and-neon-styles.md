# Solarpunk and Neon Noir Styles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** add two style packs, Solarpunk retro-futurism (study 09) and Neon noir (study 10). Each matches its concept sheets and meets the frame budget at 1920 × 1080.

**Architecture:**
- Both follow the anime style's pattern: a `Pack3D` subclass with its own `KitTown` townscape, and a Blender kit generator.
- They share two new character pieces, built once and parameterised per style:
  - a semi-realistic face path (the anime body and rig, with an illustrated face atlas);
  - a robot agent (a shell-and-visor builder with an emissive eye atlas).
- Neither is toon. Solarpunk is lit warm and physically based; neon noir is night-first, with many cheap lights and reflective wet ground.

**Tech stack:** Godot 4.6 GDScript, Forward+; Blender 5.2 Python; Python 3 with Pillow.

**Specs:**
- `docs/superpowers/specs/2026-09-25-city-solarpunk-style-design.md`
- `docs/superpowers/specs/2026-09-25-city-neon-noir-style-design.md`

## Global Constraints

- The same budget as the anime style, declared in each `style.json`: 360 fps in normal play and a 240 fps floor in the heaviest scene, with vsync at the display's rate (amended 2026-09-25 from uncapped p99 ≤ 2.78 ms / 4.17 ms; see the anime spec).
- A person looks the same in every style: outfit k, hair h, the shared colour lists.
- Agents are robots in both styles, per the comparison contract. City Agent A1 is `city:librarian`.
- Every kit asset is generator-built and specified. Kit tests run in `check.sh`.
- Neon noir needs a deliberate daytime look: neon off, a cool clean city.

## Review Focus

1. Switching between a toon style (anime) and a lit style (solarpunk or neon): environment, MSAA and material state must never leak.
2. Neon noir at noon: it must not read as a broken night scene.
3. Robot agents' emissive eyes at night versus by day: readable, not blown out.
4. The wet ground's screen-space reflections, or their fallback, in the heaviest scene within budget.
5. Solarpunk's SSIL cost: measured and kept or dropped within budget, with the choice ledgered.

---

### Task 1: Shared character pieces

**Files:**
- Create:
  - `city/tools/styles/shared/faces_real.py`: the illustrated face atlas, with parameters per style;
  - `city/tools/styles/shared/robots.py`: the robot agent builder on the shared rig, with an eye atlas drawer.

**Interfaces:**
- **Produces:**
  - `robots.build_robot(arm, look)`, where `look` is a dict of shell colour, trim colour, visor colour, eye colour, and which accessories to add (`scarf`, `hoodie`, `card`), with parts `shell`, `trim`, `visor`, `eyes`, `scarf`, `hoodie` and `badge`;
  - `faces_real.atlas(style)`, which returns a PIL image, 5 expressions × 4 faces.
- **Consumes:** the low-poly rig (`build_rig`, `Body`, `add_actions`) and the anime body builder (`build_anime`), both imported by path.

- [ ] **Step 1: Failing tests** in each kit's `test_assets.py`:
  - the robot GLB's named parts and its four actions;
  - the eye and face atlases' layout;
  - reproducible drawing.
- [ ] **Step 2: Implement.** Preview close-ups with `asset_preview.gd` (`--focus head`) and iterate against the conversation panels.
- [ ] **Step 3: Commit.**

### Task 2: The solarpunk kit

**Files:**
- Create `city/tools/styles/solarpunk/`: build, lib, palette, buildings, scenery, vegetation, props, characters, specs, `test_assets.py`, `ART.md`.
- Output: `godot/styles/solarpunk/assets/`.

The module names and conventions match the other kits. The library gets a `lib_drum_roof`: a glass-and-solar dome over a planted rim.

- [ ] **Step 1: Failing tests:** specs, validator, reproducibility.
- [ ] **Step 2: Build** family by family with previews. `asset_preview.gd` renders without toon when a style's `style.json` sets `"shading": "lit"`.
- [ ] **Step 3: Commit.**

### Task 3: The solarpunk pack

**Files:**
- Create `godot/styles/solarpunk/`: `pack.gd`, `townscape.gd`, `style.json`, `look.gd`.
- Test: `godot/tests/test_solarpunk_pack.gd`.

- [ ] **Step 1: Failing tests:**
  - the pack builds;
  - materials are not toon;
  - robots have emissive eyes;
  - A1 by id;
  - glass glows at night;
  - rain wetness and umbrellas;
  - the viewport and environment are restored on switching away.
- [ ] **Step 2: Implement.**
  - A warm, filmic environment with SSAO and optional SSIL (measured).
  - Robot agents and A1.
  - Fairy lights in the great tree at night.
  - Umbrellas and wet ground from a shared helper, factored out of the anime pack into `Pack3D`.
- [ ] **Step 3: Commit.**

### Task 4: The neon noir kit

As Task 2, under `city/tools/styles/neon/`:
- **Materials:** dark slate and glass.
- **Emissive neon strips** as separate `neon*` nodes, so the pack can switch them by time.
- **Lights:** warm globe lamps, bollard lights, planter uplights.
- **Robot A1:** a glossy black-and-white helmet, a cyan ring eye, a hoodie and a card.

### Task 5: The neon noir pack

As Task 3, plus:
- **Light by time of day:**
  - neon and windows on from dusk;
  - many lamp OmniLights without shadows, culled by distance;
  - glow.
- **Wet ground:** SSR while wet, if within budget, else streaks plus a glossy ground.
- **Daytime:** neon off and a cool sky.
- **Tests:**
  - night neon on;
  - noon neon off;
  - wet reflections in rain.

### Task 6: Evidence and budget for both

- **Sheet views and composites:** `sheet_views.gd` captures for each style, composed into `solarpunk-vs-sheet.png` and `neon-vs-sheet.png` with their notes, iterating until the gaps are minor.
- **Budget:** `scripts/bench.sh` passes for both, fixed where it breaches.
- **Gate:** `check.sh` passes.
