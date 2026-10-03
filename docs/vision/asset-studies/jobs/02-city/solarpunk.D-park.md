# solarpunk.D-park

The waterfront park path beside the river · repainted game frame (repainted frame) · style: Solarpunk retro-futurism · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. Image 1 is the edit target: this job is an edit of it.

1. `refs/frames/solarpunk/park.jpg` — edit target: a capture of the game as it is today
2. `refs/panels/solarpunk/park.jpg` — style reference: the park panel of this style's concept sheets
3. `refs/panels/solarpunk/rooftop.jpg` — style reference: the rooftop panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: sketch-to-render
Asset type: paint-over of a game capture, used as a like-for-like art target
Primary request: repaint Image 1 in the style of the reference images, keeping its layout exactly
Input images: Image 1: edit target, a capture of the game as it is today in the Solarpunk retro-futurism pack, showing the waterfront park path beside the river; Image 2: style reference (the park panel of this style's concept sheets); Image 3: style reference (the rooftop panel of this style's concept sheets). Take the look from the style references and the layout from Image 1.
Style/medium: the finished look of this style's concept sheets: smooth matte ceramic, timber with a fine straight grain, brushed brass, blue solar panels with a visible cell grid; planting in soft clumps of small leaves; gentle painted shading, not photographic
Lighting/mood: warm low golden sun with soft bloom on foliage, long gentle shadows and a pale blue sky
Color palette: architecture: cream ceramic, blonde timber slats, blue solar panels, brass trim, planted roofs; timber: timber from #70482E in shade to #FACC97 in light; metal: brushed brass, with dark slim steel; stone: cream ceramic and pale stone; foliage: olive and khaki leaves (#342F14, #6A6A29, #979139, #C5BE5C) with pink, white and purple flowers; trunk: pale brown bark, #372617 to #B88F62; ground: warm sandstone paving, soft olive lawn, pale grey street; water: clear blue water; light: warm lantern light; accent: jade green and coral; tram: a white body with a red stripe and black door frames; people: natural linen, cream, olive and rust clothes
Constraints: change only surfaces, colours, light, the detail of foliage and small surface detail; keep the camera, the horizon, and the position, size and outline of every building, tree, lamp, bench, person, vehicle, path and kerb exactly as in Image 1; do not add, remove, move or resize anything; keep the canvas the same shape as Image 1 (1536 x 1024); small name labels and round markers that float in Image 1 are interface elements, not part of the scene, and are left out; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: new or missing objects, a different viewpoint, cropping, borders, photorealism, heavy machinery, rust and grime, dystopian detail, ink outlines
```

## Before saving, look at the image

- The canvas is landscape, the same shape as the capture.
- Set beside the capture: every building, the tree, lamps, benches and people are where they were and the size they were.
- Nothing has been added, removed or moved.
- The surfaces, colours and light look like the reference panels.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add solarpunk.D-park PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/solarpunk/D-park/rNNN/image.png` with its prompt and its record.
