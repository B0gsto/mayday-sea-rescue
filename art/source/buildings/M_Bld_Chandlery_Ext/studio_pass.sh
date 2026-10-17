#!/bin/bash
# H2 Studio pass (adapted from art/source/vehicles/M_Veh_RIB/studio_pass.sh): the Chandlery exterior, interior and props
# at ONE pivot on a neutral stand; glass, Neon glow, interior practicals + exterior lamps (studio/chandlery.luau); every
# shot FOV 40. Studio lock, then one heavy slot; own TestBench window (mayday-lookdev-h2), closed at the end.
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
R=assets/review/M_Bld_Chandlery
cd "$GAME"
python3 art/source/buildings/M_Bld_Chandlery_Ext/make_import_setup.py
export MAYDAY_STUDIO_TAG=mayday-lookdev-h2
"$T/with-lock.sh" studio --owner "H2 shots" -- "$T/with-heavy.sh" -- bash -c "
python3 tools/studio/smoke.py open &&
python3 $T/studio-insert.py assets/models/M_Bld_Chandlery_Ext.rbxm auto Workspace --replace --game MaydaySeaRescue &&
python3 $T/studio-insert.py assets/models/M_Bld_Chandlery_Int.rbxm auto Workspace --replace --game MaydaySeaRescue &&
python3 $T/studio-insert.py assets/models/M_Prop_Chandlery.rbxm auto Workspace --replace --game MaydaySeaRescue &&
python3 $T/studio-shot.py --setup art/lookdev/shot-setup.luau --setup $R/studio/import-setup.luau --setup $R/studio/import-int.luau \
  --setup $R/studio/import-props.luau --setup $R/studio/chandlery.luau --setup $R/studio/preload.luau \
  --shots $R/shots.json --out $R/studio-raw.png --keep $R/studio --cols 4;
python3 tools/studio/smoke.py lua Edit $R/studio/check.luau | tee $R/studio/check.txt;
python3 tools/studio/smoke.py lua Edit $R/studio/wet_check.luau | tee $R/studio/wet_check.txt;
python3 tools/studio/smoke.py console 2>&1 | tail -8; python3 tools/studio/smoke.py close"
python3 - <<'PY'
import json, os
from PIL import Image, ImageDraw
R = "assets/review/M_Bld_Chandlery/"
names = [s["name"] for s in json.load(open(R + "shots.json"))]
cells = [(n, Image.open(R + "studio/%s.png" % n).convert("RGB")) for n in names if os.path.exists(R + "studio/%s.png" % n)]
cw, ch, cols = 480, 270, 4
rows = max(1, (len(cells) + cols - 1) // cols)
sheet = Image.new("RGB", (cw * cols, ch * rows), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(cells):
    im = im.resize((cw, int(im.height * cw / im.width)), Image.LANCZOS).crop((0, 0, cw, ch))
    sheet.paste(im, ((i % cols) * cw, (i // cols) * ch))
    d.text(((i % cols) * cw + 6, (i // cols) * ch + 4), n.replace("M_Bld_", "").replace("M_Prop_", ""), fill=(255, 255, 0))
sheet.save(R + "studio.png")
print("studio.png cells", len(cells), "of", len(names))
PY
