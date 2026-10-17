"""G1 M_Veg_Gorse_03: low cliff-edge gorse, sparse flowers. All geometry in art/source/veg/G1/vegkit.py."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "G1"))
import vegkit  # noqa: E402


def build():
    return vegkit.build("M_Veg_Gorse_03")
