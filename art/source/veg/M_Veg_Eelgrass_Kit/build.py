"""S2 M_Veg_Eelgrass_Kit: M_Veg_Eelgrass_01..04 + _Patch_01, seagrass tufts for Calm Bay (WorldConfig
`Eelgrass`). Geometry in eelgrass.py, the shared FoliageMarine cell in eelgrass_tex.py."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import eelgrass  # noqa: E402


def build():
    return eelgrass.build()
