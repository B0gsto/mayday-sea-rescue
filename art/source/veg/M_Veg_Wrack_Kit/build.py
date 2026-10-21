"""M_Veg_Wrack_Kit (docs/12 2.5, S2): four intertidal wrack mats; all geometry in wrackkit.py, the shared marine
atlas cell in wrack_tex.py. Build: python3 wrack_tex.py (atlas) then tools/blender/run.py --build <this>."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wrackkit  # noqa: E402


def build():
    return wrackkit.build()
