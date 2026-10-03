# solarpunk.E-great-tree

The great tree (three stages) · life-cycle sheet (life-cycle sheet) · style: Solarpunk retro-futurism · batch 04-life · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/solarpunk/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/solarpunk/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
3. `sheets/solarpunk/A-great-tree/LATEST/image.png` — the design sheet of this object: the newest revision in `sheets/solarpunk/A-great-tree/` (the highest rNNN)

`LATEST` stands for the newest revision folder of that design sheet. If the sheet has no image yet, skip this job and say so: it cannot be made first.

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset life-cycle sheet: one asset at three stages
Primary request: the great tree at three stages of its life, side by side, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel). These are panels from the concept sheets of the Solarpunk retro-futurism style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions. Image 3: the design sheet that shows the great tree. The second stage is that object exactly: the same design, parts, proportions and colours. Take nothing else from that sheet.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The great tree at the centre of the tree square: one large living shade tree, about 12 m across and 9.5 m tall, with a thick buttressed trunk that forks low into heavy spreading limbs. It stands in a raised bed 5.2 m square whose low edge people sit on. In this style: A massive spreading tree with a pale brown trunk, a few aerial roots and an olive and khaki crown; ringed by cream stone seat-planters and timber planter boxes with flowers. Three stages, left to right: 1. Newly planted: a young tree a quarter of the size, tied to a stake, in the same bed. 2. Mature, as it stands today. 3. Very old: a broader crown and heavier limbs, one limb propped on a timber support, more lanterns.
Style/medium: optimistic solarpunk design, drawn as a clean stylised 3D game model: rounded ceramic forms, slatted blonde timber, brass trim and blue solar glass, softly shaded, no outlines
Composition/framing: landscape canvas, 1536 x 1024, divided into three equal columns with clear empty backdrop between them; one stage in each, in three-quarter view from the front-right with the camera raised about 30 degrees, the same viewpoint and the same size in all three.
Lighting/mood: soft even warm daylight from the upper left, as in a product render: every surface readable, no golden-hour glow, no bloom, no hard cast shadows
Color palette: olive and khaki leaves (#342F14, #6A6A29, #979139, #C5BE5C) with pink, white and purple flowers; pale brown bark, #372617 to #B88F62; cream ceramic and pale stone; warm lantern light
Materials/textures: smooth matte ceramic, timber with a fine straight grain, brushed brass, blue solar panels with a visible cell grid; planting in soft clumps of small leaves; gentle painted shading, not photographic
Constraints: the same object in all three stages, with the same footprint, main form and viewpoint; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, people, three different designs, perspective distortion, depth of field, bloom, photorealism, heavy machinery, rust and grime, dystopian detail, ink outlines
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are three stages in a row, of the same object from the same viewpoint.
- The backdrop is plain grey with no scenery (a soft gradient in the grey is fine).
- There is no readable text.
- The second stage is the object on its design sheet: the same design, not a new one.

## Save

```sh
python3 tools/intake.py add solarpunk.E-great-tree PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/solarpunk/E-great-tree/rNNN/image.png` with its prompt and its record.
