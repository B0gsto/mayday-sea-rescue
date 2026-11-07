# 07 · Store page

The public face of the game: name, icon, description, trailer. Store text lives in `marketing/description.md` and
`marketing/listing.json`; prices in `04-monetization.md`. Show only what is live in the current build.

**Thumbnails and key art are the owner's (2026-10-27).** We never make, render, generate or store them (no
`marketing/thumbnails*`). The experience icon, item icons and badges are ours.

## 1. What the page sells

One promise: **upgrade your rescue boat 50 times and save everyone at sea.**

1. The boat growing from a jet ski to the Rocket Cutter, one big piece per level.
2. The rescue: drive near a survivor, they climb aboard, Go back zooms you home.
3. The sea: rarer survivors farther out, zone colours, pirates, the Deep Spin dive.

Tone: warm, bright, toy-like. Not military, not grim, not photoreal.

## 2. Platform rules

| Area | Rule |
|---|---|
| Icon | 512x512, one subject, high contrast, no text, no fake UI or badges; test at 64 px |
| Video | 30 s, 1080p, real gameplay, no external links |
| Name | `Mayday: Sea Rescue`, no keyword stuffing |
| Description | What the game is in the first two lines; live features only; 6 players |
| Genre | Adventure / Simulation (set by the owner on the Creator Hub) |
| Maturity | Paid random items: yes (Deep Spin spins); questionnaire answered to match |
| Purchases | The page never mentions a sale or a timer |
| IP | Original coastguard world; say "brick-built", never a brand name |
| Social | Discord link on the experience and group pages (13+ only); never linked in game |

## 3. Icon

Rendered in Blender (`tools/store_icon_blender.py`, Lego style, Cycles): a real in-game boat or Bosun, readable at
64 px. A/B the icon for a week and keep the winner.

## 4. Trailer

Real play captured in the live build at 60 fps, edited to 30 s: the cold open on the jet ski, a pick-up, Go back,
a level-up slam, a stage change (jet ski to RIB), the far zones, a pirate chase, the Deep Spin dive. Game music only,
no voice-over. Refresh when a stage hull changes (Hydrofoil and Rocket Cutter are still placeholders: keep them out
until their art ships).

## 5. Before each scope change

- [ ] `marketing/description.md` lists only live features.
- [ ] Icon matches the current boat look.
- [ ] Trailer shows no placeholder hull and no cut feature (phone, town, cars, radio, ranks).
- [ ] Product icons and store text match `marketing/products.md`.

## 6. What we watch

Icon click-through (A/B), play rate, the new-player funnel (`tools/trail.py`: Joined, AtSea, FirstBoard,
FirstDelivery, FirstUpgrade, BackOut, FirstSpin, BoatL3/L5/L11), D1 and D7 retention.
