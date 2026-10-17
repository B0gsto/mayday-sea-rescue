# 03 · Progression

This file owns every progression number: payouts, rank thresholds, prices in Cash, and the pacing model. Names come from [`01-game-canon.md`](01-game-canon.md) and mechanics from [`02-core-loop-and-mechanics.md`](02-core-loop-and-mechanics.md). Every number marked **(tune)** is a first guess for playtests; nothing here is a Roblox benchmark.

## 1. Principles

1. **Reputation is earned only by playing.** Calls, challenges and big calls give it. Nothing sold for Robux adds it, including Cash packs and 2x Cash.
2. **Rank opens doors, Cash buys the key.** A rank unlocks the right to buy a vehicle or relight a lighthouse. Cash pays for it. So a player who buys Cash still has to earn the rank.
3. **Always one next thing.** At every point the HUD shows the next unlock and how far away it is (in Rep or Cash).
4. **Early unlocks are fast, late ones are slow.** First rank in about 10 minutes, an unlock every 10 to 15 minutes for the first 2 hours, the helicopter in week 1, Admiral in about six weeks, then endless Service Stars. The model assumes 25-minute sessions, two a day (section 10).
5. **No streak resets, no losses.** Failing a call never costs Cash or Rep. Missing a day never resets anything.

## 2. Payouts

Base payout per call, before the call's weight ([document 02](02-core-loop-and-mechanics.md), section 3), grade and bonuses.

| Zone | Base Cash (tune) | Base Rep (tune) | Opens at |
|---|---|---|---|
| Calm Bay (and harbor mouth storm calls) | 250 | 60 | Recruit |
| Coral Reef [L] | 400 | 90 | Lifeguard (Harbor Light) |
| Open Sea [L] | 700 | 130 | Coxswain (Gannet Rock Light) |
| Storm Front [L] | 1,100 | 180 | Captain (Tempest Point Light) |
| Iceberg North [P1] | 1,500 | 230 | Commodore (Northlight) |

**Final payout** = base x call weight x grade (Gold 1.25, Silver 1.0, Bronze 0.75) x storm (1.5 in storms; 2 for Cash in a Great Storm; paid storms boost Cash only, Rep stays at the normal rate) x crew bonus (1.0 to 1.3) x 2x Cash pass (Cash only).

Other payout rules (tune):

- **Tutorial chain.** Call 1 pays 500 Cash and 150 Rep. Calls 2 to 5 pay 300 Cash and 80 Rep each.
- **Crew members** are paid only with a role action on the call ([document 02](02-core-loop-and-mechanics.md), section 7); otherwise they get the 10% fail-safe share.
- **By the Book** [L] (followed the suggested search pattern): +10% Rep.
- **Medic bonus** [L] (first aid done by a Medic): +15% Cash and Rep.
- **Big calls** [L]. Each victim pays 0.6x the big call's zone base to the player who delivers it. Every player who did a role action on the big call, including ride-along seats in the station helicopter, gets a completion bonus of 5x the zone base in Cash and 3x in Rep, scaled by the share of victims saved before the big call's own timer ran out ([document 02](02-core-loop-and-mechanics.md), section 3.1).
- **Fail-safe** (timer ran out): 10% Cash, no Rep.

### 2.1 Earning rates

A call cycle is about 3 minutes: about 45 s out and 45 s back ([document 02](02-core-loop-and-mechanics.md), section 4.1), 20 to 60 s on scene, and about 20 s to launch and collect the payout. Further zones have longer scenes. Rates assume an average weight of about 1.1, Silver grades, and storms for about a fifth of play time (x1.5 pay then, so about x1.1 overall). Measured in playtests, then tuned.

| Zone | Calls per hour (tune) | Cash per hour (tune) | Rep per hour (tune) | Per 25-min session (Cash / Rep) |
|---|---|---|---|---|
| Calm Bay | 20 | ~6,000 | ~1,450 | ~2,500 / ~600 |
| Coral Reef [L] | 18 | ~8,700 | ~1,950 | ~3,600 / ~810 |
| Open Sea [L] | 15 | ~12,700 | ~2,350 | ~5,300 / ~980 |
| Storm Front [L] | 13 | ~17,300 | ~2,850 | ~7,200 / ~1,190 |
| Iceberg North [P1] | 12 | ~21,800 | ~3,350 | ~9,100 / ~1,400 |

A player can always take calls in any zone they have opened. Higher zones pay more but need better vehicles to finish on time.

## 3. Ranks

| # | Rank | Total Rep (tune) | Main unlocks | Scope |
|---|---|---|---|---|
| 1 | **Recruit** | 0 | Jet ski (free), Bosun, Calm Bay and harbor mouth calls, radio | [MVP] |
| 2 | **Lifeguard** | 400 | Harbor Light relit, crew joining; Coral Reef calls and binoculars [L] | [MVP] |
| 3 | **Rescue Swimmer** | 900 | RIB (buy), gear level 3; Reef Light mission and wildlife calls [L] | [MVP] |
| 4 | **Coxswain** | 3,000 | Lifeboat (buy), Gannet Rock Light mission, Open Sea, gear level 4; hovercraft [P1] | [L] |
| 5 | **Rescue Pilot** | 9,000 | Rescue helicopter (buy), free helipad on your bay, hoist calls, gear level 5 | [L] |
| 6 | **Captain** | 22,000 | Tempest Point Light mission, Storm Front, Captain's cap; patrol cutter [P1] | [L] |
| 7 | **Commodore** | 55,000 | Commodore liveries (Cash), radio title; Northlight mission and Iceberg North [P1] | [L] |
| 8 | **Admiral** | 150,000 | Admiral gold livery for every vehicle, Admiral's coat, name on the station honor board, Bosun's gold medal | [L] |
| 9+ | **Service Stars** | Every +30,000 after Admiral | One cosmetic per star (below) | [L] |

**Service Stars** are endless prestige levels. Every 30,000 Rep after Admiral (about a week at two sessions a day) (tune) adds a star to the nameplate and pays one cosmetic from a rotating list: a horn, a siren tone, a wake trail, a light bar colour, a Bosun bandana, a livery stripe. After the list runs out, stars pay alternate colours of the same items. Stars never pay stats, and rank gates never sit behind them.

Crew roles ([L]) are open to everyone from the start, so a Recruit can ride along as a Medic in a friend's helicopter or take a seat in the station helicopter on a big call. Rank only limits which vehicles a player can own and drive.

Each rank-up plays a short ceremony at the station (skippable): Chief Aggie pins the badge, Bosun barks, and the player's nameplate updates for the whole server.

## 4. Vehicle ladder

| Vehicle | Unlock rank | Cash price (tune) | Seats (crew + victims) | Scope |
|---|---|---|---|---|
| Jet ski | Recruit | Free (first vehicle) | 1 + 1 | [MVP] |
| RIB inflatable | Rescue Swimmer | 4,000 | 3 + 2 | [MVP] |
| Rescue board | Recruit | Free | 1 + 1 | [L] |
| Lifeboat | Coxswain | 12,000 | 4 + 8 | [L] |
| Rescue helicopter | Rescue Pilot | 75,000 | 4 + 4 | [L] |
| Hovercraft | Coxswain | 30,000 | 4 + 6 | [P1] |
| Patrol cutter | Captain | 150,000 | 4 + 20 (plus up to 4 other players as passengers) | [P1] |

The station loaner RIB (tutorial call 2) is free for one call only.

### 4.1 Vehicle upgrades

Each vehicle has three upgrade levels. Prices are a share of the vehicle's price; the free vehicles (jet ski, rescue board) use fixed prices.

| Level | Cost (tune) | Effect |
|---|---|---|
| 1. Tuned engine | 25% of price (free vehicles: 300) | +8% top speed |
| 2. Storm hull | 50% of price (free vehicles: 800) | Better stability in waves; jet ski, RIB and hovercraft capsize less |
| 3. Extra seat | 100% of price (free vehicles: 1,500) | +1 victim seat |

**Liveries** are Cash cosmetics (2,000 to 50,000, tune) and a long-term Cash sink. Some liveries and vehicle cosmetics (horns, sirens, wake trails, light bars) are Robux-only or Service Star rewards ([document 04](04-monetization.md)). Paint never changes stats.

## 5. Gear upgrades

Gear is personal and works on every vehicle. Each item has five levels. The MVP has three items (Fins, Radio direction finder, Tow rope) at levels 1 to 3.

| Level | Cash cost (tune) | Rank needed |
|---|---|---|
| 1 | 300 | Recruit |
| 2 | 1,200 | Recruit |
| 3 | 4,000 | Rescue Swimmer |
| 4 | 12,000 | Coxswain |
| 5 | 30,000 | Rescue Pilot |

| Gear | What it improves (per level, tune) | Scope |
|---|---|---|
| **Rescue tube and line** | Throw range 12 to 24 studs, faster reel | [L] |
| **Fins** | Swim speed +8% | [MVP] |
| **Binoculars** | Time to mark a victim 1.0 s down to 0.4 s; more zoom | [L] |
| **Radio direction finder** | Bearing cone ±30° down to ±8° | [MVP] |
| **Fire pump nozzle** | Spray rate +12%, longer reach | [L] |
| **Medic kit** | Comfort refill per step +10%; level 3 adds the stretcher | [L] |
| **Hoist winch** | Winch speed +12%, wider clip ring | [L] |
| **Tow rope** | Tension tolerance +10% | [MVP] |
| **Searchlight** | Range and beam width | [L] |
| **Drysuit** | Needed for Iceberg North; each level lets the player swim longer in cold water | [P1] |

## 6. Station upgrades (your bay)

Every player has their own bay at Port Haven Station: a berth, a locker, a kennel and a trophy wall. Upgrades are personal and show on the bay for others to see.

| Upgrade | Levels and Cash cost (tune) | Effect | Scope |
|---|---|---|---|
| **Radio Room** | 2,000 / 8,000 / 25,000 / 60,000 / 120,000 | Shows 1 to 3 call offers at once, adds the victim count and call type to each offer, shrinks the search circle by up to 40% | [L] |
| **Slipway** | 5,000 / 30,000 / 100,000 | Shorter launch cooldown per level, none at level 3. Level 3 also lets you launch from the Coral Key and Gannet Rock outposts (delivering there is free for everyone) | [L] |
| **Kennel** | 3,000 / 15,000 / 50,000 | Bosun's nose range 80 to 140 studs, faster swim, level 3 lets him carry a line to a second swimmer | [L] |
| **Med Bay** | 10,000 / 40,000 | Deliver to your own bay instead of the hospital at full pay; level 2 adds +5% Cash on medical calls | [L] |
| **Crew Mess** | 10,000 / 40,000 | Crews that launch from your bay get +5% per level on top of the crew bonus | [L] |
| **Lookout Tower** | 15,000 / 60,000 | Distress flares in your zones show at +25% and +50% range | [L] |
| **Helipad** | Free at Rescue Pilot | Needed to keep the helicopter | [L] |
| **Trophy wall** | Free | Shows badges, ranks and big-call trophies | [L] |

## 7. Lighthouses and zone unlocks

Each lighthouse is a short story mission run by Tobias Wick (3 to 6 minutes). The player needs the rank, then starts the mission from the radio. Once relit, the light shines for that player in every server, and its zone opens.

| Lighthouse | Zone | Rank needed | Mission | Scope |
|---|---|---|---|---|
| Harbor Light | Calm Bay (already open); opens Coral Reef calls [L] | Lifeguard | Ferry Tobias to the pier light, light the lamp. Doubles as the Lifeguard ceremony. | [MVP] |
| Reef Light | Coral Reef (open since Lifeguard); adds wildlife and rock calls | Rescue Swimmer | Find three lens pieces around Coral Key using the radio bearing. | [L] |
| Gannet Rock Light | Open Sea | Coxswain | Run the lamp's spare battery out through a fog bank, then guide the ferry home. | [L] |
| Tempest Point Light | Storm Front | Captain | Relight during a storm. Starts only in the storm phase (or a summoned storm). | [L] |
| Northlight | Iceberg North | Commodore | Break through ice by hovercraft or cutter. | [P1] |

## 8. Badges

Roblox badges, awarded once each. Players see them on their trophy wall.

| Badge | How to get it | Scope |
|---|---|---|
| First Rescue | Finish call 1 | [MVP] |
| Good Boy | Bosun finds a victim first | [L] |
| Tow Truck | Finish a tow without snapping the line | [MVP] |
| Fire's Out | Put out a boat fire | [L] |
| Storm Chaser | Finish a call during a storm | [MVP] |
| One rank badge each | Reach each rank, Lifeguard to Admiral (7 badges) | [MVP] Lifeguard and Rescue Swimmer, [L] the rest |
| One lighthouse badge each | Relight each lighthouse (4, then 5) | [L] |
| Full Crew | Finish a call with four crew | [L] |
| By the Book | Follow a full search pattern | [L] |
| Steady Hands | Hoist without missing the clip | [L] |
| Ferry Hero | Rescue a victim in a Capsized Ferry big call | [L] |
| Cruise Control | Rescue a victim in a Cruise Ship Aground big call | [P1] |
| Along for the Ride | Work the hoist from the station helicopter's ride-along seat | [L] |
| First Star | Earn a Service Star | [L] |
| Air Pocket | Reach a trapped passenger as Rescue Swimmer | [L] |
| Gold Standard | 25 Gold grades | [L] |
| Hundred Saves | 100 people rescued | [L] |
| Thousand Saves | 1,000 people rescued | [L] |
| Every Craft | Own every vehicle in the game (five at launch, seven from [P1]) | [L] |
| Just a Little Stuck | Rescue Barnaby 10 times | [L] |
| The Long Storm | Take part in the Season 1 finale | [P1] |

## 9. Daily and weekly challenges

Nell's challenge board at the bait shop [L]. Rewards scale with the player's highest open zone ("zone base" below), so they stay useful at every rank.

**Daily: 3 challenges** from a pool, refreshed at 00:00 UTC. Each pays 3x zone base Cash and 2x zone base Rep (tune). Finishing all three adds a Bosun treat (a short dog emote) and 1,000 Cash. Examples: "Rescue 5 swimmers", "Finish 2 calls in a storm", "Get 3 Gold grades", "Do a call as Medic", "Tow a boat 500 studs".

**Weekly: 5 challenges**, refreshed Monday 00:00 UTC. Each pays 10x zone base Cash and 5x zone base Rep (tune). Finishing all five gives a weekly stamp; four stamps unlock that month's livery. Examples: "Take part in 3 big calls", "Finish 10 calls with a crew", "Relight a lighthouse or reach a new rank", "Rescue 50 people".

Unfinished challenges simply expire. Nothing carries a penalty.

### 9.1 Leaderboards [L]

Station boards and an in-game panel show weekly and all-time **people rescued**, **storm rescues** and **crew rescues** (a crew's combined saves), per server and global. Boards count rescues only, never Cash, Rep or Robux spent, and reset weekly so new players can place. The storm summary board ([document 02](02-core-loop-and-mechanics.md), section 8) feeds the server board.

## 10. Pacing model

Rough targets for a player who plays the game's way: takes calls, does dailies, and joins crews sometimes. The model uses **25-minute sessions, two a day** (tune), one daily set per day, and one weekly set by day 7. "Hours" means active playtime. Built from the rates in section 2.1. All [L] unless tagged.

**First two hours: an unlock every 10 to 15 minutes.**

| Time | Session | Unlock | Paid with |
|---|---|---|---|
| 0:02 | 1 | First rescue; the jet ski and Bosun are yours | Free |
| 0:10 | 1 | Lifeguard: Harbor Light relit, crew joining, Coral Reef calls | 400 Rep |
| 0:15 | 1 | First storm, beginner call at the harbor mouth | (storm clock) |
| 0:18 | 1 | First gear level | 300 Cash |
| 0:25 | 1 | Rescue Swimmer: RIB unlocked, about 700 Cash away at session end | 900 Rep |
| 0:30 | 2 | RIB bought | 4,000 Cash |
| 0:40 | 2 | Reef Light relit; wildlife calls | Mission |
| 0:50 | 2 | First daily set (Bosun treat); a gear item to level 2 | Challenges, 1,200 Cash |
| 1:05 | 3 | RIB Tuned engine | 1,000 Cash |
| 1:15 | 3 | Coxswain: lifeboat unlocked, Gannet Rock mission | 3,000 Rep |
| 1:25 | 4 | Gannet Rock Light relit; Open Sea and its outpost open | Mission |
| 1:35 | 4 | Lifeboat bought | 12,000 Cash |
| 1:40 | 4 | Second daily set | Challenges |
| 1:55 | 5 | Jet ski Storm hull or a second gear item to level 2 | 800 to 1,200 Cash |
| 2:05 | 5 | Third daily set; lifeboat Tuned engine | Challenges, 3,000 Cash |

**MVP** (Calm Bay only, no dailies): Lifeguard at about 0:10, Rescue Swimmer at about 0:30, RIB bought at about 0:38 (tune). The MVP playtest checks the first 40 minutes only.

| When | Rank and Rep | Owns | World |
|---|---|---|---|
| **Session 1** (25 min) | Rescue Swimmer (~900 Rep) | Jet ski, Bosun, one gear item at level 1; RIB unlocked, almost affordable (~3,300 of 4,000 Cash) | Harbor Light relit, Coral Reef open, one storm rescue at the harbor mouth |
| **First 2 hours** (5 sessions, days 1 to 3) | Coxswain (~6,000 Rep) | RIB with Tuned engine, lifeboat, three gear items at level 1 to 2 | Reef Light and Gannet Rock Light relit, Open Sea open; three daily sets done |
| **Week 1** (14 sessions, about 6 hours) | Rescue Pilot (day 4), close to Captain (~21,500 Rep) | RIB fully upgraded, lifeboat with two upgrades, a rescue helicopter (around day 5 or 6), five gear items at level 3, Radio Room 2, Kennel 1, jet ski fully upgraded | Open Sea is home, Tempest Point is next |
| **Month 1** (60 sessions, about 25 hours) | Commodore (~115,000 Rep) | Helicopter and lifeboat fully upgraded, most gear at 4 to 5, most station upgrades, first liveries | All four lighthouses lit |
| **Admiral** | 150,000 Rep | Everything in the launch build | About day 39 (~32 hours), roughly six weeks at two sessions a day. Service Stars after that, about one a week. |

### 10.1 How the numbers were built

- **Session 1:** tutorial chain (~12 minutes) gives ~470 Rep and ~1,700 Cash. Then 13 minutes of Coral Reef (~1,950 Rep/h, ~8,700 Cash/h) gives ~890 Rep and ~3,600 Cash, minus 300 for the first gear level.
- **Sessions 2 to 5:** Coral Reef to Coxswain (~1:15), Gannet Rock mission, then Open Sea, plus three daily sets (Coral Reef day 1, Open Sea days 2 and 3: about 540 to 780 Rep and 4,600 to 7,300 Cash each) gives ~6,300 Rep and ~39,000 Cash earned. Spent by 2 hours: RIB 4,000, RIB engine 1,000, lifeboat 12,000, gear ~3,300.
- **Sessions 6 to 14:** 3.75 hours of Open Sea (~8,800 Rep, ~47,600 Cash), four more daily sets (~3,100 Rep, ~29,200 Cash) and one weekly set (~3,250 Rep, ~35,000 Cash). Week 1 total: **~21,500 Rep and ~151,000 Cash**.
- **Week 1 spending:** RIB with all upgrades 11,000; lifeboat with two upgrades 21,000; helicopter 75,000; five gear items to level 3 27,500; Radio Room 1 and 2 10,000; Kennel 1 3,000; jet ski upgrades 2,600. Total **~150,000**, so the Owns column fits what was earned. Rescue Pilot arrives on day 4 (~2.7 hours); the Cash for the helicopter on day 5 or 6.
- **Month 1:** Captain on day 8, then Storm Front (~2,850 Rep/h) for ~19 hours, plus 23 daily sets and three weekly sets, gives ~115,000 Rep (Commodore around day 16). Storm Front Cash (~745,000 in weeks 2 to 4) goes into helicopter upgrades, gear levels 4 and 5 and station upgrades, which together cost more than that.
- **After month 1:** about 4,100 Rep a day (two Storm Front sessions plus dailies and weeklies), so Admiral around day 39 and a Service Star about every 7 days.

### 10.2 Watch list for tuning

- **First rank in under 12 minutes** for at least 80% of new players (tune).
- **Unlock cadence.** No gap over 20 minutes in the first 2 hours. If a gap opens, move a price or threshold before raising payouts.
- **The hook in session 1.** At least 80% of new players finish a storm call (harbor mouth or ride-along) in their first session (tune).
- **Helicopter in week 1** is the big retention promise. If it slips past 8 hours of play, cut its price before raising payouts.
- **Late-game Cash** piles up at Storm Front rates. Liveries, vehicle upgrades and [P2] station decoration must soak it up, or Cash loses meaning for Captains and above.
- **2x Cash pass effect.** A 2x Cash owner reaches the helicopter's Cash price by about session 7 (~3 hours), about when they reach Rescue Pilot (~2.7 hours). Rank stays the gate, by design.
