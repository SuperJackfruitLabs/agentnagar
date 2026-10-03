# anime_cel.A-great-tree

The great tree · asset design sheet (design sheet) · style: Cel-shaded anime · batch 01b-redo · canvas 1536 x 1024

## Asked for again

This job has an image already and is to be made again: its first image (r001) drew the crown as airy layers of small leaves with the branches showing through; the image-to-3D model built it as a hollow ring of thin leaf, three times over. The job now asks for a crown of large solid leaf clumps, closed all round and on top. The new image becomes the next revision.

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/anime_cel/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/anime_cel/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one thing, the great tree, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel). These are panels from the concept sheets of the Cel-shaded anime style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The great tree at the centre of the tree square: one large living shade tree, about 12 m across and 9.5 m tall, with a thick buttressed trunk that forks low into heavy spreading limbs. It stands in a raised bed 5.2 m square whose low edge people sit on. Outside the 5.2 m bed nothing hangs lower than 2.2 m, because people walk under the crown. The crown is wide and fairly flat on top. A few small lanterns hang from the limbs. The crown is one closed mass of large, solid, rounded leaf clumps: full all round and on top, with no gaps through which the sky or the branches show, and no single leaves or twigs. In this style: A tall broad tree with a grey-brown forked trunk and a lush crown of large solid leaf clumps, closed all round and on top, yellow-green in light and deep green in shade; no aerial roots; the sheets draw the trunk rising straight from the paving, so keep the game's bed a low plain stone kerb. Character notes: It is older than every building round it, and the square was laid out to keep it. The lanterns were hung by the guild's makers.
Style/medium: cel-shaded anime background art, drawn as a clean toon-shaded 3D game model: flat colour fills, two steps of cool lavender-grey shadow, thin dark ink lines on silhouettes and main edges
Composition/framing: landscape canvas, 1536 x 1024. Left two-thirds: one large three-quarter view from the front-right with the camera raised about 30 degrees, the whole of it in frame with a clear margin. Right third, stacked: a straight-on front elevation above, a straight-down plan view below. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: leaves in light, leaves in shade, bark, bed edge, lantern.
Lighting/mood: clear even daylight from the upper left; each surface keeps one flat colour, with a single darker step only on the faces turned away from the light; no shadow shapes or streaks painted across a flat face, no coloured light, no long cast shadows
Color palette: deep green to yellow-green leaves (#3A4634, #757C49, #A9A550, #D0C870) with white and pink flowers; grey-brown bark, #423934 to #8E7C66; grey stone, #5D5C61 to #A29493; warm cream lamp light
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
python3 tools/intake.py add anime_cel.A-great-tree PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/A-great-tree/rNNN/image.png` with its prompt and its record.
