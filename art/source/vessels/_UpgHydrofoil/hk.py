"""The Lifeboat stage's toy-brick mesh kit (_UpgLifeboat/kit.py) with the Hydrofoil palette, the concept's frame and lofts.

Authored in the concept's numbers (artifact f23406cb, +Z bow, sea at y 0.3, hull bottom at t = 6). The root frame turns that into
the asset frame: bow -Z, sea at asset y 2.05, which is where the RIB frame puts it (Builder.RIB_ORIGIN; floatPoints y -1.65, draft 1.6).
"""
import importlib.util
import math
import os

from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
_s = importlib.util.spec_from_file_location("upg_kit_base", os.path.join(HERE, "../_UpgLifeboat/kit.py"))
kit = importlib.util.module_from_spec(_s)
_s.loader.exec_module(kit)
kit.TEX_DIR = os.path.join(GAME, "build/prod/_UpgHydrofoil/textures")
kit.SET_NAME, kit.SET = "UpgHydrofoil", "Palette"
SET_NAME, SET, TEX_DIR = kit.SET_NAME, kit.SET, kit.TEX_DIR

# cell -> (rgb, roughness, metal): concept colours (maketex.py reads this table)
PALETTE = [
    ("F47B20", 0.30, 0.0),   # 0 hull orange
    ("FFC72C", 0.30, 0.0),   # 1 foil yellow
    ("F4F4F4", 0.30, 0.0),   # 2 white
    ("3A3F47", 0.45, 0.0),   # 3 dark
    ("A0A5A9", 0.35, 0.0),   # 4 light grey
    ("5AC8FA", 0.12, 0.0),   # 5 screen
    ("4FD8FF", 0.10, 0.0),   # 6 jet glow
    ("FF8A1F", 0.40, 0.0),   # 7 flame
    ("FFD23F", 0.40, 0.0),   # 8 flame core
    ("D6262B", 0.30, 0.0),   # 9 red (sheet driver only)
    ("F4F4F4", 0.30, 0.0), ("F4F4F4", 0.30, 0.0), ("F4F4F4", 0.30, 0.0), ("F4F4F4", 0.30, 0.0), ("F4F4F4", 0.30, 0.0), ("F4F4F4", 0.30, 0.0),
]
ORANGE, YELLOW, WHITE, DARK, GREY, SCREEN, GLOW, FLAME, FLAME2, RED = range(10)
WATER_ASSET = 2.05          # asset y of the sea up to L33
UP = WATER_ASSET - 0.3      # concept y -> asset y


class Kit(kit.Kit):
    def __init__(self):
        super().__init__()
        self.stack = [Matrix.Rotation(math.pi, 4, "Y") @ Matrix.Translation((0, UP, 0))]

    def rings(self, rings, cell):
        """A closed loft through equal-length rings of 3D points."""
        n = len(rings[0])
        vs = [p for r in rings for p in r]
        faces = [tuple(range(n)), tuple(reversed(range((len(rings) - 1) * n, len(rings) * n)))]
        for s in range(len(rings) - 1):
            faces += [(s * n + i, s * n + (i + 1) % n, (s + 1) * n + (i + 1) % n, (s + 1) * n + i) for i in range(n)]
        self._emit(self.stack[-1], vs, faces, cell)

    def loft_z(self, secs, cell, b=0.14):
        """Sections along z, each (z, half width, y0, y1), as chamfered slabs: the sculpted wedge."""
        def ring(z, w, y0, y1):
            c = min(b, w * 0.35, (y1 - y0) * 0.35)
            return [(-w + c, y0, z), (w - c, y0, z), (w, y0 + c, z), (w, y1 - c, z), (w - c, y1, z), (-w + c, y1, z), (-w, y1 - c, z), (-w, y0 + c, z)]
        self.rings([ring(*s) for s in secs], cell)

    def plate(self, poly, y0, y1, cell, bevel=0.12):
        """A plan polygon of (x, z) from y0 to y1."""
        self.prism(poly, y0, y1, cell, lambda a, c, d: (a, d, c), bevel=bevel)

    def bigstuds(self, spots, y, cell):
        for x, z in spots:
            self.stud(self.stack[-1], (x, y - 0.02, z), cell, big=True)

    def tongue(self, x, y, z, w, ln, cell):
        """A rounded flame tongue flying aft from z: fire, never a warhead."""
        self.at((x, y, z - ln / 2 + 0.1), (90, 0, 0), lambda: self.sphere(w, (0, 0, 0), cell, (1, ln / 2 / w, 1), n=14, lat=6))


def material():
    return kit.material("M_UpgHydrofoil_Palette")
