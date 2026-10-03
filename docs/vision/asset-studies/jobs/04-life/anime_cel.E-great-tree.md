# anime_cel.E-great-tree

The great tree (three stages) · life-cycle sheet (life-cycle sheet) · style: Cel-shaded anime · batch 04-life · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/anime_cel/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/anime_cel/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
3. `sheets/anime_cel/A-great-tree/LATEST/image.png` — the design sheet of this object: the newest revision in `sheets/anime_cel/A-great-tree/` (the highest rNNN)

`LATEST` stands for the newest revision folder of that design sheet. If the sheet has no image yet, skip this job and say so: it cannot be made first.

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset life-cycle sheet: one asset at three stages
Primary request: the great tree at three stages of its life, side by side, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel). These are panels from the concept sheets of the Cel-shaded anime style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions. Image 3: the design sheet that shows the great tree. The second stage is that object exactly: the same design, parts, proportions and colours. Take nothing else from that sheet.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The great tree at the centre of the tree square: one large living shade tree, about 12 m across and 9.5 m tall, with a thick buttressed trunk that forks low into heavy spreading limbs. It stands in a raised bed 5.2 m square whose low edge people sit on. In this style: A tall broad tree with a grey-brown forked trunk and a lush crown of large solid leaf clumps, closed all round and on top, yellow-green in light and deep green in shade; no aerial roots; the sheets draw the trunk rising straight from the paving, so keep the game's bed a low plain stone kerb. Three stages, left to right: 1. Newly planted: a young tree a quarter of the size, tied to a stake, in the same bed. 2. Mature, as it stands today. 3. Very old: a broader crown and heavier limbs, one limb propped on a timber support, more lanterns.
Style/medium: cel-shaded anime background art, drawn as a clean toon-shaded 3D game model: flat colour fills, two steps of cool lavender-grey shadow, thin dark ink lines on silhouettes and main edges
Composition/framing: landscape canvas, 1536 x 1024, divided into three equal columns with clear empty backdrop between them; one stage in each, in three-quarter view from the front-right with the camera raised about 30 degrees, the same viewpoint and the same size in all three.
Lighting/mood: clear even daylight from the upper left; each surface keeps one flat colour, with a single darker step only on the faces turned away from the light; no shadow shapes or streaks painted across a flat face, no coloured light, no long cast shadows
Color palette: deep green to yellow-green leaves (#3A4634, #757C49, #A9A550, #D0C870) with white and pink flowers; grey-brown bark, #423934 to #8E7C66; grey stone, #5D5C61 to #A29493; warm cream lamp light
Materials/textures: flat fills with a hard-edged shadow step and small painted highlights; brick, planks and paving joints drawn as a few thin lines; foliage as layered clusters of small leaf shapes
Constraints: the same object in all three stages, with the same footprint, main form and viewpoint; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, people, three different designs, perspective distortion, depth of field, bloom, photorealism, soft airbrushed gradients, heavy black outlines, chibi proportions, lens flare
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are three stages in a row, of the same object from the same viewpoint.
- The backdrop is plain grey with no scenery (a soft gradient in the grey is fine).
- There is no readable text.
- The second stage is the object on its design sheet: the same design, not a new one.

## Save

```sh
python3 tools/intake.py add anime_cel.E-great-tree PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/E-great-tree/rNNN/image.png` with its prompt and its record.
