# voxel.B-tex-wall-workshop

Wall workshop (texture) · surface (tiling texture) · style: Voxel · batch 02-city · canvas 1024 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/voxel/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/voxel/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: tileable game texture
Primary request: a seamless tileable texture of the guild hall's wall seen straight on, an area about 3 m across, with no windows or doors, as the reference images draw it
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel). These are panels from the concept sheets of the Voxel style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Subject: Bright yellow cubes on a grey stone base course.
Style/medium: a seamless tileable game texture, drawn the way the reference images draw surfaces: a grid of square cube faces, each one flat colour, with slight tone differences from cube to cube
Composition/framing: square canvas, 1024 x 1024, the material filling the whole canvas flat-on with no perspective
Lighting/mood: flat, even light with no shadows and no highlights
Color palette: a bright yellow workshop, an orange library vault, white and cobalt-glass towers, grey stone base courses
Constraints: seamless on all four edges, so that copies placed side by side show no join; even density with no single focal element; no objects, cast shadows, borders or vignette; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: perspective, objects, a darker or lighter centre, smooth or rounded surfaces, diagonal slopes, textures inside cube faces, ink outlines, tiny noisy cubes
```

## Before saving, look at the image

- The canvas is square.
- The material fills the canvas flat-on, with no objects, perspective or border.
- The left edge would meet the right edge, and the top the bottom, without a visible join.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add voxel.B-tex-wall-workshop PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/voxel/B-tex-wall-workshop/rNNN/image.png` with its prompt and its record.
