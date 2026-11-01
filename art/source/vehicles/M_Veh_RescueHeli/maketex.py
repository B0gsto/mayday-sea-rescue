"""Flat palette set for M_Veh_RescueHeli (same Lego palette as the rescue vehicles; no PBR scans).

    python3 art/source/props/M_Veh_RescueHeli/maketex.py --out build/prod/M_Veh_RescueHeli/textures/M_Veh_RescueHeli
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette  # noqa: E402

p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--name", default="RescueHeli")
p.add_argument("--set", dest="set_name", default="Lego")
a = p.parse_args()
print(palette.write_maps(a.out, a.name, a.set_name))
