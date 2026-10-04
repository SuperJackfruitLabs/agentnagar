"""Create compact gallery previews from locally rendered PNGs; requires Pillow."""
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parent.parent
for path in (root / "renders").glob("*.png"):
    with Image.open(path) as image:
        image.convert("RGB").save(path.with_suffix(".jpg"), quality=90, optimize=True)
