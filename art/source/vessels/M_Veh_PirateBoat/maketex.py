"""Palette + printed tiles of the pirate set (shared by the boat and the crew).

    python3 art/source/vessels/M_Veh_PirateBoat/maketex.py --out build/prod/M_Veh_PirateBoat/textures/M_Veh_PirateBoat
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import palette  # noqa: E402

p = argparse.ArgumentParser()
p.add_argument("--out", required=True)
print(palette.write_maps(p.parse_args().out, "PirateBoat", "Brick"))
