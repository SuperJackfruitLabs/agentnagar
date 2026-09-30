> Historical record migrated from `docs/vision/style-studies/revisions/2026-09-20-first-ten/09-solarpunk/REPAIR.md`. File paths in prose/JSON may describe the old layout; use the migration ledger for exact mappings.

# Solarpunk retro-futurism repair record — 2026-09-20

Status: four improved revised sheets promoted to the gallery, with residual issues below. **Not certified as fully contract-compliant.**

[Current gallery](../gallery-before-migration/README.md) · [Comparison contract](../../../../shared/CONSISTENCY-CONTRACT.md) · [Original archive](originals/README.md) · [Hashes, dimensions and selections](manifest.json)

## Scope and provenance

Baseline `ba5f4242d02aa37686b2a18b9add8813c5490130`. All nine original files, including four PNGs, four original prompt documents and README, are preserved byte-for-byte under `originals/` and compared against that Git commit. Built-in `image_gen.imagegen` was used for every correction; no Python image editing or CLI fallback. Every returned candidate and exact submitted prompt is retained.

Cream ceramic surfaces, curved architecture, brass, solar panels, turquoise glass, planting, jade/coral/cream palette and warm sunlight retained. These are contemporary ordinary residents in a warm-climate city.

## Selected sheets

| Sheet | Selected pass | Inspection |
| --- | --- | --- |
| 00 City perspectives | 4 | Single west river and low bridge, low workshop, living tree, broad rounded two-storey library, three stepped towers, ground tram and waterfront park. STREET route moved to foreground; three-bay workshop restored after an intermediate two-bay regression. |
| 01 Living and community | 3 | Cream rounded robot with black face, cyan eyes, brass ears, teal scarf and leaf A1 badge retained. Workshop windows use nearby foliage; home faces west without duplicate library; gathering restored to tree square with three towers. |
| 02 Creating and exploring | 2 | Red X, green/up Y, blue Z labels retained; tram now runs east–west across foreground on ground tracks. Low workshop roof in waterfront view corrected to three bays. |
| 03 Interfaces and perspectives | 2 | Phone uses the conversation robot, contains selected Workshop and Ask; facility uses distinct book/calendar/bubble actions; AR highlights low three-bay hall rather than tower and keeps category labels/colors. Rooftop duplicate library removed. |

Each promoted PNG is 1536 × 1024 and byte-identical to its selected candidate. The JSON manifest lists full SHA-256 hashes for originals, candidates, exact prompts and gallery files. All panels were visually inspected at the returned image size; a separate measured half-size usability test was not performed.

## Iteration review

Overview pass 2 fixed foreground STREET tram but reduced workshop to two bays; pass 3 restored three bays and N arrows. Independent review found four street bays and orange overhead roof tiles; pass 4 removed the fourth street bay and restored blue solar roofs. The generator also changed the MAP roof to blue. Living pass 2 removed duplicate library from home but erroneously moved river behind gathering; pass 3 restored north-facing gathering from pass 1. Creating pass 2 rotated the tram route back east–west and fixed roof count. Interface pass 2 removed duplicate rooftop library and wall slogans while preserving core phone and AR tasks.

## Residual issues

Full compliance is not claimed. MAP remains a pictorial overhead plan rather than fully flat cartography; TOP-DOWN uses simplified blue solar roof strips; MAP also retains these pictorial solar details. The overview street workshop now has three clear bays, but sawtooth edges are not mechanically identical across every experience perspective. North bridge span counts vary in small/background views. Caption bands remain partial in some interface and creating panels; typography and generated outer matte/gutters do not exactly match the requested dimensions. Some phone map/icon details require enlargement to distinguish. Static artwork does not demonstrate usability or performance.

## Prompt and candidate inventory

[Actual generation output paths and reference snapshots](generation-outputs.json).

| Candidate | Exact prompt | Selected |
| --- | --- | --- |
| [00-city-perspectives-pass1.png](../../sheets/00-city-perspectives/r002/image.png) | [Prompt](../../sheets/00-city-perspectives/r002/prompt.txt) | No |
| [00-city-perspectives-pass2.png](../../sheets/00-city-perspectives/r003/image.png) | [Prompt](../../sheets/00-city-perspectives/r003/prompt.txt) | No |
| [00-city-perspectives-pass3.png](../../sheets/00-city-perspectives/r004/image.png) | [Prompt](../../sheets/00-city-perspectives/r004/prompt.txt) | No |
| [00-city-perspectives-pass4.png](../../sheets/00-city-perspectives/r005/image.png) | [Prompt](../../sheets/00-city-perspectives/r005/prompt.txt) | Yes |
| [01-living-community-pass1.png](../../sheets/01-living-community/r002/image.png) | [Prompt](../../sheets/01-living-community/r002/prompt.txt) | No |
| [01-living-community-pass2.png](../../sheets/01-living-community/r003/image.png) | [Prompt](../../sheets/01-living-community/r003/prompt.txt) | No |
| [01-living-community-pass3.png](../../sheets/01-living-community/r004/image.png) | [Prompt](../../sheets/01-living-community/r004/prompt.txt) | Yes |
| [02-creating-exploring-pass1.png](../../sheets/02-creating-exploring/r002/image.png) | [Prompt](../../sheets/02-creating-exploring/r002/prompt.txt) | No |
| [02-creating-exploring-pass2.png](../../sheets/02-creating-exploring/r003/image.png) | [Prompt](../../sheets/02-creating-exploring/r003/prompt.txt) | Yes |
| [03-interfaces-perspectives-pass1.png](../../sheets/03-interfaces-perspectives/r002/image.png) | [Prompt](../../sheets/03-interfaces-perspectives/r002/prompt.txt) | No |
| [03-interfaces-perspectives-pass2.png](../../sheets/03-interfaces-perspectives/r003/image.png) | [Prompt](../../sheets/03-interfaces-perspectives/r003/prompt.txt) | Yes |

## Reference inputs

Initial overview calls used the original overview for style. Styles 09 and 10 also used the corrected style 08 overview as a geometry reference. Initial experience calls used that style’s original experience sheet, corrected overview and original living sheet for A1 identity. Targeted passes used the immediately preceding candidate unless noted: style 08 interface pass 3 additionally used pass 1 to restore AR; style 09 living pass 3 additionally used pass 1 to restore gathering; style 10 interface pass 3 additionally used pass 1 for geography and labels. All local reference images were viewed before use.

These remain design comparisons, not implemented city behavior, runtime geometry, accessibility certification or performance evidence.
