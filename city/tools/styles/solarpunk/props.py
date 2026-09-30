"""Props for the solarpunk kit, after the 09 sheets: white-and-brass street
lamps under little solar canopies and glowing bollards, park benches of
blonde timber slats on white ends, jade-and-cream café parasols, timber
bistro tables and chairs on white frames, and the interiors in blonde
timber: the workshop's workbench, pegboard and brass pendant lamps, desks
with monitors, the library's bookshelves and reading armchairs in cream
with jade pillows.

The anime kit (tools/styles/anime/props.py) fixes every piece's name,
pivot, extent, nodes and seat, because the pack places and seats people
the same way in every kit: Blender Z-up, pieces face +Y (Godot -Z); the
origin is the centre of the footprint on the floor. Seat assets
(`seat_<kind>_v2`) put the origin at the seated occupant's position on the
floor, facing +Y: a bench or café chair seat is 0.47 m high, a desk chair
0.5 m, a reading chair's cushion 0.42 m. The anime kit's interiors, café
tables and chairs build here in solarpunk materials (their colours
swapped for timber, white, brass and jade); the lamp, bollard, bench and
parasol are this kit's own.

Each asset is an empty named after it parenting one merged mesh, `body`,
plus the parts the pack drives by name: `light` (a lamp's glowing glass;
the pack adds an OmniLight there) and `screen` (a monitor's display, in
`glass_light`, so it glows at night). The bollard's glowing band is
lamp_glow in its body (it glows at night; no OmniLight).
"""
import math
import sys

from mathutils import Vector

from lib import Mesh, rotx
import vegetation as V

# The anime props import the anime vegetation helpers by module name.
_ours = sys.modules.get("vegetation")
sys.modules["vegetation"] = V.A
try:
    A = V._anime("props")
finally:
    sys.modules["vegetation"] = _ours
Frame, finish, add = A.Frame, V.finish, V.add
usables = A.usables
swapped, restyled = V.swapped, V.restyled

SMOOTH = 40  # degrees: rounds cylinders and domes, keeps boxes crisp


# ---- Street furniture ----

def lamp_post():
    """A white-and-brass solarpunk street lamp: a white plinth ringed in
    brass, a slim tapering white column with brass collars, a warm
    glowing lantern (`light`) between brass rings, and over it a little
    solar canopy, a blue panel in a white frame tilted to the sun."""
    m, glow = Mesh(), Mesh()
    m.cylinder(0.25, 0.1, (0, 0, 0.05), "warm_white", sides=16)
    m.cylinder(0.2, 0.3, (0, 0, 0.25), "warm_white", sides=16, radius_top=0.1)
    m.cylinder(0.205, 0.035, (0, 0, 0.12), "brass", sides=16)
    m.cylinder(0.07, 3.0, (0, 0, 1.9), "warm_white", sides=12, radius_top=0.05)
    for z in (0.44, 2.9):
        m.cylinder(0.075, 0.06, (0, 0, z), "brass", sides=12)
    # The lantern: a brass cup, the glowing glass, a brass crown.
    m.cylinder(0.06, 0.1, (0, 0, 3.43), "brass", sides=12, radius_top=0.13)
    glow.cylinder(0.12, 0.4, (0, 0, 3.68), "lamp_glow", sides=12, radius_top=0.14)
    for z in (3.5, 3.87):
        m.cylinder(0.145 if z > 3.6 else 0.13, 0.03, (0, 0, z), "brass", sides=12)
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        m.beam((0.125 * math.cos(a), 0.125 * math.sin(a), 3.5), (0.15 * math.cos(a), 0.15 * math.sin(a), 3.88),
               0.02, "brass")
    m.cylinder(0.15, 0.12, (0, 0, 3.94), "brass", sides=12, radius_top=0.05)
    m.cylinder(0.03, 0.12, (0, 0, 4.05), "brass", sides=8)
    # The solar canopy.
    tilt = rotx(-12)
    m.box((0.74, 0.48, 0.05), Vector((0, 0, 4.14)), "warm_white", bevel=0.02, rot=tilt)
    m.box((0.66, 0.4, 0.02), Vector((0, 0, 4.14)) + tilt @ Vector((0, 0, 0.022)), "solar", rot=tilt)
    finish("lamp_post", {"body": m, "light": glow}, smooth={"body": SMOOTH})


def bollard():
    """A white ceramic bollard with a brass foot and a warm glowing band
    under its brass-domed head, as the sheets' night square shows."""
    m = Mesh()
    m.cylinder(0.12, 0.04, (0, 0, 0.02), "brass", sides=16)
    m.cylinder(0.1, 0.6, (0, 0, 0.34), "warm_white", sides=16, radius_top=0.095)
    m.cylinder(0.1, 0.03, (0, 0, 0.655), "brass", sides=16)
    m.cylinder(0.088, 0.14, (0, 0, 0.74), "lamp_glow", sides=16)
    m.cylinder(0.1, 0.03, (0, 0, 0.825), "brass", sides=16)
    m.dome(0.098, (0, 0, 0.84), "warm_white", segments=16, rings=3, squash=0.6)
    finish("bollard", {"body": m}, smooth={"body": SMOOTH})


def bench(f):
    """A park bench seating one at the local origin, facing +Y: blonde
    timber slats (the seat's top 0.47 m up) and a raked slatted back
    between white end frames, each open under a timber armrest."""
    for y in (-0.165, -0.055, 0.055, 0.165):
        f.box((1.6, 0.095, 0.045), (0, y, 0.4475), "timber_light", bevel=0.01)
    back = rotx(15)
    for z in (0.58, 0.69, 0.8):
        f.box((1.6, 0.035, 0.09), (0, -0.25 - (z - 0.5) * math.tan(math.radians(15)), z), "timber_light",
              bevel=0.01, rot=back)
    # The ends: a white frame, its outline and an opening under the arm.
    # They reach no further back or forward than the slats, so seen from
    # above the bench is one rectangle, as the city stretches it to its
    # footprint.
    outer = [(0.21, 0.0), (0.21, 0.4), (0.19, 0.425), (-0.2, 0.425), (-0.24, 0.47), (-0.32, 0.86),
             (-0.355, 0.87), (-0.3, 0.45), (-0.25, 0.0)]
    hole = [(0.14, 0.06), (-0.17, 0.06), (-0.17, 0.36), (0.14, 0.36)]
    for x in (-0.7, 0.7):
        f.m.slab(outer, [hole], 0.06, f.p((x, 0, 0)), "warm_white", axis="x", rot=f.r)
        # A post up to the armrest, and the armrest.
        f.box((0.06, 0.06, 0.2), (x, 0.18, 0.53), "warm_white", bevel=0.012)
        f.box((0.08, 0.46, 0.045), (x, -0.02, 0.645), "timber", bevel=0.014)


def bench_park():
    m = Mesh()
    bench(Frame(m, at=(0, 0.04, 0)))
    finish("bench_park", {"body": m}, smooth={"body": SMOOTH})


def seat_bench():
    m = Mesh()
    bench(Frame(m))
    finish("seat_bench_v2", {"body": m}, smooth={"body": SMOOTH})


# ---- Café ----

def umbrella_cafe():
    """A jade-and-cream café parasol: eight panels, jade and cream in turn,
    with a gentle crown and a scalloped valance, white ribs and
    stretchers beneath, a jade vent cap and brass finial, on a brass pole
    in a white ceramic base."""
    m = Mesh()
    m.box((0.5, 0.5, 0.08), (0, 0, 0.04), "warm_white", bevel=0.02)
    m.cylinder(0.08, 0.16, (0, 0, 0.16), "brass", sides=12, radius_top=0.045)
    m.cylinder(0.028, 2.28, (0, 0, 1.24), "brass", sides=10)
    n = 8
    apex = Vector((0, 0, 2.4))

    def ring(r, z, k):
        a = 2 * math.pi * k / n
        return Vector((r * math.cos(a), r * math.sin(a), z))

    # Ribs are ridges and each panel sags a little between them.
    for k in range(n):
        verts = [apex, ring(0.6, 2.22, k), ring(1.15, 1.95, k), ring(0.56, 2.2, k + 0.5), ring(1.06, 1.93, k + 0.5),
                 ring(0.6, 2.22, k + 1), ring(1.15, 1.95, k + 1)]
        add(m, verts, [(0, 1, 3), (0, 3, 5), (1, 2, 4, 3), (3, 4, 6, 5)], "jade" if k % 2 else "canvas")
    for k in range(n):
        a, b = ring(1.15, 1.95, k), ring(1.15, 1.95, k + 1)
        mid = (a + b) / 2
        add(m, [a, b, b - Vector((0, 0, 0.1)), mid - Vector((0, 0, 0.17)), a - Vector((0, 0, 0.1))], [(0, 1, 2, 3, 4)],
            "canvas" if k % 2 else "jade")
    for k in range(n):
        m.beam((0, 0, 2.36), ring(1.12, 1.92, k), 0.022, "warm_white")
        m.beam((0, 0, 1.78), ring(0.6, 2.18, k), 0.018, "warm_white")
    m.cylinder(0.05, 0.06, (0, 0, 1.78), "brass", sides=10)
    m.cylinder(0.16, 0.07, (0, 0, 2.43), "jade", sides=8, radius_top=0.03)
    m.sphere(0.035, (0, 0, 2.48), "brass", subdivisions=1)
    finish("umbrella_cafe", {"body": m}, smooth={"body": SMOOTH})


# The café's colours: timber tops and seats on white frames.
CAFE = {"warm_white": "timber_light", "wood": "timber", "wood_light": "timber_light", "iron": "warm_white"}
# The interiors' colours: blonde timber, dark timber for the steel.
TIMBER = {"wood_light": "timber_light", "wood": "timber", "frame": "timber_dark", "terracotta": "ceramic"}


# ---- Things to use: displays and perches ----

# The kit's colour for each role in the shared things to use (the anime
# kit builds them): blonde timber, white ceramic and brass, solar panels
# for roofs, jade faces the light text reads on, and timber seats.
USE_LOOK = {
    "post": "timber", "post_foot": "brass_dark", "frame": "timber_dark", "board": "jade_dark",
    "roof": "solar", "roof_ridge": "solar_frame",
    "stone": "ceramic", "stone_dark": "stone_dark", "plaque": "jade_dark", "plaque_frame": "brass",
    "base": "stone", "housing": "ceramic", "canopy": "solar_frame", "bezel": "timber_dark", "screen": "jade_dark",
    "step": "stone", "nosing": "timber", "wall": "stone_dark", "coping": "timber",
    "basin": "ceramic", "rim": "stone", "water": "water",
    "seat_block": "stone", "seat": "timber_light",
}


def _solar_canopy(parts):
    """The kiosk's canopy carries a little solar panel, as the lamps do."""
    parts["body"].box((0.7, 0.4, 0.02), (0, 0, 1.89), "solar")


def _brass_edged_seat(parts):
    """A brass edge along the seat's front."""
    parts["body"].box((0.30, 0.02, 0.02), (0, usables.SEAT_FRONT - 0.005, usables.SEAT_TOP - 0.05), "brass")


# The workstation in the kit's look: a jade chair at a blonde timber desk,
# the monitor framed in timber (the kit's wooden frame), ceramic drawers.
WORK_LOOK = {
    **USE_LOOK, "chair": "jade", "chair_frame": "timber_dark", "desk": "timber_light", "desk_leg": "timber",
    "drawer": "ceramic", "keys": "warm_white", "casing": "timber_dark", "screen": "jade_dark", "trim": "timber",
    "frame_style": "wood",
}


def _desk_garden(parts):
    """A ceramic pot of greenery and a brass lamp foot on the desk's left,
    as the sheets grow something on every surface."""
    m = parts["body"]
    top = usables.DESK_TOP
    m.cylinder(0.07, 0.12, (-0.46, 0.72, top + 0.06), "ceramic", sides=10, radius_top=0.08)
    A.puff(m, (-0.46, 0.72, top + 0.19), 0.1, "leaf", cap="leaf_light", seed=87, seg=8, rings=5)
    m.cylinder(0.04, 0.1, (-0.36, 0.42, top + 0.05), "brass", sides=10)


ASSETS = {
    "workstation": A.used("workstation", usables.workstation, display=True, look=WORK_LOOK, ornament=_desk_garden),
    "noticeboard": A.used("noticeboard", usables.noticeboard, display=True, look=USE_LOOK),
    "plaque": A.used("plaque", usables.plaque, display=True, look=USE_LOOK),
    "kiosk": A.used("kiosk", usables.kiosk, display=True, look=USE_LOOK, ornament=_solar_canopy),
    "steps": A.used("steps", usables.steps, look=USE_LOOK),
    "low_wall": A.used("low_wall", usables.low_wall, look=USE_LOOK),
    "fountain": A.used("fountain", usables.fountain, look=USE_LOOK),
    "perch_seat": A.used("perch_seat", usables.perch_seat, look=USE_LOOK, ornament=_brass_edged_seat),
    "lamp_post": lamp_post,
    "bollard": bollard,
    "bench_park": bench_park,
    "seat_bench_v2": seat_bench,
    "umbrella_cafe": umbrella_cafe,
    "cafe_table": restyled(A.cafe_table_prop, CAFE),
    "cafe_table_set": restyled(A.cafe_table_set, CAFE),
    "seat_cafe-table_v2": restyled(A.seat_cafe_table, CAFE),
    "workbench": restyled(A.workbench, {**TIMBER, "vermilion": "jade", "indigo": "jade_dark", "blue": "jade"}),
    "pegboard": restyled(A.pegboard, {**TIMBER, "frame": "steel_dark", "vermilion": "coral"}),
    "pendant_lamp": restyled(A.pendant_lamp, {"frame": "brass"}),
    "desk_v2": restyled(A.desk_v2, {**TIMBER, "indigo": "jade", "vermilion": "coral"}),
    "seat_desk_v2": restyled(A.seat_desk, {**TIMBER, "indigo": "jade", "vermilion": "coral"}),
    "bookshelf_v2": restyled(A.bookshelf_v2, TIMBER),
    "reading_chair_v2": restyled(A.reading_chair_v2, {**TIMBER, "indigo": "cream", "yellow": "jade"}),
    "seat_reading-chair_v2": restyled(A.seat_reading_chair, {**TIMBER, "indigo": "cream", "yellow": "jade"}),
}
