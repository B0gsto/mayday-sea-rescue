"""Toy-brick mesh kit for the Lifeboat stage's upgrade pieces (flat palette atlas, one material, one mesh per piece).

Everything is authored in the hull frame (studs, Roblox axes, same numbers as Boat/Builder.luau buildLifeboat and the
concept): +X starboard, +Y up, -Z bow. to_object() turns that into Blender axes (bx, by, bz) = (-x, z, y), which the
export turns back (roblox = (-bx, bz, by)), so a piece's pivot is the hull origin.

Palette: art/source/vessels/_UpgLifeboat/maketex.py writes the maps (run it once with system python3).
"""
import math
import os

from mathutils import Euler, Matrix, Vector

R = math.pi / 180
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
TEX_DIR = os.path.join(GAME, "build/prod/_UpgLifeboat/textures")
SET_NAME, SET = "UpgLifeboat", "Palette"

# cell -> (rgb, roughness, metal): concept colours (art/source/vessels/_UpgLifeboat/maketex.py reads this table)
PALETTE = [
    ("F0F0EC", 0.30, 0.0),   # 0 white
    ("B2B8BE", 0.28, 0.85),  # 1 steel
    ("2D3036", 0.45, 0.0),   # 2 dark
    ("16304E", 0.30, 0.0),   # 3 navy (the hull's NAVY)
    ("D7262E", 0.30, 0.0),   # 4 red
    ("FF6600", 0.30, 0.0),   # 5 orange (the hull's ORANGE)
    ("FFC72C", 0.30, 0.0),   # 6 yellow
    ("92989C", 0.40, 0.0),   # 7 deck grey
    ("2BB24C", 0.25, 0.0),   # 8 green
    ("E4E8EC", 0.10, 1.0),   # 9 chrome
    ("6E7278", 0.40, 0.0),   # 10 grey
    ("FFEDBE", 0.10, 0.0),   # 11 warm lens
    ("286EFF", 0.15, 0.0),   # 12 beacon blue
    ("FF8F1C", 0.40, 0.0),   # 13 amber / flame orange
    ("1A2A38", 0.06, 0.0),   # 14 dark glass
    ("FF6600", 0.62, 0.0),   # 15 orange rubber
]
GRID = 4
WHITE, STEEL, DARK, NAVY, RED, ORANGE, YELLOW, DECK, GREEN, CHROME, GREY, LENS, BEACON, AMBER, GLASS, RUBBER = range(16)

# the real hull (Builder.luau buildLifeboat): straight panels between these stations, not the concept's spline
ST = [(25.1, 3.3, 8.0, 8.55), (19.0, 3.4, 8.1, 8.6), (8.0, 3.5, 8.1, 8.6), (-4.0, 3.5, 8.05, 8.55),
      (-13.0, 3.0, 7.5, 8.1), (-18.5, 2.0, 6.0, 6.7), (-22.5, 1.0, 3.4, 4.2), (-25.0, 0.35, 0.85, 1.15)]
KEEL_Y, CHINE_Y, SHEER_Y = -2.8, 0.9, 3.15


def station(z):
    if z >= ST[0][0]:
        return ST[0][1:]
    for a, b in zip(ST, ST[1:]):
        if a[0] >= z >= b[0]:
            t = (a[0] - z) / (a[0] - b[0])
            return tuple(a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
    return ST[-1][1:]


def hull_x(z, y):
    keel, chine, sheer = station(z)
    if y <= CHINE_Y:
        return keel + (chine - keel) * (y - KEEL_Y) / (CHINE_Y - KEEL_Y)
    if y <= SHEER_Y:
        return chine + (sheer - chine) * (y - CHINE_Y) / (SHEER_Y - CHINE_Y)
    return sheer


def hull_y(x, z):
    keel, chine, _ = station(z)
    return KEEL_Y if x <= keel else KEEL_Y + (x - keel) / (chine - keel) * (CHINE_Y - KEEL_Y)


def rot_m(rot):
    # mathutils order "ZYX" is Rx @ Ry @ Rz: the same result as three.js and the concept's "XYZ"
    return Matrix.Identity(4) if not rot else Euler((rot[0] * R, rot[1] * R, rot[2] * R), "ZYX").to_matrix().to_4x4()


class Kit:
    def __init__(self):
        self.v, self.f = [], []
        self.stack = [Matrix.Identity(4)]
        self.atts = {}

    # ---------------------------------------------------------------- frames
    def at(self, pos, rot, fn):
        self.stack.append(self.stack[-1] @ Matrix.Translation(pos) @ rot_m(rot))
        fn()
        self.stack.pop()

    def att(self, name, pos):
        self.atts["ATT_" + name] = tuple(self.stack[-1] @ Vector(pos))

    def _emit(self, m, verts, faces, cell):
        base = len(self.v)
        self.v.extend(tuple(m @ Vector(p)) for p in verts)
        for i, face in enumerate(faces):
            c = cell[i] if isinstance(cell, list) else cell
            self.f.append((tuple(base + k for k in face), c))

    def _m(self, pos, rot, scale=None):
        m = self.stack[-1] @ Matrix.Translation(pos or (0, 0, 0)) @ rot_m(rot)
        if scale:
            m = m @ Matrix.Diagonal((*scale, 1))
        return m

    # ---------------------------------------------------------------- boxes
    def box(self, s, pos, cell, rot=None, r=None, studs=None, stud_cell=None, big=False):
        """Chamfered box (flat facets, no bevel at all under 0.05). studs: True, 'border' or a list of local spots."""
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        b = min(0.14, min(s) * 0.25) if r is None else min(r, min(s) * 0.4)
        m = self._m(pos, rot)
        if b < 0.05:
            vs = [(sx * hx, sy * hy, sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
            self._emit(m, vs, [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)], cell)
        else:
            vs, idx = [], {}
            for sx in (-1, 1):
                for sy in (-1, 1):
                    for sz in (-1, 1):
                        for axis in range(3):
                            p = [sx * (hx - b), sy * (hy - b), sz * (hz - b)]
                            p[axis] = (sx, sy, sz)[axis] * (hx, hy, hz)[axis]
                            idx[(sx, sy, sz, axis)] = len(vs)
                            vs.append(tuple(p))
            faces = []
            sg = (-1, 1)
            for sx in sg:                                       # the six big faces
                faces.append(tuple(idx[(sx, a, c, 0)] for a, c in ((-1, -1), (1, -1), (1, 1), (-1, 1))))
            for sy in sg:
                faces.append(tuple(idx[(a, sy, c, 1)] for a, c in ((-1, -1), (1, -1), (1, 1), (-1, 1))))
            for sz in sg:
                faces.append(tuple(idx[(a, c, sz, 2)] for a, c in ((-1, -1), (1, -1), (1, 1), (-1, 1))))
            for a in sg:                                        # the twelve chamfers
                for c in sg:
                    faces.append((idx[(-1, a, c, 1)], idx[(1, a, c, 1)], idx[(1, a, c, 2)], idx[(-1, a, c, 2)]))
                    faces.append((idx[(a, -1, c, 0)], idx[(a, 1, c, 0)], idx[(a, 1, c, 2)], idx[(a, -1, c, 2)]))
                    faces.append((idx[(a, c, -1, 0)], idx[(a, c, 1, 0)], idx[(a, c, 1, 1)], idx[(a, c, -1, 1)]))
            for sx in sg:                                       # the eight corners
                for sy in sg:
                    for sz in sg:
                        faces.append((idx[(sx, sy, sz, 0)], idx[(sx, sy, sz, 1)], idx[(sx, sy, sz, 2)]))
            self._emit(m, vs, faces, cell)
        if studs:
            spots = studs if isinstance(studs, list) else stud_grid(s, studs)
            for i, p in enumerate(spots):
                c = stud_cell[i % len(stud_cell)] if isinstance(stud_cell, list) else (cell if stud_cell is None else stud_cell)
                self.stud(m, p, c, big=big or studs in ("big", "bigborder"))

    def brick(self, s, pos, cell, rot=None, studs=True, r=None, stud_cell=None, big=False):
        self.box(s, pos, cell, rot, r, studs, stud_cell, big)

    def stud(self, m, p, cell, n=8, big=False):
        """Concept stud 0.72 across, 0.28 tall; big: 1.3 across, 0.45 tall, so it reads on a phone. No bottom cap, starts inside the brick top."""
        x, y, z = p
        r, h = (0.65, 0.45) if big else (0.36, 0.28)
        n = 10 if big else n
        ring = [(x + r * math.cos(2 * math.pi * i / n), y, z + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
        top = [(a, y + h, c) for a, _, c in ring]
        faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)] + [tuple(range(n, 2 * n))]
        self._emit(m, ring + top, faces, cell)

    # ---------------------------------------------------------------- round things (axis local +Y, like three.js lathes)
    def lathe(self, pts, n, cell, pos=None, rot=None, scale=None):
        """Profile (r, y) round +Y. r 0 at an end closes it with a fan. cell: one cell or one per profile segment."""
        m = self._m(pos, rot, scale)
        vs, faces, cells = [], [], []
        rings = []
        for r_, y in pts:
            if r_ <= 1e-5:
                rings.append([len(vs)])
                vs.append((0.0, y, 0.0))
            else:
                rings.append(list(range(len(vs), len(vs) + n)))
                vs.extend((r_ * math.cos(2 * math.pi * i / n), y, r_ * math.sin(2 * math.pi * i / n)) for i in range(n))
        for k, (a, b) in enumerate(zip(rings, rings[1:])):
            seg_cell = cell[k] if isinstance(cell, (list, tuple)) else cell
            for i in range(n):
                if len(a) == 1:
                    faces.append((a[0], b[(i + 1) % n], b[i]))
                elif len(b) == 1:
                    faces.append((a[i], a[(i + 1) % n], b[0]))
                else:
                    faces.append((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
                cells.append(seg_cell)
        self._emit(m, vs, faces, cells)

    def cyl(self, r, length, pos, cell, rot=None, r2=None, n=16, studs=None):
        r2 = r if r2 is None else r2
        h = length / 2
        b = min(0.12, r * 0.25, r2 * 0.25 + 0.001, length * 0.25)
        self.lathe([(0, -h), (r - b, -h), (r, -h + b), (r2, h - b), (max(0, r2 - b), h), (0, h)], n, cell, pos, rot)
        if studs:
            m = self._m(pos, rot)
            for p in studs:
                self.stud(m, p, cell)

    def cone(self, r, length, pos, cell, rot=None, tip=0.2, n=16, base_b=0.12):
        h = length / 2
        b = min(base_b, r * 0.2, length * 0.2)
        pts = [(0, -h), (r - b, -h), (r, -h + b)]
        for k in range(4):
            a = k / 3 * math.pi / 2
            pts.append((tip * math.cos(a), h - tip + tip * math.sin(a)))
        pts[-1] = (0, h)
        self.lathe(pts, n, cell, pos, rot)

    def sphere(self, r, pos, cell, scale=None, half=False, n=12, lat=5):
        a0 = 0.0 if half else -math.pi / 2
        pts = [(r * math.cos(a0 + (math.pi / 2 - a0) * k / lat), r * math.sin(a0 + (math.pi / 2 - a0) * k / lat)) for k in range(lat + 1)]
        if half:
            pts = [(0, 0)] + pts
        else:
            pts[0] = (0, -r)
        pts[-1] = (0, r)
        self.lathe(pts, n, cell, pos, None, scale)

    def dome_z(self, r, pos, cell, sz, face=-1, n=14, lat=4):
        """Half-round cap along local Z (face -1: bulges to -Z). sz: how far it bulges as a share of r."""
        self.at(pos, (face * 90, 0, 0), lambda: self.sphere(r, (0, 0, 0), cell, (1, sz, 1), True, n, lat))

    def torus(self, big, t, pos, cell, rot=None, n=16, m_=6):
        """Ring in the local XY plane (axis Z), like THREE.TorusGeometry."""
        m = self._m(pos, rot)
        vs, faces = [], []
        for i in range(n):
            u = 2 * math.pi * i / n
            for j in range(m_):
                w = 2 * math.pi * j / m_
                vs.append(((big + t * math.cos(w)) * math.cos(u), (big + t * math.cos(w)) * math.sin(u), t * math.sin(w)))
        for i in range(n):
            for j in range(m_):
                a, b = i * m_, ((i + 1) % n) * m_
                k = (j + 1) % m_
                faces.append((a + j, b + j, b + k, a + k))
        self._emit(m, vs, faces, cell)

    def capsule(self, r, length, pos, cell, rot=None, n=12, lat=3):
        pts = [(0, -length / 2 - r)]
        for k in range(1, lat + 1):
            a = -math.pi / 2 + k / lat * math.pi / 2
            pts.append((r * math.cos(a), -length / 2 + r * math.sin(a)))
        for k in range(0, lat):
            a = k / lat * math.pi / 2
            pts.append((r * math.cos(a), length / 2 + r * math.sin(a)))
        pts.append((0, length / 2 + r))
        self.lathe(pts, n, cell, pos, rot)

    def rod(self, a, b, r, cell, n=8):
        a, b = Vector(a), Vector(b)
        d = b - a
        m = self.stack[-1] @ Matrix.Translation((a + b) / 2) @ Vector((0, 1, 0)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        h = d.length / 2
        self.stack.append(m)
        self.lathe([(0, -h), (r, -h), (r, h), (0, h)], n, cell)
        self.stack.pop()

    # ---------------------------------------------------------------- prisms and flags
    def prism(self, poly, d0, d1, cell, to3, bevel=0.0):
        """A closed 2D polygon extruded from d0 to d1. to3(a, b, d) places a polygon point. bevel: mitred inset at both ends."""
        rings = [(inset(poly, bevel), d0), (poly, d0 + bevel), (poly, d1 - bevel), (inset(poly, bevel), d1)] if bevel else [(poly, d0), (poly, d1)]
        n = len(poly)
        vs = [to3(a, b, d) for pts, d in rings for a, b in pts]
        faces = [tuple(range(n)), tuple(reversed(range((len(rings) - 1) * n, len(rings) * n)))]
        for s in range(len(rings) - 1):
            faces += [(s * n + i, s * n + (i + 1) % n, (s + 1) * n + (i + 1) % n, (s + 1) * n + i) for i in range(n)]
        self._emit(self.stack[-1], vs, faces, cell)

    def flag(self, x, y0, z, w, h, cell, tri=False, half=0, thick=0.05, seg=6):
        """A waving flag, a thin closed ribbon flying aft (+Z) from a pole at (x, y0, z). half: +1 top band, -1 bottom band."""
        sections = []
        for i in range(seg + 1):
            t = i / seg
            hi = h / 2 * (1 - t * 0.92 if tri else 1)
            a, b = -hi, hi
            if half:
                a, b = a / 2 + half * h / 4, b / 2 + half * h / 4
            bend = math.sin(t * 5.2) * 0.32 * t
            sections.append([(x + bend - thick, y0 + a, z + t * w), (x + bend + thick, y0 + a, z + t * w),
                             (x + bend + thick, y0 + b, z + t * w), (x + bend - thick, y0 + b, z + t * w)])
        vs = [p for s in sections for p in s]
        faces = [(0, 1, 2, 3), tuple(reversed(range(4 * seg, 4 * seg + 4)))]
        for s in range(seg):
            faces += [(s * 4 + i, s * 4 + (i + 1) % 4, (s + 1) * 4 + (i + 1) % 4, (s + 1) * 4 + i) for i in range(4)]
        self._emit(self.stack[-1], vs, faces, cell)

    # ---------------------------------------------------------------- output
    def tris(self):
        return sum(len(f) - 2 for f, _ in self.f)

    def to_object(self, name, material):
        import bmesh
        import bpy
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([(-x, z, y) for x, y, z in self.v], [], [f for f, _ in self.f])
        mesh.update()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        uv = mesh.uv_layers.new(name="UVMap")
        for poly, (_, c) in zip(mesh.polygons, self.f):
            col, row = c % GRID, c // GRID
            u0, u1, v0, v1 = (col + 0.1) / GRID, (col + 0.9) / GRID, (row + 0.1) / GRID, (row + 0.9) / GRID
            k = poly.loop_total
            for i, li in enumerate(poly.loop_indices):      # a small ring inside the cell: colour never bleeds
                uv.data[li].uv = ((u0 + u1) / 2 + (u1 - u0) / 2 * math.cos(2 * math.pi * i / k),
                                  (v0 + v1) / 2 + (v1 - v0) / 2 * math.sin(2 * math.pi * i / k))
            poly.use_smooth = True
        mesh.set_sharp_from_angle(angle=math.radians(32))   # chamfers stay crisp facets, 12+ sided rounds stay smooth
        mesh.materials.append(material)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def stud_grid(s, mode):
    """Local stud spots on a brick top: every spot or the border ring, at 1 stud pitch; big or bigborder at 2.4 pitch."""
    pitch = 2.4 if mode in ("big", "bigborder") else 1.0
    nx, nz = max(1, int(s[0] / pitch + 1e-6)), max(1, int(s[2] / pitch + 1e-6))
    out = []
    for i in range(nx):
        for j in range(nz):
            if mode in ("border", "bigborder") and not (i in (0, nx - 1) or j in (0, nz - 1)):
                continue
            out.append(((i - (nx - 1) / 2) * pitch, s[1] / 2 - 0.02, (j - (nz - 1) / 2) * pitch))
    return out


def inset(poly, d):
    """The polygon moved inward by d, mitred (works for the chevron wings and the blade section)."""
    n = len(poly)
    area = sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))
    sign = 1 if area > 0 else -1
    out = []
    for i in range(n):
        ax, ay = poly[i - 1]
        bx, by = poly[i]
        cx, cy = poly[(i + 1) % n]
        e1, e2 = (bx - ax, by - ay), (cx - bx, cy - by)
        l1, l2 = math.hypot(*e1), math.hypot(*e2)
        n1, n2 = (-e1[1] / l1 * sign, e1[0] / l1 * sign), (-e2[1] / l2 * sign, e2[0] / l2 * sign)
        mx, my = n1[0] + n2[0], n1[1] + n2[1]
        ml = max(math.hypot(mx, my), 1e-5)
        k = d / max(0.35, (mx * n1[0] + my * n1[1]) / ml) / ml
        out.append((bx + mx * k, by + my * k))
    return out


def material(name=None):
    """The one palette material with the set's ALB, RGH and MET."""
    import bpy
    name = name or "M_UpgLifeboat_Palette"
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    stem = os.path.join(TEX_DIR, "T_%s_%s_" % (SET_NAME, SET))
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    for kind, socket, cs in (("ALB", "Base Color", "sRGB"), ("RGH", "Roughness", "Non-Color"), ("MET", "Metallic", "Non-Color")):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(stem + kind + ".png", check_existing=True)
        tex.image.colorspace_settings.name = cs
        nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        nt.links.new(tex.outputs["Color"], bsdf.inputs[socket])
    return mat
