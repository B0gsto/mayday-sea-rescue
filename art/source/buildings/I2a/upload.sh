#!/bin/bash
# I2a upload: every shipping map PNG (Image) and every FBX LOD (Model) of the hospital, the harbourmaster's
# office, the boatyard shed, the travel hoist and the moored boat, then tools/gen_asset_ids.py.
# usage: upload.sh [hospital|harbourmaster|boatyard|hoist|moored|all]
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
cd "$GAME"
WHAT=${1:-all}
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "I2a upload" -- bash -c '
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
case $WHAT in all|hospital) up_asset M_Bld_Hospital;; esac
case $WHAT in all|harbourmaster) up_asset M_Bld_Harbourmaster;; esac
case $WHAT in all|boatyard) up_asset M_Bld_BoatyardShed;; esac
case $WHAT in all|hoist) up_asset M_Hbr_TravelHoist;; esac
case $WHAT in all|moored) up_asset M_Veh_MooredBoat_01;; esac
'
for i in 1 2 3 4 5; do
  python3 tools/gen_asset_ids.py 2>&1 | tail -2 && break
  echo "gen_asset_ids retry $i"; sleep 5
done
