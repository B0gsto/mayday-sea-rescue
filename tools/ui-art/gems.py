#!/usr/bin/env python3
"""The sea zone banner's rarity gems (docs/29 B, CLAUDE.md "UI art"): one cut gem in the sticker layers (white rim,
hard dark outline, lip, bold gradient, facets, gloss), one colour per rarity (Rarity.luau tiers).
Writes art/source/ui/gem_<rarity>.svg and renders build/ui-art/gem_<rarity>.png (2x).   usage: python3 tools/ui-art/gems.py"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC, OUT = ROOT / "art/source/ui", ROOT / "build/ui-art"
INK = "#14121C"
GEM = "M60,34 L140,34 L180,82 L100,178 L20,82 Z"
TIERS = {  # top, bottom, lip, facet light
    "rare": ("#9CE4FF", "#1E86F0", "#0F4FA8", "#D8F5FF"),
    "epic": ("#DBBDFF", "#8445F5", "#4F1FB0", "#F0E2FF"),
    "legendary": ("#FFE98A", "#FFAE0F", "#B56A00", "#FFF7CC"),
    "mythic": ("#FFB5E0", "#F2459C", "#A81F66", "#FFE3F3"),
}

for name, (top, bottom, lip, light) in TIERS.items():
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="-20 -20 240 240" width="128" height="128"><!-- {name} gem -->
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient></defs>
<path d="{GEM}" transform="translate(0,8)" fill="#fff" stroke="#fff" stroke-width="34" stroke-linejoin="round"/>
<path d="{GEM}" transform="translate(0,8)" fill="{INK}" stroke="{INK}" stroke-width="16" stroke-linejoin="round"/>
<path d="{GEM}" transform="translate(0,8)" fill="{lip}"/>
<path d="{GEM}" fill="url(#g)"/>
<path d="M20,82 L180,82 L140,34 L60,34 Z" fill="{light}" opacity="0.55"/>
<path d="M66,82 L100,34 L134,82 L100,178 Z" fill="#fff" opacity="0.28"/>
<path d="M60,34 L66,82 M140,34 L134,82 M100,34 L66,82 M100,34 L134,82 M20,82 L180,82 M66,82 L100,178 M134,82 L100,178" fill="none" stroke="{INK}" stroke-opacity="0.35" stroke-width="4" stroke-linejoin="round"/>
<path d="M70,46 L104,46" fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round" opacity="0.9"/>
<path d="{GEM}" fill="none" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>
</svg>
"""
    src = SRC / f"gem_{name}.svg"
    src.write_text(svg)
    subprocess.run(
        [sys.executable, str(ROOT / "tools/ui-art/render.py"), str(src), str(OUT / f"gem_{name}.png"), "--size", "160", "160"],
        check=True,
    )
