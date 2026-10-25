# Mayday: Sea Rescue

**Answer the call. Bring them home. Build your island.**

A Roblox coastguard rescue game for kids 8–15, many on phones. You start on a wild forest hub, take a call,
sail out to a survivor, bring them home, and build up your own Lego island. Six players per server; friends
can ride along, crew up and visit each other's islands.

The loop: **your island → a call → sail out → pick up → bring them home → build your island → farther calls,
bigger craft.**

## The design

[`docs/00-design.md`](docs/00-design.md) is the source of truth. [`docs/23-dock-and-core-loop.md`](docs/23-dock-and-core-loop.md)
is the change log that got here (a)–(n). Old designs live in git tag `pre-hub-cut` and [`docs/archive/`](docs/archive/).

| # | Chapter | What it answers |
|---|---|---|
| 00 | [The design](docs/00-design.md) | Canonical world, loop, island, craft, economy, UI, build rules |
| 23 | [Dock and core loop](docs/23-dock-and-core-loop.md) | Why the loop changed, work packages, quests, UI, Lego style |
| 05 | [Art direction](docs/05-art-direction.md) | Two lanes: existing art kept, new art Lego-style |
| 06 | [Tools and pipeline](docs/06-tools-and-pipeline.md) | Code toolchain, publish, art pipeline, repo layout |
| 08 | [References](docs/08-references.md) | Games, look/UI references, real rescue, tech docs |
| 10 | [World and map](docs/10-world-and-map.md) | Hub, six islands, bridges, outer ring, seabed, streaming |
| 12 | [Asset list](docs/12-asset-list.md) | What exists, what is new, what is cut |
| 13 | [Release plan](docs/13-release-plan.md) | What landed, what is left, launch checklist |
| 18 | [UI art requests](docs/18-ui-art-requests.md) | Simulator-style icons and kit art |
| 19 | [World sign art](docs/19-world-sign-art.md) | Hub, island, bridge and hazard signs |

Older chapters, kept for history and superseded by 00: [01](docs/01-game-canon.md), [02](docs/02-core-loop-and-mechanics.md),
[03](docs/03-progression.md), [04](docs/04-monetization.md), [07](docs/07-store-page-thumbnails-and-trailer.md),
[15](docs/15-retention-and-new-players.md). Do not use them as the current design.

## Why this game

- **The rescue loop is proven.** *Firefighting Sim* shows players want answer-call → drive → rescue → rank.
- **The water is still open.** The sea-rescue niche on Roblox is small; nobody has made a polished one.
- **The tycoon is personal.** Your island grows in the world and everyone can see it.
- **It is readable on a phone.** Flat Lego islands, chunky UI, one clear call at a time.

## Conventions

- `(tune)` marks a starting number that playtests may move.
- `(verify)` marks an engine fact to check in Studio or the official docs.
- No choice UI in gameplay: actions are in the world. Exceptions: NPC talk, the build tablet, in-world
  counters and boards.
- Show, don't tell: icons and 1–3 word labels; every action on keyboard, touch and gamepad.
- New things are Lego-style; existing finished models keep their look.

## Code

The greybox lives in `src/` (Rojo). Module ownership and APIs: [`CONTRACT.md`](CONTRACT.md).

```sh
~/RobloxProjects/tools/check.sh .          # types, lint, format, Lune specs
~/RobloxProjects/tools/build.sh .          # writes build/MaydaySeaRescue.rbxl
python3 tools/studio/smoke.py              # real Studio smoke run
python3 tools/publish.py                   # private test place, ~2 min
```

## Toolchain

Pinned in [`rokit.toml`](rokit.toml). Run `rokit install`. Details in
[chapter 06](docs/06-tools-and-pipeline.md).
