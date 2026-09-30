"""The one tram layout every style kit skins (city tram spec §5, §9): the
line's tram length, doors at 20, 50 and 80% of it on both sides, a floor,
and the rider slots two across as the core lays them out
(city-core transit::slot_along and project::slot_point).

- Slots fill rows front to back, two to a row: even slots 50 cm left of
  the way the tram runs, odd slots 50 cm right.
- Row r's middle lies (2r + 1) * length / (2 * rows) cm behind the front,
  with ceil(capacity / 2) rows, in whole centimetres as the core
  computes it.
- A row whose middle is within 65 cm of a door is standee space by that
  door; every other row is a pair of seats. The client poses riders the
  same way (CityGeometry.slot_seated).

Kit models run along +x (Godot +x; Blender +x), front at +x, centred on the
origin, so a slot `along_cm` behind the front stands at
x = length / 2 - along; left of travel is Blender +Y (Godot -Z).

python3 city/tools/styles/shared/tram_layout.py writes the layout the
client reads (godot/styles/tram_layout.json); every kit's tram build writes
it too. Standard library only.
"""
import json
import sys
from pathlib import Path

LENGTH_CM = 2050
CAPACITY = 40
# How far either side of the middle a slot's column stands (cm): half the
# core's 1 m half-width (city-core project::SLOT_ACROSS).
ACROSS_CM = 50
# Doors, in tenths of the length from the front, as the fixture's
# VehicleSpec.doors.
DOOR_TENTHS = (2, 5, 8)
DOOR_WIDTH_CM = 130
# Rows whose middle lies this close to a door are standing room.
DOOR_ROW_CM = 65
# The floor's top above the rail, and a seat's top above the floor (the
# characters sit on a seat 45 cm high: lowpoly/characters.py SEAT_HEIGHT).
FLOOR_CM = 40
SEAT_CM = 45
# A seated rider's eyes above the floor, where the client's first person
# sits aboard (godot/core/fpv_camera.gd SEATED_EYE): every kit's side
# windows run from below it to above it (tram_checks), so a seated rider
# looks out of them.
SEATED_EYE_CM = 120
# How far a door leaf slides open, along the body (cm).
DOOR_SLIDE_CM = 60

OUT = Path(__file__).resolve().parents[3] / "godot" / "styles" / "tram_layout.json"


def doors_cm(length=LENGTH_CM):
    """Door middles, cm behind the front."""
    return [length * k // 10 for k in DOOR_TENTHS]


def rows(capacity=CAPACITY):
    return max((capacity + 1) // 2, 1)


def slot_along(slot, length=LENGTH_CM, capacity=CAPACITY):
    """Slot `slot`'s row middle, cm behind the front."""
    n = rows(capacity)
    row = min(slot // 2, n - 1)
    return (2 * row + 1) * length // (2 * n)


def seated(along, length=LENGTH_CM):
    """Whether a row whose middle is `along` cm behind the front is seats."""
    return all(abs(along - d) > DOOR_ROW_CM for d in doors_cm(length))


def slots(length=LENGTH_CM, capacity=CAPACITY):
    """Every slot: its number, cm behind the front, cm left of the middle
    (negative: right), and the pose its rider takes."""
    out = []
    for s in range(2 * rows(capacity)):
        along = slot_along(s, length, capacity)
        out.append({"slot": s, "along_cm": along, "across_cm": ACROSS_CM if s % 2 == 0 else -ACROSS_CM,
                    "pose": "sitting" if seated(along, length) else "standing"})
    return out


def seats_m(length=LENGTH_CM, capacity=CAPACITY):
    """Where each seat stands in a kit model (metres, Blender axes: x
    forward from the middle, y left): one per seated slot."""
    half = length / 200.0
    return [(half - s["along_cm"] / 100.0, s["across_cm"] / 100.0) for s in slots(length, capacity)
            if s["pose"] == "sitting"]


def doors_m(length=LENGTH_CM):
    """Each door's (x0, x1) along a kit model, metres from its middle, front
    (+x) first."""
    half = length / 200.0
    w = DOOR_WIDTH_CM / 200.0
    return [(half - d / 100.0 - w, half - d / 100.0 + w) for d in doors_cm(length)]


def layout():
    return {
        "length_cm": LENGTH_CM,
        "capacity": CAPACITY,
        "across_cm": ACROSS_CM,
        "doors_cm": doors_cm(),
        "door_width_cm": DOOR_WIDTH_CM,
        "door_slide_cm": DOOR_SLIDE_CM,
        "floor_cm": FLOOR_CM,
        "seat_cm": SEAT_CM,
        "seated_eye_cm": SEATED_EYE_CM,
        "slots": slots(),
    }


def text():
    return json.dumps(layout(), indent=1) + "\n"


def write(path=OUT):
    """Writes the layout JSON (unchanged bytes if it is current)."""
    path = Path(path)
    if not path.exists() or path.read_text() != text():
        path.write_text(text())
    return path


if __name__ == "__main__":
    print(f"tram layout: wrote {write(sys.argv[1] if len(sys.argv) > 1 else OUT)}")
