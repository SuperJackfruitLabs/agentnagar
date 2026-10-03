# pixel_art.A-agent-a1

City Agent A1 · asset design sheet (design sheet) · style: Pixel art · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/pixel_art/conversation.jpg` — style reference: the conversation panel of this style's concept sheets
2. `refs/panels/pixel_art/mobile.jpg` — style reference: the mobile panel of this style's concept sheets
3. `refs/panels/pixel_art/facility.jpg` — style reference: the facility panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model or sprite will be built to
Primary request: a clean design sheet of one figure, City Agent A1, drawn as a finished game sprite in the style of the reference images
Input images: Image 1: style reference (the conversation panel); Image 2: style reference (the mobile panel); Image 3: style reference (the facility panel). These are panels from the concept sheets of the Pixel art style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: City Agent A1, the city's recurring agent, between 1.65 and 1.8 m tall. Standing relaxed with the arms slightly away from the body. A leaf badge on the chest and no lettering. In this style: City Agent A1 is a person with white hair tipped in blue, a dark jacket with a round blue and white patch on the shoulder, a blue scarf, and a leaf emblem on the backpack and on a lanyard card. Character notes: The agent people ask first. It has looked the same since the city opened, so that anyone can find it.
Style/medium: detailed 16-bit-era pixel art game sprite: hard-edged square pixels on one consistent grid, a small fixed palette, dark navy outlines, selective dithering, no anti-aliasing and no blur
Composition/framing: landscape canvas, 1536 x 1024. Four full-body views of the same figure as game sprites, in one row, equally spaced, all the same height and standing on the same ground line: front, three-quarter front, side, back. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: body, second colour, face or visor, badge, joints or trim. Every sprite pixel is one square block about 5 canvas pixels wide, and all blocks sit on one grid.
Lighting/mood: the sprite's own fixed light from the upper left, with flat tone steps
Color palette: a small fixed palette close to the pack's own, with a navy outline (#181C30) round every sprite; add a colour only where the object needs one: skin tones, with red, blue, yellow and purple clothes; red #C83C3C, royal blue #0251A4, yellow #F2B632, purple #825ABE
Materials/textures: flat pixel clusters in two or three tones for each material, with selective dithering between tones; bricks, planks and leaves drawn as small pixel patterns
Constraints: one figure only, shown four times as the same figure with the same clothes, parts and colours; drawn in a few clear pixel clusters that still read at a sprite's small size; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, anti-aliasing, blur, gradients, mixed pixel sizes, 3D render look, more than about forty colours
```

## Before saving, look at the image

- The canvas is landscape, close to 3:2.
- The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine).
- There is one thing only, whole in every view, and the views show the same object.
- There is no readable text, label or number anywhere.
- It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- Pixels are hard-edged squares of one size, with no blur.

## Save

```sh
python3 tools/intake.py add pixel_art.A-agent-a1 PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/pixel_art/A-agent-a1/rNNN/image.png` with its prompt and its record.
