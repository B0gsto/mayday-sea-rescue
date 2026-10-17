#!/bin/bash
# Ocean spike capture round: build, open TestBench-mayday, play, run shots, stop, close.
# usage: art/ocean/capture.sh <round-number>    -> build/ocean/round<N>.png (~1200 px wide)
# Two passes so the SERVER weather really is what the shot shows (the server StormService
# overwrites client-side Weather overrides): "/calm" + shots.json, then "/storm now" +
# shots-storm.json, through the Studio dev hook ServerStorage.Storm_DevCommand.
# Lighting presets are picked per shot with the Lighting attribute WeatherBase (WeatherController).
set -uo pipefail
GAME="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS=~/RobloxProjects/tools
N="${1:?round}"
cd "$GAME"
"$TOOLS/build.sh" "$GAME" 2>&1 | tail -1
rm -rf "build/ocean/round$N"
"$TOOLS/with-lock.sh" studio -- bash -c "
python3 tools/studio/smoke.py open && python3 tools/studio/smoke.py play start && sleep 8 &&
python3 tools/studio/smoke.py lua Server 'return game.ServerStorage:WaitForChild(\"Storm_DevCommand\"):Invoke(\"/calm\")' &&
python3 $TOOLS/studio-shot.py --dm Client --setup art/ocean/shot-setup.luau --shots art/ocean/shots.json \
  --out build/ocean/round$N-calm.png --keep build/ocean/round$N --cols 4;
python3 tools/studio/smoke.py lua Server 'return game.ServerStorage:WaitForChild(\"Storm_DevCommand\"):Invoke(\"/storm now\")';
sleep 3;
python3 $TOOLS/studio-shot.py --dm Client --setup art/ocean/shot-setup.luau --shots art/ocean/shots-storm.json \
  --out build/ocean/round$N-storm.png --keep build/ocean/round$N --cols 2;
python3 tools/studio/smoke.py lua Server 'return game.ServerStorage.Storm_DevCommand:Invoke(\"/calm\")';
python3 tools/studio/smoke.py console | tail -8; python3 tools/studio/smoke.py play stop; python3 tools/studio/smoke.py close"
# One contact sheet of every shot, in shot-list order, 3 columns.
python3 - "$N" <<'EOF'
import json, sys, os
from PIL import Image, ImageDraw
n = sys.argv[1]
names = [s["name"] for f in ("art/ocean/shots.json", "art/ocean/shots-storm.json") for s in json.load(open(f))]
cells = [(nm, Image.open(f"build/ocean/round{n}/{nm}.png").convert("RGB")) for nm in names
         if os.path.exists(f"build/ocean/round{n}/{nm}.png")]
cw, ch, cols = 640, 360, 3
rows = (len(cells) + cols - 1) // cols
sheet = Image.new("RGB", (cw * cols, ch * rows), (20, 20, 20))
for i, (nm, im) in enumerate(cells):
    im = im.resize((cw, int(im.height * cw / im.width)), Image.LANCZOS).crop((0, 0, cw, ch))
    sheet.paste(im, ((i % cols) * cw, (i // cols) * ch))
    ImageDraw.Draw(sheet).text(((i % cols) * cw + 8, (i // cols) * ch + 6), nm, fill=(255, 255, 0))
sheet.save(f"build/ocean/round{n}-full.png")
sheet.resize((1200, int(sheet.height * 1200 / sheet.width)), Image.LANCZOS).save(f"build/ocean/round{n}.png")
print("cells", len(cells), "of", len(names))
EOF
echo "SHEET build/ocean/round$N.png"
