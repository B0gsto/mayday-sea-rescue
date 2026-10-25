# 03 · Progression and economy

Last rewrite: 2026-10-25. This file owns the numbers: pay, ranks, prices, quests, streaks, the Album and pacing.
How it plays is `docs/02-core-loop-and-mechanics.md`; Robux prices are `docs/04-monetization.md`; the canonical
design is `docs/00-design.md`. Numbers marked **tune** are playtest targets, not promises.

## 1. Principles

1. **Rep is earned, never sold.** Calls and quests are the only Rep sources. No boost, pass or pack grants Rep.
2. **Cash is time.** Cash comes from play; packs and boosts sell time. They never sell a grade or a rank.
3. **One ladder.** Eight ranks, one dock ladder, five craft, one island. No certifications, skill trees, gear
   scores or branching classes.
4. **Every rank changes the game.** A new craft, a dock level, a building or a reach step. A rank that changes
   nothing is a bug.
5. **Free players reach the whole ladder.** Every rank, island, building, call and free craft is earnable. The
   four premium boats are Robux alternatives; they do not add reach, grade or a new call.
6. **A session pays.** Twenty minutes should buy something visible: a rank, a RIB, a dock level or a quest chain
   step. The first session must end with more island than it started with.
7. **No punishment.** No Cash is taken away on failure, no dropped rank, no decay, no energy, no lives.
8. **The sea is the content.** The economy exists to send the player out again, not to keep them in a menu.

## 2. Call pay

A call pays Cash and Rep through one formula:

```
Cash = 250 × kind weight × grade × crew × distance
Rep  =  60 × kind weight × grade × crew × distance
```

- **Base:** 250 Cash / 60 Rep at your cove, Silver, solo.
- **Kind weight:** how hard or dramatic the call is.
- **Grade:** Gold 1.25 (under 60% of the timer), Silver 1.0 (under 85%), Bronze 0.75.
- **Crew:** +10% per extra member, capped at +30% for four.
- **Distance:** from the player's berth; ×1 inside 1,500 studs, then +1 per 1,500, capped at ×4. The multiplier
  applies to Cash **and** Rep. Delivery at the hub or another island pays the round trip sailed, never more.
- **Tutorial:** call 1 pays 500/150; calls 2–5 pay 300/80 each, flat, regardless of grade.
- **Fail-safe:** timer run out (or a crew member with no role action) pays 10% of the Cash, no Rep.
- **Big call:** each survivor delivered pays 60% of the zone base (150/36 at the base rate); every helper gets a
  completion bonus of 5× base Cash and 3× base Rep, scaled by the share of survivors they saved.

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

A typical far call at Silver, solo, distance ×4 is about **1,100 Cash / 250 Rep** in 4–5 minutes. That is the
number the pacing targets below assume.

## 3. Ranks

Rep only. No rank is bought, boosted or granted by a pass; a Robux craft or dock level can be used without the
rank, but the rank itself still comes from rescues.

| Rank | Total Rep | Main unlocks |
|---|---:|---|
| **Recruit** | 0 | Jet ski, Bosun, calls in your cove. |
| **Lifeguard** | 400 | RIB, player crew joining, dock Lv2. |
| **Rescue Swimmer** | 900 | Dock Lv3 (boathouse, boat board, paint booth). |
| **Coxswain** | 3,000 | Lifeboat, submarine, sub pen, dock Lv4, top call reach. |
| **Rescue Pilot** | 9,000 | Rescue helicopter, hangar, dock Lv5, beacon, harbourmaster. |
| **Captain** | 22,000 | The captain's title; no new craft. The long climb. |
| **Commodore** | 55,000 | Commodore livery for the fleet. |
| **Admiral** | 150,000 | Gold livery, Admiral's coat, place on the honour board. |

- **Captain is the quiet rank.** Its old zone and storm unlocks are retired; its value is the title and the
  distance to Commodore. If a future build gives Captain a cosmetic, it must not be a stat.
- **Admiral is the end of the ladder,** not the end of the game. Service Stars continue the count.
- **Service Stars:** one per 30,000 Rep past Admiral, endless. A star is a title and a small profile badge; no
  stat, no craft, no island piece.

## 4. Reach

The rank caps how far a call can be offered. This is the main pacing brake: a fast boat does not skip the ladder.

| Rank | Free craft available | Call reach |
|---|---|---:|
| Recruit | Jet ski | 2,000 studs |
| Lifeguard | RIB | 3,500 studs |
| Rescue Swimmer | RIB | 3,500 studs |
| Coxswain | Lifeboat, submarine | 5,500 studs |
| Rescue Pilot | Helicopter | 5,500 studs |
| Captain–Admiral | All | 5,500 studs |

- Calls 1–2 spawn in the player's cove. From call 3 they use the distance tiers: 500–2,000, 2,000–3,500 and
  3,500–5,500 studs from the berth.
- A Robux craft does not raise reach. It inherits the reach of the best free craft the rank has unlocked.
- The outer islands sit inside the top band; the map edge beyond 5,500 is for free exploration, not paid calls.

## 5. Craft and island prices

### 5.1 Craft

| Craft | Cash | Rank | Also needs |
|---|---:|---|---|
| Jet ski | 0 | Recruit | — |
| RIB | 2,500 | Lifeguard | — |
| Lifeboat | 12,000 | Coxswain | — |
| Submarine | 40,000 | Coxswain | Sub pen (20,000) |
| Rescue helicopter | 75,000 | Rescue Pilot | Hangar (25,000) |

The Robux paths are in `docs/04-monetization.md`. A paid craft handles like its free counterpart and does not
raise reach.

### 5.2 Dock levels and buildings

| Build | Cash | Rank | Adds / unlocks |
|---|---:|---|---|
| Dock Lv2 | 2,500 | Lifeguard | Pontoon, lamps, flag, rescue board; second berth. |
| Dock Lv3 | 10,000 | Rescue Swimmer | Boathouse, boat board, paint booth; choose craft at dock. |
| Dock Lv4 | 30,000 | Coxswain | Lookout tower, slipway crane; no relaunch cooldown, lifeboat berth. |
| Dock Lv5 | 100,000 | Rescue Pilot | Station front, beacon, trophy hall; harbourmaster. |
| Sub pen | 20,000 | Coxswain | Sub pen, sub board; submarine at dock. Needs dock Lv1. |
| Hangar | 25,000 | Rescue Pilot | Helipad, hangar, hangar board; helicopter at dock. Needs dock Lv3. |
| Lighthouse | 0 | — | Keeper Ives' three-day lamp chain; a spare-lot building. Never sold. |

- Lv2 and the RIB both arrive at Lifeguard. That is deliberate: the player chooses whether the first 2,500 Cash
  goes to the island or the boat.
- The dock is the biggest Cash sink and the clearest flex. Every level is visible from the water.
- The lighthouse is the only quest-chain building at launch. Blueprints are never sold.
- **Crew wages** (in progress, WP-15) are a late-game daily Cash sink, small enough that they never block a call.

## 6. Quests, streaks and the Album

### 6.1 Quests

Thirteen quests, six givers, one a day per giver. Pay is flat; distance does not multiply it.

| Quest kind | Cash | Rep | Notes |
|---|---:|---:|---|
| Find | 1,500 | 250 | Pick it up on an outer island and bring it back. |
| Deliver | 1,500 | 250 | Carry it from the camp to a drop spot. |
| Salvage | 2,500 | 400 | Submarine; a wreck on the seabed. |
| Rescue | 1,000 | 200 | Plus the call's own pay. |
| Lamp chain finale | 2,000 | 400 | Unlocks the lighthouse blueprint. |

- A quest is roughly 1.5 calls of travel; a rescue quest also pays the call.
- No quest gates a rank, craft or call. The lighthouse is the only mechanical reward, and it is cosmetic.
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
- **Friends:** +10% Cash per friend on the server, capped at +30%. No Rep bonus.
- **Big call:** the completion bonus is shared by every helper; the survivor share goes to the deliverer.
- Crew and friend bonuses stack with distance and grade; each is capped separately.

## 7. Earning rates and pacing

At steady far-call play, a solo player earns about **15,000–17,000 Cash and 3,500 Rep per hour**. Short phone
sessions, exploration and quests earn less; a good group earns a little more. These are the targets the pacing
sim watches.

| Target | Time | Why |
|---|---:|---|
| Lifeguard (400 Rep) | 0:13 | First rank inside the first session. |
| RIB (2,500 Cash) | 0:18 | The first bought boat; a visible upgrade. |
| Dock Lv2 (2,500 Cash) | 0:20 | The first island change, competing with the RIB. |
| Rescue Swimmer (900 Rep) | 0:30 | The paint booth and dock Lv3 come into view. |
| Coxswain (3,000 Rep) | 0:55 | Lifeboat, submarine and top reach. |
| Rescue Pilot (9,000 Rep) | 2:22 | Helicopter and the Lv5 island. |
| Commodore (55,000 Rep) | about 13.6 hours (day 16) | The long-term goal. |
| Admiral (150,000 Rep) | about 36 hours (about six weeks) | The end of the ladder. |

- **First session:** Lifeguard, the RIB or dock Lv2, one quest, the first Album stamp. End with more island.
- **First week:** Coxswain, the submarine, dock Lv3–4, most of the lamp chain.
- **Long tail:** Commodore, Admiral, Service Stars, the trophy hall, the gold beacon.
- No energy, lives, daily caps on calls or paid Rep. A player can rescue all evening if they want to.
- A 6-player server does not split pay. Bonuses are added, not carved out of someone else's reward.

## 8. Where Cash goes

| Sink | When | Why |
|---|---|---|
| RIB, lifeboat, submarine, helicopter | Early to late | The main mobility ladder. |
| Dock Lv2–5 | Early to late | The main visible growth and flex. |
| Sub pen, hangar | Mid to late | Unlocks the two specialist craft. |
| Crew wages (in progress) | Late | A small recurring sink for a living station. |
| Cosmetics (Cash liveries) | Late | Commodore and Admiral rewards. |

Cash is never traded, gifted or converted to Rep. There is no player market, no auction and no Cash drop.

## 9. Guardrails

- Every payout is server-authoritative. The client shows a preview; the server pays.
- A call pays once. A delivered survivor cannot be paid again; a failed call cannot be re-completed.
- Rep has no multiplier from Robux, events or passes.
- Cash packs, boosts and day passes are capped by their own rules in `docs/04-monetization.md`.
- The pacing sim in `tests/` is the alarm for a broken economy; when a number here changes, the sim changes with
  it.
- The old item table in `docs/23-dock-and-core-loop.md §i` still lists the car garage, seaplane and Port Haven
  drop-off; those are history, not current numbers.
