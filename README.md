# Mayday: Sea Rescue

**Answer the call. Brave the storm. Bring them home.**

A Roblox coast guard and sea rescue game. You join the reopened rescue station in Port Haven, answer Mayday calls over the radio, and race out by jet ski, lifeboat or helicopter to pull people out of the sea. Every few minutes a storm rolls over the whole server and the big calls come in.

The one-line pitch: *Firefighting Sim, but on the ocean, with storms.*

This repository holds the design bible for now. Code and art come next.

## Why this game

- **The demand is proven.** *Firefighting Sim* (Blackbox Express) came out on Sept 22, 2026 (unverified) and reached a peak of 34.8K concurrent players in about three weeks, with 92% likes (unverified). Rescue on land is working.
- **The water is empty.** The sea rescue niche on Roblox is 8 to 10 small games, none we found above a few thousand concurrent players. Nobody has made a polished one.
- **The fantasy is big and has room to grow.** Boats, jet skis, helicopters, storms, sharks, icebergs and cruise ships all fit, solo or as a crew.

Full evidence: [`docs/research/reference-games.md`](docs/research/reference-games.md).

## The design bible

| # | Chapter | What it answers |
|---|---|---|
| 01 | [Game canon](docs/01-game-canon.md) | Fantasy, pillars, story, setting, characters, tone, scope |
| 02 | [Core loop and mechanics](docs/02-core-loop-and-mechanics.md) | The call loop, first two minutes, call types, vehicles, rescues, co-op, storms |
| 03 | [Progression](docs/03-progression.md) | Ranks, vehicle ladder, upgrades, zones, challenges, pacing |
| 04 | [Monetization](docs/04-monetization.md) | Game passes, developer products, prices, what we never sell, policy |
| 05 | [Art direction](docs/05-art-direction.md) | Visual style, palette, lighting, VFX, how we avoid slop, asset sources |
| 06 | [Tools and pipeline](docs/06-tools-and-pipeline.md) | Toolchain, Blender to Studio, ocean/boat/helicopter tech, repo layout |
| 07 | [Store page, thumbnails and trailer](docs/07-store-page-thumbnails-and-trailer.md) | Icon, thumbnails, gameplay video shot list, description |
| 08 | [References](docs/08-references.md) | Games, real-world references, tutorials, links |

Raw research notes: [`docs/research/`](docs/research/).

## Conventions

- Scope tags: `[MVP]` first playable, `[L]` public launch, `[P1]` first update window, `[P2]` later.
- `(tune)` marks a starting number we expect to change after playtests.
- `(unverified)` marks a fact we could not confirm from a primary source.
- Prices live in [chapter 04](docs/04-monetization.md) only. Other chapters link to it.

## Toolchain

Pinned in [`rokit.toml`](rokit.toml). Run `rokit install`. Details in [chapter 06](docs/06-tools-and-pipeline.md).
