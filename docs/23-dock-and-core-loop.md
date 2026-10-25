# 23 · Your dock and the core loop

2026-10-25. Owner: "the core game loop feels bad ... the player does not need to go too far to get the survivors,
on boat I don't get how can we save someone. The land itself is a mess and I don't know why a player needs to go
on land. On multiple players if 2 or more spawn a boat then it overlaps. I think each player needs a dock."
Then: "start first with no walls, nothing, just a simple dock and a jet ski; further down the line a garage for
cars + garage for planes/helicopters + submarines, so that we don't need to use the phone so much, we have
everything in the dock." And: "you can buy everything with Robux when you don't have Cash/rank."

This chapter wins over docs/04 §1.1 and rule 4 (where things are sold, rank-gated paid vehicles), over the
"all UI on the phone" direction for vehicles and upgrades, and over docs/20 change 5 (spawn at the shared bays).
Rules kept: no choice UI in gameplay (in-world counters are fine), show don't tell, simple rescue (get near, they
climb on, home), third person, every action on keyboard, touch and gamepad.

## (a) Why the loop feels bad (from the code)

| # | Owner felt | What is true |
|---|---|---|
| L1 | Survivors are too close | Tutorial calls use `Near` / `CalmBay`: 110–420 studs from `CallTypes.STATION`, inside the harbour. `Outer` stops at `OUTER_MAX` ≈ 1,690 studs; the map is `MapRadius` 7,000 with 7 islands (docs/21). Rescues never reach the islands. |
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
  Penwyn second harbour, docs/21 island 3).
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

- **Launch:** your active craft floats at the berth. Walk on and you're seated (docs/20 rule 7 still holds for
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
