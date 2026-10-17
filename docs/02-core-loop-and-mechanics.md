# 02 · Core loop and mechanics

How Mayday plays, from the first second to the daily habit. Names and rules come from [`01-game-canon.md`](01-game-canon.md). Progression numbers (payouts, prices, thresholds, calls per hour) live in [`03-progression.md`](03-progression.md); this file only uses relative values such as "x1.5", plus the map scale and vehicle speeds in section 4.1, which it owns. Tech lives in [`06-tools-and-pipeline.md`](06-tools-and-pipeline.md). MVP scope is in [`01-game-canon.md`](01-game-canon.md), section 9.1. Numbers marked **(tune)** are first guesses.

## 1. Core loop

```mermaid
flowchart LR
    A[Mayday on the radio] --> B[Launch a vehicle<br/>from your bay]
    B --> C[Search<br/>flare, radio bearing,<br/>Bosun, search pattern]
    C --> D[Rescue mini-task<br/>pull aboard, tow, fire,<br/>hoist, first aid]
    D --> E[Deliver to dock<br/>or hospital]
    E --> F[Payout<br/>Cash + XP + Reputation<br/>+ grade]
    F --> G[Upgrade vehicles,<br/>gear, station]
    G --> H[Rank up, relight<br/>a lighthouse]
    H --> I[Bigger calls in<br/>harder zones]
    I --> A
    S((Storm every ~15 min)) -.burst of calls,<br/>big calls, x1.5 pay.-> A
```

XP and Reputation are the same number. The UI calls it Reputation; "XP" appears only in the payout popup as "+80 Rep".

## 2. The first two minutes

The research says discovery punishes players who leave in the first 60 and 180 seconds ([`research/store-page-and-monetization.md`](research/store-page-and-monetization.md), section 5, https://create.roblox.com/docs/discovery.md). So: no menus, no text walls, a rescue inside 90 seconds, and nothing for sale on screen.

| Time | What the player sees and does |
|---|---|
| 0:00 | Spawns on the station slipway at golden hour. Gulls, waves, a crackling radio. Camera already behind the character. No loading menu, no team pick. |
| 0:02 | Radio: "Mayday, mayday! Swimmer caught in the current off Sandy Point!" Chief Aggie, in a speech bubble: "Recruit! No time for paperwork. Take the jet ski!" |
| 0:04 | A glowing arrow points to the jet ski, 8 studs away. Bosun bounds out of the station and sits on its rescue sled, tail going. |
| 0:07 | Player walks to the jet ski. One button: **Launch** (big, bottom right on phone). |
| 0:09 | On the water. Movement hint fades in: "Steer with the stick". Speed is capped low for this call and the current pulls gently toward the swimmer, so steering is forgiving. |
| 0:10 | A red flare arcs up about 700 studs ahead (tune). The minimap pings. |
| 0:30 | Jet ski reaches the swimmer, who waves both arms on a pink inflatable flamingo. Bosun stands up on the sled and barks toward them. Prompt: **Hold to pull aboard**. |
| 0:32 | Hold 1.5 s. The swimmer climbs onto the sled, Bosun licks their face. "Thank you! I thought I was going to Spain!" |
| 0:35 | A green beacon appears on the dock. Hint: "Bring them home." |
| 0:55 | Arrive at the dock. Dr. Osei waves. Auto-deliver on contact. |
| 0:57 | Payout popup: Gold grade, +Cash, +Rep, badge **First Rescue**. Confetti, a horn from the ferry. The Rep bar fills a third of the way to Lifeguard. |
| 1:05 | Chief: "Not bad! Here's your radio." The radio panel slides in, showing one new call. "Barnaby's stuck on a sandbar again. Take the station RIB, just this once." |
| 1:10 | A loaner RIB (marked "Station Loaner") waits at the slipway. Launching it teaches the bigger boat and shows what the next rank buys. |
| 1:15 | Barnaby's call teaches the radio bearing: no flare this time, just a needle on the HUD that points toward his signal. |
| 1:45 | Reach *The Optimist*. Prompt: **Attach tow line**. A short, gentle tow off the sandbar. |
| 2:00 | Barnaby: "Just a little stuck, Chief!" Payout. The storm clock appears for the first time: "Storm in 6:40". |

Rules for the first session (tune): the first five calls are a fixed tutorial chain; nothing with a Robux price is shown until the player has finished three calls; if a storm is active on join, the tutorial calls happen inside the sheltered harbor where waves stay small. The storm clock is per server, so the first storm reaches a new player within about 15 minutes, inside a 25-minute session. When it hits, the radio offers the player a beginner storm call at the **harbor mouth**: full storm waves, a short ride from the station, a small search circle and a longer timer. If a big call rolls, players below Rescue Pilot are also offered a seat in the station helicopter (section 3.1). Every first session should end with a storm rescue.

## 3. Call types

Each call has a **zone**, a **timer** (how long until the fail-safe takes over), a **grade** (Gold, Silver, Bronze) and a **payout weight** that multiplies the zone's base payout ([document 03](03-progression.md)).

Grade rules (all calls): Gold if finished in under 60% of the timer and the victim's comfort meter stays above half; Silver if finished before the timer; Bronze if finished after a "late" warning or with comfort in the red. Gold pays x1.25, Silver x1.0, Bronze x0.75 (tune). In the MVP there is no comfort meter, so the grade is speed only, with a small penalty for rock bumps.

**Fail state for every call:** the timer runs out, an NPC backup lifeboat or ferry arrives, and the radio says the victim is safe on their way to hospital. The player gets 10% of the payout as a "you tried" bonus (tune) and no Reputation. Nothing else is lost.

| Call | Zones | How it plays | Success | Weight | Scope |
|---|---|---|---|---|---|
| **Swimmer in Trouble** | All | Swimmer in a rip current or tired far out. Search, approach slowly, hold to pull aboard (or send the Rescue Swimmer or Bosun). | Swimmer delivered to dock | x1.0 | [MVP] |
| **Drifting Craft** | Calm Bay, Coral Reef | Paddleboard, kayak or inflatable drifting out. Often a child and a parent. Two people to pick up. | Both delivered | x1.1 | [MVP] |
| **Disabled Boat** | All | Engine failure, out of fuel, or stuck on a sandbar (Barnaby). Attach a tow line and tow back to the harbor or the nearest outpost without snapping it. | Boat moored at the dock | x1.3 | [MVP] |
| **Boat Fire** | All | Smoke on the horizon. Spray the hotspots with the fire pump, then take the crew off. | Fire out, crew delivered | x1.5 | [L] |
| **Seasick Passenger** | Calm Bay, Open Sea | Tour boat with a sick or bumped passenger. Come alongside, do first aid, bring them to the hospital. | Delivered to hospital | x1.2 | [L] |
| **Wildlife Rescue** | Coral Reef, Iceberg North | Turtle or seal tangled in a net. Cut the net (trace mini-task) and let it swim away. No delivery leg. | Animal freed | x0.8 | [L] |
| **Person Overboard** | Open Sea, Storm Front | Someone fell off a ferry or trawler. No flare, a short radio burst, then a search pattern. | Delivered to hospital | x1.4 | [L] |
| **Stranded on the Rocks** | Coral Reef, Storm Front | Hikers cut off by the tide on a cliff or rock. Boats cannot get close in swell; a Rescue Swimmer swims a line in, or a helicopter hoists. | All delivered | x1.6 | [L] |
| **Injured on Deck** | Open Sea, Storm Front | Trawler crew member with a "bad bump". Helicopter hoist with a stretcher, or come alongside in calm water. First aid first. | Delivered to hospital | x1.7 | [L] |
| **Sinking Yacht** | Open Sea, Storm Front | Water rising (a meter on the hull). Take everyone off before it fills, or pump water to buy time. Vance's yacht in the finale. | All aboard before it sinks | x1.8 | [L] |
| **Lost in the Fog** | Open Sea | Fog bank. Visibility 40 studs. Radio bearing and sound only. | Delivered | x1.5 | [L] |
| **Odd Job** (Hazel's calls) | Calm Bay | Cat on a buoy, a lost beach ball, a seagull stole a sandwich. Short, silly, low stakes. | Item or pet returned | x0.5 | [L] |
| **Ice Trapped** | Iceberg North | Trawler stuck in floes. Hovercraft or cutter breaks a path, then tow. | Towed clear | x2.0 | [P1] |

### 3.1 Big calls (storm only)

Big calls appear only during storms, one at a time per server, announced to everyone. They are built for 6 to 16 players across several vehicles. [L]

- **Own timer.** A big call spawns at storm start and runs its own timer of 6 to 8 minutes by size (tune), so it keeps going through Clearing and into Calm. The storm's waves and rain stay over the big call's site until it ends. When the timer runs out, the fail-safe boats take whoever is left.
- **Victims scale with the server.** Each big call has a base victim count and always spawns at least one victim per player on the server (tune), so a full server never runs out of people to save.
- **Everyone who helped is paid.** The player who delivers a victim gets the per-victim pay. The completion bonus goes to every player who did at least one role action on the big call: pulled someone aboard, delivered, hoisted, towed, treated, spotted a victim, or drove a vehicle that carried one ([document 03](03-progression.md), section 2).
- **Station helicopter ride-along.** On every big call an NPC-flown station helicopter lifts off from Port Haven with two free seats for players below Rescue Pilot. Tap **Ride along** on the call card and you are seated as Hoist Operator or Rescue Swimmer; the NPC pilot flies by script and holds the hover, and you run the winch or jump in. You earn the same pay as any other helper. It shows every new player the hero vehicle in their first storms. (tune: seat count, rank cap)

| Big call | Base victims (min 1 per player) | How it plays | Chance per storm (tune) | Scope |
|---|---|---|---|---|
| **Capsized Ferry** (*Gale Queen*) | 12 | Ferry on its side. Passengers in the water, on the hull, and two trapped in an air pocket (Rescue Swimmer only). Lifeboats carry the most. | 35% | [L] |
| **Trawler on the Rocks** | 6 | Waves break over the deck. Hoist only, plus a fire in the engine room. | 30% | [L] |
| **Cruise Ship Aground** (*MS Splendora*) | 30 | Huge ship on a reef, listing. Passengers on deck for hoisting, lifeboats lowered in the water to tow, a medic tent on the beach. | 10% | [P1] |
| **Lighthouse Keeper** | 1 | Tobias stuck at a lighthouse in the storm. Story call only. | Story | [L] |

If no big call rolls, the storm still has its burst of normal calls. At launch a player sees a big call in about 2 of every 3 storms, and about 3 of every 4 once Cruise Ship Aground lands in [P1] (tune).

## 4. Vehicle handling feel

All water vehicles ride one wave height function: a few summed sine waves, cheap to evaluate and exact at any point. The visible ocean mesh is drawn from the same function, so what the player sees is what the hull feels ([document 06](06-tools-and-pipeline.md), section 3.1). Storms raise the amplitude. Handling is arcade first: forgiving turns, auto-throttle on phone if the stick is pushed fully, and no fuel.

| Vehicle | Feel | Seats | Strengths | Weaknesses | Scope |
|---|---|---|---|---|---|
| **Rescue board** | Paddle. Slow, stable, almost impossible to tip. | 1 + victim + Bosun | Shallows, beaches, surf calls | Very slow, no tow, no fire pump | [L] |
| **Jet ski** | The first vehicle, free. Zippy, bouncy, hops wave crests, slides on turns. | 1 + victim + rescue sled (Bosun rides it) | Fastest in calm water, fun; tows small craft (paddleboards, kayaks, *The Optimist*) at half speed (tune) | Flips in storm waves if hit side-on; 1 victim only | [MVP] |
| **RIB inflatable** | Planes at speed, punches through chop, quick to stop. | 3 + 2 victims | All-rounder, tow light boats, small fire pump ([L]) | Bounces hard in big swell | [MVP] |
| **Lifeboat** | Heavy and steady. Self-righting, never capsizes. Slower to turn. | 4 + 8 victims | Storm-proof, strong tow, med bay seat | Slow, cannot enter reef shallows | [L] |
| **Hovercraft** | Floats over water, sand, reef and ice. Slides and drifts like on ice. | 4 + 6 victims | Crosses shallows and sandbars, beach landings | Pushed sideways by wind, weak in big waves | [P1] |
| **Rescue helicopter** | Hover-first. Stick moves, auto-altitude holds 30 studs over the waves. Gusts shake it in storms. | 4 crew (pilot, hoist operator, swimmer, medic) + 4 victims | Ignores waves, fastest across zones, hoist, widest spotting | Must hover to rescue; gusts push it off the hoist ring | [L] (MVP: tech spike only) |
| **Patrol cutter** | Big ship. Slow to speed up and turn, rock steady. | 4 crew roles + up to 4 other players as passengers + 20 victims | Fire monitor, deck crane, med bay, launches a small RIB from the stern, helicopter can land on deck | Slow, cannot go inshore | [P1] |

### 4.1 Map scale and travel budget

Every call should take about **45 seconds out and 45 seconds back** with the vehicle a zone is meant for (tune). Calls spawn only where that holds, measured from the nearest open dock. Distances are from the Port Haven slipway; all numbers (tune).

| Zone | Ring (studs from the station) | Nearest delivery dock | Intended vehicle |
|---|---|---|---|
| Calm Bay (harbor mouth at about 900) | 0 to 1,500 | Port Haven station or hospital | Jet ski |
| Coral Reef | 1,500 to 3,500 | Coral Key outpost (about 2,500) | Jet ski, RIB |
| Open Sea | 3,500 to 6,000 | Gannet Rock outpost (about 5,000) | RIB, lifeboat |
| Storm Front | 6,000 to 7,000 | Gannet Rock outpost | Lifeboat, helicopter |
| Iceberg North [P1] | A northern sector, 6,000 to 9,000 | Northlight dock | Hovercraft, cutter |

**Map radius:** about 7,500 studs at launch, 9,000 with Iceberg North; the MVP map is Calm Bay only, about 1,500 (tune). The Coral Key and Gannet Rock outposts are **free delivery docks** for everyone once their zone is open (victims go by NPC ferry to the hospital, at full pay). Launching from an outpost is what the Slipway upgrade and Quick Launch add ([document 03](03-progression.md), section 6).

| Vehicle | Top speed, studs/s (tune) | Cruise in waves (about 75%) | 45 s covers about |
|---|---|---|---|
| Rescue board | 20 | 15 | 700 |
| Jet ski | 70 | 52 | 2,350 |
| RIB inflatable | 60 | 45 | 2,000 |
| Lifeboat | 45 | 36 (keeps it in storms) | 1,600 |
| Hovercraft [P1] | 55 | 40 | 1,800 |
| Rescue helicopter | 110 | 110 (ignores waves) | 5,000 |
| Patrol cutter [P1] | 40 | 35 | 1,600 |

Storm waves cut boat cruise speed by about 20% (lifeboat 5%) (tune). The server rejects speeds above a vehicle's top speed plus upgrades ([document 06](06-tools-and-pipeline.md), section 3.2). Calls per hour per zone follow from this budget and live in [document 03](03-progression.md), section 2.1.

**Capsize rules.** Only the jet ski, RIB and hovercraft can capsize, and only in storm waves when hit side-on. The player floats in a life jacket, Bosun paddles over, and a prompt **Right the boat** (hold 3 s) flips it back. Victims on board stay safe on the hull. No damage, no repair bill.

**Collisions.** Hitting rocks gives a bump, a splash and a scrape sound, and costs the call grade a little (a comfort meter drop from [L]). Vehicles never break.

In the MVP, Bosun does not swim: after a capsize he floats beside the player in his vest and barks encouragement.

## 5. Search mechanics

Every call gives a **search circle** on the map. Its size depends on the call type and, from [L], the Radio Room level ([document 03](03-progression.md)). Inside the circle the player uses these tools. The MVP has flares, the radio bearing and Bosun barking and pointing; the rest are [L] unless tagged.

| Tool | How it works | Who has it |
|---|---|---|
| **Flares** | Some victims fire a red flare when the call starts and again every 25 s (tune), visible from 400 studs. Fog and rain cut the range. | All calls except Person Overboard and Lost in the Fog |
| **Radio bearing** | A needle on the HUD compass points toward the victim's radio within an error cone (starts at ±30°, shrinks with gear). The cone narrows as the player gets closer. | Victims with a radio (boats, ferries, trawlers) |
| **Bosun's nose** | Inside 80 studs Bosun stands up, points and barks in the victim's direction. In water he swims toward them ([L]). | All calls |
| **Whistle and shouts** | 3D audio from the victim inside 60 studs. Headphones help, but the HUD also shows a small sound ripple for players with sound off. | Swimmers and people in the water [L] |
| **Binoculars** | Hold to zoom. A victim in view for 1 s is marked on the map for the whole crew. | Gear, all players [L] |
| **Searchlight** | Cone of light on the water at night and in storms. Victims' reflective tape glints in it. | RIB and up [P1 night, L storms] |
| **Search pattern** | For calls with no flare, the HUD offers a suggested pattern (expanding square from the last known position, or a creeping line along a drift). Following it lights up pattern legs and pays a "By the Book" bonus of +10% Rep (tune). | Optional on all calls [L] |

From [L], victims drift with the current and wind, so the last known position goes stale. The drift direction is shown as faint arrows on the water, which teaches why real search patterns move downwind. In the MVP victims stay put.

## 6. Rescue mini-tasks

Every mini-task is short (3 to 12 seconds), works with one thumb on a phone, and has a solo and a crew version. The MVP has **Pull aboard** and **Tow** only; the rest are [L].

| Mini-task | Solo version | Crew version | Fail inside the task |
|---|---|---|---|
| **Pull aboard** | Come alongside below a speed limit, hold 1.5 s. | Rescue Swimmer jumps in and brings the victim to the boat, so the driver does not need to stop exactly. | Too fast: the victim splashes off, try again. |
| **Throw a line** | Aim the rescue tube, release when the ring is over the victim, then reel in with a hold. | Hoist Operator throws from the deck while the Pilot holds position. | Miss: reel in and throw again (2 s). |
| **Tow** | Get within 6 studs of the bow, press **Attach**. While towing, a tension meter rises with speed and sharp turns. Red for 2 s snaps the line. | Hoist Operator manages tension with a slack/tight slider, letting the Pilot go faster. | Snapped line: drift back, reattach. |
| **Fire out** | Aim the pump. Each fire has 3 to 6 hotspots that shrink under water and grow back if left alone. | Two players on two hoses; Medic takes the crew off while it burns. | If the fire reaches the fuel tank meter, the crew jump into the water (life jackets on) and the call becomes a Swimmer call for less pay. |
| **Hoist** | Helicopter auto-hover assist holds position; player lowers the cable (hold), lines up the clip with a swaying target (release on the ring), then raises. | Pilot holds the hover ring by hand against gusts, Hoist Operator runs the winch. Faster and pays the crew bonus. | Clip misses: raise and try again. Pilot drifting off the ring pauses the winch. |
| **First aid** | Three quick steps from a set of six: warm blanket (drag), check breathing (tap in rhythm), cold pack (hold), bandage a scrape (trace a line), water bottle (tap), "you're safe now" (tap to talk). | Medic does it en route, which freezes the comfort meter and adds the Medic bonus. | Wrong step costs a little comfort, never fails the call. |
| **Cut the net** | Trace the glowing net lines. | Rescue Swimmer does it in the water while the boat holds off. | None, just slower. |

**Comfort meter** [L]. Every rescued person has a comfort meter that slowly drops while they are on board (cold, scared, seasick) and faster in storms. First aid, blankets and a smooth ride keep it up. Comfort sets part of the grade. It never reaches a "fail" state.

## 7. Co-op crew roles

A crew is up to four players who share a vehicle and a call. A player creates a crew from the radio panel or by walking up to another player's vehicle and pressing **Join crew**. Roles are picked from a wheel when joining and can be changed at any time at the station or when the vehicle is stopped.

**MVP crew join** is simpler: no roles. A crewmate rides along and can pull victims aboard, attach or manage the tow, and spot. The four roles below are [L].

| Role | Main job | Perks | Solo stand-in |
|---|---|---|---|
| **Pilot / Driver** | Drives or flies. Owner of the vehicle by default. | +10% top speed with a full crew (tune); hover ring is wider for a Pilot holding it by hand. | The player |
| **Rescue Swimmer** | Jumps in to reach victims where the vehicle cannot: rocks, capsized hulls, air pockets. | Fastest swimmer, can carry one victim, only role that can enter air pockets in big calls. | Bosun (slower, cannot enter air pockets) |
| **Medic** | First aid on board, stretcher work, triage on big calls. | Freezes the comfort meter while treating; +15% payout on calls with first aid (tune). | Short first aid task done by the player |
| **Hoist Operator** | Winch, crane, tow tension, throwing lines. | Faster winch, fine control of tow tension, can throw lines from any boat. | Auto-hover assist and a simpler winch |

**Crew payout.** Every crew member gets the full call payout plus a crew bonus of +10% per extra member, up to +30% for four (tune). Nobody's share shrinks when a friend joins. Being aboard is not enough: a crew member is paid only if they did at least one **role action** on the call and were in the crew for at least 30% of it (tune). Role actions: driving or flying for at least 15 s of the call, pulling a victim aboard, attaching or managing the tow, a first aid step, a hoist or line throw, a Rescue Swimmer swim, or marking a victim (tune). A crew member with no role action gets the 10% "you tried" share only.

**Solo balance target.** A solo player clears a call in about 125% of the time a full crew takes (tune). Solo can do every call except entering big-call air pockets.

## 8. Storm event

A server-wide event on a fixed cycle. Everyone on the server sees the same storm at the same time.

| Phase | Length (tune) | What happens |
|---|---|---|
| **Calm** | ~10 min (full cycle 15 min) | Normal calls. The storm clock counts down on the HUD. |
| **Warning** | 60 s | Radio: "Storm warning, all stations." Clouds roll in, wind picks up, the station siren sounds. Players head out or swap to a storm-ready vehicle. |
| **Storm** | 3 min | Waves x2.5 height, heavy rain, lightning (visual and sound only, never hits players), gusts push helicopters. Call rate x3. All payouts x1.5. A big call may spawn ([L], with its own 6 to 8 minute timer, section 3.1). |
| **Clearing** | 60 s | Sun breaks through, a rainbow over Port Haven, calm water. Remaining storm calls stay at x1.5 until delivered. A summary board shows the server's storm rescues and names the top three crews. |

Calm Bay inside the harbor wall gets only light rain and small waves during a storm, so new players are never punished. The **harbor mouth** gets full storm waves and its own beginner storm calls (Swimmer in Trouble and Drifting Craft, longer timers, small search circles, Calm Bay pay with the storm bonus) (tune). This is where a Recruit has their first storm rescue. In the MVP the harbor mouth is the storm. The time of day does not change during a storm; only clouds, light and weather do ([document 05](05-art-direction.md), section 6).

**Storm Summon** ([document 04](04-monetization.md)) adds an extra storm on demand. Summoned storms follow the same phases and can never overlap a natural storm. In a summoned storm the bonus applies to Cash only, never Reputation: x1.5 Cash for Call the Storm, x2 Cash for the Great Storm (4-minute Storm phase).

## 9. Session loops

| Loop | What a player does | Hook to the next loop |
|---|---|---|
| **5 minutes** | One or two calls, a payout, a short trip to the bay to spend Cash. | The storm clock, a vehicle nearly affordable. |
| **25 minutes (one session)** | One to two storm cycles: about eight calls, at least one storm with a burst of calls and maybe a big call, a challenge or two done. In the first two hours, an unlock every 10 to 15 minutes ([document 03](03-progression.md), section 10). | Next storm in a few minutes; a rank or vehicle "almost there" on the HUD. |
| **Daily** | Three daily challenges from Nell's board, a daily login gift (Cash and a Bosun treat), two or three storms with friends. | Weekly challenges, the next vehicle, the season finale count. |
| **Weekly** | Weekly challenges, a new rank or vehicle, a lighthouse relit. Updates add calls and liveries. | Season arc and the next zone. |

There are no streaks that reset. A missed day never costs a player anything.

## 10. Anti-grief rules

The sea is the opponent, never other players.

1. **No PvP.** No weapons, no damage, no way to knock a player off a vehicle.
2. **Soft vehicle collisions.** Vehicles of different crews pass through each other with a gentle splash (collision groups). Nobody can ram, block or push another player's boat.
3. **Call claims.** The first crew to accept a call owns it. Other players can see it but cannot pick up its victims, unless the owner invites them into the crew. An unclaimed or abandoned call (owner more than 600 studs away for 45 s, tune) is released to everyone.
4. **No stealing deliveries.** A victim belongs to the crew that rescued them until delivered.
5. **Big calls are shared.** Anyone can rescue any victim in a big call. Whoever delivers a victim gets its pay, and everyone who helped gets the completion bonus, so there is nothing to fight over.
6. **One vehicle per player** on the water. Empty vehicles despawn after 60 s (tune). The station slipway gives each bay its own launch lane, so no queue.
7. **Crew kicks.** The vehicle owner can remove a crew member, who is moved to the nearest dock, keeping any payout earned so far.
8. **No griefing with Bosun.** Dogs pass through players and vehicles and cannot block a slipway or dock.
9. **Helicopter downwash** is visual only. It never pushes players or boats.
10. **AFK farming.** Payouts need real call actions. An idle player stops getting calls after 5 minutes and is moved to the station after 15 (tune).
11. **Chat.** Roblox filtered chat plus a quick radio wheel ("On my way!", "Need a hoist!", "Thanks, crew!") so players can coordinate without typing.
12. **Storm Summon limits.** Summons queue, never stack, and never start within 2 minutes of a natural storm, so nobody can make the server permanently stormy.
