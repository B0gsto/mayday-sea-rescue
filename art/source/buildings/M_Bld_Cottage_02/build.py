"""H3 M_Bld_Cottage_02: assembled from the Cornish cottage kit (art/source/buildings/M_Bld_Cottage_Kit/kit.py, variants.V[2])."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "M_Bld_Cottage_Kit"))
import kit  # noqa: E402


def build():
    return kit.build(2)
