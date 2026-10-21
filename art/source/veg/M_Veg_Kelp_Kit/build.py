"""S2 M_Veg_Kelp_Kit: M_Veg_Kelp_01 to _04 (Laminaria forest kelp for the Haven Head / Skerries beds). All
geometry and the FoliageMarine atlas cell are in art/source/veg/M_Veg_Kelp_Kit/kelpkit.py (+ kelp_tex.py)."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kelpkit  # noqa: E402


def build():
    return kelpkit.build()
