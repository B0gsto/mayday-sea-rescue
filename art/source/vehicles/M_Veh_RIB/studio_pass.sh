#!/bin/bash
# V2 Studio pass (docs/12 3.3; fix batch: neutral backdrop at hero distance, Night with a spotlight): studio lock, then one heavy slot; own TestBench window (mayday-lookdev-v2), closed at the end.
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
R=assets/review/M_Veh_RIB
cd "$GAME"
MAYDAY_RIB_Y=40 python3 art/source/vehicles/M_Veh_RIB/make_import_setup.py
export MAYDAY_STUDIO_TAG=mayday-lookdev-v2
"$T/with-lock.sh" studio --owner "V2 shots" -- "$T/with-heavy.sh" -- bash -c "
python3 tools/studio/smoke.py open &&
python3 $T/studio-insert.py assets/models/M_Veh_RIB.rbxm auto Workspace --replace --game MaydaySeaRescue &&
python3 $T/studio-insert.py assets/models/M_Veh_RIB_Helm.rbxm auto Workspace --replace --game MaydaySeaRescue &&
python3 $T/studio-shot.py --setup art/lookdev/shot-setup.luau --setup $R/studio/import-setup.luau --setup $R/studio/import-helm.luau --setup $R/studio/backdrop.luau \
  --shots $R/shots.json --out $R/studio-raw.png --keep $R/studio --cols 4;
python3 tools/studio/smoke.py console 2>&1 | tail -8; python3 tools/studio/smoke.py close"
python3 - <<'PY'
import json, os
from PIL import Image, ImageDraw
R = "assets/review/M_Veh_RIB/"
names = [s["name"] for s in json.load(open(R + "shots.json"))]
cells = [(n, Image.open(R + "studio/%s.png" % n).convert("RGB")) for n in names if os.path.exists(R + "studio/%s.png" % n)]
cw, ch, cols = 480, 270, 4
rows = max(1, (len(cells) + cols - 1) // cols)
sheet = Image.new("RGB", (cw * cols, ch * rows), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(cells):
    im = im.resize((cw, int(im.height * cw / im.width)), Image.LANCZOS).crop((0, 0, cw, ch))
    sheet.paste(im, ((i % cols) * cw, (i // cols) * ch))
    d.text(((i % cols) * cw + 6, (i // cols) * ch + 4), n.replace("M_Veh_", ""), fill=(255, 255, 0))
sheet.save(R + "studio.png")
print("studio.png cells", len(cells), "of", len(names))
PY
