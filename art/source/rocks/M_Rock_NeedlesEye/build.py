"""M_Rock_NeedlesEye (K1, docs/12 2.6): The Needle's Eye, the granite sea arch over Old Ned's gully (WorldConfig
`GullyArch`, footprint 30 x 60 studs).

Round 5: one continuous jointed granite mass, not glued scan chunks. The arch is a signed distance field sampled on a
0.3-stud grid (numpy), meshed through OpenVDB (Volume to Mesh) and decimated:
  * the mass: a broad buttress fused into the headland (-X), a thick lintel, a narrower seaward leg (+X), battered
    flanks and a crest that steps down from the headland to the sea; a wave-cut platform just under the tide line;
  * the eye: sea-cut along the joints, roof a dipping sheeting joint (~37 studs), a stepped overhang over the
    headland-side undercut, a scoured seaward shoulder, flared at both mouths, widest at the tide line;
  * granite jointing: one sheeting (near-horizontal) and two vertical joint sets cut the mass into blocks; each block
    is set back by its own amount and tilt, so the surface breaks into blocky fracture faces, ledges and open joints;
  * the sea: a wave-cut notch round the whole rock at the tide line, deepest on the seaward leg, where the blocks are
    worn round;
  * fallen blocks (a second field, _Base_LOD0) rest on the platform at the feet, clear of the eye.
archtex.py bakes the _HP (geometry + CC0 Poly Haven rock_face / rock_boulder_dry scan relief, box projected in world
space, so texel density is uniform and nothing stretches) onto the LOD0 UVs; compose_maps.py grades and zones it.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
for p in (HERE, os.path.join(REPO, "tools/blender")):
    if p not in sys.path:
        sys.path.insert(0, p)
import arch as A  # noqa: E402
import common  # noqa: E402
import uvlayout  # noqa: E402
import versions  # noqa: E402

NAME = "M_Rock_NeedlesEye"
VOX = 0.3                          # SDF grid (studs)
ORIGIN = (-33.0, -18.0, -1.5)
DIMS = (221, 121, 207)
LOD0_TRIS = 9800                   # MeshPart limit 10,000 per part
BASE_TRIS = 2000
SET_SIZE = 4096
PLINTH = (29.0, 26.8)              # the wave-cut platform: the flanks step out below the tide line

# fallen blocks on the platform: centre, half size, yaw, tilt (studs, radians); none in front of the eye
BLOCKS = (((23.5, -12.6, 28.6), (2.6, 2.0, 2.3), 0.40, 0.25), ((28.0, -4.5, 28.4), (2.0, 2.6, 2.1), 1.10, -0.30),
          ((27.0, 7.5, 28.4), (1.8, 1.6, 1.7), 0.20, 0.40), ((-20.0, -13.0, 28.6), (3.0, 2.0, 2.2), -0.30, 0.15),
          ((-13.0, -13.6, 28.3), (1.8, 1.5, 1.7), 0.90, -0.35), ((-27.6, -9.0, 28.4), (1.5, 2.0, 1.8), 0.60, 0.20),
          ((20.5, 12.4, 28.5), (2.0, 1.8, 1.8), -0.50, 0.30))


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def smax(a, b, k):
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.maximum(a, b) + h * h * k * 0.25


def tab(pairs, x):
    xs, ys = zip(*pairs)
    return np.interp(x, xs, ys).astype(np.float32)


class Grid:
    def __init__(self):
        self.x = (ORIGIN[0] + np.arange(DIMS[0]) * VOX).astype(np.float32)[:, None, None]
        self.y = (ORIGIN[1] + np.arange(DIMS[1]) * VOX).astype(np.float32)[None, :, None]
        self.z = (ORIGIN[2] + np.arange(DIMS[2]) * VOX).astype(np.float32)[None, None, :]

    def noise(self, cell, seed):
        """Smooth 3D value noise in [0, 1], `cell` studs per lattice step."""
        g = np.random.default_rng(seed).random(tuple(int(d * VOX / cell) + 3 for d in DIMS)).astype(np.float32)
        out = None
        idx, frac = [], []
        for c, o in zip((self.x, self.y, self.z), ORIGIN):
            f = (c - o) / cell
            i = np.floor(f).astype(np.int32)
            t = f - i
            idx.append(i)
            frac.append(t * t * (3.0 - 2.0 * t))
        for a in (0, 1):
            for b in (0, 1):
                for c in (0, 1):
                    w = (frac[0] if a else 1 - frac[0]) * (frac[1] if b else 1 - frac[1]) * (frac[2] if c else 1 - frac[2])
                    v = g[idx[0] + a, idx[1] + b, idx[2] + c] * w
                    out = v if out is None else out + v
        return out


def joints(G, seed=5):
    """Granite joint sets: sheeting joints (gently dipping, undulating) and two steep sets. Returns the per-block
    set-back (studs) and the open-joint groove depth."""
    rng = np.random.default_rng(seed)
    X, Y, Z = G.x, G.y, G.z
    undul = G.noise(14.0, seed + 1) - 0.5
    wav = G.noise(6.0, seed + 2) - 0.5                                      # sheeting joints wander, not ruled courses
    sets = (  # coordinate across the set, spacing range (log-uniform), groove depth
        (Z + 0.045 * X - 0.03 * Y + 2.6 * undul + 1.4 * wav, (2.2, 12.0), 0.70),
        (X * math.cos(0.14) + Y * math.sin(0.14) + 1.8 * undul, (5.0, 16.0), 0.50),
        (Y * math.cos(0.22) - X * math.sin(0.22) + 1.8 * undul, (6.0, 12.0), 0.50),
        (Z * math.cos(0.75) - X * math.sin(0.75) + 1.5 * undul, (9.0, 22.0), 0.45),   # oblique set: wedge blocks
    )
    key = np.zeros(1, np.float64)
    groove = np.zeros(1, np.float32)
    local = []
    for n, (u, (lo, hi), depth) in enumerate(sets):
        b = np.cumsum(np.exp(rng.uniform(math.log(lo), math.log(hi), 40))) - 70.0
        k = np.clip(np.searchsorted(b, u), 1, len(b) - 1)
        d0, d1 = u - b[k - 1], b[k] - u
        near = np.where(d0 < d1, k - 1, k)
        dist = np.minimum(d0, d1)
        open_ = (rng.random(len(b)) ** 2).astype(np.float32)[near]          # some joints gape, some are tight
        groove = groove + depth * open_ * np.maximum(1.0 - dist / 0.42, 0.0) ** 1.2
        key = key + k * (12.9898, 78.233, 37.719, 53.117)[n]
        if n == 0:
            layer = k * 12.9898
        local.append((u - (b[k - 1] + b[k]) * 0.5) / ((b[k] - b[k - 1]) * 0.5))   # -1..1 across the block
    r = lambda off, kk=key: (np.abs(np.sin(kk + off) * 43758.5453) % 1.0).astype(np.float32)
    # set-backs follow the sheeting layer more than the block, so ledges run along the face, not a brick stack
    setback = 3.6 * (0.2 * r(0.0, layer) ** 2.5 + 0.8 * r(0.0) ** 2.5) \
        + 0.9 * (r(1.3) - 0.5) * local[0] + 0.9 * (r(2.7) - 0.5) * local[1] \
        + 0.9 * (r(4.1) - 0.5) * local[2]                                     # each block its own set-back and tilt
    return setback, groove


def arch_field(G):
    X, Y, Z = G.x, G.y, G.z
    under = ss(PLINTH[0], PLINTH[1], Z)                                          # 1 below the platform
    up = np.clip((Z - 30.0) / 28.0, 0.0, 1.0)
    xl = -27.6 + 2.0 * up ** 1.3 - 2.7 * under
    xr = tab(((0, 27.6), (22, 28.2), (26, 28.6), (30, 28.6), (34, 28.8), (38, 27.9), (43, 26.6), (48, 25.5), (60, 25.0)), Z) \
        + 2.5 * under
    zt = tab(((-31, 52.5), (-27.5, 56.3), (-22, 57.8), (-15, 57.3), (-10, 56.0), (-5, 54.0), (0, 52.6), (5, 51.6),
              (10, 51.2), (14, 50.4), (17, 49.4), (20, 47.4), (23, 45.4), (26.5, 44.6), (29, 43.0), (31, 40.5)), X)
    d = tab(((-31, 13.0), (-18, 12.6), (-8, 11.2), (2, 10.2), (12, 9.8), (20, 9.0), (31, 8.6)), X) * (1 - 0.18 * up)
    d = d + np.minimum(3.5, 15.3 - d) * under
    yc = 0.9 * np.sin(X * 0.07 + 0.4)
    s = smax(np.maximum(xl - X, X - xr), np.abs(Y - yc) - d, 1.5)
    s = smax(s, Z - zt, 1.2)
    s = np.maximum(s, -Z)
    # the eye: sea-cut along the joints. Roof = a sheeting joint (gently dipping, undulating), the headland wall
    # stepped with an overhanging block over the tide-line undercut, the seaward wall leaning; flared at the mouths
    flare = 1.4 * ss(8.5, 15.0, np.abs(Y))
    wy = 0.6 * np.sin(Y * 0.19 + 1.0)
    el = tab(((0, -5.6), (12, -6.0), (22, -6.6), (27, -7.6), (31, -8.0), (32.4, -7.4), (33.0, -4.6), (35.5, -4.0),
              (40, -3.2)), Z) + wy - flare + 1.2 * (G.noise(5.0, 51) - 0.5)
    er = tab(((0, 14.0), (14, 15.2), (26, 16.8), (30.5, 19.0), (32.5, 18.0), (34.5, 16.8), (37, 14.6), (40, 12.5)), Z) + wy + flare \
        + 1.2 * (G.noise(5.0, 52) - 0.5)
    roof = tab(((-10, 38.8), (8.5, 38.0), (10.0, 37.0), (20, 36.0)), X) + 0.03 * Y + 0.6 * flare \
        + 2.6 * (G.noise(14.0, 6) - 0.5) + 0.8 * (G.noise(4.0, 53) - 0.5)       # G.noise(14, 6) = joints() undul
    s = smax(s, -smax(smax(el - X, X - er, 1.6), Z - roof, 2.2), 1.0)
    # weathering: block set-backs and open joints (softened in the surf), wave-cut notch, broad fracture relief
    setback, groove = joints(G)
    surf = np.exp(-((Z - 30.3) / 3.2) ** 2)
    sub = ss(28.0, 20.0, Z)                                                      # 1 well under the tide line
    s = s + (setback + groove) * (1.0 - 0.55 * surf) * (1.0 - 0.6 * sub)
    s = s + sub * (2.2 * (G.noise(7.0, 61) - 0.5) - 0.6)                         # rounded, slumped lower faces
    s = s + (1.0 + 0.6 * ss(14.0, 22.0, X)) * np.exp(-((Z - 30.5) / 2.4) ** 2)
    s = s + 3.0 * (G.noise(22.0, 30) - 0.5) + 2.4 * (G.noise(9.0, 31) - 0.5) + 0.35 * (G.noise(4.5, 32) - 0.5) + 0.2 * (G.noise(1.8, 33) - 0.5)
    return s


def blocks_field(G):
    X, Y, Z = G.x, G.y, G.z
    s = np.full(DIMS, 9.0, np.float32)
    for (cx, cy, cz), (hx, hy, hz), yaw, tilt in BLOCKS:
        px, py, pz = X - cx, Y - cy, Z - cz
        ca, sa, ct, st = math.cos(yaw), math.sin(yaw), math.cos(tilt), math.sin(tilt)
        qx, qy = px * ca + py * sa, -px * sa + py * ca
        qy, qz = qy * ct + pz * st, -qy * st + pz * ct
        r = 0.7
        dx, dy, dz = np.abs(qx) - hx + r, np.abs(qy) - hy + r, np.abs(qz) - hz + r
        out = np.sqrt(np.maximum(dx, 0) ** 2 + np.maximum(dy, 0) ** 2 + np.maximum(dz, 0) ** 2)
        s = np.minimum(s, out + np.minimum(np.maximum(dx, np.maximum(dy, dz)), 0.0) - r)
    _, groove = joints(G, seed=9)
    return s + 0.6 * groove + 0.6 * (G.noise(3.0, 41) - 0.5) + 0.25 * (G.noise(1.2, 42) - 0.5)


def new_object(name, me=None):
    ob = bpy.data.objects.new(name, me or bpy.data.meshes.new(name))
    bpy.context.scene.collection.objects.link(ob)
    return ob


def apply_mod(ob, mod):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)


def mesh_field(sdf, name):
    """SDF (negative inside) -> closed mesh via OpenVDB and Volume to Mesh, in studs, smoothed a little so the
    voxel steps on oblique joint faces become weathered arrises."""
    import openvdb
    path = os.path.join(common.out_root(), "work", name + ".vdb")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    g = openvdb.FloatGrid(-2.0)
    g.copyFromArray(np.clip(-sdf, -2.0, 2.0).astype(np.float32), (0, 0, 0), 0.0)
    g.transform = openvdb.createLinearTransform(voxelSize=VOX)
    g.name = "density"
    openvdb.write(path, grids=[g])
    vol = bpy.data.volumes.new(name + "_vol")
    vol.filepath = path
    vo = bpy.data.objects.new(name + "_vol", vol)
    bpy.context.scene.collection.objects.link(vo)
    ob = new_object(name)
    m = ob.modifiers.new("v2m", "VOLUME_TO_MESH")
    m.object, m.grid_name, m.threshold, m.resolution_mode, m.adaptivity = vo, "density", 0.0, "GRID", 0.0
    apply_mod(ob, m)
    bpy.data.objects.remove(vo, do_unlink=True)
    bpy.data.volumes.remove(vol)
    ob.data.transform(__import__("mathutils").Matrix.Translation(ORIGIN))
    m = ob.modifiers.new("smooth", "SMOOTH")
    m.factor, m.iterations = 0.5, 2
    apply_mod(ob, m)
    clean(ob, triangulate=True)
    return ob


def clean(ob, triangulate=False):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    if triangulate:
        bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


def components(bm):
    bm.faces.ensure_lookup_table()
    seen = np.zeros(len(bm.faces), bool)
    out = []
    for f in bm.faces:
        if seen[f.index]:
            continue
        comp, stack = [], [f]
        seen[f.index] = True
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.edges:
                for o in e.link_faces:
                    if not seen[o.index]:
                        seen[o.index] = True
                        stack.append(o)
        out.append(comp)
    return out


def drop_small(ob, keep_largest_only=False, min_faces=400):
    """Voxel crumbs (block corners the set-backs cut free) go; the fallen blocks keep every real block."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    comps = sorted(components(bm), key=len, reverse=True)
    drop = [f for c in comps[1:] for f in c] if keep_largest_only else [f for c in comps if len(c) < min_faces for f in c]
    if drop:
        bmesh.ops.delete(bm, geom=drop, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    return len(comps)


def close_holes(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bnd = [e for e in bm.edges if e.is_boundary]
    if bnd:
        bmesh.ops.holes_fill(bm, edges=bnd, sides=0)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    return len(bnd)


def fix_normals(ob):
    clean(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.data.update()


def copy_of(ob, name):
    c = ob.copy()
    c.data = ob.data.copy()
    c.name = c.data.name = name
    bpy.context.scene.collection.objects.link(c)
    return c


def join(objs, name):
    bm = bmesh.new()
    for o in objs:
        bm.from_mesh(o.data)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return new_object(name, me)


def transform_of(objs):
    co = np.concatenate([np.array([v.co[:] for v in o.data.vertices], np.float32) for o in objs])
    lo, hi = co.min(axis=0), co.max(axis=0)
    scale = np.array([A.SPAN, A.THICK, A.TOP], np.float32) / (hi - lo)
    off = np.array([(lo[0] + hi[0]) / 2.0, (lo[1] + hi[1]) / 2.0, lo[2]], np.float32)
    return off, scale


def apply_transform(ob, off, scale):
    me = ob.data
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    me.vertices.foreach_set("co", ((co.reshape(-1, 3) - off) * scale).reshape(-1))
    me.update()


def unwrap(objs, margin=0.001):
    """One shared atlas for every mesh on the set (multi-object edit), one texel density."""
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=margin)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=0.0015, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def material():
    mat = bpy.data.materials.get("MI_Arch_Granite") or bpy.data.materials.new("MI_Arch_Granite")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.25, 0.24, 0.23, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.8
    return mat


def silhouette_check(objs, out_root):
    """Front orthographic render + the two shape numbers the brief requires: crest variation >= 15% of the height,
    and the two legs at the tide line different by >= 1.5x. Raises if either fails."""
    sc = bpy.context.scene
    hidden = [o for o in sc.objects if o.type == "MESH" and o not in objs]
    for o in hidden:
        o.hide_render = True
    cam_data = bpy.data.cameras.new("_SilCam")
    cam = bpy.data.objects.new("_SilCam", cam_data)
    sc.collection.objects.link(cam)
    cam.location = (0.0, -220.0, A.TOP / 2.0)
    cam.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
    cam_data.type, cam_data.ortho_scale = "ORTHO", 66.0
    old_cam, old_engine = sc.camera, sc.render.engine
    sc.camera = cam
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light, sh.color_type = "FLAT", "SINGLE"
    sh.single_color, sh.show_object_outline = (0.82, 0.83, 0.82), False
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 900
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    path = os.path.join(out_root, "review", "silhouette_check.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    px = np.empty(img.size[0] * img.size[1] * 4, np.float32)
    img.pixels.foreach_get(px)
    mask = px.reshape(img.size[1], img.size[0], 4)[..., 3] > 0.5
    bpy.data.images.remove(img)
    sc.render.engine = old_engine
    sc.camera = old_cam
    sc.render.film_transparent = False
    bpy.data.objects.remove(cam, do_unlink=True)
    for o in hidden:
        o.hide_render = False

    h, w = mask.shape
    top = np.full(w, -1, np.int32)
    for x in range(w):
        rows = np.nonzero(mask[:, x])[0]
        if len(rows) > 4:
            top[x] = rows.max()
    z = (top[top >= 0] + 0.5) / h * cam_data.ortho_scale + (A.TOP / 2.0 - cam_data.ortho_scale / 2.0)
    span = (np.percentile(z, 97) - np.percentile(z, 3)) / A.TOP
    row = int((A.WL - (A.TOP / 2.0 - cam_data.ortho_scale / 2.0)) / cam_data.ortho_scale * h)
    runs, start = [], None
    for x in range(w):
        if mask[row, x] and start is None:
            start = x
        elif not mask[row, x] and start is not None:
            runs.append(x - start)
            start = None
    if start is not None:
        runs.append(w - start)
    runs = sorted((n for n in runs if n > 8), reverse=True)[:2]
    ratio = runs[0] / runs[1] if len(runs) > 1 else 0.0
    print("[arch] silhouette crest variation %.1f%% of height, leg widths %s px (ratio %.2f)" % (
        100.0 * span, runs, ratio))
    if span < 0.15 or ratio < 1.5:
        raise RuntimeError("silhouette still reads as a box: crest %.1f%%, leg ratio %.2f" % (100 * span, ratio))
    return span, ratio


def build():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(NAME) or o.name.startswith("ATT_"):
            bpy.data.objects.remove(o, do_unlink=True)

    G = Grid()
    body = mesh_field(arch_field(G), NAME + "_Body")
    print("[arch] body components %d (crumbs dropped)" % drop_small(body, keep_largest_only=True))
    rubble = mesh_field(blocks_field(G), NAME + "_Rubble")
    print("[arch] fallen blocks %d" % drop_small(rubble))
    del G

    lod0 = copy_of(body, NAME + "_LOD0")
    versions.decimate(lod0, LOD0_TRIS)
    rocks = copy_of(rubble, NAME + "_Base_LOD0")
    versions.decimate(rocks, BASE_TRIS)
    col = copy_of(body, NAME + "_COL")
    versions.decimate(col, 900)
    hp = join((body, rubble), NAME + "_HP")
    for o in (body, rubble):
        bpy.data.objects.remove(o, do_unlink=True)
    for o in (lod0, rocks, col):
        print("[arch] %s closed %d boundary edges" % (o.name, close_holes(o)))
        fix_normals(o)

    off, scale = transform_of((lod0, rocks))
    for o in (lod0, hp, col, rocks):
        apply_transform(o, off, scale)
    print("[arch] fit scale %s" % np.round(scale, 3))
    unwrap((lod0, rocks))
    mat = material()
    for o in (lod0, hp, col, rocks):
        o.data.materials.clear()
        o.data.materials.append(mat)

    att = bpy.data.objects.new("ATT_Waterline", None)
    att.empty_display_type = "PLAIN_AXES"
    att.location = (0.0, 0.0, A.WL)
    bpy.context.scene.collection.objects.link(att)

    me = lod0.data
    dims = [max(v.co[i] for v in me.vertices) - min(v.co[i] for v in me.vertices) for i in range(3)]
    tri = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("[arch] LOD0 %d + base %d tris, HP %d, COL %d" % (tri(lod0), tri(rocks), tri(hp), tri(col)))
    print("[arch] bbox %.2f x %.2f x %.2f studs, %d islands, texel %.1f px/stud at %d"
          % (dims[0], dims[1], dims[2], uvlayout.islands(me), uvlayout.texel_density(me, SET_SIZE), SET_SIZE))
    silhouette_check((lod0, rocks), common.out_root())
    return {
        "name": NAME,
        "budget": "rock",
        "tris": 12000,
        "tier": "background",
        "dims_m": tuple(round(d / 3.0, 3) for d in dims),
        "origin": "base",
        "sets": [{"name": "Arch", "set": "Granite", "size": SET_SIZE, "wet": True}],
        "meshes": [{"object": lod0, "set": "Granite"}, {"object": rocks, "set": "Granite"},
                   {"object": hp}, {"object": col}],
        "attachments": [att],
        "waivers": {"LOD UV layout": "the LOD0s are hundreds of projection islands, so collapse decimation "
                                    "redistributes their UV area (bounds unchanged); the maps are baked in 3D, so "
                                    "texels shift only"},
        "tiling": False,
        "lod_symmetry": None,
        "closeups": [
            {"name": "eye", "target": [0.0, -15.0, 34.0], "dist": 32.0, "az": 0.0, "el": 4.0},
            {"name": "mouth", "target": [4.0, 15.0, 34.0], "dist": 30.0, "az": 180.0, "el": 8.0},
            {"name": "tide", "target": [23.0, -11.0, 30.0], "dist": 20.0, "az": 0.0, "el": 3.0},
            {"name": "crest", "target": [-2.0, -4.0, 52.0], "dist": 40.0, "az": 35.0, "el": 30.0},
        ],
    }
