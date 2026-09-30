# Voxel pilot verification — 2026-09-22

Current revision: **pilot-r003-movement-duo**. Two robots use one local sample-data
inspection bay. The user approved Kai’s robot appearance at r002; Lyra and the
movement extension await user visual review. This is not acceptance of the
complete fourteen-character Guild scene. No live services were exercised.

## Asset pipeline

Blender **5.2.2 LTS**, original procedural geometry, one shared 16-bone rig and
seven actions. Exact source, recipe and export hashes are in the
[manifest](../asset-manifest.json). Both character GLBs contain the same bind
structure, inverse-bind matrices and animation channel bytes. Their meshes,
materials and accessories differ. Kai retains the engineering apron; Lyra uses
GR05 colour panels, sketch sheets and distinct casing trim.

| Export | Size (bytes) | Triangles | Khronos errors / warnings |
| --- | ---: | ---: | --- |
| Chair | 10,348 | 120 | 0 / 0 |
| Desk | 22,868 | 300 | 0 / 0 |
| Environment | 229,444 | 4,440 | 0 / 0 |
| Kai | 158,412 | 804 | 0 / 0 |
| Lyra | 159,484 | 816 | 0 / 0 |
| Terminal | 37,040 | 576 | 0 / 0 |
| **Total** | **617,596** | **7,056** | **0 / 0** |

These are file and mesh counts, not performance budgets. See
[export-metrics.json](export-metrics.json). Khronos `gltf-validator`
**2.0.0-dev.3.10** is pinned by package lock; the six retained reports show zero
errors/warnings. The validator command rejects either. Six export contract tests
pass, including portable skin hierarchy, outward winding, anchors and shared
rig/animation equality. New assertions first failed on missing Lyra and the two
missing transition clips, then passed after implementation.

## Animation and contact measurements

[contact-check.json](contact-check.json) samples every authored frame of all
seven clips on both evaluated meshes: **878 samples, zero failures**.
Checks include foot soles within 8 mm of ground during stance, seated hips at
0.48 m, typing hand/keyboard XY overlap and palm clearance, and planted-foot
movement below 3 mm during sit/stand and walk stance. The maximum measured
planted-foot drift is 0.00000006 m.
These are vertex-bound contact checks, not exhaustive continuous collision proof.

- Walk: 32 frames at 24 fps, 0.72 m full stride, **0.54 m/s** route speed.
- Sit-down / stand-up: each **1.333333 s**, non-looping. Root translation follows
  the knee arc so feet remain planted. Standing root offset is 0.3363034344 m.
- Chair pulls back 0.65 m before standing; sitting reverses the sequence before
  the chair slides in. The runtime compensates the authored root offset at the
  transition boundary. Idle/walk starts use a 0.12 s blend.
- The controller follows fixed waypoints outside the desk; it is not general
  navigation or dynamic obstacle avoidance. Rotations are short in-place turns.

The first gait test caught the foot bone’s opposite local X axis; correcting
its compensation brought every stance sample within tolerance. Earlier pilot
repairs (floor overlap, typing fit, and outward face winding) remain covered.

## Runtime and visual evidence

Godot **4.6.3**, Compatibility renderer, local Linux graphical session. All five
suites passed: `fixture_test.gd`, `import_test.gd`, `scene_test.gd`,
`movement_test.gd`, `journey_test.gd`. They cover real imported clips and poses,
loop progress beyond the first cycle, transition endpoints, both residents,
frame-partition independence, repeated commands, missing imports, cancellation,
reset and reduced motion. A 150-frame comparison checks that fixed-step capture
and live stepping evaluate the same blended poses. The 34 existing repository
Python tests also pass.

- [Kai authoring detail](blender-detail.png), [Lyra authoring detail](blender-lyra.png),
  [shared workshop render](blender-work-bay.png).
- [Kai runtime](godot-overview.png), [Lyra runtime](godot-lyra.png),
  [mid stand-up](godot-standing-up.png), [first-person](godot-first-person.png),
  [360 px layout](godot-360.png).
- [Kai complete journey](kai-desk-cycle.mp4), [Lyra complete journey](lyra-desk-cycle.mp4):
  each 456 deterministic rendered frames at 24 fps (19 s). These show departure,
  walking around the desk, return, sitting and chair movement. They are offline
  playback evidence, not real-time device benchmarks.

[Overview metrics](godot-overview.json) record a single startup frame. Both
residents are loaded but only one is shown. Imported cube LOD generation remains
disabled; the preview uses ambient/key/fill lighting without directional shadows.
Blender and Godot have different lighting. All on-screen states are explicitly
fictional; fixture state does not trigger movement, and working only types at
the desk. Reduced motion jumps to a stable destination and holds the pose.

Independent asset/runtime reviews identified the walk-start pose difference
(handled by blending), title-layout regression (fixed), and blanket appearance
review metadata (corrected to distinguish approved Kai from pending Lyra).
No open substantive code-review findings remain.

## Remaining production scope

- User review of Lyra and both complete motion cycles; full-cast compatibility.
- Dynamic navigation/obstacle avoidance, richer turns and transition polish.
- Complete workshop/courtyard, remaining Guild appearances, production UI/audio.
- Sustained performance on chosen target devices and agreed budgets.
- Real public-state integration, identity, comments/moderation and asset licence.

Blender CLI is verified; interactive Blender MCP adoption is not claimed. Godot
runtime verification uses the CLI. Publishing this checkpoint does not merge it
or accept all sixty production deliverables.
