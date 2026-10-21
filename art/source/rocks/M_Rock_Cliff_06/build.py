"""K1 M_Rock_Cliff_06: Poly Haven CC0 scan, decimated and re-baked (art/source/rocks/_kit)."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_kit"))
from piece_build import build_piece  # noqa: E402


def build():
    return build_piece("M_Rock_Cliff_06")
