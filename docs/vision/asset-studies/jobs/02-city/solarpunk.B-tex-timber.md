# solarpunk.B-tex-timber

Timber (texture) · surface (tiling texture) · style: Solarpunk retro-futurism · batch 02-city · canvas 1024 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/solarpunk/park.jpg` — style reference: the park panel of this style's concept sheets
2. `refs/panels/solarpunk/workshop.jpg` — style reference: the workshop panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: tileable game texture
Primary request: a seamless tileable texture of timber boards seen straight on, an area about 1.5 m across, boards running left to right, as the reference images draw it
Input images: Image 1: style reference (the park panel); Image 2: style reference (the workshop panel). These are panels from the concept sheets of the Solarpunk retro-futurism style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Subject: Blonde timber slats with solid timber ends.
Style/medium: a seamless tileable game texture, drawn the way the reference images draw surfaces: a softly painted surface with fine, even grain; not photographic
Composition/framing: square canvas, 1024 x 1024, the material filling the whole canvas flat-on with no perspective
Lighting/mood: flat, even light with no shadows and no highlights
Color palette: timber from #70482E in shade to #FACC97 in light
Constraints: seamless on all four edges, so that copies placed side by side show no join; even density with no single focal element; no objects, cast shadows, borders or vignette; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: perspective, objects, a darker or lighter centre, photorealism, heavy machinery, rust and grime, dystopian detail, ink outlines
```

## Before saving, look at the image

- The canvas is square.
- The material fills the canvas flat-on, with no objects, perspective or border.
- The left edge would meet the right edge, and the top the bottom, without a visible join.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add solarpunk.B-tex-timber PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/solarpunk/B-tex-timber/rNNN/image.png` with its prompt and its record.
