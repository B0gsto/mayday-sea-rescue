# 18 · UI art requests

2D art for the no-phone UI (docs/23 (m), WP-23a). Generate with Antigravity Gemini, save under
`marketing/ui/icons/`, upload, and paste each `rbxassetid://` into the kit's image table when WP-23b lands.
Until an id exists the kit draws its placeholder, so nothing blocks on art.

`src/shared/Config/UiImages.luau` still holds the old `Phone`, `Hud`, `SettingsArt` and `Stickers` keys. The
new kit will add its own table; do not wire new icons into the old phone sets.

## Style

- Roblox simulator style: chunky rounded shapes, thick dark outline, bright vertical gradient, one soft
  highlight, transparent background.
- One icon = one idea. Readable at 64 px on a phone.
- No text in the image. Labels are 1–3 words under the button, drawn in code.
- No mock-up background, no watermark, no drop shadow baked into the alpha.
- Square 512×512 for panel icons; 256×256 for small glyphs; 1024×1024 only for a hero shop card.
- Keep about 8% padding so the outline never touches the edge.
- A subtle Lego stud texture is allowed on panel headers and price buttons, not on every icon.

## Left button bar

| Key | File | Description |
|---|---|---|
| `Shop` | `shop.png` | A small market stall with a striped awning and a coin |
| `Quests` | `quests.png` | A rolled map with a red `!` pin |
| `Album` | `album.png` | An open sticker book with a round stamp |
| `Companion` | `companion.png` | A dog collar with a bone tag |
| `Crew` | `crew.png` | Three simple crew heads in a row |
| `Settings` | `settings.png` | A chunky gear with a wrench notch |
| `BoatToMe` | `boat_to_me.png` | A small boat with a curved arrow toward the player |
| `Map` | `map.png` | A folded chart with a compass rose |

## Shared kit glyphs

| Key | File | Description |
|---|---|---|
| `Cash` | `cash.png` | A stack of two gold coins with a wave mark |
| `Robux` | `robux.png` | The Robux diamond glyph, white on green |
| `Close` | `close.png` | A bold red square with a white X |
| `Lock` | `lock.png` | A brass padlock, front on |
| `Check` | `check.png` | A green circle with a white tick |
| `Star` | `star.png` | A single gold star with a thick outline |
| `Timer` | `timer.png` | A round clock with a small orange hand |
| `Upgrade` | `upgrade.png` | An upward arrow over a brick |
| `Build` | `build.png` | A trowel and a small brick wall |
| `Paint` | `paint.png` | A paint roller with a bright swatch |
| `Launch` | `launch.png` | A boat bow over a white arrow |
| `Info` | `info.png` | A round `i` badge |

## Panels and cards

| Key | File | Description |
|---|---|---|
| `PanelCorner` | `panel_corner.png` | 9-slice corner ornament for the kit panel, 128×128 |
| `CardGradient` | `card_gradient.png` | 9-slice bright gradient card, 256×128 |
| `PriceButton` | `price_button.png` | 9-slice green price button, 256×96 |
| `StudTile` | `stud_tile.png` | Small tiling Lego stud texture, 128×128, low contrast |
| `QuestGiver` | `quest_giver.png` | A speech bubble with a red `!` |
| `PadlockRank` | `padlock_rank.png` | A padlock with a small rank chevron behind it |

## Build tablet cards

| Key | File | Description |
|---|---|---|
| `Dock` | `build_dock.png` | A jetty with a lamp and a small boat |
| `Boathouse` | `build_boathouse.png` | A blue boathouse with a roll-up door |
| `Lookout` | `build_lookout.png` | A hut on legs with a ladder and a lamp |
| `Station` | `build_station.png` | A small station front with a beacon |
| `Hangar` | `build_hangar.png` | A wide hangar with a helicopter tail showing |
| `SubPen` | `build_subpen.png` | A concrete pen with a periscope |
| `CrewQuarters` | `build_crew.png` | A bunkhouse with a cup sign |
| `SpareLot` | `build_spare.png` | A flat green plate with builder's pegs |

## Settings glyphs

Reuse the existing `SettingsArt` shapes where they still fit: `waves`, `reset`, `horizon`, `fov`, `bob`,
`shake`, `plus`, `speed`, `blur`, `drops`, `half`, `pause`, `tap`, `note`, `sparkle`, `notes`, `bubble`,
`horn`, `burst`. Drop `wave` and `no` (radio mute) because the dispatch radio is cut. Keep `horn` and `burst`
for boat horns and sirens. Redraw them in the simulator style, white on a coloured square.

## Album stickers

The current `UiImages.Stickers` set is the source of truth for keys. Keep `SkerryIsle`, `PuffinIsle`,
`Penwyn`, `WreckReef`, `TheArches`, `GannetRock`, `MermaidLagoon`, `Bottle`, `View`, `SealPup`, `Gull`,
`Puffin`, `Otter`, `Turtle` and `Wreck`. Drop `StElowensMount` (the island is cut). The `Wreck` key currently
reuses the Wreck Reef stamp art; a separate wreck sticker is optional.

Sticker style: 512×512, die-cut with a thick white border and soft shadow, same round-stamp look for island
stamps and rounded-square look for collectibles. Draw the colour version only; the code greys found/unfound.

## Delivery

1. Generate at 1024 or 512, export transparent PNG.
2. Check at 64 px and 128 px on a dark and a light panel.
3. Upload; add the id to the new kit table and to this doc.
4. If an icon cannot be read at 64 px, simplify it; do not add detail.
