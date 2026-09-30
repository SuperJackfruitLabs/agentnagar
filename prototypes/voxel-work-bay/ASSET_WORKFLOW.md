# Voxel asset and scene workflow

This documents the workflow actually used for the robot pilot and shared workshop
as of 2026-09-22. Start here when adding assets, residents or scene interactions.
The [pilot guide](README.md) and [shared workshop guide](SHARED_WORKSHOP.md)
provide scene-specific controls; their verification reports contain measured results.

## Tools and files

| Tool | Current role | Output / entry point |
| --- | --- | --- |
| Blender 5.2.2 LTS + Python/bpy | Procedural meshes, palette, rig, actions, assembly and Cycles review renders | `scripts/build_assets.py`, `scripts/build_shared_workshop.py`; editable `.blend` files |
| glTF 2.0 / GLB | Portable mesh, material, rig and animation delivery | `godot/assets/`; workshop modules in `godot/assets/workshop/` |
| Python 3 | Inspect actual exported geometry, dimensions, hashes and contracts | `scripts/test_exports.py`, `scripts/test_shared_assets.py` |
| Node.js/npm + Khronos gltf-validator | Format validation; version 2.0.0-dev.3.10 pinned by lockfile | `tools/package-lock.json`; validator scripts and JSON reports |
| Godot 4.6.3 Compatibility | Local scene assembly, imported animations, sample states, interaction, collisions and viewport captures | `godot/main.tscn`, `godot/shared_workshop.tscn` |
| FFmpeg | Encode deterministic frame sequences into compact review videos | H.264 MP4 and contact-sheet inspection |
| Git, worktrees and GitHub PRs | Isolated milestones, reviewable checkpoints, retained source and evidence | One branch and PR per milestone |

The current mesh pipeline uses original procedural geometry. Concept images are
references, not image-to-3D input. MagicaVoxel, paid model generators and Blender
MCP are not required by these scripts; their use is not claimed. Godot is the
verified prototype client; selecting the final city engine remains a separate decision.

## 1. Establish the brief and reference

1. Read the asset's row/specification in the [60-deliverable tracker](../../docs/gameplay/asset-catalogue/FIRST_GUILD_SCENE.md).
2. Inspect the exact image and review revision from the [Voxel style index](../../docs/vision/style-studies/styles/02-voxel/README.md).
   The present workshop uses city perspectives **r004** and living/community **r002**.
3. Record the intended crop, dimensions, palette, included variants and acceptance
   boundary in a plan. Reference art is visual direction; distinguish proposed
   features from implemented behavior.
4. Preserve agent identity: agents are **robots**. Use City Agent A1's white shell,
   dark screen face, green chevron eyes/smile and segmented limbs. Use roster
   accessories/colours to distinguish residents. Human residents in a reference
   panel are not the agent template. Do not use the excluded humanoid experiment.

Kai's and Lyra's robot appearances are approved. The shared environment still
needs user visual review. Approval of these appearances does not accept all
rigs, actions, residents or production specifications.

## 2. Set the base and divide the work

Check repository instructions, status, remotes and worktrees. Fetch when upstream
state matters, verify the merged PR/base, and create an isolated feature worktree.
A GitHub merge does not update another local checkout. Preserve existing work.

Write the interface before parallel implementation. For this milestone, asset
and runtime work had separate file ownership and shared these exact contracts:

- Metres, glTF/Godot Y-up, +X east, -Z north, floor top Y=0.
- Hall 12 × 16 m; fourteen bay anchors in two zones at `x = ±3`, seven per zone
  along Z at a measured 2.0 m pitch (`z ∈ {−6,−4,−2,0,2,4,6}`). Kai occupies
  `[-3,0,0]` and Lyra `[-3,0,2]`; the other twelve anchors were reserved by
  this hall milestone and were occupied by the rest of the Guild cast in the
  following stage-2 milestone.
- Reusable 2 m floor/wall/opening modules; three roof bays, now 4.0 m wide
  (6 instances); flush east opening.
- Export names and `layout.json` schema, including world-space collision boxes.
- Existing furniture anchors, rig, clips and movement controller remain reusable.

An asset implementation task owns recipes, source, exports and authoring renders.
A runtime task owns scene code, import settings, interaction tests and captures.
Integration checks the interface, reviews both, records evidence and prepares the
PR. Independent review found the visitor corner-clearance bug in this milestone;
it was reproduced with an actual physics overlap query and fixed before publication.
Parallel tasks are useful when ownership is independent, not a requirement for
small edits.

## 3. Author and export

Edit recipes as the reproducible authority. The generated `.blend` is editable
and useful for inspection, but a script rebuild overwrites manual-only changes.
Move an accepted manual change back into the recipe before regenerating.

- `scripts/geometry.py`: shared procedural geometry and palette.
- `scripts/build_assets.py`: robot/furniture pilot and its shared rig/actions.
- `scripts/shared_workshop.py`: modular environment geometry, courtyard kit and layout.
- `scripts/build_shared_workshop.py`: exports and assembled review source.

Run only the builder for the assets being changed, in a fresh Blender process.
Commands below run from `prototypes/voxel-work-bay`:

```sh
# Environment milestone; --render also produces authoring images.
blender --background --factory-startup --python-exit-code 1 --python scripts/build_shared_workshop.py -- --render

# Robot/furniture changes only; do not run incidentally for environment work.
blender --background --factory-startup --python-exit-code 1 --python scripts/build_assets.py -- --render
```

Both builders write source, GLBs and manifests. Manifests record exact export,
source and recipe hashes; the shared manifest also records layout and reused
asset hashes. Never update a hash merely to silence a mismatch: establish which
source/export changed and regenerate the matching set.

Maintain outward face winding, ground pivots, modular widths and non-overlapping
visible surfaces. Keep collision proxies aligned with rendered structure and
openings. Reuse module meshes through instances. Track file size early; the
current small assets and source are committed directly without Git LFS.

## 4. Integrate animation and interaction

Import GLBs into Godot, retain `.glb.import` sidecars, and keep `.godot/` cache out
of Git. The current imports disable generated LODs for these small voxel meshes.

**All fourteen residents** now share a 16-bone bind structure and seven
clips: idle, walk, seated_idle, typing, attend, sit_down and stand_up (Kai
and Lyra were the first two; the stage-2 cast extended this to the whole
roster). Sit/stand are one-shot clips; the others loop. Export tests verify
this by comparing the full **ordered bone-name list** (not just a bone
count) and clip set across every profile in `character.RESIDENTS` — a
renamed or reordered bone fails the check, proven by a temporary mutation
during stage 2 (`test_every_resident_shares_the_rig_and_clip_set` in
`scripts/test_exports.py`). The walk is 32 frames at 24 fps, 0.72 m per
stride, matched to 0.54 m/s movement. Sit/stand Root translation needs
runtime compensation; chair motion must agree with the seat anchors. See
[pilot verification](evidence/VERIFICATION.md) for the original two-resident
result and [FULL-CAST-VERIFICATION](evidence/FULL-CAST-VERIFICATION.md) for
the fourteen-resident result.

### Adding a resident

Adding a resident to the cast means one `character.RESIDENTS` entry plus its
two geometry functions — `build_assets.py`, `check_contacts.py`,
`test_exports.py` and `validate_exports.cjs` all read the table and need no
further edit:

1. Author `_chest_motif_<name>(b)` and `_head_crest_<name>(b)` in
   `scripts/character.py`. Read two existing residents' functions first as
   worked examples. Chest motif: 6–12 boxes weighted to `'Spine'`, inside
   x ±0.20, z 0.88–1.24, y no further out than −0.26 (the torso shell front
   sits at y ≈ −0.145). Head crest: 1–3 boxes weighted to `'Head'`, at
   z ≈ 1.72, x ±0.20. Materials come from the existing `geometry.py`
   palette only — do not add colours.
2. Add one `RESIDENTS` entry: `mesh_name` (`GS0NN_NameInCamelCase`),
   `rig_name` (`NameRig`), `gs_id`, `source_profile`, `head_accent`,
   `thigh_accent`, `review` (the sole authority for
   `asset-manifest.json`'s `appearance_review` text — state "operator review
   pending" until the user has actually approved the appearance), the two
   function references, and `roster` — mandatory, not conditional:
   `shared_workshop.py`'s `_roster_stations()` asserts every resident in the
   table carries a unique roster number covering exactly 1–14, so a
   fifteenth resident without one breaks the shared-workshop build
   immediately. Adding the number does **not** by itself seat the resident;
   see step 4a below.
3. Rebuild (`blender --background --factory-startup --python-exit-code 1
   --python scripts/build_assets.py`) and run `check_contacts.py`,
   `test_exports.py` and `npm run --prefix tools validate`. The new
   resident's GLB is picked up automatically — no other file needs editing
   to export, contact-check or Khronos-validate it.
4a. Seating is not automatic. `BAYS` in `shared_workshop.py` is a fixed list
   of exactly fourteen positions (seven west, seven east); giving a
   fifteenth resident a `roster` number does not grow it, and the build
   fails loudly (`numbers==list(range(1,15))`) rather than silently
   misplacing or dropping anyone. A fifteenth resident needs a new bay
   position, which is a hall-layout and spec decision, not a `roster` edit.
   Once the new bay exists, rebuild `scripts/build_shared_workshop.py` and
   run `test_shared_assets.py`.
4. Render and look at it (`build_assets.py -- --render`, or a throwaway
   isolated-GLB render script). A motif that does not read as its object at
   a glance is a finding, not a matter of taste — stage 2 reworked three
   motifs (Chotu, Ollie, Sam) after a first render failed to read.

Keep fixture state independent of a journey. Two stations require distinct
fixture/controller instances. Collision guards must cover actual actor/chair
shapes, diagonal clearance and animated Root travel. Use swept checks across
bounded movement segments so large deltas cannot tunnel through a visitor.
The current fixed lanes stop and resume at obstructions; this does not implement
pathfinding. Reset, reduced motion, missing imports and repeated commands must
leave understandable states.

## 5. Validate the artifacts and runtime

Use the smallest meaningful checks for the change. Add a failing regression
before repairing a behavioral defect. Inspect generated files, not only the
recipe's expected values.

```sh
npm ci --prefix tools
node scripts/validate_shared_exports.cjs
python3 scripts/test_shared_assets.py
python3 scripts/test_exports.py
godot --headless --editor --path godot --import --quit
godot --headless --path godot --script res://tests/shared_workshop_test.gd
godot --headless --path godot --script res://tests/bay_pitch_test.gd
```

Both validator scripts reject errors **and warnings**. For robot/animation changes,
also run the contact checker and original five Godot suites listed in the
[pilot guide](README.md#check-the-delivery). The contact checker samples evaluated
mesh poses for feet, seat, typing fit and planted-foot drift. Run repository
Python tests from the repository root with `python3 -m unittest discover -s tests -q`.

Check that untouched exports (`.glb`) and `layout.json` remain byte-identical.
`source/shared-workshop.blend` is **not** byte-reproducible: consecutive rebuilds
of an unmodified recipe produce different `source_sha256` values and even
different file lengths, while every export and `layout.json` come out
byte-identical each time. A differing `.blend` hash alone is not evidence of a
change; see [hall expansion verification](evidence/HALL-EXPANSION-VERIFICATION.md)
for the full finding. Avoid regenerating historical reports or visual baselines
just to obtain a clean result. Record local tests separately from remote CI;
this repository currently has no GitHub Actions workflow.

## 6. Review pictures, movement and performance separately

Inspect Blender authoring views and actual Godot viewport captures; their lighting
is different. Check exterior, cutaway, entrance, interior and narrow-width controls.
Watch the complete departure/return cycle, including chair movement, feet, turns,
visitor obstruction and final seated poses. A still image cannot establish motion.

Use the shared scene's `--capture=/absolute/image.png` or
`--capture-walkthrough=/absolute/frames` options. Encode frames with FFmpeg and
inspect selected frames/contact sheets as well as the sequence. Retain compact
videos and useful stills; keep temporary frame sequences in ignored
`evidence/frames/` directories. Exact commands are in
[shared verification](evidence/SHARED-VERIFICATION.md).

Offline 24 fps video is visual evidence, not measured runtime speed. Run a separate
live sample with both residents cycling, warmup and duration. Record camera,
viewport, device, renderer, sample count, p50/p95/max frame intervals, draw calls
and memory. Close other rendering jobs first. Camera controls are locked during
a measurement so interactions cannot silently change the sample's view. One local
machine does not establish target-device budgets or production acceptance.

## 7. Document and checkpoint

Include these in the same PR as the asset/runtime changes:

- Editable source, reproducible recipes, GLBs, import sidecars and hash manifest.
- Run instructions and the exact references used.
- Technical evidence, useful stills/video, measured sizes and performance limits.
- Tracker updates that distinguish partial progress from full build/test/review
  acceptance; record missing variants and user review still needed.
- Review findings and fixes, followed by final diff/link/hash checks.

Commit the scoped milestone, push the branch, open a PR against the verified base,
and check the remote head/check status. Merge only with authorization. After a
merge, fetch and establish the next base before extending the scene. Preserve
historical checkpoints and superseded decisions so the design remains traceable.

## Current delivery boundaries

The workshop uses sample data with no accounts, dispatch or live agent feed.
The courtyard is a six-metre crop; its generic tree is not the specified mature
jackfruit, its planter includes vegetation, and its doorway has no animated leaf.
Its paving now forms a closed loop with a railed perimeter and an entrance awning,
but there is no threshold ramp: the hall and courtyard are flush at Y = 0, so that
deliverable is blocked rather than built until a raised entry exists.
The hall now holds fourteen bay anchors, and **all fourteen are occupied**:
the full Guild cast is authored, exported, contact-checked and seated in
roster order. `layout.json` no longer carries any reserved desk/chair/
terminal furniture — each `workshop_station.gd` furnishes its own bay.
`blocked()` still sweeps only the visitor and other stations' `actor_body`,
so **no static collision box is ever swept** — including every resident's
own desk and chair boxes. Lanes are authored to avoid static geometry
entirely by design; this was true at two residents and remains true at
fourteen.

**Only Kai's and Lyra's appearances have user approval; the other twelve do
not**, regardless of how clean their build/contact/Khronos results are.
**A seated resident's chest motif is not visible from any hall camera
position found, not only the overview's** — each one's own terminal
(wider than the chest-motif envelope) sits directly between the resident and
any seated-state viewer, and accent colours also blur at hall viewing scale;
the `Label3D` name tags do the identification work while residents are
seated, which is their normal resting state. The motif is visible only once
a resident stands, and standing close enough to see it clearly puts a
visitor inside a neighbouring resident's approach lane. See
[FULL-CAST-VERIFICATION](evidence/FULL-CAST-VERIFICATION.md) for the
standing capture, the offline per-motif lineup render, and why this is a
larger open question than hall-distance legibility alone. General
navigation, production budgets and asset licensing remain explicit
follow-up work. No downloaded models/textures/audio are used; sign
lettering comes from Blender's bundled font converted to mesh. That
provenance record does not establish a repository-wide asset licence.
