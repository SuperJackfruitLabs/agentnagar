# lowpoly_tropical.A-great-tree

The great tree · asset design sheet (design sheet) · style: Low-poly tropical · batch 00-pilot · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/lowpoly_tropical/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/lowpoly_tropical/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one thing, the great tree, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel). These are panels from the concept sheets of the Low-poly tropical style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The great tree at the centre of the tree square: one large living shade tree, about 12 m across and 9.5 m tall, with a thick buttressed trunk that forks low into heavy spreading limbs. It stands in a raised bed 5.2 m square whose low edge people sit on. Outside the 5.2 m bed nothing hangs lower than 2.2 m, because people walk under the crown. The crown is wide and fairly flat on top. A few small lanterns hang from the limbs. The crown is one closed mass of large, solid, rounded leaf clumps: full all round and on top, with no gaps through which the sky or the branches show, and no single leaves or twigs. In this style: A broad shade tree with a forked warm-brown trunk and a crown of faceted leaf clumps, olive in shade and yellow-green in light, with a few pale blossoms; a stone-edged bed full of broad-leaved plants and flowers; yellow lanterns. Character notes: It is older than every building round it, and the square was laid out to keep it. The lanterns were hung by the guild's makers.
Style/medium: stylised low-poly 3D game model, seen as a clean render: flat faceted planes on foliage, rocks, hair and cloth; buildings and furniture as smooth painted volumes with crisp chamfered edges; matte surfaces, no outlines
Composition/framing: landscape canvas, 1536 x 1024. Left two-thirds: one large three-quarter view from the front-right with the camera raised about 30 degrees, the whole of it in frame with a clear margin. Right third, stacked: a straight-on front elevation above, a straight-down plan view below. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: leaves in light, leaves in shade, bark, bed edge, lantern.
Lighting/mood: soft even daylight from the upper left, as in a product render: every surface readable, gentle shading, no coloured light, no hard cast shadows
Color palette: olive to yellow-green leaves (#233019, #586C27, #939B2D, #C5C44A) with pale and pink blossoms; warm brown bark, #45311F to #B38E62; pale warm stone, #817572 in shade to #E7CEB4 in light; warm yellow lantern light
Materials/textures: flat painted colour on each face with a soft gradient from light to shade; timber shows a few broad plank lines, stone a few large blocks, foliage is clumps of flat facets in three or four tones; no photographic texture, no noise
Constraints: one thing only, shown more than once as the same object with the same parts and colours; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, smooth realistic foliage, photographic textures, ink outlines, glossy plastic
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There is one thing only, whole in every view, and the views show the same object.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.

## Save

```sh
python3 tools/intake.py add lowpoly_tropical.A-great-tree PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/lowpoly_tropical/A-great-tree/rNNN/image.png` with its prompt and its record.
