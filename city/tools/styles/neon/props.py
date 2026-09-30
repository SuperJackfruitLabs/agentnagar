"""Props for the neon noir kit, after the 10 sheets: black street lamps
crowned with a warm glowing globe; square dark bollards with a lit band;
the waterfront's benches of dark timber on black iron, a warm strip under
the seat; dark café parasols strung with bulbs, tables with a candle; and
the interiors: the workshop's bench and pegboard under a light bar, black
dome pendants, desks with a cool-lit monitor and a glowing table lamp, the
library's shelves lit along every shelf, reading chairs.

Most shapes are the anime kit's (run on the neon palette, see
vegetation.anime), restyled; the lamp post and bollard are new. The
conventions are the anime kit's, so the pack places and seats people the
same way: Blender Z-up, pieces face +Y (Godot -Z); the origin is the centre
of the footprint on the floor. Seat assets (`seat_<kind>_v2`) put the
origin at the seated occupant's position on the floor, facing +Y: a bench
or café chair seat is 0.47 m high, a desk chair 0.5 m, a reading chair's
cushion 0.42 m; a desk seat's desk and monitor stand ahead of the sitter,
the display facing them. The pegboard hangs on the wall plane behind its
origin from 1.0 m to 2.2 m; the pendant hangs from 3.7 m to a shade 2.5 m
up.

Glowing nodes (lamp_glow, which the pack scales by night):
    light   a lamp's glowing part, its origin at the lamp, where the pack
            may put an OmniLight: lamp_post, bollard, pendant_lamp, and
            the desks' table lamp
    lights  small lamps, emission only: the bench's strip, the parasol's
            bulbs, the café candles, the pegboard's light bar, the
            bookshelf's shelf lights
    screen  a monitor's display, in screen_glow (a cool emission)
"""
import math

import bpy

from lib import Mesh, rotz

import vegetation as veg
from vegetation import bulb, part, recolour

A = veg.anime("props")
SMOOTH = A.SMOOTH
usables = A.usables


def _screens():
    """Monitors glow cool, not as warm window glass."""
    recolour({"glass_light": "screen_glow"}, nodes=["screen"])


# ---- Street furniture ----

def lamp_post():
    """The sheets' street lamp: a black standard (a round plinth, a tapered
    base, a slender post with collars and a cross-bar with ball ends) under
    a warm glowing globe, the `light`, its origin at the globe's centre."""
    m, glow = Mesh(), Mesh()
    m.cylinder(0.25, 0.08, (0, 0, 0.04), "iron", sides=8)
    m.cylinder(0.16, 0.44, (0, 0, 0.3), "iron", sides=12, radius_top=0.085)
    m.cylinder(0.1, 0.05, (0, 0, 0.545), "iron", sides=12)
    m.cylinder(0.062, 3.12, (0, 0, 0.57 + 1.56), "iron", sides=10, radius_top=0.045)
    for z in (1.2, 3.2):
        m.cylinder(0.072, 0.05, (0, 0, z), "iron", sides=10)
    m.beam((-0.34, 0, 3.32), (0.34, 0, 3.32), 0.03, "iron")
    for x in (-0.34, 0.34):
        m.sphere(0.036, (x, 0, 3.32), "iron", subdivisions=1)
    m.cylinder(0.05, 0.1, (0, 0, 3.72), "iron", sides=10, radius_top=0.11)
    glow.sphere(0.22, (0, 0, 4.0), "lamp_glow", subdivisions=2)
    veg.finish("lamp_post", {"body": m}, smooth={"body": SMOOTH})
    part("lamp_post", "light", glow, at=(0, 0, 4.0), smooth=60)


def bollard():
    """The waterfront's square bollard: a dark post on a base plate, a lit
    band near its top between four black corner posts (the `light`, its
    origin in the band), and a cap."""
    m, glow = Mesh(), Mesh()
    m.box((0.24, 0.23, 0.03), (0, 0, 0.015), "iron", bevel=0.008)
    m.box((0.17, 0.17, 0.66), (0, 0, 0.36), "charcoal", bevel=0.012)
    for x in (-0.07, 0.07):
        for y in (-0.07, 0.07):
            m.box((0.03, 0.03, 0.13), (x, y, 0.755), "iron")
    glow.box((0.13, 0.13, 0.13), (0, 0, 0.755), "lamp_glow")
    m.box((0.2, 0.2, 0.05), (0, 0, 0.845), "charcoal", bevel=0.01)
    m.cylinder(0.13, 0.03, (0, 0, 0.885), "charcoal", sides=4, radius_top=0.07, rot=rotz(45))
    veg.finish("bollard", {"body": m}, smooth={"body": SMOOTH})
    part("bollard", "light", glow, at=(0, 0, 0.755))


def _bench(name, dy):
    """The anime kit's bench (slats, a raked back, iron ends and arms) in
    the waterfront's dark timber, and a warm strip under the seat's front
    edge that pools light on the paving (`lights`)."""
    def build():
        m = Mesh()
        A.bench(A.Frame(m, at=(0, dy, 0)))
        veg.finish(name, {"body": m}, smooth={"body": SMOOTH})
        recolour({"wood_light": "wood"})
        glow = Mesh()
        glow.box((1.2, 0.02, 0.016), (0, dy + 0.19, 0.415), "lamp_glow")
        part(name, "lights", glow, at=(0, dy + 0.19, 0.415))
    build.__doc__ = _bench.__doc__
    return build


# ---- Café ----

def umbrella_cafe():
    """The anime kit's eight-panel market parasol, dark (slate canvas, a
    charcoal valance, steel ribs and pole), a string of warm bulbs looped
    round under its valance (`lights`)."""
    A.umbrella_cafe()
    recolour({"cream": "charcoal", "warm_white": "steel_dark"})
    glow = Mesh()
    n = 8
    for k in range(2 * n):
        a = math.pi * k / n
        sag = 0.0 if k % 2 == 0 else 0.1
        bulb(glow, (1.12 * math.cos(a), 1.12 * math.sin(a), 1.8 - sag), 0.045)
    part("umbrella_cafe", "lights", glow, at=(0, 0, 1.75))


CAFE = {"warm_white": "slate_light", "wood_light": "wood"}


def _candle(name):
    """A candle in a small glass on the table's centre (`lights`)."""
    glow = Mesh()
    glow.cylinder(0.05, 0.01, (0, 0, 0.755), "iron", sides=8)
    glow.cylinder(0.034, 0.05, (0, 0, 0.785), "lamp_glow", sides=8)
    part(name, "lights", glow, at=(0, 0, 0.8), smooth=60)


def cafe_table():
    """The anime kit's bistro table, a dark slate top on its timber edge and
    iron pedestal, with a candle."""
    A.cafe_table_prop()
    recolour(CAFE)
    _candle("cafe_table")


def cafe_table_set():
    """The table and two bistro chairs across the X axis, 70 cm either side,
    in dark timber, with a candle on the table."""
    A.cafe_table_set()
    recolour(CAFE)
    _candle("cafe_table_set")


def seat_cafe_table():
    """A bistro chair, the seat 0.47 m up, in dark timber."""
    A.seat_cafe_table()
    recolour(CAFE)


# ---- Workshop ----

def workbench():
    """The anime kit's workbench and its clutter; the monitor's `screen`
    glows cool."""
    A.workbench()
    _screens()


def pegboard():
    """The anime kit's pegboard of tools on a grey board in a dark steel
    frame, and a light bar along its top rail washing the tools
    (`lights`)."""
    A.pegboard()
    recolour({"wood_light": "concrete", "wood": "steel_dark"})
    glow = Mesh()
    glow.box((1.84, 0.035, 0.04), (0, 0.035, 2.14), "steel_dark")
    glow.box((1.8, 0.025, 0.012), (0, 0.037, 2.114), "lamp_glow")
    part("pegboard", "lights", glow, at=(0, 0.037, 2.11))


def pendant_lamp():
    """The anime kit's black industrial pendant, its glowing bulb the
    `light`, the node's origin at the bulb."""
    A.pendant_lamp()
    veg.pivot(bpy.data.objects["light"], (0, 0, 2.55))


# ---- Desk ----

DESK = {"warm_white": "slate_light", "cream": "slate", "wood_light": "wood", "terracotta": "charcoal"}


def _desk(name, dy):
    """The anime kit's desk and task chair in dark timber and slate, the
    monitor's `screen` cool, and a table lamp with a glowing shade on the
    desk's right (`light`, its origin in the shade)."""
    def build():
        m, screen, glow = Mesh(), Mesh(), Mesh()
        A.desk_set(A.Frame(m, at=(0, dy, 0)), screen)
        x, y, top = 0.42, dy + 0.62, 0.76
        m.cylinder(0.07, 0.02, (x, y, top + 0.01), "frame", sides=10)
        m.cylinder(0.012, 0.3, (x, y, top + 0.17), "frame", sides=6)
        glow.cylinder(0.1, 0.13, (x, y, top + 0.37), "lamp_glow", sides=10, radius_top=0.075, cap=False)
        glow.cylinder(0.02, 0.03, (x, y, top + 0.33), "lamp_glow", sides=6)
        veg.finish(name, {"body": m, "screen": screen}, smooth={"body": SMOOTH})
        recolour(DESK)
        _screens()
        part(name, "light", glow, at=(x, y, top + 0.36), smooth=60)
    build.__doc__ = _desk.__doc__
    return build


# ---- Library ----

def bookshelf_v2():
    """The anime kit's 2 m bookshelf, full of books, in dark timber, a warm
    light strip under the front of every shelf (`lights`), as the sheets'
    shelves glow."""
    A.bookshelf_v2()
    recolour({"wood_light": "wood", "wood": "wood_dark", "terracotta": "charcoal"})
    glow = Mesh()
    for z in (0.52, 0.94, 1.36, 1.78, 2.2):
        glow.box((1.88, 0.02, 0.014), (0, 0.18, z - 0.037), "lamp_glow")
    part("bookshelf_v2", "lights", glow, at=(0, 0.18, 1.36))


READING = {"wood_light": "wood", "wood": "wood_dark"}


def reading_chair_v2():
    """The anime kit's reading armchair, in dark timber."""
    A.reading_chair_v2()
    recolour(READING)


def seat_reading_chair():
    """The reading armchair as a seat: the cushion 0.42 m up."""
    A.seat_reading_chair()
    recolour(READING)


# ---- Things to use: displays and perches ----

# The kit's colour for each role in the shared things to use (the anime
# kit builds them): slate and concrete, dark steel, navy faces the cyan
# text reads on, and a neon line on each, inside its footprint.
USE_LOOK = {
    "post": "steel_dark", "post_foot": "iron", "frame": "charcoal", "board": "slate_dark",
    "roof": "slate", "roof_ridge": "frame",
    "stone": "concrete", "stone_dark": "slate", "plaque": "navy", "plaque_frame": "steel",
    "base": "slate_dark", "housing": "slate", "canopy": "charcoal", "bezel": "frame", "screen": "navy",
    "step": "concrete", "nosing": "steel_dark", "wall": "brick", "coping": "concrete",
    "basin": "concrete", "rim": "stone", "water": "water",
    "seat_block": "slate", "seat": "wood",
}


def _neon(at, size, colour):
    """A neon tube (a box of `size` at `at`, in `colour`) in its own part
    of the body."""
    def add(parts):
        parts["body"].box(size, at, colour)
    return add


def _neons(*tubes):
    def add(parts):
        for tube in tubes:
            tube(parts)
    return add


# The workstation in the kit's look: a slate chair at a dark timber desk,
# a charcoal monitor behind a pale steel edge (the kit's glass frame, kept
# off the glass materials night lights as windows), and a magenta neon
# under the monitor and along the desk's front: not the cyan of a screen in
# use, so an idle desk's lights never read as its screen lit.
WORK_LOOK = {
    **USE_LOOK, "chair": "slate", "chair_frame": "steel_dark", "desk": "wood_dark", "desk_leg": "charcoal",
    "drawer": "slate_light", "keys": "slate_light", "casing": "charcoal", "screen": "navy", "trim": "steel_light",
    "light": "neon_magenta", "frame_style": "glass",
}

ASSETS = {
    "workstation": A.used("workstation", usables.workstation, display=True, look=WORK_LOOK),
    "noticeboard": A.used("noticeboard", usables.noticeboard, display=True, look=USE_LOOK,
                          ornament=_neons(_neon((0, 0.042, 1.73), (0.94, 0.012, 0.012), "neon_cyan"),
                                          _neon((0, 0.042, 0.87), (0.94, 0.012, 0.012), "neon_cyan"))),
    "plaque": A.used("plaque", usables.plaque, display=True, look=USE_LOOK,
                     ornament=_neon((0, 0.115, 0.76), (0.46, 0.012, 0.012), "neon_violet")),
    "kiosk": A.used("kiosk", usables.kiosk, display=True, look=USE_LOOK,
                    ornament=_neon((0, 0.245, 1.79), (0.76, 0.012, 0.02), "neon_magenta")),
    "steps": A.used("steps", usables.steps, look=USE_LOOK,
                    ornament=_neon((0, 0.006, 0.39), (2.96, 0.012, 0.015), "neon_amber")),
    "low_wall": A.used("low_wall", usables.low_wall, look=USE_LOOK,
                       ornament=_neon((0, 0.141, 0.38), (2.96, 0.012, 0.015), "neon_cyan")),
    "fountain": A.used("fountain", usables.fountain, look=USE_LOOK),
    "perch_seat": A.used("perch_seat", usables.perch_seat, look=USE_LOOK,
                         ornament=_neon((0, usables.SEAT_FRONT - 0.005, usables.SEAT_TOP - 0.05), (0.26, 0.012, 0.012), "neon_cyan")),
    "lamp_post": lamp_post,
    "bollard": bollard,
    "bench_park": _bench("bench_park", 0.04),
    "seat_bench_v2": _bench("seat_bench_v2", 0.0),
    "umbrella_cafe": umbrella_cafe,
    "cafe_table": cafe_table,
    "cafe_table_set": cafe_table_set,
    "seat_cafe-table_v2": seat_cafe_table,
    "workbench": workbench,
    "pegboard": pegboard,
    "pendant_lamp": pendant_lamp,
    "desk_v2": _desk("desk_v2", -0.25),
    "seat_desk_v2": _desk("seat_desk_v2", 0.0),
    "bookshelf_v2": bookshelf_v2,
    "reading_chair_v2": reading_chair_v2,
    "seat_reading-chair_v2": seat_reading_chair,
}
