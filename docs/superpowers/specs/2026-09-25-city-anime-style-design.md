# Cel-shaded anime style: design

Date: 2026-09-25. First of three independent style specs, after the walk-in-style work merged in PR #25. The next two are 09 Solarpunk retro-futurism and 10 Neon noir. Four mechanics follow in their own specs, each working in every style: map view, conversations, tram riding and rooftops.

## 1. Goal and success

This spec adds a fourth style pack, **Cel-shaded anime** (style study 06), alongside low-poly, voxel and pixel art. The references are the study's four sheets under `docs/vision/style-studies/styles/06-anime/sheets/`:

- city perspectives, revision r008;
- living and community, r003;
- creating and exploring, r002;
- interfaces, r004.

"Pixel perfect" means crisp, carefully made high-resolution art: no blur, no shimmer and no misplaced details. It does not mean a visible pixel grid.

The pack uses the same pack contract, the same city (`fixtures/district`), and the same controls and core rules. Only the look changes. The one exception is weather, which is added to the world for every style (section 5).

**Success is judged in two ways.**

1. **Sheet match.** The game's own captures are placed beside the sheet panels and inspected panel by panel. Each view is captured at 1920 × 1080 and composed by a reusable tool into `city/godot/evidence/anime-vs-sheet.png`, with the remaining gaps written up in `anime-notes.md`. The views are:
   - TOP-DOWN, DIAGONAL and STREET;
   - NIGHT AND RAIN, WATERFRONT PARK, WORKSHOP and GATHERING;
   - City Agent A1 and a resident, close up in first person.
2. **Performance, at 1920 × 1080 on the development laptop** (RTX 3070 Ti Laptop GPU, 360 Hz panel), measured as players run the game: vsync at the display's rate, 5 s per scene.
   - **Normal play: 360 fps.** This covers the three overhead presets and first person, with a crowd of 60. A scene passes when its frame rate is within 3% of what the same display gives an empty scene and it misses at most one point more of the refreshes than the empty scene does. (On this panel under COSMIC an empty scene reaches about 354–357 fps and misses about 1.8% of refreshes.)
   - **Floor: 240 fps.** This is the heaviest scene: street view at night in rain, with a crowd of 300.
   - The bench also reports each scene uncapped: frame-time p50 and p99, and the GPU's own time.

   *Amended 2026-09-25 (was: uncapped p99 ≤ 2.78 ms and ≤ 4.17 ms).* The uncapped p99 turned out to measure the desktop's presentation jitter as much as the game: an empty scene misses refreshes too. By then the three styles' GPU time was 1.1–2.1 ms and their frame rate matched the empty scene's. The user's own target was "360 fps in normal play, 240 floor"; the gate now measures exactly that.

   A benchmark tool enforces both limits. `check.sh` runs it whenever a display is available.

## 2. Rendering

**Choice: the hybrid approach.** Characters get stable, controlled shader outlines. The city gets one screen-space line pass. Everything shares the same toon lighting.

- **Toon materials.** Toon lighting uses Godot's native `BaseMaterial3D` modes rather than custom shaders:
  - `DIFFUSE_TOON`, with a low roughness for a crisp light-to-shadow step;
  - `SPECULAR_TOON`, for the small highlight bands the sheets show on glass, metal and hair;
  - rim light;
  - shadow colour from a cool indigo ambient, which gives the sheets' bluish shadows.

  Converting in place keeps the material objects that night lighting already drives (the `KitTown` glass and lamp lists). `Pack3D` gains one virtual hook, `_style_node(node)`, which it calls after:
  - `build_world`;
  - `build_scenery`;
  - `make_occupant`;
  - every `_paint` call.

  It does nothing by default. The anime pack implements it with a `Toon` helper that converts every `BaseMaterial3D` under a node exactly once.
- **Character outlines.** Each character material gets a `next_pass` inverted-hull material:
  - it grows along normals, culls front faces and is unshaded;
  - it draws in the part's ink colour (a darker, cooler tone of the fill, never pure black);
  - its width is scaled with camera distance by a small spatial shader, so lines stay about 1.5 px wide from overhead and do not balloon in first person.

  Faces get only a silhouette line; features are drawn in the face texture.
- **City lines.** One full-screen line pass for the city:
  - a quad in front of the active camera, with a spatial shader that reads `hint_depth_texture` and `hint_normal_roughness_texture`;
  - it draws ink where depth or normals change sharply;
  - lines fade with distance so the far city does not shimmer;
  - it is one pass at 1080p whatever the scene holds, and the camera rig owns it.
- **Anti-aliasing.** 4× MSAA for crisp geometry edges, with no temporal AA, which would blur. The line pass must be verified under MSAA before the rest is built on it (plan task 1).
- **Light.**
  - Day: a warm sun, bright sky and the sheets' palette of warm whites, blues, indigo and vermilion.
  - Night: the same toon shading, lit by lamps and glowing windows.
  - Clouds are soft white toon shapes.
- **Water.** Toon water: flat bands of blue, with bright sparkle lines scrolled by a shader.

## 3. The anime kit

A new generator, `city/tools/styles/anime/`, builds the kit into `city/godot/styles/anime_cel/assets/` with Blender scripts. It is reproducible and specified like the other kits:

- `specs/*.json` give each asset's size, triangle budget, node names and animations;
- `test_assets.py` checks every reference, spec and validator result, and `check.sh` runs it.

The kit covers the pieces the sheets show:

- **Workshop:** red-brick sawtooth hall bays, with tall black-framed windows and steel roof glazing.
- **Library:** a silver barrel-vault reading room, with a two-storey glazed arcade.
  - The manifest's roof `dome` is drawn as the sheets' vault. The layout contract says "rounded reading-room roof".
- **Towers:** glass towers with planted roof terraces, for the downtown blocks.
- **Blocks:** houses and shops with balconies and shopfronts.
- **Street pieces:** paving, kerbs, road and markings.
- **Water and bridge:** a three-arch stone bridge.
- **Tram:** cream with a coral stripe.
- **Plants:** broadleaf trees (the square's great tree first), palms and shrubs.
- **Props:** lamps, benches, umbrellas, bollards and planters.
- **Interiors:** the workshop (workbenches, pegboard, pendant lamps) and the library (shelves, reading tables).
- **Railings:** the fence module.

## 4. Characters

People and agents are full anime characters.

- **Rig and motion.** They reuse the low-poly kit's shared rig and its generated clips, so walking, sitting, typing and idling behave exactly as they do in every style: walk, idle, sit and typing. The anime generator imports those functions and does not copy them.
- **Body.** The meshes are new, with anime proportions on the same skeleton: a larger head, slimmer limbs and smooth shading.
- **Clothes.** The eight outfits' everyday layers: shirts, jackets, hoodies, trousers, skirts and backpacks. The existing look rules hold (`test_looks.gd`): outfit k, hair style h, and the colour lists. A person looks the same in every style.
- **Hair.** Four styles built from swept, tapered locks, each with its own hull line. They map to the existing hair indices 0–3.
- **Faces.** Faces are crisp vector art, drawn by the generator at 4× and downsampled into an expression atlas.
  - Expressions: neutral, smile, talking, surprised and blink.
  - A face ShaderMaterial selects the cell with an `instance uniform`, so faces need no per-character materials.
  - Blinking runs in the shader from `TIME` and a per-instance seed, so it costs no CPU.
  - This spec shows only neutral and blinking. The conversations spec will use the rest.
- **Agents.** Agents are human-presenting guides, as the comparison contract requires for style 06. They wear the agent uniform: a white jacket over a blue shirt, and the leaf badge. City Agent A1 keeps the sheets' identifying features: navy hair tied up with loose strands, blue eyes, the uniform and the leaf badge. Other agents vary hair and face within the uniform.
- **Mapping.** `style.json` maps agent kinds by kind and A1 by `by_id`.
- **Crowd level of detail.**
  - The distant crowd (beyond about 45 m) switches to a simplified mesh with no outline, using `visibility_range`.
  - The far crowd updates its animation at a lower rate (manual `AnimationMixer` advance, staggered across characters).
  - Near characters always animate every frame.

## 5. Weather in the world

The core gains deterministic weather, like the clock.

- **Manifest.** An optional `weather` object: `{"rain": [{"from": minute, "to": minute, "peak": percent}]}`. These are daily spells in minutes after midnight; spells may cross midnight. Intensity ramps linearly over 20 minutes at each end.
- **Projection.** The projection gains `rain: Option<u8>`, a percentage computed from the clock and tick (`None` without a clock or weather).
  - Rules never read it, so the invariants are unaffected.
  - It uses integer maths only, so determinism holds.
  - Validation: `to != from`, `peak` between 1 and 100, and weather requires a clock.
- **Fixture.** The district fixture gains an evening rain spell (19:00 to 21:30, peak 80), so night and rain can be captured at a known tick. The gate's timings are unchanged.
- **Client.**
  - `SceneModel` emits a `rain` change.
  - `StyleHost` eases the rain per frame, like daylight, and calls `set_rain(amount: float)` on the pack.
  - The default does nothing.
- **Anime pack.** Rain is drawn as:
  - GPU particle streaks round the camera;
  - wet ground, with darker paving and higher specular;
  - streaky reflections of lamps and lit windows, as stretched emissive sprites under each light;
  - umbrellas on people outdoors.
- **Existing styles.** They get a light shared rain:
  - 3D: streaks and a greyer sky, from a shared `Pack3D` helper;
  - pixel art: a 2D streak overlay and a darker tint.

## 6. Performance

The budget and gate are in section 1. To stay inside them:

- **Draw calls.** Every repeated kit piece goes into MultiMesh batches through `KitTown.tiles`. Building bays are merged per building at build time.
- **Lights.** Shadows come from the sun only. The lamps are OmniLights without shadows, and far lamps fall back to emissive-only.
- **Line pass.** It is a single full-screen pass and its cost is fixed.
- **Crowd.** Level of detail and staggered animation as in section 4.
- **Rain.** One GPU particle system follows the camera.
- **Benchmark.** `godot/tools/bench.gd` first measures an empty scene with vsync (the baseline). It then runs scripted scenes (the presets, first person, the heaviest scene) for 5 s each at 1920 × 1080, uncapped and then with vsync, and writes `bench.json` with p50, p99, max, GPU p99, frames per second and missed refreshes per scene.
  - `scripts/bench.sh` checks the budgets against the baseline and fails on any breach.
  - `check.sh` calls it when a display is available and skips it, saying so, otherwise.

## 7. Testing

- **Core:** weather validation, projection and determinism tests, and a property test that the rain percentage stays within 0–100.
- **Client:**
  - the pack contract suite runs over the new pack automatically, since it discovers packs;
  - Toon helper tests: every `BaseMaterial3D` is converted, and night glow still works;
  - outline presence on characters;
  - the face atlas instance uniform;
  - the look rules for anime characters;
  - the rain change flows through `SceneModel` and `StyleHost`;
  - LOD switching distances.
- **Kit:** `tools/styles/anime/test_assets.py`: specs, references, validator and determinism.
- **Performance:** the bench budgets.
- **Visual:** the audit tool gains the anime style automatically (it discovers styles), plus rain scenes.

## 8. Not in this spec

- **Own specs:** map view, conversations, tram riding and rooftops. The expression atlas and the rain API are built so that they can use them.
- **Not planned:** homes, build mode, the facility kiosk, mobile and AR.
- **Packaging:** has its own spec after the three styles.

## 9. Risks

- **Face quality from procedural generation.** Mitigation: faces are 2D vector art on a stable face surface, iterated by rendering previews at close-up sizes before the kit is accepted.
- **The line pass under MSAA.** Verified first. The fallback is SMAA with no MSAA.
- **The 2.78 ms budget with outlines and a crowd.** Measured from the first playable build onward. The shared `Pack3D` batching work also helps the existing styles.
