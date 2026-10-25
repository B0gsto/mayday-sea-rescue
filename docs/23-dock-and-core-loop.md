# 23 · Your dock and the core loop

2026-10-25. Owner: "the core game loop feels bad ... the player does not need to go too far to get the survivors,
on boat I don't get how can we save someone. The land itself is a mess and I don't know why a player needs to go
on land. On multiple players if 2 or more spawn a boat then it overlaps. I think each player needs a dock."
Then: "start first with no walls, nothing, just a simple dock and a jet ski; further down the line a garage for
cars + garage for planes/helicopters + submarines, so that we don't need to use the phone so much, we have
everything in the dock." And: "you can buy everything with Robux when you don't have Cash/rank."

This chapter wins over docs/04 §1.1 and rule 4 (where things are sold, rank-gated paid vehicles), over the
"all UI on the phone" direction for vehicles and upgrades, and over docs/archive/20-clarity-redesign.md change 5 (spawn at the shared bays).
Rules kept: no choice UI in gameplay (in-world counters are fine), show don't tell, simple rescue (get near, they
climb on, home), third person, every action on keyboard, touch and gamepad.

## (a) Why the loop feels bad (from the code)

| # | Owner felt | What is true |
|---|---|---|
| L1 | Survivors are too close | Tutorial calls use `Near` / `CalmBay`: 110–420 studs from `CallTypes.STATION`, inside the harbour. `Outer` stops at `OUTER_MAX` ≈ 1,690 studs; the map is `MapRadius` 7,000 with 7 islands (docs/archive/21-explore-world-plan.md). Rescues never reach the islands. |
| L2 | "How do I save someone from a boat?" | `Board.luau`: within `REACH` 10 studs of the hull, under `STEADY_SPEED` 6 studs/s (~4 kn), for `HOLD` 0.6 s; above `RAM_SPEED` 14 you knock them away. The only cue is their outline colour. Nothing in the world says "slow down here". |
| L3 | Land has no purpose | Shops and vehicles moved to the phone, drop-offs are pads at the water, every call is at sea. Walking only serves stamps and NPC chat. |
| L4 | Boats overlap | 4 bays on one pier (`GameConfig.LaunchBayCount`), a 5th player wraps to bay 1. Phone spawn takes the nearest free bay or shared slipway spot; `spotFree` runs before the new hull exists, so two spawns in the same moment both pass it (likely; not reproduced). |
| L5 | No "home", nothing to show off | The bay is a shared slot with an 8-piece decor row (`BayDecor`); progress lives in phone menus nobody else sees. |

## (b) The loop

**Your dock → call → trip out past the islands → pick-up → bring them home → upgrade your dock → farther calls,
bigger craft.** The dock is home, garage, shop and trophy case. Everyone in the server sees everyone's dock.

## (c) Hard rules

1. **One dock per player, nobody else spawns there.** Your craft always launches at your berth (or a harbour you
   unlocked). Spawns are serialized per berth: no two hulls ever share a spot.
2. **You start with almost nothing.** A bare wooden jetty, a name board and a jet ski. No walls, no roof.
3. **Everything you upgrade appears on your dock, in the world.** The next upgrade is a ghost outline (blue
   wireframe + scaffold) on your dock; walk into it to see the price card. Built upgrades play a short build beat.
4. **Every item has two prices: Cash (+ rank) or Robux.** Robux skips both the Cash and the rank. (Overrides
   docs/04 rule 4. Still never sells skill: a bought craft handles the same as an earned one; grades and
   certifications for promotions stay earned.)
5. **The dock replaces the phone for vehicles and upgrades.** Choose, buy, paint and launch at the dock. The phone
   keeps settings, map/album, friends, events, Robux-only cosmetics and one "boat to me" button for when you are
   stranded.
6. **The pick-up reads from the water, not from text.** A ring on the water marks where to slow down.
7. **Calls get farther as you grow.** Close for the first two, then out among the islands.

## (d) The dock

### d.1 Plots (the marina)

- **16 plots** (server size 16, docs/01). Each plot = a water berth + a strip of shore behind it, sized for the
  biggest future build (hangar + sub pen) so nothing ever overlaps. Size (tune, verify on the map): 50 x 90 studs.
- Port Haven marina: two rows of 8 along the harbour (verify the shoreline fits; else 8 in Port Haven + 8 on the
  Penwyn second harbour, docs/archive/21-explore-world-plan.md island 3).
- Assigned on join; your dock rebuilds from your profile at whichever plot you get. Empty plots show a plain
  "for rent" jetty so the marina never has gaps.
- Your plot is the spawn and respawn point. A small flag with your avatar colour flies over it so you find it from
  the water; the minimap shows a house pin in your colour.
- Harbour Master plot: the head of the marina goes to the highest rank in the server (pure flex, re-assigned only
  on join/leave so nobody's dock jumps mid-play).

### d.2 Levels (each adds one visible piece)

| Lv | Adds | Unlocks | Cash / rank (tune) | Robux (tune, launch) |
|---|---|---|---|---|
| 1 | Bare jetty, name board, jet ski at the berth | — | free | — |
| 2 | Pontoon, lamp posts, flag in your colour, rescue-count board | 2nd berth (2 craft out) | 2,500 / Lifeguard | 49 |
| 3 | Boathouse (roof, roll-up door), boat board, paint booth | Choose/paint boats at the dock | 10,000 / Rescue Swimmer | 99 |
| 4 | Lookout tower + slipway crane | Faster relaunch (no cooldown), lifeboat-size berth | 30,000 / Coxswain | 199 |
| 5 | Lit station front, beacon you see across the harbour at night | Trophy hall, Harbour Master eligible | 100,000 / Rescue Pilot | 399 |
| Later | **Car garage** on the shore strip | Cars, ATV, 4x4 from the dock | rank-gated | priced then |
| Later | **Hangar + helipad** | Helicopter, seaplane | rank-gated | priced then |
| Later | **Sub pen** | Submarine | rank-gated | priced then |

Decor (flags, lights, statues, paint themes, Sea Chest drops) fills fixed slots on top of the level; the existing
`BayDecor` slots move onto the dock. Trophies appear by themselves: rescue count on the board, milestone trophies
on a shelf, island stamps on the boathouse wall.

### d.3 Doing things at the dock (no phone)

- **Launch:** your active craft floats at the berth. Walk on and you're seated (docs/archive/20-clarity-redesign.md rule 7 still holds for
  the spawn itself: afloat, bow to sea).
- **Choose / buy a craft (Lv 3+):** the boat board in the boathouse holds a scale model of every craft. Owned ones
  are lit; locked ones show a padlock + Cash + R$ price. Touch a model: the crane lowers that craft into the berth.
  Before Lv 3 the jetty has a small rack with the same models (choice at an in-world counter is allowed).
- **Upgrade:** walk into the ghost outline → price card (Cash button, R$ button) → build beat.
- **Paint:** stand the craft in the paint booth; swatches on the wall.

## (e) Core loop fixes

1. **Pick-up ring.** An orange ring (~12 studs) on the water around each survivor, plus waving and splashing.
   Inside the ring the craft eases its throttle down by itself (like a docking assist). They swim over and climb on
   in view, "+1". No knock-back below rank 3; `STEADY_SPEED` up to 10 (tune). Optional later: throw the lifebuoy
   from ~30 studs and reel them in (a faster skill move).
2. **Distance tiers.** Calls 1–2 stay `Near`. After that, calls spawn around the islands: about 600–2,000 studs
   on a jet ski, farther with faster craft (zone pool keyed by best owned craft). Pay scales with distance.
   Drop-off = your dock or the nearest unlocked harbour, so a far call does not end in a dull trip back.
3. **Land gets a job (owner to confirm):** land calls. Someone cut off by the tide on a beach, on a cliff ledge, lost
   on an island; beach the boat, reach them on foot, they follow you back aboard. Walkable town shrinks to the
   station, the marina and one street; the rest is scenery.

## (f) Work packages (disjoint files; Opus builders, ponytail; real-client check after each)

**WP-1 · Marina and your own dock (Lv 1).** `server/Services/VehicleService.luau` (bays → plots, per-plot spawn
lock), new `server/Services/DockService.luau` (plot assignment, rebuild from profile, Harbour Master),
`server/Cosmetics/BayDecor.luau` (slots onto the dock), `server/World/Harbour.luau` (16 plots), `GameConfig`.
Acceptance: 4 clients in Studio spawn a craft in the same second, no overlap; each player spawns on their plot;
rejoin lands on a plot with the same dock.

**WP-2 · Pick-up ring.** `shared/Ops/Board.luau`, `client/Mechanics/auto_board.luau`, `server/Ops/PiwRescue.luau`.
Acceptance: a fresh player at full throttle into the ring gets the survivor aboard without reading anything.

**WP-3 · Distance and drop-off.** `shared/Calls/CallTypes.luau`, `shared/Calls/CallLogic.luau`,
`server/Services/OperationService.luau`, `client/Controllers/MapController.luau`.
Acceptance: call 3+ is ≥ 600 studs out; the Home pin points at the nearer of your dock and an unlocked harbour.

**WP-4 · Dock levels 2–5, ghost upgrades, two prices.** `DockService`, `shared/Config/DockConfig.luau` (new),
`shared/Config/MonetizationConfig.luau` (developer products, one per level, stored in the profile),
`server/Services/MonetizationService.luau`. Placeholder Parts first; Blender models via Opus agents after.
Acceptance: buy Lv 2 with Cash and Lv 3 with R$ on a test account; both show to a second client.

**WP-5 · Boat board and the phone diet.** Boat board + crane + paint booth on the dock; phone Vehicles app becomes
"boat to me" only. `client/UI/Phone.luau` (Vehicles app), dock client controller.

Later, each its own chapter: car garage, hangar + helipad (helicopter, seaplane), sub pen (needs a submarine
craft and underwater play), land calls (after the owner confirms e.3).

Order: WP-1 and WP-2 first (parallel, they are the bugs), then WP-3, then WP-4 and WP-5. One Opus real-client
sign-off at the end, then publish to the test place.

## (g) Open questions

1. Land calls (e.3) or just shrink the walkable land?
2. Lifebuoy throw as the skill move, or ring only?
3. ~~Robux prices in d.2 are first guesses~~ Answered by (i) (2026-10-25).

## (h) The "Later" items (owner, 2026-10-25: "implement also the Later items")

Same rules: placeholder Parts first, one visible building per unlock on your plot's shore strip, Cash + rank or
Robux, choose the vehicle at an in-world board inside the building (scale models, lit = owned), simple rescue.

| Building | Vehicles | Their job in the loop | Rank (Cash) / Robux (tune) |
|---|---|---|---|
| **Car garage** | Existing land vehicles (LifeguardPickup, BeachATV, CoastguardResponse, HarbourGT, LighthouseCruiser) | Reach land calls and island interiors by road (St Elowen's causeway) | Lifeguard (5,000) / 75 |
| **Hangar + helipad** | Rescue helicopter (new), seaplane (new) | Helicopter: hovers, reaches cliffs and land calls; hover steady inside the ring and the winch lifts the survivor (same hold-steady rule as boats), seats 2. Seaplane: fastest to far islands, lands on water inside the ring to pick up, seats 4 | Rescue Pilot (75,000 heli / 60,000 seaplane, hangar 25,000) / heli 399, seaplane 299, hangar 199 |
| **Sub pen** | Submarine (new) | Dives under the mesh ocean to the seabed (`Ocean/Seabed`, `Underwater`); new call: a diver stuck at a wreck (Skerry seaplane wreck, *Gannet Star*, Wreck Reef) inside a ring on the seabed; plus wreck exploration with stickers | Coxswain (40,000) / 249, pen 149 |

**Land calls** (e.3, implemented as recommended): Stranded on a beach by the tide, stuck on a cliff ledge, lost on
an island. The pin leads to a beach marker; beach the craft (or drive the car / fly the helicopter), reach them on
foot inside the ring, they follow you, board, home.

### Work packages

- **WP-6 · Helicopter** and **WP-7 · Seaplane** and **WP-8 · Submarine**: flight / dive model as a pure shared
  module with Lune specs + a client controller (keyboard, touch, gamepad), following the boat and car patterns.
  Can start now (no dock or VehicleService edits); integration into VehicleService / VehicleConfig comes in WP-10.
- **WP-9 · Land calls**: after WP-3 lands (same call files).
- **WP-10 · Dock buildings**: car garage, hangar + helipad, sub pen on the plot, in-world vehicle boards, wiring
  the new vehicles into VehicleService/VehicleConfig/ProgressionConfig, prices. After WP-1, WP-4 and WP-6..8.

## (i) Economy check (2026-10-25)

`tests/Pacing.spec.luau` now plays real calls: from call 4 `CallLogic.chooseCall` with the reach of every owned
craft, pay `distancePay`, and a clock of 45 s per call + per trip (out and back at the docs/02 cruise, 35 s to
board and drop; a land call +30 s), taking whichever owned boat is quickest. Free player, solo, 2 x 25 min a day.

**Distance pay:** x1 up to 1,500 studs, then distance / 1,500, cap x4 (was / 1,200). Jet ski calls average x2.2,
RIB x1.6; Cash ~15 to 17k an hour, Rep ~3.5k an hour. Ranks: Lifeguard 0:13, RIB 0:17, Coxswain 0:59,
Rescue Pilot 2:22 (docs/03 2:42), Commodore 12.9 h (day 16), Admiral 35 h (docs/03 ~32 h).

| Item | Cash | Rank | R$ | Packs for that Cash (R$) | R$ vs packs | Free: earn time / bought at |
|---|---|---|---|---|---|---|
| Dock Lv 2 | 2,500 | Lifeguard | 49 | 20 | 2.5x | 9 min / 0:29 |
| Car garage | 5,000 | Lifeguard | 75 (was 99) | 35 | 2.1x | 19 min / 0:46 |
| Dock Lv 3 | 10,000 | Rescue Swimmer | 99 | 60 | 1.7x | 38 min / 2:00 |
| Sub pen | 20,000 | Coxswain | 149 | 100 | 1.5x | 1.3 h / 8.7 h |
| Hangar | 25,000 (was 40,000) | Rescue Pilot | 199 | 125 | 1.6x | 1.6 h / 7.1 h |
| Dock Lv 4 | 30,000 | Coxswain | 199 (was 149) | 149 | 1.3x | 1.9 h / 10.3 h |
| Submarine | 40,000 | Coxswain | 249 | 149 | 1.7x | 2.5 h / 12.3 h |
| Seaplane | 60,000 | Rescue Pilot | 299 | 209 | 1.4x | 3.8 h / 15.4 h |
| Helicopter | 75,000 | Rescue Pilot | 399 (was 299) | 274 | 1.5x | 4.7 h / 7.1 h (with hangar) |
| Dock Lv 5 | 100,000 | Rescue Pilot | 399 (was 249) | 298 | 1.3x | 6.3 h / 20.6 h |
| RIB / Lifeboat pass (for scale) | 2,500 / 12,000 | Lifeguard / Coxswain | 49 / 129 | 20 / 70 | 2.5x / 1.8x | 9 / 45 min |

Packs = the cheapest mix of live Cash packs (Calm Bay rate: 1,500 / 4,500 / 16,500 / 50,400 Cash for 10 / 25 / 75 /
149 R$, at most 5 a day). "Bought at" = play time in the sim, which keeps Cash for the next craft first.

1. No Robux price is a cheaper way to Cash than the packs (the old Lv 5 at 249 and Lv 4 at 149 were); every R$
   price is 1.3x to 2.5x its pack Cash, and the extra is the rank skip.
2. The hangar is part of the helicopter's bill, so 40k pushed the helicopter to 8.3 h (docs/03 10.2: past 8 h, cut
   the price); at 25k it lands at 7.1 h. The heli pass (399) sits above every Robux boat (max 249) and below a
   Night Hawk-style Signature (499).
3. Distance pay / 1,200 made far calls pay more per minute than near ones and ran ranks ~20% ahead of docs/03; /
   1,500 keeps far calls about even per minute. Calls are now 3.5 to 4.5 min, not docs/03's 6.5, so early ranks
   still land ~15 min early.
4. Reach is capped by rank (`CallLogic.craftReach`): the tier of the best free craft the rank unlocks (Recruit
   2,000, Lifeguard 3,500, Coxswain 5,500). A Robux boat no longer hands a Recruit x3+ calls; it buys the boat and
   its speed. Submarine (Coxswain) and helicopter / seaplane (Rescue Pilot) reach 5,500, capped the same way.
5. A call landed away from Port Haven (Haven Sands slipway, ~1,100 east; the only far drop-off) pays for half the
   trip sailed, station → scene → Sands, never more (`CallLogic.deliveredPay`): a Skerry call landed there was x1.70,
   now ~x1.41. The submarine runs 40 surfaced / 22 submerged (was 14), so the Diver timer is 600 s (x1.3 = 13 min).
   Free-player sim unchanged (ranks as above).
6. Hub map (WP-19c, 2026-10-25): distance counts from your island berth, calls from call 3 sit 1,200+ studs from
   the hub, the drop-off is your berth or the hub. Sim (playing all six islands): Lifeguard 0:13, RIB 0:18, Coxswain
   0:55, Rescue Pilot 2:22, Commodore 13.6 h, Admiral 36 h; jet ski x2.1 at 4.2 min/call, RIB x2.4 at 5.1 min (was
   x1.6 at 3.4: longer trips, same pay per minute). Within a few % of before: distance numbers unchanged.
7. Re-checked 2026-10-25 after the old-design cleanup: the sim buys no car garage or seaplane (both cut in WP-17 /
   WP-20), so the timeline is unchanged: Lifeguard 0:13, RIB 0:18, Coxswain 0:55, Rescue Pilot 2:22, Commodore
   13.7 h, Admiral 36.4 h.

8. **WP-28 (2026-10-26): no ranks, the unlock tree, Cash only.** The sim walks the tree in plan order (Workshop →
   Boathouse → RIB → Pontoon → Lifeboat slip → Lifeboat → Lookout → Helipad → Hangar → Helicopter → the rest), a
   due upgrade first. Solo: Workshop 0:07, Boathouse 0:24, RIB 0:34, Pontoon 0:49, Lifeboat 2:14, Helicopter 7:35
   (now 55,000; helipad 10,000, hangar 20,000), Submarine 12:02, Station 14:42, the whole tree 17:17 (Clinic); ~420k
   Cash unspent at 40 h. Reach = the best craft you launch; the Robux boats sit on the RIB's tier (3,500).

## (j) Plots v2: big land plots, blueprint table, crew (owner, 2026-10-25)

Owner, after seeing the blue wireframe ghost on the dock: "I don't want anything holographic or 'what could it be'.
I want a bigger plot per user with land, not just a dock, so it can evolve to fully new stuff. And at some point
to be able to hire people." Decisions: **8 players per server, big plots; buy upgrades at a blueprint table;
plots on a reshaped coast next to Port Haven.** This section wins over d.1, d.3 "Upgrade" and rule c.3.

**Pillars (owner):** tycoon-like (your plot grows), exploration and adventure (islands, wrecks, land calls),
played with friends (ride in each other's craft, crew up on big calls, visit and show off plots).

**Rules.**
1. No holograms, wireframes or translucent previews of anything not yet built. Unbuilt land is just land (grass,
   sand, a few solid builder's pegs at most).
2. Each player owns a waterfront plot: about 150 x 200 studs, roughly 2/3 land and 1/3 private water with the
   berth. Plots sit side by side on one stretch of coast next to Port Haven, each with road access, a fence/hedge
   line and an owner sign. 8 plots (server size 8; was 16).
3. You start with the bare jetty and a jet ski on an empty plot. Everything else gets built on your land.
4. Upgrades are bought at the **blueprint table**: a real table (first a trestle table on the jetty, later inside
   the station) with paper blueprints, one per available upgrade: a drawing of the building + Cash / rank / R$.
   Pick one: builder NPCs walk onto your land and put it up (short scaffold-and-rise beat, solid parts, ~5 s).
   Locked blueprints are greyed with a padlock and a rank badge.
5. The plot is laid out to grow: station building, boathouse + paint booth, car garage with its own driveway,
   helipad + hangar on land, sub pen in the berth, crew quarters, and spare lots for future buildings.

**Crew (late game; designed now so the plot has room).** Unlocks late (tune: station built + a high rank).
Job seekers **line up outside your station** as real NPCs, each showing a role glyph and skill stars over their
head. Walk up to one to see their card (role, stars, hire price, daily wage) and hire them. The line is replaced
by a new group **every 20 minutes** (a small clock glyph on the station door shows the next arrival). Hired crew
move onto your plot and work there visibly.

| Crew | Seen doing | Effect (small, never replaces playing) |
|---|---|---|
| Mechanic | Working on a boat in the boathouse | "Boat to me" cooldown −30% (60 s → 42 s), repairs |
| Lifeguard | In a tower on your beach | Brings in small ambient rescues near your plot: a little Cash while you play |
| Dispatcher | At the radio in the station | One extra call offer / better calls |
| Coxswain | Takes your second boat out | Joins big calls as an NPC helper |
| Pilot | By the helipad | Same for the helicopter |

Hires cost Cash (+ rank), with a daily wage taken from earnings so it stays a Cash sink for the late game (docs/23
(i): late players sit on ~280k unspent). Robux can hire too. Only while you're in the server; nothing idle offline.

**Exploration feeds the plot** (after crew): discovering places adds blueprints to the table (e.g. Gannet Rock
lighthouse → a small lighthouse for your plot, the Arches → a stone arch gate); wreck salvage found by the sub
(anchor, ship's bell, figurehead) goes on display on your plot; your plot is where friends meet and set off.

**Work packages.** WP-14a terrain + plot layout (8 plots on the reshaped coast, `tools/world` + map bake, layout
data). WP-14b move the dock code onto the big plots (Marina/DockService/DockPieces/buildings/boards, server size
8). WP-14c blueprint table + builder beat, ghost removed. WP-15 crew. WP-16 asset diet (owner yes, 2026-10-25): drop unused asset ids (~3,070 referenced, 1,478 in AssetIds),
merge near-duplicate PBR surfaces (455 texture packs now; they hit the upload rate limit) into shared materials,
measure client memory and load time on a phone before/after. 14a first; 14b and 14c after it and after
WP-13 lands.

**WP-16 done (2026-10-25), owner rule "do not redesign the assets we already have":** only unloaded or cut assets left.

| Measure (Studio, same build/play steps) | Before | After |
|---|---|---|
| AssetIds.luau asset ids (103 unused/cut assets out; unread Textures table out) | 1,478 | 259 |
| PBR texture-pack surfaces (publish_studio.py rule) / unique map sets | 455 / 453 | 195 / 195 |
| build/MaydaySeaRescue.rbxl (no terrain) | 5,467,244 B | 5,411,066 B |
| Client texture MB, hub spawn / own island (Studio total MB: noise, ±60) | 180 / 180 | 165 / 170 |

## (k) The hub and six islands (owner, 2026-10-25: "love the plan, do it")

Owner: "development is going slowly cause there is bloat ... and too many mechanics. Remove the cars and city for
now (don't publish them). 6 islands, one for each player, and a middle one, the city, that we can go to by boat or
by suspended highways. The rest exploratory." This section wins over (j) on layout and server size, and over
docs/10 / docs/archive/21-explore-world-plan.md where they place Great Gale, Port Haven and the town.

**Layout (tune).**
- **Hub island** at the centre (~400 studs across): newcomer spawn, Coastguard HQ (the station), radio + call
  board, leaderboard, a shop counter. Small and readable, not a town.
- **6 player islands** in a ring around the hub (~900 studs out, 60° apart, ~300 studs across each): one per
  player (server size **6**), land + a sheltered berth cove. Your island is your plot: everything in (j)
  (blueprint table, builders, station, boathouse, paint booth, helipad, sub pen, crew quarters, spare land) is
  built on it. Unclaimed islands stay plain (sand, grass, a bare jetty).
- **Suspension bridges** from the hub to each island, walkable, arched high enough for every boat to pass under.
  No cars for now.
- **Outer ring = exploration and rescues:** the docs/archive/21-explore-world-plan.md islands that don't need the town (Skerry, Puffin, Gannet,
  Wreck Reef, the Arches, Mermaid Lagoon; Penwyn and St Elowen's only if they stand without the town), wrecks,
  open sea. Calls spawn out here; distance tiers count from your island; you deliver to your island or the hub.

**Cut (deleted from main; restorable from git tag `pre-hub-cut`).** Cars and all land vehicles, the car garage,
roads, streets, traffic, the town (Port Haven buildings, cottages, chandlery, town NPCs and extras), Great Gale's
terrain. Kept: the station rig (re-homed on the hub), boats, helicopter, submarine, rescues, phone, dock/plot code.

**Second cut (owner, 2026-10-25, from the mechanics inventory):** seaplane, land + cliff calls, NPC racer,
first-person camera + viewmodel, photo mode, rare rescue variants/dressing (~5,400 lines; WP-20). Kept on purpose:
rip current call, pets + wildlife sanctuary.

**Work packages.** WP-17 tag + cut cars and town. WP-18 new map: hub, 6 islands, bridges, outer islands (terrain
generator + bake + layout data). WP-19 plots → islands (dock code, server size 6, calls/drop-off from your island).
Then WP-14c blueprint table, WP-15 crew, WP-16 asset diet. WP-14a (coast plots) is cancelled.

## (l) Hub v2: a forest island of outposts and quests (owner, 2026-10-25)

Owner: "The main island needs to be bigger ... I think NPCs for quests" and "put a forest there, not buildings
but small outposts". Approved direction:

- **Bigger hub, ~800 studs across** (was 400); the 6 player islands move out (900 → ~1,100) so the bridges stay
  long. Check the ocean covers the whole view from a player camera (no square water edge).
- **Feels unexplored** (owner): a wild, overgrown island the coastguard has only just landed on. Rough trails,
  not paved paths; the outposts are frontier camps (canvas, crates, rope, lanterns), not a settled town; deeper
  forest with old ruins, a cave, a waterfall or overgrown wreck to stumble on; the map fog covers the forest
  until you walk it, and hidden spots give discovery stickers.
- **A forest, not a town.** Dense trees with paths; clearings hold **small outposts**: a coastguard lookout hut
  with the radio + call board (the HQ), a market stall (shop counter), a harbourmaster's shack (Storm Summon), a
  campfire ring/stage (live-ops events), a rescuer monument in a clearing (this week's top rescuer), a visitor
  jetty. Tents, huts, stalls, platforms in trees; no big buildings.
- **Quest NPCs** in the outposts with a "!" over their heads; talk = camera zoom + numbered replies (CLAUDE.md
  exception). Quest kinds: find (a lost dog on Puffin Isle), deliver (supplies to the Gannet Rock keeper),
  salvage (the *Gannet Star*'s bell, by sub), special rescue (a named person, harder, bigger reward); a few 3–5
  step chains that unlock a unique blueprint for your island. Rotate daily. Reuse Dialogue/TalkController, pins,
  discovery and rescue code; no new UI kinds.

**Work packages.** WP-21a hub terrain + forest + outposts (after WP-19a/19c land). WP-21b quest system + first
quests (after 21a).

**WP-21b as built (2026-10-25).** Six givers at the quest camps: Old Maud (lost things), Tam (cargo), Captain Rook
(salvage, needs the sub), Nell (special rescues), Keeper Ives (the lamp chain), Pip (odd jobs); 13 quests in
`Quests/Data`. Pay is flat: find / deliver 1,500 Cash + 250 Rep (a trip out and back, ~1.5 calls), salvage 2,500 +
400, a rescue quest 1,000 + 200 on top of the call's own pay, the chain's last step 2,000 + 400 + the Lighthouse
blueprint (rises on your island's Spare1 lot). Each giver offers one quest a day, so the chain takes three days.
Pin rule: your accepted call > your quest > a call offer > your own waypoint. Shortcuts: the rescue quest's survivor
is the usual swimmer (named only in the giver's line); carried things ride on your back as placeholder Parts.

**Order update (owner, 2026-10-25):** publish speed first. (1) `tools/studio/publish_studio.py` re-triggers only the
texture packs that failed, not all ~455 (~28 min of the publish today). (2) WP-16 asset diet right after WP-21a
(fewer unique PBR textures, unused asset ids out). Then WP-21b quests, WP-14c blueprint table, WP-15 crew.

**Radio cut (owner, 2026-10-25):** "remove the radio, I want voices only for NPCs". The dispatch radio, its voice lines and
the HQ radio prop go (WP-22); calls read from the card, pin, flare and sound. NPCs keep their voices; the Sea Shanty
Radio music item stays.

## (m) UI redesign: no phone, Roblox simulator style (owner, 2026-10-25)

Owner: "redesign the UI also, so no phone, and I want a more Roblox-like UI", with simulator-shop references (bright
gradient cards, chunky rounded bold font with a black outline, thick dark borders, red square X, big green price
buttons, coloured square icon buttons with a label underneath). This wins over the "all UI on the phone" direction.

- **No phone.** A column of big square icon buttons on the left (Shop, Quests, Album, Companion, Crew, Settings) plus
  a "Boat to me" button; each opens a centred panel. The full map stays on M / its button.
- **One UI kit** (`src/client/UI/Kit/`): Panel (title bar with icon + name, red X), IconButton (coloured square,
  icon, short label under it, press bounce), Card (gradient row: icon/art left, title, price button right),
  PriceButton (green, Robux glyph or Cash icon + number), Tabs, Toast, counters (Cash, rank). Font: a chunky
  rounded display font (FredokaOne / LuckiestGuy class) with a black UIStroke; thick dark borders; vertical
  gradients; drop shadows; pop-in animation. Works on keyboard, touch and gamepad (selection ring).
- **Icons are generated art** (Antigravity Gemini, transparent PNGs, thick outline cartoon style), not code-drawn.
- Still show-don't-tell: icons and 1–3 word labels; shop cards may carry a 2–5 word line, never paragraphs.
- Every existing screen moves onto the kit: HUD counters, call card/debrief, dock price card, boat/craft boards'
  cards, quest talk replies, settings, album, store, companion, crew.

**Work packages.** WP-23a icons (Antigravity). WP-23b UI kit + style-guide screen + art-director critique (≤3
rounds). WP-23c delete the phone, left button bar + panels. WP-23d restyle every remaining screen on the kit.

## (n) Lego style for new things (owner, 2026-10-25)

Owner: "Do the blocky Lego stuff for things that we have not built yet. I want when building the base/dock to have
Lego-like animations when built." And: "do not redesign the assets that we already have."
- **New** buildings, outposts and props are made in a blocky, Lego-like style (chunky bricks, bright colours, studs
  on big flat tops, modest part counts). Existing finished models and art keep their look.
- **Building on your island** plays a Lego build: pieces drop in brick by brick, bottom to top, with a small bounce
  and a snap sound, builders standing by, a dust puff at the end (WP-14c).
- The UI kit can carry a subtle stud texture on title bars and price buttons (docs/23 (m)).
- **Player islands are plain Lego baseplates** (owner: "do not use the land on the player's islands, I want a simple
  plain Lego island, a simple 2D land"): flat green stud plates with a berth notch, no terrain, no scatter (WP-24).
  The hub forest and outer islands stay terrain.
- **Build station with a tablet** (owner: "I want it to be a tablet; when accessing it, the camera goes in from the
  top and there you can build the necessary things"): a small Lego builder's yard near your island spawn with a
  tablet on a stand. Using it tweens the camera up to a top-down view of your island (build mode). A bottom bar of
  kit cards lists what you can build (icon, Cash + rank or R$, padlock if locked); picking one makes its empty lot
  pulse (a flat outline on the ground, never a 3D preview); buying plays the Lego build from above. Exit returns the
  camera. Replaces the paper-blueprint table (WP-14d, after WP-14c and the UI kit).
- **Builders from now on: multiple DeepSeek V4 Pro agents** (owner); Opus reviews.

## (o) Rescued people become your workers (owner, 2026-10-25 night)

Owner: "You have your own island. You rescue people that help. There are categories — builders, gatherers,
rescuers and so on — and you build a mini empire on your island." Decisions: **4–5 categories at launch** (more
as updates), **Cash is the only currency**, **small capped offline earnings**, **the crew lineup (WP-15) is
replaced** by rescued workers. This reverses the earlier "rescued survivors don't become crew" rule.

- **On pick-up** each survivor shows a category icon and a rarity (common / rare / legendary stars) over their head.
  Delivered to your island, they walk to the matching building and work there, visibly. No management menus:
  assignment is automatic (best workers fill the building's slots; extras idle at a "bunkhouse").
- **Launch categories (one building + one clear effect each, tune):**
  | Category | Building | Effect |
  |---|---|---|
  | Builder | Workshop | builds cost less Cash and finish faster |
  | Gatherer | Fish & salvage shed | passive Cash per minute |
  | Rescuer | Rescue boathouse | NPC boats bring in small rescues near your island (Cash + occasional new worker) |
  | Mechanic | Boat yard | faster craft, shorter "Boat to me" cooldown |
  | Medic | Clinic | bigger call payouts (survivors arrive healthier) |
- Each building has worker slots that grow with its level (built at the tablet). Rarity multiplies a worker's effect.
- **Offline**: Gatherers and Rescuers earn a small capped amount while you're away (tune: up to 2 h at a reduced
  rate), collected with a coin burst when you return.
- Robux: no paid randomness; worker rarity only comes from rescues. Possible later: a paid slot expansion.
- Flex: your island fills with named people you saved; legendaries glow.

**Work packages.** WP-26 workers (after the current batch lands): survivor category + rarity roll, delivery →
worker spawn and walk-to-building, 5 buildings in DockConfig/tablet, effects, offline earnings, remove the crew
lineup, pacing/economy check. Then WP-25 art pass covers the worker buildings too.

## (p) No middle island: a tight ring of six islands (owner, 2026-10-25 night)

Owner: "remove the inner island and have the islands closer to each other so the flex element is there."
Decisions: **quest NPCs come to you** (they arrive by boat at your own jetty), **bridges between neighbours**,
**~80 stud gaps**. This wins over (k) and (l) on the hub.

- **Layout:** the 6 Lego-plate islands (~300 across) sit in a ring ~380 studs from the centre, ~80 studs of water
  between neighbours; the centre is an open lagoon (no island, no calls in it). Each island's berth notch faces
  outward to the sea. Short walkable bridges join each island to its two neighbours (a full ring), high enough for
  boats to pass under between islands.
- **Gone with the hub:** the forest island, its camps, HQ hut, market stall, harbourmaster's shack, campfire stage,
  monument, visitor jetty, hidden ruin/wreck stickers and the fine forest fog. Shop = the left-button Shop panel;
  calls = the pager card; drop-off = your own berth (the generous zone); newcomers spawn on their own island.
- **Quests come to you, with their own tablet** (owner: "a separate tablet like with quests, and visually there
  are boats that come in at that pontoon"): each island has a small **quest pontoon** (separate from your berth) and
  a **quest tablet** on a stand beside it. Quest-giver NPCs visibly sail in on small boats and moor at the pontoon
  ("!" over them); the tablet lists the quests on offer and your active one (UI-kit cards, same style as the build
  tablet: tap a quest to focus its giver/boat, accept, hand in). You can also talk to the moored NPC directly (zoom +
  numbered replies). When a quest is handed in the boat sails off and a new one arrives on the daily rotation.
  Same quest kinds and chains as before.
- **Rescue scenes that sat at the hub** (rip current beach, ferry spot off the hub harbour) move to the outer
  islands / open sea. The loading flyover circles the ring centre.
- Leaderboard: a small board on each island's jetty, or the left-button panel (builder's choice; no centre).

**Work package.** WP-27 ring layout (after WP-24 plates land): generator removes the hub terrain; HubLayout →
ring positions; neighbour bridges; delete hub camps/HQ/fog/stickers code; quest NPC boats to your jetty; move
hub-based call sites; loading-flyover centre; map image refresh.

**Done (WP-27).** Island centres 470 studs from the centre (at 380 the 320-stud plates overlap); nearest plate
corners 80 apart, ~93 studs of water under each bridge. Bridges cross each bisector 400 out, 182 long, 11.3 deg
ramps from 45 studs onto each plate to a rounded crest (deck ~20.6, underside ~19.4). The main bake window is a sand
seabed (~Y -37). Quest pontoon off each island's front-left wing (3 mooring slots), quest tablet beside it; givers sail
in from 400 out. Rip moved to Puffin Isle's north-east beach, the ferry to open sea 1,000 south of the centre. Home
counts only at your own berth. Leaderboard: a board beside every island's spawn. Chief Aggie and the station crew
removed (no island needs them).

## (q) No ranks: a linear unlock tree (owner, 2026-10-25 night)

Owner: "remove all of the recruit and rank stuff ... look at it linearly: if the player did not unlock X he cannot
build Y, clearly stated in the UI ... we can scale that." This wins over every rank/Rep rule elsewhere.

- **Removed:** ranks (Recruit → Admiral), Reputation, rank-ups and the rank ceremony, the rank bar/badge, rank
  gates, rank-based badges and leaderboards (badges/leaderboards switch to people rescued), dock levels 2–5 as a
  ladder (their pieces become separate tree buildings). Saved profile keys stay (unused).
- **Unlock tree (data-driven, so it scales):** every buildable item lists its prerequisites (`needs = {...}`) in one
  config; adding content = adding a row. First tree (tune):
  ```
  Jetty (start)
  ├─ Pontoon (2nd berth) ── Lookout tower ── Helipad ── Hangar → Helicopter
  │                              └─ Rescue boathouse (Rescuers)
  ├─ Workshop (Builders) ─┬─ Boathouse → RIB, boat board, paint booth
  │                       │     ├─ Lifeboat slip → Lifeboat
  │                       │     └─ Crane ── Sub pen → Submarine
  │                       └─ Boat yard (Mechanics)
  ├─ Fish shed (Gatherers)
  └─ Station (needs Boathouse + Lookout) ── Clinic (Medics), trophy hall
  Decor: needs Jetty only
  ```
- **UI:** a locked card shows a padlock + the missing prerequisite's icon and name ("Needs: Crane"); tapping it
  focuses that item's blueprint. In-world blueprints of locked items are greyed with a chain icon. Max ~4 steps deep.
- **Craft unlock through their building** (RIB ← Boathouse, Lifeboat ← slip, Sub ← Sub pen, Helicopter ← Hangar);
  Robux boats need the Boathouse. **Call reach** = the best craft you can launch.
- **Robux skips the Cash, never the order** (replaces rule c.4's "skips rank"): an item can be bought with Robux once
  its prerequisites exist.
- Economy: re-tune the pacing sim on the tree (Cash only), keep free players reaching everything.

**Work package.** WP-28 (after the current batch lands, before WP-27 ring): remove ranks/Rep; unlock tree config +
rules + specs; tablet cards and blueprints show prerequisites; craft/building gates; call reach; badges/leaderboard
to rescues; pacing re-tune; docs (00, 02, 03, 04) updated.
