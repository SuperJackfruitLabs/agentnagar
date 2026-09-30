"""Draws a lit style's character atlases from a Blender build: Blender's
Python has no Pillow, so faces_real.py runs under the system Python."""
import shutil
import subprocess
from pathlib import Path

FACES = Path(__file__).resolve().parent / "faces_real.py"


def draw(out, style, eyes):
    python = shutil.which("python3") or "python3"
    subprocess.run([python, str(FACES), str(out), style, eyes], check=True)
