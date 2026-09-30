> Historical record migrated from `docs/vision/style-studies/revisions/2026-09-20-first-ten/03-ink/REPAIR.md`. File paths in prose/JSON may describe the old layout; use the migration ledger for exact mappings.

# 03 Ink and watercolor — repair record

Date: 2026-09-20. Baseline: `ba5f4242d02aa37686b2a18b9add8813c5490130`.

[Current gallery](../gallery-before-migration/README.md) · [Comparison contract](../../../../shared/CONSISTENCY-CONTRACT.md) · [Preserved original gallery](originals/README.md)

Built-in imagegen was used for every image edit; no CLI fallback or programmatic image editing. Original local references were inspected before use. Every generated candidate was visually inspected, including all four panels, before selecting gallery replacements. These are repaired concept studies, not a claim of complete contract compliance, runtime functionality, measured accessibility or performance.

## Selected gallery replacements

| Sheet | Selected candidate | Exact prompt |
| --- | --- | --- |
| 00-city-perspectives | [Pass 4](../../sheets/00-city-perspectives/r005/image.png) | [Prompt](../../sheets/00-city-perspectives/r005/prompt.txt) |
| 01-living-community | [Pass 3](../../sheets/01-living-community/r004/image.png) | [Prompt](../../sheets/01-living-community/r004/prompt.txt) |
| 02-creating-exploring | [Pass 4](../../sheets/02-creating-exploring/r005/image.png) | [Prompt](../../sheets/02-creating-exploring/r005/prompt.txt) |
| 03-interfaces-perspectives | [Pass 2](../../sheets/03-interfaces-perspectives/r003/image.png) | [Prompt](../../sheets/03-interfaces-perspectives/r003/prompt.txt) |

## Repair and inspection

Tree Square now contains a living shade tree instead of a fountain. Historic skyline and changing river geography have been replaced with the contemporary district. A1 retains the original woman's curly dark bob, rust scarf, sage jacket and leaf badge. Living pass 2 corrected the westward home window and the workshop's roof count; creating pass 2 corrected four roof peaks in the rain panel to three. Interface pass 2 added Workshop selected within the single phone, removed a slogan and corrected the westward rooftop. The first interface request failed with a connection error; the identical request was retried successfully, with no candidate file from the failed attempt.

- Overview: western straight river, low north bridge, low three-bay hall west of a living central tree, broad vaulted library east, three principal stepped towers north and ground tram south are now recognizable across views. Passes 2–3 corrected river/projection drift, oversized bridge posts and inconsistent library roofs.
- Living: workshop activities stay within the low hall, home view looks west, the labeled conversation agent remains recognizable and gathering is around the living tree.
- Creating: X red, Y green/up and Z blue letters are visible. Transit and wet-night views retain the civic landmarks; the park shows the east riverbank and modern workshop nearby.
- Interfaces: Browse uses an open book, Book a calendar, Ask a speech bubble. One phone includes the district, selected workshop, matching A1 and Ask action. Workshop orange/tools, Library blue/book, Transit purple/tram and Park green/leaf legends agree with AR. AR selects the low hall, with External viewer labeled. Rooftop looks west over tree/workshop to river.
- Captions and footer are readable, correctly spelled and consistently placed at panel tops / sheet bottom. At the displayed reduced view the selected low workshop, major tree and agent remain distinguishable; tiny phone text and badge lettering require the full image. This is a visual judgment, not measured usability.

Independent review identified a fourth workshop roof peak in overview STREET, living GATHERING and creating TRANSIT. Overview pass 4 and living pass 3 locally reduced those silhouettes to three visible peaks. Creating pass 3 retained an extra bay behind a tram-window mullion; pass 4 removed that bay and shows three sloping roof planes. All three selected outputs were inspected again and promoted, with original hashes rechecked. The edit instructions requested preservation of the other panels; image generation produces minor incidental texture/detail changes, so pixel identity outside the edited roofs is not claimed.

## Residual limitations

MAP retains some pictorial roof shading rather than wholly flat cartographic footprints. TOP-DOWN still shows slight facade/roof-edge cues and is not a calibrated orthographic render. Bridge spans are clearest in overview/park; cropped home/rooftop views do not expose the full bridge. Door-facing directions and exact normalized landmark coordinates cannot be certified from these illustrations. Some road widths, roof orientations, tram-stop details and neighboring low-rise masses vary between panels. Generated matte/gutter/caption geometry is visually consistent but not pixel-exact to the requested margins. The archive and gallery are therefore labeled repaired concept studies rather than fully compliant production references.

## Provenance and verification

[Generation outputs](generation-outputs.json) records actual built-in output paths, copied without deleting the tool originals. Each candidate has its exact submitted `.prompt.txt`. Overview pass 1 used the original overview as style input; passes 2–4 edited the preceding candidate. Experience pass 1 used the revised overview and original living identity reference, except interface pass 1 used the corrected living identity. Later experience passes edited the preceding sheet; graphic living pass 2 additionally referenced overview pass 3. Graphic living/creating pass 1 preceded overview pass 3 and used overview pass 2; their targeted second passes reconcile the changed roof/bridge.

[Original SHA-256](original-sha256.json) covers the byte-preserved original images, prompts and README. [Artifact verification](verification.json) records original hash checks, candidate dimensions/hashes, prompt hashes and gallery equality. Selected candidate PNGs were copied to the four existing gallery filenames after inspection. Historical prompt text is unchanged; the original overview prompt's introductory image link now targets the preserved original. No shared files, Git staging or commits were changed by this style task.
