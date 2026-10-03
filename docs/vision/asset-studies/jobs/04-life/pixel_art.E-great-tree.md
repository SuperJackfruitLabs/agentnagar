# pixel_art.E-great-tree

The great tree (three stages) · life-cycle sheet (life-cycle sheet) · style: Pixel art · batch 04-life · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/pixel_art/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/pixel_art/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
3. `sheets/pixel_art/A-great-tree/LATEST/image.png` — the design sheet of this object: the newest revision in `sheets/pixel_art/A-great-tree/` (the highest rNNN)

`LATEST` stands for the newest revision folder of that design sheet. If the sheet has no image yet, skip this job and say so: it cannot be made first.

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset life-cycle sheet: one asset at three stages
Primary request: the great tree at three stages of its life, side by side, each drawn as a finished game sprite in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel). These are panels from the concept sheets of the Pixel art style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions. Image 3: the design sheet that shows the great tree. The second stage is that object exactly: the same design, parts, proportions and colours. Take nothing else from that sheet.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The great tree at the centre of the tree square: one large living shade tree, about 12 m across and 9.5 m tall, with a thick buttressed trunk that forks low into heavy spreading limbs. It stands in a raised bed 5.2 m square whose low edge people sit on. In this style: A large tree with a thick brown trunk and a clustered crown, bright yellow-green leaf highlights over dark teal-green shadow; a stone block bed with flowers. Three stages, left to right: 1. Newly planted: a young tree a quarter of the size, tied to a stake, in the same bed. 2. Mature, as it stands today. 3. Very old: a broader crown and heavier limbs, one limb propped on a timber support, more lanterns.
Style/medium: detailed 16-bit-era pixel art game sprite: hard-edged square pixels on one consistent grid, a small fixed palette, dark navy outlines, selective dithering, no anti-aliasing and no blur
Composition/framing: landscape canvas, 1536 x 1024, divided into three equal columns with clear empty backdrop between them; one stage in each, as a game sprite seen from the game's fixed camera: an orthographic view looking down at 30 degrees with the object turned 45 degrees, the 2:1 dimetric view of classic isometric pixel games, the same viewpoint and the same size in all three. Every sprite pixel is one square block about 5 canvas pixels wide, and all blocks sit on one grid.
Lighting/mood: the sprite's own fixed light from the upper left, with flat tone steps
Color palette: a small fixed palette close to the pack's own, with a navy outline (#181C30) round every sprite; add a colour only where the object needs one: leaf #285C34 #3E8C3E #78BE50, with one darker teal-green for deep shade and one yellow-green for highlights; wood #5C3A28 #8A5A3B; stone #AAA096 #CDC6BC and grey #787882; lamp #FFD26E #FFF0BE
Materials/textures: flat pixel clusters in two or three tones for each material, with selective dithering between tones; bricks, planks and leaves drawn as small pixel patterns
Constraints: the same object in all three stages, with the same footprint, main form and viewpoint; drawn in a few clear pixel clusters that still read at a sprite's small size; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, people, three different designs, perspective distortion, depth of field, bloom, anti-aliasing, blur, gradients, mixed pixel sizes, 3D render look, more than about forty colours
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are three stages in a row, of the same object from the same viewpoint.
- The backdrop is plain grey with no scenery (a soft gradient in the grey is fine).
- There is no readable text.
- The second stage is the object on its design sheet: the same design, not a new one.

## Save

```sh
python3 tools/intake.py add pixel_art.E-great-tree PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/pixel_art/E-great-tree/rNNN/image.png` with its prompt and its record.
