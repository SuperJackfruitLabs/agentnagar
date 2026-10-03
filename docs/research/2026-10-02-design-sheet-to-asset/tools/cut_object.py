"""cut_object.py CUTOUT.png OUT.png shortest|tallest|largest|smallest: one object out of a cut-out that holds two.

The cutter can take two neighbours on a design sheet for one object (on the solarpunk street-fixtures sheet the
bollard and the catenary pole beside it). The generated model then holds both, and fit_generated.py keeps one
(--object). This does the same to the design image the piece's colours are matched to: the image's separate
objects are told apart (pixels that touch), the one asked for is kept and the rest made clear, so that the
bollard is matched to the bollard's colours and not to the pole's. Objects smaller than a fiftieth of the
largest are specks and are not counted. Needs OpenCV and Pillow (the working folder's venv).
"""
import sys

import cv2
import numpy as np
from PIL import Image

src, out, which = sys.argv[1], sys.argv[2], sys.argv[3]
image = np.array(Image.open(src).convert("RGBA"))
count, labels, stats, _ = cv2.connectedComponentsWithStats((image[..., 3] > 128).astype(np.uint8), connectivity=8)
objects = [(k, int(stats[k, cv2.CC_STAT_HEIGHT]), int(stats[k, cv2.CC_STAT_AREA])) for k in range(1, count)]
objects = [o for o in objects if o[2] >= 0.02 * max(a for _, _, a in objects)]
key = {"shortest": lambda o: o[1], "tallest": lambda o: -o[1], "largest": lambda o: -o[2], "smallest": lambda o: o[2]}[which]
kept = min(objects, key=key)[0]
image[labels != kept] = 0
Image.fromarray(image).save(out)
print(f"cut_object: {len(objects)} objects in {src}, kept the {which} ({stats[kept, cv2.CC_STAT_WIDTH]} by {stats[kept, cv2.CC_STAT_HEIGHT]} px) -> {out}")
