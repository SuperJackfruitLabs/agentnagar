# anime_cel.A-bridge

The north bridge · asset design sheet (design sheet) · style: Cel-shaded anime · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/anime_cel/park.jpg` — style reference: the park panel of this style's concept sheets
2. `refs/panels/anime_cel/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets
3. `refs/panels/anime_cel/rooftop.jpg` — style reference: the rooftop panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one thing, the north bridge, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the park panel); Image 2: style reference (the diagonal panel); Image 3: style reference (the rooftop panel). These are panels from the concept sheets of the Cel-shaded anime style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The north bridge: one low stone bridge of three equal spans, each about 8 m long on piers about 1.5 m thick, with a deck about 4.3 m wide between railings, and beside it a length of quay wall about 2.5 m high. Low and level. No towers taller than a lamp post and no cables. In this style: Cream stone arches (#EFCFB5) with a dark iron railing and lamp posts on the deck. Character notes: The oldest structure after the tree. Its middle pier still carries the mark of the highest flood.
Style/medium: cel-shaded anime background art, drawn as a clean toon-shaded 3D game model: flat colour fills, two steps of cool lavender-grey shadow, thin dark ink lines on silhouettes and main edges
Composition/framing: landscape canvas, 1536 x 1024. Top two-thirds: one large three-quarter view from the front-right with the camera raised about 30 degrees, the whole of its length in frame. Bottom third: a straight-on side elevation running the width of the canvas. In the bottom right corner: a row of flat square colour swatches, one for each of these, in this order: stone, deck, railing, quay wall, water.
Lighting/mood: clear even daylight from the upper left; each surface keeps one flat colour, with a single darker step only on the faces turned away from the light; no shadow shapes or streaks painted across a flat face, no coloured light, no long cast shadows
Color palette: grey stone, #5D5C61 to #A29493; near-black iron, #25242B to #6E696C; deep blue water with white sparkles
Materials/textures: flat fills with a hard-edged shadow step and small painted highlights; brick, planks and paving joints drawn as a few thin lines; foliage as layered clusters of small leaf shapes
Constraints: one thing only, shown more than once as the same object with the same parts and colours; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, photorealism, soft airbrushed gradients, heavy black outlines, chibi proportions, lens flare
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There is one thing only, whole in every view, and the views show the same object.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.

## Save

```sh
python3 tools/intake.py add anime_cel.A-bridge PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/A-bridge/rNNN/image.png` with its prompt and its record.
