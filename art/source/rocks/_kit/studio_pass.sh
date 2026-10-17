#!/bin/bash
# K1 Studio pass (docs/12 3.3): studio lock, then one heavy slot; own TestBench window (mayday-lookdev-k1) on the real
# place (build/MaydaySeaRescue.rbxl, real terrain), closed at the end. The 14 kit pieces set-dress a test cove under
# Haven Head (find_cove.py); 14 shots at FOV 40: the cove in Clear / Overcast / Storm / Night dry and wet, then ledge
# waterline, boulders and cliffs close-ups (Overcast dry and wet).
# shots.json has "ocean": true: studio-shot.py starts play, inserts + imports + cove run on the Server, it waits for the
# Client to see them ("expect" models + part count, SYNC line), then it plays and captures from the Client
# with the game's mesh ocean (art/lookdev/README.md); Storm shots set the real server storm. Output assets/review/K1/studio.png (+ studio/*.png).
set -uo pipefail
cd /Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
R=assets/review/K1
python3 art/source/rocks/_kit/make_studio.py || exit 1
export MAYDAY_STUDIO_TAG=mayday-lookdev-k1
# the kit models go in through studio-shot.py --insert: in ocean mode they are inserted (and imported / set dressed) on the
# play SERVER so they replicate to the Client (Edit-time inserts did not reliably reach the play session)
INS=""
for a in $(python3 -c "import sys; sys.path.insert(0,'art/source/rocks/_kit'); from kit import KIT; print(' '.join(r[0] for r in KIT))"); do
  INS="$INS --insert assets/models/$a.rbxm"
done
"$T/with-lock.sh" studio --owner "K1 shots" -- "$T/with-heavy.sh" -- bash -c "
python3 tools/studio/smoke.py open &&
STUDIO_ID=\$(cat build/smoke/.sid-mayday-lookdev-k1) python3 $T/studio-shot.py $INS --setup $R/studio/import-setup.luau --setup $R/studio/import-rest.luau --setup $R/studio/cove.luau \
  --look-setup art/lookdev/shot-setup.luau --look-setup $R/studio/k1-shot.luau \
  --shots $R/shots.json --out $R/studio-raw.png --keep $R/studio --cols 4 --white-check;
python3 tools/studio/smoke.py console 2>&1 | tail -6; python3 tools/studio/smoke.py close"
python3 - <<'PY'
import json, os
from PIL import Image, ImageDraw
R = "assets/review/K1/"
spec = json.load(open(R + "shots.json"))
names = [s["name"] for s in (spec["shots"] if isinstance(spec, dict) else spec)]
cells = [(n, Image.open(R + "studio/" + n + ".png").convert("RGB")) for n in names if os.path.exists(R + "studio/" + n + ".png")]
cw, ch, cols = 480, 270, 4
rows = max(1, (len(cells) + cols - 1) // cols)
sheet = Image.new("RGB", (cw * cols, ch * rows), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(cells):
    im = im.resize((cw, int(im.height * cw / im.width)), Image.LANCZOS).crop((0, 0, cw, ch))
    sheet.paste(im, ((i % cols) * cw, (i // cols) * ch))
    d.text(((i % cols) * cw + 6, (i // cols) * ch + 4), n, fill=(255, 255, 0))
sheet.save(R + "studio.png")
print("studio.png cells", len(cells), "of", len(names))
PY
