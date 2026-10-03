# neon_noir.A-agent-a1

City Agent A1 · asset design sheet (design sheet) · style: Neon noir · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/neon_noir/conversation.jpg` — style reference: the conversation panel of this style's concept sheets
2. `refs/panels/neon_noir/mobile.jpg` — style reference: the mobile panel of this style's concept sheets
3. `refs/panels/neon_noir/facility.jpg` — style reference: the facility panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: game asset design sheet: the target that a 3D model will be built to
Primary request: a clean design sheet of one figure, City Agent A1, drawn as a finished game model in the style of the reference images
Input images: Image 1: style reference (the conversation panel); Image 2: style reference (the mobile panel); Image 3: style reference (the facility panel). These are panels from the concept sheets of the Neon noir style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else
Subject: City Agent A1, the city's recurring agent, between 1.65 and 1.8 m tall. Standing relaxed with the arms slightly away from the body. A leaf badge on the chest and no lettering. In this style: City Agent A1 is a robot with a glossy black visor under a silver-white cranium plate, one cyan ring light at the ear and a cyan bar on the cheek, white armour plates, and a dark hooded jacket; its leaf badge is on a white card on a lanyard. Character notes: The agent people ask first. It has looked the same since the city opened, so that anyone can find it.
Style/medium: neon noir city design, drawn as a clean stylised 3D game model: dark charcoal and navy forms with slim lines of built-in light, softly shaded, no outlines
Composition/framing: landscape canvas, 1536 x 1024. Four full-body views of the same figure in one row, equally spaced, all the same height and standing on the same ground line: front, three-quarter front, side, back. Along the bottom edge: a row of flat square colour swatches, one for each of these, in this order: body, second colour, face or visor, badge, joints or trim.
Lighting/mood: neutral soft studio light from the upper left so that the true surface colours read, with the object's own lamps and light strips switched on and glowing; no night scene, no rain, no coloured light on the backdrop; every surface is drawn in its own colour, as neutral light shows it; lamps, lanterns and light strips are drawn switched on as small bright parts, but their light does not fall on the object, the ground or the backdrop: no glow on leaves, bark, walls or seats, no halo and no pool of light
Color palette: dark jackets in charcoal, navy and mustard; amber, magenta and cyan light
Materials/textures: matte dark metal and concrete, dark timber with a faint grain, glass that glows from behind, thin strips of warm or coloured light set into edges; wet stone only where a scene asks for it
Constraints: one figure only, shown four times as the same figure with the same clothes, parts and colours; made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
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
python3 tools/intake.py add neon_noir.A-agent-a1 PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/neon_noir/A-agent-a1/rNNN/image.png` with its prompt and its record.
