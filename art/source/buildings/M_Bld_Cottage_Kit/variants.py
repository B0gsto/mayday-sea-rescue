"""H3 cottage variants (pure python, no bpy): footprints match the map/Build.luau greybox houses House1..House6
(buildHouse: Body size X = 18 + (i % 3) * 4, Y = 12 + (i % 2) * 6, Z = 16 studs; base = bottom centre; door on the
street face). Metres here, Blender X across the front, front at -Y, Z up; the greybox X maps to our W, its Y to the
eaves height E, its Z (16 studs = 5.333 m) to the depth D. Pivot = footprint centre at ground level; place at the
greybox spot with yaw 180 degrees so the front (-Y here) faces the greybox door side (+Z in Roblox).

Windows: (x centre, sill z, width, height, kind 'sash' | 'case', interior 0..5, lit). Doors: (x centre, colour,
fanlight). Units: (x0, x1, wall) with wall 'Render_<Colour>' or 'Stone'. Chimneys: (x centre, 'gable' | 'ridge', wall).
"""
D = 16 / 3.0
T = 0.5            # wall slab (the reveal depth reads 0.5 m)
PITCH = 0.78       # rise per metre run (about 38 degrees)
OVH = 0.22         # eaves overhang (horizontal)
VERGE = 0.25       # H3b: verge overhang at the gables (bargeboards under it)
SLAB = 0.06        # H3b: slate layer, vertical thickness (edge reads 6 to 7.5 cm with the course tails)
STACK_UP = 1.0     # chimney stack above the ridge
POT_H = 0.5        # (H1 value; H3b pots are pot_h())
STEP = 0.015       # H3b: slate course tail lift (vertical)
COURSE = 0.25      # H3b: slate course gauge along the slope (matches the Slate texture: 8 courses per 2 m)
STACK_OUT = 0.02   # gable stack outer face beyond the verge edge
CAP_OVER = 0.11    # cap slab oversail beyond the stack body


def pot_h(i, c, q):
    """H3b: irregular chimney pot heights (0.55 to 0.9 m), deterministic per house / stack / pot."""
    return 0.55 + ((i * 37 + c * 17 + q * 29) % 8) * 0.05
SKIRT = 0.4        # granite skirt below the pivot (sloping ground)


def W_of(i):
    return (18 + (i % 3) * 4) / 3.0


def E_of(i):
    return (12 + (i % 2) * 6) / 3.0


def ridge(E):
    return E + PITCH * D / 2


V = {
    1: dict(title="detached double-fronted, pink lime render, two storeys",
            units=[(-W_of(1) / 2, W_of(1) / 2, "Render_Pink")],
            doors=[(0.0, "Navy", True)],
            front=[(-2.2, 0.8, 0.95, 1.35, "sash", 0, True), (2.2, 0.8, 0.95, 1.35, "sash", 1, False),
                   (-2.2, 4.2, 0.9, 1.2, "sash", 2, False), (0.0, 4.2, 0.9, 1.2, "sash", 3, True),
                   (2.2, 4.2, 0.9, 1.2, "sash", 4, False)],
            back=[(1.5, 0.9, 0.8, 1.0, "case", 5, False), (-1.5, 4.2, 0.8, 1.0, "case", 2, False)],
            chimneys=[(-W_of(1) / 2 + 0.45, "gable", "Stone"), (W_of(1) / 2 - 0.45, "gable", "Stone")],
            lamps=[(0.85, 2.45)]),
    2: dict(title="terraced pair, low eaves: bare granite cottage beside an ochre-rendered one",
            units=[(-W_of(2) / 2, 0.0, "Stone"), (0.0, W_of(2) / 2, "Render_Ochre")],
            doors=[(-3.0, "Oxblood", False), (1.4, "Teal", False)],
            front=[(-1.4, 0.85, 1.0, 1.1, "case", 0, True), (3.0, 0.85, 1.0, 1.1, "case", 1, False),
                   (-2.2, 2.75, 0.9, 0.85, "case", 2, False), (2.2, 2.75, 0.9, 0.85, "case", 3, True)],
            back=[(-2.2, 0.9, 0.8, 0.9, "case", 4, False), (2.2, 0.9, 0.8, 0.9, "case", 5, False)],
            chimneys=[(0.0, "ridge", "Stone"), (W_of(2) / 2 - 0.45, "gable", "Stone")],
            lamps=[(-2.25, 2.35)]),
    3: dict(title="detached single-fronted granite cottage, two storeys, granite lintels",
            units=[(-W_of(3) / 2, W_of(3) / 2, "Stone")],
            doors=[(-1.6, "Sage", False)],
            front=[(1.0, 0.8, 1.2, 1.35, "sash", 2, False), (-1.6, 4.2, 0.9, 1.2, "sash", 4, False),
                   (1.0, 4.2, 0.9, 1.2, "sash", 5, True)],
            back=[(0.8, 0.9, 0.8, 1.0, "case", 1, True)],
            chimneys=[(-W_of(3) / 2 + 0.45, "gable", "Stone")],
            lamps=[(-0.85, 2.3)]),
    4: dict(title="detached low cottage, sage render, eaves windows, slate porch",
            units=[(-W_of(4) / 2, W_of(4) / 2, "Render_Sage")],
            doors=[(0.0, "Cream", False)],
            porch=True,
            front=[(-2.3, 0.85, 1.1, 1.1, "case", 3, False), (2.3, 0.85, 1.1, 1.1, "case", 0, True),
                   (-1.6, 2.75, 0.85, 0.85, "case", 1, True), (1.6, 2.75, 0.85, 0.85, "case", 4, False)],
            back=[(-1.5, 0.9, 0.8, 0.9, "case", 2, False)],
            chimneys=[(-W_of(4) / 2 + 0.45, "gable", "Stone"), (W_of(4) / 2 - 0.45, "gable", "Stone")],
            lamps=[(-1.15, 2.2)]),
    5: dict(title="terraced pair, two storeys: whitewashed ground floor, slate-hung upper storey",
            units=[(-W_of(5) / 2, 0.0, "Render_White"), (0.0, W_of(5) / 2, "Render_White")],
            doors=[(-0.72, "Black", True), (0.72, "Navy", True)],
            slate_hung=2.9,
            front=[(-2.6, 0.8, 1.0, 1.35, "sash", 0, True), (2.6, 0.8, 1.0, 1.35, "sash", 1, False),
                   (-2.8, 4.2, 0.85, 1.15, "sash", 2, False), (-1.0, 4.2, 0.85, 1.15, "sash", 3, False),
                   (1.0, 4.2, 0.85, 1.15, "sash", 4, False), (2.8, 4.2, 0.85, 1.15, "sash", 5, True)],
            back=[(-2.2, 4.2, 0.8, 1.0, "case", 1, False), (2.2, 0.9, 0.8, 1.0, "case", 3, False)],
            chimneys=[(-W_of(5) / 2 + 0.45, "gable", "Stone"), (0.0, "ridge", "Stone"), (W_of(5) / 2 - 0.45, "gable", "Stone")],
            lamps=[(0.0, 2.75)]),
    6: dict(title="small detached cottage, pale blue render, eaves windows, rendered stack",
            units=[(-W_of(6) / 2, W_of(6) / 2, "Render_Blue")],
            doors=[(-1.5, "Black", False)],
            front=[(1.2, 0.85, 1.1, 1.1, "case", 5, True), (-1.5, 2.8, 0.8, 0.8, "case", 3, False),
                   (1.2, 2.8, 0.8, 0.8, "case", 0, False)],
            back=[(0.0, 0.9, 0.8, 0.9, "case", 4, False)],
            chimneys=[(W_of(6) / 2 - 0.45, "gable", "Render_Blue")],
            lamps=[(-0.7, 2.25)]),
}


def dims(i):
    """Real outer size (metres): X across incl. the verge slates, Y None (free: sills, steps, porch), Z from the
    granite skirt bottom (-SKIRT) to the top of the tallest chimney pot."""
    E = E_of(i)
    n = {"gable": 2, "ridge": 3}
    ph = max(pot_h(i, c, q) for c, ch in enumerate(V[i]["chimneys"]) for q in range(n[ch[1]]))
    top = ridge(E) + SLAB + STACK_UP + ph
    sides = set(1 if c[0] > 0 else -1 for c in V[i]["chimneys"] if c[1] == "gable")
    x = W_of(i) + 2 * VERGE + (STACK_OUT + CAP_OVER) * len(sides)      # gable stacks: proud of the verge + cap oversail
    return (round(x, 3), None, round(top + SKIRT, 3))


def greybox(i):
    return dict(house="House%d" % i, size_studs=(18 + (i % 3) * 4, 12 + (i % 2) * 6, 16))


if __name__ == "__main__":
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    ref = os.path.join(here, "..", "..", "..", "reference")
    for i, v in V.items():
        x, _, z = dims(i)
        g = greybox(i)
        with open(os.path.join(ref, "M_Bld_Cottage_%02d" % i, "dims.md"), "w") as f:
            f.write("# M_Bld_Cottage_%02d\ndims_m: %.3f x - x %.3f\n" % (i, x, z))
            f.write("Reference: %s (assembled from M_Bld_Cottage_Kit, H3).\n" % v["title"])
            f.write("- Footprint matches the greybox %s in map/Build.luau: %d x %d x %d studs (X frontage x eaves height x "
                    "depth) = %.2f x %.2f m, eaves %.2f m; ridge %.2f m; X here adds the 0.25 m verges each side (+0.13 m where a gable stack and its cap stand proud of the verge); "
                    "Z runs from the 0.4 m granite skirt below ground to the chimney pot tops.\n"
                    % (g["house"], g["size_studs"][0], g["size_studs"][1], g["size_studs"][2], W_of(i), D, E_of(i),
                       ridge(E_of(i))))
            f.write("- Depth 5.33 m is shallower than a real 7 to 8 m cottage: kept to the greybox for a direct swap.\n")
            f.write("- Door about 0.96 x 2.1 m; windows 0.8 to 1.2 x 0.8 to 1.35 m; walls 0.5 m reveals (verify).\n")
            f.write("Sources: Cornish vernacular (generic; verify against photos of Mousehole / Port Isaac terraces).\n")
        print(i, dims(i))
