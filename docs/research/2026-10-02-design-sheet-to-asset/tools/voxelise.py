"""voxelise.py FITTED.glb OUT.glb --grid G --name ROOT --mesh NODE [options]: a fitted piece rebuilt from cubes.

The voxel style builds every form from cubes on one grid, and its kit's pieces are a few boxes with one flat
colour a face. A piece generated from a voxel design sheet is blocky already, but it is a dense mesh whose
cubes are neither square nor on the kit's grid. This takes such a piece after fit_generated.py has turned,
sized and coloured it (so it stands in its kit piece's box, its seat at the kit's height, its colours matched
to the design) and rebuilds it:

  1. a cell of the grid (G metres, the kit's is 0.1) is filled when at least --cover of it (default 0.5) lies
     inside the piece. Inside is judged against a closed surface rebuilt round the piece, at --samples cubed
     points a cell (default 4, so 64). A member thinner than a cell (a chair's leg) is given the one cell
     that holds most of it;
  2. only the faces between a filled cell and an empty one are drawn, joined into the largest rectangles that
     fit (so a flat side of forty cells is two triangles), and not the faces that lie on the ground;
  3. every cell face takes the colour the fitted piece has there (the middle value of nine points across the
     face, so that a dark joint the generator painted between its own cubes does not decide it), so each cube
     keeps its own tone as the design drew it. The colours go into one small texture, a block of --px by --px
     pixels a cell face (default 8), read without blending between pixels, so the cubes stay crisp.

    blender --background --factory-startup --python-exit-code 1 --python voxelise.py -- \\
        FITTED.glb OUT.glb --grid 0.1 --name bench --mesh seat [--upper Z,G2] [--cover 0.5] [--thin 0.15] [--samples 4]
        [--px 8] [--glow NAME] [--light NODE] [--warm H0,H1,SAT,VALUE] [--rough 0.9] [--report OUT.json]
        [--sheets F] [--hollows] [--keep-outside R]
        [--symmetric] [--column N[,Z0,Z1]] [--round [Z]] [--sectors N] [--heap Z[,RIM[,LEAST]]] [--tuck Z[,F]]
        [--drum R,H[,SIDES]] [--close] [--on-lines] [--tones HEX,... --tone-cubes]

--upper Z,G2   above the height Z (moved to the nearest level of the coarse grid) the cells are G2 metres, a whole
               number of fine cells: a tree's trunk and bed in small cubes, its crown in large ones, as the kit
               builds its trees and the concept sheet draws them. The small cubes run on two large cells
               above Z for what is wood-coloured there, so the trunk reaches into its crown.
--jumble F     with --upper: the crown's surface is broken up. Of its surface cells the share F is left out and
               of the empty cells touching it the share F is filled, by a fixed pattern (the same every run).
--sheets F     a cell that a sheet thinner than half a cell spans is filled: one in which, looking along x or
               along y, at least F (0 to 1) of the lines through the cell pass through the piece's surface
               twice. For a panel in a frame (a shelter's sign, its panes), which otherwise comes out as the
               frame alone.

--hollows      what the piece's surface encloses counts as inside it, whichever way the surface looks: for a
               piece of bowls and tiers (a fountain's centre piece), which the generator makes as thin shells with
               a second surface inside them, and which otherwise fill no cell by half.
--keep-outside R  the faces all of whose corners lie R metres or more from the piece's upright axis are kept as
               they are, with their materials and texture, in the one mesh; only what lies inside is rebuilt from
               cubes. For a fountain: its basin is a round drum on its footprint, which cubes cannot follow.

--solid H      below H metres every cell inside the rectangle of the piece's foot is filled: a planting bed is a
               solid block to its rim. The game's collision audit reads what a piece draws from 0.25 m up, and a
               bed whose rim is a cube lower along one side leaves the cells the grid blocks there with nothing
               drawn in them.

--symmetric    a piece that is alike all round its axis (a pedestal table, an umbrella): a cell counts as covered
               by the mean of what it and its mirror images across x, across y and, where the grid lies alike
               on both, across the diagonals are covered. A generated model of cubes is not on the kit's grid,
               and sized to the kit's box its cubes are one and a half cells or three quarters of one: read
               cell by cell, a round top or a canopy comes out ragged and lopsided; averaged over its mirror
               images it comes out as the stepped round it was drawn as. Cells filled as thin members are
               filled in every image too.
--column N[,Z0,Z1]  between the heights Z0 and Z1 the piece is a column N cells square about its axis and
               nothing else (with N odd on a grid whose line runs through the axis, or even on one whose
               cell does, the cells nearest the axis, the -x, -y ones first, as the kit sets its umbrella's
               pole). Without the heights they are the stem's, from the fit's report beside the fitted piece
               (fit_generated.py --stem), moved to the grid's levels. A pole one generated cube thick is half
               in each of two cells and comes out broken or not at all; and a table's column has to be wide
               enough to hide its umbrella's pole. The column is one colour, the middle one of what its faces
               take from the fitted piece (a collar the generator set under a table's top is not drawn on it).
--round [Z]    from Z metres up (without Z: from the top of the --column) every level of the piece is a round of
               cubes about the axis: a cell is filled when its middle lies no further from the axis than the
               fitted piece reaches at that level (half its width and half its depth there, averaged; the
               cells nearest the axis at least). A generated table top or canopy is an uneven blob of uneven
               cubes; its widths level by level are what the design drew, and a round of the grid's own cubes
               that wide is what the kit builds.
--sectors N    with --round: the rounds of more than sixteen cells (a canopy, not its finial) are painted in N
               sectors about the axis, turn about in the two colours the fitted piece mostly has there (the
               commoner one on the sector that looks along +x; N even). A design draws a striped canopy in
               clean sectors and the generator paints them as blotches; read cube by cube, blotches is what
               comes out.
--heap Z[,RIM[,LEAST]]  from Z metres up the piece is a heap: every column of cells is filled from Z up to where the
               fitted piece stands in it (nine rays are dropped on the column from above; the third highest of
               the heights they land at, to the nearest cell), and nothing else is. A planting of loose cubes
               with gaps between them fills hardly any cell by half, and comes out as a handful of cubes; as a
               heap it comes out planted full, its top as uneven as its cubes stand. RIM cells in from the
               piece's outline (default 1) stay clear, so that a planter's rim shows all round. With a third
               value, --heap Z,RIM,LEAST, every column inside the rim is at least LEAST cells high: plants
               the generator set flush with the rim, inside the box, stand a cube above it as the design draws.
--tuck Z[,F]   the corners below Z metres are drawn in towards the axis and down by F (default 0.03): an
               umbrella's pole and base stand inside its table's column and foot, and on one grid their faces
               would lie in the same planes as the table's and flicker.

--planted      a tree the game plants by the hundred (fit_generated.py --planted): the file keeps the fitted piece's
               two materials, the trunk's and the leaves' (told apart, cell by cell, by which of the two the
               fitted piece has nearest the cell's middle), sharing the one texture. The game scales each copy's
               width by 0.25 m over how far the trunk's material reaches from the origin between 0.15 and 2.2 m
               up, and leaves out what is named as leaf: with one material a leaf cube hanging into that band
               would count as trunk and shrink the tree. With --upper the small cubes above the crown's start
               are kept where the fitted piece is trunk, not where it is brown, and every large cube is leaf
               (a crown's cube holds leaves round a limb; its middle is nearest the limb). The fitted trunk is
               an open tube: its ends are closed before inside and outside are judged, or it fills no cell.
--upper-cover F  with --upper: a large cube is filled when F of it lies inside the piece (default: --cover). A
               crown fitted for a planted tree is a shell of leaf masses, which half-fills few cubes of 0.5 m.
--upper-solid  with --upper: in the large cubes, every cell between the lowest and the highest filled cell of
               its column is filled, so the crown is a solid mass and not a shell with the trunk showing through.

--planted-trunk N,F  with --planted and --upper auto,G2: a planted tree whose design is a cube tree already (a voxel
               sheet's). The piece comes from a plain fit (one material, the design's cubes kept), not from the
               fit's planted route, which rebuilds a crown as leaf masses and a trunk as a round tube. Leaf and
               wood are told by colour. The crown is rebuilt in the large cubes from where the green begins
               (--upper auto: the level of the coarse grid under the height below which a fiftieth of the green
               lies); what is wood-coloured in its two lowest levels is left out. The trunk is not rebuilt but
               built: a column N small cubes square about the origin, from the ground to the crown's lowest
               cube over it, with four ribs one cube deep and two wide at its foot, F metres high (the design's
               stepped foot), coloured from the design's trunk at the same height. The game draws every copy's
               width by 0.25 m over the trunk's reach, so a trunk as thick as the design draws it (a fifth of
               the crown) would shrink the tree to a third: the column and its ribs are the kit's own section
               (N = 4: 0.4 m and ribs to 0.3 m, the reach 0.316 m of the kit's `tree_medium`).
--leaf-material NAME, --wood-material NAME  with --planted-trunk: the two materials' names (default `leaf`, `trunk`).
--tones HEX,HEX,...  with --planted-trunk: the design sheet's swatches for this tree. Every large cube of the crown
               is then one flat colour on all its faces, one of the swatches' greens, and not what the design
               has at each face: a design image is lit (its cubes' tops light, their sides dark), the game
               lights the piece again, and the sides came out twice darkened. Which green a cube gets is read
               off the design all the same: the cubes are ranked by how light the design is on their faces
               beside the other faces that look the same way, and the darkest share of them takes the darkest
               green, and so on (--tone-shares, darkest first; default 0.25,0.45,0.30 for three greens, equal
               shares otherwise). A cube a tenth of whose face points are white (a blossom), of the whitest
               twentieth of the cubes at most, takes the swatches' white.

--drum R,H[,SIDES]  a shrub: the game draws it by the hundred, each scaled across by its footprint's radius over
               the piece's reach, and its collision audit wants the outline where people walk to be a whole
               circle, which cubes on a grid cannot make. As the voxel kit builds its own shrub: a SIDES-sided
               prism (default 32) R metres in radius stands from the ground to H metres, in the leaves' dark
               tone, joined into the one mesh, and no cube reaches further from the axis than 0.99 of R.
--on-lines     the grid is set with its lines through the piece's origin both ways, whatever the piece's ends are
               (a bed: its kerb lies on the grid's lines, and the plants that hang over it would otherwise
               set the grid half a cube off and the kerb with it).
--close        the fitted piece is open underneath (a shrub's skin): its holes are closed before inside and outside
               are judged, or it would be a shell that fills no cell.
--tone-cubes   with --tones, for a piece that is not a planted tree (a shrub on its drum, a bed): every cube that
               shows takes one flat colour as --tones describes for a crown, one of the swatches' greens by its
               rank in lightness among the cubes, the swatches' white for the whitest few, and not what the
               fitted piece has at each face (lit in the design and lit again by the game, a shrub's sides came
               out near black and a bed's plants dark). With --drum the drum takes the middle one of the
               swatches' greens (of two, the lighter) and the cubes it hides are left out of the ranking. With
               --heap the heap's cubes are the plants and take these tones in place of the heap's own colours,
               and each cube of the box under it that stands on the piece's outline (a bed's kerb) takes on
               all its faces the middle colour of the fitted piece's outer wall beside it: read face by face,
               a kerb's top took the shade of the plants over it.

--name ROOT    the root node's name, --mesh NODE the mesh node's (the kit's spec names both).
--glow NAME    the material is called NAME and the cell faces the warm rule finds (a lantern's glass: hue between
               H0 and H1 degrees, saturation above SAT, value above VALUE; default 28,62,0.42,0.62) emit their colour.
               Where the fitted piece brings a glow texture of its own (fit_generated.py --glow), a cell face
               glows where that texture is lit, whatever its colour: a lamp's glass can be pale.
--light NODE   with --glow: the cell faces that glow become a mesh part of their own named NODE, in the material
               NAME, and the rest of the piece takes a material that does not glow (`cubes`). For the kit's lamp:
               the game hangs its lamp at the middle of the part named `light`, and the voxel kit's test wants
               every material on that part to emit. The fitted piece's own `light` part is then rebuilt with
               the rest of it, not left out.
Prints one line beginning VOXEL with the numbers, and writes them to --report.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = Path(argv[0]), Path(argv[1])


def opt(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


g = float(opt("--grid", "0.1"))
drum = [float(v) for v in opt("--drum").split(",")] if opt("--drum") else None
cover = float(opt("--cover", "0.5"))
px = int(opt("--px", "8"))
root_name, mesh_name = opt("--name", out.stem), opt("--mesh", "body")
glow = opt("--glow")
report = {"grid_m": g}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src))
light_name = opt("--light")
left_out = ("lights", "canopy") if light_name else ("light", "lights", "canopy")
parts = [o for o in bpy.data.objects if o.type == "MESH" and o.name.split(".")[0] not in left_out]
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
if len(parts) > 1:
    bpy.ops.object.join()
piece = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# ---- What is kept as it is (--keep-outside R): the faces all of whose corners lie R metres or more from the
# piece's upright axis. A fountain's basin is a round drum on its footprint, which cubes cannot follow (their
# steps would stand up to 7 cm either side of the circle the game holds it to); only what stands inside it is
# rebuilt from cubes. The kept faces go into the one mesh with their own materials and texture. ----
kept = None
if opt("--keep-outside"):
    import bmesh
    r_keep = float(opt("--keep-outside"))
    bpy.ops.object.duplicate()
    kept = bpy.context.view_layer.objects.active
    for obj, keep_outer in ((kept, True), (piece, False)):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if all(math.hypot(v.co.x, v.co.y) >= r_keep for v in f.verts) != keep_outer], context="FACES")
        bm.to_mesh(obj.data)
        bm.free()
    kept.data.calc_loop_triangles()
    report["kept_as_it_is"] = {"beyond_m": r_keep, "tris": len(kept.data.loop_triangles)}
    bpy.ops.object.select_all(action="DESELECT")
    piece.select_set(True)
    bpy.context.view_layer.objects.active = piece

# ---- The fitted piece's triangles, their texture coordinates and its colour texture ----
me = piece.data
me.calc_loop_triangles()
verts = np.array([v.co[:] for v in me.vertices])
uv_data = me.uv_layers.active.data
tris, tri_uvs, tri_leaf = [], [], []
LEAF_NAMES = ("leaf", "leaves", "foliage", "frond")               # as the game tells them (kit_town.gd)
leaf_slots = [any(word in (m.name.lower() if m else "") for word in LEAF_NAMES) for m in me.materials]
slot_names = [m.name if m else "" for m in me.materials]
for lt in me.loop_triangles:
    tris.append(tuple(lt.vertices))
    tri_uvs.append([tuple(uv_data[i].uv) for i in lt.loops])
    tri_leaf.append(bool(leaf_slots[lt.material_index]) if lt.material_index < len(leaf_slots) else False)
planted = "--planted" in argv
trunk_arg = opt("--planted-trunk")
if trunk_arg and not (planted and (opt("--upper") or "").startswith("auto,")):
    sys.exit("--planted-trunk goes with --planted and --upper auto,G2")
if planted and not trunk_arg and not (any(leaf_slots) and not all(leaf_slots)):
    sys.exit("--planted: the fitted piece has to have a leaf-named material and one that is not")
tri_uvs = np.array(tri_uvs)
surface = BVHTree.FromPolygons([tuple(v) for v in verts], tris)
image = None
glow_image = None
for m in me.materials:
    for node in (m.node_tree.nodes if m and m.use_nodes else []):
        if node.type == "BSDF_PRINCIPLED" and node.inputs["Base Color"].is_linked:
            source = node.inputs["Base Color"].links[0].from_node
            if source.type == "TEX_IMAGE" and source.image is not None and image is None:
                image = source.image
        if node.type == "BSDF_PRINCIPLED" and node.inputs["Emission Color"].is_linked and light_name:
            source = node.inputs["Emission Color"].links[0].from_node
            if source.type == "TEX_IMAGE" and source.image is not None and glow_image is None:
                glow_image = source.image
iw, ih = image.size
pixels = np.empty(iw * ih * 4, dtype=np.float32)
image.pixels.foreach_get(pixels)
pixels = pixels.reshape(ih, iw, 4)[..., :3].astype(np.float64)
glow_pixels = None
if glow_image is not None:
    gw, gh = glow_image.size
    glow_pixels = np.empty(gw * gh * 4, dtype=np.float32)
    glow_image.pixels.foreach_get(glow_pixels)
    glow_pixels = glow_pixels.reshape(gh, gw, 4)[..., :3].astype(np.float64)


def texel_at(point, of=None, on=None):
    """The fitted piece's colour at the point of its surface nearest `point` (sRGB, 0 to 1), or what another of
    its textures (`of`, its pixels) holds there. `on`: a part of the surface (its tree and its triangles' numbers)."""
    loc, _normal, index, _dist = (surface if on is None else on[0]).find_nearest(Vector(point))
    if on is not None:
        index = on[1][index]
    a, b, c = (verts[i] for i in tris[index])
    v0, v1, v2 = b - a, c - a, np.array(loc) - a
    d00, d01, d11, d20, d21 = v0 @ v0, v0 @ v1, v1 @ v1, v2 @ v0, v2 @ v1
    den = d00 * d11 - d01 * d01
    w1, w2 = ((d11 * d20 - d01 * d21) / den, (d00 * d21 - d01 * d20) / den) if abs(den) > 1e-18 else (0.0, 0.0)
    u, v = (1 - w1 - w2) * tri_uvs[index][0] + w1 * tri_uvs[index][1] + w2 * tri_uvs[index][2]
    grid = pixels if of is None else of
    return grid[min(max(int(v * grid.shape[0]), 0), grid.shape[0] - 1), min(max(int(u * grid.shape[1]), 0), grid.shape[1] - 1)]


def colour_at(point):
    return texel_at(point)


def glows_at(point):
    """Whether the fitted piece's own glow texture is lit at the point of its surface nearest `point`."""
    return glow_pixels is not None and float(texel_at(point, glow_pixels).max()) > 0.2


# ---- A closed surface round the piece, to judge inside and outside by ----
bpy.ops.object.select_all(action="DESELECT")
piece.select_set(True)
bpy.context.view_layer.objects.active = piece
bpy.ops.object.duplicate()
closed = bpy.context.view_layer.objects.active
if "--planted" in argv:
    # A planted tree's trunk is a tube open at both ends: closed here, or the rebuilt surface is a thin wall
    # round nothing and the trunk covers no cell. The file's faces do not share their corners (each has its own,
    # for its normals and its place in the texture), so the corners are joined first: without that there are no
    # holes to find, only loose faces.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5)
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.fill_holes(sides=0)
    bpy.ops.object.mode_set(mode="OBJECT")
elif "--close" in argv:
    # A skin drawn over a shrub has no underside (nothing looks at it). Rebuilt as it is, it would be a thin
    # shell with nothing inside and fill no cell: its open foot is closed first.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5)
    bpy.ops.mesh.fill_holes(sides=0)
    bpy.ops.object.mode_set(mode="OBJECT")
rm = closed.modifiers.new("closed", "REMESH")
rm.mode = "VOXEL"
rm.voxel_size = g / 5
rm.adaptivity = 0.0
bpy.ops.object.modifier_apply(modifier=rm.name)
shell = BVHTree.FromObject(closed, bpy.context.evaluated_depsgraph_get())


def inside(point):
    loc, normal, _index, _dist = shell.find_nearest(Vector(point))
    return loc is not None and (Vector(point) - loc).dot(normal) < 0


# ---- The layers: one grid for the whole piece, or a coarser one above a height (--upper Z,G2) ----
layers = [(0.0, None, g, None)]          # (from, to, cell size, the height above which only wood-coloured cells are kept)
wood_surface = None
if trunk_arg:
    # Each triangle's colour at its middle, read straight off the texture: green is crown, brown is trunk.
    tri_ix = np.array(tris)
    mid_uv = tri_uvs.mean(axis=1)
    rows = np.clip((mid_uv[:, 1] * pixels.shape[0]).astype(int), 0, pixels.shape[0] - 1)
    cols = np.clip((mid_uv[:, 0] * pixels.shape[1]).astype(int), 0, pixels.shape[1] - 1)
    tone = pixels[rows, cols]
    mx_, mn_ = tone.max(axis=1), tone.min(axis=1)
    hue_ = np.degrees(np.arctan2(math.sqrt(3) * (tone[:, 1] - tone[:, 2]), 2 * tone[:, 0] - tone[:, 1] - tone[:, 2])) % 360
    sat_ = (mx_ - mn_) / np.maximum(mx_, 1e-4)
    is_green = (hue_ > 60) & (hue_ < 170) & (sat_ > 0.2)
    is_brown = (hue_ > 8) & (hue_ < 45) & (sat_ > 0.08)
    corners_ = verts[tri_ix]
    mid_z = corners_[:, :, 2].mean(axis=1)
    area_ = 0.5 * np.linalg.norm(np.cross(corners_[:, 1] - corners_[:, 0], corners_[:, 2] - corners_[:, 0]), axis=1)
    if not is_green.any() or not is_brown.any():
        sys.exit("--planted-trunk: the fitted piece has no green, or no brown")
    by_height = np.argsort(mid_z[is_green])
    green_from = float(mid_z[is_green][by_height][np.searchsorted(np.cumsum(area_[is_green][by_height]) / area_[is_green].sum(), 0.02)])
if opt("--upper"):
    z_cut, g_up = opt("--upper").split(",")
    g_up = float(g_up)
    z_cut = math.floor(green_from / g_up + 1e-6) * g_up if z_cut == "auto" else float(z_cut)
    if abs(g_up / g - round(g_up / g)) > 1e-6:
        sys.exit(f"--upper: the coarse cell ({g_up} m) must be a whole number of fine cells ({g} m)")
    z_cut = max(g_up, round(z_cut / g_up) * g_up)                  # a level of the coarse grid, so of the fine one too
    # The fine grid runs on two coarse cells above that height, for what is wood-coloured there (the trunk's top
    # and the feet of its limbs): at the coarse size a trunk fills no cell by half and would stop short of its crown.
    layers = [(0.0, z_cut + 2 * g_up, g, z_cut), (z_cut, None, g_up, None)]
    report["upper"] = {"from_m": round(z_cut, 3), "grid_m": g_up}
if trunk_arg:
    # The trunk's own surface, for its column's colours: the brown below the crown's second level.
    own = [i for i in np.nonzero(is_brown & (mid_z < z_cut + g_up))[0]]
    if own:
        wood_surface = (BVHTree.FromPolygons([tuple(v) for v in verts], [tris[i] for i in own]), own)
    report["upper"]["green_from_m"] = round(green_from, 3)
cover_thin = float(opt("--thin", "0.15"))
per = int(opt("--samples", "4"))
steps = [(a_ + 0.5) / per for a_ in range(per)]
points = [(dx, dy, dz) for dx in steps for dy in steps for dz in steps]
v_lo, v_hi = verts.min(axis=0), verts.max(axis=0)


def brown(colour):
    r, gg, b = (float(c) for c in colour)
    mx, mn = max(r, gg, b), min(r, gg, b)
    hue = math.degrees(math.atan2(math.sqrt(3) * (gg - b), 2 * r - gg - b)) % 360
    return 8 < hue < 45 and (mx - mn) / max(mx, 1e-4) > 0.08


heap_colours = {}          # (--heap) by column (its middle, in half cells): the level of its top cube, that cube's colour, the colour of those under it
heap_from = [None]
column_at = []             # (--column) the column's box in metres: x from, x to, y from, y to, z from, z to


def is_wood(point):
    """Whether the fitted piece's surface nearest `point` is of its trunk's material (a planted tree's), or,
    where the piece has one material (--planted-trunk), wood-coloured."""
    if trunk_arg:
        return brown(colour_at(point))
    _loc, _normal, index, _dist = surface.find_nearest(Vector(point))
    return not tri_leaf[index]


def wood_coloured(point):
    if planted:
        return is_wood(point)
    return brown(colour_at(point))


def cover_with_hollows_filled(lo, n, gl, phase):
    """How much of each cell lies inside the piece, with what the piece's surface encloses counted as inside
    whichever way that surface looks (--hollows). A generated model is a shell, often with a second surface
    inside it (the inside of a bowl, a floor under a lid): judged against the closed surface rebuilt round it,
    the hollow between the two counts as outside, and a bowl or a tier whose wall is thinner than half a cell
    fills no cell. Here the surface is drawn on a fine grid (the sample points': --samples to a cell), the
    outside is what can be reached from the grid's sides and top without crossing it (the ground closes the
    piece from below), and all the rest is inside."""
    h, pad = gl / per, per
    shape = tuple(int(v) * per + 2 * pad for v in n)
    origin = (lo * gl + phase) - pad * h
    wall = np.zeros(shape, dtype=bool)
    corners = verts[np.array(tris)]
    longest = np.linalg.norm(corners - np.roll(corners, 1, axis=1), axis=2).max(axis=1)
    fineness = np.clip(np.ceil(longest / (0.5 * h)).astype(int), 1, 600)          # points on each triangle no further apart than half a fine cell
    for m in np.unique(fineness):
        these = corners[fineness == m]
        ii, jj = np.meshgrid(np.arange(m + 1), np.arange(m + 1), indexing="ij")
        keep = ii + jj <= m
        w = np.stack([ii[keep], jj[keep], m - ii[keep] - jj[keep]], axis=1) / m
        idx = np.floor((np.einsum("kj,njc->nkc", w, these).reshape(-1, 3) - origin) / h).astype(int)
        idx = idx[((idx >= 0) & (idx < np.array(shape))).all(axis=1)]
        wall[idx[:, 0], idx[:, 1], idx[:, 2]] = True

    def spread(mask):
        out_ = mask.copy()
        for a_ in range(3):
            out_ |= np.roll(mask, 1, axis=a_) | np.roll(mask, -1, axis=a_)
        return out_
    thick = spread(wall)                                 # one fine cell thicker, so that nothing slips between two points
    thick[:, :, :pad] = True                             # the ground
    outside = np.zeros(shape, dtype=bool)
    outside[0, :, :] = outside[-1, :, :] = outside[:, 0, :] = outside[:, -1, :] = outside[:, :, -1] = True
    outside &= ~thick
    while True:
        grown = spread(outside) & ~thick
        if grown.sum() == outside.sum():
            break
        outside = grown
    solid = (~outside & ~spread(outside)) | wall         # what was not reached, less the cell added round the surface
    core = solid[pad:pad + n[0] * per, pad:pad + n[1] * per, pad:pad + n[2] * per]
    return core.reshape(n[0], per, n[1], per, n[2], per).mean(axis=(1, 3, 5))


crown_cells = {}
cell_tone = {}          # a large cube's middle, in twentieths of a small cube -> its flat colour (--tones)


def shown_points(occ, lo, phase, gl):
    """For every filled cell with a face that shows: the design's colour at nine points of each such face, as
    (direction, colour)."""
    out_ = {}
    n_ = occ.shape
    for idx in zip(*np.nonzero(occ)):
        got = []
        for axis in range(3):
            ua, va = [a_ for a_ in range(3) if a_ != axis]
            for side in (1, -1):
                j = list(idx)
                j[axis] += side
                if 0 <= j[axis] < n_[axis] and occ[tuple(j)]:
                    continue
                plane = (idx[axis] + lo[axis] + (1 if side == 1 else 0)) * gl + phase[axis]
                for su in (0.2, 0.5, 0.8):
                    for sv in (0.2, 0.5, 0.8):
                        point = np.zeros(3)
                        point[axis] = plane - side * 0.02 * gl
                        point[ua] = (idx[ua] + lo[ua] + su) * gl + phase[ua]
                        point[va] = (idx[va] + lo[va] + sv) * gl + phase[va]
                        got.append(((axis, side), np.array(colour_at(point))))
        if got:
            out_[idx] = got
    return out_


def hex_rgb(text):
    text = text.strip().lstrip("#")
    return np.array([int(text[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def flat_tones(occ, lo, phase, gl):
    """--tones: one of the swatches' greens for every large cube that shows, by its rank in lightness among the
    cubes (each face against the faces that look the same way), and the swatches' white for the whitest."""
    swatches = [hex_rgb(h) for h in opt("--tones").split(",")]
    def hsv(c):
        mx, mn = float(c.max()), float(c.min())
        hue = math.degrees(math.atan2(math.sqrt(3) * (c[1] - c[2]), 2 * c[0] - c[1] - c[2])) % 360
        return hue, (mx - mn) / max(mx, 1e-4), mx
    greens = sorted((c for c in swatches if 60 < hsv(c)[0] < 170 and hsv(c)[1] > 0.2), key=lambda c: float(c @ np.array([0.2126, 0.7152, 0.0722])))
    whites = [c for c in swatches if hsv(c)[1] < 0.12 and hsv(c)[2] > 0.8]
    if not greens:
        return {}
    shares = [float(v) for v in opt("--tone-shares", "0.25,0.45,0.30" if len(greens) == 3 else ",".join(["1"] * len(greens))).split(",")]
    shares = np.cumsum(shares) / sum(shares)
    pts_ = shown_points(occ, lo, phase, gl)
    luma = lambda c: float(c @ np.array([0.2126, 0.7152, 0.0722]))
    by_way = {}
    for idx, got in pts_.items():
        for way, c in got:
            by_way.setdefault(way, []).append(luma(c))
    mean_way = {way: float(np.mean(v)) for way, v in by_way.items()}
    rel, white_share = {}, {}
    for idx, got in pts_.items():
        rel[idx] = float(np.mean([luma(c) - mean_way[way] for way, c in got]))
        white_share[idx] = sum(1 for _w, c in got if hsv(c)[1] < 0.2 and hsv(c)[2] > 0.7) / len(got)
    blossoms = set()
    if whites:
        most = max(1, int(0.05 * len(pts_)))
        blossoms = set(sorted((i for i in pts_ if white_share[i] >= 0.1), key=lambda i: (-white_share[i], i))[:most])
    ranked = sorted((i for i in pts_ if i not in blossoms), key=lambda i: (rel[i], i))
    tones, counts = {}, [0] * len(greens)
    for place_, idx in enumerate(ranked):
        k = int(np.searchsorted(shares, (place_ + 0.5) / len(ranked)))
        k = min(k, len(greens) - 1)
        tones[idx] = greens[k]
        counts[k] += 1
    for idx in blossoms:
        tones[idx] = whites[0]
    for idx, c in tones.items():
        mid = (np.array(idx) + lo + 0.5) * gl + phase
        cell_tone[tuple(int(round(v / (g / 20))) for v in mid)] = c
    return {"greens": ["#%02x%02x%02x" % tuple(int(round(v * 255)) for v in c) for c in greens], "cubes_of_each": counts, "blossom_cubes": len(blossoms), "cubes_that_show": len(pts_)}


def tone_cubes(occ, lo, phase, gl):
    """--tone-cubes: the flat tones of --tones for a piece that is not a planted tree. The cubes a shrub's drum
    hides are left out. With --heap only the heap's cubes are toned, the heap's own colours are dropped, and the
    cubes of the box under it that stand on the piece's outline take one colour each, their outer wall's."""
    under = max(int(math.floor(drum[1] / gl + 1e-6)) - int(lo[2]), 0) if drum else 0          # the levels that end at or under the drum's top
    plants = occ.copy()
    plants[:, :, :under] = False
    box_cubes = 0
    if heap_from[0] is not None:
        first = max(int(round(heap_from[0] / gl)) - int(lo[2]), 0)
        plants[:, :, :first] = False
        heap_colours.clear()
        ii, jj = np.nonzero(occ.any(axis=2))
        i0, i1, j0, j1 = int(ii.min()), int(ii.max()), int(jj.min()), int(jj.max())          # the piece's outline, as --heap takes it
        for i, j in zip(ii, jj):
            walls = [wall for wall, here in (((0, -1, i0), i == i0), ((0, 1, i1 + 1), i == i1), ((1, -1, j0), j == j0), ((1, 1, j1 + 1), j == j1)) if here]
            for k in (range(first) if walls else ()):
                if not occ[i, j, k]:
                    continue
                samples = []
                for axis, side, edge in walls:
                    along = 1 - axis
                    for su in (0.2, 0.5, 0.8):
                        for sv in (0.2, 0.5, 0.8):
                            point = np.zeros(3)
                            point[axis] = (edge + lo[axis]) * gl + phase[axis] - side * 0.02 * gl
                            point[along] = ((i, j)[along] + lo[along] + su) * gl + phase[along]
                            point[2] = (k + lo[2] + sv) * gl
                            samples.append(colour_at(point))
                mid = (np.array([i, j, k]) + lo + 0.5) * gl + phase
                cell_tone[tuple(int(round(v / (g / 20))) for v in mid)] = np.median(np.array(samples), axis=0)
                box_cubes += 1
    # Only the cubes that show in the piece itself are ranked (a face towards an empty cell, the faces on the
    # ground apart: they are not drawn): a cube buried in the bed takes no share of a tone.
    shown = np.zeros_like(occ)
    for axis in range(3):
        for side in (1, -1):
            beyond = np.roll(occ, -side, axis=axis)
            edge = [slice(None)] * 3
            edge[axis] = -1 if side == 1 else 0
            beyond[tuple(edge)] = False
            face = occ & ~beyond
            if axis == 2 and side == -1 and lo[2] == 0:
                face[:, :, 0] = False
            shown |= face
    numbers = flat_tones(plants & shown, lo, phase, gl)
    if numbers:
        numbers.update({"cubes_hidden_in_the_drum": int((occ & shown)[:, :, :under].sum()), "cubes_of_the_box_in_their_wall_s_colour": box_cubes})
    return numbers


def layer_faces(z0, z1, gl, wood_above=None, jumble_here=0.0, given=None):
    """The faces of the piece between the heights z0 and z1 (None: its top) on a grid of gl metres: a list of
    (axis, side, plane, origin u, origin v, cells wide, cells high, gl) in metres, and the layer's numbers.
    Above the height wood_above only cells whose nearest surface is wood-coloured are kept. `given`: the cells
    themselves (filled or not, the lowest corner's cell numbers, the grid's offset), for a part that is built
    and not read off the piece (a planted tree's trunk); all of it is wood."""
    if given is not None:
        occ, lo, phase = given
        n = np.array(occ.shape)
        rescued = np.zeros_like(occ)
        solid_added = crumbs = jumbled = 0
        mirrored, column, rounds, heaped = False, None, None, None
        sheeted = np.zeros_like(occ)
    else:
        # The grid stands on the ground. Sideways it is set either with a cell's edge or with a cell's middle on
        # the piece's origin, whichever puts the piece's two ends nearer to cell edges: a piece three cells wide
        # about its origin needs the second.
        # Where the piece has layers (a tree), the lowest one is set by what stands on the ground (the bed), not by
        # the crown above it.
        foot = verts[verts[:, 2] < z0 + max(2 * gl, 0.5)] if (len(layers) > 1 and z0 == 0.0) else verts
        f_lo, f_hi = (foot.min(axis=0), foot.max(axis=0)) if len(foot) else (v_lo, v_hi)
        phase = np.zeros(3)
        for axis in (0, 1):
            def off_edges(ph):
                return sum(abs((v - ph) / gl - round((v - ph) / gl)) for v in (f_lo[axis], f_hi[axis]))
            # (a planted tree built on two grids keeps the large cubes on the small cubes' lines)
            phase[axis] = 0.0 if "--on-lines" in argv else min((0.0, math.floor(gl / (2 * g) + 1e-6) * g if trunk_arg else gl / 2), key=off_edges)
        lo = np.floor((v_lo - phase) / gl + 0.25).astype(int)            # an end less than a quarter of a cell into a cell does not open it
        hi = np.ceil((v_hi - phase) / gl - 0.25).astype(int)
        lo[2] = max(lo[2], int(round(z0 / gl)))                          # nothing below the ground, or below this layer
        if z1 is not None:
            hi[2] = min(hi[2], int(round(z1 / gl)))
        n = np.maximum(hi - lo, 0)
        cov = np.zeros(tuple(n))
        if "--hollows" in argv:
            cov = cover_with_hollows_filled(lo, n, gl, phase)
        else:
            for i in range(n[0]):
                for j in range(n[1]):
                    for k in range(n[2]):
                        base = (np.array([i, j, k]) + lo) * gl + phase
                        cov[i, j, k] = sum(1 for q in points if inside(base + np.array(q) * gl)) / len(points)
        mirrored = "--symmetric" in argv and z0 == 0.0 and len(layers) == 1
        if mirrored:
            # The grid is widened to reach as far on one side of the axis as on the other, and each cell takes the
            # mean of its own cover and its mirror images'.
            reach = [max(abs(int(lo[a])), abs(int(lo[a] + n[a]))) + 1 for a in (0, 1)]
            odd = [phase[a] != 0 for a in (0, 1)]                        # a cell's middle on the axis: one cell fewer
            wide = np.zeros((2 * reach[0] - odd[0], 2 * reach[1] - odd[1], n[2]))
            wide[lo[0] + reach[0]: lo[0] + reach[0] + n[0], lo[1] + reach[1]: lo[1] + reach[1] + n[1], :] = cov
            cov = (wide + wide[::-1] + wide[:, ::-1] + wide[::-1, ::-1]) / 4
            if cov.shape[0] == cov.shape[1] and odd[0] == odd[1]:
                cov = (cov + cov.transpose(1, 0, 2)) / 2
            lo = np.array([-reach[0], -reach[1], lo[2]])
            n = np.array(cov.shape)
        coarse = len(layers) > 1 and wood_above is None
        occ = cov >= (float(opt("--upper-cover", str(cover))) if coarse else cover)
        wood_left_out = 0
        if coarse and trunk_arg:
            # The design's own trunk and limbs, as thick as they are drawn, where they show under the crown: not
            # part of the crown. A cube most of whose face points are brown.
            for _round in range(3):
                gone = [idx for idx, pts_ in shown_points(occ, lo, phase, gl).items()
                        if sum(1 for _d, c in pts_ if brown(c)) >= 0.6 * len(pts_)]
                for idx in gone:
                    occ[idx] = False
                    cov[idx] = 0.0
                wood_left_out += len(gone)
                if not gone:
                    break
        if coarse and "--upper-solid" in argv:
            for ci in range(n[0]):
                for cj in range(n[1]):
                    held = np.nonzero(occ[ci, cj, :])[0]
                    if len(held) > 1:
                        occ[ci, cj, held[0]:held[-1] + 1] = True
        if wood_above is not None:
            for idx in zip(*np.nonzero(cov > 0)):
                if (idx[2] + lo[2]) * gl >= wood_above - 1e-6 and not wood_coloured((np.array(idx) + lo + 0.5) * gl + phase):
                    cov[idx] = 0.0
                    occ[idx] = False
        solid_added = 0
        if opt("--solid") and z0 == 0.0:
            top = max(int(round(float(opt("--solid")) / gl)) - int(lo[2]), 0)
            low = occ[:, :, :top]
            if low.any():
                ii, jj = np.nonzero(low.any(axis=2))
                block = np.zeros_like(occ)
                block[ii.min():ii.max() + 1, jj.min():jj.max() + 1, :top] = True
                solid_added = int((block & ~occ).sum())
                occ |= block
                cov[block] = np.maximum(cov[block], cover)
        heaped = None
        if opt("--heap") and z0 == 0.0:
            asked = opt("--heap").split(",")
            first = max(int(round(float(asked[0]) / gl)) - int(lo[2]), 0)
            rim_cells = int(asked[1]) if len(asked) > 1 else 1
            least_up = int(asked[2]) if len(asked) > 2 else 0
            filled_cols = np.nonzero(occ.any(axis=2))
            i0, i1, j0, j1 = filled_cols[0].min(), filled_cols[0].max(), filled_cols[1].min(), filled_cols[1].max()
            z_from = (first + int(lo[2])) * gl
            occ[:, :, first:] = False
            cov[:, :, first:] = 0.0
            heap_from[0] = z_from
            found_colours = {}
            for i in range(i0 + rim_cells, i1 - rim_cells + 1):
                for j in range(j0 + rim_cells, j1 - rim_cells + 1):
                    landed = []
                    for fu in (0.2, 0.5, 0.8):
                        for fv in (0.2, 0.5, 0.8):
                            hit = surface.ray_cast(Vector(((i + lo[0] + fu) * gl + phase[0], (j + lo[1] + fv) * gl + phase[1], float(v_hi[2]) + 0.5)), Vector((0, 0, -1)))
                            if hit[0] is not None:
                                landed.append((hit[0].z, tuple(float(c) for c in texel_at(hit[0]))))
                    landed.sort()
                    top_at = landed[-3][0] if len(landed) >= 3 else 0.0
                    cells_up = min(max(int(round((top_at - z_from) / gl)), least_up), int(n[2]) - first)
                    if cells_up > 0:
                        occ[i, j, first:first + cells_up] = True
                        cov[i, j, first:first + cells_up] = 1.0
                        # what the rays found standing in this column from just under the heap's foot up: its
                        # plants (not the soil or the inside of a wall lower down)
                        # (green, or a pale blossom standing clear of the heap's foot: not soil, not the rim's stone, and
                        # not what is left of a pale rim the generator drew, which lies level with the foot)
                        own = [c for z_, c in landed if (z_ >= z_from - 0.03 and c[1] > 1.1 * c[0] and c[1] > 1.1 * c[2]) or (z_ >= z_from + 0.3 * gl and min(c) > 0.75)]
                        found_colours[(i, j)] = (cells_up, own)
            # The heap's colours: a column's top cube takes the colour found highest in it, the cubes under it the
            # middle one of the colours found in it; a column in which the rays found nothing standing takes the
            # middle colour of the whole heap. Read off the nearest surface as the rest of the piece is, the lowest
            # cubes' sides took the dark inside of the box's walls.
            every = np.array([c for _n, own in found_colours.values() for c in own])
            for (i, j), (cells_up, own) in found_colours.items():
                body = np.median(np.array(own), axis=0) if own else (np.median(every, axis=0) if len(every) else np.array([0.3, 0.5, 0.2]))
                top_colour = np.array(own[-1]) if own else body
                key = (int(round(((i + lo[0] + 0.5) * gl + phase[0]) / gl * 2)), int(round(((j + lo[1] + 0.5) * gl + phase[1]) / gl * 2)))
                heap_colours[key] = (first + int(lo[2]) + cells_up - 1, top_colour, body)
            heights = occ[:, :, first:].sum(axis=2)
            heaped = {"from_m": round(z_from, 3), "rim_cells_clear": rim_cells, "columns": int((heights > 0).sum()),
                      "columns_inside_the_rim": int((i1 - i0 + 1 - 2 * rim_cells) * (j1 - j0 + 1 - 2 * rim_cells)),
                      "cells_high": {str(k): int((heights == k).sum()) for k in range(1, int(heights.max()) + 1)}}
        column = None
        if opt("--column") and z0 == 0.0:
            asked = opt("--column").split(",")
            across = int(asked[0])
            if len(asked) > 2:
                c0, c1 = float(asked[1]), float(asked[2])
            else:
                stem = json.loads(src.with_suffix(".json").read_text()).get("stem") or {}
                c0, c1 = stem["foot_m"], stem["foot_m"] + stem["stem_m"]
            k0, k1 = max(int(round(c0 / gl)) - int(lo[2]), 0), min(int(round(c1 / gl)) - int(lo[2]), int(n[2]))
            chosen = []
            for a in (0, 1):
                # the cells nearest the axis, those on its negative side first where two are as near
                ranked = sorted(range(int(n[a])), key=lambda i: (round(abs((i + lo[a] + 0.5) * gl + phase[a]), 6), (i + lo[a] + 0.5) * gl + phase[a] > 0))
                chosen.append(sorted(ranked[:across]))
            cov[:, :, k0:k1] = 0.0
            occ[:, :, k0:k1] = False
            for i in chosen[0]:
                for j in chosen[1]:
                    occ[i, j, k0:k1] = True
                    cov[i, j, k0:k1] = 1.0
            column = {"cells_square": across, "from_m": round((k0 + int(lo[2])) * gl, 3), "to_m": round((k1 + int(lo[2])) * gl, 3),
                      "x_m": [round(float((chosen[0][0] + lo[0]) * gl + phase[0]), 3), round(float((chosen[0][-1] + lo[0] + 1) * gl + phase[0]), 3)],
                      "y_m": [round(float((chosen[1][0] + lo[1]) * gl + phase[1]), 3), round(float((chosen[1][-1] + lo[1] + 1) * gl + phase[1]), 3)]}
            column_at[:] = column["x_m"] + column["y_m"] + [column["from_m"], column["to_m"]]
        rounds = None
        if "--round" in argv and z0 == 0.0:
            after = argv[argv.index("--round") + 1] if argv.index("--round") + 1 < len(argv) else "--"
            from_m = column["to_m"] if (after.startswith("--") and column) else (0.0 if after.startswith("--") else float(after))
            first = max(int(round(from_m / gl)) - int(lo[2]), 0)
            xs = (np.arange(n[0]) + lo[0] + 0.5) * gl + phase[0]
            ys = (np.arange(n[1]) + lo[1] + 0.5) * gl + phase[1]
            off_axis = np.hypot(xs[:, None], ys[None, :])
            rounds = []
            tri_ix = np.array(tris)
            ends_a = verts[np.concatenate([tri_ix[:, 0], tri_ix[:, 1], tri_ix[:, 2]])]
            ends_b = verts[np.concatenate([tri_ix[:, 1], tri_ix[:, 2], tri_ix[:, 0]])]
            rise = ends_b[:, 2] - ends_a[:, 2]
            for k in range(first, int(n[2])):
                # the fitted piece's outline at three heights of the level (a quarter, a half, three quarters): where
                # its triangles' edges cross them
                level = []
                for part in (0.25, 0.5, 0.75):
                    with np.errstate(divide="ignore", invalid="ignore"):
                        f = ((k + lo[2] + part) * gl - ends_a[:, 2]) / rise
                    cross = (rise != 0) & (f > 0) & (f < 1)
                    level.append(ends_a[cross] + (ends_b[cross] - ends_a[cross]) * f[cross][:, None])
                level = np.concatenate(level)
                cov[:, :, k] = 0.0
                occ[:, :, k] = False
                if not len(level):
                    continue
                reach_m = (float(np.ptp(level[:, 0])) + float(np.ptp(level[:, 1]))) / 4
                disc = off_axis <= max(reach_m, float(off_axis.min())) + 1e-6
                occ[:, :, k] = disc
                cov[:, :, k] = disc
                rounds.append({"at_m": round((k + int(lo[2])) * gl, 3), "reach_m": round(reach_m, 3), "cells": int(disc.sum())})
        # Members thinner than a cell (a chair's legs, a rail) cover no cell by half and would vanish. A cell is
        # filled all the same when it holds at least --thin of a cell (default 0.15), holds more than each of its
        # four neighbours across the member, none of which is filled, and the member goes on into the next cell
        # along its length (another such cell; or a filled cell on both sides, a one-cell bridge).
        rescued = np.zeros_like(occ)
        for axis in range(3):
            ua, va = [a_ for a_ in range(3) if a_ != axis]
            cand = np.zeros_like(occ)
            for idx in zip(*np.nonzero((cov >= cover_thin) & ~occ)):
                best = True
                for a_, d in ((ua, 1), (ua, -1), (va, 1), (va, -1)):
                    j = list(idx)
                    j[a_] += d
                    if 0 <= j[a_] < n[a_]:
                        if occ[tuple(j)] or cov[tuple(j)] > cov[idx] or (cov[tuple(j)] == cov[idx] and d < 0):
                            best = False
                            break
                cand[idx] = best
            for idx in zip(*np.nonzero(cand)):
                ends = []
                for d in (1, -1):
                    j = list(idx)
                    j[axis] += d
                    inside_grid = 0 <= j[axis] < n[axis]
                    ends.append("member" if inside_grid and cand[tuple(j)] else "mass" if inside_grid and occ[tuple(j)] else "nothing")
                # it goes on as a member on one side at least, or bridges two masses: a bump one cell deep on the
                # side of a mass (a mass on one side, nothing on the other) is not a member
                if "member" in ends or ends == ["mass", "mass"]:
                    rescued[idx] = True
        occ = occ | rescued
        if mirrored:
            # a thin member is filled in every mirror image (the rule above picks one of two cells that hold as much)
            alike = occ | occ[::-1] | occ[:, ::-1] | occ[::-1, ::-1]
            if occ.shape[0] == occ.shape[1] and phase[0] == phase[1]:
                alike = alike | alike.transpose(1, 0, 2)
            occ = alike
        # A sheet thinner than half a cell (a sign's panel in its frame, a pane) covers no cell by half either, and
        # is no member: it is as wide and as tall as the cell. (A sheet thinner than the cells of the closed
        # surface is not in that surface at all.) With --sheets F a cell is filled when, looking along x or along
        # y, at least F of the lines through it pass through the piece's own surface twice inside the cell: in
        # at one face of the sheet and out at the other. The side of a mass that ends in the cell is met once.
        sheeted = np.zeros_like(occ)
        if opt("--sheets"):
            across = float(opt("--sheets"))
            for idx in zip(*np.nonzero(~occ)):
                base = (np.array(idx) + lo) * gl + phase
                for axis in (0, 1):
                    ua, va = [a_ for a_ in range(3) if a_ != axis]
                    along = Vector([1.0 if a_ == axis else 0.0 for a_ in range(3)])
                    through = 0
                    for su in steps:
                        for sv in steps:
                            start = np.array(base, dtype=float)
                            start[ua] += su * gl
                            start[va] += sv * gl
                            first = surface.ray_cast(Vector(start), along, gl)
                            if first[0] is not None and gl - first[3] > 2e-4:
                                through += surface.ray_cast(first[0] + along * 1e-4, along, gl - first[3] - 1e-4)[0] is not None
                    if through >= across * per * per:
                        sheeted[idx] = True
                        break
            occ = occ | sheeted
        # Cubes that hang on nothing: of the groups of filled cells joined face to face, the largest is the piece,
        # and a group smaller than a twentieth of it is a crumb (what is left of a swatch, a speck of the rebuilt
        # surface).
        label = np.zeros(occ.shape, dtype=int)
        groups = []
        for start in zip(*np.nonzero(occ)):
            if label[start]:
                continue
            groups.append([])
            label[start] = len(groups)
            stack = [start]
            while stack:
                c = stack.pop()
                groups[-1].append(c)
                for a_ in range(3):
                    for d in (1, -1):
                        j = list(c)
                        j[a_] += d
                        j = tuple(j)
                        if 0 <= j[a_] < n[a_] and occ[j] and not label[j]:
                            label[j] = len(groups)
                            stack.append(j)
        largest = max((len(q) for q in groups), default=0)
        crumbs = 0
        for q in groups:
            if len(q) < 0.05 * largest:
                for c in q:
                    occ[c] = False
                crumbs += len(q)
        if drum:
            # A shrub's cubes stay inside 0.99 of its drum's radius, so the drum alone is what reaches the circle.
            for idx in zip(*np.nonzero(occ)):
                x0c, y0c = (np.array(idx[:2]) + lo[:2]) * gl + phase[:2]
                if max(abs(x0c), abs(x0c + gl)) ** 2 + max(abs(y0c), abs(y0c + gl)) ** 2 > (0.99 * drum[0]) ** 2:
                    occ[idx] = False
        # A crown's surface broken up, as the style's concept sheets draw foliage (cubes standing proud of their
        # neighbours, gaps between them): of the cells on the surface a share is left out, and of the empty cells
        # that touch it the same share is filled, by a fixed pattern of the cells' own places, so that the same
        # piece comes out every time. Only where asked for (--jumble, the coarse layer).
        jumbled = 0
        if jumble_here:
            def touches(mask):
                out_ = np.zeros_like(mask)
                for a_ in range(3):
                    for d in (1, -1):
                        shifted = np.roll(mask, d, axis=a_)
                        edge = [slice(None)] * 3
                        edge[a_] = 0 if d == 1 else -1
                        shifted[tuple(edge)] = False
                        out_ |= shifted
                return out_
            def pattern(idx):
                x, y, z = (int(v) for v in np.array(idx) + lo)
                h = ((x * 73856093) ^ (y * 19349663) ^ (z * 83492791)) & 0xFFFFFFFF
                h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
                return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0
            on_surface = occ & touches(~occ)
            beside = ~occ & touches(occ)
            for idx in zip(*np.nonzero(on_surface)):
                if pattern(idx) < jumble_here:
                    occ[idx] = False
                    jumbled += 1
            for idx in zip(*np.nonzero(beside)):
                if pattern(idx) > 1 - jumble_here and idx[2] > 0:          # not under the crown's lowest level
                    occ[idx] = True
                    jumbled += 1
    # A planted tree's cells are its trunk's or its leaves', by what the fitted piece has nearest each cell's middle.
    wood_cell = np.zeros_like(occ)
    if given is not None:
        wood_cell = occ.copy()
    elif planted and (len(layers) == 1 or wood_above is not None):          # the small cubes; a large cube is leaf
        for idx in zip(*np.nonzero(occ)):
            wood_cell[idx] = is_wood((np.array(idx) + lo + 0.5) * gl + phase)
    if given is None and trunk_arg:
        crown_cells.update(occ=occ, lo=lo, phase=phase, gl=gl, wood_left_out=wood_left_out,
                           tones=flat_tones(occ, lo, phase, gl) if opt("--tones") else None)
    if given is None and not trunk_arg and "--tone-cubes" in argv and opt("--tones"):
        report["tones"] = tone_cubes(occ, lo, phase, gl)
    # The faces between filled and empty, joined into the largest rectangles that fit (of one material each).
    found = []
    for axis in range(3):
        ua, va = [a_ for a_ in range(3) if a_ != axis]
        for side in (1, -1):
            for sl in range(n[axis]):
                index = [slice(None)] * 3
                index[axis] = sl
                here = occ[tuple(index)]
                wood_here = wood_cell[tuple(index)]
                t = sl + side
                if 0 <= t < n[axis]:
                    index[axis] = t
                    beyond = occ[tuple(index)]
                else:
                    beyond = np.zeros_like(here)
                shown = here & ~beyond
                if axis == 2 and side == -1 and sl + lo[2] == 0:
                    shown[:] = False                                 # the faces that lie on the ground
                plane = (sl + lo[axis] + (1 if side == 1 else 0)) * gl + phase[axis]
                lit = np.zeros_like(shown)
                if light_name and glow_pixels is not None:
                    # A lamp's glass is a part of its own: the cell faces the fitted piece's glow texture lights.
                    for u, v in zip(*np.nonzero(shown)):
                        point = np.zeros(3)
                        point[axis] = plane - side * 0.02 * gl
                        point[ua] = (u + lo[ua] + 0.5) * gl + phase[ua]
                        point[va] = (v + lo[va] + 0.5) * gl + phase[va]
                        lit[u, v] = glows_at(point)
                # A planted tree's leaves and trunk (--planted), or a lamp's glass and the rest of it (--light).
                for wood, glowing_part, mask in ((False, False, shown & ~wood_here & ~lit), (True, False, shown & wood_here & ~lit), (False, True, shown & lit)):
                    done = np.zeros_like(mask)
                    for u in range(mask.shape[0]):
                        for v in range(mask.shape[1]):
                            if not mask[u, v] or done[u, v]:
                                continue
                            w = 1
                            while u + w < mask.shape[0] and mask[u + w, v] and not done[u + w, v]:
                                w += 1
                            h = 1
                            while v + h < mask.shape[1] and mask[u:u + w, v + h].all() and not done[u:u + w, v + h].any():
                                h += 1
                            done[u:u + w, v:v + h] = True
                            found.append((axis, side, plane, (u + lo[ua]) * gl + phase[ua], (v + lo[va]) * gl + phase[va], w, h, gl, wood, glowing_part))
    numbers = {"grid_m": gl, "from_m": round(z0, 3), "cells": [int(v) for v in n], "filled": int(occ.sum()), "filled_as_thin_members": int(rescued.sum()), "filled_to_make_the_foot_solid": solid_added,
               **({"filled_as_sheets": int(sheeted.sum())} if opt("--sheets") else {}),
               "crumb_cells_dropped": crumbs, "cells_changed_by_jumble": jumbled, "grid_set_on": ["a cell's edge" if ph == 0 else "a cell's middle" for ph in phase[:2]]}
    if mirrored:
        numbers["made_alike_about_the_axis"] = True
    if column:
        numbers["column"] = column
    if rounds is not None:
        numbers["rounds"] = rounds
    if heaped:
        numbers["heap"] = heaped
    return found, numbers


rects, report["layers"] = [], []
jumble = float(opt("--jumble", "0"))
for z0, z1, gl, wood_above in ([] if trunk_arg else layers):
    found, numbers = layer_faces(z0, z1, gl, wood_above, jumble if (len(layers) > 1 and wood_above is None) else 0.0)
    rects += found
    report["layers"].append(numbers)
if trunk_arg:
    z0, z1, gl, _w = layers[1]
    found, numbers = layer_faces(z0, z1, gl, None, jumble)
    c_occ, c_lo, c_phase = crown_cells["occ"], crown_cells["lo"], crown_cells["phase"]
    n_side, foot_m = trunk_arg.split(",")
    n_side, foot_m = int(n_side), float(foot_m)
    if n_side % 2:
        sys.exit("--planted-trunk: an even number of cubes (the column stands with a cube's edge on the origin)")
    half = n_side // 2
    # The crown's lowest cube over each of the large cells the column stands under; the column rises to the
    # highest of them, so that none of its top shows.
    under = []
    for ci in range(c_occ.shape[0]):
        for cj in range(c_occ.shape[1]):
            x0, y0 = (ci + c_lo[0]) * gl + c_phase[0], (cj + c_lo[1]) * gl + c_phase[1]
            if x0 < half * g - 1e-6 and x0 + gl > -half * g + 1e-6 and y0 < half * g - 1e-6 and y0 + gl > -half * g + 1e-6:
                held = np.nonzero(c_occ[ci, cj, :])[0]
                if len(held):
                    under.append((int(held[0]) + c_lo[2]) * gl)
    top_m = max(under) if under else z0 + gl
    levels = int(round(top_m / g))
    reach_cells = half + 1
    t_occ = np.zeros((2 * reach_cells, 2 * reach_cells, levels), dtype=bool)
    t_occ[1:-1, 1:-1, :] = True                                           # the column
    ribs = min(int(round(foot_m / g)), levels)
    t_occ[:, reach_cells - 1:reach_cells + 1, :ribs] = True               # its foot's ribs, two cubes wide, one deep
    t_occ[reach_cells - 1:reach_cells + 1, :, :ribs] = True
    t_found, t_numbers = layer_faces(0.0, top_m, g, None, 0.0, given=(t_occ, np.array([-reach_cells, -reach_cells, 0]), np.zeros(3)))
    rects += t_found + found
    report["layers"] += [t_numbers, numbers]
    report["trunk"] = {"cubes_square": n_side, "ribs_to_m": round(ribs * g, 3), "rises_to_m": round(top_m, 3), "crown_cubes_over_it": len(under),
                       "wood_coloured_crown_cubes_left_out": crown_cells["wood_left_out"], "coloured_from_the_design_s_trunk": wood_surface is not None}
    if crown_cells.get("tones"):
        report["tones"] = crown_cells["tones"]
for key in ("filled", "filled_as_thin_members", "crumb_cells_dropped"):
    report[key] = sum(layer[key] for layer in report["layers"])
report["cells"] = report["layers"][0]["cells"]
report["grid_set_on"] = report["layers"][0]["grid_set_on"]
report["rectangles"] = len(rects)
report["cell_faces"] = int(sum(r[5] * r[6] for r in rects))

# ---- One block of pixels a cell face, the rectangles packed in rows ----
pad = 1
order = sorted(range(len(rects)), key=lambda r: (-rects[r][6], -rects[r][5]))
sizes = {r: (rects[r][5], rects[r][6]) for r in order}
if drum:
    sizes[len(rects)] = (1, 1)                      # one more block, for the drum's colour
    order.append(len(rects))
area = sum((sizes[r][0] * px + 2 * pad) * (sizes[r][1] * px + 2 * pad) for r in order)
side_px = 64
while side_px * side_px < area * 1.25 or side_px < max(sizes[r][0] for r in order) * px + 2 * pad:
    side_px *= 2
while True:
    x = y = row = 0
    place, fits = {}, True
    for r in order:
        w, h = sizes[r][0] * px + 2 * pad, sizes[r][1] * px + 2 * pad
        if x + w > side_px:
            x, y, row = 0, y + row, 0
        if y + h > side_px:
            fits = False
            break
        place[r] = (x + pad, y + pad)
        x, row = x + w, max(row, h)
    if fits:
        break
    side_px *= 2
atlas = np.zeros((side_px, side_px, 3))
glow_map = np.zeros((side_px, side_px, 3))
w_h0, w_h1, w_sat, w_val = (float(v) for v in opt("--warm", "28,62,0.42,0.62").split(","))
quads, quad_uvs, quad_wood, quad_lit, glowing = [], [], [], [], 0
sector_levels = {}
if opt("--sectors"):
    for layer in report["layers"]:
        for ring in layer.get("rounds", []):
            if ring["cells"] > 16:
                sector_levels[int(round(ring["at_m"] / layer["grid_m"]))] = True
striped = []                                     # (block x, block y, the cell's angle about the axis, its sampled colour)
of_the_column = []                               # (block x, block y, its sampled colour): the faces of the --column's cells
for r, (axis, side, plane, u0, v0, w, h, gl, wood, in_light) in enumerate(rects):
    ua, va = [a for a in range(3) if a != axis]
    ox, oy = place[r]
    for du in range(w):
        for dv in range(h):
            samples = []
            for su in (0.2, 0.5, 0.8):
                for sv in (0.2, 0.5, 0.8):
                    point = np.zeros(3)
                    point[axis] = plane - side * 0.02 * gl
                    point[ua] = u0 + (du + su) * gl
                    point[va] = v0 + (dv + sv) * gl
                    samples.append(texel_at(point, on=wood_surface) if (wood and wood_surface is not None) else colour_at(point))
            colour = np.median(np.array(samples), axis=0)
            if cell_tone and not wood:
                mid = np.zeros(3)
                mid[axis] = plane - side * 0.5 * gl
                mid[ua] = u0 + (du + 0.5) * gl
                mid[va] = v0 + (dv + 0.5) * gl
                colour = cell_tone.get(tuple(int(round(v / (g / 20))) for v in mid), colour)
            x0, y0 = ox + du * px, oy + dv * px
            if heap_colours or sector_levels or column_at:
                cell = np.zeros(3)                         # the middle of the cell this face belongs to
                cell[axis] = plane - side * 0.5 * gl
                cell[ua] = u0 + (du + 0.5) * gl
                cell[va] = v0 + (dv + 0.5) * gl
            if heap_colours:
                mine = heap_colours.get((int(round(cell[0] / gl * 2)), int(round(cell[1] / gl * 2))))
                if mine is not None and cell[2] > heap_from[0]:
                    colour = mine[1] if int(math.floor(cell[2] / gl + 1e-6)) >= mine[0] else mine[2]
            atlas[y0:y0 + px, x0:x0 + px] = colour
            if sector_levels and int(math.floor(cell[2] / gl + 1e-6)) in sector_levels:
                striped.append((x0, y0, math.degrees(math.atan2(cell[1], cell[0])) % 360, colour))
            if column_at and column_at[0] < cell[0] < column_at[1] and column_at[2] < cell[1] < column_at[3] and column_at[4] < cell[2] < column_at[5]:
                of_the_column.append((x0, y0, colour))
            if glow and in_light:
                glow_map[y0:y0 + px, x0:x0 + px] = colour             # the fitted piece's glow texture is lit here
                glowing += 1
            elif glow and glow_pixels is None:
                mx, mn = colour.max(), colour.min()
                hue = math.degrees(math.atan2(math.sqrt(3) * (colour[1] - colour[2]), 2 * colour[0] - colour[1] - colour[2])) % 360
                if w_h0 < hue < w_h1 and (mx - mn) / max(mx, 1e-4) > w_sat and mx > w_val:
                    glow_map[y0:y0 + px, x0:x0 + px] = colour
                    glowing += 1
    # the border round the block repeats its edge, so nothing bleeds in from a neighbour
    x0, y0, x1, y1 = ox, oy, ox + w * px, oy + h * px
    for image_ in (atlas, glow_map):
        image_[y0 - pad:y0, x0:x1] = image_[y0:y0 + 1, x0:x1]
        image_[y1:y1 + pad, x0:x1] = image_[y1 - 1:y1, x0:x1]
        image_[y0 - pad:y1 + pad, x0 - pad:x0] = image_[y0 - pad:y1 + pad, x0:x0 + 1]
        image_[y0 - pad:y1 + pad, x1:x1 + pad] = image_[y0 - pad:y1 + pad, x1 - 1:x1]
    corners = []
    for cu, cv in ((0, 0), (w, 0), (w, h), (0, h)):
        p = np.zeros(3)
        p[axis] = plane
        p[ua] = u0 + cu * gl
        p[va] = v0 + cv * gl
        corners.append((tuple(p), ((ox + cu * px) / side_px, (oy + cv * px) / side_px)))
    # wound so that the face looks out of the piece
    normal = np.cross(np.array(corners[1][0]) - np.array(corners[0][0]), np.array(corners[3][0]) - np.array(corners[0][0]))
    if normal[axis] * side < 0:
        corners = [corners[0], corners[3], corners[2], corners[1]]
    if opt("--tuck"):
        tuck = [float(v) for v in opt("--tuck").split(",")]
        keep = 1.0 - (tuck[1] if len(tuck) > 1 else 0.03)
        corners = [((tuple(float(v) * keep for v in c[0]) if c[0][2] < tuck[0] - 1e-9 else c[0]), c[1]) for c in corners]
    quads.append([c[0] for c in corners])
    quad_uvs.append([c[1] for c in corners])
    quad_wood.append(wood)
    quad_lit.append(in_light)
def borders_again():
    """The border round each block repeats its edge once more: blocks repainted after the loop above."""
    for r_, rect in enumerate(rects):
        x0_, y0_ = place[r_]
        x1_, y1_ = x0_ + rect[5] * px, y0_ + rect[6] * px
        atlas[y0_ - pad:y0_, x0_:x1_] = atlas[y0_:y0_ + 1, x0_:x1_]
        atlas[y1_:y1_ + pad, x0_:x1_] = atlas[y1_ - 1:y1_, x0_:x1_]
        atlas[y0_ - pad:y1_ + pad, x0_ - pad:x0_] = atlas[y0_ - pad:y1_ + pad, x0_:x0_ + 1]
        atlas[y0_ - pad:y1_ + pad, x1_:x1_ + pad] = atlas[y0_ - pad:y1_ + pad, x1_ - 1:x1_]


if of_the_column:
    # A column built by rule is one colour, the middle one of what its faces took from the fitted piece: where
    # the generator set a collar under a table's top, or a knuckle on a pole, the cubes there took its colour.
    one = np.median(np.array([c for _x, _y, c in of_the_column]), axis=0)
    for x0, y0, _c in of_the_column:
        atlas[y0:y0 + px, x0:x0 + px] = one
    borders_again()
    report["column_colour"] = "#%02X%02X%02X" % tuple(int(round(float(v) * 255)) for v in np.clip(one, 0, 1))
if striped:
    # The two colours the rounds mostly have (two means by lightness), and the sectors painted turn about.
    count = int(opt("--sectors"))
    tones = np.array([c for _x, _y, _a, c in striped])
    light = tones @ np.array([0.2126, 0.7152, 0.0722])
    split = float(np.median(light))
    for _ in range(12):
        dark, pale = tones[light <= split], tones[light > split]
        if not len(dark) or not len(pale):
            break
        split = float((dark @ np.array([0.2126, 0.7152, 0.0722])).mean() + (pale @ np.array([0.2126, 0.7152, 0.0722])).mean()) / 2
    dark, pale = tones[light <= split], tones[light > split]
    if len(dark) and len(pale):
        pair = [np.median(dark, axis=0), np.median(pale, axis=0)]
        if len(pale) > len(dark):
            pair = pair[::-1]                              # the commoner colour first: it takes the sector along +x
        step = 360.0 / count
        for x0, y0, angle, _c in striped:
            atlas[y0:y0 + px, x0:x0 + px] = pair[int(((angle + step / 2) % 360) // step) % 2]
        borders_again()
        report["sectors"] = {"count": count, "cell_faces": len(striped), "colours": ["#%02X%02X%02X" % tuple(int(round(float(v) * 255)) for v in np.clip(c, 0, 1)) for c in pair]}
if drum:
    # The drum: its sides and its top, all laid on one block of the texture, in the darker of the leaf tones
    # (the tone a quarter of the way up the cubes' own, by lightness).
    radius, height = drum[0], drum[1]
    sides = int(drum[2]) if len(drum) > 2 else 32
    tones = np.array([atlas[place[r][1] + dv * px, place[r][0] + du * px] for r in range(len(rects)) for du in range(rects[r][5]) for dv in range(rects[r][6])])
    green = tones[(tones[:, 1] > tones[:, 2] * 1.15) & (tones[:, 1] >= tones[:, 0] * 0.9)]
    pool = green if len(green) > 10 else tones
    tone = pool[np.argsort(pool @ np.array([0.2126, 0.7152, 0.0722]))[len(pool) // 4]]
    if "--tone-cubes" in argv and (report.get("tones") or {}).get("greens"):
        # with the cubes in the sheet's own greens, the drum in the middle one of them: in the darkest its
        # side, which the game shades, came out near black
        greens_ = report["tones"]["greens"]
        tone = hex_rgb(greens_[len(greens_) // 2])
    ox, oy = place[len(rects)]
    atlas[oy - pad: oy + px + pad, ox - pad: ox + px + pad] = tone
    spot = ((ox + px / 2) / side_px, (oy + px / 2) / side_px)
    ring = [(radius * math.cos(2 * math.pi * k / sides), radius * math.sin(2 * math.pi * k / sides)) for k in range(sides)]
    drum_faces = []
    for k in range(sides):
        a, b = ring[k], ring[(k + 1) % sides]
        drum_faces.append([(a[0], a[1], 0.0), (b[0], b[1], 0.0), (b[0], b[1], height), (a[0], a[1], height)])
        drum_faces.append([(0.0, 0.0, height), (a[0], a[1], height), (b[0], b[1], height)])
    report["drum"] = {"radius_m": radius, "height_m": height, "sides": sides, "triangles": 3 * sides,
                      "colour": "#%02X%02X%02X" % tuple(int(round(float(v) * 255)) for v in tone)}
else:
    drum_faces, spot = [], None
report["texture_px"] = side_px
report["glowing_cell_faces"] = glowing

# ---- The mesh, its material, the file ----
def mesh_of(name, which, more=()):
    """A mesh of the cell faces numbered `which`, and of `more` faces (a shrub's drum: each a list of corners),
    which all take the one spot of the texture kept for them."""
    made = bpy.data.meshes.new(name)
    faces = [tuple(range(4 * k, 4 * k + 4)) for k in range(len(which))]
    at = 4 * len(which)
    for f in more:
        faces.append(tuple(range(at, at + len(f))))
        at += len(f)
    made.from_pydata([p for i in which for p in quads[i]] + [p for f in more for p in f], [], faces)
    layer = made.uv_layers.new(name="UVMap")
    for k, i in enumerate(which):
        for j, uv in enumerate(quad_uvs[i]):
            layer.data[4 * k + j].uv = uv
    for li in range(4 * len(which), len(made.loops)):
        layer.data[li].uv = spot
    made.update()
    return made


def as_image(name, array):
    img = bpy.data.images.new(name, side_px, side_px, alpha=False)
    rgba = np.concatenate([array, np.ones((side_px, side_px, 1))], axis=2)
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    img.filepath_raw = str(out.with_suffix(f".{name}.png"))
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def material(name, emits):
    made = bpy.data.materials.new(name)
    made.use_nodes = True
    nodes, links = made.node_tree.nodes, made.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = float(opt("--rough", "0.9"))
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = albedo_image
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emits:
        etex = nodes.new("ShaderNodeTexImage")
        etex.image = emission_image
        etex.interpolation = "Closest"
        links.new(etex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    return made


if light_name or planted:
    for used in bpy.data.materials:
        used.name = "fitted " + used.name          # the fitted piece's own: a new material of the same name would come out as `name.001`
in_part = [i for i in range(len(quads)) if quad_lit[i]] if light_name else []
rest = [i for i in range(len(quads)) if not (light_name and quad_lit[i])]
mesh = mesh_of(mesh_name, rest, drum_faces)
albedo_image = as_image("albedo", atlas)
emission_image = as_image("emission", glow_map) if glow and glowing else None
split = bool(light_name and in_part)
mat = material("cubes" if (split or not glow) else glow, bool(glow and glowing and not split))
mesh.materials.append(mat)
if planted:
    # The trunk's faces in a second material, a copy of the first with the trunk's name: the game reads the name.
    mat.name = opt("--leaf-material", "leaf") if trunk_arg else next(nm for nm, leafy in zip(slot_names, leaf_slots) if leafy)
    wood_mat = mat.copy()
    wood_mat.name = opt("--wood-material", "trunk") if trunk_arg else next(nm for nm, leafy in zip(slot_names, leaf_slots) if not leafy)
    mesh.materials.append(wood_mat)
    for k, i in enumerate(rest):
        mesh.polygons[k].material_index = 1 if quad_wood[i] else 0
    band = [np.hypot(p[0], p[1]) for q, wood in zip(quads, quad_wood) if wood for p in q if 0.15 - 1e-6 <= p[2] <= 2.2 + 1e-6]
    # a face that crosses the band's top or foot counts by where it crosses, which is as far out as its corners
    band += [np.hypot(p[0], p[1]) for q, wood in zip(quads, quad_wood) if wood and min(c[2] for c in q) < 2.2 < max(c[2] for c in q) for p in q]
    band += [np.hypot(p[0], p[1]) for q, wood in zip(quads, quad_wood) if wood and min(c[2] for c in q) < 0.15 < max(c[2] for c in q) for p in q]
    reach_m = float(max(band)) if band else 0.0
    report["planted"] = {"materials": [mat.name, wood_mat.name], "trunk_reach_m": round(reach_m, 3), "width_scale_in_game": round(0.25 / reach_m, 3) if reach_m > 1e-3 else None,
                         "trunk_cell_faces": int(sum(1 for w_ in quad_wood if w_)), "leaf_cell_faces": int(sum(1 for w_ in quad_wood if not w_))}
for o in list(bpy.data.objects):
    if o is not kept:
        bpy.data.objects.remove(o, do_unlink=True)
root = bpy.data.objects.new(root_name, None)
body = bpy.data.objects.new(mesh_name, mesh)
bpy.context.scene.collection.objects.link(root)
bpy.context.scene.collection.objects.link(body)
body.parent = root
if kept is not None:
    kept_co = np.array([v.co[:] for v in kept.data.vertices])
    bpy.ops.object.select_all(action="DESELECT")
    kept.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = mesh_name
    body.data.name = mesh_name
if split:
    light_mesh = mesh_of(light_name, in_part)
    light_mesh.materials.append(material(glow, True))
    light = bpy.data.objects.new(light_name, light_mesh)
    bpy.context.scene.collection.objects.link(light)
    light.parent = root
    co_l = np.array([p for i in in_part for p in quads[i]])
    report["light_part"] = {"name": light_name, "tris": 2 * len(in_part), "middle_m": [round(float(v), 3) for v in (co_l.min(axis=0) + co_l.max(axis=0)) / 2]}
elif light_name:
    report["light_part"] = None
out.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_yup=True, export_apply=True, export_image_format="AUTO")
report["tris"] = 2 * len(quads) + (3 * len(drum_faces) // 2 if drum_faces else 0) + (report["kept_as_it_is"]["tris"] if kept is not None else 0)
report["bytes"] = out.stat().st_size
co = np.array([p for q in quads for p in q] + [p for f in drum_faces for p in f])
if kept is not None and len(kept_co):
    co = np.concatenate([co, kept_co])
report["box_min"] = [round(float(v), 3) for v in co.min(axis=0)]
report["box_max"] = [round(float(v), 3) for v in co.max(axis=0)]
print("VOXEL " + json.dumps(report))
if opt("--report"):
    Path(opt("--report")).write_text(json.dumps(report, indent=1) + "\n")
