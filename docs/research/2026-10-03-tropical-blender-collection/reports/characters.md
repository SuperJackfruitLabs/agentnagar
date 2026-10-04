# Original tropical characters

Two original, editable Blender character models and rigged GLB exports, constructed directly from the new resident and A1 reference sheets. No legacy builder or geometry was copied; no downloaded models, image textures, purchases, or paid generation APIs were used. The source repository remained read only.

## Files

- `scripts/build_characters_complete.py`: original geometry, weights, 17-bone rigs, clips, exporter and Blender reimport validation.
- `assets/lowpoly_tropical/character_human.{blend,glb,json}`
- `assets/lowpoly_tropical/character_robot.{blend,glb,json}`
- `reports/characters-glb-checks.json`: GLB geometry, weight and hierarchy checks.
- `reports/characters-reimport-validation.json`: measurements of evaluated reimported clips, including hand motion and floor contact.

| Character | Height | Triangles | Editable component meshes | Skinned export meshes |
|---|---:|---:|---:|---:|
| Resident | 1.788m with hat | 3,526 | 83 | 11 |
| A1 robot | 1.640m | 2,742 | 58 | 6 |

Human triangle count includes all four alternative hair meshes even though runtime displays one. It is 17.5% above the historical 3,000 target to retain face details, hands, collar, hat and backpack. Robot is below the historical 2,800 target. These counts measure geometry, not rendering performance.

## Visual construction

The resident has deliberate jaw/cheek/temple head rings, protruding nose planes, almond eyes with irises and glints, subtle eyebrows and smile, warm brown skin, ivory short-sleeve linen with an open spread collar, olive trousers, leather shoes, a honey sunhat, and a terracotta backpack with real straps, flap and buckle. Four hair silhouettes provide short, swept, curled and tied-back variants. The adult proportions follow the reference rather than a toy-sized head.

The A1 uses separate warm ivory torso, hip and limb shells over visible graphite joints. Olive belly, ear and knee panels, a recessed dark faceplate, two softly emissive round eyes, articulated hands and an actual folded golden leaf badge preserve the reference's friendly civic identity. Its shells are rigidly weighted; the resident's shoulders, torso and trouser knees use explicit blended vertex weights.

## Runtime contracts

The GLBs retain exactly the required mesh names: human `skin`, `top`, `bottom`, `shoes`, `details`, `hair_0` through `hair_3`, `hat_sun`, `backpack`; robot `shell`, `panel`, `joint`, `face`, `eyes`, `badge`. Skeletons are named `rig_human` and `rig_robot`.

Both use the baseline's 17 bone names: `hips`, `spine`, `chest`, `neck`, `head`, paired `upper_arm`, `forearm`, `hand`, `thigh`, `shin`, and `foot`, with `_l`/`_r` suffixes. These names were read as contract metadata from existing GLBs, without reading or copying geometry. Runtime consumption was checked in `city/godot/styles/pack_3d.gd`: painting and visibility depend on mesh names, and animation selection depends on the four exact clip names.

The skinned mesh nodes are scene roots with identity local transforms, while the skeleton remains a separately named rig root. This avoids glTF's non-root-skinned-mesh warning. Every mesh retains its skin relationship and armature modifier after Blender reimport.

## Clips and checks

- `idle`: three-second breathing/head-motion loop.
- `walk`: one-second opposite-leg/arm loop with knee flexion and per-frame root-height compensation measured from the evaluated shoe soles.
- `sit`: two-second seated breathing pose, pelvis approximately 0.54m above the floor, thighs extending forward with slight decline, shins vertical and feet planted.
- `typing`: seated working pose with raised forearms and alternating wrist movement, 1⅓-second loop.

All clips are sampled at 24fps, repeat their endpoint, and export 51 transform channels. Every vertex has normalized bone weights; human minimum/maximum sums differ from 1 only by floating-point rounding, and robot sums are exactly 1. No unweighted vertices and no zero-area GLB triangles remain. Collapsed bevel faces on thin panels were welded/dissolved before final export.

The separate Blender reimport check verifies all 17 bones, all four clips, all 11/6 skinned mesh parts, normalized weights, moving evaluated hand positions, and the seated hip translation. Sampled lowest geometry points are 1mm above the floor for walking/sitting/typing and human idle; robot idle is 1.5mm above the floor. The animation is genuine skin deformation and bone transforms, not a set of baked pose meshes.

The parent owns GPU rendering, visual acceptance and Godot runtime tests. The supplied quantitative checks do not substitute for final visual review. Feet are contact-compensated for an in-place game walk; this is an authored stylized cycle rather than motion capture or a full locomotion/IK system. Fingers share hand bones and have no individual finger controls. Backpack and hat follow their parent body bones; cloth simulation is intentionally absent.

## Reproduction

```sh
blender -b -t 2 --python scripts/build_characters_complete.py
blender -b -t 2 --python scripts/build_characters_complete.py -- validate
```

Pass `-- human` or `-- robot` to rebuild one character. Preview only `hair_0`; the runtime itself selects one of the four hair variants and toggles hat/backpack according to appearance rules.

## Final review status

Small front-facing hero images were visually inspected: both characters retain coherent adult/humanoid proportions, identifiable friendly faces, complete hands/feet and the requested clothing/panel details. Parent is producing larger correctly framed hero/rear/front images and pose proof. No static geometry revisions were indicated by the initial images.

The final sit clip lowers the forearms onto the upper thighs: reimported wrist heights are approximately 0.643m for the resident and 0.602m for A1. Floor contact remains 1mm. Game exports were frozen after this revision.

`reports/character_human-pose-proof.{blend,glb}` and the robot equivalent are four-pose scenes generated by evaluating the **shipped GLBs after reimport**. Left to right: idle, walk at frame 7, sit, typing at frame 9. They omit hidden hair alternatives. These static proof scenes are separate from game exports and can be regenerated using `-- pose-proof`; they do not replace the genuinely animated GLBs.
