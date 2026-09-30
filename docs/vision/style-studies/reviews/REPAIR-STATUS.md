> Historical record migrated from `docs/vision/style-studies/REPAIR-STATUS.md`. File paths in prose/JSON may describe the old layout; use the migration ledger for exact mappings.

# Style correction progress — 2026-09-19

Baseline: `2e835a3`. Scope: all twenty new styles (11–30), including four missing overview sheets. [Review](REVIEW-2026-09-19.md) · [Correction contract](../shared/CONSISTENCY-CONTRACT.md).

## Ordered work

1. Reference district: specified in contract §1; artwork verification pending.
2. Interaction semantics: specified in contract §2; artwork verification pending.
3. Comparison variables: specified in contract §3; artwork verification pending.
4. Missing overviews: all four added and visually inspected. Continuity corrections: in progress, starting with 11, 13, 14 and 16. Added overviews do not imply their existing experience sheets have been reconciled.
5. Frame, captions, compass and semantic colours: pending artwork correction and inspection.
6. Hierarchy review: pending corrected artwork. Runtime validation is outside this concept-art pass.

No artwork is marked fixed merely because its prompt or contract was corrected. Original PNGs remain untouched until a replacement passes visual inspection. Save exact revision prompts alongside new outputs.

New overviews were generated with the built-in image tool. The reference plan was authored as SVG and rasterized only as a tool input; original artwork was not edited with an image-processing script. Stained-glass rejected drafts are preserved under `revisions/2026-09-19/15-stained-glass-mosaic/`. All original tracked artwork also remains recoverable from baseline commit `2e835a3`.

| Style | 00 | 01 | 02 | 03 |
| --- | --- | --- | --- | --- |
| 11 | Revised gallery; inspected | Revised gallery; backgrounds and A1 inspected | Revised gallery; axes, living tree and low bridge inspected | Revised gallery; pass 3 inspected: phone task/A1, foliage backdrop, rooftop and three AR towers corrected; final cross-sheet proportions pending |
| 12 | Pending | Pending | Pending | Pending |
| 13 | Revised gallery; pass 2 inspected | Revised gallery; pass 2: local window views and stable A1 | Revised gallery; pass 3: roof count, library vault, axes and park view corrected | Revised gallery; pass 3: phone markers, rooftop and AR library restored; library proportions pending |
| 14 | Revised gallery; pass 2 inspected | Revised gallery; pass 2: home skyline removed; A1 retained | Revised gallery; pass 2: night tower count and park view corrected; build skyline partly occluded | Revised gallery; pass 4: phone markers, low bridge, rooftop and AR workshop corrected; full geometry audit pending |
| 15 | Added; inspected after 3 passes. Camera/landmark fixes improved; roof colour and entrance orientation remain | Pending | Pending | Pending |
| 16 | Pass 4 draft: overhead flattened to a second plan; library roof silhouette lost, so not promoted | Revised gallery; pass 2: local windows, leaf A1 badge and three towers | Revised gallery; pass 3: three roof bays and towers, labelled axes and close park view | Pass 2 draft: phone semantics/A1 corrected; rooftop workshop reads as separate buildings |
| 17 | Pending | Pending | Pending | Pending |
| 18 | Draft inspected: living tree restored in all views; tall bridge posts and non-flat MAP remain | Pending | Pending | Pending |
| 19 | Draft inspected: living tree restored; diagonal has four roof bays; bridge, river edge and camera mismatch remain | Pending | Pending | Pending |
| 20 | Draft inspected: living tree and quieter paths; suspension bridge, tilted overhead and four diagonal roof bays remain | Pending | Pending | Pending |
| 21 | Pending | Pending | Pending | Pending |
| 22 | Draft inspected: living tree and captions restored; park south of tram, tilted overhead, bridge and roof shapes remain | Pending | Pending | Pending |
| 23 | Added; all four cameras inspected; cross-sheet reconciliation pending | Pending | Pending | Pending |
| 24 | Added; all four cameras inspected; cross-sheet reconciliation pending | Pending | Pending | Pending |
| 25 | Added; all four cameras inspected; map still uses some illustrated roof symbols; cross-sheet reconciliation pending | Pending | Pending | Pending |
| 26 | Pending | Pending | Pending | Pending |
| 27 | Draft inspected: living tree and organic dog; diagonal has four towers; bridge posts and overhead tilt remain | Pending | Pending | Pending |
| 28 | Pending | Pending | Pending | Pending |
| 29 | Pending | Pending | Pending | Pending |
| 30 | Pending | Pending | Pending | Pending |

## Session recovery — 2026-09-19

Recovered context from session `01a0b9d5-5814-7e82-9390-812824b42c00`
and its interrupted continuation. The four interface jobs completed: all outputs
are already saved in `revisions/2026-09-19/<style>/03-interfaces-perspectives.png`.
Their former “Generating revision” status was stale. All four drafts were
visually inspected during recovery; findings are recorded above. None was
promoted to the gallery during recovery.

Resume with the style 11 interface draft, comparing against its revised overview
and A1 conversation sheet. Correct the suspension bridge behind the phone and
reconcile workshop roof bays, downtown masses, and rooftop viewpoint. Then
resolve the recorded drafts for 13, 14 and 16 before proceeding through the
remaining review findings. Keep the shared contract and existing originals.

At recovery time, the checkout was on local `main` at baseline `2e835a3`, with uncommitted
artwork and documentation. Recovery checked status, remote and worktrees;
it did not fetch, commit, publish or alter gallery images. Earlier “inspected”
entries describe partial progress, not full contract acceptance.

## Resumed artwork batch — session 01a0bab2

Nine further gallery sheets were replaced after inspection: style 11 sheet 03;
styles 13 and 14 sheets 01–03; style 16 sheets 01–02. The table above records
targeted improvements and outstanding limits. None of these statuses certifies
full contract compliance or measured readability at target display size.

Five new overview drafts for 18, 19, 20, 22 and 27 restore the central living
tree, but remain in the revision archive because camera and building/bridge
invariants still fail. Style 16 overview pass 4 and interface pass 2 also remain
drafts. All 23 images generated during this resumed batch, including rejected
intermediate edits, are preserved with exact prompts. The
[batch manifest](2026-09-19/resumed-batch-manifest.json) records output
hashes, prompts and whether each image is currently used by the gallery.

Next actions (supersedes the earlier recovery resume point):

1. Repair style 16 overview from pass 3 or pass 4: retain a real roof-view panel
   distinct from MAP while eliminating facades; restore rounded library roof.
   Repair interface pass 2 rooftop so W1 reads as one three-bay hall, then
   compare the phone and AR model against the accepted overview.
2. Correct the five tree-restoration drafts before promoting them: remove
   suspension/tall bridge structures; fix bay/tower counts and overhead views.
   Style 22 must put P1 north of S1, not south of the tram boulevard.
3. Reconcile their experience sheets and continue the outstanding styles
   12, 15, 17, 21, 23–26, 28–30 using the review order. No new image jobs remain
   running from this batch.
4. Complete the collection-wide camera, entrance, silhouette, caption/template
   and half-size hierarchy checks. Existing gallery replacements are partial
   repairs and still need this final comparison.

At the end of that artwork batch, all work was local and uncommitted. No runtime changes were made. Subsequent commit and PR status is recorded in Git and GitHub.
