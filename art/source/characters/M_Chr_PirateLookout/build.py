"""M_Chr_PirateLookout: see art/source/vessels/M_Veh_PirateBoat/crewgeo.py and its RESULT.md (shared atlas with the boat)."""
import importlib
import os
import sys

BOAT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../vessels/M_Veh_PirateBoat"))
sys.path.insert(0, BOAT)
for _m in ("kit", "crewgeo"):
    sys.modules.pop(_m, None)
crewgeo = importlib.import_module("crewgeo")


def build():
    return crewgeo.build_asset("M_Chr_PirateLookout", "crewB")
