# anime_cel.A-trees

street tree, small street tree, tall palm, short palm · asset design sheet (design sheet) · style: Cel-shaded anime · batch 01a-square-props · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/anime_cel/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/anime_cel/park.jpg` — style reference: the park panel of this style's concept sheets
3. `refs/panels/anime_cel/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of 4 separate things, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the park panel); Image 3: style reference (the diagonal panel). These are panels from the concept sheets of the Cel-shaded anime style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: 4 separate objects, in reading order. 1. A street tree: crown 4.6 m across, 5.5 m tall, with a clear trunk to 2.2 m. The crown is a closed, rounded mass of solid leaf clumps, full on top and all round. 2. A smaller street tree: crown 3.4 m across, 4.4 m tall, with a clear trunk to 2.2 m. The crown is a closed, rounded mass of solid leaf clumps, full on top and all round. 3. A tall palm: 8.5 m high, fronds 5.2 m across, on a slender ringed trunk with a slight lean. 4. A short palm: 4.5 m high, fronds 3.4 m across. Where a note above does not say how this style draws an object, use the style's own materials: layered clusters of small leaves, yellow-green in light and deep green in shade; grey-brown trunk with a clear shadow side.
Style/medium: cel-shaded anime background art, drawn as a clean toon-shaded 3D game model: flat colour fills, two steps of cool lavender-grey shadow, thin dark ink lines on silhouettes and main edges
Composition/framing: landscape canvas, 1536 x 1024, divided into four equal columns with clear empty backdrop between them. One object in each column, in three-quarter view from the front-right with the camera raised about 30 degrees, standing on a ground line near the bottom of its column and drawn as tall as the column allows, so the objects are not drawn to one scale. Every object stands well clear of its neighbours and of the canvas edge: no part or shadow of one reaches another. Under each object: a short row of flat square colour swatches, one for each of its main materials.
Lighting/mood: clear even daylight from the upper left; each surface keeps one flat colour, with a single darker step only on the faces turned away from the light; no shadow shapes or streaks painted across a flat face, no coloured light, no long cast shadows
Color palette: deep green to yellow-green leaves (#3A4634, #757C49, #A9A550, #D0C870) with white and pink flowers; grey-brown bark, #423934 to #8E7C66
Materials/textures: flat fills with a hard-edged shadow step and small painted highlights; brick, planks and paving joints drawn as a few thin lines; foliage as layered clusters of small leaf shapes
Constraints: exactly 4 objects, each whole, inside its own cell and touching nothing; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, photorealism, soft airbrushed gradients, heavy black outlines, chibi proportions, lens flare
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There are exactly 4 objects, each whole and inside the canvas.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.

## Save

```sh
python3 tools/intake.py add anime_cel.A-trees PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/A-trees/rNNN/image.png` with its prompt and its record.
