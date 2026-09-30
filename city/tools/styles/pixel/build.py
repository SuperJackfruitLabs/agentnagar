"""Builds the 08 pixel-art sprite kit into the Godot style pack.

python3 city/tools/styles/pixel/build.py [OUT_DIR]

Isometric 2:1: one metre east is (+16, +8) px, one metre south is (-16, +8),
one metre up is -16. Every sprite comes with a night twin (`*_night.png`)
made by mapping the palette, and every placed sprite's anchor (its ground
point) is written to anchors.json.

Two generators write into the pack:

* the hand-drawn Pillow status icons below;
* the pre-rendered kit (buildings/, scenery/, ground/, characters/): Blender models
  (models.py) rendered by render.py and turned into palette sprites by
  post.py. Its sprites' metadata (origins, sizes, conventions) goes to
  kit.json. This needs Blender 5.2 as `blender` (or $BLENDER).
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from palette import C, NIGHT_MAP  # noqa: E402

HERE = Path(__file__).resolve().parent

DEFAULT_OUT = Path(__file__).resolve().parents[3] / "godot" / "styles" / "pixel_art" / "assets"
T = (0, 0, 0, 0)


def rgba(name):
    return (*C[name], 255)


def save(out, rel, im, anchors=None, anchor=None):
    path = out / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=False)
    night = im.copy()
    px = night.load()
    for yy in range(night.height):
        for xx in range(night.width):
            r, g, b, a = px[xx, yy]
            if a:
                px[xx, yy] = (*NIGHT_MAP[(r, g, b)], 255)
    if not rel.startswith("icons/"):
        night.save(path.with_name(path.stem + "_night.png"), optimize=False)
    if anchors is not None and anchor is not None:
        anchors[rel] = list(anchor)


# ---- Tiles: 32 x 16 diamonds, one metre square ----

GLYPHS = {
    "working": ("yellow", ["........", "........", ".#.#.#..", "........", "........", "........", "........", "........"]),
    "waiting": ("teal", [".######.", "..####..", "...##...", "...##...", "..####..", ".######.", "........", "........"]),
    "queued": ("teal", ["........", "######..", "........", "######..", "........", "######..", "........", "........"]),
    "idle": ("leaf", ["#####...", "...#....", "..#.....", ".#......", "#####...", "........", "........", "........"]),
    "done": ("leaf_dark", ["........", "......#.", ".....#..", "#...#...", ".#.#....", "..#.....", "........", "........"]),
    "present": ("teal", ["........", "..###...", ".#####..", ".#####..", "..###...", "........", "........", "........"]),
    "offline": ("grey", ["..###...", ".#...#..", ".#...#..", ".#...#..", "..###...", "........", "........", "........"]),
    "error": ("red", ["...#....", "...#....", "...#....", "...#....", "........", "...#....", "........", "........"]),
    "stale": ("stone", ["..###...", ".#.#.#..", ".#.##...", ".#...#..", "..###...", "........", "........", "........"]),
    "unknown": ("grey", ["..###...", ".#...#..", "....#...", "...#....", "........", "...#....", "........", "........"]),
    "badge_ai": ("yellow", ["........", ".#####..", ".#...#..", ".#####..", "........", "........", "........", "........"]),
    "badge_simulation": ("teal", ["...#....", "..#.#...", ".#...#..", "..#.#...", "...#....", "........", "........", "........"]),
}


def icon(bg, rows):
    im = Image.new("RGBA", (8, 8), rgba(bg))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                im.putpixel((x, y), rgba("white"))
    for x in range(8):
        im.putpixel((x, 7), rgba("outline"))
        im.putpixel((7, x), rgba("outline"))
    return im


def blender():
    exe = os.environ.get("BLENDER") or shutil.which("blender")
    if not exe:
        raise SystemExit("pixel: Blender 5.2 is needed for the pre-rendered kit (blender on PATH or $BLENDER)")
    return exe


KIT_NOTES = {
    "projection": "2:1 isometric: one metre east (+16, +8) px, south (-16, +8), up (0, -16); rendered "
                  "orthographically at 30 deg elevation and 45 deg yaw with the model squashed vertically "
                  "by sqrt(2/3) so a metre up is 16 px, as iso() in the pack",
    "anchor": "each sprite's anchors.json entry is the pixel where its origin point (x, z, y below, "
              "metres, Godot axes) lands; place the sprite at iso(origin) of where it goes",
    "facades": "s_* slices look south: 1 m along x, outer face on the line z = Z, wall WALL m thick "
               "toward -z; origin at the slice's +x end on that line. e_* slices look east: 1 m along z, "
               "outer face on x = X, thickness toward -x; origin at the slice's +z end. The walls stand in "
               "the ring WALL deep outside the rooms: south and east slices on the ring's outer edge "
               "(z1 + WALL, x1 + WALL), north and west ones on the rooms' edge (z0, x0), seen from inside. "
               "Pairs _0/_1 are a 2 m bay in order of increasing x (s) or z (e); plain and banner are single "
               "metres; a doorway is door_l, one door_m a metre of its width (open where people walk) and "
               "door_r, its leaves folded in the reveals of door_l and door_r. Sort every slice at its origin.",
    "corners": "corner/corner_low fill the WALL-square where two walls meet and stand on its centre; the "
               "same sprite serves every corner",
    "roofs": "roof pieces have their eave at y = 0: place at iso(origin) lifted by the wall height and "
             "sort them all at the wall ring's south-east corner, after the wall slices. Hall: one "
             "sawtooth tooth per 4 m of x; for each z cell k use roof_n (k = z0), roof_s (k = z1 - 1) or "
             "roof_mid at iso(x0 + 4t + 4, k + 1). Library: roof tiles at every cell centre, the dome on "
             "its drum centre.",
    "cutaway": "open: hide the roof pieces (and dome) and swap the near (south and east) facade slices "
               "and corners for s_low/e_low/corner_low (a door_m for nothing); far walls stay",
    "stacks": "tower_base/mid/top share the tower's south-east corner: lift tower_mid by base + k*storey "
              "and tower_top by base + mids*storey metres",
    "slices": "tram back_NN/front_NN and bridge pieces are 1 m slices along x, each sorted at its own origin: "
              "the tram's back (far side, floor, seats, roof) at z - 1.3, its front (near side, windows open) at "
              "z + 1.3, riders between; tram/door.png is a door leaf standing on its origin; bridge "
              "*_back (deck, north parapet) sort at z - width/2, *_front (south parapet, arches) at z + width/2",
    "tiles": "ground/* and library/roof.png are 32 x 16 diamonds, origin at the cell centre",
    "characters": "characters/*.png: 11 columns (walk x6, sit, idle x2, typing x2) x 8 rows (facing 0, 45, "
                  "... 315 clockwise from north) of 32 x 40 frames; the ground point is at (16, 34) in standing "
                  "frames and (16, 32) in seated ones; 32 px to the top of the hair",
    "night": "every sprite has a *_night.png twin mapped through the palette (windows and lamps light up)",
    "things": "the things to use (things.py): a sprite's band_shapes are its shapes 0.25-1.9 m up about its "
              "ground point before its turn by `facing` (the collision audit's reading; render.py checks the "
              "model against them); a display's `display` is its face's middle (x, z, y) before the turn and "
              "its width and height; perch_seat_<facing> is the seat stone a perch's sitter sits on, at the "
              "sit anchor; meadow/<clump>_<frame> are a clump at rest (0), pushed (1) and swinging back (2); "
              "fountain_back (its far rim) and fountain_front (the rest) are one render cut in two, each placed "
              "and sorted at its own origin about the placement's point",
    "seats": "scenery/seats/<kind>_<facing>.png are a seat's whole furniture, its sitter's place on the "
             "origin; a workstation's `display` is its monitor's screen (x, z, y before the turn), its width "
             "and height, and its `facing` relative to the seat's (180: back at the sitter), which the pack "
             "lights over the sprite",
}


def prerender(out, anchors):
    """Renders models.KIT in Blender, then post-processes it into `out`."""
    import models
    import post
    with tempfile.TemporaryDirectory() as raw:
        subprocess.run([blender(), "--background", "--factory-startup", "--python-exit-code", "1",
                        "--python", str(HERE / "render.py"), "--", raw], check=True,
                       stdout=subprocess.DEVNULL)
        info = {}
        written = post.process(raw, out, models.KIT, anchors, info)
    constants = {k: getattr(models, k) for k in ("WALL", "HALL_H", "LIB_H", "LIB_PARAPET", "DOME_R", "TOWER",
                                                 "TOWER_BASE", "TOWER_STOREY", "TRAM_LEN", "DECK", "BRIDGE_W")}
    kit = {"notes": KIT_NOTES, "constants": constants,
           "sprites": {p: info[p] for p in sorted(written)}}
    (out / "kit.json").write_text(json.dumps(kit, indent=2, sort_keys=True) + "\n")


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    anchors = {}
    for name, (bg, rows) in GLYPHS.items():
        save(out, f"icons/{name}.png", icon(bg, rows))
    prerender(out, anchors)
    (out / "anchors.json").write_text(json.dumps(anchors, indent=2, sort_keys=True) + "\n")
    # The palette with night twins, for shapes the pack draws itself.
    hexed = lambda rgb: "#%02x%02x%02x" % rgb
    published = {name: [hexed(rgb), hexed(NIGHT_MAP[rgb])] for name, rgb in C.items()}
    (out / "palette.json").write_text(json.dumps(published, indent=2, sort_keys=True) + "\n")
    print(f"pixel: wrote {sum(1 for _ in out.rglob('*.png'))} sprites")


if __name__ == "__main__":
    main()
