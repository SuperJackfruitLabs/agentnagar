# pixel_art.A-tram-shelter

The tram shelter · asset design sheet (design sheet) · style: Pixel art · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/pixel_art/transit.jpg` — style reference: the transit panel of this style's concept sheets
2. `refs/panels/pixel_art/street.jpg` — style reference: the street panel of this style's concept sheets
3. `refs/panels/pixel_art/build-mode.jpg` — style reference: the build-mode panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model or sprite will be built to
Primary request: a clean design sheet of one thing, the tram shelter, drawn as a finished game sprite in the style of the reference images
Input images: Image 1: style reference (the transit panel); Image 2: style reference (the street panel); Image 3: style reference (the build-mode panel). These are panels from the concept sheets of the Pixel art style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The tram shelter: a canopy about 4.5 m long, 2 m deep and 2.9 m high on slim posts, with a back screen, a bench inside, and one tall sign panel at one end. Open at the front, towards the track. The sign panel is blank: the game draws its content. In this style: A dark steel shelter with a lit strip under its roof. Character notes: Each stop's shelter was made in the guild hall and carried out in pieces. The bench inside is the same as the park benches.
Style/medium: detailed 16-bit-era pixel art game sprite: hard-edged square pixels on one consistent grid, a small fixed palette, dark navy outlines, selective dithering, no anti-aliasing and no blur
Composition/framing: landscape canvas, 1536 x 1024. Left two-thirds: the object large, as a game sprite seen from the game's fixed camera: an orthographic view looking down at 30 degrees with the object turned 45 degrees, the 2:1 dimetric view of classic isometric pixel games, the whole of it in frame with a clear margin. Right third, stacked: above, the same sprite turned to face the other way; below, its night version with whatever lights it has lit and everything else darkened towards navy. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: posts and frame, canopy, back screen, bench, sign panel. Every sprite pixel is one square block about 5 canvas pixels wide, and all blocks sit on one grid.
Lighting/mood: the sprite's own fixed light from the upper left, with flat tone steps
Color palette: a small fixed palette close to the pack's own, with a navy outline (#181C30) round every sprite; add a colour only where the object needs one: dark #2E2B2A and outline navy #181C30; wood #5C3A28 #8A5A3B; lamp #FFD26E #FFF0BE
Materials/textures: flat pixel clusters in two or three tones for each material, with selective dithering between tones; bricks, planks and leaves drawn as small pixel patterns
Constraints: one thing only, shown more than once as the same object with the same parts and colours; drawn in a few clear pixel clusters that still read at a sprite's small size; every screen, sign, board and plaque face is a plain blank surface; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, anti-aliasing, blur, gradients, mixed pixel sizes, 3D render look, more than about forty colours
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There is one thing only, whole in every view, and the views show the same object.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- Screens, signs, boards and plaque faces are blank.
- Pixels are hard-edged squares of one size, with no blur.

## Save

```sh
python3 tools/intake.py add pixel_art.A-tram-shelter PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/pixel_art/A-tram-shelter/rNNN/image.png` with its prompt and its record.
