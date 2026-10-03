# neon_noir.E-tower

A downtown tower (three stages) · life-cycle sheet (life-cycle sheet) · style: Neon noir · batch 04-life · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/neon_noir/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/neon_noir/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets
3. `sheets/neon_noir/A-towers/LATEST/image.png` — the design sheet of this object: the newest revision in `sheets/neon_noir/A-towers/` (the highest rNNN)

`LATEST` stands for the newest revision folder of that design sheet. If the sheet has no image yet, skip this job and say so: it cannot be made first.

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset life-cycle sheet: one asset at three stages
Primary request: a downtown tower at three stages of its life, side by side, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the diagonal panel). These are panels from the concept sheets of the Neon noir style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions. Image 3: the design sheet that shows a downtown tower. The second stage is that object exactly: the same design, parts, proportions and colours. Take nothing else from that sheet.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: One downtown tower about 11 m square and 25 m high, eight storeys, stepping back twice towards the top, with planted terraces on the steps and a small roof structure. In this style: Dark towers with warm lit windows, planted terraces and thin magenta lines of light on their edges. Three stages, left to right: 1. Being built: the structural frame up and part of the walls and roof in place, scaffolding along one side, materials stacked at its foot. 2. Newly finished. 3. After ten years of use: planting grown up its walls and on its terraces, an awning or canopy added, a few small repairs in a slightly different tone.
Style/medium: neon noir city design, drawn as a clean stylised 3D game model: dark charcoal and navy forms with slim lines of built-in light, softly shaded, no outlines
Composition/framing: landscape canvas, 1536 x 1024, divided into three equal columns with clear empty backdrop between them; one stage in each, in three-quarter view from the front-right with the camera raised about 30 degrees, the same viewpoint and the same size in all three.
Lighting/mood: neutral soft studio light from the upper left so that the true surface colours read, with the object's own lamps and light strips switched on and glowing; no night scene, no rain, no coloured light on the backdrop; every surface is drawn in its own colour, as neutral light shows it; lamps, lanterns and light strips are drawn switched on as small bright parts, but their light does not fall on the object, the ground or the backdrop: no glow on leaves, bark, walls or seats, no halo and no pool of light
Color palette: charcoal steel frames, ribbed cladding that reads tan to brown on the workshop's gables, dark navy roofs, pale stone on the library, glazing that glows amber (#FFB560); dark olive-green leaves, #171A12 in shade to #4A3D1F in light, and violet flowers
Materials/textures: matte dark metal and concrete, dark timber with a faint grain, glass that glows from behind, thin strips of warm or coloured light set into edges; wet stone only where a scene asks for it
Constraints: the same object in all three stages, with the same footprint, main form and viewpoint; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, people, three different designs, perspective distortion, depth of field, bloom, daylight scenes, dirt and decay, weapons, dystopian signage, heavy fog, lens flare over the object, photorealism, photographic materials and lighting
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are three stages in a row, of the same object from the same viewpoint.
- The backdrop is plain grey with no scenery (a soft gradient in the grey is fine).
- There is no readable text.
- The second stage is the object on its design sheet: the same design, not a new one.
- It is not a night scene: every surface shows its own colour, and only the lamps themselves are bright.

## Save

```sh
python3 tools/intake.py add neon_noir.E-tower PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/neon_noir/E-tower/rNNN/image.png` with its prompt and its record.
