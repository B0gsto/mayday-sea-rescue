"""Shared low-poly kit in the M_Chr_Bosun_LP style: bevelled boxes, low-segment balls, flat shading and a
per-face swatch atlas (each face samples one small swatch; a zone is a top-lit colour gradient).

Used by M_Pet_Puffin, M_Pet_Gull and M_Prop_SeaChest. Parts are authored in Blender part-local studs
(X = Roblox -X, Y = Roblox Z with the front at -Y, Z up), placed at their Roblox rest CFrame, validated as
one assembled asset, then re-origined so every FBX node sits at its part's rest frame (Bosun's approach).
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

D = math.radians
_M3 = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))     # Roblox <-> Blender axes (its own inverse)
SIZE = 1024


def cf(pos, rx=0.0, ry=0.0, rz=0.0):
    """Roblox CFrame.new(pos) * CFrame.Angles(rx, ry, rz) as a Blender matrix (bx = -x, by = z, bz = y)."""
    r = Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rz, 3, "Z")
    return Matrix.Translation((-pos[0], pos[2], pos[1])) @ (_M3 @ r @ _M3).to_4x4()


# ---------------------------------------------------------------- primitives (each returns a new bmesh)

def _place(bm, centre=(0, 0, 0), rot=None, warp=None):
    if warp:
        for v in bm.verts:
            v.co = Vector(warp(v.co.copy()))
    if rot:
        for angle, axis in rot:
            bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(D(angle), 3, axis))
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    return bm


def box(size, centre=(0, 0, 0), bevel=0.05, seg=1, taper=None, rot=None, warp=None):
    """Bevelled box. taper = (axis, neg, pos): the cross-section scales by neg / pos toward each end."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if taper:
        ai = "xyz".index(taper[0])
        half = size[ai] * 0.5
        for v in bm.verts:
            t = max(-1.0, min(1.0, v.co[ai] / half))
            f = 1.0 + ((taper[1] if t < 0 else taper[2]) - 1.0) * abs(t)
            for a in range(3):
                if a != ai:
                    v.co[a] *= f
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, offset_type="OFFSET", segments=seg,
                        profile=0.5, affect="EDGES", clamp_overlap=True)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)   # clamped bevels on thin tapers
    return _place(bm, centre, rot, warp)


def ball(size, centre=(0, 0, 0), u=10, v=6, rot=None, warp=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=0.5)
    for vert in bm.verts:
        vert.co = Vector((vert.co.x * size[0], vert.co.y * size[1], vert.co.z * size[2]))
    return _place(bm, centre, rot, warp)


def cyl(radius, depth, centre=(0, 0, 0), sides=8, rot=None, r2=None):
    """Cylinder (or cone with r2) along local Z."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius,
                          radius2=radius if r2 is None else r2, depth=depth)
    return _place(bm, centre, rot)


def tube(points, radius, sides=6):
    """Open-ended faceted tube along a polyline (rope); ends sit inside knots."""
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        n1 = t.cross(a).normalized()
        n2 = t.cross(n1).normalized()
        rings.append([bm.verts.new(p + radius * (math.cos(2 * math.pi * k / sides) * n1 + math.sin(2 * math.pi * k / sides) * n2))
                      for k in range(sides)])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((r0[k], r0[(k + 1) % sides], r1[(k + 1) % sides], r1[k]))
    return bm


def mirror_x(bm):
    """Mirror a finished part across its local X (left <-> right), keeping faces outward."""
    for v in bm.verts:
        v.co.x = -v.co.x
    bmesh.ops.reverse_faces(bm, faces=list(bm.faces))


# ---------------------------------------------------------------- one segmented part

class Part:
    """Collects primitives with a zone per face (zones follow face order; from_mesh appends)."""

    def __init__(self):
        self.bm = bmesh.new()
        self.zones = []

    def add(self, src, zone):
        n = len(self.bm.faces)
        me = bpy.data.meshes.new("_lp")
        src.to_mesh(me)
        src.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        self.zones += [zone] * (len(self.bm.faces) - n)
        return self


# ---------------------------------------------------------------- swatch atlas

def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


def cells(zones):
    """zone -> (u0, u1, v0, v1) in an N x N grid, in declaration order."""
    n = math.ceil(math.sqrt(len(zones)))
    out = {}
    for i, z in enumerate(zones):
        cx, cy = i % n, i // n
        out[z] = (cx / n, (cx + 1) / n, 1.0 - (cy + 1) / n, 1.0 - cy / n)
    return out


def write_maps(tex_dir, src_dir, tex, set_name, zones, size=SIZE, seed=5):
    """zones: name -> dict(top, bottom, rough, metal, signal). Writes T_<tex>_<set>_ALB/NOR/RGH/MET and the
    signal mask (saturated zones) next to the build file for check_textures."""
    rng = np.random.default_rng(seed)
    first = next(iter(zones.values()))
    alb = np.empty((size, size, 3), np.float32)
    alb[:] = _hex(first["top"])
    rgh = np.full((size, size), first.get("rough", 0.8), np.float32)
    met = np.zeros((size, size), np.float32)
    sig = np.full((size, size), 1.0 if first.get("signal") else 0.0, np.float32)
    for z, (u0, u1, v0, v1) in cells(zones).items():
        d = zones[z]
        x0, x1, y0, y1 = int(u0 * size), int(u1 * size), int((1 - v1) * size), int((1 - v0) * size)
        t = np.linspace(0, 1, y1 - y0, dtype=np.float32)[:, None, None]
        col = _hex(d["top"]) * (1 - t) + _hex(d.get("bottom") or d["top"]) * t
        col = np.repeat(col, x1 - x0, axis=1) + rng.normal(0, 0.008, (y1 - y0, x1 - x0, 3)).astype(np.float32)
        alb[y0:y1, x0:x1] = np.clip(col, 0.09, 0.93)      # check_textures luma 20..240
        rgh[y0:y1, x0:x1] = d.get("rough", 0.8) + rng.normal(0, 0.015, (y1 - y0, x1 - x0)).astype(np.float32)
        met[y0:y1, x0:x1] = d.get("metal", 0.0)
        sig[y0:y1, x0:x1] = 1.0 if d.get("signal") else 0.0
    nor = np.empty((size, size, 3), np.float32)
    nor[..., :2] = 0.5 + rng.normal(0, 0.005, (size, size, 2)).astype(np.float32)
    nor[..., 2] = 1.0
    paths = {}
    for kind, arr in (("ALB", alb), ("NOR", np.clip(nor, 0, 1)), ("RGH", np.clip(rgh, 0, 1)), ("MET", met)):
        paths[kind] = os.path.join(tex_dir, "T_%s_%s_%s.png" % (tex, set_name, kind))
        pbrmaps.write_png(paths[kind], arr)
    pbrmaps.write_png(os.path.join(src_dir, "T_%s_%s_signal.png" % (tex, set_name)), sig)
    return paths


def material(name, paths):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    for kind, cs, socket in (("ALB", "sRGB", "Base Color"), ("NOR", "Non-Color", None),
                             ("RGH", "Non-Color", "Roughness"), ("MET", "Non-Color", "Metallic")):
        img = bpy.data.images.load(paths[kind], check_existing=True)
        img.colorspace_settings.name = cs
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        if socket:
            nt.links.new(node.outputs["Color"], bsdf.inputs[socket])
        else:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(node.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def _assign_uv(bm, zones, face_zones, refine, rng):
    uv = bm.loops.layers.uv.new("UVMap")
    grid = cells(zones)
    s = 0.004
    for f, zone in zip(bm.faces, face_zones):
        f.normal_update()
        if refine:
            zone = refine(zone, f.calc_center_median(), f.normal)
        u0, u1, v0, v1 = grid[zone]
        up = max(0.0, min(1.0, (f.normal.z + 1.0) * 0.5))
        u = rng.uniform(u0 + 0.1 * (u1 - u0), u1 - 0.1 * (u1 - u0) - s)
        v = v0 + (0.06 + 0.86 * up) * (v1 - v0)
        for i, loop in enumerate(f.loops):
            a, b = ((0, 0), (s, 0), (s, s), (0, s))[min(i, 3)]
            loop[uv].uv = (u + a, v + b)


# ---------------------------------------------------------------- the asset

def build_asset(asset, prefix, tex, set_name, zones, parts, src_dir, budget="small_prop", origin="free",
                attachments=None, extra_mapping=None, fbx_name=None):
    """parts: [dict(node, part, index, cframe (Blender matrix), roblox (pos, angles), make(Part), refine)].
    Returns the run.py spec; the mapping JSON and part re-origin happen after validate (extra check)."""
    for ob in list(bpy.data.objects):
        if ob.name.startswith(prefix) or ob.name.startswith("ATT_"):
            bpy.data.objects.remove(ob, do_unlink=True)
    paths = write_maps(common.textures_dir(asset), src_dir, tex, set_name, zones)
    mat = material(prefix + "Mat", paths)
    rng = random.Random(11)
    meshes, rest = [], {}
    for p in parts:
        pt = Part()
        p["make"](pt)
        bm = pt.bm
        bm.faces.ensure_lookup_table()
        _assign_uv(bm, zones, pt.zones, p.get("refine"), rng)
        bmesh.ops.transform(bm, matrix=p["cframe"], verts=bm.verts)
        name = prefix + p["node"]
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for poly in me.polygons:
            poly.use_smooth = False
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        meshes.append({"object": ob, "role": "visual", "lod": "LOD0"})
        rest[name] = p
    pts = [e["object"].matrix_world @ v.co for e in meshes for v in e["object"].data.vertices]
    lo = [min(q[i] for q in pts) for i in range(3)]
    hi = [max(q[i] for q in pts) for i in range(3)]
    dims_m = tuple(round((hi[i] - lo[i]) / common.STUDS_PER_METRE, 3) for i in range(3))

    def repose(spec, report):
        """After validate: each node's origin and transform at its part rest frame; short Roblox part names."""
        if spec.get("_reposed"):
            return
        rows = []
        for e in spec["meshes"]:
            if e.get("role") != "visual":
                continue
            ob = e["object"]
            base = names.mesh_base(ob.name)
            p = rest[base]
            ob.data.transform(p["cframe"].inverted())
            ob.matrix_world = p["cframe"]
            short = base[len(prefix):]
            ob.name = ob.data.name = short + ob.name[len(base):]
            if e.get("lod") == "LOD0":
                xs = [v.co for v in ob.data.vertices]
                ext = [max(c[i] for c in xs) - min(c[i] for c in xs) for i in range(3)]
                rows.append({"node": short, "part": p["part"], "index": p.get("index"),
                             "position": [round(v, 4) for v in p["roblox"][0]],
                             "angles": [round(v, 4) for v in p["roblox"][1]],
                             "mesh_size": [round(ext[0], 3), round(ext[2], 3), round(ext[1], 3)]})
        out = {"asset": asset, "axes": "Roblox rig-local studs, front -Z unless noted, up +Y; FBX via rbxkit "
                                       "(roblox = (-bx, bz, by)); each FBX node origin = its part rest CFrame "
                                       "(CFrame.new(position) * CFrame.Angles(angles))",
               "texture": "T_%s_%s_<ALB|NOR|RGH|MET>.png, 1024, one swatch atlas" % (tex, set_name),
               "parts": rows}
        out.update(extra_mapping or {})
        with open(os.path.join(common.out_root(), asset + ".mapping.json"), "w") as f:
            json.dump(out, f, indent=1)
        spec["_reposed"] = True
        report.add(asset, "part pivots", True, "%d MeshParts re-origined at their rest CFrames" % len(rows))

    return {
        "name": fbx_name or asset,      # FBX stem; must pass names.py (no "Pet" category)
        "asset": asset,
        "budget": budget,
        "tier": "standard",
        "dims_m": dims_m,
        "origin": origin,
        "sets": [{"name": tex, "set": set_name, "size": SIZE, "wet": False}],
        "atlas": None,
        "meshes": meshes,
        "attachments": attachments or [],
        "extra_checks": [repose],
        "waivers": {
            "texel density": "swatch atlas: per-face palette zones, form from faceted low-poly geometry (Bosun LP)",
            "LOD UV layout": "per-face swatches; collapsed LOD faces shift UV bounds (Bosun LP)",
        },
    }
