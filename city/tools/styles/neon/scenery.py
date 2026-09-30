"""Scenery for the neon noir kit, after the 10 sheets: dark asphalt between
grey kerbs; the tram lane's rails set flush in dark stone; deep blue water
with a few lighter ripples (the pack makes it mirror the lights); the pale
stone arch bridge lined with warm globe lamps, a glowing line under its
copings and lamps low on its piers; the cream-and-red tram, its windows
lit warm from inside; dark, subtle night clouds; a small sloop showing a
masthead light and a lit cabin; the square's dark stone paving (the pack
makes it wet); the park's path; dark metal waterfront railings.

The anime kit's pieces carry the shapes, run on the neon palette (see
vegetation.anime); the neon kit restyles them and adds the lights. Pivots,
orientations, extents and node names match the anime kit's (and so the
low-poly kit's), because the townscape places them the same way (Blender
Z-up, metres; +Y is Godot's forward, -Z):
    street_tile         2 m x 2 m of asphalt, its top at z = 0
    street_kerb         2 m of kerb along x, its body on z in [-0.08, 0.08]
    tram_track          2 m of track along x in a 2.8 m strip, its top at z = 0
    water_tile          4 m x 4 m of water; z = 0 is the surface
    bridge_span         one 8 m arch along x, the deck's paving at z = 1.26
    bridge_pier         the pier at each joint of spans, lamps on its parapets
    tram                three sections along x, 20.5 m; z = 0 is the rail
    cloud_a, cloud_b    clouds, base at z = 0
    sailboat            5 m long along +Y; z = 0 is the waterline
    paving_tile_a/b/c   1 m of the square's paving on a 0.5 m grid
    path                1 m of park path running along Y
    railing             2 m of railing along x, its post at the -x end
    railing_post        the post that closes a run
The pack tiles ground pieces, kerb, track, water and railings with a
MultiMesh of the first mesh it finds, so each of those is a single mesh.

Glowing nodes (the pack scales lamp_glow and window_glow by night):
`lights` on the bridge's span and pier, on the boat (many small lamps,
emission only; the pier's origin is between its two parapet lamps) and
under the tram's ceiling.
"""
import lib
from lib import Mesh

import vegetation as veg
from vegetation import bulb, part, recolour

A = veg.anime("scenery")


# ---- The bridge ----

BRIDGE_STONE = {"stone": "cream"}


def bridge_span():
    """The anime kit's arch (semi-elliptical, ringed by voussoirs, a string
    course, solid parapets under copings, a paved deck) in the sheets' pale
    stone, and a warm strip of light tucked under each coping's lip, inside
    and out, that draws the bridge's line across the night river
    (`lights`)."""
    A.bridge_span()
    recolour(BRIDGE_STONE)
    glow = Mesh()
    top = A.DECK + 0.87
    for s in (-1, 1):
        for y in (A.FACE + 0.025, A.FACE - 0.305):
            glow.box((A.SPAN, 0.03, 0.04), (0, s * y, top), "lamp_glow")
    part("bridge_span", "lights", glow, at=(0, 0, top))


def _globe_lamp(m, glow, x, y, z, height):
    """A black lamp standard from z to z + height on a pedestal: a square
    foot, a slender post with a collar, a cup and a warm globe (in `glow`)."""
    m.box((0.24, 0.24, 0.22), (x, y, z + 0.11), "iron", bevel=0.02)
    m.cylinder(0.055, height - 0.62, (x, y, z + 0.22 + (height - 0.62) / 2), "iron", 8, radius_top=0.042)
    m.cylinder(0.07, 0.05, (x, y, z + 0.6), "iron", 8)
    cup = z + height - 0.38
    m.cylinder(0.05, 0.08, (x, y, cup), "iron", 8, radius_top=0.1)
    glow.sphere(0.17, (x, y, cup + 0.2), "lamp_glow", subdivisions=2)
    m.cylinder(0.035, 0.05, (x, y, cup + 0.39), "iron", 6)


def bridge_pier():
    """A pier between arches, as the anime kit's (pointed cutwaters under
    sloping hoods, a cornice, a pedestal on each parapet) in the pale
    stone, carrying a black standard with a warm globe on each pedestal,
    and a lamp on each face just over the water that lights the pier and
    the arches' springing. The four lamps are `lights`, its origin between
    the two globes."""
    m, glow = Mesh(), Mesh()
    pier, face, deck, foot = A.PIER, A.FACE, A.DECK, A.FOOT
    half_y = face + 0.3
    m.box((2 * pier, 2 * half_y, deck - foot + 2.0), (0, 0, (deck + foot - 2.0) / 2), "cream", bevel=0.03)
    for s in (-1, 1):
        m.prism([(-pier, 0.0), (pier, 0.0), (0.0, s * 1.1)], 4.4, (0, s * half_y, -2.2), "cream", axis="z")
        base, hood = 0.0, 0.62
        A._solid(m, [(-pier - 0.07, s * half_y, base), (pier + 0.07, s * half_y, base), (0, s * (half_y + 1.16), base),
                     (0, s * half_y, base + hood)],
                 [(0, 1, 2), (0, 2, 3), (2, 1, 3), (1, 0, 3)], "warm_white")
        # The pedestal on the parapet, its cap and the lamp standard.
        y = s * (face - 0.1)
        m.box((0.84, 0.6, 1.2), (0, y, deck + 0.6), "cream", bevel=0.02)
        m.box((0.96, 0.72, 0.14), (0, y, deck + 1.27), "warm_white", bevel=0.02)
        _globe_lamp(m, glow, 0, y, deck + 1.34, 2.4)
        # The low lamp on the pier's face, over the hood.
        m.box((0.26, 0.1, 0.34), (0, s * (half_y + 0.05), 0.95), "iron", bevel=0.015)
        glow.box((0.18, 0.05, 0.24), (0, s * (half_y + 0.11), 0.95), "lamp_glow")
    m.box((2 * pier + 0.2, 2 * half_y + 0.24, 0.22), (0, 0, deck - 0.09), "warm_white", bevel=0.02)
    m.build("pier", lib.root("bridge_pier"))
    part("bridge_pier", "lights", glow, at=(0, 0, deck + 1.34 + 2.22), smooth=60)


# ---- The tram ----

def tram():
    """The sheets' tram, as the anime kit builds it: three cream sections on
    dark bellows (red skirt, a red line under the roof, rounded noses with
    raked, dark-framed windscreens, headlights and a lit sign, roof gear
    and a pantograph), with the riders seen through its big windows and
    its ceiling lights (window_glow in `lights`) lit warm at night."""
    A.tram()


# ---- Sky and river ----

CLOUD = {"warm_white": "render_sky", "steel_light": "slate_light"}


def cloud_a():
    """The anime kit's broad cumulus, as a dark night cloud: blue-grey
    above, slate beneath, barely lighter than the navy sky."""
    A.cloud_a()
    recolour(CLOUD)


def cloud_b():
    """The anime kit's smaller cumulus, as a dark night cloud."""
    A.cloud_b()
    recolour(CLOUD)


def sailboat():
    """The anime kit's sloop (a pale hull with a blue sheer stripe, teak
    deck, cabin, mast, boom and sails) with pale sails, its portholes lit
    warm, a lantern on the cabin roof and a masthead light (`lights`, its
    origin at the lantern)."""
    A.sailboat()
    recolour({"canvas": "cream", "glass": "window_glow"})
    glow = Mesh()
    glow.box((0.12, 0.12, 0.03), (0, 0.2, 0.825), "iron")
    glow.box((0.08, 0.08, 0.1), (0, 0.2, 0.89), "lamp_glow")
    glow.cylinder(0.07, 0.04, (0, 0.2, 0.96), "iron", 6, radius_top=0.02)
    bulb(glow, (0, 0.75, 6.56), 0.06)
    part("sailboat", "lights", glow, at=(0, 0.2, 0.89))


# ---- Railings ----

def railing():
    """The anime kit's waterfront railing in dark metal throughout: a
    steel handrail over black iron posts and rails."""
    A.railing()
    recolour({"warm_white": "steel_dark"})


ASSETS = {
    "street_tile": A.street_tile,
    "street_kerb": A.street_kerb,
    "tram_track": A.tram_track,
    "water_tile": A.water_tile,
    "bridge_span": bridge_span,
    "bridge_pier": bridge_pier,
    "tram": tram,
    "cloud_a": cloud_a,
    "cloud_b": cloud_b,
    "sailboat": sailboat,
    "paving_tile_a": A.paving_tile("a"),
    "paving_tile_b": A.paving_tile("b"),
    "paving_tile_c": A.paving_tile("c"),
    "path": A.path,
    "railing": railing,
    "railing_post": A.railing_post,
}
