# anime_cel.B-materials-ground

Ground and nature materials (board) · surface (material board) · style: Cel-shaded anime · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/anime_cel/topdown.jpg` — style reference: the topdown panel of this style's concept sheets
2. `refs/panels/anime_cel/park.jpg` — style reference: the park panel of this style's concept sheets
3. `refs/panels/anime_cel/street.jpg` — style reference: the street panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: material sample board for a game's art direction
Primary request: six square samples of ground and nature materials, as the reference images draw them
Input images: Image 1: style reference (the topdown panel); Image 2: style reference (the park panel); Image 3: style reference (the street panel). These are panels from the concept sheets of the Cel-shaded anime style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: a flat mid-grey backdrop (#B8B8B8) that shows only as narrow gaps between the samples
Subject: six flat square tiles, each a straight-on sample of one material that fills its tile from edge to edge, at a scale where the tile is about 2 m across. In reading order: 1. The square's paving: pale beige stone slabs with thin joints. 2. A park path: a pale gravel path. 3. The street: blue-grey asphalt. 4. Lawn: fresh green grass with small tufts drawn as short strokes. 5. The river's surface: deep blue water with white sparkle strokes. 6. Timber, as benches and decks use it: broad timber planks from dark brown to honey.
Style/medium: flat material samples, drawn the way the reference images draw surfaces: flat colour fills with one hard-edged darker tone and a few thin ink lines
Composition/framing: landscape canvas, 1536 x 1024: three tiles across and two down, all the same size, with equal narrow gaps
Lighting/mood: flat, even light with no shadows and no highlights
Color palette: pale beige paving, fresh green lawn, blue-grey street; deep blue water with white sparkles; timber from #3F312A in shade to #EABE8E in light
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
python3 tools/intake.py add anime_cel.B-materials-ground PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/B-materials-ground/rNNN/image.png` with its prompt and its record.
