# Revision review

AI-generated image. Filed, not approved: a filed image is a candidate until the owner accepts it.

Job: `pixel_art.A-great-tree` (The great tree; design sheet).

## The job's checks

Tick what holds in this image, and say under Findings what does not.

- [x] The canvas is landscape, close to 3:2.
- [x] The backdrop is one flat grey with no scenery, floor or people.
- [x] There is one thing only, whole in every view, and the views show the same object.
- [x] There is no readable text, label or number anywhere.
- [x] It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- [ ] Pixels are hard-edged squares of one size, with no blur.

## Findings

- Two corrections addressed mixed pixel scales and an extra swatch, then within-block noise and palette size. Second correction selected; bottom row now has the requested five swatches.
- Three whole coherent tree variants, including a navy night view with lit lanterns. No readable text; grey gradient accepted.
- Pixel precision still fails: block sizes vary between the large and small views and within details. A 100 x 100 foliage crop contains 5,962 distinct RGB colours, so the saved image is not an approximately forty-colour sprite.
- Use as a colour/shape concept; it requires pixel-grid and palette cleanup before direct sprite use.
- Original candidate: $CODEX_HOME/generated_images/01a0f973-b7cd-7042-9a8a-c44ec3950811/exec-8026116f-f493-44da-a9bc-9b05a24d5f9e.png
- First correction candidate: $CODEX_HOME/generated_images/01a0f973-b7cd-7042-9a8a-c44ec3950811/exec-f8b8d6ff-bd56-4ab6-afc0-9399e7041975.png
- First correction prompt: Change only pixel-grid consistency and the colour-swatch count. Redraw all three tree sprites on one shared grid of hard-edged square blocks about 5 canvas pixels wide; use the same block size in the large view and both small views, with no anti-aliasing, blur or mixed block sizes. Change the bottom row to exactly five flat square swatches, in this order: leaves in light, leaves in shade, bark, bed edge, lantern. Preserve the three whole tree views, their positions and sizes, the same tree and square stone bed with flowers, four lanterns, dimetric camera, night variant, palette, navy outlines, grey backdrop and 1536 x 1024 landscape layout. No text or added objects.

## Prompt change

Final submitted prompt is a targeted edit of the first generated candidate. The original generation used the job prompt unchanged; all original style references were supplied.
