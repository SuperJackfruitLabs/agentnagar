# pixel_art.A-bridge

The north bridge · asset design sheet (design sheet) · style: Pixel art · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/pixel_art/park.jpg` — style reference: the park panel of this style's concept sheets
2. `refs/panels/pixel_art/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets
3. `refs/panels/pixel_art/rooftop.jpg` — style reference: the rooftop panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model or sprite will be built to
Primary request: a clean design sheet of one thing, the north bridge, drawn as a finished game sprite in the style of the reference images
Input images: Image 1: style reference (the park panel); Image 2: style reference (the diagonal panel); Image 3: style reference (the rooftop panel). These are panels from the concept sheets of the Pixel art style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The north bridge: one low stone bridge of three equal spans, each about 8 m long on piers about 1.5 m thick, with a deck about 4.3 m wide between railings, and beside it a length of quay wall about 2.5 m high. Low and level. No towers taller than a lamp post and no cables. In this style: Grey stone arches with a pale stone parapet between stone posts, and black lamp posts. Character notes: The oldest structure after the tree. Its middle pier still carries the mark of the highest flood.
Style/medium: detailed 16-bit-era pixel art game sprite: hard-edged square pixels on one consistent grid, a small fixed palette, dark navy outlines, selective dithering, no anti-aliasing and no blur
Composition/framing: landscape canvas, 1536 x 1024. Top two-thirds: the object large, as a game sprite seen from the game's fixed camera: an orthographic view looking down at 30 degrees with the object turned 45 degrees, the 2:1 dimetric view of classic isometric pixel games, the whole of its length in frame. Bottom third: its night version at the same size, with whatever lights it has lit. In the bottom right corner: a row of flat square colour swatches, one for each of these, in this order: stone, deck, railing, quay wall, water. Every sprite pixel is one square block about 5 canvas pixels wide, and all blocks sit on one grid.
Lighting/mood: the sprite's own fixed light from the upper left, with flat tone steps
Color palette: a small fixed palette close to the pack's own, with a navy outline (#181C30) round every sprite; add a colour only where the object needs one: stone #AAA096 #CDC6BC and grey #787882; dark #2E2B2A and outline navy #181C30; water #1E4678 #326EAA #78B4DC
Materials/textures: flat pixel clusters in two or three tones for each material, with selective dithering between tones; bricks, planks and leaves drawn as small pixel patterns
Constraints: one thing only, shown more than once as the same object with the same parts and colours; drawn in a few clear pixel clusters that still read at a sprite's small size; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, anti-aliasing, blur, gradients, mixed pixel sizes, 3D render look, more than about forty colours
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There is one thing only, whole in every view, and the views show the same object.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- Pixels are hard-edged squares of one size, with no blur.

## Save

```sh
python3 tools/intake.py add pixel_art.A-bridge PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/pixel_art/A-bridge/rNNN/image.png` with its prompt and its record.
