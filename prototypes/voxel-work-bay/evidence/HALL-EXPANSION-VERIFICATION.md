# Hall expansion verification — 2026-09-22

Revision: **shared-workshop-r003**. Local sample data only. Kai's and Lyra's
robot appearances are user-approved; the environment palette and the twelve
reserved bays still await user visual review. The [r001](SHARED-VERIFICATION.md)
and [r002](COURTYARD-KIT-VERIFICATION.md) reports are preserved unchanged.
**Nothing in this milestone is accepted.**

This milestone enlarges the hall, widens the roof bays, reserves twelve empty
work-bay anchors, translates the courtyard, and removes a hardcoded two-name
resident list from the runtime. No robot, furniture, rig, clip or courtyard
module geometry was authored or re-authored.

## What changed

| Deliverable | From | To |
| --- | --- | --- |
| Hall envelope | 10 × 8 m, `x −5…5, z −4…4` | **12 × 16 m**, `x −6…6, z −8…8`, 48 floor tiles |
| Roof bays (GS-012) | 3 bays, 10/3 m width, 3 instances | **3 bays, 4.0 m width, 6 instances** (two 8 m modules deep each) |
| Bay anchors | 2 stations, `(±2,0,−0.8)` | **14 anchors**, zones at `x = ±3`, 7 per zone along Z at **2.0 m pitch**, `z ∈ {−6,−4,−2,0,2,4,6}` |
| Occupied bays | Kai `(−2,0,−0.8)`, Lyra `(2,0,−0.8)` | Kai `[-3,0,0]`, Lyra `[-3,0,2]`; **twelve** other anchors furnished (desk, terminal, chair + collision proxies) but unoccupied |
| Courtyard | Doorway `(5,0,1)`, loop `x ∈ {6,8,10}` | Translated **+1 m in X**: doorway `(6,0,1)`, loop `x ∈ {7,9,11}`; depth unchanged at 8 m; no courtyard geometry re-authored, only placements |
| Runtime | Control panel/scene text iterated `["kai","lyra"]` | Both derive from the `stations` Dictionary, so any occupied count renders correctly |
| Manifest | `shared-workshop-r002` | **`shared-workshop-r003`** |

The three sawtooth roof bays the concept art pins are preserved in count; only
their width and instance count changed. `roof.glb` is the only pre-existing
exported module whose own geometry changed in this milestone.

## The measured bay-pitch constraint

A throwaway spike (required by A05's "measure before fixing budgets") found
that `blocked()` rejects any movement bringing a resident within **1.14 m** of
another resident's body, **including a seated one**, and that the walk lane
travels **+1.45 m in X**. That makes the safe pitch depend on which axis the
bays run:

| Bay axis | Pitch tested | Result |
| --- | --- | --- |
| Z (lane runs away from neighbours) | 1.8, 2.0, 2.2, 2.5 m | all clear |
| Z | 1.5 m | departing residents block on seated neighbours |
| Z | 1.0 m | total deadlock, all fourteen waiting |
| X (lane runs toward neighbours) | 2.0, 2.4 m | six of eight movers permanently stuck |
| X | 2.6, 2.8, 3.0, 3.5 m | all clear |

**Consequence: bays run along Z at 2.0 m pitch.** An X-spaced arrangement
would need ≥ 2.6 m pitch and a hall roughly 18 m wide to hold seven bays — the
2.0 m Z pitch shipped here is the tighter, verified option.

The binding failure is a mover passing a *stationary* neighbour. When every
resident departs in lockstep, their relative distances never change, so a
naive test that departs everyone together passes at any pitch — including a
deadlocking one — and cannot detect this constraint. `godot/tests/bay_pitch_test.gd`
is a **permanent regression** promoted from that spike probe: it departs
**every resident in turn**, with all others seated, returning each mover to
`seated` before the next takes its turn — so it scales to fourteen movers
unchanged in stage 2.

The constraint is also **directional**, which is why a single fixed mover is
not enough on its own. Departure pulls the chair 1.30 m toward −Z
(`PULLED = Vector3(0,0,-1.30)`) before standing, so a mover only closes on a
neighbour seated at **lower** z: minimum separation there is
`|pitch − 0.65|` against `SAFE_RADIUS = 1.14`, i.e. the binding constraint is
**pitch ≥ 1.79 m**. Against a neighbour at **higher** z a mover never closes
(minimum separation `min(pitch, 1.45)`), so that direction clears at any
pitch ≥ 1.14 m. Looping every resident as mover exercises both ordered pairs,
including the binding lower-z direction, whichever resident happens to sort
first.

This was verified by sweeping the bay pitch with the fixed test: it **fails**
(`"failures":3`, with pushed errors naming the resident stuck at
`"pulling chair"`) at **1.5 m**, a pitch this milestone documents as
deadlocking, and **passes** (`"failures":0`) at **1.8 m** and at the shipped
**2.0 m**. See Task 4's report for the full narrow/rebuild/revert cycle used
to establish the pitch itself; this record only asserts the shipped pitch and
that the guarding test now discriminates correctly against it.

## Assets

Blender 5.2.2 LTS; original procedural geometry reusing the existing palette.
The [manifest](../shared-workshop-manifest.json) records source, recipe,
layout and export hashes.

| Module | Bytes | Khronos errors / warnings |
| --- | ---: | --- |
| floor | 8,340 | 0 / 0 |
| wall | 6,012 | 0 / 0 |
| window | 10,040 | 0 / 0 |
| door | 6,352 | 0 / 0 |
| roof | 24,584 | 0 / 0 |
| path | 5,452 | 0 / 0 |
| lawn | 1,636 | 0 / 0 |
| path_corner | 8,232 | 0 / 0 |
| path_t | 8,872 | 0 / 0 |
| railing | 5,456 | 0 / 0 |
| awning | 14,116 | 0 / 0 |
| planter | 7,980 | 0 / 0 |
| tree | 9,172 | 0 / 0 |
| bench | 7,448 | 0 / 0 |
| shelf | 19,644 | 0 / 0 |
| sign | 144,912 | 0 / 0 |
| **Total (all 16 modules)** | **288,248** | **0 / 0** |

Editable Blender source (this build): **780,671 bytes** — see *Non-reproducible
`.blend` build* below for why that figure cannot be reproduced by rebuilding.
Layout: **150** modular instances and **442** static collision boxes (up from
73 and 245 at r002), covering the enlarged hall, the translated courtyard, and
the reservation furniture/collision boxes for the twelve unoccupied bays. Kai's
and Lyra's own station furniture is added separately at runtime by
`workshop_station.gd` and is not counted in these layout figures, matching the
r001/r002 convention.

Comparing this build's manifest hashes against the pre-milestone baseline
(commit `b7afafa`): **all 15 non-roof module GLBs are byte-identical**
(`floor`, `wall`, `window`, `door`, `path`, `lawn`, `path_corner`, `path_t`,
`railing`, `awning`, `planter`, `tree`, `bench`, `shelf`, `sign`). `roof.glb`
is the only module whose export hash changed, consistent with it being the
only recipe whose geometry (bay width) changed. Every courtyard module
(`path`, `path_corner`, `path_t`, `railing`, `awning`, `planter`, `tree`,
`lawn`) kept its exact r001/r002 geometry; only its `layout.json` placement
moved +1 m in X.

The six robot/furniture GLBs (`chair.glb`, `desk.glb`, `environment.glb`,
`kai.glb`, `lyra.glb`, `terminal.glb`) are untracked by this milestone's build
and remain **byte-identical**: `git diff --stat b7afafa -- godot/assets/chair.glb
godot/assets/desk.glb godot/assets/environment.glb godot/assets/kai.glb
godot/assets/lyra.glb godot/assets/terminal.glb` reports no changes.

## Non-reproducible `.blend` build (pre-existing, not caused by this milestone)

`source/shared-workshop.blend` is **not byte-reproducible**. Task 4 rebuilt
the *same, unmodified* recipe three times in a fresh Blender process and got
three different `source_sha256` values each time, while `layout.json`'s
content (and its `layout_sha256`) came out byte-identical on every rebuild,
and every `.glb` came out byte-identical too. Only the `.blend` save format
itself varies — almost certainly an embedded timestamp or session id Blender
writes into the binary, not a change in the modelled scene.

**Consequence:** the manifest's `source_sha256` assertion holds only because
the manifest and the `.blend` are written in the same build run — it does not
mean a future rebuild of the identical recipe would reproduce that hash, and
`ASSET_WORKFLOW.md` §5's "untouched assets remain byte-identical" guidance
cannot be applied to the `.blend` file the way it applies to every GLB. This
report does not attempt to fix that; it is recorded here so it is not
rediscovered as a surprise later.

## Reserved-bay furniture is inert for movement (must-know for stage 2)

`blocked()`, the collision guard a resident's walk checks against, sweeps
only the visitor and other **stations** — the Dictionary of occupied
residents. The twelve reserved bays' desk and chair collision proxies exist
in `layout.json` (and are visible in the overview capture below) but are
**not** in that sweep, so they cannot obstruct a resident's walk. This does
not matter for anything currently in the scene, because every lane runs
straight into the open aisle and none crosses a reserved bay's furniture. It
will matter once stage 2 occupies those bays and lanes start passing closer
to neighbouring furniture; whoever does that work needs to extend the
collision sweep to reserved-bay proxies (or otherwise account for them)
rather than assume geometry that looks solid already blocks something.

This is broader than a reserved-bay gap: `blocked()` sweeps only the visitor
and other stations' `actor_body`, so **no static collision box is ever
swept** — including Kai's and Lyra's own desk and chair boxes. The design is
that lanes are authored to avoid static geometry entirely, not that reserved
bays are a special case; extending the sweep to the twelve reserved proxies
alone would not cover Kai's and Lyra's own furniture.

## Checks

Run from `prototypes/voxel-work-bay`. Full output:
[hall-expansion-tests.txt](hall-expansion-tests.txt).

```sh
node scripts/validate_shared_exports.cjs
python3 scripts/test_shared_assets.py
python3 scripts/test_exports.py
for t in fixture import scene movement journey shared_workshop bay_pitch; do
  godot --headless --path godot --script res://tests/${t}_test.gd
done
```

- All 16 GLBs: zero Khronos errors and warnings, pinned gltf-validator
  2.0.0-dev.3.10.
- `test_shared_assets.py`: **14 tests, OK** — includes the four `HallEnvelope`
  assertions added in Task 1 (hall floor count/extent, roof bay count and
  width, doorway position, corridor bounds) and the two added in Task 2
  (fourteen bays in two zones at 2.0 m pitch; the twelve reserved bays are
  furnished but unoccupied).
- `test_exports.py`: **6 tests, OK** — unchanged export contract (triangle
  geometry, resident rig/animation sharing, skin + 7 clips per character,
  outward winding, furniture mount anchors, skinned-mesh root transform).
- All seven Godot suites pass with `"failures":0`: `fixture`, `import`,
  `scene` (`"missing_assets":[]`), `movement`, `journey`, `shared_workshop`,
  and the new permanent **`bay_pitch`** regression.
- Repository-wide `python3 -m unittest discover -s tests -q` from the
  repository root: **34 tests, OK**.

## Contract changes — done

| Where | From | To | Status |
| --- | --- | --- | --- |
| `ASSET_WORKFLOW.md` §2 | hall 10 × 8 m; two named station origins | hall 12 × 16 m; fourteen bay anchors at 2.0 m Z pitch | **Done**, this record |
| `shared_workshop.gd` control loop | `for key in ["kai","lyra"]` | iterate `stations` | **Done**, commit `78778f0` |
| Scene text view | enumerates every station inline | summarises fourteen residents readably (`"...fourteen work bays, %d of them currently occupied..."`) | **Done**, commit `78778f0` |
| `test_shared_assets.py` | asserts exactly two stations | asserts fourteen bays, 2.0 m pitch and zone separation | **Done**, commits `9cfe2c1`, `f9e813e` |
| Door corridor check | x 4.85–5.15 | x 5.85–6.15 | **Done**, commit `9cfe2c1` |
| `CourtyardKit.DOORWAY` | (5.0, 1.0) | (6.0, 1.0) | **Done**, commit `9cfe2c1` |
| Roof assertions | 3 instances, width 10/3 | 6 instances, width 4.0 | **Done**, commit `9cfe2c1` |

## Captures

Godot 4.6.3, `gl_compatibility`, Mesa Intel Iris Xe Graphics, 1060 × 660
viewport.

- [Exterior](hall-exterior-r003.png) (`hall-exterior-r003.json`,
  `"error":0`, `"missing_assets":[]`) — shows three sawtooth roof bays
  spanning the wider hall, the courtyard sitting outside the east wall with
  its railed perimeter, tree island and loop intact.
- [Overview / cutaway](hall-overview-r003.png) (`hall-overview-r003.json`,
  `"error":0`, `"missing_assets":[]`) — shows fourteen bays reading as two
  parallel rows of seven along Z, with Kai and Lyra's status labels visible
  near the front of the west row and the remaining twelve bays furnished but
  unlabelled (no resident). Both captures were opened and visually confirmed,
  not just checked for `"error":0`.
- [Controls](hall-controls-r003.png) (Task 3, commit `78778f0`) — confirms the
  de-hardcoded control panel renders one leave/return row per occupied
  resident (two, for Kai and Lyra) without a fixed two-name assumption.

## Review still needed

Nothing here is accepted. The twelve reserved bays hold no residents — stage 2
authors and reviews their appearances separately. A01's environment half, A02,
A05 and A06 remain open, as does the environment-palette review noted in
`ASSET_WORKFLOW.md` and `SHARED_WORKSHOP.md`. Zone mirroring and general
navigation remain explicitly deferred (see the stage 1 spec's *Deferred*
section); the reserved-bay furniture collision gap above is a known limitation
for whoever occupies those bays next, not a defect blocking this record.
