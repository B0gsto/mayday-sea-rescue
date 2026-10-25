"""Shared kit for the low-poly pets (M_Pet_SealPup, M_Pet_Otter, M_Pet_Turtle), Bosun-LP style.

Each pet is one faceted mesh per WildlifeRig part (src/shared/Config/Wildlife.luau, same order). A shape is
authored in its part's own Roblox frame (studs, y up, front -Z, x = the animal's right), then placed at the
part's `at` CFrame. Faces are UV'd onto flat colour swatches of one 1024 atlas (Bosun coattex style: a subtle
top-lighter gradient per zone, form from the geometry). After validate every node is re-origined at its part
CFrame and renamed to its short node name, so the FBX nodes carry the rig layout.

Names: `M_Pet` is not a names.CATEGORIES category, so the meshes and FBX files use `M_Ani_<Pet>`; the asset
folders stay `M_Pet_<Pet>`.
"""
import json
import math
import os
import random

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import common
import names
import pbrmaps

M3 = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))     # Roblox (x, y, z) <-> Blender (-x, z, y); its own inverse
D = math.radians


def rb_rot(rx=0.0, ry=0.0, rz=0.0):
    """CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz, Roblox axes."""
    return Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rz, 3, "Z")


def cf(x, y, z, rx=0.0, ry=0.0, rz=0.0):
    """Roblox CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz) -> Blender 4x4 (part frame in Blender axes)."""
    return Matrix.Translation(M3 @ Vector((x, y, z))) @ (M3 @ rb_rot(rx, ry, rz) @ M3).to_4x4()


# ---------------------------------------------------------------- primitives (Roblox local axes)

def scale(bm, s):
    for v in bm.verts:
        v.co = Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))
    return bm


def move(bm, d):
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(d))
    return bm


def rotate(bm, rx=0.0, ry=0.0, rz=0.0, centre=(0, 0, 0)):
    bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector(centre), matrix=rb_rot(rx, ry, rz))
    return bm


def deform(bm, fn):
    for v in bm.verts:
        v.co = Vector(fn(v.co.copy()))
    return bm


def ellipsoid(size, centre=(0, 0, 0), u=12, v=6):
    """Low-segment UV sphere, poles on Y (up), filling `size`."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=0.5)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector(), matrix=Matrix.Rotation(D(90), 3, "X"))
    return move(scale(bm, size), centre)


def box(size, centre=(0, 0, 0), bevel=0.05, segments=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    scale(bm, size)
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, offset_type="OFFSET", segments=segments,
                        profile=0.5, affect="EDGES", clamp_overlap=True)
    return move(bm, centre)


def cone(r_base, r_tip, length, segments=8, centre=(0, 0, 0)):
    """Along +Z: base at -length/2, tip at +length/2."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=r_base,
                          radius2=max(r_tip, 0.005), depth=length)
    return move(bm, centre)


def lens(outline, thick, rings=((1.0, 0.0), (0.68, 0.85), (0.3, 1.0)), y=0.0):
    """A faceted paddle: a convex (x, z) outline at y, raised rings toward its centroid on both faces."""
    bm = bmesh.new()
    cx = sum(p[0] for p in outline) / len(outline)
    cz = sum(p[1] for p in outline) / len(outline)
    n = len(outline)
    top, bot = [], []
    for k, (s, h) in enumerate(rings):
        ring_t, ring_b = [], []
        for x, z in outline:
            px, pz = cx + (x - cx) * s, cz + (z - cz) * s
            vt = bm.verts.new((px, y + h * thick * 0.5, pz))
            ring_t.append(vt)
            ring_b.append(vt if k == 0 else bm.verts.new((px, y - h * thick * 0.5, pz)))
        top.append(ring_t)
        bot.append(ring_b)
    for rs in (top, bot):
        for k in range(len(rings) - 1):
            a, b = rs[k], rs[k + 1]
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((a[i], a[j], b[j], b[i]))
        bm.faces.new(rs[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def whisker(root, tip, w=0.022):
    """A thin square stick from root to tip."""
    root, tip = Vector(root), Vector(tip)
    d = tip - root
    bm = box((w, w, d.length), bevel=0)
    rot = d.to_track_quat("Z", "Y").to_matrix()
    bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector(), matrix=rot)
    return move(bm, (root + tip) * 0.5)


# ---------------------------------------------------------------- a part's shape: verts, faces, zone per face

class Shape:
    def __init__(self):
        self.verts, self.faces, self.zones = [], [], []

    def add(self, bm, zone):
        """zone: a zone name, or fn(face) -> name (face centre / normal in the part's Roblox frame)."""
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        bm.verts.index_update()
        base = len(self.verts)
        self.verts += [v.co.copy() for v in bm.verts]
        for f in bm.faces:
            self.faces.append([base + v.index for v in f.verts])
            self.zones.append(zone(f) if callable(zone) else zone)
        bm.free()
        return self


def by(rules, default):
    """zone fn from [(test(centre, normal) -> bool, zone)]; the first rule that passes wins."""
    def fn(f):
        c, n = f.calc_center_median(), f.normal
        for test, zone in rules:
            if test(c, n):
                return zone
        return default
    return fn


def speckle(rng, share, zone, default):
    return lambda f: zone if rng.random() < share else (default(f) if callable(default) else default)


# ---------------------------------------------------------------- atlas

GRID = 4
CELL = 1.0 / GRID
MARGIN = 0.12 * CELL


def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


def _cell(i):
    return (i % GRID) * CELL, (i // GRID) * CELL       # u0, v0


def write_atlas(out_dir, short, zones, rare=None, size=1024, seed=5):
    """zones: [(name, top hex, bottom hex, roughness, tint)]. Writes T_<short>_Coat_ALB/NOR/RGH/MET and, with
    rare = (ref hex, rare hex), T_<short>_Rare_ALB (tinted zones recoloured, luminance kept)."""
    os.makedirs(out_dir, exist_ok=True)
    rng = np.random.default_rng(seed)

    def albedo(recolour):
        alb = np.full((size, size, 3), 0.5, dtype=np.float32)
        for i, (_n, top, bottom, _r, tint) in enumerate(zones):
            u0, v0 = _cell(i)
            x0, x1 = int(u0 * size), int((u0 + CELL) * size)
            y0, y1 = int((1.0 - v0 - CELL) * size), int((1.0 - v0) * size)
            t = np.linspace(0.0, 1.0, y1 - y0, dtype=np.float32)[:, None, None]
            a, b = recolour(_hex(top), tint), recolour(_hex(bottom), tint)
            col = np.repeat(a[None, None, :] * (1 - t) + b[None, None, :] * t, x1 - x0, axis=1)
            col = col + np.random.default_rng(seed + i).normal(0.0, 0.008, col.shape).astype(np.float32)
            alb[y0:y1, x0:x1] = np.clip(col, 30 / 255.0, 240 / 255.0)
        return alb

    paths = {}
    alb = albedo(lambda c, tint: c)
    rgh = np.full((size, size), 0.8, dtype=np.float32)
    for i, z in enumerate(zones):
        u0, v0 = _cell(i)
        x0, x1 = int(u0 * size), int((u0 + CELL) * size)
        y0, y1 = int((1.0 - v0 - CELL) * size), int((1.0 - v0) * size)
        rgh[y0:y1, x0:x1] = z[3]
    rgh = np.clip(rgh + rng.normal(0.0, 0.015, rgh.shape).astype(np.float32), 0.0, 1.0)
    nor = np.zeros((size, size, 3), dtype=np.float32)
    nor[..., :2] = 0.5
    nor[..., 2] = 1.0
    for kind, arr in (("ALB", alb), ("NOR", nor), ("RGH", rgh), ("MET", np.zeros((size, size), np.float32))):
        paths[kind] = os.path.join(out_dir, "T_%s_Coat_%s.png" % (short, kind))
        pbrmaps.write_png(paths[kind], arr)
    if rare:
        ref, gold = _hex(rare[0]), _hex(rare[1])
        lum = lambda c: float(0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2])
        recolour = lambda c, tint: np.clip(gold * (lum(c) / lum(ref)), 0, 1) if tint else c
        pbrmaps.write_png(os.path.join(out_dir, "T_%s_Rare_ALB.png" % short), albedo(recolour))
    return paths


def material(asset, short, zones, rare):
    paths = write_atlas(common.textures_dir(asset), short, zones, rare)
    mat = bpy.data.materials.get(short + "_Coat") or bpy.data.materials.new(short + "_Coat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    for kind, socket, space in (("ALB", "Base Color", "sRGB"), ("RGH", "Roughness", "Non-Color"),
                                ("MET", "Metallic", "Non-Color")):
        img = bpy.data.images.load(paths[kind], check_existing=True)
        img.colorspace_settings.name = space
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        nt.links.new(node.outputs["Color"], bsdf.inputs[socket])
    return mat


# ---------------------------------------------------------------- build

def _uv(bm, zone_ids, rng):
    uv = bm.loops.layers.uv.new("UVMap")
    s = 0.004
    for f, zi in zip(bm.faces, zone_ids):
        u0, v0 = _cell(zi)
        up = max(0.0, min(1.0, (f.normal.z + 1.0) * 0.5))          # Blender world up
        u = rng.uniform(u0 + MARGIN, u0 + CELL - MARGIN - s)
        v = v0 + MARGIN + (CELL - 2 * MARGIN - s) * (0.05 + 0.9 * up)
        for i, loop in enumerate(f.loops):
            a, b = ((0, 0), (s, 0), (s, s), (0, s))[min(i, 3)]
            loop[uv].uv = (u + a, v + b)


def _mesh(name, shape, frame, zone_index, mat, rng):
    me = bpy.data.meshes.new(name)
    me.from_pydata([frame @ (M3 @ v) for v in shape.verts], [], shape.faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)       # M3 mirrors, so windings flip; closed pieces recover
    bm.normal_update()
    _uv(bm, [zone_index[z] for z in shape.zones], rng)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = False
    return ob


def build(asset, short, parts, zones, rare, closeups, waivers_extra=None, seed=3):
    """parts: [(node, rig_name, placeholder size (x, y, z), at = (x, y, z, rx, ry, rz), shape_fn)] in rig order."""
    prefix = "M_Ani_%s_" % short
    for ob in list(bpy.data.objects):
        if ob.name.startswith(prefix):
            bpy.data.objects.remove(ob, do_unlink=True)
    mat = material(asset, short, zones, rare)
    zone_index = {z[0]: i for i, z in enumerate(zones)}
    rng = random.Random(seed)
    rest, rows, meshes = {}, {}, []
    for idx, (node, rig, size, at, fn) in enumerate(parts, 1):
        shape = fn()
        lo = [min(v[i] for v in shape.verts) for i in range(3)]
        hi = [max(v[i] for v in shape.verts) for i in range(3)]
        frame = cf(*at)
        ob = _mesh(prefix + node, shape, frame, zone_index, mat, rng)
        rest[prefix + node] = frame
        meshes.append({"object": ob, "role": "visual", "lod": "LOD0"})
        r = rb_rot(*at[3:])
        rows[node] = {"rig_part": rig, "rig_index": idx, "placeholder_size": list(size),
                      "at": {"position": list(at[:3]), "matrix": [[round(r[i][j], 5) for j in range(3)] for i in range(3)]},
                      "size": [round(h - l, 4) for l, h in zip(lo, hi)],
                      "offset": [round((h + l) * 0.5, 4) for l, h in zip(lo, hi)]}
    pts = [e["object"].matrix_world @ v.co for e in meshes for v in e["object"].data.vertices]
    dims = [max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3)]
    _write_mapping(asset, short, rows)

    def repose(spec, report):
        """After validate: each node's origin at its part CFrame, renamed to its short node name."""
        if spec.get("_reposed"):
            return
        for e in spec["meshes"]:
            ob = e["object"]
            base = names.mesh_base(ob.name)
            frame = rest[base]
            ob.data.transform(frame.inverted())
            ob.matrix_world = frame
            ob.name = ob.data.name = base[len(prefix):] + ob.name[len(base):]
        spec["_reposed"] = True
        report.add(asset, "part pivots", True, "%d nodes re-origined at their WildlifeRig part CFrames" % len(parts))

    waivers = {
        "texture sets": "one 1024 swatch atlas for a small segmented low-poly pet (dog class asks 2 to 3)",
        "texel density": "swatch atlas: per-face palette zones, form from faceted geometry (Bosun LP)",
        "LOD UV layout": "per-face palette swatches; collapsed LOD faces shift UV bounds",
        "UV faces": "per-face swatch UVs are tiny squares; LOD collapse can leave one face with no UV area",
    }
    waivers.update(waivers_extra or {})
    return {
        "name": "M_Ani_" + short,
        "budget": "dog",
        "species": "animal",
        "tris": 3000,
        "tier": "standard",
        "dims_m": tuple(round(d / common.STUDS_PER_METRE, 3) for d in dims),
        "origin": "free",          # the WildlifeRig pivot: ground under the body, not the bbox base centre
        "sets": [{"name": short, "set": "Coat", "size": 1024, "wet": False}],
        "meshes": meshes,
        "attachments": [],
        "closeups": closeups,
        "extra_checks": [repose],
        "waivers": waivers,
    }


def _write_mapping(asset, short, rows):
    out = {
        "asset": asset,
        "source": "src/shared/Config/Wildlife.luau Species.%s.parts (WildlifeRig)" % short,
        "axes": "Roblox studs, rig pivot on the ground, front -Z; FBX via rbxkit (roblox = (-bx, bz, by))",
        "fbx": "fbx/%s/M_Ani_%s_LOD0.fbx (nodes named like the keys below; LOD1/LOD2 nodes add _LOD1/_LOD2)" % (asset, short),
        "swap": "rig_index is the part's position in Species.parts (duplicate rig names Eye/Glint/Flipper are split "
                "Left/Right). Each FBX node's origin is its part's `at` CFrame. A MeshPart's position is its mesh "
                "bounds centre: MeshPart.CFrame = rig pivot * at * CFrame.new(offset), Size = size (mesh bounds, studs). "
                "size differs from placeholder_size on purpose where the placeholder box was a stand-in.",
        "textures": {"set": "T_%s_Coat_<ALB|NOR|RGH|MET>.png" % short, "rare_albedo": "T_%s_Rare_ALB.png" % short,
                     "dir": "textures/%s" % asset},
        "parts": rows,
    }
    with open(os.path.join(common.out_root(), asset + ".mapping.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
