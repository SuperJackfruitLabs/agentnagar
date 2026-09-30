> Historical record migrated from `docs/vision/style-studies/REPAIR-FIRST-TEN-2026-09-20.md`. File paths in prose/JSON may describe the old layout; use the migration ledger for exact mappings.

# Styles 01–10 repair record

Baseline: `ba5f4242d02aa37686b2a18b9add8813c5490130`. The user approved repair
of the findings from the 40-sheet / 160-panel review on 2026-09-20.
These are concept illustrations, not implemented behavior or performance evidence.

## Scope and acceptance

Use [the comparison contract](../shared/CONSISTENCY-CONTRACT.md) as the repair target for
styles 01–10 as well as its original 11–30 scope. Preserve each candidate's
medium and palette. Standardize the city, cameras, interaction semantics,
agent identity and sheet presentation; do not silently preserve the historic
city substitutions found in the original experience sheets.

Keep original images under `revisions/2026-09-20-first-ten/<style>/originals/`.
Save every exact prompt and generated candidate in that style's revision folder.
Inspect candidates before gallery replacement; record residual issues explicitly.
The dated 11–30 review and progress records remain historical and unchanged.

## Ordered tasks

1. Repair styles 01–03: all four sheets per style; stabilize overview first,
   then living, creating, and interfaces against it.
2. Repair styles 04–07 using the same sequence.
3. Repair styles 08–10 using the same sequence.
4. Independently inspect each revised set, correct material regressions, then
   verify original hashes, output dimensions, prompt provenance and document links.

The three style groups have disjoint image, README and revision directories.
They share only the read-only contract. The coordinator owns this progress file.
No task changes runtime code or selects a production style.

## Baseline review

All 40 sheets, comprising 160 panels, were opened and visually inspected. All
were present at 1536 × 1024. The original briefs expressly allowed approximate
geography, so the following are comparison limitations and observed continuity
problems, not retroactive claims that the originals violated this later contract.
Evidence links point to preserved baseline material (the style folders and the migrated, byte-identical baseline files) so replacements cannot change them; the baseline commit itself is only in the pre-publication history.

| Style | Observed issues in the original set |
| --- | --- |
| [01 Graphic](../styles/01-graphic/) | 03/AR selects a tall building behind the recognizable low workshop. Later characters have substantially more detail than the simplified overview. |
| [02 Voxel](../styles/02-voxel/) | Modern orange/blue overview becomes an ornate historic city in 01–03. Conversation robot becomes a human mobile guide. |
| [03 Ink](../styles/03-ink/) | 00/Tree Square centers on a fountain-like feature surrounded by trees. Later skyline is more historic. Mobile and AR lose the recognizable workshop–square–library arrangement. |
| [04 Realistic](../styles/04-realistic/) | Modern overview becomes domes/spires and historic waterfront in 01. Bridge forms change; 03/AR Maker Hub is a multistorey block rather than the brick industrial workshop. |
| [05 Claymation](../styles/05-claymation/) | Modern downtown becomes historic town; orange/cream tram becomes blue/yellow. 03/mobile drawer sits outside phone. |
| [06 Anime](../styles/06-anime/) | Contemporary Japanese-influenced overview becomes European-looking historic riverfront. Distinctive workshop/library disappear from device views. 03/facility uses a book icon for booking. |
| [07 Paper craft](../styles/07-paper-craft/) | Angular modern towers become historic spires/domes; mobile drawer extends beyond phone. Guide does not clearly match conversation characters; both conversation figures have similar badges. |
| [08 Pixel art](../styles/08-pixel-art/) | TOP-DOWN shows fronts rather than vertical roofs. White/blue-haired conversation figure becomes brown-haired mobile guide. Movement controls outside phone; book icon for booking. |
| [09 Solarpunk](../styles/09-solarpunk/) | Low curved workshop becomes a tall AR-selected tower. Device views rearrange waterways without locating the overview district. Conversation robot becomes a human phone guide. |
| [10 Neon noir](../styles/10-neon-noir/) | Robot becomes human phone guide; AR Maker Hub becomes tall tower. Booking uses book icon; caption treatment varies. Original elevated transit was intentional. |

Build-axis up direction was green in 01, 02 and 08, blue in 03–07, 09 and 10;
clear X/Y/Z lettering was absent. Camera extent, captions and mobile tasks also
varied. The new controlled comparison deliberately uses a ground tram even for
10, whose original brief requested elevated transit. This changes a comparison
variable and does not establish a production transit decision.

Real-world hands around a virtual city were explicitly allowed by the original
experience prompts; they are not treated as a style failure. The new caption
identifies the external viewer boundary. Human-presenting guides remain allowed.

## Progress

| Task | Status |
| --- | --- |
| 01–03 | All 12 revised sheets promoted and independently inspected; geometry limitations recorded |
| 04–07 | All 16 revised sheets promoted and independently inspected; Anime overview roof count resolved in pass 7 |
| 08–10 | All 12 revised sheets promoted and independently inspected; Pixel art rooftop roof count resolved in interface pass 7 |
| Final visual and artifact verification | All 40 selected sheets independently inspected; aggregate artifact checks recorded below |

Implementation and inspection details live in each style's revision `REPAIR.md`.
No gallery image is declared fully compliant based on its prompt alone.

## Per-style evidence

Each record identifies the selected passes, exact prompts, rejected candidates,
original backups, hashes and remaining limitations. The coordinator's
[independent review](2026-09-20-first-ten/REVIEW.md) tracks the correction
rounds separately from the generating agent's inspection.

| Style | Revision record |
| --- | --- |
| 01 Graphic | [Selections and review](../styles/01-graphic/history/2026-09-20-first-ten/REPAIR.md) |
| 02 Voxel | [Selections and review](../styles/02-voxel/history/2026-09-20-first-ten/REPAIR.md) |
| 03 Ink | [Selections and review](../styles/03-ink/history/2026-09-20-first-ten/REPAIR.md) |
| 04 Realistic | [Selections and review](../styles/04-realistic/history/2026-09-20-first-ten/REPAIR.md) |
| 05 Claymation | [Selections and review](../styles/05-claymation/history/2026-09-20-first-ten/REPAIR.md) |
| 06 Anime | [Selections and review](../styles/06-anime/history/2026-09-20-first-ten/REPAIR.md) |
| 07 Paper craft | [Selections and review](../styles/07-paper-craft/history/2026-09-20-first-ten/REPAIR.md) |
| 08 Pixel art | [Selections and review](../styles/08-pixel-art/history/2026-09-20-first-ten/REPAIR.md) |
| 09 Solarpunk | [Selections and review](../styles/09-solarpunk/history/2026-09-20-first-ten/REPAIR.md) |
| 10 Neon noir | [Selections and review](../styles/10-neon-noir/history/2026-09-20-first-ten/REPAIR.md) |

## Remaining limitations

Anime's overview roof-count regression was resolved in pass 7: MAP, TOP-DOWN,
DIAGONAL and STREET now show three bays. Earlier passes that moved the error
between panels remain archived and are not selected.

Pixel art's rooftop roof count was resolved in interface pass 7 after an
intermediate correction produced two bays. The selected version has three
slopes; repeated editing softened some pixel detail.

Across the collection, illustrated maps and overhead views are not calibrated
orthographic renders. Roof orientation, building proportions, bridge details,
caption dimensions and tiny avatar badges still vary. These are documented
concept-study limitations, not passed checks. The revised sheets should not be
used as interchangeable production geometry or as proof of interface usability.

## Artifact verification

The [aggregate verification snapshot](2026-09-20-first-ten/verification-summary.json)
records gallery hashes and matching archived candidates. Checks compare all 90
preserved original files against baseline Git bytes, verify every generated
candidate against its actual built-in tool output, check PNG dimensions at
1536 × 1024 and resolve local Markdown links. Per-style records include prompt
hashes and exact generation inputs. Staged whitespace checks preserve trailing
spaces in three verbatim Pixel art prompts so their recorded hashes remain valid;
all other staged files pass the standard whitespace check.

No runtime code changed; no application test or performance result is implied.
All revisions are in the isolated `docs/first-ten-style-repairs` worktree branch.
