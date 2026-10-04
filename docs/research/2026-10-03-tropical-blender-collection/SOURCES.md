# Sources and generation record

The models and procedural Python scripts were created with OpenAI Codex,
using Blender 5.2.2 locally and human art direction/review. This is AI-assisted
procedural modelling, not a claim of hand modelling. No downloaded models,
purchased meshes or paid modelling APIs were used. Research and concept sheets
informed the design; the prior image-to-3D mesh builders were not copied.
The shared helper and 26 approved models carry forward our earlier local
Blender work. Their hashes are in `reports/delivery-integrity.json`.

The fourteen new concept sheets were generated with OpenAI's built-in image
generation tool. Prompts and a generation record are in `references/prompts/`.
Nine earlier tropical concept sheets come from the repository's
[asset studies](../../vision/asset-studies/README.md).
`references/manifest.json` records reference hashes, matching repository paths
where available, and which models each sheet guides. Coverage status strings
are historical notes from the reference phase.

- Procedural code, GDScript, shaders and gallery: AGPL-3.0-only.
- SJL's models, Blender sources, measured asset records, rendered previews and
  documentation: CC BY-SA 4.0; credit Super Jackfruit Labs (OPC) Private Limited
  and the Agentnagar contributors.
- AI-generated concept PNGs under `references/`: CC0-1.0, no rights claimed.

See [repository licensing](../../../COPYING.md). Local paths and tool-output
boilerplate were removed from public generation records. Rendered JPEGs are
compressed from the reviewed PNGs; `.blend` and `.glb` model bytes are unchanged.
