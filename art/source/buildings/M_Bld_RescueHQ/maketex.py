"""Flat palette set T_RescueHQ_Brick (run before validate; same idea as M_Bld_Depot/maketex.py).

    python3 art/source/buildings/M_Bld_RescueHQ/maketex.py --out build/prod/M_Bld_RescueHQ/textures/M_Bld_RescueHQ
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette  # noqa: E402

p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
print(palette.write_maps(p.parse_args().out))
