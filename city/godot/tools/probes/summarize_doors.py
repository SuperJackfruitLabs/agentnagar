#!/usr/bin/env python3
"""Summarises door_probe.gd output (spike, not production).

python3 summarize_doors.py OUT.txt [OUT2.txt ...]
Prints success counts per door x control x family, the failure modes, and
the rows that failed with their end place and the prediction's reasons.
"""
import json, sys, collections

rows = []
for path in sys.argv[1:]:
    for line in open(path):
        if line.startswith("ROW "):
            rows.append(json.loads(line[4:]))

def mode(r):
    if r["inside"]:
        return "inside"
    if not r.get("placed", True) and r["start_room"] == r["room"]:
        return "bad-setup"
    evs = r["events"]
    if any(k.startswith("Waitlisted") for k in evs) or (r.get("loc", "").startswith("waiting")):
        return "waitlisted"
    why = r.get("why") or []
    if why:
        first = why[0].split(":", 1)[1]
        return "stopped:" + first + ("/slides:" + ",".join(w.split(":", 1)[1] for w in why[1:]) if len(why) > 1 else "")
    return "other:" + str(r.get("loc"))

tab = collections.OrderedDict()
for r in rows:
    k = (r["style"], r["door"], r["control"], r["family"])
    tab.setdefault(k, []).append(r)
print("%-18s %-26s %-13s %-7s %s" % ("style", "door", "control", "family", "inside/total  failure modes"))
for k, rs in tab.items():
    ok = sum(1 for r in rs if r["inside"])
    modes = collections.Counter(mode(r) for r in rs if not r["inside"])
    print("%-18s %-26s %-13s %-7s %2d/%-2d  %s" % (k[0], k[1], k[2], k[3], ok, len(rs), dict(modes)))
if "-v" in sys.argv or True:
    print()
    print("Failures:")
    for r in rows:
        if r["inside"]:
            continue
        print("  %s %s %s %s off=%s ang=%s gdir=%s keys=%s -> end %s along=%s depth=%s span=%s loc=%s ev=%s why=%s mism=%s gos=%s aim=%s" % (
            r["style"], r["door"], r["control"], r["family"], r["offset"], r["angle"], r.get("ground_dir_deg"), r.get("keys"),
            r.get("end_room"), r.get("end_along"), r.get("end_depth"), r.get("end_in_span"), r.get("loc"), r["events"], r.get("why"),
            r["mismatch"], r.get("gos"), r.get("aim")))
