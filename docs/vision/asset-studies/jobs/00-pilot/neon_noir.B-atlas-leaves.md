# neon_noir.B-atlas-leaves

Leaf clusters (cut-outs) · surface (cut-out atlas) · style: Neon noir · batch 00-pilot · canvas 1024 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/neon_noir/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
2. `refs/panels/neon_noir/park.jpg` — style reference: the park panel of this style's concept sheets
3. `refs/panels/neon_noir/conversation.jpg` — style reference: the conversation panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: cut-out atlas for the foliage of a game
Primary request: four separate cut-outs of leaf clusters, as the reference images draw them
Input images: Image 1: style reference (the gathering panel); Image 2: style reference (the park panel); Image 3: style reference (the conversation panel). These are panels from the concept sheets of the Neon noir style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one flat pure magenta (#FF00FF) backdrop across the whole canvas, used as a colour key, with no shadows or gradients on it
Subject: four separate pieces, one in each quarter of the canvas, each centred with clear backdrop all round it. In reading order: 1. A leaf cluster from a large tree's crown, as seen from below and outside. 2. A second, smaller leaf cluster from a tree's crown. 3. One palm frond. 4. A spray of shrub leaves. In this style foliage is drawn as: dark olive leaves and violet flowers.
Style/medium: neon noir city design, drawn as a clean stylised 3D game model: dark charcoal and navy forms with slim lines of built-in light, softly shaded, no outlines
Composition/framing: square canvas, 1024 x 1024, divided into four equal quarters
Lighting/mood: neutral soft studio light from the upper left so that the true surface colours read, with the object's own lamps and light strips switched on and glowing; no night scene, no rain, no coloured light on the backdrop; every surface is drawn in its own colour, as neutral light shows it; lamps, lanterns and light strips are drawn switched on as small bright parts, but their light does not fall on the object, the ground or the backdrop: no glow on leaves, bark, walls or seats, no halo and no pool of light
Color palette: dark olive-green leaves, #171A12 in shade to #4A3D1F in light, and violet flowers
Constraints: each piece complete, inside its own quarter and touching nothing; crisp edges with no halo and none of the backdrop colour on the pieces; no ground, pots or shadows; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: pieces that overlap or run off the canvas, soft glows, daylight scenes, dirt and decay, weapons, dystopian signage, heavy fog, lens flare over the object, photorealism, photographic materials and lighting
```

## Before saving, look at the image

- The canvas is square.
- There are four separate pieces, one in each quarter, none touching another or the edge.
- The backdrop is one flat magenta with no shadows.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add neon_noir.B-atlas-leaves PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/neon_noir/B-atlas-leaves/rNNN/image.png` with its prompt and its record.
