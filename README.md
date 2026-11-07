# Mayday: Sea Rescue

**Upgrade your rescue boat 50 times and save everyone at sea.**

A Roblox sea-rescue game for kids 8-15, many on phones. You start on a jet ski, pull survivors out of the water,
hit Go back to race home, and spend your pay on the next boat level: each one bolts on a new piece, and every ten
levels the boat becomes a new craft (Jet Ski, RIB, Lifeboat, Hydrofoil, Rocket Cutter). Farther sea zones hold
rarer survivors; your fuel tank decides how far you can go. Six players per server, each with a plot on a ring of
Lego islands.

The loop: **rescue -> Go back -> upgrade -> farther out -> repeat.**

## The design

[`docs/00-design.md`](docs/00-design.md) is the source of truth. Open work and live versions: [`docs/NEXT.md`](docs/NEXT.md).
Old designs live in [`docs/archive/`](docs/archive/) and git tag `pre-hub-cut`.

| # | Chapter | What it answers |
|---|---|---|
| 00 | [The design](docs/00-design.md) | The game today: loop, levels, world, systems, what was cut |
| 30 | [Boat levels](docs/30-boat-pivot.md) | Go back, Upgrade Station, the 50-level table, pacing |
| 31 | [Layout and fuel](docs/31-layout-and-fuel.md) | Plots, hotspots, sea zones, the fuel gauge |
| 04 | [Monetization](docs/04-monetization.md) | Robux products and rules |
| 05 | [Art direction](docs/05-art-direction.md) | Existing art kept, new art Lego or refined toy style |
| 06 | [Tools and pipeline](docs/06-tools-and-pipeline.md) | Code toolchain, publish, art pipeline, repo layout |
| 07 | [Store page](docs/07-store-page-thumbnails-and-trailer.md) | Store text, icon, trailer (thumbnails are the owner's) |
| 08 | [References](docs/08-references.md) | Games, look references, tech docs |
| 12 | [Asset list](docs/12-asset-list.md) | What exists and its status |
| 13 | [Release plan](docs/13-release-plan.md) | What is live, what is left, launch checklist |
| 18 | [UI art](docs/18-ui-art-requests.md) | Claude SVG sprites: how to make one, UiImages tables |
| 26 | [VFX](docs/26-vfx.md) | Effects rules, VFXKit, the bench |

## Conventions

- `(tune)` marks a starting number that playtests may move.
- `(verify)` marks an engine fact to check in Studio or the official docs.
- No choice UI in gameplay: actions are in the world. Exceptions: NPC replies, the build tablet, the upgrade
  panel, in-world counters and boards.
- Show, don't tell: icons and 1–3 word labels; every action on keyboard, touch and gamepad.
- New things are Lego-style or a refined toy style; existing finished models keep their look.

## Code

The greybox lives in `src/` (Rojo). Module ownership and APIs: [`CONTRACT.md`](CONTRACT.md).

```sh
~/RobloxProjects/tools/check.sh .          # types, lint, format, Lune specs
~/RobloxProjects/tools/build.sh .          # writes build/MaydaySeaRescue.rbxl
python3 tools/studio/smoke.py              # real Studio smoke run
python3 tools/studio/publish_studio.py     # test place from Studio; add --launch for the live game
```

## Toolchain

Pinned in [`rokit.toml`](rokit.toml). Run `rokit install`. Details in
[chapter 06](docs/06-tools-and-pipeline.md).
