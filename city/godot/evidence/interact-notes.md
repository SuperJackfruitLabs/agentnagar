# Interactions: evidence (Part A)

What the
[interactions design](../../../docs/superpowers/specs/2026-09-27-city-interactions-design.md)'s
Part A set out to deliver, measured against the built district. Part B (the
workstation) is not built yet; nothing here speaks to it.

## What Part A delivers

Every placement whose kind offers a capability can now be acted on the same
way, in every style, with keyboard, controller or touch, through one core
command (`Use`) and one client path (`core/interact.gd`):

- **Sitting.** Every `sit` anchor in the district can be sat on: room seats
  (desks, benches, café tables, library reading chairs) and the perches
  — plaza steps, the fountain's rim, low walls, and the tram shelters'
  benches (added in the final fix wave, after the shots below were taken)
  — which are open to anyone, hold no room capacity, and the seat policy
  never assigns an agent to.
- **Reading.** The Square's noticeboard, the Guild hall's plaque
  (`placement:guild-hall-plaque`), the library's three bookshelves, and
  the reading room's kiosk (`Browse`) each open their
  content in an overlay, with the same content shown as a near-distance
  summary on their drawn surface and a far-distance chip beyond that. Every
  panel is marked "Sample": Part A ships only the `sample` source, from
  `fixtures/district/panels/` (`guild-hall.json`, `library-shelves.json`,
  `square-notices.json`), keyed by placement ID.
- **Boarding and going in** are now the `board` and `enter` capabilities
  under the same `Use` path as everything else, behaving exactly as before.
- **Inspecting** works on all 33 catalogue kinds and opens the same overlay
  with the kind's name, description and capabilities, entirely client-side
  (§10's amendments explain why).
- **Plants that sway.** Every meadow's grass and flowers part when a player,
  resident or agent walks through them, in every style, and spring back
  within a second.

## Tests

- **Rust** (`cargo test --workspace`, from `city/`): 451 tests passing,
  0 failed, across `city-contracts`, `city-core`, `city-cli`, `city-godot`
  and `city-mcp`. This includes `interact::apply`'s rule tests, the
  district gate's pinned log (`the_district_log_is_unchanged_by_use`), and
  invariant 25 (anchor occupancy and `using`'s own consistency) on every
  tick of both scenario gates.
- **Godot** (`godot --headless --path . --script res://tests/run_all.gd`,
  from `city/godot`): 663 passing, 0 failed — the task brief's 604 baseline
  predates this plan; Tasks 1–8 added the rest. This includes
  `test_collision_audit` (held at 0 in all six styles) and
  `test_door_entry` (100% in every family, every style).
- **Kit tests** (`for t in tools/styles/*/test_*.py; do python3 -m
  unittest "$t"; done`): all 8 files pass.
- **`generate.py --check`**: passes; the district fixture (panels, perches,
  the noticeboard, plaque, kiosk and bookshelves) is reproducible from its
  generator.

## Sway's frame cost

`tests/test_frame_cost.gd`'s `test_sixty_walkers_crossing_the_park_sway_it_
within_budget` times `SoftContacts.update` alone, headless (dummy
rendering-server calls; a real renderer adds some per-instance cost on top),
against 60 walkers crossing all three meadows, at least 80 clumps moving on
every frame after the first second (the observed minimum is 192):

| Measure | Result | Budget (spec §2) |
| --- | --- | --- |
| Median (300 timed calls) | 0.166 ms | ≤ 0.3 ms |
| p90 | 0.188–0.189 ms | — |
| Max | 0.25–0.27 ms | — |

An earlier version of the same bench, before contacts were checked every
other frame (§10's amendments), measured 0.55 ms median at the same load —
over budget. Checking each body every other frame, alternating by body, and
skipping a clump already pushed harder this frame brought it under.

## Evidence

Captured by `tools/probes/capture_interact.gd`, one set per style, all
committed under `city/godot/evidence/`:

**Sitting**, one shot per perch or seat kind, the player sat and facing as
the anchor asks:

| Style | bench | cafe-table | desk | reading-chair | steps | low-wall | fountain-rim |
| --- | --- | --- | --- | --- | --- | --- | --- |
| anime_cel | [✓](interact-anime_cel-sit-bench.png) | [✓](interact-anime_cel-sit-cafe-table.png) | [✓](interact-anime_cel-sit-desk.png) | [✓](interact-anime_cel-sit-reading-chair.png) | [✓](interact-anime_cel-sit-steps.png) | [✓](interact-anime_cel-sit-low-wall.png) | [✓](interact-anime_cel-sit-fountain-rim.png) |
| lowpoly_tropical | [✓](interact-lowpoly_tropical-sit-bench.png) | [✓](interact-lowpoly_tropical-sit-cafe-table.png) | [✓](interact-lowpoly_tropical-sit-desk.png) | [✓](interact-lowpoly_tropical-sit-reading-chair.png) | [✓](interact-lowpoly_tropical-sit-steps.png) | [✓](interact-lowpoly_tropical-sit-low-wall.png) | [✓](interact-lowpoly_tropical-sit-fountain-rim.png) |
| neon_noir | [✓](interact-neon_noir-sit-bench.png) | [✓](interact-neon_noir-sit-cafe-table.png) | [✓](interact-neon_noir-sit-desk.png) | [✓](interact-neon_noir-sit-reading-chair.png) | [✓](interact-neon_noir-sit-steps.png) | [✓](interact-neon_noir-sit-low-wall.png) | [✓](interact-neon_noir-sit-fountain-rim.png) |
| solarpunk | [✓](interact-solarpunk-sit-bench.png) | [✓](interact-solarpunk-sit-cafe-table.png) | [✓](interact-solarpunk-sit-desk.png) | [✓](interact-solarpunk-sit-reading-chair.png) | [✓](interact-solarpunk-sit-steps.png) | [✓](interact-solarpunk-sit-low-wall.png) | [✓](interact-solarpunk-sit-fountain-rim.png) |
| voxel | [✓](interact-voxel-sit-bench.png) | [✓](interact-voxel-sit-cafe-table.png) | [✓](interact-voxel-sit-desk.png) | [✓](interact-voxel-sit-reading-chair.png) | [✓](interact-voxel-sit-steps.png) | [✓](interact-voxel-sit-low-wall.png) | [✓](interact-voxel-sit-fountain-rim.png) |
| pixel_art | [✓](interact-pixel_art-sit-bench.png) | [✓](interact-pixel_art-sit-cafe-table.png) | [✓](interact-pixel_art-sit-desk.png) | [✓](interact-pixel_art-sit-reading-chair.png) | [✓](interact-pixel_art-sit-steps.png) | [✓](interact-pixel_art-sit-low-wall.png) | [✓](interact-pixel_art-sit-fountain-rim.png) |

In pixel art, the fixed view puts the middle plaza step behind a street
tree and most of the fountain behind the library's roof (see Known limits);
`sit-steps` and `sit-fountain-rim` use the anchors that view does show.

**Reading**, the Square's noticeboard far (its chip), near (headlines or a
compact label) and open (the overlay), one set per style:

| Style | far | near | open |
| --- | --- | --- | --- |
| anime_cel | [✓](interact-anime_cel-notice-far.png) | [✓](interact-anime_cel-notice-near.png) | [✓](interact-anime_cel-notice-open.png) |
| lowpoly_tropical | [✓](interact-lowpoly_tropical-notice-far.png) | [✓](interact-lowpoly_tropical-notice-near.png) | [✓](interact-lowpoly_tropical-notice-open.png) |
| neon_noir | [✓](interact-neon_noir-notice-far.png) | [✓](interact-neon_noir-notice-near.png) | [✓](interact-neon_noir-notice-open.png) |
| solarpunk | [✓](interact-solarpunk-notice-far.png) | [✓](interact-solarpunk-notice-near.png) | [✓](interact-solarpunk-notice-open.png) |
| voxel | [✓](interact-voxel-notice-far.png) | [✓](interact-voxel-notice-near.png) | [✓](interact-voxel-notice-open.png) |
| pixel_art | [✓](interact-pixel_art-notice-far.png) | [✓](interact-pixel_art-notice-near.png) | [✓](interact-pixel_art-notice-open.png) |

Two extra low-poly captures show the library's kiosk read from its stand
anchor: [`interact-lowpoly_tropical-kiosk-near.png`](interact-lowpoly_tropical-kiosk-near.png)
and, with the Square's notices bound to it,
[`interact-lowpoly_tropical-kiosk-near-notices.png`](interact-lowpoly_tropical-kiosk-near-notices.png).

[`interact-pixel_art-library-closed.png`](interact-pixel_art-library-closed.png)
shows the library closed from a distance: its dome and roof drawn, and no
indoor chip or name tag floating above them (§10's `LABEL_Z` amendment).

**Sway**, a before-and-after of a walker parting a meadow, one per style
(the 3D styles as a before | after pair; pixel art as a 12-frame strip,
0.25 s apart, 5× enlarged, a player walking north to south through
meadow 1):

- [anime_cel](interact-anime_cel-sway.png)
- [lowpoly_tropical](interact-lowpoly_tropical-sway.png)
- [neon_noir](interact-neon_noir-sway.png)
- [solarpunk](interact-solarpunk-sway.png)
- [voxel](interact-voxel-sway.png)
- [pixel_art](interact-pixel_art-sway.png)

## Known limits

Deferred minors from the build's ledger a player could notice:

- **A café umbrella draws over a sitter in pixel art.** The umbrella prop's
  sort predates this work and was not touched.
- **The fountain is mostly hidden behind the library's roof in pixel art's
  fixed view.** This is the district's layout, not a rendering bug; no
  camera angle in that fixed view shows more of it, so `sit-fountain-rim`
  uses the fountain's north-west anchor, the one side the view does show.
- **A perch sitter's first-person eye follows the core's cell centre,**
  not the seat drawn under them — up to about 15 cm off. The third-person
  and overhead drawing is correct (the seat itself is drawn on the
  anchor's point, per §10's amendment); only the first-person camera has
  this small offset.
- **Runtime operator placements are not targetable until reload.** `Interact`
  and `NavQuery` are built once at boot from the loaded layout; a placement
  an operator adds while playing does not appear as a target until the
  client restarts (the same deferral style-pack redrawing already has,
  pending build mode).
- **Bent grass has no bent normals.** The sway shader moves a clump's
  vertices but does not correct their normals to match, so the only
  lighting change on a bent clump is its tint toward the style's sway
  colour, not a shading change from the bend itself. Cosmetic only.
