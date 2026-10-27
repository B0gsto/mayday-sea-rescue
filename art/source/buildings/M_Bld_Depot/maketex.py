"""Flat palette set for the Lego Depot / Supply Barge (no PBR scans, no wear: docs/05 5).

    python3 art/source/buildings/M_Bld_Depot/maketex.py --out build/prod/M_Bld_Depot/textures/M_Bld_Depot \
        --name Depot --set Brick
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette  # noqa: E402

p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--name", required=True)
p.add_argument("--set", dest="set_name", default="Brick")
p.add_argument("--size", type=int, default=palette.SIZE)
a = p.parse_args()
palette.PALETTE[palette.PINK] = (150, 72, 44)   # Depot set only: pink is unused here, cell 10 is the warm quay fascia
print(palette.write_maps(a.out, a.name, a.set_name, a.size))
