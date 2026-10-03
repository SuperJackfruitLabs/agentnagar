# lowpoly_tropical.E-tower

A downtown tower (three stages) · life-cycle sheet (life-cycle sheet) · style: Low-poly tropical · batch 04-life · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/lowpoly_tropical/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/lowpoly_tropical/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets
3. `sheets/lowpoly_tropical/A-towers/LATEST/image.png` — the design sheet of this object: the newest revision in `sheets/lowpoly_tropical/A-towers/` (the highest rNNN)

`LATEST` stands for the newest revision folder of that design sheet. If the sheet has no image yet, skip this job and say so: it cannot be made first.

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset life-cycle sheet: one asset at three stages
Primary request: a downtown tower at three stages of its life, side by side, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the diagonal panel). These are panels from the concept sheets of the Low-poly tropical style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions. Image 3: the design sheet that shows a downtown tower. The second stage is that object exactly: the same design, parts, proportions and colours. Take nothing else from that sheet.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: One downtown tower about 11 m square and 25 m high, eight storeys, stepping back twice towards the top, with planted terraces on the steps and a small roof structure. In this style: Cream towers with regular dark windows and flat roofs carrying a small gold finial or a few roof plants. Three stages, left to right: 1. Being built: the structural frame up and part of the walls and roof in place, scaffolding along one side, materials stacked at its foot. 2. Newly finished. 3. After ten years of use: planting grown up its walls and on its terraces, an awning or canopy added, a few small repairs in a slightly different tone.
Style/medium: stylised low-poly 3D game model, seen as a clean render: flat faceted planes on foliage, rocks, hair and cloth; buildings and furniture as smooth painted volumes with crisp chamfered edges; matte surfaces, no outlines
Composition/framing: landscape canvas, 1536 x 1024, divided into three equal columns with clear empty backdrop between them; one stage in each, in three-quarter view from the front-right with the camera raised about 30 degrees, the same viewpoint and the same size in all three.
Lighting/mood: soft even daylight from the upper left, as in a product render: every surface readable, gentle shading, no coloured light, no hard cast shadows
Color palette: limewash cream and sandstone walls, terracotta roofs, green copper domes; olive to yellow-green leaves (#233019, #586C27, #939B2D, #C5C44A) with pale and pink blossoms
Materials/textures: flat painted colour on each face with a soft gradient from light to shade; timber shows a few broad plank lines, stone a few large blocks, foliage is clumps of flat facets in three or four tones; no photographic texture, no noise
Constraints: the same object in all three stages, with the same footprint, main form and viewpoint; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, people, three different designs, perspective distortion, depth of field, bloom, smooth realistic foliage, photographic textures, ink outlines, glossy plastic
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are three stages in a row, of the same object from the same viewpoint.
- The backdrop is plain grey with no scenery (a soft gradient in the grey is fine).
- There is no readable text.
- The second stage is the object on its design sheet: the same design, not a new one.

## Save

```sh
python3 tools/intake.py add lowpoly_tropical.E-tower PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/lowpoly_tropical/E-tower/rNNN/image.png` with its prompt and its record.
