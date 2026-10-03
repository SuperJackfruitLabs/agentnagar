"""cut_sheet.py SHEET.png OUT_DIR [--cells COLSxROWS] [--min-share F] [--clear-outside]: finds the objects on a design sheet
(things drawn alone on a plain grey backdrop) and saves each as a square crop for the image-to-3D model.

A design sheet's backdrop is grey with a soft gradient and contact shadows. A pixel is taken for the object when
it has colour (chroma) or is clearly lighter or much darker than the backdrop around it; near-grey pixels a
little darker than the backdrop are shadow and stay backdrop. Connected pixels are one piece; small flat squares
(the colour swatches) are dropped. With --cells the pieces are gathered by the grid cell their centre lies in,
so an object in several pieces (an exploded kit, a chair seen through its legs) stays one crop.

Writes OUT_DIR/obj-<k>.png (the crop on the sheet's own backdrop, square, with a margin), OUT_DIR/boxes.json
and OUT_DIR/found.png (the sheet with the boxes drawn, to check by eye). Also OUT_DIR/obj-<k>-clean.png: the
same crop with everything that is not the object painted over with the backdrop (the swatches under it, the
edge of a neighbour). The image-to-3D model makes slabs and lumps of those when they are left in.
Swatches drawn touching one another in a row (a strip under a tree) are found as a strip and split by colour.
With --clear-outside the cleaned crop also has everything outside the object's own box replaced by the modelled
backdrop, feathered: a grey swatch on the grey backdrop is not found as a piece and would otherwise stay.
And OUT_DIR/obj-<k>-matte.png: the cleaned crop with the object already cut out of it (an alpha channel). The
image-to-3D model removes the backdrop itself when it is given none, and its matting takes grey glass for
backdrop: a shelter's panes came back as an open frame. Here the object is what this script found, and a
large patch of near-backdrop that the object closes in on every side (a pane in its frame) is kept with it;
a small one (the gap between a bench's legs) and whatever is open to the backdrop on any side is not.
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np


def backdrop_model(lab):
    """The backdrop's lightness as a smooth surface over the sheet: a quadratic fitted to the near-grey pixels
    close to the border's median lightness."""
    h, w = lab.shape[:2]
    L = lab[..., 0].astype(np.float64)
    chroma = np.hypot(lab[..., 1].astype(np.float64) - 128, lab[..., 2].astype(np.float64) - 128)
    ring = np.concatenate([L[:12].ravel(), L[-12:].ravel(), L[:, :12].ravel(), L[:, -12:].ravel()])
    base = np.median(ring)
    ys, xs = np.mgrid[0:h:4, 0:w:4]
    sample = (chroma[::4, ::4] < 6) & (np.abs(L[::4, ::4] - base) < 18)
    x = xs[sample] / w - 0.5
    y = ys[sample] / h - 0.5
    A = np.stack([np.ones_like(x), x, y, x * x, y * y, x * y], axis=1)
    coef, *_ = np.linalg.lstsq(A, L[::4, ::4][sample], rcond=None)
    yy, xx = np.mgrid[0:h, 0:w]
    xf, yf = xx / w - 0.5, yy / h - 0.5
    return coef[0] + coef[1] * xf + coef[2] * yf + coef[3] * xf * xf + coef[4] * yf * yf + coef[5] * xf * yf, chroma


def object_mask(img):
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    bg, chroma = backdrop_model(lab)
    L = lab[..., 0].astype(np.float64)
    d = L - bg
    # OpenCV's 8-bit Lab: L is 0..255. Coloured, or lighter than the backdrop, or much darker than a shadow gets.
    fg = (chroma > 9) | (d > 14) | (d < -60)
    fg = cv2.morphologyEx(fg.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    return fg


def pieces(mask, min_area):
    n, labels, stats, centres = cv2.connectedComponentsWithStats(mask, connectivity=8)
    out = []
    for k in range(1, n):
        x, y, w, h, area = stats[k]
        if area >= min_area:
            out.append({"box": [int(x), int(y), int(x + w), int(y + h)], "area": int(area), "centre": [float(centres[k][0]), float(centres[k][1])], "label": k})
    return out, labels


def is_swatch(piece, img):
    x0, y0, x1, y1 = piece["box"]
    w, h = x1 - x0, y1 - y0
    if not (0.75 < w / max(h, 1) < 1.33) or piece["area"] < 0.9 * w * h:
        return False                      # not a filled square
    patch = img[y0 + h // 5: y1 - h // 5, x0 + w // 5: x1 - w // 5].reshape(-1, 3).astype(np.float64)
    return patch.std(axis=0).max() < 14   # one flat colour (a plank-lined swatch stays flat enough)


def swatch_strip(piece, img, sheet_width):
    """The swatches of a row drawn touching one another, as [box, ...] left to right, or None if the piece is
    not such a strip: a filled rectangle wider than high, no higher than 6% of the sheet's width, each of its
    columns one flat colour from top to bottom, that falls into two or more runs of one colour."""
    x0, y0, x1, y1 = piece["box"]
    w, h = x1 - x0, y1 - y0
    if h > 0.06 * sheet_width or w < 1.33 * h or piece["area"] < 0.85 * w * h:
        return None
    core = img[y0 + h // 4: y1 - h // 4, x0:x1].astype(np.float64)
    if np.median(core.std(axis=0).max(axis=1)) > 14:
        return None                       # its columns are not flat: something drawn, not swatches
    column = core.mean(axis=0)            # the colour of each column
    cuts = [0] + [i for i in range(1, w) if np.abs(column[i] - column[i - 1]).max() > 16] + [w]
    runs = [(a, b) for a, b in zip(cuts, cuts[1:]) if b - a >= 0.5 * h]
    if len(runs) < 2:
        return None
    return [[x0 + a, y0, x0 + b, y1] for a, b in runs]


def like_a_swatch(piece, sheet_width):
    """A looser test, for painting out only: a small filled square, whatever is on it (a swatch drawn with a
    sheen is not one flat colour, and is_swatch lets it through as part of the object above it)."""
    x0, y0, x1, y1 = piece["box"]
    w, h = x1 - x0, y1 - y0
    return 0.8 < w / max(h, 1) < 1.25 and piece["area"] >= 0.9 * w * h and max(w, h) <= 0.085 * sheet_width


def merge(boxes):
    return [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)]


def square_crop(img, box, margin=0.08):
    h, w = img.shape[:2]
    x0, y0, x1, y1 = box
    side = int(max(x1 - x0, y1 - y0) * (1 + 2 * margin))
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    # The crop's backdrop: the sheet's own colour at the box's corners, so an out-of-sheet margin does not show.
    fill = np.median(np.concatenate([img[:8].reshape(-1, 3), img[-8:].reshape(-1, 3)]), axis=0)
    out = np.empty((side, side, 3), np.uint8)
    out[:] = fill
    sx0, sy0 = cx - side // 2, cy - side // 2
    ax0, ay0, ax1, ay1 = max(sx0, 0), max(sy0, 0), min(sx0 + side, w), min(sy0 + side, h)
    out[ay0 - sy0: ay1 - sy0, ax0 - sx0: ax1 - sx0] = img[ay0:ay1, ax0:ax1]
    return out


def matte_of(labels, mine, box, least=0.015):
    """The object's own cut-out as an alpha mask over the whole sheet: its pieces, and each patch that is not
    object but is closed in by it on every side and covers at least `least` of the object's box."""
    own = np.isin(labels, list(mine)).astype(np.uint8)
    own = cv2.morphologyEx(own, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    x0, y0, x1, y1 = box
    pad = 6
    window = np.zeros((y1 - y0 + 2 * pad, x1 - x0 + 2 * pad), np.uint8)
    inner = own[max(y0, 0):y1, max(x0, 0):x1]
    window[pad:pad + inner.shape[0], pad:pad + inner.shape[1]] = inner
    n, holes = cv2.connectedComponents((window == 0).astype(np.uint8), connectivity=4)
    outside = holes[0, 0]
    kept = 0
    for label in range(1, n):
        if label == outside:
            continue
        patch = holes == label
        if patch.sum() >= least * (x1 - x0) * (y1 - y0):
            window[patch] = 1
            kept += 1
    own[max(y0, 0):y1, max(x0, 0):x1] = window[pad:pad + inner.shape[0], pad:pad + inner.shape[1]]
    alpha = cv2.GaussianBlur(own.astype(np.float32) * 255, (3, 3), 0)
    return alpha.round().astype(np.uint8), kept


def square_crop_alpha(alpha, box, margin=0.08):
    """`square_crop` for a one-channel mask: what lies off the sheet is empty."""
    h, w = alpha.shape[:2]
    x0, y0, x1, y1 = box
    side = int(max(x1 - x0, y1 - y0) * (1 + 2 * margin))
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    out = np.zeros((side, side), np.uint8)
    sx0, sy0 = cx - side // 2, cy - side // 2
    ax0, ay0, ax1, ay1 = max(sx0, 0), max(sy0, 0), min(sx0 + side, w), min(sy0 + side, h)
    out[ay0 - sy0: ay1 - sy0, ax0 - sx0: ax1 - sx0] = alpha[ay0:ay1, ax0:ax1]
    return out


def outside_cleared(img, box, margin=0.04, feather=31):
    """`img` with everything outside `box` (widened by `margin` of its longer side) replaced by the modelled
    backdrop, the change feathered over a few pixels."""
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    bg, _chroma = backdrop_model(lab)
    ring = np.concatenate([lab[:12].reshape(-1, 3), lab[-12:].reshape(-1, 3), lab[:, :12].reshape(-1, 3), lab[:, -12:].reshape(-1, 3)])
    plain = np.empty_like(lab)
    plain[..., 0] = np.clip(bg, 0, 255).astype(np.uint8)
    plain[..., 1], plain[..., 2] = np.median(ring[:, 1]), np.median(ring[:, 2])
    plain = cv2.cvtColor(plain, cv2.COLOR_LAB2BGR)
    x0, y0, x1, y1 = box
    pad = int(margin * max(x1 - x0, y1 - y0))
    inside = np.zeros(img.shape[:2], np.float32)
    inside[max(y0 - pad, 0): y1 + pad, max(x0 - pad, 0): x1 + pad] = 1.0
    inside = cv2.GaussianBlur(inside, (feather, feather), 0)[..., None]
    return (img.astype(np.float32) * inside + plain.astype(np.float32) * (1 - inside)).round().astype(np.uint8)


def painted_out(img, labels, keep, others):
    """The sheet with the pieces `others` (label numbers) painted over from the backdrop round them, the pieces
    `keep` untouched. Each piece's mask is widened a little so that its soft edge and outline go too."""
    gone = np.isin(labels, list(others)).astype(np.uint8)
    gone = cv2.dilate(gone, np.ones((15, 15), np.uint8))
    stay = cv2.dilate(np.isin(labels, list(keep)).astype(np.uint8), np.ones((5, 5), np.uint8))
    gone[stay > 0] = 0
    return cv2.inpaint(img, gone * 255, 7, cv2.INPAINT_TELEA)


def main(argv):
    sheet, out = Path(argv[0]), Path(argv[1])
    cells = None
    if "--cells" in argv:
        c, r = argv[argv.index("--cells") + 1].split("x")
        cells = (int(c), int(r))
    min_share = float(argv[argv.index("--min-share") + 1]) if "--min-share" in argv else 0.004
    out.mkdir(parents=True, exist_ok=True)
    img = cv2.imread(str(sheet), cv2.IMREAD_COLOR)
    h, w = img.shape[:2]
    mask = object_mask(img)
    found, labels = pieces(mask, min_area=int(0.0004 * w * h))
    swatches = [p for p in found if is_swatch(p, img)]
    strips = {p["label"]: swatch_strip(p, img, w) for p in found if not is_swatch(p, img)}
    strips = {label: boxes for label, boxes in strips.items() if boxes}
    objects = [p for p in found if not is_swatch(p, img) and p["label"] not in strips]
    swatches += [{"box": box} for boxes in strips.values() for box in boxes]
    clear_outside = "--clear-outside" in argv
    groups = []
    if cells:
        cols, rows = cells
        by_cell = {}
        for p in objects:
            key = (min(int(p["centre"][1] / h * rows), rows - 1), min(int(p["centre"][0] / w * cols), cols - 1))
            by_cell.setdefault(key, []).append(p)
        for key in sorted(by_cell):
            groups.append({"cell": list(key), "box": merge([p["box"] for p in by_cell[key]]), "area": sum(p["area"] for p in by_cell[key]), "pieces": len(by_cell[key]),
                           "labels": [p["label"] for p in by_cell[key]]})
    else:
        for p in sorted(objects, key=lambda p: -p["area"]):
            if p["area"] >= min_share * w * h:
                groups.append({"box": p["box"], "area": p["area"], "pieces": 1, "labels": [p["label"]]})
    shown = img.copy()
    for s in swatches:
        cv2.rectangle(shown, tuple(s["box"][:2]), tuple(s["box"][2:]), (255, 0, 255), 2)
    record = {"sheet": sheet.name, "size": [w, h], "objects": [], "swatches": []}
    every = {p["label"] for p in found}
    loose_swatches = {p["label"] for p in found if like_a_swatch(p, w)}
    for k, g in enumerate(groups):
        mine = set(g.pop("labels")) - loose_swatches
        cv2.imwrite(str(out / f"obj-{k}.png"), square_crop(img, g["box"]))
        clean = painted_out(img, labels, mine, every - mine)
        if clear_outside:
            clean = outside_cleared(clean, g["box"])
        cv2.imwrite(str(out / f"obj-{k}-clean.png"), square_crop(clean, g["box"]))
        alpha, panes = matte_of(labels, mine, g["box"])
        cv2.imwrite(str(out / f"obj-{k}-matte.png"), np.dstack([square_crop(clean, g["box"]), square_crop_alpha(alpha, g["box"])]))
        g["closed_in_patches_kept"] = panes
        cv2.rectangle(shown, tuple(g["box"][:2]), tuple(g["box"][2:]), (0, 200, 0), 3)
        cv2.putText(shown, str(k), (g["box"][0] + 6, g["box"][1] + 34), cv2.FONT_HERSHEY_SIMPLEX, 1.1, (0, 200, 0), 3)
        record["objects"].append({"k": k, **g})
    for s in sorted(swatches, key=lambda s: (s["box"][1] // 40, s["box"][0])):
        x0, y0, x1, y1 = s["box"]
        patch = img[y0 + (y1 - y0) // 4: y1 - (y1 - y0) // 4, x0 + (x1 - x0) // 4: x1 - (x1 - x0) // 4].reshape(-1, 3).mean(axis=0)
        record["swatches"].append({"box": s["box"], "hex": "#%02X%02X%02X" % (int(round(patch[2])), int(round(patch[1])), int(round(patch[0])))})
    cv2.imwrite(str(out / "found.png"), shown)
    (out / "boxes.json").write_text(json.dumps(record, indent=1) + "\n")
    print(f"{sheet.name}: {len(groups)} objects, {len(swatches)} swatches -> {out}")
    for o in record["objects"]:
        print("  obj", o["k"], o["box"], "pieces", o["pieces"])
    print("  swatches:", " ".join(s["hex"] for s in record["swatches"]))


if __name__ == "__main__":
    main(sys.argv[1:])
