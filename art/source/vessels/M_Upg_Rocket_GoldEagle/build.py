"""M_Upg_Rocket_GoldEagle: geometry in art/source/vessels/_UpgRocket/pieces.py."""
import importlib
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_UpgRocket"))
import kit  # noqa: E402
import pieces  # noqa: E402


def build():
    importlib.reload(kit)
    importlib.reload(pieces)
    return pieces.spec("GoldEagle")
