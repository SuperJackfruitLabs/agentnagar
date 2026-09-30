"""Turns the raw Blender passes of one model into palette sprites.

render.py writes, per model, the passes post.py needs to light, colour,
outline and cut it without guessing:

  alpha  coverage (no anti-aliasing: every pixel is one face or nothing)
  mat    the face's material (palette.MATERIALS, 1-based; 0 = none)
  var    a per-face variation value, 0-255 (pavers, leaf clumps)
  cell   the 1 m world cell the face lies in (kx, kz, ky), Godot axes
  loc    the position inside that cell (fx, fz, fy), 0..1
  nrm    the (flat or smooth) normal, Blender axes

Godot axes: x east, z south, y up (metres, before the vertical squash).
From those, every pixel knows its world point, depth and normal, so:

1. **Light and quantise.** The material's albedo is lit by one sun
   (ambient + diffuse) and snapped to the nearest colour of its ramp in
   CIE Lab. Patterns (brick courses, seams, mullions, pavers), per-voxel
   noise and ordered dithering nudge L* first, where the material says so.
2. **Frames and inner lines.** Glass gets a frame where it meets another
   material; where a pixel stands well in front of its neighbour (a depth
   step), it becomes a line (navy, or the material's own line colour
   against itself, e.g. dark leaf between canopy clumps).
3. **Outline.** A 1 px `outline` ring outside the silhouette (4-neighbour),
   each ring pixel belonging to the cell of the pixel it outlines.
4. **Cut.** Each output takes the pixels of its cells, cropped, with its
   anchor: the pixel where its origin point (x, z, y) projects.

Night twins map every pixel through palette.NIGHT_MAP.
"""
import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import palette  # noqa: E402

MATERIAL_KEYS = list(palette.MATERIALS)
MATERIAL_INDEX = {k: i + 1 for i, k in enumerate(MATERIAL_KEYS)}
PAL_NAMES = palette.NAMES
PAL_RGB = np.array(palette.DAY, dtype=np.int32)
PAL_INDEX = {n: i for i, n in enumerate(PAL_NAMES)}

# The sun, toward the light, in Blender axes (x east, y north, z up): from
# the south-west and high, so south faces read light, east faces darker and
# tops lightest, as on the 08 sheets.
SUN = np.array([-0.42, -0.62, 1.0])
SUN = SUN / np.linalg.norm(SUN)
AMBIENT, DIFFUSE = 0.52, 0.62
K = math.sqrt(2.0 / 3.0)  # vertical squash: 1 m up is 16 px, as the pack's iso()
DEPTH_STEP = 0.35  # metres toward the camera that make an inner line
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0 - 0.5


# ---- Colour ----

def _lin(c):
    c = np.asarray(c, dtype=np.float64) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _srgb(lin):
    lin = np.clip(lin, 0.0, 1.0)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1 / 2.4) - 0.055) * 255.0


_M = np.array([[0.4124564, 0.3575761, 0.1804375],
               [0.2126729, 0.7151522, 0.0721750],
               [0.0193339, 0.1191920, 0.9503041]])
_WHITE = np.array([0.95047, 1.0, 1.08883])


def _lab_from_linear(lin):
    xyz = lin @ _M.T / _WHITE
    f = np.where(xyz > (6 / 29) ** 3, np.cbrt(xyz), xyz / (3 * (6 / 29) ** 2) + 4 / 29)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def lab(rgb):
    """CIE Lab (D65) of sRGB colour(s) 0-255."""
    return _lab_from_linear(_lin(rgb))


PAL_LAB = lab(PAL_RGB)


def nearest(rgb, names=None):
    """The palette colour (of `names`, default all) nearest `rgb` in Lab."""
    names = names or PAL_NAMES
    labs = np.array([PAL_LAB[PAL_INDEX[n]] for n in names])
    d = ((labs - lab(rgb)) ** 2).sum(-1)
    return palette.C[names[int(np.argmin(d))]]


def unit(v):
    v = np.asarray(v, dtype=np.float64)
    return tuple(v / np.linalg.norm(v))


# ---- Raw passes ----

def empty_raw(h, w, origin):
    return {
        "alpha": np.zeros((h, w), bool),
        "mat": np.zeros((h, w), np.int32),
        "var": np.full((h, w), 128, np.int32),
        "cell": np.zeros((h, w, 3), np.int32),
        "loc": np.full((h, w, 3), 0.5, np.float64),
        "nrm": np.tile(np.array([0.0, -1.0, 0.0]), (h, w, 1)),
        "origin": tuple(origin),
        "params": {},
    }


def load_raw(npz_path):
    with np.load(npz_path) as z:
        raw = {k: z[k] for k in z.files}
    meta = json.loads(Path(npz_path).with_suffix(".json").read_text())
    return {
        "alpha": raw["alpha"].astype(bool),
        "mat": raw["mat"].astype(np.int32),
        "var": raw["var"].astype(np.int32),
        "cell": raw["cell"].astype(np.int32),
        "loc": raw["loc"].astype(np.float64),
        "nrm": raw["nrm"].astype(np.float64),
        "origin": tuple(meta["origin"]),
        "params": meta.get("params", {}),
    }


# ---- Deterministic noise ----

def _hash(*ints):
    """A uint32 hash of integer arrays, in [0, 1)."""
    h = np.uint32(2166136261) * np.ones(np.broadcast(*ints).shape, np.uint32)
    for v in ints:
        h ^= np.asarray(v).astype(np.int64).astype(np.uint32)
        h *= np.uint32(16777619)
        h ^= h >> np.uint32(13)
        h *= np.uint32(0x5BD1E995)
        h ^= h >> np.uint32(15)
    return h.astype(np.float64) / 4294967296.0


# ---- Patterns: each returns (dL, step, force) over the material's pixels ----

class Ctx:
    """The pixels of one material: world point, normal, pixel position."""

    def __init__(self, x, y, z, n, px, py, var, params):
        self.x, self.y, self.z, self.n, self.px, self.py, self.var, self.params = x, y, z, n, px, py, var, params
        count = len(x)
        self.dl = np.zeros(count)
        self.step = np.zeros(count, np.int32)
        self.force = np.full(count, -1, np.int32)

    @property
    def vertical(self):
        return np.abs(self.n[:, 1]) < 0.5

    @property
    def up(self):
        return self.n[:, 1] > 0.5

    def along(self):
        """The horizontal coordinate along a vertical face (x on faces
        looking south or north, z on faces looking east or west)."""
        return np.where(np.abs(self.n[:, 2]) >= np.abs(self.n[:, 0]), self.x, self.z)

    def px16(self, v):
        return np.floor(v * 16.0 + 1e-6).astype(np.int64)


def _brick(c):
    v = c.vertical
    row = c.px16(c.y)
    course = row % 3 == 0
    a = c.px16(c.along()) + 3 * ((row // 3) % 2)
    joint = (a % 6 == 0) & ~course
    c.step[v & course] -= 1
    c.dl[v & joint] -= 7


def _ashlar(c):
    v = c.vertical
    row = c.px16(c.y)
    course = row % 8 == 0
    a = c.px16(c.along()) + 8 * ((row // 8) % 2)
    joint = (a % 16 == 0) & ~course
    c.dl[v & (course | joint)] -= 9


def _render(c):
    c.dl += (_hash(c.px16(c.x) // 3, c.px16(c.y) // 2, c.px16(c.z) // 3, 7) - 0.5) * 4


def _seams(c):
    # Standing seams down the slope, every half metre across it.
    across = np.where(np.abs(c.n[:, 0]) > np.abs(c.n[:, 2]), c.z, c.x)
    seam = c.px16(across) % 8 == 0
    c.step[seam & ~c.vertical] += 1


def _roof_tiles(c):
    grid = (c.px16(c.x) % 16 == 0) | (c.px16(c.z) % 16 == 0)
    c.step[grid & c.up] -= 1


def _dome_grid(c):
    cx, cz, cy = c.params.get("dome_centre", (0.0, 0.0, 0.0))
    r = c.params.get("dome_radius", 4.0)
    dx, dz, dy = c.x - cx, c.z - cz, (c.y - cy)
    lon = np.arctan2(dz, dx)
    horiz = np.hypot(dx, dz)
    lat = np.arctan2(dy, horiz)
    ribs = 20
    dlon = np.abs(((lon / (2 * np.pi) * ribs) + 0.5) % 1.0 - 0.5) * (2 * np.pi / ribs) * horiz
    rings = 5
    dlat = np.abs(((lat / (np.pi / 2) * rings) + 0.5) % 1.0 - 0.5) * (np.pi / 2 / rings) * r
    rib = (dlon * 16 < 0.55) | (dlat * 16 < 0.5)
    c.step[rib & (dy > 0.15)] += 1


def _mullions(c):
    a = c.px16(c.along())
    h = c.px16(c.y)
    bar = (a % 8 == 0) | (h % 16 == 0)
    c.force[bar] = PAL_INDEX["outline"]
    c.dl += np.where((h % 16) < 5, 6, 0)


def _panes(c):
    a = c.px16(c.along())
    h = c.px16(c.y)
    bar = (a % 16 == 0)
    c.force[bar] = PAL_INDEX["night_blue"]
    # A glint that stays light by day and night (window glass is lit at
    # night, so the glint must not be the window colour itself).
    sheen = ((c.px - c.py) % 11) == 0
    c.force[sheen & ~bar] = PAL_INDEX["lamp_light"]


def _tower_panes(c):
    a = c.px16(c.along())
    h = c.px16(c.y)
    pane = _hash(a // 16, h // 48, c.px16(c.x + c.z) // 64, 11)
    lit = pane > 0.86
    c.force[lit] = PAL_INDEX["window"]          # lit at night
    c.force[pane > 0.955] = PAL_INDEX["lamp"]   # lit day and night, as on the sheet
    c.step[(pane < 0.3) & ~lit] -= 1
    sheen = ((c.px - c.py) % 13) < 2
    c.force[sheen & ~lit] = PAL_INDEX["water_light"]


def _tram_panes(c):
    h = c.px16(c.y)
    top = c.params.get("pane_top", 2.6)
    upper = h >= int((top - 0.55) * 16)
    c.force[upper] = PAL_INDEX["window"]
    heads = (_hash(c.px16(c.along()) // 5, 5) > 0.55) & (h >= int((top - 1.0) * 16)) & ~upper
    c.force[heads] = PAL_INDEX["outline"]


def _planks(c):
    grain = (c.px16(c.along()) % 5 == 0) & c.vertical
    c.dl[grain] -= 5


def _sign(c):
    a = c.px16(c.along())
    h = c.px16(c.y)
    letters = (_hash(a // 2, 1) > 0.35) & (h % 6 >= 2) & (h % 6 <= 3) & c.vertical
    c.force[letters] = PAL_INDEX["white"]


def _stripes(c):
    mode = c.params.get("stripes", "along")
    if mode == "angle":
        cx, cz = c.params.get("stripe_centre", (0.0, 0.0))
        k = np.floor((np.arctan2(c.z - cz, c.x - cx) / (2 * np.pi) + 0.5) * c.params.get("stripe_count", 12))
    else:
        k = np.floor(c.along() * 2 + 1e-6)
    c.force[:] = np.where(k % 2 == 0, PAL_INDEX["yellow"], PAL_INDEX["white"])
    shade = c.n[:, 1] < 0.35
    c.force[shade & (k % 2 == 0)] = PAL_INDEX["brick_light"]
    c.force[shade & (k % 2 == 1)] = PAL_INDEX["sand"]


FLOWERS = ["red", "yellow", "white", "purple", "brick_light", "lamp_light"]


def _flowers(c):
    vx, vy, vz = (np.floor(v * 10 + 1e-6) for v in (c.x, c.y, c.z))
    h = _hash(vx, vy, vz, 17)
    pick = (h > 0.55) & (c.n[:, 1] > 0.1)
    which = (_hash(vx, vz, 23) * len(FLOWERS)).astype(np.int64)
    for i, name in enumerate(FLOWERS):
        c.force[pick & (which == i)] = PAL_INDEX[name]


def _bark(c):
    streak = _hash(c.px16(c.x + c.z) // 1, c.px16(c.y) // 5, 29) > 0.72
    c.step[streak] -= 1


def _rings(c):
    c.step[c.px16(c.y) % 5 == 0] -= 1


def _grass(c):
    tuft = _hash(c.px16(c.x) // 2, c.px16(c.z), 31) > 0.9
    c.step[tuft] -= 1


def _pavers(c):
    seed = c.params.get("seed", 0)
    joint = (c.px16(c.x) % 8 == 0) | (c.px16(c.z) % 8 == 0)
    # Half-metre slabs; now and then one a shade warmer, like the sheet.
    slab = _hash(np.floor(c.x * 2 + 1e-6), np.floor(c.z * 2 + 1e-6), seed)
    c.step[(slab > 0.78) & ~joint] -= 1
    c.step[joint] -= 1


def _kerb(c):
    joint = c.px16(c.along()) % 8 == 0
    c.dl[joint & c.vertical] -= 10


def _ripples(c):
    frame = c.params.get("frame", 0)
    seed = c.params.get("seed", 0)
    X = c.px16(c.x - c.z)            # screen-ish columns, 2 per px step
    Y = c.px16(c.x + c.z)            # screen-ish rows
    row = Y // 2
    run = (X + row * 5 + frame * 3) // 6
    crest = (_hash(run, row, seed) > 0.87) & (row % 3 == 0)
    c.force[crest] = PAL_INDEX["water_light"]
    trough = (_hash(run, row, seed + 1) > 0.9) & (row % 3 == 1)
    c.force[trough & ~crest] = PAL_INDEX["water_dark"]


def _boards(c):
    # Floorboards along x, a quarter metre wide, ends staggered by board.
    row = c.px16(c.z) // 4
    seam = c.px16(c.z) % 4 == 0
    end = (c.px16(c.x) + 7 * row) % 24 == 0
    c.step[seam | end] -= 1
    c.dl += (_hash(row, (c.px16(c.x) + 7 * row) // 24, 5) - 0.5) * 8


def _carpet(c):
    # A red library carpet with a border and a small lozenge motif.
    u = c.px16(c.x) % 16
    v = c.px16(c.z) % 16
    motif = (np.abs(u - 8) + np.abs(v - 8)) == 5
    c.step[motif] += 1
    c.step[(u == 0) | (v == 0)] -= 1


PATTERNS = {
    "brick": _brick, "ashlar": _ashlar, "render": _render, "seams": _seams, "roof_tiles": _roof_tiles,
    "dome_grid": _dome_grid, "mullions": _mullions, "panes": _panes, "tower_panes": _tower_panes,
    "tram_panes": _tram_panes, "planks": _planks, "sign": _sign, "stripes": _stripes,
    "flowers": _flowers, "bark": _bark, "rings": _rings, "grass": _grass, "pavers": _pavers,
    "kerb": _kerb, "ripples": _ripples, "boards": _boards, "carpet": _carpet,
}


# ---- Compose ----

def _ramp_position(points, ramp_lab):
    """Each Lab point's continuous position along the ramp (0 = darkest):
    its projection on the nearest segment between successive ramp colours.
    Rounding it gives the nearer of that segment's two ends in Lab."""
    if len(ramp_lab) == 1:
        return np.zeros(len(points))
    best_d = np.full(len(points), np.inf)
    best_t = np.zeros(len(points))
    for i in range(len(ramp_lab) - 1):
        a, b = ramp_lab[i], ramp_lab[i + 1]
        ab = b - a
        f = np.clip(((points - a) @ ab) / float(ab @ ab), 0.0, 1.0)
        d = ((points - (a + f[:, None] * ab)) ** 2).sum(-1)
        # Beyond either end of the ramp, keep extrapolating so offsets act.
        if i == 0:
            f = np.where(f <= 0.0, ((points - a) @ ab) / float(ab @ ab), f)
        if i == len(ramp_lab) - 2:
            f = np.where(f >= 1.0, ((points - a) @ ab) / float(ab @ ab), f)
        better = d < best_d
        best_d = np.where(better, d, best_d)
        best_t = np.where(better, i + f, best_t)
    return best_t


def _neighbours(a):
    """The four neighbours of a 2-D array (edge-padded): up, down, left, right."""
    p = np.pad(a, ((1, 1), (1, 1)) + ((0, 0),) * (a.ndim - 2), mode="edge")
    return [p[:-2, 1:-1], p[2:, 1:-1], p[1:-1, :-2], p[1:-1, 2:]]


def compose(raw, outline=True):
    """Lights, quantises, frames, lines and outlines one render (in navy,
    or in the palette colour `outline` names: a meadow's clumps in their
    own dark green, so a field of them is not netted in navy). Returns
    {rgba (H, W, 4) uint8, cell (H, W, 3), origin}."""
    alpha = raw["alpha"]
    h, w = alpha.shape
    ox, oy = raw["origin"]
    cell = raw["cell"].astype(np.float64)
    loc = raw["loc"]
    x = cell[..., 0] + loc[..., 0]
    z = cell[..., 1] + loc[..., 1]
    y = cell[..., 2] + loc[..., 2]
    depth = 0.6123724 * (x + z) + 0.5 * K * y
    nb = raw["nrm"]
    n_godot = np.stack([nb[..., 0], nb[..., 2], -nb[..., 1]], -1)  # (x east, y up, z south)
    lengths = np.linalg.norm(nb, axis=-1, keepdims=True)
    nb = nb / np.where(lengths > 1e-9, lengths, 1.0)
    n_godot = n_godot / np.where(lengths > 1e-9, lengths, 1.0)
    pys, pxs = np.mgrid[0:h, 0:w]
    index = np.full((h, w), -1, np.int32)
    mat = np.where(alpha, raw["mat"], 0)
    for mi in sorted(set(np.unique(mat)) - {0}):
        spec = palette.MATERIALS[MATERIAL_KEYS[mi - 1]]
        sel = mat == mi
        ramp = spec["ramp"]
        ramp_lab = np.array([PAL_LAB[PAL_INDEX[r]] for r in ramp])
        order = np.argsort(ramp_lab[:, 0])
        ramp = [ramp[i] for i in order]
        ramp_lab = ramp_lab[order]
        base = spec.get("base", ramp[len(ramp) // 2])
        albedo = _lin(palette.C[base])
        nn = nb[sel]
        if spec.get("flat"):
            light = np.ones(len(nn))
        else:
            amb, dif = spec.get("light", (AMBIENT, DIFFUSE))
            light = amb + dif * np.clip(nn @ SUN, 0.0, None)
        lit = _lab_from_linear(albedo[None, :] * light[:, None])
        ctx = Ctx(x[sel], y[sel], z[sel], n_godot[sel], pxs[sel] - ox, pys[sel] - oy, raw["var"][sel],
                  raw.get("params", {}))
        if spec.get("pattern"):
            PATTERNS[spec["pattern"]](ctx)
        gap = float(np.mean(np.diff(ramp_lab[:, 0]))) if len(ramp) > 1 else 1.0
        t = _ramp_position(lit, ramp_lab)
        dl = ctx.dl
        if spec.get("noise"):
            vox = [np.floor(v * 8 + 1e-6) for v in (ctx.x, ctx.y, ctx.z)]
            dl = dl + (_hash(*vox, mi) - 0.5) * spec["noise"]
        if spec.get("var"):
            dl = dl + (ctx.var / 255.0 - 0.5) * spec["var"]
        t = t + dl / max(gap, 1e-6)
        if spec.get("dither"):
            t = t + BAYER[(ctx.py % 4), (ctx.px % 4)] * spec["dither"]
        pick = np.clip(np.floor(t + 0.5).astype(np.int64) + ctx.step, 0, len(ramp) - 1)
        chosen = np.array([PAL_INDEX[r] for r in ramp])[pick]
        chosen = np.where(ctx.force >= 0, ctx.force, chosen)
        index[sel] = chosen
    # Frames: framed materials bordering anything else.
    up, down, left, right = _neighbours(mat)
    for mi in sorted(set(np.unique(mat)) - {0}):
        frame = palette.MATERIALS[MATERIAL_KEYS[mi - 1]].get("frame")
        if frame:
            sel = mat == mi
            edge = sel & ((up != mi) | (down != mi) | (left != mi) | (right != mi))
            index[edge] = PAL_INDEX[frame]
    # Inner lines: a pixel well in front of an opaque neighbour.
    dn = _neighbours(np.where(alpha, depth, -1e9))
    mn = _neighbours(mat)
    line_same = np.full((h, w), PAL_INDEX["outline"], np.int32)
    step_same = np.full((h, w), DEPTH_STEP)
    for mi in sorted(set(np.unique(mat)) - {0}):
        spec = palette.MATERIALS[MATERIAL_KEYS[mi - 1]]
        if spec.get("line"):
            line_same[mat == mi] = PAL_INDEX[spec["line"]]
        if spec.get("line_step"):
            step_same[mat == mi] = spec["line_step"]
    # A "family" shares a line colour (leaf clusters and the dark core):
    # lines inside a family use its colour and step, others are navy.
    fam_n = _neighbours(line_same)
    for dq, mq, fq in zip(dn, mn, fam_n):
        same = (mq == mat) | ((fq == line_same) & (line_same != PAL_INDEX["outline"]))
        step = alpha & (dq > -1e8) & (depth - dq > np.where(same, step_same, DEPTH_STEP))
        index[step] = np.where(same[step], line_same[step], PAL_INDEX["outline"])
    cells = raw["cell"].copy()
    # Each pixel's ground point (x, z), for cutting a sprite by where it is
    # (cut's `rim`); an outline pixel takes its neighbour's.
    ground = np.stack([x, z], -1)
    if outline:
        best = np.full((h, w), -1e9)
        ring = np.zeros((h, w), bool)
        an = _neighbours(alpha)
        cn = _neighbours(cells)
        gn = _neighbours(ground)
        for aq, dq, cq, gq in zip(an, dn, cn, gn):
            take = ~alpha & aq & (dq > best)
            ring |= take
            best = np.where(take, dq, best)
            cells[take] = cq[take]
            ground[take] = gq[take]
        index[ring] = PAL_INDEX[outline if isinstance(outline, str) else "outline"]
    rgba = np.zeros((h, w, 4), np.uint8)
    solid = index >= 0
    rgba[solid, :3] = PAL_RGB[index[solid]]
    rgba[solid, 3] = 255
    return {"rgba": rgba, "cell": cells, "ground": ground, "origin": (ox, oy)}


def iso(x, z, y=0.0):
    """Pixel offset of a point from the model origin, as the pack's iso()."""
    return (round((x - z) * 16.0), round((x + z) * 8.0 - y * 16.0))


def cut(comp, outputs):
    """[(path, rgba, anchor)] for each output: the pixels whose cell is in
    its ranges ({"x"|"z"|"y": [lo, hi]} inclusive, Godot axes), cropped,
    with the anchor where its origin point projects. An output's `rim`
    ({"r", "back"}) cuts a round piece across the view: its back rim is the
    pixels at `r` metres or more from the middle and behind the line
    x + z = 0; the front is the rest."""
    rgba, cells = comp["rgba"], comp["cell"]
    ox, oy = comp["origin"]
    solid = rgba[:, :, 3] > 0
    out = []
    for o in outputs:
        sel = solid.copy()
        for axis, (lo, hi) in o.get("cells", {}).items():
            c = cells[:, :, "xzy".index(axis)]
            sel &= (c >= lo) & (c <= hi)
        if "rim" in o:
            gx, gz = comp["ground"][:, :, 0], comp["ground"][:, :, 1]
            back = (gx + gz < 0.0) & (np.hypot(gx, gz) >= o["rim"]["r"])
            sel &= back if o["rim"]["back"] else ~back
        if not sel.any():
            raise ValueError(f"{o['path']}: no pixels in cells {o.get('cells')}")
        dx, dy = iso(*o.get("origin", (0, 0, 0)))
        if o.get("box"):
            # A fixed canvas around the anchor (tiles: 32 x 16 around the centre).
            bl, bt, bw, bh = o["box"]
            x0, y0 = ox + dx + bl, oy + dy + bt
            x1, y1 = x0 + bw, y0 + bh
            ys, xs = np.nonzero(sel)
            if xs.min() < x0 or xs.max() >= x1 or ys.min() < y0 or ys.max() >= y1:
                raise ValueError(f"{o['path']}: pixels outside its box {o['box']}")
        else:
            ys, xs = np.nonzero(sel)
            x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        img = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        # A fixed box may reach past the render's edge: copy what overlaps.
        cy0, cx0 = max(y0, 0), max(x0, 0)
        cy1, cx1 = min(y1, rgba.shape[0]), min(x1, rgba.shape[1])
        m = sel[cy0:cy1, cx0:cx1]
        img[cy0 - y0:cy1 - y0, cx0 - x0:cx1 - x0][m] = rgba[cy0:cy1, cx0:cx1][m]
        out.append((o["path"], img, (int(ox + dx - x0), int(oy + dy - y0))))
    return out


_NIGHT_LUT = {tuple(k): v for k, v in palette.NIGHT_MAP.items()}


def night(rgba):
    out = rgba.copy()
    solid = rgba[:, :, 3] > 0
    for day, dark in _NIGHT_LUT.items():
        m = solid & (rgba[:, :, 0] == day[0]) & (rgba[:, :, 1] == day[1]) & (rgba[:, :, 2] == day[2])
        out[m, :3] = dark
    return out


# ---- Files ----

def save_png(path, rgba):
    from PIL import Image
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(path, optimize=False)


def process(raw_dir, out_dir, kit, anchors, info=None):
    """Writes every output of every rendered model in `kit` (models.KIT):
    the sprite, its night twin and its anchor (relative path -> [x, y]).
    Outputs carrying `sheet: [col, row]` are frames pasted into one sheet
    at that cell (each frame's box is the cell size)."""
    raw_dir, out_dir = Path(raw_dir), Path(out_dir)
    written = []
    for spec in kit:
        npz = raw_dir / f"{spec['name']}.npz"
        raw = load_raw(npz)
        comp = compose(raw, outline=spec["outline"])
        sheets = {}
        for o, (path, rgba, anchor) in zip(spec["outputs"], cut(comp, spec["outputs"])):
            if "sheet" in o:
                sheets.setdefault(path, []).append((o, rgba, anchor))
                continue
            _write(out_dir, path, rgba)
            anchors[path] = [int(anchor[0]), int(anchor[1])]
            if info is not None:
                info[path] = dict(spec.get("info", {}), model=spec["name"], origin=list(o["origin"]),
                                  cells=o.get("cells", {}), size=[int(rgba.shape[1]), int(rgba.shape[0])])
                if "band_shapes" in info[path]:
                    info[path]["band_shapes"] = _about(info[path]["band_shapes"], o["origin"], info[path])
            written.append(path)
        for path, frames in sheets.items():
            h, w = frames[0][1].shape[:2]
            cols = 1 + max(o["sheet"][0] for o, _, _ in frames)
            rows = 1 + max(o["sheet"][1] for o, _, _ in frames)
            canvas = np.zeros((rows * h, cols * w, 4), np.uint8)
            for o, rgba, anchor in frames:
                if rgba.shape[:2] != (h, w):
                    raise ValueError(f"{path}: frames must share one size")
                c, r = o["sheet"]
                canvas[r * h:(r + 1) * h, c * w:(c + 1) * w] = rgba
            _write(out_dir, path, canvas)
            anchors[path] = [int(frames[0][2][0]), int(frames[0][2][1])]
            if info is not None:
                info[path] = dict(spec.get("info", {}), model=spec["name"], size=[cols * w, rows * h],
                                  frame=[w, h], grid=[cols, rows])
            written.append(path)
    return written


def _about(shapes, origin, info):
    """A model's band shapes (about its origin, before its turn) about a
    sprite's origin (x, z, y) cut from it: moved, for an unturned model."""
    x, z = origin[0], origin[1]
    if x == 0 and z == 0:
        return shapes
    if info.get("facing", 0) != 0:
        raise ValueError(f"{info['model']}: a turned model's sprites stand on its own origin")
    return [["rect", sh[1] - x, sh[2] - x, sh[3] - z, sh[4] - z] if sh[0] == "rect" else ["disc", sh[1], sh[2] - x, sh[3] - z]
            for sh in shapes]


def _write(out_dir, path, rgba):
    save_png(out_dir / path, rgba)
    save_png(out_dir / path.replace(".png", "_night.png"), night(rgba))
