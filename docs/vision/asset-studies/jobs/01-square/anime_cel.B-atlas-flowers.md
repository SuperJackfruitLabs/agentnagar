# anime_cel.B-atlas-flowers

Small plants (cut-outs) · surface (cut-out atlas) · style: Cel-shaded anime · batch 01-square · canvas 1024 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/anime_cel/park.jpg` — style reference: the park panel of this style's concept sheets
2. `refs/panels/anime_cel/conversation.jpg` — style reference: the conversation panel of this style's concept sheets
3. `refs/panels/anime_cel/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: cut-out atlas for the foliage of a game
Primary request: four separate cut-outs of small plants, as the reference images draw them
Input images: Image 1: style reference (the park panel); Image 2: style reference (the conversation panel); Image 3: style reference (the gathering panel). These are panels from the concept sheets of the Cel-shaded anime style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one flat pure blue (#0000FF) backdrop across the whole canvas, used as a colour key, with no shadows or gradients on it
Subject: four separate pieces, one in each quarter of the canvas, each centred with clear backdrop all round it. In reading order: 1. A clump of flowers in bloom. 2. A second clump of different flowers. 3. A tuft of tall grass. 4. A low broad-leaved plant. In this style foliage is drawn as: layered clusters of small leaves, yellow-green in light and deep green in shade.
Style/medium: cel-shaded anime background art, drawn as a clean toon-shaded 3D game model: flat colour fills, two steps of cool lavender-grey shadow, thin dark ink lines on silhouettes and main edges
Composition/framing: square canvas, 1024 x 1024, divided into four equal quarters
Lighting/mood: clear even daylight from the upper left; each surface keeps one flat colour, with a single darker step only on the faces turned away from the light; no shadow shapes or streaks painted across a flat face, no coloured light, no long cast shadows
Color palette: deep green to yellow-green leaves (#3A4634, #757C49, #A9A550, #D0C870) with white and pink flowers
Constraints: each piece complete, inside its own quarter and touching nothing; crisp edges with no halo and none of the backdrop colour on the pieces; no ground, pots or shadows; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: pieces that overlap or run off the canvas, soft glows, photorealism, soft airbrushed gradients, heavy black outlines, chibi proportions, lens flare
```

## Before saving, look at the image

- The canvas is square.
- There are four separate pieces, one in each quarter, none touching another or the edge.
- The backdrop is one flat blue with no shadows.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add anime_cel.B-atlas-flowers PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/B-atlas-flowers/rNNN/image.png` with its prompt and its record.
