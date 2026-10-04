# Tiered fountain flow — Godot 4.6.3

A four-second looping effect for the Codex tropical fountain. The GLB and editable Blender geometry remain unchanged. **The animation is a Godot shader plus a small GDScript splash controller; it is not embedded in the GLB or Blender file.**

Features: downward-travelling foam highlights, subtle lateral stream movement, pool ripples, an upward central-jet phase and 40 tiny faceted landing droplets. No textures, simulation cache or paid tools. Droplets add 320 triangles in one MultiMesh draw; existing water surfaces receive five shader materials. Runtime performance was not benchmarked.

## Use

Copy this directory into a Godot project, e.g. `res://addons/fountain_flow/`. Instantiate the delivered `assets/lowpoly_tropical/fountain.glb` normally, then call:

```gdscript
const Flow = preload("res://addons/fountain_flow/fountain_flow.gd")

func _ready() -> void:
    var effect = Flow.attach($Fountain)
```

`$Fountain` must be the instantiated GLB root, containing the named `water` mesh. It can be attached before or after entering the scene tree; playback begins when it enters. Attach is idempotent. Geometry stays in local metres so the normal game placement scale works. `Flow.supports(model)` identifies this exact tropical fountain by its water materials; use it when working with several styles. `effect.playing = false` pauses, and `effect.set_time(seconds)` scrubs or captures deterministically. Default playback starts automatically.

The isolated game in this study installs the effect from `Pack3D._scene()` after instantiation. `integration.patch` records the small hook against the original source. It checks `supports` so other style fountains are left alone. This repository addition preserves the adapter as a candidate and does not apply the hook to the active game.

## Evidence

`../../renders/fountain-flow.mp4`: 120 frames, 30 fps, 960 × 960, captured from the actual Godot implementation. The original study recorded matching loop endpoints and verified splash motion, material isolation and duplicate-attachment protection with a real rendering backend. Those local runtime checks are historical evidence; the standalone test harness is not included here.

The flow is deliberately stylized and lightweight. It is not a fluid simulation, does not add audio, and has not been integrated or deployed into the source game.
