"""Painted colour and shading baked into vertex colours, for a kit piece already
built and baked (tools/styles/shared/bake.py) in the open Blender scene.

The game lights every pack with one sun and one constant ambient colour, and
the kits paint foliage in three or four flat palette greens. A concept sheet
paints the same tree in a ramp of colours from deep shadow to sunlit highlight,
and paints it much the same from the street and from above. This pass brings
the two together:

  * faces marked as leaf or wood are painted from the sheet's own ramp
    (ramps.json: the colours measured in the sheet's crown and trunk). Where on
    the ramp a face falls depends on how it faces the painted light, how much
    sky it sees, its cluster, the generated model's light and dark at that
    spot, a lamp near it (for a night sheet) and a little chance. Faces are
    ranked, so the share of each tone is the sheet's; faces that look up (seen
    from above) and the rest (seen from the street) are ranked apart, so both
    views show the whole ramp;
  * the game's own light at the hour the sheets are drawn is then partly taken
    back out of the colour (a face the sun will hit gets a darker colour, a
    face in the crown's shade a lighter one), per colour channel, since the
    sun is warm and the ambient light cool;
  * every other face keeps its kit colour, darkened by how little sky it sees.

It rewrites the `Col` attribute the kit's bake wrote. Materials the game drives
by name (lamps, glass, glow) are left alone.
"""
import math
import random

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

CARDS = "foliage_leaves"
# Toward the sun at 13:00 in the client (pack_3d.gd set_daylight: 56.6 degrees
# up, 15 degrees west of south), in Blender's axes (-Y is south, the viewer).
NOON = Vector((-0.142, -0.531, 0.835)).normalized()
QPOS = {5: (0.05, 0.225, 0.5, 0.775, 0.95), 3: (0.12, 0.5, 0.9)}


def lin(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def hex_lin(h):
    h = h.lstrip("#")
    return [lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]


def lum(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def light_at(style, minute):
    """A pack's sun and ambient light at `minute` past midnight, colour times
    energy (linear RGB), from its style.json day keys."""
    keys = sorted(style["day_night"]["keys"], key=lambda k: k["m"])
    a = max([k for k in keys if k["m"] <= minute] or [keys[-1]], key=lambda k: k["m"])
    b = min([k for k in keys if k["m"] > minute] or [keys[0]], key=lambda k: k["m"])
    span = (b["m"] - a["m"]) % 1440 or 1440
    t = ((minute - a["m"]) % 1440) / span

    def mix(field):
        ca, cb = hex_lin(a[field]), hex_lin(b[field])
        ea, eb = a[field + "_energy"], b[field + "_energy"]
        return [(ca[i] + (cb[i] - ca[i]) * t) * (ea + (eb - ea) * t) for i in range(3)]
    return mix("sun"), mix("ambient")


def ramp_at(stops, q):
    """The colour at rank `q` (0 darkest to 1 lightest) on a ramp of linear colours."""
    pos = QPOS[len(stops)]
    if q <= pos[0]:
        return list(stops[0])
    for k in range(1, len(pos)):
        if q <= pos[k]:
            u = (q - pos[k - 1]) / (pos[k] - pos[k - 1])
            return [stops[k - 1][i] + (stops[k][i] - stops[k - 1][i]) * u for i in range(3)]
    return list(stops[-1])


def _dirs(n, seed=5):
    """`n` directions over the upper hemisphere, cosine-weighted about +Z."""
    rng = random.Random(seed)
    out = []
    for k in range(n):
        u, v = (k + 0.5) / n, rng.random()
        r, phi = math.sqrt(u), 2 * math.pi * v
        out.append(Vector((r * math.cos(phi), r * math.sin(phi), math.sqrt(max(0.0, 1 - u)))))
    return out


def _cone(axis, n, spread, seed=9):
    """`n` directions within `spread` radians of `axis`."""
    rng = random.Random(seed)
    a = axis.normalized()
    u = a.orthogonal().normalized()
    v = a.cross(u)
    out = [a]
    for _ in range(n - 1):
        r, phi = spread * math.sqrt(rng.random()), 2 * math.pi * rng.random()
        out.append((a + u * (r * math.cos(phi)) + v * (r * math.sin(phi))).normalized())
    return out


def local_variation(points, colours, k_near, k_wide):
    """A function of a point: how much lighter (+) or darker (-) the generated
    model's colour is there than the model round it, -1..1. The model's own
    broad light and dark (its lit side and its shaded side) drops out; what is
    left is its local detail."""
    cols = np.asarray(colours, dtype=np.float64)
    lg = np.log(np.maximum(1e-4, 0.2126 * cols[:, 0] + 0.7152 * cols[:, 1] + 0.0722 * cols[:, 2]))
    kd = KDTree(len(points))
    for i, p in enumerate(points):
        kd.insert(Vector(p), i)
    kd.balance()

    def at(p):
        near = [i for _c, i, _d in kd.find_n(Vector(p), k_near)]
        wide = [i for _c, i, _d in kd.find_n(Vector(p), k_wide)]
        return float(max(-1.0, min(1.0, (lg[near].mean() - lg[wide].mean()) / 0.3)))
    return at


def auto_paint(wood_colours=(), leaf_var=None, wood_var=None, crown_from=1.95, cell=1.3, core=(0.05, 0.3, 1.0),
               bed=(0.2, 0.9, 1.0), tol=0.012):
    """Paint entries for a kit-built piece, read off its baked colours: leaf
    cards and the green cores of the crown are leaf, faces in the kit's bark
    colours (`wood_colours`: [(linear rgb, q_lo, q_hi)]) are wood. Cards share
    a group by where they stand (cells of `cell` metres), so neighbours take
    one tone and read as a clump."""
    paint = {}
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or not o.data.polygons:
            continue
        me, mw = o.data, o.matrix_world
        attr = me.color_attributes.get("Col")
        if attr is None:
            continue
        names = [m.name if m else "" for m in me.materials]
        out = []
        for p in me.polygons:
            nm = names[p.material_index] if names else ""
            c = mw @ p.center
            base = attr.data[p.loop_start].color
            r, g, b = base[0], base[1], base[2]
            entry = None
            if nm == CARDS:
                group = (round(c.x / cell), round(c.y / cell), round(c.z / cell))
                var = leaf_var(c) if leaf_var else 0.0
                entry = ("leaf", group, var, 0.0, 1.0, 1.0) if c.z > crown_from else ("leaf", group, var, bed[0], bed[1], bed[2])
            elif nm.startswith("baked_"):
                bark = next((w for w in wood_colours if abs(r - w[0][0]) + abs(g - w[0][1]) + abs(b - w[0][2]) < tol), None)
                if bark is not None:
                    entry = ("wood", None, wood_var(c) if wood_var else 0.0, bark[1], bark[2], 1.0)
                elif c.z > crown_from and g > r * 1.08 and g > b * 1.08:
                    entry = ("leaf", "core", 0.0, core[0], core[1], core[2])
            out.append(entry)
        paint[o.name] = out
    return paint


def winding_signs(obj):
    """+1 or -1 for each polygon of `obj`: -1 where it belongs to a closed solid that is wound inside out.
    The kits' box() and beam() are (the game shows them right because the kits' materials are two-sided), so a
    piece a kit's own builder made has its boxes' normals pointing inward. Open surfaces (leaf cards, blades)
    are left as they are."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    signs = [1] * len(bm.faces)
    seen = set()
    for f in bm.faces:
        if f.index in seen:
            continue
        island, stack, closed = [], [f], True
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                if len(e.link_faces) != 2:
                    closed = False
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        if not closed or len(island) < 4:
            continue
        volume = 0.0
        for g in island:
            vs = [v.co for v in g.verts]
            for k in range(1, len(vs) - 1):
                volume += vs[0].dot(vs[k].cross(vs[k + 1]))
        if volume < 0.0:
            for g in island:
                signs[g.index] = -1
    bm.free()
    return signs


def _diffuse(model):
    """The pack's diffuse response to the sun, as a function of normal . light."""
    if model.startswith("toon"):
        r = float(model.split(":")[1]) if ":" in model else 0.32

        def toon(x):
            t = max(0.0, min(1.0, (x + r) / (2.0 * r)))
            return t * t * (3.0 - 2.0 * t)
        return toon
    return lambda x: max(0.0, x)


def shade_scene(paint=None, ramps=None, rays=28, floor=0.5, gamma=0.6, reach=40.0, sun=NOON,
                ambient=(0.37, 0.42, 0.45), sun_energy=(1.2, 0.96, 0.66), take_out=0.75, e_ref=0.8, gain=None, cap=0.92,
                weights=None, card_block=0.45, sky_ref=None, tint=None, ao_share=0.25, up_from=0.5,
                channel=None, curve=None, class_gain=None, stop_gain=None, painted=None, diffuse="lambert",
                cards_shadowed=False, lamp=None, lamp_reach=5.0, turns=1, kind_marks=None, fix_winding=False):
    """Rewrites every baked face colour in the scene; returns statistics.

    paint:  {object name: [None, or (kind, group, extra, q_lo, q_hi, take) per polygon]}; kind
            names a ramp ("leaf", "wood", or any other: "timber", "stone" ...); `group` is a
            cluster, limb or part id; `extra` (-1..1) is the
            generated model's lighter-or-darker at that spot; a face's rank is squeezed
            into q_lo..q_hi (0..1 for the whole ramp); `take` (optional) scales take_out.
    ramps:  {"leaf": [hex, ...], "wood": [hex, ...]} from the concept sheet.
    ambient, sun_energy: the pack's ambient light and sun at the sheet's hour, colour times
            energy (linear RGB), as the client will light the piece; `diffuse` is the pack's
            response to the sun ("lambert", or "toon:<roughness>" for the cel pack);
            `cards_shadowed`: whether leaf cards receive shadows (the packs turn that off).
    take_out: how much of the game's predicted light is divided out of a painted colour
            (0 none: the game lights the painted colour; 1 all: it reads as painted).
    gain:   {"leaf": g, "wood": g} on the painted colours; `channel` the same per colour
            channel (the game's warm sun and tone curve shift hues); `class_gain` for faces
            that look up and for the rest; `stop_gain` per ramp stop; `curve` bends the
            ranks (above 1: more faces in the darker stops).
    weights: how much each thing moves a face along the ramp, per kind, for faces that look
            up and for the rest: {"leaf": {"up": {"facing", "sky", "group", "extra", "grain",
            "glow"}, "rest": {...}}, "wood": {...}}. `class_gain` is keyed the same way.
    lamp:   a lamp's place (a night sheet's tree is lit from under its crown); "glow" is how
            much a face is turned to it and how near, falling off over `lamp_reach` metres.
    tint:   colour multiplier (r, g, b) for the shade on unpainted faces.
    kind_marks: {kind: code} to mark each face's kind in a UV layer (kinds.py), so a capture
            can tell which pixels are which material; None writes no UVs.
    fix_winding: True for a piece a kit's own builder made: its closed solids that are wound inside out
            (winding_signs) are read the way the game shows them.
    turns:  1 for a piece that stands at one facing (the sun is taken out by direction); more
            (16, say) for a piece placed at several facings: the sun is averaged over that
            many turns about the vertical, and `painted` is then in the piece's own frame.
    """
    weights_in = weights
    # A kind with no weights of its own (timber, stone, plaster ...): the painted light gives
    # the piece its form, each part (group) its own tone, the rest a little.
    generic = {"up": {"facing": 0.25, "sky": 0.25, "group": 0.3, "extra": 0.0, "grain": 0.2, "glow": 0.0},
               "rest": {"facing": 0.45, "sky": 0.2, "group": 0.2, "extra": 0.0, "grain": 0.15, "glow": 0.0}}
    weights = {"leaf": {"up": {"facing": 0.0, "sky": 0.2, "group": 0.5, "extra": 0.2, "grain": 0.1, "glow": 0.0},
                        "rest": {"facing": 0.1, "sky": 0.2, "group": 0.45, "extra": 0.15, "grain": 0.1, "glow": 0.0}},
               # Bark: the painted light gives the limbs their round, the generated model its detail.
               "wood": {"up": {"facing": 0.3, "sky": 0.3, "group": 0.0, "extra": 0.25, "grain": 0.15, "glow": 0.0},
                        "rest": {"facing": 0.5, "sky": 0.15, "group": 0.0, "extra": 0.25, "grain": 0.1, "glow": 0.0}}}
    stops = {k: [hex_lin(h) for h in v] for k, v in (ramps or {}).items()}
    kinds = sorted(set(stops) | set(weights) | set(weights_in or {}))
    for kind in kinds:
        weights.setdefault(kind, {cls: dict(w) for cls, w in generic.items()})
    for kind, classes_ in (weights_in or {}).items():
        for cls, w in classes_.items():
            weights[kind][cls].update(w)
    gain = {**{k: 1.0 for k in kinds}, **(gain or {})}
    channel = {**{k: (1.0, 1.0, 1.0) for k in kinds}, **(channel or {})}
    curve = {**{k: 1.0 for k in kinds}, **(curve or {})}
    class_gain = {k: {"up": 1.0, "rest": 1.0, **(class_gain or {}).get(k, {})} for k in kinds}
    for kind, mult in (stop_gain or {}).items():
        if kind in stops:
            stops[kind] = [[c * m for c in stop] for stop, m in zip(stops[kind], mult)]
    response = _diffuse(diffuse)
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.data.polygons]
    # ---- What blocks light: solid faces fully, leaf cards in part ----
    verts, solid, cards = [], [], []
    for o in objs:
        me, mw = o.data, o.matrix_world
        base = len(verts)
        verts += [mw @ v.co for v in me.vertices]
        names = [m.name if m else "" for m in me.materials]
        for p in me.polygons:
            nm = names[p.material_index] if names else ""
            if "glow" in nm or nm == "lantern":
                continue
            vs = [base + i for i in p.vertices]
            into = cards if (nm == CARDS or nm.endswith("_leaves")) else solid
            for k in range(1, len(vs) - 1):
                into.append((vs[0], vs[k], vs[k + 1]))
    bvh = BVHTree.FromPolygons(verts, solid, all_triangles=True) if solid else None
    bvh_cards = BVHTree.FromPolygons(verts, cards, all_triangles=True) if cards else None

    def open_to(origin, d):
        """How much light comes along `d` to `origin`: 0 blocked, 1 open."""
        if bvh is not None and bvh.ray_cast(origin, d, reach)[0] is not None:
            return 0.0
        if bvh_cards is not None and bvh_cards.ray_cast(origin, d, reach)[0] is not None:
            return 1.0 - card_block
        return 1.0

    # The light the faces are ranked by (the painted light: high, a little toward the
    # viewer), apart from the sun the game's light is predicted with.
    painted_dir = Vector(painted).normalized() if painted is not None else sun
    lamp = Vector(lamp) if lamp is not None else None
    dirs = _dirs(rays)
    weight = sum(d.z for d in dirs)
    sun_dirs = _cone(sun, 5, 0.09)
    # A piece placed at several facings meets the sun from every side: its light is then the
    # mean over `turns` turns of the sun about the vertical (only how high the sun stands and
    # how far a face tips up can be taken out; which way it faces cannot).
    suns = [Vector((sun.x * math.cos(a) - sun.y * math.sin(a), sun.x * math.sin(a) + sun.y * math.cos(a), sun.z))
            for a in (2 * math.pi * k / turns for k in range(turns))] if turns > 1 else None
    up = Vector((0, 0, 1))
    # ---- Pass 1: what every face sees ----
    faces = []
    for o in objs:
        me, mw = o.data, o.matrix_world
        if me.color_attributes.get("Col") is None:
            continue
        names = [m.name if m else "" for m in me.materials]
        n3 = mw.to_3x3()
        corner = me.corner_normals
        signs = winding_signs(o) if fix_winding else None
        for p in me.polygons:
            nm = names[p.material_index] if names else ""
            card = nm == CARDS
            if not (nm.startswith("baked_") or card):
                continue
            c = mw @ p.center
            n = (n3 @ p.normal).normalized()
            if signs is not None and not card:
                n = n * signs[p.index]      # a kit solid wound inside out: the way the game shows it
            # What the game lights the face by: its own normal, or for a leaf card the
            # crown's soft normals the kit gave its corners.
            nl = n
            if card:
                s = Vector((0.0, 0.0, 0.0))
                for li in p.loop_indices:
                    s += corner[li].vector
                nl = (n3 @ s).normalized() if s.length > 1e-6 else n
            origin = c + (up * 0.06 if card else n * 0.03)
            sky = sum(d.z * open_to(origin, d) for d in dirs) / weight
            toward = nl.dot(sun)
            if card and not cards_shadowed:
                reaching = 1.0
            else:
                reaching = sum(open_to(origin, d) for d in sun_dirs) / len(sun_dirs) if toward > 0 else 0.0
            glow = 0.0
            if lamp is not None:
                to = lamp - c
                dist = max(0.3, to.length)
                glow = max(0.0, 0.35 + 0.65 * nl.dot(to / dist)) / (1.0 + (dist / lamp_reach) ** 2)
            direct = None
            if suns is not None:
                direct = 0.0
                for sd in suns:
                    t = nl.dot(sd)
                    if t > 0.0 or diffuse.startswith("toon"):
                        direct += response(t) * (1.0 if (card and not cards_shadowed) else open_to(origin, sd))
                direct /= len(suns)
            faces.append((o, p.index, sky, toward, reaching, card, nl.z, nl.dot(painted_dir), glow, direct))
    if sky_ref is None:
        # A tree hides most of itself: measure against its best-lit faces, not the open sky.
        vals = sorted(f[2] for f in faces)
        sky_ref = max(0.12, vals[int(0.9 * (len(vals) - 1))]) if vals else 1.0
    glow_ref = max([f[8] for f in faces] + [1e-6])
    # ---- Pass 2: rank the painted faces of each kind ----
    rng = random.Random(17)
    noise = {}
    scores = {}
    entries = {}
    classes = {}
    for i, (o, pi, sky, toward, reaching, card, nz, lit, glow, _direct) in enumerate(faces):
        e = (paint or {}).get(o.name)
        e = e[pi] if e is not None and pi < len(e) else None
        if e is None or e[0] not in stops:
            continue
        kind, group, extra = e[0], e[1], e[2]
        g = noise.setdefault((kind, group), rng.uniform(-1.0, 1.0)) if group is not None else 0.0
        cls = "up" if nz > up_from else "rest"
        w = weights[kind][cls]
        s = (w["facing"] * lit + w["sky"] * (2.0 * min(1.0, sky / sky_ref) - 1.0)
             + w["group"] * g + w["extra"] * extra + w["grain"] * rng.uniform(-1.0, 1.0)
             + w["glow"] * (2.0 * glow / glow_ref - 1.0))
        scores.setdefault((kind, cls), []).append((s, i))
        entries[i] = e
        classes[i] = cls
    rank = {}
    for _key, lst in scores.items():
        lst.sort()
        for r, (_s, i) in enumerate(lst):
            rank[i] = r / max(1, len(lst) - 1)
    # ---- Pass 3: write colours ----
    painted_n, shaded, capped = 0, 0, 0
    albedo = {k: [] for k in kinds}
    for i, (o, pi, sky, toward, reaching, card, nz, lit, glow, direct_mean) in enumerate(faces):
        me = o.data
        attr = me.color_attributes["Col"]
        p = me.polygons[pi]
        s = min(1.0, sky / sky_ref)
        if i in entries:
            kind, _group, _extra, q_lo, q_hi = entries[i][:5]
            take = take_out * (entries[i][5] if len(entries[i]) > 5 else 1.0)
            q = q_lo + (q_hi - q_lo) * rank[i] ** curve[kind]
            target = ramp_at(stops[kind], q)
            # The light the game will put on this face at the sheet's hour, to take (partly)
            # back out. The game's ambient light is one colour everywhere; only its
            # screen-space occlusion takes a little off in the crown's creases. Per colour
            # channel: the sun is warm and the ambient light cool.
            direct = response(toward) * reaching if direct_mean is None else direct_mean
            e_face = [ambient[c] * (1.0 - ao_share + ao_share * s) + sun_energy[c] * direct for c in range(3)]
            k = gain[kind] * class_gain[kind][classes[i]]
            col = [target[c] * k * channel[kind][c] / max(0.05, e_face[c] / e_ref) ** take for c in range(3)]
            m = max(col)
            if m > cap:                      # keep the hue: bring all three down together
                col = [c * cap / m for c in col]
                capped += 1
            albedo[kind].append(lum(col))
            painted_n += 1
        else:
            base = attr.data[p.loop_start].color
            f = floor + (1.0 - floor) * (s ** gamma)
            f *= 1.0 + 0.05 * (rng.random() * 2.0 - 1.0)
            t = tint or (1.0, 1.0, 1.0)
            t = [t[c] + (1.0 - t[c]) * s for c in range(3)]
            col = [min(1.0, base[c] * f * t[c]) for c in range(3)]
            shaded += 1
        for li in p.loop_indices:
            attr.data[li].color = (col[0], col[1], col[2], 1.0)
    # Which material each face is, for a capture to read back (kinds.py): a UV layer whose u is
    # the kind's code. Flat-coloured pieces have no UVs of their own, so it is their first layer; a
    # piece with leaf cards keeps its texture's layer first and takes the marks as a second.
    marked = 0
    if kind_marks:
        for o in objs:
            me = o.data
            e = (paint or {}).get(o.name)
            if e is None:
                continue
            first = me.uv_layers[0] if len(me.uv_layers) else None
            uv = me.uv_layers.new(name="kind", do_init=False)
            if first is not None:
                me.uv_layers.active = me.uv_layers[first.name]
                me.uv_layers[first.name].active_render = True
            for p in me.polygons:
                code = kind_marks.get(e[p.index][0], 0.0) if p.index < len(e) and e[p.index] is not None else 0.0
                for li in p.loop_indices:
                    uv.data[li].uv = (code, 0.0)
                marked += code > 0.0
    sky_all = np.array([f[2] for f in faces]) if faces else np.zeros(1)
    out = {"painted": painted_n, "shaded": shaded, "capped": capped, "solid_occluders": len(solid),
           "card_occluders": len(cards), "sky_ref": round(float(sky_ref), 3),
           "sky_seen_mean": round(float(sky_all.mean()), 3)}
    for kind, vals in albedo.items():
        if vals:
            out[f"{kind}_albedo_p10_p50_p90"] = [round(float(np.percentile(vals, q)), 3) for q in (10, 50, 90)]
    return out
