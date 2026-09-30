"""The anime kit's building blocks: the low-poly kit's lib (Mesh, slabs,
arches, export, ...) with the anime palette swapped in, plus smooth
shading for curved forms (toon light needs smooth normals on a vault, a
canopy or a face; boxes stay flat).

Registered as `lib` in sys.modules by build.py, so modules shared with the
low-poly kit (its character rig and motion) build with this palette.
"""
import importlib.util
import math
from pathlib import Path

import palette

_LOW = Path(__file__).resolve().parents[1] / "lowpoly" / "lib.py"
_spec = importlib.util.spec_from_file_location("lowpoly_lib", _LOW)
low = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(low)
low.PALETTE.update(palette.PALETTE)
low.EMISSIVE.clear()
low.EMISSIVE.update(palette.EMISSIVE)
low.ROUGHNESS.clear()
low.ROUGHNESS.update(palette.ROUGHNESS)
low.METALLIC.clear()
low.METALLIC.update(palette.METALLIC)

import sys  # noqa: E402

sys.modules["lowpoly_lib"] = low

from lowpoly_lib import *  # noqa: E402,F401,F403  (the shared API, anime palette)
from lowpoly_lib import Mesh, arch, arched_hole, rect_hole, rotx, roty, rotz  # noqa: E402,F401

PALETTE = low.PALETTE
# Shared code (the character rig) reaches for the low-poly lib's private
# helpers too: every name it defines is available here.
for _name in dir(low):
    if _name.startswith("_") and not _name.startswith("__") and _name not in globals():
        globals()[_name] = getattr(low, _name)


def smooth(obj, angle=40.0):
    """Smooth-shades `obj`, keeping edges sharper than `angle` degrees hard."""
    me = obj.data
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(angle))
    return obj


def finish(name, parts, smooth_parts=()):
    """An empty named `name` parenting {node: Mesh} parts; parts named in
    `smooth_parts` are smooth-shaded."""
    r = low.root(name)
    for node, mesh in parts.items():
        o = mesh.build(node, r)
        if node in smooth_parts:
            smooth(o)
    return r
