#!/usr/bin/env python3
"""Count lines and billable characters in assets/voice/lines.csv.

Billable text = the `say=` override if present, else `text` (what is sent to
ElevenLabs as `text`). Context (ctx_prev / ctx_next) is reported separately.
Usage: python3 -I count_chars.py [path/to/lines.csv]
"""
import csv
import os
import re
import sys
from collections import defaultdict

path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lines.csv")


def billable(row):
    m = re.search(r"say=(.*?)(?:\s\|\s|$)", row["notes"])
    return m.group(1) if m else row["text"]


tot = defaultdict(lambda: [0, 0])
by_voice = defaultdict(lambda: [0, 0])
by_cat = defaultdict(lambda: [0, 0])
ctx_chars = 0
with open(path, encoding="utf-8") as f:
    for r in csv.DictReader(f):
        scope = "L" if r["notes"].startswith("[L]") else "MVP"
        n = len(billable(r))
        for d, k in ((tot, scope), (tot, "ALL"), (by_voice, (r["voice"], scope)), (by_cat, r["category"])):
            d[k][0] += 1
            d[k][1] += n
        for c in re.findall(r"ctx_(?:prev|next)=([^|]*)", r["notes"]):
            ctx_chars += len(c.strip())

print("scope   lines  chars")
for k in ("MVP", "L", "ALL"):
    print(f"{k:6} {tot[k][0]:6} {tot[k][1]:7}")
print("\nvoice                 MVP lines/chars     L lines/chars")
for v in sorted({k[0] for k in by_voice}):
    a, b = by_voice[(v, "MVP")], by_voice[(v, "L")]
    print(f"{v:20} {a[0]:6} {a[1]:7}      {b[0]:5} {b[1]:6}")
print("\ncategory          lines  chars")
for c in sorted(by_cat, key=lambda c: -by_cat[c][1]):
    print(f"{c:16} {by_cat[c][0]:6} {by_cat[c][1]:7}")
print(f"\ncontext chars (previous_text/next_text, not billed as text): {ctx_chars}")
