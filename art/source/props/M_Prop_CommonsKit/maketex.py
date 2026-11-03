"""Flat palette set for M_Prop_CommonsKit (BoardKit cells, 9 green / 13 pink; no PBR scans).

    python3 art/source/props/M_Prop_CommonsKit/maketex.py --out build/prod/M_Prop_CommonsKit/textures/M_Prop_CommonsKit
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette  # noqa: E402

p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--name", default="CommonsKit")
p.add_argument("--set", dest="set_name", default="Brick")
a = p.parse_args()
print(palette.write_maps(a.out, a.name, a.set_name))
