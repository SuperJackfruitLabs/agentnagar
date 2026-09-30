"""Shared recipe helpers: metres to cells, a blocky sign font, and a few
shapes several recipes use (blocky canopies, window grids)."""
from voxel import VOXEL, Grid, unit


def m(metres):
    """Metres to cells at the kit's 10 cm voxel."""
    return int(round(metres / VOXEL))


# A 5 x 7 capital font, rows top to bottom.
FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    " ": ["00000"] * 7,
}


def text_width(word, gap=1, scale=1):
    return (len(word) * (5 + gap) - gap) * scale


def text(grid, word, j0, k, key, gap=1, depth=1, centre=0, scale=1):
    """Letters in the x-y plane, centred on column `centre`, baseline at
    j0, `depth` cells deep from k toward -z, each font pixel `scale` cells
    square. They read left to right from the -z side (a piece's front),
    which is toward -x."""
    right = centre + text_width(word, gap, scale) // 2
    for n, ch in enumerate(word):
        for r, row in enumerate(FONT[ch]):
            for c, bit in enumerate(row):
                if bit != "1":
                    continue
                for sx in range(scale):
                    for sy in range(scale):
                        for d in range(depth):
                            grid.put(right - ((n * (5 + gap) + c) * scale + sx), j0 + (6 - r) * scale + sy, k - d, key)


def canopy(grid, lobes, block, greens, seed, j_top=None):
    """A blocky canopy: `lobes` is a list of ellipsoids (ci, cj, ck, ri, rj,
    rk) in cells; every `block`-sized cube whose centre falls inside one is
    filled with one green, lighter toward the top and the sun side, darker
    underneath, with a stable hash deciding the rest. A few surface blocks
    are knocked out and a few extra stuck on, so the silhouette is ragged
    like the sheets' trees."""
    b = block
    filled = set()
    lo = [min(l[a] - l[a + 3] for l in lobes) for a in range(3)]
    hi = [max(l[a] + l[a + 3] for l in lobes) for a in range(3)]
    for bi in range(int(lo[0] // b) - 1, int(hi[0] // b) + 2):
        for bj in range(int(lo[1] // b) - 1, int(hi[1] // b) + 2):
            for bk in range(int(lo[2] // b) - 1, int(hi[2] // b) + 2):
                c = ((bi + 0.5) * b, (bj + 0.5) * b, (bk + 0.5) * b)
                for (ci, cj, ck, ri, rj, rk) in lobes:
                    d = ((c[0] - ci) / ri) ** 2 + ((c[1] - cj) / rj) ** 2 + ((c[2] - ck) / rk) ** 2
                    if d <= 1.0 + 0.35 * (unit(seed, "rag", bi, bj, bk) - 0.5):
                        filled.add((bi, bj, bk))
                        break
    top = max(bj for _, bj, _ in filled)
    bottom = min(bj for _, bj, _ in filled)
    dark, mid, light = greens
    for (bi, bj, bk) in sorted(filled):
        exposed_up = (bi, bj + 1, bk) not in filled
        h = (bj - bottom) / max(1, top - bottom)
        u = unit(seed, "shade", bi, bj, bk)
        if not exposed_up and (bi, bj - 1, bk) not in filled:
            key = dark
        elif exposed_up and h > 0.35 and u < 0.75:
            key = light
        elif h < 0.35 and u < 0.6:
            key = dark
        elif u < 0.2:
            key = dark
        elif u > 0.85:
            key = light
        else:
            key = mid
        grid.box(bi * b, bj * b, bk * b, bi * b + b, bj * b + b, bk * b + b, key)
    return filled


def new():
    return Grid(VOXEL)
