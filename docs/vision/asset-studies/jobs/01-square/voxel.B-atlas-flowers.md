# voxel.B-atlas-flowers

Small plants (cut-outs) · surface (cut-out atlas) · style: Voxel · batch 01-square · canvas 1024 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/voxel/park.jpg` — style reference: the park panel of this style's concept sheets
2. `refs/panels/voxel/conversation.jpg` — style reference: the conversation panel of this style's concept sheets
3. `refs/panels/voxel/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: cut-out atlas for the foliage of a game
Primary request: four separate cut-outs of small plants, as the reference images draw them
Input images: Image 1: style reference (the park panel); Image 2: style reference (the conversation panel); Image 3: style reference (the gathering panel). These are panels from the concept sheets of the Voxel style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one flat pure blue (#0000FF) backdrop across the whole canvas, used as a colour key, with no shadows or gradients on it
Subject: four separate pieces, one in each quarter of the canvas, each centred with clear backdrop all round it. In reading order: 1. A clump of flowers in bloom. 2. A second clump of different flowers. 3. A tuft of tall grass. 4. A low broad-leaved plant. In this style foliage is drawn as: green cubes in three tones, a few set proud of the mass, with white blossom cubes.
Style/medium: voxel 3D game model, seen as a clean render: forms built from cubes on one grid, with stepped edges where a curve would be; only the largest roofs (the workshop's sawtooth, the library's vault) are drawn smooth; no outlines
Composition/framing: square canvas, 1024 x 1024, divided into four equal quarters
Lighting/mood: bright even daylight from the upper left, soft shading between cubes, no coloured light, no hard cast shadows
Color palette: saturated greens (#18330B, #448114, #69A715, #A1D026) with white blossom cubes
Constraints: each piece complete, inside its own quarter and touching nothing; crisp edges with no halo and none of the backdrop colour on the pieces; no ground, pots or shadows; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: pieces that overlap or run off the canvas, soft glows, smooth or rounded surfaces, diagonal slopes, textures inside cube faces, ink outlines, tiny noisy cubes
```

## Before saving, look at the image

- The canvas is square.
- There are four separate pieces, one in each quarter, none touching another or the edge.
- The backdrop is one flat blue with no shadows.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add voxel.B-atlas-flowers PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/voxel/B-atlas-flowers/rNNN/image.png` with its prompt and its record.
