# anime_cel.B-tex-bark

Trunk (texture) · surface (tiling texture) · style: Cel-shaded anime · batch 02-city · canvas 1024 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/anime_cel/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/anime_cel/park.jpg` — style reference: the park panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: tileable game texture
Primary request: a seamless tileable texture of tree bark seen straight on, an area about 1 m across, grain running bottom to top, as the reference images draw it
Input images: Image 1: style reference (the street panel); Image 2: style reference (the park panel). These are panels from the concept sheets of the Cel-shaded anime style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Subject: Grey-brown trunk with a clear shadow side.
Style/medium: a seamless tileable game texture, drawn the way the reference images draw surfaces: flat colour fills with one hard-edged darker tone and a few thin ink lines
Composition/framing: square canvas, 1024 x 1024, the material filling the whole canvas flat-on with no perspective
Lighting/mood: flat, even light with no shadows and no highlights
Color palette: grey-brown bark, #423934 to #8E7C66
Constraints: seamless on all four edges, so that copies placed side by side show no join; even density with no single focal element; no objects, cast shadows, borders or vignette; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: perspective, objects, a darker or lighter centre, photorealism, soft airbrushed gradients, heavy black outlines, chibi proportions, lens flare
```

## Before saving, look at the image

- The canvas is square.
- The material fills the canvas flat-on, with no objects, perspective or border.
- The left edge would meet the right edge, and the top the bottom, without a visible join.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add anime_cel.B-tex-bark PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/B-tex-bark/rNNN/image.png` with its prompt and its record.
