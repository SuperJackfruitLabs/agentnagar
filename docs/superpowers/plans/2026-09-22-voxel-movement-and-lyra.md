# Voxel movement and second robot implementation plan

> Use superpowers:subagent-driven-development for the independent runtime task and review.

**Goal:** Demonstrate a complete leave/return-to-desk cycle and a distinct second robot on the shared rig, then push this feature branch and open a PR.
**Architecture:** Blender exports Kai and Artistic Lyra with the same 16-bone skeleton and seven named clips. Godot coordinates a fixed safe workshop route, chair movement and non-looping seat transitions. A resident selector lets both characters use the same bay; both are visible in a comparison render.
**Tech Stack:** Blender 5.2.2 Python, GLB, Khronos, Godot 4.6.3.
**Spec:** Existing `../specs/2026-09-22-voxel-work-bay-design.md` plus the approved extension contract below.

## Approved extension contract

The user requested next steps 2 and 3, then step 1: movement, second distinct robot, then push/PR. Kai appearance is visually approved; Lyra follows GR05 reversible colour panels and sketch sheets. White shells/dark display/green expression remain shared Voxel agent grammar. No human anatomy, no humanoid experiment, no live data. No merge authorised.

The seat anchor is `(0,0,-0.65)`. Before standing, chair and seated robot slide to `(0,0,-1.30)` in 0.65 seconds. Both assets export `stand_up` and `sit_down`, each 32 frames / 24 fps = 1.333333 seconds. Rig Root translation is authored within the clips: seated vertical -0.29 m and forward 0; standing vertical 0 and forward `sqrt(.34*.34-.05*.05)` = 0.3363034344 m. The runtime instance stays at the pulled-chair anchor during transitions. Transition endpoint standing actor origin is therefore `(0,0,-0.9636965656)`. Switch to idle/walk at that world origin without a jump. Face +Z at the chair.

The route travels laterally from that origin to `(1.45,0,-0.9636965656)`, then to `(1.45,0,1.15)`, outside the desk footprint. Return reverses it, aligns +Z, plays sit_down at pulled-chair anchor, then slides chair and seated robot to normal desk anchor. Movement uses walk's measured stride/cadence (asset manifest records this), not arbitrary frame-dependent steps. Clip loop mode: only idle/walk/seated_idle/typing/attend loop; sit_down/stand_up are one-shot.

Only explicit demo controls request movement. Fixture states never imply navigation or live work. Working types only when seated. State changes during travel affect destination idle/typing safely. Reduced motion snaps to the requested stable destination, stops animation and cancels transitional motion; reset and resident switches cancel cleanly. Missing required clips/meshes cannot claim a successful motion. Repeated commands cannot overlap. Manual clip inspection is separate and cancels movement safely. Persistent SAMPLE DATA and accurate text descriptions remain.

## Task 1 — root: assets and proof of shared rig

Files: `scripts/character.py`, `geometry.py`, `build_assets.py`, `test_exports.py`, `check_contacts.py`, `validate_exports.cjs`, source/exports/manifest/evidence.

- [x] Extend export assertions to both Kai/Lyra, seven clips, equal skeleton bind structure and identical shared animation data; observe missing Lyra/transition failures.
- [x] Parameterise the existing robot builder by profile while keeping skeleton dimensions/bind poses equal. Lyra has reversible colour-panel vest, sketch-sheet pouch and distinctive head trim. Produce `lyra.glb` alongside `kai.glb`.
- [x] Author reversible 32-frame stand/sit curves: thigh angle interpolates 0 to `-pi/2+asin(.05/.34)`; opposing shin angle keeps feet level; root vertical `-.34*(1-cos(angle))`, forward `sqrt(.34*.34-.05*.05)+.34*sin(angle)` keeps feet planted. Blend upper arms/forearms between existing idle and seated idle. Endpoints match their stable poses.
- [x] Generate both characters from the exact same animation actions; do not accidentally export suffixed or duplicate clips. Record walk speed/stride and transition root offset in manifest.
- [x] Check evaluated foot contact throughout transitions, keyboard/seat contacts on both robots, export validity and source comparison renders. Render an actual animation capture for runtime integration.

## Task 2 — runtime agent: movement and resident inspection

Own `godot/` excluding GLB binary files; may edit `.glb.import` sidecars. Root owns all other scripts/docs/evidence until runtime capture handoff.

- [x] Read the contract above and existing main/fixture tests. Add a focused `movement_controller.gd` with deterministic phase progress and waypoints; test complete outbound/return cycles, elapsed-time independence, repeated commands, reduced motion, reset and cancellation before implementing.
- [x] Connect the shared controller to real imported actors and AnimationPlayers. Follow the exact clip/anchor contract above. Keep fixture status logic and route motion distinct; update chair collision with chair position. Do not loop transitions.
- [x] Add resident selector Kai / Artistic Lyra and explicit Leave desk / Return to desk controls. Only the selected resident occupies the bay; changing resident resets safely. UI and text name current resident and accurate phase; preserve 360 px usability.
- [x] Extend scene/import tests to both residents, one-shot clips, correct endpoints and actual runtime playback. Provide repeatable `--resident=lyra` and motion capture options for deterministic samples, including mid-transition and a complete cycle if possible.
- [x] Import and run tests using elevated Godot CLI (Flatpak sandbox otherwise fails). Coordinate when final GLBs are ready. Do not commit or write root-owned docs; report owned paths and results for root integration.

## Task 3 — root: integrate, review and publish checkpoint

- [x] Reconcile asset/runtime contract against real frames, inspect Kai and Lyra walking/sitting/standing and compare silhouettes, patch substantive issues.
- [x] Update tracker GS031 and shared animation evidence without claiming all fourteen accepted. Record user's Kai visual approval separately from broader acceptance.
- [x] Refresh manifest hashes, file sizes, real validation and runtime evidence; update run instructions and limitations.
- [x] Get focused independent review, run required existing/new checks, commit clean branch.
- Publication handoff: push `feat/voxel-work-bay-pilot`, open PR against verified default branch, verify remote head and checks, report PR link and any pending CI. Do not merge.

## Verification result

Six export tests, five Godot suites, 34 existing Python tests and 878 evaluated
contact samples pass. All six GLBs validate without errors or warnings.
Both 456-frame desk cycles were captured, inspected and encoded to 19-second
videos. Independent reviews have no remaining substantive code findings.
Publication status is recorded by the GitHub PR and final task report.
