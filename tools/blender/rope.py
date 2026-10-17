"""Rope, coils, nets and lines from centrelines, with a tiling rope trim (docs/12 section 1.1, rope.py row).

Geometry (runs inside Blender; 1 Blender unit = 1 stud, every input in metres through common.metres_to_studs):
  rope(name, points_m, diameter_m, profile)   any centreline -> one tube mesh, profile "three_strand" (three lobes
                                               twisting one full turn per trim tile), "braid" (two counter-rotating
                                               4-lobe families, diamond plait) or "plain" (round, for thin lines)
  coil(name, ...)       flat coil / flake (Archimedean spiral lying on the ground, origin at its base centre)
  hang(name, p0, p1, sag_m, ...)               hanging catenary between two points
  mooring_line(name, bollard, fairlead, ...)   eye splice loop round a bollard + catenary to the boat fairlead
  net(name, width_m, height_m, mesh_m, ...)    rectangular knotted net in the XZ plane (front -Y)
UVs (one set, common.UV_NAME): U runs once round the rope (0..1), V runs along it in trim tiles:
  V = metres_to_studs(arc length) / metres_to_studs(tile_m), tile_m = rope circumference by default, so a square trim
  texture gives square texels and its strands line up with the geometric twist. V goes past 1: specs set "tiling": True.
Triangle budget: every builder takes `sides` (around) and `max_tris`; segments along the length are
  min(segments_per_tile * tiles, what fits in max_tris); the triangle count is returned and printed.
Names follow names.py (M_<Cat>_<Name>[_NN][_LOD0]); one material per mesh, "Rope_<Set>".

Trim texture (pure numpy, also from system python3, no Pillow needed):
  trim_maps(set_name, profile, size) -> {"ALB", "NOR", "RGH", "MET"} arrays; write_trim(dir, ...) writes
  T_Rope_<Set>_ALB/NOR/RGH/MET.png, tileable in U and V, OpenGL normals, RGH / MET single-channel. A procedural trim is
  enough at rope scale; bake.py is not needed for it.

CLI:
  ~/RobloxProjects/tools/blender-run.sh tools/blender/rope.py -- --demo --out build/b01-rope [--max-tris 2000]
  python3 tools/blender/rope.py --trim-only --out build/b01-rope/textures --set Manila --profile three_strand
"""
import argparse
import json
import math
import os
import struct
import sys
import zlib

import numpy as np

LIB_DIR = os.path.dirname(os.path.abspath(__file__))
if LIB_DIR not in sys.path:
    sys.path.insert(0, LIB_DIR)
import common  # noqa: E402
import names  # noqa: E402

PROFILES = ("three_strand", "braid", "plain")
# albedo sRGB, roughness base; saturation kept under check_textures' 0.45 limit
SETS = {"Manila": ((164, 141, 102), 0.82), "Nylon": ((214, 210, 200), 0.62), "Green": ((79, 107, 74), 0.70),
        "Tarred": ((70, 61, 52), 0.58)}


# ---------------------------------------------------------------- centrelines (metres, Blender X Y Z, Z up)
def polyline_length(p):
    return float(np.linalg.norm(np.diff(p, axis=0), axis=1).sum())


def resample(points, count):
    """`count` points evenly spaced by arc length along a polyline."""
    p = np.asarray(points, dtype=np.float64)
    seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    t = np.linspace(0.0, s[-1], count)
    return np.stack([np.interp(t, s, p[:, k]) for k in range(3)], -1)


def catenary(p0, p1, sag_m, count=64):
    """Hanging chain from p0 to p1 (metres); sag = drop of the curve below the chord at mid-span (> 0)."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    horiz = p1[:2] - p0[:2]
    span = float(np.linalg.norm(horiz))
    h = float(p1[2] - p0[2])
    if span < 1e-6:
        raise ValueError("catenary needs a horizontal span")
    sag = max(sag_m, 1e-4)

    def curve(a, x):
        x0 = span / 2 - a * math.asinh(h / (2 * a * math.sinh(span / (2 * a))))
        return a * (np.cosh((x - x0) / a) - math.cosh(x0 / a))

    def sag_of(a):
        return (h / 2) - float(curve(a, np.array(span / 2)))

    lo, hi = span * 1e-3, span * 1e4           # sag falls as a grows
    for _ in range(200):
        mid = math.sqrt(lo * hi)
        if sag_of(mid) > sag:
            lo = mid
        else:
            hi = mid
    a = math.sqrt(lo * hi)
    x = np.linspace(0, span, count)
    z = curve(a, x)
    d = horiz / span
    return np.stack([p0[0] + d[0] * x, p0[1] + d[1] * x, p0[2] + z], -1)


def coil_points(inner_radius_m, turns, diameter_m, per_turn=48):
    """Flat flake: Archimedean spiral on the ground (Z = rope radius), widening by one diameter per turn."""
    t = np.linspace(0, turns * 2 * np.pi, int(turns * per_turn) + 1)
    r = inner_radius_m + diameter_m * 1.02 * t / (2 * np.pi)
    return np.stack([r * np.cos(t), r * np.sin(t), np.full_like(t, diameter_m / 2)], -1)


# ---------------------------------------------------------------- tube geometry (numpy, studs)
def frames(p):
    """Parallel-transport tangent / normal / binormal along a polyline."""
    t = np.gradient(p, axis=0)
    t /= np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-12)
    ref = np.array([0, 0, 1.0]) if abs(t[0, 2]) < 0.9 else np.array([1.0, 0, 0])
    n = np.cross(t[0], ref)
    n /= np.linalg.norm(n)
    ns = [n]
    for i in range(1, len(p)):
        v = np.cross(t[i - 1], t[i])
        sv = np.linalg.norm(v)
        if sv > 1e-9:
            ax = v / sv
            ang = math.atan2(sv, float(np.dot(t[i - 1], t[i])))
            n = n * math.cos(ang) + np.cross(ax, n) * math.sin(ang) + ax * np.dot(ax, n) * (1 - math.cos(ang))
        n = n - t[i] * np.dot(n, t[i])
        n /= np.linalg.norm(n)
        ns.append(n)
    n = np.array(ns)
    return t, n, np.cross(t, n)


def profile_radius(profile, theta, phase):
    """Relative radius (<= 1) of the cross-section at angle theta, twist phase (radians) along the rope."""
    if profile == "three_strand":
        return 0.80 + 0.20 * np.sqrt(np.abs(np.cos(1.5 * (theta - phase))))
    if profile == "braid":
        return 0.93 + 0.035 * (np.cos(4 * (theta - phase)) + np.cos(4 * (theta + phase)))
    return np.ones_like(theta)


def tube(points_m, diameter_m, profile="three_strand", sides=10, tile_m=None, segments_per_tile=6, max_tris=None,
         caps=True, v0=0.0):
    """Arrays for one rope tube: (verts studs (n, 3), faces list, loop uvs per face, tris, v_end)."""
    if profile not in PROFILES:
        raise ValueError("profile must be one of %s" % (PROFILES,))
    p = np.asarray(points_m, dtype=np.float64)
    length = polyline_length(p)
    tile_m = tile_m or math.pi * diameter_m
    tiles = length / tile_m
    seg = max(2, int(math.ceil(tiles * segments_per_tile)), len(p) - 1 if profile == "plain" else 2)
    if max_tris:
        seg = max(1, min(seg, (max_tris - (2 * sides if caps else 0)) // (2 * sides)))
    if profile != "plain" and seg < 4 * tiles:
        profile = "plain"                  # budget too small to resolve the twist: round tube, the trim carries it
    c = resample(p, seg + 1) * common.STUDS_PER_METRE
    s_m = np.linspace(0.0, length, seg + 1)
    t, n, b = frames(c)
    R = common.metres_to_studs(diameter_m / 2)
    theta = np.arange(sides) / sides * 2 * np.pi
    phase = 2 * np.pi * s_m / tile_m                           # one full twist per trim tile
    r = R * profile_radius(profile, theta[None, :], phase[:, None])
    ring = (np.cos(theta)[None, :, None] * n[:, None, :] + np.sin(theta)[None, :, None] * b[:, None, :])
    verts = (c[:, None, :] + r[..., None] * ring).reshape(-1, 3)
    v = v0 + common.metres_to_studs(s_m) / common.metres_to_studs(tile_m)
    faces, uvs = [], []
    for i in range(seg):
        for j in range(sides):
            j1 = (j + 1) % sides
            faces.append((i * sides + j, i * sides + j1, (i + 1) * sides + j1, (i + 1) * sides + j))
            u0, u1 = j / sides, (j + 1) / sides
            uvs.append(((u0, v[i]), (u1, v[i]), (u1, v[i + 1]), (u0, v[i + 1])))
    tris = 2 * seg * sides
    if caps:
        extra = []
        for ring_i, outward in ((0, False), (seg, True)):       # start cap faces -t, end cap +t
            centre = len(verts) + len(extra)
            extra.append(c[ring_i])
            for j in range(sides):
                j1 = (j + 1) % sides
                ia, ib = ring_i * sides + j, ring_i * sides + j1
                ua = (0.5 + 0.25 * math.cos(2 * math.pi * j / sides), v[ring_i] + 0.25 * math.sin(2 * math.pi * j / sides))
                ub = (0.5 + 0.25 * math.cos(2 * math.pi * j1 / sides), v[ring_i] + 0.25 * math.sin(2 * math.pi * j1 / sides))
                if outward:
                    faces.append((ia, ib, centre))
                    uvs.append((ua, ub, (0.5, v[ring_i])))
                else:
                    faces.append((ib, ia, centre))
                    uvs.append((ub, ua, (0.5, v[ring_i])))
            tris += sides
        verts = np.concatenate([verts, np.array(extra)])
    return verts, faces, uvs, tris, float(v[-1])


def knot(centre_studs, radius_studs):
    """Octahedron knot (8 tris)."""
    d = np.array([(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)], float) * radius_studs
    verts = centre_studs + d
    fs = [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)]
    uvs = [((0.0, 0.0), (0.5, 0.0), (0.25, 0.5))] * 8
    return verts, fs, uvs, 8


# ---------------------------------------------------------------- Blender objects
def _object(name, parts, set_name="Manila"):
    import bpy
    prob = names.mesh_name_problem(name)
    if prob:
        raise ValueError("%s: %s" % (name, prob))
    verts, faces, uvs, off = [], [], [], 0
    for pv, pf, pu in parts:
        verts.extend(map(tuple, pv))
        faces.extend(tuple(i + off for i in f) for f in pf)
        uvs.extend(pu)
        off += len(pv)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate()
    uv = me.uv_layers.new(name=common.UV_NAME)
    flat = [c for poly in uvs for c in poly]
    uv.data.foreach_set("uv", [x for c in flat for x in c])
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    mat_name = "Rope_%s" % set_name
    mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def rope(name, points_m, diameter_m, profile="three_strand", set_name="Manila", **kw):
    v, f, u, tris, _ = tube(points_m, diameter_m, profile, **kw)
    return _object(name, [(v, f, u)], set_name)


def coil(name, diameter_m=0.024, inner_radius_m=0.12, turns=5.0, profile="three_strand", **kw):
    return rope(name, coil_points(inner_radius_m, turns, diameter_m), diameter_m, profile, **kw)


def hang(name, p0_m, p1_m, sag_m, diameter_m=0.02, profile="three_strand", **kw):
    return rope(name, catenary(p0_m, p1_m, sag_m), diameter_m, profile, **kw)


def mooring_line(name, bollard_m, fairlead_m, sag_m=0.4, eye_radius_m=0.2, diameter_m=0.028, profile="three_strand",
                 **kw):
    """Eye round a bollard at `bollard_m` (centre of the eye, metres), catenary to the boat fairlead."""
    b, f = np.asarray(bollard_m, float), np.asarray(fairlead_m, float)
    d = (f[:2] - b[:2]) / np.linalg.norm(f[:2] - b[:2])
    a0 = math.atan2(d[1], d[0])
    t = np.linspace(a0 + 0.35, a0 + 2 * np.pi - 0.35, 40)
    eye = np.stack([b[0] + eye_radius_m * np.cos(t), b[1] + eye_radius_m * np.sin(t), np.full_like(t, b[2])], -1)
    throat = b + np.array([d[0], d[1], 0]) * eye_radius_m * 1.6
    line = catenary(throat, f, sag_m, 64)
    pts = np.concatenate([eye, [throat], line[1:]])
    return rope(name, pts, diameter_m, profile, **kw)


def net(name, width_m=1.2, height_m=1.0, mesh_m=0.12, twine_m=0.006, knot_scale=2.2, sides=4, set_name="Green",
        knots=True):
    """Knotted rectangular net in the XZ plane, bottom edge at Z = 0, centred on X."""
    nx = max(1, int(round(width_m / mesh_m)))
    nz = max(1, int(round(height_m / mesh_m)))
    xs = np.linspace(-width_m / 2, width_m / 2, nx + 1)
    zs = np.linspace(0, height_m, nz + 1)
    parts, tris = [], 0
    for x in xs:
        v, f, u, t, _ = tube(np.stack([np.full(nz + 1, x), np.zeros(nz + 1), zs], -1), twine_m, "plain", sides=sides,
                             caps=False, segments_per_tile=0)
        parts.append((v, f, u))
        tris += t
    for z in zs:
        v, f, u, t, _ = tube(np.stack([xs, np.zeros(nx + 1), np.full(nx + 1, z)], -1), twine_m, "plain", sides=sides,
                             caps=False, segments_per_tile=0)
        parts.append((v, f, u))
        tris += t
    if knots:
        kr = common.metres_to_studs(twine_m / 2 * knot_scale)
        for x in xs:
            for z in zs:
                kv, kf, ku, kt = knot(np.array([x, 0, z]) * common.STUDS_PER_METRE, kr)
                parts.append((kv, kf, ku))
                tris += kt
    return _object(name, parts, set_name)


# ---------------------------------------------------------------- trim texture (pure numpy)
def tile_noise(size, cycles, seed):
    """Tileable smooth noise 0..1: white noise low-passed in the Fourier domain (periodic by construction)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(size) * size
    k = np.sqrt(f[:, None] ** 2 + f[None, :] ** 2)
    spec = np.fft.fft2(rng.standard_normal((size, size))) * np.exp(-(k / cycles) ** 2)
    n = np.real(np.fft.ifft2(spec))
    return (n - n.min()) / max(n.max() - n.min(), 1e-12)


def trim_height(profile, size, seed=7):
    """Height 0..1 of one trim tile: x = U (round the rope), image up = +V (along)."""
    u = (np.arange(size) + 0.5)[None, :] / size
    v = 1.0 - (np.arange(size) + 0.5)[:, None] / size
    fine = tile_noise(size, size / 6, seed)
    if profile == "braid":
        a1, a2 = 4 * (u - v), 4 * (u + v)
        h1 = np.sqrt(np.sin(np.pi * (a1 % 1.0)))
        h2 = np.sqrt(np.sin(np.pi * (a2 % 1.0)))
        over = (np.floor(a1) + np.floor(a2)) % 2 == 0
        h = np.where(over, np.maximum(h1, 0.55 * h2), np.maximum(h2, 0.55 * h1))
        yarn = 0.5 + 0.5 * np.cos(2 * np.pi * np.where(over, 12 * (u + v), 12 * (u - v)))
    elif profile == "three_strand":
        p = (3 * (u - v)) % 1.0                                 # strand centre lines u - v = k / 3 (matches tube())
        h = np.sqrt(np.sin(np.pi * p))
        yarn = 0.5 + 0.5 * np.cos(2 * np.pi * (18 * u + 36 * v))   # yarns laid the opposite way
    else:
        h = np.ones_like(u * v)
        yarn = 0.5 + 0.5 * np.cos(2 * np.pi * (24 * u + 8 * v))
    return np.clip(h * (0.86 + 0.14 * yarn) + 0.06 * (fine - 0.5), 0, 1)


def trim_maps(set_name="Manila", profile="three_strand", size=common.SHIP_SIZE, seed=7, strength=6.0):
    rgb, rough = SETS[set_name]
    h = trim_height(profile, size, seed)
    blotch = tile_noise(size, 6, seed + 1)
    ao = 0.45 + 0.55 * h
    shade = ao * (0.9 + 0.2 * blotch)
    shade = np.maximum(shade, 34.0 / min(rgb))          # darkest channel stays >= 34 (scale, not clip: hue kept)
    alb = np.clip(np.array(rgb, float)[None, None, :] * shade[..., None], 0, 238).astype(np.uint8)
    # OpenGL normal: +X = +U (right), +Y = +V (image up); heights wrap (tileable)
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, 1, 0) - np.roll(h, -1, 0)) * 0.5 * strength     # row above minus row below = d/dV
    nrm = np.stack([-dx, -dy, np.ones_like(h)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    nor = np.round((nrm * 0.5 + 0.5) * 255).astype(np.uint8)
    rgh = np.clip((rough + 0.12 * (1 - h) + 0.05 * (blotch - 0.5)) * 255, 0, 255).astype(np.uint8)
    met = np.zeros((size, size), np.uint8)
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met}


def write_png(path, arr):
    """8-bit greyscale (H, W), RGB (H, W, 3) or RGBA (H, W, 4) PNG with zlib only (works in Blender's python and system python3)."""
    arr = np.ascontiguousarray(arr, dtype=np.uint8)
    h, w = arr.shape[:2]
    ctype = 0 if arr.ndim == 2 else {3: 2, 4: 6}[arr.shape[2]]
    raw = b"".join(b"\x00" + arr[y].tobytes() for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def write_trim(directory, set_name="Manila", profile="three_strand", size=common.SHIP_SIZE, name="Rope"):
    os.makedirs(directory, exist_ok=True)
    out = []
    for kind, arr in trim_maps(set_name, profile, size).items():
        stem = names.texture_stem(name, set_name, kind)
        assert names.texture_name_problem(stem) is None, stem
        p = os.path.join(directory, stem + ".png")
        write_png(p, arr)
        out.append(p)
    return out


# ---------------------------------------------------------------- demo
def demo(out, max_tris=None):
    import bpy
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    bpy.context.scene.unit_settings.system = "NONE"
    kw = {"max_tris": max_tris} if max_tris else {}
    built = [
        rope("M_Hbr_Rope_ThreeStrand_01_LOD0", [(0, 0, 0.1), (2.0, 0, 0.1)], 0.024, "three_strand", sides=12, **kw),
        rope("M_Hbr_Rope_Braid_01_LOD0", [(0, 0.3, 0.1), (2.0, 0.3, 0.1)], 0.016, "braid", set_name="Nylon",
             sides=16, **kw),
        coil("M_Hbr_RopeCoil_01_LOD0", 0.024, 0.12, 5.0, sides=10, **kw),
        hang("M_Hbr_RopeHang_01_LOD0", (0, 1, 1.2), (3.0, 1, 1.0), 0.35, 0.02, sides=8, **kw),
        mooring_line("M_Hbr_MooringLine_01_LOD0", (0, 2, 0.45), (6.0, 2, 1.3), 0.5, 0.2, 0.028, sides=8, **kw),
        net("M_Kit_Net_01_LOD0", 1.2, 1.0, 0.12, 0.006),
    ]
    rows = []
    for ob in built:
        ob.data.update()
        dims = tuple(round(x / common.STUDS_PER_METRE, 3) for x in ob.dimensions)
        uv = ob.data.uv_layers[common.UV_NAME].data
        vs = [d.uv[1] for d in uv]
        rows.append({"name": ob.name, "tris": tri_count(ob), "verts": len(ob.data.vertices), "dims_m": dims,
                     "materials": [m.name for m in ob.data.materials], "uv_layers": [l.name for l in ob.data.uv_layers],
                     "v_range": (round(min(vs), 3), round(max(vs), 3)),
                     "name_ok": names.mesh_name_problem(ob.name) is None})
    os.makedirs(out, exist_ok=True)
    tex = write_trim(os.path.join(out, "textures"), "Manila", "three_strand")
    tex += write_trim(os.path.join(out, "textures"), "Nylon", "braid")
    tex += write_trim(os.path.join(out, "textures"), "Green", "plain")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "rope_demo.blend"))
    report = {"objects": rows, "textures": [os.path.basename(p) for p in tex]}
    with open(os.path.join(out, "rope_demo.json"), "w") as f:
        json.dump(report, f, indent=1)
    for r in rows:
        print("ROPE %-32s tris %6d  dims_m %s  V %s  mat %s  uv %s  name_ok %s" % (
            r["name"], r["tris"], r["dims_m"], r["v_range"], r["materials"], r["uv_layers"], r["name_ok"]))
    print("ROPE textures:", ", ".join(report["textures"]))
    return report


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser(description="rope / coil / net generator and rope trim")
    ap.add_argument("--demo", action="store_true", help="(Blender) build the six demo meshes and the trims")
    ap.add_argument("--trim-only", action="store_true", help="write one trim set (no Blender needed)")
    ap.add_argument("--out", default=os.path.join(common.REPO_DIR, "build", "rope"))
    ap.add_argument("--set", default="Manila", choices=sorted(SETS))
    ap.add_argument("--profile", default="three_strand", choices=PROFILES)
    ap.add_argument("--size", type=int, default=common.SHIP_SIZE)
    ap.add_argument("--max-tris", type=int, default=None, help="per-rope triangle cap")
    a = ap.parse_args(argv)
    if a.trim_only:
        for p in write_trim(a.out, a.set, a.profile, a.size):
            print("wrote", p)
    elif a.demo:
        demo(a.out, a.max_tris)
    else:
        ap.print_help()


if __name__ == "__main__":
    main()
