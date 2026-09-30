"""Voxel grids to GLB, in plain Python (no Blender, no numpy).

A `Grid` holds voxels as integer cells (i, j, k) -> palette key, in Godot
axes: i along +x (east), j along +y (up), k along +z (south, toward the
default camera). Cell (i, j, k) covers [i, i + 1) x [j, j + 1) x [k, k + 1)
voxels of `size` metres, so a recipe that wants the origin at a piece's
bottom-centre simply paints cells on both sides of zero.

`mesh()` keeps only the faces with no voxel beside them, groups them by
direction, plane and palette key, and merges each group into rectangles
(greedy meshing). `write_glb()` writes an asset as one node per part, one
primitive per palette key, one material per key.

Everything is deterministic: cells, groups and materials are visited in
sorted order, shade variation comes from an explicit integer hash (never
Python's randomised `hash`), and the GLB's JSON and binary chunks are laid
out in a fixed order, so two builds are byte-identical.
"""
import json
import math
import struct

VOXEL = 0.1

# Face directions as (axis, sign). For axis a the face's in-plane axes are
# ((a + 1) % 3, (a + 2) % 3), which keeps u x v = +a, so quads listed
# u-then-v wind counter-clockwise seen from the + side.
DIRECTIONS = [(0, 1), (0, -1), (1, 1), (1, -1), (2, 1), (2, -1)]


def cells(metres, size=VOXEL):
    """Metres to a whole number of cells (recipes think in metres)."""
    return int(round(metres / size))


def mix(*values):
    """A 32-bit integer hash of integers and strings, stable across runs
    and machines (FNV-1a over the values' text)."""
    h = 0x811C9DC5
    for v in values:
        for ch in str(v).encode() + b"|":
            h = ((h ^ ch) * 0x01000193) & 0xFFFFFFFF
    # Final avalanche so neighbouring cells differ in the low bits.
    h ^= h >> 16
    h = (h * 0x85EBCA6B) & 0xFFFFFFFF
    h ^= h >> 13
    return h


def unit(*values):
    """A stable pseudo-random number in [0, 1)."""
    return mix(*values) / 2 ** 32


class Grid:
    """Sparse voxels: {(i, j, k): palette key}."""

    def __init__(self, size=VOXEL):
        self.size = size
        self.cells = {}

    def __len__(self):
        return len(self.cells)

    def put(self, i, j, k, key):
        self.cells[(i, j, k)] = key

    def get(self, i, j, k):
        return self.cells.get((i, j, k))

    def erase(self, i, j, k):
        self.cells.pop((i, j, k), None)

    def box(self, i0, j0, k0, i1, j1, k1, key):
        """Fills cells i0 <= i < i1 (and so on). `key` may be a function of
        (i, j, k) returning a key or None (leave the cell alone)."""
        for i in range(i0, i1):
            for j in range(j0, j1):
                for k in range(k0, k1):
                    if callable(key):
                        v = key(i, j, k)
                        if v is not None:
                            self.cells[(i, j, k)] = v
                    else:
                        self.cells[(i, j, k)] = key

    def clear(self, i0, j0, k0, i1, j1, k1):
        for i in range(i0, i1):
            for j in range(j0, j1):
                for k in range(k0, k1):
                    self.cells.pop((i, j, k), None)

    def paint(self, i0, j0, k0, i1, j1, k1, key, only=None):
        """Recolours existing cells in the box (those whose key is in
        `only`, when given)."""
        for i in range(i0, i1):
            for j in range(j0, j1):
                for k in range(k0, k1):
                    old = self.cells.get((i, j, k))
                    if old is not None and (only is None or old in only):
                        self.cells[(i, j, k)] = key

    def ellipsoid(self, ci, cj, ck, ri, rj, rk, key):
        """Cells whose centres lie inside the ellipsoid centred on the
        corner point (ci, cj, ck) with radii in cells."""
        for i in range(math.floor(ci - ri), math.ceil(ci + ri)):
            for j in range(math.floor(cj - rj), math.ceil(cj + rj)):
                for k in range(math.floor(ck - rk), math.ceil(ck + rk)):
                    d = ((i + 0.5 - ci) / ri) ** 2 + ((j + 0.5 - cj) / rj) ** 2 + ((k + 0.5 - ck) / rk) ** 2
                    if d <= 1.0:
                        self.cells[(i, j, k)] = key(i, j, k) if callable(key) else key

    def cylinder(self, ci, ck, r, j0, j1, key, axis="y"):
        """An upright disc stack (axis y) centred on the corner point
        (ci, ck); radius in cells."""
        for i in range(math.floor(ci - r), math.ceil(ci + r)):
            for k in range(math.floor(ck - r), math.ceil(ck + r)):
                if (i + 0.5 - ci) ** 2 + (k + 0.5 - ck) ** 2 <= r * r:
                    for j in range(j0, j1):
                        self.cells[(i, j, k)] = key(i, j, k) if callable(key) else key

    def blit(self, other, di=0, dj=0, dk=0):
        for (i, j, k), key in sorted(other.cells.items()):
            self.cells[(i + di, j + dj, k + dk)] = key

    def vary(self, keys, block=(5, 5, 5), light=0.25, dark=0.25, seed=""):
        """Shade variation: every `block` of cells holding one of `keys` is
        assigned, by a stable hash, the key itself, its light shade `key+`
        or its dark shade `key-`, so large surfaces read as stacked blocks
        without breaking into single-voxel noise."""
        bi, bj, bk = block
        for (i, j, k) in sorted(self.cells):
            key = self.cells[(i, j, k)]
            if key not in keys:
                continue
            u = unit(seed, key, i // bi, j // bj, k // bk)
            if u < light:
                self.cells[(i, j, k)] = key + "+"
            elif u < light + dark:
                self.cells[(i, j, k)] = key + "-"

    def bounds(self):
        """(lo, hi) cell corners of the occupied cells."""
        if not self.cells:
            return (0, 0, 0), (0, 0, 0)
        lo = [min(c[a] for c in self.cells) for a in range(3)]
        hi = [max(c[a] for c in self.cells) + 1 for a in range(3)]
        return tuple(lo), tuple(hi)


# ---- Meshing ----

def exposed_faces(grid, open_planes=()):
    """{(axis, sign, plane, key): set((u, v))}: every face of every voxel
    with no voxel on the other side, grouped by the plane it lies in.
    Faces in `open_planes`, (axis, sign, plane) triples, are left out: a
    module that always tiles against a neighbour there need not carry
    them."""
    groups = {}
    occupied = grid.cells
    skip = set(open_planes)
    for c, key in occupied.items():
        for axis, sign in DIRECTIONS:
            n = list(c)
            n[axis] += sign
            if tuple(n) in occupied:
                continue
            plane = c[axis] + (1 if sign > 0 else 0)
            if (axis, sign, plane) in skip:
                continue
            uv = (c[(axis + 1) % 3], c[(axis + 2) % 3])
            groups.setdefault((axis, sign, plane, key), set()).add(uv)
    return groups


def greedy(points):
    """Covers a set of (u, v) unit squares with rectangles (u, v, w, h),
    greedily: widest run along u first, then as many rows along v as the
    whole run allows."""
    out = []
    used = set()
    for (u, v) in sorted(points, key=lambda p: (p[1], p[0])):
        if (u, v) in used:
            continue
        w = 1
        while (u + w, v) in points and (u + w, v) not in used:
            w += 1
        h = 1
        while all((u + x, v + h) in points and (u + x, v + h) not in used for x in range(w)):
            h += 1
        for x in range(w):
            for y in range(h):
                used.add((u + x, v + y))
        out.append((u, v, w, h))
    return out


def mesh(grid, offset=(0.0, 0.0, 0.0), open_planes=()):
    """{key: (positions, normals, indices)} for a grid's exposed faces,
    merged into rectangles; positions in metres plus `offset`."""
    s = grid.size
    out = {}
    groups = exposed_faces(grid, open_planes)
    for gkey in sorted(groups):
        axis, sign, plane, key = gkey
        a1, a2 = (axis + 1) % 3, (axis + 2) % 3
        pos, nor, idx = out.setdefault(key, ([], [], []))
        normal = [0.0, 0.0, 0.0]
        normal[axis] = float(sign)
        for (u, v, w, h) in greedy(groups[gkey]):
            corners = [(u, v), (u + w, v), (u + w, v + h), (u, v + h)]
            if sign < 0:
                corners.reverse()
            base = len(pos)
            for (cu, cv) in corners:
                p = [0.0, 0.0, 0.0]
                p[axis] = plane
                p[a1] = cu
                p[a2] = cv
                pos.append(tuple(round(p[x] * s + offset[x], 6) for x in range(3)))
                nor.append(tuple(normal))
            idx.extend((base, base + 1, base + 2, base, base + 2, base + 3))
    return out


def drum(sides, radius, y0, y1, side_key, top_key, seed=""):
    """{key: (positions, normals, indices)} for an upright prism of `sides`
    flat faces round the y axis, its corners on a circle of `radius`
    metres, from y0 to y1, capped on top: a round mass a 10 cm voxel
    cannot draw closely enough, where it must follow a disc (a clipped
    bush). The side faces alternate between `side_key` and its shades by
    a stable hash of `seed`, as `Grid.vary` shades blocks."""
    out = {}
    corners = [(round(radius * math.cos(2 * math.pi * n / sides), 6), round(radius * math.sin(2 * math.pi * n / sides), 6))
               for n in range(sides)]
    for n in range(sides):
        (x0, z0), (x1, z1) = corners[n], corners[(n + 1) % sides]
        u = unit(seed, "drum", n)
        key = side_key + ("+" if u < 0.25 else ("-" if u < 0.5 else ""))
        pos, nor, idx = out.setdefault(key, ([], [], []))
        mid = math.pi * (2 * n + 1) / sides
        normal = (round(math.cos(mid), 6), 0.0, round(math.sin(mid), 6))
        base = len(pos)
        # Counter-clockwise seen from outside.
        for p in ((x0, y0, z0), (x0, y1, z0), (x1, y1, z1), (x1, y0, z1)):
            pos.append(p)
            nor.append(normal)
        idx.extend((base, base + 1, base + 2, base, base + 2, base + 3))
    pos, nor, idx = out.setdefault(top_key, ([], [], []))
    base = len(pos)
    pos.append((0.0, y1, 0.0))
    nor.append((0.0, 1.0, 0.0))
    for (x, z) in corners:
        pos.append((x, y1, z))
        nor.append((0.0, 1.0, 0.0))
    for n in range(sides):
        idx.extend((base, base + 1 + (n + 1) % sides, base + 1 + n))
    return out


def merged(*meshes):
    """One {key: (positions, normals, indices)} holding every mesh given:
    a piece planted by the hundred is drawn from its first mesh alone, so
    its voxels and shapes must be one."""
    out = {}
    for m in meshes:
        for key in sorted(m):
            pos, nor, idx = out.setdefault(key, ([], [], []))
            base = len(pos)
            pos.extend(m[key][0])
            nor.extend(m[key][1])
            idx.extend(i + base for i in m[key][2])
    return out


def blocks(boxes):
    """{key: (positions, normals, indices, bends)} for boxes that need not
    sit on the voxel grid, each (x0, y0, z0, x1, y1, z1, key, w0, w1) in
    metres, and optionally False after them for a box whose top is covered
    (a flower's stem, under its blossom): its sides and top (no bottom), faces
    wound outward, and each vertex's bend weight, w0 at the box's bottom
    and w1 at its top (a blade of grass stacked from boxes bends from 0 at
    its root to 1 at its tip; see glb_bytes)."""
    out = {}
    for box in boxes:
        x0, y0, z0, x1, y1, z1, key, w0, w1 = box[:9]
        top = box[9] if len(box) > 9 else True
        pos, nor, idx, bend = out.setdefault(key, ([], [], [], []))
        faces = (
            ((1.0, 0.0, 0.0), [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)]),
            ((-1.0, 0.0, 0.0), [(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)]),
            ((0.0, 0.0, 1.0), [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]),
            ((0.0, 0.0, -1.0), [(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)]),
        ) + ((((0.0, 1.0, 0.0), [(x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0)]),) if top else ())
        for normal, corners in faces:
            a, b, c = corners[0], corners[1], corners[2]
            u = [b[n] - a[n] for n in range(3)]
            v = [c[n] - a[n] for n in range(3)]
            cross = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            if sum(cross[n] * normal[n] for n in range(3)) < 0:
                corners = corners[::-1]
            base = len(pos)
            for p in corners:
                pos.append(tuple(round(x, 6) for x in p))
                nor.append(normal)
                bend.append(w1 if p[1] == y1 else w0)
            idx.extend((base, base + 1, base + 2, base, base + 2, base + 3))
    return out


def triangles(meshes):
    return sum(len(m[2]) // 3 for m in meshes.values())


# ---- Palette and materials ----

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def shade(h, factor):
    """A hex colour lightened (factor > 1) or darkened (< 1) in sRGB."""
    r, g, b = hex_rgb(h)
    if factor >= 1:
        r, g, b = (c + (1 - c) * (factor - 1) for c in (r, g, b))
    else:
        r, g, b = (c * factor for c in (r, g, b))
    return "#%02X%02X%02X" % tuple(int(round(min(1.0, max(0.0, c)) * 255)) for c in (r, g, b))


LIGHTER = 1.045
DARKER = 0.95


def resolve(key, palette):
    """The hex colour of a key: a palette name, or its shade `name+`/`name-`."""
    if key.endswith("+"):
        return shade(palette[key[:-1]], LIGHTER)
    if key.endswith("-"):
        return shade(palette[key[:-1]], DARKER)
    return palette[key]


def base_key(key):
    return key.rstrip("+-")


def material(key, palette, props):
    """A glTF material for a palette key; `props` maps base keys to
    {roughness, metallic, emissive} overrides."""
    colour = [round(srgb_to_linear(c), 6) for c in hex_rgb(resolve(key, palette))]
    p = props.get(base_key(key), {})
    m = {
        "name": key,
        "pbrMetallicRoughness": {
            "baseColorFactor": colour + [1.0],
            "metallicFactor": p.get("metallic", 0.0),
            "roughnessFactor": p.get("roughness", 0.85),
        },
    }
    if p.get("emissive"):
        m["emissiveFactor"] = [round(c * p["emissive"], 6) for c in colour]
    return m


# ---- GLB ----

def _f32(x):
    return struct.unpack("<f", struct.pack("<f", x))[0]


class _Writer:
    def __init__(self):
        self.bin = bytearray()
        self.views = []
        self.accessors = []

    def _view(self, data, target):
        while len(self.bin) % 4:
            self.bin.append(0)
        self.views.append({"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data), "target": target})
        self.bin.extend(data)
        return len(self.views) - 1

    def vec2(self, values):
        flat = [c for v in values for c in v]
        view = self._view(struct.pack("<%df" % len(flat), *flat), 34962)
        self.accessors.append({"bufferView": view, "componentType": 5126, "count": len(values), "type": "VEC2"})
        return len(self.accessors) - 1

    def vec3(self, values, with_bounds):
        flat = [c for v in values for c in v]
        view = self._view(struct.pack("<%df" % len(flat), *flat), 34962)
        acc = {"bufferView": view, "componentType": 5126, "count": len(values), "type": "VEC3"}
        if with_bounds:
            acc["min"] = [min(_f32(v[a]) for v in values) for a in range(3)]
            acc["max"] = [max(_f32(v[a]) for v in values) for a in range(3)]
        self.accessors.append(acc)
        return len(self.accessors) - 1

    def indices(self, values, vertex_count):
        if vertex_count < 65535:
            data, ctype = struct.pack("<%dH" % len(values), *values), 5123
        else:
            data, ctype = struct.pack("<%dI" % len(values), *values), 5125
        view = self._view(data, 34963)
        self.accessors.append({"bufferView": view, "componentType": ctype, "count": len(values), "type": "SCALAR"})
        return len(self.accessors) - 1


def glb_bytes(name, parts, palette, props):
    """A GLB: a root node `name` whose children are `parts`, a list of
    (node name, {key: (positions, normals, indices)}, translation), each
    with a scale after its translation when it has one. A
    part's mesh may carry each vertex's bend weight as a fourth list (see
    `blocks`): it is written as TEXCOORD_1's U (Godot's UV2.x), after an
    all-zero TEXCOORD_0, where the sway (Task 8) reads it. A part with no
    mesh is an empty node, such as a display's face."""
    w = _Writer()
    nodes = [{"name": name, "children": list(range(1, len(parts) + 1))}]
    meshes = []
    keys = sorted({k for part in parts for k in part[1]})
    for part in parts:
        part_name, part_mesh, translation = part[:3]
        scale = part[3] if len(part) > 3 else None
        prims = []
        for key in sorted(part_mesh):
            pos, nor, idx = part_mesh[key][:3]
            if not idx:
                continue
            attributes = {"POSITION": w.vec3(pos, True), "NORMAL": w.vec3(nor, False)}
            if len(part_mesh[key]) > 3:
                attributes["TEXCOORD_0"] = w.vec2([(0.0, 0.0)] * len(pos))
                attributes["TEXCOORD_1"] = w.vec2([(b, 0.0) for b in part_mesh[key][3]])
            prims.append({
                "attributes": attributes,
                "indices": w.indices(idx, len(pos)),
                "material": keys.index(key),
                "mode": 4,
            })
        node = {"name": part_name}
        if prims:
            meshes.append({"name": part_name, "primitives": prims})
            node["mesh"] = len(meshes) - 1
        if any(translation):
            node["translation"] = [float(t) for t in translation]
        if scale is not None:
            node["scale"] = [float(t) for t in scale]
        nodes.append(node)
    while len(w.bin) % 4:
        w.bin.append(0)
    doc = {
        "asset": {"version": "2.0", "generator": "agentnagar city/tools/styles/voxel"},
        "scene": 0,
        "scenes": [{"name": name, "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": [material(k, palette, props) for k in keys],
        "accessors": w.accessors,
        "bufferViews": w.views,
        "buffers": [{"byteLength": len(w.bin)}],
    }
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(w.bin)
    out = bytearray()
    out += struct.pack("<4sII", b"glTF", 2, total)
    out += struct.pack("<I4s", len(text), b"JSON") + text
    out += struct.pack("<I4s", len(w.bin), b"BIN\x00") + bytes(w.bin)
    return bytes(out)


class Asset:
    """A named asset made of parts: each part is a Grid meshed into its own
    glTF node (so a pack can hide, fade or swap it)."""

    def __init__(self, name):
        self.name = name
        self.parts = []

    def part(self, name, grid, translation=(0.0, 0.0, 0.0), open_planes=()):
        self.parts.append((name, grid, translation, tuple(open_planes)))
        return grid

    def shape(self, name, shape_mesh, translation=(0.0, 0.0, 0.0), scale=None):
        """A part drawn as a ready mesh ({key: (positions, normals,
        indices)}, such as a `drum`) rather than voxels; `scale` scales its
        node (a display's face size on its empty node)."""
        self.parts.append((name, shape_mesh, translation, (), scale))
        return shape_mesh

    def meshes(self):
        out = []
        for n, g, t, o, *scale in self.parts:
            m = mesh(g, open_planes=o) if isinstance(g, Grid) else g
            out.append((n, m, t, scale[0]) if scale and scale[0] is not None else (n, m, t))
        return out

    def glb(self, palette, props):
        return glb_bytes(self.name, self.meshes(), palette, props)
