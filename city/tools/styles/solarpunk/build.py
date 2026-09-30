"""Builds the solarpunk kit into the Godot style pack.

blender --background --factory-startup --python-exit-code 1 \\
    --python city/tools/styles/solarpunk/build.py -- [--out DIR] [MODULE_OR_PREFIX ...]

Modules: buildings, scenery, vegetation, props, characters (each an ASSETS
dict of name -> builder; ANIMATED names export with skins and actions;
EXTRAS draw atlases). See tools/styles/shared/kitbuild.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "shared"))
sys.path.insert(0, str(HERE))
import lib  # noqa: E402

sys.modules["lib"] = lib
import kitbuild  # noqa: E402

kitbuild.main(HERE, HERE.parents[2] / "godot" / "styles" / "solarpunk" / "assets", "solarpunk")
