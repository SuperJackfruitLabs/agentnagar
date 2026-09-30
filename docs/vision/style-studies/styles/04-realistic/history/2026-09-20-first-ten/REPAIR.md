> Historical record migrated from `docs/vision/style-studies/revisions/2026-09-20-first-ten/04-realistic/REPAIR.md`. File paths in prose/JSON may describe the old layout; use the migration ledger for exact mappings.

# Architectural realism repair — 2026-09-20

Built-in imagegen edits; originals copied byte-for-byte before replacement. Exact prompts are under [prompts](../../README.md), every generated candidate is under [candidates](../../README.md). Current gallery uses the following inspected revisions.

| Sheet | Candidate | SHA-256 |
| --- | --- | --- |
| 00-city-perspectives | [pass 4](../../sheets/00-city-perspectives/r005/image.png) | `45c3ec2fc83570774a98314b3c53c6ff0bf51a40d4801ba02a7e0466ab07afc1` |
| 01-living-community | [pass 3](../../sheets/01-living-community/r004/image.png) | `11cc34ebfe0fe6d50b90183f7ee7cec2581a13deb7d2d4037c05b410013c87d9` |
| 02-creating-exploring | [pass 2](../../sheets/02-creating-exploring/r003/image.png) | `39452ec55f0393aaadbe287c8d6a636916f2f94d63e9ef2118eb75ebbbb6eb22` |
| 03-interfaces-perspectives | [pass 2](../../sheets/03-interfaces-perspectives/r003/image.png) | `f924a0e9826c30ea1a05af9360477d04dc6518170df0dcb44c9fd56c541cbc57` |

## Inspection
All sixteen panels inspected at output size. Overview workshop, living central tree, broad rounded library, three modern towers, ground tram and north bridge now recur across experiences. Home and rooftop west cameras corrected. Bun-haired olive-jacket human-presenting A1 retains face/clothing identity and leaf badge in phone; phone map, selected workshop and Ask are entirely inside bezel. Browse/book, Book/calendar and Ask/bubble distinguish facility actions. XYZ uses red X, green/up Y, blue Z. AR selects low workshop, has three towers, four category legend and External viewer annotation. Captions/footer are readable.

## Residuals
Not fully contract-compliant: overview map retains shaded tree/roof glyphs and bridge elevation rather than purely flat cartography; top-down retains a small amount of facade perspective. Overview map lost Workshop/Library category pins in pass3, although labels remain and phone/AR restore all four categories. Independent review corrections reduced STREET/GATHERING/NIGHT workshop to three peaks; HOME bridge is now hidden by foliage. Generated matte/caption margins vary and were not measured as exact. Tiny mobile avatar badge is adjacent to portrait rather than on its chest. Smaller presentation needs prototype validation; no accessibility or performance claim.

## Provenance
Original images and prompts are in [originals](originals/README.md); generated candidates match tool output byte-for-byte, without image postprocessing. Original and replacement image SHA-256 values are recorded in `hashes.sha256`.

[Actual imagegen output/source paths for every candidate](generation-outputs.json). Sources verified byte-for-byte.
