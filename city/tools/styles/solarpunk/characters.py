"""Solarpunk characters on the low-poly kit's shared rigs and motion:

    character_solarpunk  a resident: the semi-realistic person (shared
                         people.py) in warm-climate clothes: a short-
                         sleeved linen shirt with an open camp collar,
                         trousers rolled at the ankle, canvas sneakers,
                         and a maker's bib apron the pack shows for some
                         outfits
    agent_solarpunk      an agent: the white ceramic robot with brass
                         trim, a dark visor with two cyan eyes, the green
                         scarf and the leaf badge on an ID card (City
                         Agent A1 is one of these)

EXTRAS draws face_atlas.png (semi-realistic faces) and eyes_atlas.png
(the robot's two soft eyes) into the pack.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "shared"))
import atlases as _atlases  # noqa: E402
import people  # noqa: E402
import robots  # noqa: E402

PERSON = {"sleeves": "short", "cuffs": True, "extras": ["apron"],
          "colours": {"top": "#E8E0CF", "bottom": "#6B6F52", "shoes": "#8A7A66", "sole": "#EFEADF",
                      "apron": "#4F5D4A", "backpack": "#5B6B4A", "strap": "#7A5232"}}
LOOK = {"helmet": "round", "extras": ["scarf"], "eye_at": 90.0, "eye_span": 30.0}


def character_solarpunk():
    people.build(PERSON)


def agent_solarpunk():
    robots.build(LOOK)


def atlases(out):
    _atlases.draw(out, "solarpunk", "pair")


ASSETS = {
    "character_solarpunk": character_solarpunk,
    "agent_solarpunk": agent_solarpunk,
}
ANIMATED = set(ASSETS)
EXTRAS = [atlases]
