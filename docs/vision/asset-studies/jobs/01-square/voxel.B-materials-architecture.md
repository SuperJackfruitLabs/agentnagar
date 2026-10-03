# voxel.B-materials-architecture

Building materials (board) · surface (material board) · style: Voxel · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/voxel/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/voxel/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
3. `refs/panels/voxel/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: material sample board for a game's art direction
Primary request: six square samples of building materials, as the reference images draw them
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel); Image 3: style reference (the diagonal panel). These are panels from the concept sheets of the Voxel style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: a flat mid-grey backdrop (#B8B8B8) that shows only as narrow gaps between the samples
Subject: six flat square tiles, each a straight-on sample of one material that fills its tile from edge to edge, at a scale where the tile is about 2 m across. In reading order: 1. The guild hall's wall: bright yellow cubes on a grey stone base course. 2. The guild hall's roof: flat parapet roofs, some with roof gardens or blue roof panels. 3. The library's wall: orange cubes with white trim cubes. 4. The library's rounded roof: an orange vault with white rounded end caps. 5. The walls of houses and towers: flat-coloured cube walls with a grey stone base course. 6. Glazing: cobalt-blue glass cubes with a lighter mullion grid.
Style/medium: flat material samples, drawn the way the reference images draw surfaces: a grid of square cube faces, each one flat colour, with slight tone differences from cube to cube
Composition/framing: landscape canvas, 1536 x 1024: three tiles across and two down, all the same size, with equal narrow gaps
Lighting/mood: flat, even light with no shadows and no highlights
Color palette: a bright yellow workshop, an orange library vault, white and cobalt-glass towers, grey stone base courses
Constraints: each tile shows only its material, seen flat-on, with no objects, no perspective and no frame; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenes, objects, perspective, vignettes, smooth or rounded surfaces, diagonal slopes, textures inside cube faces, ink outlines, tiny noisy cubes
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are six square tiles in three columns and two rows.
- Each tile is a flat-on sample of one material, with no objects or perspective.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add voxel.B-materials-architecture PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/voxel/B-materials-architecture/rNNN/image.png` with its prompt and its record.
