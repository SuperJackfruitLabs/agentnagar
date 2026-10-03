"""The park bench (seat_bench_v2.glb) for the four Blender kits, drawn as each style's sheet draws it and
painted from that sheet's colours.

    blender --background --factory-startup --python bench/build_bench.py -- KIT OUT.glb [PARAMS.json]

KIT is lowpoly, anime, solarpunk or neon. Built with the kit's own helpers (its Mesh, Frame, palette, finish,
bake and exporter), so the pack's conventions hold: the sitter's place is the origin, facing +Y; the seat's
top is where the kit has it; the node names are the kit's; the piece's slice where people walk is the
catalogue's bench footprint (1.6 m by 0.6 m, from 0.25 m ahead of the sitter to 0.35 m behind). The game then
stretches it to the cells its walking grid blocks: 4 to 7% in depth where the fixture places benches (the
kits' own benches, 0.57 to 0.59 m deep, are stretched 6 to 10%).

What each sheet draws (WATERFRONT PARK panel), against the kit's bench of thin slats on a thin frame:
  lowpoly    a chunky bench: a thick seat of two broad boards, a back of two broad planks, timber arm blocks,
             dark posts
  anime      broad planks on dark iron ends, each a flat bar bent into leg, arm and back post
  solarpunk  all timber: slats between solid timber ends under a timber arm, a thick top rail
  neon       dark slats under a thick top rail on black iron ends, a warm strip under the seat (the kit's)

Timber and frame are painted from the sheet's ramps (bench/ramps.json) by shade.py, through marks.py.
"""
import json
import math
import os
import sys
from pathlib import Path

argv = sys.argv[sys.argv.index("--") + 1:]
kit, out = argv[0], Path(argv[1])
HERE = Path(__file__).resolve().parent
TOOLS = HERE.parent
ROOT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
PACK = {"lowpoly": "lowpoly_tropical", "anime": "anime_cel", "solarpunk": "solarpunk", "neon": "neon_noir"}[kit]
STYLE = json.loads((TOOLS / "city" / "godot" / "styles" / PACK / "style.json").read_text())
CONFIG = json.loads((HERE / "asset.json").read_text())
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(ROOT / "shared"))
sys.path.insert(0, str(ROOT / kit))
import lib  # noqa: E402  (this kit's palette, Mesh and exporter)
import props  # noqa: E402  (this kit's Frame and finish)
from lib import Mesh, rotx  # noqa: E402
import marks  # noqa: E402

P = marks.settings(STYLE, toon=kit == "anime")
# Iron: dark all over, only its tops catching a little light.
P["ranges"] = {"frame": {"tops": [0.3, 0.85], "sides": [0.0, 0.5], "under": [0.0, 0.2]}}
# Timber: each plank its own tone; the frame: by how it faces the painted light.
P["weights"] = {"timber": {"up": {"facing": 0.2, "sky": 0.25, "group": 0.45, "grain": 0.1},
                           "rest": {"facing": 0.4, "sky": 0.2, "group": 0.3, "grain": 0.1}},
                "frame": {"up": {"facing": 0.5, "sky": 0.3, "group": 0.1, "grain": 0.1},
                          "rest": {"facing": 0.5, "sky": 0.3, "group": 0.1, "grain": 0.1}}}
if len(argv) > 2 and Path(argv[2]).exists():
    P.update(json.loads(Path(argv[2]).read_text()))

sys.modules["lib"] = lib
lib.reset()
Frame = props.Frame if hasattr(props, "Frame") else props.A.Frame       # the neon kit builds on the anime kit's
ramps = json.loads((HERE / "ramps.json").read_text())[PACK]
T = math.tan


def boards(f, k, kind, part, x_cuts, size_yz, at_yz, mat, bevel, rot=None):
    """A plank along x from -0.8 to 0.8, in lengths butted end to end at `x_cuts`."""
    xs = [-0.8] + list(x_cuts) + [0.8]
    for i in range(len(xs) - 1):
        x0, x1 = xs[i] + (0.004 if i else 0.0), xs[i + 1] - (0.004 if i < len(xs) - 2 else 0.0)
        f.box((x1 - x0, size_yz[0], size_yz[1]), ((x0 + x1) / 2, at_yz[0], at_yz[1]), mat, bevel=bevel, rot=rot)
        k.mark(kind, (part, i))


def bar(f, x, a, b, w, d, mat, bevel=0.0):
    """A straight bar in the plane x = const from (y, z) `a` to `b`, `w` across x and `d` deep in the plane.
    (The kits' beam() turns its section any way round its axis: no good for a flat bar or a tight fit.)"""
    (y0, z0), (y1, z1) = a, b
    f.box((w, d, math.hypot(y1 - y0, z1 - z0)), (x, (y0 + y1) / 2, (z0 + z1) / 2), mat, bevel=bevel,
          rot=rotx(math.degrees(math.atan2(-(y1 - y0), z1 - z0))))


def lowpoly(f, k):
    top = 0.47                                   # the kit's seat is 0.475 up
    # The seat: two broad boards, 10 cm thick, each in two lengths.
    boards(f, k, "timber", "seat-front", (0.18,), (0.22, 0.10), (0.14, top - 0.05), "wood", 0.012)
    boards(f, k, "timber", "seat-back", (-0.30,), (0.22, 0.10), (-0.09, top - 0.05), "wood", 0.012)
    # The back: two broad planks, raked, a hand above the seat.
    rake = 10.0
    by = lambda z: -0.19 - (z - 0.56) * T(math.radians(rake))  # noqa: E731
    boards(f, k, "timber", "back-low", (0.25,), (0.065, 0.17), (by(0.66), 0.66), "wood", 0.012, rot=rotx(rake))
    boards(f, k, "timber", "back-high", (-0.20,), (0.065, 0.17), (by(0.84), 0.84), "wood", 0.012, rot=rotx(rake))
    for x in (-0.70, 0.70):
        # Dark posts: one behind the planks, raked with them; a leg at the front; a rail under the seat.
        bar(f, x, (by(0.0) - 0.066, 0.0), (by(0.90) - 0.066, 0.90), 0.07, 0.07, "iron")
        bar(f, x, (0.17, 0.0), (0.17, top - 0.10), 0.08, 0.08, "iron")
        bar(f, x, (0.17, 0.33), (by(0.33) - 0.066, 0.33), 0.06, 0.06, "iron")
        k.mark("frame", ("post", x))
        # A timber arm block on the seat's end.
        f.box((0.10, 0.36, 0.15), (0.75 if x > 0 else -0.75, 0.0, top + 0.075), "wood_light", bevel=0.025)
        k.mark("timber", ("arm", x))
    return {}


def iron_ends(f, k, by, top, post_top, wide=0.04):
    """The anime sheet's ends: a flat iron bar bent into front leg, arm and raked back post, a rail under the
    seat, and feet."""
    py = lambda z: by(z) - 0.045  # noqa: E731
    for x in (-0.71, 0.71):
        bar(f, x, (py(0.0), 0.0), (py(post_top), post_top), wide, 0.05, "iron")
        bar(f, x, (0.19, 0.0), (0.19, 0.60), wide, 0.05, "iron")
        bar(f, x, (0.19, 0.59), (0.14, 0.655), wide, 0.05, "iron")                  # the arm's rounded corner
        f.box((0.07, 0.165 - py(0.66), 0.035), (x, (0.165 + py(0.66)) / 2, 0.665), "iron", bevel=0.012)
        bar(f, x, (0.19, top - 0.08), (py(top - 0.08), top - 0.08), wide, 0.045, "iron")
        for y in (0.19, py(0.0)):
            f.box((0.10, 0.10, 0.025), (x, y, 0.0125), "iron", bevel=0.006)
        k.mark("frame", ("end", x))


def anime(f, k):
    top = 0.47
    # The seat: three broad planks; the back: two.
    for i in range(3):
        f.box((1.6, 0.148, 0.055), (0, -0.215 + 0.155 * (i + 0.5), top - 0.0275), "wood_light", bevel=0.012)
        k.mark("timber", ("seat", i))
    rake = 12.0
    by = lambda z: -0.205 - (z - 0.5) * T(math.radians(rake))  # noqa: E731
    for i, z in enumerate((0.625, 0.795)):
        f.box((1.6, 0.04, 0.15), (0, by(z), z), "wood_light", bevel=0.01, rot=rotx(rake))
        k.mark("timber", ("back", i))
    iron_ends(f, k, by, top, 0.87)
    return {"smooth": props.SMOOTH}


def solarpunk(f, k):
    top = 0.47
    for i, y in enumerate((-0.139, -0.028, 0.083, 0.194)):
        f.box((1.6, 0.102, 0.05), (0, y, top - 0.025), "timber_light", bevel=0.012)
        k.mark("timber", ("seat", i))
    rake = 14.0
    by = lambda z: -0.20 - (z - 0.5) * T(math.radians(rake))  # noqa: E731
    for i, z in enumerate((0.575, 0.665, 0.755)):
        f.box((1.6, 0.035, 0.075), (0, by(z), z), "timber_light", bevel=0.008, rot=rotx(rake))
        k.mark("timber", ("back", i))
    # A thick top rail.
    f.box((1.6, 0.065, 0.085), (0, by(0.855), 0.855), "timber", bevel=0.02, rot=rotx(rake))
    k.mark("timber", ("rail", 0))
    # Solid timber ends (the kit's end frame without its opening, and in timber), a post and a timber arm.
    outer = [(0.21, 0.0), (0.21, 0.4), (0.19, 0.425), (-0.19, 0.425), (-0.225, 0.47), (-0.30, 0.88), (-0.34, 0.885),
             (-0.29, 0.45), (-0.25, 0.0)]
    for x in (-0.70, 0.70):
        f.m.slab(outer, [], 0.07, f.p((x, 0, 0)), "timber", axis="x", rot=f.r)
        k.mark("timber", ("end", x))
        f.box((0.07, 0.06, 0.2), (x, 0.18, 0.525), "timber", bevel=0.012)
        k.mark("timber", ("post", x))
        f.box((0.09, 0.46, 0.05), (x, -0.02, 0.648), "timber_dark", bevel=0.016)
        k.mark("timber", ("arm", x))
    return {"smooth": props.SMOOTH}


def neon(f, k):
    top = 0.47
    for i, y in enumerate((-0.139, -0.028, 0.083, 0.194)):
        f.box((1.6, 0.098, 0.045), (0, y, top - 0.0225), "wood", bevel=0.01)
        k.mark("timber", ("seat", i))
    rake = 12.0
    by = lambda z: -0.205 - (z - 0.5) * T(math.radians(rake))  # noqa: E731
    for i, z in enumerate((0.575, 0.66, 0.745)):
        f.box((1.6, 0.03, 0.065), (0, by(z), z), "wood", bevel=0.008, rot=rotx(rake))
        k.mark("timber", ("back", i))
    f.box((1.6, 0.06, 0.09), (0, by(0.845), 0.845), "wood", bevel=0.014, rot=rotx(rake))
    k.mark("timber", ("rail", 0))
    iron_ends(f, k, by, top, 0.87)
    return {"smooth": props.SMOOTH, "lights": True}


m = Mesh()
marked = marks.Marks(m, P)
made = {"lowpoly": lowpoly, "anime": anime, "solarpunk": solarpunk, "neon": neon}[kit](Frame(m), marked)
assert len(marked.entries) == len(m.bm.faces)
name = "seat_bench_v2"
if kit == "lowpoly":
    props.finish(name, {"body": m})
elif kit == "neon":
    props.veg.finish(name, {"body": m}, smooth={"body": made["smooth"]})
    glow = Mesh()                     # the kit's warm strip under the seat's front edge
    glow.box((1.2, 0.02, 0.016), (0, 0.235, 0.415), "lamp_glow")
    props.part(name, "lights", glow, at=(0, 0.235, 0.415))
else:
    props.finish(name, {"body": m}, smooth={"body": made["smooth"]})
import bake  # noqa: E402  (tools/styles/shared: palette colours into vertex colours, as the kits' builds do)
import bpy  # noqa: E402
bake.bake_scene()
bpy.context.view_layer.update()
stats = marks.paint({"body": marked.entries}, ramps, STYLE, P, CONFIG["kinds"])
out.parent.mkdir(parents=True, exist_ok=True)
lib.export(out)
print(f"BUILD bench {kit}: wrote {out} ({lib.triangles()} triangles) {json.dumps(stats)}")
