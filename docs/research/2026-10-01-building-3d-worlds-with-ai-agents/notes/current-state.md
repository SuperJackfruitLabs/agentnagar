# Agentnagar's 3D models and character movement: the current state

_Written by an AI model (Claude Opus 5.5, Anthropic) from a read-only inspection of this repository on 2026-10-01. Nothing was built, launched or rendered; code, committed images and GLB files were read as they stand. "Seen in" marks my own observation of a named image. "Inferred" marks a conclusion drawn from code alone. Movement feel cannot be judged from stills, so everything said about it is inferred._

_Short paths are relative to `city/tools/styles/` (generators), `city/godot/styles/` (client style code) or `city/godot/evidence/` (images and notes)._

## Summary

1. Every model is code: about 22,000 lines of in-house Python assemble boxes, prisms and tubes in headless Blender (voxels in plain Python) into 413 GLBs and pixel art's 596 PNGs. No model is sculpted, bought or downloaded.
2. The kits are light: 54,000–92,000 triangles and 4–6 MB per style, coloured by one flat palette value per face. The only environment texture is a shared leaf-card image.
3. There are three geometry families, not five: low-poly; an anime kit that solarpunk and neon largely recolour; and voxel. Pixel art renders its own models to sprites.
4. Apart from voxel's pilot robots, every character shares one 17-bone rig, one-bone-per-vertex skinning and four computed loops (walk, idle, sit, typing), with no transitions, gestures or facial animation beyond a blink.
5. Movement is a 25 cm grid simulation stepped once a second and replayed one tick late in straight lines. Inferred: speed steps each tick, turns snap, diagonals are 41% faster, and nothing accelerates.
6. The scene is sparse by construction: 843 placements, 724 of them trees and shrubs, nearly all outside the places people gather; a 1,008 m² square with 34 objects; a crowd of 60.
7. Composition, landmark shapes and palettes already match the concept sheets. The gaps are density and life, light, ground and materials, interiors, and characters seen close.
8. Lighting is one sun, a constant ambient colour, point lamps at night, fog and glow, with no baked or bounced light. Three styles are gated at 360 fps, six times the vision's 60 fps.
9. The project's own records admit most of this and say no pack is a production style decision.
10. A rework must honour footprints in the walking band, origins, named nodes and materials, clip names, seat geometry and the tram layout; today's tests also reject any asset the generator cannot rebuild.

## 1. Inventory

Counts and triangles are measured from each pack's GLBs, which each kit's `build.py` writes. Categories follow each kit's `specs/*.json`, with the tram and shared "things to use" pulled out; low-poly and voxel file houses and towers under scenery, and voxel files trees under props.

| Pack | Buildings | Props | Usables | Vegetation | Scenery | Tram | Characters | Files | MB | Triangles | Material slots |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `lowpoly_tropical` | 14 | 20 | 10 | 11 | 13 | 1 | 2 | 71 | 4.0 | 53,736 | 394 |
| `voxel` | 23 | 19 | 10 | – | 19 | 1 | 1 | 73 + 29 pilot | 6.2 | 77,050 | 579 |
| `anime_cel` | 20 | 16 | 10 | 16 | 15 | 1 | 2 | 80 | 6.2 | 91,970 | 200 |
| `solarpunk` | 20 | 16 | 10 | 16 | 15 | 1 | 2 | 80 | 5.5 | 91,774 | 268 |
| `neon_noir` | 20 | 16 | 10 | 16 | 15 | 1 | 2 | 80 | 6.2 | 92,031 | 269 |
| `pixel_art` | 46 | 64, and 48 seats | – | 9 | 45 | 43 | 36 sheets | 596 PNG | 2.1 | – | 32 colours |

Voxel's 29 pilot files (15 kit pieces, 14 robots) are copied from an earlier prototype (`voxel/SOURCES.md`). Pixel art's counts are day sprites by folder, its plants among the props; each has a night twin.

| Pack | How colour and material are done |
| --- | --- |
| Low-poly | One flat-shaded material per palette colour; no textures or vertex colours |
| Voxel | The same, with lighter and darker keys per block; faces merged into rectangles |
| Anime, solarpunk, neon | Palette colour baked into vertex colours to cut draw calls (73 of 80 files; `shared/bake.py:1-15`); one leaf-card texture; face and robot-eye atlases. Anime turns toon with ink at runtime; the other two render as plain PBR |
| Pixel | Blender renders snapped to a 32-colour palette, outlined and dithered |

Specs set each asset's size, node names and triangle budget: in the Blender kits 100–1,500 for props, 3,000 for houses, 5,000–6,000 for towers, 9,000–10,000 for the tram and 3,000–10,000 for characters.

| Generator folder | `lowpoly` | `anime` | `solarpunk` | `neon` | `voxel` | `pixel` | `shared` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Python lines | 3,791 | 3,984 | 2,572 | 2,144 | 2,818 | 3,393 | 3,381 |

That is 22,083 lines; tests add 1,872 and preview tools 1,087. `lowpoly/lib.py` is the mesh library of every Blender-built kit, pixel art's models included, and `lowpoly/characters.py` the rig and motion of every style. Solarpunk and neon re-run anime builders on their own palettes: 30 of the 77 piece names the three share have identical triangle counts. Client style code has 5,063 shared lines; a 3D pack adds 44–516, pixel art 2,738.

## 2. How a model is authored

`lowpoly/lib.py` offers a `Mesh` of boxes (optionally bevelled, one segment), extruded prisms, slabs with holes, cylinders, jittered ico-spheres, domes and beams (`lib.py:180-374`); one material per palette name with fixed roughness, metallic and emission (`:101-114`); flat shading (`:143-144`); and Blender's glTF export (`:415-421`). Every coordinate is typed.

- **Building.** `hall_wall` is a slab with one hole and about a dozen boxes for glazing and trim (`lowpoly/buildings.py:46-83`). The client lays such bays along a footprint and stretches them to fit (`kit_town.gd:356-369`).
- **Tree.** The banyan is a fluted tube trunk, tube limbs and 29 jittered spheres whose faces take one of four greens by the way they face (`lowpoly/vegetation.py:59-78`, `:216-326`). The newer kits wrap lobes in alpha-masked leaf cards (`shared/foliage.py:1-30`).
- **Prop.** A bench is slat boxes on beam legs (`lowpoly/props.py:57-72`).
- **Human.** Elliptical rings lofted into head, chest and hips, a tapered tube per limb segment, box hands and box eyes (`lowpoly/characters.py:481-604`). Solarpunk and neon heads come from a signed-distance field, with the face painted on a plate (`shared/people.py:187-205`, `:307-347`).
- **Robot.** A lofted helmet, a curved visor patch, tube limbs and sphere joints (`lowpoly/characters.py:651-739`; `shared/robots.py:155-336`).

**Limits on the look.** Only face, eye and leaf-card plates are textured, so surfaces have no textures, decals, signage, wear or normal maps. Forms are primitives: no sculpting, subdivision or booleans beyond wall openings. Detail is typed boxes inside budgets of a few hundred triangles. Pieces are stretched unevenly to fill their footprints (`pack_3d.gd:719-734`). Bodies are tubes, so there is no cloth, no fingers and little facial form.

## 3. Characters and animation

- **Skeleton and skin.** 17 bones (`lowpoly/characters.py:89-96`), each vertex weighted 1.0 to one bone (`:196-208`). In all 23 skinned GLBs every vertex has one influence, so limbs are rigid segments overlapping at the joints.
- **Proportions and variety.** Figures are about six heads tall in low-poly and 7.5 in solarpunk and neon (`shared/people.py:6-12`), with one body and one height per kit. An outfit number fixes top, trousers, skin and hair colour together (`pack_3d.gd:1666-1690`); with four hair meshes the crowd has 32 human looks, plus a hat, a backpack and, by style, an apron, jacket, hood or scarf. The newer kits have four painted faces each. Low-poly, solarpunk and neon have one robot each, recoloured by agent kind; anime agents are people in uniform; voxel reuses 14 pilot robots on a different 16-bone rig.
- **Clips.** Four loops are computed, not hand-keyed: pose functions with two-bone IK, sampled at 24 fps (`characters.py:1090-1131`). Walk is 1 s over a 1.1 m stride, in place (`:751-752`, `:1002-1022`); idle is 6 s; sit and typing animate seven channels each.
- **Playback.** `_animate` picks walk, typing (seated and "Working"), sit or idle, cross-fades over 0.2 s and starts each person at a random phase (`pack_3d.gd:1897-1925`). Walk speed follows distance covered, so feet do not slide (`style_pack.gd:940-954`).
- **Seated and riding.** Sitting puts the hips over the origin on a 0.45 m seat; typing puts the wrists 0.32 m ahead at 0.77 m (`characters.py:85-87`). Tram riders are posed once and frozen, facing the way the tram runs (`pack_3d.gd:2783-2799`, `:2823-2829`).
- **Crowds.** Animation advances every frame above 90 px on screen, every second frame above 30 px, every fourth below, never off screen (`pack_3d.gd:59-65`, `:2102-2127`). The newer styles swap to a merged far body beyond 45 m (`:1771-1795`); low-poly and voxel do not. There are no impostors.

## 4. Movement

**The core** (`city/crates/city-core/src/`). Walkers stand on the centres of 25 cm cells and follow eight-way grid paths (`nav.rs:21-23`). A tick is one second at normal speed (`city/godot/core/world_driver.gd:1-2`), and in it a walker takes up to five steps, straight or diagonal alike (`world.rs:2326-2349`; `invariants.rs:451-466`). Facing is the last step, rounded to 45° (`walk.rs:6-18`). A cell holds one visible person: a blocked walker waits and re-plans after three blocked ticks (`world.rs:2410-2437`); two walkers wanting each other's cells swap (`:2355-2393`). Rooms admit at the door and queue on cells outside it. Trams run a constant 7 m a tick and stop exactly on the stop (`transit.rs:1301-1310`).

**Each tick the client receives**, per person: position, facing, `moving`, `trail` (the cells crossed last tick), `path_ahead`, queue place, vehicle slot and what is being used (`city/crates/city-contracts/src/projection.rs:123-166`).

**The client** replays the trail one tick late, by distance, in straight segments (`city/godot/core/motion.gd:1-4`, `:80-97`), sets yaw directly from the segment's direction (`pack_3d.gd:1833-1839`) and shows the walk clip exactly while the replay moves (`city/godot/core/style_host.gd:550-560`). There is no easing, turn smoothing or acceleration on this path.

**Why it is likely to feel mechanical** (all inferred):

1. Speed is constant within a tick and steps at tick boundaries. A last tick with one cell left covers 25 cm in a whole second, the walk slowed to a fifth.
2. A diagonal step is 35 cm and a straight one 25 cm, so walkers do 1.25 m/s along the axes and 1.77 m/s diagonally.
3. Paths are staircases of straight and 45° runs, and the body snaps to each new heading.
4. A blocked walker freezes for whole seconds; walkers meeting head-on pass through each other.
5. Sitting is a 0.2 s cross-fade with no sit-down motion, and the walk ends on the seat's own cell.
6. Everyone has one gait, stride and height; idle people never look round, gesture or talk.
7. Trams neither brake nor pull away, and riders teleport on and off.

Only the local player's steered walk is predicted and smoothed (`city/godot/core/player.gd:24-39`, `:287-313`).

## 5. Scene composition and lighting

`city/catalogue/catalogue.json` defines 34 kinds, each with a footprint, anchors and a height. `city/fixtures/district/generate.py` writes the one district.

| Place | Size | What stands there |
| --- | --- | --- |
| District | 140 × 118 m | 843 placements: 309 round trees, 299 palms, 116 shrubs, 28 street lamps, 27 building lots |
| Square | 36 × 28 m | 1 great tree, 10 benches, 8 bollards, 6 lamps, 4 planters, 2 flowerbeds, a fountain, a noticeboard, a plaque |
| Workshop | 16 × 16 m | 8 workstations, 1 workbench |
| People | – | 18 scripted occupants and a default crowd of 60 (`city/godot/core/args.gd:27`) |

Planting is a jittered 4.8 m lattice kept off the square, terrace and platforms and away from doors, seats and paths, because a plant is solid (`generate.py:868-876`); the places people gather therefore stay bare. In four of the five 3D packs the ground is flat boxes in one grass colour (`lowpoly_tropical/townscape.gd:166-170`). The newer kits each contain a pegboard and a pendant lamp that no script or `style.json` uses.

**Lighting.** Every 3D pack gets a procedural sky, a constant ambient colour, one sun, SSAO, glow and depth fog (`pack_3d.gd:1029-1073`), driven through the day by eight keys in `style.json`. Lamps and rooms have point lights, on only at night (`pack_3d.gd:1129-1137`, `:2051-2055`). Anime adds toon shading and ink lines and drops SSAO (`anime_cel/look.gd:21-47`); solarpunk and neon use filmic tone mapping, neon with reflections only in rain (`neon_noir/look.gd:9-34`). Those three also set one shadow split, a 2,048 px shadow map and 2× MSAA. There is no baked or bounced light, no probes and no volumetric fog.

## 6. The visual gap

The sheets are AI-generated concept paintings, made under a contract that calls itself "not an engine, production geometry or gameplay specification" (`docs/vision/style-studies/shared/CONSISTENCY-CONTRACT.md:3`), so part of the gap is beyond any real-time kit. The composites date from the style specs of 24–25 September.

**Seen in every 3D style** (`<style>-vs-sheet.png`, `placement-<style>-street.png`):

- **Density and life.** The sheets fill the square with trees, planters, parasols, a tram and dozens of people. The game shows open paving, one tree, a ring of benches, a few lamps and a few small figures. From above the sheets are continuous paving and canopy; the game is a small built core in flat lawn with an even scatter of trees.
- **Ground and surfaces.** Lawn, road, walls and glass are large single-colour planes. The river is a straight-edged slab.
- **Light.** Even daylight with thin shadows, against low warm light, long soft shadows, haze and glowing interiors.
- **Interiors** (workshop rows). A bare floor, plain walls and a few desks under flat light, against benches crowded with tools, shelves and pendant lamps.
- **Characters close up** (A1 rows, `interact-<style>-sit-bench.png`). Stiff, upright mannequins.

**Style by style:**

- **Low-poly.** Works: the most consistent 3D pack; banyan, library and chunky figures agree with one another, and its people hold up close (`interact-lowpoly_tropical-sit-bench.png`). Short: towers are stepped boxes with window bands, the canopy is a few large lobes, and night is flat blue with pasted-on window rectangles (`lowpoly-vs-sheet.png`).
- **Voxel.** Works: the block grammar, yellow sawtooth workshop, orange vault and lettered signs match (`voxel-vs-sheet.png`). Short: paving is nearly white and featureless, towers are plain grids, and blocky limbs overlap when seated (`interact-voxel-sit-bench.png`).
- **Anime.** Works: ink lines and two-tone shading give the buildings a drawn look (`placement-anime_cel-street.png`). Short: A1 is the largest miss of all, a smooth egg head with a flat face decal, helmet hair and tube sleeves beside an expressive drawn character (`anime-vs-sheet.png`, A1 row). The waterfront is a bare quay and a slab of lawn where the sheet shows a planted promenade (park row).
- **Solarpunk.** Works: palette, rounded towers, solar roofs and the robot's head (`solarpunk-vs-sheet.png`). Short: the sheet's all-over greenery is missing from the square and façades, materials read as matt plastic, and people are thin, long-necked mannequins with painted faces (`interact-solarpunk-sit-bench.png`).
- **Neon noir.** Works: the strongest atmosphere, with lit windows, magenta crowns, bulbs in the tree and streaked reflections in rain (`neon-vs-sheet.png`). Short: dozens of light points against hundreds, towers lit as whole slabs, large dark lawns, and a black robot that nearly vanishes indoors (A1 row).
- **Pixel art.** Works: the closest match of the six; outlined, dithered sprites make a coherent isometric town (`pixel-vs-sheet.png`). Short: one fixed view, a large empty square, 32 px faceless figures and a night that is only a palette swap.

Also seen: the tram's interior is flat panels and glass where the sheets show seats, poles and riders (`tram-vs-sheets.png`), and a figure standing on a seat cell stands inside its chair (`workstation-monitor-in-use-<style>.png`).

## 7. What the project's own records already admit

- After the first build the owner "judged that the art does not yet look like the style studies" (`docs/superpowers/specs/2026-09-24-city-walk-in-style-design.md:9`) and chose "Richer procedural art, made in-house. Nothing is bought or downloaded" (`:24`). The same spec says the owner, not tests, judges the art (`:308-309`) and that none of it is "a production style decision" (`:436-437`).
- The specs record that decision, not a comparison; the stated virtues are validation and reproducibility (`docs/superpowers/specs/2026-09-24-city-style-packs-and-movement-design.md:353-354`). The bake-off between kits, generators and capture proposed in `docs/architecture/TOOLS.md:309-323` is not recorded as run.
- Recorded gaps: density and crowd size in all six style notes; "Faces are simple eye blocks" (`lowpoly-notes.md:38`); "Hands and clothing folds are simple" (`anime-notes.md:39`); faces "long and plain" close up (`solarpunk-notes.md:36-37`); more lamps "would cost frame time" (`neon-notes.md:35-37`); "Boarding is a jump, not a walk" and "The ride's interior is bare" (`tram-notes.md:89-94`).
- Gates: 360 fps in normal play and 240 fps in the heaviest scene at 1920 × 1080 on the development laptop (`docs/superpowers/specs/2026-09-25-city-anime-style-design.md:24-26`), against the vision's 60 fps on desktop (`docs/superpowers/specs/2026-09-27-city-placement-grid-design.md:283`). Measured frames take 2–5 ms (`placement-notes.md:276-299`).
- Movement: "Clients only interpolate between ticks" (the same movement spec, `:36-37`); a navmesh is ruled out because "The grid stays, for determinism" (placement-grid spec, `:294`).

## 8. Contracts a rework must keep

- **Footprints.** Between 0.25 and 1.9 m above the ground a piece must stay inside its kind's catalogue footprint; above and below, a style is free (placement-grid spec, `:237`). `city/godot/tests/test_collision_audit.gd:23-44` holds all six styles to zero offences.
- **Frame and names.** Metres; origin at the footprint's centre on the ground, or at the sitter's point for a seat; front facing Godot −Z. `style.json` maps every catalogue kind and five occupant kinds (`style_pack.gd:11-22`, `:139-142`). The townscape asks for modules by name and nominal size, such as `hall_wall` at 4 m (`lowpoly_tropical/townscape.gd:9-17`, `:53-76`).
- **Nodes and materials the client drives.** `light`, `screen`, `display` and `roof` nodes; glass, glow, neon and paving materials found by name (`kit_town.gd:157-177`; `pack_3d.gd:115`); leaf materials named so the audit ignores them. Characters are recoloured by overriding the material of nodes named `skin`, `top`, `bottom` and `hair_0`–`hair_3` (`pack_3d.gd:1745-1754`), which would wipe a textured mesh.
- **Clips.** The client needs an `AnimationPlayer` with walk, idle, sit and typing; `style.json` can rename clips and set walk pace, as voxel's pilot robots do (`pack_3d.gd:1910-1914`). The low-poly kit's tests are stricter: the 17 bone names, 1 s walk and typing loops, hips 0.45–0.60 m high over the origin, typing hands at desk height (`lowpoly/test_assets.py:263-328`).
- **Tram.** 20.5 m long, 40 slots, door leaves named `door_<side>_<k>_<fore|aft>`, a seat under each seated slot, windows at a seated eye (`shared/tram_checks.py:145-203`).
- **Kit tests.** Size within 10% of the spec, triangle budget, a spec for every GLB, no validator warnings (`lowpoly/test_assets.py:218-241`) and, for every kit but low-poly, the committed file identical to the generator's output (`shared/kittests.py:128-144`).

**What would break with third-party kits or AI generators.** Where it applies, the byte-for-byte rebuild test fails at once, since such files have no generator. Budgets and validator warnings come next, then the name contracts, the recolouring rule and uneven stretching to footprints. Textures and denser meshes would also threaten the 360 fps gate. `CONTRIBUTING.md:31-40` requires recorded provenance for third-party material and a label on anything AI-generated.

## Could not determine

- How movement, blending and the level-of-detail switches look in motion: nothing was run.
- Whether the tests, including the rebuild check, pass today.
- How the composites would look if retaken now; the low-poly notes still call rain unmodelled although `pack_3d.gd:2147` draws it.
- Why the `interact-<style>-sit-desk.png` captures show a seated figure on open floor beside a chair. The fixture no longer has `desk` seats, so they may be stale.
