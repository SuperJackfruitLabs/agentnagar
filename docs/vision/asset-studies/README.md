# Asset studies: instructions for generating design images

_Written on 2026-10-02 by an AI coding agent (Claude Opus 5.5, Anthropic) for Agentnagar's art rework · a proposal, not adopted · **the pilot batch (21 images) was run on 2026-10-02 and the pack was revised from it** (see [Changes after the pilot batch](#changes-after-the-pilot-batch)) · it follows the [asset-to-sheet pilot](../../research/2026-10-01-asset-to-sheet-pilot/README.md)._

**This folder holds 311 ready-to-run image jobs that give every asset the game draws today its own design image in each of the six styles, together with the colours, surfaces, shapes and repainted frames those assets need.** The pilot found that the concept sheets are scene paintings: an asset is 50 to 350 pixels in a panel and is drawn differently from panel to panel, so there was no clean target to build to. These jobs ask an image model for that target. The images are made with the owner's ChatGPT subscription, by ChatGPT's coding agent working in this folder or by hand in a chat.

## What gets made

| | Family | What one image is | Images |
| --- | --- | --- | --- |
| A | **Design sheets** | One asset, or four to six small ones, alone on a flat grey backdrop in one style: a three-quarter view, a front and a plan, and a row of colour swatches. The target a model is built to and its colours are measured from. | 126 |
| B | **Surfaces** | Material boards (six flat samples), tiling textures for ground, walls, roofs, timber and bark, and cut-out atlases of leaves and small plants. | 84 |
| C | **Shapes** | One plain object, like an untextured 3D model in a viewer: what the image-to-3D model on the laptop needs. Trees, palms, shrubs and plants, plain and as voxels. | 15 |
| D | **Frames** | A capture of the game as it is today, repainted in the style without moving anything: a like-for-like picture of where the game should get to. Some are also "dressed" with the planting, furniture and people the concept sheets show. | 44 |
| E | **Life-cycle sheets** | One asset at three stages: being built, new, and after years of use. Optional. | 42 |

Run them in batches, one at a time:

| Batch | Design sheets | Material boards | Textures | Cut-out atlases | Shapes | Frames | Dressed frames | Life-cycle | Total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `00-pilot` (done) | 5 | 2 | 2 | 2 | 3 | 2 | | 2 | **18** |
| `00b-pilot-rest` (done) | 6 | | | | | | | | **6** |
| `01a-square-props` (done) | 30 | | | | | | | | **30** |
| `01b-redo` (next) | 3 | | | | | | | | **3** |
| `01-square` | 32 | 10 | 4 | 10 | | 15 | | | **71** |
| `02-city` | 50 | | 54 | | | 16 | 11 | | **131** |
| `03-shapes` | | | | | 12 | | | | **12** |
| `04-life` | | | | | | | | 40 | **40** |

The pilot batch tried every kind of job once or twice: in low-poly (the easiest style, already close to a render), in neon noir (the hardest, a night style whose assets came out worst in the pilot) and in pixel art (sprites, not models). It made 21 images; three of its jobs are asked for again and are counted in the batches that make them again (the neon great tree in `00b-pilot-rest`, the low-poly and neon seating sheets in `01b-redo`). `00b-pilot-rest` gave the three styles the pilot left out (voxel, anime, solarpunk) the same two design sheets, the seating and the great tree, and made the neon great tree again in neutral light; it was run on 2026-10-02 and all seven images were used (one of its jobs, the anime great tree, is asked for again in `01b-redo`). `01a-square-props` is thirty design sheets of single things that stand in and round the tree square (terrace furniture, street fixtures, street trees and palms, low planting, the tram shelter, the fountain) in the five styles whose sheets have been turned into game pieces; it is being run. It is cut out of the two large batches, which also hold what cannot be used yet: buildings the game assembles from modules, pixel art, surfaces that have not been tried in the game. `01b-redo` is the next: three sheets asked for again after pieces were built from their first images, the anime great tree (the image-to-3D model built its airy crown as a hollow ring) and the low-poly and neon seating sheets (their perch seat was drawn as a stool). [JOBS.md](JOBS.md) lists every job.

## How to run it

With ChatGPT's coding agent (Codex), from the repository:

```sh
codex
```

and give it this:

> Read docs/vision/asset-studies/INSTRUCTIONS.md and do batch 01b-redo.

[INSTRUCTIONS.md](INSTRUCTIONS.md) is written for that agent. It tells it to load each job's reference images, submit the job's prompt unchanged, look at the result against the job's checks, file the image and write down honestly what is wrong with it. It forbids paid tools: the agent's built-in image tool only. Image generation counts towards the subscription's usage limits.

By hand in a ChatGPT chat: upload the job's reference images in order, paste the job's prompt, download the result as `<job id>.png`, and file a folder of downloads with `python3 tools/intake.py folder <folder>`.

Afterwards:

```sh
cd docs/vision/asset-studies
python3 tools/intake.py status 01b-redo       # what is done
python3 tools/intake.py check 01b-redo        # records, hashes and shapes
uv run --with pillow python3 tools/intake.py contact 01b-redo    # one sheet a style: sheets/contact-01b-redo-<style>.jpg
```

Each image lands in `sheets/<style>/<item>/r001/` as `image.png` with `prompt.txt` (the exact prompt), `generation.json` (hashes, size, references, generator) and `review.md` (the agent's own inspection). That is the same record the style studies keep for their sheets. A filed image is a candidate. Nothing is accepted until the owner says so.

## What the pilot batch showed

The pilot was to answer six questions. The answers come from looking at all 21 images, putting 11 of them through the image-to-3D model and building four pieces in two styles from them ([the record](../../research/2026-10-02-design-sheet-to-asset/README.md)).

1. **Does a design sheet hold the style?** Low-poly: yes. Neon noir: the objects are right but drawn near-photoreal. Pixel art: no.
2. **Is the layout usable?** Yes: whole objects on a plain backdrop with their swatches. The views of one object do not agree in detail, so only one view is used, and a neighbour can intrude at the edge of a cut-out.
3. **Is the night style readable in neutral light?** The seats, yes. The great tree came back as a night scene lit by its own lamps, and its colours could not be used.
4. **Do the shapes work in the image-to-3D model?** Yes, all three. So do the objects on design sheets, which is the more useful result: a seat or a tree cut from its sheet comes back as a whole model.
5. **Does a repainted frame keep the layout?** Yes. It stays close to the capture.
6. **Do the pixel sheets keep one pixel size?** No. They serve as colour and shape guides only.

## Changes after the pilot batch

Made on 2026-10-02 from those answers and from two reviews of the pack (kept with the record, in its `notes/`).

- **Night styles in neutral light.** A design image in neon noir now asks for every surface in its own colour, with lamps drawn lit as small bright parts that throw no light on the object, and the neon palette no longer offers lit colours for leaves and bark. The job checks for it.
- **Neon noir drawn as a game model.** Photorealism is on its avoid list.
- **A plain backdrop, not a flat one.** A soft gradient in the grey is accepted. The image agent spent one or two generations a sheet flattening it.
- **Sturdier, better-spaced objects.** Nothing wire-thin (thin legs do not survive the cut to a game model), leaves as solid masses, and objects on a grid sheet kept clear of each other.
- **Descriptions corrected against the sheets.** Sixty-three entries in `data/styles.json` and `data/subjects.json`, most of them lines that a second reading of the concept sheets contradicted or could not support. Where the sheets draw no café or café umbrella in a style, the description is removed and the job asks for one that belongs with what the sheets do show.
- **The perch seat** is described as what the game uses it for: a plain seat stone at every place someone can sit on a wall or a step, not a stool.
- **Life-cycle sheets tied to their design sheets.** The pilot's worn bench was a different bench from its design sheet's. A life-cycle job now loads the newest image of its object's design sheet and holds the middle stage to it, so it cannot be made before that sheet exists.
- **A job can be asked for again** (`redo` in `data/plan.json`): `status` shows it as to do until it has a second image.
- **Corrections keep their prompt.** `intake.py add --correction "<text>"` files the job's prompt with the correction after it. Before, a corrected image's record held only the correction.
- **Repainted frames are corrected from the capture**, not from the first result.
- **No local paths in the records.** Six of the image agent's reviews named files by their full path on the laptop. The home directory in those ten lines is replaced by `$CODEX_HOME`, the instructions now ask for file names only, and `check` reports such a path as a fault.

Not changed: the cut-out atlases still use a colour key (the pilot's atlas keyed cleanly), and the square images come back at 1254 pixels, not 1024, which the tools accept.

## What happens with the images

- **Design sheets** replace the scene panels as targets. The pilot's tools measure a material's colours inside boxes on an image; a design sheet gives them an asset hundreds of pixels across instead of fifty, with nothing in front of it.
- **Material boards and textures** give the ground and wall colours the game lacks today, and are the first material for trying detail on surfaces that are now one flat colour.
- **Cut-out atlases** are tried as the leaf cards of the three packs that draw foliage that way.
- **Shapes** go through the image-to-3D model, and whatever comes out is styled by each pack's own kit code, as the great tree was.
- **Frames** are set beside captures after each change, in place of the scene panels, whose cameras never matched the game's.
- **Life-cycle sheets** are for later, when the game shows construction and age.

The first of this was built on 2026-10-02: the bench, the café chair, the reading chair and the great tree, in low-poly and neon noir overnight from the pilot's design sheets, then in anime, solarpunk and voxel, with the perch seat and the tree square's props from batch `01a-square-props` ([the record](../../research/2026-10-02-design-sheet-to-asset/README.md)). The textures, boards and atlases have been checked but not used.

## How the jobs are written

The jobs are generated from three data files, so a change is made once and applies everywhere:

- [`data/styles.json`](data/styles.json): each style as an image model needs it described: medium, surfaces, light, a palette by material (with the colours measured from the concept sheets during the pilot), and how it draws timber, stone, foliage and the rest. [STYLES.md](STYLES.md) is the readable copy.
- [`data/subjects.json`](data/subjects.json): each thing, with its real size from the kits' specs, what the game needs of it (a seat at 45 cm, nothing hanging below 2.2 m outside a tree's bed, a screen left blank because the game draws on it), how each style's sheets draw it, and a line of character. [SUBJECTS.md](SUBJECTS.md) is the readable copy.
- [`data/plan.json`](data/plan.json): which things go on which sheet, which panels of the concept sheets are given as style references, and which batch a job belongs to.

After an edit:

```sh
python3 tools/build_jobs.py            # rewrite jobs/, JOBS.md, STYLES.md, SUBJECTS.md
python3 tools/build_jobs.py --check    # everything up to date, every reference present
```

The prompts use the labelled lines of the Codex image generation skill (`Use case`, `Subject`, `Composition/framing`, `Constraints` and so on), so the agent passes them through unchanged. A job gives the model two or three panels of that style's concept sheets as style references (`refs/panels/`); a frame job also gives it the game's capture to repaint (`refs/frames/`), and the plain shapes are given none. `tools/make_refs.py` made both; it cuts the panels well inside their edges so that no caption comes along.

## Limits

- **Tested once.** Twenty-one of the 311 jobs have been through the image model: three styles and three plain shapes. The revised jobs have not been run.
- **The style and subject descriptions are one reading of the concept sheets**, by the same agent whose reading of a crop was wrong in the pilot. Where a sheet does not show a thing closely, the description says so and asks for something that belongs with what is shown. Read [STYLES.md](STYLES.md) and [SUBJECTS.md](SUBJECTS.md) before the full batches; they are short.
- **The lines of character are invented.** Each thing has a proposed sentence or two of history ("made in the guild hall; the seat boards are worn paler where people sit"). They are there to give the designs something particular, and they are the owner's to rewrite or strike out.
- **Image models hold layout, text and consistency loosely.** Every prompt forbids text, and screens, signs and plaques are asked for blank, because the game draws on them. Views of one object may disagree in detail. A texture asked to be seamless must be tiled and looked at before it is believed.
- **Only what the game draws today is covered**: the 34 kinds in the catalogue and the other pieces the kits build. The vision's catalogue of 108 kinds (homes, tools, small objects, other vehicles) is not, and neither is the interface.
- **The frames show the game at commit `f393026`.** They need making again when the game changes: `tools/make_refs.py frames`.
- **Painted light is still painted.** A repainted frame shows a look that one sun and one ambient colour may not reach. It is a target for judging by eye, not a promise.

## Files

- `README.md`, `INSTRUCTIONS.md`: this page, and the agent's instructions.
- `data/`: the three files the jobs are written from.
- `jobs/`: one file a job, by batch, and `jobs.json`, the same for the tools. `JOBS.md`, `STYLES.md`, `SUBJECTS.md`: generated indexes.
- `refs/panels/<style>/`: sixteen panels a style, cut from the selected concept sheets (AI-generated, CC0, as the sheets are). `refs/frames/<style>/`: the game's captures, cropped to 3:2. `sources.json` in each says where every file came from.
- `tools/build_jobs.py`, `tools/make_refs.py`, `tools/intake.py`: writing the jobs, making the references, filing and checking the images.
- `sheets/`: where the images go. It holds the 58 images of the first three batches with their records: 28 from the two pilot batches and 30 from `01a-square-props`.

The images are AI-generated material and say so where they are kept: `generation.json` records the generator, the prompt and the references, and `REUSE.toml` and `COPYING.md` carry entries for them and for the panels, as the concept sheets have.
