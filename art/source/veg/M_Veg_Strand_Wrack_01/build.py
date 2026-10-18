"""Strand line M_Veg_Strand_Wrack_01: dried bladderwrack / serrated wrack clump lying flat. All geometry in art/source/veg/Strand/strandkit.py."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Strand"))
import strandkit  # noqa: E402


def build():
    return strandkit.build("M_Veg_Strand_Wrack_01")
