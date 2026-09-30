"""Neon noir characters on the low-poly kit's shared rigs and motion:

    character_neon  a resident: the semi-realistic person (shared
                    people.py) in night clothes: a long-sleeved crew-neck
                    top, slim trousers, dark sneakers on pale soles, and
                    the extras the pack shows by outfit: an open zip
                    jacket, a hood (with the jacket, a hoodie), a scarf
    agent_neon      an agent: the glossy black helmet with white side
                    plates and a cyan ring eye, a dark hoodie over white
                    limb plates, the ID card (City Agent A1 is one)

EXTRAS draws face_atlas.png (semi-realistic faces) and eyes_atlas.png
(the robot's ring eye) into the pack.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "shared"))
import atlases as _atlases  # noqa: E402
import people  # noqa: E402
import robots  # noqa: E402

PERSON = {"sleeves": "long", "cuffs": False, "extras": ["jacket", "hood", "scarf"],
          "colours": {"top": "#3A3F4C", "bottom": "#23252D", "shoes": "#2A2B31", "sole": "#D6D6DA",
                      "jacket": "#1C1E25", "scarf": "#B8862E", "backpack": "#24262D", "strap": "#15161A"}}
LOOK = {"helmet": "sleek", "extras": ["hoodie", "plates", "side_light"], "eye_at": 64.0, "eye_span": 27.0,
        "eye_z": (1.42, 1.58), "side_light": "neon_cyan"}


def character_neon():
    people.build(PERSON)


def agent_neon():
    robots.build(LOOK)


def atlases(out):
    _atlases.draw(out, "neon", "ring")


ASSETS = {
    "character_neon": character_neon,
    "agent_neon": agent_neon,
}
ANIMATED = set(ASSETS)
EXTRAS = [atlases]
