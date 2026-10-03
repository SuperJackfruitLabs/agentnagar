# pixel_art.D-street-dressed

The tree square, seen from the pixel pack's fixed isometric camera (dressed) · repainted game frame (dressed frame) · style: Pixel art · batch 02-city · canvas 1536 x 1024

## Reference images

Load each with `view_image`, in this order, before generating. Image 1 is the edit target: this job is an edit of it.

1. `refs/frames/pixel_art/street.jpg` — edit target: a capture of the game as it is today
2. `refs/panels/pixel_art/street.jpg` — style reference: the street panel of this style's concept sheets
3. `refs/panels/pixel_art/gathering.jpg` — style reference: the gathering panel of this style's concept sheets

## Prompt

Submit exactly this text.

```text
Use case: sketch-to-render
Asset type: paint-over of a game capture, used as a like-for-like art target
Primary request: repaint Image 1 in the style of the reference images and dress the scene as they are dressed, keeping what exists where it is
Input images: Image 1: edit target, a capture of the game as it is today in the Pixel art pack, showing the tree square, seen from the pixel pack's fixed isometric camera; Image 2: style reference (the street panel of this style's concept sheets); Image 3: style reference (the gathering panel of this style's concept sheets). Take the look from the style references and the layout from Image 1.
Style/medium: the finished look of this style's concept sheets: flat pixel clusters in two or three tones for each material, with selective dithering between tones; bricks, planks and leaves drawn as small pixel patterns
Lighting/mood: bright daylight pixel scene with a blue sky and pixel clouds; at night, navy shadows with amber lamps and windows
Color palette: a small fixed palette close to the pack's own, with a navy outline (#181C30) round every sprite; add a colour only where the object needs one: architecture: brick #7A3028 #A84834 #C86E50, sand stone #DEC496 #F0E0BE, slate-blue roofs #303A6E, windows #A0C8E1; timber: wood #5C3A28 #8A5A3B; metal: dark #2E2B2A and outline navy #181C30; stone: stone #AAA096 #CDC6BC and grey #787882; foliage: leaf #285C34 #3E8C3E #78BE50, with one darker teal-green for deep shade and one yellow-green for highlights; trunk: wood #5C3A28 #8A5A3B; ground: sand #DEC496 #F0E0BE paving, the leaf greens for lawn, grey #787882 street; water: water #1E4678 #326EAA #78B4DC; light: lamp #FFD26E #FFF0BE; accent: red #C83C3C, royal blue #0251A4, yellow #F2B632, purple #825ABE; tram: red #C83C3C and cream #F4F1EA; people: skin tones, with red, blue, yellow and purple clothes
Constraints: keep the camera, the horizon, and the position, size and outline of everything that exists in Image 1; add only what the reference panels show in such a place and Image 1 lacks: planted beds and planter boxes, flowers, café tables and umbrellas, banners, and more people; put additions on open ground, never across a path, a doorway or the tram track; keep the canvas the same shape as Image 1 (1536 x 1024); small name labels and round markers that float in Image 1 are interface elements, not part of the scene, and are left out; no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere
Avoid: new buildings, new large trees, a different viewpoint, cropping, borders, anti-aliasing, blur, gradients, mixed pixel sizes, 3D render look, more than about forty colours
```

## Before saving, look at the image

- The canvas is landscape, the same shape as the capture.
- Set beside the capture: every building, the tree, lamps, benches and people are where they were and the size they were.
- Nothing that was in the capture is gone; additions are planting, furniture, banners and people only, on open ground.
- The surfaces, colours and light look like the reference panels.
- There is no readable text.

## Save

```sh
python3 tools/intake.py add pixel_art.D-street-dressed PATH_TO_THE_GENERATED_IMAGE
```

It files the image as `sheets/pixel_art/D-street-dressed/rNNN/image.png` with its prompt and its record.
