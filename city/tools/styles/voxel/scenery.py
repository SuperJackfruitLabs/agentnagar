"""Ground tiles, the river, the bridge, the tram and its track and shelter,
and the town blocks around the district.

Conventions:
- ground tiles are 2 m squares (the pack's module) centred on the origin,
  one voxel thick, top at y = 0; the water tile is 4 m; the pack tiles them
  and chooses paving variants by a hash of the cell;
- linear pieces (street dash, crosswalk, kerb, quay, tram track, bridge
  span) run along x; the pack rotates them to the line's direction;
- the tram runs along +x (as the pack's vehicles expect), three cars
  centred on the origin, 20.5 m on the shared tram layout, wheels on
  y = 0;
- blocks stand on y = 0 centred on the origin, fronts toward -z.
"""
import sys
from pathlib import Path

from shapes import canopy, m, new, text
from voxel import Asset, unit

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "shared"))
import tram_layout  # noqa: E402

TILE = m(2.0)


def _tile(name, key_of, size=TILE, depth=1, node=None):
    a = Asset(name)
    g = new()
    half = size // 2
    for i in range(-half, half):
        for k in range(-half, half):
            key = key_of(i, k)
            for j in range(-depth, 0):
                g.put(i, j, k, key)
    a.part(node or name.split("_")[0], g)
    return a


def _paving(variant):
    """0.5 m slabs in three greys, a stable hash per slab and variant."""
    def key(i, k):
        u = unit("paving", variant, i // 5, k // 5)
        return "paving_light" if u < 0.3 else ("paving_dark" if u > 0.82 else "paving")
    return key


def paving_a():
    return _tile("paving_a", _paving("a"), node="paving")


def paving_b():
    return _tile("paving_b", _paving("b"), node="paving")


def paving_c():
    """The same slabs with a darker 0.1 m joint on two edges, for borders."""
    base = _paving("c")
    return _tile("paving_c", lambda i, k: "stone" if i == -TILE // 2 or k == -TILE // 2 else base(i, k),
                 node="paving")


def lawn_tile():
    return _tile("lawn_tile", lambda i, k: "lawn_dark" if unit("lawn", i // 5, k // 5) < 0.3 else "lawn",
                 node="lawn")


def street_tile():
    return _tile("street_tile", lambda i, k: "asphalt-" if unit("asph", i // 10, k // 10) < 0.25 else "asphalt",
                 node="street")


def street_dash():
    """Asphalt with a 1 m white dash on its centre line, along x."""
    return _tile("street_dash", lambda i, k: "white" if -1 <= k < 1 and i < 0 else "asphalt", node="street")


def crosswalk():
    """White bars 0.4 m wide across the street (the street runs along x)."""
    return _tile("crosswalk", lambda i, k: "white" if (i + 10) % 8 < 4 and -8 <= k < 8 else "asphalt",
                 node="street")


def kerb():
    """A 2 m kerb stone along x: 0.3 m wide, 0.1 m proud of the ground,
    its road-side face at z = 0 and its body toward +z."""
    a = Asset("kerb")
    g = new()
    g.box(-TILE // 2, -1, 0, TILE // 2, 1, 3, "kerb")
    a.part("stone", g)
    return a


def water_tile():
    """A 4 m square of river, top at y = 0: water blue with a scatter of
    lighter ripples, each ripple a short dash along x."""
    size = m(4.0)
    half = size // 2

    def key(i, k):
        u = unit("ripple", (i + 40) // 6, k)
        if u < 0.07 and unit("ripple-row", k // 3) < 0.6:
            return "water_light"
        return "water"
    return _tile("water_tile", key, size=size, depth=2, node="water")


def quay():
    """The river's stone edge, 2 m along x: a wall of grey blocks from 2.4 m
    under the ground to a light kerb cap 0.1 m above it, a darker plinth
    course at the waterline (water at about y = -2); the water side is -z
    (the wall face at z = 0), the land side +z."""
    a = Asset("quay")
    g = new()
    for i in range(-TILE // 2, TILE // 2):
        for k in range(0, 6):
            for j in range(-24, 1):
                key = "kerb" if j == 0 else "stone"
                g.put(i, j, k, key)
        for j in range(-24, -18):
            g.put(i, j, -1, "stone_dark")
    g.vary({"stone"}, block=(5, 4, 6), light=0.3, dark=0.3, seed="quay")
    a.part("wall", g)
    return a


def bridge_span():
    """A 4 m length of the bridge along x, 4 m wide: a grey deck (top at
    y = 0) with an asphalt carriageway, raised pavements, light parapets
    with posts every metre, and a darker beam underneath."""
    a = Asset("bridge_span")
    g = new()
    half = m(2.0)
    for i in range(-half, half):
        for k in range(-half, half):
            edge = abs(k + 0.5) > 15
            for j in range(-6, 0):
                g.put(i, j, k, "stone")
            if edge:
                g.put(i, 0, k, "paving")
            else:
                g.put(i, -1, k, "asphalt")
            if abs(k + 0.5) > 18:
                top = 10 if i % 10 in (0, 1) else 8
                for j in range(1, top):
                    g.put(i, j, k, "kerb" if i % 10 in (0, 1) else "white")
        for k in range(-16, 16):
            for j in range(-9, -6):
                g.put(i, j, k, "stone_dark")
    g.vary({"stone"}, block=(10, 3, 40), light=0.25, dark=0.25, seed="bridge")
    a.part("span", g)
    return a


def bridge_pier():
    """A pier under the deck, 1.2 m along the bridge and 3.8 m across,
    from the deck's underside (y = -0.9) down to y = -5; stepped
    cutwaters, a darker cap and base."""
    a = Asset("bridge_pier")
    g = new()
    for j in range(-50, -9):
        for i in range(-6, 6):
            for k in range(-19, 19):
                taper = abs(k + 0.5) - 15
                if taper > 0 and abs(i + 0.5) > 6 - taper * 1.5:
                    continue
                key = "stone_dark" if j >= -11 or j < -44 else "stone"
                g.put(i, j, k, key)
    g.vary({"stone"}, block=(4, 5, 6), light=0.3, dark=0.3, seed="pier")
    a.part("pier", g)
    return a


def tram_track():
    """A 2 m length of track along x on a grey bed 2.8 m wide: dark
    sleepers every 0.5 m and two steel rails at standard gauge."""
    a = Asset("tram_track")
    g = new()
    for i in range(-TILE // 2, TILE // 2):
        for k in range(-14, 14):
            g.put(i, -1, k, "paving_dark" if abs(k + 0.5) > 12 else "stone")
            if i % 5 in (0, 1) and abs(k + 0.5) < 10:
                g.put(i, 0, k, "charcoal")
        for k in (-8, 7):
            g.put(i, 0, k, "rail")
            g.put(i, 1, k, "rail")
    a.part("track", g)
    return a


# ---- Tram ----

# The tram on the shared layout (tools/styles/shared/tram_layout.py): 20.5 m
# long, its doors at 20, 50 and 80% of it on both sides. Cells are 10 cm,
# so it is built on cells i = -103..101 and its parts shifted 5 cm along x
# (TRAM_SHIFT), centring it: cell edge i lies at x = i / 10 + 0.05 m.
TRAM_SHIFT = 0.05
TRAM_W = 12          # half width in cells (2.4 m wide)
TRAM_CARS = [(-103, -33, -1), (-29, 28, 0), (32, 102, 1)]   # cell edges, cab end
TRAM_CAB = 8
TRAM_SILL, TRAM_HEAD, TRAM_ROOF = 13, 25, 26                 # cells up
TRAM_FLOOR = tram_layout.FLOOR_CM // 10                      # the floor's top, cells
TRAM_GANGWAY = 8


def _cell(x):
    """The cell edge nearest x metres along the tram."""
    return int(round((x - TRAM_SHIFT) * 10))


# Each door's cell edges: 12 cells (1.2 m) about its middle, inside the
# layout's 1.3 m doorway.
TRAM_DOORS = [(_cell((a + b) / 2) - 6, _cell((a + b) / 2) + 6) for a, b in tram_layout.doors_m()]
# Windows between the doors and the cars' ends, in cell edges.
TRAM_WINDOWS = [(-93, -71), (-55, -36), (-26, -9), (8, 25), (35, 53), (69, 92)]


def _tram_body(g, roof):
    """The cars' sides, ends and cabs in `g`, their roofs in `roof`: a cream
    body over a charcoal sill and an orange band, glass in the windows,
    open doorways framed in orange, open joint ends for the gangway."""
    doors = TRAM_DOORS
    for i0, i1, cab in TRAM_CARS:
        for i in range(i0, i1):
            tip = min(i1 - 1 - i if cab > 0 else 99, i - i0 if cab < 0 else 99)
            in_cab = tip < TRAM_CAB
            for k in range(-TRAM_W, TRAM_W):
                # Round the cab's corners in plan.
                if in_cab and abs(k + 0.5) > TRAM_W - 1 - max(0, 3 - tip):
                    continue
                side = k in (-TRAM_W, TRAM_W - 1) or (in_cab and abs(k + 0.5) >= TRAM_W - 1 - max(0, 3 - tip) - 1)
                end = (i == i0 and cab >= 0) or (i == i1 - 1 and cab <= 0)
                nose = in_cab and tip == 0
                if not (side or end or nose):
                    continue
                door = side and not in_cab and any(a <= i < b for a, b in doors)
                window = side and not in_cab and any(a <= i < b for a, b in TRAM_WINDOWS)
                jamb = side and any(i in (a - 1, b) for a, b in doors)
                gangway = end and abs(k + 0.5) < TRAM_GANGWAY
                for j in range(3, TRAM_ROOF):
                    if j < 5:
                        key = "charcoal"
                    elif j < 10:
                        key = "orange"
                    elif nose and TRAM_SILL - 1 <= j < TRAM_HEAD:
                        key = "glass_dark"
                    elif window and TRAM_SILL <= j < TRAM_HEAD:
                        key = "glass_dark"
                    else:
                        key = "cream"
                    if door and j >= TRAM_FLOOR:
                        continue
                    if gangway and TRAM_FLOOR <= j < 22:
                        continue
                    if jamb and j >= 5:
                        key = "orange"
                    g.put(i, j, k, key)
                # The roof's rim over the walls.
                for j in range(TRAM_ROOF, 32):
                    roof.put(i, j, k, "orange" if j == 27 and side else "cream")
        # The roof over the car, with its equipment.
        roof.box(i0, 32, -TRAM_W, i1, 33, TRAM_W, "cream")
        mid = (i0 + i1) // 2
        roof.box(mid - 8, 33, -6, mid + 8, 35, 6, "kerb")
        # Headlights, and a destination board over the windscreen.
        if cab:
            tip_i = i1 - 1 if cab > 0 else i0
            for k in (-8, -7, 6, 7):
                g.put(tip_i, 7, k, "lamp_glow")
            roof.box(min(tip_i, tip_i - 2 * cab), 27, -5, max(tip_i, tip_i - 2 * cab) + 1, 30, 5, "navy")
        # Bogies and wheels, under the floor.
        for c in (i0 + 12, i1 - 12):
            g.box(c - 6, 0, -TRAM_W + 2, c + 6, 3, TRAM_W - 2, "charcoal")
    # Bellows between the cars: their sides and roof.
    for (_, a, _), (b, _, _) in zip(TRAM_CARS, TRAM_CARS[1:]):
        for k0 in (-TRAM_W + 1, TRAM_W - 3):
            g.box(a, 5, k0, b, TRAM_ROOF, k0 + 2, "charcoal")
        roof.box(a, TRAM_ROOF, -TRAM_W + 1, b, 31, TRAM_W - 1, "charcoal")
    # The pantograph on the middle car.
    for j in range(35, 44):
        off = abs(39 - j) // 2
        roof.put(-2 - off, j, 0, "charcoal")
        roof.put(1 + off, j, 0, "charcoal")
    roof.box(-1, 44, -8, 1, 45, 8, "charcoal")


def _tram_interior(g):
    """The floor, a seat under every seated slot facing +x (a cushion
    whose top is the layout's seat height, rounded to the cell, and a
    backrest), and poles in the standing room by each door."""
    for i0, i1, cab in TRAM_CARS:
        a = i0 + (3 if cab < 0 else 1)
        b = i1 - (3 if cab > 0 else 1)
        g.box(a, TRAM_FLOOR - 1, -TRAM_W + 1, b, TRAM_FLOOR, TRAM_W - 1, "stone_dark")
    for (_, a, _), (b, _, _) in zip(TRAM_CARS, TRAM_CARS[1:]):
        g.box(a, TRAM_FLOOR - 1, -TRAM_GANGWAY, b, TRAM_FLOOR, TRAM_GANGWAY, "stone_dark")
    top = TRAM_FLOOR + (tram_layout.SEAT_CM + 5) // 10
    for x, y in tram_layout.seats_m():
        i = _cell(x)
        k0, k1 = (-9, -2) if y > 0 else (2, 9)
        g.box(i - 2, top - 1, k0, i + 2, top, k1, "orange")
        g.box(i - 3, top, k0, i - 2, top + 5, k1, "orange")
        g.box(i - 1, TRAM_FLOOR, (k0 + k1) // 2, i, top - 1, (k0 + k1) // 2 + 1, "charcoal")
    for a, b in TRAM_DOORS:
        mid = (a + b) // 2
        for d in (-5, 5):
            g.box(mid + d, TRAM_FLOOR, 0, mid + d + 1, TRAM_HEAD, 1, "steel")


def _tram_door(g, a, b, k):
    """A door leaf over cells a <= i < b, one cell outside the wall at k: an
    orange frame round glass above a solid kick panel."""
    for i in range(a, b):
        for j in range(TRAM_FLOOR, TRAM_HEAD):
            edge = i in (a, b - 1) or j in (TRAM_FLOOR, TRAM_HEAD - 1) or j < 9
            g.put(i, j, k, "orange" if edge else "glass_dark")


def tram():
    """Three cars along +x on the shared tram layout, cab at each end:
    cream over an orange band, windows you see the riders through, doors
    that slide open, a seat under every seated slot and ceiling lights.
    Nodes: body, roof, interior, lights and the door leaves
    (door_<left|right>_<k>_<fore|aft>)."""
    tram_layout.write()
    a = Asset("tram")
    shift = (TRAM_SHIFT, 0.0, 0.0)
    body, roof, inside, lights = new(), new(), new(), new()
    _tram_body(body, roof)
    _tram_interior(inside)
    for i0, i1, cab in TRAM_CARS:
        lights.box(i0 + (10 if cab < 0 else 5), TRAM_HEAD - 1, -1, i1 - (10 if cab > 0 else 5), TRAM_HEAD, 1,
                   "window_glow")
    a.part("body", body, shift)
    a.part("roof", roof, shift)
    a.part("interior", inside, shift)
    a.part("lights", lights, shift)
    for n, (d0, d1) in enumerate(TRAM_DOORS):
        mid = (d0 + d1) // 2
        for side, k in (("left", -TRAM_W - 1), ("right", TRAM_W)):
            for leaf, (i0, i1) in (("fore", (mid, d1)), ("aft", (d0, mid))):
                g = new()
                _tram_door(g, i0, i1, k)
                a.part(f"door_{side}_{n}_{leaf}", g, shift)
    return a


def tram_shelter():
    """A 4.4 m shelter open toward -z (the pack turns it to face its stand):
    charcoal posts along a glass back wall, a wooden bench along it, a
    timetable at the bench's open end and a glass end screen at the other,
    under a white roof with an orange fascia lettered TRAM. Where people
    walk it is laid out as the other kits' stops are, to the tram-shelter
    kind's footprint once the pack fits it there: the back 0.75 m behind
    the point, the bench to 0.15 m, the end screen's post to 0.40 m, the
    front open to the stand."""
    a = Asset("tram_shelter")
    g = new()

    def box(x0, x1, j0, j1, z0, z1, key):
        # Laid out in the kind's frame (x across, z toward the stand, in
        # cells), which is this piece's turned half a turn.
        g.box(-x1, j0, -z1, -x0, j1, -z0, key)

    for x in (-22, 0, 21):
        box(x, x + 1, 0, 27, -8, -6, "charcoal")
    for x in range(-21, 21):
        if x == 0:
            continue
        for j in range(2, 25):
            box(x, x + 1, j, j + 1, -8, -7, "steel" if j in (2, 24) or x % 9 == 0 else "glass_light")
    # The end screen, glass in a steel frame, and its post at the front.
    for z in range(-6, 3):
        for j in range(2, 25):
            box(21, 22, j, j + 1, z, z + 1, "steel" if j in (2, 24) else "glass_light")
    box(21, 22, 0, 27, 3, 4, "charcoal")
    # The bench along the back, seat top 0.5 m, a backrest on the glass.
    box(-7, 18, 4, 5, -6, -2, "wood")
    box(-7, 18, 5, 8, -7, -6, "wood_dark")
    for x in (-6, 16):
        box(x, x + 1, 0, 4, -5, -3, "charcoal")
    # The timetable on the glass at the bench's open end.
    box(-19, -12, 3, 18, -7, -6, "navy")
    box(-18, -13, 8, 16, -7, -6, "white")
    # The roof and its fascia over the front.
    box(-23, 23, 27, 29, -9, 5, "white")
    box(-23, 23, 24, 33, 5, 6, "orange")
    text(g, "TRAM", 25, -7, "white")
    a.part("shelter", g)
    return a


# ---- Town blocks ----

def _facade(g, i0, k0, i1, k1, j0, j1, wall, paint):
    """A hollow box two voxels thick; `paint(side, a, j, width)` returns
    the key of the outer layer on `side` ("n" is the front, -z; "s", "e",
    "w"), `a` along it and j - j0 above its base: a key, None for a
    recessed window (the inner layer becomes `glass`), or "" for an
    opening."""
    for i in range(i0, i1):
        for k in range(k0, k1):
            d = min(i - i0, i1 - 1 - i, k - k0, k1 - 1 - k)
            if d > 1:
                continue
            if k - k0 == d:
                side, a, width = "n", i - i0, i1 - i0
            elif k1 - 1 - k == d:
                side, a, width = "s", i - i0, i1 - i0
            elif i - i0 == d:
                side, a, width = "w", k - k0, k1 - k0
            else:
                side, a, width = "e", k - k0, k1 - k0
            for j in range(j0, j1):
                key = paint(side, a, j - j0, width)
                if key == "":
                    continue
                if key is None:
                    key = "glass" if d == 1 else None
                    if key is None:
                        continue
                else:
                    key = key if d == 0 else wall
                g.put(i, j, k, key)


def _roof(g, i0, k0, i1, k1, j, surface, parapet):
    for i in range(i0, i1):
        for k in range(k0, k1):
            edge = i in (i0, i1 - 1) or k in (k0, k1 - 1)
            g.put(i, j, k, parapet if edge else surface)
            if edge:
                g.put(i, j + 1, k, parapet)
                g.put(i, j + 2, k, parapet)


def _greens(g, i0, k0, i1, k1, j, seed, trees=0):
    """Rooftop greenery: a planter ring of bush blocks inside a parapet,
    and blocky trees in up to four corners (on a setback's terrace ring)."""
    for i in range(i0, i1, 3):
        for k in range(k0, k1):
            if not (i - i0 < 9 or i1 - i <= 9 or k - k0 < 9 or k1 - k <= 9):
                continue
            if unit(seed, i // 3, k // 3) < 0.75:
                h = 2 + int(unit(seed, "h", i // 3, k // 3) * 3)
                key = "leaf" if unit(seed, "c", i // 3, k // 3) < 0.6 else "leaf_dark"
                g.box(i, j, (k // 3) * 3, i + 3, j + h, (k // 3) * 3 + 3, key)
    corners = ((i0 + 8, k0 + 8), (i1 - 8, k1 - 8), (i1 - 8, k0 + 8), (i0 + 8, k1 - 8))
    for n in range(trees):
        ci, ck = corners[n % 4]
        g.box(ci - 1, j, ck - 1, ci + 1, j + 8, ck + 1, "trunk")
        canopy(g, [(ci, j + 13, ck, 7, 6, 7)], 3, ("leaf_dark", "leaf", "leaf_light"), f"{seed}{n}")


def house_a():
    """A two-storey white house, 6 m square, 6.8 m to the parapet: blue
    windows, a door on the front (-z), a blue roof with a parapet and a
    rooftop box and planter."""
    return _house("house_a", "white", "blue", 2)


def house_b():
    """A three-storey cream house with an orange roof."""
    return _house("house_b", "cream", "orange", 3)


def _house(name, wall, roof, storeys):
    a = Asset(name)
    g = new()
    s = 30
    top = storeys * s + 2

    def paint(side, a_, j, width):
        if j < 3:
            return "stone"
        storey, z = divmod(j, s)
        if a_ in (0, 1, width - 2, width - 1):
            return wall
        if side == "n" and storey == 0 and 25 <= a_ < 35 and 3 <= j < 23:
            return ""
        bay = (a_ - 2) % 14
        if 3 <= bay < 11 and 9 <= z < 22:
            return None
        if 3 <= bay < 11 and z == 8:
            return "kerb"
        return wall
    _facade(g, -30, -30, 30, 30, 0, top, wall, paint)
    _roof(g, -30, -30, 30, 30, top, roof, wall)
    g.box(8, top + 1, 6, 18, top + 5, 14, "steel")
    g.box(-22, top + 1, -22, -14, top + 3, -14, "soil")
    canopy(g, [(-18, top + 5, -18, 5, 3, 5)], 2, ("leaf_dark", "leaf", "leaf_light"), name)
    g.vary({wall}, block=(5, 5, 5), light=0.2, dark=0.2, seed=name)
    a.part("house", g)
    return a


def shop_a():
    """A two-storey cream shop, 6 m square: a glazed shopfront with a door
    under an orange-and-white awning on the front (-z), windows above, an
    orange roof."""
    a = Asset("shop_a")
    g = new()
    top = 62

    def paint(side, a_, j, width):
        if j < 3:
            return "stone"
        if a_ in (0, 1, width - 2, width - 1) or 26 <= j < 30:
            return "cream"
        if j < 26:
            return None if side == "n" else ("cream" if (a_ - 2) % 14 < 3 or j < 8 else None)
        bay = (a_ - 2) % 14
        if 3 <= bay < 11 and 38 <= j < 52:
            return None
        return "cream"
    _facade(g, -30, -30, 30, 30, 0, top, "cream", paint)
    # The front's ground floor: a door between two big panes.
    for i in range(-28, 28):
        for j in range(3, 26):
            door = -5 <= i < 5 and j < 23
            if door:
                g.erase(i, j, -30)
                g.erase(i, j, -29)
            elif i in (-6, 5) or j == 25:
                g.put(i, j, -30, "charcoal")
    for i in range(-30, 30):
        for n in range(8):
            j = 29 - n // 2
            g.put(i, j, -31 - n, "orange" if (i // 5) % 2 == 0 else "white")
    _roof(g, -30, -30, 30, 30, top, "orange", "cream")
    g.box(-20, top + 1, 4, -10, top + 4, 14, "steel")
    g.vary({"cream"}, block=(5, 5, 5), light=0.2, dark=0.2, seed="shop_a")
    a.part("shop", g)
    return a


def _tower_volume(g, half, j0, j1, base_orange):
    """A white frame with blue glass: 2 m bays, 3 m storeys, white
    spandrels and pilasters; the first storey orange with shopfronts when
    `base_orange`."""
    def paint(side, a_, j, width):
        storey, z = divmod(j, 30)
        if a_ < 4 or a_ >= width - 4:
            return "white"
        if base_orange and storey == 0:
            if z < 2:
                return "stone"
            return None if 4 <= (a_ % 20) < 18 and z < 26 else "orange"
        if a_ % 20 in (0, 1, 2, 19) or z < 9:
            return "white"
        return None
    _facade(g, -half, -half, half, half, j0, j1, "white", paint)


def tower_a():
    """A stepped tower: 14 m square to 19.5 m (an orange ground storey and
    five white-and-blue storeys), a 10 m square top of two storeys, green
    terraces with bushes and blocky trees on both roofs."""
    a = Asset("tower_a")
    g = new()
    _tower_volume(g, 70, 0, 180, True)
    _roof(g, -70, -70, 70, 70, 180, "paving_dark", "white")
    _greens(g, -68, -68, 68, 68, 181, "tower_a", trees=4)
    _tower_volume(g, 50, 183, 243, False)
    _roof(g, -50, -50, 50, 50, 243, "lawn", "white")
    _greens(g, -48, -48, 48, 48, 244, "tower_a_top", trees=3)
    g.box(-50, 181, -50, 50, 183, 50, "white")
    a.part("tower", g)
    return a


def tower_b():
    """A taller, slimmer stepped tower: 13 m square to 15 m, 9 m to 24 m,
    a 5 m crown to 27 m, with terraces planted at every step."""
    a = Asset("tower_b")
    g = new()
    _tower_volume(g, 64, 0, 150, True)
    _roof(g, -64, -64, 64, 64, 150, "lawn", "white")
    _greens(g, -62, -62, 62, 62, 151, "tower_b", trees=2)
    _tower_volume(g, 46, 153, 243, False)
    g.box(-46, 151, -46, 46, 153, 46, "white")
    _roof(g, -46, -46, 46, 46, 243, "paving_dark", "white")
    _greens(g, -44, -44, 44, 44, 244, "tower_b_mid", trees=3)
    g.box(-26, 244, -26, 26, 270, 26, "white")
    for i in range(-24, 24):
        for j in range(248, 266):
            for (x, z) in ((i, -26), (i, 25), (-26, i), (25, i)):
                if (i + 24) % 8 not in (0, 7):
                    g.put(x, j, z, "glass")
    _roof(g, -26, -26, 26, 26, 270, "lawn", "white")
    _greens(g, -24, -24, 24, 24, 271, "tower_b_top", trees=1)
    a.part("tower", g)
    return a


ASSETS = {f.__name__: f for f in (
    paving_a, paving_b, paving_c, lawn_tile, street_tile, street_dash, crosswalk, kerb,
    water_tile, quay, bridge_span, bridge_pier, tram_track, tram, tram_shelter,
    house_a, house_b, shop_a, tower_a, tower_b,
)}
