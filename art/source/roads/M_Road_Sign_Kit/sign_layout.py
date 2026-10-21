"""M_Road_Sign_Kit sheet layout (pure python; read by build.py in Blender and signtex.py outside it).

One shared sign atlas, `T_Sign_Main_*` (1024 ship, 2048 master), used by all five signs of the kit (docs/12 2.4 row:
"300 to 1,500; sign atlas"). Two columns of the 2048 master.

The trim column (u 0.0000..0.3300) holds the plain surfaces; each is painted as a seamless tile or as a "height above
ground" band, so a post, a strap or a plate back can be box-projected into it and repeat without a seam:

  galv      676 x 700 px, tile both ways: galvanised post steel (zinc spangle, rain wash, dried salt, rust specks).
            U repeats every 2.40 m along the part; V is the height above ground over 2.60 m, so a whole post sits in
            one V span with no wrapping (consecutive bands would otherwise share V values and a LOD merge of two of
            them would collapse their UVs).
  galvbase  676 x 300 px, absz: the bottom BASE_M of a steel post - road splash, grit, salt bloom, rust at the base.
  paint     676 x 300 px, tile: the fingerpost's white painted timber, upper part (chalky paint, thin lichen).
  paintbase 676 x 300 px, absz: the painted post's bottom BASE_M - splash, moss and lichen crusts.
  alu       676 x 300 px, tile: plate backs, folded rims and stiffeners (milled aluminium, grime, salt).
  dark      338 x 148 px, tile: bolt heads, nuts and clip studs (dull oiled steel).
  clip      338 x 148 px, fit: the galvanised band clip drawn once, whole, with rust at its ends (rust at the clips).

The face column (u 0.3400..1.0000) holds one rect per printed sign face, each at its own pixels per metre and in its
true aspect ratio, so no lettering is ever stretched. `FACES` gives the rects (atlas UVs, v up); `face_rect` returns
one. Face rects are mapped without an inset (the painter bleeds the face's own edge colour into the gutter), the trim
rects are inset by INSET_PX at the ship size the way M_Road_CrashBarrier and M_Road_FieldGate inset theirs.
"""
M = 2048                  # master sheet size (px)
SHIP = 1024               # shipped size (px); the master is exactly 2x
INSET_PX = 3              # at the ship size: keeps bilinear filtering inside a trim region
# The trim tiles are deliberately coarse: the galvanised posts, the plate backs and the fixings are plain surfaces, and
# a coarse tile keeps their share of the sheet's UV area small, so decimating the small fittings and the round posts at
# LOD1 / LOD2 does not move the layout the printed faces hold (= 307 px per metre at the master, 51 px/stud shipped).
# The plain regions are deliberately coarse: they carry galvanised steel, paint and milled aluminium, and a coarse
# tile keeps their share of the sheet's UV area small, so a LOD that drops the band clips, the bolt heads and the round
# post segments does not move the layout the printed faces hold. The two splash-band regions are the exception: they
# map V to the height above ground over POST_M, so the grit, salt and lichen stay at their real height.
PLATE_TILE_M = (1.40, 2.00)   # the plate backs, folded rims and stiffeners: one tile fits a whole plate

# trim regions: name -> (x0, y0, w, h) in master pixels, y0 = the top row (image space, row 0 at v = 1)
TRIMS = {   # (x0, y0 top, w, h) in master pixels
    "galv":      (0,    0, 410, 445),
    "paint":     (0,  445, 410, 445),
    "alu":       (0,  890, 410, 150),
    "dark":      (0, 1040, 205, 100),
    "clip":      (205, 1040, 205, 24),
}

TILES = {
    # Iso texels everywhere. The plain surfaces carry galvanised steel and paint at 171 px per metre at the master (85
    # at the ship size, 28 px per stud): a plain surface, and coarse enough that dropping band clips, bolt heads and
    # round post segments at LOD1 / LOD2 does not move the layout the printed faces hold. V is the height above ground
    # over the whole 2.60 m tile, so a post sits in one V span with no wrapping and no band boundaries inside it.
    "galv": (2.40, 2.60), "paint": (2.40, 2.60), "alu": (2.40, 0.878),
    "dark": (1.20, 0.585),
    "clip": (0.45, 0.0525),       # one unfolded band clip: 0.45 m of strap (U) by the 30 mm width (V), fit, not tiled
}

GROUND_M = 0.45               # the bottom of the galv / paint tile carries the post's splash, grit, salt and lichen

ABSZ = ()                           # no region maps V to the height above ground any more

# printed faces: name -> (real width m, real height m, px per metre, x0, y0 top)
# The rects are packed in shelves in the face column (x 696..2048, 12 px gutters, shelves from the top): tideboard +
# cliff, then car park + launch + keeper plate, then the cliff plate + car park plate, then the four blades. Widths
# follow from each face's real aspect ratio, so no lettering is ever stretched. 850 px/m on the blades (142 px/stud at
# the ship size: they carry the lettering) and 600 to 700 px/m on the plates (100 to 117 px/stud): sign faces are read
# close up, so they sit in the hero tier (docs/05 5.3).
FACE_SPEC = {
    "blade_a":      (1.10, 0.145, 850, 696, 1356),
    "blade_b":      (0.98, 0.145, 850, 696, 1491),
    "blade_c":      (0.92, 0.145, 850, 696, 1626),
    "blade_d":      (0.85, 0.145, 850, 4, 1884),      # the sheet's bottom-left corner: it anchors the UV hull
    "tideboard":    (0.90, 1.15, 600, 696, 0),
    "cliff":        (0.90, 0.7791, 600, 1248, 0),
    "launch":       (0.75, 0.55, 700, 1128, 702),
    "carpark":      (0.60, 0.60, 700, 696, 702),
    "cliffPlate":   (0.60, 0.30, 700, 696, 1134),
    "carparkPlate": (0.60, 0.20, 700, 1128, 1134),
    "launchKeeper": (0.45, 0.15, 700, 1665, 702),
}

# fixing bolts that show on each printed face: (fraction of the face's width, fraction of its height measured from the
# bottom). The geometry puts the bolt heads here and the painter runs rust down from the same points, so plate, clip
# and rust streak always line up (docs/05 5.4: no wear without a cause).
FIXINGS = {
    # each blade is held by a galvanised strap round the post, its two ears bolted through the blade near the post end
    "blade_a":      ((0.072, 0.500), (0.165, 0.500)),
    "blade_b":      ((0.072, 0.500), (0.165, 0.500)),
    "blade_c":      ((0.072, 0.500), (0.165, 0.500)),
    "blade_d":      ((0.072, 0.500), (0.165, 0.500)),
    # tide board: two band clips per post (the posts stand at 0.10 and 0.90 of the board's width)
    "tideboard":    ((0.028, 0.945), (0.172, 0.945), (0.828, 0.945), (0.972, 0.945),
                     (0.028, 0.075), (0.172, 0.075), (0.828, 0.075), (0.972, 0.075)),
    "cliff":        ((0.428, 0.200), (0.572, 0.200)),          # one clip, low, in the wide white field
    "launch":       ((0.413, 0.780), (0.587, 0.780), (0.413, 0.220), (0.587, 0.220)),
    "carpark":      ((0.392, 0.800), (0.608, 0.800), (0.392, 0.200), (0.608, 0.200)),
    "cliffPlate":   ((0.392, 0.500), (0.608, 0.500)),          # its own clip on the post
    "carparkPlate": ((0.250, 0.950), (0.750, 0.950)),          # bolted up into the plate above
    "launchKeeper": ((0.280, 0.930), (0.720, 0.930)),
}


def fixings_mm(name):
    """The face's fixing bolts in millimetres from its top-left corner: [(x_mm, y_mm_from_top), ...]."""
    w_m, h_m, ppm, _x0, _y0 = FACE_SPEC[name]
    w_mm, h_mm = w_m * 1000.0, h_m * 1000.0
    return [(fx * w_mm, (1.0 - fy) * h_mm) for fx, fy in FIXINGS[name]]
FACE_SPAN = (0.3400, 1.0000)      # u range of the face column (x 696..2048 of the master)


def face_rect(name):
    """(u0, v0, u1, v1) of a printed face rect in atlas UVs, v up; no inset (the painter bleeds the edge colour)."""
    w_m, h_m, ppm, x0, y0 = FACE_SPEC[name]
    w, h = int(round(w_m * ppm)), int(round(h_m * ppm))
    return (x0 / float(M), 1.0 - (y0 + h) / float(M), (x0 + w) / float(M), 1.0 - y0 / float(M))


def face_px(name):
    """(x0, y0, w, h) of a printed face rect in master pixels, y0 = the top row."""
    w_m, h_m, ppm, x0, y0 = FACE_SPEC[name]
    return (x0, y0, int(round(w_m * ppm)), int(round(h_m * ppm)))


def region_rect(region):
    """(u0, v0, u1, v1) of a trim region in atlas UVs, v up, inset for filtering."""
    x0, y0, w, h = TRIMS[region]
    e = INSET_PX / float(SHIP)
    return (x0 / float(M) + e, 1.0 - (y0 + h) / float(M) + e, (x0 + w) / float(M) - e, 1.0 - y0 / float(M) - e)


def region_px(region):
    """(x0, y0, w, h) of a trim region in master pixels, y0 = the top row."""
    return TRIMS[region]


def signal_faces():
    """The printed faces that carry real sign signal colours (red / blue): the saturation check skips these."""
    return ("cliff", "launch", "launchKeeper", "carpark")


def check():
    """Rect sanity: every rect inside the sheet, and no two rects overlapping. Returns a list of problems."""
    bad, anchor = [], False
    rects = {("trim", n): (x, y, x + w, y + h) for n, (x, y, w, h) in TRIMS.items()}
    for n in FACE_SPEC:
        x, y, w, h = face_px(n)
        rects[("face", n)] = (x, y, x + w, y + h)
    for key, (x0, y0, x1, y1) in rects.items():
        if x0 < 0 or y0 < 0 or x1 > M or y1 > M:
            bad.append("%s %s outside the sheet" % key)
        if key[0] == "face" and x0 <= 16 and y1 >= M - 200:
            anchor = True               # a printed face in the bottom-left corner anchors the sheet's UV hull
    if not anchor:
        bad.append("no printed face anchors the bottom-left corner of the sheet (the UV hull)")
    items = sorted(rects.items())
    for i, (ka, a) in enumerate(items):
        for kb, b in items[i + 1:]:
            if a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]:
                bad.append("%s overlaps %s" % (ka, kb))
    return bad


if __name__ == "__main__":
    import sys
    problems = check()
    for p in problems:
        print("PROBLEM", p)
    for n in FACE_SPEC:
        print("%-14s px %d %d %d %d uv %.4f %.4f %.4f %.4f" % ((n,) + face_px(n) + face_rect(n)))
    sys.exit(1 if problems else 0)
