"""Flat palette set for M_Bld_Bunkhouse (as M_Bld_Depot/maketex.py).

    python3 art/source/buildings/M_Bld_Bunkhouse/maketex.py --out build/prod/M_Bld_Bunkhouse/textures/M_Bld_Bunkhouse
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette  # noqa: E402

p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--name", default="Bunkhouse")
p.add_argument("--set", dest="set_name", default="Brick")
a = p.parse_args()
print(palette.write_maps(a.out, a.name, a.set_name))
