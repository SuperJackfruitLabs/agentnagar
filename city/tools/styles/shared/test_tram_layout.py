"""Checks the shared tram layout (tram_layout.py): the committed layout JSON
is what the module writes, a slot for every rider, doors at 20, 50 and 80%
of the length, two seats to a row away from the doors and standing room
beside them.

python3 -m unittest city/tools/styles/shared/test_tram_layout.py
"""
import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import tram_layout  # noqa: E402


class TramLayout(unittest.TestCase):
    def test_the_committed_layout_is_what_the_module_writes(self):
        self.assertTrue(tram_layout.OUT.exists(), "run tram_layout.py (or a kit's tram build)")
        self.assertEqual(tram_layout.OUT.read_text(), tram_layout.text())

    def test_a_slot_for_every_rider_two_across(self):
        slots = json.loads(tram_layout.text())["slots"]
        self.assertGreaterEqual(len(slots), tram_layout.CAPACITY)
        self.assertEqual([s["slot"] for s in slots], list(range(len(slots))))
        for s in slots:
            self.assertEqual(s["across_cm"], 50 if s["slot"] % 2 == 0 else -50)
        # The front row is 51 cm behind the front, rows every 102.5 cm.
        self.assertEqual([s["along_cm"] for s in slots[:6:2]], [51, 153, 256])
        self.assertEqual(slots[-1]["along_cm"], 1998)

    def test_doors_at_twenty_fifty_and_eighty_percent(self):
        self.assertEqual(tram_layout.doors_cm(), [410, 1025, 1640])
        self.assertEqual([(round(a, 3), round(b, 3)) for a, b in tram_layout.doors_m()],
                         [(5.5, 6.8), (-0.65, 0.65), (-6.8, -5.5)])

    def test_seats_away_from_the_doors_and_standing_room_beside_them(self):
        slots = tram_layout.slots()
        standing = [s["along_cm"] for s in slots if s["pose"] == "standing"]
        self.assertEqual(len(standing), 12, "two rows by each of three doors")
        self.assertEqual(len(tram_layout.seats_m()), 28)
        for x, _ in tram_layout.seats_m():
            for x0, x1 in tram_layout.doors_m():
                self.assertFalse(x0 - 0.3 < x < x1 + 0.3, f"a seat at {x:.2f} m blocks a door")


if __name__ == "__main__":
    unittest.main()
