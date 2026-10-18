"""Pure numpy packing for FX sheets (used by build_fx.py inside Blender and by repack.py outside it).

Cells are straight-alpha sRGB floats 0..1 (as Blender writes its PNGs). pack() lays them out in Roblox Grid order
(left to right, top to bottom), derives alpha from brightness for emissive sheets, lifts thin rain streaks, and
bleeds colour into transparent texels so mips do not pull dark fringes in.
"""
import numpy as np


def pack(cells, grid, kind):
    cell = cells[0].shape[0]
    size = cell * grid
    sheet = np.zeros((size, size, 4), np.float32)
    for i, px in enumerate(cells):
        r, c = divmod(i, grid)
        sheet[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell] = px
    if kind == "emissive":
        # additive sprite (LightEmission 1): alpha from brightness, colour normalised so colour * alpha == render
        rgb = np.clip(sheet[..., :3], 0, None)
        a = np.clip(rgb.max(axis=2) * 1.15, 0, 1)
        col = np.where(a[..., None] > 1e-4, np.clip(rgb / np.maximum(a[..., None], 1e-4), 0, 1), 0)
        sheet = np.dstack([col, a])
    a = sheet[..., 3]
    hi = np.percentile(a[a > 0.01], 99.5) if (a > 0.01).any() else 1.0
    if kind == "lit" and hi < 0.6:  # thin, fast streaks (rain): bring the exposure up so the streak reads
        sheet[..., 3] = np.clip(a * (0.9 / max(hi, 1e-3)), 0, 1) ** 0.6
    out = np.round(np.clip(sheet, 0, 1) * 255).astype(np.uint8)
    return edge_bleed(out, grid)


def edge_bleed(sheet, grid):
    out = sheet.copy()
    cell = sheet.shape[0] // grid
    for r in range(grid):
        for c in range(grid):
            blk = out[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell]
            vis = blk[..., 3] > 8
            if not vis.any():
                continue
            mean = blk[vis][:, :3].mean(axis=0)
            rgb = blk[..., :3].astype(np.float32)
            w = blk[..., 3:4].astype(np.float32) / 255.0
            pc, pw = rgb * w, w.copy()
            for _ in range(6):
                pc = (pc + np.roll(pc, 1, 0) + np.roll(pc, -1, 0) + np.roll(pc, 1, 1) + np.roll(pc, -1, 1)) / 5
                pw = (pw + np.roll(pw, 1, 0) + np.roll(pw, -1, 0) + np.roll(pw, 1, 1) + np.roll(pw, -1, 1)) / 5
            fill = np.where(pw > 1e-3, pc / np.maximum(pw, 1e-3), mean)
            hole = ~vis
            blk[..., :3][hole] = np.clip(fill[hole], 0, 255).astype(np.uint8)
    return out


def stats(sheet, grid):
    al = sheet[..., 3]
    cell = sheet.shape[0] // grid
    blocks = [al[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell] for r in range(grid) for c in range(grid)]
    cells = [int(b.max()) for b in blocks]
    edge = [int(max(b[0].max(), b[-1].max(), b[:, 0].max(), b[:, -1].max())) for b in blocks]
    return {"alpha_cover": round(float((al > 8).mean()), 4), "cell_alpha_max": cells, "cell_edge_alpha_max": edge,
            "empty_cells": sum(1 for c in cells if c <= 8)}
