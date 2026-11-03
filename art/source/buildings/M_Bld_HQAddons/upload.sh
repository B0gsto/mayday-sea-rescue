#!/bin/bash
# Upload the HQ pair (M_Bld_RescueHQ Lv1-2 + M_Bld_HQAddons Lv3-5): flat palette maps (Image) and the FBX LODs (Model).
# Run from the checkout that holds assets/ (worktree or main).
set -uo pipefail
GAME=${GAME:-$(cd "$(dirname "$0")/../../../.." && pwd)}
T=~/RobloxProjects/tools
cd "$GAME"
"$T/with-lock.sh" assets.MaydaySeaRescue --owner "HQ upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
for A in M_Bld_RescueHQ M_Bld_HQAddons; do
  for f in assets/textures/$A/*.png; do
    python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
  done
  python3 $T/assets.py upload . assets/fbx/$A/${A}_LOD0.fbx --type Model --name $A 2>&1 | tail -2
  python3 $T/assets.py upload . assets/fbx/$A/${A}_LOD1.fbx --type Model --name ${A}_LOD1 2>&1 | tail -2
  python3 $T/assets.py upload . assets/fbx/$A/${A}_LOD2.fbx --type Model --name ${A}_LOD2 2>&1 | tail -2
done
'
