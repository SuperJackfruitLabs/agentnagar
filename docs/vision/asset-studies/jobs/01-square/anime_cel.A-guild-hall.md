# anime_cel.A-guild-hall

The guild hall · asset design sheet (design sheet) · style: Cel-shaded anime · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/anime_cel/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/anime_cel/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
3. `refs/panels/anime_cel/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one thing, the guild hall, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel); Image 3: style reference (the diagonal panel). These are panels from the concept sheets of the Cel-shaded anime style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The guild hall, the makers' workshop: a low rectangular hall under three sawtooth roof bays, each about 4.3 m wide, with walls 5.2 m high and roof ridges about 8 m high. Its front is made of panels 4 m wide: solid wall, glazed wall, and one door panel with double doors 2 m wide and 3.2 m high, between square corner piers. Workbenches show through the glazing. Keep three equal sawtooth bays on a low, long hall. Leave a plain band above the door for the game's own sign. In this style: A red-brick hall with red-brown sawtooth roofs, each slope carrying one long blue-grey skylight, and tall windows in dark slim steel frames. Character notes: The guild built it for itself. The north-light roof was drawn first, and each bay was put up by a different crew, so the bays match without being identical.
Style/medium: cel-shaded anime background art, drawn as a clean toon-shaded 3D game model: flat colour fills, two steps of cool lavender-grey shadow, thin dark ink lines on silhouettes and main edges
Composition/framing: landscape canvas, 1536 x 1024. Left two-thirds: one large three-quarter view from the front-right with the camera raised about 30 degrees, the whole of it in frame with a clear margin. Right third, stacked: a straight-on front elevation above, a straight-down plan view below. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: wall, roof, frame, glass, door.
Lighting/mood: clear even daylight from the upper left; each surface keeps one flat colour, with a single darker step only on the faces turned away from the light; no shadow shapes or streaks painted across a flat face, no coloured light, no long cast shadows
Color palette: red brick, red-brown workshop roofs with long blue-grey skylights, silver metal on the library's vault, pale concrete and blue glass, warm white render; warm cream lamp light; indigo and vermilion
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
python3 tools/intake.py add anime_cel.A-guild-hall PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/A-guild-hall/rNNN/image.png` with its prompt and its record.
