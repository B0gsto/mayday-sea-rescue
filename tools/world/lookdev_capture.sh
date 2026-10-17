#!/bin/bash
# Terrain look-dev capture (play mode, shared art/lookdev/shot-setup.luau): 4 views x Overcast / Clear of the island
# terrain -> build/world/round<N>.png (768 px cells) and the full-size shots in build/world/round<N>/.
# usage: tools/world/lookdev_capture.sh <round>   (build first: ~/RobloxProjects/tools/build.sh .)
set -uo pipefail
GAME="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS=~/RobloxProjects/tools
N="${1:?round}"
cd "$GAME"
export MAYDAY_STUDIO_TAG="${MAYDAY_STUDIO_TAG:-mayday-terrain-lookdev}"
rm -rf "build/world/round$N"
mkdir -p build/world
export STUDIO_NAME="TestBench-$MAYDAY_STUDIO_TAG"  # studio-shot.py targets only this window
# ocean mode (lookdev-shots.json "ocean": true): studio-shot.py starts play, sends /calm, runs the look setup in the
# Client and stops play at the end
"$TOOLS/with-lock.sh" studio -- bash -c "
python3 tools/studio/smoke.py open &&
python3 $TOOLS/studio-shot.py --look-setup art/lookdev/shot-setup.luau --shots tools/world/lookdev-shots.json \
  --out build/world/round$N-raw.png --keep build/world/round$N --cols 4 --cell 768x432;
python3 tools/studio/smoke.py close"
python3 - "$N" <<'PY'
import json, os, sys
from PIL import Image, ImageDraw
n = sys.argv[1]
names = [s["name"] for s in json.load(open("tools/world/lookdev-shots.json"))["shots"] if not s["name"].startswith("ZZ_")]
cells = [(nm, Image.open(f"build/world/round{n}/{nm}.png").convert("RGB")) for nm in names
         if os.path.exists(f"build/world/round{n}/{nm}.png")]
cw, ch, cols = 768, 432, 4
rows = (len(cells) + cols - 1) // cols
sheet = Image.new("RGB", (cw * cols, ch * rows), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, (nm, im) in enumerate(cells):
    s = max(cw / im.width, ch / im.height)
    im = im.resize((int(im.width * s + 0.5), int(im.height * s + 0.5)), Image.LANCZOS)
    x0, y0 = (im.width - cw) // 2, (im.height - ch) // 2
    sheet.paste(im.crop((x0, y0, x0 + cw, y0 + ch)), ((i % cols) * cw, (i // cols) * ch))
    d.text(((i % cols) * cw + 8, (i // cols) * ch + 6), nm, fill=(255, 255, 0))
sheet.save(f"build/world/round{n}.png")
print(f"build/world/round{n}.png", sheet.size, len(cells), "cells")
PY
