# Working with style studies

[Gallery](../README.md) · [Shared sheet program](sheet-program.md) ·
[Comparison contract](CONSISTENCY-CONTRACT.md) · [Reviews](../reviews/README.md)

## Ownership

`styles/<numbered-slug>/` owns a style's brief, selections, sheet revisions and
historical records. `shared/` owns comparison rules and reference geometry;
`reviews/` owns dated collection-wide audits; `comparisons/` owns comparison
sheets. None of this is a runtime asset format or a production style decision.

```text
styles/01-graphic/
  brief.md
  manifest.json
  README.md                 # Generated selected gallery
  sheets/00-city-perspectives/r001/
    image.png
    prompt.txt              # Present only when the exact prompt is known
    generation.json
    review.md
  history/                  # Original records and readable historical copies
```

## Add a revision

1. Create the next unused `rNNN` directory within the owning sheet. Existing
   revision directories and their image/prompt bytes are immutable. Revisions
   from this migration are ordered from recorded source names; their numbers
   are not asserted generation timestamps.
2. Save the image and exact submitted prompt together. Do not trim whitespace,
   rephrase prompts or invent missing historical prompts. Record missing prompts
   with `status: "missing"`, `path: null`, `sha256: null` in `generation.json`.
3. Record SHA-256 hashes, PNG dimensions, source provenance and reference images.
   Use repository-relative identifiers for source history and revision-relative
   paths for resolvable reference images and legacy records. Absolute tool output
   paths in archived records are historical evidence, not required runtime inputs.
4. Write `review.md` with actual inspection findings and remaining limitations.
   A successful generation or a selection is not approval. Do not promote a
   candidate merely because its prompt requested the right result.
5. To select a reviewed revision, update only that sheet's entry in the style's
   `manifest.json`, update its review summary if needed, and regenerate galleries.
   Generated READMEs must not be edited directly. No duplicate current-image
   copies are maintained; README image links resolve to immutable revisions.

## Data formats

All current manifests and generation records use `schema_version: 1`.

A style manifest contains `id`, `name`, a `selected` mapping of the four fixed
sheet IDs to revision IDs, `review_summary`, and style-relative `review_sources`.

A generation record contains `sha256`, `width`, `height`, `prompt`, `source_paths`,
`reference_images`, `legacy_records`, and `baseline_commit`. Migrated records use the original commit; new generations
use an explicit `null` and nonempty `source_paths` containing their actual tool
output identifiers (for example an image-generation output ID). `source_paths` in
migrated records identifies original files in the baseline; the migration ledger
resolves those identities to their new location. `reference_images` and
`legacy_records` are paths relative to the revision directory. Missing reference
inputs must remain unknown, not be guessed from neighboring filenames.

Original overview prompts stored inside Markdown are extracted verbatim from
their fenced text blocks. Their generation records include `prompt_source` with
the wrapper path, format and hash; the complete wrapper bytes remain preserved.
These are labelled archived prompts because original tool-call whitespace cannot
be independently reconstructed beyond the saved block.

Historical generation JSON and hash lists keep their original bytes and schema.
They live under `history/` or `reviews/` and may contain paths from the former
layout. Do not use them as current selection manifests. Readable Markdown copies
have relocated links; `.md.source.txt` files preserve their exact original bytes.
The [migration ledger](../reviews/migration-2026-09-20.json) records every old path,
its byte-preserved destination and SHA-256. Identical image aliases may share one
revision; different prompt sources remain preserved.

## Commands

From the repository root, using Python 3 and local Git:

```sh
python3 scripts/style_studies.py --write
python3 scripts/style_studies.py --check
python3 -m unittest discover -s tests -v
```

The checker verifies all 30 style selections, image/prompt hashes, PNG dimensions,
reference paths, gallery freshness, repository-local Markdown links and complete
baseline preservation. It requires no network or third-party Python packages.
It cannot certify visual consistency, usability, accessibility or runtime behavior.

The ledger records `selected_at_migration` independently of current selections.
Changing a manifest later is allowed; changing the original preserved bytes is not.

The baseline ledger is a migration record, not a registry of future revisions.
Preserve its entries when adding new artwork; new generation provenance must be
explicitly recorded without claiming the new file existed in the old baseline.
