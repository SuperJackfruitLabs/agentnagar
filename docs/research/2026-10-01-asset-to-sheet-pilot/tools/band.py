"""The game's own measure of what a kit piece draws where people walk, in Python.

city/godot/styles/kit_town.gd (band_box_of, _band_points): the (x, z) bounds, in the piece's frame, of its
faces cut to BAND_MEASURE, 0.15 to 2.2 m up (the spec's walking band, 0.25 to 1.9 m, with a margin either
side): every vertex inside the band and every point where an edge crosses its two heights. Every mesh counts,
leaves too.

A piece a pack `fill`s (pack_3d.gd _fill_footprint) is stretched so that box fills its catalogue footprint as
the walking grid draws it (CityGeometry.drawn_rect): each edge of the footprint moved out to 2.5 cm past the
centres of the cells the grid blocks, so by up to about 12 cm, by where the placement falls on the 25 cm grid.
So a piece whose box is its footprint is still stretched a few per cent, and one leaf or limb in the band
outside the footprint squeezes the whole piece.
"""
import json
import struct

BAND_MEASURE = (0.15, 2.2)
_FMT = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}


def _matrix(node):
    if 'matrix' in node:
        m = node['matrix']
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = node.get('translation', [0, 0, 0]); s = node.get('scale', [1, 1, 1]); x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[i][0] * s[0], r[i][1] * s[1], r[i][2] * s[2], t[i]] for i in range(3)] + [[0, 0, 0, 1]]


def _mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def triangles(path):
    """{node name: [triangle, ...]} of a GLB, each triangle three (x, y, z) points in the root's frame (y up)."""
    d = open(path, 'rb').read()
    n = struct.unpack('<I', d[12:16])[0]
    g = json.loads(d[20:20 + n]); blob = d[20 + n + 8:]

    def acc(i):
        a = g['accessors'][i]; v = g['bufferViews'][a['bufferView']]
        comps = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
        f = _FMT[a['componentType']]; size = struct.calcsize(f) * comps
        stride = v.get('byteStride', size); off = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        return [struct.unpack_from('<' + f * comps, blob, off + k * stride) for k in range(a['count'])]
    out = {}

    def visit(i, parent):
        node = g['nodes'][i]
        world = _mul(parent, _matrix(node))
        if 'mesh' in node:
            tris = out.setdefault(node.get('name', str(i)), [])
            for p in g['meshes'][node['mesh']]['primitives']:
                pos = [tuple(sum(world[r][c] * v for c, v in enumerate((*q, 1.0))) for r in range(3)) for q in acc(p['attributes']['POSITION'])]
                idx = [k[0] for k in acc(p['indices'])] if 'indices' in p else list(range(len(pos)))
                tris += [(pos[idx[k]], pos[idx[k + 1]], pos[idx[k + 2]]) for k in range(0, len(idx) - 2, 3)]
        for c in node.get('children', []):
            visit(c, world)
    identity = [[1.0 if r == c else 0.0 for c in range(4)] for r in range(4)]
    for i in g['scenes'][g.get('scene', 0)]['nodes']:
        visit(i, identity)
    return out


def band_points(tris, band=BAND_MEASURE):
    """The game's _band_points: (x, z) of vertices inside the band and of edges' crossings of its heights."""
    lo, hi = band
    out = []
    for tri in tris:
        for k in range(3):
            p, q = tri[k], tri[(k + 1) % 3]
            if lo <= p[1] <= hi:
                out.append((p[0], p[2]))
            if p[1] == q[1]:
                continue
            for level in (lo, hi):
                f = (level - p[1]) / (q[1] - p[1])
                if 0.0 < f < 1.0:
                    out.append((p[0] + (q[0] - p[0]) * f, p[2] + (q[2] - p[2]) * f))
    return out


def band_box(path, band=BAND_MEASURE, skip=()):
    """(box, per node): the piece's band box [x0, z0, x1, z1] (None with nothing in the band), and each
    node's own. Nodes whose names start with one of `skip` are left out."""
    per, pts = {}, []
    for name, tris in triangles(path).items():
        if any(name.startswith(s) for s in skip):
            continue
        p = band_points(tris, band)
        per[name] = [min(x for x, _ in p), min(z for _, z in p), max(x for x, _ in p), max(z for _, z in p)] if p else None
        pts += p
    box = [min(x for x, _ in pts), min(z for _, z in pts), max(x for x, _ in pts), max(z for _, z in pts)] if pts else None
    return box, per
