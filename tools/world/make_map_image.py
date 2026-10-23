#!/usr/bin/env python3
"""Render the Gale Isles top-down map (the GTA-style minimap / full map texture) from the terrain bake.

usage: python3 tools/world/make_map_image.py [--out art/map/gale_isles_map.png] [--size 2048] [--preview PATH] [--labels]

Inputs (read only): map/generated/terrain.json + terrain_height.i16 + terrain_material.u8 (gen_terrain.py),
src/shared/Config/WorldConfig.luau (road splines, car parks), the breakwater arms from src/server/World/Harbour.luau.

World -> image (north up, the same frame as the bake: rows are +Z = south):
    u = (x - originX) / extent,  v = (z - originZ) / extent,  extent = (nx - 1) * cell  (5120 studs)
    pixel = (u * size, v * size)
The transform is printed and must match src/shared/Config/MapConfig.luau (Origin, Extent).

Look: sea depth shading (shallow aqua to deep navy) with depth contours and a surf line, the seabed showing
through the shallows (reefs, kelp, sand), land coloured by terrain material with elevation tint and NW
multi-directional hillshade (3x relief), subtle hypsometric tint and 5 m / 20 m contours, cliffs greyed by
slope, the breakwater and harbour, roads with a casing on top, car parks. Place names live in
MapConfig.Places and are drawn by the game; --labels bakes them in for a preview. Needs numpy and Pillow; no heavy slot (about 5 s)."""

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
    # MaterialVariant slots (gen_terrain.py): shingle, straw / olive / worn turf, rippled sand, wrack
    "CrackedLava": (150, 142, 128), "Snow": (160, 152, 98), "WoodPlanks": (96, 126, 66), "Brick": (132, 124, 86),
    "Glacier": (226, 208, 160), "Ice": (156, 138, 100),
}
SEABED_TINT = {  # how the seabed reads through shallow water
    "Sand": (232, 222, 180), "Limestone": (214, 208, 186), "Rock": (110, 116, 108),
    "Slate": (60, 84, 58), "Basalt": (70, 74, 74), "Mud": (120, 110, 84),
    "Salt": (232, 222, 180), "CrackedLava": (150, 142, 128), "Glacier": (232, 222, 180),  # seabed sand, shingle, ripples
}
DEPTH_STOPS = [  # depth below sea level (studs, 3 studs = 1 m) -> colour
    (0, (120, 214, 214)), (6, (82, 190, 204)), (18, (44, 150, 186)), (40, (26, 104, 156)),
    (80, (16, 70, 124)), (165, (8, 38, 82)),
]


RELIEF_Z = 3.0  # vertical exaggeration for the hillshade
HYPSO_STOPS = [  # elevation 0..1 (of 325 studs) -> tint blended over the material colour
    (0.0, (96, 132, 74)), (0.25, (120, 136, 82)), (0.55, (150, 144, 104)), (0.8, (186, 178, 150)),
    (1.0, (222, 218, 204)),
]


def lerp_rgb(t, stops):
    out = np.zeros(t.shape + (3,), np.float32)
    out[...] = stops[0][1]
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        k = np.clip((t - t0) / (t1 - t0), 0, 1)[..., None]
        sel = (t >= t0)[..., None]
        out = np.where(sel, np.array(c0) * (1 - k) + np.array(c1) * k, out)
    return out


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
    cp_src = src[src.index("CarParks = {"): src.index("Farms = {") if "Farms = {" in src else src.index("Points = {")]
    for block in re.split(r"\n\t\t\{", cp_src)[1:]:
        c = re.search(vec, block)
        size = re.search(r"size = \{\s*([\d.]+),\s*([\d.]+)", block)
        yaw = re.search(r"yaw = (-?[\d.]+)", block)
        surface = re.search(r'surface = "(\w+)"', block)
        if c and size:
            parks.append({"center": (float(c.group(1)), float(c.group(3))),
                          "size": (float(size.group(1)), float(size.group(2))),
                          "yaw": float(yaw.group(1)) if yaw else 0, "surface": surface.group(1) if surface else "Asphalt"})
    towns = []  # built-up rect per town grid: avenues (x) and streets (z offsets from origin), minus keep rects
    if "Towns = {" in src:
        for block in re.split(r"\n\t\t\{", src[src.index("Towns = {"): src.index("CarParks = {")])[1:]:
            o = re.search(vec, block)
            av = re.search(r"avenues = \{([^}]*)\}", block)
            st = re.search(r"streets = \{([^}]*)\}", block)
            if o and av and st:
                xs = [float(v) for v in re.findall(r"-?[\d.]+", av.group(1))]
                zs = [float(o.group(3)) + float(v) for v in re.findall(r"-?[\d.]+", st.group(1))]
                keep = [tuple(map(float, k)) for k in re.findall(r"\{\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+),?\s*\}", block[block.find("keep = {"):] if "keep = {" in block else "")]
                towns.append({"rect": (min(xs), min(zs), max(xs), float(o.group(3))), "keep": keep})
    return roads, parks, towns


def lerp_stops(depth):
    out = np.zeros(depth.shape + (3,), np.float32)
    d = np.clip(depth, 0, DEPTH_STOPS[-1][0])
    for (d0, c0), (d1, c1) in zip(DEPTH_STOPS, DEPTH_STOPS[1:]):
        t = np.clip((d - d0) / (d1 - d0), 0, 1)[..., None]
        sel = ((d >= d0) & (d <= d1))[..., None]
        out = np.where(sel, np.array(c0) * (1 - t) + np.array(c1) * t, out)
    return out


def parse_places():
    """MapConfig.Places rows: { text = "...", x = N, z = N, kind = "...", left = true? }."""
    src = open(os.path.join(ROOT, "src", "shared", "Config", "MapConfig.luau")).read()
    body = src[src.index("Places = {"):]
    body = body[:body.index("\n\t},")]
    rows = []
    for m in re.finditer(r'\{ text = "([^"]+)", x = (-?[\d.]+), z = (-?[\d.]+), kind = "(\w+)"(, left = true)? \}', body):
        rows.append({"text": m.group(1), "x": float(m.group(2)), "z": float(m.group(3)), "kind": m.group(4),
                     "left": m.group(5) is not None})
    return rows


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

    # relief (GTA-like, muted): a multi-directional hillshade (key light from the north-west, softer
    # fills from the west and north, 40 deg up) on a 3x vertical exaggeration so the moors and gullies
    # read at map scale; shade is taken relative to flat ground so plains keep their colour
    stud = extent / S
    Hs = H.copy()
    for _ in range(3):  # cheap separable blur: smooth the speckle out of the hillshade
        Hs = (np.roll(Hs, 1, 0) + np.roll(Hs, -1, 0) + np.roll(Hs, 2, 0) + np.roll(Hs, -2, 0) + Hs) / 5
        Hs = (np.roll(Hs, 1, 1) + np.roll(Hs, -1, 1) + np.roll(Hs, 2, 1) + np.roll(Hs, -2, 1) + Hs) / 5
    gz, gx = np.gradient(Hs * RELIEF_Z, stud)
    nrm = np.sqrt(gx * gx + gz * gz + 1)
    alt = math.radians(40)
    shade = np.zeros_like(H)
    for az_deg, wgt in ((315, 0.6), (270, 0.2), (0, 0.2)):
        az = math.radians(az_deg)
        lx, lz, ly = math.sin(az) * math.cos(alt), -math.cos(az) * math.cos(alt), math.sin(alt)
        shade += wgt * np.clip((-gx * lx - gz * lz + ly) / nrm, 0, 1)
    rel = shade - math.sin(alt)  # 0 on flat ground, + toward the light, - away
    slope = np.degrees(np.arctan(np.sqrt(gx * gx + gz * gz) / RELIEF_Z))

    lut = np.array([MAT_RGB.get(n, (150, 150, 150)) for n in names], np.float32)
    base = lut[M]
    # hypsometric tint, subtle: lowland greens deepen a touch, the uplands drift to olive heath and
    # the tops to pale moor (blended over the material colour, never replacing it)
    elev = np.clip(H / 325, 0, 1)
    hyp = lerp_rgb(elev, HYPSO_STOPS)
    hw = (0.10 + 0.22 * elev)[..., None]
    base = base * (1 - hw) + hyp * hw
    # cliffs: steep faces go to granite grey
    cliff = np.clip((slope - 32) / 18, 0, 1)[..., None]
    base = base * (1 - cliff) + np.array([118, 114, 106], np.float32) * cliff
    land_rgb = base * np.clip(1 + 1.05 * rel, 0.55, 1.3)[..., None]
    # elevation contours: a hairline every 5 m (15 studs), every 4th (20 m) a little stronger; the
    # width test uses the gradient so the lines stay ~1 px on gentle and steep ground alike
    grad = np.sqrt(gx * gx + gz * gz) / RELIEF_Z * stud + 1e-4  # studs of height per pixel
    for interval, a in ((15, 0.10), (60, 0.20)):
        q = Hs / interval
        dist_px = np.abs(q - np.round(q)) * interval / grad
        line = (dist_px < 0.6) & (Hs > interval * 0.5) & (slope < 40)
        land_rgb[line] = land_rgb[line] * (1 - a) + np.array([62, 56, 40], np.float32) * a

    depth = np.clip(-H, 0, None)
    sea = lerp_stops(depth)
    tint = np.array([SEABED_TINT.get(n, (200, 200, 180)) for n in names], np.float32)[M]
    see = np.clip(1 - depth / 22, 0, 1)[..., None] * 0.42
    sea = sea * (1 - see) + tint * see
    # gentle relief on the seabed too, so reefs and gullies read
    sea = sea * np.clip(1 + 0.6 * rel, 0.75, 1.15)[..., None]

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

    # the harbour breakwaters (src/server/World/Harbour.luau breakwaterLine): each arm runs root -> knee at x +-x,
    # dog-legs in to the head, then out to the 60-stud mouth at x +-mouth; granite with a dark rock-armour edge
    hb = open(os.path.join(ROOT, "src", "server", "World", "Harbour.luau")).read()
    B = {k: float(v) for k, v in re.findall(r"(\w+) = (-?[\d.]+)", re.search(r"Harbour\.BREAKWATER = \{([^}]*)\}", hb).group(1))}
    wall, wall_edge = (190, 180, 160, 255), (52, 48, 42, 255)
    w = B["w"] * k
    arms = [[to_px(s * B["x"], B["root"]), to_px(s * B["x"], B["knee"]), to_px(s * B["head"], B["far"]),
             to_px(s * B["mouth"], B["far"])] for s in (-1, 1)]
    for fill, width in ((wall_edge, max(5, int(w) + 3)), (wall, max(3, int(w)))):
        for pts in arms:
            d.line(pts, fill=fill, width=width, joint="curve")
    roads, parks, towns = parse_world_config()
    for t in towns:  # built-up blocks in a pale stone tone; kept rects (squares, greens) stay terrain
        x0, z0, x1, z1 = t["rect"]
        d.rectangle([to_px(x0, z0), to_px(x1, z1)], fill=(206, 198, 184, 255))
        for kx0, kz0, kx1, kz1 in t["keep"]:
            d.rectangle([to_px(kx0, kz0), to_px(kx1, kz1)], fill=tuple(int(c) for c in rgb[int(to_px((kx0 + kx1) / 2, (kz0 + kz1) / 2)[1]), int(to_px((kx0 + kx1) / 2, (kz0 + kz1) / 2)[0])]) + (255,))
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
    for casing in (True, False):  # all casings first so a later road never cuts an earlier one at a junction
        for r in roads:
            pts = [to_px(x, z) for x, z in r["points"]]
            wpx = max(9.0, r["width"] * k * 1.4)
            track = r["surface"] in ("Ground", "Sand")
            if casing:
                d.line(pts, fill=(60, 60, 60, 255) if not track else (110, 90, 60, 255), width=int(wpx + 4), joint="curve")
            else:
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

    dot(44, 360, (255, 214, 90, 255))  # Harbour Light, east pierhead
    dot(-36, 360, (220, 50, 40, 255), r=4)  # west pierhead light (Harbour.luau: x -(mouth + 6))
    dot(1800, 1750, (255, 214, 90, 255))
    # Place names are drawn live by MapController from MapConfig.Places (so they stay screen-size,
    # dodge the legend / title / top bar and never sit under a panel). --labels bakes them in too,
    # for a stand-alone preview.
    if "--labels" in sys.argv:
        style = {  # kind -> (px at 2048, colour, italic, letter spacing)
            "region": (64, (235, 240, 220, 255), False, 1), "town": (46, (255, 248, 232, 255), False, 0),
            "place": (34, (238, 232, 214, 255), False, 0), "water": (36, (196, 236, 246, 255), True, 0),
            "street": (30, (238, 232, 214, 255), False, 0),
        }
        for p in parse_places():
            size, colour, italic, spacing = style[p["kind"]]
            label(p["text"], p["x"], p["z"], int(size * S / 2048), colour, italic=italic, spacing=spacing,
                  left=p["left"])

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
