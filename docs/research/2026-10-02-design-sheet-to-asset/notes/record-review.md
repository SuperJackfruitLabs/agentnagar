# The review of this record, and what was done about it

On 2026-10-02, about 06:25, a second AI agent was given the record as it then stood, with one instruction: check every claim against the files, open every picture, read the code, and change nothing. It reported about 35 minutes later. This is its list, in its order, with what was done. "Fixed" means the tools or the pieces were changed and everything was built, captured and measured again; "corrected" means a sentence of the report was changed.

## Claims in the report

| What it found | What was done |
| --- | --- |
| "Seven more models were not fitted" counted the two worn benches, which were fitted, and left out the perch seat. | Corrected: five, and the perch seat named. |
| The report said the footprint rule no longer squeezed the trees. The neon tree drew 5.44 m in the walking band against a 5.2 m footprint and the game placed it at 0.973 of its width. | Fixed. Edges that cross the top of the band outside the bed are pulled in and the bed is held to its size. The neon tree now draws 5.20 by 5.10 m and is placed at 1.020 by 1.040. `check.py` fails a tree that reaches out. |
| "The pilot got slabs and cards" was wrong: two of its six crops gave real trees. | Corrected. |
| "Marks the whole piece as metal where the image is a night scene" was wrong: studio-lit neon chairs and a low-poly chair were marked too. | Corrected, with the figures. |
| "The fewest triangles that hold the shape" did not hold for the neon bench and reading chair, which were forced to the kit's budget and fail the fit's own rule. "Six of eight" rested on that, unsaid. | Said, under Known faults and Decisions. |
| "I ran exactly this": the replay had been made with the working folder's copy of the tools, and a fresh run printed no game scales (the check ran before the captures) and no round-2 row. | Fixed and run again from this folder's `tools/`. The check now runs after the captures. The round-2 row needs the pilot's own captures; the report says so. |
| "The sit anchors still hold" was not measured, and the seats' tops had moved by up to 9 cm. | Fixed: `--seat` moves the seat's top to the kit's height; `seat_top.py` measures it; the report has the table. |
| `fit_generated.py` was said to document all its options; 22 were missing and one documented option did not exist. | Fixed: the documentation was rewritten, and `tools/check_options.py` confirms that the options documented are the options read. |
| No file supported "58%", "42,000" or the card's temperatures; "no closer" understated "further"; the requirements left out `kwin_wayland`, `setpriv` and `rsync`. | `observations.md` sets down the figures from replaced runs; the bench now keeps the temperature after each run; the two sentences are corrected. |

It confirmed the 21 images, the 16 objects from 11 images, the generator's times, every cell of the three tables then in the report, the stretch figures, and that the replayed pieces matched by checksum.

## The pictures

| What it saw | What was done |
| --- | --- |
| The neon bench's light strip lay on top of the seat boards. | Fixed: a strip carried from the kit is hung under whatever of the new piece lies above it. |
| The neon tree read as a bright khaki-brown mass at night in which the lights barely showed; the kit's tree was nearer the target. Its hanging lanterns and its bed strip were gone, and a black void sat in the crown from above. | Partly fixed. Its leaves take the neon kit's leaf green, its bed has its line of light, and the mass inside the crown is in the leaves' shade. The hanging lanterns are still lost (Known faults). |
| The low-poly tree read brown at dusk, showed two dark holes and bleached blossom patches from above, and its lanterns were a metre tall and cream. | Partly fixed. The lanterns take the sheet's lantern yellow and the inner mass is lighter. Size, blossoms and the olive palette are under Known faults. |
| The low-poly bench had pale speckle on its back board, and its seat boards were fused into one slab. | The speckle is fixed (three design colours, the sheet's swatch count). The fused boards are under Known faults. |
| The low-poly reading chair's pillow covers a third of the seat, and no picture showed a sitter close up. | Under Known faults. `compare/sitters.jpg` shows the benches' sitters; the chairs are under Not done. |
| The neon armchair's bar lights no floor. The "park" rows of the wider views showed no new piece. | The first is under Known faults. The wider views now show the night view in rain in place of the park. |

It found the new pieces clearly better in both trunks, the low-poly crown's separate masses, the low-poly reading chair and the neon chairs' shapes.

## Hygiene

It found no local paths, names, addresses or keys in the folder's text files or in the metadata of its models and images, and the licence annotations covering every model, image and shell script.

| What it found | What was done |
| --- | --- |
| `bench.sh` wrote to the game's own cache folder and deleted the last result there. | Fixed: whatever is there is put aside and put back, also when the run is interrupted. |
| `check.py` left a compiled cache file in the pilot's tools folder. | Fixed: it writes none. |

## The code

| What it found | What was done |
| --- | --- |
| The tree fit lifted stray vertices to 2.27 m, but faces still crossed 2.2 m outside the bed. | Fixed, as above. |
| `run_all.sh` ran the check before the captures it reads. | Fixed. |
| The kit's light strip was copied at the kit's coordinates. | Fixed, as above. |
| "Colour off the design" was computed before the median, the lift and the flattening, so it was not the finished texture's. | Fixed: it is measured on the finished texture, and the report gives it beside the share of the design's colours found. |
| `check.py` computed the footprint overhang and never failed on it. | Fixed. |
| A failed fit was printed and the run went on, so an old piece could be placed. | Fixed: a failed fit stops the run. |
| A comment promised a lamp for the slab under the armchair, which gets none. | Corrected; the slab can be named `light` where a lamp is wanted (the neon tree's bed). |

## Found afterwards, by the same kind of check

Started directly, the game could not load a piece that had just been swapped in, because swapping deletes the engine's cached import and only the capture tools imported first. `run_game.sh` now imports first, `boot_test.sh` starts the game through it, and `build.py` deletes only the cache of the piece it swaps.
