# anime_cel.A-agent-a1

City Agent A1 · asset design sheet (design sheet) · style: Cel-shaded anime · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/anime_cel/conversation.jpg` — style reference: the conversation panel of this style's concept sheets
2. `refs/panels/anime_cel/mobile.jpg` — style reference: the mobile panel of this style's concept sheets
3. `refs/panels/anime_cel/facility.jpg` — style reference: the facility panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one figure, City Agent A1, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the conversation panel); Image 2: style reference (the mobile panel); Image 3: style reference (the facility panel). These are panels from the concept sheets of the Cel-shaded anime style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: City Agent A1, the city's recurring agent, between 1.65 and 1.8 m tall. Standing relaxed with the arms slightly away from the body. A leaf badge on the chest and no lettering. In this style: City Agent A1 is a young woman with navy-blue hair tied in a loose bun, a white work jacket over a blue shirt, and a blue leaf badge. Character notes: The agent people ask first. It has looked the same since the city opened, so that anyone can find it.
Style/medium: cel-shaded anime background art, drawn as a clean toon-shaded 3D game model: flat colour fills, two steps of cool lavender-grey shadow, thin dark ink lines on silhouettes and main edges
Composition/framing: landscape canvas, 1536 x 1024. Four full-body views of the same figure in one row, equally spaced, all the same height and standing on the same ground line: front, three-quarter front, side, back. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: body, second colour, face or visor, badge, joints or trim.
Lighting/mood: clear even daylight from the upper left; each surface keeps one flat colour, with a single darker step only on the faces turned away from the light; no shadow shapes or streaks painted across a flat face, no coloured light, no long cast shadows
Color palette: white, navy, red and khaki summer clothes; indigo and vermilion
Materials/textures: flat fills with a hard-edged shadow step and small painted highlights; brick, planks and paving joints drawn as a few thin lines; foliage as layered clusters of small leaf shapes
Constraints: one figure only, shown four times as the same figure with the same clothes, parts and colours; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, photorealism, soft airbrushed gradients, heavy black outlines, chibi proportions, lens flare
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There is one thing only, whole in every view, and the views show the same object.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.

## Save

```sh
python3 tools/intake.py add anime_cel.A-agent-a1 PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/A-agent-a1/rNNN/image.png` with its prompt and its record.
