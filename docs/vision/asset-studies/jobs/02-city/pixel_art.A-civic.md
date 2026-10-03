# pixel_art.A-civic

noticeboard, plaque, kiosk, steps and low wall · asset design sheet (design sheet) · style: Pixel art · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/pixel_art/facility.jpg` — style reference: the facility panel of this style's concept sheets
2. `refs/panels/pixel_art/street.jpg` — style reference: the street panel of this style's concept sheets
3. `refs/panels/pixel_art/park.jpg` — style reference: the park panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model or sprite will be built to
Primary request: a clean design sheet of 4 separate things, each drawn as a finished game sprite in the style of the reference images
Input images: Image 1: style reference (the facility panel); Image 2: style reference (the street panel); Image 3: style reference (the park panel). These are panels from the concept sheets of the Pixel art style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: 4 separate objects, in reading order. 1. A noticeboard: 1.5 m wide and 2.5 m high, on two posts under a small roof, with a board 1.1 m by 0.8 m. The board is blank: the game draws the notices. 2. A plaque on a low plinth: 60 cm wide and 1.2 m high, with a sloping face. The face is blank: the game draws its lettering. 3. An information kiosk: a standing slab 80 cm wide, 1.9 m high and 50 cm deep, with a screen 60 cm by 80 cm at chest height. The screen is blank: the game draws its content. In this style: A dark navy monolith with a blue screen. 4. Broad steps 3 m wide, 1 m deep and 45 cm high in three risers, and beside them a low sitting wall 3 m long, 30 cm thick and 45 cm high. Where a note above does not say how this style draws an object, use the style's own materials: grey stone blocks with lighter top faces; dark navy and black frame pixels; brown plank pixels in two tones with dark gaps.
Style/medium: detailed 16-bit-era pixel art game sprite: hard-edged square pixels on one consistent grid, a small fixed palette, dark navy outlines, selective dithering, no anti-aliasing and no blur
Composition/framing: landscape canvas, 1536 x 1024, divided into four equal cells, two across and two down with clear empty backdrop between them. One object in each, centred, as a game sprite seen from the game's fixed camera: an orthographic view looking down at 30 degrees with the object turned 45 degrees, the 2:1 dimetric view of classic isometric pixel games, drawn as large as its cell allows. Every object stands well clear of its neighbours and of the canvas edge: no part or shadow of one reaches another. Under each object: a short row of flat square colour swatches, one for each of its main materials. Every sprite pixel is one square block about 5 canvas pixels wide, and all blocks sit on one grid.
Lighting/mood: the sprite's own fixed light from the upper left, with flat tone steps
Color palette: a small fixed palette close to the pack's own, with a navy outline (#181C30) round every sprite; add a colour only where the object needs one: stone #AAA096 #CDC6BC and grey #787882; dark #2E2B2A and outline navy #181C30; wood #5C3A28 #8A5A3B
Materials/textures: flat pixel clusters in two or three tones for each material, with selective dithering between tones; bricks, planks and leaves drawn as small pixel patterns
Constraints: exactly 4 objects, each whole, inside its own cell and touching nothing; drawn in a few clear pixel clusters that still read at a sprite's small size; every screen, sign, board and plaque face is a plain blank surface; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, anti-aliasing, blur, gradients, mixed pixel sizes, 3D render look, more than about forty colours
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There are exactly 4 objects, each whole and inside the canvas.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- Screens, signs, boards and plaque faces are blank.
- Pixels are hard-edged squares of one size, with no blur.

## Save

```sh
python3 tools/intake.py add pixel_art.A-civic PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/pixel_art/A-civic/rNNN/image.png` with its prompt and its record.
