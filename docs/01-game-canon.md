# 01 · Game canon

This file is the single source of truth for **Mayday: Sea Rescue**. Every other design document expands one part of it. If another document disagrees with this one, this one wins until it is changed here first.

Numbers marked **(tune)** are starting values we expect to move after playtests. [Document 02](02-core-loop-and-mechanics.md) owns mechanics (including map scale and vehicle speeds), [document 09](09-rescue-operations.md) owns the rescue operations (steps, radio, grading, certifications, kit), [document 03](03-progression.md) owns progression numbers, [document 04](04-monetization.md) owns prices and [document 06](06-tools-and-pipeline.md) owns tech; where they differ from an anchor here, they win and this file is updated.

## 1. Identity

| | |
|---|---|
| **Working title** | Mayday: Sea Rescue |
| **Pitch** | Firefighting Sim, but on the ocean, with storms, and every rescue done the way real lifeboat crews do it. |
| **Fantasy** | Be the hero who saves people at sea. |
| **Platform** | Roblox (phone first, then PC, tablet, console) |
| **Genre** | Realistic rescue simulator: multi-step co-op rescue operations and a shared weather event |
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

1. **Every rescue is a real operation.** A rescue is a chain of real search-and-rescue steps (tasking, search, approach, recovery, casualty care, handover), and every step is a skill: steering, timing, positioning, choosing gear, reading the casualty. Never "go there, push a button, go there". Decisions have consequences, every step is graded, and the debrief says what to do better ([document 09](09-rescue-operations.md)).
2. **Mega realistic, never grim.** The sea, the boats, the kit, the radio and the procedures look and behave like the real thing ([document 05](05-art-direction.md) for the look). Failure shows as a casualty's condition dropping and another unit taking over, never as injury or death.
3. **Every operation is a hero moment.** It ends with a casualty handed over safe and someone saying thank you. A new player finishes their first rescue inside 3 minutes of joining; a standard operation takes about 4 to 7 minutes (tune).
4. **The sea is the opponent.** Wind, waves, tide, fog and storms make rescues hard. Other players never do. There is no PvP and no way to hurt another player's run.
5. **Better together, fine alone.** Crew roles (Helm, Navigator/Radio, Crew/Swimmer, Medic, later Winch Operator and Pilot) make co-op operations faster and better graded. NPC crew fill empty seats, slower and less precise, so a solo player can do every operation.
6. **Light the way home.** Progress is visible in the world: the station comes back to life, lighthouses relight one by one, certificates show on the nameplate, and the player's boats and helicopter sit in their bay.

## 3. What Mayday is not

- Not a roleplay game with no goals. It has calls, payouts, ranks and a clear next step at all times.
- Not a MilSim. No military ranks to apply for, no group required. Training exercises exist but are short, optional and solo-friendly.
- Not grim. Realistic does not mean scary: nobody drowns, nobody is hurt on screen, nothing frightens a young child.
- Not an arcade fetch quest. No "hold E to rescue": every rescue is played step by step.
- Not a loot-box game at launch. No paid random items.
- Not pay-to-rank. Rank and Reputation can never be bought.

## 4. Setting: Port Haven and the Gale Isles

**The Gale Isles** are a chain of green, rocky islands in a cold North Atlantic sea, drawn as realistically as Roblox allows ([document 05](05-art-direction.md)). The weather turns fast. Fishermen, ferries, tourists, surfers and the occasional cruise ship all share the water.

**Port Haven** is the main town: a crescent harbor, painted houses up the hill, a fish market, a bait shop, a ferry pier, the Cottage Hospital, and at the end of the harbor wall, the old **Port Haven Coast Guard Station**.

**The Long Storm.** Years ago a storm sat over the isles for a whole season. The station was damaged, its crews moved away, and one by one the lighthouses went dark. Without the station, the town has made do with Vance Sterling's private salvage boats, which charge a fortune and arrive late.

**The player's arrival.** The game opens on the day Chief Aggie Brightwater reopens the station with one recruit (the player), one jet ski and one very large dog. The player runs one quick drill with the Chief and answers the first Mayday before the paint is dry.

### 4.1 Zones

| Zone | Lighthouse | Feel | Main hazards | Scope |
|---|---|---|---|---|
| **Calm Bay** | Harbor Light | Sheltered harbor, beaches, sandbars, swimmers and paddleboards | Rip currents, sandbars | [MVP] |
| **The Skerries** | Skerry Light on Skerry Isle | Cold, rocky skerries and kelp beds, sea caves, grey seals, dive and kayak tours. Opens at Lifeguard. | Rocky ledges just under the surface (hull scrapes), kelp that fouls propellers, tide races in tight channels | [L] |
| **Open Sea** | Gannet Rock Light | Deep blue swell, fishing trawlers, ferry lanes, fog banks | Big swell, fog, long distances | [L] |
| **Storm Front** | Tempest Point Light | Dark water, sea cliffs, permanent rough weather, wrecks | Huge waves, gusts, lightning, cliffs | [L] |
| **Iceberg North** | Northlight | Pale water, ice floes, research station, seals | Ice, cold (needs drysuit), drifting bergs | [P1] |

Zones are rings outward from Port Haven (map scale in [document 02](02-core-loop-and-mechanics.md), section 4.1). Calm Bay sits inside the harbor wall and stays sheltered even during storms, so a new player's first call is never in a storm. The **harbor mouth**, the gap in the harbor wall a short ride from the station, is the exception: it takes full storm waves and gets beginner storm calls, so a player sees the hook (a real storm rescue) in their first session without leaving the harbor. Skerry Isle and Gannet Rock have **outposts** with free delivery docks, so long trips stay short.

## 5. Characters

### 5.1 The station

| Character | Role | Personality |
|---|---|---|
| **Chief Agnes "Aggie" Brightwater** | Station chief. Runs training exercises, signs off certifications, gives rank promotions, story beats and debrief tips. | Retired lifeboat coxswain who came back to reopen the station. Warm, dry, never flustered. Always holding a mug of cocoa. Catchphrase: "Kettle's on. Go get them." |
| **Bosun** | The player's Newfoundland rescue dog. Every player gets one free on their first call. | Huge, fluffy, brave, slightly clumsy on land and graceful in water. Barks toward victims, swims a line out to swimmers, shakes water over everyone at the dock. Players can rename him. |
| **Gale Isles Coastguard** | The coordination centre (invented) that tasks every rescue over the radio: MAYDAY and PAN-PAN taskings, situation reports, the helicopter *Rescue Gale One*, stand-downs. | Calm, precise, unhurried voice. Never jokes during a tasking; says "good work" at the stand-down. |
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
| **Skerries Dive Shop (the Tran twins)** | The Skerries | Dive and kayak tour calls, wildlife calls (a seal in a net). |
| **Skipper Ingrid Hale** | Trawler *Northern Dawn* | Open Sea and Iceberg North calls. Calm, precise radio voice. |

Voice lines are text plus short radio "crackle" sounds by default. Optional recorded voice lines for the Coastguard, Chief Aggie and the player's radio replies are [L] ([document 09](09-rescue-operations.md), section 3.5).

## 6. Season 1 arc: "Relight the Gales"

A light story told through Chief Aggie's radio, Tobias's lighthouse missions and Vance's interruptions. Each chapter is one lighthouse. Story never blocks play: a player can skip any cutscene, and the story missions are just special calls.

| Chapter | Beat | Unlocks | Scope |
|---|---|---|---|
| **0. Reopening Day** | A throw-bag drill with the Chief, the first MAYDAY from Gale Isles Coastguard, the first rescue, Bosun joins. | Calm Bay calls | [MVP] |
| **1. Harbor Light** | Tobias needs a ride to the pier light. Relighting it is the player's Lifeguard promotion. | Crew joining; Skerries calls [L] | [MVP] |
| **2. Skerry Light** | The Skerry light's lens is in pieces around Skerry Isle. Find and carry them back. Vance tries to sell the lens back to the town. | Reef wildlife and rock calls | [L] |
| **3. Gannet Rock Light** | A fog bank has swallowed the shipping lane. Relight the light in the fog so the ferry can find its way home. | Open Sea | [L] |
| **4. Tempest Point Light** | The tallest light, last to go dark. Relight it during a storm with a full crew (or Bosun, solo). | Storm Front | [L] |
| **Finale: The Long Storm Returns** | A scheduled, all-servers event. The biggest storm the isles have seen, a cruise ship aground, the ferry capsized, and Vance's yacht sinking. Every server works together toward one shared rescue count. | Season badge, a permanent finale livery for everyone who joins | [P1] |
| **5. Northlight** | Season 2 opener. Tobias's sister keeps a light in the ice. | Iceberg North | [P1] |

**Server-wide progress.** The finale shows a "Port Haven Rescues" total across all servers on the station board. This is a shared goal, never a race between players.

## 7. Tone rules

1. **Nobody dies, nobody is shown hurt.** Casualties can be cold, very cold (hypothermic), exhausted, panicking, seasick, bumped or not responding, shown through realistic body language and a condition meter. There is no blood, no injury close-up, no drowning animation, no bodies. CPR is shown from a calm, high camera with a rhythm bar, and always ends with the casualty breathing or paramedics taking over.
2. **The fail-safe always saves them.** If a casualty's condition reaches Critical, the harbour patrol or the Coastguard helicopter takes over and the casualty is safe. The player keeps the steps already earned (at a reduced rate), never loses the person, and the radio says something kind ("*Rescue Gale One* has them. Good work holding on.").
3. **The player never dies either.** A capsized or swamped vehicle leaves the player bobbing in a life jacket with Bosun paddling over. They can right the boat or tap "Back to Station".
4. **Warm and a little funny.** Thank-you lines, Barnaby's mishaps, Bosun shaking himself dry, Vance's photo poses. Jokes are gentle and never at a victim's expense.
5. **Heroic, not military.** Ranks are rescue service ranks. No weapons anywhere in the game.
6. **Storms are exciting, not scary.** Big waves and lightning, bright rain-lit colours, rousing music. No horror sounds, no darkness that hides everything.
7. **Real rescue craft, done the real way.** Approach from downwind, throw the bag beyond the casualty, keep a cold casualty flat, give an ATMIST handover, take the strain gently on a tow. Physics and numbers are simplified; procedure never is. Anything not yet checked against an official source is marked "(verify)" in [document 09](09-rescue-operations.md). Players should come away knowing real sea safety (wear a lifejacket, float to live, wave both arms, call the Coastguard).
8. **Plain words on screen.** Short labels a nine-year-old can read. Icons first, text second.

## 8. Signature features

| Feature | Why it matters | Scope |
|---|---|---|
| Realistic multi-step rescue operations | The core: every rescue is a chain of real procedure steps, each a skill, graded and debriefed ([document 09](09-rescue-operations.md)). | [MVP] Person in the Water, Disabled Vessel, Capsized Ferry; [L] sinking, fire, winch, beach, cliff; [P1] medevac |
| A real radio | MAYDAY and PAN-PAN taskings from Gale Isles Coastguard, answered on a quick-reply radio wheel: acknowledgement, ETA, POB, sitreps, handover. | [MVP] wheel; [L] optional voice lines |
| Certifications | Helm, Casualty Care, Rescue Swimmer, Coxswain, Winch Operator, Pilot: earned in exercises and operations, gating roles and vehicles. | [MVP] first three; [L] the rest |
| Mayday radio calls with a real search | The "find them" moment is what a fire game cannot do. Flares, radio bearings and Bosun's nose make searching a skill. | [MVP] datum and drift, lookout, flares and strobes, bearing, Bosun points; [L] binoculars, expanding square |
| Server-wide storm every ~15 min (tune) | A shared clock everyone feels at once, with a burst of calls and rare big calls. Full storm waves at the harbor mouth put it in every first session. | [MVP] storm and harbor mouth, [L] big calls |
| Bosun the Newfoundland | A companion players love and screenshot. Helps solo players feel like a crew. | [MVP] follower who barks and points, [L] swims and tows |
| Crew roles with NPC fill-in | Intentional co-play, which Roblox discovery rewards (see [`research/store-page-and-monetization.md`](research/store-page-and-monetization.md), section 5). | [MVP] Helm, Navigator/Radio, Crew/Swimmer, Medic with NPC fill-in; ride-along Winch Operator and Winchman; [L] Pilot |
| Rescue helicopter with hoist | The headline vehicle and the hero shot for the store page. | [MVP] tech spike only, [L] |
| Station helicopter ride-along | On big calls, low-rank players can take a seat in the NPC-flown Coastguard helicopter as trainee Winch Operator or Winchman, so the hero vehicle shows up long before they can own it. | [MVP] on the Capsized Ferry if the helicopter spike is ready, else [L] |
| Lighthouses relit island by island | Visible, permanent progress on the map. | [MVP] Harbor Light, [L] four |
| Storm Summon (paid, server-wide) | A social "admin abuse" style event the whole server enjoys. | [L] |

## 9. Scope tags

Used in every design document.

| Tag | Meaning | Contents in short |
|---|---|---|
| **[MVP]** | The vertical slice we playtest first. | See section 9.1. |
| **[L]** | Public launch. | Everything deferred from the MVP (section 9.1), plus Open Sea and Storm Front, rescue board, lifeboat, player helicopter and the Pilot role, sinking, fire, winch, rip-current and cliff operations, Coxswain, Winch Operator and Pilot certifications, Trawler on the Rocks, all eight ranks and Service Stars, badges, daily and weekly challenges, leaderboards, game passes, Storm Summon. |
| **[P1]** | First post-launch update (about 4 to 6 weeks after launch). | Iceberg North, medical evacuation from a ship, night searches, patrol cutter, hovercraft, Cruise Ship Aground big call, Season 1 finale event, drysuit, night calls with searchlights, more liveries. |
| **[P2]** | Later. | Station decoration, dog tricks, a second island town, seasonal events. |

### 9.1 MVP scope

The MVP proves one thing: a first session of real, step-by-step rescue operations that ends with a storm rescue and a reason to come back. Three operations, built deep rather than many built shallow ([document 09](09-rescue-operations.md)). Anything not on the keep list waits for [L] unless tagged otherwise.

| Keep in the MVP | Defer |
|---|---|
| Port Haven and Calm Bay, with a storm-exposed harbor mouth | The Skerries and the Skerry Light lens hunt [L] |
| Jet ski with rescue sled (first vehicle, free) and RIB | Sinking, fire, winch, rip-current and cliff operations [L]; medevac from a ship [P1] |
| **Person in the Water**: tasking, datum and drift search, downwind approach, throw bag, swimmer, horizontal lift, panicking casualty, DR ABCDE survey, treatment, CPR (gated), transport, ATMIST handover | Expanding square and sector search patterns [L] |
| **Disabled Vessel**: assessment, heaving line, tow line and bridle, tension and snatch loads, alongside tow, berthing | The two-casualty Drifting Craft variant and Person Overboard from a ferry [L] |
| **Capsized Ferry** storm big call (co-op): scene command, triage tags, hull knocking, air-pocket dive, multi-boat coordination; NPC-flown helicopter ride-along if the spike is ready | Trawler on the Rocks [L], Cruise Ship Aground [P1] |
| Radio wheel with Gale Isles Coastguard taskings, ETA, POB and handover | Optional voice lines [L] |
| Crew roles Helm, Navigator/Radio, Crew/Swimmer, Medic, with NPC crew filling empty seats | Player-flown helicopter and the Pilot role [L] |
| Per-step grading and the debrief screen; Assist and Pro settings | AED, oxygen variants beyond one mask [L] |
| Reopening Day drill and the Helm, Casualty Care and Rescue Swimmer exercises and certifications | Coxswain, Winch Operator and Pilot certifications [L] |
| A real storm: full cycle, big waves at the harbor mouth, rain, tasking burst | Radio Room, Kennel and the other station upgrades [L] |
| Bosun as a follower who barks and points | Most badges [L]; Bosun swimming or towing [L] |
| Three ranks: Recruit, Lifeguard, Rescue Swimmer | Binoculars [L] |
| Two or three gear items | Patrol cutter, hovercraft [P1] |
| Mesh ocean only (no Terrain water) | |
| Helicopter as a tech spike, flown only by NPC on the ferry call | |

Exact MVP numbers (gear items, thresholds, prices) are in [document 03](03-progression.md); mechanics are in [document 02](02-core-loop-and-mechanics.md).

## 10. Glossary

| Term | Meaning |
|---|---|
| **Operation** | One rescue, played as a chain of real procedure steps from tasking to handover ([document 09](09-rescue-operations.md)). Older text says "call"; it means the same. |
| **Step** | One part of an operation (search, approach, recovery, survey...), each a skill with its own grade. |
| **Tasking** | The radio message from Gale Isles Coastguard that starts an operation. |
| **Big call** | A rare storm-only operation with many casualties, built for several crews (the Capsized Ferry). |
| **Bay** | The player's own berth and locker at the station, where their vehicles and upgrades live. |
| **Casualty** | A person being rescued. |
| **Condition** | A casualty's 0 to 100 meter (Stable, Concern, Serious, Critical). Critical brings in another unit to take over. |
| **Certification** | A role qualification (Helm, Casualty Care, Rescue Swimmer, Coxswain, Winch Operator, Pilot), earned in exercises and operations, never sold. |
| **Exercise** | A short training drill with Chief Aggie and the manikin, the first half of a certification. |
| **Assist / Pro** | Operation setting: Assist shows overlays and hints; Pro shows only real cues and pays more Rep. |
| **Datum** | The last known position of a casualty, the start of a search. |
| **POB** | Persons on board, reported on the radio. |
| **ATMIST** | The handover report: Age, Time, Mechanism, Injuries, Signs, Treatment. |
| **OSC** | On Scene Coordinator, the player who commands a big call. |
| **Debrief** | The screen after an operation: step grades, condition graph, Rep and one tip. |
| **Cash** | Soft currency. Earned from operations, spent on vehicles, gear and station upgrades. Can be bought in packs. |
| **Reputation** | Rank XP. Earned only by playing. Never sold. |
| **Service Star** | An endless prestige level after Admiral. Each one pays a cosmetic. |
| **Harbor mouth** | The gap in the harbor wall. Sheltered in calm weather, full storm waves in a storm, with beginner storm calls. |
| **Outpost** | A small dock at Skerry Isle or Gannet Rock. Free handover point for nearby operations. |
| **Ride-along** | A trainee seat (Winch Operator or Winchman) in the NPC-flown Coastguard helicopter on a big call, offered to players below Rescue Pilot. |
| **Grade** | Gold, Silver or Bronze for each step and for the whole operation, based mostly on care and technique, a little on speed. |
| **Crew** | Up to four players sharing a vehicle and a call. |
