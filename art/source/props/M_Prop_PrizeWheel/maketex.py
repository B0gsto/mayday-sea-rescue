"""Palette set for M_Prop_PrizeWheel (own cells: glossy plastic, gold, chrome).

    python3 art/source/props/M_Prop_PrizeWheel/maketex.py --out build/prod/M_Prop_PrizeWheel/textures/M_Prop_PrizeWheel
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette  # noqa: E402

p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
a = p.parse_args()
print(palette.write_maps(a.out, "PrizeWheel", "Brick"))
