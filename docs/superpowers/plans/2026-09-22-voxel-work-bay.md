# Voxel Work Bay Implementation Plan

**Goal:** Deliver an editable voxel asset set and working local inspection scene.
**Architecture:** Blender scripts generate separate GLBs; Godot assembles and
exercises them; evidence records actual export and runtime results.
**Tech Stack:** Blender Python, glTF/GLB, Khronos validator, Godot/GDScript.
**Spec:** ../specs/2026-09-22-voxel-work-bay-design.md

## Global constraints

Use `02-voxel` pinned references, original Kai design and sample state only.
Never use the humanoid experiment. Match the spec's coordinate/asset contract.
Work only in the isolated pilot branch; no publication or merge.

### Task 1: Editable assets and exports

- [x] Create `prototypes/voxel-work-bay/scripts/build_assets.py` plus focused
  geometry/character helpers, source `.blend` and `godot/assets/*.glb`.
- [x] Generate five clips, shared palette, anchor metadata and build manifest.
- [x] Inspect actual renders and fix geometry/furniture fit.
- [x] Validate all exports with Khronos; preserve validation reports.

### Task 2: Runtime inspection scene

Own `prototypes/voxel-work-bay/godot/` except its `assets/` directory.
Consumes the exact five GLBs and coordinate/clip contract in the spec.
Produces `project.godot`, main scene/scripts and a runnable headless smoke test.

- [x] First write runtime tests for fail-closed fixture transitions, reduced
  motion and imported animations. Observe failures before implementation.
- [x] Implement overview and first-person controls, collisions, fixture state,
  readable responsive UI, keyboard controls and text alternative.
- [x] Use sample labels persistently; inaccessible feed states cannot animate
  verified work. Capture script permits repeatable runtime screenshots.
- [x] Import GLBs, run headless smoke tests and render locally.

### Task 3: Integration, evidence and documentation

- [x] Reconcile actual exports with runtime; check screenshots and contacts.
- [x] Record versions, hashes, validator output, runtime results and limitations
  in `prototypes/voxel-work-bay/evidence/` and `README.md`.
- [x] Link the pilot from root documentation and asset tracker, record Voxel
  selection and pilot-only status without claiming full asset acceptance.
- [x] Run existing tests, new smoke checks, link/whitespace checks and review.

## Progress

Baseline: upstream `7700357`; 34 existing Python tests passed.
Ruling: use the already-approved local pilot scope without another approval
round. Godot selection applies to the pilot; final product engine is undecided.

Completed locally: original asset source/export pipeline, Godot inspection scene,
review corrections and verification evidence. Five export contract tests, three
Godot smoke tests and 34 existing Python tests pass. Operator art acceptance
and final product-engine choice remain open; no merge or publication.
