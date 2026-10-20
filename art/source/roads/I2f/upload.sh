#!/bin/bash
# I2f upload: every shipping map PNG (Image) and every FBX LOD (Model) of the accepted queue rows not yet uploaded
# (needle's eye, parked cars, harbourmaster r2, boatyard shed LODs, moored boats 02/03, Cornish hedge, seal, gull,
# Bosun LP, I2e kit, cliffs 06-08, ledge 04, I2d seabed, kelp), then tools/gen_asset_ids.py.
# usage: upload.sh [asset ...]   (default: all)
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
cd "$GAME"
ALL="M_Rock_NeedlesEye M_Road_ParkedCar_01 M_Road_ParkedCar_02 M_Road_ParkedCar_03 M_Bld_Harbourmaster M_Bld_BoatyardShed
M_Veh_MooredBoat_02 M_Veh_MooredBoat_03 M_Road_CornishHedge M_Ani_GreySeal M_Ani_HerringGull M_Chr_Bosun_LP M_Kit_Bridle
M_Kit_ChartTablet M_Kit_HeavingLine M_Kit_LineKnife M_Kit_StretcherBasket M_Kit_TowLine M_Kit_TriageTags M_Rock_Cliff_06
M_Rock_Cliff_07 M_Rock_Cliff_08 M_Rock_Ledge_04 M_Sea_BottleField M_Sea_LostPot M_Sea_MailSeaplane M_Sea_MooringBlock
M_Sea_SandRipples M_Veg_Kelp_Kit"
WHAT=${*:-$ALL}
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "I2f upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
for a in '"$(echo $WHAT)"'; do
  for f in assets/textures/$a/*.png; do
    [ -f "$f" ] || continue
    python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
  done
  for lod in LOD0 LOD1 LOD2; do
    f=assets/fbx/$a/${a}_$lod.fbx
    [ -f "$f" ] || continue  # some kit rows ship LOD0/LOD1 only
    n=$a; [ $lod != LOD0 ] && n=${a}_$lod
    python3 $T/assets.py upload . "$f" --type Model --name "$n" 2>&1 | tail -2
  done
done
'
for i in 1 2 3 4 5; do
  python3 tools/gen_asset_ids.py 2>&1 | tail -2 && break
  echo "gen_asset_ids retry $i"; sleep 5
done
