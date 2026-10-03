# anime_cel.A-work-furniture

desk with stool, workstation, workbench, bookshelf, pegboard, pendant lamp · asset design sheet (design sheet) · style: Cel-shaded anime · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/anime_cel/workshop.jpg` — style reference: the workshop panel of this style's concept sheets
2. `refs/panels/anime_cel/facility.jpg` — style reference: the facility panel of this style's concept sheets
3. `refs/panels/anime_cel/home.jpg` — style reference: the home panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of 6 separate things, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the workshop panel); Image 2: style reference (the facility panel); Image 3: style reference (the home panel). These are panels from the concept sheets of the Cel-shaded anime style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: 6 separate objects, in reading order. 1. A workshop desk with a stool: the desk 1.3 m wide, 70 cm deep and 75 cm high. 2. A workstation: the same desk carrying a computer with one screen. The screen is blank: the game draws its content. 3. A long workbench: 3.2 m long, 1 m deep and 90 cm high, with a heavy top and a lower shelf. 4. A bookshelf: 2 m wide, 2.6 m high and 45 cm deep, with five shelves of books. Book spines are plain colours with no lettering. 5. A pegboard wall panel 2 m wide and 1.2 m high with hand tools hung in rows. 6. A pendant lamp: a metal shade about 45 cm across hanging on a cord. Where a note above does not say how this style draws an object, use the style's own materials: broad timber planks from dark brown to honey; near-black iron in slim bars; warm cream lantern glass in a black frame.
Style/medium: cel-shaded anime background art, drawn as a clean toon-shaded 3D game model: flat colour fills, two steps of cool lavender-grey shadow, thin dark ink lines on silhouettes and main edges
Composition/framing: landscape canvas, 1536 x 1024, divided into six equal cells, three across and two down with clear empty backdrop between them. One object in each, centred, in three-quarter view from the front-right with the camera raised about 30 degrees, drawn as large as its cell allows. Every object stands well clear of its neighbours and of the canvas edge: no part or shadow of one reaches another. Under each object: a short row of flat square colour swatches, one for each of its main materials.
Lighting/mood: clear even daylight from the upper left; each surface keeps one flat colour, with a single darker step only on the faces turned away from the light; no shadow shapes or streaks painted across a flat face, no coloured light, no long cast shadows
Color palette: timber from #3F312A in shade to #EABE8E in light; near-black iron, #25242B to #6E696C; warm cream lamp light
Materials/textures: flat fills with a hard-edged shadow step and small painted highlights; brick, planks and paving joints drawn as a few thin lines; foliage as layered clusters of small leaf shapes
Constraints: exactly 6 objects, each whole, inside its own cell and touching nothing; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; every screen, sign, board and plaque face is a plain blank surface; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, photorealism, soft airbrushed gradients, heavy black outlines, chibi proportions, lens flare
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There are exactly 6 objects, each whole and inside the canvas.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- Screens, signs, boards and plaque faces are blank.

## Save

```sh
python3 tools/intake.py add anime_cel.A-work-furniture PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/A-work-furniture/rNNN/image.png` with its prompt and its record.
