# pixel_art.A-shop

The shop · asset design sheet (design sheet) · style: Pixel art · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/pixel_art/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets
2. `refs/panels/pixel_art/street.jpg` — style reference: the street panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model or sprite will be built to
Primary request: a clean design sheet of one thing, the shop, drawn as a finished game sprite in the style of the reference images
Input images: Image 1: style reference (the diagonal panel); Image 2: style reference (the street panel). These are panels from the concept sheets of the Pixel art style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: A shop building about 5 m wide, 8.5 m high and 9 m deep: a glazed shopfront with a door and a deep awning at street level, and one or two plain storeys above. Leave a plain band above the awning for the game's own sign. In this style: The concept sheets do not show this closely, so design it to belong with what they do show, in this style's own materials: brown plank pixels in two tones with dark gaps; dark navy and black frame pixels; grey stone blocks with lighter top faces. Character notes: It has changed trades three times and kept the same awning frame.
Style/medium: detailed 16-bit-era pixel art game sprite: hard-edged square pixels on one consistent grid, a small fixed palette, dark navy outlines, selective dithering, no anti-aliasing and no blur
Composition/framing: landscape canvas, 1536 x 1024. Left two-thirds: the object large, as a game sprite seen from the game's fixed camera: an orthographic view looking down at 30 degrees with the object turned 45 degrees, the 2:1 dimetric view of classic isometric pixel games, the whole of it in frame with a clear margin. Right third, stacked: above, the same sprite turned to face the other way; below, its night version with whatever lights it has lit and everything else darkened towards navy. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: wall, shopfront, awning, window, roof. Every sprite pixel is one square block about 5 canvas pixels wide, and all blocks sit on one grid.
Lighting/mood: the sprite's own fixed light from the upper left, with flat tone steps
Color palette: a small fixed palette close to the pack's own, with a navy outline (#181C30) round every sprite; add a colour only where the object needs one: brick #7A3028 #A84834 #C86E50, sand stone #DEC496 #F0E0BE, slate-blue roofs #303A6E, windows #A0C8E1; red #C83C3C, royal blue #0251A4, yellow #F2B632, purple #825ABE
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
python3 tools/intake.py add pixel_art.A-shop PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/pixel_art/A-shop/rNNN/image.png` with its prompt and its record.
