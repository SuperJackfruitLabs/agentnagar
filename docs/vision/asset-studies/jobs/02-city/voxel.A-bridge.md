# voxel.A-bridge

The north bridge · asset design sheet (design sheet) · style: Voxel · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/voxel/park.jpg` — style reference: the park panel of this style's concept sheets
2. `refs/panels/voxel/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets
3. `refs/panels/voxel/rooftop.jpg` — style reference: the rooftop panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one thing, the north bridge, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the park panel); Image 2: style reference (the diagonal panel); Image 3: style reference (the rooftop panel). These are panels from the concept sheets of the Voxel style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The north bridge: one low stone bridge of three equal spans, each about 8 m long on piers about 1.5 m thick, with a deck about 4.3 m wide between railings, and beside it a length of quay wall about 2.5 m high. Low and level. No towers taller than a lamp post and no cables. In this style: Grey stone cubes with a flat deck and block piers. Character notes: The oldest structure after the tree. Its middle pier still carries the mark of the highest flood.
Style/medium: voxel 3D game model, seen as a clean render: forms built from cubes on one grid, with stepped edges where a curve would be; only the largest roofs (the workshop's sawtooth, the library's vault) are drawn smooth; no outlines
Composition/framing: landscape canvas, 1536 x 1024. Top two-thirds: one large three-quarter view from the front-right with the camera raised about 30 degrees, the whole of its length in frame. Bottom third: a straight-on side elevation running the width of the canvas. In the bottom right corner: a row of flat square colour swatches, one for each of these, in this order: stone, deck, railing, quay wall, water.
Lighting/mood: bright even daylight from the upper left, soft shading between cubes, no coloured light, no hard cast shadows
Color palette: grey stone, #635E64 to #9F979A; dark grey, #2E2F35 to #434249; saturated blue water
Materials/textures: one flat saturated colour on each cube, with a slight tone difference from cube to cube and soft shading where cubes meet; no painted texture inside a cube face
Constraints: one thing only, shown more than once as the same object with the same parts and colours; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, smooth or rounded surfaces, diagonal slopes, textures inside cube faces, ink outlines, tiny noisy cubes
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There is one thing only, whole in every view, and the views show the same object.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.

## Save

```sh
python3 tools/intake.py add voxel.A-bridge PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/voxel/A-bridge/rNNN/image.png` with its prompt and its record.
