# 18 · UI art

Screen UI sprites (icons, arrows, edge pointers, toasts, pins, badges) are Claude-designed vector art, not generated
images and never text glyphs (owner test 2026-10-28). Ids: `src/shared/Config/UiImages.luau`.

## Make one

1. Hand-author the SVG (or HTML) in `art/source/ui/<name>.svg`.
2. Render: `python3 tools/ui-art/render.py art/source/ui/<name>.svg build/ui/<name>.png --scale 2` (headless Chrome,
   transparent, trimmed; `--keep` for a sprite that rotates about its centre).
3. Contact sheet to an Opus art director; ship at 8.5+.
4. Upload: `~/RobloxProjects/tools/assets.py upload . <png> --type Image`; paste the id into `UiImages` with a comment
   naming the source file. PNGs stay local.

Batch makers: `tools/ui-art/kit_icons*.py`, `gems.py`, `critters.py`, `stickers.py`, `pin_variants.py`,
`pip_variants.py`. Blender only for hero art 200 px+ on screen.

## Style

- White sticker rim, hard dark outline, bold vertical gradient with a lip; one idea per sprite.
- At least ~32 pt on a phone; labels 14 pt+, drawn in code, 1-3 words.
- No outline rings round HUD buttons; no flashing or pulsing orange. Presence is a red badge, one bounce or a
  lifted tile.

## UiImages tables

| Table | What |
|---|---|
| `Hud` | Go back pill, fuel chevron, coin, exit, minimap ring, panel |
| `Markers` | Waypoint and transport pins, edge pointer, build arrow, beacon mark |
| `Badges`, `Pip` | Red badge, streak and stage pips |
| `VehicleArt` | Boat card art |
| `Pad` | Touch drive pad (go, brake, left, right, up, down, exit) |
| `Kit` | Menu and kit icons (shop, quests, album, companion, crew, skills, settings, map, boat to me, home, spin, fuel ...) |
| `SettingsArt` | Settings row glyphs |
| `Stickers` | Album island stamps, critters |

## Open requests

| Sprite | For | Now |
|---|---|---|
| Pirate edge arrow | `PirateController` | Red pin with a flag Frame |
