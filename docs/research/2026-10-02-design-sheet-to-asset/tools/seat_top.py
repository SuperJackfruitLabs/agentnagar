"""seat_top.py LABEL=PIECE.glb [...]: the height of each seat's top, as a sitter meets it. Rays are dropped on
the middle of the piece (the middle half of its width and three fifths of its depth); the height most of them
land at, between a quarter and three quarters of the piece's height, is the seat's top. A seat with no back (a
stool, a perch) has nothing above its seat: where no ray lands in that band, the height most rays land at
above a quarter of the piece's height is taken, and the line says so. The game seats a figure by its own
sitting pose, at one height whatever the piece, so a seat whose top is not where the kit's is leaves the
sitter floating or sunk.

    blender --background --factory-startup --python seat_top.py -- LABEL=PIECE.glb [LABEL=PIECE.glb ...]
"""
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def seat_top_of(objs):
    """(seat top, piece height, whether the seat is the piece's own top) of mesh objects standing on z = 0, in metres."""
    verts, polys = [], []
    for o in objs:
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in o.data.vertices]
        polys += [[base + i for i in p.vertices] for p in o.data.polygons]
    tree = BVHTree.FromPolygons([tuple(v) for v in verts], polys)
    xs, ys, zs = ([v[i] for v in verts] for i in range(3))
    x0, x1, y0, y1, top = min(xs), max(xs), min(ys), max(ys), max(zs)
    cx, cy, w, d = (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0
    hits, above = [], []
    for i in range(25):
        for j in range(25):
            p = Vector((cx + (i / 24 - 0.5) * 0.5 * w, cy + (j / 24 - 0.5) * 0.6 * d, top + 0.1))
            hit = tree.ray_cast(p, Vector((0, 0, -1)))
            if hit[0] is not None and 0.25 * top <= hit[0].z <= 0.75 * top:
                hits.append(hit[0].z)
            if hit[0] is not None and hit[0].z >= 0.25 * top:
                above.append(hit[0].z)
    stool = not hits
    if stool and not above:
        return None, top, False
    bins = np.round(np.array(above if stool else hits) / 0.01).astype(int)
    values, counts = np.unique(bins, return_counts=True)
    return float(values[np.argmax(counts)] * 0.01), float(top), stool


if __name__ == "__main__":
    for item in sys.argv[sys.argv.index("--") + 1:]:
        label, path = item.split("=", 1)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=path)
        meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.name.split(".")[0] not in ("light", "lights")]
        seat, top, stool = seat_top_of(meshes)
        print(f"SEAT {label}: top of the seat {seat:.2f} m, piece {top:.2f} m high" + (" (no back: the seat is the piece's top)" if stool else "")
              if seat is not None else f"SEAT {label}: no seat found")
