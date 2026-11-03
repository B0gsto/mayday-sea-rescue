"""Spin-cinematic flipbooks (prize-wheel RNG roll, docs/26): Lego-toy sprites, white-ish so code tints per rarity.

  FX_SpinFlare      4x4  a chunky 8-point stud star: tiles spiral in, it charges, bursts (a beaded ring), settles
  FX_SpinRays       4x4  10 rounded plastic rays shoot out to frame 4, then travel outward and fade (god-ray burst / tunnel)
  FX_SpinBolt       2x2  four chunky toy lightning bolts (variants: random start frame, fps 0)
  FX_SpinHaloBrick  4x4  a gold 1x2 Lego brick tumbling one full turn (seamless loop)
  FX_SpinHaloRing   1x1  a soft round ring glow (tint gold)

Runs inside the live Blender MCP session (owner 2026-11-01: never --background; no factory reset, it would drop the
MCP add-on). In execute_blender_code:
  import sys, runpy; sys.argv = ["blender", "--", "--only", "FX_SpinBolt"]   # omit --only for all
  runpy.run_path("<repo>/art/source/fx/spincine.py", run_name="__main__")
Writes build/prod/spincine/<name>.png (1024 RGBA, straight alpha, RGB bled, Roblox grid order); contact sheet:
python3 art/source/fx/spincine_contact.py.
"""
import math
import os
import sys
import tempfile

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT = os.path.join(REPO, "build", "prod", "spincine")
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
from rope import write_png  # noqa: E402  (zlib PNG writer; no Pillow in Blender)

TAU = math.pi * 2
SHEET = 1024
WHITE = "#F6F8FC"
GOLD = "#F2B21C"


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def ease_out(t, p=3):
    return 1 - (1 - min(max(t, 0), 1)) ** p


def ease_in(t, p=2):
    return min(max(t, 0), 1) ** p


def back_out(t, s=1.7):
    t = min(max(t, 0), 1) - 1
    return 1 + t * t * ((s + 1) * t + s)


# ---------------------------------------------------------------- scene (live session: wipe data, keep the add-on)


def clear_objects(keep=("CAMERA", "LIGHT")):
    for o in list(bpy.data.objects):
        if o.type not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


def scene(cell, ortho):
    clear_objects(keep=())
    for coll in (bpy.data.lights, bpy.data.cameras):  # materials stay: the sheet functions make them first
        for b in list(coll):
            coll.remove(b)
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    sc.render.resolution_x = sc.render.resolution_y = cell
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "8"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.eevee.taa_render_samples = 64
    w = sc.world or bpy.data.worlds.new("W")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*lin("#C8D2E0"), 1)
    bg.inputs["Strength"].default_value = 0.3
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.location = (0, 0, 20)
    sc.collection.objects.link(cam)
    sc.camera = cam
    # soft key from the image's upper left, cool fill: the bevels read as rounded plastic
    for name, loc, e, col in (("Key", (-5, 5, 6), 620, "#FFF6E8"), ("Fill", (5, -4, 5), 120, "#DDE8FF")):
        d = bpy.data.lights.new(name, "AREA")
        d.energy, d.size, d.color = e, 6, lin(col)
        o = bpy.data.objects.new(name, d)
        o.location = loc
        o.rotation_euler = (math.atan2(math.hypot(*loc[:2]), loc[2]), 0, math.atan2(loc[1], loc[0]) + math.pi / 2)
        sc.collection.objects.link(o)
    return sc


def plastic(name, hexcol, emit=0.35, rough=0.3, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*lin(hexcol), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Emission Color"].default_value = (*lin(hexcol), 1)
    b.inputs["Emission Strength"].default_value = emit
    b.inputs["Alpha"].default_value = alpha
    m.surface_render_method = "BLENDED" if alpha < 1 else "DITHERED"
    m.use_backface_culling = True
    return m


def slab(name, pts, thick, bevel, mat, loc=(0, 0, 0), rot=0.0, holes=None, parent=None, seg=5):
    """A flat outline (CCW, XY) extruded up by `thick` with pillowy bevelled rims. holes: inner loop -> ring."""
    me = bpy.data.meshes.new(name)
    if holes is None:
        me.from_pydata([(x, y, 0) for x, y in pts], [], [list(range(len(pts)))])
    else:  # ring: outer and inner loops with the same point count, joined by quads
        n = len(pts)
        verts = [(x, y, 0) for x, y in pts] + [(x, y, 0) for x, y in holes]
        me.from_pydata(verts, [], [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)])
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    s = o.modifiers.new("Solid", "SOLIDIFY")
    s.thickness, s.offset, s.use_even_offset = thick, 1.0, True
    if bevel:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width, b.segments, b.limit_method = bevel, seg, "ANGLE"
        b.angle_limit = math.radians(50)
        b.use_clamp_overlap = True
    o.data.materials.append(mat)
    o.parent = parent
    o.location = loc
    o.rotation_euler = (0, 0, rot)
    return o


def circle(r, n=48, cx=0.0, cy=0.0):
    return [(cx + r * math.cos(TAU * i / n), cy + r * math.sin(TAU * i / n)) for i in range(n)]


def star(points, r_long, r_short, r_in, p=3.0, n=400):
    """Rounded star outline: `points` tips alternating long / short, fat |cos|^p lobes, rounded tips."""
    out = []
    for i in range(n):
        a = TAU * i / n
        k = round(a / (TAU / points)) % points
        tip = r_long if k % 2 == 0 else r_short
        lobe = abs(math.cos(a * points / 2)) ** p
        out.append(((r_in + (tip - r_in) * lobe) * math.cos(a), (r_in + (tip - r_in) * lobe) * math.sin(a)))
    return out


def hull(pts):
    pts = sorted(set(pts))
    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and (lo[-1][0] - lo[-2][0]) * (p[1] - lo[-2][1]) - (lo[-1][1] - lo[-2][1]) * (p[0] - lo[-2][0]) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and (hi[-1][0] - hi[-2][0]) * (p[1] - hi[-2][1]) - (hi[-1][1] - hi[-2][1]) * (p[0] - hi[-2][0]) <= 0:
            hi.pop()
        hi.append(p)
    return lo[:-1] + hi[:-1]


def ray(a, r0, r1, w0, w1):
    """A rounded plastic ray from radius r0 to r1 along angle a, cap radii w0 (inner) and w1 (outer)."""
    ca, sa = math.cos(a), math.sin(a)
    pts = [(x * ca - y * sa, x * sa + y * ca) for x, y in circle(w0, 24, r0, 0) + circle(w1, 24, r1, 0)]
    return hull([(round(x, 6), round(y, 6)) for x, y in pts])


def ring_pts(r_in, r_out, n=96):
    return circle(r_out, n), circle(r_in, n)


# ---------------------------------------------------------------- post: soft glow, RGB bleed, sheet


def box(a, r, axis):
    pad = [(r + 1, r) if ax == axis else (0, 0) for ax in range(a.ndim)]
    c = np.cumsum(np.pad(a, pad), axis=axis)
    n = a.shape[axis]
    return (np.take(c, range(2 * r + 1, 2 * r + 1 + n), axis=axis) - np.take(c, range(n), axis=axis)) / (2 * r + 1)


def blur(a, r):
    for _ in range(3):
        a = box(box(a, r, 0), r, 1)
    return a


def render_cell(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)[::-1]  # Blender rows run bottom-up


def finish(cell, glow, radius, bleed):
    """Sprite over a soft glow of its own alpha (glow RGB = bleed colour); fully clear pixels get the bleed colour."""
    rgb, a = cell[..., :3], cell[..., 3]
    ag = np.clip(blur(a, radius) * glow * 1.6, 0, 0.8) if glow else np.zeros_like(a)
    out_a = a + ag * (1 - a)
    bc = np.array(bleed, np.float32)
    out_rgb = (rgb * a[..., None] + bc * (ag * (1 - a))[..., None]) / np.maximum(out_a, 1e-6)[..., None]
    out_rgb = np.where(out_a[..., None] > 1e-3, out_rgb, bc)
    out_a[:2], out_a[-2:], out_a[:, :2], out_a[:, -2:] = 0, 0, 0, 0  # no bleed into neighbour cells
    return np.dstack([out_rgb, out_a])


def bake(name, grid, ortho, frames, build, glow=lambda i: 0.0, radius=6, bleed=(1, 1, 1)):
    cell = SHEET // grid
    scene(cell, ortho)
    sheet = np.zeros((SHEET, SHEET, 4), np.float32)
    tmp = tempfile.mkdtemp(prefix="spincine_")
    cov = []
    for i in range(frames):
        clear_objects()
        build(i)
        c = finish(render_cell(os.path.join(tmp, "f%02d.png" % i)), glow(i), radius, bleed)
        r, k = divmod(i, grid)
        sheet[r * cell:(r + 1) * cell, k * cell:(k + 1) * cell] = c
        ys, xs = np.nonzero(c[..., 3] > 0.02)
        pad = min(xs.min(), ys.min(), cell - 1 - xs.max(), cell - 1 - ys.max()) / cell if len(xs) else 0.5
        cov.append(round(float(pad), 3))
    os.makedirs(OUT, exist_ok=True)
    write_png(os.path.join(OUT, name + ".png"), np.round(np.clip(sheet, 0, 1) * 255))
    print(name, "grid %dx%d" % (grid, grid), "frames", frames, "min pad", min(cov), cov)


# ---------------------------------------------------------------- the sheets


def flare():
    m_star = plastic("Star", WHITE, emit=0.42)
    m_stud = plastic("Stud", WHITE, emit=0.48)
    STAR = star(8, 1.0, 0.7, 0.4, p=1.4)
    m_lip = plastic("Lip", "#AEB7C8", emit=0.12)
    SIZE = [0.6, 0.63, 0.67, 0.71, 0.76, 0.81, 0.85, 0.86, 0.7, 0.58]  # swell, then squash before the pop
    BURST = 10  # the impact frame (of 16)

    def tile(name, r, x, y, z=0.0, mat=m_stud):
        slab(name, circle(r, 32), r * 0.7, r * 0.3, mat, loc=(x, y, z))

    def build(i):
        if i < BURST:  # charge: the star swells and turns, six round tiles spiral in
            c = i / (BURST - 1)
            s, rot, alpha = SIZE[i], math.radians(-30 + 30 * c), 1.0
            for k in range(6):
                rr = 0.42 + 0.56 * (1 - ease_in(c, 1.3))
                a = TAU * k / 6 + math.radians(110) * c
                tile("Tile%d" % k, 0.125 * (1 - 0.35 * c), rr * math.cos(a), rr * math.sin(a))
        else:  # burst then settle: the star pops to full size and eases back, a beaded ring flies out
            u = (i - BURST) / (15 - BURST)
            s = 1.0 - 0.42 * ease_out(u, 2)
            rot = math.radians(6 * u)
            alpha = 1.0 - 0.6 * ease_in(u, 1.5)
            m_ring = plastic("Ring", WHITE, emit=0.48, alpha=1.0 - ease_in(u, 1.4))
            r = 0.78 + 0.24 * ease_out(u, 2)
            for k in range(12):  # a studded shockwave: round tiles on the ring, not a line
                a = TAU * (k + 0.5) / 12 + math.radians(20 * u)
                tile("Bead%d" % k, 0.085 * (1 - 0.45 * u), r * math.cos(a), r * math.sin(a), mat=m_ring)
        plastic("Star", WHITE, emit=0.42, alpha=alpha)
        plastic("Stud", WHITE, emit=0.48, alpha=alpha)
        th = 0.18 * s + 0.05
        slab("Star", [(x * s, y * s) for x, y in STAR], th, 0.09 * s + 0.02, m_star, rot=rot)
        plastic("Lip", "#AEB7C8", emit=0.12, alpha=alpha)
        slab("Lip", circle(0.34 * s + 0.03, 48), 0.03, 0.012, m_lip, loc=(0, 0, th - 0.01))
        tile("Stud", 0.26 * s + 0.02, 0, 0, th + 0.02)
        for k in range(4):  # a stud tile on each long point: it reads as a toy piece, not a sparkle
            a = rot + TAU * k / 4
            tile("Pip%d" % k, 0.075 * s + 0.01, 0.66 * s * math.cos(a), 0.66 * s * math.sin(a), th - 0.01)

    glow = [0.14, 0.16, 0.18, 0.2, 0.23, 0.26, 0.3, 0.34, 0.38, 0.42, 0.75, 0.55, 0.4, 0.28, 0.18, 0.1]
    bake("FX_SpinFlare", 4, 2.6, 16, build, glow=lambda i: glow[i], radius=6)


def rays():
    m = plastic("Ray", WHITE, emit=0.42)
    m_stud = plastic("RayStud", WHITE, emit=0.5)
    HUB = 0.34  # a clean gap: the flare sits there and tinted bases never merge into a blob

    def build(i):
        spin = math.radians(1.5 * i)
        if i <= 4:  # shoot out, peak at frame 4
            u = back_out(i / 4, 1.2)
            r0, grow, wk, alpha, push = HUB, u, 0.6 + 0.4 * min(u, 1), 1.0, 0.0
        else:  # then the whole ray travels outward, thins and is gone by frame 14 (the tunnel feel)
            v = min((i - 4) / 10, 1)
            r0, grow, wk, alpha, push = HUB + 0.62 * ease_in(v, 1.2), 1.0, 1.0 - 0.5 * v, 1.0 - ease_in(v, 2.2), 0.24 * v
        if alpha <= 0:
            return
        plastic("Ray", WHITE, emit=0.42, alpha=alpha)
        plastic("RayStud", WHITE, emit=0.5, alpha=alpha)
        for k in range(10):  # regular long / short rhythm, wide and round-tipped so it holds on a phone
            long_ = k % 2 == 0
            w0, w1 = (0.105 * wk, 0.07 * wk) if long_ else (0.08 * wk, 0.05 * wk)
            r1 = max(r0 + 0.02, HUB + (0.6 if long_ else 0.36) * grow + push)
            a = TAU * k / 10 + spin
            slab("Ray%d" % k, ray(a, r0, r1, w0, w1), 0.08, 0.035, m)
            if long_ and r1 - r0 > 0.14:  # a stud on each long ray's fat end: toy rays, not light streaks
                rs = w0 * 0.58
                slab("Stud%d" % k, circle(rs, 28), rs * 0.7, rs * 0.3, m_stud,
                     loc=((r0 + 0.02) * math.cos(a), (r0 + 0.02) * math.sin(a), 0.075))

    glow = [0.2, 0.3, 0.42, 0.52, 0.55, 0.5, 0.46, 0.42, 0.38, 0.32, 0.26, 0.2, 0.14, 0.08, 0.04, 0.0]
    bake("FX_SpinRays", 4, 2.75, 16, build, glow=lambda i: glow[i], radius=5)


def bolt():
    m = plastic("Bolt", WHITE, emit=0.44)
    emoji = [(0.06, 1.0), (0.46, 1.0), (0.2, 0.2), (0.44, 0.2), (-0.18, -1.0), (-0.32, -1.0), (-0.06, -0.08), (-0.34, -0.08)]
    variants = [
        [emoji],  # the iconic chunky bolt
        [[(-0.38, 1.0), (0.02, 1.0), (-0.12, 0.46), (0.24, 0.46), (0.04, -0.08), (0.38, -0.08), (0.24, -1.0), (0.1, -1.0),
          (-0.08, -0.28), (-0.36, -0.28), (-0.2, 0.24), (-0.52, 0.24)]],  # three steps
        [[(-x, y) for x, y in emoji]],  # mirrored
        [[(-0.06, 1.0), (0.44, 1.0), (0.14, 0.44), (0.42, 0.44), (0.02, -0.16), (0.3, -0.16), (-0.12, -1.0), (-0.27, -1.0),
          (-0.14, -0.4), (-0.42, -0.4), (-0.14, 0.16), (-0.42, 0.16)]],  # steep, three steps
    ]

    def ccw(p):
        area = sum(p[k][0] * p[(k + 1) % len(p)][1] - p[(k + 1) % len(p)][0] * p[k][1] for k in range(len(p)))
        return p if area > 0 else list(reversed(p))

    def build(i):
        for k, poly in enumerate(variants[i]):
            slab("Bolt%d" % k, ccw(poly), 0.14, 0.05, m, loc=(0, 0, -0.03 * k))

    bake("FX_SpinBolt", 2, 2.7, 4, build, glow=lambda i: 0.35, radius=7)


def halo_brick():
    m = plastic("Gold", GOLD, emit=0.3, rough=0.22)
    from mathutils import Quaternion, Vector

    axis = Vector((1.0, 0.55, 0.35)).normalized()
    base = Quaternion((1, 0, 0), math.radians(-35)) @ Quaternion((0, 0, 1), math.radians(20))

    def rect(w, h):
        return [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]

    def build(i):
        piv = bpy.data.objects.new("Brick", None)
        bpy.context.scene.collection.objects.link(piv)
        piv.rotation_mode = "QUATERNION"
        piv.rotation_quaternion = Quaternion(axis, TAU * i / 16) @ base
        H = 1.2  # a real 1x2 brick: 2 x 1 studs, 1.2 tall, studs 0.6 wide, 0.2 high
        walls_out = [(x, y) for x, y in rect(2.0, 1.0)]
        walls_in = [(x * 0.88, y * 0.76) for x, y in rect(2.0, 1.0)]
        # ring of four walls needs matched loops: subdivide each rectangle edge into 8 points
        def dense(p, n=8):
            return [(p[e][0] + (p[(e + 1) % 4][0] - p[e][0]) * t / n, p[e][1] + (p[(e + 1) % 4][1] - p[e][1]) * t / n)
                    for e in range(4) for t in range(n)]
        slab("Walls", dense(walls_out), H - 0.15, 0.05, m, loc=(0, 0, -H / 2), holes=dense(walls_in), parent=piv)
        slab("Top", rect(2.0, 1.0), 0.15, 0.05, m, loc=(0, 0, H / 2 - 0.15), parent=piv)
        slab("Rod", circle(0.16, 32), H - 0.2, 0.0, m, loc=(0, 0, -H / 2), parent=piv)
        for x in (-0.5, 0.5):
            slab("Stud", circle(0.3, 48), 0.2, 0.04, m, loc=(x, 0, H / 2), parent=piv)

    bake("FX_SpinHaloBrick", 4, 3.0, 16, build, radius=4, bleed=tuple(c ** (1 / 2.2) for c in lin(GOLD)))


def halo_ring():
    m = plastic("RingGlow", WHITE, emit=0.6)

    def build(i):
        o, h = ring_pts(0.7, 0.8, 128)
        slab("Ring", o, 0.05, 0.02, m, holes=h)

    bake("FX_SpinHaloRing", 1, 2.4, 1, build, glow=lambda i: 1.0, radius=20)


SHEETS = {"FX_SpinFlare": flare, "FX_SpinRays": rays, "FX_SpinBolt": bolt,
          "FX_SpinHaloBrick": halo_brick, "FX_SpinHaloRing": halo_ring}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else list(SHEETS)
    for nm in only:
        SHEETS[nm]()
