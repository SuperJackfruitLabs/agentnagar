# voxel.C-shrub-round

One low shrub built from cubes, 2 m across and 0.8 m high · shape for the image-to-3D model (shape) · style: Voxel · batch 03-shapes · canvas 1024 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/voxel/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/voxel/park.jpg` — style reference: the park panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: single-object render, used as the input of an image-to-3D model
Primary request: a plain render of one low shrub built from cubes, 2 m across and 0.8 m high
Input images: Image 1: style reference (the street panel); Image 2: style reference (the park panel). These are panels from the concept sheets of the Voxel style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one flat light-grey backdrop (#D9D9D9), with no floor, no horizon and no shadow on it
Subject: One low shrub built from cubes, 2 m across and 0.8 m high: a rounded heap of small leaf cubes.
Style/medium: a plain voxel model render: everything built only from cubes on one grid, matte, each cube one flat colour, with no smooth curves
Composition/framing: square canvas, 1024 x 1024. One object, centred and whole, with a clear margin on every side, in three-quarter view with the camera raised about 25 degrees so that the top of the object shows
Lighting/mood: soft even studio light from the upper front, with no cast shadows
Constraints: exactly one object; nothing cut off by the canvas edge; no ground plane, pot, base, people or scenery; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: painterly brushwork, outlines, depth of field, haze, backlight, transparency, fine noise
```

## Before saving, look at the image

- There is exactly one object, whole, centred, with margin on every side.
- The backdrop is one flat light grey with no floor or shadow.
- It looks like a plain 3D model, not a painting.
- The top of the object is visible.
- Everything is built from cubes.

## Save

```sh
python3 tools/intake.py add voxel.C-shrub-round PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/voxel/C-shrub-round/rNNN/image.png` with its prompt and its record.
