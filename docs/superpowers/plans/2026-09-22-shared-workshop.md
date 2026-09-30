# Shared Voxel workshop and courtyard plan

**Goal:** A walkable, modular workshop/courtyard with Kai and Lyra present simultaneously, independently working and moving safely; measure the scene and publish the next PR.
**Approval:** User approved the proposed next milestone with “Go ahead.” This is a local sample-data scene, not a live city rollout or permission to merge.
**Base:** merged PR17, `635b879`, isolated `feat/shared-voxel-workshop`.
**Workflow:** superpowers:subagent-driven-development; asset and runtime tasks have separate ownership and a fixed interface. Root integrates, reviews and publishes.

## Layout and interface contract

The existing one-bay scene remains runnable. Add `godot/shared_workshop.tscn` and its own focused scripts; load with `godot --path godot res://shared_workshop.tscn`. Reuse the existing Kai/Lyra, furniture GLBs and movement_controller.gd without changing their bind poses or clip/anchor contract.

- All layout coordinates are glTF/Godot metres, Y-up; +X east, -Z north. Floor top Y=0, workshop footprint X[-5,5], Z[-4,4]. A single low rectangular hall with exactly THREE stepped sawtooth roof bays; east entrance centred `(5,0,1)` opening1.4m wide and2.2m high. No additional district/library/tower reproduction is claimed.
- Stations: Kai origin `[-2,0,-0.8]`, Lyra `[2,0,-0.8]`. Existing desk/chair/terminal/robot positions and movement routes are translated by these station origins. Both residents exist at once with independent fixture/movement state. Their fixed routes stay separated; no general dynamic pathfinding claim.
- Courtyard east X[5,11] (final six-metre tile crop; original planned bound X=12), Z[-4,4]; path centres `(6,0,1),(8,0,1),(10,0,1)`, optional corner/branch. Tree near `(9,0,-2)`, planters clear of the entrance path; sign beside east door. Visitor starts `(8,0,1)` facing west through the doorway. Flush threshold, no traversal step above5cm.
- New GLBs under `godot/assets/workshop/`; new editable `source/shared-workshop.blend`; `shared-workshop-manifest.json`; layout at `godot/assets/workshop/layout.json`.
- Layout schema: `version:1`, `bounds:{min:[-5.3,0,-4.5],max:[12.5,4,4.5]}`, `stations:[{resident,origin:[x,y,z]}]`, `instances:[{id,asset:"workshop/name.glb",position:[x,y,z],rotation_y:degrees,group:"structure|roof|front|courtyard|decor"}]`, `collisions:[{id,position:[x,y,z],size:[x,y,z],rotation_y:degrees}]`. Collision transforms are WORLD coordinates. Individual wall/opening colliders preserve window/door openings. Solid structure is still collidable in cutaway mode. All static collision boxes emitted by builder must correspond to visible structure; no invisible wall across the doorway. Root and runtime may add instantiated workstation and actor collision shapes.
- Instance roof/front groups hide in cutaway overview. Provide exterior/roof and first-person views. First-person player uses collisions and can enter/exit the east door. UI must leave both robots visible and have keyboard access, text scene/status view, persistent SAMPLE DATA, and narrow360px layout.
- Robot motion pauses safely for a visitor in its swept path, resumes when clear, and records a waiting status. Prevent inter-robot overlap; fixed lanes plus continuous/swept checks are acceptable. Do not change sample work state merely because a motion is paused. Reset/reduced-motion transitions must leave valid endpoints and both actors independently usable.

## Task 1 — environment assets (asset agent)

Own new `scripts/shared_workshop.py`, `scripts/build_shared_workshop.py`, `scripts/test_shared_assets.py`, `source/shared-workshop.blend`, `shared-workshop-manifest.json`, `godot/assets/workshop/`, authoring screenshots under `evidence/shared-*`. Do not modify existing robot/furniture scripts or runtime GDScript.

- [x] Inspect selected Voxel city r004 and living r002 images/prompt/review. Use workshop sawtooth roof, warm wood, cream/cobalt/yellow and greenery; preserve robotic resident authority.
- [x] Author reusable2m floor/wall/window/door modules, one repeatable sawtooth roof bay (3.333m×8m), shared workbench/shelf, path, planter, shrub/tree and entrance sign. Do not duplicate geometry per placed tile. Export each GLB and layout as above. Build a coherent workshop/courtyard, including two shared furniture stations in editable source.
- [x] Include new factory-style source scene with both reused robots in seated poses; no editing original assets. Generate full exterior and cutaway authoring renders. Source renderer is not runtime evidence.
- [x] Tests for actual GLB geometry/outward winding, modular dimensions and door clearance/layout/three roof instances, source/export recipe hash manifest. Run failing layout/export tests before build then passing tests after.
- [x] Report manifest/asset count/sizes, layout decisions and remaining limitations; no commit/push.

## Task 2 — simultaneous runtime (runtime agent)

Own `godot/shared_workshop.tscn`, `godot/shared_workshop.gd` and focused new helper/test scripts. Existing one-bay code must continue to pass; prefer reuse of movement_controller/fixture classes rather than modifying old main.gd. Do not alter raw GLBs or layout owned by asset agent. May create import sidecars once assets ready.

- [x] Use layout contract to build visible instances/static collisions and two station actors with independent fixture/movement/controllers. Write meaningful tests first: simultaneous complete cycles, actor separation/swept obstacle checks, doorway traversal, visitor pause/resume, fixture independence, reset/reduced motion, missing assets and root-offset transitions.
- [x] Implement both present together, controls for both/all journeys and independent sample states, chair collision movement, useful labels and accurate text description. Use existing fixed gait/seat animation contract and actual looping/blend behavior.
- [x] Add overview cutaway / roof exterior / first-person controls and persistent sample notice;360px controls collapse/scroll. Handle live visitor obstacles by waiting safely; prove swept checks with larger delta. Avoid expensive rebuilding every frame.
- [x] Deterministic graphical capture for stills and walkthrough video with BOTH robots operating; use same stepping/blends as live. Include courtyard/entrance/interior views. Measure draw calls, primitives, nodes, asset bytes and real live frame timing separately from offline capture. Capture reports must state device/renderer/viewport, duration/samplecount and limits.
- [x] Run current five Godot suites plus new shared workshop tests; tell root when ready for final captures. No commit/push.

## Task 3 — root integration, review and publication

- [x] Validate all new GLBs using pinned Khronos and shared module tests. Verify source/layout manifest hashes and original assets unchanged. Inspect exterior/cutaway/first-person views and both robot cycles; fix concrete problems.
- [x] Run representative live sampling (for example30 seconds after warmup) and record percentiles without inventing device budgets or performance acceptance. Include actual machine/renderer details and distinguish offline video from live timing.
- [x] Add current run instructions, evidence summary and tracker updates with partial scope. Preserve concept reference and full production acceptance distinctions.
- [x] Independently review assets/runtime, verify regressions and documentation links.
- [ ] Commit/push feature branch and open a PR against verified main; confirm exact remote head/checks. Do not merge.

## Additional approved scope

User requested the actual end-to-end asset/scene workflow in this PR. Added `prototypes/voxel-work-bay/ASSET_WORKFLOW.md` with tools, reference authority, reproducible recipes, runtime contracts, checks, review and checkpoint process.
