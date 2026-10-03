# lowpoly_tropical.B-materials-ground

Ground and nature materials (board) · surface (material board) · style: Low-poly tropical · batch 00-pilot · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/lowpoly_tropical/topdown.jpg` — style reference: the topdown panel of this style's concept sheets
2. `refs/panels/lowpoly_tropical/park.jpg` — style reference: the park panel of this style's concept sheets
3. `refs/panels/lowpoly_tropical/street.jpg` — style reference: the street panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: material sample board for a game's art direction
Primary request: six square samples of ground and nature materials, as the reference images draw them
Input images: Image 1: style reference (the topdown panel); Image 2: style reference (the park panel); Image 3: style reference (the street panel). These are panels from the concept sheets of the Low-poly tropical style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: a flat mid-grey backdrop (#B8B8B8) that shows only as narrow gaps between the samples
Subject: six flat square tiles, each a straight-on sample of one material that fills its tile from edge to edge, at a scale where the tile is about 2 m across. In reading order: 1. The square's paving: warm cream square slabs, each a slightly different tone. 2. A park path: a sand-coloured compacted path with a few larger pavers. 3. The street: plain warm-grey asphalt. 4. Lawn: soft yellow-green grass in broad flat patches of two tones. 5. The river's surface: teal water with a few lighter flat facets. 6. Timber, as benches and decks use it: chunky warm-brown timber in broad boards.
Style/medium: flat material samples, drawn the way the reference images draw surfaces: flat painted colour with soft gradients and a few broad lines; no photographic texture and no noise
Composition/framing: landscape canvas, 1536 x 1024: three tiles across and two down, all the same size, with equal narrow gaps
Lighting/mood: flat, even light with no shadows and no highlights
Color palette: warm cream paving, soft yellow-green lawn, warm grey street; teal water; warm mid-brown timber, #613E2B in shade to #C78860 in light
Constraints: each tile shows only its material, seen flat-on, with no objects, no perspective and no frame; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenes, objects, perspective, vignettes, smooth realistic foliage, photographic textures, ink outlines, glossy plastic
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are six square tiles in three columns and two rows.
- Each tile is a flat-on sample of one material, with no objects or perspective.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add lowpoly_tropical.B-materials-ground PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/lowpoly_tropical/B-materials-ground/rNNN/image.png` with its prompt and its record.
