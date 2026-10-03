# voxel.A-towers

The downtown towers · asset design sheet (design sheet) · style: Voxel · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/voxel/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/voxel/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets
3. `refs/panels/voxel/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of two variants of one kind of building, the downtown towers, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the diagonal panel); Image 3: style reference (the gathering panel). These are panels from the concept sheets of the Voxel style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: Downtown towers: two variants of a stepped tower about 11 to 14 m square and 25 to 29 m high, eight or nine storeys, stepping back twice towards the top, with planted terraces on the steps and a small roof structure. Two separate towers, alike in materials and different in how they step. Regular window rows. In this style: White and cobalt-glass cube towers with green roof gardens and an orange base course. Character notes: The first tall buildings in the city, built with terraces so that nobody would live without a garden.
Style/medium: voxel 3D game model, seen as a clean render: forms built from cubes on one grid, with stepped edges where a curve would be; only the largest roofs (the workshop's sawtooth, the library's vault) are drawn smooth; no outlines
Composition/framing: landscape canvas, 1536 x 1024, divided into two equal columns with clear empty backdrop between them. One object in each, centred, in three-quarter view from the front-right with the camera raised about 30 degrees, drawn as large as its cell allows. Every object stands well clear of its neighbours and of the canvas edge: no part or shadow of one reaches another. Under each object: a short row of flat square colour swatches, one for each of its main materials.
Lighting/mood: bright even daylight from the upper left, soft shading between cubes, no coloured light, no hard cast shadows
Color palette: a bright yellow workshop, an orange library vault, white and cobalt-glass towers, grey stone base courses; saturated greens (#18330B, #448114, #69A715, #A1D026) with white blossom cubes
Materials/textures: one flat saturated colour on each cube, with a slight tone difference from cube to cube and soft shading where cubes meet; no painted texture inside a cube face
Constraints: two separate variants of one kind of building, alike in size and style; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, smooth or rounded surfaces, diagonal slopes, textures inside cube faces, ink outlines, tiny noisy cubes
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There are exactly 2 objects, each whole and inside the canvas.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.

## Save

```sh
python3 tools/intake.py add voxel.A-towers PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/voxel/A-towers/rNNN/image.png` with its prompt and its record.
