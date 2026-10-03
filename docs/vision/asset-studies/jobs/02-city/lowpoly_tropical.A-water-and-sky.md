# lowpoly_tropical.A-water-and-sky

sailing boat, cloud, small cloud · asset design sheet (design sheet) · style: Low-poly tropical · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/lowpoly_tropical/park.jpg` — style reference: the park panel of this style's concept sheets
2. `refs/panels/lowpoly_tropical/rooftop.jpg` — style reference: the rooftop panel of this style's concept sheets
3. `refs/panels/lowpoly_tropical/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of 3 separate things, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the park panel); Image 2: style reference (the rooftop panel); Image 3: style reference (the diagonal panel). These are panels from the concept sheets of the Low-poly tropical style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: 3 separate objects, in reading order. 1. A small sailing boat: hull about 5 m long, mast 6.8 m, with one or two sails. In this style: A white triangular sail with one yellow panel over a red or brown hull. 2. A cloud about 10 m long with a flat base. In this style: A faceted white cloud. 3. A smaller cloud about 8 m long with a flat base. Where a note above does not say how this style draws an object, use the style's own materials: teal water with a few lighter flat facets.
Style/medium: stylised low-poly 3D game model, seen as a clean render: flat faceted planes on foliage, rocks, hair and cloth; buildings and furniture as smooth painted volumes with crisp chamfered edges; matte surfaces, no outlines
Composition/framing: landscape canvas, 1536 x 1024, divided into three equal columns with clear empty backdrop between them. One object in each, centred, in three-quarter view from the front-right with the camera raised about 30 degrees, drawn as large as its cell allows. Every object stands well clear of its neighbours and of the canvas edge: no part or shadow of one reaches another. Under each object: a short row of flat square colour swatches, one for each of its main materials.
Lighting/mood: soft even daylight from the upper left, as in a product render: every surface readable, gentle shading, no coloured light, no hard cast shadows
Color palette: teal water; jackfruit yellow for awnings, banners and umbrellas
Materials/textures: flat painted colour on each face with a soft gradient from light to shade; timber shows a few broad plank lines, stone a few large blocks, foliage is clumps of flat facets in three or four tones; no photographic texture, no noise
Constraints: exactly 3 objects, each whole, inside its own cell and touching nothing; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, smooth realistic foliage, photographic textures, ink outlines, glossy plastic
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There are exactly 3 objects, each whole and inside the canvas.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.

## Save

```sh
python3 tools/intake.py add lowpoly_tropical.A-water-and-sky PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/lowpoly_tropical/A-water-and-sky/rNNN/image.png` with its prompt and its record.
