# solarpunk.A-resident

A resident · asset design sheet (design sheet) · style: Solarpunk retro-futurism · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/solarpunk/conversation.jpg` — style reference: the conversation panel of this style's concept sheets
2. `refs/panels/solarpunk/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
3. `refs/panels/solarpunk/workshop.jpg` — style reference: the workshop panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one figure, a resident, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the conversation panel); Image 2: style reference (the gathering panel); Image 3: style reference (the workshop panel). These are panels from the concept sheets of the Solarpunk retro-futurism style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: A resident of the city: an adult about 1.8 m tall in contemporary everyday clothes for a warm climate. Standing relaxed with the arms slightly away from the body. A shirt or top, trousers or a skirt, shoes. No lettering on clothes. In this style: Loose linen and cotton in natural colours, a canvas backpack. Character notes: One of the people who live and work here. Nobody in the city is background.
Style/medium: optimistic solarpunk design, drawn as a clean stylised 3D game model: rounded ceramic forms, slatted blonde timber, brass trim and blue solar glass, softly shaded, no outlines
Composition/framing: landscape canvas, 1536 x 1024. Four full-body views of the same figure in one row, equally spaced, all the same height and standing on the same ground line: front, three-quarter front, side, back. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: skin, hair, top, bottom, shoes.
Lighting/mood: soft even warm daylight from the upper left, as in a product render: every surface readable, no golden-hour glow, no bloom, no hard cast shadows
Color palette: natural linen, cream, olive and rust clothes
Materials/textures: smooth matte ceramic, timber with a fine straight grain, brushed brass, blue solar panels with a visible cell grid; planting in soft clumps of small leaves; gentle painted shading, not photographic
Constraints: one figure only, shown four times as the same figure with the same clothes, parts and colours; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, photorealism, heavy machinery, rust and grime, dystopian detail, ink outlines
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There is one thing only, whole in every view, and the views show the same object.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.

## Save

```sh
python3 tools/intake.py add solarpunk.A-resident PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/solarpunk/A-resident/rNNN/image.png` with its prompt and its record.
