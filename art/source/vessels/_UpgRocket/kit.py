"""Toy-brick kit for the Rocket Cutter stage: the Lifeboat stage's Kit with this stage's palette, frames and a loft.

Everything is authored in the concept's numbers (artifact b8ff43b0): +X bow, +Y up, +Z starboard, sea at y 0. The frames below turn
that into the game's axes (+X starboard, +Y up, -Z bow), HullRoot mid-length at concept x 10, sea at hull y +1.5 (see RESULT.md).
Palette: maketex.py writes the maps (system python3).
"""
import importlib.util
import math
import os

from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
_spec = importlib.util.spec_from_file_location("_upglifeboat_kit", os.path.join(HERE, "../_UpgLifeboat/kit.py"))
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)
base.TEX_DIR = os.path.join(GAME, "build/prod/_UpgRocket/textures")
base.SET_NAME = SET_NAME = "UpgRocket"
SET = base.SET
TEX_DIR = base.TEX_DIR

# cell -> (rgb, roughness, metal)
PALETTE = [
    ("F2F1EC", 0.30, 0.0),   # 0 white
    ("16304E", 0.30, 0.0),   # 1 navy
    ("D7262E", 0.30, 0.0),   # 2 red
    ("F5BE3C", 0.25, 0.35),  # 3 gold
    ("E4E8EC", 0.10, 1.0),   # 4 chrome
    ("23262C", 0.60, 0.0),   # 5 rubber
    ("FFC72C", 0.30, 0.0),   # 6 seat yellow
    ("FF6600", 0.30, 0.0),   # 7 vest orange
    ("FF8F1C", 0.40, 0.0),   # 8 flame orange
    ("FFD23F", 0.40, 0.0),   # 9 flame yellow
    ("FFE98A", 0.40, 0.0),   # 10 flame core (warm, never white-hot)
    ("F2C9A0", 0.45, 0.0),   # 11 skin
    ("1E7FD6", 0.15, 0.0),   # 12 deep water
    ("39C6E0", 0.15, 0.0),   # 13 aqua
    ("C8B27A", 0.45, 0.0),   # 14 deck tan
    ("1A2A38", 0.06, 0.0),   # 15 dark glass
]
WHITE, NAVY, RED, GOLD, CHROME, RUBBER, SEAT, VEST, FLAME_O, FLAME_Y, FLAME_W, SKIN, DEEP, AQUA, TAN, GLASS = range(16)

ORIGIN = (0.0, -2.8, -0.01)     # Builder.TIDEWALKER_ORIGIN: where a Lifeboat-frame hull model's pivot sits in HullRoot space


def frame(dy, tz):
    return Matrix(((0, 0, 1, 0), (0, 1, 0, dy), (-1, 0, 0, tz), (0, 0, 0, 1)))


ROOT_FRAME = frame(1.5, 10.0)               # pieces: pivot at HullRoot
MODEL_FRAME = frame(1.5 - ORIGIN[1], 10.0 - ORIGIN[2])  # the hull model: pivot at Builder.TIDEWALKER_ORIGIN


class Kit(base.Kit):
    def __init__(self, m=ROOT_FRAME):
        super().__init__()
        self.stack = [m]

    def scaled(self, pos, s, fn, rot=None):
        self.stack.append(self.stack[-1] @ Matrix.Translation(pos) @ base.rot_m(rot) @ Matrix.Scale(s, 4))
        fn()
        self.stack.pop()

    def loft(self, sections, cells):
        """Closed sections (same point count) joined in order, ends capped. cells: one per section side, or one cell."""
        n = len(sections[0])
        vs = [p for s in sections for p in s]
        faces, fc = [tuple(range(n)), tuple(reversed(range((len(sections) - 1) * n, len(sections) * n)))], []
        end = cells[0] if isinstance(cells, list) else cells
        fc += [end, end]
        for s in range(len(sections) - 1):
            for i in range(n):
                faces.append((s * n + i, s * n + (i + 1) % n, (s + 1) * n + (i + 1) % n, (s + 1) * n + i))
                fc.append(cells[i] if isinstance(cells, list) else cells)
        self._emit(self.stack[-1], vs, faces, fc)

    def ring(self, x0, ln, r0, r1, cell, y=0.0, z=0.0, n=28):
        """A fat collar round the X axis at (y, z), from x0 going +X."""
        b = min(0.08, ln * 0.2, (r1 - r0) * 0.2)
        self.lathe([(r0, 0), (r1 - b, 0), (r1, b), (r1, ln - b), (r1 - b, ln), (r0, ln), (r0, 0)], n, cell, (x0, y, z), (0, 0, -90))

    def along(self, x0, x1, r, cell, y=0.0, z=0.0, n=28):
        self.cyl(r, abs(x1 - x0), ((x0 + x1) / 2, y, z), cell, (0, 0, -90), n=n)

    def flame(self, x, y, z, r, ln, n=14):
        """A stacked cartoon flame blowing aft (-X): warm core at the nozzle, yellow, orange tip, scalloped so it never reads as a beam."""
        pts = [(0, -0.2), (r * 0.6, -0.2), (r * 0.95, 0.14 * ln), (r * 0.72, 0.3 * ln), (r * 0.85, 0.36 * ln), (r * 0.56, 0.58 * ln),
               (r * 0.68, 0.62 * ln), (r * 0.36, 0.84 * ln), (0, ln)]
        cells = [FLAME_W, FLAME_W, FLAME_W, FLAME_Y, FLAME_Y, FLAME_O, FLAME_O, FLAME_O]
        self.lathe(pts, n, cells, (x, y, z), (0, 0, 90))

    def rim_window(self, x, y, s, r, rocket_r=None):
        """A cartoon porthole on a side at z = s * rocket_r."""
        rr = rocket_r
        self.torus(r, max(0.2, r * 0.24), (x, y, s * rr), SEAT, n=12, m_=4)
        self.cyl(r, 0.7, (x, y, s * (rr - 0.3)), GLASS, (90, 0, 0), n=12)


def material():
    return base.material("M_UpgRocket_Palette")


stud_grid = base.stud_grid
R = math.pi / 180
Vec = Vector
