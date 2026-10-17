#!/usr/bin/env python3
"""Shim: the sky baker moved to tools/blender/cubemap.py (docs/12 section 1.1). Same CLI and outputs:

Usage:  python3 art/ocean/bake_skies.py [Preset ...]      (default: all five)
Output: assets/ocean/sky/<Preset>_<Face>.png, 1024x1024 RGB, Face in Bk Dn Ft Lf Rt Up.
Every cubemap.py option (--out, --size, --hdri ...) also works here.
"""
import os
import runpy
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TARGET = os.path.join(ROOT, "tools", "blender", "cubemap.py")

if __name__ == "__main__":
    sys.argv[0] = TARGET
    runpy.run_path(TARGET, run_name="__main__")
