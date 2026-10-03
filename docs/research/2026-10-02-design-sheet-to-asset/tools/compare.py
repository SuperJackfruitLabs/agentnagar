"""compare.py STYLE OUT.png ASSET [ASSET ...] [--views eye-0,above-0] [--before today] [--after new] [--height 420]
              [--clear] [--show ASSET=VIEW,VIEW ...] [--names "FIRST;SECOND"]

One row an asset: the design image it was built from, then the game today and the game with the new piece,
from each view. The game frames are cropped round the piece (its mask pass says where it is), the same crop for
today's and the new one, so the two are seen from the same place at the same size.

--clear: a view is of one placement of the piece (eye-0 is the first, eye-1 the second). Where something stands
between the camera and the piece in either capture (a new tree's crown over a shrub, a palm's frond before a
street tree), the next placement that is in the clear is shown instead, and the tile's label says which. A
placement counts as hidden when the piece fills less than 0.6 of what it fills at the middle one of that
capture's placements.
--show ASSET=VIEW,VIEW: these views for this one asset (a placement with a neighbour standing in the foreground
is not hidden by the measure above, and is passed over by hand). May be given more than once.
--names "FIRST;SECOND": what the two captures are called over their frames (default: today;new), for a sheet that
sets two builds of a piece side by side.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

W = Path(__file__).resolve().parent.parent
BG, INK = (246, 244, 239), (30, 30, 30)
FONT = next((p for p in ("/usr/share/fonts/noto/NotoSans-Regular.ttf", "/usr/share/fonts/TTF/DejaVuSans.ttf") if Path(p).exists()), None)


def font(size):
    return ImageFont.truetype(FONT, size) if FONT else ImageFont.load_default()


def mask_box(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    m = (a[..., 0] > 200) & (a[..., 1] < 80) & (a[..., 2] > 200)
    if not m.any():
        return None
    ys, xs = np.where(m)
    return [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]


def mask_share(path):
    if not path.exists():
        return None
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return float(((a[..., 0] > 200) & (a[..., 1] < 80) & (a[..., 2] > 200)).mean())


def in_the_clear(view, folders, taken):
    """`view`, or the first other placement of the same kind that is hidden in neither capture."""
    kind = view.rsplit("-", 1)[0]
    shares = {}                                           # placement -> [share in each capture]
    for i in range(12):
        got = [mask_share(f / f"asset-{kind}-{i}-mask.png") for f in folders]
        if any(g is None for g in got):
            break
        shares[f"{kind}-{i}"] = got
    if view not in shares or len(shares) < 2:
        return view
    middle = [float(np.median([s[c] for s in shares.values()])) for c in range(len(folders))]

    def clear(name):
        return all(shares[name][c] >= 0.6 * middle[c] for c in range(len(folders)))
    if clear(view):
        return view
    return next((n for n in shares if n != view and n not in taken and clear(n)), view)


def union(a, b):
    if a is None:
        return b
    if b is None:
        return a
    return [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])]


def framed(image, box, aspect=1.25, margin=0.35):
    """The frame cropped round `box` with a margin, at one aspect, kept inside the frame."""
    w, h = image.size
    bw, bh = box[2] - box[0], box[3] - box[1]
    cw = max(bw * (1 + 2 * margin), bh * (1 + 2 * margin) * aspect)
    ch = cw / aspect
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    x0 = min(max(cx - cw / 2, 0), max(w - cw, 0))
    y0 = min(max(cy - ch / 2, 0), max(h - ch, 0))
    return image.crop((int(x0), int(y0), int(min(x0 + cw, w)), int(min(y0 + ch, h))))


def fit_h(image, h):
    return image.resize((max(1, round(image.width * h / image.height)), h), Image.LANCZOS)


def main(argv):
    def opt(name, default):
        return argv[argv.index(name) + 1] if name in argv else default
    style, out = argv[0], Path(argv[1])
    shows = dict(argv[i + 1].split("=", 1) for i, x in enumerate(argv) if x == "--show")
    first, second = opt("--names", "today;new").split(";")
    given = (opt("--views", ""), opt("--before", ""), opt("--after", ""), opt("--height", ""), opt("--names", ""), *(f"{k}={v}" for k, v in shows.items()))
    assets = [a for a in argv[2:] if not a.startswith("--") and a not in given]
    views = opt("--views", "eye-0,above-0").split(",")
    before, after, height = opt("--before", "today"), opt("--after", "new"), int(opt("--height", "420"))
    moved = []
    config = json.loads((W / "work" / "assets.json").read_text())
    rows = []
    for key in assets:
        a = config["assets"][key]
        rev = a.get("rev", {}).get(style, "r001")
        design = W / "crops" / style / (a["sheet"] if rev == "r001" else f"{a['sheet']}@{rev}") / f"obj-{a['obj']}.png"
        tiles = [("design image", fit_h(Image.open(design).convert("RGB"), height))]
        own = shows[key].split(",") if key in shows else views
        for asked in own:
            b_dir, a_dir = W / "captures" / before / key / style, W / "captures" / after / key / style
            view = in_the_clear(asked, (b_dir, a_dir), own) if "--clear" in argv else asked
            if view != asked:
                moved.append(f"{key} {view} for {asked}")
            box = union(mask_box(b_dir / f"asset-{view}-mask.png"), mask_box(a_dir / f"asset-{view}-mask.png"))
            if box is None:
                continue
            for label, folder in ((f"{first} ({view})", b_dir), (f"{second} ({view})", a_dir)):
                tiles.append((label, fit_h(framed(Image.open(folder / f"asset-{view}.png").convert("RGB"), box), height)))
        gap, label_h = 12, 30
        width = sum(t.width for _, t in tiles) + gap * (len(tiles) - 1)
        row = Image.new("RGB", (width, height + label_h), BG)
        d = ImageDraw.Draw(row)
        x = 0
        for label, t in tiles:
            d.text((x + 2, 4), f"{key}: {label}" if x == 0 else label, fill=INK, font=font(19))
            row.paste(t, (x, label_h))
            x += t.width + gap
        rows.append(row)
    pad = 18
    sheet = Image.new("RGB", (max(r.width for r in rows) + 2 * pad, sum(r.height for r in rows) + pad * (len(rows) + 1)), BG)
    y = pad
    for r in rows:
        sheet.paste(r, (pad, y))
        y += r.height + pad
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"compare: {out} {sheet.size}" + (f"; hidden, so another placement: {', '.join(moved)}" if moved else ""))


if __name__ == "__main__":
    main(sys.argv[1:])
