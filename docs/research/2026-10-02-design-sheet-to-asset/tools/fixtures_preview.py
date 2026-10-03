#!/usr/bin/env python3
"""fixtures_preview.py STYLE [ASSET ...]: for each built street fixture, one sheet in
previews/<style>-<asset>.png with the design cut-out, the kit's piece and the built piece from the same places
at one scale, shaded and in colour (look.py --lit), and the close views that show what a whole-piece view hides:
a lamp post's lantern and foot, a railing's post and its own second file. The working folder is this script's
parent; the checkout comes from AGENTNAGAR. Runs Blender once a view set, one at a time. (Named for its family:
the other families have preview scripts of their own.)
"""
import json
import os
import subprocess
import sys
from pathlib import Path

W = Path(__file__).resolve().parent.parent
AGENTNAGAR = Path(os.environ["AGENTNAGAR"])
CONFIG = json.loads((W / "work" / "assets.json").read_text())
STYLES = AGENTNAGAR / "city" / "godot" / "styles"


def look(model, out, views, *more):
    lit = [] if "--unlit" in more else ["--lit", "--light", "paint.sl"]          # the studio light that darkens a pale colour least
    r = subprocess.run(["blender", "--background", "--factory-startup", "--python", str(W / "work" / "look.py"), "--", str(model), str(out),
                        "--size", "520", *lit, "--views", views, *[m for m in more if m != "--unlit"]], capture_output=True, text=True)
    if "LOOK " not in r.stdout:
        sys.exit(f"look.py failed on {model}\n{r.stdout[-800:]}\n{r.stderr[-400:]}")


def main(style, names):
    scratch = W / "scratch" / "preview" / style
    scratch.mkdir(parents=True, exist_ok=True)
    for key, a in CONFIG["assets"].items():
        if not a.get("contract") or (names and key not in names):
            continue
        own = a.get("style", {}).get(style, {})
        a = {**a, **{k: own[k] for k in ("file", "post_file") if k in own}}
        new = W / "out" / style / Path(a["file"]).name
        kit = STYLES / style / a["file"]
        cutout = W / "raw" / style / f"{key}_cutout.png"
        if (W / "scratch" / "designs" / style / cutout.name).exists():          # the piece's own object, where the cut-out held two (build.py, design_object)
            cutout = W / "scratch" / "designs" / style / cutout.name
        if not new.exists():
            print(f"{style} {key}: not built")
            continue
        span = {"lamp": "4.7", "bollard": "1.0", "railing": "2.15"}[a["contract"]]          # one scale for the kit's piece and the new one
        tiles = [("design", cutout)]
        role = a["contract"]
        for who, model in (("kit", kit), ("new", new)):
            look(model, scratch / f"{key}-{who}.png", "front,quarter,side,above", "--span", span)
        look(new, scratch / f"{key}-new-unlit.png", "quarter", "--span", span, "--unlit")          # its colours as they are in its texture
        if role == "lamp":
            tiles += [("kit's", scratch / f"{key}-kit-quarter.png"), ("new", scratch / f"{key}-new-quarter.png"), ("new, unlit (its colours)", scratch / f"{key}-new-unlit-quarter.png"), ("new, front", scratch / f"{key}-new-front.png")]
            for who, model in (("kit", kit), ("new", new)):
                look(model, scratch / f"{key}-{who}-top.png", "front,quarter,eye", "--heights", "3.2,4.3", "--span", "1.15")
                look(model, scratch / f"{key}-{who}-foot.png", "front,quarter", "--heights", "0,1.5", "--span", "1.6")
            tiles += [("kit's lantern", scratch / f"{key}-kit-top-quarter.png"), ("new lantern", scratch / f"{key}-new-top-quarter.png"),
                      ("new lantern, front", scratch / f"{key}-new-top-front.png"), ("new lantern, from below", scratch / f"{key}-new-top-eye.png"),
                      ("kit's foot", scratch / f"{key}-kit-foot-quarter.png"), ("new foot", scratch / f"{key}-new-foot-quarter.png"), ("new foot, front", scratch / f"{key}-new-foot-front.png")]
            cols = 4
        elif role == "bollard":
            tiles += [("kit's", scratch / f"{key}-kit-quarter.png"), ("new", scratch / f"{key}-new-quarter.png"), ("new, unlit (its colours)", scratch / f"{key}-new-unlit-quarter.png"),
                      ("kit's, front", scratch / f"{key}-kit-front.png"), ("new, front", scratch / f"{key}-new-front.png"), ("new, side", scratch / f"{key}-new-side.png"), ("new, from above", scratch / f"{key}-new-above.png")]
            cols = 4
        else:
            look(new, scratch / f"{key}-new-behind.png", "quarter", "--span", span, "--from-behind")
            tiles += [("kit's", scratch / f"{key}-kit-quarter.png"), ("new", scratch / f"{key}-new-quarter.png"), ("new, unlit (its colours)", scratch / f"{key}-new-unlit-quarter.png"),
                      ("kit's, front", scratch / f"{key}-kit-front.png"), ("new, front", scratch / f"{key}-new-front.png"), ("new, from behind", scratch / f"{key}-new-behind-quarter.png"),
                      ("new, from above", scratch / f"{key}-new-above.png")]
            if a.get("post_file"):
                kit_post, new_post = STYLES / style / a["post_file"], W / "out" / style / Path(a["post_file"]).name
                for who, model in (("kit", kit_post), ("new", new_post)):
                    look(model, scratch / f"{key}-post-{who}.png", "front,quarter,side", "--span", "1.3")
                look(new, scratch / f"{key}-new-end.png", "front,quarter", "--heights", "0,1.3", "--span", "1.3")
                tiles += [("kit's post", scratch / f"{key}-post-kit-quarter.png"), ("new post (railing_post)", scratch / f"{key}-post-new-quarter.png"),
                          ("new post, along the run", scratch / f"{key}-post-new-front.png"), ("new post, across the run", scratch / f"{key}-post-new-side.png")]
            cols = 4
        out = W / "previews" / f"{style}-{key}.png"
        r = subprocess.run([str(W / "venv/bin/python"), str(W / "work" / "strip.py"), str(out), *[f"{label}={path}" for label, path in tiles if Path(path).exists()],
                            "--cols", str(cols), "--height", "420"], capture_output=True, text=True)
        print(r.stdout.strip() or r.stderr.strip()[-300:])


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
