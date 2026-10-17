# 03 · Progression

This file owns every progression number: payouts, rank thresholds, prices in Cash, and the pacing model. Names come from [`01-game-canon.md`](01-game-canon.md), mechanics from [`02-core-loop-and-mechanics.md`](02-core-loop-and-mechanics.md), and operations, grading and certification content from [`09-rescue-operations.md`](09-rescue-operations.md). Every number marked **(tune)** is a first guess for playtests; nothing here is a Roblox benchmark.

## 1. Principles

1. **Reputation is earned only by playing.** Operations, exercises, challenges and big calls give it. Nothing sold for Robux adds it, including Cash packs and 2x Cash.
2. **Rank and certification open doors, Cash buys the key.** A rank (plus, for some, a certification) unlocks the right to buy a vehicle or relight a lighthouse. Cash pays for it. So a player who buys Cash still has to earn the rank and pass the certification.
3. **Skill is earned, never bought.** Grades, certifications and Pro mode come only from how a player performs. Gear upgrades change what a player can do (range, speed, capacity), never how a step is graded: grade bands are measured against the kit in use (for example, tow tension is graded as a share of the line's own rating), so a better rope does not make a careless tow Gold.
4. **Always one next thing.** At every point the HUD shows the next unlock and how far away it is (in Rep, Cash or certification steps).
5. **Early unlocks are fast, late ones are slow.** First rank in about 10 minutes, an unlock every 10 to 15 minutes for the first 2 hours, the helicopter in week 1, Admiral in about six weeks, then endless Service Stars. The model assumes 25-minute sessions, two a day (section 10).
6. **No streak resets, no losses.** A takeover never costs Cash, Rep or a certification. Missing a day never resets anything.

## 2. Payouts

Base payout per operation, before the operation's weight ([document 02](02-core-loop-and-mechanics.md), section 3), grade and bonuses. Operations are longer than the old one-button calls (about 4 to 7 minutes instead of about 3), so base pay is about 2.2 times the old per-call values and the **hourly** rates in section 2.1 stay where they were. That keeps the whole pacing model (section 10) intact.

| Zone | Base Cash (tune) | Base Rep (tune) | Opens at |
|---|---|---|---|
| Calm Bay (and harbor mouth storm operations) | 550 | 135 | Recruit |
| The Skerries [L] | 900 | 200 | Lifeguard (Harbor Light) |
| Open Sea [L] | 1,500 | 280 | Coxswain (Gannet Rock Light) |
| Storm Front [L] | 2,400 | 390 | Captain (Tempest Point Light) |
| Iceberg North [P1] | 3,300 | 500 | Commodore (Northlight) |

Zones are areas on the map ([document 10](10-world-and-map.md), section 1.2): beach and cliff operations at Long Strand, Gull Cove, Kittiwake Cliffs and the Saltings pay at the Skerries rate.

**Final payout** = base x operation weight x grade (Gold 1.25, Silver 1.0, Bronze 0.75) x storm (1.5 for operations tasked in the Storm phase; 2 for Cash in a Great Storm; paid storms boost Cash only, Rep stays at the normal rate) x crew bonus (1.0 to 1.3, human crew only) x Pro mode (Rep x1.2, tune) x 2x Cash pass (Cash only).

Other payout rules (tune):

- **Tutorial chain.** Operation 1 (Reopening Day, under 3 minutes) pays 500 Cash and 150 Rep. Operations 2 and 3 pay 600 Cash and 160 Rep each.
- **Exercises** ([document 09](09-rescue-operations.md), section 9.2) pay 200 Cash and 50 Rep the first time each is passed, nothing on repeats.
- **Crew members** are paid only if they completed a step on the operation ([document 02](02-core-loop-and-mechanics.md), section 7); otherwise they get the 10% share.
- **By the Book** [L] (flew or drove the full expanding square or sector search): +10% Rep.
- **Big calls.** Each casualty pays 0.3x the big call's zone base to the player who hands it over. Every player who completed a step on the big call, including ride-along seats in the Coastguard helicopter, gets a completion bonus of 2.5x the zone base in Cash and 1.5x in Rep, scaled by the share of casualties saved before the big call's own timer ran out ([document 02](02-core-loop-and-mechanics.md), section 3.1). The On Scene Coordinator gets +20% on the completion bonus (tune).
- **Takeover** (condition reached Critical or the operation cap passed, [document 09](09-rescue-operations.md), section 2.5): each completed step pays half its share of the operation's payout (its weight over the total weight), Cash and Rep; no completion share.
- **Assisting a takeover** (standing by for the helicopter) pays like a Silver step.

### 2.1 Earning rates

An operation cycle is about 6.5 minutes: about 45 s out and 45 s back ([document 02](02-core-loop-and-mechanics.md), section 4.1), 3 to 4 minutes of on-scene steps, and about a minute for the debrief, kit and launch. Further zones have longer scenes. Rates assume an average weight of about 1.1, Silver grades, Assist mode, and storms for about a fifth of operations (x1.5 pay then, so about x1.1 overall). Measured in playtests, then tuned.

| Zone | Operations per hour (tune) | Cash per hour (tune) | Rep per hour (tune) | Per 25-min session (Cash / Rep) |
|---|---|---|---|---|
| Calm Bay | 9 | ~6,000 | ~1,450 | ~2,500 / ~600 |
| The Skerries [L] | 8 | ~8,700 | ~1,950 | ~3,600 / ~810 |
| Open Sea [L] | 7 | ~12,700 | ~2,350 | ~5,300 / ~980 |
| Storm Front [L] | 6 | ~17,300 | ~2,850 | ~7,200 / ~1,190 |
| Iceberg North [P1] | 5.5 | ~21,800 | ~3,350 | ~9,100 / ~1,400 |

A player can always take operations in any zone they have opened. Higher zones pay more but need better vehicles and more certifications to finish well. Gold-grade players earn up to about 25% more and Pro players about 20% more Rep; the pacing model below does not count on either.

## 3. Ranks

| # | Rank | Total Rep (tune) | Certification needed | Main unlocks | Scope |
|---|---|---|---|---|---|
| 1 | **Recruit** | 0 | None | Jet ski (free), lifeguard 4x4 (free), Bosun, Calm Bay and harbor mouth operations, radio | [MVP] |
| 2 | **Lifeguard** | 400 | Helm | Harbor Light relit, crew joining; Skerries operations, binoculars and the beach ATV [L] | [MVP] |
| 3 | **Rescue Swimmer** | 900 | Rescue Swimmer (which needs Casualty Care) | RIB (buy), gear level 3; Skerry Light mission, wildlife operations and the response vehicle with boat trailer [L] | [MVP] |
| 4 | **Coxswain** | 3,000 | Coxswain | Lifeboat (buy), the Long Strand launch tractor, Gannet Rock Light mission, Open Sea, gear level 4; hovercraft [P1] | [L] |
| 5 | **Rescue Pilot** | 9,000 | Pilot (which needs Winch Operator) | Rescue helicopter (buy), free helipad on your bay, winch operations, gear level 5 | [L] |
| 6 | **Captain** | 22,000 | None new | Tempest Point Light mission, Storm Front, Captain's cap; patrol cutter [P1] | [L] |
| 7 | **Commodore** | 55,000 | None new | Commodore liveries (Cash), radio title; Northlight mission and Iceberg North [P1] | [L] |
| 8 | **Admiral** | 150,000 | All six | Admiral gold livery for every vehicle, Admiral's coat, name on the station honor board, Bosun's gold medal | [L] |
| 9+ | **Service Stars** | Every +30,000 after Admiral | | One cosmetic per star (below) | [L] |

**Service Stars** are endless prestige levels. Every 30,000 Rep after Admiral (about a week at two sessions a day) (tune) adds a star to the nameplate and pays one cosmetic from a rotating list: a horn, a siren tone, a wake trail, a light bar colour, a Bosun bandana, a livery stripe. After the list runs out, stars pay alternate colours of the same items. Stars never pay stats, and rank gates never sit behind them.

If a player reaches a rank's Rep before passing its certification, the Rep keeps counting and the HUD shows the certification as the next thing ("Pass Rescue Swimmer to be promoted"); the promotion happens the moment both are done. Crew roles are open to everyone from the start as **trainees** beside a certified crewmate ([document 09](09-rescue-operations.md), section 4.3), so a Recruit can ride along as Medic in a friend's RIB or take a trainee winch seat in the Coastguard helicopter on a big call. Rank and certifications only limit which roles a player can lead and which vehicles they can own and drive.

Each rank-up plays a short ceremony at the station (skippable): Chief Aggie pins the badge, Bosun barks, and the player's nameplate updates for the whole server.

### 3.1 Certifications

Certifications are the realistic half of progression: real crews are assessed for each role. Their content (exercises, live requirements, what each gates) is in [document 09](09-rescue-operations.md), section 11; their place on the ladder is here. Reputation stays the rank currency. Certifications are never sold, never expire and are never lost.

| Certification | Exercise + live requirement (tune) | Expected at (section 10) | Gates | Scope |
|---|---|---|---|---|
| **Helm** | Boat handling + 2 operations with the approach or alongside step at Silver or better | ~0:13 (end of the tutorial chain) | Lifeguard rank; leading the Helm seat in the RIB and up; buying the RIB | [MVP] |
| **Casualty Care** | Casualty care + 2 operations with survey and treatment at Silver or better | ~0:20 | Leading the Medic seat; oxygen, CPR and triage as lead; AED [L] | [MVP] |
| **Rescue Swimmer** | Swim test + 1 swimmer recovery at Silver or better; needs Casualty Care. Air-pocket endorsement: hull and dive drill + one ferry hull-team step | ~0:27; endorsement at the first ferry call | Rescue Swimmer rank; entering the water from boats; Winchman as lead; air-pocket dive | [MVP] |
| **Coxswain** | Tow and command exercises + lead 3 operations as Helm at Silver or better overall, including one tow and one storm operation; needs Helm and Casualty Care | ~1:10 | Coxswain rank; lifeboat; On Scene Coordinator; search patterns | [L] |
| **Winch Operator** | Winch exercise + 3 helicopter lifts at Silver or better (one double lift, one stretcher); ride-along lifts count | Days 2 to 4 (storm big calls) | Leading the Winch Operator seat in player helicopters | [L] (ride-along trainee seat [MVP]) |
| **Pilot** | Flight school + 2 winch operations flown with the hover at Silver or better; needs Coxswain rank and Winch Operator | Day 4 (~2.7 hours) | Rescue Pilot rank; flying the helicopter | [L] |
| **Rescue Diver** | Dive school (buddy check, ascent, line signals) + 2 dive tasks at Silver or better; needs Rescue Swimmer and Coxswain rank | Week 1 | Scuba to about 30 m; the Rescue Diver role (air-pocket dives as lead, propeller and hull work, entangled wildlife) ([document 10](10-world-and-map.md), section 4.5) | [P1] |

Each certification is a Roblox badge (section 8) and a small badge on the nameplate. The HUD's "next thing" counts certification steps ("Casualty Care: 1 of 2 operations").

## 4. Vehicle ladder

| Vehicle | Unlock rank | Cash price (tune) | Seats (crew + casualties) | Scope |
|---|---|---|---|---|
| Jet ski | Recruit | Free (first vehicle) | 1 + 1 | [MVP] |
| RIB inflatable | Rescue Swimmer (and Helm) | 4,000 | 3 + 2 | [MVP] |
| Rescue board | Recruit | Free | 1 + 1 | [L] |
| Lifeboat | Coxswain (and the Coxswain certification) | 12,000 | 4 + 8 | [L] |
| Rescue helicopter | Rescue Pilot (and Pilot) | 75,000 | 4 + 4 | [L] |
| Hovercraft | Coxswain | 30,000 | 4 + 6 | [P1] |
| Patrol cutter | Captain | 150,000 | 4 + 20 (plus up to 4 other players as passengers) | [P1] |

The station loaner RIB (tutorial operation 2, with an NPC Helm instructor) is free for one operation only.

**Land vehicles** are free station pool vehicles, gated by rank only, so they never compete with boats for Cash ([document 10](10-world-and-map.md), section 3). Their liveries are Cash cosmetics like any other.

| Land vehicle | Unlock | Seats | Scope |
|---|---|---|---|
| Lifeguard 4x4 pickup | Recruit | 5 | [MVP] |
| Beach ATV | Lifeguard | 1 + beach sled | [L] |
| Coastguard response vehicle and boat trailer | Rescue Swimmer (and Helm) | 5 | [L] |
| Lifeboat launch tractor (Long Strand) | Coxswain | 1 | [L] |
| Ambulance (volunteer shift) | Rescue Swimmer and Casualty Care | 2 + 1 casualty | [P1] (NPC only at [L]) |

### 4.1 Vehicle upgrades

Each vehicle has three upgrade levels. Prices are a share of the vehicle's price; the free vehicles (jet ski, rescue board) use fixed prices.

| Level | Cost (tune) | Effect |
|---|---|---|
| 1. Tuned engine | 25% of price (free vehicles: 300) | +8% top speed |
| 2. Storm hull | 50% of price (free vehicles: 800) | Better stability in waves; jet ski, RIB and hovercraft capsize less |
| 3. Extra seat | 100% of price (free vehicles: 1,500) | +1 casualty seat |

**Liveries** are Cash cosmetics (2,000 to 50,000, tune) and a long-term Cash sink. Some liveries and vehicle cosmetics (horns, sirens, wake trails, light bars) are Robux-only or Service Star rewards ([document 04](04-monetization.md)). Paint never changes stats.

## 5. Gear upgrades

Gear is personal and works on every vehicle. Each item has five levels. Gear improves numbers (range, speed, capacity) but never widens a grade band (principle 3): a step's Gold criteria are always measured against the kit in use. The MVP has three items (Fins, Radio direction finder, Tow rope) at levels 1 to 3.

| Level | Cash cost (tune) | Rank needed |
|---|---|---|
| 1 | 300 | Recruit |
| 2 | 1,200 | Recruit |
| 3 | 4,000 | Rescue Swimmer |
| 4 | 12,000 | Coxswain |
| 5 | 30,000 | Rescue Pilot |

| Gear | What it improves (per level, tune) | Scope |
|---|---|---|
| **Throw bag and rescue tube** | Throw range 12 to 24 studs, longer line | [L] |
| **Fins** | Swim speed +8% | [MVP] |
| **Binoculars** | Time to mark a casualty 1.0 s down to 0.4 s; more zoom | [L] |
| **Radio direction finder** | Bearing cone ±30° down to ±8° | [MVP] |
| **Fire pump nozzle** | Spray rate +12%, longer reach | [L] |
| **Medic kit** | Casualty recovery rate while treated +10% per level; level 3 adds the stretcher | [L] |
| **Hoist winch** | Winch speed +12% | [L] |
| **Tow rope** | Line rating +10% (tension is graded as a share of the rating, so grades do not change) | [MVP] |
| **Searchlight** | Range and beam width | [L] |
| **Drysuit** | Needed for Iceberg North; each level lets the player swim longer in cold water | [P1] |

## 6. Station upgrades (your bay)

Every player has their own bay at Port Haven Station: a berth, a locker, a kennel and a trophy wall. Upgrades are personal and show on the bay for others to see.

| Upgrade | Levels and Cash cost (tune) | Effect | Scope |
|---|---|---|---|
| **Radio Room** | 2,000 / 8,000 / 25,000 / 60,000 / 120,000 | Shows 1 to 3 tasking offers at once, adds the POB and operation type to each offer, makes the tasking's datum more reliable (search area up to 40% smaller) | [L] |
| **Slipway** | 5,000 / 30,000 / 100,000 | Shorter launch cooldown per level, none at level 3. Level 3 also lets you launch from the Skerry Isle and Gannet Rock outposts (delivering there is free for everyone) | [L] |
| **Kennel** | 3,000 / 15,000 / 50,000 | Bosun's nose range 80 to 140 studs (Pro: 40 to 70), faster swim, level 3 lets him carry a line to a second swimmer | [L] |
| **Med Bay** | 10,000 / 40,000 | Hand over at your own bay (an ambulance waits there) instead of the hospital pontoon at full pay; level 2 adds +5% Cash on operations with a casualty | [L] |
| **Crew Mess** | 10,000 / 40,000 | Crews that launch from your bay get +5% per level on top of the crew bonus | [L] |
| **Lookout Tower** | 15,000 / 60,000 | Distress flares in your zones show at +25% and +50% range | [L] |
| **Helipad** | Free at Rescue Pilot | Needed to keep the helicopter | [L] |
| **Trophy wall** | Free | Shows badges, ranks and big-call trophies | [L] |

## 7. Lighthouses and zone unlocks

Each lighthouse is a short story mission run by Tobias Wick (3 to 6 minutes). The player needs the rank, then starts the mission from the radio. Once relit, the light shines for that player in every server, and its zone opens.

| Lighthouse | Zone | Rank needed | Mission | Scope |
|---|---|---|---|---|
| Harbor Light | Calm Bay (already open); opens the Skerries [L] | Lifeguard | Ferry Tobias to the pier light, light the lamp. Doubles as the Lifeguard ceremony. | [MVP] |
| Skerry Light | The Skerries (open since Lifeguard); adds wildlife and cliff operations | Rescue Swimmer | Find three lens pieces around Skerry Isle using the radio bearing. | [L] |
| Gannet Rock Light | Open Sea | Coxswain | Run the lamp's spare battery out through a fog bank, then guide the ferry home. | [L] |
| Tempest Point Light | Storm Front | Captain | Relight during a storm. Starts only in the storm phase (or a summoned storm). | [L] |
| Northlight | Iceberg North | Commodore | Break through ice by hovercraft or cutter. | [P1] |

## 8. Badges

Roblox badges, awarded once each. Players see them on their trophy wall.

| Badge | How to get it | Scope |
|---|---|---|
| First Rescue | Finish operation 1 | [MVP] |
| Good Boy | Bosun finds a casualty first | [L] |
| One certification badge each | Pass each certification (6) | [MVP] Helm, Casualty Care, Rescue Swimmer; [L] the rest |
| Downwind | 10 approaches at Gold | [MVP] |
| Gentle Hands | Hand over 5 very cold casualties in the Stable band | [L] |
| Clean Handover | 10 ATMIST handovers with every card right | [L] |
| Scene Commander | Command a Capsized Ferry as On Scene Coordinator with all persons accounted for | [L] |
| Pro Crew | Finish an operation at Gold in Pro mode | [L] |
| Tow Truck | Finish a tow without snapping the line | [MVP] |
| Fire's Out | Put out a boat fire | [L] |
| Storm Chaser | Finish an operation tasked during a storm | [MVP] |
| One rank badge each | Reach each rank, Lifeguard to Admiral (7 badges) | [MVP] Lifeguard and Rescue Swimmer, [L] the rest |
| One lighthouse badge each | Relight each lighthouse (4, then 5) | [L] |
| Full Crew | Finish an operation with four human crew | [L] |
| By the Book | Follow a full search pattern | [L] |
| Steady Hands | A winch operation with the hook earthed every time and no pauses | [L] |
| Ferry Hero | Rescue a casualty in a Capsized Ferry big call | [MVP] |
| Cruise Control | Rescue a casualty in a Cruise Ship Aground big call | [P1] |
| Along for the Ride | Work the winch from the Coastguard helicopter's ride-along seat | [MVP if the spike is ready, else L] |
| First Star | Earn a Service Star | [L] |
| Air Pocket | Lead a trapped passenger out of the air pocket | [MVP] |
| Gold Standard | 25 Gold grades | [L] |
| Hundred Saves | 100 people rescued | [L] |
| Thousand Saves | 1,000 people rescued | [L] |
| Every Craft | Own every vehicle in the game (five at launch, seven from [P1]) | [L] |
| Just a Little Stuck | Rescue Barnaby 10 times | [L] |
| First Wreck | Find the *Morwenna* in Calm Bay | [MVP] |
| Wreck Hunter | Find every wreck in the logbook | [L] |
| Keeper's Tales | Complete every lighthouse history | [L] |
| Seal Code | Log grey seals, dolphins and a basking shark from a respectful distance | [L] |
| Every Cove | Find every hidden cove and cave | [L] |
| Shutterbug | Log 10 sightings in photo mode | [L] |
| Island Explorer | Complete the whole logbook | [L] |
| The Long Storm | Take part in the Season 1 finale | [P1] |

### 8.1 Exploration rewards

Exploration ([document 10](10-world-and-map.md), section 5) pays **no Reputation**, so the pacing model in section 10 is unchanged by it. Rewards are one-time (tune):

| Find | Reward |
|---|---|
| A discovery (point of interest, viewpoint, cove, rock pool, wildlife sighting) | 100 Cash and a logbook entry |
| A wreck | 250 Cash and its story page |
| A lighthouse history | 150 Cash (the relight itself is the story mission, section 7) |
| A completed logbook page (all wrecks, all wildlife, all coves and so on) | 1,000 to 2,500 Cash and a cosmetic: a wreck-hunter mask pattern, a seal plush for the bay, a lighthouse model for the trophy wall, an explorer's jacket |

All launch discoveries together pay about 15,000 Cash (tune), about two and a half hours of Calm Bay operations, once. Exploring never pays per minute, so it cannot be farmed.

## 9. Daily and weekly challenges

Nell's challenge board at the bait shop [L]. Rewards scale with the player's highest open zone ("zone base" below), so they stay useful at every rank.

**Daily: 3 challenges** from a pool, refreshed at 00:00 UTC. Each pays 1.4x zone base Cash and 0.9x zone base Rep (tune; halved from the old per-call multipliers because the base doubled). Finishing all three adds a Bosun treat (a short dog emote) and 1,000 Cash. Examples: "Rescue 3 people in the water", "Finish 2 operations in a storm", "Get 5 Gold steps", "Do an operation as Medic", "Tow a boat without the line going red".

**Weekly: 5 challenges**, refreshed Monday 00:00 UTC. Each pays 4.5x zone base Cash and 2.3x zone base Rep (tune). Finishing all five gives a weekly stamp; four stamps unlock that month's livery. Examples: "Take part in 3 big calls", "Finish 6 operations with a crew", "Relight a lighthouse, reach a new rank or pass a certification", "Rescue 20 people".

Unfinished challenges simply expire. Nothing carries a penalty.

### 9.1 Leaderboards [L]

Station boards and an in-game panel show weekly and all-time **people rescued**, **storm rescues** and **crew rescues** (a crew's combined saves), per server and global. Boards count rescues only, never Cash, Rep or Robux spent, and reset weekly so new players can place. The storm summary board ([document 02](02-core-loop-and-mechanics.md), section 8) feeds the server board.

## 10. Pacing model

Rough targets for a player who plays the game's way: takes operations in Assist mode with Silver grades, does dailies, and joins crews sometimes. The model uses **25-minute sessions, two a day** (tune), one daily set per day, and one weekly set by day 7. "Hours" means active playtime on operations; time spent exploring is extra and earns no Rep. Built from the rates in section 2.1. All [L] unless tagged.

**First two hours: an unlock every 10 to 15 minutes.**

| Time | Session | Unlock | Paid with |
|---|---|---|---|
| 0:03 | 1 | First rescue (under 3 minutes); the jet ski and Bosun are yours | Free |
| 0:13 | 1 | Helm certification, then Lifeguard: Harbor Light relit, crew joining, the Skerries | Exercise + tutorial chain, 400 Rep |
| 0:15 | 1 | First storm, beginner operation at the harbor mouth (or a ferry ride-along) | (storm clock) |
| 0:18 | 1 | First gear level | 300 Cash |
| 0:20 | 1 | Casualty Care certification: oxygen and CPR as lead | Exercise + 2 operations |
| 0:27 | 1 | Rescue Swimmer certification and rank: RIB unlocked, about 1,000 Cash away at session end | Exercise + 1 operation, 900 Rep |
| 0:30 | 2 | RIB bought | 4,000 Cash |
| 0:40 | 2 | Skerry Light relit; wildlife operations | Mission |
| 0:50 | 2 | First daily set (Bosun treat); a gear item to level 2 | Challenges, 1,200 Cash |
| 1:05 | 3 | RIB Tuned engine | 1,000 Cash |
| 1:10 | 3 | Coxswain certification | Exercises + 3 led operations |
| 1:15 | 3 | Coxswain: lifeboat unlocked, Gannet Rock mission | 3,000 Rep |
| 1:25 | 4 | Gannet Rock Light relit; Open Sea and its outpost open | Mission |
| 1:35 | 4 | Lifeboat bought | 12,000 Cash |
| 1:40 | 4 | Second daily set | Challenges |
| 1:55 | 5 | Jet ski Storm hull or a second gear item to level 2 | 800 to 1,200 Cash |
| 2:05 | 5 | Third daily set; lifeboat Tuned engine | Challenges, 3,000 Cash |

**MVP** (Calm Bay only, no dailies): first rescue under 0:03, Helm and Lifeguard at about 0:13, Casualty Care at about 0:20, Rescue Swimmer (certification and rank) at about 0:30, RIB bought at about 0:38 (tune). The MVP playtest checks the first 40 minutes only.

| When | Rank and Rep | Owns | World |
|---|---|---|---|
| **Session 1** (25 min) | Rescue Swimmer (~900 Rep) | Jet ski, Bosun, one gear item at level 1, Helm, Casualty Care and Rescue Swimmer certifications; RIB unlocked, almost affordable (~3,000 of 4,000 Cash) | Harbor Light relit, the Skerries open, one storm rescue at the harbor mouth |
| **First 2 hours** (5 sessions, days 1 to 3) | Coxswain (~6,000 Rep), Coxswain certification | RIB with Tuned engine, lifeboat, three gear items at level 1 to 2 | Skerry Light and Gannet Rock Light relit, Open Sea open; three daily sets done |
| **Week 1** (14 sessions, about 6 hours) | Rescue Pilot (day 4, with Winch Operator and Pilot certifications), close to Captain (~21,500 Rep) | RIB fully upgraded, lifeboat with two upgrades, a rescue helicopter (around day 5 or 6), five gear items at level 3, Radio Room 2, Kennel 1, jet ski fully upgraded | Open Sea is home, Tempest Point is next |
| **Month 1** (60 sessions, about 25 hours) | Commodore (~115,000 Rep) | Helicopter and lifeboat fully upgraded, most gear at 4 to 5, most station upgrades, first liveries | All four lighthouses lit |
| **Admiral** | 150,000 Rep | Everything in the launch build | About day 39 (~32 hours), roughly six weeks at two sessions a day. Service Stars after that, about one a week. |

### 10.1 How the numbers were built

- **Session 1:** tutorial chain (three operations, ~13 minutes) gives ~470 Rep and ~1,700 Cash. Three exercises (~6 minutes, first pass) give 150 Rep and 600 Cash. The remaining ~6 minutes in the Skerries and the harbor mouth storm (~1,950 Rep/h, ~8,700 Cash/h) give ~200 Rep and ~900 Cash. Total ~820 to 900 Rep and ~3,200 Cash, minus 300 for the first gear level; Rescue Swimmer lands at about 0:27 (tune; it may slip into session 2 for slower players, which the watch list tracks).
- **Sessions 2 to 5:** the Skerries to Coxswain (~1:15), Gannet Rock mission, then Open Sea, plus three daily sets (the Skerries day 1, Open Sea days 2 and 3: about 540 to 760 Rep and 4,800 to 7,300 Cash each) gives ~6,300 Rep and ~39,000 Cash earned. Spent by 2 hours: RIB 4,000, RIB engine 1,000, lifeboat 12,000, gear ~3,300.
- **Sessions 6 to 14:** 3.75 hours of Open Sea (~8,800 Rep, ~47,600 Cash), four more daily sets (~3,100 Rep, ~29,200 Cash) and one weekly set (~3,250 Rep, ~35,000 Cash). Week 1 total: **~21,500 Rep and ~151,000 Cash**.
- **Week 1 spending:** RIB with all upgrades 11,000; lifeboat with two upgrades 21,000; helicopter 75,000; five gear items to level 3 27,500; Radio Room 1 and 2 10,000; Kennel 1 3,000; jet ski upgrades 2,600. Total **~150,000**, so the Owns column fits what was earned. Rescue Pilot arrives on day 4 (~2.7 hours); the Cash for the helicopter on day 5 or 6.
- **Month 1:** Captain on day 8, then Storm Front (~2,850 Rep/h) for ~19 hours, plus 23 daily sets and three weekly sets, gives ~115,000 Rep (Commodore around day 16). Storm Front Cash (~745,000 in weeks 2 to 4) goes into helicopter upgrades, gear levels 4 and 5 and station upgrades, which together cost more than that.
- **After month 1:** about 4,100 Rep a day (two Storm Front sessions plus dailies and weeklies), so Admiral around day 39 and a Service Star about every 7 days.

### 10.2 Watch list for tuning

- **First rescue in under 3 minutes** for at least 90% of new players, and **first rank in under 15 minutes** for at least 80% (tune).
- **Operation length.** Standard operations should land at 4 to 7 minutes. If one runs long, cut a step's length (section 10 of [document 09](09-rescue-operations.md)) before raising its pay.
- **Certification friction.** If more than 30% of players reach a rank's Rep without its certification, make the certification's exercise easier or let more operation types count; never lower the procedure bar.
- **Unlock cadence.** No gap over 20 minutes in the first 2 hours. If a gap opens, move a price or threshold before raising payouts.
- **The hook in session 1.** At least 80% of new players finish a storm operation (harbor mouth or ride-along) in their first session (tune).
- **Helicopter in week 1** is the big retention promise. If it slips past 8 hours of play, cut its price before raising payouts.
- **Late-game Cash** piles up at Storm Front rates. Liveries, vehicle upgrades and [P2] station decoration must soak it up, or Cash loses meaning for Captains and above.
- **2x Cash pass effect.** A 2x Cash owner reaches the helicopter's Cash price by about session 7 (~3 hours), about when they reach Rescue Pilot (~2.7 hours). Rank stays the gate, by design.
