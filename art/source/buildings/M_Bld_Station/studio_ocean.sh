#!/bin/bash
# H1 play-mode ocean pass (studio-shot.py ocean mode, art/lookdev/README.md): the station and slipway imported on the
# server at the studio_pass.sh layout (run make_studio.py first: it writes the import/scene setups), the game's client
# mesh ocean in front. 2 shots, FOV 40: harbour hero Overcast dry, slipway from the water in the storm (wet).
# Studio lock, then one heavy slot; own TestBench window (mayday-lookdev-h1o), closed at the end.
set -uo pipefail
cd /Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
R=assets/review/M_Bld_Station
python3 art/source/buildings/M_Bld_Station/make_studio.py || exit 1
# server variant of scene.luau without the ContentProvider preload (it times out on the play server; the client shots preload)
python3 - <<'PY2'
R = 'assets/review/M_Bld_Station/studio/'
s = open(R + 'scene.luau').read()
open(R + 'scene-server.luau', 'w').write(s[:s.index('local CP = ')] + 'return "H1 scene (server) ok"\n')
PY2
python3 - <<'PY'
import json
R = "assets/review/M_Bld_Station/"
def s(name, cam, look, preset, wet):
    return {"name": name, "cam": cam, "look": look, "settle": 4.0, "storm": preset == "Storm",
            "lua": "workspace.CurrentCamera.FieldOfView = 40 _G.LookDev.preload(25) return _G.LookDev.apply('%s', %s)"
                   % (preset, "true" if wet else "false")}
json.dump({"ocean": True, "storm_wait": 6, "expect": ["M_Bld_Station", "M_Bld_Slipway"], "shots": [
    s("M_Bld_Station_Ocean_Overcast_dry", [40, 7, 175], [-20, 10, 10], "Overcast", False),
    s("M_Bld_Slipway_Ocean_Storm_wet", [-10, 6, 160], [-50, 4, 80], "Storm", True)]},
    open(R + "shots_ocean.json", "w"), indent=1)
PY
export MAYDAY_STUDIO_TAG=mayday-lookdev-h1o
"$T/with-lock.sh" studio --owner "H1 ocean shots" -- "$T/with-heavy.sh" -- bash -c "
python3 tools/studio/smoke.py open &&
STUDIO_ID=\$(cat build/smoke/.sid-mayday-lookdev-h1o) python3 $T/studio-shot.py \
  --insert assets/models/M_Bld_Station.rbxm --insert assets/models/M_Bld_Slipway.rbxm \
  --setup $R/studio/import-setup.luau --setup $R/studio/import-slipway.luau --setup $R/studio/scene-server.luau \
  --look-setup art/lookdev/shot-setup.luau \
  --shots $R/shots_ocean.json --out $R/studio-ocean.png --keep $R/studio --cols 2 --white-check;
python3 tools/studio/smoke.py console 2>&1 | tail -6; python3 tools/studio/smoke.py close"
mkdir -p assets/review/M_Bld_Slipway/studio
mv -f $R/studio/M_Bld_Slipway_Ocean_*.png assets/review/M_Bld_Slipway/studio/ 2>/dev/null
