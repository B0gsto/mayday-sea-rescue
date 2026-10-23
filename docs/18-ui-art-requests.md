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
