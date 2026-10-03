# lowpoly_tropical.B-atlas-leaves

Leaf clusters (cut-outs) · surface (cut-out atlas) · style: Low-poly tropical · batch 00-pilot · canvas 1024 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. This job is a new image, not an edit.

1. `refs/panels/lowpoly_tropical/gathering.jpg` — style reference: the gathering panel of this style's concept sheets
2. `refs/panels/lowpoly_tropical/park.jpg` — style reference: the park panel of this style's concept sheets
3. `refs/panels/lowpoly_tropical/conversation.jpg` — style reference: the conversation panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: stylized-concept
Asset type: cut-out atlas for the foliage of a game
Primary request: four separate cut-outs of leaf clusters, as the reference images draw them
Input images: Image 1: style reference (the gathering panel); Image 2: style reference (the park panel); Image 3: style reference (the conversation panel). These are panels from the concept sheets of the Low-poly tropical style. Take from them only how this style renders, colours and builds things like this. Do not copy their composition, scenery, people or captions.
Scene/backdrop: one flat pure magenta (#FF00FF) backdrop across the whole canvas, used as a colour key, with no shadows or gradients on it
Subject: four separate pieces, one in each quarter of the canvas, each centred with clear backdrop all round it. In reading order: 1. A leaf cluster from a large tree's crown, as seen from below and outside. 2. A second, smaller leaf cluster from a tree's crown. 3. One palm frond. 4. A spray of shrub leaves. In this style foliage is drawn as: clumps of flat leaf facets, olive in shade and yellow-green in light, with a few pale blossoms.
Style/medium: stylised low-poly 3D game model, seen as a clean render: flat faceted planes on foliage, rocks, hair and cloth; buildings and furniture as smooth painted volumes with crisp chamfered edges; matte surfaces, no outlines
Composition/framing: square canvas, 1024 x 1024, divided into four equal quarters
Lighting/mood: soft even daylight from the upper left, as in a product render: every surface readable, gentle shading, no coloured light, no hard cast shadows
Color palette: olive to yellow-green leaves (#233019, #586C27, #939B2D, #C5C44A) with pale and pink blossoms
Constraints: each piece complete, inside its own quarter and touching nothing; crisp edges with no halo and none of the backdrop colour on the pieces; no ground, pots or shadows; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: pieces that overlap or run off the canvas, soft glows, smooth realistic foliage, photographic textures, ink outlines, glossy plastic
```

## Before saving, look at the image

- The canvas is square.
- There are four separate pieces, one in each quarter, none touching another or the edge.
- The backdrop is one flat magenta with no shadows.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add lowpoly_tropical.B-atlas-leaves PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/lowpoly_tropical/B-atlas-leaves/rNNN/image.png` with its prompt and its record.
