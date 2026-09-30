# Shared Voxel workshop and courtyard

This milestone assembles a modular workshop and adjoining courtyard around the
approved Voxel robot design. **All fourteen Guild residents are present
simultaneously**, each with an independent workstation, fixture state and
desk journey. Everything shown is local sample data; this scene has no
agent-service or account connection.

**Only Kai's and Lyra's appearances have user approval.** The other twelve —
Olivia, Chotu, Pete, Ray, Quill, Echo, Paul, Sam, Casey, Ollie, Theo and
Cody — are authored, exported and seated, but unreviewed. See
[evidence/FULL-CAST-VERIFICATION.md](evidence/FULL-CAST-VERIFICATION.md).

The original one-bay inspector remains available. The new scene reuses its
exact robot/furniture exports and shared animation controller.

See [Asset and scene workflow](ASSET_WORKFLOW.md) for the end-to-end authoring,
validation, review and checkpoint process.

## Run

Requires Godot 4.6.x (verified engine version and results are recorded in the
[shared verification report](evidence/SHARED-VERIFICATION.md)). From this folder:

```sh
godot --headless --editor --path godot --import --quit
godot --path godot res://shared_workshop.tscn
```

Use `O` for cutaway, `E` for exterior/roof, and `F` for first-person inspection.
`C` opens controls; `L` triggers **All leave**, `B` triggers **All return**
(both still bound to the same `"all"` action, relabelled from the
two-resident "Both leave/return" at stage 2), `R` resets, `M` toggles reduced
motion, and `T` toggles scene text within the controls. Walk with WASD; click
to look and press Escape to release the mouse. The east entrance opens onto
the courtyard path. All fourteen workstations have their own sample state and
journey controls, reachable as compact per-resident rows in the controls
panel (sized to `clampf(size.y*0.45, 188, 320)`, scrolling past that). The
text view leads with a short phase tally (e.g. "1 seated, 13 pulling chair; 2
waiting for the visitor") and then one line per resident for detail; controls
remain available at narrow widths.

The three sawtooth roof bays, cream/cobalt walls, yellow roof and warm wood follow
the selected Voxel [city r004](../../docs/vision/style-studies/styles/02-voxel/sheets/00-city-perspectives/r004/image.png)
and [living r002](../../docs/vision/style-studies/styles/02-voxel/sheets/01-living-community/r002/image.png)
references. The low hall has an east-facing doorway. This crop does not recreate
the entire district, library, transit system or central Tree Square.

## Layout and movement

- Workshop floor: 12 × 16 m, with reusable 2 m floor/wall/window/door units,
  48 floor tiles on the grid `x ∈ {−5,−3,−1,1,3,5}`, `z ∈ {−7,−5,−3,−1,1,3,5,7}`.
- Fourteen bay anchors sit in two zones at `x = ±3`, seven per zone along Z at
  a measured **2.0 m pitch** (`z ∈ {−6,−4,−2,0,2,4,6}`). **All fourteen are
  now occupied**, seated in roster order (`character.RESIDENTS[*]['roster']`):
  GR01–07 west zone (`x=-3`) north to south — Onboarding Olivia, Super Chotu,
  Project Manager Pete, Kai, Lyra, Research Ray, Writer Quill; GR08–14 east
  zone (`x=3`) north to south — Analyst Echo, Predictor Paul, Strategy Sam,
  Controller Casey, Optimizer Ollie, Threat Hunter Theo, Cleaner Cody. Kai
  stays at `[-3,0,0]` and Lyra at `[-3,0,2]`, unchanged from the two-resident
  milestone. `layout.json` no longer carries any reserved desk/terminal/chair
  furniture — every bay furnishes itself via `workshop_station.gd`. Bays run
  along Z, not X, because the walk lane travels +1.45 m in X and a mover has
  to clear a *seated* neighbour's 1.14 m clearance radius; see the
  [hall expansion verification](evidence/HALL-EXPANSION-VERIFICATION.md) for
  the measured pitch constraint and
  [full-cast verification](evidence/FULL-CAST-VERIFICATION.md) for the
  regression run at its full fourteen-mover scale.
- Existing desk, chair, terminal and robot anchors are translated by station.
- Each robot pulls its chair back, stands, follows its fixed lane, returns and
  sits. Their fixture states are independent of travel requests.
- Fixed lanes keep all fourteen robots separated. Visitor obstruction causes
  waiting and resumption when clear. This is local collision avoidance by
  stopping; general route finding and crowd simulation are not implemented.
- **A seated resident's chest motif is not visible from any camera position
  found in the hall, not only the overview's.** Each one's own terminal
  (wider than the chest-motif envelope) sits directly between the resident
  and any viewer while seated — every resident's normal resting state — and
  no seated angle tried gets past it. The motif becomes visible only once a
  resident stands and walks, and standing close enough to see it clearly
  puts the visitor inside a neighbouring resident's approach lane. The
  `Label3D` name tags do the identification work at any distance while
  residents are seated. See [full-cast verification](evidence/FULL-CAST-VERIFICATION.md)
  for the standing capture, the offline lineup render, and the open design
  question this raises.
- The courtyard connects through a flush east threshold, with a 6 × 8 m courtyard crop (X=6…12), a path, planting
  and an entrance sign. Cutaway visibility does not remove structural collisions. The courtyard translated
  +1 m in X to clear the enlarged hall's east wall (now at X=6); no courtyard module geometry was re-authored,
  only placements moved.
- Courtyard paving forms a **closed public loop** of eight tiles around a central
  planted island carrying the shade tree. Corner and T tiles share one grammar: a
  cobalt marker stud, a paved strip per open arm, and the sand base left showing on
  closed sides. All orientations come from `rotation_y`, not from separate meshes.
- A **cantilevered entrance awning** projects 2 m over 4 m of frontage with no post
  in the walkway; its underside stays at or above 2.44 m, clear of the 2.19 m
  doorway corridor.
- **Perimeter edge panels** run the north, east and south courtyard boundary, each
  with one continuous collision proxy so joins cannot be squeezed through. They make
  the boundary readable instead of an invisible wall; they never cross the route.
- The hall floor and courtyard path both finish at Y = 0. There is no threshold rise,
  so no ramp is present; a raised entry would need that deliverable re-specified.

## Editable sources

[Shared workshop source](source/shared-workshop.blend) contains the assembled
scene. Its new modular exports and placement/collision layout live in
[assets/workshop](godot/assets/workshop/). The
[shared manifest](shared-workshop-manifest.json) records recipes, exact exports,
placements and source hashes. The existing `source/work-bay.blend` and original
robot/furniture GLBs retain the PR17 checkpoint unchanged.

Rebuild only the new environment assets in a fresh Blender process:

```sh
blender --background --factory-startup --python-exit-code 1 --python scripts/build_shared_workshop.py
```

Authoring renders use Blender lighting; inspect Godot captures separately.
Append `-- --render` to regenerate the two authoring images. Runtime capture
commands are recorded in the verification report.

## Verification

```sh
npm ci --prefix tools
node scripts/validate_shared_exports.cjs
python3 scripts/test_shared_assets.py
python3 scripts/test_exports.py
```

Courtyard kit results, including the connectivity and clearance assertions added for
the loop, awning and railing, are in
[COURTYARD-KIT-VERIFICATION](evidence/COURTYARD-KIT-VERIFICATION.md).

The runtime tests originally covered two residents together; `shared_workshop_test.gd`
and `bay_pitch_test.gd` now exercise all fourteen (`scene.stations.size() == 14`,
and every resident in turn as the departing mover). Independent sample state,
separation, visitor waiting, the entrance route and reset/reduced-motion handling
are all still covered. Run commands and the two-resident-era measured results
are in [SHARED-VERIFICATION](evidence/SHARED-VERIFICATION.md).

The 12 × 16 m hall, widened roof bays, fourteen bay anchors and the +1 m
courtyard translation are recorded, with the measured bay-pitch constraint and
its permanent regression, in
[HALL-EXPANSION-VERIFICATION](evidence/HALL-EXPANSION-VERIFICATION.md) (the
milestone that reserved but did not yet occupy the twelve non-Kai/Lyra bays).
The twelve new appearances, all fourteen residents seated, the shared-rig
parity result at fourteen, the bay-pitch regression run at its full
fourteen-mover scale, and the runtime changes (controls panel, all-leave/
all-return, scene text) are recorded in
[FULL-CAST-VERIFICATION](evidence/FULL-CAST-VERIFICATION.md).
Offline walkthrough video is a visual artifact; live frame-time measurements
are recorded separately with machine, renderer, viewport and sample duration.
No performance budget or target-device guarantee is inferred from one machine.

## Acceptance boundary

**Only Kai's and Lyra's robot appearances have user approval.** The other
twelve residents' appearances — authored, exported, contact-checked and
Khronos-validated with zero failures — are not accepted by having been
built; each carries "operator review pending" in `character.RESIDENTS`. The
environment (hall, roof, courtyard) remains subject to visual review; the
courtyard kit modules are equally unreviewed. New tracker entries record
partial pilot progress, not acceptance of all sixty production deliverables.
The final city engine, live work feed and public accounts are separate
decisions.
