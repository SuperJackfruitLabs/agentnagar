# voxel.D-diagonal

The district from above, looking north-west from the south-east · repainted game frame (repainted frame) · style: Voxel · batch 01-square · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. Image 1 is the edit target: this job is an edit of it.

1. `refs/frames/voxel/diagonal.jpg` — edit target: a capture of the game as it is today
2. `refs/panels/voxel/diagonal.jpg` — style reference: the diagonal panel of this style's concept sheets
3. `refs/panels/voxel/rooftop.jpg` — style reference: the rooftop panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: sketch-to-render
Asset type: paint-over of a game capture, used as a like-for-like art target
Primary request: repaint Image 1 in the style of the reference images, keeping its layout exactly
Input images: Image 1: edit target, a capture of the game as it is today in the Voxel pack, showing the district from above, looking north-west from the south-east; Image 2: style reference (the diagonal panel of this style's concept sheets); Image 3: style reference (the rooftop panel of this style's concept sheets). Take the look from the style references and the layout from Image 1.
Style/medium: the finished look of this style's concept sheets: one flat saturated colour on each cube, with a slight tone difference from cube to cube and soft shading where cubes meet; no painted texture inside a cube face
Lighting/mood: bright midday sun, clear blue sky with white cube clouds, short soft shadows
Color palette: architecture: a bright yellow workshop, an orange library vault, white and cobalt-glass towers, grey stone base courses; timber: orange-brown timber, #643511 in shade to #F7A544 in light; metal: dark grey, #2E2F35 to #434249; stone: grey stone, #635E64 to #9F979A; foliage: saturated greens (#18330B, #448114, #69A715, #A1D026) with white blossom cubes; trunk: brown, #40250B to #98612A; ground: light grey paving tiles, bright green lawn, dark grey street; water: saturated blue water; light: a warm yellow glow; accent: orange, cobalt and emerald; tram: a white body with an orange-red stripe; people: blue, orange, green and white clothes
Constraints: change only surfaces, colours, light, the detail of foliage and small surface detail; keep the camera, the horizon, and the position, size and outline of every building, tree, lamp, bench, person, vehicle, path and kerb exactly as in Image 1; do not add, remove, move or resize anything; keep the canvas the same shape as Image 1 (1536 x 1024); small name labels and round markers that float in Image 1 are interface elements, not part of the scene, and are left out; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: new or missing objects, a different viewpoint, cropping, borders, smooth or rounded surfaces, diagonal slopes, textures inside cube faces, ink outlines, tiny noisy cubes
```

## Before saving, look at the image

- The canvas is landscape, the same shape as the capture.
- Set beside the capture: every building, the tree, lamps, benches and people are where they were and the size they were.
- Nothing has been added, removed or moved.
- The surfaces, colours and light look like the reference panels.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add voxel.D-diagonal PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/voxel/D-diagonal/rNNN/image.png` with its prompt and its record.
