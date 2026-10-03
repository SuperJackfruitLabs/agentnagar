# Street trees and palms

Written by Claude (an AI), 2026-10-02. These are the pieces of sheet `A-trees` (two street trees, a tall palm and a short one), built by the coordinating session while four build agents had the other families. The design images, the generated models and their textures are AI-generated. The game's contract for them is `notes/contracts/trees.md`; the figures for each piece are in the main `README.md`'s table.

## What is built

Twenty-two pieces: the large and the small street tree in all five styles, and three palms (tall, middle, short) in low-poly, neon, anime and solarpunk. The voxel kit has no palm (its `palm` kind draws its two trees), so the voxel palms' models wait unused. The middle palm has no design object of its own: it is the tall palm's model sized to the kit's middle palm, so that every palm the game draws is a new one.

Outside voxel each has a far twin beside it (`<piece>_far.glb`, about 775 triangles, textures a quarter the size). The game draws a planted piece's twin beyond 90 m wherever the twin's file sits beside it, in any pack; the build places the twins only where the kit has its own, in neon, anime and solarpunk. The low-poly kit has none, so the low-poly twins are built but not placed and its trees are drawn in full at every distance; placing them is measured under "Frame time" in the main record. Voxel has no twins.

Each tree is also built with its leaves in its kit's greens (`out-kit-green/`, four styles). The neon ones are the ones in the game; see "Palette".

All pass `check.py` (the kit's spec for size and parts, and `planted_rules.py`: one mesh, a leaf and a trunk material, the trunk's reach, the foot on the origin, the far twin's triangles), and with them placed the game's collision audit is zero in every style.

## Why they are built differently from every other piece

The district has 309 street-tree placements and 299 palm placements of 843 in all. The game does not place these as scenes. It loads the file, takes the mesh of its first mesh node and draws copies of it in MultiMeshes, each turned by some angle about the piece's origin. Nothing else in the file is looked at. And it scales each copy's width: by 0.25 m over the trunk's reach, where the reach is the farthest point from the origin, between 0.15 and 2.2 m up, of everything whose material is not named as leaf.

So a planted tree has to be:

- one mesh, with a material named `trunk` and one named `leaf` sharing the piece's textures;
- its trunk's foot on the origin and its trunk upright over it;
- nothing but trunk between 0.15 and 2.2 m: no fork, no low limb, no leaf mass counted as trunk. A design drawn with a low fork (all eight street trees outside voxel are: 1.45 to 1.92 m at this size) has its stem below the fork stretched to 2.4 m and what is above pressed into the height that is left (to 0.67 to 0.87 of it);
- its trunk slimmed until it reaches exactly 0.25 m, so that the game draws the tree at the size it was built. Six of the eight designs' trunks are thicker than that and are slimmed, to as little as 0.45 of their width; a tree left with such a trunk would be drawn at 0.45 of its own width.

That is `fit_generated.py --planted CROWN,HEIGHT` with `--parts`. The stem below the fork is not cut down from the generated mesh at all (a thin trunk rebuilt from cells comes back torn) but built again as a tube through the generated trunk's cross-sections, 170 triangles. The crown is cut as leaf masses rebuilt from 7 cm cells (5 cm for a palm's fronds), 1,800 to 2,000 triangles, and smaller copies of a street tree's own upper masses are set inside it (800 to 1,800 more), because the generator builds a crown as a ring that is open from above.

## Colours

Leaves take the sheet's own leaf swatches as a ramp from dark to light (`leaf_ramp: "swatches"`), and the trunk the sheet's browns. That is what the owner decided at 12:15 ("Keep the design sheets' greens"). The swatches are olive to yellow in every style, and so are the trees: yellow-olive in low-poly, olive to yellow in anime, yellow-green in solarpunk (dark khaki until their normals were lifted, below). In neon they read brown under the amber lamps, so the neon trees in the game are the ones in the neon kit's greens.

`previews/planted-<style>-three-ways.jpg` sets the three side by side for low-poly, anime, neon and solarpunk: the kit's trees, the new ones in the sheet's greens, and the new ones in the kit's greens.

**Blossoms.** The neon and solarpunk sheets draw flowering trees (violet in neon; pink, cream and violet in solarpunk), and the first builds lost every flower: the leaf masses are recoloured along the ramp, and a flower the generator had painted became a light green. Now a leaf texel the generator painted as a flower (plainly not leaf-coloured and lighter than the middle leaf, or pale with little colour) takes the nearest of the sheet's blossom swatches instead, and each flower is drawn two texels wider, because the generator paints fewer and smaller flowers than the sheet (`--leaf-blossoms`, `--leaf-blossoms-grow`). That is about 5 to 11% of the leaf texels on the four trees; `previews/street-tree-blossoms.jpg` shows two of them with and without. The low-poly sheet draws a handful of cream flowers and the generator painted none that can be told from lit leaf, so the low-poly trees have none; the anime sheet draws none. In voxel the white blossom cubes are kept (below).

## Leaves need normals that lean up

The first anime trees came out dull, darker than their own textures. The anime pack draws with the engine's toon step: a face turned from the sun is drawn in the shadow tone, and on the new street tree that was 38% of the painted colour in red and green. The kits of anime, neon and solarpunk lean their trees' leaf normals upward for this reason (`city/tools/styles/shared/foliage.py`). The fit now does the same: leaf normals point away from the crown's middle and are then lifted (`--leaf-round 0.85 --leaf-lift 1.0`). `previews/planted-anime_cel-lift.jpg` shows the same anime tree with and without.

Solarpunk and neon were then built the same way (`--leaf-smooth --leaf-round 0.85 --leaf-lift 1.0` in their style's flags for the street trees and palms). In solarpunk's daylight the trees and palms had shown mostly their shaded sides from eye height and read dark khaki; with the normals lifted they are the sheet's yellow-green (`previews/planted-solarpunk-lift.jpg`: the same trees before and after, from the street, the park and above). In neon the difference shows by day, where the trees in the kit's greens go from a dark green to a lighter one, and hardly at night from across the square (`previews/planted-neon_noir-lift.jpg`, taken while the neon leaves still had the neon pieces' roughness of 0.6). Close up at night the lifted leaves showed a fault of their own at that roughness: the tops of the crowns and fronds took the night's light as a pale sheen, like frost. The neon kit's foliage is matt (0.85, against the 0.6 the neon trees and palms were first built at), and with the kit's roughness the sheen is gone (`previews/neon-leaf-roughness.jpg`: the same frames at 0.6 and at 0.85; `"rough": 0.85` in the neon entries of the trees and palms). Nothing but that number changed in the files. Low-poly and voxel are left as fitted: their kits do not use the shared tree builder, and their facets and cubes are meant to shade flat.

## Voxel: built from the design's own cubes

The voxel sheet draws a cube tree already: a round crown of small cubes in three greens with white blossom cubes, on a square trunk three cubes thick. Put through the route above it came out wrong three times over: the crown, rebuilt as leaf masses, was a ragged shell; the trunk, rebuilt as a round tube and slimmed, filled no cell of the cube grid and came out in pieces or not at all; and raising the fork pressed the crown flat. Three repairs were tried on that route and dropped.

It is built another way (`voxelise.py --planted-trunk`, with `"flags_replace": true` in the piece's voxel entry):

- the generated model is fitted plainly to the kit's box with its cubes kept (40,000 triangles, an intermediate file);
- the crown is rebuilt in the kit's large cubes (0.5 m for the large tree, 0.4 m for the small) from where the design's green begins, a cube filled when a third of it lies in the model (a quarter for the small tree) and each column filled from its lowest cube to its highest;
- every cube of the crown is one flat colour on all its faces, one of the sheet's three greens. Which one is read off the design: the cubes are ranked by how light the design is on their faces, against the other faces that look the same way, so that the lighting drawn into the image does not decide it. A quarter take the dark green, 45% the middle one and 30% the light one. The whitest few take the sheet's white as blossom (7 cubes on the large tree, 4 on the small);
- the trunk is not rebuilt but built: the kit's own column and foot ribs in 0.1 m cubes (0.4 m square with ribs to 0.5 m; 0.2 m with ribs to 0.4 m), coloured from the design's trunk at the same height. The design's trunk is three of its sixteen cubes thick: at this size about 0.9 m, a reach of about 0.64 m, and the game would draw the tree at about 0.4 of its width.

They come out at 470 and 328 triangles (the kit's: 544 and 350), in the kit's box, and the game draws them at the kit's width (0.79 and 1.12 times as built, as it draws the kit's).

## The foot of the solarpunk small tree

The evening's review found a pale lump at the foot of the solarpunk small street tree, on every copy: 26 faces of leaf lying up to 0.17 m from the ground and out to 0.51 m, painted in the sheet's blossom colours. It was a patch of the drawn ground that the leaf rules had taken for leaf, and that the blossom rule then took for flowers; the game's width scale and its collision audit do not count leaf, so nothing had caught it. `--planted-leaf-from 0.5` now takes out leaf faces lying wholly below half a metre, and only this tree uses it: the refitted file lost exactly those 26 faces and nothing else changed in it, textures included (`previews/solarpunk-tree-foot-before-after.jpg`). `planted_rules.py` now holds every planted piece to it; no other tree or palm has such faces.

## What is wrong or weak

- **The palette**, above. It is the largest visible change to each town, and in solarpunk it is the least kind.
- **Blossoms** are patches of flat colour on the leaf masses, not flowers with a shape, and there are fewer than the sheets draw. Low-poly has none.
- **Crowns are masses of facets.** The kits' trees outside low-poly are leaf cards with cut-out leaves; these are leaf masses with painted leaves, closed from above but for the large anime tree's, which has a hollow at the top that shows its inside and trunk. From the street they read fuller and heavier than the kit's.
- **The crown is pressed** to two thirds to seven eighths of its drawn height by the raised fork, and the whole tree is stretched to the kit's crown and height (1.13 to 1.44 times wider than drawn).
- **Palms stand a little off their point**: the middle of the foot (the trunk's lowest 0.3 m) is 3.5 to 9.4 cm from the origin, about which the game turns each copy. The kits' palms stand on it (0 to 1.4 cm by the same measure); the kits' street trees in neon, anime and solarpunk are themselves 4 cm off. `check.py` reports it above 3 cm and fails it above 12.5 cm (half a walking cell). The street trees are within 1.2 cm.
- **Size.** A street tree is 3,200 to 4,200 triangles and a palm 2,230 to 2,550, against the kits' 370 to 820 and 600 to 1,670. With 608 of them in the district they are most of what the new pieces add to a frame in low-poly (1.1 to 1.2 of 1.5 to 1.6 ms), where every copy is drawn in full because no twin is placed, and a quarter of it in neon (0.1 of 0.4 ms), where the twins are. With the low-poly twins placed, the low-poly trees and palms cost 0.04 to 0.29 ms: see "Frame time" in the main record.
- **The voxel crowns' tones** are assigned by rank, so the darkest quarter is dark wherever the design was in shade: the hollow at the top of the large tree reads as a dark patch from above.

## Decisions made

1. Crowns are sized to the mean of the kit box's width and depth, which keeps a round crown inside the kit's size on both; in low-poly, whose test holds each axis apart, the model is turned a quarter where that fits better (`--planted-box`).
2. The fork is raised to 2.4 m in every style but voxel.
3. Far twins are cut to 800 triangles, the kits' limit for them.
4. The middle palm is the tall palm's model at the middle palm's size.
5. Neon's trees are placed in the kit's greens; the other styles' in their sheets'.
6. Voxel trees follow the kit's cube sizes and the kit's trunk, not the design's finer cubes and thick trunk.

## Tools

`fit_generated.py`: `--planted`, `--planted-box`, `--planted-clear`, `--far`, `--leaf-round`, `--leaf-lift`, `--leaf-blossoms`, `--leaf-blossoms-grow`, with the tree options the great tree already used (`--parts`, `--crown-fill`). `voxelise.py`: `--planted-trunk`, `--tones`, `--tone-shares`, `--upper auto,G`, `--upper-cover`, `--upper-solid`. `planted_rules.py` holds a built file to the contract. `planted_three_ways.sh` makes the palette sheets.
