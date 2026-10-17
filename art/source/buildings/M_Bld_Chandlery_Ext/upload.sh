#!/bin/bash
# H2 upload: every map PNG (Image) and every FBX LOD (Model) of the Chandlery exterior, interior and props.
# usage: upload.sh [ext|int|props|all]   (default all; the interior is uploaded once its re-export has settled)
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
cd "$GAME"
WHAT=${1:-all}
"$T/with-lock.sh" assets.MaydaySeaRescue --owner "H2 upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
WHAT='"$WHAT"'
up_asset() {  # $1 asset, $2.. "lod:name"
  a=$1; shift
  for f in assets/textures/$a/*.png; do
    n=$(basename "$f" .png)
    python3 $T/assets.py upload . "$f" --type Image --name "$n" 2>&1 | tail -1
  done
  for spec in "$@"; do
    lod=${spec%%:*}; n=${spec#*:}
    python3 $T/assets.py upload . assets/fbx/$a/${a}_$lod.fbx --type Model --name "$n" 2>&1 | tail -2
  done
}
case $WHAT in all|ext) up_asset M_Bld_Chandlery_Ext LOD0:M_Bld_Chandlery_Ext LOD1:M_Bld_Chandlery_Ext_LOD1 LOD2:M_Bld_Chandlery_Ext_LOD2;; esac
case $WHAT in all|props) up_asset M_Prop_Chandlery LOD0:M_Prop_Chandlery LOD1:M_Prop_Chandlery_LOD1;; esac
case $WHAT in all|int) up_asset M_Bld_Chandlery_Int LOD0:M_Bld_Chandlery_Int LOD1:M_Bld_Chandlery_Int_LOD1 LOD2:M_Bld_Chandlery_Int_LOD2;; esac
'
