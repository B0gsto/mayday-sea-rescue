"""HP2a M_Hbr_Rope_Chain: harbour prop on the shared harbour prop atlas (art/source/harbour/M_Hbr_PropAtlas)."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "M_Hbr_PropAtlas"))
from props import build_prop  # noqa: E402


def build():
    return build_prop("M_Hbr_Rope_Chain")
