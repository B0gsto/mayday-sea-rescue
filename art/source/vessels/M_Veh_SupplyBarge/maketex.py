"""Flat palette set for the Supply Barge (shared Lego palette with M_Bld_Depot).

    python3 art/source/vessels/M_Veh_SupplyBarge/maketex.py --out build/prod/M_Veh_SupplyBarge/textures/M_Veh_SupplyBarge \
        --name Barge --set Hull
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../../buildings/M_Bld_Depot"))
import palette  # noqa: E402

p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--name", required=True)
p.add_argument("--set", dest="set_name", default="Hull")
p.add_argument("--size", type=int, default=palette.SIZE)
a = p.parse_args()
print(palette.write_maps(a.out, a.name, a.set_name, a.size))
