# neutral.C-shrub-leafy

One loose leafy shrub, 1.1 m across and 1.2 m high, with a few stems showing and irregular leaf masses · shape for the image-to-3D model (shape) · style: No style (plain model) · batch 03-shapes · canvas 1024 x 1024

## Reference images

None. This job has no reference images.

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: single-object render, used as the input of an image-to-3D model
Primary request: a plain render of one loose leafy shrub, 1.1 m across and 1.2 m high, with a few stems showing and irregular leaf masses
Scene/backdrop: one flat light-grey backdrop (#D9D9D9), with no floor, no horizon and no shadow on it
Subject: One loose leafy shrub, 1.1 m across and 1.2 m high, with a few stems showing and irregular leaf masses.
Style/medium: a plain, clean 3D model render, like an untextured model in a viewer: matte surfaces, each part one flat colour (bark brown, leaves mid green, flowers a pale colour), simple solid forms with clear gaps between them
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

## Save

```sh
python3 tools/intake.py add neutral.C-shrub-leafy PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/neutral/C-shrub-leafy/rNNN/image.png` with its prompt and its record.
