"""HP1 M_Hbr_Ladder: galvanised recessed quay ladder (geometry in ../_hp1/kit.py, maps in ../_hp1/maketex.py)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_hp1"))
import kit  # noqa: E402


def build():
    return kit.ladder_spec(None)
