"""Checks the pixel-art kit: only palette colours (day or night) on a fixed
grid, every style.json reference present, byte-reproducible output, and the
pre-render pipeline (post.py on synthetic passes; the Blender-rendered kit's
anchors, night twins, tile shapes and seamless façade modules).

python3 -m unittest city/tools/styles/pixel/test_sprites.py
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
PACK = HERE.parents[2] / "godot" / "styles" / "pixel_art"
ASSETS = PACK / "assets"
sys.path.insert(0, str(HERE))
import palette  # noqa: E402
import models  # noqa: E402
import post  # noqa: E402


def refs(style):
    """Every asset style.json names, however deep (a meadow's clumps are
    lists of frames)."""
    def walk(value):
        if isinstance(value, str):
            if value.startswith("assets/"):
                yield value
        elif isinstance(value, dict):
            for v in value.values():
                yield from walk(v)
        elif isinstance(value, list):
            for v in value:
                yield from walk(v)
    for section, entries in style.items():
        if isinstance(entries, dict):
            yield from walk(entries)


def in_kit(path):
    """Whether a file under ASSETS is part of the generated kit: not the
    style picker's preview (a capture of the scene) and not the interface
    skin's frames (drawn by shared/ui_frames.py, checked by its own test)."""
    rel = path.relative_to(ASSETS).as_posix()
    return rel != "preview.png" and not rel.startswith("ui/")


def size(png):
    with Image.open(png) as im:
        return im.size


class PixelKit(unittest.TestCase):
    def pngs(self):
        return sorted(p for p in ASSETS.rglob("*.png") if in_kit(p))

    def test_a_person_wears_the_same_colours_in_every_style(self):
        # Outfit k is the same colour family in every pack, so someone keeps
        # their look when the style is switched.
        import colorsys

        def hue(rgb):
            h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
            return h * 360, l, s

        def rgb(hexcode):
            h = hexcode.lstrip("#")
            return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

        styles = HERE.parents[2] / "godot" / "styles"
        packs = {name: [rgb(c) for c in json.loads((styles / name / "style.json").read_text())["outfits"]]
                 for name in ("lowpoly_tropical", "voxel")}
        import figures
        tops = [palette.MATERIALS[t]["base"] for t in figures.TOPS]
        self.assertEqual(tops, palette.OUTFITS, "palette.OUTFITS names the tops the sheets are drawn in")
        packs["pixel_art"] = [palette.C[n] for n in tops]
        for k in range(8):
            looks = {name: hue(colours[k]) for name, colours in packs.items()}
            greys = [n for n, (_, l, s) in looks.items() if s < 0.25 or l > 0.85]
            if greys:
                self.assertEqual(len(greys), 3, f"outfit {k}: all neutral or none: {looks}")
                continue
            hues = [h for h, _, _ in looks.values()]
            spread = max(min(abs(a - b), 360 - abs(a - b)) for a in hues for b in hues)
            self.assertLess(spread, 45, f"outfit {k} differs between styles: {looks}")

    def test_skin_and_hair_follow_the_same_order_in_every_style(self):
        # A person's skin is skin[k % 4] and hair colour hair[(k + 1) % 4]
        # in every style (as figures.human draws them), so the lists must
        # match in order: skin light to dark, hair brown, black, auburn, blond.
        import colorsys
        import figures

        def light(hexcode):
            h = hexcode.lstrip("#")
            return colorsys.rgb_to_hls(*(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)))[1]

        styles = HERE.parents[2] / "godot" / "styles"
        pixel_skins = [palette.MATERIALS[s]["base"] for s in figures.SKINS]
        pixel_light = [colorsys.rgb_to_hls(*(c / 255 for c in palette.C[n]))[1] for n in pixel_skins]
        self.assertEqual(pixel_light, sorted(pixel_light, reverse=True), "pixel skins run light to dark")
        for name in ("lowpoly_tropical", "voxel"):
            style = json.loads((styles / name / "style.json").read_text())
            lights = [light(c) for c in style["skin"]]
            self.assertEqual(lights, sorted(lights, reverse=True), f"{name} skins run light to dark")
            bottoms = [light(c) for c in style["bottoms"]]
            pixel_bottoms = [colorsys.rgb_to_hls(*(c / 255 for c in palette.C[palette.MATERIALS[b]["base"]]))[1]
                             for b in figures.BOTTOMS]
            self.assertEqual(len(bottoms), len(pixel_bottoms), f"{name}: one trouser colour per pixel bottom")
            for a, b in zip(bottoms, pixel_bottoms):
                self.assertLess(abs(a - b), 0.2, f"{name}: trousers match the pixel sheets' in lightness")
            hairs = [light(c) for c in style["hair_colours"]]
            self.assertEqual(hairs.index(max(hairs)), 3, f"{name}: blond is the fourth hair colour")
            self.assertEqual(hairs.index(min(hairs)), 1, f"{name}: black is the second hair colour")

    def test_the_palette_is_published_for_drawn_shapes(self):
        published = json.loads((ASSETS / "palette.json").read_text())
        hexed = lambda rgb: "#%02x%02x%02x" % rgb
        self.assertEqual(sorted(published), sorted(palette.NAMES))
        for name, rgb in palette.C.items():
            self.assertEqual(published[name], [hexed(rgb), hexed(palette.NIGHT_MAP[rgb])], name)

    def test_only_palette_colours(self):
        allowed = set(palette.DAY) | set(palette.NIGHT)
        self.assertEqual(len(palette.DAY), 32)
        for png in self.pngs():
            with Image.open(png) as raw:
                im = raw.convert("RGBA")
            for count, (r, g, b, a) in im.getcolors(1 << 16):
                if a == 0:
                    continue
                self.assertEqual(a, 255, f"{png.name}: partial alpha")
                self.assertIn((r, g, b), allowed, f"{png.name}: off-palette {(r, g, b)}")

    def test_sizes_sit_on_the_grid(self):
        for png in (ASSETS / "tiles").glob("*.png"):
            self.assertEqual(size(png), (32, 16), png.name)
        sheets = [p for p in (ASSETS / "characters").glob("*.png") if not p.name.endswith("_night.png")]
        self.assertEqual(len(sheets), 36, "8 outfits × 4 hair styles, muted, and 3 robots")
        for png in (ASSETS / "characters").glob("*.png"):
            self.assertEqual(size(png), (11 * 32, 8 * 40), f"{png.name}: 11 frames x 8 directions of 32 x 40")
        for png in (ASSETS / "icons").glob("*.png"):
            self.assertEqual(size(png), (8, 8), png.name)

    def test_every_reference_exists_with_a_night_twin(self):
        style = json.loads((PACK / "style.json").read_text())
        found = list(refs(style))
        self.assertGreater(len(found), 40)
        for ref in found:
            path = PACK / ref
            self.assertTrue(path.exists(), ref)
            if "icons/" not in ref:
                self.assertTrue(path.with_name(path.stem + "_night.png").exists(), ref + " night")

    def test_generation_is_reproducible(self):
        """Regenerating (Pillow sprites and the Blender pre-render) gives
        byte-identical sprites, anchors and kit metadata."""
        if not (os.environ.get("BLENDER") or shutil.which("blender")):
            self.skipTest("Blender not installed: the pre-rendered kit cannot be regenerated here")

        def digest(root, keep=lambda p: True):
            return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in sorted(Path(root).rglob("*")) if p.suffix in (".png", ".json") and keep(p)}
        with tempfile.TemporaryDirectory() as a:
            subprocess.run([sys.executable, str(HERE / "build.py"), a], check=True, stdout=subprocess.DEVNULL)
            self.assertEqual(digest(a), digest(ASSETS, in_kit), "committed sprites match the generator")


def diamond():
    """The pixels a 1 m ground cell covers: centres inside the 32 x 16
    diamond whose corners are pixel corners, so cells tile exactly."""
    return {(x, y) for y in range(16) for x in range(32)
            if abs(x + 0.5 - 16) / 16 + abs(y + 0.5 - 8) / 8 < 1}


class PreRenderedKit(unittest.TestCase):
    """The Blender-rendered kit as committed: complete, anchored, on the
    grid, and assembling without seams."""

    @classmethod
    def setUpClass(cls):
        cls.anchors = json.loads((ASSETS / "anchors.json").read_text())
        cls.kit = json.loads((ASSETS / "kit.json").read_text())
        # A sheet's frames share its path; every other output has its own.
        singles = [o["path"] for spec in models.KIT for o in spec["outputs"] if "sheet" not in o]
        sheets = sorted({o["path"] for spec in models.KIT for o in spec["outputs"] if "sheet" in o})
        cls.unique = len(singles) == len(set(singles)) and not set(singles) & set(sheets)
        cls.paths = singles + sheets

    def test_every_model_output_is_written_with_night_twin_anchor_and_metadata(self):
        self.assertTrue(self.unique, "output paths are unique")
        self.assertGreater(len(self.paths), 100)
        for rel in self.paths:
            path = ASSETS / rel
            self.assertTrue(path.exists(), rel)
            self.assertTrue(path.with_name(path.stem + "_night.png").exists(), rel + " night")
            self.assertIn(rel, self.anchors, rel + " anchor")
            ax, ay = self.anchors[rel]
            self.assertTrue(isinstance(ax, int) and isinstance(ay, int), rel)
            self.assertIn(rel, self.kit["sprites"], rel + " in kit.json")
            self.assertEqual(self.kit["sprites"][rel]["size"], list(size(path)), rel)
        on_disk = {p.relative_to(ASSETS).as_posix() for d in ("buildings", "scenery", "ground", "characters")
                   for p in (ASSETS / d).rglob("*.png") if not p.name.endswith("_night.png")}
        self.assertEqual(on_disk, set(self.paths), "no stray sprites in the kit folders")

    def test_night_twins_are_the_palette_map_of_the_day_sprite(self):
        for rel in self.paths:
            with Image.open(ASSETS / rel) as d, Image.open(ASSETS / rel.replace(".png", "_night.png")) as n:
                day, night = d.convert("RGBA"), n.convert("RGBA")
            self.assertEqual(day.size, night.size, rel)
            for (r, g, b, a), m in zip(day.getdata(), night.getdata()):
                self.assertEqual(a, m[3], rel)
                if a:
                    self.assertEqual(m[:3], palette.NIGHT_MAP[(r, g, b)], rel)

    def test_ground_tiles_are_exact_diamonds(self):
        want = diamond()
        tiles = [p for p in self.paths if p.startswith("ground/")] + ["buildings/library/roof.png"]
        self.assertGreater(len(tiles), 20)
        for rel in tiles:
            with Image.open(ASSETS / rel) as raw:
                im = raw.convert("RGBA")
            self.assertEqual(im.size, (32, 16), rel)
            got = {(x, y) for y in range(16) for x in range(32) if im.getpixel((x, y))[3]}
            self.assertEqual(got, want, rel)
            self.assertEqual(self.anchors[rel], [16, 8], rel)

    def test_facade_modules_join_without_gaps(self):
        """Laid along a face as the pack will lay them, the slices cover
        the face line with no hole at any height up to the eaves, but for
        a doorway's opening below its head. (The two ends of a face are
        closed by the corner piers.)"""
        for folder, top, head in (("buildings/hall", models.HALL_H, models.HALL_HEAD),
                                  ("buildings/library", models.LIB_H, models.LIB_HEAD)):
            for face in ("s", "e"):
                seq = ["wall_0", "wall_1", "plain", "door_l", "door_m", "door_m", "door_r", "wall_0", "wall_1"]
                if folder.endswith("library"):
                    seq.insert(3, "banner")
                opening = (seq.index("door_m"), seq.index("door_r"))
                canvas = Image.new("RGBA", (800, 600))
                ox, oy = 400, 300
                for k, name in enumerate(seq):
                    rel = f"{folder}/{face}_{name}.png"
                    px, py = (ox + (k + 1) * 16, oy + (k + 1) * 8) if face == "s" else \
                        (ox - (k + 1) * 16, oy + (k + 1) * 8)
                    ax, ay = self.anchors[rel]
                    with Image.open(ASSETS / rel) as im:
                        canvas.alpha_composite(im.convert("RGBA"), (px - ax, py - ay))
                n = len(seq)
                for step in range(16, (n - 1) * 16):
                    t = step / 16
                    for h in (0.2, 1.0, top - 0.6):
                        if opening[0] <= t <= opening[1] and h < head:
                            continue
                        x, y = (ox + t * 16, oy + t * 8 - h * 16) if face == "s" else (ox - t * 16, oy + t * 8 - h * 16)
                        self.assertEqual(canvas.getpixel((int(x), int(y)))[3], 255,
                                         f"{folder} {face}: hole at {t:.2f} m, {h} m up")

    def test_a_doorway_is_open_across_its_width_where_people_walk(self):
        """A doorway's opening shows the ground through it at walking
        height, a metre of opening per door_m."""
        for folder in ("buildings/hall", "buildings/library"):
            for face in ("s", "e"):
                with Image.open(ASSETS / f"{folder}/{face}_door_m.png") as raw:
                    im = raw.convert("RGBA")
                ax, ay = self.anchors[f"{folder}/{face}_door_m.png"]
                # The metre's middle on the wall's outer line, a metre up.
                x, y = (ax - 8, ay - 4 - 16) if face == "s" else (ax + 8, ay - 4 - 16)
                self.assertEqual(im.getpixel((x, y))[3], 0, f"{folder} {face}_door_m is open a metre up")

    def test_character_frames_stand_on_their_ground_point_and_fill_every_cell(self):
        """Every frame of every sheet holds a figure, inside its 32 x 40
        cell, its lowest pixels at the feet (standing) or around the seat
        (seated), no taller than 32 px plus its outline."""
        import figures
        for name in figures.VARIANTS:
            with Image.open(ASSETS / "characters" / f"{name}.png") as raw:
                im = raw.convert("RGBA")
            for row in range(len(figures.DIRECTIONS)):
                for col, (action, _) in enumerate(figures.FRAMES):
                    cell = im.crop((col * 32, row * 40, col * 32 + 32, row * 40 + 40))
                    box = cell.getbbox()
                    self.assertIsNotNone(box, f"{name} [{col}, {row}] is empty")
                    fx, fy = figures.SEAT if action in ("sit", "typing") else figures.FEET
                    self.assertGreaterEqual(box[1], fy - 33, f"{name} [{col}, {row}] too tall")
                    if action in ("walk", "idle"):
                        self.assertTrue(fy - 2 <= box[3] - 1 <= fy + 6, f"{name} [{col}, {row}] feet at {box[3] - 1}")
                    self.assertTrue(box[0] < fx < box[2], f"{name} [{col}, {row}] centred on its ground point")

    def test_the_tram_is_drawn_as_wide_as_the_tram_kind(self):
        """Where people walk the tram reaches the tram kind's width about
        its line (250 cm), which the core keeps clear round the track."""
        catalogue = json.loads((HERE.parents[2] / "catalogue" / "catalogue.json").read_text())
        tram = next(k for k in catalogue["kinds"] if k["id"] == "tram")
        self.assertAlmostEqual(models.TRAM_HW * 200, tram["width"])

    def test_kit_notes_document_the_conventions(self):
        for key in ("projection", "anchor", "facades", "roofs", "cutaway", "tiles", "night", "characters", "things"):
            self.assertIn(key, self.kit["notes"])

    def test_the_things_to_use_declare_their_band_and_faces(self):
        """Every sprite of the things to use carries the shapes the audit
        reads it by (render.py holds the model to them); the displays their
        faces; the perches' kinds at four facings (the fountain at one) and
        their seat stones at eight."""
        import things
        mine = {p: i for p, i in self.kit["sprites"].items() if "band_shapes" in i}
        for kind in ("noticeboard", "plaque", "kiosk", "steps", "low_wall"):
            for f in (0, 90, 180, 270):
                info = mine[f"scenery/{kind}_{f}.png"]
                self.assertEqual(info["facing"], f)
                rect = things.drawn_rect(kind.replace("_", "-"), f)
                self.assertEqual(info["band_shapes"], [["rect", *rect]],
                                 f"{kind} {f}: its footing on its drawn rectangle")
                if kind in things.DISPLAY:
                    (x, z, y), (w, h) = things.DISPLAY[kind]
                    self.assertEqual(info["display"], {"at": [x, z, y], "size": [w, h]})
                    # The face is on the front of the drawn rectangle, inside it.
                    self.assertTrue(rect[2] <= z < 0, f"{kind}: its face looks out of its front")
        # The fountain's two halves each read as the basin's whole disc,
        # about their own origins.
        self.assertEqual(mine["scenery/fountain_front.png"]["band_shapes"], [["disc", 1.5, 0.0, 0.0]])
        self.assertEqual(mine["scenery/fountain_back.png"]["band_shapes"], [["disc", 1.5, 1.5, 1.5]])
        self.assertEqual(mine["scenery/fountain_back.png"]["origin"], [-1.5, -1.5, 0])
        for f in things.SEAT_FACINGS:
            self.assertEqual(mine[f"scenery/perch_seat_{f}.png"]["band_shapes"], things.SEAT_BAND)
        # A seat stone's front and sides, a centimetre off for its pixel,
        # keep the body clearance (10 cm) inside the 25 cm square round its
        # sitter that the audit leaves to it.
        (_, x0, x1, z0, _), = things.SEAT_BAND
        self.assertLessEqual(max(-x0, x1, -z0) + 0.01 + 0.10, 0.25 + 1e-9)

    def test_the_fountains_halves_are_cut_from_one_render_without_overlap(self):
        """Laid at their origins, the back rim and the rest of the fountain
        cover each other nowhere: one render, cut in two; the back holds
        only its far rim, all of it behind the middle on the screen."""
        canvas = Image.new("RGBA", (200, 140))
        ox, oy = 100, 90
        layers = []
        for rel, (x, z) in (("scenery/fountain_back.png", (-1.5, -1.5)), ("scenery/fountain_front.png", (0, 0))):
            ax, ay = self.anchors[rel]
            px, py = ox + round(16 * (x - z)), oy + round(8 * (x + z))
            with Image.open(ASSETS / rel) as im:
                layer = Image.new("RGBA", canvas.size)
                layer.alpha_composite(im.convert("RGBA"), (px - ax, py - ay))
            layers.append(layer)
        back, front = ([p[3] > 0 for p in layer.getdata()] for layer in layers)
        self.assertFalse(any(b and f for b, f in zip(back, front)), "the halves overlap")
        w = canvas.size[0]
        rows = [k // w for k, b in enumerate(back) if b]
        self.assertTrue(rows and max(rows) < oy, "the back rim lies behind the middle on the screen")

    def test_a_meadow_clump_rustles_in_three_frames(self):
        import things
        for name in things.CLUMPS:
            frames = [self.kit["sprites"][f"scenery/meadow/{name}_{k}.png"] for k in range(3)]
            self.assertEqual([f["rustle"] for f in frames], [0, 1, 2], name)
            reaches = [f["band_shapes"][0][1] for f in frames]
            self.assertTrue(all(0.1 < r < 0.35 for r in reaches), f"{name}: reaches {reaches}")
            # Each frame is its own drawing: the push shows.
            pixels = []
            for k in range(3):
                with Image.open(ASSETS / f"scenery/meadow/{name}_{k}.png") as im:
                    pixels.append(im.convert("RGBA").tobytes())
            self.assertEqual(len(set(pixels)), 3, f"{name}: three different frames")


class PostProcess(unittest.TestCase):
    """post.py on hand-made passes: no Blender needed."""

    def square(self, material, size=12, normals=None):
        raw = post.empty_raw(size + 6, size + 6, origin=(3, 3))
        sl = (slice(3, 3 + size), slice(3, 3 + size))
        raw["alpha"][sl] = True
        raw["mat"][sl] = post.MATERIAL_INDEX[material]
        if normals is not None:
            raw["nrm"][sl] = normals
        return raw

    def colours(self, rgba):
        return {tuple(int(v) for v in px[:3]) for px in rgba.reshape(-1, 4) if px[3]}

    def test_lab_matches_reference_values(self):
        for rgb, want in (((255, 255, 255), (100.0, 0.0, 0.0)), ((255, 0, 0), (53.24, 80.09, 67.20)),
                          ((0, 0, 255), (32.30, 79.19, -107.86))):
            got = post.lab(rgb)
            for g, w in zip(got, want):
                self.assertAlmostEqual(float(g), w, delta=0.05)

    def test_nearest_colour_in_lab_is_a_palette_colour(self):
        self.assertEqual(post.nearest((250, 250, 248)), palette.C["white"])
        self.assertEqual(post.nearest((20, 26, 50)), palette.C["outline"])
        self.assertEqual(post.nearest((170, 72, 50), ["brick_dark", "brick", "brick_light"]), palette.C["brick"])

    def test_every_pixel_stays_in_its_material_ramp(self):
        rng = __import__("random").Random(3)
        n = [[post.unit((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0, 1))) for _ in range(12)]
             for _ in range(12)]
        rgba = post.compose(self.square("brick", normals=n), outline=True)["rgba"]
        allowed = {palette.C[c] for c in palette.MATERIALS["brick"]["ramp"] + ["outline"]}
        self.assertLessEqual(self.colours(rgba), allowed)

    def test_the_silhouette_gets_a_one_pixel_outline_outside_it(self):
        rgba = post.compose(self.square("stone_light"), outline=True)["rgba"]
        navy = palette.C["outline"]
        for k in range(3, 15):
            for y, x in ((2, k), (15, k), (k, 2), (k, 15)):
                self.assertEqual(tuple(rgba[y, x, :3]), navy, (x, y))
        for y, x in ((2, 2), (15, 15), (1, 5), (5, 1)):
            self.assertEqual(rgba[y, x, 3], 0, (x, y))
        self.assertNotIn(navy, self.colours(rgba[3:15, 3:15]))
        plain = post.compose(self.square("stone_light"), outline=False)["rgba"]
        self.assertEqual(plain[2, 5, 3], 0)

    def test_an_outline_can_take_a_palette_colour(self):
        rgba = post.compose(self.square("stone_light"), outline="leaf_dark")["rgba"]
        self.assertEqual(tuple(rgba[2, 5, :3]), palette.C["leaf_dark"])
        self.assertNotIn(palette.C["outline"], self.colours(rgba))

    def test_dither_only_where_the_material_asks_for_it(self):
        # A normal sweeping from facing away to facing the light, left to right.
        n = [[post.unit((0.0, -1.0 + 2.0 * x / 23, 0.3)) for x in range(24)] for _ in range(24)]

        def isolated(material):
            rgba = post.compose(self.square(material, size=24, normals=n), outline=False)["rgba"]
            row = [tuple(p[:3]) for p in rgba[12, 3:27]]
            return sum(1 for a, b, c in zip(row, row[1:], row[2:]) if b != a and b != c)

        self.assertGreater(isolated("leaf"), 2)
        self.assertEqual(isolated("stone_light"), 0)

    def test_night_twins_map_every_pixel_through_the_palette(self):
        rgba = post.compose(self.square("glass_warm"), outline=True)["rgba"]
        night = post.night(rgba)
        for day_px, night_px in zip(rgba.reshape(-1, 4), night.reshape(-1, 4)):
            self.assertEqual(day_px[3], night_px[3])
            if day_px[3]:
                self.assertEqual(tuple(night_px[:3]), palette.NIGHT_MAP[tuple(int(v) for v in day_px[:3])])

    def test_cut_modules_reassemble_the_render(self):
        raw = post.empty_raw(20, 70, origin=(3, 16))
        raw["alpha"][4:16, 3:67] = True
        raw["mat"][4:16, 3:67] = post.MATERIAL_INDEX["brick"]
        for x in range(70):
            raw["cell"][:, x, 0] = (x - 3) // 16
        comp = post.compose(raw, outline=True)
        outs = [{"path": f"m{k}.png", "cells": {"x": [k, k]}, "origin": [k + 1, 0, 0]} for k in range(4)]
        sprites = post.cut(comp, outs)
        canvas = __import__("numpy").zeros_like(comp["rgba"])
        ox, oy = comp["origin"]
        for k, (path, rgba, (ax, ay)) in enumerate(sprites):
            px, py = ox + (k + 1) * 16, oy + (k + 1) * 8
            h, w = rgba.shape[:2]
            region = canvas[py - ay:py - ay + h, px - ax:px - ax + w]
            mask = rgba[:, :, 3] > 0
            self.assertFalse((region[:, :, 3][mask] > 0).any(), f"{path} overlaps a neighbour")
            region[mask] = rgba[mask]
        self.assertTrue((canvas == comp["rgba"]).all(), "the modules put back together are the render")


if __name__ == "__main__":
    unittest.main()
