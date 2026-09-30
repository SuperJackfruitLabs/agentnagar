# Verification record

Date: 2026-09-17. This is evidence for this reference character and these tool
versions, not a general compatibility or performance guarantee.

## Original interactive experiment

The modeling, hand revision, rigging, animation, render and export steps were
executed through the community Blender MCP server against Blender 5.2.2 LTS.
The original application scene was retained. The hands and sampled wave
poses were inspected in rendered images; the included MP4 is a Blender
Workbench preview, not a Godot capture.

Each refined hand had 23,184 base vertices, one connected component and zero
non-manifold edges. Rigging produced 40 bones and 52 bound meshes with
normalized vertex weights. `Wave_Hello` runs for four seconds and returns to
the neutral pose. The MP4 has 48 frames at 12 fps, 630 × 700 pixels.

## Portable reference verification

The committed step scripts were replayed from a factory-startup Blender
process into a fresh output directory. The geometry, topology assertions,
weight assertions, rig, named animation, character-only GLB export and saved
Blender asset were reproduced. The final asset packages only the two study
scenes and dependencies, excluding saved UI and cached brush-library paths.
The compressed asset was decompressed before checking for private machine
paths. Optional Cycles stills were skipped during
replay. The MCP runner was separately exercised against the connected
Blender session using `export-wave` and a different temporary destination.

The generated GLB was imported into Godot 4.6.3 and tested with the included
`godot-check/check.gd`. Measured output:

```json
{
  "result": "PASS",
  "animation": "Wave_Hello",
  "bones": 40,
  "mesh_count": 52,
  "duration_seconds": 4.0,
  "hand_travel_m": 0.754530668258667,
  "wrist_wave_radians": 0.428384989500046,
  "return_error_m": 0.0
}
```

The script checks hand displacement exceeds 0.4 m, sampled wrist rotation
exceeds 0.1 radians, and the ending hand position is within 0.01 m of the
start. A negative check removed one mesh from a temporary export; the same
verifier exited with status 1 and reported 51 meshes instead of 52.
This establishes imported bone animation, not visual skin-deformation
quality or runtime performance in a populated city.

Khronos `gltf-validator` 2.0.0-dev.3.10 reported **zero errors** and 52
`NODE_SKINNED_MESH_NON_ROOT` warnings: the skinned meshes sit beneath the
identity armature node, whose parent transform does not control skinning.
Unused UV attributes produced informational notices. The GLB has one scene,
one named animation and 395,308 triangles. These warnings and the dense mesh
remain documented limitations, not a warning-free or optimized release claim.

## Reproduction limits

- Tested with Blender 5.2.2 LTS, Godot 4.6.3 and MCP Python client 1.29.0.
- The original MCP server installation had a local disabled-telemetry fix;
  this repository does not distribute or install that infrastructure patch.
- `-noaudio` is used for headless replay: audio is unnecessary here and the
  restricted-environment runs stalled during audio shutdown after producing
  the assets, including with audio disabled. A fresh replay outside that
  sandbox completed normally with exit code zero.
- Preview media was retained from the original visually reviewed experiment.
  The editable Blender asset was regenerated using the portable replay.
- Browser/mobile performance, arbitrary-character rigging, IK, facial
  animation, multiplayer and deployment were not tested.
