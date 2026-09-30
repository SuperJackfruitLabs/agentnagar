"""Things to use (interactions spec sections 2 to 5), in voxels: the
displays (noticeboard, plaque, kiosk), the perches (steps, low wall,
fountain) and the seat a sitter takes on one, the meadow's grass and
flower clumps, and the workstation.

They are the objects the other kits draw (tools/styles/shared/usables.py:
a board on two posts, a plaque on a plinth, a standing screen, broad steps,
a low wall, a round basin) in 10 cm blocks. Each stands on y = 0 on its
kind's footprint's centre, its front toward -z. The pack stretches a
`fill` piece to the cells its footprint blocks, so a piece's depth may be
a voxel off the footprint's.

- A display carries an empty node `display` at the middle of its face,
  facing -z, where the pack mounts the surface's text; its scale is the
  face's size (width along x, height along y).
- `perch_seat` is the seat a sitter takes on a perch: its origin is the
  sitter's place (the sit anchor, just outside the perch), and it reaches
  back into the perch, its top 0.51 m up, the kit's seat height.
- A meadow clump's blades are stacked boxes whose bend weight (UV2.x) rises
  from 0 at the root to 1 at the tip (voxel.blocks).
- The workstation is a seat: its origin is the sitter's place, facing -z,
  the desk ahead on the kind's footprint and the chair in the square round
  the sitter. Its monitor's face looks back at the sitter (+z), so its
  `display` node is turned half round (two of its scale's axes negated);
  its screen is its own part, `screen`, which the pack lights.
"""
import math

from shapes import new
from voxel import Asset, blocks, drum, merged, mesh, unit

# A perch's seat: the kit's seat height, a centimetre over the perches' own
# tops (0.5 m), so the planks lying back over them never share their plane.
SEAT_TOP = 0.51
# How far a perch's seat reaches in front of the sitter's place (usables).
SEAT_FRONT = 0.15


def _display(a, at, size):
    """The `display` node: an empty at the middle of the face, scaled to
    its size (width, height)."""
    a.shape("display", {}, translation=at, scale=(size[0], size[1], 1.0))


def noticeboard():
    """A board on two posts: charcoal posts, a navy board framed in wood
    from 0.9 to 1.7 m, and a stepped orange roof above the walking band."""
    a = Asset("noticeboard")
    g = new()
    for i in (-6, 5):
        g.box(i, 0, -1, i + 1, 23, 1, "charcoal")
    g.box(-5, 8, -1, 5, 18, 0, "wood")
    g.box(-5, 9, -1, 5, 17, 0, "navy")
    g.box(-5, 8, 0, 5, 18, 1, "wood_dark")
    g.box(-5, 8, -2, 5, 9, -1, "wood")
    for step, (i0, i1, k0, k1) in enumerate(((-7, 7, -3, 3), (-7, 7, -2, 2), (-7, 7, -1, 1))):
        g.box(i0, 23 + step, k0, i1, 24 + step, k1, "orange" if step < 2 else "orange_dark")
    g.vary(["orange", "wood"], seed="noticeboard")
    a.part("board", g)
    _display(a, (0.0, 1.3, -0.101), (1.0, 0.8))
    return a


def plaque():
    """A plaque on a low plinth: a grey stone upright to 1.2 m on a darker
    plinth, the navy plaque (`face`) framed in gold on its face, 0.8 to
    1.15 m."""
    a = Asset("plaque")
    g = new()
    g.box(-3, 0, -2, 3, 2, 2, "stone_dark")
    g.box(-3, 2, -1, 3, 12, 1, "stone")
    g.box(-3, 12, -2, 3, 13, 2, "stone_dark")
    g.box(-3, 7, -2, 3, 12, -1, "yellow_dark")
    g.vary(["stone"], seed="plaque")
    a.part("plinth", g)
    a.shape("face", blocks([(-0.25, 0.8, -0.205, 0.25, 1.15, -0.2, "navy", 0.0, 0.0)]))
    _display(a, (0.0, 0.975, -0.206), (0.5, 0.35))
    return a


def kiosk():
    """A standing screen: a charcoal plinth, a white housing to 1.8 m under
    an orange canopy, and the screen (`screen`, navy) 0.9 to 1.7 m on its
    face."""
    a = Asset("kiosk")
    g = new()
    g.box(-4, 0, -3, 4, 1, 3, "charcoal")
    g.box(-4, 1, -2, 4, 18, 3, "white")
    g.box(-4, 8, -3, 4, 18, -2, "charcoal")
    g.box(-4, 18, -3, 4, 19, 3, "orange")
    a.part("housing", g)
    a.shape("screen", blocks([(-0.3, 0.9, -0.305, 0.3, 1.7, -0.3, "navy", 0.0, 0.0)]))
    _display(a, (0.0, 1.3, -0.306), (0.6, 0.8))
    return a


def steps():
    """Broad steps sat on at the top step's front edge, looking out (-z):
    the top step 0.5 m high and 0.5 m deep, the lower one 0.3 m behind it,
    in grey blocks with a pale nosing."""
    a = Asset("steps")
    g = new()
    g.box(-15, 0, 0, 15, 5, 5, "stone")
    g.box(-15, 0, 5, 15, 3, 10, "stone_dark")
    g.box(-15, 4, 0, 15, 5, 1, "paving_light")
    g.box(-15, 2, 5, 15, 3, 6, "paving_light")
    g.vary(["stone", "stone_dark"], seed="steps")
    a.part("treads", g)
    return a


def low_wall():
    """Three metres of low wall, 0.4 m of grey blocks under a pale coping
    to 0.5 m, sat on along its front (-z)."""
    a = Asset("low_wall")
    g = new()
    g.box(-15, 0, -2, 15, 4, 2, "stone")
    g.box(-15, 4, -2, 15, 5, 2, "paving_light")
    g.vary(["stone"], seed="low_wall")
    a.part("wall", g)
    return a


def fountain():
    """A round fountain, the 1.5 m disc: a stone basin drawn as a 48-sided
    drum (a disc a 10 cm voxel cannot follow) brimming with water to its
    rim, and in the middle a blocky pedestal carrying two bowls."""
    a = Asset("fountain")
    g = new()
    g.box(-2, 5, -2, 2, 14, 2, "stone")
    for (r, j, key) in ((5, 10, "stone_dark"), (2, 15, "stone_dark")):
        for i in range(-r, r):
            for k in range(-r, r):
                if (i + 0.5) ** 2 + (k + 0.5) ** 2 <= r * r:
                    g.put(i, j, k, key)
                    if (i + 0.5) ** 2 + (k + 0.5) ** 2 <= (r - 1) ** 2:
                        g.put(i, j + 1, k, "water")
                    else:
                        g.put(i, j + 1, k, key)
    g.box(-1, 17, -1, 1, 19, 1, "stone")
    g.put(0, 19, 0, "water_light")
    a.shape("basin", merged(drum(48, 1.5, 0.0, 0.5, "stone", "stone", "fountain"),
                            drum(48, 1.3, 0.5, 0.51, "water", "water", "fountain_water"), mesh(g)))
    return a


def perch_seat():
    """The seat a sitter takes on a perch: a grey block from 0.4 m behind
    the sitter's place (inside the perch) to 0.1 m in front of it, under
    three planks 0.3 m wide reaching SEAT_FRONT in front, under the
    thighs, their top at SEAT_TOP."""
    a = Asset("perch_seat")
    boxes = [(-0.12, 0.0, -0.1, 0.12, SEAT_TOP - 0.06, 0.4, "stone", 0.0, 0.0)]
    for n, key in enumerate(("wood", "wood_light", "wood")):
        x = -0.15 + 0.1 * n
        boxes.append((x, SEAT_TOP - 0.06, -SEAT_FRONT, x + 0.1, SEAT_TOP, 0.4, key, 0.0, 0.0))
    a.shape("seat", blocks(boxes))
    return a


# ---- The meadow ----

GRASS = ("lawn", "lawn_dark", "leaf_light")
FLOWERS = ("flower_white", "flower_pink", "flower_yellow")


def _clump(name, blades, flowers):
    """A clump of tall grass blades, each two stacked 3.5 cm boxes, the
    upper stepping out and narrowing, and `flowers` stems carrying a
    blossom block; one mesh, planted by the dozen, so a stem's top, which
    its blossom covers, is left out."""
    boxes = []
    for b in range(blades):
        a = 2 * math.pi * (b + unit(name, b, "a") * 0.6) / blades
        r = 0.03 + 0.05 * unit(name, b, "r")
        height = 0.5 + 0.4 * unit(name, b, "h")
        out = 0.1 + 0.15 * unit(name, b, "o")
        key = GRASS[b % len(GRASS)]
        for s in range(2):
            t0, t1 = s / 2, (s + 1) / 2
            d = r + out * 0.45 * s
            x, z = d * math.cos(a), d * math.sin(a)
            w = 0.035 * (1.0 - 0.3 * s)
            boxes.append((x - w / 2, height * t0, z - w / 2, x + w / 2, height * t1, z + w / 2, key, t0, t1))
    for f in range(flowers):
        a = 2 * math.pi * (f + 0.5) / max(1, flowers)
        d = 0.06
        x, z = d * math.cos(a), d * math.sin(a)
        height = 0.6 + 0.2 * unit(name, f, "fh")
        boxes.append((x - 0.012, 0.0, z - 0.012, x + 0.012, height, z + 0.012, "leaf_dark", 0.0, 1.0, False))
        boxes.append((x - 0.035, height, z - 0.035, x + 0.035, height + 0.05, z + 0.035, FLOWERS[f % len(FLOWERS)],
                      1.0, 1.0))
    a = Asset(name)
    a.shape("grass", blocks(boxes))
    return a


def meadow_grass():
    """A clump of the meadow's tall grass."""
    return _clump("meadow_grass", 9, 0)


def meadow_flowers():
    """A clump of tall grass with three flowers."""
    return _clump("meadow_flowers", 6, 3)


# ---- The workstation ----

# The screen: its face's middle (x, y, z, metres) and size, as the other
# kits draw it (usables.DISPLAY), 64 mm in from the desk's far edge.
WORKSTATION_SCREEN = ((0.0, 1.02, -0.886), (0.54, 0.30))


def workstation():
    """A desk seating one at the origin, facing -z: an orange task chair in
    the square round the sitter, a timber desk on the kind's footprint (1.3
    m across, 25 to 95 cm ahead) on charcoal legs with a white pedestal, and
    at its far edge a chunky charcoal monitor, its navy screen (`screen`)
    54 x 30 cm looking back at the sitter, 0.87 to 1.17 m up; a keyboard, a
    mug and a potted plant on the desk."""
    a = Asset("workstation")
    d = new()
    d.box(-7, 7, -10, 6, 8, -3, "wood")
    d.box(-7, 7, -4, 6, 8, -3, "wood_dark")
    for i, k in ((-7, -10), (5, -10), (-7, -4), (5, -4)):
        d.box(i, 0, k, i + 1, 7, k + 1, "charcoal")
    d.box(-6, 4, -10, 5, 7, -9, "charcoal")
    d.box(2, 0, -9, 5, 7, -4, "white")
    d.vary(["wood", "white"], seed="workstation")
    # Half a voxel over, so the desk's thirteen voxels stand on the
    # footprint's 1.3 m and its seven on 25 to 95 cm.
    a.part("desk", d, translation=(0.05, 0.0, 0.05))
    c = new()
    c.box(-2, 0, -2, 2, 1, 2, "charcoal")
    c.box(-1, 1, -1, 1, 4, 1, "charcoal")
    c.box(-2, 4, -2, 2, 5, 2, "orange")
    c.box(-2, 5, 1, 2, 9, 2, "orange")
    c.box(-2, 9, 1, 2, 10, 2, "orange_dark")
    # Half a voxel back, so its back reaches the edge of the square round
    # the sitter, as the other kits' chairs do: the pack stretches the
    # piece to that square, and a chair short of it stretches the desk
    # toward the sitter.
    a.part("chair", c, translation=(0.0, 0.0, 0.05))
    (sx, sy, sz), (sw, sh) = WORKSTATION_SCREEN
    a.shape("monitor", blocks([
        (-0.12, 0.80, -0.93, 0.12, 0.83, -0.80, "charcoal", 0.0, 0.0),
        (-0.04, 0.83, -0.94, 0.04, 0.86, -0.90, "charcoal", 0.0, 0.0),
        (-0.33, 0.85, -0.95, 0.33, 1.20, -0.89, "charcoal", 0.0, 0.0),
        (-0.33, 1.20, -0.95, 0.33, 1.22, -0.89, "steel", 0.0, 0.0),
        (-0.22, 0.80, -0.52, 0.22, 0.83, -0.38, "white", 0.0, 0.0),
        (0.28, 0.80, -0.48, 0.34, 0.83, -0.40, "white", 0.0, 0.0),
        (-0.42, 0.80, -0.46, -0.34, 0.89, -0.38, "orange", 0.0, 0.0),
        (-0.52, 0.80, -0.86, -0.40, 0.90, -0.74, "orange_dark", 0.0, 0.0),
        (-0.55, 0.90, -0.89, -0.37, 1.02, -0.71, "leaf", 0.0, 0.0),
    ]))
    a.shape("screen", blocks([(sx - sw / 2, sy - sh / 2, -0.89, sx + sw / 2, sy + sh / 2, sz, "navy", 0.0, 0.0)]))
    a.shape("display", {}, translation=(sx, sy, sz), scale=(-sw, sh, -1.0))
    return a


ASSETS = {f.__name__: f for f in (
    noticeboard, plaque, kiosk, steps, low_wall, fountain, perch_seat, meadow_grass, meadow_flowers, workstation,
)}
