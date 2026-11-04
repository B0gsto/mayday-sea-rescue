"""Mesh helpers for the pirate set: lego.B (from M_Prop_PrizeWheel) plus a transform stack, per-face colours, printed
tiles. Local axes are whatever self.M maps to Blender studs; bow / front is Blender -Y (validate's front).

Blender's sys.modules outlive MCP calls: drop the shared names first, or a sibling asset's palette would stick.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
for _m in ("lego", "palette"):
    sys.modules.pop(_m, None)
for _p in (os.path.join(G, "art/source/props/M_Prop_PrizeWheel"), HERE):
    if _p in sys.path:
        sys.path.remove(_p)
    sys.path.insert(0, _p)
import lego  # noqa: E402
import palette as P  # noqa: E402

SET_NAME, SET = "PirateBoat", "Brick"
TEX_DIR = os.path.join(G, "build/prod/M_Veh_PirateBoat/textures/M_Veh_PirateBoat")
ALB = os.path.join(TEX_DIR, "T_PirateBoat_Brick_ALB.png")


class RB(lego.B):
    def __init__(self, M=None):
        import mathutils
        super().__init__()
        self.M = M if M is not None else mathutils.Matrix.Identity(4)
        self.tiles = {}                # face index -> {vertex index: uv}

    def at(self, N):
        """with b.at(matrix): local geometry goes through self.M @ matrix."""
        b = self

        class _Ctx:
            def __enter__(self):
                self.old = b.M
                b.M = b.M @ N

            def __exit__(self, *a):
                b.M = self.old
        return _Ctx()

    def _emit(self, verts, faces, c):
        import mathutils
        cs = list(c) if isinstance(c, (list, tuple)) else [c] * len(faces)
        base = len(self.v)
        self.v.extend(tuple(self.M @ mathutils.Vector(p)) for p in verts)
        for face, col in zip(faces, cs):
            self.f.append((tuple(base + i for i in face), col))

    def tile(self, face_index, rect, flip=False):
        """Print a tile on a quad whose vertices run bottom-left, bottom-right, top-right, top-left seen from outside."""
        u0, v0, u1, v1 = P.uv_rect(rect)
        if flip:
            u0, u1 = u1, u0
        self.uv_quad(face_index, ((u0, v0), (u1, v0), (u1, v1), (u0, v1)))

    def uv_quad(self, face_index, uvs):
        self.tiles[face_index] = dict(zip(self.f[face_index][0], uvs))

    def to_object(self, name, material, s=1.0):
        obj = super().to_object(name, material, s)
        mesh = obj.data
        uv = mesh.uv_layers["UVMap"]
        for fi, m in self.tiles.items():
            for li in mesh.polygons[fi].loop_indices:
                uv.data[li].uv = m[mesh.loops[li].vertex_index]
        return obj

    # ------------------------------------------------------------ shapes
    def lathe(self, cx, cy, prof, c, n=8, start=0.0):
        """Closed surface of revolution round Z; prof = [(r, z), ...]; r = 0 ends need no cap. c may be a list per span."""
        rings, verts = [], []
        for r, z in prof:
            if r <= 1e-6:
                rings.append([len(verts)])
                verts.append((cx, cy, z))
                continue
            rings.append(list(range(len(verts), len(verts) + n)))
            for i in range(n):
                a = start + 2 * math.pi * i / n
                verts.append((cx + r * math.cos(a), cy + r * math.sin(a), z))
        faces, cols = [], []
        for s in range(len(rings) - 1):
            col = c[s] if isinstance(c, (list, tuple)) else c
            A, B = rings[s], rings[s + 1]
            for i in range(n):
                j = (i + 1) % n
                if len(A) == 1:
                    faces.append((A[0], B[j], B[i]))
                elif len(B) == 1:
                    faces.append((A[i], A[j], B[0]))
                else:
                    faces.append((A[i], A[j], B[j], B[i]))
                cols.append(col)
        last = c[-1] if isinstance(c, (list, tuple)) else c
        if len(rings[0]) > 1:
            faces.append(tuple(reversed(rings[0])))
            cols.append(c[0] if isinstance(c, (list, tuple)) else c)
        if len(rings[-1]) > 1:
            faces.append(tuple(rings[-1]))
            cols.append(last)
        self._emit(verts, faces, cols)

    def rod(self, p0, p1, r, c, n=6):
        """A round bar between two points (rigging, poles, spokes)."""
        import mathutils
        p0, p1 = mathutils.Vector(p0), mathutils.Vector(p1)
        d = p1 - p0
        R = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        with self.at(mathutils.Matrix.Translation(p0) @ R):
            self.lathe(0, 0, [(r, 0), (r, d.length)], c, n)


def along(axis_from, pos=(0, 0, 0)):
    """Matrix taking local +Z to the given direction, at pos (discs and rings that face sideways)."""
    import mathutils
    R = mathutils.Vector(axis_from).to_track_quat("Z", "Y").to_matrix().to_4x4()
    return mathutils.Matrix.Translation(pos) @ R


def dims_of(meshes):
    pts = [e["object"].matrix_world @ v.co for e in meshes if e.get("role") != "col" for v in e["object"].data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    print("[pirate] bbox", [round(v, 2) for v in lo], [round(v, 2) for v in hi])
    return tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
