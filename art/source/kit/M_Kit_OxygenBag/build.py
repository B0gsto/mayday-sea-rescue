"""E1 M_Kit_OxygenBag: hand-held rescue kit on the shared kit atlas (art/source/kit/E1, docs/12 2.8)."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "E1"))
from kitgeo import build_kit  # noqa: E402


def build():
    return build_kit("M_Kit_OxygenBag")
