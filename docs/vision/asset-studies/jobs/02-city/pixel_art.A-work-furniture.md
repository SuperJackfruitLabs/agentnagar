# pixel_art.A-work-furniture

desk with stool, workstation, workbench, bookshelf, pegboard, pendant lamp · asset design sheet (design sheet) · style: Pixel art · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/pixel_art/workshop.jpg` — style reference: the workshop panel of this style's concept sheets
2. `refs/panels/pixel_art/facility.jpg` — style reference: the facility panel of this style's concept sheets
3. `refs/panels/pixel_art/home.jpg` — style reference: the home panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model or sprite will be built to
Primary request: a clean design sheet of 6 separate things, each drawn as a finished game sprite in the style of the reference images
Input images: Image 1: style reference (the workshop panel); Image 2: style reference (the facility panel); Image 3: style reference (the home panel). These are panels from the concept sheets of the Pixel art style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: 6 separate objects, in reading order. 1. A workshop desk with a stool: the desk 1.3 m wide, 70 cm deep and 75 cm high. 2. A workstation: the same desk carrying a computer with one screen. The screen is blank: the game draws its content. 3. A long workbench: 3.2 m long, 1 m deep and 90 cm high, with a heavy top and a lower shelf. 4. A bookshelf: 2 m wide, 2.6 m high and 45 cm deep, with five shelves of books. Book spines are plain colours with no lettering. 5. A pegboard wall panel 2 m wide and 1.2 m high with hand tools hung in rows. 6. A pendant lamp: a metal shade about 45 cm across hanging on a cord. Where a note above does not say how this style draws an object, use the style's own materials: brown plank pixels in two tones with dark gaps; dark navy and black frame pixels; amber lantern pixels in a black frame.
Style/medium: detailed 16-bit-era pixel art game sprite: hard-edged square pixels on one consistent grid, a small fixed palette, dark navy outlines, selective dithering, no anti-aliasing and no blur
Composition/framing: landscape canvas, 1536 x 1024, divided into six equal cells, three across and two down with clear empty backdrop between them. One object in each, centred, as a game sprite seen from the game's fixed camera: an orthographic view looking down at 30 degrees with the object turned 45 degrees, the 2:1 dimetric view of classic isometric pixel games, drawn as large as its cell allows. Every object stands well clear of its neighbours and of the canvas edge: no part or shadow of one reaches another. Under each object: a short row of flat square colour swatches, one for each of its main materials. Every sprite pixel is one square block about 5 canvas pixels wide, and all blocks sit on one grid.
Lighting/mood: the sprite's own fixed light from the upper left, with flat tone steps
Color palette: a small fixed palette close to the pack's own, with a navy outline (#181C30) round every sprite; add a colour only where the object needs one: wood #5C3A28 #8A5A3B; dark #2E2B2A and outline navy #181C30; lamp #FFD26E #FFF0BE
Materials/textures: flat pixel clusters in two or three tones for each material, with selective dithering between tones; bricks, planks and leaves drawn as small pixel patterns
Constraints: exactly 6 objects, each whole, inside its own cell and touching nothing; drawn in a few clear pixel clusters that still read at a sprite's small size; every screen, sign, board and plaque face is a plain blank surface; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, anti-aliasing, blur, gradients, mixed pixel sizes, 3D render look, more than about forty colours
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There are exactly 6 objects, each whole and inside the canvas.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- Screens, signs, boards and plaque faces are blank.
- Pixels are hard-edged squares of one size, with no blur.

## Save

```sh
python3 tools/intake.py add pixel_art.A-work-furniture PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/pixel_art/A-work-furniture/rNNN/image.png` with its prompt and its record.
