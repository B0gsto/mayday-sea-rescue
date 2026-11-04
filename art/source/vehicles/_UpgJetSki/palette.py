"""Flat palette atlas for M_Upg_JetSki: colours from the owner-cleared concept (artifact 236fbf08), per-cell roughness and metal.

8 x 8 grid at 1024 px. UV rows 0-4 are flat cells (index = order below, row 0 at v = 0); the top of the atlas holds the two
printed pieces: the RESCUE strip and the shark-face sticker. System python3 (Pillow):

    python3 art/source/vehicles/_UpgJetSki/palette.py build/prod/_UpgJetSki/textures
"""
GRID, SIZE = 8, 1024
RGH_ABS = 0.3

# name: (hex, roughness, metal)
COLOURS = {
    "FinGrey": ("8E989F", RGH_ABS, 0), "ToothWhite": ("FBF9F2", RGH_ABS, 0), "HullCharcoal": ("26282C", 0.36, 0),
    "BrickOrange": ("DD6B2C", RGH_ABS, 0), "BrickWhite": ("F1F0EA", RGH_ABS, 0), "BrickNavy": ("25395C", RGH_ABS, 0),
    "BrickDark": ("4A5158", RGH_ABS, 0), "Chrome": ("E8ECEF", 0.08, 1), "FlameRed": ("E2261A", 0.16, 0),
    "FlameOrange": ("FF7A12", 0.16, 0), "FlameYellow": ("FFD21E", 0.16, 0), "BananaYellow": ("F7CC2E", RGH_ABS, 0),
    "BananaTip": ("5C4720", RGH_ABS, 0), "BrickRed": ("D0302A", RGH_ABS, 0), "Rope": ("E9DFC4", 0.9, 0),
    "BullGrey": ("454C54", RGH_ABS, 0), "HornCream": ("EEE1BE", RGH_ABS, 0), "HornTip": ("3B3430", RGH_ABS, 0),
    "BrickGrey": ("A3ABB1", RGH_ABS, 0), "BulbRed": ("C8352E", 0.42, 0), "GemRed": ("D2302A", 0.08, 0),
    "Gold": ("E2AC36", 0.18, 1), "BrickYellow": ("F4C01E", RGH_ABS, 0),
    # preview-only stand-in rider (never exported)
    "VestYellow": ("FFE11F", RGH_ABS, 0), "SuitNavy": ("2C3A4A", RGH_ABS, 0), "Skin": ("EDC096", RGH_ABS, 0),
    "Visor": ("1E2428", 0.05, 0),
}
CELL = {name: i for i, name in enumerate(COLOURS)}

# atlas regions (u0, v0, u1, v1), v up
RESCUE_UV = (0.0, 0.875, 1.0, 1.0)      # 1024 x 128
FACE_UV = (0.0, 0.625, 0.5, 0.875)      # 512 x 256
FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"


def _rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _quad(p0, c, p1, n=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p1[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p1[1]) for t in (k / n for k in range(n + 1))]


def face_outline():
    """Sticker outline in (u, v), the concept's canvas path."""
    return (_quad((0, .42), (.02, .92), (.2, .97)) + _quad((.97, .97), (1, .97), (1, .85))
            + _quad((1, .1), (1, .03), (.94, .03)) + _quad((.25, .03), (.02, .05), (0, .42)))


def mouth_upper(s):
    import math
    return .6 + .1 * math.sin(math.pi * s)


def mouth_lower(s):
    import math
    return .56 - .38 * math.sin(math.pi * s) ** .9


def mouth_u(s):
    return .08 + .72 * s


def _face():
    from PIL import Image, ImageDraw
    k = 4
    W, H = 512 * k, 256 * k
    im = Image.new("RGB", (W, H), _rgb("8E989F"))    # grey to the edge: the mesh is cut to the outline, no alpha
    d = ImageDraw.Draw(im)
    P = lambda u, v: (u * W, (1 - v) * H)
    d.polygon([P(*p) for p in _quad((.02, .38), (.4, 0), (.98, .12)) + [(.98, .03), (.25, .03)]], fill=_rgb("E9ECEC"))
    n = 40
    mouth = [P(mouth_u(i / n), mouth_upper(i / n)) for i in range(n + 1)] + [P(mouth_u(i / n), mouth_lower(i / n)) for i in range(n, -1, -1)]
    d.polygon(mouth, fill=_rgb("5A1A24"))
    d.line(mouth + mouth[:2], fill=_rgb("E58C8C"), width=10 * k, joint="curve")
    cx, cy = P(.46, .4)
    d.ellipse((cx - 60 * k, cy - 22 * k, cx + 60 * k, cy + 22 * k), fill=_rgb("3A1016"))
    return im.resize((512, 256), Image.LANCZOS)


def _rescue():
    from PIL import Image, ImageDraw, ImageFont
    k = 4
    W, H = 1024 * k, 128 * k
    im = Image.new("RGB", (W, H), _rgb("F1F0EA"))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 100 * k)
    d.text((W / 2, H / 2), "RESCUE", font=f, fill=_rgb("C8352E"), anchor="mm")
    return im.resize((1024, 128), Image.LANCZOS)


def write_maps(out_dir, name="UpgJetSki", set_name="Brick"):
    import os
    from PIL import Image
    os.makedirs(out_dir, exist_ok=True)
    cell = SIZE // GRID
    alb = Image.new("RGB", (SIZE, SIZE), _rgb("8E989F"))
    rgh = Image.new("RGB", (SIZE, SIZE), (int(RGH_ABS * 255),) * 3)
    met = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    for nm, (hx, r, m) in COLOURS.items():
        i = CELL[nm]
        col, row = i % GRID, GRID - 1 - i // GRID     # image row 0 is the top; cell 0 is bottom-left in UV
        box = (col * cell, row * cell, (col + 1) * cell, (row + 1) * cell)
        alb.paste(_rgb(hx), box)
        rgh.paste((int(r * 255),) * 3, box)
        met.paste((int(m * 255),) * 3, box)
    alb.paste(_rescue(), (0, 0))
    alb.paste(_face(), (0, 128))
    stem = os.path.join(out_dir, "T_%s_%s_" % (name, set_name))
    alb.save(stem + "ALB.png")
    rgh.save(stem + "RGH.png")
    met.save(stem + "MET.png")
    Image.new("RGB", (SIZE, SIZE), (128, 128, 255)).save(stem + "NOR.png")
    return stem + "ALB.png"


if __name__ == "__main__":
    import sys
    print(write_maps(sys.argv[1]))
