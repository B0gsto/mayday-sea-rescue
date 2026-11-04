"""M_Upg_Hydrofoil_TTail: geometry in art/source/vessels/_UpgHydrofoil/pieces.py (asset frame: RIB pivot, sea at y 2.05, bow -Z)."""
import importlib
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_UpgHydrofoil"))
import hk  # noqa: E402
import pieces  # noqa: E402


def build():
    importlib.reload(hk)
    importlib.reload(pieces)
    return pieces.spec("TTail")
