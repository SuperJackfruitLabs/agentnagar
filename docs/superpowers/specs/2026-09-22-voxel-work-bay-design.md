# Voxel work-bay pilot

Approved direction: the user selected Voxel and said “Begin” after the proposed
Blender → GLB → validator → Godot work-bay test. This authorises the local pilot.

## Scope and visual direction

One original Coder Kai appearance, chair, desk and terminal in a small open
workshop bay. Use style `02-voxel`: city r004, living r002, creating r002,
interfaces r003. In particular use the living sheet's WORKSHOP material/block
language and the CONVERSATION robot design. The user confirmed that agent
appearances must be robotic. Kai has a white shell, dark screen face with green
chevron eyes and a smiling mouth, mechanical joints, and a tool apron with
cobalt/orange details. Human skin, hair and facial anatomy are excluded.
Kai has an individual identity within the A1 robot design grammar. The excluded
humanoid experiment supplies no geometry, rig, proportions or animation.

Use stepped silhouettes, warm wood, cream structure, cobalt accents, orange
tools and emerald foliage. All geometry and animations are authored locally by
Blender Python. Editable sources and five GLB exports are retained. No purchased
assets, external fonts, private content or network-dependent preview.

## Interface between asset and runtime tasks

Root: `prototypes/voxel-work-bay/`. Exports in `godot/assets/`:
`environment.glb`, `desk.glb`, `chair.glb`, `terminal.glb`, `kai.glb`.
Coordinates after GLB import: metres, Y up, ground Y=0. Character faces +Z.
Environment ground 8 × 6 m, rear wall Z=-2.8, left wall X=-3.8, open front.
Desk width 1.8, depth .8, top height .78, origin ground centre. Chair seat .48,
front +Z. Runtime positions desk at (0,0,0), chair and Kai at (0,0,-.65),
terminal at (0,.78,.12). Terminal screen faces -Z toward seated Kai, keyboard
extends toward -Z. Character standing height about 1.73 m including the top casing accent.
Kai exports looping clips `idle`, `walk`, `seated_idle`, `typing`, `attend`.
Seated clips place hips/feet to meet chair and desk; runtime need not guess
bone transforms. Environment includes scenery and its own preview lighting is
provided by runtime. No Blender cameras/lights in exports.

## Runtime and status

Godot compatibility renderer with an overview camera and optional first-person
WASD navigation, mouse look, Escape release, reset, keyboard-operable controls,
an equivalent text description/status view and reduced-motion control. Buttons
switch fixture states: working, idle, stale, unavailable, unknown. A persistent
SAMPLE DATA notice remains visible. Stale/unknown/unavailable stop typing. An
animation inspection selector may explicitly preview any clip without implying
real work. No agent dispatch, auth or live services.

## Acceptance

Rebuild source and exports with a documented command. Run Khronos validation
on every GLB, then import and test in Godot. Check actual animation import,
fixture transitions and text alternative using a headless test script. Capture
a real rendered scene; inspect scale, silhouette, furniture contact, clipping,
screen orientation and labels. Measure the local pilot without presenting the
machine as an approved target device. Record hashes, versions, results and
remaining limitations. Keep the 60-item tracker unaccepted; this partial pilot
does not test all fourteen appearances. User visual approval remains pending.


## Approved extension — 2026-09-22

After approving Kai’s robot appearance, the user requested sit/stand and travel
to the desk, then a second robot to verify the shared rig, followed by pushing
a checkpoint PR. The [movement and Lyra plan](../plans/2026-09-22-voxel-movement-and-lyra.md)
supersedes the initial one-character/five-clip scope: six GLBs include both Kai
and Artistic Lyra; seven shared clips include sit-down and stand-up. The same
bay is inspected with one selected resident at a time. The chair moves back
before standing and slides in after sitting. A fixed path clears the desk.
General navigation and the remaining twelve appearances are outside this step.
No merge is authorised. Lyra’s individual appearance remains pending review.
