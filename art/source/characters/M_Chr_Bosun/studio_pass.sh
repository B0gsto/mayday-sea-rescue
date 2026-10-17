#!/bin/bash
# CH6 Studio pass (docs/12 3.3): studio lock, then one heavy slot (order studio -> heavy); own TestBench window
# (mayday-lookdev-ch6), closed unsaved. Sheet: assets/review/M_Chr_Bosun/studio.png (34 shots, 6 per row:
# per preset dry EV-0.5/0/+0.5 | wet EV-0.5/0/+0.5, then side views and wet fur close-ups); cells kept in .../studio/.
# Run upload_ch6.sh first (it waits for moderation). The SurfaceAppearances are preloaded (dry + wet) and re-checked
# up to 4 x 40 s before any shot: Studio's generated TexturePacks must exist or the fur renders as a bare grey ghost.
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
R=assets/review/M_Chr_Bosun
cd "$GAME"
python3 art/source/characters/M_Chr_Bosun/make_studio_setup.py || exit 1
export MAYDAY_STUDIO_TAG=mayday-lookdev-ch6
"$T/with-lock.sh" studio --owner "CH6 Bosun shots" -- "$T/with-heavy.sh" --owner "CH6 Bosun shots" -- bash -c "
# every lock taken below is a re-entrant no-op under the studio+heavy this tree holds; locks.py checks order before
# re-entrancy, so those no-ops would each print a false 'lock order inversion' warning: silence them here only.
export ROBLOX_LOCKS_QUIET=1
date +%T; python3 tools/studio/smoke.py open || exit 1
python3 $T/studio-insert.py assets/models/M_Chr_Bosun_LOD0.rbxm auto Workspace --replace --game MaydaySeaRescue 2>&1 | tail -2
python3 tools/studio/smoke.py lua Edit $R/studio/import-a.luau 2>&1 | cut -c1-300
python3 tools/studio/smoke.py lua Edit $R/studio/import-b.luau > $R/studio/import-result.txt 2>&1
python3 -c 'import json,sys; t=open(sys.argv[1]).read(); i=t.find(\"{\"); d=json.loads(t[i:t.rfind(\"}\")+1]); json.dump(d, open(sys.argv[2], \"w\"), indent=1); print(\"idCheck\", d[\"idCheck\"][\"ok\"], \"preload\", d[\"preload\"][\"allOk\"], \"failed\", [f[\"file\"] for f in d[\"preload\"][\"failed\"]], d[\"preload\"][\"otherFailed\"], \"atts\", d[\"attachments\"])' $R/studio/import-result.txt $R/studio/import-result.json \
  || { echo 'import-b gave no JSON:'; head -c 800 $R/studio/import-result.txt; echo; }
for i in 1 2 3 4; do
  python3 tools/studio/smoke.py lua Edit $R/studio/preload.luau > $R/studio/preload-result.txt 2>&1
  if grep -q '\"allOk\":true' $R/studio/preload-result.txt; then echo \"preload ok (try \$i)\"; break; fi
  echo \"preload not ready (try \$i):\"; head -c 400 $R/studio/preload-result.txt; echo
done
python3 $T/studio-shot.py --setup art/lookdev/shot-setup.luau --shots $R/shots.json --out $R/studio.png --keep $R/studio --cols 6 --cell 640x360
python3 tools/studio/smoke.py console 2>&1 | tail -8; python3 tools/studio/smoke.py close; date +%T" 2>&1 | tee $R/studio/session.log
