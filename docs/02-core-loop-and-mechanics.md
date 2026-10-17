# 02 · Core loop and mechanics

How Mayday plays, from the first second to the daily habit. Names and rules come from [`01-game-canon.md`](01-game-canon.md). Progression numbers (payouts, prices, thresholds, calls per hour) live in [`03-progression.md`](03-progression.md); this file only uses relative values such as "x1.5", plus the map scale and vehicle speeds in section 4.1, which it owns. Tech lives in [`06-tools-and-pipeline.md`](06-tools-and-pipeline.md). The rescue operations themselves (steps, radio, crew roles on scene, grading, certifications, kit) live in [`09-rescue-operations.md`](09-rescue-operations.md); this file links into it. The world layout (the island, roads, beaches, seabed, discoverables, free exploration) lives in [`10-world-and-map.md`](10-world-and-map.md), which works its travel times from the speeds here. MVP scope is in [`01-game-canon.md`](01-game-canon.md), section 9.1. Numbers marked **(tune)** are first guesses.

## 1. Core loop

The core loop is the **operation**: a real rescue played step by step ([document 09](09-rescue-operations.md)). Everything else (vehicles, gear, ranks, certifications, the storm) exists to make the next operation possible, harder or better.

```mermaid
flowchart LR
    A[Tasking from<br/>Gale Isles Coastguard] --> B[Kit and launch<br/>from your bay]
    B --> C[Passage and search<br/>datum, drift, lookout]
    C --> D[On scene steps<br/>approach, recovery,<br/>survey, treatment<br/>or assess, rig, tow]
    D --> E[Transport and<br/>handover]
    E --> F[Debrief<br/>step grades, Cash, Rep]
    F --> G[Certifications,<br/>vehicles, gear, station]
    G --> H[Rank up, relight<br/>a lighthouse]
    H --> I[Harder operations<br/>in harder zones]
    I --> A
    S((Storm every ~15 min)) -.tasking burst,<br/>big call, x1.5 pay.-> A
```

XP and Reputation are the same number. The UI calls it Reputation; "XP" appears only in the debrief as "+135 Rep".

## 2. The first three minutes

The research says discovery punishes players who leave in the first 60 and 180 seconds ([`research/store-page-and-monetization.md`](research/store-page-and-monetization.md), section 5, https://create.roblox.com/docs/discovery.md). So: no menus, no text walls, a hands-on drill inside 10 seconds, the first rescue handed over inside 3 minutes, and nothing for sale on screen.

The minute-by-minute script (throw-bag drill with Chief Aggie, the first MAYDAY, jet ski passage, keep eyes on, downwind approach, throw bag, three-card survey, thermal blanket, smooth ride home, three-card handover at about 2:50) is in [document 09](09-rescue-operations.md), section 9.1.

Rules for the first session (tune): the first three operations are a fixed tutorial chain, each adding one new kind of step (operation 2 is Barnaby's tow with the station's loaner RIB and an NPC crew; operation 3 adds the full survey and a swimmer recovery as a trainee); nothing with a Robux price is shown until three operations are done; if a storm is active on join, the tutorial operations happen inside the sheltered harbor where waves stay small. The storm clock is per server, so the first storm reaches a new player within about 15 minutes, inside a 25-minute session. When it hits, the Coastguard tasks the player to a beginner storm operation at the **harbor mouth**: full storm waves, a short ride from the station, a small search area and a casualty who starts in the Stable band. If the Capsized Ferry rolls, players below Rescue Pilot are also offered a ride-along seat in the Coastguard helicopter (section 3.1). Every first session should end with a storm rescue. After the tutorial chain the player is **On watch** by default and can switch to **Off duty** to explore with no taskings ([document 10](10-world-and-map.md), section 5.1).

## 3. Operations

Every rescue is an operation from [document 09](09-rescue-operations.md): a chain of graded steps, a casualty **condition meter** instead of a countdown, and a debrief. Each operation type has a **zone** list and a **payout weight** that multiplies the zone's base payout ([document 03](03-progression.md), section 2).

**Grades.** Each step is graded Gold, Silver or Bronze and the step grades make the operation grade ([document 09](09-rescue-operations.md), section 2.4). Gold pays x1.25, Silver x1.0, Bronze x0.75 (tune). Care and technique count far more than speed.

**Fail state for every operation:** the casualty's condition reaches Critical (or a standard operation passes its 12-minute cap, tune), and the harbour patrol or the Coastguard helicopter takes over. The casualty is always safe. The player keeps the steps already done at half pay and gets no completion share ([document 09](09-rescue-operations.md), section 2.5; [document 03](03-progression.md), section 2). Nothing else is lost.

| Operation | Variants (older call names) | Zones | Weight (tune) | Steps | Scope |
|---|---|---|---|---|---|
| **Person in the Water** | Swimmer in a rip, tired swimmer far out, panicking, very cold, not responding; harbor mouth storm version | All | x1.0 | [09 §5](09-rescue-operations.md#5-operation-1-person-in-the-water-mvp) | [MVP] |
| **Person in the Water: two casualties** | Drifting Craft (parent and child off a paddleboard or kayak) | Calm Bay, the Skerries | x1.2 | [09 §5](09-rescue-operations.md#5-operation-1-person-in-the-water-mvp) | [L] |
| **Person in the Water: overboard** | Person Overboard from a ferry or trawler: no flare, search pattern needed | Open Sea, Storm Front | x1.4 | [09 §5.2](09-rescue-operations.md#52-search) | [L] |
| **Disabled Vessel** | Engine failure, out of fuel, fouled propeller, aground on a sandbar (Barnaby) | All | x1.2 | [09 §6](09-rescue-operations.md#6-operation-2-disabled-vessel-mvp) | [MVP] |
| **Capsized Ferry** (big call) | *Gale Queen* turned turtle in a storm | Harbor approaches | Big-call pay (section 3.1) | [09 §7](09-rescue-operations.md#7-operation-3-capsized-ferry-mvp-co-op-big-call-storms-only) | [MVP] |
| **Sinking Vessel** | Sinking Yacht (Vance's yacht in the finale) | Open Sea, Storm Front | x1.6 | [09 §8.1](09-rescue-operations.md#81-sinking-vessel-l) | [L] |
| **Vessel Fire** | Boat Fire | All but Calm Bay | x1.5 | [09 §8.2](09-rescue-operations.md#82-vessel-fire-l) | [L] |
| **Helicopter winch** | Injured on Deck, hoist from a deck or the water | Open Sea, Storm Front | x1.7 | [09 §8.3](09-rescue-operations.md#83-helicopter-winch-operations-l) | [L] |
| **Rip-current beach rescue** | Swimmer in Trouble at the beach tower | Calm Bay, the Skerries | x0.9 | [09 §8.4](09-rescue-operations.md#84-rip-current-beach-rescue-l) | [L] |
| **Cliff casualty** | Stranded on the Rocks | The Skerries, Storm Front | x1.6 | [09 §8.5](09-rescue-operations.md#85-cliff-casualty-l) | [L] |
| **Medical evacuation from a ship** | Seasick or injured passenger on a tour boat, trawler crew ill | Open Sea, Iceberg North | x1.7 | [09 §8.6](09-rescue-operations.md#86-medical-evacuation-from-a-ship-p1) | [P1] (the tour-boat version [L]) |
| **Lost in the Fog** | Disabled Vessel or Person in the Water in a fog bank: radio bearing and sound only | Open Sea | x1.5 | [09 §6](09-rescue-operations.md#6-operation-2-disabled-vessel-mvp) | [L] |
| **Wildlife Rescue** | A seal or seabird tangled in a net: approach, swimmer cuts the net with the knife, no handover leg | The Skerries, Iceberg North | x0.8 | Short: tasking, approach, swimmer, release | [L] |
| **Odd Job** (Hazel's calls) | Cat on a buoy, a lost beach ball: short, gentle, low stakes | Calm Bay | x0.5 | Short: tasking, approach, recovery | [L] |
| **Ice Trapped** | Trawler stuck in floes: hovercraft or cutter breaks a path, then a Disabled Vessel tow | Iceberg North | x2.0 | [09 §6](09-rescue-operations.md#6-operation-2-disabled-vessel-mvp) | [P1] |

### 3.1 Big calls (storm only)

Big calls appear only during storms, one at a time per server, tasked to everyone by a MAYDAY RELAY. They are built for 6 to 16 players across several vehicles, with one player as On Scene Coordinator ([document 09](09-rescue-operations.md), section 7).

- **Own timer.** A big call spawns at storm start and runs its own timer of 8 to 10 minutes by size (tune), so it keeps going through Clearing and into Calm. The storm's waves and rain stay over the big call's site until it ends. When the timer runs out, NPC lifeboats and *Rescue Gale One* take whoever is left.
- **Casualties scale with the server.** Each big call has a base casualty count and always spawns at least one casualty per player on the server (tune), so a full server never runs out of people to save.
- **Everyone who helped is paid.** The player who hands over a casualty gets the per-casualty pay. The completion bonus goes to every player who completed at least one step on the big call: recovered, triaged, knocked on the hull, tended a dive line, coned or ran the winch, drove a boat that carried a casualty, or commanded the scene ([document 03](03-progression.md), section 2).
- **Coastguard helicopter ride-along.** On every big call the NPC-flown *Rescue Gale One* lifts off with two trainee seats for players below Rescue Pilot: **Winch Operator** (cons the pilot and runs the winch) and **Winchman** (goes down on the wire). The NPC pilot flies by script and follows the Winch Operator's conning calls with a short lag. Riders earn the same pay as any other helper, and their lifts count toward the Winch Operator certification. In the MVP this needs the helicopter tech spike; otherwise it arrives at [L]. (tune: seat count, rank cap)

| Big call | Base casualties (min 1 per player) | How it plays | Chance per storm (tune) | Scope |
|---|---|---|---|---|
| **Capsized Ferry** (*Gale Queen*) | 12 + 2 in an air pocket | Scene command, triage tags, liferaft and water pick-ups, hull knocking, an air-pocket dive on a line, helicopter lifts, POB accounting ([document 09](09-rescue-operations.md), section 7) | 60% at MVP and launch, 35% once Trawler on the Rocks lands | [MVP] |
| **Trawler on the Rocks** | 6 | Waves break over the deck. Winch only (09 §8.3), plus an engine-room fire (09 §8.2). | 30% | [L] |
| **Cruise Ship Aground** (*MS Splendora*) | 30 | A huge ship on a rocky reef, listing. Deck lifts by winch, lifeboats towed in the water, a casualty clearing station on the beach. | 10% | [P1] |
| **Lighthouse Keeper** | 1 | Tobias stuck at a lighthouse in the storm. Story operation only. | Story | [L] |

If no big call rolls, the storm still has its burst of standard taskings. At launch a player sees a big call in about 2 of every 3 storms, and about 3 of every 4 once Cruise Ship Aground lands in [P1] (tune).

## 4. Vehicle handling feel

All water vehicles ride one wave height function: a few summed sine waves, cheap to evaluate and exact at any point. The visible ocean mesh is drawn from the same function, so what the player sees is what the hull feels ([document 06](06-tools-and-pipeline.md), section 3.1). Storms raise the amplitude. Handling aims for realistic weight and momentum (boats carry way, pivot from their stern, slam off crests, drift with the wind when in neutral) with phone-friendly input: auto-throttle on phone if the stick is pushed fully, and no fuel. Precise slow-speed handling matters most, because approaches, station-keeping and towing are where operations are graded ([document 09](09-rescue-operations.md)).

| Vehicle | Feel | Seats | Strengths | Weaknesses | Scope |
|---|---|---|---|---|---|
| **Rescue board** | Paddle. Slow, stable, almost impossible to tip. | 1 + casualty + Bosun | Shallows, beaches, surf rescues | Very slow, no tow, no fire pump | [L] |
| **Jet ski** | The first vehicle, free. Zippy, bouncy, hops wave crests, slides on turns. | 1 + casualty on the rescue sled (Bosun rides the footwell) | Fastest in calm water, fun; tows small craft (paddleboards, kayaks, *The Optimist*) at half speed (tune) | Flips in storm waves if hit side-on; 1 casualty only | [MVP] |
| **RIB inflatable** | Planes at speed, punches through chop, quick to stop. | 3 + 2 casualties | All-rounder, tow light boats, small fire pump ([L]) | Bounces hard in big swell | [MVP] |
| **Lifeboat** | Heavy and steady. Self-righting, never capsizes. Slower to turn. | 4 + 8 casualties | Storm-proof, strong tow, med bay seat | Slow, cannot enter reef shallows | [L] |
| **Hovercraft** | Floats over water, sand, reef and ice. Slides and drifts like on ice. | 4 + 6 casualties | Crosses shallows and sandbars, beach landings | Pushed sideways by wind, weak in big waves | [P1] |
| **Rescue helicopter** | Hover-first. Stick moves, auto-altitude holds 30 studs over the waves. Gusts shake it in storms. | 4 crew (Pilot, Winch Operator, Winchman, Medic) + 4 casualties | Ignores waves, fastest across zones, hoist, widest spotting | Must hover to rescue; gusts push it off the hoist ring | [L] (MVP: tech spike only) |
| **Patrol cutter** | Big ship. Slow to speed up and turn, rock steady. | 4 crew roles + up to 4 other players as passengers + 20 casualties | Fire monitor, deck crane, med bay, launches a small RIB from the stern, helicopter can land on deck | Slow, cannot go inshore | [P1] |

### 4.1 Map scale and travel budget

Every operation's passage should take about **45 seconds out and 45 seconds back** with the vehicle a zone is meant for (tune). Taskings spawn only where that holds, measured from the nearest open dock (or, for beach and cliff operations, the nearest car park or rescue point). Distances are from the Port Haven slipway; all numbers (tune). The rings are measured at sea: the main island, Great Gale, fills their northern half, so on the map each zone is an area ([document 10](10-world-and-map.md), section 1.2).

| Zone | Ring (studs from the station) | Nearest delivery dock | Intended vehicle |
|---|---|---|---|
| Calm Bay (harbor mouth at about 900) | 0 to 1,500 | Port Haven station or hospital | Jet ski |
| Skerries | 1,500 to 3,500 | Skerry Isle outpost (about 2,500) | Jet ski, RIB |
| Open Sea | 3,500 to 6,000 | Gannet Rock outpost (about 5,000) | RIB, lifeboat |
| Storm Front | 6,000 to 7,000 | Gannet Rock outpost | Lifeboat, helicopter |
| Iceberg North [P1] | A northern sector, 6,000 to 9,000 | Northlight dock | Hovercraft, cutter |

**Map radius:** about 7,500 studs (2.5 km) at launch, 9,000 with Iceberg North; the MVP map is the main island's south coast, Calm Bay and the harbour mouth, about 2,500 (tune). Drives from the station stay under about 2 minutes, and under 1:30 to any beach ([document 10](10-world-and-map.md), section 1.3). The Skerry Isle and Gannet Rock outposts are **free handover points** for everyone once their zone is open (an ambulance boat takes casualties on to the hospital, at full pay). Launching from an outpost is what the Slipway upgrade and Quick Launch add ([document 03](03-progression.md), section 6).

| Vehicle | Top speed, studs/s (tune) | Cruise in waves (about 75%) | 45 s covers about |
|---|---|---|---|
| Rescue board | 20 | 15 | 700 |
| Jet ski | 70 | 52 | 2,350 |
| RIB inflatable | 60 | 45 | 2,000 |
| Lifeboat | 45 | 36 (keeps it in storms) | 1,600 |
| Hovercraft [P1] | 55 | 40 | 1,800 |
| Rescue helicopter | 110 | 110 (ignores waves) | 5,000 |
| Patrol cutter [P1] | 40 | 35 | 1,600 |

Land vehicles (section 4.3): lifeguard 4x4 top 75 studs/s, coastguard response vehicle 70 (50 towing a trailer), ambulance 75, beach ATV 45, launch tractor 10.

Storm waves cut boat cruise speed by about 20% (lifeboat 5%) (tune). The server rejects speeds above a vehicle's top speed plus upgrades ([document 06](06-tools-and-pipeline.md), section 3.2). Operations per hour per zone follow from this budget and live in [document 03](03-progression.md), section 2.1.

**Capsize rules.** Only the jet ski, RIB and hovercraft can capsize, and only in storm waves when hit side-on. The player floats in a lifejacket and Bosun paddles over. To right it, the player swims to the righting side of the jet ski or hovercraft and pulls as a wave lifts it (a timing step), and on the RIB the crew fires the self-righting airbag on the frame, as real inshore lifeboats do (verify: RNLI Atlantic-class self-righting). Casualties stay safe holding the hull lines, with a condition cost. No damage, no repair bill.

**Collisions.** Hitting rocks gives a bump, a splash and a scrape sound, and costs the current step's grade a little (and a little condition for a cold casualty aboard). Vehicles never break.

In the MVP, Bosun does not swim: after a capsize he floats beside the player in his vest and barks encouragement.

### 4.2 Gravity and scale

[Document 05](05-art-direction.md) sets the world scale at **1 m = 3 studs**. Roblox's default gravity (196.2 studs/s²) is about 6.7 g at that scale, which makes boats slam down off crests too fast, spray fall like gravel and a hovering helicopter feel stiff. **Decision:** set `workspace.Gravity` to about **29.4 studs/s²** (9.81 m/s² x 3) for realistic boat, spray, rope and helicopter motion (tune; verify the feel in a greybox spike before building handling on it).

Side effects to handle in the same spike:

- **Character jumping.** At default jump settings a character would jump about 14 m. Set the jump height to a real step-up of about 1.5 studs (0.5 m) and keep climbing onto boats and pontoons as an animated climb, not a jump (tune).
- **Walking speed.** The default 16 studs/s is about 5.3 m/s, a jog. Walk near 4 to 5 studs/s and run near 12 studs/s on decks and slipways (tune).
- **Falls and ropes.** Things fall more slowly and look heavier, which suits heaving lines, tow lines and the winch hook, but every physics-driven rope, buoyancy and suspension value tuned at default gravity must be retuned. Wave-following casualties and NPC boats are scripted, not physics, so they are unaffected ([CONTRACT](../CONTRACT.md)).

### 4.3 Land vehicles

Cars, the ATV and the launch tractor get players to beaches, cliff tops and slipways ([document 10](10-world-and-map.md), section 3, owns their roles, unlocks and spawn points). They use an in-house raycast chassis tuned at the gravity in section 4.2, with grip per surface (asphalt, gravel, sand, mud, grass, wet variants). Like boats, they never break, never hit pedestrians and pass through other players' vehicles (section 10). Speeds (tune; 1 m = 3 studs):

| Vehicle | Top speed, studs/s (km/h) | Typical cruise, studs/s | Scope |
|---|---|---|---|
| Lifeguard 4x4 pickup | 75 (90) | Town 25, coast road 55, single track 40, gravel 30, soft sand 20 | [MVP] |
| Coastguard response vehicle | 70 (84); 50 (60) towing a trailer | As the 4x4, slower on tracks with a trailer | [L] |
| Ambulance (NPC; player [P1]) | 75 (90) | As the 4x4 on roads | [L] |
| Beach ATV | 45 (54) | Hard sand 40, soft sand 35; beaches, tracks and car parks only | [L] |
| Lifeboat launch tractor | 10 (12) (verify against the real launch tractor) | Beach and surf only | [L] |

## 5. Search mechanics

Searching is a step in every operation. The full design (datum and drift, the search start point, cues such as arm waves, whistles, strobes and flares, keeping eyes on, the expanding square and sector search from Coxswain rank, night searches) is in [document 09](09-rescue-operations.md), section 5.2. Two tools here sit across all operations:

| Tool | How it works | Who has it |
|---|---|---|
| **Radio bearing** | A needle on the HUD compass points toward a casualty's VHF within an error cone (starts at ±30°, shrinks with gear). The cone narrows as the player gets closer. | Casualties with a radio (boats, ferries, trawlers) |
| **Bosun's nose** | Inside 80 studs (40 in Pro mode) Bosun stands up, points and barks toward a casualty. In water he swims toward them ([L]). | All operations |

From [L] the Radio Room upgrade shortens the tasking's error ([document 03](03-progression.md), section 6), so the datum is more reliable. The MVP already has drift: casualties move with the current and boats with the wind.

## 6. Rescue steps

The old one-button mini-tasks are gone. Every on-scene action is a graded step with a real procedure and a skill mechanic: approach, throw bag, swimmer and panic handling, horizontal lift, parbuckle, primary survey, treatment and CPR, transport comfort, ATMIST handover, assessment, heaving line, rigging, tension, alongside tow, triage, hull knocking, the air-pocket dive, conning and winching, fire and pump work. See [document 09](09-rescue-operations.md), sections 5 to 8, with the shared controls in section 2.7.

The casualty **condition meter** ([document 09](09-rescue-operations.md), section 2.2) replaces the old comfort meter and the call timer. It is in the MVP.

## 7. Co-op crew roles

A crew is up to four players who share a vehicle and an operation. A player creates a crew from the radio panel or by walking up to another player's vehicle and pressing **Join crew**. Roles are picked from a wheel when joining and can be swapped whenever the boat is safe.

The roles (Helm, Navigator/Radio, Crew/Swimmer, Medic, and the helicopter's Winch Operator, Winchman and Pilot), which steps each one owns, the **NPC crew** who fill empty seats (about 40% slower, Silver at most), and the **trainee** rule that lets an uncertified player take any role beside a certified crewmate are in [document 09](09-rescue-operations.md), section 4. Certifications are in section 11 there.

**Crew payout.** Every crew member gets the full operation payout plus a crew bonus of +10% per extra human member, up to +30% for four (tune). NPC crew add no bonus. Nobody's share shrinks when a friend joins. Being aboard is not enough: a crew member is paid only if they completed at least one **step** on the operation and were in the crew for at least 30% of it (tune). A crew member with no step gets the 10% share only.

**Solo balance target.** A solo player with NPC crew clears an operation in about 125% of the time a full human crew takes, and can reach Gold by doing the key steps personally (tune). Solo can do every operation; on a big call, the air-pocket dive needs a human or NPC tender on the line, which NPC units provide.

## 8. Storm event

A server-wide event on a fixed cycle. Everyone on the server sees the same storm at the same time.

| Phase | Length (tune) | What happens |
|---|---|---|
| **Calm** | ~10 min (full cycle 15 min) | Standard taskings. The storm clock counts down on the HUD. |
| **Warning** | 60 s | Radio: "Storm warning, all stations." Clouds roll in, wind picks up, the station siren sounds. Players head out or swap to a storm-ready vehicle. |
| **Storm** | 3 min | Waves x2.5 height, heavy rain, lightning (visual and sound only, never hits players), gusts push helicopters. Tasking rate x3. Operations tasked in this phase pay x1.5 and keep storm sea state at their scene until the handover. A big call may spawn (with its own 8 to 10 minute timer, section 3.1). |
| **Clearing** | 60 s | Sun breaks through over Port Haven, the sea starts to settle. Storm operations still running stay at x1.5 until the handover. A summary board shows the server's storm rescues and names the top three crews. |

Calm Bay inside the harbor wall gets only light rain and small waves during a storm, so new players are never punished. The **harbor mouth** gets full storm waves and its own beginner storm operations (Person in the Water with a casualty who starts Stable and a small search area, Calm Bay pay with the storm bonus) (tune). This is where a Recruit has their first storm rescue. In the MVP the harbor mouth is the storm. The time of day does not change during a storm; only clouds, light and weather do ([document 05](05-art-direction.md), section 6).

**Storm Summon** ([document 04](04-monetization.md)) adds an extra storm on demand. Summoned storms follow the same phases and can never overlap a natural storm. In a summoned storm the bonus applies to Cash only, never Reputation: x1.5 Cash for Call the Storm, x2 Cash for the Great Storm (4-minute Storm phase).

## 9. Session loops

An operation is now the unit of play: about 4 to 7 minutes from tasking to handover, plus about a minute to read the debrief, restock kit and accept the next tasking ([document 09](09-rescue-operations.md), section 10). All timings (tune).

| Loop | What a player does | Hook to the next loop |
|---|---|---|
| **5 to 7 minutes (one operation)** | Tasking, the steps, a handover and a debrief with step grades and one tip. | The weak step to do better next time, a certification step "1 of 2", the storm clock. |
| **25 minutes (one session)** | One to two storm cycles: about four operations, at least one of them in a storm (often the Capsized Ferry), an exercise or certification step, a trip to the bay to spend Cash. In the first two hours, an unlock every 10 to 15 minutes ([document 03](03-progression.md), section 10). | Next storm in a few minutes; a rank, certification or vehicle "almost there" on the HUD. |
| **Daily** | Three daily challenges from Nell's board, a daily login gift (Cash and a Bosun treat), two or three storms with friends. | Weekly challenges, the next certification, the next vehicle, the season finale count. |
| **Weekly** | Weekly challenges, a new rank, certification or vehicle, a lighthouse relit. Updates add operations and liveries. | Season arc and the next zone. |

There are no streaks that reset. A missed day never costs a player anything.

Between operations the world is open: players drive the coast, snorkel the wrecks, fill the logbook and take photos, Off duty or On watch ([document 10](10-world-and-map.md), section 5). Exploring pays Cash, cosmetics and badges, never Reputation, so the pacing above does not depend on it.

## 10. Anti-grief rules

The sea is the opponent, never other players.

1. **No PvP.** No weapons, no damage, no way to knock a player off a vehicle.
2. **Soft vehicle collisions.** Vehicles of different crews pass through each other with a gentle splash (collision groups). Nobody can ram, block or push another player's boat.
3. **Tasking claims.** The first crew to accept a tasking owns the operation. Other players can see it but cannot recover its casualties, unless the owner invites them into the crew. An unclaimed or abandoned operation (owner more than 600 studs away for 45 s, tune) is released to everyone.
4. **No stealing handovers.** A casualty belongs to the crew that recovered them until the handover.
5. **Big calls are shared.** Anyone can rescue any casualty in a big call, and the On Scene Coordinator assigns tasks but cannot block anyone. Whoever hands over a casualty gets its pay, and everyone who helped gets the completion bonus, so there is nothing to fight over.
6. **One vehicle per player** on the water, plus one land vehicle. Empty vehicles despawn after 60 s (tune). The station slipway gives each bay its own launch lane, so no queue.
7. **Crew kicks.** The vehicle owner can remove a crew member, who is moved to the nearest dock, keeping any payout earned so far.
8. **No griefing with Bosun.** Dogs pass through players and vehicles and cannot block a slipway or dock.
9. **Helicopter downwash** is visual only. It never pushes players or boats.
10. **AFK farming.** Payouts need completed steps. An idle player stops getting taskings after 5 minutes and is moved to the station after 15 (tune). Off-duty players get no taskings by choice, and a player who is moving is exploring, not idle ([document 10](10-world-and-map.md), section 5.1).
11. **Chat.** Roblox filtered chat plus the radio wheel ([document 09](09-rescue-operations.md), section 3.3), which also carries crew lines ("On my way", "Need the winch", "Thanks, crew") so players can coordinate without typing.
12. **Storm Summon limits.** Summons queue, never stack, and never start within 2 minutes of a natural storm, so nobody can make the server permanently stormy.
