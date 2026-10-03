# Licensing

Agentnagar is Copyright 2026 Super Jackfruit Labs (OPC) Private Limited and
contributors. Different parts of this repository are under different
licences. This page says which licence covers which paths.
[`REUSE.toml`](REUSE.toml) records the same mapping in the machine-readable
[REUSE](https://reuse.software/) format, and every licence text is in
[`LICENSES/`](LICENSES/).

| What | Where | Licence |
| --- | --- | --- |
| **Code**: the Rust crates, GDScript, shaders, Godot scenes and project files, Python and shell tools, the browser prototypes and style pages, fixtures, data and CI configuration | everything not listed in the rows below, including code that sits among the documentation (for example `docs/**/*.py`, `*.js`, `*.css`, `*.html`) | [GNU Affero General Public License v3.0 only](LICENSE) (`AGPL-3.0-only`) |
| **Documentation** | every `*.md` file and the rest of `docs/` (prompts, review records, generation records), and the evidence notes | [Creative Commons Attribution-ShareAlike 4.0](LICENSES/CC-BY-SA-4.0.txt) (`CC-BY-SA-4.0`) |
| **SJL's own assets**: 3D models and their Blender sources, sprites, textures, UI art, icons, SVG diagrams, renders, engine captures, evidence images and video | `city/godot/styles/*/assets/` (except `fonts/`), `city/godot/evidence/`, `prototypes/**/assets/`, `prototypes/**/source/`, `prototypes/**/evidence/`, `docs/assets/`, `docs/references/**/assets/`, and every other `*.png`, `*.svg`, `*.glb`, `*.blend` and `*.mp4` not listed below | CC BY-SA 4.0 |
| **AI-generated concept art** | `docs/vision/style-studies/styles/*/sheets/*/r*/image.png` and `docs/vision/style-studies/comparisons/*.png`; crops of it that the asset-to-sheet pilot measured, in `docs/research/2026-10-01-asset-to-sheet-pilot/banyan/inputs/` and `banyan/round2/sheets/`; the design images of the [asset studies](docs/vision/asset-studies/README.md), `docs/vision/asset-studies/sheets/*/*/r*/image.png`, and the crops of concept sheets they were made from, `docs/vision/asset-studies/refs/panels/` | [CC0 1.0](LICENSES/CC0-1.0.txt): no rights claimed. See [the style-study README](docs/vision/style-studies/README.md) |
| **Evidence composites** that set game captures beside crops of that concept art | `city/godot/evidence/*-vs-sheet.png`, `*-vs-sheets.png`; the comparison sheets and previews of the [asset-to-sheet pilot](docs/research/2026-10-01-asset-to-sheet-pilot/README.md) (`compare/` and `previews/` in its folders) | CC BY-SA 4.0 for SJL's composite; the embedded AI-generated crops remain CC0 1.0 |
| **AI-generated 3D shapes**, and the trees built on them, in the asset-to-sheet pilot | `docs/research/2026-10-01-asset-to-sheet-pilot/banyan/round2/parts/` and `banyan/previews/` (an image-to-3D model's output, reduced to parts or rendered); `banyan/out/` and `banyan/round2/out/` (the trees SJL's scripts build on those parts) | CC0 1.0 for the generated material: no rights claimed. CC BY-SA 4.0 for SJL's build and painting |
| **Fonts** | `city/godot/styles/*/assets/fonts/`, `docs/vision/style-studies/shared/page-kit/fonts/` | Their own licences, in the file beside each font: the [SIL Open Font License 1.1](LICENSES/OFL-1.1.txt), and the [Apache License 2.0](LICENSES/Apache-2.0.txt) for Special Elite |
| **Third-party code** | `docs/vision/style-studies/shared/page-kit/vendor/three/` (three.js) | Its own licence, beside it ([MIT](LICENSES/MIT.txt)) |
| **Third-party licence files** | `city/packaging/licenses/` (Godot's `LICENSE.txt` and `COPYRIGHT.txt`, the Rust standard library's and Emscripten's licence files, the MPL-2.0 text), `THIRD-PARTY-NOTICES.txt` | The notices and licence texts reproduced remain under their owners' terms; SJL claims no rights in the compilation in `THIRD-PARTY-NOTICES.txt` (CC0 1.0) |
| **Code of conduct** | [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Adapted from the Contributor Covenant 2.1, [CC BY 4.0](LICENSES/CC-BY-4.0.txt) |

## What ships in a package

A package of the city client (see [`city/README.md`](city/README.md#packaging))
combines Agentnagar's code (AGPL-3.0-only), its assets (CC BY-SA 4.0), the
bundled fonts (OFL 1.1), the Godot engine (MIT, with the components its
`COPYRIGHT.txt` lists), godot-rust (MPL-2.0, used unmodified) and other Rust
crates (MIT, Apache-2.0 and similar). Every package carries `LICENSE.txt` and
[`THIRD-PARTY-NOTICES.txt`](THIRD-PARTY-NOTICES.txt), which
`city/scripts/third_party_notices.py` writes, and the game shows both under
**About**, together with a link to this repository.

## Notes

- **The AGPL and networks.** If you modify Agentnagar and let people use
  your modified version over a network, the AGPL (section 13) requires you
  to offer them its source code.
- **Attribution for CC BY-SA material.** Credit "Super Jackfruit Labs (OPC)
  Private Limited and the Agentnagar contributors", link this repository,
  name the licence and say whether you changed the material.
- **Quoted material.** Documents under `docs/research/` and elsewhere quote
  short passages of third-party terms, prices, statutes and pages, with
  citations. Quoted third-party material remains under its owners' terms;
  the CC BY-SA licence covers only SJL's own text.
- **AI-generated concept art** is labelled as such where it lives. It is
  concept study material, not a shipped game asset. Purely generated images
  may carry no copyright in many jurisdictions; to the extent any rights
  exist, they are waived under CC0 1.0.
- **Names and logos are not licensed.** None of these licences grants any
  right to Agentnagar's or Super Jackfruit Labs' names, logos or app icon.
  See [`TRADEMARKS.md`](TRADEMARKS.md).
- **Contributions** are accepted under the [Contributor Licence
  Agreement](CLA.md) and licensed as the table above says. See
  [`CONTRIBUTING.md`](CONTRIBUTING.md).
