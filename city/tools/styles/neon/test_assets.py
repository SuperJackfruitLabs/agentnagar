"""Checks the neon noir kit (see tools/styles/shared/kittests.py), and its
character atlases: the semi-realistic face atlas and the robot eye atlas.

python3 -m unittest city/tools/styles/neon/test_assets.py
"""
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "shared"))
import kittests  # noqa: E402
import tram_checks  # noqa: E402
import atlas_tests  # noqa: E402

PACK = HERE.parents[2] / "godot" / "styles" / "neon_noir"
NeonKit = kittests.kit_case(HERE, PACK)

# The tram: the line's length, doors that open, an interior with its seats
# under the shared layout's slots (tools/styles/shared/tram_checks.py).
Tram = tram_checks.tram_case(PACK / "assets" / "tram.glb")
NeonAtlases = atlas_tests.atlas_case(PACK / "assets", "neon", "ring")

if __name__ == "__main__":
    unittest.main()
