# voxel.A-tram-shelter

The tram shelter · asset design sheet (design sheet) · style: Voxel · batch 01a-square-props · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/voxel/transit.jpg` — style reference: the transit panel of this style's concept sheets
2. `refs/panels/voxel/street.jpg` — style reference: the street panel of this style's concept sheets
3. `refs/panels/voxel/build-mode.jpg` — style reference: the build-mode panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one thing, the tram shelter, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the transit panel); Image 2: style reference (the street panel); Image 3: style reference (the build-mode panel). These are panels from the concept sheets of the Voxel style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The tram shelter: a canopy about 4.5 m long, 2 m deep and 2.9 m high on slim posts, with a back screen, a bench inside, and one tall sign panel at one end. Open at the front, towards the track. The sign panel is blank: the game draws its content. In this style: The concept sheets do not show this closely, so design it to belong with what they do show, in this style's own materials: orange-brown timber cubes; dark grey cubes; grey stone cubes in two tones. Character notes: Each stop's shelter was made in the guild hall and carried out in pieces. The bench inside is the same as the park benches.
Style/medium: voxel 3D game model, seen as a clean render: forms built from cubes on one grid, with stepped edges where a curve would be; only the largest roofs (the workshop's sawtooth, the library's vault) are drawn smooth; no outlines
Composition/framing: landscape canvas, 1536 x 1024. Left two-thirds: one large three-quarter view from the front-right with the camera raised about 30 degrees, the whole of it in frame with a clear margin. Right third, stacked: a straight-on front elevation above, a straight-down plan view below. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: posts and frame, canopy, back screen, bench, sign panel.
Lighting/mood: bright even daylight from the upper left, soft shading between cubes, no coloured light, no hard cast shadows
Color palette: dark grey, #2E2F35 to #434249; orange-brown timber, #643511 in shade to #F7A544 in light; a warm yellow glow
Materials/textures: one flat saturated colour on each cube, with a slight tone difference from cube to cube and soft shading where cubes meet; no painted texture inside a cube face
Constraints: one thing only, shown more than once as the same object with the same parts and colours; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; every screen, sign, board and plaque face is a plain blank surface; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, smooth or rounded surfaces, diagonal slopes, textures inside cube faces, ink outlines, tiny noisy cubes
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There is one thing only, whole in every view, and the views show the same object.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- Screens, signs, boards and plaque faces are blank.

## Save

```sh
python3 tools/intake.py add voxel.A-tram-shelter PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/voxel/A-tram-shelter/rNNN/image.png` with its prompt and its record.
