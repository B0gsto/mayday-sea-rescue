"""M_Upg_Lifeboat_IcePlough: geometry in art/source/vessels/_UpgLifeboat/pieces.py (hull frame, pivot at the hull origin)."""
import importlib
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_UpgLifeboat"))
import kit  # noqa: E402
import pieces  # noqa: E402


def build():
    importlib.reload(kit)
    importlib.reload(pieces)
    return pieces.spec("IcePlough")
