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


# ---- appended by the Ext builder (H2): what the exterior shell actually builds (nothing above moved)
DOOR_LEAF = (-8.0, -6.8, FLOOR, FLOOR + 1.98, Y0 + 0.15, Y0 + 0.20)   # x0, x1, z0, z1, y_out, y_in; fanlight above to DOOR z1
DOOR_STONE_OPENING = (-8.05, -6.75, 0.0, FLOOR + 2.35)  # masonry hole; 0.05 m timber linings through the wall thickness
DOOR_HINGE = (-8.0, Y0 + 0.20, FLOOR)                     # hinge line (inner face edge), the door swings inward (+Y)
BAY_OPENING = (-4.6, 8.0, 0.0, 2.95)                      # masonry hole behind the bay: open from the quay to the bay head
BAY_FLOOR = (-4.6, 8.0, Y0 - 0.58, Y0 + WALL, FLOOR)      # Ext builds the display bed up to the inner wall face (y IY0)
SHOPFRONT_PILASTERS = [(-5.0, -4.6), (8.0, 8.4)]          # x ranges, projecting to Y0 - 0.7, consoles at the fascia ends
ROOF_SLOPE = (RIDGE - EAVES) / (Y1)                       # rise per metre run (underside plane through the wall plate)
SKYLIGHT_YZ = ((4.286, 7.0), (3.422, 7.504))               # roof hole on the back slope, (y, z underside) low and high edge
ATT_EXT_EXTRA = {"ATT_DoorHinge": DOOR_HINGE}
ATT_EXT_EXTRA.update({"ATT_Lamp_%02d" % (i + 1): (x, Y0 - 1.0, 3.93) for i, x in enumerate((-3.2, 1.7, 6.7))})  # gooseneck lamp shades over the fascia (point lights)
A_BOARD = (-3.62, -2.98, -6.95)          # A-frame chalk board on the quay: x0, x1, y centre (feet +-0.25 m)


# ---- appended by the Ext builder (H2 fix round): practical light spec for the game to place (nothing above moved)
# Units: positions in this frame (metres, x3 = studs, world = pivot + (bx, bz, -by) studs, see the docstring); drop_studs is
# how far below the marker the light Attachment sits (so the shade / bulb mesh does not shadow its own light);
# brightness / range / angle are Roblox Light properties (range in studs). "face" is the SpotLight Face in the world frame.
# "on": presets where the light is lit all day, plus "dusk" presets where it is lit only when ClockTime >= 17.0 or < 7.5.
# Values match the look-dev rig (assets/review/M_Bld_Chandlery/studio/chandlery.luau): interior PointLights 0.55 / 15,
# exterior 1.1 / 16, colour 2700 K. Kind brightness scales follow the Int builder's Blender energies (220/260/140/120 W).
WARM_2700K = (255, 177, 110)
COOL_6500K = (232, 240, 255)          # daylight fill, a touch cool against the warm practicals
PRESETS = ("Clear", "Overcast", "Storm", "Night")
ON_EXT = {"presets": ("Night",), "dusk": ("Clear", "Overcast", "Storm")}           # street lamps: dark hours only
ON_INT = {"presets": ("Overcast", "Storm", "Night"), "dusk": ("Clear",)}           # shop open: lit unless a clear day
ON_DAY = {"presets": (), "day": ("Clear", "Overcast", "Storm")}                    # daylight fills: 7.5 <= ClockTime < 17.0

LIGHTS = {
    # exterior gooseneck lamps over the fascia (M_Bld_Chandlery_Ext ATT_Lamp_01..03); their Glow part goes Neon with them
    "ext_lamp": {"attachments": ("ATT_Lamp_01", "ATT_Lamp_02", "ATT_Lamp_03"), "type": "PointLight", "color": WARM_2700K,
                 "brightness": 1.1, "range": 16, "shadows": True, "drop_studs": 0.6, "on": ON_EXT,
                 "neon_part": "M_Bld_Chandlery_Ext_Glow"},
    # interior practicals (M_Bld_Chandlery_Int ATT_Light_NN, kind exported by the Int builder); Int Glow part goes Neon
    "int_pendant": {"match": "^ATT_Light_%d+$", "kind": "pendant", "type": "PointLight", "color": WARM_2700K,
                    "brightness": 0.55, "range": 15, "shadows": True, "drop_studs": 0.35, "on": ON_INT,
                    "neon_part": "M_Bld_Chandlery_Int_Glow"},
    "int_holophane": {"match": "^ATT_Light_%d+$", "kind": "holophane", "type": "PointLight", "color": WARM_2700K,
                      "brightness": 0.65, "range": 16, "shadows": True, "drop_studs": 0.35, "on": ON_INT,
                      "neon_part": "M_Bld_Chandlery_Int_Glow"},
    "int_wall": {"match": "^ATT_Light_%d+$", "kind": "wall", "type": "PointLight", "color": WARM_2700K,
                 "brightness": 0.35, "range": 12, "shadows": True, "drop_studs": 0.35, "on": ON_INT,
                 "neon_part": "M_Bld_Chandlery_Int_Glow"},
    "int_bulkhead": {"match": "^ATT_Light_%d+$", "kind": "bulkhead", "type": "PointLight", "color": WARM_2700K,
                     "brightness": 0.3, "range": 10, "shadows": False, "drop_studs": 0.2, "on": ON_INT,
                     "neon_part": "M_Bld_Chandlery_Int_Glow"},
    # desk lamp by the till (M_Prop_Chandlery_Stock ATT_Light_Till): warm pool on the counter
    "till_lamp": {"attachments": ("ATT_Light_Till",), "type": "SpotLight", "face": "Bottom", "angle": 70,
                  "color": WARM_2700K, "brightness": 0.9, "range": 7, "shadows": True, "drop_studs": 0.1, "on": ON_INT},
    # cool daylight fill: inside the bay (between the glazing and the display bed) and under the rooflight; no shadows
    "bay_fill": {"positions": [(-2.5, Y0 - 0.3, 2.3), (1.7, Y0 - 0.3, 2.3), (5.9, Y0 - 0.3, 2.3)], "type": "PointLight",
                 "color": COOL_6500K, "brightness": 0.2, "range": 12, "shadows": False, "drop_studs": 0.0, "on": ON_DAY},
    "skylight_fill": {"positions": [((SKYLIGHT[0] + SKYLIGHT[1]) / 2, 3.85, 6.6)], "type": "SpotLight", "face": "Bottom",
                      "angle": 90, "color": COOL_6500K, "brightness": 0.35, "range": 14, "shadows": False,
                      "drop_studs": 0.0, "on": ON_DAY},
    # warm night glow behind the glazing so the shop windows read lit from the quay (bay behind the glass, loft behind
    # the half-drawn curtains); no shadows (cheap), cover the window reveals only
    "glazing_glow": {"positions": [(-2.5, Y0 + 0.35, 2.2), (1.7, Y0 + 0.35, 2.2), (5.9, Y0 + 0.35, 2.2)]
                     + [((a + b) / 2, Y0 + 0.9, 4.9) for a, b in LOFT_WINDOWS], "type": "PointLight", "color": WARM_2700K,
                     "brightness": 0.4, "range": 10, "shadows": False, "drop_studs": 0.0,
                     "on": {"presets": ("Night",), "dusk": ("Clear", "Overcast", "Storm")}},
}

# ---- appended (H2 fix round): which interior ATT_Light_NN is which LIGHTS kind (Int builder's lamp order, 2026-10-17)
LIGHT_KINDS = {"ATT_Light_%02d" % i: k for r, k in ((range(1, 8), "pendant"), (range(8, 10), "holophane"),
                                                    (range(10, 17), "wall"), (range(17, 22), "bulkhead")) for i in r}
LIGHT_KINDS["ATT_Light_Till"] = "till"   # M_Prop_Chandlery_Stock desk lamp by the till (warm SpotLight down)
