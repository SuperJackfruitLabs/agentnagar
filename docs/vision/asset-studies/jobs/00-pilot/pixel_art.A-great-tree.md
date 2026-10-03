# pixel_art.A-great-tree

The great tree · asset design sheet (design sheet) · style: Pixel art · batch 00-pilot · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/pixel_art/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/pixel_art/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model or sprite will be built to
Primary request: a clean design sheet of one thing, the great tree, drawn as a finished game sprite in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel). These are panels from the concept sheets of the Pixel art style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The great tree at the centre of the tree square: one large living shade tree, about 12 m across and 9.5 m tall, with a thick buttressed trunk that forks low into heavy spreading limbs. It stands in a raised bed 5.2 m square whose low edge people sit on. Outside the 5.2 m bed nothing hangs lower than 2.2 m, because people walk under the crown. The crown is wide and fairly flat on top. A few small lanterns hang from the limbs. The crown is one closed mass of large, solid, rounded leaf clumps: full all round and on top, with no gaps through which the sky or the branches show, and no single leaves or twigs. In this style: A large tree with a thick brown trunk and a clustered crown, bright yellow-green leaf highlights over dark teal-green shadow; a stone block bed with flowers. Character notes: It is older than every building round it, and the square was laid out to keep it. The lanterns were hung by the guild's makers.
Style/medium: detailed 16-bit-era pixel art game sprite: hard-edged square pixels on one consistent grid, a small fixed palette, dark navy outlines, selective dithering, no anti-aliasing and no blur
Composition/framing: landscape canvas, 1536 x 1024. Left two-thirds: the object large, as a game sprite seen from the game's fixed camera: an orthographic view looking down at 30 degrees with the object turned 45 degrees, the 2:1 dimetric view of classic isometric pixel games, the whole of it in frame with a clear margin. Right third, stacked: above, the same sprite turned to face the other way; below, its night version with whatever lights it has lit and everything else darkened towards navy. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: leaves in light, leaves in shade, bark, bed edge, lantern. Every sprite pixel is one square block about 5 canvas pixels wide, and all blocks sit on one grid.
Lighting/mood: the sprite's own fixed light from the upper left, with flat tone steps
Color palette: a small fixed palette close to the pack's own, with a navy outline (#181C30) round every sprite; add a colour only where the object needs one: leaf #285C34 #3E8C3E #78BE50, with one darker teal-green for deep shade and one yellow-green for highlights; wood #5C3A28 #8A5A3B; stone #AAA096 #CDC6BC and grey #787882; lamp #FFD26E #FFF0BE
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
python3 tools/intake.py add pixel_art.A-great-tree PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/pixel_art/A-great-tree/rNNN/image.png` with its prompt and its record.
