#!/usr/bin/env python3
"""Tables door_probe.gd sweep rows (spike): approach angle x where the line
crosses the door. Y = ended inside; s = slid along the wall past the door
(ended beyond the span); | = stopped at the wall/jamb; w = waitlisted; ? = other.
python3 sweep_table.py OUT.txt [family]"""
import json, sys, collections
fam = sys.argv[2] if len(sys.argv) > 2 else "sweep"
rows = [json.loads(l[4:]) for l in open(sys.argv[1]) if l.startswith("ROW ")]
rows = [r for r in rows if r["family"] == fam]
by = collections.defaultdict(dict)
for r in rows:
    by[r["door"]][(r["angle"], r["offset"])] = r
def sym(r):
    if r["inside"]:
        return "Y"
    if r.get("loc", "").startswith("waiting"):
        return "w"
    along = r.get("end_along")
    if along is not None and abs(along) > 75:
        return "s"
    return "|"
for door, cells in by.items():
    angs = sorted({a for a, _ in cells})
    offs = sorted({o for _, o in cells})
    print("\n%s (%s): rows = approach angle from the door normal (deg), cols = where the line crosses the door (cm from centre)" % (door, rows[0]["style"]))
    print("  ang " + " ".join("%4d" % o for o in offs) + "   inside")
    tot = ok = 0
    for a in angs:
        line = [sym(cells[(a, o)]) for o in offs if (a, o) in cells]
        tot += len(line); ok += line.count("Y")
        print("  %4d " % a + " ".join("%4s" % s for s in line) + "   %d/%d" % (line.count("Y"), len(line)))
    print("  total inside %d/%d" % (ok, tot))
