# What was done about the evening review

Written by Claude (an AI), the coordinating session, on 2026-10-03, about `review-evening.md`. Each finding was checked against the files before it was acted on; none was found wrong. Line numbers are the review's.

## Must fix

1. **The low-poly far swap is not a change in the game's code.** Confirmed in `city/godot/styles/pack_3d.gd` (`_plant` loads `<piece>_far.<ext>` for any pack wherever the file exists). Every sentence that said otherwise is rewritten (README, WORKFLOW, the street-trees page, the two bench notes, `fit_generated.py --far` and a comment in `build.py`). The swap was then measured as the review said it had not been: `work/far_swap.py` places the five low-poly twins beside the trees and `work/bench_far_swap.sh` runs the bench (`bench/trees-far-swap/`, 2026-10-03 05:16 to 05:20, pairs within 0.07 ms): +0.04 ms from above and +0.29 ms from the street, against +1.08 and +1.21 in full. Open decision 3 now offers it as the first way to go. A first run of this was thrown away: taking the twins out left their import files behind, and its last kit run drew the kit's trees only within 90 m (its log shows the load errors); `far_swap.py --remove` now takes those files out, and the game copy was checked to hold none.
2. **Five lanterns, not six.** Counted again (five parts, 0.86 to 1.05 m); the sentence says five.
3. **Frame cost laid on triangles.** The README, WORKFLOW and the street-trees page now say that the far-twin trial changes triangles, vertices and texture size at once and shows only that the full files cost; "differ in one thing" is gone; the trial's note says the diagonal's +0.03 ms is inside the kit pair's spread. The measurement of finding 1 is what the decision now rests on.
4. **The solarpunk café chair's seat.** Confirmed by a render of the file from five places (its seat top is charcoal, its back and leg tops tan). Not fixed: it needs its own colour work. It is now under "Known faults", with `previews/solarpunk-cafe-chair-seat.jpg`.
5. **The pale skirt at the solarpunk small tree's foot.** Fixed in the piece. New option `--planted-leaf-from M` takes out leaf faces lying wholly below M metres; only this tree uses it (0.5, both colourings). The refitted file lost exactly the 26 faces and nothing else: the trunk, the other leaf faces and the textures are byte-identical (its far twin was cut again from it). `planted_rules.py` now fails any planted piece with leaf faces wholly below 0.5 m; of the 40 tree and palm files only these two had them. After the refit: the kits' validator clean, the piece placed, the audit zero, the tree and the town captured again, the solarpunk sheets made again, and a rebuild of the solarpunk style alone in an empty folder byte for byte as kept (`out/replay-solarpunk.txt`). Picture: `previews/solarpunk-tree-foot-before-after.jpg`.

## Should fix

6. **The large anime street tree's open crown.** The three sentences now say the crowns are closed from above but for this one, and the faults list names it.
7. **The neon rows describe files the game does not draw.** The street trees' table now has a note under it naming the files the game draws for neon (`out-kit-green/neon_noir/`) with their colour figures and sizes.
8. **The anime and neon leafy shrubs are never drawn.** The README now says that 97 of the pieces are drawn and why the other two are not, and the shrub fault no longer implies they were seen in the game.
9. **Far twins outside low-poly.** Corrected to "outside voxel", with where the game draws them.
10. **The afternoon's low-poly pairs.** The sentence now says the neon pairs agreed within 0.02 ms and the low-poly kit pairs differed by up to 0.44 ms; the afternoon note's start time is 16:20 and its own sentence is the same.
11. **"Each merge was proved".** Now says the fountain agent's first merge could not be, and why, and how the second was.
12. **"Three to eight" colours.** Now "two to eight", and the ten props matched to two colours are named, with the warning that their figures say little.
13. **The writer's choices as the owner's.** WORKFLOW and `tools/assets.json` (`_triangles`) now mark the three kinds held near their limits as the writer's choice and the frame-time gate for planted pieces as a proposal; the README's Triangles section says the same.
14. **Three of the audit's six counts.** Confirmed in `city/godot/tools/collision_audit/audit.gd` (with no day the walker, player and tram counts are written empty). README, WORKFLOW and `tools/audit.sh`'s own description now say that `audit.sh` measures three counts and that the other three are measured by the game's own test of the audit, inside the suite (which passed after the last change to the pieces).

## Minor

15. "The textures are unchanged" now excepts the anime café chair (README and the fixtures addendum).
16. The `out-leaves/` shrubs are cited to `out/replay-after-adopting.txt`.
17. "Every piece now builds twice" is replaced by what was shown: four kept files were taken from the rebuild and have been built once since.
18. The model count now comes from `notes/gen3d-times.tsv` (runs and distinct models), not from the folder of generated files.
19. The five-in-one run's temperatures are what its files hold (79 to 82 °C after its runs); "63" is gone (README and WORKFLOW).
20. "Captured from the same camera" is now "at the same placements", with the planted pieces' camera chosen per capture.
21. The file-size sentence now speaks of a bench or chair (the perch seats are far smaller).
22. The roughness sentence now speaks of the neon trees and palms only.
23. `--leaf-swatches` and `--tones-by-rank` are attributed to `fit_generated.py` (README and WORKFLOW).
24. "Six with trunks thicker than 0.5 m" is now six reaching further than the game's 0.25 m, four of them over half a metre thick.
25. "5 to 10%" is now "about 5 to 11%".
26. The voxel trunk is "about 0.4 of its width" in both places.
27. The neon café chair sentence names the 1,440-triangle build the picture shows and the kept chair's 2,997.
28. The first suite run is now "917 of its 920 tests passed and three failed, with 20 failing checks among them".
29. The disturbed run's note says 0.46 to 1.35 ms, and its load-average figure is marked as watched, not kept.
30. The terrace page's first-pass sizes and the planter's 9,188 are corrected in an addendum under the agent's report (the report itself is kept as the agent gave it).
31. The street and views sheets now label their right-hand frames "new seats and great tree"; they were made again.
32. `run_game.sh` names all five styles; `game_tests.sh` says about a quarter of an hour; the README's game command says it runs on the laptop that holds the working folder; WORKFLOW gives the count rule's second condition (all of the surface within 0.8%).
33. `docs/vision/asset-studies/README.md` now says the first build went on to five styles and the square's props.

## What the review could not check

- The 38% toon-shadow figure, the earlier suite run and two other replaced figures are now in `notes/observations.md` with what printed them.
- The audit's "twelve seconds" is now "under half a minute" (the kept reports land 16 seconds after the newest piece placed, start included).
- The merge sentence's "up to a dozen conflicting places" is replaced by the counts that are on file: five places in the planting agent's own merge, twelve additions carried over by hand in the terrace agent's second pass.
- The agents' durations, the pilot's "two of the six" and the 226 railing panels rest on the ledger, the pilot's record and the contract note's arithmetic, as the review says; they are unchanged.
