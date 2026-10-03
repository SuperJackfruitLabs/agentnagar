"""The voxel pack's planter (v2/planter.glb), drawn as its sheet draws it and painted from the sheet's colours.

    blender --background --factory-startup --python planter/build_planter_voxel.py -- OUT.glb [PARAMS.json]

The kit's planter is a grey box with a mound the kit's writer merges into a few large stepped slabs. The
sheet's is a grey block box under a heap of small green cubes, white blossom cubes among them. This one is on
the kit's 0.1 m grid and of the kit's size (1.2 m square, the box 0.5 m tall): the box in 0.2 m tiles, a heap
of 0.2 m leaf cubes that each keep their own faces and take their own tone, a few white cubes on top. Colours
are vertex colours on one material, where the kit writes a material a palette colour. Blender is used for the
painting (shade.py, through marks.py) and the export only.
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
from voxel import unit  # noqa: E402
import bake  # noqa: E402
import marks  # noqa: E402
import shade  # noqa: E402

P = marks.settings(STYLE)
P.update({"ao_share": 0.4, "tops": [0.5, 1.0], "sides": [0.1, 0.75], "under": [0.0, 0.2],
          "ranges": {"box": {"tops": [0.5, 1.0], "sides": [0.1, 0.8], "under": [0.0, 0.2]}},
          "weights": {"leaf": {"up": {"facing": 0.0, "sky": 0.3, "group": 0.6, "grain": 0.1},
                               "rest": {"facing": 0.4, "sky": 0.2, "group": 0.35, "grain": 0.05}},
                      "box": {"up": {"facing": 0.2, "sky": 0.3, "group": 0.4, "grain": 0.1},
                              "rest": {"facing": 0.5, "sky": 0.2, "group": 0.25, "grain": 0.05}}}})
if len(argv) > 1 and Path(argv[1]).exists():
    P.update(json.loads(Path(argv[1]).read_text()))
ramps = json.loads((HERE / "ramps.json").read_text())["voxel"]
SEED = "planter"
C = voxel.VOXEL                              # the kit's cell, 0.1 m

# ---- Blocks, in cells (i along x, j up, k along the kit's z): (i0, j0, k0, i1, j1, k1, kind, palette key) ----
blocks = []
for i in range(-6, 6, 2):                    # the box: 0.2 m tiles, 0.4 m tall
    for k in range(-6, 6, 2):
        edge = i in (-6, 4) or k in (-6, 4)
        blocks.append((i, 0, k, i + 2, 4, k + 2, "box" if edge else None, "stone" if edge else "soil"))
for a, b in ((-6, -4), (4, 6)):              # its kerb: four lengths, 0.1 m high
    blocks.append((a, 4, -6, b, 5, 6, "box", "kerb"))
    blocks.append((-4, 4, a, 4, 5, b, "box", "kerb"))
blocks.append((-4, 4, -4, 4, 5, 4, None, "soil"))
heap = {}
for i in range(-5, 5, 2):                    # the heap: 0.2 m leaf cubes, taller toward the middle
    for k in range(-5, 5, 2):
        d = max(abs(i + 1), abs(k + 1)) / 4.0
        heap[(i, k)] = max(1, min(3, round(2.7 - 1.5 * d + 1.1 * (unit(SEED, "heap", i, k) - 0.5))))
blossoms = 0
for (i, k), n in sorted(heap.items()):
    for t in range(n):
        blocks.append((i, 5 + 2 * t, k, i + 2, 7 + 2 * t, k + 2, "leaf", "leaf"))
    if n < 3 and unit(SEED, "bloom", i, k) < 0.3:      # a white blossom cube on a lower column
        blocks.append((i, 5 + 2 * n, k, i + 2, 7 + 2 * n, k + 2, None, "flower_white"))
        blossoms += 1
cells = set()
for (i0, j0, k0, i1, j1, k1, _kind, _key) in blocks:
    cells.update((i, j, k) for i in range(i0, i1) for j in range(j0, j1) for k in range(k0, k1))

bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
col = bm.loops.layers.float_color.new("Col")
entries = []


def base(key):
    return [shade.lin(c) for c in voxel.hex_rgb(voxel.resolve(key, palette.PALETTE))]


def at(i, j, k):
    return (i * C, -k * C, j * C)            # Blender: x, -z of the kit, up


for n, (i0, j0, k0, i1, j1, k1, kind, key) in enumerate(blocks):
    faces = (  # (the layer of cells just outside this face, its four corners, the way it looks)
        ([(i1, j, k) for j in range(j0, j1) for k in range(k0, k1)], [(i1, j0, k0), (i1, j1, k0), (i1, j1, k1), (i1, j0, k1)], (1, 0, 0)),
        ([(i0 - 1, j, k) for j in range(j0, j1) for k in range(k0, k1)], [(i0, j0, k0), (i0, j0, k1), (i0, j1, k1), (i0, j1, k0)], (-1, 0, 0)),
        ([(i, j1, k) for i in range(i0, i1) for k in range(k0, k1)], [(i0, j1, k0), (i0, j1, k1), (i1, j1, k1), (i1, j1, k0)], (0, 1, 0)),
        ([(i, j, k1) for i in range(i0, i1) for j in range(j0, j1)], [(i0, j0, k1), (i1, j0, k1), (i1, j1, k1), (i0, j1, k1)], (0, 0, 1)),
        ([(i, j, k0 - 1) for i in range(i0, i1) for j in range(j0, j1)], [(i0, j0, k0), (i0, j1, k0), (i1, j1, k0), (i1, j0, k0)], (0, 0, -1)),
    )                                        # no undersides: every block stands on the ground or on another
    for outside, corners, d in faces:
        if all(c in cells for c in outside):
            continue
        f = bm.faces.new([bm.verts.new(at(*c)) for c in corners])
        f.normal_update()
        look = Vector((d[0], -d[2], d[1]))
        if f.normal.dot(look) < 0:
            f.normal_flip()
        for loop in f.loops:
            loop[col] = (*base(key), 1.0)
        lo, hi = marks.where(look.z, kind, P) if kind else (0.0, 1.0)
        entries.append((kind, n, 0.0, lo, hi, 1.0) if kind else None)

me = bpy.data.meshes.new("box")
bm.normal_update()
bm.to_mesh(me)
bm.free()
for p in me.polygons:
    p.use_smooth = False
me.materials.append(bake._vertex_colour_material("baked_r85_m0", 0.85))
me.color_attributes.active_color = me.color_attributes["Col"]
root = bpy.data.objects.new("planter", None)
box = bpy.data.objects.new("box", me)
for o in (root, box):
    bpy.context.scene.collection.objects.link(o)
box.parent = root
bpy.context.view_layer.update()
stats = marks.paint({"box": entries}, ramps, STYLE, P, CONFIG["kinds"])
out.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_yup=True, export_apply=True,
                          export_animations=False, export_cameras=False, export_lights=False, export_extras=False,
                          export_skins=False, export_morph=False)
tris = sum(len(p.vertices) - 2 for p in me.polygons)
print(f"BUILD planter voxel: wrote {out} ({tris} triangles, {sum(heap.values())} leaf cubes, {blossoms} blossom cubes) {json.dumps(stats)}")
