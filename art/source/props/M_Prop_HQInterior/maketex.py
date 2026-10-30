"""Flat palette set for M_Prop_HQInterior (same Lego palette as the dock add-ons; no PBR scans).

    python3 art/source/props/M_Prop_HQInterior/maketex.py --out build/prod/M_Prop_HQInterior/textures/M_Prop_HQInterior
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette  # noqa: E402

p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
p.add_argument("--name", default="HQInterior")
p.add_argument("--set", dest="set_name", default="Brick")
a = p.parse_args()
print(palette.write_maps(a.out, a.name, a.set_name))
