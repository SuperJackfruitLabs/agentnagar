"""A style kit's lib: the low-poly kit's lib (Mesh, slabs, arches,
export, ...) on the kit's own palette, plus smooth shading and `finish`.
A kit's lib.py is `from kitlib import *` after `kitlib.load(palette)`.
"""
import importlib.util
import math
import sys
from pathlib import Path

_LOW = Path(__file__).resolve().parents[1] / "lowpoly" / "lib.py"


def load(palette):
    """The low-poly lib module on `palette` (a module with PALETTE,
    EMISSIVE, ROUGHNESS, METALLIC), registered as lowpoly_lib."""
    spec = importlib.util.spec_from_file_location("lowpoly_lib", _LOW)
    low = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(low)
    low.PALETTE.update(palette.PALETTE)
    for name in ("EMISSIVE", "ROUGHNESS", "METALLIC"):
        table = getattr(low, name)
        table.clear()
        table.update(getattr(palette, name))
    sys.modules["lowpoly_lib"] = low
    return low


def export_into(namespace, low):
    """Copies every name `low` defines, private helpers too (the shared
    character rig reaches for them), into `namespace`, then adds smooth()
    and finish()."""
    for name in dir(low):
        if not name.startswith("__"):
            namespace.setdefault(name, getattr(low, name))

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

    namespace["smooth"] = smooth
    namespace["finish"] = finish
    namespace["PALETTE"] = low.PALETTE
