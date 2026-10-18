"""HP1 M_Hbr_QuayKit_LadderBay: quay kit piece (geometry in ../_hp1/kit.py, maps in ../_hp1/maketex.py)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "_hp1"))
import kit  # noqa: E402


def build():
    return kit.quay_spec("LadderBay", 6, (3.0, None, 4.0), None)
