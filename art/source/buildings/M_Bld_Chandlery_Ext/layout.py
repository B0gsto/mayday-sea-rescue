"""H2 Port Haven Chandlery: the shared frame for M_Bld_Chandlery_Ext, M_Bld_Chandlery_Int and M_Prop_Chandlery.

All three assets are authored in ONE frame so they drop in at the same pivot: metres here (x3 = studs in Blender),
Blender X along the frontage, front (the quay / Harbour Road) is -Y, Z up. Origin = centre of the main wall footprint
at quay level. Read-only for the Int and Props builders (import it via sys.path); the Ext builder owns it.

Placement in map/Build.luau (greybox Chandlery x -74..-14, z -78..-42, door on the +Z side): pivot at world
(-44, LandTopY, -60) yawed 180 degrees, so world = pivot + (bx, bz, -by) in studs and the front faces +Z.
The greybox counter prompt (-32, g + 4.5, -60.5) maps to ATT_Counter below.
"""

# shell (exterior walls, granite 0.55 m)
X0, X1 = -10.0, 10.0
Y0, Y1 = -6.0, 6.0            # Y0 = front wall outer face
WALL = 0.55
IX0, IX1 = X0 + WALL, X1 - WALL   # inner faces -9.45 .. 9.45
IY0, IY1 = Y0 + WALL, Y1 - WALL   # -5.45 .. 5.45
FLOOR = 0.15                  # ground floor finished level (one step up from the quay at 0)
BEAM_UNDERSIDE = 2.95         # exposed ceiling beams (run along Y, every 2.4 m in X: x = -7.2, -4.8 ... 7.2)
BEAM_XS = [-7.2, -4.8, -2.4, 0.0, 2.4, 4.8, 7.2]
LOFT = 3.35                   # loft finished floor level (structure 3.05 .. 3.35)
EAVES = 6.0                   # wall plate (outside)
RIDGE = 9.5                   # ridge along X; gables at the X ends; chimney on the west gable

# front wall openings (Y = Y0)
DOOR = (-8.0, -6.8, FLOOR, FLOOR + 2.3)          # x0, x1, z0, z1: half-glazed timber door, opens inward, hinge at x -8.0
BAY = (-4.6, 8.0, 0.75, 2.95)                     # deep timber bay window: x0, x1, sill, head; projects to Y0 - 0.6
BAY_DEPTH = 0.6
FASCIA = (-5.0, 8.4, 3.05, 3.65)                  # painted fascia board "PORT HAVEN CHANDLERY"
SIGN = (-5.8, Y0 - 0.55, 3.0)                     # hanging sign on a wrought bracket (centre), double-sided, 0.9 x 0.6 m
LOFT_WINDOWS = [(-7.0, -5.9), (-1.55, -0.45), (3.9, 5.0)]   # x0, x1 of the loft sashes; sill 4.0, head 5.5
LOFT_WIN_Z = (4.0, 5.5)
SKYLIGHT = (-3.0, -2.0, 1.0)  # x0, x1 on the back (+Y) slope, 0.8 m up-slope from 7.0 m height: x0, x1, z centre offset

# interior (M_Bld_Chandlery_Int)
STAIR = (8.3, 9.45, 4.9, -1.4)    # x0, x1, y at the bottom step (floor), y at the top landing edge (loft); rises toward -Y
STAIRWELL = (8.3, 9.45, -1.4, IY1)
COUNTER = (0.7, 7.3, 0.6, 1.25, 1.0)   # x0, x1, y_front (customer side), y_back, height
BEHIND_COUNTER_WALL = (0.0, 8.2)       # back wall (+Y) shelving / hardware wall / framed service cards, x range
CHART_TABLE = (-3.2, -1.4, 3.6, 4.6, 0.85)
FITTING_ROOM = (-9.45, -7.6, -1.2, 1.2)  # loft, west end: curtain booth, full-length mirror on the west wall
SKY_LOFT_LIGHT_XS = [-5.0, 0.0, 5.0]

# props (M_Prop_Chandlery): stand positions
RACK_WALL = (-9.1, -3.6, 4.4)            # wall rail for lifejackets on the west wall: x, y0, y1, rail height 1.7
RACK_MID = (-6.2, -2.2, 4.1)             # free-standing rail for foul-weather gear: x0, x1, y
GONDOLA = (-6.0, -1.6, -1.5, -0.3)       # double-sided shelf unit: x0, x1, y0, y1, 1.4 m high: rope, shackles, blocks
MANNEQUINS = [(-2.6, -5.85, FLOOR), (5.0, -5.85, FLOOR), (-4.0, 3.9, LOFT), (-0.7, 3.9, LOFT)]   # 2 in the bay window, 2 in the loft
DOG_CORNER = (-0.4, 2.6)                 # dog basket + low rail of dog coats (x, y)

# attachment points (ATT_ empties, metres in this frame; z is the prompt height)
ATT = {
    # Ext
    "ATT_Door": (-7.4, Y0 - 0.6, 1.2),           # outside the door
    "ATT_Sign": SIGN,
    # Int
    "ATT_DoorInside": (-7.4, IY0 + 0.7, 1.2),
    "ATT_Counter": (4.0, 0.2, 1.5),              # = greybox CounterPrompt (PromptAnchor ShopCounter)
    "ATT_Till": (5.6, 0.95, 1.1),
    "ATT_Logbook": (2.2, 0.9, 1.05),
    "ATT_ServiceCards": (4.0, IY1 - 0.05, 1.9),
    "ATT_ChartTable": (-2.3, 3.4, 1.0),
    "ATT_StairBottom": (8.9, 5.2, FLOOR + 0.1),
    "ATT_StairTop": (8.9, -1.8, LOFT + 0.1),
    "ATT_Mirror": (-9.0, 0.0, LOFT + 1.2),
    "ATT_FittingRoom": (-8.5, 0.0, LOFT + 1.0),
    # Props
    "ATT_Rack_01": (-8.6, 0.4, 1.4),             # lifejacket wall rail
    "ATT_Rack_02": (-4.2, 3.6, 1.4),             # foul-weather rail
    "ATT_Rack_03": (-3.8, -1.9, 1.2),            # gondola (rope, shackles, blocks)
    "ATT_Mannequin_01": (-2.6, -5.3, 1.3),
    "ATT_Mannequin_02": (5.0, -5.3, 1.3),
    "ATT_Mannequin_03": (-4.0, 3.3, LOFT + 1.2),
    "ATT_Mannequin_04": (-0.7, 3.3, LOFT + 1.2),
    "ATT_DogBasket": (-0.4, 2.0, 0.6),
    "ATT_HornBoard": (-9.0, -4.6, 1.5),
    "ATT_SwatchBoard": (-6.0, IY1 - 0.4, 1.5),
    "ATT_RadioShelf": (7.6, IY1 - 0.4, 1.6),
}


def studs(p):
    return tuple(v * 3.0 for v in p)
