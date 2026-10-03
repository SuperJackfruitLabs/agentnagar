"""tree_metrics.py [STYLE ...]: the great tree's crown from the street against its concept sheet, by the five
measures of the pilot's metrics.py (contrast, fine detail, colour variety, deep shadow, highlight; none of them
is what any colour was fitted to), for the game today, the asset-to-sheet pilot's rounds 1 and 2 (hand-built
from the kit's piece), the tree built from the first, night-lit sheet where a style has one, the tree held to
the kit's triangle limit, and the new tree.
Run from the working copy (game/), which holds inputs/ and captures/{before,after,round2,first-sheet,budget,new}.
A capture that shows a magenta placeholder (a piece the game failed to load) is refused."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

W = Path.cwd()
LUM = np.array([0.2126, 0.7152, 0.0722])
SHEET, STREET = (0.28, 0.12, 0.72, 0.52), (0.445, 0.13, 0.555, 0.36)
LABELS = (("today", "before"), ("round 1", "after"), ("round 2", "round2"), ("first sheet", "first-sheet"), ("at the limit", "budget"), ("new", "new"))


def look(path, box):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    a = np.asarray(im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h))).resize((256, 192), Image.LANCZOS)).astype(np.float64)
    lum = (a @ LUM) / 255
    grad = (np.abs(np.diff(lum, axis=0)).mean() + np.abs(np.diff(lum, axis=1)).mean()) / 2
    q = (a // 8).astype(np.int64).reshape(-1, 3)
    colours = len(np.unique(q[:, 0] * 1024 + q[:, 1] * 32 + q[:, 2]))
    med = np.median(lum)
    return {"contrast": round(float(lum.std()), 3), "detail": round(float(grad), 4), "colours": int(colours),
            "deep_shadow": round(float((lum < 0.5 * med).mean()), 3), "highlight": round(float((lum > 1.5 * med).mean()), 3)}


def placeholder(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return float(((a[..., 0] > 240) & (a[..., 1] < 30) & (a[..., 2] > 240)).mean()) > 0.0005


def distance(a, b):
    return round(float(np.mean([abs(np.log(max(a[k], 1e-3) / max(b[k], 1e-3))) for k in a])), 3)


rows = {}
for style in sys.argv[1:] or ["lowpoly_tropical", "neon_noir", "anime_cel", "solarpunk", "voxel"]:
    sheet = look(W / "inputs" / f"{style}-banyan.png", SHEET)
    rows[style] = {"concept": sheet}
    for label, folder in LABELS:
        path = W / "captures" / folder / style / "street.png"
        if not path.exists():
            continue
        if placeholder(path):
            sys.exit(f"{path} shows a magenta placeholder: a piece failed to load; capture again")
        m = look(path, STREET)
        m["distance"] = distance({k: m[k] for k in sheet}, sheet)
        rows[style][label] = m
(W / "tree-metrics.json").write_text(json.dumps(rows, indent=1) + "\n")
for style, r in rows.items():
    print(style)
    for label, m in r.items():
        print(f"  {label:12s} contrast {m['contrast']:.3f}  detail {m['detail']:.4f}  colours {m['colours']:4d}  deep shadow {m['deep_shadow']:.3f}  highlight {m['highlight']:.3f}"
              + (f"  | distance from the sheet {m['distance']:.3f}" if "distance" in m else ""))
