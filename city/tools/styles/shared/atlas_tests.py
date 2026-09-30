"""Checks a lit style's character atlases: the semi-realistic face atlas
(faces_real.py: expressions across, faces down, over transparency so skin
shows through) and the robot eye atlas (one row of expressions, light on
black), and that the committed files are exactly what the drawing code
makes.
"""
import hashlib
import tempfile
import unittest
from pathlib import Path

import faces_real


def _digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def atlas_case(assets, style, eyes):
    assets = Path(assets)
    C = faces_real.CELL

    class Atlases(unittest.TestCase):
        def test_the_face_atlas_has_a_cell_per_expression_and_face(self):
            from PIL import Image
            atlas = Image.open(assets / "face_atlas.png")
            self.assertEqual(atlas.size, (C * len(faces_real.EXPRESSIONS), C * len(faces_real.VARIANTS)))
            self.assertEqual(atlas.mode, "RGBA")
            for row in range(len(faces_real.VARIANTS)):
                for col in range(len(faces_real.EXPRESSIONS)):
                    alpha = atlas.crop((col * C, row * C, (col + 1) * C, (row + 1) * C)).getchannel("A")
                    self.assertEqual(alpha.getpixel((0, 0)), 0, "skin shows through the corners")
                    self.assertGreater(sum(1 for a in alpha.getdata() if a > 128), 300, f"cell {row},{col} draws a face")

        def test_the_eye_atlas_has_a_lit_cell_per_expression(self):
            from PIL import Image
            atlas = Image.open(assets / "eyes_atlas.png").convert("L")
            self.assertEqual(atlas.size, (C * len(faces_real.EYE_EXPRESSIONS), C))
            for col in range(len(faces_real.EYE_EXPRESSIONS)):
                cell = atlas.crop((col * C, 0, (col + 1) * C, C))
                self.assertEqual(cell.getpixel((2, 2)), 0, "black around the eyes")
                self.assertGreater(sum(1 for v in cell.getdata() if v > 160), 150, f"eye cell {col} glows")

        def test_the_atlases_are_drawn_reproducibly(self):
            with tempfile.TemporaryDirectory() as out:
                faces_real.write(Path(out), style, eyes)
                for name in ("face_atlas.png", "eyes_atlas.png"):
                    self.assertEqual(_digest(Path(out) / name), _digest(assets / name),
                                     f"committed {name} matches faces_real.py")

    return Atlases
