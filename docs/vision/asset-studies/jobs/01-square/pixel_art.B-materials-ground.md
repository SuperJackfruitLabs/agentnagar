# pixel_art.B-materials-ground

Ground and nature materials (board) · surface (material board) · style: Pixel art · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/pixel_art/topdown.jpg` — style reference: the topdown panel of this style's concept sheets
2. `refs/panels/pixel_art/park.jpg` — style reference: the park panel of this style's concept sheets
3. `refs/panels/pixel_art/street.jpg` — style reference: the street panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: material sample board for a game's art direction
Primary request: six square samples of ground and nature materials, as the reference images draw them
Input images: Image 1: style reference (the topdown panel); Image 2: style reference (the park panel); Image 3: style reference (the street panel). These are panels from the concept sheets of the Pixel art style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: a flat mid-grey backdrop (#B8B8B8) that shows only as narrow gaps between the samples
Subject: six flat square tiles, each a straight-on sample of one material that fills its tile from edge to edge, at a scale where the tile is about 2 m across. In reading order: 1. The square's paving: beige and pink paving bricks. 2. A park path: beige path tiles. 3. The street: grey-blue asphalt. 4. Lawn: bright green grass with small darker tufts. 5. The river's surface: blue water with lighter ripple pixels. 6. Timber, as benches and decks use it: brown plank pixels in two tones with dark gaps.
Style/medium: flat material samples, drawn the way the reference images draw surfaces: hard-edged pixels on one grid in two or three tones with selective dithering, every pixel a square block about 5 canvas pixels wide
Composition/framing: landscape canvas, 1536 x 1024: three tiles across and two down, all the same size, with equal narrow gaps
Lighting/mood: flat, even light with no shadows and no highlights
Color palette: a small fixed palette close to the pack's own, with a navy outline (#181C30) round every sprite; add a colour only where the object needs one: sand #DEC496 #F0E0BE paving, the leaf greens for lawn, grey #787882 street; water #1E4678 #326EAA #78B4DC; wood #5C3A28 #8A5A3B
Constraints: each tile shows only its material, seen flat-on, with no objects, no perspective and no frame; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenes, objects, perspective, vignettes, anti-aliasing, blur, gradients, mixed pixel sizes, 3D render look, more than about forty colours
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are six square tiles in three columns and two rows.
- Each tile is a flat-on sample of one material, with no objects or perspective.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add pixel_art.B-materials-ground PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/pixel_art/B-materials-ground/rNNN/image.png` with its prompt and its record.
