"""Workshop and library modules, assembled by the pack along a footprint.

Conventions (every module, before the pack rotates it):
- metres, Godot axes, y up, floor top at y = 0;
- a wall module spans x in [-w/2, w/2]; its outer face is the plane z = 0
  and it is `T` thick toward +z (the building's inside), so the pack lays
  it along a footprint edge with -z pointing out of the building; trims
  and sills stand proud of z = 0 by one voxel;
- a corner pier sits on the footprint corner, 0.1 m proud of both faces,
  its body toward +x and +z (the inside of a north-west corner);
- roof pieces are separate assets from walls and sit on the wall tops
  (y = WS_H or LIB_H), so the cut-away hides roofs and swaps near walls
  for their `_low` twins.

Workshop: 5 m walls in 4 m bays; sawtooth roof bays 4 m across the ridge
and 4 m along it, low at -x, glazed on the +x vertical face; a gable
fills the bay's end under the roof, at z in [0, 0.3] of the bay's frame.

Library: 6 m walls in 2 m modules (the entrance is 4 m round a 2 m
opening, as is the workshop's door); an elliptic
barrel vault spanning 18 m in 2 m segments along z; white end walls with
a glass lunette, one piece for both ends (it is symmetric; rotate 180
degrees for the far end).
"""
import math

from shapes import m, new, text
from voxel import Asset

WS_H = m(5.0)
WS_T = m(0.3)
WS_BAY = m(4.0)
WS_RISE = m(3.0)  # the ridge is at ws_top(19) = 3.0 m
LIB_H = m(6.0)
LIB_T = m(0.3)
LIB_MOD = m(2.0)
VAULT_HALF = m(9.2)
# A door piece's opening, in cells: the exterior door's 2 m (the building
# kinds' door_width), clear from the floor to the lintel.
DOOR_OPENING = m(2.0)
VAULT_RISE = m(5.0)


# ---- Workshop ----

def _ws_panel(width, height=WS_H):
    """A plain yellow workshop wall: grey plinth with a lip, yellow body in
    half-metre blocks, a darker band and cornice at the top, pilasters at
    both ends (two modules side by side make one 0.2 m pilaster)."""
    g = new()
    half = width // 2
    for i in range(-half, half):
        for j in range(height):
            for k in range(WS_T):
                if j < 4:
                    key = "stone"
                elif j >= height - 4:
                    key = "yellow_dark"
                else:
                    key = "yellow"
                g.put(i, j, k, key)
        g.put(i, 0, -1, "stone")
        g.put(i, 1, -1, "stone")
        if height > 10:
            g.put(i, height - 2, -1, "yellow_dark")
            g.put(i, height - 1, -1, "yellow_dark")
    if height > 10:
        for i in (-half, half - 1):
            for j in range(4, height - 2):
                g.put(i, j, -1, "yellow_dark")
    return g


def _clear(g, i0, i1, j0, j1, k0=0, k1=WS_T):
    g.clear(i0, j0, k0, i1, j1, k1)


def _glaze(g, i0, i1, j0, j1, k, mullions=(), transoms=(), glass="glass", frame="steel"):
    """A pane in the plane k with a frame ring and bars."""
    for i in range(i0, i1):
        for j in range(j0, j1):
            edge = i in (i0, i1 - 1) or j in (j0, j1 - 1) or i in mullions or j in transoms
            g.put(i, j, k, frame if edge else glass)


def ws_wall():
    a = Asset("ws_wall")
    g = _ws_panel(WS_BAY)
    g.vary({"yellow"}, seed="ws_wall")
    a.part("wall", g)
    return a


def ws_window():
    a = Asset("ws_window")
    g = _ws_panel(WS_BAY)
    _clear(g, -16, 16, 10, 35)
    _glaze(g, -16, 16, 10, 35, 1, mullions=(-6, 5), transoms=(27,))
    for i in range(-17, 17):
        g.put(i, 9, -1, "stone")
    g.vary({"yellow"}, seed="ws_window")
    a.part("wall", g)
    return a


def ws_wall_glazed():
    """A clerestory strip: a band of glass high on the wall, over a plain
    lower wall."""
    a = Asset("ws_wall_glazed")
    g = _ws_panel(WS_BAY)
    _clear(g, -18, 18, 30, 43)
    _glaze(g, -18, 18, 30, 43, 1, mullions=(-12, -6, 0, 5, 11))
    for i in range(-19, 19):
        g.put(i, 29, -1, "yellow_dark")
    g.vary({"yellow"}, seed="ws_wall_glazed")
    a.part("wall", g)
    return a


def ws_door():
    """A 2 m open doorway (DOOR_OPENING: occupants walk through it) between
    glazed side lights, under a charcoal canopy at 3.1 m; plain wall above
    it for the WORKSHOP sign (from y = 3.5 m). The pack stretches it so the
    opening is as wide as each door."""
    a = Asset("ws_door")
    g = _ws_panel(WS_BAY)
    _clear(g, -18, 18, 0, 31, -1, WS_T)
    half = DOOR_OPENING // 2
    for side in ((-18, -half), (half, 18)):
        _glaze(g, side[0], side[1], 0, 31, 1, glass="glass")
    for i in (-half - 1, half):
        for j in range(0, 31):
            g.put(i, j, 0, "steel")
            g.put(i, j, 1, "steel")
    for i in range(-17, 17):
        for k in range(-9, 0):
            g.put(i, 31, k, "charcoal")
        g.put(i, 32, -9, "charcoal")
    g.vary({"yellow"}, seed="ws_door")
    a.part("wall", g)
    return a


def _low(name, width, opening=None, top="yellow_dark"):
    a = Asset(name)
    g = new()
    half = width // 2
    for i in range(-half, half):
        if opening and opening[0] <= i < opening[1]:
            continue
        for j in range(6):
            for k in range(WS_T):
                g.put(i, j, k, "stone" if j < 4 else top)
        g.put(i, 0, -1, "stone")
        g.put(i, 1, -1, "stone")
    a.part("wall", g)
    return a


def ws_wall_half():
    """A 2 m plain wall, to centre a 4 m door bay on any 2 m point."""
    a = Asset("ws_wall_half")
    g = _ws_panel(WS_BAY // 2)
    g.vary({"yellow"}, seed="ws_wall_half")
    a.part("wall", g)
    return a


def ws_wall_low():
    return _low("ws_wall_low", WS_BAY)


def ws_wall_low_half():
    return _low("ws_wall_low_half", WS_BAY // 2)


def ws_door_low():
    return _low("ws_door_low", WS_BAY, opening=(-DOOR_OPENING // 2, DOOR_OPENING // 2))


def ws_corner():
    a = Asset("ws_corner")
    g = new()
    g.box(-1, 0, -1, 3, WS_H + 2, 3, lambda i, j, k: "stone" if j < 4 else "yellow_dark")
    a.part("pier", g)
    return a


def ws_corner_low():
    """The corner pier cut down to the low course, for the cut-away."""
    a = Asset("ws_corner_low")
    g = new()
    g.box(-1, 0, -1, 3, 6, 3, lambda i, j, k: "stone" if j < 4 else "yellow_dark")
    a.part("pier", g)
    return a


def ws_top(i):
    """The sawtooth roof's top cell row over column i of a bay: treads of
    0.5 m run and 0.4 m rise (chunky enough to read as blocks, and not to
    shimmer, from the 40-70 m diagonal camera)."""
    return 2 + ((i + WS_BAY // 2) // 5) * 4


def ws_low(i):
    """The roof slab's lowest cell row over column i: two voxels under the
    tread, and down to the tread below where a riser starts."""
    lo = ws_top(i) - 2
    if i > -WS_BAY // 2:
        lo = min(lo, ws_top(i - 1))
    return lo


def ws_roof_bay():
    """One sawtooth tooth: a yellow staircase slope rising from -x to +x, a
    steel gutter at the foot, a darker ridge cap, and a vertical strip of
    glass under the ridge facing +x (the next tooth's foot meets it)."""
    a = Asset("ws_roof_bay")
    g = new()
    half = WS_BAY // 2
    for i in range(-half, half):
        for k in range(WS_BAY):
            for j in range(ws_low(i), ws_top(i)):
                if i == -half:
                    key = "steel"
                elif i >= half - 2:
                    key = "yellow_dark"
                else:
                    key = "yellow_roof"
                g.put(i, j, k, key)
    ridge = ws_low(half - 1)
    for k in range(WS_BAY):
        for j in range(0, ridge):
            mull = k % 5 == 0 or j in (0, 1, ridge - 1)
            g.put(half - 1, j, k, "steel" if mull else "glass_grey")
    g.vary({"yellow_roof"}, block=(5, 5, 10), light=0.2, dark=0.12, seed="ws_roof_bay")
    a.part("roof", g)
    return a


def ws_gable():
    """The yellow end of a tooth, under its slope, with an orange verge
    tracing the staircase one voxel outside it; the glazed column is left
    to the roof bay so nothing overlaps."""
    a = Asset("ws_gable")
    g = new()
    half = WS_BAY // 2
    for i in range(-half, half):
        for k in range(WS_T):
            if i < half - 1:
                for j in range(ws_low(i)):
                    g.put(i, j, k, "yellow")
            g.put(i, ws_top(i), k, "orange")
            if i < half - 1:
                for j in range(ws_top(i), ws_top(i + 1) + 1):
                    g.put(i, j, k, "orange")
    g.vary({"yellow"}, seed="ws_gable")
    a.part("gable", g)
    return a


def ws_sign():
    """WORKSHOP in navy letters 1.4 m tall (9.4 m long), 0.2 m proud of the
    wall: the pack mounts its back (z = 0) on the wall face above the
    door canopy."""
    word = "WORKSHOP"
    a = Asset("ws_sign")
    g = new()
    text(g, word, 0, -1, "navy", depth=2, scale=2)
    a.part("sign", g)
    return a


# ---- Library ----

def _lib_panel(width, height=LIB_H):
    """An orange library wall: grey plinth, orange in half-metre blocks, a
    lighter orange cornice."""
    g = new()
    half = width // 2
    for i in range(-half, half):
        for j in range(height):
            for k in range(LIB_T):
                if j < 4:
                    key = "stone"
                elif j >= height - 3:
                    key = "orange_light"
                else:
                    key = "orange"
                g.put(i, j, k, key)
        g.put(i, 0, -1, "stone")
        g.put(i, 1, -1, "stone")
        if height > 10:
            for j in range(height - 3, height):
                g.put(i, j, -1, "orange_light")
    return g


def lib_wall():
    """A tall two-storey window in a blue frame."""
    a = Asset("lib_wall")
    g = _lib_panel(LIB_MOD)
    for i in range(-7, 7):
        for j in range(7, 53):
            if i in (-7, 6) or j in (7, 52):
                g.put(i, j, -1, "blue")
    _clear(g, -6, 6, 8, 52, 0, LIB_T)
    _glaze(g, -6, 6, 8, 52, 1, mullions=(-1, 0), transoms=(30, 31), glass="glass", frame="blue")
    g.vary({"orange"}, seed="lib_wall")
    a.part("wall", g)
    return a


def lib_wall_plain():
    a = Asset("lib_wall_plain")
    g = _lib_panel(LIB_MOD)
    g.vary({"orange"}, seed="lib_wall_plain")
    a.part("wall", g)
    return a


def lib_entrance():
    """A 4 m glass entrance: a blue curtain wall in a blue portal, 4 m
    tall, warm lit panes over a 2 m open doorway (DOOR_OPENING), under a
    white canopy; orange wall above it for the LIBRARY sign (from
    y = 4.3 m). The pack stretches it so the opening is as wide as each
    door."""
    a = Asset("lib_entrance")
    g = _lib_panel(m(4.0))
    for i in range(-19, 19):
        for j in range(0, 41):
            if i in (-19, 18) or j == 40:
                g.put(i, j, -1, "blue")
    half = DOOR_OPENING // 2
    _clear(g, -18, 18, 0, 40, 0, LIB_T)
    _glaze(g, -18, 18, 0, 40, 1, mullions=(-half - 1, half), transoms=(28, 29), glass="glass", frame="blue")
    for i in range(-half, half):
        for j in range(30, 40):
            if g.get(i, j, 1) == "glass":
                g.put(i, j, 1, "window_glow")
    _clear(g, -half, half, 0, 28, -1, LIB_T)
    for i in (-half - 1, half):
        for j in range(0, 28):
            g.put(i, j, 1, "charcoal")
    for i in range(-15, 15):
        for k in range(-11, 0):
            g.put(i, 29, k, "white")
            g.put(i, 30, k, "white")
        for j in (31,):
            g.put(i, j, -11, "orange_dark")
    g.vary({"orange"}, seed="lib_entrance")
    a.part("entrance", g)
    return a


def lib_wall_low():
    return _low("lib_wall_low", LIB_MOD, top="orange_light")


def lib_entrance_low():
    return _low("lib_entrance_low", m(4.0), opening=(-DOOR_OPENING // 2, DOOR_OPENING // 2), top="orange_light")


def lib_corner():
    a = Asset("lib_corner")
    g = new()
    g.box(-1, 0, -1, 3, LIB_H + 1, 3, lambda i, j, k: "stone" if j < 4 else "orange_light")
    a.part("pier", g)
    return a


def lib_corner_low():
    """The corner pier cut down to the low course, for the cut-away."""
    a = Asset("lib_corner_low")
    g = new()
    g.box(-1, 0, -1, 3, 6, 3, lambda i, j, k: "stone" if j < 4 else "orange_light")
    a.part("pier", g)
    return a


def vault_top(i):
    """Top of the vault's shell over column i (cells above the wall top)."""
    x = (i + 0.5) / VAULT_HALF
    if abs(x) >= 1:
        return 0
    return max(1, int(round(VAULT_RISE * math.sqrt(1 - x * x))))


def vault_low(i):
    """Bottom of the shell over column i: two voxels thick, and deep enough
    to meet the neighbouring columns so the steps stay closed."""
    lo = min(vault_top(i) - 2, vault_top(i - 1), vault_top(i + 1))
    if abs(i + 0.5) > VAULT_HALF - 3:
        lo = 0
    return max(0, lo)


def lib_vault():
    """A 2 m segment of the orange barrel vault, spanning x in [-9.2, 9.2]
    (18 m between the walls' outer faces plus a 0.2 m eave), rising 5 m;
    the axis runs along +z from z = 0. A darker rib crosses the vault at the
    segment's start, bands of lighter orange run along the axis, and a strip
    of glass runs along both springings."""
    a = Asset("lib_vault")
    g = new()
    for i in range(-VAULT_HALF, VAULT_HALF):
        top = vault_top(i)
        band = int(abs(i + 0.5) // 12) % 2
        for j in range(vault_low(i), top):
            for k in range(LIB_MOD):
                if abs(i + 0.5) > VAULT_HALF - 5 and 1 <= j < 12:
                    key = "steel" if j in (1, 11) else "glass"
                elif k == 0:
                    key = "orange_dark"
                else:
                    key = "orange_light" if band else "orange"
                g.put(i, j, k, key)
    g.vary({"orange", "orange_light"}, block=(6, 100, LIB_MOD), light=0.2, dark=0.2, seed="lib_vault")
    # Segments always meet another segment or an end cap (whose section
    # covers the vault's), so the section faces at z = 0 and z = 2 m are
    # never seen.
    a.part("roof", g, open_planes=((2, -1, 0), (2, 1, LIB_MOD)))
    return a


CAP = m(4.0)
CAP_BAND = 4
CAP_COLUMN = 2


def cap_scale(k):
    """How far the cap's section at row k has shrunk toward the end wall:
    1 at the band that meets the vault, falling to about 0.3 at z = 0 (a
    quarter ellipsoid sampled at each 0.4 m band's inner edge)."""
    t = k // CAP_BAND
    z = (CAP - (t + 1) * CAP_BAND) / CAP
    return (1 - z * z) ** 0.5


def cap_top(i, k):
    """Top of the vault's white end cap over column (i, k): nested arches,
    each 0.4 m band a vault section scaled by cap_scale, in 0.2 m columns
    of 0.1 m steps; 0 outside the arch."""
    f = cap_scale(k)
    x = ((i // CAP_COLUMN) * CAP_COLUMN + CAP_COLUMN / 2) / (VAULT_HALF * f)
    if abs(x) >= 1:
        return 0
    return max(1, int(round(VAULT_RISE * f * (1 - x * x) ** 0.5)))


def lib_vault_end():
    """The vault's rounded white end over z in [0, 4] (z = 4 meets a vault
    segment's start): nested white arches stepping down toward the end
    wall, on a flat white roof that closes the footprint's corners; the
    walls under it are ordinary library walls. Use it rotated 180 degrees
    at the far end."""
    a = Asset("lib_vault_end")
    g = new()
    for k in range(CAP):
        outer = k // CAP_BAND * CAP_BAND - 1
        for i in range(-VAULT_HALF, VAULT_HALF):
            top = cap_top(i, k)
            below = cap_top(i, outer) if outer >= 0 else 0
            nb = min(cap_top(i - CAP_COLUMN, k), cap_top(i + CAP_COLUMN, k))
            lo = max(0, min(top - 2, nb, below))
            for j in range(lo, top):
                g.put(i, j, k, "white")
            g.put(i, 0, k, "white")
        # The last band also holds the vault's whole section, so the
        # segments' open section faces are always covered.
    for k in range(CAP - CAP_BAND, CAP):
        for i in range(-VAULT_HALF, VAULT_HALF):
            for j in range(vault_low(i), vault_top(i)):
                g.put(i, j, k, "white")
    g.vary({"white"}, block=(6, 100, CAP_BAND), light=0.15, dark=0.15, seed="lib_vault_end")
    a.part("roof", g)
    return a


def lib_sign():
    """LIBRARY in navy letters 1.4 m tall (8.2 m long), 0.2 m proud of the
    wall, for above the entrance."""
    word = "LIBRARY"
    a = Asset("lib_sign")
    g = new()
    text(g, word, 0, -1, "navy", depth=2, scale=2)
    a.part("sign", g)
    return a


ASSETS = {f.__name__: f for f in (
    ws_wall, ws_wall_half, ws_window, ws_wall_glazed, ws_door, ws_wall_low, ws_wall_low_half, ws_door_low,
    ws_corner, ws_corner_low,
    ws_roof_bay, ws_gable, ws_sign,
    lib_wall, lib_wall_plain, lib_entrance, lib_wall_low, lib_entrance_low, lib_corner, lib_corner_low,
    lib_vault, lib_vault_end, lib_sign,
)}
