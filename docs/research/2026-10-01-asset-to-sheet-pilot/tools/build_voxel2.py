"""Round 2, voxel: the pack's `tree_large.glb` from the blocks a generated tree
fills, as in round 1, with the surface and colour reworked.

    blender --background --factory-startup --python build_voxel2.py -- PARTS_DIR NAME OUT.glb [PARAMS.json]

Round 1 wrote the tree with the voxel kit's own writer: three palette greens,
each face within 5% of its key, like faces merged into large flat quads. This
build keeps the kit's grid, block sizes, root skirt and trunk meshing, and
changes what round 1 left alone:

  * every leaf block keeps its own faces, so the crown reads as cubes, as the
    sheet draws it, not as merged slabs; a few blocks are cut out of the
    surface and a few set proud of it;
  * leaves and bark are painted from the sheet's own colours (ramps.json):
    block tops in the ramp's light half, sides by how they face the painted
    light, undersides dark, each block a little lighter or darker than the
    next; the game's light at the sheet's hour is partly taken back out
    (shade.py);
  * faces that see little sky are darkened.

The colours are vertex colours on one material, where the kit writes one
material per palette key. Runs in Blender only for the painting and export.
"""
import json
import os
import random
import sys
from pathlib import Path

import bmesh
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
parts, name, out = Path(argv[0]), argv[1], Path(argv[2])
HERE = Path(__file__).resolve().parent
ROOT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
STYLE = json.loads((HERE / "city" / "godot" / "styles" / "voxel" / "style.json").read_text())
P = {"take_out": 0.85, "gain_leaf": 1.0, "gain_wood": 1.0, "floor": 0.6, "ao_share": 0.4, "e_ref": 0.8,
     # The sheet lights its cubes from the upper left: faces to the west light, to the south
     # (the street's viewer) mid, to the east dark, so neighbouring faces differ.
     "channel": {}, "curve": {}, "class_gain": {}, "stop_gain": {}, "painted": [-0.8, -0.25, 0.55], "slope": 0.16,
     "cut": 0.2, "proud": 0.12, "top": [0.35, 1.0], "side": [0.03, 0.95], "under": [0.0, 0.22], "minute": 780,
     "crown_from": 3.5, "stub": 1.3,
     "weights": {"leaf": {"up": {"group": 0.3, "sky": 0.3, "extra": 0.3, "grain": 0.1, "facing": 0.0},
                          "rest": {"facing": 0.6, "group": 0.12, "sky": 0.13, "extra": 0.15, "grain": 0.0}},
                 "wood": {"up": {"facing": 0.2, "sky": 0.5, "extra": 0.2, "grain": 0.1},
                          "rest": {"facing": 0.6, "sky": 0.2, "extra": 0.15, "grain": 0.05}}}}
if len(argv) > 3 and Path(argv[3]).exists():
    P.update(json.loads(Path(argv[3]).read_text()))
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / "shared"))
sys.path.insert(0, str(ROOT / "voxel"))
import palette  # noqa: E402
import props  # noqa: E402
import voxel  # noqa: E402
from shapes import new  # noqa: E402
from voxel import Asset, unit  # noqa: E402
import bake  # noqa: E402
import shade  # noqa: E402

occ = json.loads((parts / f"{name}-blocks.json").read_text())
colours = json.loads((parts / f"{name}-colours.json").read_text())
ramps = json.loads((HERE / "ramps.json").read_text())["voxel"]
W_, L = round(occ["wood_step"] / voxel.VOXEL), round(occ["leaf_step"] / voxel.VOXEL)   # 2 and 7 cells
SEED = "tree_large"
BAND = (0.25, 1.9)                      # metres: where people walk
HALF = props.ROOT_HALF                  # the great tree's square, half a side in cells

bpy.ops.wm.read_factory_settings(use_empty=True)

# ---- Trunk, limbs and root skirt: the kit's grid and greedy meshing, as round 1 ----
g = new()
wood = {tuple(b) for b in occ["wood"]}
foot = [max(abs(i * W_), abs(i * W_ + W_), abs(k * W_), abs(k * W_ + W_)) for (i, j, k) in wood if j * W_ < 6]
trunk_half = max(4, min(12, sorted(foot)[len(foot) // 2] if foot else 4))
props._root_skirt(g, HALF, trunk_half, SEED)
# The trunk's axis, from the wood between 1 and 2 m up.
mid = [(i, k) for (i, j, k) in wood if 1.0 <= j * W_ * voxel.VOXEL <= 2.0]
ax_i = sorted(i for i, _k in mid)[len(mid) // 2] if mid else 0
ax_k = sorted(k for _i, k in mid)[len(mid) // 2] if mid else 0
shelf = 0
for (i, j, k) in sorted(wood):
    lo, hi = j * W_ * voxel.VOXEL, (j * W_ + W_) * voxel.VOXEL
    reach = max(abs(i * W_), abs(i * W_ + W_), abs(k * W_), abs(k * W_ + W_))
    if hi > BAND[0] and lo < BAND[1] and reach > HALF:
        continue   # would stand in people's way outside the tree's square
    # Under the crown the sheet's tree is a straight, thick trunk with short stubs: the
    # generated limbs' flat spread just below the leaves is cut back to 1.3 m of the axis.
    out_ = max(abs(i - ax_i), abs(k - ax_k)) * W_ * voxel.VOXEL
    if BAND[1] < lo < P["crown_from"] + 0.3 and out_ > P["stub"]:
        shelf += 1
        continue
    g.box(i * W_, j * W_, k * W_, i * W_ + W_, j * W_ + W_, k * W_ + W_, "trunk_dark" if (i + k + j // 2) % 5 == 0 else "trunk")
# ---- Which leaf blocks stand ----
leaf = {tuple(b) for b in occ["leaf"] if b[1] * L * voxel.VOXEL >= 3.5}   # the crown starts at 3.5 m, as round 1
NEIGH = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))   # (i, j, k): j is up
rng = random.Random(23)
surface = [b for b in sorted(leaf) if any((b[0] + d[0], b[1] + d[1], b[2] + d[2]) not in leaf for d in NEIGH)]
# A few blocks cut out of the surface (only where leaf stands behind every open side, so no
# hole opens into the crown), and a few set proud of it: the sheet's crown is stepped.
cut = set()
for b in surface:
    opens = [d for d in NEIGH if (b[0] + d[0], b[1] + d[1], b[2] + d[2]) not in leaf]
    backed = all((b[0] - d[0], b[1] - d[1], b[2] - d[2]) in leaf for d in opens)
    if backed and len(opens) <= 2 and unit(SEED, "cut", *b) < P["cut"]:
        cut.add(b)
proud = set()
for b in surface:
    if b in cut:
        continue
    for d in NEIGH:
        n = (b[0] + d[0], b[1] + d[1], b[2] + d[2])
        if d[1] >= 0 and n not in leaf and n[1] * L * voxel.VOXEL >= 3.5 and unit(SEED, "proud", *n) < P["proud"] / 3:
            proud.add(n)
blocks = (leaf - cut) | proud
# The leaf blocks go into the kit's grid too, so it leaves out the wood they bury; their own
# faces are not taken from it (it would merge them into slabs).
for (i, j, k) in sorted(blocks):
    g.box(i * L, j * L, k * L, i * L + L, j * L + L, k * L + L, "leaf")
a = Asset("tree_large")
a.part("tree", g)
kit_mesh = {k: v for k, v in a.meshes()[0][1].items() if not voxel.base_key(k).startswith("leaf")}


bm = bmesh.new()
col = bm.loops.layers.float_color.new("Col")
entries = []                            # one paint entry per face, in order


def tint(key):
    return [shade.lin(c) for c in voxel.hex_rgb(voxel.resolve(key, palette.PALETTE))]


wood_var = shade.local_variation(colours["wood"]["points"], colours["wood"]["colours"], 6, 120)
leaf_var = shade.local_variation(colours["leaf"]["points"], colours["leaf"]["colours"], 10, 300)
for key in sorted(kit_mesh):
    pos, _nor, idx = kit_mesh[key][:3]
    vs = [bm.verts.new((p[0], -p[2], p[1])) for p in pos]
    rgb = tint(key)
    for t in range(0, len(idx), 3):
        try:
            f = bm.faces.new([vs[idx[t]], vs[idx[t + 1]], vs[idx[t + 2]]])
        except ValueError:
            continue
        for loop in f.loops:
            loop[col] = (*rgb, 1.0)
        base = voxel.base_key(key)
        if base in ("trunk", "trunk_dark"):
            c = f.calc_center_median()
            entries.append(("wood", None, wood_var(c), 0.0, 0.6 if base == "trunk_dark" else 1.0, 1.0))
        else:
            entries.append(None)
wood_faces = len(entries)

# ---- Leaves: every block its own faces ----
s = L * voxel.VOXEL
CORNERS = {   # the four corners of a block's face toward each neighbour, counter-clockwise from outside (i, j, k)
    (1, 0, 0): ((1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)), (-1, 0, 0): ((0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)),
    (0, 1, 0): ((0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)), (0, -1, 0): ((0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)),
    (0, 0, 1): ((0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)), (0, 0, -1): ((0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)),
}
green = tint("leaf")
leaf_quads = 0
for b in sorted(blocks):
    centre = ((b[0] + 0.5) * s, -(b[2] + 0.5) * s, (b[1] + 0.5) * s)        # Blender axes
    # Its lean lighter or darker: the generated model's, and its clump's (blocks in twos).
    var = max(-1.0, min(1.0, 0.5 * leaf_var(centre) + 1.4 * (unit(SEED, "clump", b[0] // 2, b[1] // 2, b[2] // 2) - 0.5)))
    for d in NEIGH:
        if (b[0] + d[0], b[1] + d[1], b[2] + d[2]) in blocks:
            continue
        quad = [bm.verts.new(((b[0] + c[0]) * s, -(b[2] + c[2]) * s, (b[1] + c[1]) * s)) for c in CORNERS[d]]
        f = bm.faces.new(quad)
        f.normal_update()
        if f.normal.dot((d[0], -d[2], d[1])) < 0:
            f.normal_flip()
        for loop in f.loops:
            loop[col] = (*green, 1.0)
        lo, hi = P["top"] if d[1] > 0 else (P["under"] if d[1] < 0 else P["side"])
        entries.append(("leaf", b, var, lo, hi, 1.0))
        leaf_quads += 1

me = bpy.data.meshes.new("tree")
bm.normal_update()
bm.to_mesh(me)
bm.free()
for p in me.polygons:
    p.use_smooth = False
me.materials.append(bake._vertex_colour_material("baked_r85_m0", 0.85))
me.color_attributes.active_color = me.color_attributes["Col"]
root = bpy.data.objects.new("tree_large", None)
tree = bpy.data.objects.new("tree", me)
for o in (root, tree):
    bpy.context.scene.collection.objects.link(o)
tree.parent = root
bpy.context.view_layer.update()

sun_now, ambient_now = shade.light_at(STYLE, P["minute"])
stats = shade.shade_scene(paint={"tree": entries}, ramps=ramps, floor=P["floor"], ambient=ambient_now, sun_energy=sun_now,
                          ao_share=P["ao_share"], take_out=P["take_out"], e_ref=P["e_ref"], weights=P["weights"],
                          gain={"leaf": P["gain_leaf"], "wood": P["gain_wood"]}, channel=P["channel"],
                          curve=P["curve"], class_gain=P["class_gain"], stop_gain=P["stop_gain"], painted=P["painted"])
# Each leaf face runs a little lighter toward the painted light (up a side face, toward the
# light across a top), so a cube reads as a cube with one face in view, as the sheet shades them.
from mathutils import Vector  # noqa: E402
light = Vector(P["painted"]).normalized()
attr = me.color_attributes["Col"]
for p, entry in zip(me.polygons, entries):
    if entry is None or entry[0] != "leaf":
        continue
    along = light - p.normal * light.dot(p.normal)          # the light's direction in the face's plane
    if along.length < 1e-6:
        continue
    along.normalize()
    for li, vi in zip(p.loop_indices, p.vertices):
        k = 1.0 + P["slope"] * (me.vertices[vi].co - p.center).dot(along) / (0.5 * s)
        c = attr.data[li].color
        attr.data[li].color = (min(1.0, c[0] * k), min(1.0, c[1] * k), min(1.0, c[2] * k), 1.0)
out.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_yup=True, export_apply=True,
                          export_animations=False, export_cameras=False, export_lights=False, export_extras=False,
                          export_skins=False, export_morph=False)
tris = sum(len(p.vertices) - 2 for p in me.polygons)
print(f"BUILD voxel2: wrote {out} ({tris} triangles, {len(blocks)} leaf blocks ({len(cut)} cut, {len(proud)} proud), "
      f"{leaf_quads} leaf faces, {wood_faces} wood and skirt triangles, {shelf} limb blocks under the crown cut back) {json.dumps(stats)}")
