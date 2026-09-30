"""Replay the same geometry/rig/export steps inside a fresh background Blender."""
import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
STEPS = ("create", "refine-hands", "finish-hands", "rig", "animate", "export-wave")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "output")
    parser.add_argument("--render", action="store_true", help="Also render the Cycles stills")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    output = args.output.expanduser().resolve()
    # Keep earlier assets intact; use a new destination for every replay.
    output.mkdir(parents=True, exist_ok=False)
    for step in STEPS:
        path = ROOT / "steps" / f"{step}.py"
        print(f"REFERENCE STEP: {step}", flush=True)
        exec(compile(path.read_text(), str(path), "exec"), {
            "__name__": "__main__", "OUTPUT_DIR": str(output), "RENDER_PREVIEWS": args.render,
        })
    print(f"REFERENCE REPLAY PASSED: {output}", flush=True)


if __name__ == "__main__":
    main()
