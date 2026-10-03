# solarpunk.B-atlas-flowers

Small plants (cut-outs) · surface (cut-out atlas) · style: Solarpunk retro-futurism · batch 01-square · canvas 1024 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/solarpunk/park.jpg` — style reference: the park panel of this style's concept sheets
2. `refs/panels/solarpunk/conversation.jpg` — style reference: the conversation panel of this style's concept sheets
3. `refs/panels/solarpunk/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: cut-out atlas for the foliage of a game
Primary request: four separate cut-outs of small plants, as the reference images draw them
Input images: Image 1: style reference (the park panel); Image 2: style reference (the conversation panel); Image 3: style reference (the gathering panel). These are panels from the concept sheets of the Solarpunk retro-futurism style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one flat pure blue (#0000FF) backdrop across the whole canvas, used as a colour key, with no shadows or gradients on it
Subject: four separate pieces, one in each quarter of the canvas, each centred with clear backdrop all round it. In reading order: 1. A clump of flowers in bloom. 2. A second clump of different flowers. 3. A tuft of tall grass. 4. A low broad-leaved plant. In this style foliage is drawn as: soft clumps of small olive and khaki leaves with pink, white and purple flowers.
Style/medium: optimistic solarpunk design, drawn as a clean stylised 3D game model: rounded ceramic forms, slatted blonde timber, brass trim and blue solar glass, softly shaded, no outlines
Composition/framing: square canvas, 1024 x 1024, divided into four equal quarters
Lighting/mood: soft even warm daylight from the upper left, as in a product render: every surface readable, no golden-hour glow, no bloom, no hard cast shadows
Color palette: olive and khaki leaves (#342F14, #6A6A29, #979139, #C5BE5C) with pink, white and purple flowers
Constraints: each piece complete, inside its own quarter and touching nothing; crisp edges with no halo and none of the backdrop colour on the pieces; no ground, pots or shadows; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: pieces that overlap or run off the canvas, soft glows, photorealism, heavy machinery, rust and grime, dystopian detail, ink outlines
```

## Before saving, look at the image

- The canvas is square.
- There are four separate pieces, one in each quarter, none touching another or the edge.
- The backdrop is one flat blue with no shadows.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add solarpunk.B-atlas-flowers PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/solarpunk/B-atlas-flowers/rNNN/image.png` with its prompt and its record.
