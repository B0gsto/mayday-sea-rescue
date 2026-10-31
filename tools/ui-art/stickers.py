#!/usr/bin/env python3
"""The small UI-kit stickers (uia2, CLAUDE.md "UI art"): one shape each, drawn in the build arrow's layers (white
sticker rim, hard dark outline, darker lip under a bold gradient, a soft gloss stroke). Writes the SVG sources to
art/source/ui/<name>.svg and renders build/ui-art/<name>.png (2x).   usage: python3 tools/ui-art/stickers.py
Rotating sprites (the map arrow) have no lip and keep their box (--keep) so the game spins them about its centre."""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC, OUT = ROOT / "art/source/ui", ROOT / "build/ui-art"
INK = "#14121C"

STAR = "M100,18 L122,72 L180,76 L135,113 L150,170 L100,138 L50,170 L65,113 L20,76 L78,72 Z"
HEART = "M100,176 C40,132 18,104 18,72 C18,44 40,26 64,26 C82,26 94,36 100,50 C106,36 118,26 136,26 C160,26 182,44 182,72 C182,104 160,132 100,176 Z"
ARROW = "M100,14 L170,178 Q172,184 166,181 L100,142 L34,181 Q28,184 30,178 Z"
STUD = "M100,30 A70,70 0 1,1 99.9,30 Z"
# four thick arms round an open centre: the map arrow shows through it when they stack
CROSS = ("M89,8 L111,8 L111,56 L89,56 Z M89,144 L111,144 L111,192 L89,192 Z M8,89 L56,89 L56,111 L8,111 Z "
         "M144,89 L192,89 L192,111 L144,111 Z")
GEM = "M100,14 L186,100 L100,186 L14,100 Z"
# a speech bubble, tail down-left
CHAT = "M40,30 L160,30 Q186,30 186,56 L186,118 Q186,144 160,144 L92,144 L56,176 Q50,181 51,173 L58,144 L40,144 Q14,144 14,118 L14,56 Q14,30 40,30 Z"


def stud_top(light, dark):
    """a Lego stud's flat top: a lighter raised disc inside a dark ring, a short gloss arc"""
    return (f'<circle cx="100" cy="100" r="46" fill="{light}" stroke="{dark}" stroke-width="7"/>'
            '<path d="M70,88 A32,32 0 0,1 94,66" fill="none" stroke="#fff" stroke-opacity="0.7" stroke-width="9" stroke-linecap="round"/>')


def sticker(d, top, bottom, lip, lip_dy=12, gloss=None, extra=""):
    """d: the shape; top/bottom: its gradient; lip: the shade under it, lip_dy units down (0: none)."""
    g = f'<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'
    shift = [0, lip_dy] if lip_dy else [0]
    p = lambda fill, stroke="", w=0, dy=0: (f'<path d="{d}" transform="translate(0,{dy})" fill="{fill}"'
                                            + (f' stroke="{stroke}" stroke-width="{w}" stroke-linejoin="round"' if w else "") + "/>")
    layers = "".join(p("#fff", "#fff", 30, dy) for dy in shift) + "".join(p(INK, INK, 12, dy) for dy in shift)
    layers += (p(lip, dy=lip_dy) if lip_dy else "") + p("url(#g)")
    if gloss:
        layers += f'<path d="{gloss}" fill="none" stroke="#fff" stroke-opacity="0.55" stroke-width="10" stroke-linecap="round"/>'
    return g, layers + extra


def svg(name, defs_layers, box=(-22, -22, 244, 256), note=""):
    x, y, w, h = box
    defs, layers = defs_layers
    text = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" width="{w}" height="{h}">'
            f"<!-- {note} --><defs>{defs}</defs>{layers}</svg>\n")
    (SRC / f"{name}.svg").write_text(text)


STICKERS = {
    "star_on": (sticker(STAR, "#FFE45C", "#FFAE00", "#C27400", gloss="M58,84 L84,82 L95,52"),
                "a building level earned / the weekly streak day: gold Lego star"),
    "star_off": (sticker(STAR, "#B4BCCB", "#8A94A8", "#5E677B"), "a level not built yet: the same star in pale slate"),
    "heart": (sticker(HEART, "#FF8FA0", "#EE3D57", "#AE1F36", gloss="M40,66 C40,52 52,44 64,44"),
              "the companion's love hearts (a pat, a treat)"),
    "pip_on": (sticker(STUD, "#5FCF66", "#2FA84A", "#1A6E2E", lip_dy=16, extra=stud_top("#8BEA86", "#1E7A34")),
               "a filled seat on your craft: a green Lego stud (flat top, raised ring, side lip)"),
    "pip_full": (sticker(STUD, "#F0544A", "#D9202A", "#8E1219", lip_dy=16, extra=stud_top("#FF9A8E", "#A3161E")),
                 "every seat filled: the studs turn red"),
    "pip_off": (sticker(STUD, "#8C95A8", "#6E778B", "#4A5264", lip_dy=16,
                        extra='<circle cx="100" cy="100" r="44" fill="#3A4150" stroke="#14121C" stroke-width="6"/>'),
                "an empty seat: a hollow grey socket"),
    "map_cross": (sticker(CROSS, "#FFE45C", "#FFB000", "#C27400", lip_dy=6), "the full map's gamepad crosshair"),
    "map_player": (sticker(ARROW, "#6CC4FF", "#1C78E0", None, lip_dy=0,
                           extra='<path d="M100,30 L100,136 L42,170 Z" fill="#fff" fill-opacity="0.35"/>'),
                   "you on the map: a blue arrow, tip up, its box centred to spin about"),
    "chat": (sticker(CHAT, "#8FD3FF", "#3D9BF0", "#1F64B5", gloss="M36,70 C36,56 44,50 56,50",
                     extra="".join(f'<circle cx="{x}" cy="87" r="13" fill="#fff" stroke="{INK}" stroke-width="6"/>' for x in (64, 100, 136))),
             "idle crew chatting (WorkerController): a wordless speech bubble, three dots"),
}


def beacon():
    """The onboarding beacon's mark: a gem over a short stem that ends in a point (one sprite, 80x120 billboard)."""
    stem = "M88,190 L112,190 L104,330 Q100,342 96,330 Z"
    gem_defs, gem = sticker(GEM, "#FFB07F", "#E1601D", "#A94816", gloss="M50,92 L96,46")
    stem_l = "".join(f'<path d="{stem}" fill="{c}" stroke="{c}" stroke-width="{w}" stroke-linejoin="round"/>'
                     for c, w in (("#fff", 30), (INK, 12)))
    stem_l += f'<path d="{stem}" fill="#E1601D"/>'
    facet = '<path d="M100,62 L138,100 L100,138 L62,100 Z" fill="#fff" stroke="' + INK + '" stroke-width="6" stroke-linejoin="round"/>'
    return gem_defs, stem_l + gem + facet


def transport_pin():
    """The drop-off pad's marker: the waypoint pin in rescue blue with a white medical cross in its head."""
    src = (SRC / "waypoint_pin.svg").read_text()
    assert all(k in src for k in ("#FF7A6B", "#D9202A", "#A3161E")), "the red template colours moved"
    src = src.replace("#FF7A6B", "#7CC2FF").replace("#D9202A", "#2A7FE6").replace("#A3161E", "#1A55A8")
    cross = ('<path d="M87,54 L113,54 L113,75 L134,75 L134,101 L113,101 L113,122 L87,122 L87,101 L66,101 L66,75 L87,75 Z"'
             f' fill="#fff" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>')
    (SRC / "transport_pin.svg").write_text(src.replace("</svg>", cross + "</svg>"))


def tap():
    """The tablet cue's touch glyph: a Lego-yellow hand, index finger up, three tap ticks over the fingertip."""
    finger = "M80,58 Q80,40 96,40 Q112,40 112,58 L112,104 L80,104 Z"
    palm = "M56,100 Q56,86 70,86 L150,86 Q166,86 166,102 L166,150 Q166,184 132,184 L92,184 Q56,184 56,150 Z"
    thumb = "M64,122 L36,104 Q24,96 31,85 Q39,74 52,82 L80,100 Z"
    defs, hand = sticker(f"{finger} {palm} {thumb}", "#FFE45C", "#FFB000", "#C27400", lip_dy=10,
                         gloss="M90,60 L90,92")
    knuckles = f'<path d="M124,88 L124,112 M146,88 L146,112" fill="none" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>'
    ticks_d = "M68,44 L52,30 M96,24 L96,4 M124,44 L140,30"
    ticks = "".join(f'<path d="{ticks_d}" fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round"/>'
                    for c, w in (("#fff", 30), (INK, 18), ("#fff", 7)))
    return defs, ticks + hand + knuckles


def render(name, w, h, keep=False):
    subprocess.run([sys.executable, str(ROOT / "tools/ui-art/render.py"), str(SRC / f"{name}.svg"),
                    str(OUT / f"{name}.png"), "--size", str(w), str(h)] + (["--keep"] if keep else []), check=True)


OUT.mkdir(parents=True, exist_ok=True)
for name, (layers, note) in STICKERS.items():
    svg(name, layers, note=note)
    render(name, 244, 256, keep=name == "map_player")
svg("beacon_mark", beacon(), box=(-22, -10, 244, 372), note="the onboarding beacon over the goal: gem + stem")
render("beacon_mark", 244, 372)
transport_pin()
subprocess.run([sys.executable, str(ROOT / "tools/ui-art/render.py"), str(SRC / "transport_pin.svg"),
                str(OUT / "transport_pin.png"), "--size", "324", "324", "--scale", "3"], check=True)
svg("tap", tap(), note="the build tablet cue on touch: tap here")
render("tap", 244, 256)
