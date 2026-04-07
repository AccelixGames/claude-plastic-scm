#!/usr/bin/env python3
"""Read handover from stdin, save to timestamped file, copy to clipboard, print path."""
import sys, os, platform, subprocess, io
from datetime import datetime

sys.stdin.reconfigure(encoding="utf-8")
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

text = sys.stdin.read()
if not text.strip():
    print("ERROR: empty handover text", file=sys.stderr)
    sys.exit(1)

is_win = platform.system() == "Windows" or os.path.isdir("C:/tmp")
tmp_dir = "C:/tmp" if is_win else "/tmp"
ts = datetime.now().strftime("%y%m%d%H%M%S")
path = os.path.join(tmp_dir, f"handover-{ts}.md")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

if is_win:
    subprocess.run(
        ["powershell.exe", "-Command",
         f"Set-Clipboard -Value (Get-Content -Raw -Encoding UTF8 -Path '{path}')"],
        check=True
    )
else:
    subprocess.run(["pbcopy"], input=text.encode(), check=True)

print(f"\U0001f4cb Copied to clipboard \u2192 {path}")
