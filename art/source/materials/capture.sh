#!/bin/bash
# B02 look-dev capture: build, open TestBench-mayday, play, swatch board + terrain shots in the four presets, stop, close.
# usage: art/source/materials/capture.sh <round>   -> build/materials/round<N>.png (contact sheet, 1200 px wide)
set -uo pipefail
GAME="$(cd "$(dirname "$0")/../../.." && pwd)"
TOOLS=~/RobloxProjects/tools
N="${1:?round}"
cd "$GAME"
"$TOOLS/build.sh" "$GAME" 2>&1 | tail -1
rm -rf "build/materials/round$N"
mkdir -p build/materials
"$TOOLS/with-lock.sh" studio -- bash -c "
python3 tools/studio/smoke.py open && python3 tools/studio/smoke.py play start && sleep 8 &&
python3 tools/studio/smoke.py lua Server 'return game.ServerStorage:WaitForChild(\"Storm_DevCommand\"):Invoke(\"/calm\")';
python3 $TOOLS/studio-shot.py --dm Client --setup art/ocean/shot-setup.luau --setup art/source/materials/lookdev-setup.luau \
  --shots art/source/materials/lookdev-shots.json --out build/materials/round$N-raw.png --keep build/materials/round$N --cols 4;
python3 tools/studio/smoke.py console | tail -6; python3 tools/studio/smoke.py play stop; python3 tools/studio/smoke.py close"
python3 - "$N" <<'PY'
import json, os, sys
from PIL import Image, ImageDraw
n = sys.argv[1]
names = [s["name"] for s in json.load(open("art/source/materials/lookdev-shots.json"))]
cells = [(nm, Image.open(f"build/materials/round{n}/{nm}.png").convert("RGB")) for nm in names
         if os.path.exists(f"build/materials/round{n}/{nm}.png")]
cw, ch, cols = 640, 360, 3
rows = (len(cells) + cols - 1) // cols
sheet = Image.new("RGB", (cw * cols, ch * rows + 40), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, (nm, im) in enumerate(cells):
    im = im.resize((cw, int(im.height * cw / im.width)), Image.LANCZOS).crop((0, 0, cw, ch))
    sheet.paste(im, ((i % cols) * cw, (i // cols) * ch))
    d.text(((i % cols) * cw + 8, (i // cols) * ch + 6), nm, fill=(255, 255, 0))
d.text((8, ch * rows + 12), "B02 round %s: board = dry|wet pairs, rows of 5, names sorted A-Z (see setup log)" % n, fill=(220, 220, 220))
sheet.save(f"build/materials/round{n}-full.png")
sheet.resize((1200, int(sheet.height * 1200 / sheet.width)), Image.LANCZOS).save(f"build/materials/round{n}.png")
print("cells", len(cells), "of", len(names))
PY
echo "SHEET build/materials/round$N.png"
