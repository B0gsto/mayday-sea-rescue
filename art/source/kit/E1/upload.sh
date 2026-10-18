#!/bin/bash
# E1 upload: the shared kit atlas maps (Image) and every FBX LOD (Model) of the 12 kit items, then tools/gen_asset_ids.py.
# usage: upload.sh [tex|models|all]
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
cd "$GAME"
WHAT=${1:-all}
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "E1 upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
WHAT='"$WHAT"'
if [ $WHAT = all ] || [ $WHAT = tex ]; then
  for f in assets/textures/M_Kit_Atlas/*.png; do
    python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
  done
fi
if [ $WHAT = all ] || [ $WHAT = models ]; then
  for a in M_Kit_ThrowBag M_Kit_ThrowLine M_Kit_RescueTube M_Kit_Lifebuoy M_Kit_ThermalBlanket M_Kit_ThermalBlanketDraped \
           M_Kit_FirstAidBag M_Kit_OxygenBag M_Kit_VHFHandset M_Kit_HandFlare M_Kit_ParaFlare M_Kit_Strobe; do
    for lod in LOD0 LOD1 LOD2; do
      n=$a; [ $lod != LOD0 ] && n=${a}_$lod
      python3 $T/assets.py upload . assets/fbx/$a/${a}_$lod.fbx --type Model --name "$n" 2>&1 | tail -1
    done
  done
fi
'
for i in 1 2 3 4 5; do
  python3 tools/gen_asset_ids.py 2>&1 | tail -2 && break
  echo "gen_asset_ids retry $i"; sleep 5
done
