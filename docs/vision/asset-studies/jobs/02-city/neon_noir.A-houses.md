# neon_noir.A-houses

The town houses · asset design sheet (design sheet) · style: Neon noir · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/neon_noir/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets
2. `refs/panels/neon_noir/rooftop.jpg` — style reference: the rooftop panel of this style's concept sheets
3. `refs/panels/neon_noir/street.jpg` — style reference: the street panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of three variants of one kind of building, the town houses, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the diagonal panel); Image 2: style reference (the rooftop panel); Image 3: style reference (the street panel). These are panels from the concept sheets of the Neon noir style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: Town houses for the city blocks: three variants of one house about 6.6 m wide, 8.2 m high and 9 m deep, two to three storeys, each with a ground-floor door, regular windows and a simple roof. Three separate buildings, alike in size and materials and different in roof, window rhythm and colour accent. In this style: Grey walls with a few lit windows under dark navy flat roofs; no neon (the neon lines are on the towers). Character notes: Their first occupants built them from one kit of parts, which is why they rhyme without matching.
Style/medium: neon noir city design, drawn as a clean stylised 3D game model: dark charcoal and navy forms with slim lines of built-in light, softly shaded, no outlines
Composition/framing: landscape canvas, 1536 x 1024, divided into three equal columns with clear empty backdrop between them. One object in each, centred, in three-quarter view from the front-right with the camera raised about 30 degrees, drawn as large as its cell allows. Every object stands well clear of its neighbours and of the canvas edge: no part or shadow of one reaches another. Under each object: a short row of flat square colour swatches, one for each of its main materials.
Lighting/mood: neutral soft studio light from the upper left so that the true surface colours read, with the object's own lamps and light strips switched on and glowing; no night scene, no rain, no coloured light on the backdrop; every surface is drawn in its own colour, as neutral light shows it; lamps, lanterns and light strips are drawn switched on as small bright parts, but their light does not fall on the object, the ground or the backdrop: no glow on leaves, bark, walls or seats, no halo and no pool of light
Color palette: charcoal steel frames, ribbed cladding that reads tan to brown on the workshop's gables, dark navy roofs, pale stone on the library, glazing that glows amber (#FFB560); amber, magenta and cyan light
Materials/textures: matte dark metal and concrete, dark timber with a faint grain, glass that glows from behind, thin strips of warm or coloured light set into edges; wet stone only where a scene asks for it
Constraints: three separate variants of one kind of building, alike in size and style; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, daylight scenes, dirt and decay, weapons, dystopian signage, heavy fog, lens flare over the object, photorealism, photographic materials and lighting
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There are exactly 3 objects, each whole and inside the canvas.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- It is not a night scene: every surface shows its own colour, and only the lamps themselves are bright.

## Save

```sh
python3 tools/intake.py add neon_noir.A-houses PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/neon_noir/A-houses/rNNN/image.png` with its prompt and its record.
