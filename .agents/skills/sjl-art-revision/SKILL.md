---
name: sjl-art-revision
description: Create or review an Agentnagar style-study sheet revision while preserving prior images, exact prompts, provenance, and gallery selections. Use for the city's concept-art revision workflow, not for choosing its engine or implementing runtime assets.
---

Work from the Agentnagar repository root. Locate the requested style, sheet, current
selection, and intended change. If the user names an image outside this collection,
establish its relationship to the study before changing collection records.

## Read the relevant source

Read `docs/vision/style-studies/shared/STRUCTURE.md` for current record formats and
commands, the shared `CONSISTENCY-CONTRACT.md` and `sheet-program.md` for comparison
constraints, and the selected style's `brief.md`, `manifest.json`, and review.
These repo-owned documents remain authoritative; do not copy their schemas into
another independent source.

Inspect the actual source/reference images using the available image tool before
editing. If generation or image inspection is unavailable, prepare the requested
prompt/review scope and state the missing capability. Do not claim an image was
generated or visually reviewed from its filename or prompt alone.

## Create the revision

Use the next unused `rNNN` directory in the owning sheet. Preserve every existing
revision's image and prompt bytes. Save the exact submitted prompt without
trimming or paraphrasing it, the generated image, and actual tool/source identifiers.
Record hashes, dimensions, reference inputs, and provenance using the current
generation-record contract. Keep unavailable historical inputs explicitly unknown.

New artwork is not part of the historical migration baseline. Do not extend that
ledger to imply it existed before generation. Keep its prior preservation entries.

## Inspect and select

Write the actual visual findings and limitations into the new revision's review.
Distinguish successful generation, gallery selection, and review approval.
Apply the user's requested selection change when authorized; otherwise present the
candidate and its comparison without silently changing the chosen revision.

For an authorized selection, update only the relevant manifest selection and
review summary, then regenerate the galleries through the existing script.
Do not hand-edit generated gallery READMEs or create mutable current-image copies.

## Verify and deliver

Run `python3 scripts/style_studies.py --check` from the repository root after
metadata/gallery changes. Use `--write` when regeneration is needed. Its hashes,
dimensions, links, and preservation checks complement actual visual inspection;
they cannot establish visual consistency or runtime readiness.

Report the new revision, image and prompt provenance, visual findings, selection
status, preservation/check results, and any missing evidence. These are concept
studies; they do not establish a production style, engine choice, or runtime asset.
