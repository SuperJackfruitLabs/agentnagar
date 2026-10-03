# pixel_art.B-atlas-flowers

Small plants (cut-outs) · surface (cut-out atlas) · style: Pixel art · batch 01-square · canvas 1024 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/pixel_art/park.jpg` — style reference: the park panel of this style's concept sheets
2. `refs/panels/pixel_art/conversation.jpg` — style reference: the conversation panel of this style's concept sheets
3. `refs/panels/pixel_art/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: cut-out atlas for the foliage of a game
Primary request: four separate cut-outs of small plants, as the reference images draw them
Input images: Image 1: style reference (the park panel); Image 2: style reference (the conversation panel); Image 3: style reference (the gathering panel). These are panels from the concept sheets of the Pixel art style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one flat pure blue (#0000FF) backdrop across the whole canvas, used as a colour key, with no shadows or gradients on it
Subject: four separate pieces, one in each quarter of the canvas, each centred with clear backdrop all round it. In reading order: 1. A clump of flowers in bloom. 2. A second clump of different flowers. 3. A tuft of tall grass. 4. A low broad-leaved plant. In this style foliage is drawn as: clustered leaf pixels in three greens with a few flower pixels.
Style/medium: detailed 16-bit-era pixel art game sprite: hard-edged square pixels on one consistent grid, a small fixed palette, dark navy outlines, selective dithering, no anti-aliasing and no blur
Composition/framing: square canvas, 1024 x 1024, divided into four equal quarters Every sprite pixel is one square block about 5 canvas pixels wide, and all blocks sit on one grid.
Lighting/mood: the sprite's own fixed light from the upper left, with flat tone steps
Color palette: a small fixed palette close to the pack's own, with a navy outline (#181C30) round every sprite; add a colour only where the object needs one: leaf #285C34 #3E8C3E #78BE50, with one darker teal-green for deep shade and one yellow-green for highlights
Constraints: each piece complete, inside its own quarter and touching nothing; crisp edges with no halo and none of the backdrop colour on the pieces; no ground, pots or shadows; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: pieces that overlap or run off the canvas, soft glows, anti-aliasing, blur, gradients, mixed pixel sizes, 3D render look, more than about forty colours
```

## Before saving, look at the image

- The canvas is square.
- There are four separate pieces, one in each quarter, none touching another or the edge.
- The backdrop is one flat blue with no shadows.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add pixel_art.B-atlas-flowers PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/pixel_art/B-atlas-flowers/rNNN/image.png` with its prompt and its record.
