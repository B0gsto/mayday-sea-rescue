"""M_Road_CornishHedge trim-set layout (pure python; read by build.py in Blender and hedgetex.py outside it).

One trim set, `T_CornishHedge_Stone_*` (1024 ship, 2048 master), three regions, all at the same master scale
(`PPM` pixels per metre of wall), so a box projection keeps one texel density across the asset:

  stone  (U along the wall, wraps every period; V = height above the ground, so weathering is baked where it belongs:
         splash and damp at the foot, moss under the turf lip, lichen up the face) - the granite facing-stone bed
  earth  the bare earth core, seen through the joints and on the end cuts: dark earth, packing stones, moss
  turf   the turf cap: the top surface, the overhanging lip and its damp underside

`region_rect` gives the cell in atlas UVs (v up), inset so bilinear filtering and mips never sample the neighbour.
The veg on top is not in this set: it is cards on the shared `T_FoliageLand_Main` atlas (see build.py).
"""
MASTER = 2048
SHIP = 1024
PPM = 707.0                       # master pixels per metre of wall, every region
INSET = 0.004                     # atlas-UV inset of every region (< 0.5 mip at 2048)
BLOCK = 0.02                      # guard band left between the regions

REGIONS = {
    # asset: (u0, v0, u1, v1) of the block this region owns (this asset owns its whole sheet)
    "stone": (0.000, 0.500, 1.000, 1.000),   # V covers 1.45 m of wall above the ground
    "earth": (0.000, 0.000, 0.395, 0.480),
    "turf":  (0.415, 0.000, 1.000, 0.480),
}


def region_rect(region, inset=INSET):
    """(u0, v0, u1, v1) of a region in atlas UVs, v up, inset so filtering stays inside the cell."""
    u0, v0, u1, v1 = REGIONS[region]
    du, dv = (u1 - u0) * inset, (v1 - v0) * inset
    return (u0 + du, v0 + dv, u1 - du, v1 - dv)


def span_m(region):
    """(metres along U, metres along V) of a region's full block at PPM (master pixels / PPM)."""
    u0, v0, u1, v1 = REGIONS[region]
    return ((u1 - u0) * MASTER / PPM, (v1 - v0) * MASTER / PPM)


def px_rect(region, size=MASTER):
    """(x0, y0, x1, y1) of a region in image pixels (row 0 = v 1, as texlib writes it)."""
    u0, v0, u1, v1 = REGIONS[region]
    return (int(round(u0 * size)), int(round((1.0 - v1) * size)),
            int(round(u1 * size)), int(round((1.0 - v0) * size)))
