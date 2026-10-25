#!/usr/bin/env python3
"""Render the Gale Isles top-down map (the GTA-style minimap / full map texture) from the terrain bake.

usage: python3 tools/world/make_map_image.py [--out art/map/gale_isles_map.png] [--size 4096] [--preview PATH] [--labels]

Inputs (read only): map/generated/terrain.json + the main and island-window height / material grids
(gen_terrain.py). The outer islands come from the bake; the six player islands are Lego plates (Parts, not
terrain), drawn from layout.RING with the neighbour bridges (mirroring HubLayout); place names from MapConfig.Places
(--labels).

World -> image (north up, the same frame as the bake: rows are +Z = south), the whole archipelago canvas:
    u = (x + 7168) / 14336,  v = (z + 7168) / 14336
    pixel = (u * size, v * size); cut into 4 x 4 tiles <out>_r{row}c{col}.png
The transform is printed and must match src/shared/Config/MapConfig.luau (Origin, Extent).

Look: sea depth shading (shallow aqua to deep navy) with depth contours and a surf line, the seabed showing
through the shallows (reefs, kelp, sand), land coloured by terrain material with elevation tint and NW
multi-directional hillshade (3x relief), subtle hypsometric tint and 5 m / 20 m contours, cliffs greyed by
slope. Place names live in
MapConfig.Places and are drawn by the game; --labels bakes them in for a preview. Needs numpy and Pillow; no heavy slot (about 5 s)."""

import json, math, os, re, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GEN = os.path.join(ROOT, "map", "generated")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout as L  # noqa: E402


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


SIZE = int(arg("--size", "4096"))
CANVAS = 7168  # tools/world/layout.py MAP_CANVAS: the map covers x, z in +-CANVAS
FLOOR_Y = -165  # layout.SEABED_FLOOR_Y: the deep sea between the bake windows
TILES = 4  # TILES x TILES images of SIZE / TILES px (MapConfig.Tiles)
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


def composite(meta, S):
    """Every bake window (main + the docs/21 island windows) resampled onto the +-CANVAS map: heights bilinear,
    materials nearest. Between windows the deep sea is the flat floor; window sea fades into it over ~800 studs
    (abutting windows do not fade), so no window edge shows as a line."""
    names = meta["materials"]
    cell, stud = meta["cell"], 2 * CANVAS / S
    H = np.full((S, S), FLOOR_Y, np.float32)
    M = np.full((S, S), names.index("Salt"), np.uint8)
    inside = np.zeros((S, S), np.uint8)
    pc = -CANVAS + (np.arange(S) + 0.5) * stud  # pixel centres (x along columns, z along rows)
    for g in [meta] + meta.get("windows", []):
        nx, nz = g["nx"], g["nz"]
        h = np.fromfile(os.path.join(GEN, g["height"]), "<i2").reshape(nz, nx) / meta["heightScale"]
        m = np.fromfile(os.path.join(GEN, g["material"]), "u1").reshape(nz, nx)
        u, v = (pc - g["originX"]) / cell, (pc - g["originZ"]) / cell
        cols, rows = np.where((u >= 0) & (u <= nx - 1))[0], np.where((v >= 0) & (v <= nz - 1))[0]
        u, v = u[cols], v[rows]
        i, j = np.clip(u.astype(int), 0, nx - 2), np.clip(v.astype(int), 0, nz - 2)
        fu, fv = (u - i)[None, :], (v - j)[:, None]
        hh = (h[np.ix_(j, i)] * (1 - fu) * (1 - fv) + h[np.ix_(j, i + 1)] * fu * (1 - fv)
              + h[np.ix_(j + 1, i)] * (1 - fu) * fv + h[np.ix_(j + 1, i + 1)] * fu * fv)
        H[np.ix_(rows, cols)] = hh
        M[np.ix_(rows, cols)] = m[np.ix_(np.round(v).astype(int), np.round(u).astype(int))]
        inside[np.ix_(rows, cols)] = 255
    blur = np.array(Image.fromarray(inside).filter(ImageFilter.GaussianBlur(400 / stud)), np.float32) / 255
    w = np.clip(2 * blur - 1, 0, 1) * (inside > 0)
    H = np.where(H < 0, FLOOR_Y + (H - FLOOR_Y) * w, H).astype(np.float32)
    return H, M


def main():
    meta = json.load(open(os.path.join(GEN, "terrain.json")))
    names = meta["materials"]
    ox = oz = -CANVAS
    extent = 2 * CANVAS
    S = SIZE
    px_per_stud = S / extent

    def to_px(x, z):
        return ((x - ox) / extent * S, (z - oz) / extent * S)

    H, M = composite(meta, S)
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

    # docs/23 (p): the ring of six Lego-plate islands (HubLayout.IslandPlate rects) and the bridges between neighbours
    # (HubLayout.BRIDGE: crossing each bisector 400 out, 91 studs either side)
    e, ch, hw, head = L.RING["islandRadius"], 47, L.RING["notch"]["halfWidth"], L.RING["notch"]["head"]
    rects = [(-e + ch, -hw, -e + ch, e - ch), (hw, e - ch, -e + ch, e - ch), (-hw, hw, -e + ch, head),
             (-e + ch, e - ch, -e, -e + ch), (-e, -e + ch, -e + ch, e - ch), (e - ch, e, -e + ch, e - ch),
             (-e + ch, -hw, e - ch, e), (hw, e - ch, e - ch, e)]
    isl = L.PLAYER_ISLANDS
    for k, a in enumerate(isl):
        b = isl[(k + 1) % len(isl)]
        mx, mz = L.local(*L.CENTER, a["bearing"] + 30, 0, 400)
        dx, dz = a["center"][0] - b["center"][0], a["center"][1] - b["center"][1]
        n = math.hypot(dx, dz)
        d.line([to_px(mx + dx / n * 91, mz + dz / n * 91), to_px(mx - dx / n * 91, mz - dz / n * 91)],
               fill=(105, 64, 40, 255), width=max(2, round(12 * px_per_stud)))
    for grow, colour in ((3, (39, 92, 46, 255)), (0, (75, 151, 75, 255))):  # the trim, then the green slab
        for a in isl:
            for r0, r1, f0, f1 in rects:
                pts = [to_px(*L.local(*a["center"], a["bearing"], r, f))
                       for r, f in ((r0 - grow, f0 - grow), (r1 + grow, f0 - grow), (r1 + grow, f1 + grow),
                                    (r0 - grow, f1 + grow))]
                d.polygon(pts, fill=colour)
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
    # Roblox serves images at up to 1024 px, so the full map is also cut into TILES x TILES tiles of 1024 px
    # (MapConfig.Tiles, row-major from the north-west) to keep 3.5 studs per pixel in game.
    t = S // TILES
    for r in range(TILES):
        for c in range(TILES):
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
