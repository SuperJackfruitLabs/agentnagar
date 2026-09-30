# Godot inspection scene

This is a local **sample-data** inspection pilot. It loads the six GLBs in
`assets/` and has no feed, auth, dispatch, or network integration. Godot's
Compatibility renderer is used for this pilot; it is not a product-engine
decision.

Godot 4.6.3 was used for the recorded local verification. From this directory:

```sh
godot --headless --editor --import --path . --quit
godot --headless --path . --script res://tests/fixture_test.gd
godot --headless --path . --script res://tests/import_test.gd
godot --headless --path . --script res://tests/scene_test.gd
godot --headless --path . --script res://tests/movement_test.gd
godot --headless --path . --script res://tests/journey_test.gd
godot --path .
```

The import step is required after rebuilding GLBs. The committed `.glb.import`
sidecars turn off automatic LOD generation because these small disconnected
voxel cubes lose detail with generated LODs.

Controls: `O` overview, `F` first person, `WASD` move, mouse look after capture,
`Escape` release the mouse, `R` reset, `T` text description, and `M` reduced
motion. The controls panel has keyboard-focusable buttons. At narrow widths,
the panel stacks beneath the persistent sample-data notice; a separate button
shows or hides the panel so the world remains visible.

The fixture buttons are fictional states. Working may play `typing`; idle,
stale, unavailable and unknown play `seated_idle`. Reduced motion jumps to the requested stable desk/floor destination and holds
the appropriate seated/standing frame still. Animation inspection is explicitly labelled as a
manual clip preview. The scene shows missing imports instead of substituting
geometry or implying verified work.

For repeatable screenshots, run in a **graphical** session. The capture option
seeks the active clip to 0.4 seconds, writes a PNG and a measurement JSON beside
it, then exits. Headless display servers cannot render this PNG.

```sh
godot --path . -- --capture="$PWD/../evidence/godot-overview.png"
godot --path . -- --camera=first_person --capture="$PWD/../evidence/godot-first-person.png"
godot --windowed --resolution 360x640 --path . -- --capture="$PWD/../evidence/godot-360.png"
```

The JSON records one local startup frame's draw calls, primitives, static
memory, and node count. It is not a target-device performance benchmark.


Choose Kai or Artistic Lyra, then Leave desk / Return to desk. Movement is a
fixed demonstration route with chair pullback, one-shot stand/sit clips and
0.54 m/s walking; fixture state alone never requests movement. Only one robot
occupies the bay. Reset, resident changes and manual inspection cancel travel.
The runtime and authored clips share exact anchor and root-offset contracts in
`../../../docs/superpowers/plans/2026-09-22-voxel-movement-and-lyra.md`.

Use `--resident=lyra --motion-time=1.3 --capture=/absolute/path.png` for a
transition sample. Use `--resident=lyra --capture-cycle=/absolute/workspace/frames`
for a complete 24 fps leave/return sequence. Fixed-step capture evaluates the
same blend and motion logic as live playback; it is not a frame-rate benchmark.
