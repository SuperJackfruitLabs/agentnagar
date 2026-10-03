# lowpoly_tropical.D-night-rain

The tree square at night in rain · repainted game frame (repainted frame) · style: Low-poly tropical · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. Image 1 is the edit target: this job is an edit of it.

1. `refs/frames/lowpoly_tropical/night-rain.jpg` — edit target: a capture of the game as it is today
2. `refs/panels/lowpoly_tropical/night-rain.jpg` — style reference: the night-rain panel of this style's concept sheets
3. `refs/panels/lowpoly_tropical/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: sketch-to-render
Asset type: paint-over of a game capture, used as a like-for-like art target
Primary request: repaint Image 1 in the style of the reference images, keeping its layout exactly
Input images: Image 1: edit target, a capture of the game as it is today in the Low-poly tropical pack, showing the tree square at night in rain; Image 2: style reference (the night-rain panel of this style's concept sheets); Image 3: style reference (the gathering panel of this style's concept sheets). Take the look from the style references and the layout from Image 1.
Style/medium: the finished look of this style's concept sheets: flat painted colour on each face with a soft gradient from light to shade; timber shows a few broad plank lines, stone a few large blocks, foliage is clumps of flat facets in three or four tones; no photographic texture, no noise
Lighting/mood: night and rain, as the night panel of the concept sheets shows them
Color palette: architecture: limewash cream and sandstone walls, terracotta roofs, green copper domes; timber: warm mid-brown timber, #613E2B in shade to #C78860 in light; metal: charcoal iron, #2C282B to #4A4548; stone: pale warm stone, #817572 in shade to #E7CEB4 in light; foliage: olive to yellow-green leaves (#233019, #586C27, #939B2D, #C5C44A) with pale and pink blossoms; trunk: warm brown bark, #45311F to #B38E62; ground: warm cream paving, soft yellow-green lawn, warm grey street; water: teal water; light: warm yellow lantern light; accent: jackfruit yellow for awnings, banners and umbrellas; tram: a cream body with a coral-red stripe; people: green, yellow, white and terracotta clothes
Constraints: change only surfaces, colours, light, the detail of foliage and small surface detail; keep the camera, the horizon, and the position, size and outline of every building, tree, lamp, bench, person, vehicle, path and kerb exactly as in Image 1; do not add, remove, move or resize anything; keep the canvas the same shape as Image 1 (1536 x 1024); small name labels and round markers that float in Image 1 are interface elements, not part of the scene, and are left out; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: new or missing objects, a different viewpoint, cropping, borders, smooth realistic foliage, photographic textures, ink outlines, glossy plastic
```

## Before saving, look at the image

- The canvas is landscape, the same shape as the capture.
- Set beside the capture: every building, the tree, lamps, benches and people are where they were and the size they were.
- Nothing has been added, removed or moved.
- The surfaces, colours and light look like the reference panels.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add lowpoly_tropical.D-night-rain PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/lowpoly_tropical/D-night-rain/rNNN/image.png` with its prompt and its record.
