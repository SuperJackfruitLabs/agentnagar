"""cut_panels.py [STYLE ...]: cuts every concept-sheet panel that the game has a matching capture for, with
the project's own sheet layout (city/godot/tools/sheet_compare.py: which sheet, row and column each view is,
and which revision the style study selects), into panels/<style>-<view>.png.

For a new asset: find it in one of these panels, note its box (grid.py draws a labelled grid to read it off),
and measure the same box's counterpart in the game's capture of the same view (try.sh).

The banyan pilot's own crops (sheets/, inputs/) were cut by hand before this helper existed and include the
panels' caption strip; the patch boxes in bands.py refer to those, so they are kept as they are.
"""
import os
import sys
from pathlib import Path

W = Path(__file__).resolve().parent
AGENTNAGAR = Path(os.environ["AGENTNAGAR"])
sys.path.insert(0, str(AGENTNAGAR / "city" / "godot" / "tools"))
import sheet_compare as project  # noqa: E402

out = W / "panels"
out.mkdir(exist_ok=True)
wanted = sys.argv[1:]
for style, study_name in project.STYLES:
    if wanted and style not in wanted:
        continue
    study = AGENTNAGAR / "docs" / "vision" / "style-studies" / "styles" / study_name
    for view, sheet, row, col in project.PAIRS:
        chosen = project.selected(study, sheet)
        project.panel(chosen, row, col).save(out / f"{style}-{view}.png")
        print(f"{style}-{view}.png  from {sheet}/{chosen.parent.name}, row {row}, column {col}")
