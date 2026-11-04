"""M_Upg_RIB_ThunderWing: geometry in art/source/vehicles/_UpgRIB/pieces.py (hull frame, pivot at the hull origin)."""
import importlib
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_UpgRIB"))
import pieces  # noqa: E402


def build():
    importlib.reload(pieces)
    return pieces.spec("ThunderWing")
