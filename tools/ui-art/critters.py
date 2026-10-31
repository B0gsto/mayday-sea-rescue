#!/usr/bin/env python3
"""The album stickers (UI/Sticker.luau): Bottle, View and the rare critters as die-cut vector stickers in the
stickers.py recipe, but multi-part: the white rim and the hard outline wrap the UNION of all parts (and its lip copy
12 units down), then each part's lip and fill, then the inner detail.   usage: python3 tools/ui-art/critters.py
Writes art/source/ui/critter_<name>.svg (square, art centred); render each with render.py --keep --size 256 256."""
import math
import pathlib

SRC = pathlib.Path(__file__).resolve().parents[2] / "art/source/ui"
INK = "#14121C"
LIP_DY = 12
# one square page for every sticker (same rim and outline weight on screen), its corner set so each sits centred
SIZE = 246
CORNER = {
    "bottle": (-20.0, -14.3),
    "view": (-15.7, -11.5),
    "sealpup": (-10.5, -5.5),
    "gull": (-21.0, -9.0),
    "puffin": (-7.8, -12.0),
    "otter": (-5.2, -14.6),
    "turtle": (-21.2, 10.5),
}

# name: (light top, saturated bottom, lip)
PAL = {
    "red": ("#FF8A7A", "#E2333A", "#A3161E"), "blue": ("#8EE0FF", "#2C8EF0", "#1A55A8"),
    "green": ("#A4F57A", "#33BE4D", "#1F8A33"), "gold": ("#FFE45C", "#FFAE00", "#C27400"),
    "teal": ("#8FF5E2", "#1DB59B", "#13776E"), "pink": ("#FFA6DA", "#F2459C", "#A82468"),
    "orange": ("#FFC266", "#FF7419", "#B84A08"), "white": ("#FFFFFF", "#D3DEEA", "#8796AC"),
    "slate": ("#B9C9DC", "#7086A6", "#4C5E7C"), "seal": ("#D3DEEC", "#8A9DBA", "#56688A"),
    "coal": ("#646A88", "#2A2C3B", "#0E0D14"), "brown": ("#DFA066", "#A55E28", "#6B3A16"),
    "cream": ("#FFF8E6", "#F5DDAE", "#C9A66B"), "cork": ("#E8B57A", "#B0723A", "#74461F"),
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


def gloss(d, w=10):
    return f'<path d="{d}" fill="none" stroke="#fff" stroke-opacity="0.55" stroke-width="{w}" stroke-linecap="round"/>'


def line(d, w=7, color=INK):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'


def stud(cx, cy, r, color):
    """a Lego stud seen from above: a lighter disc in a dark ring, a short gloss arc"""
    top, _, lip = PAL[color]
    a = r * 0.62
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{top}" stroke="{lip}" stroke-width="6"/>'
            f'<path d="M{cx - a:.1f},{cy - 2:.1f} A{a:.1f},{a:.1f} 0 0,1 {cx - 2:.1f},{cy - a:.1f}" fill="none" '
            f'stroke="#fff" stroke-opacity="0.75" stroke-width="6" stroke-linecap="round"/>')


def critter(name, parts, detail, defs="", note=""):
    """parts: [(element without fill/stroke, fill, lip colour, inner line?)], bottom of the z-order first"""
    def layer(fill, dy, stroke=None, w=0, which=None):
        els = "".join(p[0] for p in (which or parts))
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


# --- seal pup: lying on its belly, big head to the left, tail flippers up-right
critter("sealpup", [
    ('<path d="M168,150 C176,124 196,108 204,118 C212,128 202,150 186,166 Z"/>', P("seal"), PAL["seal"][2], True),
    ('<ellipse cx="118" cy="134" rx="80" ry="50"/>', P("seal"), PAL["seal"][2], True),
    ('<circle cx="72" cy="86" r="54"/>', P("seal"), PAL["seal"][2], False),
    ('<ellipse cx="104" cy="176" rx="26" ry="13" transform="rotate(-18 104 176)"/>', P("slate"), PAL["slate"][2], True),
], ('<ellipse cx="128" cy="156" rx="52" ry="20" fill="#F2F7FC"/>'
    + '<circle cx="60" cy="104" r="15" fill="#F7FAFD" stroke="#14121C" stroke-width="7"/>'
      '<circle cx="84" cy="104" r="15" fill="#F7FAFD" stroke="#14121C" stroke-width="7"/>'
      '<ellipse cx="72" cy="92" rx="11" ry="8" fill="#14121C"/>'
      '<circle cx="34" cy="96" r="8" fill="#FF9CC9"/><circle cx="110" cy="96" r="8" fill="#FF9CC9"/>'
    + eye(48, 72) + eye(96, 72)
    + gloss("M30,70 C32,52 46,38 62,35") + gloss("M140,98 C154,94 166,98 174,106", 9)),
    G("seal", "slate"), "a rare seal pup spotted: a chubby grey-blue pup lying on its belly")

# --- gull: a chubby standing gull, yellow beak with the red spot, grey wing with a dark tip
critter("gull", [
    ('<path d="M54,118 L4,140 L18,156 L60,150 Z"/>', P("coal"), PAL["coal"][2], True),
    ('<path d="M80,158 L94,158 L94,180 L108,192 L66,192 L80,180 Z"/>', P("orange"), PAL["orange"][2], True),
    ('<path d="M112,158 L126,158 L126,180 L140,192 L98,192 L112,180 Z"/>', P("orange"), PAL["orange"][2], True),
    ('<ellipse cx="98" cy="120" rx="66" ry="52"/>', P("white"), PAL["white"][2], True),
    ('<circle cx="124" cy="66" r="42"/>', P("white"), PAL["white"][2], False),
    ('<path d="M150,52 L194,64 C202,67 202,77 194,80 L150,88 Z"/>', P("gold"), PAL["gold"][2], True),
    ('<path d="M54,100 C86,84 132,98 140,124 C132,154 84,164 20,150 C26,124 36,108 54,100 Z"/>',
     P("slate"), PAL["slate"][2], True),
    ('<path d="M20,150 C26,130 34,116 46,106 C54,124 56,142 52,156 C40,156 28,154 20,150 Z"/>',
     P("coal"), PAL["coal"][2], True),
], ('<circle cx="184" cy="76" r="7" fill="#E2333A"/>' + line("M152,70 L188,70")
    + eye(134, 56, 10, 13) + gloss("M92,52 C96,38 108,28 122,26") + gloss("M74,104 C90,98 108,100 120,108", 9)),
    G("white", "slate", "coal", "orange", "gold"), "a rare gull spotted: a chubby standing gull, wings folded")

# --- puffin: black back and head, white face and chest, big striped orange-red beak, orange feet
critter("puffin", [
    ('<path d="M74,170 L88,170 L88,182 L104,194 L60,194 L74,182 Z"/>', P("orange"), PAL["orange"][2], True),
    ('<path d="M108,170 L122,170 L122,182 L138,194 L94,194 L108,182 Z"/>', P("orange"), PAL["orange"][2], True),
    ('<ellipse cx="96" cy="124" rx="62" ry="58"/>', P("coal"), PAL["coal"][2], True),
    ('<circle cx="98" cy="64" r="48"/>', P("coal"), PAL["coal"][2], False),
    ('<path d="M136,40 C164,44 190,64 196,86 C184,100 160,104 136,98 Z"/>', P("red"), PAL["red"][2], True),
    ('<path d="M136,40 C142,41 148,43 152,45 L152,101 C146,101 140,100 136,98 Z"/>', P("gold"), PAL["gold"][2], True),
], ('<ellipse cx="108" cy="130" rx="38" ry="44" fill="url(#white)"/>'
    '<path d="M70,62 C70,40 94,30 118,36 C128,40 134,52 132,70 C130,88 120,98 100,98 C80,98 70,82 70,62 Z" '
    'fill="url(#white)" stroke="#14121C" stroke-width="7"/>'
    '<path d="M44,104 C64,98 84,110 88,134 C90,156 74,170 52,164 C40,146 38,122 44,104 Z" fill="url(#coalw)" '
    'stroke="#14121C" stroke-width="7"/>'
    + line("M168,56 C176,64 180,76 178,88")
    + eye(108, 58, 10, 13) + gloss("M60,52 C62,38 74,24 90,20") + gloss("M60,112 C66,106 74,106 80,112", 8)),
    G("coal", "red", "gold", "orange") + G("white", y1=30, y2=180)
    + grad("coalw", "slate", 100, 170).replace("#B9C9DC", "#7A809E").replace("#7086A6", "#3D4056"),
    "a rare puffin spotted: black back, white face and chest, striped orange-red beak, orange feet")

# --- otter: sitting up, big head, warm brown with a cream face and belly, holding a pink scallop shell
critter("otter", [
    ('<path d="M138,168 C172,176 200,160 198,128 C186,146 166,152 142,148 Z"/>', P("brown"), PAL["brown"][2], True),
    ('<circle cx="54" cy="30" r="17"/>', P("brown"), PAL["brown"][2], True),
    ('<circle cx="146" cy="30" r="17"/>', P("brown"), PAL["brown"][2], True),
    ('<ellipse cx="100" cy="146" rx="58" ry="46"/>', P("brown"), PAL["brown"][2], True),
    ('<circle cx="100" cy="74" r="58"/>', P("brown"), PAL["brown"][2], True),
], ('<circle cx="54" cy="30" r="8" fill="#6B3A16"/><circle cx="146" cy="30" r="8" fill="#6B3A16"/>'
    '<ellipse cx="100" cy="156" rx="40" ry="34" fill="url(#cream)"/>'
    '<ellipse cx="100" cy="96" rx="40" ry="28" fill="url(#cream)" stroke="#14121C" stroke-width="7"/>'
    + line("M62,92 L36,86") + line("M62,104 L38,110") + line("M138,92 L164,86") + line("M138,104 L162,110")
    + '<path d="M88,82 L112,82 C114,82 115,85 113,88 L102,97 C101,98 99,98 98,97 L87,88 C85,85 86,82 88,82 Z" fill="#14121C"/>'
    + line("M86,104 Q93,113 100,104 Q107,113 114,104")
    + '<path d="M100,178 L68,146 C72,124 128,124 132,146 Z" fill="url(#pink)" stroke="#14121C" stroke-width="7" stroke-linejoin="round"/>'
    + line("M100,174 L88,136") + line("M100,174 L112,136")
    + '<ellipse cx="68" cy="148" rx="15" ry="13" fill="url(#brown)" stroke="#14121C" stroke-width="7"/>'
      '<ellipse cx="132" cy="148" rx="15" ry="13" fill="url(#brown)" stroke="#14121C" stroke-width="7"/>'
    + eye(76, 64) + eye(124, 64) + gloss("M56,58 C58,40 72,26 90,22") + gloss("M80,136 C86,132 94,131 100,131", 7)),
    G("brown") + G("cream", y1=70, y2=190) + G("pink", y1=126, y2=178),
    "a rare otter spotted: sitting up, warm brown, cream face and belly, holding a pink shell")

# --- turtle: a sea turtle, a green Lego shell (brick plates, studs) on a gold rim, teal flippers and head
critter("turtle", [
    ('<path d="M44,140 C26,150 12,166 10,182 C30,182 52,170 62,154 Z"/>', P("teal"), PAL["teal"][2], True),
    ('<path d="M120,140 C150,146 178,166 186,190 C158,192 128,180 108,158 Z"/>', P("teal"), PAL["teal"][2], True),
    ('<path d="M20,136 L4,128 L18,146 Z"/>', P("teal"), PAL["teal"][2], True),
    ('<path d="M148,134 C150,110 156,92 170,84 L190,92 C196,110 186,126 166,140 Z"/>', P("teal"), PAL["teal"][2], True),
    ('<circle cx="172" cy="94" r="28"/>', P("teal"), PAL["teal"][2], False),
    ('<rect x="10" y="124" width="158" height="26" rx="13"/>', P("gold"), PAL["gold"][2], True),
    ('<path d="M18,132 C18,42 160,42 160,132 Z"/>', P("green"), PAL["green"][2], True),
], (line("M64,68 C72,88 72,110 68,132") + line("M114,68 C106,88 106,110 110,132")
    + stud(42, 110, 11, "green") + stud(89, 104, 15, "green") + stud(136, 110, 11, "green")
    + line("M44,134 L44,150") + line("M89,134 L89,150") + line("M134,134 L134,150")
    + eye(178, 86, 9, 12) + line("M164,108 Q176,116 190,106")
    + gloss("M78,77 C86,72 96,71 102,73", 9) + gloss("M156,86 C158,78 164,72 170,70", 8)),
    G("green", y1=54, y2=132) + G("teal") + G("gold", y1=124, y2=150),
    "a rare sea turtle spotted: green Lego brick-plate shell with studs on a gold rim")

# --- bottle: a message in a bottle lying diagonal, cork up-right, a rolled note with a red ribbon inside
R = "translate(0,-8) rotate(-40 107 105)"
critter("bottle", [
    (f'<rect x="180" y="86" width="26" height="38" rx="8" transform="{R}"/>', P("corkr"), PAL["cork"][2], True),
    (f'<path d="M126,61 C152,61 152,84 168,84 L182,84 L182,126 L168,126 C152,126 152,149 126,149 L36,149 '
     f'C20,149 10,139 10,123 L10,87 C10,71 20,61 36,61 Z" transform="{R}"/>', P("glass"), PAL["teal"][2], False),
    (f'<rect x="172" y="78" width="16" height="54" rx="6" transform="{R}"/>', P("glass"), PAL["teal"][2], True),
], (f'<g transform="{R}">'
    '<rect x="30" y="82" width="92" height="46" rx="12" fill="url(#cream)" stroke="#14121C" stroke-width="7"/>'
    '<rect x="68" y="82" width="16" height="46" rx="5" fill="url(#redr)" stroke="#14121C" stroke-width="7"/>'
    + line("M44,96 L58,96", 7, "#C9A66B") + line("M44,114 L58,114", 7, "#C9A66B")
    + line("M96,96 L110,96", 7, "#C9A66B") + line("M96,114 L110,114", 7, "#C9A66B")
    + gloss("M30,72 L118,72") + gloss("M150,76 C156,84 162,88 168,90", 8)
    + '</g>'),
    grad("glass", "teal", 0, 210, (40, 107, 105)) + grad("corkr", "cork", 0, 210, (40, 107, 105))
    + grad("cream", "cream", 60, 150) + grad("redr", "red", 60, 150),
    "a message in a bottle found: sea-glass bottle, cork, a rolled note with a red ribbon")

# --- view: a chunky telescope on a thick tripod, pointing up-right at the view
T = "rotate(-28 95 95)"
critter("view", [
    (leg(95, 104, 104, 190, 20, 18), P("orangeD"), "#8E3806", True),
    (leg(92, 104, 36, 186, 20, 18), P("orange"), PAL["orange"][2], True),
    (leg(98, 104, 156, 186, 20, 18), P("orange"), PAL["orange"][2], True),
    (f'<rect x="8" y="82" width="28" height="26" rx="7" transform="{T}"/>', P("coalr"), PAL["coal"][2], True),
    (f'<rect x="28" y="72" width="124" height="46" rx="12" transform="{T}"/>', P("bluer"), PAL["blue"][2], True),
    (f'<rect x="140" y="62" width="52" height="66" rx="14" transform="{T}"/>', P("bluer"), PAL["blue"][2], True),
    (f'<rect x="128" y="66" width="18" height="58" rx="6" transform="{T}"/>', P("goldr"), PAL["gold"][2], True),
    (f'<ellipse cx="192" cy="95" rx="13" ry="33" transform="{T}"/>', P("goldr"), PAL["gold"][2], True),
    ('<circle cx="95" cy="100" r="17"/>', P("gold"), PAL["gold"][2], True),
], (f'<g transform="{T}"><ellipse cx="194" cy="95" rx="6" ry="22" fill="#BDF1FF" stroke="#14121C" stroke-width="7"/>'
    + gloss("M44,84 L118,84") + gloss("M154,74 L178,74", 9) + '</g>'
    + '<circle cx="95" cy="100" r="6" fill="#14121C"/>'),
    G("orange", "gold", y1=90, y2=195) + grad("orangeD", "orange", 90, 195).replace("#FFC266", "#F09A4A").replace("#FF7419", "#D2580C")
    + grad("bluer", "blue", 20, 160, (28, 95, 95)) + grad("goldr", "gold", 20, 160, (28, 95, 95))
    + grad("coalr", "coal", 60, 160, (28, 95, 95)),
    "a scenic viewpoint found: a chunky blue telescope on a thick orange tripod")
