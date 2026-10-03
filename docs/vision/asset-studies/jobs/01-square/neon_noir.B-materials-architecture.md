# neon_noir.B-materials-architecture

Building materials (board) · surface (material board) · style: Neon noir · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/neon_noir/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/neon_noir/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
3. `refs/panels/neon_noir/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: material sample board for a game's art direction
Primary request: six square samples of building materials, as the reference images draw them
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel); Image 3: style reference (the diagonal panel). These are panels from the concept sheets of the Neon noir style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: a flat mid-grey backdrop (#B8B8B8) that shows only as narrow gaps between the samples
Subject: six flat square tiles, each a straight-on sample of one material that fills its tile from edge to edge, at a scale where the tile is about 2 m across. In reading order: 1. The guild hall's wall: vertical ribbed cladding, tan to brown and lighter than the dark steel frame round it. 2. The guild hall's roof: dark navy panels. 3. The library's wall: pale smooth stone. 4. The library's rounded roof: dark blue glass in a fine grid. 5. The walls of houses and towers: charcoal steel frames with tall glazing that glows amber. 6. Glazing: glass glowing amber from inside, or dark blue glass.
Style/medium: flat material samples, drawn the way the reference images draw surfaces: a matte dark surface with faint grain and a slight sheen
Composition/framing: landscape canvas, 1536 x 1024: three tiles across and two down, all the same size, with equal narrow gaps
Lighting/mood: flat, even light with no shadows and no highlights
Color palette: charcoal steel frames, ribbed cladding that reads tan to brown on the workshop's gables, dark navy roofs, pale stone on the library, glazing that glows amber (#FFB560)
Constraints: each tile shows only its material, seen flat-on, with no objects, no perspective and no frame; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenes, objects, perspective, vignettes, daylight scenes, dirt and decay, weapons, dystopian signage, heavy fog, lens flare over the object, photorealism, photographic materials and lighting
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are six square tiles in three columns and two rows.
- Each tile is a flat-on sample of one material, with no objects or perspective.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add neon_noir.B-materials-architecture PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/neon_noir/B-materials-architecture/rNNN/image.png` with its prompt and its record.
