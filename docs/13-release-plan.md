# 13 · Release plan

Status for the hub + Lego islands game. The design is [`00-design.md`](00-design.md); the change log and work
packages are [`23-dock-and-core-loop.md`](23-dock-and-core-loop.md). This file is the launch view: what has
landed, what is left, and what only the owner can do.

Snapshot: 2026-10-25. The private test place was published at v42 with the forest hub, six islands and the cuts.
Older audits in [`archive/`](archive/) describe Port Haven and are not current.

## 1. Scope

**Launch game:** hub forest, six flat Lego player islands, six suspension bridges, seven outer islands, calls,
quests, dock/island building, boat board, helicopter, submarine, album, crew (late), simulator UI, no phone.

**Cut:** Port Haven town, roads, cars and land vehicles, car garage, seaplane, land/cliff calls, NPC racer,
first-person camera/viewmodel, photo mode, rare rescue variants, dispatch radio.

## 2. What has landed

| Area | State |
|---|---|
| Cars and town cut | WP-17 done; restorable from tag `pre-hub-cut` |
| Hub map, six islands, bridges, outer ring | WP-18 done |
| Plots → islands, server size 6 | WP-19 done |
| Forest hub, outposts, fog | WP-21a done |
| Quest givers and 13 quests | WP-21b done |
| Radio cut; NPC voices only | WP-22 done |
| Flat Lego baseplate islands | WP-24 done |
| Own dock/berth, pick-up ring, dock levels 2–5 | WP-1, WP-2, WP-4 done |
| Publish speed: retry only failed texture packs | Done; about 2 min, 429-aware, ≤1% failures |
| Hub forest fog and discovery | Done |
| Build tablet design | In progress (WP-14d) |
| UI kit / no phone | In progress (WP-23) |
| Crew | In progress (WP-15) |

## 3. What is left

Order matters. Publish speed and the asset diet come before more content.

| Order | Work | Why |
|---|---|---|
| 1 | **WP-16 asset diet** | Drop unused ids, merge near-duplicate PBR surfaces, measure phone memory/load. The hub is dense; this protects phones and publish time. |
| 2 | **WP-14c blueprint table + builder beat** | The in-world upgrade flow; the tablet builds on it. |
| 3 | **WP-15 crew** | Late-game Cash sink and plot life. |
| 4 | **WP-23 UI kit, then delete the phone** | WP-23a icons, WP-23b kit + style screen, WP-23c phone deletion, WP-23d restyle every screen. |
| 5 | **WP-14d build tablet** | After WP-14c and the UI kit: top-down build mode, flat lot outline, Lego build. |
| 6 | **Launch polish** | Store art, badges, analytics, real-phone check, final smoke/soak. |

WP-16 is next because it was queued after WP-21a. Do not start a new content package while it is open.

## 4. Launch checklist

### Gameplay

- [ ] New player spawns on the hub, sees the call board and gets calls 1–3 without reading a paragraph.
- [ ] Pick-up ring works at full throttle; survivor climbs aboard; full craft shows pips.
- [ ] Calls 3+ spawn among the outer islands; drop-off is the nearer of island berth and hub.
- [ ] Six quest givers offer one quest a day; chains unlock the lighthouse blueprint.
- [ ] Boat board chooses/paints owned craft; "Boat to me" works.
- [ ] Dock levels 2–5 build visibly; Cash + rank and Robux paths both work.
- [ ] Helicopter winch and submarine diver pick-up work on all inputs.
- [ ] Rejoin restores island, dock level, craft, quests and album.

### World

- [ ] Hub forest, six baseplates, six bridges and seven outer islands are all reachable.
- [ ] Bridges clear every boat and the helicopter.
- [ ] Ocean covers the horizon from a player camera; no square edge.
- [ ] Hub fog clears as walked; hidden ruin and wreck give stickers.
- [ ] No town, roads, cars or street furniture in the live map.

### UI

- [ ] No phone frame, phone home grid or iOS tiles remain.
- [ ] Left button bar opens Shop, Quests, Album, Companion, Crew, Settings, Boat to me; map on M.
- [ ] Every panel uses the kit; red X closes; price buttons are green; gamepad selection ring works.
- [ ] Icons read at 64 px on a phone; labels are 1–3 words.
- [ ] Build tablet top-down mode and flat lot outline work.

### Tech and release

- [ ] `~/RobloxProjects/tools/check.sh .` passes.
- [ ] `tools/studio/smoke.py` and `soak.py` pass.
- [ ] Phone memory/load measured after WP-16; no regression from the old town baseline.
- [ ] Publish is about 2 minutes and has no texture-pack failures.
- [ ] Store icon, thumbnails and trailer match the current game (no town/cars/phone).
- [ ] Badges, analytics and monetization ids are live.
- [ ] Real phone test: touch targets, safe area, text size, frame rate.

## 5. Owner-only steps

These cannot be finished by an agent:

1. Approve the store icon, thumbnails and trailer.
2. Test on a real phone and sign off touch/readability.
3. Create/confirm the Roblox group and put its id in `SocialConfig`.
4. Create/confirm developer products and passes; fill the live ids.
5. Record or approve NPC voice lines.
6. Publish the final place and set the public experience.

## 6. Definition of launch-ready

A new player can join, see the forest hub, take a call, pick up a survivor, bring them home, earn Cash, build
their island, meet a quest giver, and come back the next day. No phone, no town, no cars, no radio. The game
runs on a phone, the store art matches the game, and the checks pass.

## 7. Risks

| Risk | Mitigation |
|---|---|
| Hub density hurts phones | WP-16 first; measure, do not guess |
| UI kit leaves old screens behind | WP-23d checklist; delete phone code, not just hide it |
| Build tablet depends on kit | Do WP-14c and WP-23 before WP-14d |
| Asset/publish time | Retry only failed packs; keep texture packs shared |
| Stale old chapters | `00` wins; archive old designs; do not link them as current |
| Quest/crew scope | Ship one good quest chain and a small crew, not a second game |
