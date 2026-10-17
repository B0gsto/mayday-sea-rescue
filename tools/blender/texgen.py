"""Atlas rectangle maths for the shared prop, kit, street and foliage atlases and the trim sheets (docs/12 1.1).

Pure Python: imports in Blender and in the system python3. Ported from Gulp's texgen.py; the creature layouts and
placeholder stamping are dropped. Sizes are pixels at MASTER (4096) or the
shipped size (SHIP_SIZE by default, EXPORT_CAP at most); UV rects are (u0, v0, u1, v1), V up.
"""
from common import MASTER, SHIP_SIZE


def margin_px(size):
    """Bake padding: 16 px at 1024, 64 at 4096, never under 2 (Gulp's 06 5.5 rule, scaled)."""
    return max(2, size // 64)


def inner(rect, size):
    """`rect` shrunk by the bake margin of a `size`-pixel texture."""
    m = margin_px(size) / float(size)
    u0, v0, u1, v1 = rect
    return (u0 + m, v0 + m, u1 - m, v1 - m)


def atlas_rects(items, atlas, cap=MASTER):
    """Shelf-pack cells (name, w, h) in pixels into an `atlas`-pixel square, tallest first.
    Returns {name: (u0, v0, u1, v1)}; raises ValueError when they do not fit or the atlas is over `cap`."""
    if atlas > cap:
        raise ValueError("atlas %d is over the %d ceiling" % (atlas, cap))
    out, x, y, row_h = {}, 0, 0, 0
    for name, w, h in sorted(items, key=lambda it: (-it[2], -it[1], it[0])):
        if w > atlas:
            raise ValueError("%s (%dx%d) does not fit in a %d atlas" % (name, w, h, atlas))
        if x + w > atlas:
            x, y, row_h = 0, y + row_h, 0
        if y + h > atlas:
            raise ValueError("%s (%dx%d) does not fit in a %d atlas" % (name, w, h, atlas))
        out[name] = (x / atlas, 1.0 - (y + h) / atlas, (x + w) / atlas, 1.0 - y / atlas)
        x += w
        row_h = max(row_h, h)
    return out


def scale_rect_to(rect, master=MASTER, cap=SHIP_SIZE):
    """A cell keeps its UV rect when the atlas is downsized; this returns its pixel box at `cap` and whether its edges
    still land on whole pixels (cells should be multiples of master/cap pixels so a downsize does not bleed)."""
    u0, v0, u1, v1 = rect
    px = [c * cap for c in (u0, v0, u1, v1)]
    return [int(round(p)) for p in px], all(abs(p - round(p)) < 1e-6 for p in px)


def remap_uv(uv, rect):
    """A 0..1 UV moved into an atlas cell."""
    u0, v0, u1, v1 = rect
    return (u0 + (u1 - u0) * uv[0], v0 + (v1 - v0) * uv[1])


def texel_density_px_per_stud(uv_area, surface_area, size):
    """Pixels per stud: sqrt(texture pixels used / surface area in square studs)."""
    return (uv_area * size * size / surface_area) ** 0.5 if surface_area > 0 else 0.0


def texture_size_for(target_px_per_stud, surface_area, uv_fill=0.7, cap=MASTER):
    """Smallest power-of-two texture that hits a texel density for a surface (stud^2) at a UV fill share."""
    need = (target_px_per_stud ** 2 * surface_area / uv_fill) ** 0.5
    size = 64
    while size < need and size < cap:
        size *= 2
    return size
