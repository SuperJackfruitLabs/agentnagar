# neon_noir.A-great-tree

The great tree · asset design sheet (design sheet) · style: Neon noir · batch 00b-pilot-rest · canvas 1536 x 1024

## Asked for again

This job has an image already and is to be made again: its first image (r001) is a night scene lit by the tree's own lamps, so its colours could not be used; the job now asks for neutral light and for lamps that throw no light on the tree. The new image becomes the next revision.

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/neon_noir/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/neon_noir/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one thing, the great tree, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel). These are panels from the concept sheets of the Neon noir style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The great tree at the centre of the tree square: one large living shade tree, about 12 m across and 9.5 m tall, with a thick buttressed trunk that forks low into heavy spreading limbs. It stands in a raised bed 5.2 m square whose low edge people sit on. Outside the 5.2 m bed nothing hangs lower than 2.2 m, because people walk under the crown. The crown is wide and fairly flat on top. A few small lanterns hang from the limbs. The crown is one closed mass of large, solid, rounded leaf clumps: full all round and on top, with no gaps through which the sky or the branches show, and no single leaves or twigs. In this style: A broad dark-leaved tree with a thick trunk and clusters of violet flowers; strings of small warm lights through the crown and a few hanging lanterns; a dark concrete bed edge with a warm light strip under its rim. Character notes: It is older than every building round it, and the square was laid out to keep it. The lanterns were hung by the guild's makers.
Style/medium: neon noir city design, drawn as a clean stylised 3D game model: dark charcoal and navy forms with slim lines of built-in light, softly shaded, no outlines
Composition/framing: landscape canvas, 1536 x 1024. Left two-thirds: one large three-quarter view from the front-right with the camera raised about 30 degrees, the whole of it in frame with a clear margin. Right third, stacked: a straight-on front elevation above, a straight-down plan view below. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: leaves in light, leaves in shade, bark, bed edge, lantern.
Lighting/mood: neutral soft studio light from the upper left so that the true surface colours read, with the object's own lamps and light strips switched on and glowing; no night scene, no rain, no coloured light on the backdrop; every surface is drawn in its own colour, as neutral light shows it; lamps, lanterns and light strips are drawn switched on as small bright parts, but their light does not fall on the object, the ground or the backdrop: no glow on leaves, bark, walls or seats, no halo and no pool of light
Color palette: dark olive-green leaves, #171A12 in shade to #4A3D1F in light, and violet flowers; dark brown bark, #251303 to #52300D; dark concrete, #2F2322 to #5C4A45; warm amber light (#FFB560), with thin violet-magenta (about #B030C0) and cyan (#3FE3FF) lines
Materials/textures: matte dark metal and concrete, dark timber with a faint grain, glass that glows from behind, thin strips of warm or coloured light set into edges; wet stone only where a scene asks for it
Constraints: one thing only, shown more than once as the same object with the same parts and colours; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, daylight scenes, dirt and decay, weapons, dystopian signage, heavy fog, lens flare over the object, photorealism, photographic materials and lighting
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There is one thing only, whole in every view, and the views show the same object.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- It is not a night scene: every surface shows its own colour, and only the lamps themselves are bright.

## Save

```sh
python3 tools/intake.py add neon_noir.A-great-tree PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/neon_noir/A-great-tree/rNNN/image.png` with its prompt and its record.
