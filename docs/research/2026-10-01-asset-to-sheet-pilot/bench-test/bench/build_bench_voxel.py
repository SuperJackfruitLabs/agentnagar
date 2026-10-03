"""The voxel pack's bench (v2/bench.glb), drawn as its sheet draws it and painted from the sheet's colours.

    blender --background --factory-startup --python bench/build_bench_voxel.py -- OUT.glb [PARAMS.json]

The sheet's bench is a thick slab of orange blocks on grey stone legs with a low back of the same blocks; the
kit's is thin striped slats on a charcoal frame with arms. This one is on the kit's 0.1 m grid, in 0.2 m
blocks that each keep their own faces and take their own tone (the kit's writer merges like faces into
slabs), its seat top 0.5 m up as the kit's. It is 1.6 m by 0.6 m where people walk, the catalogue's bench
footprint, which the game then stretches 4% in depth to the cells its walking grid blocks (the kit's bench is
1.8 m by 0.7 m, and the game squeezes it by a ninth). Colours are vertex colours on one material, where the kit
writes a material a palette colour. Blender is used for the painting (shade.py, through marks.py) and the
export only.
"""
import json
import os
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out = Path(argv[0])
HERE = Path(__file__).resolve().parent
TOOLS = HERE.parent
ROOT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
STYLE = json.loads((TOOLS / "city" / "godot" / "styles" / "voxel" / "style.json").read_text())
CONFIG = json.loads((HERE / "asset.json").read_text())
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(ROOT / "shared"))
sys.path.insert(0, str(ROOT / "voxel"))
import palette  # noqa: E402
import voxel  # noqa: E402
import bake  # noqa: E402
import marks  # noqa: E402
import shade  # noqa: E402

P = marks.settings(STYLE)
# Blocks: tops in the ramp's light half, sides across its middle; the stone legs dark.
P.update({"ao_share": 0.4, "tops": [0.55, 1.0], "sides": [0.2, 0.8], "under": [0.0, 0.2],
          "ranges": {"frame": {"tops": [0.3, 0.85], "sides": [0.0, 0.7], "under": [0.0, 0.2]}},
          "weights": {"timber": {"up": {"facing": 0.0, "sky": 0.25, "group": 0.65, "grain": 0.1},
                                 "rest": {"facing": 0.35, "sky": 0.2, "group": 0.4, "grain": 0.05}},
                      "frame": {"up": {"facing": 0.5, "sky": 0.3, "group": 0.2, "grain": 0.0},
                                "rest": {"facing": 0.5, "sky": 0.3, "group": 0.2, "grain": 0.0}}}})
if len(argv) > 1 and Path(argv[1]).exists():
    P.update(json.loads(Path(argv[1]).read_text()))

ramps = json.loads((HERE / "ramps.json").read_text())["voxel"]
bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
col = bm.loops.layers.float_color.new("Col")
entries = []
B = 0.2                                  # a block: two of the kit's voxels


def base(key):
    return [shade.lin(c) for c in voxel.hex_rgb(voxel.resolve(key, palette.PALETTE))]


def quad(corners, outward, kind, part, key):
    f = bm.faces.new([bm.verts.new(c) for c in corners])
    f.normal_update()
    if f.normal.dot(Vector(outward)) < 0:
        f.normal_flip()
    for loop in f.loops:
        loop[col] = (*base(key), 1.0)
    lo, hi = marks.where(outward[2], kind, P)
    entries.append((kind, part, 0.0, lo, hi, 1.0))


def cuts(a, b, step, first=None):
    """The edges of the tiles from a to b: whole steps, with a shorter first one if `first` says so."""
    out_, x = [a], a + (first if first else step)
    while x < b - 1e-6:
        out_.append(x); x += step
    return out_ + [b]


def face(axis, at, u, v, outward, kind, tag, key):
    """A wall of tiles on the plane axis = at: `u` and `v` are the tile edges along the other two axes."""
    for i in range(len(u) - 1):
        for j in range(len(v) - 1):
            pts = [(u[i], v[j]), (u[i + 1], v[j]), (u[i + 1], v[j + 1]), (u[i], v[j + 1])]
            corners = [{0: (at, a, b), 1: (a, at, b), 2: (a, b, at)}[axis] for a, b in pts]
            quad(corners, outward, kind, (tag, i, j), key)


# Blender axes: x along the bench, +y the way the sitter faces (Godot -z), z up.
X = cuts(-0.8, 0.8, B)
# The seat: a slab one block thick, 0.6 m deep, its top 0.5 m up; the back stands on its rear 0.1 m.
face(2, 0.5, X, cuts(-0.25, 0.25, B, first=0.1), (0, 0, 1), "timber", "seat-top", "wood_light")
face(1, 0.25, X, [0.3, 0.5], (0, 1, 0), "timber", "seat-front", "wood")
for x, n in ((-0.8, -1), (0.8, 1)):
    face(0, x, cuts(-0.35, 0.25, B), [0.3, 0.5], (n, 0, 0), "timber", ("seat-end", n), "wood")
    face(0, x, [-0.35, -0.25], cuts(0.5, 0.9, B), (n, 0, 0), "timber", ("back-end", n), "wood")
face(2, 0.3, [-0.8, 0.8], [-0.35, 0.25], (0, 0, -1), "timber", "seat-under", "wood_dark")
# The back: 0.1 m thick, two blocks tall.
face(1, -0.25, X, cuts(0.5, 0.9, B), (0, 1, 0), "timber", "back-front", "wood")
face(2, 0.9, X, [-0.35, -0.25], (0, 0, 1), "timber", "back-top", "wood_light")
face(1, -0.35, X, cuts(0.3, 0.9, B), (0, -1, 0), "timber", "rear", "wood")
# Four stone legs, a block square, set in from the ends.
for x0 in (-0.7, 0.5):
    for y0 in (-0.25, 0.05):
        tag = ("leg", x0, y0)
        face(0, x0, [y0, y0 + B], [0.0, 0.3], (-1, 0, 0), "frame", tag + (0,), "stone_dark")
        face(0, x0 + B, [y0, y0 + B], [0.0, 0.3], (1, 0, 0), "frame", tag + (1,), "stone_dark")
        face(1, y0, [x0, x0 + B], [0.0, 0.3], (0, -1, 0), "frame", tag + (2,), "stone_dark")
        face(1, y0 + B, [x0, x0 + B], [0.0, 0.3], (0, 1, 0), "frame", tag + (3,), "stone_dark")

me = bpy.data.meshes.new("seat")
bm.normal_update()
bm.to_mesh(me)
bm.free()
for p in me.polygons:
    p.use_smooth = False
me.materials.append(bake._vertex_colour_material("baked_r85_m0", 0.85))
me.color_attributes.active_color = me.color_attributes["Col"]
root = bpy.data.objects.new("bench", None)
seat = bpy.data.objects.new("seat", me)
for o in (root, seat):
    bpy.context.scene.collection.objects.link(o)
seat.parent = root
bpy.context.view_layer.update()
stats = marks.paint({"seat": entries}, ramps, STYLE, P, CONFIG["kinds"])
out.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_yup=True, export_apply=True,
                          export_animations=False, export_cameras=False, export_lights=False, export_extras=False,
                          export_skins=False, export_morph=False)
tris = sum(len(p.vertices) - 2 for p in me.polygons)
print(f"BUILD bench voxel: wrote {out} ({tris} triangles, {len(me.polygons)} tiles) {json.dumps(stats)}")
