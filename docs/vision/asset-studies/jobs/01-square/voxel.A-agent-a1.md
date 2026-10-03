# voxel.A-agent-a1

City Agent A1 · asset design sheet (design sheet) · style: Voxel · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/voxel/conversation.jpg` — style reference: the conversation panel of this style's concept sheets
2. `refs/panels/voxel/mobile.jpg` — style reference: the mobile panel of this style's concept sheets
3. `refs/panels/voxel/facility.jpg` — style reference: the facility panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one figure, City Agent A1, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the conversation panel); Image 2: style reference (the mobile panel); Image 3: style reference (the facility panel). These are panels from the concept sheets of the Voxel style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: City Agent A1, the city's recurring agent, between 1.65 and 1.8 m tall. Standing relaxed with the arms slightly away from the body. A leaf badge on the chest and no lettering. In this style: City Agent A1 is a white box-headed robot whose black screen face shows a green pixel smile and eyes, with dark ear panels, black hands and feet, and a green and white chequered torso; its leaf badge sits on a white chest plate. Character notes: The agent people ask first. It has looked the same since the city opened, so that anyone can find it.
Style/medium: voxel 3D game model, seen as a clean render: forms built from cubes on one grid, with stepped edges where a curve would be; only the largest roofs (the workshop's sawtooth, the library's vault) are drawn smooth; no outlines
Composition/framing: landscape canvas, 1536 x 1024. Four full-body views of the same figure in one row, equally spaced, all the same height and standing on the same ground line: front, three-quarter front, side, back. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: body, second colour, face or visor, badge, joints or trim.
Lighting/mood: bright even daylight from the upper left, soft shading between cubes, no coloured light, no hard cast shadows
Color palette: blue, orange, green and white clothes; orange, cobalt and emerald
Materials/textures: one flat saturated colour on each cube, with a slight tone difference from cube to cube and soft shading where cubes meet; no painted texture inside a cube face
Constraints: one figure only, shown four times as the same figure with the same clothes, parts and colours; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, smooth or rounded surfaces, diagonal slopes, textures inside cube faces, ink outlines, tiny noisy cubes
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There is one thing only, whole in every view, and the views show the same object.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.

## Save

```sh
python3 tools/intake.py add voxel.A-agent-a1 PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/voxel/A-agent-a1/rNNN/image.png` with its prompt and its record.
