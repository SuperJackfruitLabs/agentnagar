# What was done about the review of the five-style record

Written by Claude (an AI), 2026-10-02, afternoon. The review is `review-five-styles.md` (a second AI agent, read-only, 45 numbered findings and 13 confirmations). Each finding below is either fixed (in the tools, the pieces or the text) or listed in the README under the heading named. "Rebuilt" means the piece was fitted again and the record's tables are written from the new files.

## Must fix

| Finding | What was done |
| --- | --- |
| 1. "Colour off the design" was measured before a tree's leaves, bed and lanterns were recoloured | Fixed in the tool: the figures in a report are now the finished texture's, measured the same way just before the texture is written; where colours were changed on purpose after the match, the earlier figures are kept as `colour_as_matched` with the share of texels changed. All pieces rebuilt (files unchanged where nothing else changed, reports new). The README's tables give the finished figures and a second table gives both for the pieces that differ. |
| 37. The game's own tests and collision audit were not run with the pieces in place | Run. With the 23 pieces as they were: 917 passed, 20 failed (17 counts of the collision audit, 2 for the solarpunk tree's missing `fairy_glow`, 1 timing test). The kit's own pieces pass the audit at zero in the same working copy. The causes were in the pieces: the reading chair's seat stood in two walkable cells in front of it in all five styles, the bench left cells the grid blocks behind it with nothing drawn within 10 cm in four, and the voxel tree's bed was a cube short at its edges. Fixed in the fit (`--plan-pull`, `--plan-cols`, `--plan-rows`, `--plan-notch`, the cube rebuild's `--solid`) and the solarpunk tree's lantern material renamed; the audit now runs with every build (`audit.sh`, in `run_all.sh`), and the suite's result after the fixes is in the README. |

## Should fix

| Finding | What was done |
| --- | --- |
| 2. The great tree was not captured from the same camera as the kit's | Fixed: the tree's camera is now set by one box for every tree put on that point (`frame: box=13.1x9.85x13.1`); kit, new, held-to-limit and first-sheet trees captured again; tree measures recomputed. |
| 3. "All 23 keep their kit's size" | Reworded: by the kit tests' rule on the file; as the game draws them the trees differ, and the sizes are given. |
| 4. "The shape decides each piece's triangle count" | Reworded: a rule decides it for the seats outside voxel; a tree's counts are chosen by eye and entered, and a third or more of a tree's triangles are the copies that fill its crown. |
| 5. The solarpunk reading chair's count was set by a forced rebuild, not a stall | Said so in the legend and under Decisions. |
| 6, 29. A piece's own `--materials` was dead in a style that counts swatches; the colour counts quoted were wrong | `build.py` now lets a piece's own count win. The two trees it affected (solarpunk, voxel) were built with four and keep four: their dead flags are removed, so the files do not change. The README gives the counts actually used, and says where the cutter misses a swatch. |
| 7. Solarpunk café chair: the brass was never one of the colours matched | Listed under Known faults. |
| 8. Generation times | Corrected in both documents from the timing log, which is now kept in the record. |
| 9, 10, 11. Frame-time wording | Reworded: where the frame time did not rise is said; the night's runs get their qualifying sentence; "up to four times". |
| 12. File sizes | Recomputed from the files. |
| 19. Low-poly tree: pale patches with dark centres on the crown | Listed under Known faults. |
| 30. A preview cited that was not in the record | The reference is corrected. |
| 31. `REUSE.toml` | `out-first-sheet/` and the new folders added. |
| 38. What going into the kits would take | Added under Open decisions. |
| 39. Material names | Added to WORKFLOW ("Material names the game acts on") and to the README: a tree's body is one material named for its lights, and it has no leaf-named material; for a planted tree the names are `trunk` and `leaf`. |
| 43. The tree measures have no repeat | Said; one tree was captured twice to give the spread. |

## Minor

| Finding | What was done |
| --- | --- |
| 13. A seated figure is in view at the edge of some café-chair tiles | Reworded. |
| 14, 33. Lantern count; stray glowing faces in the `lanterns` part | The tool now keeps only groups of touching glowing faces as lanterns (`--glow-part-least`); the low-poly tree rebuilt; the count corrected. |
| 15. A fifth model came with junk | Reworded. |
| 16. Counts of images and models | Recounted from `raw/` and the timing log. |
| 17. Blossom cubes on the voxel tree | Counted again on the rebuilt tree. |
| 18. "on the kit's 0.1 m grid" | Reworded: the seats; the tree's two sizes are named there. |
| 20, 21, 22, 23, 24, 25, 26. Faults and weak views seen in the pictures | Each listed under Known faults or beside the picture. |
| 27. A preview with wrong labels that nothing referred to | Removed from the record. |
| 28. The limit sheet's triangle counts were the reports', not the files' | `limit_compare.py` reads the files' counts. |
| 32. `run_all.sh` would have generated the next batch's objects | It now names its pieces (`PIECES`, default the seats and the great tree) and its steps. `run_game.sh`'s comment corrected. |
| 34. A raised crown's start was reported before the raise | Fixed in the report (no tree here was raised). |
| 35. WORKFLOW slips | Corrected. |
| 36. `bench/morning` held the night's runs | Renamed `bench/night`. |
| 40. The perch seats' tops were not measured | Measured and added to the table. |
| 41. The seat-height check uses the fit's own routine | Said. |
| 42. What a rebuild loses is not measured | Said. |
| 44. No neon piece shown in neutral light | Neutral-light views of the three neon seats added to `previews/`. |
| 45. A preview of the first neon sheet's cut | Replaced by the cut of the sheet the tree is built from, the other kept and named. |

## Not changed

- The reviewer's "could not check" items that need the game: the boot test was run again after the last change, and the suite's log is kept.
- Figures from runs whose files were replaced stay in `observations.md`, named as such.
