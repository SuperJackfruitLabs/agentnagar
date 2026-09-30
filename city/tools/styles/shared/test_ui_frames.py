"""Checks the interface skins' nine-slice frames (ui_frames.py): each
committed file's size, the pixels either side of its margin, and that the
committed file is exactly what the drawing code makes.

python3 -m unittest city/tools/styles/shared/test_ui_frames.py
"""
import hashlib
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import ui_frames  # noqa: E402

STYLES = HERE.parents[2] / "godot" / "styles"


def rgb(hexcode):
    h = hexcode.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def open_frame(name):
    with Image.open(STYLES / ui_frames.FRAMES[name]["path"]) as raw:
        return raw.convert("RGBA")


def edge_points(size, depth):
    """The pixel `depth` in from each edge's middle: left, top, right,
    bottom."""
    mid = size // 2
    return [(depth, mid), (mid, depth), (size - 1 - depth, mid), (mid, size - 1 - depth)]


class BrassFrame(unittest.TestCase):
    def setUp(self):
        self.im = open_frame("brass")

    def test_size_and_margin(self):
        self.assertEqual(self.im.size, (96, 96))
        self.assertEqual(ui_frames.FRAMES["brass"]["margin"], 16)

    def test_a_brass_bevel_twelve_pixels_deep_round_a_teal_field(self):
        dark, light = rgb("#B8862F"), rgb("#E4C27A")
        for depth in range(12):
            for x, y in edge_points(96, depth):
                r, g, b, a = self.im.getpixel((x, y))
                self.assertEqual(a, 255, f"bevel opaque at {x},{y}")
                for channel, lo, hi in zip((r, g, b), dark, light):
                    self.assertTrue(min(lo, hi) <= channel <= max(lo, hi), f"brass at {x},{y}: {(r, g, b)}")
        # The ridge is lit: the bevel's middle is lighter than its edge.
        self.assertGreater(sum(self.im.getpixel((6, 48))[:3]), sum(self.im.getpixel((0, 48))[:3]))
        for depth in (12, 15, 16, 48):
            for x, y in edge_points(96, depth):
                self.assertEqual(self.im.getpixel((x, y)), rgb("#123C3A") + (255,), f"field at {x},{y}")

    def test_the_outer_corners_are_rounded_off(self):
        for x, y in ((0, 0), (95, 0), (0, 95), (95, 95)):
            self.assertEqual(self.im.getpixel((x, y))[3], 0, f"corner {x},{y} clear")

    def test_every_edge_is_the_same_along_its_stretch(self):
        # A nine-slice stretches the edges between the margins: each row of
        # the left edge must be the same from margin to margin.
        m = ui_frames.FRAMES["brass"]["margin"]
        for depth in range(m):
            column = {self.im.getpixel((depth, y)) for y in range(m, 96 - m)}
            self.assertEqual(len(column), 1, f"left edge column {depth} is uniform")


class PixelFrame(unittest.TestCase):
    def setUp(self):
        self.im = open_frame("pixel")

    def test_size_and_margin(self):
        self.assertEqual(self.im.size, (48, 48))
        self.assertEqual(ui_frames.FRAMES["pixel"]["margin"], 6)

    def test_outline_highlight_and_field(self):
        expected = [rgb("#0A0F22")] * 3 + [rgb("#3E5AA8")] + [rgb("#141B33")] * 3
        for depth, colour in enumerate(expected):
            for x, y in edge_points(48, depth):
                self.assertEqual(self.im.getpixel((x, y)), colour + (255,), f"depth {depth} at {x},{y}")
        self.assertEqual(self.im.getpixel((24, 24)), rgb("#141B33") + (255,), "field")

    def test_only_its_three_colours_and_no_partial_alpha(self):
        allowed = {rgb("#0A0F22"), rgb("#3E5AA8"), rgb("#141B33")}
        for _, (r, g, b, a) in self.im.getcolors(1 << 16):
            self.assertIn(a, (0, 255), "hard pixels")
            if a:
                self.assertIn((r, g, b), allowed)

    def test_the_corners_are_notched(self):
        self.assertEqual(self.im.getpixel((0, 0))[3], 0, "corner pixel clear")
        self.assertEqual(self.im.getpixel((1, 1))[3], 255, "inside the notch is outline")


class Reproducible(unittest.TestCase):
    def test_the_committed_frames_are_what_the_tool_draws(self):
        with tempfile.TemporaryDirectory() as out:
            ui_frames.write(Path(out))
            for name, frame in ui_frames.FRAMES.items():
                built = hashlib.sha256((Path(out) / frame["path"]).read_bytes()).hexdigest()
                committed = hashlib.sha256((STYLES / frame["path"]).read_bytes()).hexdigest()
                self.assertEqual(built, committed, name)


if __name__ == "__main__":
    unittest.main()
