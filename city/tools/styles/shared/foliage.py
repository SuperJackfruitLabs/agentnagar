"""Leaf-card foliage, shared by the style kits: crowns drawn as the anime
sheets draw them, fluffy masses of leaf clusters with a leaf-edged outline,
lit as one soft form.

A crown is a few overlapping lobes (ellipsoids). Each lobe is a small, dark,
opaque core that stops the eye, wrapped in square cards that each carry a
cluster of pointed leaves: a shared, alpha-masked texture (`LEAVES`, a 2 x 2
atlas of four clusters, drawn here with Pillow). The cards tilt every which
way off the lobe's surface, so from any side some stand across the view and
fringe the outline with leaves. Every vertex's normal comes from a smooth
field in space, the lobe's outward normal leaning toward the whole crown's,
not from the card, so the light's step runs across the crown as a soft
curve and each lobe reads as a bulge on it; cards in front of one another
share normals where they touch, so a line pass that inks normal creases
draws the crown's lobes, not every card. Cards are single-sided, back
faces culled: every card faces out of its lobe, so from any side the ones
turned away are behind nearer ones and the heart (`both=True` adds a back
face with the same normals, for twice the vertices; a double-sided material
would light a card's back with its normal flipped). Cards buried inside a
neighbouring lobe are left out.

Materials: one per green, named `<colour>_leaves` (the palette colour times
the white texture, alphaMode MASK at `CUTOFF`, back faces culled), and the
cores in plain palette colours. The mesh's custom normals are left in
`mesh.normals` ({vertex index: normal}), the convention the anime kit's
`vegetation.finish` applies; kits with their own finish call
`apply_normals(obj, mesh)` after building. At runtime the cards want alpha
to coverage with MSAA and no received shadows (the anime pack's Toon does
this for materials named `*_leaves`), and their GLBs imported without LODs
(Godot's simplifier deletes whole cards).

Use (inside a Blender kit build, `lib` being the kit's lib):

    import foliage                                  # tools/styles/shared
    lobes = foliage.round_lobes((0, 0, 4), (2.2, 2.2, 1.7), 7, seed=3)
    foliage.crown(mesh, lobes, 0.9, seed=3, core_mat=("leaf", "leaf_dark"))
    # then fit the crown to foliage.padded(size, 0.9) to meet a spec size

Draw the texture with Pillow (the build draws it too when it is missing):

    python3 tools/styles/shared/foliage.py [OUT.png]
"""
import math
import random
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
# The committed texture, next to the anime kit's GLBs that embed it.
LEAVES = HERE.parents[2] / "godot" / "styles" / "anime_cel" / "assets" / "foliage_leaves.png"
CELL = 256       # one leaf cluster's cell, in pixels
SUPER = 4        # drawn this much larger, then filtered down
# How far a crown's cards reach past its leaves, as a fraction of the card
# size: the clusters are round and the cards square. A crown fitted to a
# size looks that size when fitted up to this much larger on each side
# (`padded` keeps that within a size tolerance).
MARGIN = 0.25


def padded(size, card, most=0.06):
    """`size` grown by the cards' empty corners (`MARGIN` of `card` each
    side), but by no more than `most` of it: what to fit a crown to so it
    looks about `size` and measures within its spec."""
    return size + min(2 * card * MARGIN, most * size)


# The alpha cutoff: below a half, so the leafy fringe, whose alpha the
# texture's smaller mipmaps average down, still stands at a distance.
CUTOFF = 0.35


# ---- The texture (Pillow; runs outside Blender) ----

def _leaf(cx, cy, angle, length, width, base, steps=14):
    """A pointed leaf's outline: from a point `base` px out from the cell's
    centre along `angle`, `length` px long and `width` px across at its
    widest, which is a little below the middle; the tip is sharp."""
    ux, uy = math.cos(angle), math.sin(angle)
    vx, vy = -uy, ux
    bx, by = cx + ux * base, cy + uy * base
    left, right = [], []
    for i in range(steps + 1):
        t = i / steps
        half = 0.5 * width * math.sin(math.pi * t ** 0.8) ** 0.85
        px, py = bx + ux * length * t, by + uy * length * t
        left.append((px + vx * half, py + vy * half))
        right.append((px - vx * half, py - vy * half))
    return left + right[::-1]


def draw_cluster(seed, size=CELL, leaves=40):
    """One cell: a clump of `leaves` pointed leaves over a solid, lumpy
    heart, the outer ones pointing outward so its outline is all leaf tips,
    the inner ones every which way; each leaf a slightly different light
    grey (the palette colour multiplies it), transparent round it. Returns
    (rgb, alpha) Pillow images of `size` px."""
    from PIL import Image, ImageDraw

    rng = random.Random(seed)
    s = size * SUPER
    c = s / 2
    rgb = Image.new("L", (s, s), 236)
    alpha = Image.new("L", (s, s), 0)
    dr, da = ImageDraw.Draw(rgb), ImageDraw.Draw(alpha)
    # The heart: a lump of overlapping rounds, solid, so the middle of every
    # card is leaf.
    heart = s * 0.27
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-0.3, 0.3)
        r = heart * rng.uniform(0.55, 0.7)
        x, y = c + (heart - r) * math.cos(a), c + (heart - r) * math.sin(a)
        da.ellipse((x - r, y - r, x + r, y + r), fill=255)
        dr.ellipse((x - r, y - r, x + r, y + r), fill=int(255 * rng.uniform(0.84, 0.9)))
    outer = leaves * 2 // 3
    for k in range(leaves):
        at = rng.uniform(0, 2 * math.pi)
        if k < outer:
            # Round the rim, pointing out.
            off = heart * rng.uniform(0.55, 0.95)
            a = at + rng.uniform(-0.5, 0.5)
            length = s * rng.uniform(0.14, 0.23)
        else:
            # Over the heart, any way.
            off = heart * math.sqrt(rng.uniform(0.0, 0.5))
            a = at + rng.uniform(-1.2, 1.2)
            length = s * rng.uniform(0.11, 0.17)
        # Tips stay inside the cell.
        length = min(length, s * 0.49 - off)
        width = length * rng.uniform(0.4, 0.5)
        x, y = c + off * math.cos(at), c + off * math.sin(at)
        poly = _leaf(x, y, a, length, width, 0.0)
        da.polygon(poly, fill=255)
        dr.polygon(poly, fill=int(255 * rng.uniform(0.86, 1.0)))
    rgb = rgb.resize((size, size), Image.LANCZOS)
    alpha = alpha.resize((size, size), Image.LANCZOS)
    return rgb, alpha


def draw_leaves(path=LEAVES, seed=11):
    """Writes the 2 x 2 atlas of four leaf clusters, RGBA, to `path`; the
    same bytes for the same seed."""
    from PIL import Image

    out = Image.new("RGBA", (CELL * 2, CELL * 2), (236, 236, 236, 0))
    for k in range(4):
        rgb, alpha = draw_cluster(seed * 10 + k)
        cell = Image.merge("RGBA", (rgb, rgb, rgb, alpha))
        out.paste(cell, ((k % 2) * CELL, (k // 2) * CELL))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    out.save(path, optimize=False)
    return path


# ---- Crowns (Blender) ----

def _vec(v):
    from mathutils import Vector
    return Vector(v)


def _grad(p, centre, radii):
    """The outward normal at `p` of the ellipsoid `radii` about `centre`
    (its gradient, so it is right off the surface too)."""
    from mathutils import Vector
    d = Vector((p[0] - centre[0], p[1] - centre[1], p[2] - centre[2]))
    g = Vector((d.x / radii[0] ** 2, d.y / radii[1] ** 2, d.z / radii[2] ** 2))
    return g.normalized() if g.length > 1e-9 else Vector((0, 0, 1))


class Field:
    """The crown's normals: at a point, its lobe's outward normal leaning
    `weight` of the way to the whole crown's, tipped `lift` toward the sky
    (a sunnier crown)."""

    def __init__(self, whole, weight=0.45, lift=0.15):
        self.whole, self.weight, self.lift = whole, weight, lift

    def __call__(self, p, lobe):
        from mathutils import Vector
        n = _grad(p, *lobe).lerp(_grad(p, *self.whole), self.weight)
        return (n + Vector((0, 0, self.lift))).normalized()


def spread(n, lo=-0.3, seed=0, jitter=0.0, hi=1.0):
    """`n` directions spread evenly over the band of the unit sphere from
    z = `lo` to `hi` (a golden spiral), each nudged up to about `jitter`
    radians at random."""
    from mathutils import Vector
    rng = random.Random(seed)
    out = []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = hi - (hi - lo) * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - z * z))
        d = Vector((r * math.cos(golden * i), r * math.sin(golden * i), z))
        if jitter:
            d = (d + Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))) * jitter * 0.5).normalized()
        out.append(d)
    return out


def round_lobes(centre, radii, n, seed, lo=-0.75, hi=0.45, size=0.6, reach=0.5):
    """`n` lobes making up a rounded crown `radii` about `centre`: one
    capping the top and the rest spread round its flanks from z = `lo` to
    `hi` (of its unit sphere), each about `size` of the crown's radii and
    set `reach` of the way out. Returns [(centre, radii)]."""
    rng = random.Random(seed)
    c = _vec(centre)
    top = (c.x, c.y, c.z + radii[2] * (1 - size))
    out = [(top, (radii[0] * size * 1.1, radii[1] * size * 1.1, radii[2] * size))]
    for d in spread(n - 1, lo=lo, hi=hi, seed=seed, jitter=0.2):
        k = rng.uniform(0.9, 1.1)
        p = (c.x + d.x * radii[0] * reach, c.y + d.y * radii[1] * reach, c.z + d.z * radii[2] * reach)
        out.append((p, (radii[0] * size * k, radii[1] * size * k, radii[2] * size * k * 0.85)))
    return out


def _uv_layer(m):
    return m.bm.loops.layers.uv.verify()


def _face(m, verts, mat, uvs=None, normals=None, field=None, lobe=None):
    """Adds one face through new vertices `verts` in material `mat`, with
    loop UVs `uvs`, and field normals recorded in `m.normals`."""
    uv = _uv_layer(m)
    first = len(m.bm.verts)
    vs = [m.bm.verts.new(v) for v in verts]
    f = m.bm.faces.new(vs)
    f.material_index = m.slot(mat)
    if uvs:
        for loop, t in zip(f.loops, uvs):
            loop[uv].uv = t
    if field is not None:
        store = m.__dict__.setdefault("normals", {})
        for j, v in enumerate(verts):
            store[first + j] = field(v, lobe)
    return f


def leaf_material(colour, image=None, cutoff=CUTOFF):
    """The card material in palette `colour` (created once per scene):
    the leaf texture multiplied by the colour, alpha cut at `cutoff` (glTF
    alphaMode MASK), back faces culled."""
    import bpy
    import lib

    name = f"{colour}_leaves"
    if name in bpy.data.materials:
        return name
    image = image or leaf_image()
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Linear"
    tex.extension = "EXTEND"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], mix.inputs["A"])
    mix.inputs["B"].default_value = (*lib.rgb(colour), 1.0)
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    # 1 - (alpha < cutoff): the node pattern the glTF exporter writes as
    # alphaMode MASK with this alphaCutoff.
    below = nt.nodes.new("ShaderNodeMath")
    below.operation = "LESS_THAN"
    nt.links.new(tex.outputs["Alpha"], below.inputs[0])
    below.inputs[1].default_value = cutoff
    keep = nt.nodes.new("ShaderNodeMath")
    keep.operation = "SUBTRACT"
    keep.inputs[0].default_value = 1.0
    nt.links.new(below.outputs[0], keep.inputs[1])
    nt.links.new(keep.outputs[0], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = lib.ROUGHNESS.get(colour, 0.85)
    return name


def leaf_image(path=LEAVES):
    """The leaf atlas as a Blender image, drawn first (with the system's
    Python and Pillow) if it is missing."""
    import bpy

    path = Path(path)
    if not path.exists():
        subprocess.run(["python3", str(Path(__file__).resolve()), str(path)], check=True)
    for img in bpy.data.images:
        if img.filepath and Path(bpy.path.abspath(img.filepath)).resolve() == path.resolve():
            return img
    img = bpy.data.images.load(str(path))
    img.name = "foliage_leaves"
    img.alpha_mode = "STRAIGHT"
    return img


def core(m, lobe, mat, field, scale=0.72, seg=7, rings=4, flat=0.3):
    """A lobe's opaque heart: a low ellipsoid `scale` of the lobe, flatter
    underneath, in `mat` (or `mat` = (top, rest): all but its underside,
    which shows through gaps in the sunlit leaves, in the first), with
    field normals."""
    from mathutils import Vector
    c, r = lobe
    rr = (r[0] * scale, r[1] * scale, r[2] * scale)
    pts = [Vector((0, 0, -1))]
    for i in range(1, rings):
        lat = -math.pi / 2 + math.pi * i / rings
        for k in range(seg):
            lon = 2 * math.pi * (k + 0.5 * (i % 2)) / seg
            pts.append(Vector((math.cos(lat) * math.cos(lon), math.cos(lat) * math.sin(lon), math.sin(lat))))
    pts.append(Vector((0, 0, 1)))
    verts = []
    for d in pts:
        z = d.z * (1 - flat if d.z < 0 else 1)
        verts.append((c[0] + d.x * rr[0], c[1] + d.y * rr[1], c[2] + z * rr[2]))
    top = len(pts) - 1
    faces = [(0, 1 + (k + 1) % seg, 1 + k) for k in range(seg)]
    for i in range(rings - 2):
        a, b = 1 + i * seg, 1 + (i + 1) * seg
        for k in range(seg):
            k2 = (k + 1) % seg
            if i % 2 == 0:
                faces += [(a + k, a + k2, b + k2), (a + k, b + k2, b + k)]
            else:
                faces += [(a + k, a + k2, b + k), (a + k2, b + k2, b + k)]
    last = 1 + (rings - 2) * seg
    faces += [(last + k, last + (k + 1) % seg, top) for k in range(seg)]
    first = len(m.bm.verts)
    vs = [m.bm.verts.new(v) for v in verts]
    top_mat, rest_mat = (mat, mat) if isinstance(mat, str) else mat
    for f in faces:
        nf = m.bm.faces.new([vs[i] for i in f])
        up = sum(pts[i].z for i in f) / len(f)
        nf.material_index = m.slot(top_mat if up > -0.2 else rest_mat)
    store = m.__dict__.setdefault("normals", {})
    for j, v in enumerate(verts):
        store[first + j] = field(v, lobe)


def card(m, at, facing, size, mat, field, lobe, roll=0.0, cell=0, both=True):
    """A leaf card: a square `size` m across centred on `at`, its front
    toward `facing`, its texture's top turned toward the sky (then `roll`
    radians round), showing atlas cell `cell`; two faces back to back."""
    from mathutils import Matrix, Vector
    f = Vector(facing).normalized()
    up = Vector((0, 0, 1)) - f * f.z
    if up.length < 0.2:
        up = Vector((1, 0, 0)) - f * f.x
    up.normalize()
    up = Matrix.Rotation(roll, 3, f) @ up
    right = up.cross(f)
    h = size / 2
    p = Vector(at)
    corners = [p - right * h - up * h, p + right * h - up * h, p + right * h + up * h, p - right * h + up * h]
    u0, v0 = (cell % 2) * 0.5, (1 - cell // 2) * 0.5
    uvs = [(u0, v0), (u0 + 0.5, v0), (u0 + 0.5, v0 + 0.5), (u0, v0 + 0.5)]
    _face(m, [tuple(c) for c in corners], mat, uvs, field=field, lobe=lobe)
    if both:
        order = [0, 3, 2, 1]
        _face(m, [tuple(corners[i]) for i in order], mat, [uvs[i] for i in order], field=field, lobe=lobe)


def default_tone(up, rng):
    """A card's green by how high it sits (`up`, -1 under the crown to 1 on
    top): sunlit crown, light and mid flanks, dark underside."""
    up += rng.uniform(-0.1, 0.1)
    if up > 0.7:
        return "leaf_sun"
    if up > 0.18:
        return "leaf_light"
    if up > -0.4:
        return "leaf"
    return "leaf_dark"


def _area(r):
    p = 1.6
    return 4 * math.pi * (((r[0] * r[1]) ** p + (r[0] * r[2]) ** p + (r[1] * r[2]) ** p) / 3) ** (1 / p)


def _buried(p, lobes, own, bury):
    """Whether `p` lies within `bury` of the way out of any lobe but
    lobe `own`."""
    for j, (c, r) in enumerate(lobes):
        if j != own and sum(((p[i] - c[i]) / r[i]) ** 2 for i in range(3)) < bury * bury:
            return True
    return False


def crown(m, lobes, card_size, seed, whole=None, weight=0.45, lift=0.15, cover=5.0, lo=-0.55,
          core_mat="leaf_dark", core_scale=0.6, tilt=0.8, tone=default_tone, cores=True, bury=0.9,
          both=False, core_seg=7, core_rings=4, rise=0.4, cards=True):
    """A leafy crown in Mesh `m`: over each lobe (centre, radii), an opaque
    core and leaf cards about `card_size` m across, spread over the lobe
    above z = `lo` (of its unit sphere), enough to cover it `cover` times
    over, each tipped up to `tilt` off the surface at random. Cards
    buried deeper than `bury` inside another lobe are left out: nobody
    sees them. `core_mat` is a colour or (top, rest) colours (see
    `core`). The cores are `core_scale` of each lobe, or of each of the
    lobes `cores` lists instead (fewer, for a cheaper heart), or none. `whole`
    (centre, radii) is the ellipsoid the normals lean toward, `weight` of
    the way (default: the lobes' bounds); `tone(up, rng)` picks each
    card's palette green. With `cards` false only the cores are built (a far
    tree: its crown as solid lobes). Returns the number of cards."""
    from mathutils import Matrix, Vector
    rng = random.Random(seed)
    if whole is None:
        lo_c = [min(c[i] - r[i] for c, r in lobes) for i in range(3)]
        hi_c = [max(c[i] + r[i] for c, r in lobes) for i in range(3)]
        whole = (tuple((a + b) / 2 for a, b in zip(lo_c, hi_c)), tuple((b - a) / 2 for a, b in zip(lo_c, hi_c)))
    field = Field(whole, weight, lift)
    wc, wr = whole
    count = 0
    if cores:
        for lobe in (lobes if cores is True else cores):
            core(m, lobe, core_mat, field, scale=core_scale, seg=core_seg, rings=core_rings)
    if not cards:
        return 0
    for li, lobe in enumerate(lobes):
        c, r = lobe
        # Enough to cover the band of the lobe above `lo` `cover` times.
        n = max(6, round(cover * _area(r) * (1 - lo) / 2 / (card_size * card_size)))
        for k, d in enumerate(spread(n, lo=lo, seed=seed * 131 + li, jitter=0.35)):
            depth = rng.uniform(0.78, 0.96)
            p = Vector((c[0] + d.x * r[0] * depth, c[1] + d.y * r[1] * depth, c[2] + d.z * r[2] * depth))
            if _buried(p, lobes, li, bury):
                continue
            out = _grad(p, c, r)
            # Tipped off the surface by at least a third of `tilt`, about a
            # random axis in it: a card square to its outward normal would
            # be edge-on wherever it lies on the outline.
            axis = out.orthogonal().normalized()
            axis.rotate(Matrix.Rotation(rng.uniform(0, 2 * math.pi), 3, out))
            facing = Matrix.Rotation(rng.uniform(tilt / 3, tilt) * rng.choice((-1, 1)), 3, axis) @ out
            # Flank cards turned up a little toward the overhead views (a
            # card square to a flank is edge-on from above); top cards are
            # left tipped, or they would be edge-on from the street.
            facing = (facing + Vector((0, 0, rise * max(0.0, 1 - abs(out.z) * 1.5)))).normalized()
            # Each lobe's top lighter than its underside, and the crown's
            # top lobes lighter than its lower ones.
            up = 0.45 * d.z + 0.3 * _grad(p, wc, wr).z + 0.25 * (p.z - wc[2]) / wr[2]
            mat = leaf_material(tone(up, rng))
            card(m, p, facing, card_size * rng.uniform(0.8, 1.2), mat, field, lobe,
                 roll=rng.uniform(-0.6, 0.6), cell=rng.randrange(4), both=both)
            count += 1
    return count


def apply_normals(obj, mesh):
    """Sets `obj`'s custom normals from `mesh.normals` (for kits whose own
    finish does not)."""
    custom = getattr(mesh, "normals", None)
    if not custom:
        return
    me = obj.data
    for p in me.polygons:
        p.use_smooth = True
    normals = [tuple(c.vector) for c in me.corner_normals]
    for loop in me.loops:
        if loop.vertex_index in custom:
            normals[loop.index] = tuple(custom[loop.vertex_index])
    me.normals_split_custom_set(normals)


if __name__ == "__main__":
    print(draw_leaves(sys.argv[1] if len(sys.argv) > 1 else LEAVES))
