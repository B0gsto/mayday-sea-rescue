# 01 · Game canon

This file is the single source of truth for **Mayday: Sea Rescue**. Every other design document expands one part of it. If another document disagrees with this one, this one wins until it is changed here first.

Numbers marked **(tune)** are starting values we expect to move after playtests. [Document 02](02-core-loop-and-mechanics.md) owns mechanics (including map scale and vehicle speeds), [document 03](03-progression.md) owns progression numbers, [document 04](04-monetization.md) owns prices and [document 06](06-tools-and-pipeline.md) owns tech; where they differ from an anchor here, they win and this file is updated.

## 1. Identity

| | |
|---|---|
| **Working title** | Mayday: Sea Rescue |
| **Pitch** | Firefighting Sim, but on the ocean, with storms. |
| **Fantasy** | Be the hero who saves people at sea. |
| **Platform** | Roblox (phone first, then PC, tablet, console) |
| **Genre** | Job simulator with co-op rescues and a shared weather event |
| **Players per server** | 16 (tune) |
| **Audience** | Core 8 to 15, secondary 16+. Many play on phones. |
| **Content rating target** | The lowest maturity label the questionnaire allows (expected Minimal or Mild). No gore, no death shown. |
| **Session target** | 25 minutes (tune): one to two storm cycles. Every first session sees a storm. |

### 1.1 Why this game, why now

- **Firefighting Sim** (Blackbox Express) shows the "answer the call, drive the vehicle, save people, rank up" loop is hot right now: a fast-rising rescue sim (34.8K peak CCU, Oct 2026), 19,225 live, 92% likes (https://rblxstat.com/games/10767634248, seen 2026-10-17). Its place ID looks older than 2025, so we treat its creation date as unknown; the visit count is flagged unverified in [`research/reference-games.md`](research/reference-games.md).
- **No polished sea rescue game exists.** The coast guard, lifeguard and sea rescue niche is 8 to 10 small roleplay, MilSim and sim titles. None was verified above a few thousand CCU ([`research/reference-games.md`](research/reference-games.md), section 4).
- **The name is clear.** No Roblox game titled "Mayday" was found. "Coast Guard" and "Sea Rescue" are taken, so we avoid them as the lead word.

## 2. Design pillars

Every feature serves at least one pillar. A feature that serves none is cut.

1. **Every call is a hero moment.** A call goes from radio to rescue fast, ends with a clear win, and someone says thank you. A new player finishes a rescue inside 90 seconds of joining.
2. **The sea is the opponent.** Waves, wind, fog and storms make rescues hard. Other players never do. There is no PvP and no way to hurt another player's run.
3. **Better together, fine alone.** Four crew roles make co-op rescues faster and richer. A solo player can do every call, just more slowly.
4. **Light the way home.** Progress is visible in the world: the station comes back to life, lighthouses relight one by one, and the player's boats and helicopter sit in their bay.

## 3. What Mayday is not

- Not a roleplay game with no goals. It has calls, payouts, ranks and a clear next step at all times.
- Not a MilSim. No drills, no military ranks to apply for, no group required.
- Not grim. Nobody drowns, nobody is hurt on screen, nothing is scary for a young child.
- Not a loot-box game at launch. No paid random items.
- Not pay-to-rank. Rank and Reputation can never be bought.

## 4. Setting: Port Haven and the Gale Isles

**The Gale Isles** are a chain of green, rocky islands in a bright, stylized ocean. The weather turns fast. Fishermen, ferries, tourists, surfers and the occasional cruise ship all share the water.

**Port Haven** is the main town: a crescent harbor, painted houses up the hill, a fish market, a bait shop, a ferry pier, the Cottage Hospital, and at the end of the harbor wall, the old **Port Haven Coast Guard Station**.

**The Long Storm.** Years ago a storm sat over the isles for a whole season. The station was damaged, its crews moved away, and one by one the lighthouses went dark. Without the station, the town has made do with Vance Sterling's private salvage boats, which charge a fortune and arrive late.

**The player's arrival.** The game opens on the day Chief Aggie Brightwater reopens the station with one recruit (the player), one jet ski and one very large dog. The player answers the first Mayday before the paint is dry.

### 4.1 Zones

| Zone | Lighthouse | Feel | Main hazards | Scope |
|---|---|---|---|---|
| **Calm Bay** | Harbor Light | Sheltered harbor, beaches, sandbars, swimmers and paddleboards | Rip currents, sandbars | [MVP] |
| **Coral Reef** | Reef Light on Coral Key | Turquoise shallows, reef walls, snorkel tours, sea turtles. Opens at Lifeguard. | Shallow reef (hull scrapes), tight channels | [L] |
| **Open Sea** | Gannet Rock Light | Deep blue swell, fishing trawlers, ferry lanes, fog banks | Big swell, fog, long distances | [L] |
| **Storm Front** | Tempest Point Light | Dark water, sea cliffs, permanent rough weather, wrecks | Huge waves, gusts, lightning, cliffs | [L] |
| **Iceberg North** | Northlight | Pale water, ice floes, research station, seals | Ice, cold (needs drysuit), drifting bergs | [P1] |

Zones are rings outward from Port Haven (map scale in [document 02](02-core-loop-and-mechanics.md), section 4.1). Calm Bay sits inside the harbor wall and stays sheltered even during storms, so a new player's first call is never in a storm. The **harbor mouth**, the gap in the harbor wall a short ride from the station, is the exception: it takes full storm waves and gets beginner storm calls, so a player sees the hook (a real storm rescue) in their first session without leaving the harbor. Coral Key and Gannet Rock have **outposts** with free delivery docks, so long trips stay short.

## 5. Characters

### 5.1 The station

| Character | Role | Personality |
|---|---|---|
| **Chief Agnes "Aggie" Brightwater** | Station chief. Gives the player calls, rank promotions and story beats over the radio. | Retired lifeboat coxswain who came back to reopen the station. Warm, dry, never flustered. Always holding a mug of cocoa. Catchphrase: "Kettle's on. Go get them." |
| **Bosun** | The player's Newfoundland rescue dog. Every player gets one free on their first call. | Huge, fluffy, brave, slightly clumsy on land and graceful in water. Barks toward victims, swims a line out to swimmers, shakes water over everyone at the dock. Players can rename him. |
| **Tobias Wick** | Old lighthouse keeper. Runs each lighthouse relight mission. | Forgetful, kind, talks to the lamps by name. Knows every rock in the isles. |

Newfoundlands are a real water-rescue breed, which lets Bosun do real jobs (towing a swimmer by a rope, finding people by scent and sound) without breaking the tone.

### 5.2 The rival and the comic regular

| Character | Role | Personality |
|---|---|---|
| **Vance Sterling** | Friendly rival. Owner of Sterling Salvage & Yacht Co. Wants the station land for a luxury marina. | Gold jet ski, white suit, big smile. Turns up at rescues to take photos and claim credit. Never mean, just vain. In the season finale he finally needs rescuing himself and changes his mind about the station. |
| **Barnaby Puddleford** | Comic recurring caller. Fisherman with a small, unlucky boat called *The Optimist*. | Gets stuck on a sandbar, runs out of fuel, hooks a buoy, drifts out asleep. Always cheerful: "Just a little stuck again, Chief!" His calls are the game's light relief and its gentlest teaching calls. |

### 5.3 Townsfolk who call in

| Character | Where | What they bring |
|---|---|---|
| **Dr. Priya Osei** | Port Haven Cottage Hospital | The hospital delivery point. Gives medic tips and thanks the crew by name. |
| **Nell Tackle** | Bait shop on the pier | A 12-year-old who runs the challenge board (daily and weekly challenges). Big fan of Bosun. |
| **Hazel Crumb** | Ferry ticket booth | Radio gossip. Calls in the odd non-emergency (a cat on a buoy, a lost beach ball) that pays small and is pure charm. |
| **Captain Lou Marlow** | Ferry *Gale Queen* | The ferry captain. Centre of the capsized ferry big call. |
| **Coral Key Dive Shop (the Tran twins)** | Coral Reef | Snorkel tour calls, wildlife calls (turtle in a net). |
| **Skipper Ingrid Hale** | Trawler *Northern Dawn* | Open Sea and Iceberg North calls. Calm, precise radio voice. |

Voice lines are text plus short radio "crackle" sounds. No recorded dialogue at launch.

## 6. Season 1 arc: "Relight the Gales"

A light story told through Chief Aggie's radio, Tobias's lighthouse missions and Vance's interruptions. Each chapter is one lighthouse. Story never blocks play: a player can skip any cutscene, and the story missions are just special calls.

| Chapter | Beat | Unlocks | Scope |
|---|---|---|---|
| **0. Reopening Day** | First Mayday, first rescue, Bosun joins, the Chief hands over a radio. | Calm Bay calls | [MVP] |
| **1. Harbor Light** | Tobias needs a ride to the pier light. Relighting it is the player's Lifeguard promotion. | Crew joining; Coral Reef calls [L] | [MVP] |
| **2. Reef Light** | The reef light's lens is in pieces around Coral Key. Find and carry them back. Vance tries to sell the lens back to the town. | Reef wildlife and rock calls | [L] |
| **3. Gannet Rock Light** | A fog bank has swallowed the shipping lane. Relight the light in the fog so the ferry can find its way home. | Open Sea | [L] |
| **4. Tempest Point Light** | The tallest light, last to go dark. Relight it during a storm with a full crew (or Bosun, solo). | Storm Front | [L] |
| **Finale: The Long Storm Returns** | A scheduled, all-servers event. The biggest storm the isles have seen, a cruise ship aground, the ferry capsized, and Vance's yacht sinking. Every server works together toward one shared rescue count. | Season badge, a permanent finale livery for everyone who joins | [P1] |
| **5. Northlight** | Season 2 opener. Tobias's sister keeps a light in the ice. | Iceberg North | [P1] |

**Server-wide progress.** The finale shows a "Port Haven Rescues" total across all servers on the station board. This is a shared goal, never a race between players.

## 7. Tone rules

1. **Nobody dies, nobody is shown hurt.** Victims are "cold", "tired", "seasick", "bumped", or "stuck". There is no blood, no drowning animation, no bodies.
2. **The fail-safe always saves them.** If a call's timer runs out, an NPC lifeboat or a passing ferry "sweeps them away to the hospital". The player loses the payout, never the person. The radio says something kind ("Backup's got them. Next one's yours.").
3. **The player never dies either.** A capsized or swamped vehicle leaves the player bobbing in a life jacket with Bosun paddling over. They can right the boat or tap "Back to Station".
4. **Warm and a little funny.** Thank-you lines, Barnaby's mishaps, Bosun shaking himself dry, Vance's photo poses. Jokes are gentle and never at a victim's expense.
5. **Heroic, not military.** Ranks are rescue service ranks. No weapons anywhere in the game.
6. **Storms are exciting, not scary.** Big waves and lightning, bright rain-lit colours, rousing music. No horror sounds, no darkness that hides everything.
7. **Real rescue craft, simplified.** Throw a line, tow, hoist, first aid, follow a search pattern. Kids should come away knowing a little about real sea rescue (wear a life jacket, wave both arms, fire a flare).
8. **Plain words on screen.** Short labels a nine-year-old can read. Icons first, text second.

## 8. Signature features

| Feature | Why it matters | Scope |
|---|---|---|
| Mayday radio calls with a real search | The "find them" moment is what a fire game cannot do. Flares, radio bearings and Bosun's nose make searching a skill. | [MVP] flares, bearing, Bosun points; [L] binoculars, search patterns, drift |
| Server-wide storm every ~15 min (tune) | A shared clock everyone feels at once, with a burst of calls and rare big calls. Full storm waves at the harbor mouth put it in every first session. | [MVP] storm and harbor mouth, [L] big calls |
| Bosun the Newfoundland | A companion players love and screenshot. Helps solo players feel like a crew. | [MVP] follower who barks and points, [L] swims and tows |
| Four crew roles | Intentional co-play, which Roblox discovery rewards (see [`research/store-page-and-monetization.md`](research/store-page-and-monetization.md), section 5). | [MVP] simple crew join, [L] four roles |
| Rescue helicopter with hoist | The headline vehicle and the hero shot for the store page. | [MVP] tech spike only, [L] |
| Station helicopter ride-along | On big calls, low-rank players can take a seat in an NPC-flown station helicopter and work the hoist, so the hero vehicle shows up long before they can own it. | [L] |
| Lighthouses relit island by island | Visible, permanent progress on the map. | [MVP] Harbor Light, [L] four |
| Storm Summon (paid, server-wide) | A social "admin abuse" style event the whole server enjoys. | [L] |

## 9. Scope tags

Used in every design document.

| Tag | Meaning | Contents in short |
|---|---|---|
| **[MVP]** | The vertical slice we playtest first. | See section 9.1. |
| **[L]** | Public launch. | Everything deferred from the MVP (section 9.1), plus Open Sea and Storm Front, rescue board, lifeboat, helicopter, hoist, cliff and deck calls, all four roles, big storm calls with the station helicopter ride-along, all eight ranks and Service Stars, badges, daily and weekly challenges, leaderboards, game passes, Storm Summon. |
| **[P1]** | First post-launch update (about 4 to 6 weeks after launch). | Iceberg North, patrol cutter, hovercraft, Cruise Ship Aground big call, Season 1 finale event, drysuit, night calls with searchlights, more liveries. |
| **[P2]** | Later. | Station decoration, dog tricks, a second island town, seasonal events. |

### 9.1 MVP scope

The MVP proves one thing: a first session that ends with a storm rescue and a reason to come back. Anything not on the keep list waits for [L] unless tagged otherwise.

| Keep in the MVP | Defer |
|---|---|
| Port Haven and Calm Bay, with a storm-exposed harbor mouth | Coral Reef and the Reef Light lens hunt [L] |
| Jet ski (first vehicle, free) and RIB | Boat Fire and Seasick Passenger calls, first aid, comfort meter [L] |
| Three calls: Swimmer in Trouble, Drifting Craft, Disabled Boat (tow) | Binoculars, search patterns, victim drift [L] |
| A real storm: full cycle, big waves at the harbor mouth, rain, call burst | Radio Room, Kennel and the other station upgrades [L] |
| Bosun as a follower who barks and points | Most badges [L] |
| Three ranks: Recruit, Lifeguard, Rescue Swimmer | Throw-line mini-task [L] |
| Two or three gear items | Bosun swimming or towing [L] |
| Simple crew join (ride along, pull aboard, tow) | Rescue board, lifeboat, crew roles, big calls [L] |
| Mesh ocean only (no Terrain water) | Patrol cutter, hovercraft, Cruise Ship Aground [P1] |
| Helicopter as a tech spike only (not playable) | |

Exact MVP numbers (gear items, thresholds, prices) are in [document 03](03-progression.md); mechanics are in [document 02](02-core-loop-and-mechanics.md).

## 10. Glossary

| Term | Meaning |
|---|---|
| **Call** | One rescue job, started by a Mayday on the radio. |
| **Big call** | A rare storm-only call with many victims, built for several crews. |
| **Bay** | The player's own berth and locker at the station, where their vehicles and upgrades live. |
| **Cash** | Soft currency. Earned from calls, spent on vehicles, gear and station upgrades. Can be bought in packs. |
| **Reputation** | Rank XP. Earned only by playing. Never sold. |
| **Service Star** | An endless prestige level after Admiral. Each one pays a cosmetic. |
| **Harbor mouth** | The gap in the harbor wall. Sheltered in calm weather, full storm waves in a storm, with beginner storm calls. |
| **Outpost** | A small dock at Coral Key or Gannet Rock. Free delivery point for nearby calls. |
| **Ride-along** | A seat in the NPC station helicopter on a big call, offered to players below Rescue Pilot. |
| **Grade** | Gold, Silver or Bronze for each call, based on speed and care. |
| **Crew** | Up to four players sharing a vehicle and a call. |
