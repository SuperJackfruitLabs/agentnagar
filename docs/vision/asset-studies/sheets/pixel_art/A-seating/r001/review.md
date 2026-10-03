# Revision review

AI-generated image. Filed, not approved: a filed image is a candidate until the owner accepts it.

Job: `pixel_art.A-seating` (park bench, café chair, reading chair, perch seat; design sheet).

## The job's checks

Tick what holds in this image, and say under Findings what does not.

- [x] The canvas is landscape, close to 3:2.
- [x] The backdrop is one flat grey with no scenery, floor or people.
- [x] There are exactly 4 objects, each whole and inside the canvas.
- [x] There is no readable text, label or number anywhere.
- [x] It reads as this style's concept sheets do, and as something a simple game model could reproduce.
- [ ] Pixels are hard-edged squares of one size, with no blur.

## Findings

- Two corrections simplified rendering and attempted a common pixel grid and limited palette; second correction selected.
- Exactly four whole seats, separated in a two-by-two layout with swatches and no readable text. Grey background gradient accepted.
- Pixel precision still fails: block sizes are not uniformly five canvas pixels and edges/details are not on a demonstrably single grid. A 100 x 100 bench crop contains 3,179 distinct RGB colours, exceeding the roughly forty-colour limit.
- Useful as a design and palette guide; pixel cleanup is required for direct sprite use.
- Original candidate: $CODEX_HOME/generated_images/01a0f973-b7cd-7042-9a8a-c44ec3950811/exec-79ec9bef-882d-4983-80bd-a791d19f37f1.png
- First correction candidate: $CODEX_HOME/generated_images/01a0f973-b7cd-7042-9a8a-c44ec3950811/exec-99c325f1-4fa3-4d50-9dde-51b050aa2102.png
- First correction prompt: Change only the pixel rendering of the four seat sprites: place all details and outlines on one common grid of hard-edged square blocks about 5 canvas pixels wide, with the same block size on every seat. Each sprite block must have one flat colour; use at most forty sprite colours, flat tone steps and selective dithering, with no anti-aliasing, blur, gradients inside blocks or texture noise. Preserve exactly four complete seats, their designs and dimetric viewpoints, two-by-two layout, positions, sizes, colour swatches, dark navy outlines, grey backdrop and 1536 x 1024 landscape canvas. No text or added objects.

## Prompt change

Final submitted prompt is a targeted edit of the first generated candidate. The original generation used the job prompt unchanged; all original style references were supplied.
