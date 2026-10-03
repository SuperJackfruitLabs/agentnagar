# neon_noir.D-night-rain

The tree square at night in rain · repainted game frame (repainted frame) · style: Neon noir · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. Image 1 is the edit target: this job is an edit of it.

1. `refs/frames/neon_noir/night-rain.jpg` — edit target: a capture of the game as it is today
2. `refs/panels/neon_noir/night-rain.jpg` — style reference: the night-rain panel of this style's concept sheets
3. `refs/panels/neon_noir/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: sketch-to-render
Asset type: paint-over of a game capture, used as a like-for-like art target
Primary request: repaint Image 1 in the style of the reference images, keeping its layout exactly
Input images: Image 1: edit target, a capture of the game as it is today in the Neon noir pack, showing the tree square at night in rain; Image 2: style reference (the night-rain panel of this style's concept sheets); Image 3: style reference (the gathering panel of this style's concept sheets). Take the look from the style references and the layout from Image 1.
Style/medium: the finished look of this style's concept sheets: matte dark metal and concrete, dark timber with a faint grain, glass that glows from behind, thin strips of warm or coloured light set into edges; wet stone only where a scene asks for it
Lighting/mood: night and rain, as the night panel of the concept sheets shows them
Color palette: architecture: charcoal steel frames, ribbed cladding that reads tan to brown on the workshop's gables, dark navy roofs, pale stone on the library, glazing that glows amber (#FFB560); timber: dark timber, #1B100D to #846058; metal: matte charcoal and black; stone: dark concrete, #2F2322 to #5C4A45; foliage: dark olive leaves with warm highlights (#171A12, #4A3D1F, #846127, #DAA854) and violet flowers; trunk: dark brown bark, #251303 to #52300D, warm where lit; ground: dark stone paving, dark green lawn, near-black street; water: dark navy water; light: warm amber light (#FFB560), with thin violet-magenta (about #B030C0) and cyan (#3FE3FF) lines; accent: amber, magenta and cyan light; tram: a white and silver body with a red lower band; people: dark jackets in charcoal, navy and mustard
Constraints: change only surfaces, colours, light, the detail of foliage and small surface detail; keep the camera, the horizon, and the position, size and outline of every building, tree, lamp, bench, person, vehicle, path and kerb exactly as in Image 1; do not add, remove, move or resize anything; keep the canvas the same shape as Image 1 (1536 x 1024); small name labels and round markers that float in Image 1 are interface elements, not part of the scene, and are left out; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: new or missing objects, a different viewpoint, cropping, borders, daylight scenes, dirt and decay, weapons, dystopian signage, heavy fog, lens flare over the object, photorealism, photographic materials and lighting
```

## Before saving, look at the image

- The canvas is landscape, the same shape as the capture.
- Set beside the capture: every building, the tree, lamps, benches and people are where they were and the size they were.
- Nothing has been added, removed or moved.
- The surfaces, colours and light look like the reference panels.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add neon_noir.D-night-rain PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/neon_noir/D-night-rain/rNNN/image.png` with its prompt and its record.
