"""Scenery for the solarpunk kit, after the 09 sheets: light grey streets
between pale kerbs; the tram's grooved rails laid in a green grass bed
between pale edging; bright river-blue water; the pale stone three-arch
bridge with white-and-brass lamps on its piers; the cream tram with its
red bands, big dark-framed windows and rounded noses; puffy cumulus; a
white sailboat; warm sand stone paving; the park's sand path; and the
waterfront's railing of pale stone posts under a brass handrail.

The anime kit (tools/styles/anime/scenery.py) fixes every piece's name,
pivot, orientation and extent, because the townscape places each kit the
same way; its pieces build here in the solarpunk palette wherever the
design already fits (streets, kerbs, water, paving, path, the span, the
tram, clouds and the boat; the tram with its bands moved and its glass
dark-tinted, as the sheets paint it). The pack draws tiled pieces (ground tiles,
kerb, track, water, railings) with MultiMesh from the first mesh it finds,
so each is a single mesh.
"""
import lib
from lib import Mesh
from vegetation import _anime, swapped

A = _anime("scenery")
_add, _sides, _solid = A._add, A._sides, A._solid


# ---- The tram track ----

# Bands across the track's 2.8 m strip, from -Y to +Y: (y where the band
# starts, colour). Grass between and beside the rails; each rail a steel
# head and a dark flangeway on a pale concrete lip; pale stone edging.
TRACK_BANDS = [(-1.40, "kerb"), (-1.28, "grass"), (-0.80, "concrete"), (-0.765, "steel"), (-0.695, "frame"),
               (-0.665, "concrete"), (-0.63, "grass"), (0.63, "concrete"), (0.665, "frame"), (0.695, "steel"),
               (0.765, "concrete"), (0.80, "grass"), (1.28, "kerb"), (1.40, None)]
RAIL_RISE = 0.015


def tram_track():
    """Two metres of the tram line in its grass bed: grass between and
    beside the rails, each rail's steel head standing 1.5 cm proud on a
    pale concrete lip with a dark flangeway inside it, and pale stone
    edging along both sides of the 2.8 m strip. The top is at z = 0 (the
    pack lays it 2 cm up); its edges run 12 cm down."""
    r = lib.root("tram_track")
    m = Mesh()
    verts, faces, mats = [], [], []
    for (y0, mat), (y1, _) in zip(TRACK_BANDS, TRACK_BANDS[1:]):
        k = len(verts)
        z = RAIL_RISE if mat == "steel" else 0.0
        verts += [(-1.0, y0, z), (1.0, y0, z), (1.0, y1, z), (-1.0, y1, z)]
        faces.append((k, k + 1, k + 2, k + 3))
        mats.append(mat)
    _add(m, verts, faces, mats)
    # The rail heads' sides, down to the bed.
    for y0, y1 in ((-0.765, -0.695), (0.695, 0.765)):
        _add(m, [(-1, y0, 0), (1, y0, 0), (1, y0, RAIL_RISE), (-1, y0, RAIL_RISE),
                 (1, y1, 0), (-1, y1, 0), (-1, y1, RAIL_RISE), (1, y1, RAIL_RISE)],
             [(0, 1, 2, 3), (4, 5, 6, 7)], "steel")
    # An underlay behind the seams, and the strip's edges and ends.
    _add(m, [(-1, -1.4, -0.01), (1, -1.4, -0.01), (1, 1.4, -0.01), (-1, 1.4, -0.01)], [(0, 1, 2, 3)], "grass_dark")
    _sides(m, [(-1, -1.4), (1, -1.4), (1, 1.4), (-1, 1.4)], -0.12, 0.0, "kerb")
    m.build("track", r)


# ---- The bridge ----

def _pier_lamp(m, y, z):
    """A white-and-brass lamp on a pier's pedestal (its foot at height z):
    a brass-banded plinth, a slim white column, a brass collar, a warm
    glowing globe in a brass ring, and a small solar cap."""
    m.cylinder(0.15, 0.3, (0, y, z + 0.15), "warm_white", 12, radius_top=0.12)
    m.cylinder(0.155, 0.04, (0, y, z + 0.3), "brass", 12)
    m.cylinder(0.06, 1.1, (0, y, z + 0.87), "warm_white", 10, radius_top=0.045)
    m.cylinder(0.075, 0.06, (0, y, z + 1.44), "brass", 10)
    m.sphere(0.17, (0, y, z + 1.66), "lamp_glow", subdivisions=2, scale=(1, 1, 1.1))
    m.cylinder(0.14, 0.03, (0, y, z + 1.52), "brass", 12)
    m.cylinder(0.2, 0.05, (0, y, z + 1.86), "brass", 12, radius_top=0.14)
    m.box((0.3, 0.3, 0.03), (0, y, z + 1.9), "solar", rot=lib.rotx(-8))
    m.cylinder(0.02, 0.1, (0, y, z + 1.98), "brass", 6)


def bridge_pier():
    """A pier between arches, as the anime kit's: pointed cutwaters up and
    down stream under sloping white hoods, faces rising to a white
    cornice, and a pedestal on each parapet, here carrying a white-and-
    brass lamp with a glowing globe."""
    r = lib.root("bridge_pier")
    m = Mesh()
    PIER, FACE, DECK, FOOT = A.PIER, A.FACE, A.DECK, A.FOOT
    half_y = FACE + 0.3
    m.box((2 * PIER, 2 * half_y, DECK - FOOT + 2.0), (0, 0, (DECK + FOOT - 2.0) / 2), "stone", bevel=0.03)
    for s in (-1, 1):
        m.prism([(-PIER, 0.0), (PIER, 0.0), (0.0, s * 1.1)], 4.4, (0, s * half_y, -2.2), "stone", axis="z")
        base, hood = 0.0, 0.62
        _solid(m, [(-PIER - 0.07, s * half_y, base), (PIER + 0.07, s * half_y, base), (0, s * (half_y + 1.16), base),
                   (0, s * half_y, base + hood)],
               [(0, 1, 2), (0, 2, 3), (2, 1, 3), (1, 0, 3)], "warm_white")
        y = s * (FACE - 0.1)
        m.box((0.84, 0.6, 1.2), (0, y, DECK + 0.6), "stone", bevel=0.02)
        m.box((0.96, 0.72, 0.14), (0, y, DECK + 1.27), "warm_white", bevel=0.02)
        _pier_lamp(m, y, DECK + 1.34)
    m.box((2 * PIER + 0.2, 2 * half_y + 0.24, 0.22), (0, 0, DECK - 0.09), "warm_white", bevel=0.02)
    lib.smooth(m.build("pier", r))


# ---- The tram ----

# The anime tram's livery bands between its rings up the side, moved as
# the sheets paint the tram: a white skirt over the dark sill, a broad red
# band just under the windows (its foot lowered to 0.85 m), and the red
# band under the roof.
TRAM_RINGS = list(A.TRAM_RINGS)
TRAM_RINGS[3] = (0.85, 0.0, 0.0)
TRAM_BANDS = list(A.TRAM_BANDS)
TRAM_BANDS[2] = ("tram_cream", "tram_cream")
TRAM_BANDS[3] = ("tram_coral", "tram_coral")


def tram():
    """The sheets' tram, as the anime kit builds it: three cream sections
    articulated on dark bellows, rounded noses with raked windscreens under
    a lit sign, big dark-framed windows and glazed doors, roof equipment
    and a pantograph. Here the lower red band runs just under the windows
    over a white skirt, and the glass is dark-tinted, as the sheets show."""
    saved = A.TRAM_RINGS, A.TRAM_BANDS
    A.TRAM_RINGS, A.TRAM_BANDS = TRAM_RINGS, TRAM_BANDS
    try:
        with swapped({"glass": "glass_dark"}):
            A.tram()
    finally:
        A.TRAM_RINGS, A.TRAM_BANDS = saved


# ---- Railings ----

RAIL_H = 1.0


def _railing_post(m, x):
    """A square pale stone post, chamfered, on a plinth, with a brass
    band under a stone cap; the handrail runs into it."""
    m.box((0.16, 0.16, 0.06), (x, 0, 0.03), "stone_dark", bevel=0.012)
    m.box((0.13, 0.13, RAIL_H + 0.02), (x, 0, 0.06 + (RAIL_H + 0.02) / 2), "stone", bevel=0.014)
    m.box((0.136, 0.136, 0.025), (x, 0, RAIL_H - 0.07), "brass", bevel=0.004)
    m.box((0.15, 0.15, 0.04), (x, 0, RAIL_H + 0.1), "stone", bevel=0.014)


def railing():
    """Two metres of the waterfront railing, running along x from -1 to 1
    (as the anime kit's): a pale stone post at the -x end (the next
    module's post, or a `railing_post`, closes the +x end), a round brass
    handrail over two slimmer brass rails, and a brass baluster midway."""
    m = Mesh()
    _railing_post(m, -0.92)
    m.cylinder(0.035, 2.0, (0, 0, RAIL_H - 0.02), "brass", 10, rot=lib.roty(90))
    m.cylinder(0.018, 2.0, (0, 0, 0.55), "brass", 6, rot=lib.roty(90))
    m.cylinder(0.016, 2.0, (0, 0, 0.2), "brass", 6, rot=lib.roty(90))
    m.cylinder(0.02, RAIL_H - 0.2, (0.07, 0, 0.1 + (RAIL_H - 0.2) / 2), "brass", 6)
    lib.finish("railing", {"body": m}, smooth_parts=("body",))


def railing_post():
    """The post that closes a run of railing, or turns its corner."""
    m = Mesh()
    _railing_post(m, 0.0)
    lib.finish("railing_post", {"body": m}, smooth_parts=("body",))


ASSETS = {
    "street_tile": A.street_tile,
    "street_kerb": A.street_kerb,
    "tram_track": tram_track,
    "water_tile": A.water_tile,
    "bridge_span": A.bridge_span,
    "bridge_pier": bridge_pier,
    "tram": tram,
    "cloud_a": A.cloud_a,
    "cloud_b": A.cloud_b,
    "sailboat": A.sailboat,
    "paving_tile_a": A.paving_tile("a"),
    "paving_tile_b": A.paving_tile("b"),
    "paving_tile_c": A.paving_tile("c"),
    "path": A.path,
    "railing": railing,
    "railing_post": railing_post,
}
