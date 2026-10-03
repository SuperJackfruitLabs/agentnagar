# neon_noir.A-seating

park bench, café chair, reading chair, perch seat · asset design sheet (design sheet) · style: Neon noir · batch 01b-redo · canvas 1536 x 1024

## Asked for again

This job has an image already and is to be made again: its first image (r001) drew the perch seat as a stool with legs; the job now describes it as the game uses it, a plain seat stone with a board on top. Only the perch seat of the new image will be used: the other three seats are built from r001. The new image becomes the next revision.

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/neon_noir/park.jpg` — style reference: the park panel of this style's concept sheets
2. `refs/panels/neon_noir/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
3. `refs/panels/neon_noir/home.jpg` — style reference: the home panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of 4 separate things, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the park panel); Image 2: style reference (the gathering panel); Image 3: style reference (the home panel). These are panels from the concept sheets of the Neon noir style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: 4 separate objects, in reading order. 1. A park bench for two: 1.6 m long, 0.6 m deep, seat 45 cm high, back to 85 cm. In this style: Dark timber slats on dark metal with a short warm light bar under the back rail. 2. A café chair: 46 cm wide, 50 cm deep, seat 45 cm high, back to 90 cm. 3. A reading armchair: 85 cm wide and deep, 95 cm high, low and upholstered. 4. A perch seat: a plain seat stone 30 cm by 55 cm and 46 cm high with a timber board on top. The game draws one at every place someone can sit on a wall, a step or inside a shelter, so it usually stands in or against the thing it belongs to. A plain block with a seat board. Not a stool: no legs, no frame, no back. Where a note above does not say how this style draws an object, use the style's own materials: dark timber slats on dark metal; matte charcoal steel in slim sections; dark concrete with a thin warm light strip set into its edge.
Style/medium: neon noir city design, drawn as a clean stylised 3D game model: dark charcoal and navy forms with slim lines of built-in light, softly shaded, no outlines
Composition/framing: landscape canvas, 1536 x 1024, divided into four equal cells, two across and two down with clear empty backdrop between them. One object in each, centred, in three-quarter view from the front-right with the camera raised about 30 degrees, drawn as large as its cell allows. Every object stands well clear of its neighbours and of the canvas edge: no part or shadow of one reaches another. Under each object: a short row of flat square colour swatches, one for each of its main materials.
Lighting/mood: neutral soft studio light from the upper left so that the true surface colours read, with the object's own lamps and light strips switched on and glowing; no night scene, no rain, no coloured light on the backdrop; every surface is drawn in its own colour, as neutral light shows it; lamps, lanterns and light strips are drawn switched on as small bright parts, but their light does not fall on the object, the ground or the backdrop: no glow on leaves, bark, walls or seats, no halo and no pool of light
Color palette: dark timber, #1B100D to #846058; matte charcoal and black; dark concrete, #2F2322 to #5C4A45
Materials/textures: matte dark metal and concrete, dark timber with a faint grain, glass that glows from behind, thin strips of warm or coloured light set into edges; wet stone only where a scene asks for it
Constraints: exactly 4 objects, each whole, inside its own cell and touching nothing; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, daylight scenes, dirt and decay, weapons, dystopian signage, heavy fog, lens flare over the object, photorealism, photographic materials and lighting
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There are exactly 4 objects, each whole and inside the canvas.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- It is not a night scene: every surface shows its own colour, and only the lamps themselves are bright.

## Save

```sh
python3 tools/intake.py add neon_noir.A-seating PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/neon_noir/A-seating/rNNN/image.png` with its prompt and its record.
