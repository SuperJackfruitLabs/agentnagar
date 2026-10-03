Review of the research record docs/research/2026-10-02-design-sheet-to-asset/ (the evening review)

Written by Claude, an AI reviewing agent, on 2026-10-02. The work ran past midnight into 2026-10-03. One edit since, on 2026-10-03: the owner is named where the review used a pronoun.

What I was given:
- the brief, scratch/review-brief.md in the working folder;
- the record;
- the working folder .asset-pilot/2026-10-02-sheet-to-asset/ beside the checkout (LEDGER.md, logs/, out/, captures/, game/, agents/, scratch/);
- the checkout agentnagar, on branch docs/asset-to-sheet-pilot;
- the owner's messages that the record's decisions rest on, quoted to me by the coordinating session.

How I worked: read-only. Nothing was written, moved, deleted or committed. I ran no Blender, Godot, game, test suite, rebuild, bench, image-to-3D model or validator. I only read files and ran grep, small read-only Python (GLB headers and buffers parsed with numpy, the JSON reports), `python3 tools/report_tables.py . --check README.md`, `tools/check_options.py`, and git status/diff. I looked at every sheet in compare/ and at the previews the pages name. Where a sheet left a doubt I also looked at the game captures behind it.

Paths are relative to the record unless they say "working folder" or "checkout". Line numbers are as the files stood at the time of review.

FINDINGS

Must fix

1. Must fix. The low-poly far swap is not a change in the game's code.
- The sentence: README.md:669, open decision 3: "give the low-poly pack the far swap the other three packs have, which is a change in the game's code and not made here".
- The same error appears in:
  - README.md:405: "Three styles swap to a second file, `<piece>_far.glb`, beyond 90 m".
  - README.md:491: "The two styles differ in one thing: neon, anime and solarpunk draw a tree's far twin ... and low-poly draws all 608 copies in full".
  - families/street-trees-and-palms.md:9: "Low-poly and voxel have no such swap and draw every copy in full".
  - WORKFLOW.md:101: "the far twin three styles draw beyond 90 m".
  - bench/trees-as-far-twins/README.md:9: "the low-poly pack never draws them, because it has no far swap".
- What the code shows:
  - The swap is not tied to a pack. Pack3D._plant (checkout city/godot/styles/pack_3d.gd:804-825) loads `<piece>_far.<ext>` for any planted piece whenever `ResourceLoader.exists(asset(far_path))`. It then splits visibility at FAR_TREE_M = 90.
  - styles/lowpoly_tropical/pack.gd extends Pack3D and overrides only _make_town and make_player_marker. Its style.json plants street trees and palms through the same tiled path.
  - Low-poly draws every copy in full only because no `_far.glb` sits in its assets. The working copy of the game holds five far twins in each of anime, neon and solarpunk, and none in low-poly.
  - The record already holds the five low-poly far twins (out/lowpoly_tropical/*_far.glb, "same" in out/replay.txt).
  - No test ties far twins to particular packs.
- So "the far swap" means copying five files into the pack. It is also the one way that was never measured. The trial drew the twins at every distance, which is not what the swap does (full trees within 90 m, twins beyond).
- How checked: read pack_3d.gd, the low-poly pack.gd and style.json; listed the game copy's asset folders; grepped city/godot/tests.

2. Must fix. The low-poly great tree has five lanterns, not six.
- The sentence: README.md:561: "The low-poly tree keeps its six (about a metre tall, as drawn; the kit hangs eleven of half that size)".
- What the file shows: out/lowpoly_tropical/tree_banyan.glb holds five lantern pieces, 0.86 to 1.05 m tall.
- The earlier review raised this (notes/review-five-styles.md, finding 14). notes/review-five-styles-answers.md:37 answers "the count corrected", but the sentence still says six.
- How checked: counted the separate lantern parts in the GLB.

3. Must fix. The frame cost is attributed to triangles further than the trial allows.
- The sentences:
  - README.md:491: "The two styles differ in one thing ... So in low-poly it is the size of the planted trees that costs (...), and at about 775 triangles a copy the cost is gone".
  - README.md:669: "Drawn as their far twins (about 775 triangles) at every distance, the low-poly ones cost 0.03 to 0.11 ms".
  - WORKFLOW.md:51: "which is how the low-poly trees' cost was traced to their triangles".
  - families/street-trees-and-palms.md:62 also lays the cost on "Triangles".
- What the files show: the trial changes three things at once. Low-poly trees and palms in full against their far twins:
  - triangles: 2,250-3,680 against 774-776;
  - vertices (flat-shaded): 6,713-11,021 against 2,322-2,328;
  - texture: 1024 x 1024 against 256 x 256, a sixteenth of the texels.
- The trial's own README says it "does not tell triangles from texture size" (bench/trees-as-far-twins/README.md:22-23). The README and WORKFLOW drop that.
- On the diagonal, +0.03 ms is inside the kit pair's own spread: 3.994 against 4.099, a 0.105 ms gap. That gap also breaks WORKFLOW.md:51's own rule that a pair agree within 0.1 ms.
- Low-poly and neon differ in far more than the swap: pack, kit trees, lighting, materials. "Differ in one thing" is false.
- What the numbers do support: the 608 full copies cost 1.08 and 1.21 ms (bench/trees-only/), and drawing the smaller twins instead removes nearly all of that. They show neither that triangles are the cause nor what a 90 m swap would cost.
- How checked: recomputed the pairs from bench/trees-as-far-twins/*.json; parsed the GLBs for triangles, vertices and texture sizes.

4. Must fix. The solarpunk café chair's seat is near-black, and the record does not say so.
- The sentence: README.md:567 gives one fault: "The brass its design draws on the legs was never one of the colours matched". The table row and the pages say nothing more.
- What the pictures show:
  - The design draws tan slats on the seat.
  - The built seat is charcoal with a few wood streaks: working folder captures/new/cafe-chair/solarpunk/asset-above-1.png, and the second chair at the right edge of "new (eye-0)" in compare/seats-solarpunk.jpg.
  - About 77% of the seat's top is darker than luminance 70 in the file's own texture.
- Why no sheet shows it plainly: in compare/seats-solarpunk.jpg the table hides the chair's seat in both eye frames, and the seat sheets have no view from above.
- How checked: looked at the captures and the sheet; sampled the texture over the seat-top faces.

5. Must fix. The solarpunk small street tree has a pale skirt at its foot, on every copy, and the record does not say so.
- What the file shows: out/solarpunk/tree_round_b.glb has 26 leaf-material triangles at the foot. They run from -0.012 to 0.165 m up and out to 0.51 m from the axis, painted in the pale blossom colours.
- What the pictures show: a pink-white patch round the base of the trunk, in working folder captures/new/street-tree-b/solarpunk/asset-eye-2.png and in compare/trees-solarpunk.jpg.
- What the record says: README.md:405 and families/street-trees-and-palms.md:23 describe a planted tree as nothing but trunk in the band that starts at 0.15 m. The skirt reaches 1.5 cm into that band.
- check.py cannot see it, because planted_rules.py measures only non-leaf reach.
- The game's width scaling and the collision audit are not affected: leaf faces are not counted, and the audit's band starts at 0.25 m.
- How checked: parsed the GLB by material; looked at the capture and the sheet.

Should fix

6. Should fix. The anime large street tree's crown is open from above.
- The sentences:
  - README.md:576: "Crowns are closed masses of facets".
  - README.md:377: "a crown that is closed from above".
  - families/street-trees-and-palms.md:59: "these are closed leaf masses".
- What the pictures show: a hollow at the top shows the inside and the trunk. See working folder captures/new/street-tree-a/anime_cel/asset-above-0.png and compare/trees-anime_cel.jpg ("new (above-0)"). The fill described at families/street-trees-and-palms.md:26 did not close this one.

7. Should fix. The neon tree and palm rows describe files that are not in the game.
- The rows: README.md:187, 192, 197, 201, 205.
- What the files show:
  - The rows describe out/neon_noir/, the neon sheet's greens.
  - The game copy holds the out-kit-green/neon_noir/ files (sha256 identical).
  - Colour off the design: 7.6, 5.5, 4.2, 4.1, 3.1 in the table; 13.9, 11.0, 7.7, 7.7, 8.4 for the files the game draws (colour_delta_e in their reports).
  - File size: 0.43, 0.41, 0.30, 0.29, 0.27 MB in the table; 0.46, 0.42, 0.33, 0.33, 0.29 MB in the game.
  - Triangle counts agree.
- Nothing in the table says which file a row describes.

8. Should fix. The anime and neon leafy shrubs are never drawn.
- The sentences:
  - README.md:9: "99 pieces built from design sheets and running in a copy of the game".
  - README.md:42: "Every piece in the table is in that copy of the game".
  - README.md:598: "(low-poly, solarpunk, the leafy one in anime and neon) read as bushes".
- What the files show: the anime and neon leafy shrubs sit in the copy's asset folders, but the anime and neon style.json name only shrub_round.glb for shrubs. Low-poly and solarpunk do name shrub_leafy.glb.
- So 97 pieces are drawn, and these two were only ever seen in Blender. families/low-planting.md:222, 249 and 272 say so; the README does not.

9. Should fix. README.md:38: "a tree or palm outside low-poly and voxel has a second file for the far distance: 124 files in all".
- Far twins exist outside voxel, low-poly included: 104 piece files + 20 twins = 124.
- With twins only outside low-poly and voxel, the count would be 119.

10. Should fix. README.md:493: "its low-poly and neon pairs agreed and gave 1.0 and 0.4 ms".
- In bench/afternoon/ the low-poly kit runs of a pair differ by 0.249 and 0.437 ms. The bench README itself says "agree within 0.45" (bench/afternoon/README.md:27).
- By WORKFLOW.md:51's 0.1 ms rule these pairs did not agree, so the 1.0 ms is no firmer than the figures the README discards.
- Also, bench/afternoon/README.md:1 says "16:13 to 16:43", but the log begins at 16:20:28.

11. Should fix. README.md:392: "each merge was proved by building pieces again and comparing them byte for byte with the agent's own".
- README.md:455 says the fountain's build "did not repeat".
- families/fountain-and-shelter.md:236 says that merge "could not be proved by comparing files".
- families/fountain-and-shelter.md:340 says four of its ten pieces differ after the merge.

12. Should fix. README.md:158: the image's colours are gathered "(three to eight, by piece)".
- Ten pieces were matched to two colours:

  | Piece | Colour off the design |
  | --- | --- |
  | anime bollard | 1.7 |
  | anime café table | 3.9 |
  | anime railing | 1.8 |
  | low-poly café table | 0.0 |
  | solarpunk café table | 0.3 |
  | voxel bench | 0.8 |
  | voxel bollard | 2.0 |
  | voxel café chair | 1.1 |
  | voxel café table | 2.4 |
  | voxel fountain | 0.9 |

- WORKFLOW.md:138 (trap 15) says such a figure "is met by construction and says nothing". Yet these ten stand unmarked in the README's tables; families/terrace.md:93 flags only the low-poly table.
- How checked: "materials" and colour_delta_e in every out/<style>/<piece>.json.

13. Should fix. The writer's choices are framed as the owner's decision.
- The sentences:
  - WORKFLOW.md:63 opens "The triangle count is the shape's to decide (the owner's decision, 2026-10-02)".
  - The same paragraph then states "Three kinds of piece are held near their limits all the same" and "For the planted pieces the frame time is the gate".
  - tools/assets.json:3 (`_triangles`) does the same.
  - README.md:356 follows the owner's quote with the planted pieces' counts being "set by measured frame time"; it reads the same way.
- What the owner said: "Keep \"the shape decides\" for triangles", and earlier the question "Why are we budgeting on triangles?". The owner decided nothing about the planted pieces' counts or a frame-time gate.
- Elsewhere the record has this right: README.md:627 lists the three held kinds under "Decisions I made for you", and README.md:669 treats the planted counts as open.

14. Should fix. The kept audit reports measure only three of the six gates.
- The sentences:
  - WORKFLOW.md:38: "`work/audit.sh <style>` runs the game's collision audit ... All six counts must be zero".
  - README.md:44 cites out/audit-props/ for the zero audit.
- What the files show:
  - tools/audit.sh passes `--audit-ticks=0`, and every kept report (out/audit/, audit-kit/, audit-props/) has day_ticks 0.
  - With no day, the audit sets walker_pass, player_pass and tram_overlap empty without measuring them (checkout city/godot/tools/collision_audit/audit.gd:163-176).
  - The full day was run only inside the test suite (tests/test_collision_audit.gd uses DAY_TICKS). That suite passed at 22:23-22:37.
- The result stands; the evidence cited for it and the WORKFLOW's promise do not.

Minor

15. README.md:427: "the textures are unchanged". Against the earlier files (working folder scratch/before-normals/), the anime café chair's texture differs by more than 12 levels (of 255) over about 18% of its area, compared block by block.

16. README.md:685 cites out/replay.txt for "the two shrubs of out-leaves/". replay.txt does not list out-leaves; they are in out/replay-after-adopting.txt.

17. README.md:455: "every piece now builds twice to the same bytes". Four kept files were built only once:
- out-budget/anime_cel/seat_cafe-table_v2.glb
- out-budget/lowpoly_tropical/seat_reading-chair_v2.glb
- out-budget/solarpunk/seat_cafe-table_v2.glb
- out-worn/lowpoly_tropical/seat_bench_v2.glb

They differed from the kept files, or were missing, in replay.txt and were adopted from that same rebuild. replay-after-adopting.txt compares them with that same build. The second full rebuild planned for this (ledger, scratch/replay-3) stalled in the out-of-memory hour. Only neon was built again.

18. README.md:419: "117 of them by now". notes/gen3d-times.tsv records 121 runs of 116 distinct cut-outs.

19. README.md:510 and WORKFLOW.md:146: "from 63 to 82 °C". bench/five-in-one-run/*.temperature.txt hold 81, 82, 79 and 81. 63 appears in none of that run's files.

20. README.md:40: "captured from the same camera as the kit's piece". README.md:71 itself says a planted piece's camera is chosen per capture, and tools/assets.json:459 says the same of `auto` framing.

21. README.md:539: "Outside voxel a seat is 0.24 MB to 0.57 MB". The anime and solarpunk perch seats are 33 kB and 24 kB (README.md:142, 147).

22. families/street-trees-and-palms.md:40: "0.6 for the neon pieces built here". The neon great tree's main material is at roughness 0.7, and its crown_top has none (1.0).

23. README.md:433 and WORKFLOW.md:139 attribute `--leaf-swatches` and `--tones-by-rank` to voxelise.py. Only fit_generated.py reads them (lines 5520-5527 and 6048-6063).

24. README.md:656: "six with trunks thicker than the 0.5 m". In the reports, trunk_width_generated_m exceeds 0.5 m in four trees: low-poly large 0.823, low-poly small 0.56, solarpunk large 0.565, neon large 0.507. Six were slimmed, because reach also counts flare and lean. families/street-trees-and-palms.md:24 is right in its own terms.

25. families/street-trees-and-palms.md:34: "5 to 10% of the leaf texels". Measured: 4.8% to 11.2%.

26. README.md:447 says "a third of its width"; families/street-trees-and-palms.md:51 says "about 0.4" for the same voxel trunk.

27. README.md:377: "at 1,500 triangles the neon café chair's steel legs become spikes (previews/neon-cafe-chair-budget.jpg)". The picture (05:59) shows builds at 1,440 and 2,999 triangles; the kept chair has 2,997.

28. README.md:102: "917 passes and 20 failures". The run had 920 tests: 3 failed, with 20 failing assertions (17 + 2 + 1). 917 + 20 mixes tests and assertions.

29. bench/trees-only-disturbed/README.md:16: "0.3 to 1.35 ms slower". It recomputes as 0.46 to 1.35.

30. families/terrace.md:
- Lines 15, 18, 21: the three tables' sizes (0.39, 0.44, 0.39 MB) are from the first pass. The kept files, rebuilt with their own normals, are 0.38, 0.40 and 0.35 MB.
- Line 187: "9,188 triangles". The file, and the README's table, have 9,187.

31. compare/street-<style>.jpg and compare/views-<style>.jpg label their frames "game with the new pieces" / "new pieces". They show the first set only: the kit's palms, lamps, bollards and props are still there. README.md:83 files them under "The first set", but the labels read as the whole set.

32. Stale or local instructions:
- tools/run_game.sh:2-3 still says "(lowpoly_tropical or neon_noir; the other styles are untouched)".
- tools/game_tests.sh:5 says "about 25 minutes"; the final run took 14.
- README.md:93's run command points into the working folder, which a reader of the committed record will not have.
- WORKFLOW.md:63 omits the count rule's second condition, "and all of it within 0.8%" (tools/fit_generated.py:361-363).

33. Outside the record, uncommitted but linked from it: docs/vision/asset-studies/README.md:97 still says the first build was "in low-poly and neon noir".

CHECKED AND FOUND CORRECT

- Tables: `report_tables.py --check` agrees with the files (260 of 260 rows). I checked all 104 pieces by hand: triangle count and file size match each GLB.
- Counts:
  - 99 pieces (23 + 76); 104 files with the railing posts; 124 with the far twins.
  - 58 images; 43 neon files; 179 files rebuilt; 608 planted placements (309 + 299); 36 perch places; 18 seats rebuilt with their own normals.
  - Forks at 1.45-1.92 m; crowns pressed to 0.67-0.87; slimming to 0.452.
  - Palms 3.5-9.4 cm off their point.
  - Voxel trees at 470 and 328 triangles, drawn at 0.79 and 1.12.
  - Low-poly trees and palms total 1.7-1.9 million triangles in the district.
- Runs after the last change to the pieces. Newest piece per style in the game copy, then its kept audit report:

  | Style | Newest piece | Audit report |
  | --- | --- | --- |
  | anime | 20:28:20 | 20:30:17 |
  | low-poly | 22:15:15 | 22:15:31 |
  | neon | 22:12:19 | 22:12:35 |
  | solarpunk | 20:29:15 | 20:30:32 |
  | voxel | 20:14:40 | 20:30:40 |

  All five audits count zero, for the three gates measured (see 14).
  - Test suite: 920 passed, 22:23-22:37 (out/game-tests.txt). The run before it, which passed the same, is game-tests-2030.txt; the afternoon's 4.14 ms timing failure is in game-tests-work_app.txt.
  - Boot test: 22:37-22:40, clean in all five styles.
  - Validator: 22:22:55, no error or warning in the 124 files or in the other out-* folders.
  - Full rebuild: 169 same, 7 differing, 1 missing, then 179 same after adopting.
  - Neon-only rebuild: 22:13-22:22, 43 of 43 the same.
  - The game copy's low-poly trees are the full files again after the far-twin trial.
  - None of these checks ran inside the out-of-memory hour (21:05-22:07).
- Frame time: every other figure in the evening, trees-only, far-twin, noon and night tables and sentences recomputes from the run files (p50 medians, pair means, differences).
- Code claims are as stated, at the cited lines:
  - planted drawing: copies of the first mesh; width 0.25 m over the non-leaf reach in 0.15-2.2 m; the leaf regex;
  - FAR_TREE_M = 90 m;
  - the audit: band 0.25-1.9 m, 10 cm clearance, 25 cm cells, six gates;
  - the footprint fill and drawn_rect's 12 cm cell-centre quirk;
  - the wet-ground prefix and the material names the game acts on.
- Tools: check_options.py reports 183 options documented and read. Every `work/` script WORKFLOW names exists in tools/, and its command lines match the scripts' usage text.
- The terrace merge: the record's terrace files equal the agent's, or differ only where tangents were mended or many-sided faces were cut into triangles.
- The owner's words: the three quotes are verbatim and used for what the owner decided. The record does not present the proportions, committing, the planted counts or the neon greens as the owner's. The neon greens are labelled as the writer's (README.md:618, 628). The one exception is finding 13.
- No /home/ path and no email address in the record.
- REUSE.toml and COPYING.md cover every kind of file the record holds.
- The checkout: nothing under city/ was modified and nothing was committed. Only COPYING.md and REUSE.toml are modified; the record, the image pack and tests/test_asset_studies.py are untracked.
- Pictures: the town, terrace, water, fixtures, trees, planting, seats, tree, perch-seats, sitters, limit and views sheets show what their labels and the README say. The props' "today" frames do show the new seats and great tree. The listed faults are visible where stated. Exceptions: findings 4, 5, 6 and 31.

COULD NOT CHECK

- Anything that needs the game, Godot, Blender, the bench, the validator or a rebuild run again. I read the result files and logs named above instead.
- Several figures rest only on the ledger, the agents' reports or the contract agents' arithmetic, with no result file to recount:
  - the 38% toon-shadow figure;
  - the audit's "twelve seconds";
  - the agents' durations;
  - "up to a dozen conflicting places";
  - the pilot's "two of the six came back as real trees";
  - the 226 railing panels.
- The load average "5 to 7" in bench/trees-only-disturbed/README.md: recorded in no file.
- Seat tops measured by ray in the game: I used out/seat-heights.txt and a plan-view estimate from the files instead.
- The anime and neon leafy shrubs in the game: they are never drawn (finding 8), so no capture of them exists.
