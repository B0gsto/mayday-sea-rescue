#!/bin/bash
# V1 Studio pass (from the V2 RIB template: FOV 40, heroes at about 17 studs, first person from ATT_EyePoint dry + wet, 3 close-ups, neutral backdrop, Night spotlight + nav PointLights): studio lock, then one heavy slot; own TestBench window (mayday-lookdev-v1), closed at the end.
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
R=assets/review/M_Veh_JetSki
cd "$GAME"
MAYDAY_JET_Y=40 python3 art/source/vehicles/M_Veh_JetSki/make_import_setup.py
export MAYDAY_STUDIO_TAG=mayday-lookdev-v1
"$T/with-lock.sh" studio --owner "V1 shots" -- "$T/with-heavy.sh" -- bash -c "
python3 tools/studio/smoke.py open &&
python3 $T/studio-insert.py assets/models/M_Veh_JetSki.rbxm auto Workspace --replace --game MaydaySeaRescue &&
python3 $T/studio-insert.py assets/models/M_Veh_JetSki_CloseUp.rbxm auto Workspace --replace --game MaydaySeaRescue &&
python3 $T/studio-shot.py --setup art/lookdev/shot-setup.luau --setup $R/studio/import-setup.luau --setup $R/studio/import-closeup.luau --setup $R/studio/backdrop.luau --setup $R/studio/preload.luau \
  --shots $R/shots.json --out $R/studio-raw.png --keep $R/studio --cols 4;
python3 tools/studio/smoke.py lua Edit tools/studio/import_test.luau | tee $R/studio/import_test.txt;
python3 tools/studio/smoke.py lua Edit $R/studio/wet_check.luau | tee $R/studio/wet_check.txt;
python3 tools/studio/smoke.py console 2>&1 | tail -8; python3 tools/studio/smoke.py close"
python3 - <<'PY'
import json, os
from PIL import Image, ImageDraw
R = "assets/review/M_Veh_JetSki/"
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
