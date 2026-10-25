# 03 · Progression and economy

Last rewrite: 2026-10-26 (WP-28: no ranks, the unlock tree). This file owns the numbers: pay, the unlock tree,
prices, quests, streaks, the Album and pacing. How it plays is `docs/02-core-loop-and-mechanics.md`; Robux prices
are `docs/04-monetization.md`; the canonical design is `docs/00-design.md`. Numbers marked **tune** are playtest
targets, not promises. Code: `src/shared/Config/DockConfig.luau` (the tree), `src/shared/UnlockTree.luau` (its
rules), `src/shared/Config/ProgressionConfig.luau` (craft), `tests/Pacing.spec.luau` (the sim).

## 1. Principles

1. **No ranks, no Reputation.** Progress is what stands on your island. Cash is the only currency.
2. **Cash is time.** Cash comes from play; packs and boosts sell time. They never sell a grade or skip the order.
3. **One tree.** Each building says what it needs ("Needs: Crane"); craft unlock through their building. No
   certifications, skill trees, gear scores or branching classes.
4. **Every build changes the game.** A craft, a berth, a faster relaunch, workers, or a visible flex. A building
   that changes nothing is a bug.
5. **Free players reach the whole tree.** Every building, call and free craft is earnable with Cash. The four
   premium boats are Robux alternatives on the RIB's reach.
6. **A session pays.** Twenty minutes should buy something visible. The first session must end with more island
   than it started with.
7. **No punishment.** No Cash is taken away on failure, no decay, no energy, no lives.
8. **The sea is the content.** The economy exists to send the player out again, not to keep them in a menu.

## 2. Call pay

```
Cash = 250 × kind weight × grade × crew × distance
```

- **Base:** 250 Cash at your cove, Silver, solo.
- **Kind weight:** how hard or dramatic the call is.
- **Grade:** Gold 1.25 (under 60% of the timer), Silver 1.0 (under 85%), Bronze 0.75.
- **Crew:** +10% per extra member, capped at +30% for four.
- **Distance:** from the player's berth; ×1 inside 1,500 studs, then +1 per 1,500, capped at ×4. Delivery at the
  hub or another island pays the round trip sailed, never more.
- **Tutorial:** call 1 pays 500; calls 2–5 pay 300 each, flat, regardless of grade.
- **Fail-safe:** timer run out (or a crew member with no role action) pays 10% of the Cash.
- **Big call:** each survivor delivered pays 60% of the zone base (150 at the base rate); every helper gets a
  completion bonus of 5× base Cash, scaled by the share of survivors they saved.

| Kind | Weight | Why |
|---|---:|---|
| Wildlife rescue | 0.8 | Short, gentle, close. |
| Rip current | 0.9 | One person, but a long timer and a swim. |
| Swimmer | 1.0 | The baseline call. |
| Drifting craft | 1.1 | Two people, a bigger pick-up. |
| Sinking vessel | 1.2 | Three people, far out, a sinking clock. |
| Diver at a wreck | 1.4 | Submarine only; a deep, technical pick-up. |
| Vessel fire | 1.5 | Two people, smoke, the most dramatic. |
| Capsized ferry | share | Big call; pays by survivor and completion, not weight. |

A typical far call at Silver, solo, distance ×4 is about **1,100 Cash** in 4–5 minutes.

## 3. The unlock tree

```
Jetty (start)
├─ Pontoon (2nd berth) ── Lookout tower ── Helipad ── Hangar → Helicopter
│                              └─ Rescue boathouse
├─ Workshop ─┬─ Boathouse → RIB, boat board, paint booth, Robux boats
│            │     ├─ Lifeboat slip → Lifeboat
│            │     └─ Crane (no relaunch wait) ── Sub pen → Submarine
│            └─ Boat yard
├─ Fish shed
└─ Station (Boathouse + Lookout tower) ── Clinic, Trophy hall
Decor: the jetty only.
```

| Build | Cash | Needs | Adds / unlocks |
|---|---:|---|---|
| Workshop | 1,000 | — | Builders (WP-26). Opens the boathouse. |
| Pontoon | 2,500 | — | Second berth, lamps, flag, rescue board. |
| Fish shed | 3,000 | — | Gatherers (WP-26). |
| Boathouse | 2,500 | Workshop | Boat board, paint booth; the RIB and Robux boats. |
| Lookout tower | 8,000 | Pontoon | Opens the helipad, rescue boathouse, station. |
| Boat yard | 8,000 | Workshop | Mechanics (WP-26). |
| Lifeboat slip | 10,000 | Boathouse | The lifeboat. |
| Helipad | 10,000 | Lookout tower | Opens the hangar. |
| Rescue boathouse | 12,000 | Lookout tower | Rescuers (WP-26). |
| Crane | 15,000 | Boathouse | No relaunch cooldown; opens the sub pen. |
| Hangar | 20,000 | Helipad | The helicopter, at its own board. |
| Sub pen | 20,000 | Crane | The submarine, at its own board. |
| Station | 40,000 | Boathouse, Lookout tower | Lit station + beacon; crew hire; Harbour Master. |
| Trophy hall | 20,000 | Station | Milestone cups and island-stamp plaques. |
| Clinic | 30,000 | Station | Medics (WP-26). |
| Lighthouse | 0 | — | Keeper Ives' lamp chain; quest reward, never sold. |

- All prices **tune**. Worker buildings are plain Lego placeholders until WP-26 adds the workers.
- Old saves: dock Lv2 → Pontoon; Lv3 → + Workshop, Boathouse; Lv4 → + Lookout tower, Crane; Lv5 → + Station,
  Trophy hall; an old hangar also owns its helipad. Saved `rep` and `dockLevel` stay, unread.
- Badges and leaderboards count **people rescued** (`totalRescues`): the old rank badges became 10 / 50 / 200 /
  500 / 2,000 rescued; the monthly liveries unlock at 500 rescued.

## 4. Reach

Reach = the best craft you can launch. Calls 1–2 spawn in the player's cove; from call 3 they use the distance
tiers 500–2,000, 2,000–3,500 and 3,500–5,500 studs from the berth.

| Craft | Call reach |
|---|---:|
| Jet ski | 2,000 studs |
| RIB, Robux boats | 3,500 studs |
| Lifeboat, submarine, helicopter | 5,500 studs |

The Robux boats need the boathouse and sit on the RIB's tier, so Robux never skips the tree. The outer islands sit
inside the top band; the map edge beyond 5,500 is for free exploration, not paid calls.

## 5. Craft prices

| Craft | Cash | Needs |
|---|---:|---|
| Jet ski | 0 | — |
| RIB | 2,500 | Boathouse |
| Lifeboat | 12,000 | Lifeboat slip |
| Submarine | 40,000 | Sub pen |
| Rescue helicopter | 55,000 | Hangar |

The Robux paths are in `docs/04-monetization.md`. A paid craft handles like its free counterpart. A craft owned
before WP-28 (or a pass bought on the website) always launches; the building gate is on the buy.

## 6. Quests, streaks and the Album

### 6.1 Quests

Thirteen quests, six givers, one a day per giver. Pay is flat; distance does not multiply it.

| Quest kind | Cash | Notes |
|---|---:|---|
| Find | 1,500 | Pick it up on an outer island and bring it back. |
| Deliver | 1,500 | Carry it from the camp to a drop spot. |
| Salvage | 2,500 | Submarine; a wreck on the seabed. |
| Rescue | 1,000 | Plus the call's own pay. |
| Lamp chain finale | 2,000 | Unlocks the lighthouse blueprint. |

- A quest is roughly 1.5 calls of travel; a rescue quest also pays the call.
- No quest gates a building, craft or call. The lighthouse is the only mechanical reward, and it is cosmetic.
- The chain is three days because it is one quest per giver per day, not because it is a wall.

### 6.2 Streak

| Day | Cash |
|---:|---:|
| 1 | 100 |
| 2 | 150 |
| 3 | 225 |
| 4 | 325 |
| 5 | 450 |
| 6 | 600 |
| 7 | 900 + a cosmetic |

- One missed day is free (a calm day). A longer break drops the streak back three days, never to zero.
- Away more than three days: the next crate is a welcome-back crate, +500 Cash, once.
- The crate is once per UTC day. No purchase extends it, protects it or sells a second claim.
- The day-7 cosmetic is the only random item in the streak; it is cosmetic and duplicate-protected.

### 6.3 Album

| Find | Cash |
|---|---:|
| Island stamp | 150 |
| Message in a bottle | 75 |
| Viewpoint | 75 |
| Critter | 75 |
| Wreck | 150 |
| Page completion | 300 |

- One hub page and seven outer-island pages.
- Fog lifts as the player walks the hub. Album finds are in the world, not in a paid chest.
- The Album is the exploration record. It pays Cash once per find; it is not a repeatable grind.

### 6.4 Friends and crew

- **Player crew:** +10% Cash per extra crew member, capped at +30% for four. The bonus appears on the payout card.
- **Friends:** +10% Cash per friend on the server, capped at +30%.
- **Big call:** the completion bonus is shared by every helper; the survivor share goes to the deliverer.
- Crew and friend bonuses stack with distance and grade; each is capped separately.

## 7. Earning rates and pacing

At steady far-call play, a solo player earns about **15,000–17,000 Cash per hour**. Short phone sessions,
exploration and quests earn less; a good group earns a little more. The sim (`tests/Pacing.spec.luau`, 2 × 25 min
a day, Cash only, the plan Workshop → Boathouse → RIB → Pontoon → Lifeboat → Lookout → Helipad → Hangar →
Helicopter → the rest) watches these:

| Target | Time (sim, solo) | Why |
|---|---:|---|
| Workshop | 0:07 | The first building inside the first session (NewPlayerPace: ~8 min). |
| Boathouse | 0:24 | The boat board and paint booth. |
| RIB | 0:33 | The first bought boat. |
| Pontoon | 0:46 | The second berth. |
| Lifeboat | 2:07 | Top reach. |
| Helicopter | 7:38 | Week 1 (helipad + hangar + 55,000). |
| Submarine | 12:37 | Crane and sub pen first. |
| Station | 15:25 | The beacon and the Harbour Master race. |
| Clinic (the whole tree) | 17:52 | Everything a free player can build. |

- **First session:** the workshop and the boathouse, one quest, the first Album stamp. End with more island.
- **First week:** the RIB, the lifeboat, the helicopter, most of the lamp chain.
- **Long tail:** the sub, the station, the trophy hall, worker buildings, decor, the gold beacon.
- No energy, lives or daily caps on calls. A player can rescue all evening if they want to.
- A 6-player server does not split pay. Bonuses are added, not carved out of someone else's reward.

## 8. Where Cash goes

| Sink | When | Why |
|---|---|---|
| RIB, lifeboat, submarine, helicopter | Early to late | The main mobility ladder. |
| The unlock tree | Early to late | The main visible growth and flex. |
| Decor | Any time | Cash-only Lego set pieces. |
| Crew wages (in progress) | Late | A small recurring sink for a living station. |

Cash is never traded or gifted. There is no player market, no auction and no Cash drop.

## 9. Guardrails

- Every payout is server-authoritative. The client shows a preview; the server pays.
- A call pays once. A delivered survivor cannot be paid again; a failed call cannot be re-completed.
- Robux buys a building only once its prerequisites stand (checked on the server grant too).
- Cash packs, boosts and day passes are capped by their own rules in `docs/04-monetization.md`.
- The pacing sim in `tests/` is the alarm for a broken economy; when a number here changes, the sim changes with
  it.
