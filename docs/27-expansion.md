# 27 · Expansion: sea plates, the era ladder and the Deep (proposal, 2026-10-29)

Owner: "after 10ish minutes [I want] to be able to extend your island forward to have better stuff and so on to go
far into futuristic stuff, like a crazy plot twist go to the bottoms of the sea and fight monsters and so on. Or IDK
automate the whole world, build cyborgs, smth crazy."

Status: **proposal, needs the owner's OK** (questions in section 6). Rules that still hold: CLAUDE.md (no choice UI in
gameplay, show don't tell, Lego style for new things, walk-in buildings with something to do, no sparkle on
buildings, no flashing orange, one companion), docs/00, docs/25 J/K, docs/26 (VFX). Coordinates with work in flight:
ECON1 (tree ~15-17 h, early goals a few rescues each), conveyor belts, idle-worker leisure, fuller sea, later quests,
walk-in actions.

**In one line:** your island grows out to sea in Lego **sea plates** (the first at ~10 min). Each plate carries the
next era's buildings: Harbour → Modern → Tide-Tech. Halfway up the ladder a crack opens in the lagoon: the sub
goes down to the **Deep**, a sunken Lego city whose broken engine causes every storm and mayday. Its salvage powers the
future island (robot crews, drones, exo-suits), and those let you go deeper.

## 1. Sea plates: the island grows forward

**What:** one Lego baseplate section on brick pillars, bolted to the island's sea side. It is a building like any
other, so it costs nothing new to support: each plate is **a `DockConfig.Buildings` row** (`SeaPlate1..SeaPlate8`, one
level each) with `needs` chaining them (`SeaPlate2` needs `SeaPlate1`, ...) and an `hq` gate. Buildings that stand on
a plate list it in `needs`. UnlockTree, the build tablet card (camera focus on its water lot), BuildTimer, Depot loads,
Robux-skips-Cash, NextGoal and saves (`data.dock.levels.SeaPlate1 = 1`) all work as they do today. **No migration.**

**Geometry (RingLayout, `WorldConfig.Ring`):** plate centres sit 470 out, edge ±160, so the sea-side edge is 630 from
the ring centre. Toward the sea the 60° wedge widens: half-room to the bisector is `0.577 × d`, which is 364 at d =
630 and 520 at d = 900. Plates only grow **outward** and never toward a neighbour or a bridge (bridges are behind,
at 400 out). The berth channel stays clear down the middle, ≥ 70 studs wide, straight to open sea.

```
                 open sea (calls 1-2 move out to the outermost plate + 80)
        +--------+                                  +--------+
        |  P7    |   Tide-Tech row   d 820-900      |  P8    |  <- Deep Lock
        +--------+--------+            +--------+---+--------+
        |  P5    |  P3    |  channel   |  P4    |  P6    |    Modern row  d 726-820
        +--------+--------+   >=70     +--------+--------+
        |  P1 Ramp Wharf  |  (berth)   |  P2 Freight Wharf |  Harbour row d 630-726
  ======+=================+==[ cove ]==+===================+======  island front edge (d 630)
        quest pontoon moves to P1's outer-left corner (RingLayout.QUEST_PONTOON reads the outermost left plate)
```

- Section size 96 deep × 120-128 wide (P1/P2 hug the cove; P5/P6 sit beside P3/P4). Deck at plate height (Y 4),
  pillars to the seabed (Y -40), so boats can't pass under (the channel is the way out).
- Hard limits (one new spec, `tests/SeaPlates.spec.luau`): every plate rect ≥ 40 studs from the 30° bisectors, ≤ 900
  from the centre, ≥ 120 from every outer island, wreck and call site. **Check first: the ferry sits 1,000 S of the
  centre**, so the island facing south ends 100 short of it. Move the ferry to 1,250 if the spec says so.
- **Part budget:** each plate is 1 MeshPart deck (stud texture, one material) + 1 rim mesh + ≤ 6 pillar MeshParts +
  2 bollard/lamp rows = ≤ 12 parts, so 8 plates ≈ 100 parts. Buildings on plates follow the docs/25 per-building
  budget (layered Blender mesh, ≤ 120 parts with collision). Target: a maxed island with every plate ≤ 2,500 parts,
  a full server ≤ 15k. The island model streams as Atomic, the same as today.

**Build moment (`plate_drop`, docs/26: job = spectacle/reward, ~3 s):** while the timed build runs, the crew works on a
floating Lego scaffold barge and the pillars rise from the water brick by brick with progress (BuildSeq order, splash
rings at each pillar foot). At the finish: *anticipation* (0.5 s): a crane hook lowers the deck from above as its
shadow grows on the water. *Impact*: one big stud-snap "CLICK", a water ring bursts out from every pillar, a small camera kick
(off with reduce-motion), gulls lift off. *Settle* (1 s): rim bricks pop in around the edge left to right, then
bollards and lamps drop in with the BuildSeq bounce. Sound: brick rattle → deep snap → splash → seagulls. It never
sparkles (owner rule). Fired by name through VFXKit, tested on the DEV `vfx plate_drop` bench, art director 8.5+.

**Cost and time (ECON1 numbers; tune in `tests/NewPlayerPace` and `tests/Pacing`):**

| Plate | Era | Gate | Cash | Build T (BuildTimer) | Lands at (sim target) | What it enables |
|---|---|---|---|---|---|---|
| P1 Ramp Wharf | Harbour | HQ1 + Workshop | 1,500 (≈3 early rescues) | ~29 s | **8-14 min** | jet ski **jump ramp** off the end (a toy at once), 1 lot (Fish Market pier stalls move here at Lv2), quest pontoon moves here |
| P2 Freight Wharf | Harbour | HQ2 + Depot | 6,000 | ~100 s | ~40 min | 2nd barge mooring: Depot refill ×1.5 (bricks are a real limit, docs/25 J), conveyor end (with the conveyor work) |
| P3 Air Deck | Modern | HQ4 | 45,000 | 600 s (cap) | ~9 h | 2nd helipad (a friend lands too), radar mast: call pins +300 reach |
| P4 Sub Lock | Modern | HQ5 + Sub Pen Lv3 | 90,000 | 600 s | ~15 h | the sub lock basin; fits the **pressure hull** to the sub (Deep entry, Update 2) |
| P5 Robo Works plate | Tide-Tech | HQ6 | 140k + Metal | 600 s | Update 3 | lot for Robo Works |
| P6 Drone plate | Tide-Tech | HQ6 | 160k + Metal | 600 s | Update 3 | lot for the Drone Tower |
| P7 Hover Dock | Tide-Tech | HQ7 | 220k + Cores | 600 s | Update 3 | hover lifeboat berth |
| P8 Deep Lock | Tide-Tech | HQ7 | 260k + Cores | 600 s | Update 3 | Deep Sub Lv2 (deeper zone) |

P1/P2 add ~7.5k to the launch tree (minutes, not hours). P3/P4 are the **late rows docs/23 (r) said were missing**:
they take the tree from ~15 h to ~17 h without longer gaps, so ECON1 should own their prices. Robux skip per plate follows the
docs/23 (i) rule (R$ ≥ 1.3× the pack value of the Cash); plates are never Robux-only.

**Next chip and tutorial:** put `SeaPlate1` right after `Workshop` in `DockConfig.BUILDINGS` so NextGoal offers it
as soon as you can afford it. No new tutorial beat; the chip, the card focus and the ramp do the teaching.

## 2. The era ladder

The HQ stays the spine (docs/25 A): **HQ6 and HQ7 are new levels** on the same row (add-on wings, never a reshape).
An era is a look and a set of rows, not a mode. Old buildings keep their models, and new eras add plates beside them.

| | Harbour (HQ1-3, 0-5 h) | Modern (HQ4-5, 5-17 h) | Tide-Tech (HQ6-7, updates) |
|---|---|---|---|
| Look | red/white/blue bricks, timber wharves, bunting | grey + coastguard orange, steel pillars, radar, cranes | white + teal trans bricks, rounded tiles, rails; lights only as windows at night (no glow FX) |
| Craft | jet ski, RIB, Lifeboat | Helicopter, Submarine, Robux boats | Deep Sub (pressure hull + lamp + claw), hover lifeboat (skims rocks and shallows) |
| Crew | survivors: Builder, Hauler, Fisher, Mechanic, Medic, Rescuer | + Pilots, Divers (docs/25 Update 2) | **exo-suits**: any worker at Robo Works gets a Lego mech suit (×1.5 work, chunky walk); **Bolt-bots** (robot workers made from Metal, rarity-less, no Bunkhouse slot, max 6) |
| Automation | barge, Haulers | conveyors (in flight), Rescuer NPC boats | **Drone Tower**: drones fly the swimmer calls within 600 studs of home by themselves (50% pay, never golden calls) |
| Materials | Bricks | + Planks, Stone (Update 1) | + Metal (wreck salvage), **Tide Cores** (the Deep) |

Automation never replaces the player. Drones take only nearby swimmer calls, pay half and skip golden ones, so you
still sail out to get the best calls. Bots and suits are bought with Cash plus materials, never with Robux alone.

## 3. The twist: three options

**A. The Deep.** A crack opens in the centre lagoon (shared by all 6 islands). Through it is **Brinehold**, a sunken
Lego city. Its **Tide Engine** is broken, and that is why the storms and maydays happen. Down there you rescue trapped
divers in air-bubble domes (drive close → they board, the same simple rescue), and nothing is ever killed:
- **Murklings** (ink-cloud critters drifting toward a dome): hold the sub's lamp on one for 1.5 s and it pops into
  a school of friendly glowfish.
- **Crab Tanks** (sit on wreck hatches): ram their shell to flip them. They scuttle off and the hatch opens (salvage).
- **The Leviathan** (a server event every ~20 min, co-op): a Lego sea serpent tangled in the engine's cables. Grab
  the glowing knots with the claw and back away (hold). When every knot is off it swims a lap round the ring, and every
  helper gets Cores and a trophy.
Calls never fail: a Murkling reaching a dome only lowers the grade. Fun: high, and it is the "crazy twist" and the hook for the update.
Scope: large (a new zone, lighting below Y -60, 3 creature rigs). Risk: the underwater look (the Part sea, fog),
perf at depth, and creatures reading as scary (keep them round and cute).

**B. Automation.** Robo Works, exo-suit crews, drone fleets and conveyor belts until the island runs itself while
you sail farther. Fun: medium (idle-tycoon payoff, good flex). Scope: medium, since it reuses WorkerRules, the Rescuer
NPC boat, WorkLoop and conveyors. Risk: it competes with the core loop (why rescue if drones do it?) and invites
pay-to-win pressure (buying bots).

**C. Blend (recommended).** The Deep is the adventure and the twist; automation is how the island pays off. **Tide
Cores from the Deep power the Tide-Tech island**, and its exo-suits, drones and Deep Sub Lv2 take you deeper.
Two pillars feed each other (explore ↔ tycoon) and friends meet in the shared crack in the lagoon. The finale (later update): fix the
Tide Engine as a server-wide co-op build, and the ring's sea turns clear and calm, with a new sky and a statue on every island.

| | Fun | Scope (agent-days) | Risk | Monetization (no pay-to-win) |
|---|---|---|---|---|
| A Deep | ★★★ | ~15 | look/perf below the surface | sub skins, lamp colours, Deep wake trails |
| B Automation | ★★ | ~10 | eats the core loop | bot/suit paint, drone skins |
| **C Blend** | ★★★ | ~25 over 2 updates | the two above, in sequence | all of the above + plate themes (Coral, Chrome, Neon decks), Robo-Bosun **variant** (still one companion), Deep cosmetics as wheel prizes |

Paid things stay cosmetic or skip Cash (never order, never skill). No Deep-only pass. Spin wheel prizes add
Deep finishes and pet variants (Abyss Otter), with odds shown as today.

**The mystery is seeded from launch** (no text; the world tells it):
1. A teal brick washes up on P1's edge after the first plate. Tap it and it goes to the Trophy Hall (a "?" plinth).
2. From HQ4 the sub's sonar pings at the lagoon centre, and the camera nudges there once.
3. From HQ5 (Update 1) there's a steady teal light under the lagoon water at night, and storms track out of it on the map.
4. Update 2: the crack opens in a server-wide moment (the water spirals and parts like Lego plates sliding apart), and
   a marine scientist NPC sails in with a quest chain (NPC talk: the allowed zoom + numbered replies).

## 4. Walk-in buildings (something to do in each)

- **Ramp Wharf (P1):** a timber kiosk with lifebuoys on the walls. Ride the jet ski off the ramp and your best jump
  height shows on a board (counter, allowed).
- **Freight Wharf (P2):** a walk-through crane cab. Stand at the lever and hold it to swing the crane: one barge
  unloads 20% faster (an action, not a menu).
- **Sub Lock (P4):** walk the lock walls and pull the big lever. The lock floods while your sub sinks and the gates open.
- **Robo Works:** the fitting rig is in view. Step on the pad yourself to try a suit for a 10 s stomp (a jump boost).
- **Drone Tower:** stairs up to the deck. Drones launch past you, and the board counts their rescues today.
- **Brinehold dome:** a walk-in air dome on the Deep floor. Divers wait inside and you can get out of the sub and walk
  round (an air pocket; the swim rules apply outside).

## 5. Phased plan

Agent-days = Opus builder days, review included. Assets go through the Blender MCP pipeline (art/bench/PROD_BRIEF:
.blend + build.py, LODs, `zfight_check.py`, AD > 8, Sonnet → Opus escalation). Everything is data rows plus specs, so
saves stay compatible: new rows default to "not built" and new `data` keys default in `ProgressionRules`.

**Slice 0: launch-sized, ~4 agent-days (ships in days).**
- Systems: `DockConfig` rows SeaPlate1/2 (+ order); `RingLayout` plate rects + moved quest pontoon + calls 1-2 spawn
  offset; `tests/SeaPlates.spec.luau` (geometry above) and the ZFight spec covering plates; pillars rise with
  `BuildSeq` progress; `plate_drop` in VFXKit + sound; P1 jump ramp (one wedge + a counter); P2 2nd barge
  mooring (`DepotRules.bargeLoads` × 1.5 with `SeaPlate2`); seed 1 (the teal brick).
- Assets (Lego, Blender MCP): plate deck + rim + pillar kit (1 asset, reused 8×), the ramp, the kiosk, the crane cab.
  Code uses placeholder Parts until they land.
- Telemetry: one new funnel `Expand` = {CardSeen, Bought, Built, Used} (Used = first ramp jump / first P2 barge), so
  7 of the 10 funnels are used (onboarding + 5 today; `Deep` and `Automate` later make 9). Custom `PlateBuilt` (index, minutes-played bucket).
- Done when NewPlayerPace puts P1 between 8 and 14 min, check.sh passes, an Opus Studio playtest has a fresh save
  reach P1, and the AD scores the plate drop 8.5+.

Slice 0 status (2026-10-29, EXPAND1, branch `t3/c7f27af7`): rows SeaPlate1/2 (`DockConfig.SEA_PLATE_CASH` 1,500 /
6,000, R$ 15 / 35 products with id 0 until deploy.py creates them), Part placeholder decks on pillars (layered rise),
`plate_drop` + `ramp_jump` presets, the ramp (no counter: free toy), the quest pontoon shift, the second barge
(`DepotRules.WHARF_MULT`), the `Expand` funnel + `PlateBuilt`, seed 1 (teal brick -> a "?" Trophy Hall cup). The
plates join the HQ gate (HQ2 needs P1, HQ3 needs P2). Pacing: P1 at 13.8 min, P2 ~1:45-2:20. Open: Blender assets
(deck/rim/pillar kit, ramp, kiosk, crane cab), the crane-cab lever, AD score of plate_drop, ECON1 prices.

**Update 1 "Outer Wharves", ~8 agent-days (+ docs/25 D Timber & Stone, already planned).**
- Systems: SeaPlate3/4 rows (late Cash sinks; ECON1 retunes them to ~17 h); radar reach in `CallTypes` reach; 2nd helipad
  in AirStation spawn spots; the Sub Lock lever + pressure-hull flag (`data.vehicles.DeepSub`, inert until Update 2);
  seeds 2-3.
- Assets: Air Deck + radar mast, Sub Lock basin + lever, a teal light under the lagoon.
- Funnel `Expand` keeps counting; tree spec asserts the full tree is ≤ 17 h ± 15%.

**Update 2 "The Deep", ~15 agent-days (the twist; the marketing beat).**
- Systems: Rift shaft in the lagoon + the Brinehold zone 1 (Y -80 to -250, depth lighting blend on the client);
  Deep calls in `Calls` (dome rescue, Murkling defence, Crab hatch salvage); sub lamp-hold + claw-pull actions (on
  the Deep Sub; keyboard / touch / gamepad glyphs); Leviathan server event (co-op, ~20 min); `TideCores` as a Depot
  material (`data.depot.cores`); HQ6 row level; Divers (docs/25 Update 2); the scientist's quest chain; seed 4.
- Assets: Brinehold set (6-8 modular Lego ruins + dome), Murkling / Crab Tank / Leviathan rigs (cute, rounded),
  Deep Sub add-on (hull, lamp, claw), glowfish flipbook.
- Telemetry funnel `Deep` = {RiftSeen, Dived, DomeRescue, CoreBanked}; custom `LeviathanFreed` (helpers count).
- Skill tree: a "Deep" outer ring on the Rescue sector (Lamp range, Claw grip, Dive time), using the docs/25 J "soon" teasers.

**Update 3 "Tide-Tech", ~12 agent-days.**
- Systems: SeaPlate5-8 rows; HQ7; Robo Works (suit flag on a worker, `WorkerRules` ×1.5); Bolt-bots (worker
  entries with `Category = "Bot"`, outside the Bunkhouse cap, max 6); Drone Tower (an auto-rescue loop on the
  Rescuer NPC boat code, swimmer calls ≤ 600 studs, 50% pay); hover lifeboat; Deep zone 2 (Deep Lock).
- Assets: Robo Works, Drone Tower + drone, exo-suit, Bolt-bot, hover lifeboat, HQ6/HQ7 add-ons.
- Funnel `Automate` = {SuitFitted, BotBuilt, DroneRescue}. The finale (Tide Engine repair) is the next update's headline.

## 6. Open questions for the owner

1. Direction **C** (Deep first in Update 2, automation in Update 3)? Or do you want automation sooner?
2. Is "fight" OK as **calm / flip / untangle** (nothing dies, monsters turn friendly)? Or do you want sub "blasters"
   that knock them out (still kid-safe, more shooter-like)?
3. Tide-Tech look: is a steady teal light strip on future buildings OK, or does it break "no building ever glows"?
4. Is a shared crack in the centre lagoon OK? (It puts the friends pillar at the heart of the ring. The other choice
   is a private gate on every island's P8, which has fewer meetings and costs more parts.)
5. Should the P1 ramp be a free toy, or should jump height feed a leaderboard/badge?

## 7. Owner decisions (2026-10-29)

1. **Direction C** (the Deep + Tide-Tech automation blend), as proposed.
2. **Sub blasters**: the Deep has real sub combat. The submarine knocks monsters out with blasters. Keep it kid-safe: knocked out, not killed, with no gore. The calm/flip/untangle actions can stay as extra moves.
3. **Steady teal light strip OK** on Tide-Tech (future-era) buildings only. It stays calm and steady, never flashing or pulsing. Every other building still never glows.
4. **A private Deep gate on every island**, not a shared centre crack. Each island's outermost sea plate holds its own gate.
5. Not answered: the P1 ramp is a free toy for now, with no leaderboard.
