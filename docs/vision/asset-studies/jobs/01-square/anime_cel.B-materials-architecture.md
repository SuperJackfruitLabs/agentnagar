# anime_cel.B-materials-architecture

Building materials (board) · surface (material board) · style: Cel-shaded anime · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/anime_cel/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/anime_cel/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
3. `refs/panels/anime_cel/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: material sample board for a game's art direction
Primary request: six square samples of building materials, as the reference images draw them
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel); Image 3: style reference (the diagonal panel). These are panels from the concept sheets of the Cel-shaded anime style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: a flat mid-grey backdrop (#B8B8B8) that shows only as narrow gaps between the samples
Subject: six flat square tiles, each a straight-on sample of one material that fills its tile from edge to edge, at a scale where the tile is about 2 m across. In reading order: 1. The guild hall's wall: red brick with thin pale mortar lines. 2. The guild hall's roof: red-brown roof slopes like the brick, each with one long blue-grey skylight. 3. The library's wall: pale stone panels with thin joints. 4. The library's rounded roof: silver standing-seam metal curving over the vault. 5. The walls of houses and towers: red brick with thin mortar lines, or pale concrete. 6. Glazing: blue glass in dark slim frames.
Style/medium: flat material samples, drawn the way the reference images draw surfaces: flat colour fills with one hard-edged darker tone and a few thin ink lines
Composition/framing: landscape canvas, 1536 x 1024: three tiles across and two down, all the same size, with equal narrow gaps
Lighting/mood: flat, even light with no shadows and no highlights
Color palette: red brick, red-brown workshop roofs with long blue-grey skylights, silver metal on the library's vault, pale concrete and blue glass, warm white render
Constraints: each tile shows only its material, seen flat-on, with no objects, no perspective and no frame; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenes, objects, perspective, vignettes, photorealism, soft airbrushed gradients, heavy black outlines, chibi proportions, lens flare
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are six square tiles in three columns and two rows.
- Each tile is a flat-on sample of one material, with no objects or perspective.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add anime_cel.B-materials-architecture PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/B-materials-architecture/rNNN/image.png` with its prompt and its record.
