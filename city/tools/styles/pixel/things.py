"""The things to use (interactions spec sections 2 and 3) in the pixel kit:
the displays (noticeboard, plaque, kiosk), the perches (steps, low wall,
fountain) and the seat stone a sitter takes on one, and the meadow's
clumps, each pre-rendered from its model like every kit sprite.

They are the same objects the 3D kits draw (tools/styles/shared/
usables.py): a noticeboard is a board on two posts under a little roof,
the steps are two treads, the fountain a basin with a pedestal of bowls,
and a sitter on a perch sits on a stone seat that reaches back into it.

Conventions (see models.py):

- A kind's model is built in its own frame (its front, where a display
  faces and a sitter looks, toward -z) and turned to each facing it is
  drawn at (`m.turn = -facing`): four right angles, or one for the round
  fountain; a seat stone at the eight facings a sitter can face.
- **Where people walk** (0.25-1.9 m up) a fixture stands on the rectangle
  the grid blocks for its footprint at that facing (`drawn_rect`, the
  styles' CityGeometry.drawn_rect): a footing fills it and everything
  else keeps inside it, so nothing walkable is within the body clearance
  of it and nothing blocked stands clear of it. Above the band a piece may
  reach past it (the noticeboard's roof).
- Every sprite's info carries `band_shapes`: its shapes in the band about its
  ground point, before its turn (`facing`), as the collision audit reads a
  sprite (tools/collision_audit/solids_2d.gd): ["rect", x0, x1, z0, z1]
  or ["disc", r, x, z], metres. render.py checks them against the model's
  own geometry, so the audit's table cannot drift from what is drawn.
- A display's info carries `display`: the middle of its drawn face (x, z,
  y, metres about its ground point, before its turn) and the face's width
  and height, where the pack fits the surface's text.
- A meadow clump comes in three frames: at rest, pushed and swinging back
  (`rustle`), which the pack plays when someone passes through it.
"""
import json
import math
import random
from pathlib import Path

import models
from models import Model, out

CATALOGUE = json.loads((Path(__file__).resolve().parents[3] / "catalogue" / "catalogue.json").read_text())
KINDS = {k["id"]: k for k in CATALOGUE["kinds"]}

# The walking band, metres.
BAND = (0.25, 1.9)
# The grid's cells are 25 cm with their centres 12 cm past a corner, and a
# placement's point lies on the 25 cm snap; a cell whose centre is within
# the body clearance (10 cm) of a footprint is blocked. In centimetres.
CELL, CENTRE, CLEARANCE = 25, 12, 10
# A fixture's footing, which fills its drawn rectangle into the band.
FOOTING = 0.3
# The facings a sitter's seat stone is drawn at.
SEAT_FACINGS = (0, 45, 90, 135, 180, 225, 270, 315)
# How high a perch's seat is (the 3D kits' SEAT_TOP), and how far it
# reaches in front of the sitter's place and behind it, into the perch.
# It keeps a centimetre inside the 3D kits' seat (15 cm in front, 30 cm
# wide): a stone off the 25 cm lattice (a sit anchor) is drawn on its
# nearest pixel, up to a centimetre or so off its anchor, and must still
# keep to the square round it that the collision audit leaves to it.
SEAT_TOP = 0.46
SEAT_FRONT = 0.14
SEAT_BACK = 0.40
SEAT_HALF_WIDTH = 0.14


def turned(x, z, facing):
    """A point of a kind's frame turned to `facing` (degrees clockwise
    from north), as the core turns it."""
    t = math.radians(facing)
    c, s = round(math.cos(t), 12), round(math.sin(t), 12)
    return (x * c - z * s, x * s + z * c)


def drawn(lo, hi):
    """One side of a footprint rectangle (cm about its point, in the
    world's axes) as the styles draw it (CityGeometry.drawn_rect): an edge
    that blocked cells' centres lie beyond moves out to 2.5 cm past them."""
    first = CENTRE + CELL * -((CENTRE - (lo - CLEARANCE)) // CELL)
    last = CENTRE + CELL * ((hi + CLEARANCE - 1 - CENTRE) // CELL)
    return min(lo, first - 2.5), max(hi, last + 2.5)


def drawn_rect(kind, facing):
    """The rectangle a kind's (one-rectangle) footprint is drawn on at
    `facing`, a right angle, in the kind's own frame, metres: the world's
    drawn rectangle turned back, so the model turned to `facing` stands on
    it exactly. (The lattice is a centimetre lopsided, so each facing's
    rectangle differs a little.)"""
    (sh,) = KINDS[kind]["footprint"]
    corners = [turned(sh["x"] + dx, sh["z"] + dz, facing) for dx in (0, sh["w"]) for dz in (0, sh["d"])]
    x0, x1 = drawn(min(c[0] for c in corners), max(c[0] for c in corners))
    z0, z1 = drawn(min(c[1] for c in corners), max(c[1] for c in corners))
    back = [turned(x, z, -facing) for x in (x0, x1) for z in (z0, z1)]
    return tuple(round(v / 100, 4) for v in (min(p[0] for p in back), max(p[0] for p in back),
                                             min(p[1] for p in back), max(p[1] for p in back)))


def rect(r):
    return ["rect", *r]


# ---- Displays: each faces -z (its display anchor's facing), as the kind ----

# The middle of each display's face (x, z, y) and its size (width,
# height), metres, in the kind's frame: as the 3D kits draw them
# (usables.DISPLAY), a noticeboard's board 0.94 x 0.80 m from 0.90 m up.
DISPLAY = {
    "noticeboard": ((0.0, -0.05, 1.30), (0.94, 0.80)),
    "plaque": ((0.0, -0.12, 0.975), (0.48, 0.34)),
    "kiosk": ((0.0, -0.245, 1.30), (0.60, 0.80)),
}


def noticeboard(facing):
    """A board on two posts: a stone footing on the kind's drawn
    rectangle, timber posts at its ends, the framed board between them
    (its face navy, lettered with notices) over a ledge, and a little
    terracotta roof above the walking band."""
    x0, x1, z0, z1 = drawn_rect("noticeboard", facing)
    (cx, cz, cy), (w, h) = DISPLAY["noticeboard"]

    def build():
        m = Model()
        m.turn = -facing
        m.box(x0, x1, z0, z1, 0.0, FOOTING, "stone_light")
        for a, b in ((x0 + 0.03, x0 + 0.14), (x1 - 0.14, x1 - 0.03)):
            m.box(a, b, -0.055, 0.055, FOOTING, 2.3, "wood_dark")
        m.box(x0 + 0.1, x1 - 0.1, -0.04, 0.04, 0.86, 1.74, "wood")
        m.box(cx - w / 2, cx + w / 2, cz, -0.04, cy - h / 2, cy + h / 2, "sign")
        m.box(x0 + 0.1, x1 - 0.1, -0.1, 0.04, 0.82, 0.86, "wood")
        # The roof: a ridge along x over two slopes, from 2.24 m.
        m.box(x0 + 0.05, x1 - 0.05, -0.05, 0.05, 2.24, 2.3, "wood_dark")
        m.prism_x([(-0.34, 2.3), (0.34, 2.3), (0.0, 2.52)], x0 - 0.07, x1 + 0.07, "roof_red")
        return m.build("noticeboard")
    return build


def plaque(facing):
    """A lettered bronze plaque on a stone: the plinth on the kind's
    drawn rectangle, an upright stone to 1.2 m under a cap, and the plaque
    on its face, 50 x 35 cm."""
    x0, x1, z0, z1 = drawn_rect("plaque", facing)
    (cx, cz, cy), (w, h) = DISPLAY["plaque"]

    def build():
        m = Model()
        m.turn = -facing
        m.box(x0, x1, z0, z1, 0.0, FOOTING, "stone")
        m.box(x0 + 0.08, x1 - 0.08, -0.11, 0.11, FOOTING, 1.14, "stone_light")
        m.box(x0 + 0.05, x1 - 0.05, -0.13, 0.13, 1.14, 1.2, "stone")
        m.box(cx - w / 2 - 0.02, cx + w / 2 + 0.02, -0.115, -0.11, cy - h / 2 - 0.02, cy + h / 2 + 0.02, "wood_dark")
        m.box(cx - w / 2, cx + w / 2, cz, cz + 0.005, cy - h / 2, cy + h / 2, "bronze")
        return m.build("plaque")
    return build


def kiosk(facing):
    """A standing screen for browsing: a plinth on the kind's drawn
    rectangle, a teal housing to 1.8 m under a canopy (inside the band's
    rectangle too), and the screen, 60 x 80 cm, framed on its face."""
    x0, x1, z0, z1 = drawn_rect("kiosk", facing)
    (cx, cz, cy), (w, h) = DISPLAY["kiosk"]

    def build():
        m = Model()
        m.turn = -facing
        m.box(x0, x1, z0, z1, 0.0, FOOTING, "concrete")
        m.box(x0 + 0.04, x1 - 0.04, z0 + 0.03, z1 - 0.03, FOOTING, 1.8, "kiosk")
        m.box(x0, x1, z0, z1, 1.8, 1.88, "metal")
        m.box(cx - w / 2 - 0.04, cx + w / 2 + 0.04, -0.24, -0.22, cy - h / 2 - 0.04, cy + h / 2 + 0.04, "metal")
        m.box(cx - w / 2, cx + w / 2, cz, -0.24, cy - h / 2, cy + h / 2, "screen")
        return m.build("kiosk")
    return build


# ---- Perches: sat on outside their front edge (-z), facing out ----

def steps(facing):
    """Broad stone steps: the top tread 45 cm high and 50 cm deep along
    the front, the lower one 30 cm behind it, each with a pale nosing."""
    x0, x1, z0, z1 = drawn_rect("steps", facing)

    def build():
        m = Model()
        m.turn = -facing
        mid = (z0 + z1) / 2
        m.box(x0, x1, z0, mid, 0.0, 0.45, "stone")
        m.box(x0, x1, mid, z1, 0.0, 0.30, "stone")
        m.box(x0, x1, z0, z0 + 0.06, 0.41, 0.45, "stone_light")
        m.box(x0, x1, mid, mid + 0.06, 0.26, 0.30, "stone_light")
        return m.build("steps")
    return build


def low_wall(facing):
    """Three metres of low brick wall, 40 cm under a 5 cm stone coping."""
    x0, x1, z0, z1 = drawn_rect("low-wall", facing)

    def build():
        m = Model()
        m.turn = -facing
        m.box(x0, x1, z0 + 0.01, z1 - 0.01, 0.0, 0.40, "brick")
        m.box(x0, x1, z0, z1, 0.40, 0.45, "stone_light")
        return m.build("low_wall")
    return build


FOUNTAIN_R = 1.5
# The fountain is rendered whole and cut into two sprites sorted apart:
# the back of its rim (post.cut's `rim`: from FOUNTAIN_CUT_R out, behind
# the line x + z = 0 across the view), sorted at FOUNTAIN_BACK, behind
# every sitter on its far side, who sit in front of it; and the rest (the
# front of the rim, the water and the pedestal), sorted at its middle,
# behind its near-side sitters and before its far-side ones.
FOUNTAIN_CUT_R = 1.2
FOUNTAIN_BACK = (-FOUNTAIN_R, -FOUNTAIN_R)


def fountain():
    """A round fountain on the kind's 1.5 m disc: a stone basin to 40 cm
    under a pale rim to 45 cm, brimming with water, and in the middle a
    pedestal carrying two bowls to 1.8 m."""
    def build():
        m = Model()
        m.cyl(0, 0, 0.0, 0.40, FOUNTAIN_R, "stone", sides=48)
        m.cyl(0, 0, 0.40, 0.45, FOUNTAIN_R, "stone_light", sides=48)
        m.cyl(0, 0, 0.45, 0.455, 1.28, "water", sides=48)
        m.cyl(0, 0, 0.455, 1.0, 0.14, "stone_light", sides=12)
        m.cyl(0, 0, 1.0, 1.12, 0.12, "stone", sides=16, r_top=0.56)
        m.cyl(0, 0, 1.12, 1.13, 0.5, "water", sides=24)
        m.cyl(0, 0, 1.13, 1.5, 0.07, "stone_light", sides=10)
        m.cyl(0, 0, 1.5, 1.57, 0.06, "stone", sides=12, r_top=0.27)
        m.cyl(0, 0, 1.57, 1.58, 0.23, "water", sides=16)
        m.cyl(0, 0, 1.58, 1.76, 0.04, "stone_light", sides=8)
        m.sphere(0, 0, 1.8, 0.06, "stone_light", sub=1)
        return m.build("fountain")
    return build


def perch_seat(facing):
    """The seat a sitter takes on a perch, the sitter on its origin facing
    -z before it turns: a stone block from SEAT_BACK behind the sitter's
    place (inside the perch) to 5 cm short of the seat's front, under a
    timber seat 28 cm wide to SEAT_TOP reaching SEAT_FRONT in front. It
    stands in the square round the sit anchor that the collision audit
    leaves to a seat's own furniture, and inside the perch behind it."""
    def build():
        m = Model()
        m.turn = -facing
        m.box(-0.12, 0.12, -SEAT_FRONT + 0.05, SEAT_BACK, 0.0, SEAT_TOP - 0.06, "stone")
        m.box(-SEAT_HALF_WIDTH, SEAT_HALF_WIDTH, -SEAT_FRONT, SEAT_BACK, SEAT_TOP - 0.06, SEAT_TOP, "wood")
        return m.build("perch_seat")
    return build


SEAT_BAND = [["rect", -SEAT_HALF_WIDTH, SEAT_HALF_WIDTH, -SEAT_FRONT, SEAT_BACK]]


# ---- The meadow: clumps of tall grass (and some flowers) that rustle ----

# A clump's three frames: at rest, its tips pushed across the view (along
# +x and -z, which is straight right on the screen) and swinging back
# half as far the other way.
RUSTLE = (0.0, 0.1, -0.05)
# Where the push points (a unit vector, x and z).
PUSH = (math.sqrt(0.5), -math.sqrt(0.5))
# The meadow's clumps: grass of two cuts and a flowering one.
CLUMPS = {"grass_a": (7, 0), "grass_b": (8, 0), "flowers": (9, 2)}
FLOWER_COLOURS = ("paint_white", "paint_yellow", "canvas_red")


def clump_blades(seed, flowers, push):
    """A clump's blades as polygons (lists of (x, z, y) points, metres)
    with their material, the tips pushed `push` metres along PUSH: a dozen
    blades 0.45 to 0.85 m tall fanning out round the clump's middle, and
    `flowers` stems with a head each."""
    rng = random.Random(seed)
    polys = []
    n = 12
    for k in range(n + flowers):
        flower = k >= n
        a = 2 * math.pi * (k + rng.uniform(-0.35, 0.35)) / (n if not flower else max(1, flowers))
        r = rng.uniform(0.0, 0.05)
        bx, bz = r * math.cos(a), r * math.sin(a)
        reach = rng.uniform(0.06, 0.15) if not flower else rng.uniform(0.03, 0.08)
        lx, lz = reach * math.cos(a) + push * PUSH[0], reach * math.sin(a) + push * PUSH[1]
        h = rng.uniform(0.45, 0.85) if not flower else rng.uniform(0.65, 0.85)
        width = rng.uniform(0.09, 0.13) if not flower else 0.02
        across = a + math.pi / 2
        wx, wz = math.cos(across) * width / 2, math.sin(across) * width / 2

        def at(t, side):
            bend = t * t
            taper = 1.0 - t
            return (bx + lx * bend + side * wx * taper, bz + lz * bend + side * wz * taper, h * t)
        mat = "stem" if flower else ("blade", "blade_dark", "blade_light")[k % 3]
        # Two segments and a point, bending more toward the tip.
        polys.append(([at(0, -1), at(0, 1), at(0.5, 1), at(0.5, -1)], mat))
        polys.append(([at(0.5, -1), at(0.5, 1), at(1.0, 0)], mat))
        if flower:
            tx, tz, ty = at(1.0, 0)
            s = 0.04
            colour = FLOWER_COLOURS[k % len(FLOWER_COLOURS)]
            polys.append(([(tx - s, tz - s, ty), (tx + s, tz - s, ty), (tx + s, tz + s, ty), (tx - s, tz + s, ty)],
                          colour))
            polys.append(([(tx - s, tz, ty - s), (tx + s, tz, ty - s), (tx + s, tz, ty + s), (tx - s, tz, ty + s)],
                          colour))
    return polys


def band_reach(polys):
    """How far from the clump's middle its blades reach in the walking
    band: each polygon clipped to the band, the farthest point of what is
    left."""
    far = 0.0
    for pts, _ in polys:
        for lo, keep_above in ((BAND[0], True), (BAND[1], False)):
            clipped = []
            for p, q in zip(pts, pts[1:] + pts[:1]):
                pin = p[2] >= lo if keep_above else p[2] <= lo
                qin = q[2] >= lo if keep_above else q[2] <= lo
                if pin:
                    clipped.append(p)
                if pin != qin:
                    t = (lo - p[2]) / (q[2] - p[2])
                    clipped.append(tuple(a + (b - a) * t for a, b in zip(p, q)))
            pts = clipped
            if not pts:
                break
        for x, z, _ in pts:
            far = max(far, math.hypot(x, z))
    return far


def clump(seed, flowers, push):
    """A clump's model (clump_blades) and how far it reaches in the band."""
    polys = clump_blades(seed, flowers, push)

    def build():
        m = Model()
        for pts, mat in polys:
            m.quad(pts, mat)
        return m.build("clump")
    return build, round(band_reach(polys), 4)


def add_things():
    for f in (0, 90, 180, 270):
        for name, build in (("noticeboard", noticeboard), ("plaque", plaque), ("kiosk", kiosk)):
            (x, z, y), (w, h) = DISPLAY[name]
            models.add(f"{name}_{f}", build(f), [out(f"scenery/{name}_{f}.png")],
                       info={"facing": f, "band_shapes": [rect(drawn_rect(name, f))],
                             "display": {"at": [x, z, y], "size": [w, h]}})
        models.add(f"steps_{f}", steps(f), [out(f"scenery/steps_{f}.png")],
                   info={"facing": f, "band_shapes": [rect(drawn_rect("steps", f))]})
        models.add(f"low_wall_{f}", low_wall(f), [out(f"scenery/low_wall_{f}.png")],
                   info={"facing": f, "band_shapes": [rect(drawn_rect("low-wall", f))]})
    # Each half is read, where people walk, as the whole basin's disc (kit.json
    # gives it about each sprite's own origin), so the audit sees the basin
    # twice over, never less.
    bx, bz = FOUNTAIN_BACK
    models.add("fountain", fountain(),
               [dict(out("scenery/fountain_back.png", origin=(bx, bz, 0)), rim={"r": FOUNTAIN_CUT_R, "back": True}),
                dict(out("scenery/fountain_front.png"), rim={"r": FOUNTAIN_CUT_R, "back": False})],
               info={"facing": 0, "band_shapes": [["disc", FOUNTAIN_R, 0.0, 0.0]]})
    for f in SEAT_FACINGS:
        models.add(f"perch_seat_{f}", perch_seat(f), [out(f"scenery/perch_seat_{f}.png")],
                   info={"facing": f, "band_shapes": SEAT_BAND})
    for name, (seed, flowers) in CLUMPS.items():
        for frame, push in enumerate(RUSTLE):
            build, reach = clump(seed, flowers, push)
            # Outlined in the grass's own dark green, not navy, so a field
            # of overlapping clumps reads as grass, not a net.
            models.add(f"meadow_{name}_{frame}", build, [out(f"scenery/meadow/{name}_{frame}.png")],
                       outline="leaf_dark",
                       info={"facing": 0, "band_shapes": [["disc", reach, 0.0, 0.0]], "rustle": frame})
