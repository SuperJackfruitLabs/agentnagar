# Shared workshop verification — 2026-09-22

Revision: **shared-workshop-r001**. Local sample data only. Kai’s robot appearance remains approved; Lyra and this environment await user visual review. Original PR17 robot, furniture, source and movement controller files are unchanged.

## Assets

Blender 5.2.2 LTS; original procedural geometry using the existing palette. The [manifest](../shared-workshop-manifest.json) records source, recipe, layout and export hashes.

| Module | Bytes | Khronos errors / warnings |
| --- | ---: | --- |
| floor | 8,340 | 0 / 0 |
| wall | 6,012 | 0 / 0 |
| window | 10,040 | 0 / 0 |
| door | 6,352 | 0 / 0 |
| roof | 24,672 | 0 / 0 |
| path | 5,452 | 0 / 0 |
| lawn | 1,636 | 0 / 0 |
| planter | 7,980 | 0 / 0 |
| tree | 9,172 | 0 / 0 |
| bench | 7,448 | 0 / 0 |
| shelf | 19,644 | 0 / 0 |
| sign | 144,912 | 0 / 0 |
| **Total** | **251,660** | **0 / 0** |

Editable Blender source: **441,343 bytes**. Layout: 62 modular instances and 234 static collision boxes, plus two reused workstations and their actor/chair colliders.

The hall is 10 × 8 m with three sawtooth roof bays. The courtyard is a 6 × 8 m crop. The generic shade tree is not the complete mature jackfruit deliverable. Door export is an open frame without a movable leaf; planter vegetation is integrated. These remain partial production assets.

## Checks

Run from `prototypes/voxel-work-bay`:

```sh
npm ci --prefix tools
node scripts/validate_shared_exports.cjs
python3 scripts/test_shared_assets.py
python3 scripts/test_exports.py
godot --headless --editor --path godot --import --quit
godot --headless --path godot --script res://tests/shared_workshop_test.gd
```

- All 12 new GLBs: zero Khronos errors and warnings, using pinned gltf-validator 2.0.0-dev.3.10. Reports: [shared-validation](shared-validation/).
- Two new asset tests pass: actual triangle winding/normals, positive volume, modular widths, flush entrance/corridor, station and roof placement, non-coplanar floor tops, exact source/recipe/export hashes.
- Six original export contract tests and 34 repository Python tests pass.
- All six Godot suites pass: fixture, import, scene, movement, journey and shared_workshop. [Test output](shared-godot-tests.txt). Final shared suite also rerun after measurement input locking.
- Shared runtime coverage includes simultaneous full cycles, independent states, actual animation Root pose, live/offline pose parity, large-delta swept obstruction, chair blocking, diagonal physics overlap, missing clips, reset/reduced motion and actual door traversal both ways.
- Independent review reproduced a diagonal overlap missed by the initial circular guard. Clearance now encloses the actual square actor/chair colliders plus visitor capsule and animated Root travel. The physics reproduction reports no overlap and waiting=true; review has no remaining actionable findings.

## Visual evidence

- [Authoring exterior](shared-authoring-exterior.png) and [cutaway](shared-authoring-cutaway.png). Blender lighting differs from runtime.
- Godot [overview](shared-runtime-overview.png), [exterior](shared-runtime-exterior.png), [entrance](shared-runtime-entrance.png), [interior](shared-runtime-interior.png), [360 px scene](shared-runtime-360.png) and [360 px controls](shared-controls-360.png).

[Walkthrough video](shared-walkthrough.mp4): 480 frames at 24 fps (20 seconds),
with exterior, simultaneous journeys, entrance traversal and return to both
seated endpoints. [Capture metadata](shared-walkthrough.json) and
[contact sheet](shared-walkthrough-contact-sheet.png). This is deterministic
offline rendering, separate from live timing.

Reproduce the recording from the prototype directory (output directory must be
absolute):

```sh
godot --path godot res://shared_workshop.tscn -- --capture-walkthrough=/absolute/frames
ffmpeg -framerate 24 -i /absolute/frames/frame-%04d.png -c:v libx264 -crf 23 -pix_fmt yuv420p -movflags +faststart /absolute/shared-walkthrough.mp4
```

## Live performance sample

[Raw report](shared-performance.json): Godot 4.6.3, Compatibility renderer,
Mesa Intel Iris Xe (ADL GT2), overview camera, **1060 × 660** viewport. Both
residents continuously cycle. Five-second warmup, **30.002 s** sample,
**10,777** process-frame intervals. Other asset rendering jobs had finished.

| Measurement | Result |
| --- | ---: |
| Frame interval p50 | 2.779 ms |
| Frame interval p95 | 3.198 ms |
| Maximum interval | 6.006 ms |
| Final-frame draw calls | 237 |
| Final-frame primitives | 12,078 |
| Nodes | 702 |
| Engine static memory | 39,171,758 bytes |

These are process-frame intervals and final-frame counters, not GPU timestamps,
whole-process RSS, target-device budgets or production acceptance. An initial
sample changed camera during interaction and was discarded; measurement now locks
camera controls. Normal preview controls remain enabled.

```sh
godot --path godot --resolution 1060x660 res://shared_workshop.tscn -- --camera=overview --measure-seconds=30 --warmup-seconds=5 --report=/absolute/shared-performance.json
```

## Scope limits

Fixed robot lanes and swept visitor guards pause/resume motion; general pathfinding and crowds are outside this milestone. The visitor has horizontal walk controls, without gravity, jumping or terrain traversal. Cutaway hides roof/front meshes but retains collisions; first-person view restores them. No live account, agent feed, production-device acceptance or full Guild cast compatibility is claimed.

The production tracker now records 25/60 entries in progress, with no entries declared fully built, tested or accepted against all production specifications.
