# Review of the five-style record

Reviewed on 2026-10-02 by a second AI agent (Claude), read-only: `agentnagar/docs/research/2026-10-02-design-sheet-to-asset/` against its own files, the game's code under `city/`, and the working folder. Nothing in the record or the working folder was changed except this file. No Godot, Blender, capture, bench or image-to-3D run was made.

"Seriousness" is must fix, should fix or minor. "README" and "WORKFLOW" are the record's two documents. Paths without a folder are in the record.

How to read the picture findings: a first pass of picture reads returned nothing for nine sheets (a size limit on batched reads). Each was read again singly, reduced, and the points below were then checked on full-size crops or on the working folder's captures. Every picture in `compare/` (24) and `previews/` (12) was seen. Where a point rests on a reduced view only, it says so.

## Claims that are wrong or unsupported

1. **README, table legend: "Colour off the design: the finished texture against the design image."** It is not the finished texture for the trees. In `tools/fit_generated.py` the figures (`colour_delta_e`, `materials_reached`) are computed at lines 1103 to 1123; the bed walls (`--bed-colour`, line 1156), the leaves (`--leaf-colour`, line 1195), the lanterns (`--lantern-colour`, line 1214) and the warm texels (`--glow-warm`, line 1221) are recoloured afterwards. The neon tree's report says 73.3% of its texels were then moved to the kit's green, the anime tree's 87.1%. Measured the same way on the texture that is actually inside `out/neon_noir/tree_banyan.glb`, the neon tree stands at about 8.1 and about 92% found, not 3.8 and 98%: the design's dark olive (Lab 25.3, -3.5, 14.0) is met by texels of median Lab 36.1, -29.0, 18.3, a distance of 28. The anime tree comes out at about 5.2 and 100% (reported 6.5 and 91%). My replication agrees with the reports to 0.2 where nothing is recoloured afterwards (low-poly bench 1.1 against 1.0, solarpunk tree 2.0 against 2.2, low-poly tree 4.3 against 4.2), so the method is sound; its "found" share is less exact than its distance. The same holds for the held-to-limit rows and for the sentence "the tree built from it is matched to its design (colour off by 3.8, 98% of the design's colours found)". The first review raised this class of fault and `notes/record-review.md` says it was fixed. **Must fix.**

2. **README, "What is ready": "The piece ... was captured from the same camera as the kit's piece."** Not for the great tree. `tools/assets.json` gives it `"frame": "auto"`, and `tools/asset_views.gd` (lines 134 to 141) then stands the camera back by the piece's own bounds and aims at its own centre. From the sizes in the captures' `asset-views.json` the new anime tree's camera is about 8% closer than the kit's, the neon tree's about 3% closer, the voxel tree's about 4% further. In `compare/tree-anime_cel.jpg` (above-0) the fountain at the bottom-left is mostly in frame in the kit's tile and nearly out of it in the new one. So in the five `compare/tree-<style>.jpg` sheets the two tiles are not like for like in size. The seats (fixed cameras) and the street and standard views are unaffected. **Should fix.**

3. **README: "All 23 keep their kit's size."** True of each file against its spec, by a rule that allows 10% plus 2 cm. As the game draws them (`asset-views.json`, kit against new) the new trees are smaller: anime 12.10 by 9.47 by 11.72 m against 13.07 by 9.81 by 13.12 (7% narrower, 11% shallower), solarpunk 12.30 by 9.61 by 11.65 against 13.05 by 9.88 by 13.01, low-poly 12.24 by 9.50 by 12.10 against 12.68 by 9.82 by 13.13, neon 12.76 by 9.82 by 12.26 against 13.07 by 9.81 by 13.12. The voxel tree is 11% deeper (9.54 m against 8.56). The cause is the game's fill rule (`pack_3d.gd` `_fill_footprint`): the kit's trees have a smaller bed against their crown and are stretched 1.03 to 1.06; the new ones 1.02 by 1.04; the voxel tree 1.06 against the kit's 1.019. **Should fix** (say which size is meant).

4. **README, Decisions 1 and "Triangles": "The shape decides each piece's triangle count."** A rule decides it only for the twelve seats outside voxel. A tree's counts are numbers typed into `assets.json` (`--parts 3000,900,10000` and the like), and 30 to 44% of each tree's triangles are the copies `--crown-fill` adds (low-poly 6,366 of 20,473; neon 8,545 of 28,222; anime 10,922 of 24,617; solarpunk 6,659 of 21,029). WORKFLOW says "a tree takes the counts given", which is accurate; the README's sentence is not. **Should fix.**

5. **README, table: Solarpunk reading chair, 1,500 triangles, inside its limit; legend: "Where the reduction stalled and the piece was cut from a rebuilt surface".** This chair's reduction did not stall. `assets.json` forces `--remesh 0.0085` for it (its report has `rebuilt_surface_m` and no `rebuilt_because_stalled_m`). Cut straight to 1,499 triangles it fails the fit's own rule seven times over: 95% within 17.35 mm, worst 50.3 mm, against 2.4 and 12.2 allowed (working folder, `scratch/sp-reading-1500.json`). With the forced rebuild the rule is judged against the smoothed surface and passes at once. It is the only one of the 23 with a forced rebuild (the anime and voxel reading chairs and the two perch seats are true stalls, at one 180th of the diagonal). So it is a piece whose count a choice of route set, it is not among the nine "over", and it is not under Decisions. The built piece looks sound in the game. **Should fix.**

6. **README, Decision 6: "matched to as many colours as its sheet shows swatches ... the trees to five to seven"; legend: "(three to seven, by piece)".** By the reports the solarpunk and voxel trees were matched to four colours, not six and five as their `flags` say. Cause: `build.py` puts the style's swatch count on the command line before the piece's own `--materials`, and `opt()` in `fit_generated.py` takes the first; the flag is silently dead. The count itself is short where the cutter misses a swatch: the solarpunk seating sheet draws four swatches a seat and `boxes.json` has three (the brass one, drawn with a sheen, is gathered into the object: `pieces: 2`); the voxel bench's sheet draws three and two were found. The range is two to seven (voxel bench and café chair: two). The voxel perch seat was matched to five by default because one swatch was found. **Should fix.**

7. **README, table: Solarpunk café chair, "Design colours found 100%".** That is 100% of three colours; the brass was never one of them. On the piece the design's brass sleeves and caps are the timber's colour: light pixels on the legs average RGB 212, 164, 114 against 222, 158, 111 for the back's timber (unlit pass, working folder `captures/new/cafe-chair/solarpunk/asset-eye-2-albedo.png`); the sheet's brass swatch is about 191, 158, 96. My leg sample may include a little seat timber, so this supports "not distinct", not an exact distance. **Should fix.**

8. **README, "How it was done" and "Time": "69 to 290 seconds an image"; WORKFLOW step 3: "one and a half to four minutes".** The working folder's `logs/gen3d-times.tsv` has, for models in this record, 292.0 s (solarpunk tree), 361.0 s (anime tree) and 477.2 s (anime reading chair); the shortest is 68.7 s. The two documents also disagree with each other. If the long runs shared the card with something else, the log does not say. **Should fix.**

9. **README, Frame time: "Within every style the frame time rises from one run to the next whichever pieces are in place."** Not in four of the ten scenes: low-poly diagonal 4.11, 5.46, 4.74, 4.91; low-poly street 4.35 then 4.33; neon street 3.51 then 3.46; voxel diagonal 3.78 then 3.77. "They are the card's temperature" is an inference: no run without a swap was made, and in low-poly diagonal the slowest run (5.46 ms) has the lowest GPU time of the four (`gpu_p99` 3.84 ms). The conclusion "This table does not measure the pieces" stands. The arithmetic is right: range -0.61 to +0.59, mean -0.03, last run slowest in eight of ten, new medians 2.45 to 5.46. **Should fix** (wording).

10. **README, the night's runs: "those pieces cost 0.04 and 0.07 ms ... 0.14 and 0.17 ms ... the only steady figure".** The arithmetic is right. But the order was kit, new, kit, new with the card at 71, 74, 76, 77 degrees after each, so the new pieces were always measured on the warmer card, the confound the README names for the morning and not here. The kit's own second run is 0.05 to 0.09 ms slower than its first. The neon figures survive it (the kit's second run is still faster than the new pieces' first); the low-poly ones are within it. **Should fix** (one qualifying sentence).

11. **README: "later runs were up to three times slower than the first"; WORKFLOW trap 19 and `bench_pairs.sh`: "up to four times".** `bench/five-in-one-run/` gives 4.05 times (anime street 2.517 to 10.197) and 3.98 (solarpunk diagonal). "From 63": the record's files hold only the temperatures after each run (79, 81, 81, 82). **Minor.**

12. **README, File size: "The voxel pieces are ... smaller than the kit's."** Two of five are larger: café chair 8,188 bytes against 6,396, reading chair 16,192 against 7,436. "The kit's seats are 14 to 38 kB" leaves out the kit's perch seats (6 kB) and voxel seats (6 to 18 kB); "0.22 to 0.56 MB a seat" leaves out the new perch seats (25 and 35 kB). **Minor.**

13. **README, Not done: "no capture shows a figure in a café chair".** A cut-off seated figure is at the right edge of the café-chair `eye-0` tiles, kit and new, in `compare/seats-lowpoly_tropical.jpg`, `seats-anime_cel.jpg`, `seats-solarpunk.jpg` and `seats-voxel.jpg`, in the chair across the table. None is visible to me in the dark neon tiles. What holds is narrower: no capture shows how a figure sits on one. **Minor.**

14. **README, Known faults: "The low-poly tree keeps its six [lanterns]".** The `lanterns` part of `out/lowpoly_tropical/tree_banyan.glb` holds five lantern-sized pieces (72 to 103 triangles, 0.88 to 1.10 m tall) and 18 fragments of one to three triangles (26 triangles) in the bed and high in the crown. "About a metre" is right; the kit's eleven at 0.54 m is right. Whether a sixth sits unlit in `body` I did not determine. **Minor.**

15. **README, Decision 10: "Only the four that came with junk were generated again."** A fifth came with junk and kept its model: the solarpunk café chair (`previews/solarpunk-models-with-slabs.jpg`, a stray on the ground at the tile's bottom edge; its report: `stray_parts` 1, 3.3% of the surface, dropped by the fit). **Minor.**

16. **README: "Every object given to it from a design sheet, 31 by now"; "Five more models ... were not fitted"; "this used eleven".** By `raw/` and the timing log, 29 objects from design sheets (A and E) had gone through by the end of the second batch, 32 with the three plain shapes, and more than 40 by the time the README was last edited. Not fitted from the first batch: six, with the low-poly perch stool. The 23 pieces come from ten of the pack's 126 design sheets (two sheet kinds, five styles); eleven only if the neon tree's two revisions count as two. **Minor.**

17. **README, Known faults: "One pale blossom cube sits on top" (voxel tree).** Two are visible in `compare/tree-voxel.jpg` (new, above-0), three in `previews/trees-generated-and-built.jpg` (voxel, built, from above). **Minor.**

18. **README, "How it was done", step 4: "rebuilds the fitted piece on the kit's 0.1 m grid".** True of the four seats. The tree is on 0.25 and 0.75 m, which are neither the kit's 0.1 nor its 0.7; Decision 8 says so, this sentence does not. **Minor.**

## Faults seen in the pictures

19. **`compare/tree-lowpoly_tropical.jpg`, new, above-0.** At least six pale patches with darker centres on top of the crown, where the design draws blossoms; they read as white-rimmed pits. `notes/record-review.md` says of the first review's "bleached blossom patches" that they "are under Known faults"; the README has no low-poly tree entry and its only use of "blossom" is for the voxel tree. A counter-example, with finding 1, to "Each finding was fixed or listed". **Should fix** (list it or correct the note).

20. **`compare/seats-solarpunk.jpg`, café chair, and the unlit pass.** Beside its design (`inputs/solarpunk/cafe-chair.png`: three back slats with gaps, brass sleeves and caps) the built chair has a back that is one slab with pale lines painted where the gaps were, and smudged, dark-fringed edges where tan meets charcoal on the legs. The chair has no entry under Known faults. Whether the generator or the fit closed the gaps I did not determine. **Minor** (the colour point is finding 7).

21. **Armchairs with something on the seat.** The README lists the pillow only for the low-poly reading chair. The anime armchair (`compare/seats-anime_cel.jpg`, both cameras; plain in the unlit pass) and the solarpunk armchair (`compare/seats-solarpunk.jpg`) carry a pillow on the seat against the back; the voxel armchair has a cushion block, 0.2 by 0.1 m, standing 10 cm above the seat top at its back-middle (from the GLB). **Minor.**

22. **`compare/tree-neon_noir.jpg`, new, above-0.** The middle and upper crown read olive-khaki, green only toward the rim. The README says the khaki was answered by the kit's green. The body texture is green (median Lab 34.7, -26.4, 16.5), so this is the lamp, the painted halo or the inner mass carrying the sheet's top view; I did not determine which. A gap low on the near-left of the crown shows the lit bed: a side gap between leaf masses, not a hole in the top. **Minor.**

23. **`compare/seats-anime_cel.jpg`, reading chair.** The chair reads lilac (median RGB 137, 132, 168 over the piece) where its design is cream. The texture is right: the unlit pass is cream (234, 223, 209) with a slate pillow and brown base. So it is the scene's light on a near-white piece, and the sheet shows only the lit view. A few short stray ink ticks on the back cushion, the right arm's front edge and the pillow's lower edge; they are in the unlit pass too. Slight, not scribble. **Minor.**

24. **`compare/street-five-styles.jpg` and `previews/voxel-tree-street.jpg`, voxel.** The new crown starts much lower than the kit's: its cubes begin at 3.0 m, the kit's leaves at 4.9 m. The kit's long bare trunk becomes a short thick one. It is what the sheet draws and it clears the walking band; it is not mentioned. **Minor.**

25. **`compare/tree-anime_cel.jpg`, new, above-0.** A dark gap on the left of the crown shows branch through the ring. The rest matches the README's own account of its weakest piece. **Minor.**

26. **The café-chair rows of all five seats sheets.** The table top hides most of the seat from both cameras, and in low-poly, neon and anime a foreground palm crosses the tree's street-level tile. The pictures are a weak view of those pieces; the README does not say so. **Minor.**

27. **`previews/solarpunk-armchair-cut-straight-and-rebuilt.jpg`.** Its tiles are "1,500 shaded" (wrecked), "2,999 shaded" (sound), "1,500 colours", "1,500 front". None is labelled rebuilt and none shows the piece as built (1,500 from a rebuilt surface). Neither document refers to it. I found no report for the 2,999 build, so I cannot say whether that tile is a straight cut. **Minor.**

28. **`compare/limit.jpg`, labels.** The tree counts on the tiles (20,478; 28,227; 24,622; 21,049; 6,498; 7,046; 7,030; 7,310) are the reports' `tris`, 5 to 32 more than the files' triangles in the tables (20,473; 28,222; 24,617; 21,029; 6,492; 7,039; 7,021; 7,278). `tools/limit_compare.py` reads the report. **Minor.**

## Faults in the code or the how-to

29. **`tools/build.py`, `fit()`: an option given twice, the first silently winning.** See finding 6. A piece's `--materials` in `assets.json` has no effect in a style with `"materials": "swatches"`. **Should fix.**

30. **WORKFLOW trap 4 cites `previews/lowpoly-tree-budget.jpg`.** The file is not in the record (the working folder has a `.png` of that name). `notes/observations.md` cites `bench/first`, which is also only in the working folder, as it says. **Should fix.**

31. **`REUSE.toml`.** The record's annotation for AI-generated models ("CC-BY-SA-4.0 AND CC0-1.0") lists `out/`, `out-budget/` and `out-worn/` and omits `out-first-sheet/`. That model is matched only by the general `docs/**` and `**/*.glb` rules, as plain CC-BY-SA-4.0. Nothing is uncovered (239 files, all matched). **Should fix** (one path).

32. **`tools/run_all.sh`, line 14.** `build.py gen <style>` with no names takes every entry, the sixteen queued prop objects included. A fresh run as "Running it again" describes would cut their sheets and put up to eighty more objects through the generator. The README does not say. `tools/run_game.sh` still says "(lowpoly_tropical or neon_noir; the other styles are untouched)". **Minor.**

33. **`tools/fit_generated.py`, stray glowing faces.** A glow part is refused when it has fewer than 12 faces in all (line 1377), but there is no test of each loose bit, so one- to three-triangle fragments ride along in `lanterns` (finding 14). **Minor.**

34. **`tools/fit_generated.py`, line 447.** The report's `crown_starts_m` is the value before the crown is raised; the script's own variable is raised to `--clear`. `build.py` passes the report's value to `voxelise.py --upper`. No tree here was raised (`tree_raised` is null in all), so nothing was affected. **Minor.**

35. **WORKFLOW, small slips.** The options table gives `"upper": 0.7`; `assets.json` uses 0.75. "Keep 95% of the generated surface within 0.16% of the piece's size" leaves out the second test (all of it within 0.8%) and means the diagonal. `look.py` writes `<name>-front.png` and four more, not `previews/<piece>.png`. **Minor.**

36. **`bench/morning/` holds the night's runs** (taken about 07:30); this morning's are in `bench/` itself. The README's Files section says so; the name will mislead. **Minor.**

`tools/check_options.py` does what it claims and no more: the 71 options `fit_generated.py` documents are the 71 its code reads. It does not cover WORKFLOW's table (I checked that by hand: every option there exists), `voxelise.py`, the keys of `assets.json`, or defaults.

## Missing

37. **The game's own tests and its collision audit were not run with the pieces in place, and the record does not say.** "Not done" lists only the kits' suites. By reading, one game test would fail: `city/godot/tests/test_solarpunk_pack.gd`, `test_fairy_lights_glow_in_the_great_tree_at_night`, asserts a material named `fairy_glow` among the lamp materials; in the solarpunk kit only `tree_banyan.glb` has one, and the new tree's `lights` part is `lamp_glow`. Behaviour changes with it: `lit_pack.gd` keeps `fairy_glow` dark by day and `pack_3d.gd` leaves `lamp_glow` at 0.35. The collision audit is held to zero in every style (`tests/test_collision_audit.gd`); the working folder's own contract notes call it "the rule that bites" and give the command to run it without a display. I ran neither; this is from the code and the GLBs. **Must fix** (run them or say they were not run and what is expected).

38. **What going into the kits would take.** Besides the triangle limit (nine pieces), each kit's tests require the committed kit to be byte for byte what its generator builds, and zero errors and warnings from the Khronos validator (`city/tools/styles/shared/kittests.py`). All 23 would fail the first as things stand; the second was not run. Open decision 5 asks "whether any of this goes into the kits" without this. **Should fix.**

39. **Material names.** The whole body of each tree outside voxel, trunk, bed and leaves, is one material named `lamp_glow` (the voxel tree likewise, with no emission). The game tells leaves by material name (`kit_town.gd`: `leaf|leaves|foliage|frond`), as does the collision audit for the great tree. No new tree has a leaf-named material. WORKFLOW's "Material names the game acts on" lists `lamp_glow` and `fairy_glow` only. For the great tree the effect is probably nil, since the fit lifts everything outside the bed above the band, but that is my reading, not a run. **Should fix.**

40. **The perch seats' tops and the voxel perch seat's size.** "The fifteen seats have their tops at the kit's heights" covers bench, café chair and reading chair; the three perch seats have no `--seat` flag and are not measured. They fill the kit's box, so anime and solarpunk are at the kit's height; the voxel one is 0.50 m high against the kit's 0.51 and 0.60 m long against 0.55 (5 cm further back). **Minor.**

41. **The seat-height check is the fit's own measure.** `seat_top.py` and `fit_generated.py` use the same routine, binned to 1 cm, so agreement is by construction. It shows the tops are where the kit's are by that measure; it is not an independent check, and the kit's own tops differ from one another (0.42 to 0.50 m) while the game seats a figure at one height. **Minor.**

42. **"Shape kept" for the five rebuilt pieces** is measured from the rebuilt surface, as the legend says; what the rebuild itself lost (cells of 4.3 to 8.7 mm) is not measured anywhere. **Minor.**

43. **The tree measures.** Each is one capture, read in a window 11% of the frame's width by 23% of its height, with no repeat; no figure says how much it moves between two captures of the same tree. "Closer by 0.04" (low-poly) has nothing to be set against. The voxel tree's "a little further" rests on one term at its floor: zero pixels brighter than 1.5 times the median against the kit's 0.4%; on the other four measures it is closer than the kit's. **Should fix** (a sentence).

44. **No neon piece is shown by day or in neutral light in the comparison sheets.** Every neon tile is a night capture and the seats are near-silhouettes. The two neutral views are `previews/benches-new-and-worn.jpg` (bench) and `previews/neon-cafe-chair-budget.jpg` (café chair); the neon armchair as built has none. **Minor.**

45. **`previews/cut-neon_noir-A-great-tree.jpg` is of the first, night-lit sheet**, not the sheet the neon tree is built from. **Minor.**

## Confirmed

46. `python3 tools/report_tables.py . --check README.md`: 104 of 104 rows agree. Every triangle count and byte size in the tables matches the GLBs (my own parse) and the kit's files.
47. All 35 GLBs in the record are byte-identical (SHA-256) to the working folder's, to `.asset-pilot/2026-10-02-replay-five/`, and, for the 23, to the game copy.
48. Counts: 23 pieces; nine over their limit (the trees 2.8 to 3.8 times); 28 images in two batches (21 and 7); 18 of them through the generator; 126 design sheets in the pack (21 by six styles); 36 perch seats placed; thirty prop sheets.
49. Kit limits, sizes and named parts match `city/tools/styles/<kit>/specs/`; the size rule (10% plus 2 cm) is the kit tests' own in all five kits. All spec parts are present; the trees' walking-band boxes are within the catalogue's 5.2 by 5.1 m footprint.
50. The game's rules as described: the band 0.15 to 2.2 m and fill to the drawn footprint (`kit_town.gd`, `pack_3d.gd`); perch seats as children of a holder; `lamp_glow`, `fairy_glow`, `light`, `lights` and `glow_lights` (neon only, `tree_banyan`).
51. Scales the game gave: every row of the table; the kit's voxel seats get the same scales as the new ones; perch seats 1.000.
52. All fifteen measured seats have their backs on the kit's side (from the GLBs); none is turned wrongly. Stretch 1.22 to 1.85. Seat tops before the move: 7 cm low to 9 cm high, as stated.
53. Tree measures: every figure, the four differences (0.04, 0.07, 0.12, 0.27), "four of five closer than the kit's", "none as close as round 2".
54. Bench: the tables; order and temperatures in `bench/pairs.txt`; NVIDIA RTX 3070 Ti at 1920 by 1080 (working folder logs); no generator run overlapped it.
55. Nothing under `city/` was modified after the work began; nothing is committed.
56. The voxel reading chair: the cube step did not darken it (green texels, median L 31.0 against 30.2 in the fitted piece); the near-black cubes in the game picture are not in the texture, so "in the library's light" is fair; about 6 L of the darkening is the texture.
57. Pictures that show what the README says: `street-five-styles`, the five `street-<style>`, `sitters`, `perch-seats`, `limit`, `anime-tree-three-seeds`, `benches-new-and-worn`, `crops-cleaned`, `neon-cafe-chair-budget`, `other-generated-models`, `solarpunk-models-with-slabs`, `voxel-seats-fitted-and-cubes`, `voxel-tree-street`, `trees-generated-and-built`. The neon bench's strip hangs under the seat. The low-poly crown is closed from above.
58. `check_options.py` passes; every option in WORKFLOW's table exists; `setup.sh`'s needs from the earlier pilot (`--bare`, `cvenv`, `try.sh`, `banyan/inputs`) are there.

## Could not check

- That the game starts and runs clean: I may not run it. The five boot logs hold the engine's banner and exit 124 and no error line; the 25 seconds include the import; they do not show that a piece was drawn. They were written at 12:00 to 12:02, before the perch seats were last placed (12:13 to 12:15).
- Which build of the anime and solarpunk trees the standard views show: their first frames were saved 7 and 8 seconds after those trees were built. Plausible, not provable from files.
- The captures, contract check, seat heights and tree measures in the fresh replay folder: the README says they were not run again; I confirm only the GLBs.
- The Khronos validator on the pieces; Blender's version.
- "Four as flat cards" in the earlier pilot (its README supports "two of six" only); that `#296238` was read from the kit tree's colours; the figures 14,859, 9,161 and 6,489, which are in no file of the record (`notes/observations.md` covers the night's figures only).
- "3.1 GB" of raw output: it is 4.3 GB now and growing.
