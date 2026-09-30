"""The solarpunk kit's building blocks: the low-poly kit's lib (Mesh, slabs,
arches, export, ...) on the solarpunk palette, plus smooth() and finish().

Registered as `lib` in sys.modules by build.py, so shared modules (the
character rig, the robot and people builders, anime generators reused
here) build with this palette."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "shared"))
import kitlib  # noqa: E402
import palette  # noqa: E402

_low = kitlib.load(palette)
kitlib.export_into(globals(), _low)
