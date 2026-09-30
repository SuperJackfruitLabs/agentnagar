# Solarpunk retro-futurism style: design

Date: 2026-09-25. This is the second of three independent style specs, after the [cel-shaded anime style](2026-09-25-city-anime-style-design.md). It builds on that spec's shared pieces: the weather, the benchmark gate, the sheet-view tools, animation level of detail, and the pattern of a style pack plus a kit generator.

## 1. Goal and success

A fifth style pack, **Solarpunk retro-futurism** (style study 09), after its four sheets under `docs/vision/style-studies/styles/09-solarpunk/sheets/`:

- city perspectives r005;
- living community r004;
- creating and exploring r003;
- interfaces r003.

The look is a warm, sunlit, semi-realistic illustration.

- **Materials:** soft, physically based, with no ink lines.
- **Architecture:** curved white ceramic and blonde timber, brass details, turquoise glass and solar canopies.
- **Greenery:** planted terraces, green corridors and palms everywhere.
- **Palette:** jade, coral and cream.

The pack uses the same pack contract, city, controls and core rules. It draws the core's rain.

**Success.** The same two measures as the anime style:

1. **Sheet match.** The `sheet_views` captures sit beside the study's panels in `city/godot/evidence/solarpunk-vs-sheet.png`, with gaps noted in `solarpunk-notes.md`.
2. **Performance.** The same budget as the anime style, declared in `style.json`: 360 fps in normal play (measured against an empty scene on the same display) and a 240 fps floor in the heaviest scene, with vsync at the display's rate. *Amended 2026-09-25 with the anime spec, from uncapped p99 ≤ 2.78 ms / 4.17 ms.*

## 2. Rendering

- **Materials.** The kit's GLB materials render as shipped, with no toon conversion: albedo, roughness and metallic per palette colour. Ceramic white is soft and slightly glossy; brass is metallic; glass is turquoise with low roughness.
- **Light.** A warm golden sun with soft shadows (2 splits, max distance 140 m, blur 1.2) and a bright sky with warm haze.
  - **Occlusion:** SSAO, subtle.
  - **Bounce light:** SSIL at half resolution, for the sheets' sunlit bounce, if the budget allows. It is measured first.
  - **Tonemapping:** filmic.
  - **Glow:** on lit windows and lamps.
- **Anti-aliasing:** 4× MSAA plus FXAA for specular edges, with no temporal AA.
- **Night:** warm interior glow, amber lamps and fairy lights in the great tree. Rain gives a slightly darker, glossier ground (shared wet-ground helper) and umbrellas.

## 3. The solarpunk kit

A generator at `city/tools/styles/solarpunk/` follows the anime kit's pattern:

- the low-poly `lib` on the solarpunk palette;
- the same module names and conventions, so the townscape reuses the low-poly assembly;
- specs, tests and previews.

The previews come from `godot/tools/asset_preview.gd`, extended to render without toon when a style asks.

The pieces:

- **Workshop:** blonde timber sawtooth bays, each steep face a blue solar panel, with warm glazing, vines and planters.
- **Library:** a white ceramic drum, two storeys of warm glazing between white bands, a planted rim and a glass-and-solar dome. This replaces the low-poly dome, with a `lib_drum` roof piece.
- **Towers:** rounded white towers with curved balconies, planted terraces and roof gardens with solar crowns.
- **Houses and shops:** white and cream with solar roofs, pergolas and awnings.
- **Streets:** streets, paving, kerbs, a tram track with a grass bed, water, and the three-arch stone bridge.
- **Tram:** cream and red.
- **Plants:** the great banyan-like tree, broadleaf trees, palms, shrubs and flowerbeds.
- **Props:** lamps, benches, planters, bollards, umbrellas and railings.
- **Interiors:** workbenches, desks and shelves.

## 4. Characters

- **People.** People reuse the anime kit's body builder and rig, with a solarpunk face atlas:
  - illustrated, semi-realistic features: smaller eyes, noses, lips, gentle shading;
  - drawn by a parameterised `faces.py`.
- **Clothing.** Everyday warm-climate clothing: linen shirts, overalls and aprons.
- **Agents are robots**, as the comparison contract requires for style 09:
  - white ceramic shells with brass joints;
  - a dark visor face whose cyan eyes are a small emissive atlas (neutral, smile, blink, talk);
  - a green scarf and the leaf badge.
- **A1.** City Agent A1 is that robot, with the sheets' features: a brass ring round the visor, the green scarf and the leaf badge on an ID card.
- **Crowd.** The distant crowd uses a merged far body, as in the anime style.

## 5. Testing

- **Contract:** the pack contract suite, by discovery.
- **Pack tests:**
  - materials untouched (not toon);
  - robot agents with emissive eyes;
  - A1 by id;
  - night glow;
  - rain wetness and umbrellas.
- **Kit:** the kit's `test_assets.py`.
- **Performance:** the benchmark budgets.
- **Visual:** sheet views and the audit.

## 6. Not in this spec

Map view, conversations, tram riding and rooftops, as for the anime style.
