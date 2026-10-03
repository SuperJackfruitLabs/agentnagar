#!/usr/bin/env python3
"""build.py STEP STYLE [ASSET ...]: the steps from a design sheet to a piece in the game, one at a time.

    cut STYLE [SHEET...]   cut the sheets' objects out (crops/<style>/<sheet>/obj-<k>.png; a later revision
                           of a sheet, r002 and on, goes to crops/<style>/<sheet>@<revision>/); every sheet
                           listed in assets.json unless some are named
    gen STYLE [ASSET...]   the image-to-3D model on each asset's crop (raw/<style>/<asset>.glb); skips what exists
    fit STYLE [ASSET...]   turn, size, cut down, bake and colour-match (out/<style>/<kit file name>); in a style
                           built from cubes (its settings have `voxel`) the fitted piece goes to out-mid/ and
                           voxelise.py rebuilds it from cubes into out/
    fit STYLE [ASSET...] --budget   the same held to the kit's triangle limit, for the pieces whose entry has a
                           `budget` for the style (out-budget/<style>/<kit file name>)
    place STYLE [ASSET...] copy the built pieces into the working copy of the game
    restore STYLE [ASSET...] put the kit's own pieces back in the working copy
    try STYLE LABEL [ASSET...] capture each asset in the game into captures/<label>/<asset>/<style>/ (all of
                           them in one start of the game)
    seats STYLE            print, for seat_top.py, each seat's kit piece and built piece (LABEL=FILE pairs)
    all STYLE [ASSET...]   fit, place, try new

The working folder is this script's parent; the checkout comes from AGENTNAGAR. Standard library only; the
tools it calls need Blender, the generator and the game's dev environment.
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import mend_tangents          # beside this file

W = Path(__file__).resolve().parent.parent
AGENTNAGAR = Path(os.environ["AGENTNAGAR"])
CONFIG = json.loads((W / "work" / "assets.json").read_text())
SHEETS = AGENTNAGAR / "docs" / "vision" / "asset-studies" / "sheets"
STYLES = AGENTNAGAR / "city" / "godot" / "styles"
GAME = W / "game"


def run(cmd, **kw):
    return subprocess.run([str(c) for c in cmd], text=True, capture_output=True, **kw)


def wanted(names):
    """The assets named, or every one that is not a variant of another (a variant is built only when named).
    A name beginning @ is a set of them (`sets` in assets.json): @first is the seats and the great tree."""
    asked = []
    for n in names:
        asked += CONFIG.get("sets", {}).get(n[1:], []) if n.startswith("@") else [n]
    return {k: v for k, v in CONFIG["assets"].items() if (k in asked if names else "variant" not in v)}


BUDGET = "--budget" in sys.argv


def out_dir(a):
    if BUDGET:
        return W / "out-budget"
    return W / ("out-" + a["variant"] if a.get("variant") else "out")


def raw_name(key, a, style):
    """The generated model's name: the asset's (or the one it names), with the sheet's revision when it is not the first."""
    rev = rev_of(a, style)
    # A model made again from the pre-matted cut-out (`crop`: "matte", for a design with grey glass) has a name
    # of its own, so the model made from the plain crop stays beside it.
    took = "~matte" if a.get("style", {}).get(style, {}).get("crop", a.get("crop")) == "matte" else ""
    return a.get("raw", key) + ("" if rev == "r001" else "@" + rev) + took


def for_style(a, style):
    """The asset as one style has it: a style whose kit keeps the piece under another file or names its parts
    differently says so in its own settings (`file`, `needle`, `name`, `mesh`, `voxel`), and so does one whose
    model was made from the other crop (`crop`), one that is sized to another box (`size`, `kit`), and one
    whose second file (a railing's post: `post_file`, `post_mesh`) is kept elsewhere, or whose model is kept
    under a name of its own (`raw`: a model generated again from another seed)."""
    own = a.get("style", {}).get(style, {})
    merged = {**a, **{k: own[k] for k in ("file", "needle", "name", "mesh", "voxel", "crop", "size", "kit", "post_file", "post_mesh", "raw") if k in own}}
    # A style that has no such piece in its kit says `"file": null`: the model is generated all the same (it is
    # there when the style gets the piece), and nothing is fitted or placed.
    return {k: v for k, v in merged.items() if not (k == "file" and v is None)}


def rev_of(a, style):
    """The revision of its sheet an asset is built from in a style: the first, unless the asset names another
    (`rev`: {style: "r002"}). A sheet made again does not silently change a piece already built."""
    return a.get("rev", {}).get(style, "r001")


def crop_dir(style, sheet, rev):
    return W / "crops" / style / (sheet if rev == "r001" else f"{sheet}@{rev}")


def swatches_under(record, a, cells):
    """The swatches a sheet shows for one object: those in its cell of a grid sheet, or all of them on a sheet of
    one thing (`record` is the cutter's boxes.json)."""
    mine = next(o for o in record["objects"] if o["k"] == a["obj"])
    if not (cells and "cell" in mine):
        return record.get("swatches", [])
    cols, rows = (int(v) for v in cells.split("x"))
    w, h = record["size"]

    def cell_of(box):
        return [min(int((box[1] + box[3]) / 2 / h * rows), rows - 1), min(int((box[0] + box[2]) / 2 / w * cols), cols - 1)]
    return [sw for sw in record.get("swatches", []) if cell_of(sw["box"]) == mine["cell"]]


def cut(style, sheets=()):
    for sheet, o in CONFIG["sheets"].items():
        if sheets and sheet not in sheets:
            continue
        for image in sorted((SHEETS / style / sheet).glob("r[0-9][0-9][0-9]/image.png")):
            rev = image.parent.name
            cmd = [W / "venv/bin/python", W / "work/cut_sheet.py", image, crop_dir(style, sheet, rev)]
            if o.get("cells"):
                cmd += ["--cells", o["cells"]]
            if o.get("clear_outside"):
                cmd.append("--clear-outside")
            print(f"{style} {sheet} {rev}: " + run(cmd).stdout.splitlines()[0])


def gen(style, names):
    for key, a in wanted(names).items():
        if style not in a.get("only", [style]):
            continue
        out = W / "raw" / style / f"{raw_name(key, a, style)}.glb"
        if out.exists() and out.stat().st_size > 0:
            print(f"have {out.relative_to(W)}")
            continue
        # The cleaned crop (swatches and neighbours painted out) where the piece asks for it; the pieces
        # generated before it existed came from the plain one, and say nothing.
        a = for_style(a, style)
        clean = {"clean": "-clean", "matte": "-matte"}.get(a.get("crop"), "")
        crop = crop_dir(style, a["sheet"], rev_of(a, style)) / f"obj-{a['obj']}{clean}.png"
        if not crop.exists():
            print(f"{style} {key}: no design image yet ({crop.relative_to(W)})")
            continue
        r = run([W / "work/gen3d.sh", crop, out])
        print(r.stdout.strip() or r.stderr.strip()[-300:])


def fit(style, names):
    failed = []
    for key, a in wanted(names).items():
        if style not in a.get("only", [style]):
            continue
        a = for_style(a, style)
        if "file" not in a:
            continue                          # generated, but its kit piece and settings are not entered yet
        s = {**CONFIG["styles"][style], **a.get("style", {}).get(style, {})}
        cubes = {**CONFIG["styles"][style]["voxel"], **a.get("voxel", {})} if CONFIG["styles"][style].get("voxel") else None
        held = a.get("budget", {}).get(style)
        if BUDGET:
            if not held:
                continue                      # this piece is inside its kit's limit as it is
            s = {**s, **{k: v for k, v in held.items() if k not in ("set", "drop")}}
        raw = W / "raw" / style / f"{raw_name(key, a, style)}.glb"
        if not raw.exists():
            print(f"{style} {key}: no generated model yet")
            continue
        final = out_dir(a) / style / Path(a["file"]).name
        out = W / "out-mid" / style / Path(a["file"]).name if cubes else final
        for stale in set(out.parent.glob(out.stem + ".*.png")) | set(final.parent.glob(final.stem + ".*.png")):          # an earlier build's textures
            stale.unlink()
        design = W / "raw" / style / f"{raw_name(key, a, style)}_cutout.png"
        if s.get("design_object"):
            # The cut-out holds a neighbour as well (the cutter took two objects for one): the piece's colours
            # are matched to its own object alone, cut out of the cut-out (cut_object.py).
            own_design = W / "scratch" / "designs" / style / design.name
            own_design.parent.mkdir(parents=True, exist_ok=True)
            print(run([W / "venv/bin/python", W / "work/cut_object.py", design, own_design, s["design_object"]]).stdout.strip())
            design = own_design
        cmd = ["blender", "--background", "--factory-startup", "--python-exit-code", "1", "--python", W / "work/fit_generated.py", "--",
               raw, out, "--tris", str(s.get("tris", a.get("tris", "auto"))), "--max-tris", a.get("max_tris", 6000), "--tex", s.get("tex", a.get("tex", 1024)),
               "--design", design, "--report", out.with_suffix(".json"), "--rough", s.get("rough", 0.85), "--flatten", a.get("flatten", {}).get(style, s.get("flatten", 0.5))]
        if a.get("kit", True):
            cmd += ["--kit", STYLES / style / a["file"]]
        if a.get("size"):
            cmd += ["--size", a["size"]]
        if s.get("glow") and a.get("glow", True):
            cmd += ["--glow", s["glow"], "--glow-strength", s.get("glow_strength", 2.0)]
            if s.get("glow_colour"):
                cmd += ["--glow-colour", s["glow_colour"]]
            if s.get("glow_light"):
                cmd.append("--glow-light")
        if s.get("lift"):
            cmd += ["--lift", s["lift"]]
        if s.get("kit_lights"):
            cmd += ["--kit-lights", "--kit-lights-as", s["kit_lights"]]
        if s.get("core_plan"):
            # The sheet's view from straight above: of the objects on the sheet other than the one the piece is
            # built from, the one drawn lowest.
            rev = rev_of(a, style)
            boxes = json.loads((crop_dir(style, a["sheet"], rev) / "boxes.json").read_text())["objects"]
            size = json.loads((crop_dir(style, a["sheet"], rev) / "boxes.json").read_text())["size"]
            views = [o for o in boxes if o["k"] != a["obj"] and min(o["box"][2] - o["box"][0], o["box"][3] - o["box"][1]) > 0.15 * size[0]]
            plan = max(views, key=lambda o: o["box"][1])          # not a swatch that was taken for an object: a view is large
            cmd += ["--core-plan", f"{SHEETS / style / a['sheet'] / rev / 'image.png'}," + ",".join(str(v) for v in plan["box"])]
        if s.get("materials", a.get("materials")) == "swatches":
            # As many design colours as the sheet shows swatches for this object: those under it in its cell
            # of a grid sheet, or all of them on a sheet of one thing.
            rev = rev_of(a, style)
            record = json.loads((crop_dir(style, a["sheet"], rev) / "boxes.json").read_text())
            mine = next(o for o in record["objects"] if o["k"] == a["obj"])
            cells = CONFIG["sheets"].get(a["sheet"], {}).get("cells")
            if cells and "cell" in mine:
                cols, rows = (int(v) for v in cells.split("x"))
                w, h = record["size"]
                def cell_of(box):
                    return [min(int((box[1] + box[3]) / 2 / h * rows), rows - 1), min(int((box[0] + box[2]) / 2 / w * cols), cols - 1)]
                count = sum(1 for sw in record.get("swatches", []) if cell_of(sw["box"]) == mine["cell"])
            else:
                count = len(record.get("swatches", []))
            # A piece that names its own count keeps it: the fit reads the first --materials it is given.
            if count >= 2 and "--materials" not in list(s.get("flags", [])) + list(a.get("flags", [])):
                cmd += ["--materials", count]
        s = {**{k: a[k] for k in ("leaf_colour", "wood_colour", "leaf_ramp", "wood_ramp") if k in a}, **s}          # an asset may ask for them in every style
        if s.get("leaf_ramp") or s.get("wood_ramp"):
            # The leaves and the wood coloured from the sheet's own swatches under this object (told apart by
            # colour: the green and yellow-green ones are leaf, the brown ones bark; a pale one is blossom and
            # is left out), or the leaves from the swatches named (a kit's greens).
            import colorsys
            rev = rev_of(a, style)
            record = json.loads((crop_dir(style, a["sheet"], rev) / "boxes.json").read_text())
            mine = next(o for o in record["objects"] if o["k"] == a["obj"])
            cells = CONFIG["sheets"].get(a["sheet"], {}).get("cells")
            own = [sw["hex"] for sw in sorted(record.get("swatches", []), key=lambda w: w["box"][0])]
            if cells and "cell" in mine:
                cols, rows = (int(v) for v in cells.split("x"))
                w, h = record["size"]
                own = [sw["hex"] for sw in sorted(record.get("swatches", []), key=lambda w_: w_["box"][0])
                       if [min(int((sw["box"][1] + sw["box"][3]) / 2 / h * rows), rows - 1), min(int((sw["box"][0] + sw["box"][2]) / 2 / w * cols), cols - 1)] == mine["cell"]]
            def hsv(hexa):
                return colorsys.rgb_to_hsv(*(int(hexa[i:i + 2], 16) / 255 for i in (1, 3, 5)))
            greens = [c for c in own if 45 <= hsv(c)[0] * 360 <= 170 and hsv(c)[1] >= 0.12]
            # Bark is a brown: a hue from red round to orange-yellow. A violet or pink swatch is the blossom's
            # (a neon tree's violet one was taken for bark, and its trunk's lighter half came out violet).
            browns = [c for c in own if c not in greens and (hsv(c)[0] * 360 <= 45 or hsv(c)[0] * 360 >= 345) and hsv(c)[1] >= 0.2 and hsv(c)[2] < 0.85]
            if s.get("leaf_ramp") == "swatches" and len(greens) >= 2:
                cmd += ["--leaf-ramp", ",".join(greens)]
            elif s.get("leaf_ramp") and s["leaf_ramp"] != "swatches":
                cmd += ["--leaf-ramp", s["leaf_ramp"]]
            # The sheet's blossom swatches (what is neither leaf nor bark), for a piece that asks for its flowers
            # to be kept (`blossoms`: the number of texels each is drawn wider by).
            petals = [c for c in own if c not in greens and c not in browns]
            if "--leaf-ramp" in cmd and petals and a.get("blossoms") is not None:
                cmd += ["--leaf-blossoms", ",".join(petals), "--leaf-blossoms-grow", s.get("blossoms", a["blossoms"])]
            if s.get("wood_ramp") == "swatches" and browns:
                cmd += ["--wood-ramp", ",".join(browns if len(browns) > 1 else browns * 2)]
        if s.get("leaf_colour") == "swatches" or s.get("wood_colour") == "swatches":
            rev = rev_of(a, style)
            record = json.loads((crop_dir(style, a["sheet"], rev) / "boxes.json").read_text())
            found = sorted(record.get("swatches", []), key=lambda w: w["box"][0])
            cells = CONFIG["sheets"].get(a["sheet"], {}).get("cells")
            mine = next(o for o in record["objects"] if o["k"] == a["obj"])
            if cells and "cell" in mine:
                # A sheet of several things: the swatches under this one, told apart by their colour. Its
                # leaves in light and in shade are the lightest and the darkest of the green and yellow-green
                # ones; its bark is the one that is not green (the brownest, if there are several).
                cols, rows = (int(v) for v in cells.split("x"))
                w, h = record["size"]
                def cell_of(box):
                    return [min(int((box[1] + box[3]) / 2 / h * rows), rows - 1), min(int((box[0] + box[2]) / 2 / w * cols), cols - 1)]
                own = [sw["hex"] for sw in found if cell_of(sw["box"]) == mine["cell"]]
                def hsv(hexa):
                    import colorsys
                    return colorsys.rgb_to_hsv(*(int(hexa[i:i + 2], 16) / 255 for i in (1, 3, 5)))
                greens = sorted((c for c in own if 45 <= hsv(c)[0] * 360 <= 170 and hsv(c)[1] >= 0.12), key=lambda c: hsv(c)[2])
                others = sorted((c for c in own if c not in greens), key=lambda c: abs(hsv(c)[0] * 360 - 30))
                if s.get("leaf_colour") == "swatches" and len(greens) >= 2:
                    cmd += ["--leaf-colour", f"{greens[-1]},{greens[0]}"]
                if s.get("wood_colour") == "swatches" and others:
                    cmd += ["--wood-colour", others[0]]
            elif s.get("leaf_colour") == "swatches" and len(found) >= 2:
                # A sheet of one tree: its first two swatches, from the left, are its leaves in light and in shade.
                cmd += ["--leaf-colour", f"{found[0]['hex']},{found[1]['hex']}"]
        elif s.get("leaf_colour", a.get("leaf_colour")) == "cell":
            # A planted piece on a sheet of several things: of the swatches under it in its own cell, the green
            # ones (green not less than nine tenths of red, and a fifth more than blue). The lightest is its
            # leaves in light and the darkest its leaves in shade; with one green only, the leaves take that.
            rev = rev_of(a, style)
            record = json.loads((crop_dir(style, a["sheet"], rev) / "boxes.json").read_text())
            greens = []
            for sw in swatches_under(record, a, CONFIG["sheets"].get(a["sheet"], {}).get("cells")):
                r, g, b = (int(sw["hex"][i:i + 2], 16) for i in (1, 3, 5))
                if g >= 0.9 * r and g > 1.2 * b:
                    greens.append((0.2126 * r + 0.7152 * g + 0.0722 * b, sw["hex"]))
            greens.sort()
            if len(greens) >= 2:
                cmd += ["--leaf-colour", f"{greens[-1][1]},{greens[0][1]}"]
            elif greens:
                cmd += ["--leaf-colour", greens[0][1]]
        if a.get("name"):
            cmd += ["--name", a["name"]]
        if a.get("mesh") and not cubes:
            cmd += ["--mesh-name", a["mesh"]]                 # the kit's spec names the piece's mesh part (in a style built from cubes voxelise.py names it)
        if (s.get("water_colour") or a.get("water_colour")) == "swatches":
            # The sheet's water swatch: of its swatches, the one that is blue to teal, the strongest of them.
            import colorsys
            rev = rev_of(a, style)
            found = json.loads((crop_dir(style, a["sheet"], rev) / "boxes.json").read_text()).get("swatches", [])
            wet = []
            for sw in found:
                h, sat, val = colorsys.rgb_to_hsv(*(int(sw["hex"][i:i + 2], 16) / 255 for i in (1, 3, 5)))
                if 165 < h * 360 < 255 and sat > 0.25:
                    wet.append((sat, sw["hex"]))
            if wet:
                cmd += ["--water-colour", max(wet)[1]]
        if (s.get("timber_colour") or a.get("timber_colour")) == "swatches":
            # The sheet's timber swatch (orange to brown, the strongest): what the generator painted as timber is
            # moved to it as a whole (--paint). The range of hue and the least saturation that count as
            # generated timber are the style's to say (`timber_range`); a style whose stone is warm cannot use it.
            import colorsys
            rev = rev_of(a, style)
            found = json.loads((crop_dir(style, a["sheet"], rev) / "boxes.json").read_text()).get("swatches", [])
            brown = []
            for sw in found:
                h, sat, val = colorsys.rgb_to_hsv(*(int(sw["hex"][i:i + 2], 16) / 255 for i in (1, 3, 5)))
                if 8 < h * 360 < 50 and sat > 0.25:
                    brown.append((sat, sw["hex"]))
            if brown:
                cmd += ["--paint", f"{s.get('timber_range', '8,50,0.1')},{max(brown)[1]}"]
        if a.get("post_file"):
            # A fence panel's own post, written beside it as the kit's second file (a railing's `railing_post`).
            cmd += ["--panel-post", out.parent / Path(a["post_file"]).name]
        cmd += [str(f) for f in s.get("flags", [])]
        if CONFIG.get("image_format"):
            cmd += ["--image-format", CONFIG["image_format"], "--image-quality", CONFIG.get("image_quality", 90)]
        # A style whose piece goes another way altogether (a voxel tree, built from its design's own cubes and not
        # as the other styles' planted trees) gives all its options itself: `"flags_replace": true`.
        for flag in ([] if s.get("flags_replace") else a.get("flags", [])):
            cmd.append(flag)
        if BUDGET:
            for flag, value in held.get("set", {}).items():          # the options that differ at the kit's limit
                if flag in cmd:
                    cmd[cmd.index(flag) + 1] = value
                else:
                    cmd += [flag, value]
            for flag in held.get("drop", []):                         # and those (each with one value) that go
                if flag in cmd:
                    del cmd[cmd.index(flag): cmd.index(flag) + 2]
        r = run(cmd)
        line = next((l for l in r.stdout.splitlines() if l.startswith("FIT ")), None)
        if line is None:
            print(f"{style} {key}: FIT FAILED\n{r.stdout[-1500:]}\n{r.stderr[-800:]}")
            failed.append(key)
            continue
        d = json.loads(line[4:])
        if not cubes:
            # Zero tangents, which the kits' validator counts as errors, are replaced in the written file.
            mended = mend_tangents.mend(out)
            if mended:
                d["tangents_mended"] = d.get("tangents_mended", 0) + mended
                report_file = out.with_suffix(".json")
                if report_file.exists():
                    whole = json.loads(report_file.read_text())
                    whole["tangents_mended"] = d["tangents_mended"]
                    report_file.write_text(json.dumps(whole, indent=1) + "\n")
        if cubes:
            cmd = ["blender", "--background", "--factory-startup", "--python-exit-code", "1", "--python", W / "work/voxelise.py", "--",
                   out, final, "--grid", cubes.get("grid", 0.1), "--samples", cubes.get("samples", 4), "--name", a.get("name", final.stem), "--mesh", a.get("mesh", "body"),
                   "--rough", s.get("rough", 0.9), "--report", final.with_suffix(".cubes.json")]
            if cubes.get("glow"):
                cmd += ["--glow", cubes["glow"]]
            if cubes.get("light"):
                cmd += ["--light", cubes["light"]]          # the cubes that glow as a part of their own (a lamp's `light`)
            for flag in cubes.get("flags", []):
                cmd.append(str(flag))
            if cubes.get("solid"):
                cmd += ["--solid", cubes["solid"]]          # a planting bed: a solid block to its rim
            if cubes.get("sheets"):
                cmd += ["--sheets", cubes["sheets"]]                       # a panel in a frame, thinner than half a cell
            if cubes.get("hollows"):
                cmd.append("--hollows")                                    # bowls and tiers the generator made as shells
            if d.get("fountain"):
                # a fountain's basin stays the round ring the fit built on its footprint (and the water's disc with
                # it): cubes cannot follow the circle. Only what stands inside the ring is rebuilt.
                cmd += ["--keep-outside", round(d["fountain"]["ring"]["inner_m"] - 0.005, 3)]
            crown_from = (d.get("tree") or d.get("planted") or {}).get("crown_starts_m")
            if cubes.get("trunk"):
                # A cube tree: the crown from where the design's green begins, the trunk built as the kit's column.
                cmd += ["--upper", f"auto,{cubes['upper']}", "--planted-trunk", cubes["trunk"]]
                rev = rev_of(a, style)
                record = json.loads((crop_dir(style, a["sheet"], rev) / "boxes.json").read_text())
                under = swatches_under(record, a, CONFIG["sheets"].get(a["sheet"], {}).get("cells"))
                if under and cubes.get("tones", True):
                    cmd += ["--tones", ",".join(sw["hex"] for sw in under)]          # the crown's cubes in the sheet's own greens
                if cubes.get("tone_shares"):
                    cmd += ["--tone-shares", cubes["tone_shares"]]
                if cubes.get("jumble"):
                    cmd += ["--jumble", cubes["jumble"]]
            elif cubes.get("upper") and crown_from is not None:
                cmd += ["--upper", f"{crown_from},{cubes['upper']}"]          # the crown in larger cubes
                if cubes.get("jumble"):
                    cmd += ["--jumble", cubes["jumble"]]
            if a.get("planted"):
                cmd.append("--planted")                 # trunk and leaves stay two materials: the game reads their names
            if cubes.get("upper_cover"):
                cmd += ["--upper-cover", cubes["upper_cover"]]
            if cubes.get("upper_solid"):
                cmd.append("--upper-solid")
            r = run(cmd)
            vline = next((l for l in r.stdout.splitlines() if l.startswith("VOXEL ")), None)
            if vline is None:
                print(f"{style} {key}: CUBES FAILED\n{r.stdout[-1200:]}\n{r.stderr[-600:]}")
                failed.append(key)
                continue
            v = json.loads(vline[6:])
            if a.get("post_file"):
                # The post is rebuilt from cubes on the same grid, from the fitted post beside the fitted panel.
                post_mid, post_final = out.parent / Path(a["post_file"]).name, final.parent / Path(a["post_file"]).name
                r = run(["blender", "--background", "--factory-startup", "--python-exit-code", "1", "--python", W / "work/voxelise.py", "--",
                         post_mid, post_final, "--grid", cubes.get("grid", 0.1), "--samples", cubes.get("samples", 4), "--name", post_final.stem,
                         "--mesh", a.get("post_mesh", a.get("mesh", "body")), "--rough", s.get("rough", 0.9), "--report", post_final.with_suffix(".cubes.json")]
                        + [str(f) for f in cubes.get("post_flags", cubes.get("flags", []))])
                pline = next((l for l in r.stdout.splitlines() if l.startswith("VOXEL ")), None)
                if pline is None:
                    print(f"{style} {key}: CUBES FAILED for the post\n{r.stdout[-1200:]}\n{r.stderr[-600:]}")
                    failed.append(key)
                    continue
                v["post"] = json.loads(pline[6:])
            merged = {**d, "fitted_tris": d["tris"], "tris": v["tris"], "bytes": v["bytes"], "cubes": v}
            final.with_suffix(".json").write_text(json.dumps(merged, indent=1) + "\n")
            print(f"{style} {key}: rebuilt from {v['filled']} cubes of {v['grid_m']} m ({v['filled_as_thin_members']} of them thin members): {v['tris']} tris, texture {v['texture_px']} px, {v['bytes'] / 1e3:.0f} kB; "
                  f"the fitted piece it was made from: {d['tris']} tris, colour off the design by {d.get('colour_delta_e')}")
            continue
        dev = d["deviation"]
        for zone in ("shelter", "fountain", "water", "glass", "lamp_faces"):
            if d.get(zone):
                print(f"{style} {key}: {zone}: {json.dumps(d[zone])}")
        print(f"{style} {key}: {d['tris']} tris (kit {d.get('kit_tris')}), turn {d['yaw']:.0f}, stretch {d.get('stretch')}, "
              f"off the generated surface: mean {dev['mean_mm']} mm, 95% within {dev['p95_mm']} mm, worst {dev['max_mm']} mm; "
              f"texels used {d['texels_used']}; colour off the design by {d.get('colour_delta_e')} ({d.get('materials_reached', 0) * 100:.0f}% of its materials reached); "
              f"{d['bytes'] / 1e6:.1f} MB" + (f", glow {d['glow_share'] * 100:.1f}% of texels" if "glow_share" in d else "")
              + (f", seat top {d['seat_top_m']['generated']} m moved to the kit's {d['seat_top_m']['kit']} m" if d.get("seat_top_m") else "")
              + (f", its post alone: {d['panel']['post']['tris']} tris" if d.get("panel", {}).get("post") else ""))
    if failed:
        sys.exit(f"fit failed for: {', '.join(failed)} (nothing is placed for a piece that did not build)")


def place(style, names, restore=False):
    """Copies each built piece over the kit's in the working copy of the game, or puts the kit's back. A kit
    piece with a texture has that texture beside it in the repository (the engine pulled it out of the file at
    import); it is put back with the piece. The textures the engine pulled out of a built piece are named
    <piece>_<piece>*.png and go when the kit's piece returns. The engine's cached import of the piece goes
    either way (it is named for the piece's own path, so other styles' pieces of the same name keep theirs),
    so the next import reads the file that is there now. Until that import has run the game cannot load
    the piece: the capture tools and run_game.sh import first."""
    for key, a in wanted(names).items():
        if style not in a.get("only", [style]):
            continue
        a = for_style(a, style)
        if "file" not in a:
            continue
        target = GAME / "city" / "godot" / "styles" / style / a["file"]
        kit = STYLES / style / a["file"]
        source = kit if restore else (out_dir(a) / style / Path(a["file"]).name)
        if not source.exists():
            print(f"{style} {key}: nothing built")
            continue
        for mine in target.parent.glob(f"{target.stem}_{target.stem}*.png*"):
            mine.unlink()
        shutil.copyfile(source, target)
        for beside in kit.parent.glob(target.stem + "_*.png*"):          # the kit piece's own textures and their import files
            shutil.copyfile(beside, target.parent / beside.name)
        cache_name = hashlib.md5(f"res://styles/{style}/{a['file']}".encode()).hexdigest()
        for cached in (GAME / "city" / "godot" / ".godot" / "imported").glob(f"{target.name}-{cache_name}.*"):
            cached.unlink()
        # A planted piece's far twin (<piece>_far.glb, drawn beyond 90 m wherever it sits beside the piece) goes with it, where
        # the kit has one: left as the kit's, the tree would turn back into the kit's at a distance.
        far = ""
        kit_far = kit.with_name(kit.stem + "_far.glb")
        far_source = kit_far if restore else source.with_name(source.stem + "_far.glb")
        if kit_far.exists() and far_source.exists():
            far_target = target.with_name(target.stem + "_far.glb")
            for mine in far_target.parent.glob(f"{far_target.stem}_{target.stem}*.png*"):
                mine.unlink()
            shutil.copyfile(far_source, far_target)
            far_file = a["file"][:-4] + "_far.glb"
            far_cache = hashlib.md5(f"res://styles/{style}/{far_file}".encode()).hexdigest()
            for cached in (GAME / "city" / "godot" / ".godot" / "imported").glob(f"{far_target.name}-{far_cache}.*"):
                cached.unlink()
            far = " (and its far twin)"
        # A fence panel's own post (a second file of the kit, `post_file`) goes with it.
        post = ""
        if a.get("post_file"):
            post_target = GAME / "city" / "godot" / "styles" / style / a["post_file"]
            post_source = (STYLES / style / a["post_file"]) if restore else (out_dir(a) / style / Path(a["post_file"]).name)
            if post_source.exists():
                for mine in post_target.parent.glob(f"{post_target.stem}_{post_target.stem}*.png*"):
                    mine.unlink()
                shutil.copyfile(post_source, post_target)
                for beside in (STYLES / style / a["post_file"]).parent.glob(post_target.stem + "_*.png*"):
                    shutil.copyfile(beside, post_target.parent / beside.name)
                post_cache = hashlib.md5(f"res://styles/{style}/{a['post_file']}".encode()).hexdigest()
                for cached in (GAME / "city" / "godot" / ".godot" / "imported").glob(f"{post_target.name}-{post_cache}.*"):
                    cached.unlink()
                post = " (and its post)"
        print(f"{style} {key}: {'kit piece restored' if restore else 'placed'} -> {a['file']}{far}{post}")


def try_(style, label, names):
    """Each asset's own views, all in one start of the game (asset_try_many.sh): starting it is most of what a
    capture costs. An asset without a `needle` is left out."""
    jobs = []
    for key, a in wanted(names).items():
        if style not in a.get("only", [style]):
            continue
        a = for_style(a, style)
        if "file" not in a or not a.get("needle") or a.get("capture") is False:
            continue
        jobs.append(f"{a['needle']}@{key}:{a.get('frame', 'prop')}:{a.get('count', 3)}")
    if not jobs:
        print(f"{style}: nothing to capture")
        return
    r = run([GAME / "asset_try_many.sh", style, W / "captures" / label, ",".join(jobs)], cwd=GAME)
    for line in r.stdout.strip().splitlines() or ["?"]:
        print(line[:200])


def main(argv):
    argv = [x for x in argv if x != "--budget"]
    step, style, rest = argv[0], argv[1], argv[2:]
    if step == "cut":
        cut(style, rest)
    elif step == "gen":
        gen(style, rest)
    elif step == "fit":
        fit(style, rest)
    elif step == "place":
        place(style, rest)
    elif step == "restore":
        place(style, rest, restore=True)
    elif step == "try":
        try_(style, rest[0], rest[1:])
    elif step == "seats":
        pairs = []
        for key, a in wanted([]).items():
            # the seats whose tops the fit moves to the kit's height, and those measured without being moved (the
            # perch seat fills its kit's box and has no seat top of its own to move)
            if style not in a.get("only", [style]) or not ("--seat" in a.get("flags", []) or a.get("measure_seat")):
                continue
            a = for_style(a, style)
            pairs += [f"kit+{style}+{key}={STYLES / style / a['file']}", f"new+{style}+{key}={out_dir(a) / style / Path(a['file']).name}"]
        print(" ".join(pairs))
    elif step == "all":
        fit(style, rest)
        place(style, rest)
        try_(style, "new", rest)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
