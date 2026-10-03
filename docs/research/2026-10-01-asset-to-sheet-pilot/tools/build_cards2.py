"""Round 2 for the leaf-card kits (anime, solarpunk, neon): the pack's
`tree_banyan.glb` built by the kit's own banyan builder round a generated
tree, as in round 1, with the surface and colour reworked.

    blender --background --factory-startup --python build_cards2.py -- KIT PARTS_DIR NAME OUT.glb [PARAMS.json]

Round 1 swapped in the generated trunk, limbs and crown layout. This build
also changes what round 1 left alone:

  * the crown is some fifty small lobes of smaller leaf cards, where round 1
    had 30 large ones and the kit has 13;
  * leaf cards, the crown's cores and the bark are painted from the style's
    own concept sheet (ramps.json), not the kit's four palette greens, and the
    game's light at the sheet's hour is partly taken back out (shade.py);
  * for a night sheet (neon), leaves take the ramp's warm end by how near the
    tree's lamp they are and how they are turned to it.

Everything else is the kit's: the planter ring and its bed, the surface roots
that fill the tree's square, the leaf cards' texture and soft normals, the
lights.
"""
import json
import os
import sys
from pathlib import Path

import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
kit, parts, name, out = argv[0], Path(argv[1]), argv[2], Path(argv[3])
HERE = Path(__file__).resolve().parent
ROOT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
PACK = {"anime": "anime_cel", "solarpunk": "solarpunk", "neon": "neon_noir"}[kit]
# The pack's style as the scratch copy of the client has it (its light keys).
STYLE = json.loads((HERE / "city" / "godot" / "styles" / PACK / "style.json").read_text())
P = {"lobes": 46, "card": 1.0, "cover": 3.4, "reach": 1.14, "full": 1.1, "cell": 0.8,
     # The anime sheet's tree is a broad shade tree with one trunk: no aerial roots there.
     "aerial_roots": kit != "anime", "take_out": 0.85, "gain_leaf": 1.0,
     "gain_wood": 1.0, "floor": 0.6, "ao_share": 0.3, "e_ref": 0.8, "weights": {}, "channel": {}, "curve": {},
     "class_gain": {}, "stop_gain": {}, "core": [0.05, 0.3, 1.0], "painted": [-0.2, -0.3, 0.93],
     "minute": 1308 if STYLE.get("sheet_night") else 780,
     "diffuse": "toon:0.32" if kit == "anime" else "lambert", "lamp_reach": 5.0}
if kit == "neon":
    # A night sheet: lamps light the tree, not the sky, so none of the sky's light is taken
    # out; leaves take the warm end of the ramp near the lamp under the crown.
    P["take_out"] = 0.0
    P["weights"] = {"leaf": {"up": {"glow": 0.5, "group": 0.3, "sky": 0.0, "extra": 0.1, "grain": 0.1},
                             "rest": {"glow": 0.6, "group": 0.2, "sky": 0.0, "facing": 0.0, "extra": 0.1, "grain": 0.1}},
                    "wood": {"up": {"glow": 0.5, "facing": 0.1, "sky": 0.1}, "rest": {"glow": 0.5, "facing": 0.2, "sky": 0.05}}}
if len(argv) > 4 and Path(argv[4]).exists():
    P.update(json.loads(Path(argv[4]).read_text()))
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / "shared"))
sys.path.insert(0, str(ROOT / kit))
import lib  # noqa: E402  (this kit's palette and exporter)
import vegetation as veg  # noqa: E402
import foliage  # noqa: E402
import shade  # noqa: E402

load = lambda suffix: json.loads((parts / f"{name}-{suffix}.json").read_text())  # noqa: E731
wood, drops, report, colours = (load(s) for s in ("wood", "drops", "report", "colours"))
ramps = json.loads((HERE / "ramps.json").read_text())[PACK]


def light_at(minute):
    """The pack's sun and ambient light at `minute`, colour times energy (linear RGB)."""
    keys = sorted(STYLE["day_night"]["keys"], key=lambda k: k["m"])
    a = max([k for k in keys if k["m"] <= minute] or [keys[-1]], key=lambda k: k["m"])
    b = min([k for k in keys if k["m"] > minute] or [keys[0]], key=lambda k: k["m"])
    span = (b["m"] - a["m"]) % 1440 or 1440
    t = ((minute - a["m"]) % 1440) / span

    def mix(field):
        ca, cb = shade.hex_lin(a[field]), shade.hex_lin(b[field])
        ea, eb = a[field + "_energy"], b[field + "_energy"]
        return [(ca[i] + (cb[i] - ca[i]) * t) * (ea + (eb - ea) * t) for i in range(3)]
    return mix("sun"), mix("ambient")


# ---- The crown's lobes: the generated crown's leaf surface gathered into small masses ----
pts = np.asarray(colours["leaf"]["points"], dtype=np.float64)
rng = np.random.default_rng(7)
centres = pts[rng.choice(len(pts), P["lobes"], replace=False)]
for _ in range(30):
    label = np.argmin(((pts[:, None, :] - centres[None, :, :]) ** 2).sum(axis=2), axis=1)
    for k in range(P["lobes"]):
        if (label == k).any():
            centres[k] = pts[label == k].mean(axis=0)
cc = report["crown_centre"]
crown_lobes = []
for k in range(P["lobes"]):
    mine = pts[label == k]
    if len(mine) < 8:
        continue
    radii = np.clip(mine.std(axis=0) * 1.9, 0.6, 1.45) * P["full"]
    c = centres[k]
    # Leaf cards reach about half a card past their lobe and must clear the walking band's 1.9 m.
    z = max(float(c[2]), 2.05 + float(radii[2]) + 0.55 * P["card"])
    crown_lobes.append(((cc[0] + (c[0] - cc[0]) * P["reach"], cc[1] + (c[1] - cc[1]) * P["reach"], z),
                        (float(radii[0]), float(radii[1]), float(radii[2]))))
# The generator saw the tree from the side and left the crown thin on top: a lobe
# wherever, seen from above, none covers the crown, so it is whole from the
# city-builder camera.
import math  # noqa: E402
reach_at = {}
for x, y, _z in pts:
    b = round(math.degrees(math.atan2(y - cc[1], x - cc[0])) / 20.0)
    reach_at.setdefault(b, []).append(math.hypot(x - cc[0], y - cc[1]))
reach_at = {b: float(np.percentile(v, 90)) * P["reach"] for b, v in reach_at.items()}
step, filled = 1.5, 0
for i in range(-6, 7):
    for j in range(-6, 7):
        x, y = cc[0] + (i + 0.5 * (j % 2)) * step, cc[1] + j * step
        b = round(math.degrees(math.atan2(y - cc[1], x - cc[0])) / 20.0)
        if math.hypot(x - cc[0], y - cc[1]) > 0.85 * reach_at.get(b, 0.0):
            continue
        if any(((x - c[0]) / (r[0] * 0.85)) ** 2 + ((y - c[1]) / (r[1] * 0.85)) ** 2 < 1.0 and c[2] > cc[2] for c, r in crown_lobes):
            continue
        near = sorted(crown_lobes, key=lambda lobe: (lobe[0][0] - x) ** 2 + (lobe[0][1] - y) ** 2)[:5]
        z = max(c[2] + 0.4 * r[2] for c, r in near)
        crown_lobes.append(((x, y, z), (1.25, 1.25, 0.85)))
        filled += 1
half = report["crown_half"]
whole = ((cc[0], cc[1], cc[2]), (half[0] * P["reach"] + 0.3, half[1] * P["reach"] + 0.3, half[2] + 0.5))

# Where the kit's helpers really live: the anime kit's vegetation module, which
# solarpunk and neon load by path under their own names.
A = next((m for k, m in sys.modules.items() if k.endswith("anime_vegetation")), veg)
real_tube, real_fit, real_finish, real_crown = A.tube, A.fit, veg.finish, foliage.crown
real_roots = A.square_roots
state = {"skip": True, "added": False, "cards": 0, "pruned": 0}


def tube(m, pts_, radii, mat, *a, **kw):
    """The kit's own trunk, limbs and aerial roots are left out."""
    if state["skip"]:
        return None
    return real_tube(m, pts_, radii, mat, *a, **kw)


def square_roots(m, ring, half_, mat, *a, **kw):
    state["skip"] = False
    try:
        return real_roots(m, ring, half_, mat, *a, **kw)
    finally:
        state["skip"] = True


def crown(m, its_lobes, card, seed, *a, **kw):
    if card >= 1.0:   # the great crown (the planter's bed uses small cards)
        kw["whole"] = whole
        kw["cover"] = P["cover"]
        state["cards"] = real_crown(m, crown_lobes, P["card"], seed, *a, **kw)
        return state["cards"]
    return real_crown(m, its_lobes, card, seed, *a, **kw)


def fit(m, first, width, depth, *a, **kw):
    if width > 10:   # the crown: keep the generated tree's own size
        return None
    return real_fit(m, first, width, depth, *a, **kw)


def finish(asset, meshes, *a, **kw):
    body = meshes["body"]
    if not state["added"]:
        state["added"] = True
        start = A.mark(body)
        # Limb ends that would stick out of the crown are left off: above the fork, only
        # wood inside a lobe is kept.
        wv = wood["verts"]

        def inside(face):
            x, y, z = (sum(wv[i][k] for i in face) / len(face) for k in range(3))
            if z < 4.2:
                return True
            return any(((x - c[0]) / r[0]) ** 2 + ((y - c[1]) / r[1]) ** 2 + ((z - c[2]) / r[2]) ** 2 < 0.9 for c, r in crown_lobes)
        kept = [f for f in wood["faces"] if inside(f)]
        state["pruned"] = len(wood["faces"]) - len(kept)
        A.add(body, wv, kept, "trunk_light")
        body.bm.faces.ensure_lookup_table()
        dark = body.slot("trunk")
        for f in list(body.bm.faces)[start:]:
            f.normal_update()
            if f.normal.z < -0.3:
                f.material_index = dark
        state["skip"] = False
        for k, (x, y, z) in enumerate(drops if P["aerial_roots"] else []):
            d = Vector((x, y, 0)).normalized()
            foot = d * (1.3 + 0.2 * (k % 2)) + Vector((0, 0, 0.36))
            topv = Vector((x, y, z))
            real_tube(body, [topv, topv.lerp(foot, 0.5) + d * 0.05, foot], [0.07, 0.06, 0.09], "trunk", sides=5)
        state["skip"] = True
    return real_finish(asset, meshes, *a, **kw)


# The kit's builder looks these names up in its own module (and the anime
# kit's helpers in theirs), so swap them in both places.
for mod in {veg, A}:
    if hasattr(mod, "tube"):
        mod.tube = tube
    if hasattr(mod, "fit"):
        mod.fit = fit
    if hasattr(mod, "square_roots"):
        mod.square_roots = square_roots
veg.finish = finish
foliage.crown = crown

sys.modules["lib"] = lib
lib.reset()
veg.tree_banyan()
import bake  # noqa: E402  (tools/styles/shared: palette colours into vertex colours, as the kit's build does)
import bpy  # noqa: E402
bake.bake_scene()
bpy.context.view_layer.update()

leaf_var = shade.local_variation(colours["leaf"]["points"], colours["leaf"]["colours"], 10, 300)
wood_var = shade.local_variation(colours["wood"]["points"], colours["wood"]["colours"], 6, 120)
# The kit's lighter bark takes the whole ramp; its darker bark (undersides, aerial roots) the darker half.
paint = shade.auto_paint(wood_colours=[(lib.rgb("trunk_light"), 0.0, 1.0), (lib.rgb("trunk"), 0.0, 0.55)],
                         leaf_var=leaf_var, wood_var=wood_var, core=tuple(P["core"]), cell=P["cell"])
sun_now, ambient_now = light_at(P["minute"])
lamp = bpy.data.objects.get("lights")
lamp_at = tuple(lamp.matrix_world.translation) if (lamp is not None and kit == "neon") else None
stats = shade.shade_scene(paint=paint, ramps=ramps, floor=P["floor"], ambient=ambient_now, sun_energy=sun_now,
                          ao_share=P["ao_share"], take_out=P["take_out"], e_ref=P["e_ref"], weights=P["weights"],
                          gain={"leaf": P["gain_leaf"], "wood": P["gain_wood"]}, channel=P["channel"],
                          curve=P["curve"], class_gain=P["class_gain"], stop_gain=P["stop_gain"],
                          painted=P["painted"], diffuse=P["diffuse"], lamp=lamp_at, lamp_reach=P["lamp_reach"])
out.parent.mkdir(parents=True, exist_ok=True)
lib.export(out)
stats.update({"sun": [round(v, 3) for v in sun_now], "ambient": [round(v, 3) for v in ambient_now], "lamp": lamp_at})
print(f"BUILD {kit}2: wrote {out} ({lib.triangles()} triangles, {len(crown_lobes)} lobes ({filled} fill the top), {state['cards']} cards, "
      f"{len(drops) if P['aerial_roots'] else 0} aerial roots, {state['pruned']} wood faces outside the crown left off) {json.dumps(stats)}")
