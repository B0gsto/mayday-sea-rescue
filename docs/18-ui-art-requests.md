# 18 · UI art requests

2026-10-23 (WP7, phone). 2D art the phone needs that code can't draw well. Generate with Antigravity Gemini
(images-via-antigravity), save under `assets/ui/<set>/`, upload with `~/RobloxProjects/tools/assets.py upload` and paste each id
into the `src/shared/Config/UiImages.luau` key shown. Until a key has an id, the UI draws its Frame-glyph
placeholder, so nothing breaks while art is missing. No text in any image.

Style for all: the phone's look (iOS dark mode, the Hud set's navy and rescue orange), clean vector shapes,
soft single-light shading, no outlines thicker than ~6% of the canvas, centred with ~10% padding.

## Vehicles app (`UiImages.VehicleArt`, set `assets/ui/vehicles/`)

| Key | File | Size | Alpha | Description | Where |
|---|---|---|---|---|---|
| `Engine` | `upgrade_engine.png` | 256×256 | transparent | Full-colour badge icon: a chunky outboard motor with a small orange speed streak. Reads "faster" at 26 px | Vehicles card, upgrade tile 1 (Engine) |
| `Hull` | `upgrade_hull.png` | 256×256 | transparent | Full-colour badge icon: a boat hull in side view riding over a wave, with a steel shield shape behind it. Reads "steady in waves" | Upgrade tile 2 (Hull) |
| `Fit` | `upgrade_seat.png` | 256×256 | transparent | Full-colour badge icon: an orange boat seat with a small green "+" bubble at its top right. Reads "+1 aboard" | Upgrade tile 3 (Extra seat) |
| `Speed` | `stat_speed.png` | 128×128 | transparent | Monochrome light grey (#B4BEC5) speedometer glyph, solid fill | Stat row 1, left of the bar (20 px) |
| `People` | `stat_people.png` | 128×128 | transparent | Monochrome light grey (#B4BEC5) two-person silhouette (head and shoulders) | Stat row 2 |
| `Tough` | `stat_tough.png` | 128×128 | transparent | Monochrome light grey (#B4BEC5) shield glyph | Stat row 3 |
| `Check` | `check.png` | 128×128 | transparent | Green (#30D158) filled circle with a white tick | "Fitted" on an upgrade tile; "out now" on the 3D stage |

## Pets app (`UiImages.Phone.Pets`, set `assets/ui/phone_v2/`)

| Key | File | Size | Alpha | Description | Where |
|---|---|---|---|---|---|
| `Pets` | `pets.png` | 512×512 | transparent corners | iOS-style app squircle like the other phone_v2 tiles: warm orange (#FF6B1A) gradient, a big white paw print centred, a tiny navy dog tag hanging off one toe. Reads "my pets" at 66 du | Phone home grid (Pets app). Until uploaded `PetsApp.icon` draws a flat paw tile |

Portraits inside the app are live 3D ViewportFrames of Bosun and each pet, so they need no art.

## Settings rows (`UiImages.SettingsArt`, set `assets/ui/settings/`)

Pure white (#FFFFFF) monochrome SF-Symbols-style glyphs, 96×96, transparent. The coloured iOS tile behind
each stays in code. Add each as `SettingsArt.<key> = "rbxassetid://…"`.

| Key | Glyph | Row(s) |
|---|---|---|
| `waves` | three stacked waves | Seasick-safe, Ocean |
| `reset` | circular arrow | Reset |
| `horizon` | level line inside a circle | Horizon lock |
| `fov` | wide-angle cone from an eye | Field of view |
| `bob` | head with small up/down arrows | Head bob |
| `shake` | phone shape with shake marks | Shake |
| `plus` | crosshair / plus in a circle | Sensitivity |
| `speed` | speedometer | Speed FOV |
| `blur` | three motion lines | Motion blur |
| `drops` | water drops | Lens spray |
| `half` | half-filled circle | Colour assist |
| `pause` | pause bars | Reduce motion |
| `tap` | finger tapping a dot | Hold to tap |
| `peak` | rock and plant | Rocks & plants |
| `note` | single music note | Master |
| `sparkle` | four-point sparkle | Effects |
| `wave` | radio wave arcs | Radio |
| `notes` | two beamed notes | Music |
| `bubble` | speech bubble | Voices |
| `horn` | air horn | Mute horns |
| `burst` | siren light with rays | Mute sirens |
| `no` | circle with a slash | Mute radios |

The letter rows ("A" Text size, "G" G-lean) stay as type.

## Album app and stamp slam (`UiImages.Phone.Album`, `UiImages.Stickers`, set `assets/ui/album/`)

docs/21 §3. Until a key has an id, `UI/Sticker` draws its Frame-glyph placeholder (round island stamp,
rounded-square collectible, grey silhouette until found). Every sticker 512×512, transparent, die-cut
sticker look: a thick white border (~6% of the canvas) and a soft drop shadow. Found and silhouette are
the same file: the code greys a sticker out, so draw only the colour version. Add each as
`Stickers.<key> = "rbxassetid://…"`.

| Key | File | Description | Where |
|---|---|---|---|
| `Album` (in `Phone`) | `phone_v2/album.png` | iOS app squircle like the other phone_v2 tiles: turquoise (#1FB5A8) gradient, an open sticker book with a round red rubber-stamp mark on the right page | Phone home grid. Until then `AlbumApp.icon` draws a flat tile |
| `SkerryIsle` | `stamp_skerry.png` | Round rubber-stamp mark, slate blue (#5B7F95) ink, slightly uneven inked edge and an inner ring: a seal on a granite rock with the Skerry Light behind | Album page stamp; the stamp slam; the float over the stamp post |
| `StElowensMount` | `stamp_elowen.png` | Same stamp style, warm brown (#8C6B4F): a castle on a cone of rock with a causeway | as above |
| `PuffinIsle` | `stamp_puffin.png` | Same, sea-pink (#E2557A): a puffin in front of twin green humps | as above |
| `Penwyn` | `stamp_penwyn.png` | Same, harbour blue (#2F9BD6): a white windmill on a hill over coloured cottages | as above |
| `WreckReef` | `stamp_wreck.png` | Same, rust (#B5562B): a cargo ship beached bow-high on a reef | as above |
| `TheArches` | `stamp_arches.png` | Same, violet (#7A6FB0): a giant natural sea arch with a needle stack | as above |
| `GannetRock` | `stamp_gannet.png` | Same, red (#D23B3B): a red-and-white lighthouse on a white-streaked rock, a gannet diving | as above |
| `MermaidLagoon` | `stamp_lagoon.png` | Same, turquoise (#1FB5A8): two palms on a white-sand isle over a turquoise lagoon | as above |
| `Bottle` | `sticker_bottle.png` | Rounded-square sticker: a green glass message bottle with a cork and a rolled paper inside, on wet sand | Every island's bottle slot |
| `View` | `sticker_view.png` | Rounded-square sticker: a brass telescope on a wooden tripod looking out to sea | Every island's viewpoint slot |
| `SealPup`, `Gull`, `Puffin`, `Otter`, `Turtle` | `critter_<species>.png` | Rounded-square sticker per rare animal (the rare colour variant of Config/Wildlife: golden seal pup, white-gold gull, …), head and shoulders, friendly | The critter slot of the islands that use that species |
