"""audit_plot.py CELLS.json OUT.png ID[,ID...]: a picture of what audit_cells.gd wrote for some placements, each in
its own frame: what the style draws in the walking band (grey), the catalogue footprint's cells as the grid has them
(blocked: dark dot; walkable: green dot; the seat's own cell: yellow; in the protected square: ringed), and the cells
the audit counts (red: through or within 10 cm; blue: blocked with nothing drawn near)."""
import json
import sys

from PIL import Image, ImageDraw

data = json.load(open(sys.argv[1]))
ids = sys.argv[3].split(",")
S = 4.0                                             # pixels a centimetre
tiles = []
for pid in ids:
    pl = data["placements"][pid]
    xs = [c[0] for c in pl["cells"]]
    zs = [c[1] for c in pl["cells"]]
    x0, x1, z0, z1 = min(xs) - 15, max(xs) + 15, min(zs) - 15, max(zs) + 15
    im = Image.new("RGB", (int((x1 - x0) * S), int((z1 - z0) * S) + 22), (245, 244, 238))
    d = ImageDraw.Draw(im)
    to = lambda x, z: ((x - x0) * S, (z - z0) * S + 22)
    for flat in pl["drawn"]:
        pts = [to(flat[i], flat[i + 1]) for i in range(0, len(flat), 2)]
        if len(pts) >= 3:
            d.polygon(pts, fill=(170, 170, 176))
        elif len(pts) == 2:
            d.line(pts, fill=(120, 120, 130), width=2)
    for x, z, state, near, gated in pl["cells"]:
        cx, cy = to(x, z)
        col = (60, 160, 70) if state[0] == "W" else (40, 40, 48) if state[0] == "B" else (230, 190, 0)
        r = 5
        if "t" in state or "n" in state:
            col, r = (220, 30, 30), 9
        if "r" in state:
            col, r = (30, 80, 230), 9
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=col)
        if "o" in state:
            d.ellipse((cx - 12, cy - 12, cx + 12, cy + 12), outline=(230, 190, 0), width=2)
        d.ellipse((cx - 10 * S, cy - 10 * S, cx + 10 * S, cy + 10 * S), outline=(200, 200, 205))
    ox, oy = to(0, 0)
    d.line((ox - 8, oy, ox + 8, oy), fill=(0, 0, 0)); d.line((ox, oy - 8, ox, oy + 8), fill=(0, 0, 0))
    d.text((4, 4), f"{data['style']} {pid} ({pl['kind']}, facing {pl['facing']:g})", fill=(0, 0, 0))
    tiles.append(im)
w = sum(t.width for t in tiles) + 8 * (len(tiles) - 1)
sheet = Image.new("RGB", (w, max(t.height for t in tiles)), (255, 255, 255))
x = 0
for t in tiles:
    sheet.paste(t, (x, 0)); x += t.width + 8
sheet.save(sys.argv[2])
print(sheet.size)
