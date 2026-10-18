"""R1a M_Road_Bench (docs/12 2.4): street furniture on the shared Street atlas. Geometry and UVs: art/source/roads/kit.py.

    python3 art/source/roads/streettex.py     (atlas maps, once)
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Road_Bench --steps build,lod,validate,export,turntable
"""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
import kit  # noqa: E402


def build():
    return kit.spec("M_Road_Bench")
