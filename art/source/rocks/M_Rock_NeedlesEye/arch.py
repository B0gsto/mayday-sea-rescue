"""M_Rock_NeedlesEye shared numbers: pure Python (no bpy) so build.py (Blender) and compose_maps.py (system python3)
agree on the size and the tide line.

Blender axes: X = the span across the gully (60 studs, cliff side -X, open sea +X), Y = the depth through the gully
(30 studs; the eye tunnels along Y), Z = up, base at z = 0. WorldConfig GullyArch (30 x 60 studs) sits on the gully
floor 30 studs under the water, so the tide line crosses the rock at WL.
"""

SPAN, THICK, TOP = 60.0, 30.0, 58.0     # bbox in studs
WL = 30.0                                # the tide line above the base
