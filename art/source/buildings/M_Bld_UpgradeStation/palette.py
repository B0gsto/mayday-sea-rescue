"""One 1024 px atlas for M_Bld_UpgradeStation. Bottom half: 16 x 8 flat cells of 64 px (name: hex, roughness, metalness).
Top half: two 512 px stud patches (quay grey, baseplate green), each 8 x 8 studs plus a 16 px gutter, so the big decks show
true 1-stud-pitch studs from the normal map for no triangles. Roblox ignores FBX material colours, so colour lives here.

    python3 art/source/buildings/M_Bld_UpgradeStation/palette.py <out_dir>     writes T_UpgradeStation_Brick_{ALB,NOR,RGH,MET}.png
"""
COLOURS = {
    "red": ("#D8302A", .32, 0), "white": ("#F4F4F0", .35, 0), "yellow": ("#F5C518", .32, 0), "chrome": ("#C4CCD6", .18, 1),
    "handle": ("#C46A2B", .4, 0), "iron": ("#4A4F55", .35, .55), "ironLt": ("#6E767F", .35, .55), "green": ("#4CA94C", .45, 0),
    "leaf": ("#2F8E3F", .45, 0), "quay": ("#A0A5A9", .5, 0), "wall": ("#8A929A", .5, 0), "deep": ("#5C646D", .55, 0),
    "blue": ("#2A6FD6", .32, 0), "navy": ("#1C3F78", .35, 0), "black": ("#2B2D31", .4, 0), "rubber": ("#2B2D31", .8, 0),
    "brown": ("#7A4A2A", .5, 0), "wood": ("#C98E52", .5, 0), "orange": ("#FF6A13", .35, 0), "console": ("#5A6168", .4, 0),
    "brass": ("#E0A526", .3, .55), "glass": ("#A8DBF5", .06, 0), "portLt": ("#FF3B30", .3, 0), "stbdLt": ("#27E05A", .3, 0),
    "bulb": ("#FFE9A8", .3, 0), "btn": ("#2BD94F", .35, 0), "fir1": ("#3E9E48", .45, 0), "fir2": ("#256F34", .45, 0),
    "palm": ("#A0703F", .5, 0), "crate": ("#D39A5E", .5, 0), "crateDk": ("#8E5A2E", .55, 0), "screen": ("#2F7FE0", .4, 0),
    "ink": ("#1B2430", .4, 0), "steel": ("#DCE1E6", .62, 0),
}
CELL = {k: i for i, k in enumerate(COLOURS)}
GRID, ROWS, SIZE = 16, 8, 1024
PATCH = {"quay": 0, "green": 1}      # patch index, left to right in the top half
PATCH_STUDS, PATCH_GUTTER = 8, 16
assert len(COLOURS) <= GRID * ROWS


def cell_uv(c, inset=.1):
    col, row = c % GRID, c // GRID
    return (col + inset) / GRID, (row + inset) / GRID, (col + 1 - inset) / GRID, (row + 1 - inset) / GRID


def patch_uv(name, sx, sz):
    """UV of the point sx, sz studs from a plate's corner (0..PATCH_STUDS), in the patch of colour `name`."""
    span = (.5 * SIZE - 2 * PATCH_GUTTER) / SIZE
    g = PATCH_GUTTER / SIZE
    return PATCH[name] * .5 + g + sx / PATCH_STUDS * span, .5 + g + sz / PATCH_STUDS * span


def _rgb(hx):
    return tuple(int(hx[k:k + 2], 16) for k in (1, 3, 5))


def write_maps(out_dir, name="UpgradeStation", set_name="Brick"):
    import os

    import numpy as np
    from PIL import Image

    S, cell = SIZE, SIZE // GRID
    alb, rgh, met = np.zeros((S, S, 3), np.uint8), np.zeros((S, S), np.uint8), np.zeros((S, S), np.uint8)
    nor = np.zeros((S, S, 3), np.float32)
    nor[..., 2] = 1
    for i, (hx, r, m) in enumerate(COLOURS.values()):
        x, y = (i % GRID) * cell, S - cell - (i // GRID) * cell    # image row 0 is the top, v = 0 the bottom row
        alb[y:y + cell, x:x + cell] = _rgb(hx)
        rgh[y:y + cell, x:x + cell] = round(r * 255)
        met[y:y + cell, x:x + cell] = round(m * 255)
    px = (S // 2 - 2 * PATCH_GUTTER) / PATCH_STUDS                  # pixels per stud
    for key, p in PATCH.items():
        x0 = p * S // 2
        yy, xx = np.mgrid[0:S // 2, 0:S // 2]
        u = (xx + .5 - PATCH_GUTTER) / px
        v = (S // 2 - yy - .5 - PATCH_GUTTER) / px                  # v up
        d = np.hypot((u % 1) - .5, (v % 1) - .5)                    # distance to the nearest stud centre, in studs
        h = np.clip((.31 - d) / .04, 0, 1) * .2                     # stud: 0.6 wide, 0.2 tall, soft 0.04 shoulder
        gy, gx = np.gradient(h * px)
        n = np.dstack((-gx, gy, np.ones_like(h)))                   # OpenGL: +G up in v, and image rows run down
        n /= np.linalg.norm(n, axis=2, keepdims=True)
        nor[0:S // 2, x0:x0 + S // 2] = n
        base = np.array(_rgb(COLOURS[key][0]), np.float32)
        contact = np.clip((.45 - d) / .14, 0, 1) * (d >= .31)       # soft contact shade round each stud
        top = np.clip((.31 - d) / .04, 0, 1)                        # stud tops a touch lighter
        shade = 1 - .22 * contact + .06 * top
        alb[0:S // 2, x0:x0 + S // 2] = np.clip(base[None, None] * shade[..., None], 0, 255).astype(np.uint8)
        rgh[0:S // 2, x0:x0 + S // 2] = round(COLOURS[key][1] * 255)
    os.makedirs(out_dir, exist_ok=True)
    stem = os.path.join(out_dir, "T_%s_%s_" % (name, set_name))
    Image.fromarray(alb).save(stem + "ALB.png")
    Image.fromarray(np.clip((nor * .5 + .5) * 255, 0, 255).astype(np.uint8)).save(stem + "NOR.png")
    Image.fromarray(rgh).convert("RGB").save(stem + "RGH.png")
    Image.fromarray(met).convert("RGB").save(stem + "MET.png")
    return stem + "ALB.png"


if __name__ == "__main__":
    import sys
    print(write_maps(sys.argv[1]))
