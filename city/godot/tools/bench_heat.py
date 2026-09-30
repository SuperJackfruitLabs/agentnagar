#!/usr/bin/env python3
"""Puts each bench scene's GPU heat beside its result, so a scene slowed by
a hot, throttled GPU can be told apart from one that costs too much:

    python3 city/godot/tools/bench_heat.py BENCH_JSON GPU_CSV

BENCH_JSON is tools/bench.gd's output, whose results carry the Unix times
each scene started and ended ("t0", "t1"). GPU_CSV holds the samples
scripts/bench.sh takes while the bench runs, one a line: Unix time,
temperature in degrees C, graphics clock in MHz. Prints a table of each
scene's peak temperature and its lowest and median graphics clock, and
writes them into BENCH_JSON as gpu_peak_c, gpu_clock_min_mhz and
gpu_clock_median_mhz. A scene with no samples shows "-".
"""
import json
import statistics
import sys
from pathlib import Path


def samples(path: Path):
    out = []
    for line in path.read_text().splitlines():
        parts = [p.strip() for p in line.split(",")]
        if len(parts) != 3:
            continue
        try:
            out.append((float(parts[0]), int(parts[1]), int(parts[2])))
        except ValueError:
            continue
    return out


def heat(result: dict, taken) -> dict:
    inside = [s for s in taken if result["t0"] <= s[0] <= result["t1"]]
    if not inside:
        return {}
    clocks = [s[2] for s in inside]
    return {"gpu_peak_c": max(s[1] for s in inside), "gpu_clock_min_mhz": min(clocks),
        "gpu_clock_median_mhz": round(statistics.median(clocks))}


def main(argv):
    bench_path, gpu_path = Path(argv[0]), Path(argv[1])
    bench = json.loads(bench_path.read_text())
    taken = samples(gpu_path)
    print(f"{'style':<18} {'scene':<24} {'peak C':>6} {'min MHz':>7} {'median MHz':>10}")
    for r in bench["results"]:
        h = heat(r, taken) if "t0" in r and "t1" in r else {}
        r.update(h)
        if h:
            print(f"{r['style']:<18} {r['scene']:<24} {h['gpu_peak_c']:>6} {h['gpu_clock_min_mhz']:>7} {h['gpu_clock_median_mhz']:>10} ")
        else:
            print(f"{r['style']:<18} {r['scene']:<24} {'-':>6} {'-':>7} {'-':>10} ")
    bench_path.write_text(json.dumps(bench, indent=2))


if __name__ == "__main__":
    main(sys.argv[1:])
