"""The tram parts every mesh kit builds alike from the shared layout
(tram_layout.py), each its own node for the client to move, fade or light
(city tram spec §5):

    interior        the floor, a seat under every seated slot facing the
                    way the tram runs (+x), and grab poles in the standing
                    room by each door
    lights          ceiling strips down the aisle in window_glow, which
                    the pack lights at night at the style's window energy
    door_<side>_<k>_<fore|aft>
                    the two leaves of door k (from the front) on the left
                    (+Y) or right (-Y) side: glazed over a solid kick
                    panel, standing just proud of the body so they can
                    slide open along it

Runs inside Blender with the kit's lib registered as `lib`. Colours are the
kit's palette names by role; see COLOURS.
"""
import math

from lib import Mesh

import tram_layout as L

FLOOR = L.FLOOR_CM / 100.0
SEAT = FLOOR + L.SEAT_CM / 100.0
CEILING = 2.5
# The palette names each part takes, by role; a kit passes its own.
COLOURS = {"floor": "stone_dark", "seat": "tram_coral", "seat_frame": "steel_dark", "pole": "steel",
           "door": "tram_dark", "door_glass": "glass", "light": "window_glow"}
# Across the seat pairs: each seat reaches from beside the aisle to the
# wall, its rider sitting on the slot 50 cm off the middle.
SEAT_Y = (0.26, 0.92)


def _colours(given):
    out = dict(COLOURS)
    out.update(given or {})
    return out


def interior(root, spans, inside, colours=None, seats=True):
    """The floor over each (x0, x1) of `spans` (the sections' insides and
    the gangways between), reaching `inside(x)` either side of the middle
    at x (a number for a straight-sided body); the seats; and the poles."""
    c = _colours(colours)
    reach = inside if callable(inside) else (lambda x: inside)
    m = Mesh()
    for x0, x1 in spans:
        n = max(1, int(math.ceil((x1 - x0) / 0.25)))
        xs = [x0 + (x1 - x0) * k / n for k in range(n + 1)]
        outline = [(x, -reach(x)) for x in xs] + [(x, reach(x)) for x in reversed(xs)]
        m.prism(_simplified(outline), 0.04, (0, 0, FLOOR - 0.02), c["floor"], axis="z")
    if seats:
        for x, y in L.seats_m():
            seat(m, x, y, c, min(reach(x - 0.29), reach(x + 0.22)) - 0.02)
    for x0, x1 in L.doors_m():
        mid = (x0 + x1) / 2
        for dx in (-0.51, 0.51):
            m.cylinder(0.025, CEILING - FLOOR - 0.03, (mid + dx, 0, (FLOOR + CEILING - 0.03) / 2), c["pole"], 8)
    return m.build("interior", root)


def _simplified(pts):
    """`pts` without the points that lie on a straight line between their
    neighbours."""
    out = []
    n = len(pts)
    for k in range(n):
        (ax, ay), (bx, by), (cx, cy) = pts[k - 1], pts[k], pts[(k + 1) % n]
        if abs((bx - ax) * (cy - ay) - (by - ay) * (cx - ax)) > 1e-9:
            out.append(pts[k])
    return out


def seat(m, x, y, c, reach=SEAT_Y[1]):
    """A seat whose rider sits over (x, y), facing +x: a cushion SEAT high
    reaching toward the wall (no further than `reach` from the middle), a
    backrest behind and a pedestal."""
    s = 1 if y > 0 else -1
    y0, y1 = SEAT_Y[0], min(SEAT_Y[1], reach)
    w, mid = y1 - y0, s * (y0 + y1) / 2
    m.box((0.44, w, 0.08), (x, mid, SEAT - 0.04), c["seat"], bevel=0.02)
    m.box((0.07, w, 0.56), (x - 0.25, mid, SEAT + 0.26), c["seat"], bevel=0.02)
    m.box((0.1, 0.1, SEAT - FLOOR - 0.08), (x - 0.05, s * 0.5, (FLOOR + SEAT - 0.08) / 2), c["seat_frame"])


def lights(root, spans, colours=None, z=CEILING):
    """A light strip down the aisle under the ceiling over each span."""
    c = _colours(colours)
    m = Mesh()
    for x0, x1 in spans:
        m.box((x1 - x0, 0.16, 0.03), ((x0 + x1) / 2, 0, z - 0.015), c["light"])
    return m.build("lights", root)


def doors(root, y_out, colours=None, z0=FLOOR, z1=CEILING, thickness=0.03):
    """Every door's two leaves on both sides, their outer faces at y_out
    either side of the middle."""
    c = _colours(colours)
    out = []
    for k, (x0, x1) in enumerate(L.doors_m()):
        mid = (x0 + x1) / 2
        for side, s in (("left", 1), ("right", -1)):
            y = s * (y_out - thickness / 2)
            for leaf, (a, b) in (("fore", (mid, x1)), ("aft", (x0, mid))):
                m = Mesh()
                leaf_panel(m, a, b, y, z0, z1, thickness, c)
                out.append(m.build(f"door_{side}_{k}_{leaf}", root))
    return out


def leaf_panel(m, a, b, y, z0, z1, t, c):
    """One door leaf from x a to b at y: a solid kick panel, a glazed upper
    part between narrow stiles, and a top rail."""
    w = b - a
    sill = z0 + 0.5
    m.box((w, t, sill - z0), ((a + b) / 2, y, (z0 + sill) / 2), c["door"])
    m.box((w, t, 0.1), ((a + b) / 2, y, z1 - 0.05), c["door"])
    for x in (a + 0.03, b - 0.03):
        m.box((0.06, t, z1 - 0.1 - sill), (x, y, (sill + z1 - 0.1) / 2), c["door"])
    m.box((w - 0.12, t * 0.6, z1 - 0.1 - sill), ((a + b) / 2, y, (sill + z1 - 0.1) / 2), c["door_glass"])


def build_all(root, spans, inside, y_out, colours=None):
    """The interior, the lights and the doors."""
    interior(root, spans, inside, colours)
    lights(root, spans, colours)
    doors(root, y_out, colours)
    return root

