#!/bin/bash
# H1 Studio pass (docs/12 3.3): studio lock, then one heavy slot; own TestBench window (mayday-lookdev-h1), closed at the end.
# 12 shots, FOV 40: the station from the harbour in Clear / Overcast / Storm / Night dry and wet, the slipway close-up and
# the bay-door detail (Overcast dry and wet). Output assets/review/M_Bld_Station/studio.png (+ studio/*.png).
set -uo pipefail
cd /Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
R=assets/review/M_Bld_Station
python3 art/source/buildings/M_Bld_Station/make_studio.py
export MAYDAY_STUDIO_TAG=mayday-lookdev-h1
"$T/with-lock.sh" studio --owner "H1 shots" -- "$T/with-heavy.sh" -- bash -c "
python3 tools/studio/smoke.py open &&
python3 $T/studio-insert.py assets/models/M_Bld_Station.rbxm auto Workspace --replace --game MaydaySeaRescue &&
python3 $T/studio-insert.py assets/models/M_Bld_Slipway.rbxm auto Workspace --replace --game MaydaySeaRescue &&
python3 $T/studio-shot.py --setup art/lookdev/shot-setup.luau --setup $R/studio/import-setup.luau --setup $R/studio/import-slipway.luau --setup $R/studio/scene.luau \
  --shots $R/shots.json --out $R/studio-raw.png --keep $R/studio --cols 4;
python3 tools/studio/smoke.py console 2>&1 | tail -6; python3 tools/studio/smoke.py close"
python3 - <<'PY'
import json, os
from PIL import Image, ImageDraw
R = "assets/review/M_Bld_Station/"
names = [s["name"] for s in json.load(open(R + "shots.json"))]
cells = [(n, Image.open(R + "studio/%s.png" % n).convert("RGB")) for n in names if os.path.exists(R + "studio/%s.png" % n)]
cw, ch, cols = 480, 270, 4
rows = max(1, (len(cells) + cols - 1) // cols)
sheet = Image.new("RGB", (cw * cols, ch * rows), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(cells):
    im = im.resize((cw, int(im.height * cw / im.width)), Image.LANCZOS).crop((0, 0, cw, ch))
    sheet.paste(im, ((i % cols) * cw, (i // cols) * ch))
    d.text(((i % cols) * cw + 6, (i // cols) * ch + 4), n.replace("M_Bld_", ""), fill=(255, 255, 0))
sheet.save(R + "studio.png")
print("studio.png cells", len(cells), "of", len(names))
PY
