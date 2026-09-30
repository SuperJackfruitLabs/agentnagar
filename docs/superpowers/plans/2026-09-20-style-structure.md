# Style-study structure implementation plan

> For agentic workers: use superpowers:subagent-driven-development for independent tooling and final review.

**Goal:** Migrate all 30 styles without changing selected artwork or losing history.
**Architecture:** Immutable sheet revisions, per-style selections, generated galleries, preserved source ledger.
**Tech Stack:** Python standard library, JSON, Markdown, PNG.
**Spec:** ../specs/2026-09-20-style-structure.md

## Global constraints

Preserve image and exact prompt bytes; do not infer unknown generation inputs or
upgrade historical review status. Keep original numbered style IDs and four sheet
IDs. Operate only in this isolated worktree. No publication or merge in this task.

## Tasks

- [x] Inventory and migrate all files into the approved layout. Build the full
  old-path-to-new-path ledger before removing old directories; verify old hashes.
- [x] Implement `scripts/style_studies.py` with `--write` and `--check`. Add
  meaningful fixture tests for broken selections, mutated image/prompt bytes,
  missing prompts, duplicate IDs, stale generated galleries and broken links.
- [x] Rebuild gallery READMEs, relocate shared rules and audits, rewrite incoming
  links throughout repository Markdown, document schema and authoring workflow.
- [x] Run unittest, generator check, full preservation audit and diff whitespace
  check (verbatim snapshots/prompts retain original whitespace). Independently
  review the complete migration and fix findings.

## Decisions and progress

Ruling: PR #12 is merged. Start from current origin/main (4cc96de), preserving
later member-role correction. Use a separate style-structure worktree.
Ruling: retain raw historical records beside readable migrated copies rather
than silently changing bytes covered by old hash records.


Verification: 674 baseline files preserved with complete Git blob/hash coverage;
120 selected PNGs unchanged; 279 unique sheet revisions plus two historical
comparison images. 34 regression tests and full collection validation pass.
Independent review found Markdown-wrapped original prompts and two missing
cross-style references; both were corrected and passed scoped re-review.
Ruling: historical Markdown remains byte-preserved in source snapshots while
readable copies use current links. New revisions use null baseline_commit;
initial selections are recorded separately from future manifest selections.
