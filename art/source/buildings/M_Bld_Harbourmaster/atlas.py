"""M_Bld_Harbourmaster Details atlas rects (u0, v0, u1, v1), shared by build.py and maketex.py.

One own 1024 px atlas: brass nameplate, storm queue board, tide board, glass, white joinery and granite trim strips
(full width, u tiles), brass, iron, signal red, rope and terracotta pots. Walls and slates are the shared quay sets
(Station Granite ashlar, Chandlery Slate), gutters / downpipes / fascia / lead are the BldTrim Sheet strips.
"""

RECTS = {
    "StormBoard": (0.00, 0.40, 1.00, 0.70),     # 3.22 x 0.96 m whiteboard inside the big front window frame
    "Nameplate": (0.01, 0.70, 0.67, 0.92),      # 1.02 x 0.36 m brass plate, 130 px caps
    "BoardBack": (0.675, 0.70, 0.715, 0.92),     # dark rebate behind the storm board
    "TideBoard": (0.72, 0.70, 0.92, 0.98),      # 0.50 x 0.70 m wall tide table
    "Glass": (0.93, 0.70, 1.00, 0.98),
    "WhiteJoin": (0.00, 0.30, 1.00, 0.38),      # strip: white-painted joinery, u tiles every 1 m
    "Granite": (0.00, 0.20, 1.00, 0.30),        # strip: dressed granite sills / lintels / copings, u tiles every 1 m
    "Brass": (0.00, 0.10, 0.10, 0.18),
    "Iron": (0.10, 0.10, 0.20, 0.18),
    "RedPaint": (0.20, 0.10, 0.30, 0.18),
    "Rope": (0.30, 0.10, 0.42, 0.18),
    "Pots": (0.42, 0.10, 0.52, 0.18),
    "WhitePaint": (0.52, 0.10, 0.62, 0.18),
}
