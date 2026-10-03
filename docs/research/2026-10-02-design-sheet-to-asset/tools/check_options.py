"""check_options.py: fit_generated.py's documentation lists exactly the options its code reads. Exit 1 if not."""
import re
import sys
from pathlib import Path

text = (Path(__file__).resolve().parent / "fit_generated.py").read_text()
doc = text[:text.index('"""\nimport json')]
code = text[len(doc):]
read = set(re.findall(r'opt\("(--[a-z0-9-]+)"', code)) | set(re.findall(r'"(--[a-z0-9-]+)" (?:not )?in argv', code))
named = set(re.findall(r"(--[a-z][a-z0-9-]+)", doc)) - {"--background", "--factory-startup", "--python-exit-code", "--python"}
for option in sorted(read - named):
    print("read by the code, not documented:", option)
for option in sorted(named - read):
    print("documented, not read by the code:", option)
print(f"{len(read & named)} options documented and read")
sys.exit(1 if read != named else 0)
