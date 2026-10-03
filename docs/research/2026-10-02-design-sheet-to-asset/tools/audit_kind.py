"""audit_kind.py CELLS.json OUT.png KIND [KIND...]: every placement of a kind laid over one another in the kind's own
frame, from what audit_cells.gd wrote: what the style draws in the walking band (grey; the first placement's), and
the centres of the cells round every placement: blocked ones the audit finds bare (blue), walkable ones it finds
touched (red), blocked ones with something near (black), walkable ones left clear (green), protected ones (yellow).
Prints, for each kind, the box of what is drawn and the worst bare and touched cells."""
import json
import os
import sys

from PIL import Image, ImageDraw

data = json.load(open(sys.argv[1]))
S = 5.0
tiles = []
for kind in sys.argv[3:]:
    places = {k: v for k, v in data["placements"].items() if v["kind"] == kind}
    if not places:
        continue
    pts = [(c[0], c[1]) for v in places.values() for c in v["cells"] if c[3] < 40 or c[2][0] != "W"]
    x0, x1 = min(p[0] for p in pts) - 12, max(p[0] for p in pts) + 12
    z0, z1 = min(p[1] for p in pts) - 12, max(p[1] for p in pts) + 12
    if os.environ.get("WINDOW"):                     # x0,z0,x1,z1 in the kind's frame, cm
        x0, z0, x1, z1 = (float(v) for v in os.environ["WINDOW"].split(","))
    im = Image.new("RGB", (int((x1 - x0) * S), int((z1 - z0) * S) + 24), (245, 244, 238))
    d = ImageDraw.Draw(im)
    to = lambda x, z: ((x - x0) * S, (z - z0) * S + 24)
    first = next(iter(places.values()))
    flat_all = [q for flat in first["drawn"] for q in flat]
    for flat in first["drawn"]:
        poly = [to(flat[i], flat[i + 1]) for i in range(0, len(flat), 2)]
        if len(poly) >= 3:
            d.polygon(poly, fill=(176, 176, 182))
        elif len(poly) == 2:
            d.line(poly, fill=(130, 130, 140), width=2)
    bare = touched = 0
    for pid, v in places.items():
        for x, z, state, near, gated in v["cells"]:
            if not (x0 < x < x1 and z0 < z < z1):
                continue
            cx, cy = to(x, z)
            if "r" in state:
                col, r = (30, 80, 230), 8
                bare += 1
            elif "t" in state or "n" in state:
                col, r = (220, 30, 30), 8
                touched += 1
            elif "o" in state:
                col, r = (220, 180, 0), 3
            elif state[0] == "B":
                col, r = (30, 30, 36), 3
            else:
                col, r = (70, 170, 80), 3
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=col)
    ox, oy = to(0, 0)
    d.line((ox - 10, oy, ox + 10, oy), fill=(0, 0, 0)); d.line((ox, oy - 10, ox, oy + 10), fill=(0, 0, 0))
    for g in range(int(x0 // 25) * 25, int(x1) + 1, 25):
        d.text((to(g, z0)[0], 12), str(g), fill=(90, 90, 90))
    for g in range(int(z0 // 25) * 25, int(z1) + 1, 25):
        d.text((2, to(x0, g)[1]), str(g), fill=(90, 90, 90))
    xs, zs = flat_all[0::2], flat_all[1::2]
    box = (min(xs), min(zs), max(xs), max(zs)) if xs else None
    d.text((4, 1), f"{data['style']} {kind}: {len(places)} placed, {bare} bare, {touched} touched; drawn {None if box is None else [round(b, 1) for b in box]}", fill=(0, 0, 0))
    print(data["style"], kind, "placed", len(places), "bare", bare, "touched", touched, "drawn box", None if box is None else [round(b, 1) for b in box])
    tiles.append(im)
w = sum(t.width for t in tiles) + 8 * (len(tiles) - 1)
sheet = Image.new("RGB", (w, max(t.height for t in tiles)), (255, 255, 255))
x = 0
for t in tiles:
    sheet.paste(t, (x, 0)); x += t.width + 8
sheet.save(sys.argv[2])
