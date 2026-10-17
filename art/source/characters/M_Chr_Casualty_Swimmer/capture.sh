#!/bin/bash
# CH1 Studio pass: insert the three LOD0 rbxm, import_asset.luau each, play, place the swimmer at sea level, shots calm then storm.
set -uo pipefail
GAME="$(cd "$(dirname "$0")/../../../.." && pwd)"; TOOLS=~/RobloxProjects/tools; cd "$GAME"; S=build/ch1/studio
"$TOOLS/build.sh" "$GAME" 2>&1 | tail -1
"$TOOLS/with-lock.sh" studio --owner "CH1 shots" -- bash -c "
python3 tools/studio/smoke.py open || exit 1
for A in M_Chr_Casualty_Swimmer M_Chr_HumanBase_M M_Chr_HumanBase_F; do
  python3 $TOOLS/studio-insert.py assets/models/\${A}_LOD0.rbxm auto Workspace 2>&1 | tail -1
  python3 tools/studio/smoke.py lua Edit $S/import_\$A.luau 2>&1 | cut -c1-300
done
python3 tools/studio/smoke.py play start && sleep 8
python3 tools/studio/smoke.py lua Server 'return game.ServerStorage:WaitForChild(\"Storm_DevCommand\"):Invoke(\"/calm\")'
python3 tools/studio/smoke.py lua Server $S/place.luau
python3 $TOOLS/studio-shot.py --dm Client --setup art/lookdev/shot-setup.luau --shots $S/shots_calm.json --out $S/calm.png --keep $S/cells --cols 3
python3 tools/studio/smoke.py lua Server 'return game.ServerStorage:WaitForChild(\"Storm_DevCommand\"):Invoke(\"/storm now\")'
sleep 4
python3 $TOOLS/studio-shot.py --dm Client --setup art/lookdev/shot-setup.luau --shots $S/shots_storm.json --out $S/storm.png --keep $S/cells --cols 2
python3 tools/studio/smoke.py console | tail -4; python3 tools/studio/smoke.py play stop; python3 tools/studio/smoke.py close"
