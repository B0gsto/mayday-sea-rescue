#!/bin/bash
# G1 Studio pass (docs/12 3.3): studio lock, then one heavy slot; own TestBench window (mayday-lookdev-g1), closed
# unsaved. Inserts the 16 LOD0 models, imports them with the atlas ids (AlphaMode Transparency, wet twin, DoubleSided),
# plants a patch on the real terrain (Haven Head cliff top, Haven Sands dune crest), then 18 shots (4 presets dry + wet
# per site, FOV 40, cursor parked by studio-shot.py, plus two Overcast close-ups) -> assets/review/G1/studio.png.
# Run upload_g1.sh first (waits for Approved).
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue; T=~/RobloxProjects/tools; R=assets/review/G1
cd "$GAME"; mkdir -p $R/studio
python3 art/source/veg/G1/make_studio_g1.py setup || exit 1
export MAYDAY_STUDIO_TAG=mayday-lookdev-g1
"$T/with-lock.sh" studio --owner "G1 veg shots" -- "$T/with-heavy.sh" --owner "G1 veg shots" -- bash -c "
export ROBLOX_LOCKS_QUIET=1
date +%T; python3 tools/studio/smoke.py open || exit 1
for f in assets/models/M_Veg_*_LOD0.rbxm; do
  case \$f in *Kelp*|*Wrack*|*Eelgrass*) continue;; esac
  python3 $T/studio-insert.py \$f auto Workspace --replace --game MaydaySeaRescue 2>&1 | tail -1
done
python3 tools/studio/smoke.py lua Edit tools/studio/import_asset.luau 2>&1 | tail -1 | cut -c1-200
python3 tools/studio/smoke.py lua Edit $R/studio/plant.luau > $R/studio/plant-result.txt 2>&1
python3 art/source/veg/G1/make_studio_g1.py shots $R/studio/plant-result.txt || { head -c 1500 $R/studio/plant-result.txt; python3 tools/studio/smoke.py close; exit 1; }
sleep 20
python3 $T/studio-shot.py --setup art/lookdev/shot-setup.luau --shots $R/shots.json --out $R/studio_dune.png --keep $R/studio --cols 3 --cell 640x360
python3 tools/studio/smoke.py console 2>&1 | tail -6; python3 tools/studio/smoke.py close; date +%T" 2>&1 | tee $R/studio/session.log
