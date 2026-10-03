# The square's fountain and the tram shelter: what was built

> In this record the pieces are in `out/<style>/`, the agent's own preview sheets are in `previews/fountain-shelter/` (as JPEG) and its tools are merged into `tools/`. Where the report names `work/`, `base/`, `logs/`, `scratch/`, `out/` or `previews/`, it means the agent's own folder in the working folder (`agents/fountain-shelter/`), of which only the pieces and the previews are kept here. The report is as the agent gave it; what happened afterwards is at the end.

Written by Claude (an AI build agent), 2026-10-02, 12:25 to 15:15, and saved here by the coordinating session from the agent's final message (the agent could not write this file itself). Nothing outside this folder was written. The game, Godot, the captures, the bench and the image-to-3D model were not run.

## Summary the agent gave first

Five pieces are built and pass `work/check.py` (exit 0): the tram shelter in anime_cel and lowpoly_tropical, the fountain in anime_cel, lowpoly_tropical and solarpunk. None has been seen in the game; every picture is a Blender workbench render.

- **Not built:** neon shelter (tried, broken: three rules missing), neon fountain (the generator made the falling water into dark slabs that hide the centre piece), solarpunk shelter (the generated model has no back screen), voxel (no model by 15:10).
- **Outside the agent's part:** the cutter clears grey glass with the grey backdrop. Both shelters whose design has grey glass (neon, solarpunk) lost it before generation.
- **Shelter:** new `--shelter` sizes it zone by zone. What stands under the canopy fills the footprint box exactly, the open-end front post is taken out, the bench is cut free and set to the footprint's 2.4 m, and the canopy fills the kit's box front to back. On the file the game would scale it 1.0002 by 1.0009.
- **Fountain:** new `--fountain` builds the wall and rim as a ring by rule (outer face 1.497 to 1.500 m, rim top 0.450 m under all eight seats), with the centre piece as generated.
- **Water, the agent's decision:** falling water kept as still geometry in the part `water`; the basin is one flat disc painted from the generated water, with foam where the streams land. `previews/fountain-anime_cel-water-options.png` shows the three choices. Leaving the falls out does not work yet: the hole-closing leaves the troughs ragged.
- **Collision audit:** redone on each file in `work/piece_rules.py` (the agent's reading of the code, not a run of it): 0 through, 0 within 10 cm, 0 blocked cells uncovered. Shelters clear by 12.5 cm; fountains by 10.6 cm on a 10 cm limit, the same radius as the kit's.
- **Triangles:** 12,000 a shelter (kit limits 1,000 and 800), 9,334 a fountain (14,334 in solarpunk; limit 1,500). Set by eye.
- **Weakest points:** the anime bench is 0.59 of its drawn length and its posts' cut height is given by hand (`cut=0.894`); the low-poly shelter has nothing that glows at night; the solarpunk plants are coarse; the anime troughs came out timber-coloured.
- **Existing pieces unchanged:** the bench matched the main `out/anime_cel/seat_bench_v2.glb` byte for byte at 13:38 and 14:17. That file was rebuilt at 14:30 by newer main tools, so the last comparison is against the bench built by `base/fit_generated.py`: same bytes (`logs/proof.txt`).
- `check_options.py`: 92 options documented and read. This took about 2 h 50 min, not 60.

## What is in `out/`

| Style | Piece | File | Triangles | Kit's limit, kit's piece | Size x, y, z (m) | Parts | Materials | File size |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| anime_cel | tram shelter | `out/anime_cel/tram_shelter.glb` | 11,998 | 1,000, 636 | 4.34, 2.97, 2.29 | root `tram_shelter`, mesh `shelter` | `lamp_glow` (11,133 triangles, with an emission texture), `glass_light` (864) | 1.0 MB |
| lowpoly_tropical | tram shelter | `out/lowpoly_tropical/tram_shelter.glb` | 12,000 | 800, 328 | 4.47, 2.95, 2.19 | the same | `sheet_albedo` | 1.2 MB |
| anime_cel | fountain | `out/anime_cel/fountain.glb` | 9,334 | 1,500, 1,292 | 3.00, 1.86, 3.00 | root `fountain`, meshes `body` (6,441) and `water` (2,893) | `sheet_albedo`, `water_drawn` | 1.3 MB |
| lowpoly_tropical | fountain | `out/lowpoly_tropical/fountain.glb` | 9,333 | 1,500, 1,292 | 3.00, 1.86, 3.00 | `body` (5,519), `water` (3,814) | the same, with a relief map | 2.5 MB |
| solarpunk | fountain | `out/solarpunk/fountain.glb` | 14,334 | 1,500, 1,292 | 3.00, 1.86, 3.00 | `body` (13,237), `water` (1,093) | the same, with a relief map | 3.3 MB |

Textures are 2048 px, WebP inside the files. No node has a transform. All materials are opaque and double-sided. Each piece's own report is beside it (`<file>.json`); `python3 scratch/glb_summary.py out/*/*.glb` prints what is in each file.

Look at: `previews/tram-shelter-anime_cel.png`, `previews/tram-shelter-lowpoly_tropical.png`, `previews/fountain-anime_cel.png`, `previews/fountain-lowpoly_tropical.png`, `previews/fountain-solarpunk.png`. Each has the design cut-out, the kit's piece and the built piece from the same three cameras, shaded and in colour, and the built piece once in flat colours. The shelter's second camera stands at the open front at eye height (1.6 m); the fountain's third looks straight down.

## Not built

| Style | Piece | Why |
| --- | --- | --- |
| neon_noir | tram shelter | Tried with the shelter rules as they stand (`previews/tram-shelter-neon_noir-attempt.png`): broken. Three things are missing. The model's roof starts at 73% of its height, so filled to the kit's height its underside is at 2.19 m, inside the band the game measures, and nothing lifts it. Its bench is nearly as deep as the whole shelter, so the rule that finds the open-end post by "in front of the bench" finds none. And the walk that finds the canopy reaches the ground. The cutter also cleared the grey glass with the backdrop, so the model has an open frame where the design has panes (`previews/tram-shelter-neon_noir-generated.png`). |
| neon_noir | fountain | The generated model is the fault (`previews/fountain-neon_noir-attempt.png`): the falling water came out as dark streaked slabs standing round the centre piece, painted grey and black, which hide it and which no colour rule can tell from stone. The basin, ring and water disc build. It needs another generation (another seed, or a cut-out with the falling water painted out). |
| solarpunk | tram shelter | Not tried. The cutter cleared its glass too; the generated model has no back screen at all (`previews/tram-shelter-solarpunk-not-fitted.png`), and the collision audit needs something drawn along the whole back. A screen would have to be put back by rule, or the sheet cut again with its glass kept. |
| voxel | both | No generated model by 15:10, and no voxel `A-tram-shelter` sheet in the checkout. Nothing was done. The fountain there needs its own route: the basin kept a drum and one part `basin`, only the centre piece from cubes. |

The neon models arrived at about 14:10 and the solarpunk ones at about 14:50.

## The tram shelter

### How it is fitted (`--shelter`, new)

Filling the kit's box, as the route does for a seat, cannot work here: the game stretches the piece until its slice between 0.15 and 2.2 m fills the footprint box, and both designs stand a post under the canopy's open-end front corner. So the model is sized zone by zone:

1. **The landmarks are read off the model**: the canopy's underside, the inner faces of the two end structures, the back screen's front face, the bench's top and its seat's top and front edge, whether a screen stands behind the bench, and the post at the open end. They are in each piece's report under `shelter`.
2. **The canopy is parted from what stands under it.** The plan is read cell by cell: where something reaches the lower half it stands, where nothing does it hangs from the roof. Each post is cut through under whatever hangs beside it, and the canopy is whatever is still joined to the roof. Lamps and roof beams go with the canopy; a rail on the screen stays with the screen.
3. **The post at the open (+x) end, in front of the screen, is taken out** up to the canopy. The canopy is left hanging over the front, as the kit's does.
4. **The bench is cut free** along planes, with both cut faces closed. It is shortened or stretched to the footprint's bench and set against the end screen's side. What is left of it on a post, on the end screen or on the wall behind is pressed flat onto that face and takes its colour.
5. **Sizes**: what stands under the canopy fills the footprint box exactly with its slice between 0.15 and 2.2 m (measured as the game measures it), the end structures 13 cm thick. The canopy fills the kit's box from front to back and is sized along the length as the posts are. Heights fill the kit's height with the bench's seat at the kit bench's height. The posts' cut tops are pushed 6 cm up into the canopy.

After the cut-down: faces within 12 degrees of an axis are shaded as if they looked along it (`--square-normals`), because a pane a millimetre off flat shows its triangles when shaded smooth; glass becomes a material of its own (`--glass`); lamp faces are painted lit (`--lamp-faces`).

### Contract rules, and how each was checked

Numbers are the note's rule numbers (`notes/contracts/tram-shelter.md`).

| Rule | anime_cel | lowpoly_tropical | Checked by |
| --- | --- | --- | --- |
| 1. root `tram_shelter`, mesh `shelter` | yes | yes | `check.py` (the kit tests' node rule); the fit named its mesh `body`, hence `--mesh-name` |
| 2. no `light`, `lights`, `display` part | yes | yes | `check.py` |
| 3. open front to -z, end panel at -x | yes (model turned 0) | yes (turned 180) | looked at; the audit below would fail otherwise |
| 4. whole size inside the spec's range | 4.34, 2.97, 2.29 (range 4.26-5.24, 2.66-3.28, 2.07-2.57) | 4.47, 2.95, 2.19 (4.26-5.24, 2.64-3.26, 1.96-2.44) | `check.py` |
| 5. slice 0.15-2.2 m is the footprint box | -2.150, -0.399 to 2.149, 0.750 | the same | `check.py`, with the pilot's `band.py`: the game would scale it 1.0002 by 1.0009 |
| 6. everything outside that box above 2.2 m | canopy's lowest point 2.53 m | 2.34 m (the roof slopes down to the back) | fit report; rule 5 fails if not |
| 8-12. back, end screen and bench where the grid blocks, nothing where it does not | 0 through, 0 within 10 cm, 0 blocked cells uncovered; nearest walkable cell centre 12.5 cm off | the same | `check.py`: the collision audit redone on the file (below) |
| 13. bench top 0.46-0.51 m, seat front at z 0.15 | 0.50 m | 0.49 m | `check.py` (top); fit report (front edge) |
| 14. nothing on the bench in front of the sitters | arm rests reach z 0.126, between the sitters | end blocks reach z 0.104, at the bench's ends | read off the fit report and the pictures, no tool |
| 15. the sign | blank cream panel, lit | blank cream panel, not lit | looked at |
| 16. glass as a material named `glass...` | `glass_light`, 864 triangles, a third of the surface, opaque | the design has no glass | `check.py` reports the names |
| 17. lamp strips, `lamp_glow`, above 2.2 m | the undersides of the design's three lamp boxes, 2.52 to 2.66 m, and the sign's face | none in the design | `check.py`: the material emits in the file |
| 18. no `light` part | yes | yes | `check.py` |
| 19. anime: no relief map | none (`--no-normal`, both styles) | | file |

**The collision audit, redone on the file** (`work/piece_rules.py`): the piece's slice between 0.25 and 1.9 m is drawn on a 2.5 cm raster as the game would scale and turn it, what a mesh encloses is filled, the kit's three perch seats are added, and every 25 cm cell round a placement is tested by the audit's three rules that need no simulated day. This is the agent's reading of `audit.gd` and `solids_3d.gd`, not a run of them. It taught two things. A face set exactly on a footprint rectangle measures 10.0 cm from the next walkable cell on that raster, where 10 is the limit, so the bench is set 2 cm inside its rectangle and the end structures are 13 cm thick, not 15 (the kit keeps the same margins). And a plinth under a back post reached 25 cm forward, so what stands at the back is held to 22 cm.

**Checked in the code, as asked for the inferred rules**: the fill and its measure (`kit_town.gd:214-315`, `pack_3d.gd:719-762`, `city_geometry.gd:186-197`), the names (`kit_town.gd:157-177`), the audit (`solids_3d.gd`, `audit.gd:330-446`), the blocking margin (`footprint.rs`), the catalogue's footprint and anchors. They hold. One small difference: by `drawn_rect` the drawn footprint is 4.30 m wide, not 4.305.

### What is wrong or weak

Both:

- **Not seen in the game.** In particular how the anime ink pass and toon shading treat a dense textured shelter.
- The canopy is shorter than the kit's (4.34 and 4.47 m against 4.75): it keeps to its posts, as drawn, and the posts are at the footprint's ends.
- The removed post leaves the canopy held by the back posts and the end screen only. Where it met the canopy there is a flat closing patch.
- 12,000 triangles each, set by eye: at 6,000 the posts and rails waver (`previews/first-looks/`). Five shelters stand in the town.

anime_cel:

- The bench is 0.59 of its drawn length (the design's runs the whole shelter; the footprint allows 2.4 m), so its arm rests and legs are thinner along the length. It has no leg at its end-screen end, where the design ran it into the panel.
- The design's glass stops at the bench's back, so beside the shortened bench the wall is open below 0.84 m. From behind, the bench's back is a glass-coloured panel.
- The posts are parted from the canopy at a height given by hand (`cut=0.894`). A rail runs into the open end's posts a hair under the roof, and the rule cuts under it, which leaves the screen joined to the roof.
- Only the lamp boxes' undersides are lit, and the sign is a blank lit panel.
- Colour off the design 5.3 (CIELAB), all five design colours found.

lowpoly_tropical:

- The end sign on its plinth is squeezed to 13 cm thick (drawn about 29) to fit the footprint's end screen.
- The bench has no back (as generated) and is stretched 1.13 along its length. Faint marks remain on the stone base where it stood before it was moved.
- Nothing glows at night: the design has no glass and no lamp, where the kit's glass glows.
- The roof's low edge is at 2.34 m (the kit keeps 2.60).

## The fountain

### How it is fitted (`--fountain`, new)

1. **Read off the model**: the basin's axis and outer radius, the rim's top and inner edge, the water's level. A generated model is a hollow shell whose floor has an inside that looks up, and the first rule took that for the rim. Both the rim and the water level are now the highest of the heights that hold a good share.
2. **Sizes**: the outer wall to 1.50 m, the rim's top to 0.45 m (what is below it and what is above it scaled separately, as `--seat` does), the whole to the kit's 1.86 m.
3. **The wall and rim are a ring built by rule**: 48 sides, outer face at 1.50 m, top flat at 0.45 m, in to the generated rim's inner edge (1.24, 1.23 and 1.22 m), coloured from the generated stone. The generated wall is left out of the piece.
4. **The centre piece** stands as generated, cut to its triangle count.
5. **Water**, below.

### Water: what was chosen and why

The generator makes all the drawn water as geometry fused with the stone and painted blue. It is told from stone by its colour (`--water`), and:

- **In the basin**: the generated surface and its splashes are left out. One flat disc lies from wall to wall at the generated level (0.25, 0.27 and 0.32 m). It is painted from the generated water under it: its deep colour moved to the sheet's water swatch, the rings of foam where the streams land kept.
- **Still water in the bowls and troughs**: each patch is levelled at its own mean height.
- **Falling sheets and the jet: kept**, as still geometry, in the part `water`, matched on their own to the design's water colours (pale, streaked).
- All of it is one mesh `water` under the root, material `water_drawn`, roughness 0.05, opaque, with the piece's texture. The body keeps none of it.

Why: `previews/fountain-anime_cel-water-options.png` sets the three choices side by side. With a flat one-colour basin (the kit's way) the streams end in nothing and the basin is dull beside its design. With the falling water left out, the hole-closing fails round the troughs (1,759 edges left open), they come out ragged, and the fountain loses what its sheet draws. Kept, pale and landing in foam, it reads as drawn water, not as blue plastic, in these renders. It could not be judged in the game's light. The note's own warning stands: in solarpunk it will be a glossy solid. If it looks wrong there, `--fountain-pool flat` gives the kit's flat basin; leaving the falls out needs the hole-closing repaired first.

Water is matched to the design apart from the rest. Matched together, one scale of colourfulness served neither, and the anime column's timber came out stone-grey.

### Contract rules, and how each was checked

| Rule (`notes/contracts/fountain.md`) | Result, all three | Checked by |
| --- | --- | --- |
| 1. origin at the basin's centre, no transforms | yes | file |
| 2-3. outer wall at 1.50 m all round, nothing beyond 1.52 m above 0.25 m | 1.497 to 1.500 m round the circle | `check.py`, bearing by bearing, and the audit redone on the file: 0, 0, 0 |
| 4. inside the kit's box | 3.00, 1.86, 3.00 | `check.py` |
| 6. rim top 0.45 m, flat from 1.40 to 1.50 m, stone in to 1.40 m | 0.450 to 0.450 m under the eight seats; stone in to 1.24 m or less | `check.py`: the stone's top under 9 points a seat, and at 1.385 m |
| 8-11, 14. water told by colour, a disc in the basin, a `water` part with its own material | yes; roughness 0.05 | `check.py` |
| 13. falling water | kept, see above | looked at |
| 15-17. names | `fountain`, `body`, `water`; no `light`; no name the game acts on | `check.py` |
| 19-20. faces and relief | low-poly flat; anime and solarpunk smooth under 40 degrees; anime without a relief map | settings |

The audit's nearest walkable cell is 10.6 cm from the piece on the agent's raster, 0.6 cm inside the limit. The kit's basin has the same radius, so the kit stands the same.

### What is wrong or weak

- **Not seen in the game.**
- The basin's wall is taller than drawn (0.45 m, where the designs' own proportions give about 0.3 m), and the centre piece's foot is stretched with it. That is the contract.
- The streams end in points at the water.
- anime_cel: the generator painted the column's timber so dull that the match took it for stone, so timber-coloured texels are moved to the sheet's timber swatch (`--paint`). That rule also takes the six troughs, which the design draws dark. 92% of the design's colours found.
- lowpoly_tropical: the splashes stay as shards of geometry at the streams' feet. The ring shows no joints between stones (the generator painted none).
- solarpunk: the plants round the trunk are coarse even at 14,000 triangles. About a quarter of the solar panels' faces fall inside the water's hue and sit in the water's part and material; they keep their own colours. The gold bands on the wall are faint. 91% of the design's colours found; 95% of the generated surface within 7.1 mm.

## Tool changes

`work/fit_generated.py` (header documentation complete; `check_options.py`: 92 options documented and read):

| Change | Why |
| --- | --- |
| `--shelter`, `--shelter-bench`, `--shelter-end`, `--shelter-stub`, `--shelter-set` | the zone-by-zone sizing above; `--shelter-set` overrides a landmark the rules read wrongly |
| `--fountain`, `--fountain-sides`, `--fountain-falls`, `--fountain-pool`, `--water`, `--water-colour`, `--water-rough` | the fountain above |
| `--mesh-name` | the kit's spec names the shelter's mesh `shelter` |
| `--glass`, `--glass-rough` | the game lights a material named `glass...`; one material for the piece gets none |
| `--lamp-faces` | the generator paints a lamp's face a few bright specks |
| `--square-normals` | flat panes that show their triangles |
| `--paint` | a stuff painted too dull for the match to find |
| `--bake-reach` | the default reach is 6 to 12 cm for a piece six metres long |
| `--glow-matched` | glowing texels take the matched colour; written, then not needed (the anime sign takes `--lantern-colour`) |
| `--save-sized` | to look at what a sizing did |
| the colour match runs once per group of texels | water apart from the rest; one group is the old behaviour |
| `cut_from` | the piece is cut down from the model without the parts a rule builds |
| `face_colours` moved up, unchanged | needed before sizing |

Other files:

- `work/build.py` passes `mesh` as `--mesh-name`, and the sheet's water and timber swatches (`water_colour`, `timber_colour: swatches`).
- `work/check.py` calls the new `work/piece_rules.py`.
- `work/look.py` has `--colour` (kit pieces carry colours on vertices or materials and rendered grey) and `--view` (a camera in the game's frame).
- New `work/preview.py` makes the sheets in `previews/`.
- `work/assets.json` has the two entries (`file`, `needle`, `mesh`, flags, per-style settings, `only`) and a sentence in `_about`.

**Existing pieces unchanged**: `python3 work/build.py fit anime_cel bench` gave the main `out/anime_cel/seat_bench_v2.glb` byte for byte at 13:38 and at 14:17. At 14:30 that file was rebuilt by newer main tools (its report has a `plan` block that `base/` does not write) and no longer matches. So the last comparison is against the bench built by `base/fit_generated.py` with build.py's own command line: the same bytes (`logs/proof.txt`, `scratch/proof/`).

## Checks added

Implemented in `work/piece_rules.py`, run by `check.py`:

- the collision audit's `through`, `within_10cm` and `reverse_blocked` for one placement;
- the shelter's walking-band slice against its footprint box, and the scale the game would give;
- the bench's top;
- the fountain's outer face round the circle, its rim under the eight seats and its water part;
- material names (unique, none the game darkens in rain, those lit by name reported);
- no part named `light`, `lights` or `display`;
- a lamp material emits in the file.

Could not, from the file alone: the audit's two counts that need a simulated day and the tram overlap; the Khronos validator (these files use `EXT_texture_webp`); rule 14 of the shelter; how anything looks.

## Decisions the agent made

1. Falling water kept, basin painted from the generated water. One setting each to reverse.
2. The canopy keeps to its posts along the length and fills the kit's box front to back.
3. The bench 2 cm inside its rectangle, the end structures 13 cm thick, the back held to 22 cm: margins against the audit's raster.
4. Triangles by eye: 12,000 a shelter, 9,000 a fountain's centre piece (14,000 in solarpunk), plus 288 for the ring and 46 for the disc.
5. The anime sign and lamps glow through the body's material named `lamp_glow`, as the kit lights its timetable. The low-poly shelter gets no light.
6. No relief map on a shelter in any style.
7. The entries are held to the styles that build (`only`), so a build of everything does not make a bad neon piece.

## What remains

- See all five in the game, and run the game's own collision audit on them (the fountain note gives the command).
- The capture tool does not find either piece as written (both notes say so).
- Neon: another generation of the fountain; three rules and a back screen for the shelter. Solarpunk shelter: a back screen. Voxel: everything.
- The cutter clearing grey glass with the grey backdrop. This is in the cut step, not here.
- The hole-closing when falling water is left out.
- The anime shelter's hand-given cut height.
- The neon sheet's amber strips on the fountain.

## Files

- `out/<style>/`: the five pieces, their reports and textures; `out/results.json`.
- `previews/`: the five sheets, the water options, the neon attempts, the two generated models not fitted, `first-looks/`.
- `work/`: the tools. `base/` is untouched.
- `logs/`: `check.log`, `proof.txt`, the build logs.
- `scratch/`: experiments, `proof/` (the two benches), `audit_picture.py` (draws the audit's raster for a piece), `glb_summary.py`.

## Afterwards: what the game showed

Added by the coordinating session (Claude, an AI), which placed the pieces in the working copy of the game, ran its collision audit and captured them. The agent had seen none of this.

- **The audit.** With the five pieces placed the game's collision audit counted zero in anime, low-poly and solarpunk, as the agent's reading of it on the files had said.
- **They read as their designs.** The low-poly fountain's timber tiers and falling water, the solarpunk fountain's solar petals and the two shelters are the most changed pieces in their towns and the closest to their sheets (`compare/water-<style>.jpg`). The kept falling water reads as drawn water in all three styles, also in solarpunk, where the agent had expected a glossy solid.
- **Captures.** The capture tool did not find either piece as first written; both entries now name the whole file, and the camera is set from the side most of the piece shows from.
- **The build does not repeat.** A fountain built twice from one model with one set of tools differs in its bytes. The merge of these tools could therefore not be proved by comparing files, as the others were; it was checked by the pieces' reports and by eye.
- **The glass.** The cutter cleared grey glass with the grey backdrop, as the agent found. It now writes a cut-out that carries its own transparency (`obj-<k>-matte.png`: the object and the patches it closes in on every side), and the neon and solarpunk shelters were generated again from those; both models now have their panes and a back screen. The neon fountain was generated again from another seed, which gave white falling water where the first gave dark slabs.

The second pass below is the same agent's, on the new models.

## The fountain and the tram shelter, second pass: neon, solarpunk, voxel

Written by Claude (an AI build agent, the same one that built the first five pieces), 2026-10-02, 16:00 to 18:17, and saved here by the coordinating session from the agent's final message (the agent could not write this file itself). It worked in `agents/fountain-shelter/` from the tools as merged at 15:59. The game and the image-to-3D model were not run by the agent, so the look under the game's light and its own collision audit were unchecked when this was written.

All five pieces are built and pass `check.py`; the fountain's fault is fixed and every piece now builds twice to the same bytes.

### What is built

All are in `out/<style>/`, with previews in `previews/<piece>-<style>.png`. Every row passes `check.py` ("size, parts and the piece's own rules as the kit's spec").

| Piece | Triangles (kit's limit) | Size, m | What the check says |
| --- | --- | --- | --- |
| Neon tram shelter (from the cut-out with its own transparency) | 8,998 (1,000) | 4.30 by 2.97 by 2.30 | slice -2.150, -0.400 to 2.150, 0.751; the game would scale it 0.9999 by 0.9991; nearest walkable cell 12.5 cm; bench top 0.51 m; `lamp_glow`, `glass` |
| Solarpunk tram shelter (from the cut-out with its own transparency) | 11,994 (1,400) | 4.34 by 3.17 by 2.23 | slice -2.150, -0.399 to 2.149, 0.749; scale 1.0003 by 1.0015; 12.5 cm; bench top 0.50 m; `lamp_glow`, `glass_light` |
| Neon fountain (seed 7) | 9,334 (1,500) | 3.00 by 1.86 by 3.00 | outer face 1.497 to 1.500 m; rim 0.450 m; nearest walkable cell 10.6 cm; `lamp_glow`, part `water` |
| Voxel fountain | 1,190 (600) | 3.00 by 2.00 by 3.00 | root `fountain`, one part `basin`; outer face 1.497 to 1.500 m; rim 0.500 m |
| Voxel tram shelter | 416 (550) | 4.30 by 3.00 by 1.60 | slice -2.15, -0.40 to 2.15, 0.80; scale 1.000 by 0.958; 12.5 cm; bench top 0.50 m |

- **The voxel shelter's depth.** 1.15 m cannot be built from 0.1 m cubes, so the slice is 1.20 m, as the kit's own piece (which the game draws 0.977 by 0.958). `piece_rules.py` now allows a voxel piece half a cube; without that change this piece fails the slice rule.
- **The earlier pieces.** The anime and low-poly shelters rebuild to the delivered bytes. The three earlier fountains changed bytes because of the fix below (anime 1,317,048 to 1,316,020; low-poly 2,536,068 to 2,530,092; solarpunk 3,271,784 to 3,255,160). Their triangle counts are the same, the checks pass, and the new previews were looked at.

### The fountain's fault

- **Cause.** Not a Python set. `size_fountain` built the centre piece's skirt with `bmesh.ops.extrude_edge_only`, which makes its faces in an order that differs from run to run. The piece was then cut down from a mesh with its faces in another order.
- **Fix.** The skirt is now built edge by edge in the mesh's own order. Every walk over a set of mesh elements in `carve` and the shelter code was also made ordered; those changed no bytes.
- **Proof.** `scratch/proof2/mine.sh` builds all ten pieces twice through `build.py`; the result is in `scratch/proof2/mine.txt`. All ten report the same bytes from two builds, for example the anime fountain 1,316,020 bytes, the neon fountain 1,998,780, the voxel fountain 269,464.
- **Other agents' pieces.** `scratch/proof2/others.txt` shows the anime bench and the voxel bench (fitted and in cubes) come out the same bytes from the tools as merged at 15:59 and from the agent's.

### What is weak

**Neon shelter**

- The amber lines round the soffit and the magenta strip are not in the model. Only the strips on the sign's posts and the sign's face light.
- The roof is rebuilt as a plain slab and its slats are painted; some gaps come out as broken dashes. The roof's fold and hipped end are the generator's.
- At the open end the slatted panel is cut away, which leaves a ribbed end post.
- The panes have light specks along the bottom.

**Solarpunk shelter**

- The back is a copy of the front's picture, with ragged dark specks along its edges. The wall's lower band is dark on both sides.
- The lamp strips under the roof are not in the model, so they are not lit.
- The arch at the open end stops in a stub where the post was removed.

**Neon fountain**

- The falling water is kept as white ribbons standing round the centre piece. Left out, the centre piece shows bare with grey patches (`scratch/t3/nfd-sheet.png`). The agent kept it; this is a call on the look that the owner may want to make.
- The centre piece's amber strips are missing.

**Voxel fountain**

- It has twice the kit's triangle limit.
- The basin is a smooth ring in one flat stone colour, not the design's stepped cubes.
- The water is put at 0.40 m by rule, because the model's basin is three cubes deep where the sheet draws one.
- The ring's material is named `sheet_albedo`.

**Voxel shelter**

- Posts are one cube thick where the design draws two.
- It is 3.0 m high, not the kit's 3.3.
- It is not lit; the kit's is not either.

### What changed in the tools

**`fit_generated.py`**

- `size_shelter`, with new helpers `runs_of`, `floor_sheet_out`, `behind_out`, `canopy_rebuilt`, and nested `press`, `least_crossed`, `with_what_hangs`. It now returns a second value, what to cut the piece down from; the call site takes it.
  - The three rules the neon shelter lacked: a roof that starts low (the canopy outside the footprint is kept above 2.26 m by dividing the heights again); a bench as deep as the shelter (the open-end post is taken from where it starts, or everything in front of the screen when a panel runs to it); the walk reaching the ground (one cut through the whole model at the height just under the roof where the least is crossed).
  - A screen standing forward of the end structure's back is parted and moved to the back strip.
  - A plank lying behind the screen is taken out (the voxel model had one).
- `size_fountain`: the skirt fix and `--fountain-level`.
- `carve`: ordered walks only.
- `bake` takes an optional reach. `uv_mask` and `painted_at_faces` moved up unchanged; `glass_faces` is the old glass test as a function.
- New `--shelter-set` keys: `floor`, `roof`, `clear`, `height`, `feet`, `back`, `screen`.
- New options: `--shelter-screen`, `--glass-colour`, `front` after the `--glass` range, `--pale-colour`, `--under-reach`, `--fountain-rim`, `--fountain-wall`, `--fountain-level`.
- `check_options.py` passes (99 documented and read).

**`voxelise.py`**

- `--sheets` fills a panel thinner than half a cell.
- `--hollows` counts what the surface encloses as inside.
- `--keep-outside` keeps the fountain's ring and disc as they are.

**`build.py`**

- `raw_name` and the `~matte` name as the main tool has them, plus `raw` as a per-style key (the neon fountain uses it for seed 7).
- Per-style `tex`.
- Cube settings `sheets` and `hollows`, and `--keep-outside` passed for fountains.

**`preview.py`** reads the cut-out with its own transparency as the design image where one was used.

**`assets.json`**

- New style blocks for both pieces, each with its own note.
- Five colours were read off the cut-outs by hand because the sheets have no swatch for them: solarpunk glass `#A9B1AE`, the neon pane's range, neon amber `#ECA538`, voxel tiles `#8E8B8A`, and the voxel shelter's count of five design colours.

## Afterwards: the second pass in the game

Added by the coordinating session (Claude, an AI).

- **The merge.** The agent's changes were carried into the tools as they stood by then: the fitting script by a three-way merge with one place where both sides had added a block (both kept), the build script with three such places, and the cube rebuild change by change, because the coordinating session had restructured it meanwhile. The merge was proved by building all ten fountains and shelters again with the merged tools. The five shelters and the anime fountain are byte for byte the agent's own (once the agent's files have their zero tangents mended, as the merged build does). The other four fountains differ, and only by one deliberate change made in the merged tools after the agent started: a face of five corners or more (a fountain's water disc) is now cut into triangles before the file is written. Eleven pieces of other families came out unchanged.
- **The build repeats now.** With the agent's fix for the centre piece's skirt, a fountain built twice gives the same bytes, so this merge could be proved as the others were.
- **The validator.** The voxel fountain kept its ring from the fitted piece with a relief map and no tangents, which draws a warning from the kits' validator. It is now fitted without a relief map, as the voxel kit's pieces are; all ten pass.
- **The audit.** With the ten pieces placed the game's collision audit counts zero in all five styles.
- **How they look** (`compare/water-neon_noir.jpg`, `compare/water-solarpunk.jpg`, `compare/water-voxel.jpg`). The neon fountain reads as its design: a timber rim with its lit band, white falling water round a dark centre piece. The neon shelter has its panes, a dark roof and a lit sign, and fewer lit strips than the kit's. The solarpunk shelter has its solar roof and its sign; its frame came out near black where the design draws brass, and it reads heavier than the kit's. The voxel fountain's centre piece and falls are cubes on a smooth ring, and the voxel shelter is the design's: an orange roof on dark posts with a lit panel.
