# voxel.E-guild-hall

The guild hall (three stages) · life-cycle sheet (life-cycle sheet) · style: Voxel · batch 04-life · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/voxel/street.jpg` — style reference: the street panel of this style's concept sheets
2. `refs/panels/voxel/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
3. `sheets/voxel/A-guild-hall/LATEST/image.png` — the design sheet of this object: the newest revision in `sheets/voxel/A-guild-hall/` (the highest rNNN)

`LATEST` stands for the newest revision folder of that design sheet. If the sheet has no image yet, skip this job and say so: it cannot be made first.

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset life-cycle sheet: one asset at three stages
Primary request: the guild hall at three stages of its life, side by side, each drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the street panel); Image 2: style reference (the gathering panel). These are panels from the concept sheets of the Voxel style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions. Image 3: the design sheet that shows the guild hall. The second stage is that object exactly: the same design, parts, proportions and colours. Take nothing else from that sheet.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: The guild hall, the makers' workshop: a low rectangular hall under three sawtooth roof bays, each about 4.3 m wide, with walls 5.2 m high and roof ridges about 8 m high. Its front is made of panels 4 m wide: solid wall, glazed wall, and one door panel with double doors 2 m wide and 3.2 m high, between square corner piers. Workbenches show through the glazing. In this style: A bright yellow cube hall with yellow sawtooth roofs whose upright faces are grey skylights, a grey stone base, one wide glazed opening. Three stages, left to right: 1. Being built: the structural frame up and part of the walls and roof in place, scaffolding along one side, materials stacked at its foot. 2. Newly finished. 3. After ten years of use: planting grown up its walls and on its terraces, an awning or canopy added, a few small repairs in a slightly different tone.
Style/medium: voxel 3D game model, seen as a clean render: forms built from cubes on one grid, with stepped edges where a curve would be; only the largest roofs (the workshop's sawtooth, the library's vault) are drawn smooth; no outlines
Composition/framing: landscape canvas, 1536 x 1024, divided into three equal columns with clear empty backdrop between them; one stage in each, in three-quarter view from the front-right with the camera raised about 30 degrees, the same viewpoint and the same size in all three.
Lighting/mood: bright even daylight from the upper left, soft shading between cubes, no coloured light, no hard cast shadows
Color palette: a bright yellow workshop, an orange library vault, white and cobalt-glass towers, grey stone base courses; a warm yellow glow; orange, cobalt and emerald
Materials/textures: one flat saturated colour on each cube, with a slight tone difference from cube to cube and soft shading where cubes meet; no painted texture inside a cube face
Constraints: the same object in all three stages, with the same footprint, main form and viewpoint; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, people, three different designs, perspective distortion, depth of field, bloom, smooth or rounded surfaces, diagonal slopes, textures inside cube faces, ink outlines, tiny noisy cubes
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- There are three stages in a row, of the same object from the same viewpoint.
- The backdrop is plain grey with no scenery (a soft gradient in the grey is fine).
- There is no readable text.
- The second stage is the object on its design sheet: the same design, not a new one.

## Save

```sh
python3 tools/intake.py add voxel.E-guild-hall PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/voxel/E-guild-hall/rNNN/image.png` with its prompt and its record.
