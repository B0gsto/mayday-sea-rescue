"""M_Road_FieldGate sheet layout (pure python; read by build.py in Blender and gatetex.py outside it).

One trim set, `T_FieldGate_Timber_*` (1024 ship, 2048 master), three regions:

  timber  the full width, v 0.15..1.00 (2048 x 1741 px at 2048): the Cornish five-bar gate's timber - the five bars,
          the heel / head / middle stiles, the brace and both posts, all from one weathered oak-softwood stock. Like
          M_Road_CrashBarrier's galv region, the timber region covers the whole sheet width so a part's U may run past
          1.0 and repeat without ever leaving its own pixels. U repeats every `TILE_U_M` (1.8 m: three 0.6 m tiles of
          the fine_grained_wood scan, CC0 Poly Haven) along the part, V
          runs 0 at ground level to `GATE_H_M` (1.60 m) at the top: mud splash and grit at the bottom, moss at the post
          feet, silver bleaching, rain wash and lichen crusts higher up, checks along the grain, rust drips from the
          fittings. Horizontal members (bars, brace) map U along X, vertical members (posts, stiles) map U along Z, so
          the grain always runs along the piece; a face with no length or height to give (a bar's top, a post's side)
          takes a slice of the region around `MID_V`, the way M_Road_CrashBarrier's rims take MID_V of galv.
  metal   u 0.00..0.60, v 0.00..0.15 (1229 x 307 px): galvanised fittings - hinge straps and their hooks, the hinge
          pins, the latch bar and its keeper, the chain, the ring - the same procedural hot-dip zinc as the crash
          barrier's galv region, on a `MET_TILE_M` (U, V) tile. Every fitting is projected locally about its own
          centre, so its faces share one continuous mapping and the decimator keeps their UVs.
  dark    u 0.60..1.00, v 0.00..0.15 (819 x 307 px): bolt heads, nuts and the pin shanks - dull oiled steel, low
          metalness, on a `DARK_TILE_M` (U, V) tile, projected the same way.
"""
REGIONS = {  # (u0, v0, u1, v1) in atlas UVs, v up
    "timber": (0.000, 0.150, 1.000, 1.000),
    "metal":  (0.000, 0.000, 0.600, 0.150),
    "dark":   (0.600, 0.000, 1.000, 0.150),
}

TILE_U_M = 1.80       # timber: metres of part along one U tile (three 0.6 m scan tiles: the scan's own grain scale)
GATE_H_M = 1.60       # timber: metres of height above ground across the V span (mud at the bottom, bleached at the top)
MID_V = 0.52          # the V a face with no height to give takes (0.83 m above ground: a clean, worn band)
MET_TILE_M = (0.90, 0.225)    # metal region: metres per U tile and per V tile (isotropic texels)
DARK_TILE_M = (0.80, 0.300)   # dark region: metres per U tile and per V tile
INSET_PX = 3          # at the 1024 ship size: keeps bilinear filtering inside a region


def region_rect(region):
    """(u0, v0, u1, v1) of a region in atlas UVs, v up, inset for filtering."""
    u0, v0, u1, v1 = REGIONS[region]
    e = INSET_PX / 1024.0
    return (u0 + e, v0 + e, u1 - e, v1 - e)
