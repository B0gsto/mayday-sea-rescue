# 03 · Progression

This file owns every progression number: payouts, rank thresholds, prices in Cash, and the pacing model. Names come from [`01-game-canon.md`](01-game-canon.md) and mechanics from [`02-core-loop-and-mechanics.md`](02-core-loop-and-mechanics.md). Every number marked **(tune)** is a first guess for playtests; nothing here is a Roblox benchmark.

## 1. Principles

1. **Reputation is earned only by playing.** Calls, challenges and big calls give it. Nothing sold for Robux moves it, including Cash packs and 2x Cash.
2. **Rank opens doors, Cash buys the key.** A rank unlocks the right to buy a vehicle or relight a lighthouse. Cash pays for it. So a player who buys Cash still has to earn the rank.
3. **Always one next thing.** At every point the HUD shows the next unlock and how far away it is (in Rep or Cash).
4. **Early unlocks are fast, late ones are slow.** First rank in about 10 minutes, the helicopter in about a week, Admiral in about six weeks at an hour a day.
5. **No streak resets, no losses.** Failing a call never costs Cash or Rep. Missing a day never resets anything.

## 2. Payouts

Base payout per call, before the call's weight ([document 02](02-core-loop-and-mechanics.md), section 3), grade and bonuses.

| Zone | Base Cash (tune) | Base Rep (tune) | Opens at |
|---|---|---|---|
| Calm Bay | 250 | 60 | Recruit |
| Coral Reef | 400 | 90 | Rescue Swimmer (Reef Light) |
| Open Sea | 700 | 130 | Coxswain (Gannet Rock Light) |
| Storm Front | 1,100 | 180 | Captain (Tempest Point Light) |
| Iceberg North [P1] | 1,500 | 230 | Commodore (Northlight) |

**Final payout** = base x call weight x grade (Gold 1.25, Silver 1.0, Bronze 0.75) x storm (1.5 in storms; 2 for Cash in a Great Storm; paid storms boost Cash only, Rep stays at the normal rate) x crew bonus (1.0 to 1.3) x 2x Cash pass (Cash only).

Other payout rules (tune):

- **Tutorial chain.** Call 1 pays 500 Cash and 150 Rep. Calls 2 to 5 pay 300 Cash and 80 Rep each.
- **By the Book** (followed the suggested search pattern): +10% Rep.
- **Medic bonus** (first aid done by a Medic): +15% Cash and Rep.
- **Big calls.** Each victim pays 0.6x the zone base. Every player who rescued at least one victim gets a completion bonus of 5x the zone base in Cash and 3x in Rep.
- **Fail-safe** (timer ran out): 10% Cash, no Rep.

### 2.1 Earning rates

Assumes about 18 calls per hour including travel, an average weight of about 1.1, Silver grades, and two or three storms per hour. Measured in playtests, then tuned.

| Zone | Cash per hour (tune) | Rep per hour (tune) |
|---|---|---|
| Calm Bay | ~5,000 | ~1,200 |
| Coral Reef | ~8,000 | ~1,800 |
| Open Sea | ~14,000 | ~2,600 |
| Storm Front | ~22,000 | ~3,600 |
| Iceberg North [P1] | ~30,000 | ~4,500 |

A player can always take calls in any zone they have opened. Higher zones pay more but need better vehicles to finish on time.

## 3. Ranks

| # | Rank | Total Rep (tune) | Main unlocks | Scope |
|---|---|---|---|---|
| 1 | **Recruit** | 0 | Rescue board, Bosun, Calm Bay calls, radio | [MVP] |
| 2 | **Lifeguard** | 400 | Jet ski (buy), Harbor Light relit, binoculars, crew joining | [MVP] |
| 3 | **Rescue Swimmer** | 1,800 | RIB (buy), Reef Light mission, Coral Reef calls, wildlife calls, gear level 3 | [MVP] |
| 4 | **Coxswain** | 5,500 | Lifeboat and hovercraft (buy), Gannet Rock Light mission, Open Sea, gear level 4 | [L] |
| 5 | **Rescue Pilot** | 14,000 | Rescue helicopter (buy), free helipad on your bay, hoist calls, gear level 5 | [L] |
| 6 | **Captain** | 35,000 | Patrol cutter (buy), Tempest Point Light mission, Storm Front, Captain's cap | [L] |
| 7 | **Commodore** | 80,000 | Commodore liveries (Cash), Northlight mission and Iceberg North [P1], radio title | [L] |
| 8 | **Admiral** | 175,000 | Admiral gold livery for every vehicle, Admiral's coat, name on the station honor board, Bosun's gold medal | [L] |

Crew roles are open to everyone from the start, so a Recruit can ride along as a Medic in a friend's helicopter. Rank only limits which vehicles a player can own and drive.

Each rank-up plays a short ceremony at the station (skippable): Chief Aggie pins the badge, Bosun barks, and the player's nameplate updates for the whole server.

## 4. Vehicle ladder

| Vehicle | Unlock rank | Cash price (tune) | Seats (crew + victims) | Scope |
|---|---|---|---|---|
| Rescue board | Recruit | Free | 1 + 1 | [MVP] |
| Jet ski | Lifeguard | 1,000 | 1 + 1 | [MVP] |
| RIB inflatable | Rescue Swimmer | 6,000 | 3 + 2 | [MVP] |
| Lifeboat | Coxswain | 18,000 | 4 + 8 | [L] |
| Hovercraft | Coxswain | 40,000 | 4 + 6 | [L] |
| Rescue helicopter | Rescue Pilot | 90,000 | 4 + 4 | [L] |
| Patrol cutter | Captain | 200,000 | 4 + 20 (plus up to 4 other players as passengers) | [L] |

The station loaner jet ski (tutorial call 2) is free for one call only.

### 4.1 Vehicle upgrades

Each vehicle has three upgrade levels. Prices are a share of the vehicle's price; the board uses fixed prices.

| Level | Cost (tune) | Effect |
|---|---|---|
| 1. Tuned engine | 25% of price (board: 300) | +8% top speed |
| 2. Storm hull | 50% of price (board: 800) | Better stability in waves; jet ski, RIB and hovercraft capsize less |
| 3. Extra seat | 100% of price (board: 1,500) | +1 victim seat |

**Liveries** are Cash cosmetics (2,000 to 50,000, tune) and a long-term Cash sink. Some liveries are Robux-only cosmetics ([document 04](04-monetization.md)). Paint never changes stats.

## 5. Gear upgrades

Gear is personal and works on every vehicle. Each item has five levels.

| Level | Cash cost (tune) | Rank needed |
|---|---|---|
| 1 | 300 | Recruit |
| 2 | 1,200 | Recruit |
| 3 | 4,000 | Rescue Swimmer |
| 4 | 12,000 | Coxswain |
| 5 | 30,000 | Rescue Pilot |

| Gear | What it improves (per level, tune) | Scope |
|---|---|---|
| **Rescue tube and line** | Throw range 12 to 24 studs, faster reel | [MVP] |
| **Fins** | Swim speed +8% | [MVP] |
| **Binoculars** | Time to mark a victim 1.0 s down to 0.4 s; more zoom | [MVP] |
| **Radio direction finder** | Bearing cone ±30° down to ±8° | [MVP] |
| **Fire pump nozzle** | Spray rate +12%, longer reach | [MVP] |
| **Medic kit** | Comfort refill per step +10%; level 3 adds the stretcher | [MVP] |
| **Hoist winch** | Winch speed +12%, wider clip ring | [L] |
| **Tow rope** | Tension tolerance +10% | [L] |
| **Searchlight** | Range and beam width | [L] |
| **Drysuit** | Needed for Iceberg North; each level lets the player swim longer in cold water | [P1] |

## 6. Station upgrades (your bay)

Every player has their own bay at Port Haven Station: a berth, a locker, a kennel and a trophy wall. Upgrades are personal and show on the bay for others to see.

| Upgrade | Levels and Cash cost (tune) | Effect | Scope |
|---|---|---|---|
| **Radio Room** | 2,000 / 8,000 / 25,000 / 60,000 / 120,000 | Shows 1 to 3 call offers at once, adds the victim count and call type to each offer, shrinks the search circle by up to 40% | [MVP] |
| **Slipway** | 5,000 / 30,000 / 100,000 | Shorter launch cooldown per level, none at level 3. Level 3 also lets you launch from the Coral Key and Gannet Rock outposts | [L] |
| **Kennel** | 3,000 / 15,000 / 50,000 | Bosun's nose range 80 to 140 studs, faster swim, level 3 lets him carry a line to a second swimmer | [MVP] |
| **Med Bay** | 10,000 / 40,000 | Deliver to your own bay instead of the hospital at full pay; level 2 adds +5% Cash on medical calls | [L] |
| **Crew Mess** | 10,000 / 40,000 | Crews that launch from your bay get +5% per level on top of the crew bonus | [L] |
| **Lookout Tower** | 15,000 / 60,000 | Distress flares in your zones show at +25% and +50% range | [L] |
| **Helipad** | Free at Rescue Pilot | Needed to keep the helicopter | [L] |
| **Trophy wall** | Free | Shows badges, ranks and big-call trophies | [MVP] |

## 7. Lighthouses and zone unlocks

Each lighthouse is a short story mission run by Tobias Wick (3 to 6 minutes). The player needs the rank, then starts the mission from the radio. Once relit, the light shines for that player in every server, and its zone opens.

| Lighthouse | Zone | Rank needed | Mission | Scope |
|---|---|---|---|---|
| Harbor Light | Calm Bay (already open) | Lifeguard | Ferry Tobias to the pier light, light the lamp. Doubles as the Lifeguard ceremony. | [MVP] |
| Reef Light | Coral Reef | Rescue Swimmer | Find three lens pieces around Coral Key using the radio bearing. | [MVP] |
| Gannet Rock Light | Open Sea | Coxswain | Run the lamp's spare battery out through a fog bank, then guide the ferry home. | [L] |
| Tempest Point Light | Storm Front | Captain | Relight during a storm. Starts only in the storm phase (or a summoned storm). | [L] |
| Northlight | Iceberg North | Commodore | Break through ice by hovercraft or cutter. | [P1] |

## 8. Badges

Roblox badges, awarded once each. Players see them on their trophy wall.

| Badge | How to get it | Scope |
|---|---|---|
| First Rescue | Finish call 1 | [MVP] |
| Good Boy | Bosun finds a victim first | [MVP] |
| Tow Truck | Finish a tow without snapping the line | [MVP] |
| Fire's Out | Put out a boat fire | [MVP] |
| Storm Chaser | Finish a call during a storm | [MVP] |
| One rank badge each | Reach each rank, Lifeguard to Admiral (7 badges) | [MVP] / [L] |
| One lighthouse badge each | Relight each lighthouse (4, then 5) | [MVP] / [L] |
| Full Crew | Finish a call with four crew | [L] |
| By the Book | Follow a full search pattern | [L] |
| Steady Hands | Hoist without missing the clip | [L] |
| Ferry Hero | Rescue a victim in a Capsized Ferry big call | [L] |
| Cruise Control | Rescue a victim in a Cruise Ship Aground big call | [L] |
| Air Pocket | Reach a trapped passenger as Rescue Swimmer | [L] |
| Gold Standard | 25 Gold grades | [L] |
| Hundred Saves | 100 people rescued | [L] |
| Thousand Saves | 1,000 people rescued | [L] |
| Every Craft | Own all seven vehicles | [L] |
| Just a Little Stuck | Rescue Barnaby 10 times | [L] |
| The Long Storm | Take part in the Season 1 finale | [P1] |

## 9. Daily and weekly challenges

Nell's challenge board at the bait shop. Rewards scale with the player's highest open zone ("zone base" below), so they stay useful at every rank.

**Daily: 3 challenges** from a pool, refreshed at 00:00 UTC. Each pays 4x zone base Cash and 2x zone base Rep (tune). Finishing all three adds a Bosun treat (a short dog emote) and 1,000 Cash. Examples: "Rescue 5 swimmers", "Finish 2 calls in a storm", "Get 3 Gold grades", "Do a call as Medic", "Tow a boat 500 studs".

**Weekly: 5 challenges**, refreshed Monday 00:00 UTC. Each pays 10x zone base Cash and 5x zone base Rep (tune). Finishing all five gives a weekly stamp; four stamps unlock that month's livery. Examples: "Take part in 3 big calls", "Finish 10 calls with a crew", "Relight a lighthouse or reach a new rank", "Rescue 50 people".

Unfinished challenges simply expire. Nothing carries a penalty.

## 10. Pacing model

Rough targets for a player who plays the game's way: takes calls, does dailies, and joins crews sometimes. "Hours" means active playtime. Built from the rates in section 2.1.

| When | Rank and Rep | Owns | World |
|---|---|---|---|
| **10 minutes** | Lifeguard (~470 Rep) | Rescue board, jet ski (1,000 Cash spent), Bosun, gear level 1 in one item | Harbor Light relit, has seen one storm |
| **1 hour** | Rescue Swimmer (~1,800 Rep) | RIB just bought or nearly; 3 to 4 gear items at level 1 or 2; Radio Room 1 | Reef Light mission ready; first daily challenges done |
| **Day 1** (about 3 hours) | Coxswain (~5,500 Rep) | RIB with upgrade 1, Kennel 1, saving for the lifeboat (18,000) | Coral Reef open, Gannet Rock mission ready, a big call or two seen |
| **Week 1** (about 10 hours over 7 days) | Rescue Pilot, close to Captain (~30,000 Rep) | Lifeboat, hovercraft, a new rescue helicopter, most gear at level 3 to 4 | Open Sea is home, Storm Front is the next goal |
| **Month 1** (about 30 hours) | Commodore (~130,000 Rep) | Patrol cutter, all gear at 5, most station upgrades | All four lighthouses lit, collecting liveries |
| **Admiral** | ~175,000 Rep | Everything | At about 40 to 45 hours, roughly six weeks at an hour a day |

### 10.1 How the numbers were built

- First 12 minutes: tutorial chain, ~470 Rep and ~1,700 Cash.
- To 1 hour: Calm Bay at 1,200 Rep/h for 48 minutes plus one day of dailies (~360 Rep) gives ~1,800.
- 1 to 3 hours: Coral Reef at 1,800 Rep/h gives ~5,400 by hour 3.
- 3 to 10 hours: Open Sea at 2,600 Rep/h (~18,000) plus six more days of dailies (~4,700) and one weekly set (~3,250) gives ~31,000.
- Cash over week 1 is about 200,000 against about 200,000 of spending (lifeboat, hovercraft, helicopter, gear, a few station levels), so the helicopter lands at the end of week 1.
- 10 to 30 hours: mostly Storm Front plus dailies and weeklies gives about 130,000.

### 10.2 Watch list for tuning

- **First rank in under 12 minutes** for at least 80% of new players (tune).
- **Helicopter in week 1** is the big retention promise. If it slips past 12 hours of play, cut its price before raising payouts.
- **Late-game Cash** piles up at Storm Front rates. Liveries, vehicle upgrades and [P2] station decoration must soak it up, or Cash loses meaning for Captains and above.
- **2x Cash pass effect.** A 2x Cash owner reaches the helicopter's Cash price in about 5 to 6 hours, but still needs Rescue Pilot rank (about 7 hours). Rank stays the gate, by design.
