"""check.py [--variant NAME | --budget]: each built piece against what its kit and the game hold a piece to.

  * the kit's spec (city/tools/styles/<kit>/specs/*.json) by the kit tests' own rule: each axis within 10% + 2 cm
    of the spec's size and its named nodes present. The spec's triangle limit is reported against (`over_limit`)
    and is a miss only for the builds made to stay inside it (--budget): the limit stood in for frame cost,
    which the bench measures;
  * for the great tree (a piece the game fills to its footprint): what it draws in the walking band, by the
    game's own measure (the pilot's band.py), against the 5.2 by 5.1 m footprint; more than 1.1 cm outside it
    is a miss, because the game then squeezes the whole piece;
  * for the square's fountain and the tram shelter: the rules of their contract notes that the game or its
    tests enforce and that the file alone can show (piece_rules.py lists them): the collision audit's three
    counts that need no simulated day, the shelter's walking-band slice against its footprint box and its
    bench's top, the fountain's outer face, its rim where the perch seats meet it and its water part, and the
    names the game acts on;
  * for a shrub (an entry whose flags have --shrub) and a kerbed bed (--bed): what the game and its tests hold
    such a piece to, as far as the file shows it (planting_rules.py lists the rules, where each comes from, and
    what cannot be checked from a file): one mesh, no node transform, the kit's reach, a whole circle where
    people walk and at most two materials for a shrub; the kerb a whole rectangle higher than 0.25 m for a
    bed, and in neon its `lights` with an emitting `lamp_glow`; no material named as the game names what it
    lights or wets;
  * the scale the game really gave it (from the captures of it), its file size against the kit piece's.

  * for a piece whose entry names `rules` (the café terrace: "table", "umbrella", "planter"): what the game does
    with that kind, checked from the file alone by terrace_rules.py (its top lists the rules): the fill and the
    collision audit's cells, the root, the ground and the material names, the pole on its axis and inside the
    table's column, the plants inside the planter's outline;
  * where an entry says a piece `departs` from its spec on an axis by decision (a planter kept at its design's
    height), that axis is reported as a departure, with the reason, and is not a miss;
  * for a piece the game plants by the hundred (`planted`: a street tree, a palm): planted_rules.py (one mesh
    node, a leaf-named and a trunk material, the trunk's reach as the game measures it, the trunk's foot on the
    origin, the far twin);
  * for a street fixture (an entry with `contract`: lamp, bollard or railing; a railing's `post_file` is checked
    as its post, a row of its own named `<asset> post`): the rules the game and its tests hold it to that a file
    can show, in fixture_rules.py (the collision audit's reach for a post, the lamp's `light` part and
    `lamp_glow`, a panel's length, single mesh and symmetry, the post's fit to its panel, material and node
    names). A railing and its post are held to their kit's triangle limit, because the game draws them by the
    hundred. Such a piece is also put through the Khronos validator the kits' tests use, when it is installed
    (validate.cjs): an error or a warning is a miss, as it is in those tests;
  * a fixture's entry may say `size_as_drawn` (for its post `post_size_as_drawn`): {axis: why} for the axes on
    which the piece keeps the size its design drew and not the kit's spec (a lamp post without the kit's
    cross-bar). On those axes a difference from the spec is printed and recorded (`off_spec`), not counted as a
    miss. (`departs` above says the same of a terrace piece, and prints it on a line of its own.)

The game's own collision audit is not run here: audit.sh runs it on the working copy of the game with the pieces
in place (run_all.sh does, and keeps what it prints in out/audit-<style>.txt).

--kits runs the planting rules on the kits' own pieces instead (they pass the game's tests, so they must pass
these: a check of the rules themselves).

Prints a table, writes results.json beside the built pieces. Exit 1 if any piece misses its kit's spec or a rule.
"""
import json
import math
import os
import subprocess
import sys
from pathlib import Path

W = Path(__file__).resolve().parent.parent
AGENTNAGAR = Path(os.environ["AGENTNAGAR"])
TOOLS = AGENTNAGAR / "docs" / "research" / "2026-10-01-asset-to-sheet-pilot" / "tools"
STYLES = AGENTNAGAR / "city" / "tools" / "styles"
sys.dont_write_bytecode = True          # the modules below are imported from other folders of the checkout: leave no cache there
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(STYLES / "shared"))
sys.path.insert(0, str(STYLES / "lowpoly"))
sys.path.insert(0, str(W / "work"))
import band  # noqa: E402
import test_assets as kit_tests  # noqa: E402
import terrace_rules  # noqa: E402
import planted_rules  # noqa: E402
import piece_rules  # noqa: E402
import fixture_rules  # noqa: E402
import planting_rules  # noqa: E402

KIT = {"lowpoly_tropical": "lowpoly", "neon_noir": "neon", "anime_cel": "anime", "solarpunk": "solarpunk", "voxel": "voxel"}
FOOTPRINT = {"tree_banyan": [-2.6, -2.55, 2.6, 2.55], "tree_large": [-2.6, -2.55, 2.6, 2.55]}
variant = sys.argv[sys.argv.index("--variant") + 1] if "--variant" in sys.argv else None
budget = "--budget" in sys.argv          # the pieces held to their kit's triangle limit (out-budget/)
folder = "out-budget" if budget else ("out-" + variant if variant else "out")
config = json.loads((W / "work" / "assets.json").read_text())
rows, ok = [], True


def planting(path, kit_file, style, flags, stem):
    """The planting rules on one file: (problems, numbers, a few words for the table)."""
    tris = band.triangles(path)
    problems, numbers = planting_rules.names(path, style, stem)
    words = ""
    if "--shrub" in flags:
        kit_pts = planting_rules.band_points([t for part in band.triangles(kit_file).values() for t in part])
        kit_reach = max(math.hypot(x, z) for x, z in kit_pts)
        more, shrub = planting_rules.shrub(path, tris, style, kit_reach)
        problems += more
        numbers.update(shrub)
        words = (f"shrub: reach {shrub['reach_m']:.3f} m (kit's {kit_reach:.3f}), so drawn x{shrub['drawn_scale_across']} across; "
                 f"its outline where people walk reaches at least {shrub['circle_least']:.3f} of the circle; {len(shrub['materials'])} material(s), {len(shrub['mesh_nodes'])} mesh")
    if "--bed" in flags:
        fit = 2.0 if style == "voxel" else 3.0                     # the skins' `fit` lengths (styles/*/style.json props.flowerbed)
        copies = max(1, round(3.30 / fit))
        more, bed_numbers = planting_rules.bed(path, tris, style, (3.30, 1.30), copies)
        problems += more
        numbers.update(bed_numbers)
        words = (f"bed: slice {bed_numbers['slice_m'][0]:.3f} by {bed_numbers['slice_m'][1]:.3f} m, so drawn x{3.30 / copies / bed_numbers['slice_m'][0]:.3f} long, x{1.30 / bed_numbers['slice_m'][1]:.3f} deep"
                 f"{' in two copies' if copies > 1 else ''}; kerb above 0.25 m along {bed_numbers['edge_points'] - bed_numbers['edge_points_bare']} of {bed_numbers['edge_points']} edge points")
    return problems, numbers, words


if "--kits" in sys.argv:
    bad = False
    for style, kit in KIT.items():
        for key, a in config["assets"].items():
            flags = a.get("flags", [])
            if not ("--shrub" in flags or "--bed" in flags) or a.get("variant") or style not in a.get("only", [style]):
                continue
            file = a.get("style", {}).get(style, {}).get("file", a.get("file"))
            kit_file = AGENTNAGAR / "city" / "godot" / "styles" / style / file
            problems, numbers, words = planting(kit_file, kit_file, style, flags, Path(file).stem)
            if style == "neon_noir":
                problems = [q for q in problems if "`lamp_glow` on `lights`" not in q]
            bad = bad or bool(problems)
            print(f"{style:17s} {key:12s} the kit's own {Path(file).name}: {words}" + ("; MISSES: " + "; ".join(problems) if problems else "; passes"))
    sys.exit(1 if bad else 0)


def validated(path):
    """(errors, warnings) from the kits' validator, or None where it is not installed."""
    try:
        r = subprocess.run(["node", str(W / "work" / "validate.cjs"), str(path)], capture_output=True, text=True)
    except FileNotFoundError:
        return None                           # no node on this machine
    if r.returncode == 2 or not r.stdout.strip():
        return None
    words = r.stdout.splitlines()[0].rsplit(":", 1)[1].split()
    return int(words[0]), int(words[2])


def check_piece(style, key, a, file, role, specs, waived, partner=None, second=False):
    """One built file against its kit's spec and the rules for its kind. `role` is a street fixture's (its
    `contract`, or `railing_post` for a railing's second file, which is checked with `second` set: what the
    entry says of its own piece, `departs`, `rules`, `planted`, is not asked of the post). Returns a fixture's
    triangles by node (its post is checked against them), an empty dict for any other piece, or None where the
    file is not built."""
    global ok
    path = W / folder / style / Path(file).name
    if not path.exists():
        return None
    stem = path.stem
    spec = specs[stem]
    size, tris = kit_tests.glb_stats(path)
    kit_file = AGENTNAGAR / "city" / "godot" / "styles" / style / file
    kit_size, kit_tris = kit_tests.glb_stats(kit_file)
    problems, notes, departures, off_spec = [], [], [], {}
    departs = {} if second else a.get("departs", {})
    for axis, got, want in zip("xyz", size, spec["size"]):
        if abs(got - want) > 0.1 * want + 0.02:
            if axis in departs:
                departures.append(f"{axis} {got:.2f} m against the spec's {want} m: {departs[axis]}")
            elif axis in waived:
                off_spec[axis] = {"got": round(got, 3), "spec": want, "why": waived[axis]}
                notes.append(f"{axis} {got:.2f} m against the spec's {want} m, as drawn ({waived[axis]})")
            else:
                problems.append(f"{axis} {got:.2f} m against the spec's {want} m")
    # The kit's triangle limit is reported, not held to (assets.json says why); only a build made to stay
    # inside it (--budget) fails on it, and a piece the game draws by the hundred (a railing, its post).
    over_limit = tris > spec["tris"]
    if over_limit and (budget or role in ("railing", "railing_post")):
        problems.append(f"{tris} triangles, limit {spec['tris']}")
    missing = sorted(set(spec.get("nodes", [])) - kit_tests.node_names(path))
    if missing:
        problems.append(f"nodes missing: {missing}")
    row = {"style": style, "asset": key, "file": file, "size_m": [round(v, 2) for v in size], "spec_size_m": spec["size"], "triangles": tris,
           "budget": spec["tris"], "over_limit": over_limit, "kit_triangles": kit_tris, "nodes": sorted(kit_tests.node_names(path)), "spec_nodes": spec.get("nodes", []),
           "bytes": path.stat().st_size, "kit_bytes": kit_file.stat().st_size}
    if off_spec:
        row["off_spec"] = off_spec
    if stem in FOOTPRINT:
        fp = FOOTPRINT[stem]
        box, _ = band.band_box(path)
        over = max(fp[0] - box[0], fp[1] - box[1], box[2] - fp[2], box[3] - fp[3])
        row["band_box"] = [round(v, 2) for v in box]
        row["outside_footprint_cm"] = round(over * 100, 1)
        notes.append(f"in the walking band {box[2] - box[0]:.2f} by {box[3] - box[1]:.2f} m (footprint 5.2 by 5.1)")
        if over > 0.011:
            problems.append(f"reaches {over * 100:.0f} cm outside its footprint where people walk: the game will squeeze it")
    if stem in ("tram_shelter", "fountain"):
        rules = piece_rules.shelter_rules if stem == "tram_shelter" else piece_rules.fountain_rules
        more_problems, more_notes, numbers = rules(path, style, AGENTNAGAR)
        problems += more_problems
        notes += more_notes
        row["piece_rules"] = numbers
    flags = [] if second else a.get("flags", [])
    if "--shrub" in flags or "--bed" in flags:
        more, numbers, words = planting(path, kit_file, style, flags, stem)
        problems += more
        row["planting"] = numbers
        notes.append(words)
    by_node = {}
    if role:
        by_node = band.triangles(path)
        more, said, facts = fixture_rules.rules(role, style, path, kit_tests.glb_json(path), by_node, band, partner)
        problems += more
        notes += said
        row["fixture_rules"] = {"role": role, **facts}
        verdict = validated(path)
        row["validator"] = None if verdict is None else {"errors": verdict[0], "warnings": verdict[1]}
        if verdict is None:
            notes.append("validator not installed, not run")
        elif verdict[0] or verdict[1]:
            problems.append(f"the Khronos validator: {verdict[0]} errors, {verdict[1]} warnings")
        else:
            notes.append("passes the Khronos validator")
    views = W / "captures" / "new" / a.get("raw", key) / style / "asset-views.json"
    if views.exists() and not variant and not budget:
        seen = json.loads(views.read_text())["views"]
        if seen:
            row["game_scale"] = [round(seen[0]["scale"][0], 3), round(seen[0]["scale"][2], 3)]
            notes.append(f"the game placed it scaled {row['game_scale'][0]} by {row['game_scale'][1]}")
    ruled = []
    terrace = None if second else a.get("rules")
    if terrace:
        # The same style's built table, for an umbrella: its pole has to hide in that table's column.
        beside = None
        if terrace == "umbrella":
            for other in config["assets"].values():
                if other.get("rules") == "table" and other.get("variant") == variant:
                    beside = W / folder / style / Path(other.get("style", {}).get(style, {}).get("file", other["file"])).name
        more, ruled, numbers = terrace_rules.check(terrace, style, path, kit_file, beside)
        problems += more
        row["rules"] = terrace
        row.update(numbers)
    if a.get("planted") and not second:
        more, said, numbers = planted_rules.check(style, path, kit_file)
        problems += more
        notes += said
        row["planted"] = numbers
    row["problems"] = problems
    row["departures"] = departures
    rows.append(row)
    ok = ok and not problems
    held = "size, parts" + (" and footprint" if stem in FOOTPRINT else "") + (" and the piece's own rules" if "piece_rules" in row else "") + (" and the game's rules for " + {"table": "a table", "umbrella": "an umbrella", "planter": "a planter"}[terrace] if terrace else "") + " as the kit's spec"
    if departures:
        held = "parts" + (" and the game's rules for " + {"table": "a table", "umbrella": "an umbrella", "planter": "a planter"}[terrace] if terrace else "") + " as the kit's spec; size but for a departure"
    if role:
        held += ", the fixtures' rules met"
    print(f"{style:17s} {key:18s} {size[0]:5.2f} x {size[1]:4.2f} x {size[2]:5.2f} m  {tris:6d} tris (kit's limit {spec['tris']}{', over it' if over_limit else ''}; kit's piece {kit_tris})  "
          f"{row['bytes'] / 1e6:4.1f} MB (kit's {row['kit_bytes'] / 1e3:.0f} kB)  "
          + ("MISSES: " + "; ".join(problems) if problems else held) + ("; " + "; ".join(notes) if notes else ""))
    for line in departures:
        print(f"{'':36s} departs by decision: {line}")
    for line in ruled:
        print(f"{'':36s} {line}")
    return by_node


for style, kit in KIT.items():
    specs = {}
    for f in sorted((STYLES / kit / "specs").glob("*.json")):
        specs.update(json.loads(f.read_text()))
    for key, a in config["assets"].items():
        if a.get("variant") != variant or style not in a.get("only", [style]):
            continue
        own = a.get("style", {}).get(style, {})
        a = {**a, **{k: own[k] for k in ("file", "needle", "name", "mesh", "post_file", "size_as_drawn", "post_size_as_drawn") if k in own}}          # a style's own file and names
        if not a.get("file"):
            continue                          # generated, not fitted yet; or a style whose kit has no such piece (`"file": null`)
        if budget and style not in a.get("budget", {}):
            continue
        panel = check_piece(style, key, a, a["file"], a.get("contract"), specs, a.get("size_as_drawn", {}))
        if panel is not None and a.get("post_file") and a.get("contract") == "railing":
            check_piece(style, key + " post", a, a["post_file"], "railing_post", specs, a.get("post_size_as_drawn", {}),
                        partner=[tri for tris in panel.values() for tri in tris], second=True)
out = W / folder / "results.json"
out.write_text(json.dumps(rows, indent=1) + "\n")
sys.exit(0 if ok else 1)
