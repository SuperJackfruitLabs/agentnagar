# solarpunk.A-street-fixtures

street lamp, bollard, catenary pole, railing · asset design sheet (design sheet) · style: Solarpunk retro-futurism · batch 01a-square-props · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/solarpunk/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/solarpunk/park.jpg` — style reference: the park panel of this style's concept sheets
3. `refs/panels/solarpunk/transit.jpg` — style reference: the transit panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of 4 separate things, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the park panel); Image 3: style reference (the transit panel). These are panels from the concept sheets of the Solarpunk retro-futurism style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: 4 separate objects, in reading order. 1. A street lamp: 4.2 m high, one lantern at about 3.5 m on a slim post with a small base. In this style: A slim dark post with a brass-capped glass lantern. 2. A bollard: 90 cm high and 24 cm across. 3. A catenary pole for the tram's overhead wire: 6 m high, slim, with one side arm near the top. 4. A railing panel: 2 m long and 1.1 m high, with an end post. Where a note above does not say how this style draws an object, use the style's own materials: brushed brass trim with dark slim steel; warm glass lantern with a brass cap; cream ceramic or pale stone with rounded corners.
Style/medium: optimistic solarpunk design, drawn as a clean stylised 3D game model: rounded ceramic forms, slatted blonde timber, brass trim and blue solar glass, softly shaded, no outlines
Composition/framing: landscape canvas, 1536 x 1024, divided into four equal columns with clear empty backdrop between them. One object in each column, in three-quarter view from the front-right with the camera raised about 30 degrees, standing on a ground line near the bottom of its column and drawn as tall as the column allows, so the objects are not drawn to one scale. Every object stands well clear of its neighbours and of the canvas edge: no part or shadow of one reaches another. Under each object: a short row of flat square colour swatches, one for each of its main materials.
Lighting/mood: soft even warm daylight from the upper left, as in a product render: every surface readable, no golden-hour glow, no bloom, no hard cast shadows
Color palette: brushed brass, with dark slim steel; warm lantern light; cream ceramic and pale stone
Materials/textures: smooth matte ceramic, timber with a fine straight grain, brushed brass, blue solar panels with a visible cell grid; planting in soft clumps of small leaves; gentle painted shading, not photographic
Constraints: exactly 4 objects, each whole, inside its own cell and touching nothing; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, photorealism, heavy machinery, rust and grime, dystopian detail, ink outlines
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There are exactly 4 objects, each whole and inside the canvas.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.

## Save

```sh
python3 tools/intake.py add solarpunk.A-street-fixtures PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/solarpunk/A-street-fixtures/rNNN/image.png` with its prompt and its record.
