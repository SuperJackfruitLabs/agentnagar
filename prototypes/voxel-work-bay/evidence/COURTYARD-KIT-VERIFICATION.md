# Courtyard environment kit verification — 2026-09-22

Revision: **shared-workshop-r002**. Local sample data only. Kai's robot appearance
remains approved; Lyra, the workshop environment and this courtyard kit all await
user visual review. The [r001 report](SHARED-VERIFICATION.md) is preserved unchanged.

This milestone adds four environment modules and reworks the courtyard paving. No
robot, furniture, rig, clip or movement-controller file was touched.

## What changed

| Deliverable | Module | Instances | Outcome |
| --- | --- | ---: | --- |
| GS-003 corner path module | `path_corner` | 4 | Built at pilot scope |
| GS-004 path junction module | `path_t` | 1 | Built at pilot scope |
| GS-013 entrance awning | `awning` | 1 | Built at pilot scope |
| GS-017 courtyard edge railing | `railing` | 10 | Built at pilot scope |
| GS-014 threshold ramp | — | 0 | **Blocked**; see below |

### GS-014 is blocked, not built

The hall floor and the courtyard path both finish at **Y = 0**. Measured from the
actual exports rather than from the draft prose:

| Surface | Module top |
| --- | ---: |
| Hall floor | 0.000000 m |
| Courtyard path | 0.000000 m |
| Rise to bridge | **0.000000 m** |

GS-014 drafts "2 m wide, 2.4 m long for 0.2 m rise; adjust to actual floor height."
Adjusted to the actual height there is no rise and therefore no ramp geometry to
author. Raising the hall 0.2 m to match the draft would move both station origins,
every collision proxy and the door-corridor clearance, disturbing the approved PR17
pilot; that was rejected as out of scope for an environment milestone.

The row stays valid for a future raised entry, such as the GS-016 home frontages.
`CourtyardKit.test_hall_and_courtyard_remain_flush` asserts the zero rise so the
blocked reason cannot drift out of date silently.

## Assets

Blender 5.2.2 LTS; original procedural geometry reusing the existing palette. The
[manifest](../shared-workshop-manifest.json) records source, recipe, layout and
export hashes.

| Module | Bytes | Khronos errors / warnings |
| --- | ---: | --- |
| path_corner | 8,232 | 0 / 0 |
| path_t | 8,872 | 0 / 0 |
| railing | 5,456 | 0 / 0 |
| awning | 14,116 | 0 / 0 |
| **New subtotal** | **36,676** | **0 / 0** |
| All 16 modules | 288,336 | 0 / 0 |

Editable Blender source: **449,761 bytes**. Layout: 73 modular instances and 245
static collision boxes, up from 62 and 234.

The twelve r001 modules rebuilt **byte-identical**, confirmed against hashes taken
before any edit, so this milestone is purely additive to the existing kit. Their
r001 Khronos reports were left in place rather than regenerated for a new timestamp.

## Geometry contracts

- Junction tiles share one grammar: a 0.44 m cobalt marker stud, one paved strip
  per open arm, and corner pavers. Closed sides leave the sand base showing, which
  is what makes a turn legible underfoot.
- `path_corner` is authored with arms north and east; `path_t` with arms west, east
  and south. All four orientations come from `rotation_y` in `layout.json`, matching
  how the wall modules are placed. No orientation-specific mesh was exported.
- `railing` carries one continuous 2 × 1.1 × 0.14 m collision proxy per panel, so
  abutting panels leave no gap to squeeze through at a join.
- `awning` cantilevers 2 m from the wall plane over 4 m of frontage with no post in
  the walkway. Its underside never drops below **2.44 m** and its collision slab
  sits at 2.45 m, clear of the 2.19 m doorway corridor ceiling.

## Layout

The courtyard was a dead end: a spine and a spur that terminated at an invisible
boundary, which GS-001 explicitly forbids ("walk the entire public route without
gaps, falls or an invisible exit"). It is now a closed loop of eight tiles around a
central planted island carrying the shade tree, entered from the hall doorway on the
loop's west side.

Placed counts against the drafted targets: 4 corners (draft 4–8) and 1 T junction
(draft 2–4). One T is placed because the hall has exactly one courtyard entrance;
this is a layout outcome, not an unbuilt variant. Three planters moved onto the
north lawn strip so nothing stands in the new paved route, and the sign moved
0.25 m south clear of the junction tile.

The tree is 0.2 m east of the island centre so its canopy clears the awning's
projection. The courtyard remains a 6 × 8 m crop; the generic shade tree is still
not the mature jackfruit deliverable, and the door is still an open frame.

## Checks

Run from `prototypes/voxel-work-bay`. Full output: [courtyard-kit-tests.txt](courtyard-kit-tests.txt).

```sh
npm ci --prefix tools
node scripts/validate_shared_exports.cjs
python3 scripts/test_shared_assets.py
python3 scripts/test_exports.py
godot --headless --editor --path godot --import --quit
godot --headless --path godot --script res://tests/shared_workshop_test.gd
```

- All 16 GLBs: zero Khronos errors and warnings, pinned gltf-validator 2.0.0-dev.3.10.
- Six new `CourtyardKit` assertions pass, added before the geometry existed and
  observed failing first: every arm reaches paving or the hall threshold; no abutting
  paving is left without a facing arm; the public route contains a cycle rather than a
  dead end; perimeter railing runs have no gap; awning collision clears 2.4 m; and the
  hall/courtyard rise is zero.
- Two original shared-asset tests still pass, extended to cover the new modules'
  winding, volume, widths and non-coplanar tops.
- Six original export contract tests and 34 repository Python tests pass.
- All six Godot suites pass: fixture, import, scene, movement, journey, shared_workshop.
- Robot and furniture GLBs verified byte-identical: chair, desk, environment, kai,
  lyra, terminal.

One existing assertion was narrowed. `test_layout_and_clearance` required
`path.glb` at each of x = 6, 8, 10 along z = 1, which encoded the straight spur this
milestone deliberately replaces. It now requires a paved landing outside the doorway;
the new connectivity assertions cover the route far more strongly than the old check.

## Captures

Godot 4.6.3, gl_compatibility, Mesa Intel Iris Xe Graphics, 1060 × 660 viewport.

- [Exterior](shared-exterior-r002.png) — awning, railed perimeter, loop and island.
- [Cutaway](shared-overview-r002.png) — both stations with the reworked courtyard.
- [Entrance, first person](shared-entrance-r002.png) — GS-013's "entrance remains
  identifiable from the courtyard" check, from a visitor's eye height.
- Blender authoring renders: [exterior](shared-authoring-exterior.png) and
  [cutaway](shared-authoring-cutaway.png). Cycles lighting; not runtime captures.

Each capture's sidecar JSON records draw calls, primitives and static memory for that
single deterministic frame. These are not live frame-time measurements, and one local
machine establishes no target-device budget.

## Review still needed

Nothing here is accepted. The four modules need visual review against the pinned
02-voxel references, alongside the still-pending review of Lyra and the r001
environment. A01, A02, A05 and A06 remain open for every row this milestone touches.
