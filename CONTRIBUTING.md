# Contributing to Agentnagar

Thank you for helping. Agentnagar is pre-release: the design is still being
settled, and much of the repository is planning documents and prototypes (see
the [README](README.md)). Small, focused pull requests are easiest to review.
For anything larger, open an issue first so the direction can be agreed.

Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before your first pull request: the CLA

Super Jackfruit Labs (OPC) Private Limited ("SJL") maintains Agentnagar and
needs every contributor to agree to the
[Contributor Licence Agreement](CLA.md) before a pull request can be merged.
You keep the copyright in your work. The CLA gives SJL a licence to use it,
including the right to publish its own builds (for example on app stores) and
to relicense the project, and it commits SJL to keep your contribution
available under an open-source licence.

To agree, tick the CLA box in the pull request template and add the sentence
the CLA's "How to agree" section gives, with your name. If you contribute on
behalf of your employer or another organisation, it needs a corporate
agreement first: say so in an issue and SJL will arrange it.

## How your contribution is licensed

Contributions are licensed as [COPYING.md](COPYING.md) describes: code under
the GNU AGPL v3.0 only, documentation and SJL's own assets under CC BY-SA 4.0.
Follow these rules:

- **Third-party material** (code, fonts, models, textures, images, sounds)
  must have a licence compatible with the path it goes into. Record its
  source, licence and author beside it: a `SOURCES.md` like the style packs
  have, and the licence file next to fonts. Mention it in the pull request.
  Update [`REUSE.toml`](REUSE.toml) if the licence differs from the path's
  default; [`reuse lint`](https://reuse.software/) checks the mapping.
- **AI-generated material** must say so. Name the generator where you can,
  keep the prompt or generation record, and do not present it as
  hand-made. The existing concept art is labelled in
  [docs/vision/style-studies/](docs/vision/style-studies/README.md).
- **Nothing private.** Do not commit credentials, personal data, internal
  host names or infrastructure details, or local absolute paths.
- **Names and logos** are not covered by the open licences; see
  [TRADEMARKS.md](TRADEMARKS.md).

## Building and testing

The city client and simulation live in [`city/`](city/README.md). Its
[Tests section](city/README.md#tests) holds the **pre-merge checklist**: run
the whole list from `city/` and see each command pass before you ask for a
review. `city/scripts/check.sh` runs all of it, plus the packaging and
benchmark checks. In short, you need Rust (the version in
`city/Cargo.toml`), Python 3 and, for the client, Godot 4.6.

- **Dependencies, fonts or the Godot release changed?** Regenerate the
  third-party notices with `python3 city/scripts/third_party_notices.py`
  and commit `THIRD-PARTY-NOTICES.txt`. The checklist runs `--check`.
- **Documentation or style studies changed?** From the repository root,
  run `python3 scripts/style_studies.py --check` (it also checks every local
  Markdown link) and `python3 -m unittest discover tests`.
- **Browser prototypes changed?** Open them locally, as the README's "Try
  the prototypes" section says, exercise the controls you touched, and
  confirm they still work without credentials or network access.
- **Interface changed?** The client's screens must stay usable with a
  keyboard and a game controller; the Godot suite has tests for each screen.

When you write documentation, put each document with its subject, mark
proposals and open decisions as such, and keep research dates and the limits
of the evidence visible.

## Pull requests

- Describe what changed and why, and how you checked it (commands and
  results).
- Keep commits coherent; say in the description if part of the change was
  written with an AI assistant.
- Use the pull request template, including the CLA box.

## Reporting security problems

Do not open a public issue. Follow [SECURITY.md](SECURITY.md).
