#!/bin/bash
# CH6 Studio pass (docs/12 3.3): studio lock, then one heavy slot; own TestBench window (mayday-lookdev-ch6), closed unsaved.
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
R=assets/review/M_Chr_Bosun
cd "$GAME"
python3 art/source/characters/M_Chr_Bosun/make_studio_setup.py
export MAYDAY_STUDIO_TAG=mayday-lookdev-ch6
"$T/with-lock.sh" studio --owner "CH6 shots" -- "$T/with-heavy.sh" -- bash -c "
date +%T; python3 tools/studio/smoke.py open || exit 1
python3 $T/studio-insert.py assets/models/M_Chr_Bosun_LOD0.rbxm auto Workspace --replace --game MaydaySeaRescue 2>&1 | tail -2
python3 tools/studio/smoke.py lua Edit $R/studio/import-a.luau 2>&1 | cut -c1-300
python3 tools/studio/smoke.py lua Edit $R/studio/import-b.luau > $R/studio/import-result.txt 2>&1
head -c 600 $R/studio/import-result.txt; echo
python3 $T/studio-shot.py --setup art/lookdev/shot-setup.luau --shots $R/shots.json --out $R/studio.png --keep $R/studio --cols 4 --cell 640x360
python3 tools/studio/smoke.py console 2>&1 | tail -8; python3 tools/studio/smoke.py close; date +%T"
