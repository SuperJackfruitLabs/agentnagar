#!/usr/bin/env python3
"""Writes the district fixture: manifest.json and the scripted story feed.

Run with no arguments to regenerate, or with --check to confirm the committed
files match what this script produces. Standard library only; regenerating
then has the core validate the manifest (`cargo run -p city-cli -- validate`).
Everything written here is a labelled fixture, not real agent state.
"""
import json
import math
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CITY = HERE.parent.parent
CATALOGUE = json.loads((CITY / "catalogue" / "catalogue.json").read_text(encoding="utf-8"))
KINDS = {k["id"]: k for k in CATALOGUE["kinds"]}
# The core's body clearance: a cell whose centre lies within this of a
# footprint is blocked.
MARGIN = 10


def door(id_, to, x, z):
    return {"id": id_, "to": to, "pos": {"x": x, "z": z}, "transit": {"min": 1, "max": 1}}


def seat(id_, x, z, facing, kind, pod=None, reserved_for=None):
    s = {"id": id_, "pos": {"x": x, "z": z}, "facing": facing, "kind": kind}
    if pod:
        s["pod"] = pod
    if reserved_for:
        s["reserved_for"] = reserved_for
    return s


def rect(x, z, w, d):
    return {"x": x, "z": z, "w": w, "d": d}


def place(slug, kind, x, z, facing=0, size=None, panel=None):
    """A placement of a catalogue kind: the only solid things there are.
    Its point must lie on the kind's snap. A display names the sample
    panel file it shows (`panel`, under panels/)."""
    snap = KINDS[kind]["snap"]
    assert x % snap == 0 and z % snap == 0, f"{slug} at ({x}, {z}) is off the {snap} cm snap"
    p = {"id": f"placement:{slug}", "kind": kind, "at": {"x": x, "z": z}}
    if facing:
        p["facing"] = facing
    if size:
        p["size"] = {"w": size[0], "d": size[1]}
    if panel:
        assert panel in PANELS and p["id"] in PANELS[panel], f"{p['id']} has no panel in {panel}"
        p["binding"] = {"source": "sample", "ref": f"panels/{panel}"}
    return p


def snap(v, step):
    """`v` to the nearest multiple of `step`, halves rounding up."""
    return (v + step // 2) // step * step


def centred(v):
    """The centre of the 25 cm cell holding `v` (its corner plus 12 cm),
    where the core seats a sitter: a bench's point there puts the sitter
    where the bench is drawn round them."""
    return v // 25 * 25 + 12


def turned(x, z, facing):
    """A point of a kind's own frame turned to `facing`, a right angle, the
    way the core turns it (footprint.rs `from_local`)."""
    return {0: (x, z), 90: (-z, x), 180: (-x, -z), 270: (z, -x)}[facing % 360]


def bounds(p, anchors=True):
    """The box a placement's footprint (and, unless told not to, its
    standing anchors) takes, in world centimetres, as (x0, z0, x1, z1):
    what later things keep clear of."""
    kind = KINDS[p["kind"]]
    ax, az, facing = p["at"]["x"], p["at"]["z"], p.get("facing", 0)
    if facing % 90:
        # Only a kind that is a disc round its point (a lamp facing the
        # square's tree) turns off a right angle, and turning leaves it be.
        assert all("r" in s and s["x"] == s["z"] == 0 for s in kind["footprint"]) \
            and not kind.get("anchors"), f"{p['id']} turns {facing} degrees"
        facing = 0
    if "size" in p:
        w, d = p["size"]["w"], p["size"]["d"]
        return (ax - w // 2, az - d // 2, ax + w // 2, az + d // 2)
    corners = []
    for s in kind["footprint"]:
        if "r" in s:
            corners += [(s["x"] - s["r"], s["z"] - s["r"]), (s["x"] + s["r"], s["z"] + s["r"])]
        else:
            corners += [(s["x"], s["z"]), (s["x"] + s["w"], s["z"] + s["d"])]
    # A standing anchor keeps a cell clear round it.
    for a in kind.get("anchors", []) if anchors else []:
        corners += [(a["at"]["x"] - 25, a["at"]["z"] - 25), (a["at"]["x"] + 25, a["at"]["z"] + 25)]
    if not corners:
        return None
    pts = [turned(x, z, facing) for x, z in corners]
    return (ax + min(x for x, _ in pts), az + min(z for _, z in pts),
            ax + max(x for x, _ in pts), az + max(z for _, z in pts))


def overlaps(a, b, gap=0):
    return a[0] < b[2] + gap and b[0] < a[2] + gap and a[1] < b[3] + gap and b[1] < a[3] + gap


def blocked_cells(r):
    """The 25 cm cells (by their corner) whose centre, at the corner plus
    12 cm, lies inside rect `r`: what a schema 1 obstacle blocked."""
    return {(x, z)
            for x in range(r["x"] // 25 * 25 - 25, r["x"] + r["w"] + 25, 25)
            for z in range(r["z"] // 25 * 25 - 25, r["z"] + r["d"] + 25, 25)
            if r["x"] <= x + 12 < r["x"] + r["w"] and r["z"] <= z + 12 < r["z"] + r["d"]}


def replaces(p, obstacle):
    """Asserts that placement `p` blocks every cell the schema 1 `obstacle`
    blocked: its footprint (at a right angle) covers them."""
    x0, z0, x1, z1 = bounds(p, anchors=False)
    for x, z in blocked_cells(obstacle):
        cx, cz = x + 12, z + 12
        assert x0 - MARGIN <= cx < x1 + MARGIN and z0 - MARGIN <= cz < z1 + MARGIN, \
            f"{p['id']} leaves ({cx}, {cz}) of {obstacle} open"
    return p


def room(id_, name, template, r, capacity, doors, seats=(), outdoor=False, overflow=None,
         pods=None):
    out = {"id": id_, "name": name, "capacity": capacity, "template": template, "rect": r,
           "doors": list(doors), "seats": list(seats)}
    if outdoor:
        out["outdoor"] = True
    if overflow:
        out["overflow"] = overflow
    if pods:
        out["pods"] = pods
    return out


def pair(a, b, x, z, n=None):
    """Doors both ways between rooms a and b at (x, z); `n` numbers extra doors."""
    suffix = "" if n is None else f"-{n}"
    return (door(f"door:{a}-{b}{suffix}", f"room:{b}", x, z),
            door(f"door:{b}-{a}{suffix}", f"room:{a}", x, z))


# The composition every style sheet shares: a tree square in the middle, the
# sawtooth Guild hall to its west with a café terrace beside it, the domed
# library to its east, a park to the south-west and the tram stop along the
# south; the river and bridge beyond the park, downtown to the north.
WP, PW = pair("workshop", "plaza", -1800, -600)
CP, PC = pair("commons", "plaza", -1800, 600)
WC, CW = pair("workshop", "commons", -2600, 200)
TP_CAFE, P_TCAFE = pair("cafe-terrace", "plaza", -1800, 1200)
TK, KT = pair("cafe-terrace", "park", -2600, 1600)
RP, PR = pair("reading", "plaza", 1800, -200)
KS, SK = pair("park", "tram-stop", -1800, 1700)
TRAM = [pair("tram-stop", "plaza", x, 1400, n) for n, x in enumerate((-600, 0, 600), 1)]
# The Square stop's south platform opens onto the lane south of it, and the
# Avenue stop's platforms onto the avenue to the north and its far end to
# the south: every platform can be left without crossing the tracks.
TRAM_SOUTH = [pair("tram-stop-south", "south-lane", x, 2600, n) for n, x in enumerate((-600, 0, 600), 1)]
AVENUE_NORTH = [pair("avenue-stop-north", "avenue", x, 1500, n) for n, x in enumerate((5400, 5700), 1)]
AVENUE_SOUTH = [pair("avenue-stop-south", "avenue-end", x, 2600, n) for n, x in enumerate((5400, 5700), 1)]

# The boulevard tram: a centreline at z = 20.5 m from the tram street's west
# edge to the district's east edge, the eastbound track 1.5 m north of it and
# the westbound 1.5 m south: 3 m apart, so the kits' trams (2.47 m wide)
# pass each other clear. Its two stops: the Square, centred south of the
# square at x = 0, and the Avenue, near the east end.
LINE_Z = 2050
LINE_WEST, LINE_EAST = -1800, 6800
TRACKS = [-150, 150]
SQUARE_X, AVENUE_X = 0, 5750
# The tram's length is the 3D kits' tram model, 20.6 m long in every kit that
# ships a tram.glb (anime, lowpoly, neon, solarpunk: three sections along x
# from -10.3 to +10.3 m), rounded to the nearest 50 cm. Its doors sit at
# 20%, 50% and 80% of it, from the front.
TRAM_LENGTH = 2050
TRAM_DOORS = [TRAM_LENGTH * k // 10 for k in (2, 5, 8)]


# Each room below returns itself and the placements standing in it: in
# schema 2 they are all that is solid. Where a placement took the place of
# a schema 1 obstacle, `replaces` checks it blocks the same cells; where it
# does not, the comment says what opened. Things moved onto their kind's
# snap say so where they stand.


def workshop():
    seats, placements = [], []
    n = 0
    for z, pod in ((-1000, "pod:making-1"), (-500, "pod:making-2")):
        for x in (-3050, -2750, -2450, -2150):
            n += 1
            # Each desk is a workstation, a hot desk (bound to no station).
            seats.append(seat(f"seat:w{n}", x, z, 0, "workstation", pod,
                              "agent:kai" if n == 1 else None))
            # The desk's own footprint blocks what its obstacle did.
            replaces(place("desk", "workstation", x, z), rect(x - 50, z - 80, 100, 60))
    # The workbench moved 10 cm south (z -160 to -150), onto its 25 cm snap,
    # and its footprint is its old obstacle's.
    placements.append(replaces(place("workbench", "workbench", -2750, -150),
                               rect(-3250, -210, 1000, 120)))
    return room("room:workshop", "Workshop", "workshop", rect(-3400, -1400, 1600, 1600), 8,
                [WP, WC], seats, overflow="room:commons",
                pods=[{"id": "pod:making-1", "department": "making"},
                      {"id": "pod:making-2", "department": "making"}]), placements


def commons():
    seats = [seat(f"seat:c{n + 1}", centred(x), centred(z), 90, "bench")
             for n, (x, z) in enumerate([(-3100, 450), (-3100, 750), (-2500, 450), (-2500, 750)])]
    # The bookshelf moved 5 cm east (x -3330 to -3325), onto its snap.
    return (room("room:commons", "Commons", "commons", rect(-3400, 200, 1600, 800), 4,
                 [CP, CW], seats),
            [place("commons-bookshelf", "bookshelf", -3325, 600, 90)])


def cafe_terrace():
    seats, placements = [], []
    n = 0
    # The tables and their chairs moved 5 cm north (z 1180 and 1430 to 1175
    # and 1425), onto the tables' snap.
    for t, (cx, cz) in enumerate(((-3050, 1175), (-2450, 1175), (-3050, 1425), (-2450, 1425)), 1):
        placements += [replaces(place(f"cafe-table-{t}", "cafe-table-top", cx, cz),
                                rect(cx - 40, cz - 40, 80, 80)),
                       place(f"cafe-umbrella-{t}", "umbrella", cx, cz)]
        for dx, facing in ((-70, 90), (70, 270)):
            n += 1
            seats.append(seat(f"seat:f{n}", cx + dx, cz, facing, "cafe-table"))
    return room("room:cafe-terrace", "Café terrace", "cafe-terrace", rect(-3400, 1000, 1600, 600),
                10, [TP_CAFE, TK], seats, outdoor=True, overflow="room:plaza"), placements


def reading_room():
    seats = []
    n = 0
    for z in (-800, -300, 300):
        for x in (2300, 2700, 3100):
            if n < 8:
                n += 1
                seats.append(seat(f"seat:r{n}", x, z, 90, "reading-chair"))
    # Two public hot desks against the south wall, facing it, clear of the
    # chairs and the kiosk, with room behind each chair to look over a
    # shoulder. The room's capacity stays 8: seats may outnumber it, as on
    # the café terrace. Their IDs sort after every chair's (`w` after the
    # digits), so the seat policy, which takes the lowest free ID, fills
    # the chairs first and leaves the desks to whoever chooses one.
    for k, x in enumerate((2500, 2900), 1):
        seats.append(seat(f"seat:rw{k}", x, 600, 180, "workstation"))
    # The shelves moved 5 cm west (x 3530 to 3525), onto their snap. The
    # schema 1 obstacle ran the whole 16 m along them; the floor between
    # the three shelves is open now. Their spines are the vision's
    # documents. The kiosk stands by the door, its screen facing east
    # into the room.
    shelves = [(k, 3525, z) for k, z in enumerate((-700, -100, 500), 1)]
    return (room("room:reading", "Reading room", "reading-room", rect(1800, -1200, 1800, 2000), 8,
                 [RP], seats),
            [place(f"reading-shelf-{k}", "bookshelf", x, z, 270, panel="library-shelves.json")
             for k, x, z in shelves]
            + [place("library-kiosk", "kiosk", 2000, 450, 90)])


def core_covers(kind, at, facing, p, margin=MARGIN):
    """Whether point `p` lies in `kind`'s footprint at `at`, turned to
    `facing`, grown by `margin`, as the core tests it (footprint.rs
    `covers`: the sine table scaled to 2^16, each product floored)."""
    sin = round(math.sin(math.radians(facing)) * 65536)
    cos = round(math.cos(math.radians(facing)) * 65536)
    dx, dz = p[0] - at[0], p[1] - at[1]
    x, z = (dx * cos + dz * sin) >> 16, (-dx * sin + dz * cos) >> 16
    for sh in KINDS[kind]["footprint"]:
        if "r" in sh:
            if (x - sh["x"]) ** 2 + (z - sh["z"]) ** 2 < (sh["r"] + margin) ** 2:
                return True
        elif sh["x"] - margin <= x < sh["x"] + sh["w"] + margin and sh["z"] - margin <= z < sh["z"] + sh["d"] + margin:
            return True
    return False


def seat_reachable(kind, at, facing, others=()):
    """Whether a seat's own furniture (and `others`, placements near it)
    leave a way into its cell: the core keeps the seat's cell open, and a
    walker must reach it from beyond, so the open cells from it must lead
    out of the furniture's reach (1.5 m). The grid's cells are 25 cm with
    their centres 12 cm past a corner on the 25 cm snap."""
    seat_cell = (at[0] // 25 * 25 + 12, at[1] // 25 * 25 + 12)
    open_ = lambda p: not core_covers(kind, at, facing, p) and not any(  # noqa: E731
        core_covers(o["kind"], (o["at"]["x"], o["at"]["z"]), o.get("facing", 0), p) for o in others)
    seen, frontier = {seat_cell}, [seat_cell]
    while frontier:
        c = frontier.pop()
        for q in ((c[0] + 25, c[1]), (c[0] - 25, c[1]), (c[0], c[1] + 25), (c[0], c[1] - 25)):
            if q in seen or not open_(q):
                continue
            if math.dist(q, at) > 150:
                return True
            seen.add(q)
            frontier.append(q)
    return False


def outline_margin(kind, at, facing, drawn_at=None):
    """How well the cells round a seat at `at`, turned to `facing`, agree
    with its outline drawn at `drawn_at` (where a style draws it; `at`
    unless it says): the least, over the cells, of how far (cm) a cell lies
    on its right side of the clearance, negative where one lies on the
    wrong side. The core blocks every cell whose centre lies within the
    clearance of the footprint's rectangles, grown square; off the right
    angles a style draws the outline itself, with the seat across the
    square the sitter keeps (25 cm about the seat). So a blocked cell in a
    grown corner more than the clearance from the outline looks open, and
    an open cell in front of the seat can come within it. Cells in the
    square are left out."""
    drawn_at = drawn_at or at
    t = math.radians(facing)
    rects = [(sh["x"], sh["z"], sh["x"] + sh["w"], sh["z"] + sh["d"]) for sh in KINDS[kind]["footprint"]]
    margin = math.inf
    for i in range(-6, 7):
        for j in range(-6, 7):
            p = (at[0] // 25 * 25 + 12 + 25 * i, at[1] // 25 * 25 + 12 + 25 * j)
            ax, az = p[0] - at[0], p[1] - at[1]
            if max(abs(ax * math.cos(t) + az * math.sin(t)), abs(-ax * math.sin(t) + az * math.cos(t))) <= 25:
                continue
            dx, dz = p[0] - drawn_at[0], p[1] - drawn_at[1]
            x, z = dx * math.cos(t) + dz * math.sin(t), -dx * math.sin(t) + dz * math.cos(t)
            d = min(math.hypot(max(x0 - x, 0, x - x1), max(z0 - z, 0, z - z1)) for x0, z0, x1, z1 in rects)
            drawn = min(d, math.hypot(max(abs(x) - 25, 0), max(abs(z) - 25, 0)))
            margin = min(margin, MARGIN - d if core_covers(kind, at, facing, p) else drawn - MARGIN)
    return margin


def pixel_at(x, z):
    """Where the pixel style draws a sprite for ground point (x, z), in cm:
    it stands on a whole pixel, one metre east being 16 px across and 8
    down, so a point off the 12.5 cm lattice (whole centimetres: the 25 cm
    points) lands up to 5 cm away."""
    half_away = lambda v: math.floor(abs(v) + 0.5) * (1 if v >= 0 else -1)  # noqa: E731 (as Godot rounds)
    px, py = half_away((x - z) * 0.16), half_away((x + z) * 0.08)
    return ((px / 0.16 + py / 0.08) / 2, (py / 0.08 - px / 0.16) / 2)


def ring_point(ideal, facing, others, ring=450):
    """Where a ring bench stands, near `ideal` (its place on the ring,
    4.5 m out). Off the right angles the grid's cells fall anywhere against
    a footprint's edges, so a bench stands where they fall best: within
    15 cm of its place, on a whole centimetre whose own cell the bench (and
    `others` round it: the tree) leaves a way into, where the cells round
    it agree with its outline as the 3D styles draw it (on its point) and
    as the pixel style does (on the nearest pixel, up to 5 cm off: only the
    25 cm points are exact, and at every one of them some ring bench walls
    in its own cell or leaves a grown corner looking open) by the widest
    margin (`outline_margin`), counted in whole millimetres up to 1.5 cm,
    which is margin enough; then nearest its cell's centre, where the core
    seats the sitter; then nearest the ring, then nearest its place. A
    bench at a right angle stands on the centre of the cell at its 25 cm
    snap, where every style fits it to the cells
    (`CityGeometry.drawn_rect`) and the sitter sits on its point."""
    if facing % 90 == 0:
        return centred(snap(round(ideal[0]), 25)), centred(snap(round(ideal[1]), 25))
    best = None
    for x in range(round(ideal[0]) - 15, round(ideal[0]) + 16):
        for z in range(round(ideal[1]) - 15, round(ideal[1]) + 16):
            if not seat_reachable("bench", (x, z), facing, others):
                continue
            margin = min(outline_margin("bench", (x, z), facing), outline_margin("bench", (x, z), facing, pixel_at(x, z)))
            key = (-min(math.floor(margin * 10), 15), math.dist((x, z), (centred(x), centred(z))),
                   abs(math.hypot(x, z) - ring) + 0.1 * math.dist((x, z), ideal))
            if margin > 0.3 and (best is None or key < best[0]):
                best = (key, (x, z))
    assert best, f"no place for a ring bench near {ideal}"
    return best[1]


def plaza():
    tree = place("great-tree", "great-tree", 0, 0)
    seats = []
    for k in range(10):
        a = k * 2 * math.pi / 10
        facing = (k * 36 + 180) % 360
        x, z = ring_point((450 * math.sin(a), -450 * math.cos(a)), facing, [tree])
        seats.append(seat(f"seat:p{k + 1}", x, z, facing, "bench"))
    # The planters' centres moved 10 cm outward, onto their snap: (-1440,
    # -1040) to (-1450, -1050) and likewise at each corner.
    planters = [(-1450, -1050), (1450, -1050), (-1450, 1050), (1450, 1050)]
    planter_obstacles = [rect(-1500, -1100, 120, 120), rect(1380, -1100, 120, 120),
                         rect(-1500, 980, 120, 120), rect(1380, 980, 120, 120)]
    # Each bed's point moved 5 cm north (z -1220 to -1225), onto its snap.
    bed_points = [(-1100, -1225), (1100, -1225)]
    lamps = [(-900, -900), (900, -900), (-900, 900), (900, 900), (0, -1100), (0, 1100)]
    # The bollards moved 5 cm north (z 1330 to 1325), onto their snap, and
    # the two that stood in front of the tram stop's outer doors (x -600
    # and 600) are gone: solid now, they would stand in the way out.
    bollards = [x for x in range(-1500, 1501, 300) if all(abs(x - d) > 200 for d in (-600, 0, 600))]
    # The square's things to use: the noticeboard facing the tree from
    # beside the tram stop, where arrivals step off; the fountain in the
    # north-east quarter of the square, clear of every way across it; and
    # the guild hall's plaque against its east wall halfway between its two
    # doors (6 m from each, beyond where walks along the wall turn in),
    # facing the square.
    things = [place("square-noticeboard", "noticeboard", -1100, 1000, panel="square-notices.json"),
              place("square-fountain", "fountain-rim", 1000, -500),
              place("guild-hall-plaque", "plaque", -1750, 0, 90, panel="guild-hall.json")]
    placements = ([replaces(tree, rect(-200, -200, 400, 400))]
                  + [replaces(place(f"plaza-planter-{k}", "planter", x, z), o)
                     for k, ((x, z), o) in enumerate(zip(planters, planter_obstacles), 1)]
                  + [place(f"plaza-bed-{k}", "flowerbed", x, z) for k, (x, z) in enumerate(bed_points, 1)]
                  # The square's lamps face the tree they light round.
                  + [place(f"plaza-lamp-{k}", "street-lamp", x, z, bearing(-x, -z))
                     for k, (x, z) in enumerate(lamps, 1)]
                  + [place(f"plaza-bollard-{k:02}", "bollard", x, 1325)
                     for k, x in enumerate(bollards, 1)]
                  + things)
    # Each flowerbed blocks its bed, 3.1 by 1.1 m (every style draws its
    # kerb and flowers in the walking band, and people walk round it), in
    # place of the 6 by 1.6 m schema 1 obstacle along it.
    return room("room:plaza", "Tree square", "plaza", rect(-1800, -1400, 3600, 2800), 50,
                [PW, PC, P_TCAFE, PR] + [t[1] for t in TRAM], seats, outdoor=True), placements


# Where the tracks leave the district, north to south: the trams fade out
# over their last 10 m there, so the fence at the land's east edge opens
# for them, and the park keeps its palms and benches off their way west.
PORTAL_GAP = (1650, 2450)


def park():
    palms = [(-3200, 1800), (-2300, 1700), (-3100, 2400), (-2300, 2500), (-3150, 2850), (-2050, 2850)]
    # Bench k1 moved 50 cm west and 50 cm south (from (-2700, 1650)): its
    # measured footprint then, 1.9 m long, covered the terrace door's span.
    # Each bench's point is its cell's centre, where its sitter is seated.
    seats = [seat(f"seat:k{n + 1}", centred(x), centred(z), f, "bench")
             for n, (x, z, f) in enumerate([(-2750, 1700, 180), (-2700, 2650, 0),
                                            (-2000, 2650, 270), (-3300, 2100, 90)])]
    # The flowerbed's point moved 5 cm north (z 2380 to 2375), onto its snap;
    # it blocks its bed, as the plaza's beds, where its 3 by 1 m schema 1
    # obstacle stood. A palm takes only its trunk: its crown is above
    # the walking band, so the 60 cm square obstacle each palm stood in is
    # gone.
    # Two low walls to sit on, their sitters facing north over the lawn,
    # and three meadows of tall grass, all in the park's south half, off
    # the paths a pack lays from the doors to the centre and out of the
    # trams' way west (z 17.5–23.5 m east of x = -30 m).
    walls = [(-3000, 2650), (-2350, 2650)]
    meadows = [(-3250, 2550, 200, 150), (-2600, 2850, 300, 200), (-2250, 2900, 200, 150)]
    placements = ([place(f"park-palm-{k}", "palm", x, z) for k, (x, z) in enumerate(palms, 1)]
                  + [place("park-path", "path", -2600, 2300),
                     place("park-bed", "flowerbed", -2650, 2375)]
                  + [place(f"park-wall-{k}", "low-wall", x, z) for k, (x, z) in enumerate(walls, 1)]
                  + [place(f"park-meadow-{k}", "meadow", x, z, size=(w, d))
                     for k, (x, z, w, d) in enumerate(meadows, 1)])
    return room("room:park", "Park", "park", rect(-3400, 1600, 1600, 1400), 20, [KT, KS],
                seats, outdoor=True), placements


def library_garden():
    """The library garden's steps, against the library's south wall, sat
    on facing south over the garden."""
    return [place("library-steps", "steps", 2700, 925, 180)]


# Each platform's edge stands 1.5 m from its track's centre, clear of the
# kits' trams (2.47 m wide; the core's footprint is 2 m), and each holds far
# more than a full tram's 40 riders, so a tram's arrivals can always step
# off. Shelters face the track: north platforms south, south
# platforms north.
PLATFORM_CAPACITY = 60


def shelters(slug, spots):
    """A platform's shelters: each stands its `stand` anchor on the track
    side. The shelters stand 50 cm farther from their tracks than they did
    (z 1650 to 1600 on the north platforms, 2450 to 2500 on the south):
    their footprint (posts, back glass, bench and end screen) reaches 80 cm
    behind their point and their anchor 1.1 m in front, and there the
    anchor stays on the platform."""
    return [place(f"shelter-{slug}-{k}", "tram-shelter", x, z, f) for k, (x, z, f) in enumerate(spots, 1)]


def tram_stop():
    return (room("room:tram-stop", "Tram stop", "tram-stop", rect(-1800, 1400, 3600, 350),
                 PLATFORM_CAPACITY, [t[0] for t in TRAM] + [SK], outdoor=True),
            shelters("square-north", [(-1200, 1600, 0), (1200, 1600, 0)]))


def tram_stop_south():
    return (room("room:tram-stop-south", "Tram stop, south platform", "tram-stop",
                 rect(-1800, 2350, 3600, 250), PLATFORM_CAPACITY, [t[0] for t in TRAM_SOUTH],
                 outdoor=True),
            shelters("square-south", [(-1200, 2500, 180)]))


def avenue_stop():
    north = room("room:avenue-stop-north", "Avenue stop, north platform", "tram-stop",
                 rect(5200, 1500, 1600, 250), PLATFORM_CAPACITY, [t[0] for t in AVENUE_NORTH],
                 outdoor=True)
    south = room("room:avenue-stop-south", "Avenue stop, south platform", "tram-stop",
                 rect(5200, 2350, 1600, 250), PLATFORM_CAPACITY, [t[0] for t in AVENUE_SOUTH],
                 outdoor=True)
    return ([north, south], shelters("avenue-north", [(6300, 1600, 0)])
            + shelters("avenue-south", [(6300, 2500, 180)]))


def line():
    """The boulevard tram, to the spec's timetable: a tram each way every
    30 ticks, the westbound half a headway behind, 7 m a tick, 12 ticks at
    each stop, 40 riders. The first eastbound tram enters on the day's
    first tick (ticks run from 1), so a player joining at launch rides in
    at once rather than waiting a headway at the portal."""
    def stop(id_, name, x, platforms):
        return {"id": id_, "name": name, "at": x - LINE_WEST, "platforms": platforms}

    return {
        "id": "line:boulevard", "name": "Boulevard tram", "mode": "tram",
        "points": [{"x": LINE_WEST, "z": LINE_Z}, {"x": LINE_EAST, "z": LINE_Z}],
        "tracks": TRACKS,
        "stops": [stop("stop:square", "Square", SQUARE_X, ["room:tram-stop", "room:tram-stop-south"]),
                  stop("stop:avenue", "Avenue", AVENUE_X,
                       ["room:avenue-stop-north", "room:avenue-stop-south"])],
        "timetable": {"headway": 30, "offset": [1, 16], "speed": 28, "dwell": 12},
        "vehicle": {"capacity": 40, "length": TRAM_LENGTH, "doors": TRAM_DOORS},
    }


# The land the city stands on, west to east and north to south, and the
# bridge deck across the river to the west.
LAND = (-4400, -6650, 6800, 5100)
BRIDGE = rect(-7200, 2100, 2800, 400)
# Open ground around the district: every metre of the land the district's
# rooms leave, in rectangles that join along their edges, and the bridge.
# The tram street holds the tracks between the Square stop's platforms,
# with a lane south of them; the avenue gives up its south-east corner to
# the Avenue stop's platforms and the tracks between them.
GROUND = [
    ("room:bridge", "Bridge", BRIDGE),
    ("room:quay", "Quay", rect(-4400, -1400, 1000, 4400)),
    ("room:uptown", "Uptown", rect(-4400, -6650, 11200, 5250)),
    ("room:avenue", "Avenue", rect(3600, -1400, 3200, 2900)),
    ("room:avenue-south", "Avenue, south", rect(3600, 1500, 1600, 1500)),
    ("room:avenue-tramway", "Avenue tramway", rect(5200, 1750, 1600, 600)),
    ("room:avenue-end", "Avenue end", rect(5200, 2600, 1600, 400)),
    ("room:library-lane", "Library lane", rect(1800, -1400, 1800, 200)),
    ("room:library-garden", "Library garden", rect(1800, 800, 1800, 2200)),
    ("room:tram-street", "Tram street", rect(-1800, 1750, 3600, 600)),
    ("room:south-lane", "South lane", rect(-1800, 2600, 3600, 400)),
    ("room:south-streets", "South streets", rect(-4400, 3000, 11200, 2100)),
]


def clip(a, b):
    """The part of rect `a` inside rect `b`, or None."""
    x0, z0 = max(a["x"], b["x"]), max(a["z"], b["z"])
    x1, z1 = min(a["x"] + a["w"], b["x"] + b["w"]), min(a["z"] + a["d"], b["z"] + b["d"])
    return rect(x0, z0, x1 - x0, z1 - z0) if x1 > x0 and z1 > z0 else None


def ground():
    """The open-ground rooms. The blocks standing on them are sized block
    placements, which block every cell the schema 1 obstacles carved out of
    them (`block_placements`)."""
    return [room(id_, name, "ground", r, 200, [], outdoor=True) for id_, name, r in GROUND]


def fences():
    """Railings wherever the ground ends: round the land (open where the
    bridge meets the quay, and where the tracks leave at the east edge)
    and across the bridge's far end; the bridge's own parapets fence its
    sides."""
    def fence(*points):
        return {"kind": "fence", "points": [pt(x, z) for x, z in points]}

    x0, z0, x1, z1 = LAND
    bz0, bz1 = BRIDGE["z"], BRIDGE["z"] + BRIDGE["d"]
    bx = BRIDGE["x"]
    g0, g1 = PORTAL_GAP
    return [fence((x0, bz0), (x0, z0), (x1, z0), (x1, g0)),
            fence((x1, g1), (x1, z1), (x0, z1), (x0, bz1)),
            fence((bx, bz0), (bx, bz1))]


# The blocks of houses, shops and towers, each a lot (x, z, w, d) that
# the block's buildings, porches and steps stand inside.
HOUSES = [
    # West, on the quay, and north-west.
    (-4100, -1400, 600, 1000), (-4200, -3800, 1000, 1200), (-3100, -3800, 900, 1200),
    # South of the tram, two rows.
    (-1000, 2700, 1200, 900), (800, 2700, 1200, 900), (2600, 2700, 1200, 900),
    (-3000, 4200, 1200, 900), (-1400, 4200, 1500, 900), (800, 4200, 1200, 900), (2600, 4200, 1200, 900),
    (4000, 4200, 800, 900),
    # East of the library and across the avenue, standing back from the
    # tram, which runs out between the houses across the avenue.
    (3800, 900, 900, 800),
    (5800, -4000, 1000, 1200), (5800, -2600, 1000, 1200), (5800, -1200, 1000, 1200), (5800, 200, 1000, 1200),
    (5800, 3000, 1000, 1200),
    # North, behind downtown.
    (-3300, -5800, 1100, 1000), (-2000, -5800, 1300, 1000), (100, -5800, 1300, 1000),
    (2100, -5800, 1300, 1000), (3700, -5800, 1000, 1000),
]
SHOPS = [(3700, -1200, 1000, 900), (3700, -200, 1000, 900)]
TOWERS = [(-2000, -4200, 1500, 1500), (0, -4200, 1500, 1500), (2000, -4200, 1500, 1500)]
# Architecture stands on a 2 m snap, so a block's centre must lie on it.
BLOCK_SNAP = KINDS["block-house"]["snap"]


def on_snap(lo, length):
    """One side of a lot, (lo, length), trimmed as little as it can be so
    its centre lies on the block snap: never grown, so it reaches no
    further onto the sidewalk than it did. Of two equal trims, the one on
    the side away from the district's heart, which the buildings face."""
    for trim in range(0, BLOCK_SNAP * 2 + 1, 100):
        cuts = [(c, trim - c) for c in range(0, trim + 1, 100)]
        # Far side first: the high side for a lot east or south of the heart.
        if 2 * lo + length < 0:
            cuts.reverse()
        for low, high in cuts:
            if (2 * lo + length + low - high) % (2 * BLOCK_SNAP) == 0:
                return lo + low, length - low - high
    raise AssertionError(f"no trim of ({lo}, {length}) centres it on the snap")


def blocks():
    """Every block as (height class, lot), each lot trimmed onto the snap:
    the lot the packs draw and the sized placement that blocks it."""
    out = []
    for h, lots in (("house", HOUSES), ("shop", SHOPS), ("tower", TOWERS)):
        for x, z, w, d in lots:
            (x, w), (z, d) = on_snap(x, w), on_snap(z, d)
            out.append((h, rect(x, z, w, d)))
    return out


def block_placements():
    counts = {}
    out = []
    for h, r in blocks():
        counts[h] = counts.get(h, 0) + 1
        p = place(f"{h}-{counts[h]:02}", f"block-{h}", r["x"] + r["w"] // 2, r["z"] + r["d"] // 2,
                  size=(r["w"], r["d"]))
        for _, _, g in GROUND:
            carved = clip(r, g)
            if carved:
                replaces(p, carved)
        out.append(p)
    return out


def pt(x, z):
    return {"x": x, "z": z}


def street(x0, z0, x1, z1, width):
    return {"kind": "street", "points": [pt(x0, z0), pt(x1, z1)], "width": width}


def row(x0, z0, x1, z1, spacing=600):
    """A row of palms from (x0, z0) to (x1, z1), laid out by `row_trees`."""
    return {"points": [pt(x0, z0), pt(x1, z1)], "spacing": spacing}


STREETS = [
    street(-4200, 2300, -3400, 2300, 300),
    street(-4400, -1900, 5000, -1900, 600),
    # The tram's street, under the tracks from end to end.
    street(LINE_WEST, LINE_Z, LINE_EAST, LINE_Z, 600),
    # The avenue east of the district, broken by the Avenue stop's
    # platforms either side of the tram's street; cross streets between
    # the towers and between the southern blocks, and a far street.
    street(5200, -6400, 5200, 1500, 600),
    street(5200, 2600, 5200, 5100, 600),
    street(-250, -6400, -250, -2200, 500),
    street(1750, -6400, 1750, -2200, 500),
    street(550, 2600, 550, 5100, 400),
    street(2380, 2600, 2380, 5100, 400),
    street(-3400, 3900, 5200, 3900, 500),
    street(-4400, -6400, 5200, -6400, 500),
]
TREE_ROWS = [
    row(-1700, -1500, 1700, -1500), row(-1500, 2650, 4800, 2650),
    # Rows of palms along the quay, both sides of the avenue, and in front
    # of downtown, laid as `palm` placements: every style draws them as its
    # palm, the same objects in every style. The lawns' round trees are
    # the planting's `street-tree`s.
    row(-4270, -6000, -4270, -2600), row(-4270, -300, -4270, 1900),
    row(4800, -6000, 4800, -2500), row(4800, -1400, 4800, 1400),
    row(5650, -6000, 5650, -2500), row(5650, -1400, 5650, 1400), row(5650, 2800, 5650, 4600),
    row(-4000, -2300, -800, -2300), row(300, -2300, 1300, -2300), row(2200, -2300, 4600, -2300),
]
WATER = rect(-7000, -4000, 2600, 9000)
BRIDGE_DECK = {"kind": "bridge", "from": pt(-7200, 2300), "to": pt(-4200, 2300), "width": 400}


def scenery():
    """The surfaces and edges around the district, after the style sheets:
    the river and its bridge to the west, the tram's street to the south,
    the street grid and the fences. The blocks of houses, shops and
    downtown towers, and the avenues of palms, are placements; the tram
    line itself is a rule-bearing line (see `line`)."""
    return [{"kind": "water", "rect": WATER}, BRIDGE_DECK] + STREETS + fences()


def ends(item):
    a, b = item["points"]
    return (a["x"], a["z"]), (b["x"], b["z"])


def along(item, spacing, first=0, to_end=True):
    """Points every `spacing` along a two-point item from `first` on, each
    with the item's unit direction, in centimetres: up to and including its
    end, as a tree row's trees are, or short of it (`to_end` false), as
    the kits lay lamps and catenary."""
    (ax, az), (bx, bz) = ends(item)
    length = math.hypot(bx - ax, bz - az)
    ux, uz = (bx - ax) / length, (bz - az) / length
    t = first
    while t <= length + 0.001 if to_end else t < length:
        yield ax + ux * t, az + uz * t, ux, uz
        t += spacing


class Layout:
    """The placements laid so far, so each later one keeps clear of them."""

    def __init__(self, placements):
        self.placements = list(placements)
        self.boxes = [b for b in (bounds(p) for p in self.placements) if b]

    def clear(self, p):
        box = bounds(p)
        return box is None or not any(overlaps(box, b, gap=2 * MARGIN) for b in self.boxes)

    def add(self, p):
        self.placements.append(p)
        box = bounds(p)
        if box:
            self.boxes.append(box)

    def lay(self, slug, kind, x, z, ux, uz, reach, facing=0):
        """A placement near (x, z), slid along (ux, uz) by the least whole
        25 cm step, up to `reach`, that keeps it clear of everything laid;
        None if no step does."""
        step = KINDS[kind]["snap"]
        for k in range(0, reach // step + 1):
            for sign in ((1,) if k == 0 else (1, -1)):
                p = place(slug, kind, snap(round(x + ux * k * step * sign), step),
                          snap(round(z + uz * k * step * sign), step), facing)
                if self.clear(p):
                    self.add(p)
                    return p
        return None


def row_trees(layout):
    """Each tree row as palms at its spacing, on the snap, where the packs
    draw its trees."""
    for r, item in enumerate(TREE_ROWS, 1):
        for k, (x, z, _, _) in enumerate(along(item, item["spacing"]), 1):
            layout.add(place(f"row-{r:02}-{k:02}", "palm", snap(round(x), 25), snap(round(z), 25)))


# The catenary: a pole every 14 m along each track, 2 m out from it (the
# kits draw 1.9 m, and the snap is 25 cm), the eastbound's to the north
# and the westbound's to the south, both outside the pair and clear of
# the trams' 2.5 m.
POLE_EVERY, POLE_FIRST, POLE_OUT = 1400, 200, 200


def catenary(layout):
    """Poles laid as the kits lay them, from each track's own start in the
    direction its trams run; a pole that would meet a shelter slides along
    the track until it is clear."""
    for index, offset in enumerate(TRACKS):
        track = street(LINE_WEST, LINE_Z + offset, LINE_EAST, LINE_Z + offset, 0)
        if index == 1:
            track["points"].reverse()
        for k, (x, z, ux, uz) in enumerate(along(track, POLE_EVERY, POLE_FIRST, to_end=False), 1):
            # The kits' side: the travel direction turned to the left.
            sx, sz = -uz, ux
            p = layout.lay(f"catenary-{index + 1}-{k:02}", "catenary-pole",
                           x - sx * POLE_OUT, z - sz * POLE_OUT, ux, uz, 400)
            assert p, f"no room for catenary pole {index + 1}-{k}"


# Street lamps as solarpunk lights its streets: one every 22 m from 11 m
# in, standing 70 cm beyond the carriageway's edge, sides alternating,
# each facing the street it lights.
LAMP_EVERY, LAMP_OUT = 2200, 70


def bearing(dx, dz):
    """The whole-degree facing, clockwise from north (-z), of the way
    (dx, dz)."""
    return round(math.degrees(math.atan2(dx, -dz))) % 360


def street_lamps(layout):
    for s, item in enumerate(STREETS, 1):
        for k, (x, z, ux, uz) in enumerate(along(item, LAMP_EVERY, LAMP_EVERY // 2, to_end=False), 1):
            side = 1 if k % 2 == 1 else -1
            out = item["width"] // 2 + LAMP_OUT
            lx, lz = x - uz * side * out, z + ux * side * out
            # Where a block's lot comes right up to the carriageway (the
            # towers either side of the cross streets), the lamp's spot is
            # in the building, and there is no lamp.
            spot = grow((lx, lz, lx, lz), KINDS["street-lamp"]["footprint"][0]["r"] + 2 * MARGIN)
            if any(overlaps(spot, box(r)) for _, r in blocks()):
                continue
            p = layout.lay(f"lamp-{s:02}-{k}", "street-lamp", lx, lz, ux, uz, 400,
                           bearing(uz * side, -ux * side))
            assert p, f"no room for street lamp {s}-{k}"


# The planting solarpunk scatters, in its proportions: its planting list
# is five round trees, three palms and two shrubs. On the paved quay, a
# plant is a planter, as voxel sets its planters out.
PLANTING = ["street-tree", "street-tree", "street-tree", "street-tree",
            "palm", "palm", "palm", "shrub", "street-tree", "shrub"]
PLANTING_STEP, PLANTING_REACH = 480, 2400
# The rooms planting may stand in, besides the open ground: the park's lawn.
LAWNS = {"room:park"}


def mix(x, z):
    """A fixed 32-bit hash of a point, so the scatter is the same on every
    run and every machine."""
    h = (x * 0x9E3779B1 + z * 0x85EBCA77) & 0xFFFFFFFF
    h ^= h >> 15
    h = (h * 0x2C1B3C6D) & 0xFFFFFFFF
    h ^= h >> 12
    h = (h * 0x297A2D39) & 0xFFFFFFFF
    return h ^ (h >> 15)


def grow(r, by):
    return (r[0] - by, r[1] - by, r[2] + by, r[3] + by)


def box(r):
    return (r["x"], r["z"], r["x"] + r["w"], r["z"] + r["d"])


def segment_box(item, by):
    """The box round an item's points (or a bridge's ends), grown by `by`."""
    pts = item.get("points") or [item["from"], item["to"]]
    xs, zs = [q["x"] for q in pts], [q["z"] for q in pts]
    return grow((min(xs), min(zs), max(xs), max(zs)), by)


def garden_paths(r):
    """The paths a pack lays across a lawn room, as boxes: from each door
    to the room's centre, first across then along (`_paths`)."""
    x0, z0, x1, z1 = box(r["rect"])
    cx, cz = (x0 + x1) // 2, (z0 + z1) // 2
    out = []
    for d in r["doors"]:
        px = min(max(d["pos"]["x"], x0), x1)
        pz = min(max(d["pos"]["z"], z0), z1)
        corner = (px, cz) if pz in (z0, z1) else (cx, pz)
        for (ax, az), (bx, bz) in (((px, pz), corner), (corner, (cx, cz))):
            out.append((min(ax, bx), min(az, bz), max(ax, bx), max(az, bz)))
    return out


def planting(layout, rooms, entrances):
    """The planting on the lawns and verges, laid out as `_plant` scatters
    it: a jittered 4.8 m lattice over the district and 24 m beyond, clear
    of water, blocks, streets and their sidewalks, tree rows and the
    tracks, and 1 m clear of every drawn room but the park's lawn (so off
    the square, the terrace and the platforms). A plant is solid, so it
    also keeps off the ways in and out: 2.5 m from every door, 1.5 m from
    every seat and 3 m from every entrance, 1.5 m from the park's paths,
    and clear of every placement laid before it and its anchors."""
    items = scenery()
    walked = [box(r["rect"]) for r in rooms if r["template"] != "ground" and r["id"] not in LAWNS]
    keep_clear = ([grow(box(WATER), 160)]
                  + [grow(box(r), 160) for _, r in blocks()]
                  + [segment_box(s, s["width"] // 2 + 240) for s in STREETS]
                  + [segment_box(BRIDGE_DECK, BRIDGE_DECK["width"] // 2 + 180)]
                  + [grow((x, z, x, z), 220) for item in TREE_ROWS
                     for x, z, _, _ in along(item, item["spacing"])]
                  + [grow((LINE_WEST, LINE_Z + t, LINE_EAST, LINE_Z + t), 330) for t in TRACKS]
                  + [grow(r, 100) for r in walked]
                  + [grow((d["pos"]["x"], d["pos"]["z"]) * 2, 250) for r in rooms for d in r["doors"]]
                  + [grow((s["pos"]["x"], s["pos"]["z"]) * 2, 150) for r in rooms for s in r["seats"]]
                  + [grow((e["x"], e["z"]) * 2, 300) for e in entrances]
                  + [grow(b, 150) for r in rooms if r["id"] in LAWNS for b in garden_paths(r)])
    quay = next(box(r) for id_, _, r in GROUND if id_ == "room:quay")
    # The extent the lattice covers, blocks and rows of palms included, as
    # when they were scenery.
    extent = ([box(r["rect"]) for r in rooms] + [box(i["rect"]) for i in items if "rect" in i]
              + [box(r) for _, r in blocks()]
              + [segment_box(i, i.get("width", 0) // 2) for i in items + TREE_ROWS if "rect" not in i])
    x0 = min(r[0] for r in extent) - PLANTING_REACH
    z0 = min(r[1] for r in extent) - PLANTING_REACH
    x1 = max(r[2] for r in extent) + PLANTING_REACH
    z1 = max(r[3] for r in extent) + PLANTING_REACH
    n = 0
    for z in range(z0, z1, PLANTING_STEP):
        for x in range(x0, x1, PLANTING_STEP):
            h = mix(x, z)
            px = snap(x + (h % 37) * 320 // 37 - 160, 25)
            pz = snap(z + (h // 37 % 41) * 320 // 41 - 160, 25)
            if h % 5 == 0 or any(r[0] <= px < r[2] and r[1] <= pz < r[3] for r in keep_clear):
                continue
            on_quay = quay[0] <= px < quay[2] and quay[1] <= pz < quay[3]
            p = place("planting", "planter" if on_quay else PLANTING[h // 7 % len(PLANTING)], px, pz)
            if not layout.clear(p):
                continue
            n += 1
            p["id"] = f"placement:planting-{n:03}"
            layout.add(p)


# The sample panels the district's displays show, by file under panels/,
# each keyed by the placement that shows it: bundled content, marked
# Sample, until a product feeds a display live (spec §2).
def spines(*docs):
    return [{"title": title, "subtitle": f"docs/vision/{name}.md"} for name, title in docs]


PANELS = {
    "square-notices.json": {
        "placement:square-noticeboard": {
            "type": "Notices", "title": "Notices from the city", "sample": True,
            "items": [
                {"date": "2026-09-27", "headline": "v0.0.3: the boulevard tram",
                 "body": "Trams run the boulevard between the Square and the Avenue. Arrivals ride "
                         "in, and anyone can board, ride and step off."},
                {"date": "2026-09-26", "headline": "v0.0.2: menus and a map",
                 "body": "A title screen, menus, settings and rebinding, six interface skins, and a "
                         "map to find a place and go there."},
                {"date": "2026-09-26", "headline": "v0.0.1: the first packages",
                 "body": "The Makers' square in six styles, with its walkers, seats and daylight, "
                         "packaged as a client to download."},
            ],
        },
    },
    "library-shelves.json": {
        "placement:reading-shelf-1": {
            "type": "Shelf", "title": "The vision", "sample": True,
            "spines": spines(("VISION", "A maker city worth returning to"),
                             ("MASTER_PLAN", "An open maker city"),
                             ("CITY_PLAN", "The city map and its institutions"),
                             ("PEOPLE_AND_DAILY_LIFE", "People and daily life")),
        },
        "placement:reading-shelf-2": {
            "type": "Shelf", "title": "Residents and projects", "sample": True,
            "spines": spines(("FOUNDING_AGENTS", "The first agent residents"),
                             ("GUILD_RESIDENTS", "The Guild's fourteen founding residents"),
                             ("PROJECTS_AND_COLLABORATION", "Projects, creators and collaboration"),
                             ("EXPERIENCES", "Features and experiments")),
        },
        "placement:reading-shelf-3": {
            "type": "Shelf", "title": "How the city runs", "sample": True,
            "spines": spines(("ECOSYSTEM", "How SJL projects power the city"),
                             ("OPERATING_MODEL", "Ownership, access and funding"),
                             ("COMMUNITY_CHARTER", "Community, stewardship and creative rights")),
        },
    },
    "guild-hall.json": {
        "placement:guild-hall-plaque": {
            "type": "Plaque", "title": "The Guild hall", "sample": True,
            "text": "Where Agentnagar's makers work: agents and people at shared desks and the "
                    "long bench, with the commons beside them.",
        },
    },
}


def occupant(id_, kind, name, role, work, department=None):
    o = {"id": id_, "kind": {"type": kind}, "display_name": name, "role": role, "work": work}
    if department:
        o["department"] = department
    return o


# Where a walk out goes when no platform can be reached.
ENTRANCES = [{"x": -1400, "z": 3000}, {"x": 500, "z": 3000}, {"x": -3400, "z": 2300},
             {"x": 0, "z": -1400}, {"x": 1800, "z": 1100}]


def manifest():
    workshop_room, workshop_things = workshop()
    commons_room, commons_things = commons()
    reading, reading_things = reading_room()
    terrace, terrace_things = cafe_terrace()
    square, square_things = plaza()
    park_room, park_things = park()
    stop_north, stop_north_things = tram_stop()
    stop_south, stop_south_things = tram_stop_south()
    avenue_rooms, avenue_things = avenue_stop()
    streets = ground()
    rooms = ([workshop_room, commons_room, reading, terrace, square, park_room, stop_north, stop_south]
             + avenue_rooms + streets)
    # The manifest's own things first, then the blocks and the tree rows
    # where the packs draw them; the catenary, street lamps and planting
    # then keep clear of all of those.
    layout = Layout(workshop_things + commons_things + reading_things + terrace_things + square_things
                    + park_things + stop_north_things + stop_south_things + avenue_things
                    + library_garden() + block_placements())
    row_trees(layout)
    catenary(layout)
    street_lamps(layout)
    planting(layout, rooms, ENTRANCES)
    return {
        "schema_version": 2,
        "catalogue": CATALOGUE["version"],
        "clock": {"ticks_per_day": 600, "start_minute": 420},
        # An evening shower, so night and rain can be seen together.
        "weather": {"rain": [{"from": 1140, "to": 1290, "peak": 80}]},
        "seat_policy": "department-first",
        "scenery": scenery(),
        "lines": [line()],
        "city": {
            "id": "city:agentnagar", "name": "Agentnagar",
            # Arrivals ride the tram in and departures ride it out; the
            # entrances serve only a walk out when no platform can be
            # reached, so none stands on a platform.
            "arrivals": "tram",
            "entrances": ENTRANCES,
            "districts": [{
                "id": "district:makers-square", "name": "Makers' square",
                # The guild hall's and library's shells stand 25 cm outside
                # their rooms, over one edge row of cells of the quay,
                # uptown, the square, the café terrace, the library lane,
                # the library garden and the avenue. No seat, door, platform
                # or placement stood on those rows, so nothing had to move.
                # The café terrace has no building kind: no café building
                # stands behind it yet, and a shell would wall the terrace.
                "facilities": [
                    {"id": "facility:guild-hall", "name": "Guild hall", "kind": "guild-hall",
                     "roof": "sawtooth", "storeys": 1,
                     "rooms": [workshop_room, commons_room], "category": "workshop"},
                    {"id": "facility:library", "name": "Library", "kind": "library",
                     "roof": "dome", "storeys": 2, "rooms": [reading], "category": "library"},
                    {"id": "facility:cafe", "name": "Café terrace", "rooms": [terrace]},
                    {"id": "facility:square", "name": "Tree square", "rooms": [square]},
                    {"id": "facility:park", "name": "Park", "rooms": [park_room], "category": "park"},
                    {"id": "facility:tram-stop", "name": "Tram stop",
                     "rooms": [stop_north, stop_south], "category": "transit"},
                    {"id": "facility:avenue-stop", "name": "Avenue stop", "rooms": avenue_rooms,
                     "category": "transit"},
                    {"id": "facility:streets", "name": "Streets", "rooms": streets},
                ],
                "placements": sorted(layout.placements, key=lambda p: p["id"]),
            }],
        },
        "occupants": [
            occupant("agent:kai", "GuildAgent", "Kai", "maker", "room:workshop", "making"),
            occupant("agent:lyra", "GuildAgent", "Lyra", "maker", "room:workshop", "making"),
            occupant("agent:theo", "GuildAgent", "Theo", "builder", "room:workshop"),
            occupant("agent:quill", "GuildAgent", "Quill", "writer", "room:workshop"),
            occupant("agent:echo", "GuildAgent", "Echo", "researcher", "room:reading", "knowledge"),
            occupant("city:librarian", "CityRoleAgent", "Librarian", "librarian", "room:reading"),
        ],
    }


def stamp(at, exp):
    return {"observed_at": at, "fetched_at": at, "expires_at": exp,
            "source": "fixture:district", "source_version": "1"}


def observe(at, who, dim, value, exp):
    return (at, {"type": "Observe", "occupant": who,
                 "observation": {"dimension": dim, "value": value, "stamp": stamp(at, exp)}})


def arrive(at, who, room=None, profile=None):
    c = {"type": "Arrive", "occupant": who}
    if room:
        c["room"] = room
    if profile:
        c["profile"] = profile
    return (at, c)


def person(id_, name, tier):
    return {"id": id_, "kind": {"type": "Human", "tier": tier}, "display_name": name,
            "appearance": {"palette": str(sum(map(ord, id_)) % 8), "hair": str(len(name) % 4)}}


# Arrivals ride in by tram: from `Arrive` to stepping off at the Square takes
# some 20 to 50 ticks (waiting at a portal for the next tram, then the ride;
# the story's first trams bring them at 35 and 38). The beats that need
# people present come this much later than they did when arrivals walked in.
RIDE = 40


def story():
    """The gate beats: seats by capacity, overflow, a queue of two outside the
    workshop, a stale task, a process with no task, a private agent and an
    observer as overlays, a walk between buildings, and everyone leaving."""
    e = [
        arrive(1, "agent:kai"), arrive(2, "agent:lyra"), arrive(3, "agent:theo"),
        arrive(4, "agent:quill"), arrive(2, "agent:echo"), arrive(3, "city:librarian"),
        observe(1, "agent:kai", "Process", "Running", 400),
        observe(1, "agent:kai", "Task", {"state": "Working", "summary": "Sketching the kiln door",
                                         "summary_public": True}, 400),
        observe(2, "agent:lyra", "Process", "Running", 400),
        observe(2, "agent:lyra", "Task", {"state": "Working", "summary": "Glazing test tiles"}, 60 + RIDE),
        observe(3, "agent:theo", "Process", "Running", 400),
        observe(4, "agent:quill", "Process", "Running", 400),
        observe(4, "agent:quill", "Task", {"state": "Idle"}, 400),
        observe(2, "agent:echo", "Process", "Running", 400),
        observe(2, "agent:echo", "Task", {"state": "Working"}, 400),
        observe(3, "city:librarian", "Process", "Running", 400),
        observe(3, "city:librarian", "Task", {"state": "Waiting"}, 400),
        arrive(6, "person:ravi", "room:workshop", person("person:ravi", "Ravi", "Resident")),
        arrive(8, "person:meera", "room:workshop", person("person:meera", "Meera", "Registered")),
        arrive(9, "person:noor", "room:workshop", person("person:noor", "Noor", "Resident")),
        arrive(10, "person:kiran", "room:workshop", person("person:kiran", "Kiran", "Registered")),
        arrive(12, "person:asha", "room:workshop", person("person:asha", "Asha", "Registered")),
        arrive(13, "person:tara", "room:workshop", person("person:tara", "Tara", "Registered")),
        arrive(15, "person:omar", "room:workshop", person("person:omar", "Omar", "Resident")),
        arrive(14, "person:dev", "room:workshop", person("person:dev", "Dev", "Registered")),
        arrive(18, "person:sana", "room:workshop", person("person:sana", "Sana", "Registered")),
        arrive(20, "person:ila", "room:workshop", person("person:ila", "Ila", "Resident")),
        arrive(13, "pa:asha-notes", "room:workshop",
               {"id": "pa:asha-notes", "display_name": "Asha's notes",
                "kind": {"type": "PersonalAgent", "owner": "person:asha"}}),
        observe(13, "pa:asha-notes", "Process", "Running", 400),
        observe(13, "pa:asha-notes", "Task", {"state": "Working",
                                              "summary": "Collecting kiln readings for Asha"}, 400),
        arrive(16, "person:guest", "room:plaza", person("person:guest", "Guest", "Observer")),
        # The first to leave are three the trams bring into the workshop, so
        # its queue drains into it: Asha, Ravi, then Noor (Meera, on the
        # later tram, finds the workshop full and waits in the commons).
        (80 + RIDE, {"type": "Move", "occupant": "person:asha", "to": "room:cafe-terrace"}),
        (90 + RIDE, {"type": "Depart", "occupant": "person:ravi"}),
        (100 + RIDE, {"type": "Depart", "occupant": "person:noor"}),
    ]
    for at, who in [(140, "person:meera"), (142, "person:kiran"), (146, "person:tara"),
                    (148, "person:omar"),
                    (150, "agent:theo"), (155, "person:sana"), (160, "person:ila"),
                    (165, "pa:asha-notes"), (168, "person:guest"), (170, "person:dev"),
                    (172, "person:asha"), (175, "agent:quill"), (178, "agent:lyra"),
                    (180, "agent:echo"), (184, "city:librarian"), (188, "agent:kai")]:
        e.append((at + RIDE, {"type": "Depart", "occupant": who}))
    for who in ["person:ravi", "person:meera", "person:noor", "person:kiran", "person:asha",
                "person:tara", "person:omar", "person:dev", "person:sana", "person:ila",
                "person:guest"]:
        at = next(a for a, c in e if c.get("occupant") == who and c["type"] == "Arrive")
        e.append(observe(at, who, "Connection", "Connected", 400))
    e.sort(key=lambda x: x[0])
    header = {"record": "header", "schema_version": 1, "source": "fixture:district",
              "fixture": True,
              "description": "Scripted district story for the style-pack gate. A fixture, not real agent state."}
    lines = [header] + [{"record": "entry", "at": at, "fixture": True, "command": c} for at, c in e]
    return "".join(json.dumps(line, sort_keys=True) + "\n" for line in lines)


def outputs():
    out = {
        "manifest.json": json.dumps(manifest(), indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        "feed.jsonl": story(),
    }
    for name, panels in PANELS.items():
        out[f"panels/{name}"] = json.dumps(panels, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    return out


def main():
    check = "--check" in sys.argv[1:]
    stale = []
    for name, text in outputs().items():
        path = HERE / name
        if check:
            if not path.exists() or path.read_text(encoding="utf-8") != text:
                stale.append(name)
        else:
            path.parent.mkdir(exist_ok=True)
            path.write_text(text, encoding="utf-8")
    if stale:
        print("stale: " + ", ".join(stale) + " (run generate.py)", file=sys.stderr)
        sys.exit(1)
    if not check:
        validate(HERE / "manifest.json")


def validate(path):
    """The core's own check of what was written: every placement, shell and
    door span as the city will build them. (The fixture test runs the same
    check, so `--check` leaves it to the test.)"""
    run = subprocess.run(["cargo", "run", "--quiet", "--manifest-path", str(CITY / "Cargo.toml"),
                          "-p", "city-cli", "--", "validate", str(path)],
                         capture_output=True, text=True, check=False)
    report = json.loads(run.stdout or "{}")
    if not report.get("valid"):
        for i in report.get("issues", []):
            print(f"{i.get('code')} {i.get('place')}: {i.get('message')}", file=sys.stderr)
        print(run.stderr, file=sys.stderr, end="")
        sys.exit(1)


if __name__ == "__main__":
    main()
