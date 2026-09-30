"""Trees and street, café and library furniture.

Every prop stands on y = 0, centred on the origin, its front (the side a
sitter faces, or the open side of a shelf) toward -z. Seats: the bench's
and chairs' seat tops are 0.5 m up, the sitter facing -z.
"""
from shapes import canopy, new
from voxel import Asset, drum, merged, mesh, unit

GREENS = ("leaf_dark", "leaf", "leaf_light")


def _trunk(g, half, j1, flare=True):
    g.box(-half, 0, -half, half, j1, half, lambda i, j, k: "trunk_dark" if (i + k + j // 4) % 5 == 0 else "trunk")
    if flare:
        for (i, k) in ((-half - 1, 0), (half, -1), (0, -half - 1), (-1, half)):
            g.box(i, 0, k, i + 1, 2, k + 1, "trunk_dark")


def tree_small():
    """A 3.6 m street tree: a slim trunk and a two-tier canopy of 0.4 m
    blocks, about 2.8 m across."""
    a = Asset("tree_small")
    g = new()
    _trunk(g, 1, 16)
    canopy(g, [(0, 22, 0, 14, 8, 14), (1, 30, -1, 9, 6, 9)], 4, GREENS, "tree_small")
    a.part("tree", g)
    return a


def tree_medium():
    """A 5.8 m tree: a 0.4 m trunk and three stacked tiers of 0.5 m blocks,
    about 4.5 m across."""
    a = Asset("tree_medium")
    g = new()
    _trunk(g, 2, 26)
    canopy(g, [(0, 33, 0, 22, 9, 22), (-2, 43, 2, 16, 8, 16), (1, 51, -1, 10, 6, 10)], 5, GREENS, "tree_medium")
    a.part("tree", g)
    return a


# The great tree's footprint, half a side in cells (the great-tree kind's
# 5.2 m square; the pack stretches the tree to it).
ROOT_HALF = 26


def _root_skirt(g, half, trunk, seed):
    """Surface roots filling a square `half` cells from the trunk's axis:
    every other column of cells a root, running straight out from the
    trunk (`trunk` cells round) to the nearest edge, arched at knee height
    and diving into the ground at the edge, over a layer of soil; so no
    ground within the square is more than half a root's gap from one."""
    for i in range(-half, half):
        for k in range(-half, half):
            g.put(i, 0, k, "soil")
            if abs(k + 0.5) >= abs(i + 0.5):
                across, out, side = i, abs(k + 0.5), "s" if k > 0 else "n"
            else:
                across, out, side = k, abs(i + 0.5), "e" if i > 0 else "w"
            if out < trunk or across % 2:
                continue
            f = (out - trunk) / (half - trunk)
            # Each root its own height, a hand's width either way.
            lift = 1 if unit(seed, "root", side, across) < 0.5 else 0
            top = 3 + lift + int(round(2 * (1 - f)))
            bottom = 0 if out > half - 2 else max(1, top - 2)
            g.box(i, bottom, k, i + 1, top, k + 1, "trunk_dark" if (i + k) % 6 == 0 else "trunk")


def tree_large():
    """The square's great tree, 10 m: a 0.8 m trunk with branches, a broad
    canopy of 0.7 m blocks in overlapping lobes, about 9 m across, and its
    surface roots filling its 5.2 m square of ground (the great-tree
    kind's footprint) where people walk round it."""
    a = Asset("tree_large")
    g = new()
    _root_skirt(g, ROOT_HALF, 4, "tree_large")
    _trunk(g, 4, 50, flare=False)
    for (di, dk, j) in ((-1, 0, 44), (1, 0, 48), (0, -1, 46), (0, 1, 50)):
        for s in range(14):
            g.box(di * s - 1, j + s // 2, dk * s - 1, di * s + 2, j + s // 2 + 2, dk * s + 2, "trunk")
    canopy(g, [(0, 62, 0, 40, 14, 40), (-16, 72, 12, 24, 13, 24), (16, 74, -12, 24, 13, 24),
               (10, 70, 18, 20, 11, 20), (-14, 70, -16, 20, 11, 20), (0, 84, 0, 22, 11, 22)],
           7, GREENS, "tree_large")
    a.part("tree", g)
    return a


def shrub():
    """A clipped bush, 2.1 m across and 0.8 m tall (the shrub kind's disc):
    a round hedge drum 0.4 m high, drawn as a 32-sided prism so its edge
    follows the disc, under a mound of bush blocks kept inside it, all one
    mesh."""
    a = Asset("shrub")
    r = 1.05
    g = new()
    canopy(g, [(-3, 5, -2, 7, 3, 7), (4, 5, 3, 6, 3, 6), (1, 4, -5, 7, 2, 5), (-2, 4, 6, 6, 2, 5)], 2, GREENS, "shrub")
    for (i, j, k) in list(g.cells):
        # Inside the drum's flats, and on it.
        far = max(abs(i), abs(i + 1)) ** 2 + max(abs(k), abs(k + 1)) ** 2
        if j < 3 or far > (r * 0.99 * 10) ** 2:
            g.erase(i, j, k)
    # One mesh: the pack plants shrubs by the hundred from it.
    a.shape("bush", merged(drum(32, r, 0.0, 0.4, "leaf_dark", "leaf_dark", "shrub"), mesh(g)))
    return a


def _bushes(g, i0, k0, i1, k1, j, seed, block=2, flowers=(), height=4.5):
    """A mound of small bush blocks over a bed, with flowers poking out."""
    lobes = []
    n = max(1, (i1 - i0) // 6)
    for t in range(n):
        ci = i0 + (t + 0.5) * (i1 - i0) / n
        lobes.append((ci, j, (k0 + k1) / 2, (i1 - i0) / n * 0.8, height, (k1 - k0) / 2 * 0.95))
    filled = canopy(g, lobes, block, GREENS, seed)
    # Keep the mound inside the bed and above its soil.
    for (i, jj, k) in list(g.cells):
        if jj >= j - 3 and (i < i0 or i >= i1 or k < k0 or k >= k1 or jj < j):
            if g.get(i, jj, k) in GREENS:
                g.erase(i, jj, k)
    if flowers:
        tops = {}
        for (i, jj, k), key in g.cells.items():
            if key in GREENS:
                tops[(i, k)] = max(tops.get((i, k), -1), jj)
        for (i, k), jj in sorted(tops.items()):
            u = unit(seed, "flower", i, k)
            if u < 0.22:
                g.put(i, jj + 1, k, flowers[int(u * 100) % len(flowers)])
    return filled


def planter():
    """A 1.2 m grey planter box, 0.5 m tall, with a mound of bushes."""
    a = Asset("planter")
    g = new()
    g.box(-6, 0, -6, 6, 5, 6, lambda i, j, k: "kerb" if j == 4 else ("stone" if abs(i + 0.5) > 5 or abs(k + 0.5) > 5 else "soil"))
    _bushes(g, -5, -5, 5, 5, 5, "planter")
    a.part("box", g)
    return a


def planter_long():
    """A 2.4 x 0.8 m planter along x with a hedge of bush blocks."""
    a = Asset("planter_long")
    g = new()
    g.box(-12, 0, -4, 12, 5, 4, lambda i, j, k: "kerb" if j == 4 else ("stone" if abs(i + 0.5) > 11 or abs(k + 0.5) > 3 else "soil"))
    _bushes(g, -11, -3, 11, 3, 5, "planter_long")
    a.part("box", g)
    return a


def flowerbed():
    """A 2 x 1 m bed along x: a stone kerb 0.3 m high, bushes and white,
    pink and yellow flowers."""
    a = Asset("flowerbed")
    g = new()
    # The kerb stands 0.3 m, so the bed's edge is drawn where people walk.
    g.box(-10, 0, -5, 10, 3, 5, lambda i, j, k: "kerb" if abs(i + 0.5) > 9 or abs(k + 0.5) > 4 else ("soil" if j < 2 else None))
    _bushes(g, -9, -4, 9, 4, 2, "flowerbed", flowers=("flower_white", "flower_pink", "flower_yellow", "flower_white"),
            height=2.5)
    a.part("bed", g)
    return a


def bench():
    """A 1.8 m park bench along x: wooden seat slats (top 0.5 m) and a
    two-slat backrest on the +z side, flush with the back of the charcoal
    end frames (so the bench's back is one line where people walk), and
    armrests; the sitter faces -z."""
    a = Asset("bench")
    g = new()
    for i in range(-9, 9):
        for k in range(-2, 4):
            g.put(i, 4, k, "wood" if k % 2 == 0 else "wood_light")
        for j in (6, 8):
            g.put(i, j, 4, "wood")
            g.put(i, j + 1, 4, "wood_light")
    for i in (-8, 7):
        for k in (-2, 2):
            g.box(i, 0, k, i + 1, 4, k + 1, "charcoal")
        g.box(i, 3, -2, i + 1, 4, 3, "charcoal")
        g.box(i, 5, 4, i + 1, 10, 5, "charcoal")
        g.box(i, 0, 4, i + 1, 5, 5, "charcoal")
        g.box(i - (1 if i < 0 else 0), 6, -2, i + (2 if i > 0 else 1), 7, 3, "charcoal")
        g.box(i, 5, -2, i + 1, 6, -1, "charcoal")
    a.part("seat", g)
    return a


def lamp():
    """A 4.4 m street lamp: a charcoal post on a stepped base, a lantern
    whose glowing panes are the node `light` (emissive), and a cap."""
    a = Asset("lamp")
    g = new()
    g.box(-2, 0, -2, 2, 2, 2, "charcoal")
    g.box(-1, 2, -1, 1, 36, 1, "charcoal")
    g.box(-2, 20, -2, 2, 21, 2, "charcoal")
    g.box(-3, 36, -3, 3, 37, 3, "charcoal")
    for (i, k) in ((-3, -3), (2, -3), (-3, 2), (2, 2)):
        g.box(i, 37, k, i + 1, 42, k + 1, "charcoal")
    g.box(-3, 42, -3, 3, 43, 3, "charcoal")
    g.box(-2, 43, -2, 2, 44, 2, "charcoal")
    g.box(-1, 44, -1, 1, 45, 1, "charcoal")
    a.part("post", g)
    glow = new()
    for i in range(-3, 3):
        for k in range(-3, 3):
            if (i in (-3, 2)) != (k in (-3, 2)):
                glow.box(i, 37, k, i + 1, 42, k + 1, "lamp_glow")
            elif i not in (-3, 2):
                glow.box(i, 37, k, i + 1, 42, k + 1, "lamp_glow")
    a.part("light", glow)
    return a


def bollard():
    """A 0.8 m charcoal bollard, 0.2 m square on its axis (inside the
    bollard kind's 15 cm disc), with a light band."""
    a = Asset("bollard")
    g = new()
    g.box(-1, 0, -1, 1, 8, 1, lambda i, j, k: "kerb" if j == 6 else "charcoal")
    a.part("post", g)
    return a


def _railing_post(g, i0):
    """A white post two voxels square with a yellow cap, on the kerb."""
    g.box(i0, 0, -1, i0 + 2, 1, 1, "kerb")
    g.box(i0, 1, -1, i0 + 2, 10, 1, "white")
    g.box(i0, 10, -1, i0 + 2, 11, 1, "yellow")


def railing():
    """Two metres of railing along x, where walkable ground ends: a kerb,
    a post at the -x end (the next module's post, or a railing_post,
    closes the +x end), charcoal bars between a bottom rail and a yellow
    handrail at 0.9 m."""
    a = Asset("railing")
    g = new()
    g.box(-10, 0, -1, 10, 1, 1, "kerb")
    _railing_post(g, -10)
    g.box(-8, 9, -1, 10, 10, 1, "yellow")
    g.box(-8, 1, -1, 10, 2, 0, "charcoal")
    for i in range(-5, 10, 3):
        g.box(i, 2, -1, i + 1, 9, 0, "charcoal")
    a.part("rail", g)
    return a


def railing_post():
    """The post that closes a run of railing, or turns its corner."""
    a = Asset("railing_post")
    g = new()
    _railing_post(g, -1)
    a.part("post", g)
    return a


def cafe_table():
    """A round café table, 0.9 m across and 0.8 m tall, white top on a
    charcoal pedestal."""
    a = Asset("cafe_table")
    g = new()
    g.box(-3, 0, -3, 3, 1, 3, "charcoal")
    g.box(-1, 1, -1, 1, 7, 1, "charcoal")
    g.cylinder(0, 0, 4.6, 7, 8, "white")
    a.part("table", g)
    return a


def cafe_chair():
    """A café chair facing -z: an orange seat (top 0.5 m) and back on
    charcoal legs."""
    a = Asset("cafe_chair")
    g = new()
    for (i, k) in ((-2, -2), (1, -2), (-2, 1), (1, 1)):
        g.box(i, 0, k, i + 1, 4, k + 1, "charcoal")
    g.box(-2, 4, -2, 2, 5, 2, "orange")
    g.box(-2, 5, 1, 2, 9, 2, "orange")
    g.box(-2, 9, 1, 2, 10, 2, "orange_dark")
    a.part("chair", g)
    return a


def umbrella():
    """A 2.4 m café umbrella, 2.6 m tall: a stepped canopy in orange and
    white segments on a white pole with a charcoal weight."""
    a = Asset("umbrella")
    g = new()
    g.box(-2, 0, -2, 2, 1, 2, "charcoal")
    g.box(-1, 1, -1, 0, 24, 0, "white")
    for step, half in enumerate((12, 10, 7, 4)):
        j = 22 + step
        for i in range(-half, half):
            for k in range(-half, half):
                seg = (abs(i + 0.5) > abs(k + 0.5)) != ((i < 0) == (k < 0))
                g.put(i, j, k, "orange" if seg else "white")
    for i in range(-12, 12):
        for k in (-12, 11):
            g.put(i, 21, k, "orange")
            g.put(k, 21, i, "orange")
    g.box(-1, 26, -1, 1, 27, 1, "orange_dark")
    a.part("canopy", g)
    return a


def reading_chair():
    """A blue armchair facing -z, laid out to the reading-chair kind's
    footprint (the pack stretches it across to it): arms from front to
    back either side, a high back, and a seat (top 0.5 m) that stops 0.2 m
    ahead of the sitter, so the ground in front of it, between the arms,
    stays clear where people walk; wooden feet under the arms."""
    a = Asset("reading_chair")
    g = new()
    for (i, k) in ((-4, -4), (3, -4), (-4, 4), (3, 4)):
        g.put(i, 0, k, "wood_dark")
    for i0 in (-4, 3):
        g.box(i0, 1, -4, i0 + 1, 7, 5, "blue")
    g.box(-3, 1, 3, 3, 10, 5, "blue")
    g.box(-3, 7, 3, 3, 10, 4, "glass_light")
    g.box(-3, 1, -2, 3, 3, 3, "blue")
    g.box(-3, 3, -2, 3, 5, 3, "glass_light")
    a.part("chair", g)
    return a


def bookshelf():
    """A 1.6 m bookshelf, 2 m tall and 0.4 m deep, open toward -z: a
    wooden frame, four shelves of books in many colours with gaps."""
    a = Asset("bookshelf")
    g = new()
    g.box(-8, 0, -2, 8, 20, 2, lambda i, j, k: "wood" if (abs(i + 0.5) > 7 or j in (0, 19) or k == 1) else None)
    shelves = (1, 6, 11, 15, 19)
    for j in shelves[:-1]:
        g.box(-7, j - 1 if j > 1 else 0, -2, 7, j, 1, "wood")
    colours = ("book_red", "blue", "book_green", "orange", "cream", "navy", "yellow")
    for n in range(len(shelves) - 1):
        j0, j1 = shelves[n], shelves[n + 1] - 1
        for i in range(-7, 7):
            u = unit("book", n, i)
            if u < 0.12:
                continue
            h = min(j1 - j0, 2 + int(unit("h", n, i) * 3))
            g.box(i, j0, -1, i + 1, j0 + h, 1, colours[int(u * 97) % len(colours)])
    a.part("shelf", g)
    return a


def workbench():
    """A 2 m workshop bench facing -z: a thick wooden top at 0.9 m on
    charcoal legs with a lower shelf, a pegboard on the +z side with tools,
    and parts on the top (a toolbox, a small blue-and-orange model)."""
    a = Asset("workbench")
    g = new()
    g.box(-10, 8, -4, 10, 9, 4, "wood")
    g.box(-10, 7, -4, 10, 8, 4, "wood_dark")
    for (i, k) in ((-10, -4), (9, -4), (-10, 3), (9, 3)):
        g.box(i, 0, k, i + 1, 7, k + 1, "charcoal")
    g.box(-9, 2, -3, 9, 3, 3, "wood_dark")
    g.box(-10, 9, 3, 10, 18, 4, "cream")
    for (i, j, key) in ((-8, 13, "charcoal"), (-5, 12, "orange"), (-2, 14, "steel"), (2, 12, "charcoal"),
                        (5, 13, "blue"), (8, 14, "orange_dark")):
        g.box(i, j, 2, i + 1, j + 3, 3, key)
    g.box(-8, 9, -2, -4, 11, 1, "book_red")
    g.box(-8, 11, -2, -4, 12, 1, "charcoal")
    g.box(1, 9, -2, 5, 10, 1, "steel")
    g.box(2, 10, -1, 4, 12, 0, "blue")
    g.box(3, 12, -1, 5, 13, 0, "orange")
    g.box(-2, 3, -2, 1, 5, 1, "orange")
    a.part("bench", g)
    return a


def path_garden():
    """A 2 m park tile: lawn with a light gravel path 1.2 m wide along x
    and a few stepping-stone edges."""
    a = Asset("path_garden")
    g = new()
    for i in range(-10, 10):
        for k in range(-10, 10):
            edge = abs(k + 0.5) - 6 + (1 if unit("edge", i // 2, k > 0) < 0.4 else 0)
            if edge < 0:
                key = "paving_light" if unit("gravel", i // 3, k // 3) < 0.7 else "kerb"
            else:
                key = "lawn_dark" if unit("lawn", i // 5, k // 5) < 0.3 else "lawn"
            g.put(i, -1, k, key)
    a.part("path", g)
    return a


ASSETS = {f.__name__: f for f in (
    tree_small, tree_medium, tree_large, shrub, planter, planter_long, flowerbed, bench, lamp, bollard, railing, railing_post,
    cafe_table, cafe_chair, umbrella, reading_chair, bookshelf, workbench, path_garden,
)}
