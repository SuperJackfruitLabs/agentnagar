# anime_cel.D-park

The waterfront park path beside the river · repainted game frame (repainted frame) · style: Cel-shaded anime · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. Image 1 is the edit target: this job is an edit of it.

1. `refs/frames/anime_cel/park.jpg` — edit target: a capture of the game as it is today
2. `refs/panels/anime_cel/park.jpg` — style reference: the park panel of this style's concept sheets
3. `refs/panels/anime_cel/rooftop.jpg` — style reference: the rooftop panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: sketch-to-render
Asset type: paint-over of a game capture, used as a like-for-like art target
Primary request: repaint Image 1 in the style of the reference images, keeping its layout exactly
Input images: Image 1: edit target, a capture of the game as it is today in the Cel-shaded anime pack, showing the waterfront park path beside the river; Image 2: style reference (the park panel of this style's concept sheets); Image 3: style reference (the rooftop panel of this style's concept sheets). Take the look from the style references and the layout from Image 1.
Style/medium: the finished look of this style's concept sheets: flat fills with a hard-edged shadow step and small painted highlights; brick, planks and paving joints drawn as a few thin lines; foliage as layered clusters of small leaf shapes
Lighting/mood: vivid clear daylight with crisp cel shadows and cumulus clouds in a blue sky
Color palette: architecture: red brick, red-brown workshop roofs with long blue-grey skylights, silver metal on the library's vault, pale concrete and blue glass, warm white render; timber: timber from #3F312A in shade to #EABE8E in light; metal: near-black iron, #25242B to #6E696C; stone: grey stone, #5D5C61 to #A29493; foliage: deep green to yellow-green leaves (#3A4634, #757C49, #A9A550, #D0C870) with white and pink flowers; trunk: grey-brown bark, #423934 to #8E7C66; ground: pale beige paving, fresh green lawn, blue-grey street; water: deep blue water with white sparkles; light: warm cream lamp light; accent: indigo and vermilion; tram: a cream body with a coral-red stripe; people: white, navy, red and khaki summer clothes
Constraints: change only surfaces, colours, light, the detail of foliage and small surface detail; keep the camera, the horizon, and the position, size and outline of every building, tree, lamp, bench, person, vehicle, path and kerb exactly as in Image 1; do not add, remove, move or resize anything; keep the canvas the same shape as Image 1 (1536 x 1024); small name labels and round markers that float in Image 1 are interface elements, not part of the scene, and are left out; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: new or missing objects, a different viewpoint, cropping, borders, photorealism, soft airbrushed gradients, heavy black outlines, chibi proportions, lens flare
```

## Before saving, look at the image

- The canvas is landscape, the same shape as the capture.
- Set beside the capture: every building, the tree, lamps, benches and people are where they were and the size they were.
- Nothing has been added, removed or moved.
- The surfaces, colours and light look like the reference panels.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add anime_cel.D-park PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/anime_cel/D-park/rNNN/image.png` with its prompt and its record.
