# Style-study structure

Implements the style-first layout approved in conversation on 2026-09-20.

- Shared contracts/reference assets live in `docs/vision/style-studies/shared/`.
- All 30 styles live in `styles/<existing-numbered-slug>/`, with `brief.md`,
  `manifest.json`, generated `README.md`, and `sheets/<sheet>/rNNN/` revisions.
- Each revision owns `image.png`, exact `prompt.txt` when known,
  `generation.json`, and `review.md`. Unknown prompts are explicitly missing;
  never infer a prompt from the current neighboring filename.
- A manifest selects one revision per sheet. Selection does not imply approval.
- Group byte-identical images within a style/sheet into one revision; keep every
  original source path in provenance. Revision numbers are migration ordering,
  not invented timestamps. Retain all distinct images and exact prompt bytes.
- Historical records live within each style's `history/`; collection-wide audits
  live in `reviews/`. Original Markdown bytes remain in `.source.txt` snapshots;
  readable Markdown copies get updated relative links. Historical JSON retains
  its original schema/paths and is explicitly marked as historical.
- A migration ledger maps every old file to preserved bytes and every old gallery
  image to its manifest-selected revision. No image generation or editing.
- A standard-library Python tool renders galleries from manifests and validates
  selections, hashes, dimensions, provenance, preservation and document links.
  No network, engine, npm dependencies, or production asset pipeline.

Manifest schema v1: `schema_version`, `id`, `name`, `selected` (four sheet IDs
mapped to `rNNN`), `review_summary` (text), `review_sources` (style-relative paths).
Generation schema v1: `schema_version`, `sha256`, `width`, `height`, `prompt`
(`status`: saved/missing, `path`: prompt.txt/null, `sha256`: hex/null),
`source_paths` (baseline repo-relative identifiers), `reference_images`
(revision-relative paths), `legacy_records` (revision-relative paths),
`baseline_commit` (original commit for migration, explicit null for new generations).

Migration ledger: `schema_version`, `baseline_commit`, `files` array containing
`old_path`, `new_path` (both repo-relative), `sha256` for byte-preserved files.
Every baseline style-studies file appears exactly once. `selected_at_migration`
maps each original selected PNG path to its preserved image destination; manifests
may subsequently select other valid revisions without modifying the ledger.


Original Markdown-wrapped prompts use optional `prompt_source` with the wrapper's
relative path, `markdown-fenced-text` format and SHA-256; `prompt.txt` contains the
verbatim fenced payload. The raw wrapper remains a byte-preserved ledger target.
Galleries label these as archived prompts. Historical review/provenance links
point to dated snapshots, not mutable generated galleries.
