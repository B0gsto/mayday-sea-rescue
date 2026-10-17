#!/bin/bash
# H1 Studio pass (docs/12 3.3): studio lock, then one heavy slot; own TestBench window (mayday-lookdev-h1), closed at the end.
# 22 shots, FOV 40: station and slipway hero framing in Clear / Overcast / Storm / Night dry and wet, close-ups of the
# tide line, the bay door + sign and the crew-wing wall (Overcast dry and wet). Slipway shots move to assets/review/M_Bld_Slipway/studio/. Output assets/review/M_Bld_Station/studio.png (+ studio/*.png).
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
mkdir -p assets/review/M_Bld_Slipway/studio
mv -f $R/studio/M_Bld_Slipway_*.png assets/review/M_Bld_Slipway/studio/ 2>/dev/null   # each sheet's Studio row shows its own asset
python3 - <<'PY'
import json, os
from PIL import Image, ImageDraw
R = "assets/review/M_Bld_Station/"
names = [s["name"] for s in json.load(open(R + "shots.json"))]
def find(n):
    for d in (R + "studio/", "assets/review/M_Bld_Slipway/studio/"):
        if os.path.exists(d + n + ".png"):
            return d + n + ".png"
cells = [(n, Image.open(find(n)).convert("RGB")) for n in names if find(n)]
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
