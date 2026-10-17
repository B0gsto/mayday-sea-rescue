#!/usr/bin/env python3
"""Render the Gale Isles top-down map (the GTA-style minimap / full map texture) from the terrain bake.

usage: python3 tools/world/make_map_image.py [--out art/map/gale_isles_map.png] [--size 2048] [--preview PATH]

Inputs (read only): map/generated/terrain.json + terrain_height.i16 + terrain_material.u8 (gen_terrain.py),
src/shared/Config/WorldConfig.luau (road splines, car parks), the greybox harbour from tools/world/layout.py.

World -> image (north up, the same frame as the bake: rows are +Z = south):
    u = (x - originX) / extent,  v = (z - originZ) / extent,  extent = (nx - 1) * cell  (5120 studs)
    pixel = (u * size, v * size)
The transform is printed and must match src/shared/Config/MapConfig.luau (Origin, Extent).

Look: sea depth shading (shallow aqua to deep navy) with depth contours and a surf line, the seabed showing
through the shallows (reefs, kelp, sand), land coloured by terrain material with elevation tint and NW
hillshading, cliffs darkened by slope, the breakwater and harbour, roads with a casing, car parks, and
labels for the main places. Needs numpy and Pillow; no heavy slot (about 5 s)."""

import json, math, os, re, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GEN = os.path.join(ROOT, "map", "generated")


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


SIZE = int(arg("--size", "2048"))
OUT = os.path.join(ROOT, arg("--out", "art/map/gale_isles_map.png"))

MAT_RGB = {  # land colours by terrain material (Roblox-ish, slightly desaturated for a map)
    "Sand": (226, 210, 160), "Sandstone": (204, 186, 138), "Salt": (226, 214, 176),
    "Limestone": (206, 198, 176), "Rock": (134, 132, 124), "Slate": (104, 110, 104),
    "Basalt": (80, 80, 82), "Grass": (110, 146, 80), "LeafyGrass": (138, 142, 86),
    "Mud": (118, 102, 78), "Ground": (152, 130, 96), "Asphalt": (88, 90, 96),
    "Cobblestone": (140, 134, 126), "Concrete": (186, 184, 176), "Pavement": (170, 168, 160),
    "Air": (0, 0, 0),
}
SEABED_TINT = {  # how the seabed reads through shallow water
    "Sand": (232, 222, 180), "Limestone": (214, 208, 186), "Rock": (110, 116, 108),
    "Slate": (60, 84, 58), "Basalt": (70, 74, 74), "Mud": (120, 110, 84),
}
DEPTH_STOPS = [  # depth below sea level (studs, 3 studs = 1 m) -> colour
    (0, (120, 214, 214)), (6, (82, 190, 204)), (18, (44, 150, 186)), (40, (26, 104, 156)),
    (80, (16, 70, 124)), (165, (8, 38, 82)),
]


def load_terrain():
    meta = json.load(open(os.path.join(GEN, "terrain.json")))
    n = meta["nx"]
    h = np.fromfile(os.path.join(GEN, meta["height"]), "<i2").reshape(meta["nz"], n) / meta["heightScale"]
    m = np.fromfile(os.path.join(GEN, meta["material"]), "u1").reshape(meta["nz"], n)
    return meta, h.astype(np.float32), m


def parse_world_config():
    src = open(os.path.join(ROOT, "src", "shared", "Config", "WorldConfig.luau")).read()
    roads_src = src[src.index("Roads = {"): src.index("CarParks = {")]
    vec = r"Vector3\.new\(\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+)\)"
    roads = []
    for block in re.split(r"\n\t\t\{", roads_src)[1:]:
        rid = re.search(r'id = "(\w+)"', block)
        width = re.search(r"width = ([\d.]+)", block)
        surface = re.search(r'surface = "(\w+)"', block)
        pts = [(float(a), float(c)) for a, _, c in re.findall(vec, block)]
        if rid and len(pts) >= 2:
            roads.append({"id": rid.group(1), "width": float(width.group(1)) if width else 12,
                          "surface": surface.group(1) if surface else "Asphalt", "points": pts})
    parks = []
    cp_src = src[src.index("CarParks = {"): src.index("Points = {")]
    for block in re.split(r"\n\t\t\{", cp_src)[1:]:
        c = re.search(vec, block)
        size = re.search(r"size = \{\s*([\d.]+),\s*([\d.]+)", block)
        yaw = re.search(r"yaw = (-?[\d.]+)", block)
        surface = re.search(r'surface = "(\w+)"', block)
        if c and size:
            parks.append({"center": (float(c.group(1)), float(c.group(3))),
                          "size": (float(size.group(1)), float(size.group(2))),
                          "yaw": float(yaw.group(1)) if yaw else 0, "surface": surface.group(1) if surface else "Asphalt"})
    return roads, parks


def lerp_stops(depth):
    out = np.zeros(depth.shape + (3,), np.float32)
    d = np.clip(depth, 0, DEPTH_STOPS[-1][0])
    for (d0, c0), (d1, c1) in zip(DEPTH_STOPS, DEPTH_STOPS[1:]):
        t = np.clip((d - d0) / (d1 - d0), 0, 1)[..., None]
        sel = ((d >= d0) & (d <= d1))[..., None]
        out = np.where(sel, np.array(c0) * (1 - t) + np.array(c1) * t, out)
    return out


def font(size, bold=True, italic=False):
    cands = [("/System/Library/Fonts/Avenir Next.ttc", 2 if bold and not italic else (3 if italic else 7)),
             ("/System/Library/Fonts/HelveticaNeue.ttc", 1 if bold else 0)]
    for path, idx in cands:
        try:
            return ImageFont.truetype(path, size, index=idx)
        except Exception:
            continue
    return ImageFont.load_default()


def main():
    meta, h, mat = load_terrain()
    names = meta["materials"]
    ox, oz, cell = meta["originX"], meta["originZ"], meta["cell"]
    extent = (meta["nx"] - 1) * cell
    S = SIZE
    px_per_stud = S / extent

    def to_px(x, z):
        return ((x - ox) / extent * S, (z - oz) / extent * S)

    # resample to the output grid: heights bilinear, materials nearest
    H = np.array(Image.fromarray(h).resize((S, S), Image.BILINEAR), np.float32)
    M = np.array(Image.fromarray(mat).resize((S, S), Image.NEAREST))
    land = H > 0.15

    # hillshade (light from the north-west, 40 deg up); exaggerate relief for a readable map
    stud = extent / S
    Hs = H.copy()
    for _ in range(3):  # cheap separable blur: smooth the speckle out of the hillshade
        Hs = (np.roll(Hs, 1, 0) + np.roll(Hs, -1, 0) + np.roll(Hs, 2, 0) + np.roll(Hs, -2, 0) + Hs) / 5
        Hs = (np.roll(Hs, 1, 1) + np.roll(Hs, -1, 1) + np.roll(Hs, 2, 1) + np.roll(Hs, -2, 1) + Hs) / 5
    gz, gx = np.gradient(Hs * 1.6, stud)
    az, alt = math.radians(315), math.radians(40)
    lx, lz, ly = math.sin(az) * math.cos(alt), -math.cos(az) * math.cos(alt), math.sin(alt)
    nrm = np.sqrt(gx * gx + gz * gz + 1)
    shade = np.clip((-gx * lx - gz * lz + ly) / nrm, 0, 1)
    slope = np.degrees(np.arctan(np.sqrt(gx * gx + gz * gz) / 1.6))

    lut = np.array([MAT_RGB.get(n, (150, 150, 150)) for n in names], np.float32)
    base = lut[M]
    # elevation tint: lowlands richer, moor tops paler
    elev = np.clip(H / 320, 0, 1)[..., None]
    base = base * (1 - 0.18 * elev) + np.array([236, 230, 210], np.float32) * 0.18 * elev
    # cliffs: steep faces go to granite grey
    cliff = np.clip((slope - 32) / 18, 0, 1)[..., None]
    base = base * (1 - cliff) + np.array([118, 114, 106], np.float32) * cliff
    land_rgb = base * (0.84 + 0.24 * shade[..., None])

    depth = np.clip(-H, 0, None)
    sea = lerp_stops(depth)
    tint = np.array([SEABED_TINT.get(n, (200, 200, 180)) for n in names], np.float32)[M]
    see = np.clip(1 - depth / 22, 0, 1)[..., None] * 0.42
    sea = sea * (1 - see) + tint * see
    # gentle relief on the seabed too, so reefs and gullies read
    sea = sea * (0.86 + 0.22 * shade[..., None])

    rgb = np.where(land[..., None], land_rgb, sea)

    # depth contours (5, 10, 20, 40 m)
    for d, a in ((15, 0.14), (60, 0.08)):
        band = np.abs(depth - d) < 0.9 * (stud / 2.5)
        edge = band & ~land
        rgb[edge] = rgb[edge] * (1 - a) + np.array([200, 236, 240]) * a
    # surf line and coast edge
    land_img = Image.fromarray((land * 255).astype(np.uint8))
    grow = np.array(land_img.filter(ImageFilter.MaxFilter(5))) > 0
    shrink = np.array(land_img.filter(ImageFilter.MinFilter(3))) > 0
    surf = grow & ~land
    rgb[surf] = rgb[surf] * 0.35 + np.array([236, 248, 248]) * 0.65
    coast = land & ~shrink
    rgb[coast] = rgb[coast] * 0.72 + np.array([70, 64, 50]) * 0.28

    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")
    k = px_per_stud

    # the greybox harbour (map/Build.luau): breakwater arms at x = +-320 (z -20 .. 368), cross arms to the
    # 60-stud mouth at x = +-30, Harbour Light on the east head, the quay along the town front
    wall, wall_edge = (190, 180, 160, 255), (52, 48, 42, 255)
    w = 16 * k
    for side in (-1, 1):
        d.line([to_px(side * 320, -20), to_px(side * 320, 368)], fill=wall_edge, width=max(5, int(w) + 3))
        d.line([to_px(side * 320, 368), to_px(side * 30, 368)], fill=wall_edge, width=max(5, int(w) + 3))
    for side in (-1, 1):
        d.line([to_px(side * 320, -20), to_px(side * 320, 368)], fill=wall, width=max(3, int(w)))
        d.line([to_px(side * 320, 368), to_px(side * 30, 368)], fill=wall, width=max(3, int(w)))
    roads, parks = parse_world_config()
    for p in parks:
        cx, cz = p["center"]
        sx, sz = p["size"]
        a = math.radians(p["yaw"])
        corners = []
        for ux, uz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            x, z = ux * sx / 2, uz * sz / 2
            corners.append(to_px(cx + x * math.cos(a) - z * math.sin(a), cz + x * math.sin(a) + z * math.cos(a)))
        d.polygon(corners, fill=(96, 98, 104, 255) if p["surface"] == "Asphalt" else (160, 140, 104, 255),
                  outline=(230, 228, 220, 255))
    # roads: casing then fill, minor tracks thinner and sandy
    for r in roads:
        pts = [to_px(x, z) for x, z in r["points"]]
        wpx = max(9.0, r["width"] * k * 1.4)
        track = r["surface"] in ("Ground", "Sand")
        d.line(pts, fill=(60, 60, 60, 255) if not track else (110, 90, 60, 255), width=int(wpx + 4), joint="curve")
        d.line(pts, fill=(250, 245, 230, 255) if not track else (214, 190, 140, 255), width=int(wpx), joint="curve")

    # place labels
    def label(text, x, z, size, colour, italic=False, spacing=0, left=False):
        f = font(size, bold=not italic, italic=italic)
        px, pz = to_px(x, z)
        if spacing:
            text = (" " * spacing).join(text)
        bb = d.textbbox((0, 0), text, font=f)
        tx, tz = (px if left else px - (bb[2] - bb[0]) / 2), pz - (bb[3] - bb[1]) / 2
        halo = (10, 25, 45, 235) if not italic else (8, 34, 64, 215)
        d.text((tx, tz), text, font=f, fill=colour, stroke_width=max(3, size // 7), stroke_fill=halo)

    def dot(x, z, colour, r=6):
        px, pz = to_px(x, z)
        d.ellipse([px - r, pz - r, px + r, pz + r], fill=colour, outline=(20, 20, 20, 255), width=2)

    land_c, sea_c, minor = (255, 248, 232, 255), (196, 236, 246, 255), (238, 232, 214, 255)
    dot(44, 368, (255, 214, 90, 255))
    dot(1800, 1750, (255, 214, 90, 255))
    region = (235, 240, 220, 255)
    label("PORT HAVEN", 0, -250, 48, land_c)
    label("Calm Bay", 0, 170, 38, sea_c, italic=True)
    label("Harbour Mouth", 0, 450, 36, sea_c, italic=True)
    label("Harbour Light", 64, 322, 34, minor, left=True)
    label("Sandy Point", 560, 530, 36, minor)
    label("HAVEN SANDS", 1080, 210, 40, land_c)
    label("Haven Head", 1560, 560, 36, minor)
    label("SKERRY ISLE", 1800, 1660, 40, land_c)
    label("Skerry Light outpost", 1800, 1850, 30, minor)
    label("The Skerries", 2060, 1380, 34, sea_c, italic=True)
    label("West Ledges", -1200, 470, 36, sea_c, italic=True)
    label("GREAT GALE", -1300, -1500, 64, region, spacing=1)
    label("OPEN SEA", 0, 1900, 60, sea_c, italic=True)
    label("Gannet Rock outpost >", 2150, 2440, 30, sea_c, italic=True)
    label("< Tempest Point Light", -2150, 600, 30, minor)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, optimize=True)
    # Roblox serves images at up to 1024 px, so the full map is also cut into 2 x 2 tiles of 1024 px
    # (MapConfig.Tiles, row-major from the north-west) to keep 2.5 studs per pixel in game.
    t = S // 2
    for r in range(2):
        for c in range(2):
            img.crop((c * t, r * t, (c + 1) * t, (r + 1) * t)).save(OUT.replace(".png", f"_r{r}c{c}.png"), optimize=True)
    prev = arg("--preview", None)
    if prev:
        p = os.path.join(ROOT, prev)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        img.resize((768, 768), Image.LANCZOS).save(p)
    print(f"wrote {OUT} ({S} px)")
    print(f"transform: u = (x - {ox}) / {extent}, v = (z - {oz}) / {extent}  ({extent / S:.4f} studs/px)")


if __name__ == "__main__":
    main()
