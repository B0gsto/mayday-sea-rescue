"""M_Hbr_NavMark_South (docs/12 2.3, batch HP2b): South cardinal. Built by ../HP2b/buoylib.py; see ../HP2b/marks.py for the IALA spec.

    ~/RobloxProjects/tools/blender-run.sh art/source/harbour/HP2b/run_all.py -- South
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "HP2b"))
import buoylib  # noqa: E402


def build():
    return buoylib.build("South")
