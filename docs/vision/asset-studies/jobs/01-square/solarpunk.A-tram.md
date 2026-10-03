# solarpunk.A-tram

The tram · asset design sheet (design sheet) · style: Solarpunk retro-futurism · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/solarpunk/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/solarpunk/transit.jpg` — style reference: the transit panel of this style's concept sheets
3. `refs/panels/solarpunk/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one thing, the tram, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the transit panel); Image 3: style reference (the diagonal panel). These are panels from the concept sheets of the Solarpunk retro-futurism style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The boulevard tram: a low-floor tram 20.5 m long, 2.5 m wide and about 3.5 m high to the roof, with a pantograph above, in three to five jointed sections, with wide doors on both sides, a long band of windows and a driver's cab at each end. A cream or white body with one coral-red stripe along its length, in every style. Windows are dark by day. It runs on rails set flush in the ground. In this style: A long white tram with a red stripe, black door frames and a slim roof. Character notes: It is the line's first tram and still in service. The stripe is repainted by hand every year.
Style/medium: optimistic solarpunk design, drawn as a clean stylised 3D game model: rounded ceramic forms, slatted blonde timber, brass trim and blue solar glass, softly shaded, no outlines
Composition/framing: landscape canvas, 1536 x 1024. Top two-thirds: one large three-quarter view from the front-right with the camera raised about 30 degrees, the whole of its length in frame. Bottom third: a straight-on side elevation running the width of the canvas. In the bottom right corner: a row of flat square colour swatches, one for each of these, in this order: body, stripe, windows, roof equipment, doors.
Lighting/mood: soft even warm daylight from the upper left, as in a product render: every surface readable, no golden-hour glow, no bloom, no hard cast shadows
Color palette: a white body with a red stripe and black door frames; brushed brass, with dark slim steel
Materials/textures: smooth matte ceramic, timber with a fine straight grain, brushed brass, blue solar panels with a visible cell grid; planting in soft clumps of small leaves; gentle painted shading, not photographic
Constraints: one thing only, shown more than once as the same object with the same parts and colours; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
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
python3 tools/intake.py add solarpunk.A-tram PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/solarpunk/A-tram/rNNN/image.png` with its prompt and its record.
