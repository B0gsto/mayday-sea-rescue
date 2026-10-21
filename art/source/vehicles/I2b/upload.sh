#!/bin/bash
# I2b upload: every shipping PNG (Image) and every FBX LOD (Model) of the land fleet, then
# tools/gen_asset_ids.py. usage: upload.sh [pickup|amb|cg|atv|trailer-js|trailer-rib|all]
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
cd "$GAME"
WHAT=${1:-all}
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "I2b upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
WHAT='"$WHAT"'
up_asset() {  # $1 asset
  a=$1
  for f in assets/textures/$a/*.png; do
    n=$(basename "$f" .png)
    python3 $T/assets.py upload . "$f" --type Image --name "$n" 2>&1 | tail -1
  done
  for lod in LOD0 LOD1 LOD2; do
    n=$a; [ $lod != LOD0 ] && n=${a}_$lod
    python3 $T/assets.py upload . assets/fbx/$a/${a}_$lod.fbx --type Model --name "$n" 2>&1 | tail -2
  done
}
case $WHAT in all|pickup) up_asset M_Veh_LifeguardPickup;; esac
case $WHAT in all|amb) up_asset M_Veh_Ambulance;; esac
case $WHAT in all|cg) up_asset M_Veh_Coastguard4x4;; esac
case $WHAT in all|atv) up_asset M_Veh_ATV;; esac
case $WHAT in all|trailer-js) up_asset M_Veh_BoatTrailer_JetSki;; esac
case $WHAT in all|trailer-rib) up_asset M_Veh_BoatTrailer_RIB;; esac
'
for i in 1 2 3 4 5; do
  python3 tools/gen_asset_ids.py 2>&1 | tail -2 && break
  echo "gen_asset_ids retry $i"; sleep 5
done
