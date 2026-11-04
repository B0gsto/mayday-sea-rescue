"""M_Upg_JetSki_HugeSpoiler: geometry in art/source/vehicles/_UpgJetSki/pieces.py (hull frame, pivot at the hull origin)."""
import importlib
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_UpgJetSki"))
import kitgeo  # noqa: E402
import pieces  # noqa: E402


def build():
    importlib.reload(kitgeo)
    importlib.reload(pieces)
    return pieces.spec("HugeSpoiler")
