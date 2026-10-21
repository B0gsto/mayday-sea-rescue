#!/bin/bash
# I2c upload: road furniture (barrier, gate, dry-stone wall, sign kit), rock pools, intertidal wrack, eelgrass and
# the island proxies. Every shipping PNG (Image), then LOD0/1/2 FBX (Model) each, under the assets lock.
# Then: python3 tools/gen_asset_ids.py (with retries). usage: upload.sh [asset ...]
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
cd "$GAME"
ASSETS=("$@")
if [ ${#ASSETS[@]} -eq 0 ]; then
  ASSETS=(M_Road_CrashBarrier M_Road_FieldGate M_Road_DryStoneWall M_Road_Sign_Kit M_Rock_RockPool_Kit M_Veg_Wrack_Kit M_Veg_Eelgrass_Kit M_Rock_IslandProxy_Kit)
fi
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "I2c upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
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
for a in '"${ASSETS[*]}"'; do up_asset "$a"; done
'
for i in 1 2 3 4 5; do
  python3 tools/gen_asset_ids.py 2>&1 | tail -2 && break
  echo "gen_asset_ids retry $i"; sleep 5
done
