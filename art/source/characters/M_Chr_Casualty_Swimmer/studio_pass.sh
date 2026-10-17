#!/bin/bash
# CH1 clothed Studio pass: make_studio.py inputs; studio lock then one heavy slot; own TestBench window (mayday-lookdev-ch1),
# closed unsaved. Floating at sea level (calm + storm), standing turntable on a pontoon, 4 presets dry + wet, FOV 40 close-ups,
# face at ~1 m. Sheet -> assets/review/M_Chr_Casualty_Swimmer/studio.png, cells in .../studio/.
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue; T=~/RobloxProjects/tools; S=build/ch1/studio2; R=assets/review/M_Chr_Casualty_Swimmer
cd "$GAME"; mkdir -p $R/studio
python3 art/source/characters/M_Chr_Casualty_Swimmer/make_studio.py || exit 1
"$T/build.sh" "$GAME" 2>&1 | tail -1
export MAYDAY_STUDIO_TAG=mayday-lookdev-ch1
"$T/with-lock.sh" studio --owner "CH1 clothed shots" -- "$T/with-heavy.sh" --owner "CH1 clothed shots" --cap 600 -- bash -c "
export ROBLOX_LOCKS_QUIET=1
date +%T; python3 tools/studio/smoke.py open || exit 1
python3 $T/studio-insert.py assets/models/M_Chr_Casualty_Swimmer_LOD0.rbxm auto Workspace --replace --game MaydaySeaRescue 2>&1 | tail -2
python3 tools/studio/smoke.py lua Edit $S/import.luau 2>&1 | cut -c1-400
for i in 1 2 3; do python3 tools/studio/smoke.py lua Edit $S/preload.luau 2>&1 | tail -1 | tee $S/preload.txt; grep -q 'failed: \$' $S/preload.txt && break; sleep 20; done
python3 tools/studio/smoke.py play start && sleep 8
python3 tools/studio/smoke.py lua Server 'return game.ServerStorage:WaitForChild(\"Storm_DevCommand\"):Invoke(\"/calm\")'
python3 tools/studio/smoke.py lua Server $S/place.luau
python3 $T/studio-shot.py --dm Client --setup art/lookdev/shot-setup.luau --shots $S/shots_calm.json --out $S/calm.png --keep $R/studio --cols 4
python3 tools/studio/smoke.py lua Server 'return game.ServerStorage:WaitForChild(\"Storm_DevCommand\"):Invoke(\"/storm now\")'
sleep 5
python3 $T/studio-shot.py --dm Client --setup art/lookdev/shot-setup.luau --shots $S/shots_storm.json --out $S/storm.png --keep $R/studio --cols 4
python3 tools/studio/smoke.py console 2>&1 | tail -8; python3 tools/studio/smoke.py play stop; python3 tools/studio/smoke.py close; date +%T" 2>&1 | tee $S/session.log
python3 - <<'PY'
import json, os
from PIL import Image, ImageDraw
S, R = "build/ch1/studio2/", "assets/review/M_Chr_Casualty_Swimmer/"
names = [s["name"] for f in ("shots_calm.json", "shots_storm.json") for s in json.load(open(S + f))]
cells = [(n, Image.open(R + "studio/%s.png" % n).convert("RGB")) for n in names if os.path.exists(R + "studio/%s.png" % n)]
cw, ch, cols = 480, 300, 6
rows = max(1, (len(cells) + cols - 1) // cols)
sheet = Image.new("RGB", (cw * cols, ch * rows), (20, 20, 20)); d = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(cells):
    s = max(cw / im.width, ch / im.height); im = im.resize((int(im.width * s + 1), int(im.height * s + 1)), Image.LANCZOS)
    l, t = (im.width - cw) // 2, (im.height - ch) // 2
    sheet.paste(im.crop((l, t, l + cw, t + ch)), ((i % cols) * cw, (i // cols) * ch))
    d.text(((i % cols) * cw + 6, (i // cols) * ch + 4), n, fill=(255, 255, 0))
sheet.save(R + "studio.png"); print("studio.png cells", len(cells), "of", len(names))
PY
