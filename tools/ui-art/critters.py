#!/usr/bin/env python3
"""The album stickers (UI/Sticker.luau): Bottle, View and the rare critters as die-cut vector stickers in the
stickers.py recipe, but multi-part: the white rim and the hard outline wrap the UNION of all parts (and its lip copy
12 units down), then each part's lip and fill, then the inner detail.   usage: python3 tools/ui-art/critters.py
Writes art/source/ui/critter_<name>.svg (square, art centred); render each with render.py --keep --size 256 256."""
import math
import pathlib

SRC = pathlib.Path(__file__).resolve().parents[2] / "art/source/ui"
INK = "#14121C"
# round 7 redraws (anchored AD rounds): False regenerates the shipped best PNG pixel-identical
R7 = {"view": True}
LIP_DY = 12
# one square page for every sticker (same rim and outline weight on screen), its corner set so each sits centred
SIZE = 246
CORNER = {
    "bottle": (-11.1, -20.8),
    "view": (-17.6, -11.5),
    "sealpup": (-6.4, -9.1),
    "gull": (-21.0, -1.2),
    "puffin": (-5.4, -12.0),
    "otter": (0.1, -6.9),
    "turtle": (-21.9, 11.5),
}

# name: (light top, saturated bottom, lip)
PAL = {
    "red": ("#FF8A7A", "#E2333A", "#A3161E"), "blue": ("#8EE0FF", "#2C8EF0", "#1A55A8"),
    "green": ("#A4F57A", "#33BE4D", "#1F8A33"), "gold": ("#FFE45C", "#FFAE00", "#C27400"),
    "teal": ("#8FF5E2", "#1DB59B", "#13776E"), "pink": ("#FFA6DA", "#F2459C", "#A82468"),
    "orange": ("#FFC266", "#FF7419", "#B84A08"), "white": ("#FFFFFF", "#D3DEEA", "#8796AC"),
    "slate": ("#B9C9DC", "#7086A6", "#4C5E7C"), "seal": ("#D4EAFF", "#7C9FD8", "#4A6599"),
    "coal": ("#646A88", "#2A2C3B", "#0E0D14"), "brown": ("#DFA066", "#A55E28", "#6B3A16"),
    "cream": ("#FFF8E6", "#F5DDAE", "#C9A66B"), "roll": ("#F7DDA6", "#E0B166", "#A87A35"),
    "gullw": ("#E6EEF8", "#B4C6DE", "#7F93B0"), "coral": ("#FFC9B0", "#FF7A5C", "#B8402A"), "cork": ("#F8D49C", "#C27E3C", "#74461F"),
    "gullb": ("#FFFFFF", "#E4ECF5", "#7F90AC"), "wing": ("#A8B8D0", "#62769A", "#3A4866"),
    "tail": ("#C98850", "#8A4C1E", "#4E280C"), "pcoal": ("#7E88B0", "#2A2C3B", "#0E0D14"),
}


def grad(gid, color, y1, y2, rot=None):
    """a top-to-bottom gradient in user space (one light for the whole sticker); rot undoes a part's rotation"""
    top, bot, _ = PAL[color]
    t = f' gradientTransform="rotate({rot[0]} {rot[1]} {rot[2]})"' if rot else ""
    return (f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" x1="0" y1="{y1}" x2="0" y2="{y2}"{t}>'
            f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bot}"/></linearGradient>')


def leg(x0, y0, x1, y1, w0, w1):
    """a tapered bar from (x0,y0) to (x1,y1) as a closed path (thick tripod legs, bird legs)"""
    a = math.atan2(y1 - y0, x1 - x0) + math.pi / 2
    c, s = math.cos(a), math.sin(a)
    pts = [(x0 + c * w0 / 2, y0 + s * w0 / 2), (x1 + c * w1 / 2, y1 + s * w1 / 2),
           (x1 - c * w1 / 2, y1 - s * w1 / 2), (x0 - c * w0 / 2, y0 - s * w0 / 2)]
    return '<path d="M' + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + ' Z"/>'


def eye(cx, cy, rx=11, ry=14):
    """a big friendly eye: a solid ink oval with one white glint (no glassy sclera)"""
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{INK}"/>'
            f'<circle cx="{cx - rx * 0.3:.1f}" cy="{cy - ry * 0.38:.1f}" r="{rx * 0.42:.1f}" fill="#fff"/>')


def gloss(d, w=10, o=0.55):
    return f'<path d="{d}" fill="none" stroke="#fff" stroke-opacity="{o}" stroke-width="{w}" stroke-linecap="round"/>'


def line(d, w=7, color=INK):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'


def stud(cx, cy, r, color):
    """a Lego stud seen from above: a lighter disc in a dark ring, a short gloss arc"""
    top, _, lip = PAL[color]
    a = r * 0.62
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{top}" stroke="{lip}" stroke-width="6"/>'
            f'<path d="M{cx - a:.1f},{cy - 2:.1f} A{a:.1f},{a:.1f} 0 0,1 {cx - 2:.1f},{cy - a:.1f}" fill="none" '
            f'stroke="#fff" stroke-opacity="0.75" stroke-width="6" stroke-linecap="round"/>')


def critter(name, parts, detail, defs="", note="", rim="", ink=""):
    """parts: [(element without fill/stroke, fill, lip colour, inner line?)], bottom of the z-order first;
    rim: extra shapes that only widen the white die-cut (fill gaps between thin parts); ink: shapes that join the
    hard outline (close a gap that would pinch to a white sliver)"""
    def layer(fill, dy, stroke=None, w=0, which=None):
        els = "".join(p[0] for p in (which or parts)) + (rim if fill == "#fff" else "") + (ink if fill in ("#fff", INK) else "")
        st = f' stroke="{stroke}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"' if w else ""
        return f'<g transform="translate(0,{dy})" fill="{fill}"{st}>{els}</g>'

    out = [layer("#fff", dy, "#fff", 30) for dy in (0, LIP_DY)]          # white rim round the union and its lip
    out += [layer(INK, dy, INK, 12) for dy in (0, LIP_DY)]               # hard outline round the union and its lip
    out += [layer(lip, LIP_DY, which=[p]) for p in parts for lip in [p[2]]]  # the darker lip under every part
    for p in parts:                                                      # fills, inner ink lines between parts
        out.append(layer(p[1], 0, INK, 7, [p]) if p[3] else layer(p[1], 0, which=[p]))
    body = "".join(out) + detail
    x, y = CORNER[name]
    text = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {SIZE} {SIZE}" width="256" height="256">'
            f"<!-- {note} --><defs>{defs}</defs>{body}</svg>\n")
    (SRC / f"critter_{name}.svg").write_text(text)


def P(color):
    return f"url(#{color})"


def G(*colors, y1=20, y2=195):
    return "".join(grad(c, c, y1, y2) for c in colors)


# --- seal pup: lying on its belly, big head to the left, a forked tail flipper on top of the rear, up-right
critter("sealpup", [
    ('<ellipse cx="118" cy="134" rx="80" ry="50"/>', P("seal"), PAL["seal"][2], True),
    ('<circle cx="72" cy="86" r="54"/>', P("seal"), PAL["seal"][2], False),
    ('<path d="M168,140 C178,126 188,114 200,104 C210,98 218,108 212,120 C208,128 202,132 196,136 '
     'C208,136 218,144 214,154 C210,162 192,162 174,156 Z"/>', P("slate"), PAL["slate"][2], True),
], ('<ellipse cx="122" cy="156" rx="44" ry="20" fill="#F2F7FC"/>'
    + '<circle cx="59" cy="106" r="16" fill="#F7FAFD" stroke="#14121C" stroke-width="7"/>'
      '<circle cx="85" cy="106" r="16" fill="#F7FAFD" stroke="#14121C" stroke-width="7"/>'
      '<ellipse cx="72" cy="91" rx="14" ry="10" fill="#14121C"/>'
      '<circle cx="32" cy="98" r="8" fill="#FF9CC9"/><circle cx="112" cy="98" r="8" fill="#FF9CC9"/>'
    + eye(47, 68, 13, 16) + eye(97, 68, 13, 16)
    + gloss("M28,66 C30,50 42,38 56,34") + gloss("M140,98 C154,94 166,98 174,106", 9)
    + gloss("M188,118 C194,112 200,108 204,106", 7)),
    G("seal", "slate"), "a rare seal pup spotted: a chubby blue-grey pup lying on its belly, forked tail flipper")

# --- gull: a chubby standing gull, yellow beak, grey wing folded over a black wingtip, tall orange legs
critter("gull", [
    ('<path d="M72,126 L4,144 C1,152 7,161 16,160 L72,154 Z"/>', P("coal"), PAL["coal"][2], True),
    ('<path d="M73,154 L91,154 L91,190 L106,208 L58,208 L73,190 Z"/>', P("orange"), PAL["orange"][2], True),
    ('<path d="M111,154 L129,154 L129,190 L144,208 L96,208 L111,190 Z"/>', P("orange"), PAL["orange"][2], True),
    ('<ellipse cx="98" cy="120" rx="66" ry="52"/>', P("gullb"), PAL["gullb"][2], True),
    ('<circle cx="124" cy="66" r="42"/>', P("gullb"), PAL["gullb"][2], False),
    ('<path d="M150,52 L194,64 C202,67 202,77 194,80 L150,88 Z"/>', P("gold"), PAL["gold"][2], True),
    ('<path d="M54,106 C86,90 132,104 140,130 C132,160 84,170 20,156 C26,130 36,114 54,106 Z"/>',
     PAL["wing"][2], PAL["wing"][2], True),  # the wing's own darker lip, ~2.5 pt under it
    ('<path d="M54,100 C86,84 132,98 140,124 C132,154 84,164 20,150 C26,124 36,108 54,100 Z"/>',
     P("wing"), PAL["wing"][2], True),
], ('<circle cx="183" cy="77" r="8" fill="#E2333A"/>' + line("M152,70 L188,70")
    + eye(126, 56, 19, 23) + gloss("M92,52 C96,38 108,28 122,26", 10, 0.8)
    + gloss("M64,104 C86,94 110,98 124,110", 10, 0.8)),
    G("gullb", "coal", "orange", "gold") + G("wing", y1=90, y2=165), "a rare gull spotted: a chubby standing gull, wing folded over a black tip")

# --- puffin: blue-black back and head, a big white face and chest, gold-red-gold striped beak, orange feet
critter("puffin", [
    ('<path d="M74,170 L88,170 L88,182 L104,194 L60,194 L74,182 Z"/>', P("orange"), "#8A3604", True),
    ('<path d="M108,170 L122,170 L122,182 L138,194 L94,194 L108,182 Z"/>', P("orange"), "#8A3604", True),
    ('<path d="M84,70 C120,62 160,92 164,134 C166,166 140,184 102,184 C70,184 44,170 40,146 C36,120 52,78 84,70 Z"/>', P("pcoal"), PAL["pcoal"][2], True),
    ('<circle cx="98" cy="64" r="48"/>', P("pcoal"), PAL["pcoal"][2], False),
    ('<path d="M136,40 C164,44 190,64 196,86 C184,100 160,104 136,98 Z"/>', P("red"), "#7E0E15", True),
    ('<path d="M136,40 C144,41 152,43 158,47 L158,101 C150,101 142,100 136,98 Z"/>', P("gold"), "#9A5800", True),
    ('<path d="M177,58 C186,64 194,76 196,86 C192,91 186,94 179,97 C182,84 181,70 177,58 Z"/>', P("gold"), "#9A5800", True),
], ('<ellipse cx="116" cy="136" rx="40" ry="42" fill="url(#white)"/>'
    '<path d="M60,64 C58,36 88,20 116,26 C130,30 138,46 136,68 C134,92 122,106 98,106 C74,106 62,88 60,64 Z" '
    'fill="url(#white)" stroke="#14121C" stroke-width="7"/>'
    '<path d="M52,106 C72,100 92,112 96,136 C98,156 82,170 62,166 C50,148 46,124 52,106 Z" fill="url(#coalw)" '
    'stroke="#14121C" stroke-width="11" stroke-linejoin="round"/>'
    + line("M158,47 L158,101", 10) + line("M179,97 C182,84 181,70 177,58", 10)
    + eye(116, 56, 11, 14) + gloss("M58,44 C64,32 74,22 88,18", 11, 0.75) + gloss("M58,122 C65,115 73,114 80,120", 9, 0.75)),
    G("pcoal", "red", "gold", "orange") + G("white", y1=30, y2=180)
    + grad("coalw", "slate", 100, 170).replace("#B9C9DC", "#A2ACD0").replace("#7086A6", "#5A6084"),
    "a rare puffin spotted: blue-black back, big white face and chest, gold-red-gold striped beak, orange feet")

# --- otter: sitting up, a wide flat head with small low ears, a big cream muzzle (nose, whisker dots), a fat tail,
# holding one big coral scallop shell on its belly
critter("otter", [
    ('<path d="M128,186 C182,200 224,170 220,112 C219,100 201,100 200,112 C198,146 174,160 136,160 Z"/>', P("tail"), PAL["tail"][2], True),
    ('<circle cx="39" cy="58" r="13"/>', P("brown"), PAL["brown"][2], True),
    ('<circle cx="161" cy="58" r="13"/>', P("brown"), PAL["brown"][2], True),
    ('<ellipse cx="100" cy="146" rx="58" ry="46"/>', P("brown"), PAL["brown"][2], True),
    ('<ellipse cx="100" cy="78" rx="66" ry="50"/>', P("brown"), PAL["brown"][2], True),
], ('<ellipse cx="100" cy="158" rx="40" ry="32" fill="url(#cream)"/>'
    '<ellipse cx="100" cy="102" rx="56" ry="26" fill="url(#cream)" stroke="#14121C" stroke-width="7"/>'
    + "".join(f'<circle cx="{x}" cy="{y}" r="5.5" fill="#14121C"/>' for x, y in ((66, 100), (70, 114), (134, 100), (130, 114)))
    + '<path d="M84,83 L116,83 C120,83 121,88 117,91 L104,101 C101,103 99,103 96,101 L83,91 C79,88 80,83 84,83 Z" fill="#14121C"/>'
    + '<path d="M100,186 L62,154 A14,14 0 0,1 86,136 A14,14 0 0,1 114,136 A14,14 0 0,1 138,154 Z" '
      'fill="url(#coral)" stroke="#14121C" stroke-width="7" stroke-linejoin="round"/>'
    + line("M100,182 L86,138") + line("M100,182 L114,138")
    + '<ellipse cx="62" cy="160" rx="15" ry="13" fill="url(#brown)" stroke="#14121C" stroke-width="7"/>'
      '<ellipse cx="138" cy="160" rx="15" ry="13" fill="url(#brown)" stroke="#14121C" stroke-width="7"/>'
    + eye(73, 56, 11, 13) + eye(127, 56, 11, 13) + gloss("M50,50 C56,42 63,38 70,36", 9, 0.35)
    + gloss("M189,162 C200,154 207,144 208,131", 7)),
    G("brown", "tail") + G("cream", y1=70, y2=190) + G("coral", y1=122, y2=190),
    "a rare otter spotted: sitting up, wide flat head, big cream muzzle with nose and whisker dots, fat tail, holding a shell")

# --- turtle: a sea turtle, a green Lego shell (brick plates, studs) on one gold band, teal flippers and head
critter("turtle", [
    ('<path d="M40,142 C22,150 6,162 2,178 C24,180 44,170 54,154 Z"/>', P("teal"), PAL["teal"][2], True),
    ('<path d="M128,142 C158,148 184,168 192,192 C164,194 134,182 116,160 Z"/>', P("teal"), PAL["teal"][2], True),
    ('<path d="M148,134 C150,110 156,92 170,84 L190,92 C196,110 186,126 166,140 Z"/>', P("teal"), PAL["teal"][2], True),
    ('<circle cx="172" cy="94" r="28"/>', P("teal"), PAL["teal"][2], False),
    ('<rect x="10" y="124" width="158" height="26" rx="13"/>', P("gold"), "#9A5800", True),
    ('<path d="M18,132 C18,42 160,42 160,132 Z"/>', P("green"), PAL["green"][2], True),
], (line("M64,68 C72,88 72,110 68,132") + line("M114,68 C106,88 106,110 110,132")
    + stud(42, 110, 11, "green") + stud(89, 104, 15, "green") + stud(136, 110, 11, "green")
    + line("M26,143 L152,143", 6, "#E08E00")
    + eye(181, 85, 12, 15) + line("M166,112 Q178,120 192,110")
    + gloss("M78,77 C86,72 96,71 102,73", 9) + gloss("M152,92 C153,84 156,79 160,76", 8)),
    G("green", y1=54, y2=132) + G("teal") + G("gold", y1=124, y2=150),
    "a rare sea turtle spotted: green Lego brick-plate shell with studs on a gold band")

# --- bottle: a fat message in a bottle lying diagonal, a big studded cork up-right, a big scroll with a wax seal
R = "translate(0,-8) rotate(-40 107 105)"
critter("bottle", [
    (f'<rect x="210" y="86" width="16" height="16" rx="4" transform="{R}"/>', P("corkr"), PAL["cork"][2], True),
    (f'<rect x="210" y="108" width="16" height="16" rx="4" transform="{R}"/>', P("corkr"), PAL["cork"][2], True),
    (f'<rect x="184" y="78" width="32" height="54" rx="10" transform="{R}"/>', P("corkr"), PAL["cork"][2], True),
    (f'<path d="M134,52 C156,52 156,78 170,78 L178,78 L178,132 L170,132 C156,132 156,158 134,158 L46,158 '
     f'C28,158 18,148 18,130 L18,80 C18,62 28,52 46,52 Z" transform="{R}"/>', P("glass"), "#0B4F49", False),
    (f'<rect x="170" y="66" width="18" height="78" rx="7" transform="{R}"/>', P("glass"), "#0B4F49", True),
], (f'<g transform="{R}">'
    + '<rect x="40" y="76" width="92" height="58" rx="8" fill="url(#cream)" stroke="#14121C" stroke-width="7"/>'
    '<rect x="30" y="68" width="22" height="74" rx="9" fill="url(#roll)" stroke="#14121C" stroke-width="7"/>'
    '<rect x="120" y="68" width="22" height="74" rx="9" fill="url(#roll)" stroke="#14121C" stroke-width="7"/>'
    '</g><g transform="translate(0,-8) rotate(-40 107 105) rotate(40 86 105)">'
    '<path d="M76,108 L70,128 L78,125 L83,131 L88,110 Z M96,108 L102,128 L94,125 L89,131 L84,110 Z" fill="url(#redr)" '
    'stroke="#14121C" stroke-width="6" stroke-linejoin="round"/>'
    '<circle cx="86" cy="102" r="19" fill="url(#redr)" stroke="#14121C" stroke-width="7"/>'
    + gloss("M77,96 C79,91 83,88 88,88", 6, 0.8)
    + f'</g><g transform="{R}">'
    + gloss("M44,62 L130,62") + gloss("M188,90 L208,90", 8, 0.8)
    + '</g>'),
    grad("glass", "teal", 0, 210, (40, 107, 105)) + grad("corkr", "cork", 0, 210, (40, 107, 105))
    + grad("cream", "cream", 60, 150) + grad("roll", "roll", 60, 150) + grad("redr", "red", 76, 136),
    "a message in a bottle found: fat sea-glass bottle, studded cork, a big scroll with a red wax seal")

# --- view: a chunky telescope on a thick tripod (the die-cut fills between the legs), pointing up-right
T = "rotate(-28 95 95)"
TUBE_LIP = "#0D5A8C"
VIEW_CORNER = (-22.4, -11.0)
if R7["view"]:
    # r7 (AD r4-r6): a true tripod: three legs meet at a big hinge knob under the tube and splay out to dark foot pads,
    # the back leg shorter and darker, white die-cut between them; deep wood brown (not orange) so the stand does not
    # melt into sand; objective end ~15% bigger with a bright cyan lens and a big white glint
    CORNER["view"] = VIEW_CORNER
    critter("view", [
        (leg(95, 124, 95, 178, 28, 26), P("legD"), "#2E1404", True),
        (leg(95, 124, 18, 190, 30, 26), P("leg"), "#3E1E08", True),
        (leg(95, 124, 172, 190, 30, 26), P("leg"), "#3E1E08", True),
        ('<rect x="80" y="172" width="30" height="14" rx="7"/>', P("coal"), PAL["coal"][2], True),
        ('<rect x="-1" y="186" width="38" height="15" rx="7.5"/>', P("coal"), PAL["coal"][2], True),
        ('<rect x="153" y="186" width="38" height="15" rx="7.5"/>', P("coal"), PAL["coal"][2], True),
        (f'<rect x="4" y="74" width="38" height="42" rx="10" transform="{T}"/>', P("redr"), PAL["red"][2], True),
        (f'<rect x="38" y="72" width="104" height="46" rx="12" transform="{T}"/>', P("bluer"), TUBE_LIP, True),
        (f'<rect x="130" y="58" width="56" height="74" rx="15" transform="{T}"/>', P("bluer"), TUBE_LIP, True),
        (f'<rect x="114" y="64" width="24" height="62" rx="8" transform="{T}"/>', P("goldr"), PAL["gold"][2], True),
        (f'<ellipse cx="186" cy="95" rx="18" ry="46" transform="{T}"/>', P("goldr"), PAL["gold"][2], True),
        ('<circle cx="95" cy="122" r="20"/>', P("gold"), PAL["gold"][2], True),
    ], (f'<g transform="{T}"><ellipse cx="189" cy="95" rx="13" ry="36" fill="url(#lens)" stroke="#14121C" stroke-width="7"/>'
        + gloss("M46,84 L104,84") + '<ellipse cx="187" cy="80" rx="6.5" ry="13" fill="#fff"/>'
        + gloss("M14,86 L14,102", 7, 0.7) + '</g>'
        + '<circle cx="95" cy="122" r="7" fill="#14121C"/>' + gloss("M82,116 C84,110 89,106 95,105", 6, 0.8)
        + gloss("M78,140 L44,172", 7, 0.45) + gloss("M112,140 L146,172", 7, 0.45)),
        G("gold", y1=100, y2=145) + G("coal", y1=170, y2=202)
        + grad("leg", "brown", 110, 195).replace("#DFA066", "#D08A4A").replace("#A55E28", "#7A3E14")
        + grad("legD", "brown", 110, 195).replace("#DFA066", "#8E5226").replace("#A55E28", "#4E260A")
        + grad("bluer", "blue", 20, 160, (28, 95, 95)) + grad("goldr", "gold", 20, 160, (28, 95, 95))
        + grad("redr", "red", 20, 160, (28, 95, 95))
        + grad("lens", "blue", 12, 82, (28, 95, 95)).replace("#8EE0FF", "#E0FFFF").replace("#2C8EF0", "#14DCFF"),
        "a scenic viewpoint found: a chunky blue telescope on a brown three-leg tripod with foot pads, big cyan lens",
        rim='<path d="M18,190 L95,178 L172,190 L95,124 Z"/>')
else:
    critter("view", [
        (leg(95, 104, 98, 192, 39, 36), P("legD"), "#7A2E04", True),
        (leg(90, 104, 26, 186, 39, 36), P("leg"), "#963A06", True),
        (leg(100, 104, 168, 186, 39, 36), P("leg"), "#963A06", True),
        (f'<rect x="2" y="74" width="38" height="42" rx="10" transform="{T}"/>', P("redr"), PAL["red"][2], True),
        (f'<rect x="36" y="72" width="116" height="46" rx="12" transform="{T}"/>', P("bluer"), TUBE_LIP, True),
        (f'<rect x="140" y="62" width="52" height="66" rx="14" transform="{T}"/>', P("bluer"), TUBE_LIP, True),
        (f'<rect x="124" y="64" width="26" height="62" rx="8" transform="{T}"/>', P("goldr"), PAL["gold"][2], True),
        (f'<ellipse cx="192" cy="95" rx="16" ry="40" transform="{T}"/>', P("goldr"), PAL["gold"][2], True),
        ('<circle cx="95" cy="100" r="17"/>', P("gold"), PAL["gold"][2], True),
    ], (f'<g transform="{T}"><ellipse cx="195" cy="95" rx="11" ry="30" fill="url(#lens)" stroke="#14121C" stroke-width="7"/>'
        + gloss("M44,84 L112,84") + '<ellipse cx="193" cy="83" rx="4.5" ry="8" fill="#fff"/>'
        + gloss("M12,86 L12,102", 7, 0.7) + '</g>'
        + '<circle cx="95" cy="100" r="6" fill="#14121C"/>'),
        G("gold", y1=90, y2=195) + grad("leg", "orange", 90, 195).replace("#FFC266", "#FFDCA0").replace("#FF7419", "#FF9638")
        + grad("legD", "orange", 90, 195).replace("#FFC266", "#FBB466").replace("#FF7419", "#EC7424")
        + grad("bluer", "blue", 20, 160, (28, 95, 95)) + grad("goldr", "gold", 20, 160, (28, 95, 95))
        + grad("redr", "red", 20, 160, (28, 95, 95))
        + grad("lens", "blue", 18, 80, (28, 95, 95)).replace("#8EE0FF", "#B8FBFF").replace("#2C8EF0", "#1ECDF2"),
        "a scenic viewpoint found: a chunky blue telescope on a thick orange tripod",
        rim='<path d="M26,186 L98,192 L168,186 L95,104 Z"/>', ink='<path d="M46,170 L95,112 L146,170 Z"/>')
