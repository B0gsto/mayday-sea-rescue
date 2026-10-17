"""M_Chr_Casualty_Swimmer (CH1, rebuilt under the docs/06 2.1a moderation rule): ONE merged mesh per LOD. Full-length
wetsuit with boots (real offset geometry, cuffs, knee/elbow panels, back zip) + inflated SOLAS lifejacket (crotch straps,
strobe, whistle, retro tape) merged with the head/neck/hands; the base body under the clothing is deleted. See swimmer.py.
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Chr_Casualty_Swimmer --steps build,lod,validate,turntable
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import swimmer  # noqa: E402


def build():
    return swimmer.build()
