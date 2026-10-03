"""check_docs.py FOLDER: what the record's pages name, held against what is there.

For README.md, WORKFLOW.md and families/*.md in FOLDER (the record, or record-draft/ in the working folder with
the tools beside it in ../work): every option written `--like-this` must be read somewhere in the tools, every
script named `like_this.py`, `.sh`, `.gd` or `.cjs` must be in the tools, and every picture or file named under
compare/, previews/, out*/, bench/, notes/ or families/ must exist (a name with <style> or another <word> in it is
tried for each of the five styles, and counts when one exists). A build agent's report names scripts of the game
and of its own folder, and files of its own folder: on such a page only a script written `tools/like_this.py` is
held to the tools, and the files are not looked for. Prints what is missing; exit 1 if anything is.

    python3 tools/check_docs.py .
"""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
tools = root / "tools" if (root / "tools").is_dir() else root.parent / "work"
code = "\n".join(p.read_text(errors="ignore") for p in sorted(tools.iterdir()) if p.is_file() and p.suffix in (".py", ".sh", ".gd", ".cjs"))
pages = [p for p in [root / "README.md", root / "WORKFLOW.md"] + sorted((root / "families").glob("*.md")) if p.exists()]
STYLES = ("lowpoly_tropical", "neon_noir", "anime_cel", "solarpunk", "voxel")
missing = []
for page in pages:
    text = page.read_text()
    for option in sorted(set(re.findall(r"`(--[a-z][a-z0-9-]*)", text))):
        if f'"{option}"' not in code and f"'{option}'" not in code and f"{option} " not in code and f"{option}\n" not in code:
            missing.append(f"{page.name}: option {option} is not in the tools")
    agents = page.parent.name == "families" and "the agent's own folder" in text
    named = r"`tools/([a-z_0-9]+\.(?:py|sh|gd|cjs))" if agents else r"`(?:tools/|work/)?([a-z_0-9]+\.(?:py|sh|gd|cjs))"
    for script in sorted(set(re.findall(named, text))):
        if not (tools / script).exists():
            missing.append(f"{page.name}: script {script} is not in the tools")
    if agents:
        continue                                           # an agent's report names files of its own folder
    for name in sorted(set(re.findall(r"`((?:compare|previews|out[a-z-]*|bench|notes|families)/[^`\s]+)`", text)) | set(re.findall(r"\]\(((?:compare|previews)/[^)]+)\)", text))):
        tries = [name]
        if "<style>" in name:
            tries = [name.replace("<style>", s) for s in STYLES]
        tries = [t for one in tries for t in ([one.replace("<family>", f) for f in ("trees", "terrace", "fixtures", "planting", "water")] if "<family>" in one else [one])]
        tries = [re.sub(r"<[a-z]+>", "*", t) for t in tries]
        if not any(list(root.glob(t.rstrip("/"))) for t in tries):
            missing.append(f"{page.name}: {name} does not exist")
print("\n".join(missing) if missing else f"{len(pages)} pages: every option, script and file they name is there")
sys.exit(1 if missing else 0)
