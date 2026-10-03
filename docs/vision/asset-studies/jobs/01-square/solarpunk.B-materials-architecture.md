# solarpunk.B-materials-architecture

Building materials (board) · surface (material board) · style: Solarpunk retro-futurism · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/solarpunk/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/solarpunk/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
3. `refs/panels/solarpunk/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: material sample board for a game's art direction
Primary request: six square samples of building materials, as the reference images draw them
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel); Image 3: style reference (the diagonal panel). These are panels from the concept sheets of the Solarpunk retro-futurism style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: a flat mid-grey backdrop (#B8B8B8) that shows only as narrow gaps between the samples
Subject: six flat square tiles, each a straight-on sample of one material that fills its tile from edge to edge, at a scale where the tile is about 2 m across. In reading order: 1. The guild hall's wall: blonde vertical timber slats. 2. The guild hall's roof: blue solar panels in a pale frame, or a planted roof. 3. The library's wall: cream ceramic panels with fine joints. 4. The library's rounded roof: blue solar glass in a pale grid. 5. The walls of houses and towers: cream ceramic panels or blonde timber slat cladding. 6. Glazing: clear turquoise-tinted glass in slim frames.
Style/medium: flat material samples, drawn the way the reference images draw surfaces: a softly painted surface with fine, even grain; not photographic
Composition/framing: landscape canvas, 1536 x 1024: three tiles across and two down, all the same size, with equal narrow gaps
Lighting/mood: flat, even light with no shadows and no highlights
Color palette: cream ceramic, blonde timber slats, blue solar panels, brass trim, planted roofs
Constraints: each tile shows only its material, seen flat-on, with no objects, no perspective and no frame; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenes, objects, perspective, vignettes, photorealism, heavy machinery, rust and grime, dystopian detail, ink outlines
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are six square tiles in three columns and two rows.
- Each tile is a flat-on sample of one material, with no objects or perspective.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add solarpunk.B-materials-architecture PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/solarpunk/B-materials-architecture/rNNN/image.png` with its prompt and its record.
