# voxel.A-work-furniture

desk with stool, workstation, workbench, bookshelf, pegboard, pendant lamp · asset design sheet (design sheet) · style: Voxel · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/voxel/workshop.jpg` — style reference: the workshop panel of this style's concept sheets
2. `refs/panels/voxel/facility.jpg` — style reference: the facility panel of this style's concept sheets
3. `refs/panels/voxel/home.jpg` — style reference: the home panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of 6 separate things, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the workshop panel); Image 2: style reference (the facility panel); Image 3: style reference (the home panel). These are panels from the concept sheets of the Voxel style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: 6 separate objects, in reading order. 1. A workshop desk with a stool: the desk 1.3 m wide, 70 cm deep and 75 cm high. 2. A workstation: the same desk carrying a computer with one screen. The screen is blank: the game draws its content. 3. A long workbench: 3.2 m long, 1 m deep and 90 cm high, with a heavy top and a lower shelf. 4. A bookshelf: 2 m wide, 2.6 m high and 45 cm deep, with five shelves of books. Book spines are plain colours with no lettering. 5. A pegboard wall panel 2 m wide and 1.2 m high with hand tools hung in rows. 6. A pendant lamp: a metal shade about 45 cm across hanging on a cord. Where a note above does not say how this style draws an object, use the style's own materials: orange-brown timber cubes; dark grey cubes; one warm glowing cube inside a dark frame.
Style/medium: voxel 3D game model, seen as a clean render: forms built from cubes on one grid, with stepped edges where a curve would be; only the largest roofs (the workshop's sawtooth, the library's vault) are drawn smooth; no outlines
Composition/framing: landscape canvas, 1536 x 1024, divided into six equal cells, three across and two down with clear empty backdrop between them. One object in each, centred, in three-quarter view from the front-right with the camera raised about 30 degrees, drawn as large as its cell allows. Every object stands well clear of its neighbours and of the canvas edge: no part or shadow of one reaches another. Under each object: a short row of flat square colour swatches, one for each of its main materials.
Lighting/mood: bright even daylight from the upper left, soft shading between cubes, no coloured light, no hard cast shadows
Color palette: orange-brown timber, #643511 in shade to #F7A544 in light; dark grey, #2E2F35 to #434249; a warm yellow glow
Materials/textures: one flat saturated colour on each cube, with a slight tone difference from cube to cube and soft shading where cubes meet; no painted texture inside a cube face
Constraints: exactly 6 objects, each whole, inside its own cell and touching nothing; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; every screen, sign, board and plaque face is a plain blank surface; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, smooth or rounded surfaces, diagonal slopes, textures inside cube faces, ink outlines, tiny noisy cubes
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
python3 tools/intake.py add voxel.A-work-furniture PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/voxel/A-work-furniture/rNNN/image.png` with its prompt and its record.
