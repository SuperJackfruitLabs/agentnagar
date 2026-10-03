# lowpoly_tropical.E-tram-shelter

The tram shelter (three stages) · life-cycle sheet (life-cycle sheet) · style: Low-poly tropical · batch 04-life · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/lowpoly_tropical/transit.jpg` — style reference: the transit panel of this style's concept sheets
2. `refs/panels/lowpoly_tropical/street.jpg` — style reference: the street panel of this style's concept sheets
3. `sheets/lowpoly_tropical/A-tram-shelter/LATEST/image.png` — the design sheet of this object: the newest revision in `sheets/lowpoly_tropical/A-tram-shelter/` (the highest rNNN)

`LATEST` stands for the newest revision folder of that design sheet. If the sheet has no image yet, skip this job and say so: it cannot be made first.

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset life-cycle sheet: one asset at three stages
Primary request: the tram shelter at three stages of its life, side by side, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the transit panel); Image 2: style reference (the street panel). These are panels from the concept sheets of the Low-poly tropical style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions. Image 3: the design sheet that shows the tram shelter. The second stage is that object exactly: the same design, parts, proportions and colours. Take nothing else from that sheet.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The tram shelter: a canopy about 4.5 m long, 2 m deep and 2.9 m high on slim posts, with a back screen, a bench inside, and one tall sign panel at one end. In this style: The concept sheets do not show this closely, so design it to belong with what they do show, in this style's own materials: chunky warm-brown timber in broad boards; matte charcoal iron in simple square sections; pale warm stone in a few large blocks. Three stages, left to right: 1. Its parts laid out before assembly as a kit, every piece separate and flat on the ground. 2. New, just assembled. 3. After years of use: edges worn, one part replaced in a slightly different tone, one small neat repair.
Style/medium: stylised low-poly 3D game model, seen as a clean render: flat faceted planes on foliage, rocks, hair and cloth; buildings and furniture as smooth painted volumes with crisp chamfered edges; matte surfaces, no outlines
Composition/framing: landscape canvas, 1536 x 1024, divided into three equal columns with clear empty backdrop between them; one stage in each, in three-quarter view from the front-right with the camera raised about 30 degrees, the same viewpoint and the same size in all three.
Lighting/mood: soft even daylight from the upper left, as in a product render: every surface readable, gentle shading, no coloured light, no hard cast shadows
Color palette: charcoal iron, #2C282B to #4A4548; warm mid-brown timber, #613E2B in shade to #C78860 in light; warm yellow lantern light
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
python3 tools/intake.py add lowpoly_tropical.E-tram-shelter PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/lowpoly_tropical/E-tram-shelter/rNNN/image.png` with its prompt and its record.
