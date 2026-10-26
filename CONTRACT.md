# Build contract

Who owns what, and the APIs between modules, for the game as it is now (`docs/00-design.md` is the design
source of truth; `docs/23-dock-and-core-loop.md` is the change log). Use another module's API; don't edit its
files without a reason. History of cut systems lives in git and `docs/archive/16-launch-polish-plan.md`, not here.

## Rules (every module)

- No choice UI in gameplay: no menu, card or list where the player picks an option. Mechanics are world
  actions (drive, grab, hold), readable without text; a device glyph is fine. Menus live only in the phone
  (settings, Vehicles, Store, Crew) and outside play. Exception: talking to a town NPC shows numbered
  replies (docs/23 (l)).
- Show, don't tell: icons and 1 to 3 word labels; keyboard, touch and gamepad for every action.
- Placeholders (code-built Parts) until art lands; gameplay never waits on art.
- Modules in `src/server/Services/` and `src/client/Controllers/` export `Init()` and `Start()` plus an
  optional `Priority` (lower first, default 100). `Main.server.luau`'s `require` is not xpcall-guarded:
  deleting a module means deleting every `require` of it.
- Remotes: the shared ones are typed in `src/shared/Net.luau` (`Net.event(name)`, `Net.func(name)`); a
  service may create its own `<Prefix>_<Name>` remote under `ReplicatedStorage.Net`. Every remote has a
  server handler or a client listener; drop it with its last user.
- Gate: `~/RobloxProjects/tools/check.sh .` (stylua, selene, luau-lsp, Lune specs in `tests/`) must pass.

## Core loop (docs/00 §3)

<<<<<<< HEAD
A call goes up, you drive a craft near the survivors, they climb aboard by themselves, you bring them to a
drop-off and get Cash. Cash builds your island's unlock tree (docs/23 (q)); each building unlocks the next and
its craft. No ranks, no Rep (WP-28).
=======
A call goes up, you drive a craft near the survivors, they climb aboard by themselves, you bring them to your
own berth (the drop-off zone round it) and get Cash and Rep. Cash buys vehicles and upgrades in the phone; Rep raises your rank, and
rank unlocks bigger boats.
>>>>>>> main
Pick-up ring (docs/23 e.1): `PickupRingController` draws an orange `Board.RING` ring on the water round every
survivor still in the water (grey while your craft is full) and `BoatController` runs the throttle through its
`Assist` (`Board.assistThrottle`: eases to `ASSIST_SPEED` by the ring). Ram knock-back only from `Board.KNOCK_RANK`.

## Shared remotes (`src/shared/Net.luau`)

| Remote | Dir | Owner / payload |
|---|---|---|
| `VehicleSpawned` | S->C | VehicleService: `(model, bayName)` |
| `CrewJoin` / `CrewLeave` | both | CrewService: join `{ targetUserId }`; echo `{ leader, members }` |
| `PlayerDataChanged` | S->C | ProgressionService: the progression snapshot (plus `award`, `bought` extras) |
| `StormChanged` | S->C | StormService: one-shot cue per phase change |
| `DogPoint` | S->C | DogService: Bosun points at a survivor or flare |
| `RequestVehicle` | C->S fn | VehicleService: `(vehicleId, docked?, near?) -> (ok, reasonOrVehicle)`; `near` = Boat to me (id ignored) |
| `BuyGear` | C->S fn | ProgressionService: buys a vehicle (`vehicleId`); the name is historical |

Service-owned remotes: `Progression_GetData`, `Camera_SaveSettings` (ProgressionService), `Upgrade_Buy`
(UpgradeService), `Vehicle_QuickLaunch` (VehicleService), `PIW_Rescue` (Ops/PiwRescue), `Ops_*` (below), `Streak_State` / `Streak_Get` /
`Streak_Open`, `Pet_State` / `Pet_Get` / `Pet_Equip`, `Dock_Upgrade` / `Dock_Build`, `Cosmetics_Equip` / `Cosmetics_Action` /
`Cosmetics_Event`, `Monetization_GetCatalogue` / `Monetization_Purchased`, `PlatformPrompt_Ask` / `_Offer` /
`_OptIn`, `Telemetry_Client`, `Dev_Grant` / `Dev_Action`.

## Weather and storms

- `src/shared/Weather.luau` (client and server) reads `ReplicatedStorage.Weather` attributes `State`
  (`Calm`/`Warning`/`Storm`/`Clearing`), `StateStartTime`, `StateDuration`, `StormId`, `WindDirection`,
  `IsGreatStorm`: `getState`, `getIntensity(now?)`, `getZoneAt(pos)`, `getWaveParams(pos, now?)`,
  `heightAt(pos, now?)`, `changed`.
- `StormService`: `ForceStorm(isGreat?, skipWarning?, warningSeconds?)`, `ForceCalm()`, `QueueSummon(player,
  tier)`. The game is always sunny by default (`ALWAYS_SUNNY`); the storm products are `ready = false`.
- `OnboardingWeather` keeps the cold open calm (`OperationService.ColdOpenHoldsWeather()`).
- `OceanController` draws the mesh ocean from `Weather.getWaveParams` and matches `Waves.heightAt` at the
  grid vertices; `OceanController.GetVisualHeight(x, z)`.

## Vehicles

- `DockService` (docs/23 WP-1, WP-19b): your island is your plot. `src/shared/Marina.luau` (pure,
  `tests/Marina.spec.luau`): the 6 plots = `HubLayout.Islands` (server size 6); `Marina.LOTS[name]` = each lot in
  the berth frame (the same on every island), `Marina.SUB`, `Marina.ISLAND`, `Marina.spawn(i)`. Every island has a
  bare jetty down its cove + a finger beside the boat berth; an owner adds a name sign and flag (unclaimed: no sign).
  A joining player gets the lowest free island, freed on leave; what they built is `data.dockBuildings`.
  API: `GetBerth(player) -> BasePart?`, `GetPlot`, `GetSpawn` (VehicleService stands every spawn there),
  `Owns(player, key)` (the pontoon's 2nd berth, the crane's no-wait relaunch),
  `Berths()`. Player attributes `DockPlot`, `BayCFrame` (the berth CFrame); berth part attributes `LaunchBay`,
  `PlotIndex`, `Owner`.
- Unlock tree (docs/23 (q), WP-28; replaced dock levels 2..5 and ranks): `src/shared/Config/DockConfig.luau`
  `Buildings` (one row per building: `name`, `desc`, `cash`, `needs = { keys }`, optional `product` / `robux`,
  `spot` + `size` in the berth frame, `vehicles` = its own board's craft, `worker` = a WP-26 worker building),
  `BUILDINGS` (card order), `LEVEL_ITEMS` (old dock level -> tree items, the save migration). Rules:
  `src/shared/UnlockTree.luau` (pure, `tests/UnlockTree.spec.luau`): `missing`, `canBuy(key, owned, cash)` ->
  ok, "Owned" | "Needs" | "Cash", price, need; `canRobux` (Robux skips the Cash, never the order); `craftMissing`;
  `migrate(level, owned)`. Craft gates: `ProgressionConfig.Vehicles[id].needs` (RIB / Robux boats <- Boathouse,
  Lifeboat <- LifeboatSlip, Submarine <- SubPen, RescueHelicopter <- Hangar); owned craft always launch.
  `src/shared/DockPieces.luau` `building(key, berthCFrame) -> Model` (placeholder Parts; worker buildings and the
  lifeboat slip are plain Lego huts). DockService builds each owner's buildings on their plot (everyone sees
  them), berth attribute `<key>` and player attribute `Dock<key>` per building; remote `Dock_Upgrade` C->S fn
  `(key) -> ok, reason`; Robux = products with `dockBuilding` (the old `DockLevel2..5`, `DockHangar`,
  `DockSubPen` ids), granted only once the prerequisites stand (else the receipt waits). A buy plays the Lego
  build beat: `Dock_Build` S->C `{ plot, parent, name }`, `shared/BuildSeq` drops the pieces client-side, two
  crew builders stand by. Build tablet (WP-14d/e): the station tablet opens `DockController`'s top-down build
  mode: a paper blueprint on every spot not built (`DockBlueprints.onIsland`; locked = grey + chain + padlock),
  a right-hand Kit list (locked cards: padlock + "Needs: X" chip with X's drawing; tapping it focuses X;
  `DockBlueprints.needs`), and a focus view with name + `desc` + Cash / Robux buttons; Escape / B / sea tap backs
  out. Drawings: `DockBlueprints.GLYPHS`, drawn by `client/UI/BuildGlyph`. `server/Dock/BoatBoard` builds every
  board (boat, hangar, sub): the heli on the pad, the sub in the pen (`VehicleService.DockLaunch`); the boat
  board moves into the boathouse (`DockConfig.BOARD_SLOT`) once it stands; a craft whose building is missing
  shows its padlock + the building (drawing + name) and a greyed R$ chip. Studio:
  `DockDev:Invoke("building", key | "all")`, DevBoard "Build (target)".
- Dock WP-13: plots are claimed when the profile loads (`GetBerth` claims earlier; nil before Init). Harbour
  Master = `Marina.harbourMaster` (most people rescued among islands with a Station, ties keep the holder) on
  join / leave / a build: gold name board + tall gold beacon on their island, berth attribute `HarbourMaster`; nobody's island moves.
  The trophy hall (its own building) on the station's front wall: `BadgeRules.trophies`
  cups + island-stamp plaques (`DockPieces.trophies`). The boathouse's paint booth (`DockConfig.PAINT_BOOTH`): seated in it
  on your own plot → `DockController` paint card (CosmeticPicker Livery + Decal). `MonetizationEffects.passActive`
  = pass or day pass (server `OwnsPass` and the client's Boat to me ring).
- `VehicleService` (boats and jet skis): one vehicle per player, always launched at the player's own berth
  (phone, Quick Launch, berth `Launch` prompt, the cold open via `BerthLaunch`). Spawns are serialized per berth
  (`Marina.lock`). Each berth has one owner-only `Launch` prompt that spawns the player's last-launched craft
  (`data.flags.lastVehicle`, K3); switching craft is the boat board (`server/Dock/BoatBoard` + client
  `BoatBoardController`, docs/23 WP-5: a rack of scale models on each owned plot, tag `BoatBoard`; owned →
  crane beat + `DockLaunch` docked at the berth, locked → the kit Boat card via `Menu.openBoat(id)`). Every spawn stands the player on
  their jetty; a returning player (`coldOpenDone`) also gets that craft docked beside them (K11). API: `GetBay`
  (the berth), `BerthLaunch(player, vehicleId) -> CFrame?`, `GetVehicle`, `GetDriver`,
  `GetOccupants`, `AddSurvivor(model, survivor) -> boolean` (false when full), `RemoveSurvivors`, `Climb`,
  `SpawnSeated`, `SpawnColdOpen`, `QuickLaunch`, `DockLaunch(player, id)`, `DockSpot(player, id) -> CFrame?` (the
  crane's spot; clears the hulls the launch replaces first), `Stow`, `RefreshUpgrades`, `AttachTow` / `DetachTow`
  (scripted scenes only), signal `VehicleSpawned (player, model)`. Model attributes `VehicleId`, `Owner`,
  `Capacity`, `SurvivorCount`; hull attachments `SurvivorSlot1..n`, `PetSeat`, `TowHitch`, `BowPoint`.
- Capacity is the depth: jet ski 1, RIB 3, lifeboat 8 (`VehicleConfig`). `Boat/Buoyancy`,
  `Boat/Simulator`, `Boat/Unstick`, `Boat/Helm` are pure and tested in `tests/Boat*.spec.luau`.
- Seated launches (berth Launch, Quick Launch; the phone's Boat to me `RequestVehicle(nil, false, true)` brings
  your current or last craft to the open water nearest you first; free calls wait
  `MonetizationEffects.BOAT_TO_ME_COOLDOWN`, player attribute `BoatToMeAt`, Quick Launch skips it) float the craft in open water off the player's berth, bow to sea, never overlapping a vehicle. Off your craft: `[E] Board` from 30
  studs and a `CraftPin` billboard (seat pips). Dock Lv 2+ (WP-11a): your current craft stays out beside a new
  one (2 craft; a docked second moors along the pontoon when the berth is taken); berth Launch hides locally while you have a craft out and on
  other players' berths. With no craft, point the craft pin at `BayCFrame`.
- Hangar and sub pen craft (docs/23 h): `VehicleConfig.CraftOrder` (RescueHelicopter, Submarine;
  `spec.craft` = Heli / Sub; `VehicleConfig.Order` stays boats only). Built and idled by
  `Services/Vehicle/Craft` (an empty heli auto-lands to its hover floor, an empty sub holds depth); a heli
  launches hovering over the berth. Who boards which craft: `Ops/CraftBoard.ready` (heli winch, sub ring;
  boats `Board.ready`), used by `AmbientRescueService.StepBoarding` and `auto_board`. A local `Airborne`
  model attribute (HeliController) blocks stepping out mid-air (VehicleExitController, OpsController).
- Crowding (`src/shared/Crowding.luau`, `tests/Crowding.spec.luau`): player boats are collision group
  `PlayerBoat` (ghost through each other, BoatController eases them apart); idle-despawn
  timers, NPC traffic and small moored boats scale by `Crowding.scale(players)`; a boat on land
  past recovery (or empty there 6 s) despawns with `VehicleRecovery.poof`.
- Auto-recovery: `src/shared/VehicleRecovery.luau` (pure, `tests/VehicleRecovery.spec.luau`) puts a
  flipped, stuck or sunk vehicle back upright (timers + lift-and-settle path); VehicleService runs it.
- Upgrades: `src/shared/VehicleUpgrades.luau` (pure: Engine = speed, Hull = steady in waves, Fit = +1
  aboard on RIB and lifeboat), fitted by `UpgradeService` (`Upgrade_Buy`), saved as a bitmask in
  `data.vehicleUpgrades`.
- Cut 2026-10-25 (docs/23 k, restorable from tag `pre-hub-cut`): cars and land vehicles, the car garage, roads,
  streets, traffic, the town (Port Haven buildings, cottages, chandlery, ambient town crowd). Their Robux passes
  stay in `MonetizationConfig` with `ready = false`.
- Second cut 2026-10-25 (WP-20, same tag): the seaplane (`SeaplanePass` stays, `ready = false`), land and
  cliff calls, the NPC racer, the first-person camera and viewmodel (the camera is third-person only),
  photo mode, rare rescue variants and their dressing (and the Legendary sky flare, PhotoFirst /
  LegendaryRescue / GoldenGull badges). Saved profile keys are untouched.

## Operations (simple rescue)

Every op runs the same 4-step plan (`src/shared/Ops/Definitions/SimpleSteps.luau`, docs/23 (e)):

| Step | Mechanic (`src/client/Mechanics/`) | What happens |
|---|---|---|
| `tasking` | `answer` | the call is answered (auto-accepted when seated and heading to it, or R / tap) |
| `launch` | `launch` | get aboard your craft (a `RequestVehicle` from anywhere) |
| `recovery` | `auto_board` | drive up close and steady: survivors climb aboard if there is room (`effect = "board"`) |
| `transport` | `transport` | bring them to a drop-off pad (`effect = "deliver"`) |

`recovery` and `transport` loop per survivor (`perCasualty`): a full craft goes home and comes back.

- Kinds (`Ops/Definitions`): PersonInWater, RipCurrent, SinkingVessel, VesselFire, WildlifeRescue, Diver,
  CapsizedFerry (big call; relay -> [pickup -> movement]* -> account). The scene is spectacle only:
  `server/Ops/{SinkingScene,FireScene,RipFlow}`.
- Diver at a Wreck (docs/23 (h) "Sub pen", WP-10c): kind `Diver` at a `CallTypes.DiveSites` wreck (mail
  seaplane, *Gannet Star*, Wreck Reef hulk; 25+ studs down). Offered only to Submarine owners from call 3
  (`CallLogic.chooseCall(..., sub)`, `DIVER_CHANCE` ~1 in 6, within reach). Pin = the surface over the wreck.
  The casualty is a normal RescueService swimmer held on the seabed (`call.dive`, floater `fixedY`);
  `server/Ops/DiverRescue` adds the ring (always-on-top Highlight), shot line and buoy, tank/mask/bubbles,
  and the placeholder hulls (`BuildWrecks`). Only the sub boards them (`CraftBoard.DEEP`); normal Home.
  Each wreck is a bonus `Wreck` sticker on its island's album page (`DiscoveryRules`, not needed to
  complete the page; `DiscoveryConfig.Range.Wreck`).
- Shared data: `Ops/Types`, `Operations` (registry, `plan`), `Condition` (0-100 meter; survivors tire),
  `Grading` (step and op grades, `payout`), `Board` (pure auto_board rule: close, slow, level, room).
- Call positions (docs/23 (p), WP-27): calls count from the owner's berth (`CallLogic.homeOf(BayCFrame)`, Plot1's
  without one). Calls 1-2 (`Near`, `CalmBay`) spawn 150-300 studs straight out of that cove (coves face out to
  sea); later calls in the outer ring (1,200+ from the ring centre: open-sea rings round the berth by reach, every
  outer island whose centre is in reach). No calls inside the ring (`CallLogic.isWater`: radius < `HubLayout.Ring`).
  Fixed sites: the ferry 1,000 studs south of the centre (`FerrySite`), the rip off Puffin Isle's beach
  (`BeachRip`, `RipCurrent.Beach`). Home = your own berth's drop-off zone only (`ColdOpen.atDropOff`; the cold open
  lands at your own `ColdOpen.SHORE` point); a call landed away from the berth pays for the trip sailed
  (`deliveredPay`).
- `OperationService` (server): offers and pacing (`Calls/CallLogic`, `Calls/OfferPacing`), tracks, the
  condition tick and takeover, pay at the debrief. The Capsized Ferry big call runs on its own clock
  (`OfferPacing.nextBigCallAt`, calm weather; paged only to players past the tutorial chain, with a
  `SkyFlare.distress` flare and horn). API: `GetActiveOperations()`, `GetOperationOf(player)`,
  `GetVictimPositions(player)`, `OperationCompleted (info, helpers)`, `ForceBigCall()`, `DevStart`,
  `StartColdOpen(player, cframe?)`, `ColdOpenHoldsWeather()`. Studio: `ServerStorage.OpsDev`
  (`timescale`, `start`, `coldopen`, `status`); `python3 tools/studio/smoke.py ops`.
- `RescueService`: the scene (rigged swimmers, drift, waving, boarding, pad delivery); `PiwRescue` /
  `PiwWays` make a survivor answer the boat (`PIW_Rescue` C->S `arm` / `bump`).
- Takeover: a casualty at Critical or the cap ends a normal call unpaid at once (`finish(op, "Takeover")`,
  the "Too slow" debrief); never on the cold open and the next three calls. Call spots must be reachable by
  water from the bays (`clearSpawn`). Studio: `OpsDev` `start <kind> <zone>`, `victims`.
- Free-roam swimmers (K13): `AmbientRescueService` keeps up to 4 mission-less swimmers; one is always
  visible from the harbour mouth; boarded server-side with `Ops/Board`, paid on delivery.
- Wildlife (K16): `SanctuaryService` dresses the WildlifeRescue survivor as an animal (`WildlifeRig`); it
  rides home on the craft, recovers in `PetService`'s sanctuary, then follows you as a pet.

### Ops remotes (`src/shared/Ops/Remotes.luau`)

| Remote | Dir | Payload |
|---|---|---|
| `Ops_Offered` | S->C | `{ opId, kind, title, zoneName, position, isBig, offerExpiresAt, cash, rep }` |
| `Ops_Accept` | C->S | `(opId)` |
| `Ops_State` | S->C | the operation snapshot for this player |
| `Ops_StepStart` | S->C | the mechanic `ctx` (`operation`, `step`, `casualty`, `vehicle`, `attempt`, `scene`) |
| `Ops_StepResult` | C->S | `(opId, stepKey, { metrics, events?, failed?, stub? })` |
| `Ops_StepAck` | S->C | `{ opId, stepKey, accepted, grade?, reason? }` |
| `Ops_Debrief` | S->C | `{ opId, kind, grade, stepGrade, reason, takeover?, steps, condition, saved, total, cash, rep, tip, me }` (drawn as stars, Cash and mastery icons, K5) |
| `Ops_Closed` | S->C | `{ opId, reason }` |

Client: `OpsController` plays one mechanic per step (`{ start(ctx, finish) -> cleanup? }`, fallback
`Mechanics/Default`); UI in `UI/OpsHud`, `OpsTaskingCard` (pager icon), `OpsStepCard` (icon + at most 2
words, K4), `OpsDebrief`; `OpsController` mounts `OpsHud`. No dispatch radio (owner, 2026-10-25): a new call is the
pager card, its flare and pin, and a pager beep. Voices are NPCs only: `VoiceTTS` + `UI/VoiceCast` (TalkController,
casualty shouts in CasualtyController).

## First 10 minutes (docs/00 §3, docs/23 (a)-(e))

- Loading screen (`src/first/LoadingScreen.client.luau`, ReplicatedFirst): overlay + bar while it preloads
  and streams the ring centre and the player's island, the camera circling the ring of islands; then a flyover
  (`src/shared/LoadingPath.luau`, `tests/LoadingPath.spec.luau`) down past the name sign to behind the
  character, or behind the cold-open jet ski on a first session. While it runs the LocalPlayer has
  `LoadingScreenActive` (CameraController stands down, no cold-open cinematic) and `CinematicPlaying` (the
  HUD hides). Reduced motion: a plain fade.
- Cold open (B0, B1): `StartColdOpen` seats a new player on a jet ski (`VehicleService.SpawnColdOpen`) with
  a swimmer ahead; auto_board, the slipway pad, `ColdOpenCue` world cues, `OnboardingReward` coins. The
  jet ski stays with the player after (`ColdOpenFlow` handover `Ride`). Profile `coldOpenDone`.
- `src/shared/Onboarding.luau` (pure, `tests/Onboarding.spec.luau`): `goal()` is the next tutorial call
  (`CallTypes.TutorialChain`: Swimmer, DriftingCraft x1, DriftingCraft x2, Swimmer, WildlifeRescue) marked
  by a flare, the beacon and the minimap blip; `failsafeCall(n)` holds condition above Critical for the
  cold open and the next three calls. No text, no station walk, nothing holds offers.
- Beats: B4 capacity (red ring when the jet ski is full, RIB on the goal chip), B5 first upgrade (phone
  red dot, Vehicles opens on the affordable card), B7 the first island building (the Workshop), B8 daily crate at the bay,
  B9 first pet. `tests/NewPlayerPace.spec.luau` checks the pace.
- Bosun (K14): `DogService` / `DogController` (`Shared/Dog/BosunMotion`); he points and barks at the
  nearest survivor or flare when the player is idle (`DogPoint`).

## Progression and data

- `DataService`: `Get`, `MarkDirty`, `Save(player, release?, deadline?)`, `OnLoaded(fn)`,
  `CommitReceipt(player, purchaseId, grantFn)` (idempotent receipt ledger), `HasReceipt`; session locks;
  `tests/Data.spec.luau`.
- `ProgressionRules` (pure): `PlayerData { cash, vehicles, vehicleUpgrades, totalRescues, coldOpenDone,
  dockBuildings, crew, flags, cosmetics, badgeCounters?, badgesAwarded? }` (retired `rep`, `dockLevel`, `certs`,
  `certLive`, `exercises` are kept as saved, never read), `migrate` (retired gear is paid back; old dock levels
  map onto the tree), `snapshot` (cash, totalRescues, dockBuildings, vehicles, ...), `canBuyVehicle` (its
  building first), `vehicleLock`. `ProgressionConfig`: vehicle unlocks (`needs` building, Cash price).
- `ProgressionService`: `Award(player, cash, reason, flat?)` (storm, pass, friend and crew
  multipliers on Cash), `GetData`, `CanUseVehicle`, `OwnsVehiclePass`, `SetFlag`, `RecordTraining(player,
  grade)`, `Refresh`. leaderstats Cash + Rescued; player attribute `Rescued` (= totalRescues, the rescued
  badges). Studio: `ServerStorage.ProgressionDev`.
- Affordable (B5/B6): `src/shared/Affordable.luau` (pure, `tests/Affordable.spec.luau`): `cheapest(snapshot,
  passOwned)` is the cheapest unowned vehicle or upgrade the player can buy now; the Vehicles app's
  pulsing card reads it.
- Crew: `CrewService` (`GetCrew`, `IsCrewmate`, `Join`, `Leave`; "Join crew" prompt on multi-seat boats).
  Friends: `FriendService.Count(player)`, attributes `FriendCount` / `FriendBonus` (+% Cash,
  `Shared/FriendBonus`). Group reward: `GroupRewardService.IsMember` (+10% daily crate, checked on join).
- Daily crate (K12): `StreakService` + `StreakRules` / `StreakConfig`; the crate and its day-pip sign are
  client-built at the player's bay (`World/StreakCrate`, `World/StreakSign`).

## Menu (all menus, WP-23c: no phone)

`src/client/UI/Menu.luau`: the left grid of kit icon buttons (HudLayout region `menu`; touch: 4 x 2 above the thumbstick): Shop, Quests,
Album, Pet, Crew, Settings, Map, Boat (Boat to me: `RequestVehicle(nil, false, true)`, the server's cooldown
via `MonetizationEffects.boatToMeWait` x player attribute `WorkerBoatScale`, Quick Launch bolt). Each opens a kit Panel
(`UI/Kit/`): `UI/Panels/Shop` (tabs Passes / Packs / Boosts / Day from `ProductShelves.storeItems`),
`Panels/Quests`, `Panels/Album` (sticker pages), `Panels/Companion` (Bosun or one pet; `Pet_Equip`),
`Panels/Crew` (party seats + your workers by category), `SettingsPanel.newPanel`; dock boards open `UI/BoatCard` via
`Menu.openBoat(id)`. Keys: P Shop, gamepad Start Settings, D-pad Left focuses the column, B closes.
Player attribute `MenuOpen` while a panel is up.

## HUD and map

- HUD (K10): menu column, wallet (Cash), objective strip, minimap (no radio strip, no goal chip).
  `src/shared/HudLayout.luau` (pure) places the regions per device; on touch nothing overlaps Roblox's thumbstick or
  jump zones, landscape or portrait (`tests/HudLayout.spec.luau`).
- `MapController` (minimap and full map on M / Select / tap), `MapService`, `MapConfig` (styles, blips);
  `SetBlips(group, items)` for static blips (seamarks). Player attributes `MapWaypoint`, `MapOpen`.
  The one objective pin (`GetObjective`, docs/archive/20-clarity-redesign.md rule 1): your accepted call, then your quest (`QuestTarget`),
  then a call offer, then your own waypoint. An offer never takes the pin from a quest.

## Monetization and cosmetics

- `MonetizationConfig` (`Products` / `GamePasses`, `id = 0` or `ready = false` = not for sale),
  `MonetizationService` (`OnProduct`, `OnPassOwned`, `OwnsPass`; receipts through
  `DataService.CommitReceipt`), effects in `src/shared/MonetizationEffects.luau` (Cash only). Player attributes `Pass_<Key>`, `PassesChecked`.
- Cosmetics: `src/shared/Config/Cosmetics/*` (one slot per file), `src/shared/Cosmetics.luau` registry,
  `CosmeticsService` (`Cos_<Slot>` attributes), `CosmeticsController`, `CosmeticLoadout` (earned rewards).

## Other systems

- The ring of six islands (docs/23 (p), WP-27): `src/shared/Config/HubLayout.luau` (pure, `tests/HubLayout.spec.luau`
  checks it against the bake), built from the generated `WorldConfig.Ring`: `Center` (the open lagoon, no island),
  `Ring` (470), `Islands` / `byId` (Plot1..6: center, facing (out to sea), frame, spawn, berths Boat / Sub, lots
  Station, Boathouse, PaintBooth, Helipad (clearRadius 45), Hangar, SubPen, Jetty, BlueprintTable, CrewQuarters,
  LifeguardTower, Spare1..3, QuestTablet; `quest` = { pontoon, slots }), `Bridges` (island i -> i + 1, a full ring)
  + `deckY` / `deckAt`. `server/World/Bridges` builds the six Lego neighbour bridges (11.3 deg ramps, ~20 studs
  under the crest; WorldDressingService I2 list). WP-24: the islands are flat Lego plates, not terrain: `IslandPlate`
  (footprint rects, topY, thick, chamfer, notch) + `onPlate` / `plateContains`; `server/World/IslandPlates` builds
  one Persistent `Plate<n>` model per `Islands` entry (I2 list). `map/Build.luau` builds `Map.Spawns` (one neutral
  SpawnLocation per island spawn); the main bake window is open water (a sand seabed ~Y -37). LeaderboardService
  stands a rescue board beside every island's spawn. The hub forest island (HQ hut, call board, market stall,
  harbourmaster, campfire, monument, quest camps, hidden spots, its drop-off pad, the forest trees, Chief Aggie and
  the station crew) was removed in WP-27 (git tag `pre-hub-cut` has the town; history has the hub).
- Pets and sanctuary: `PetService`, `PetRules`, `PetSeat`, `PetAccessory`, `PetController`.
- Workers (docs/23 (o), WP-26; replaced the WP-15 crew lineup, old hires paid back on load): `shared/WorkerRules`
  (pure, `tests/WorkerRules.spec.luau`: roll, admit at the cap, assign, effects, offline pay, clean). RescueService
  rolls a survivor on pick-up (model attributes `WorkerCategory` / `WorkerRarity` / `WorkerName`, tag `WorkerBadge`)
  and calls `WorkerService.Recruit` when they land at the driver's berth. `WorkerService`: `data.workers`, published
  as data only (`ReplicatedStorage.Workers.<UserId>.<i>`: Configuration, attributes `Spot` feet CFrame at their
  building or the jetty, `Work`, `Rig`, `From`), 12 shared R15 templates in `ReplicatedStorage.WorkerRigs`
  (NpcFactory, built once), Gatherer pay, the Rescuers' NPC boat (`Workspace.Workers.<UserId>`), offline pay on
  join (`data.lastSeen`, stamped by `DataService.Save`; attribute `WorkerOffline`), effect attributes
  `WorkerBuildDiscount` (DockService / `UnlockTree.canBuy` discount, build tablet, BuildSeq pace), `WorkerBoatScale`
  (VehicleService, UI/Menu), `WorkerCraftSpeed` (boat `SpeedMultiplier`), `WorkerPayBonus` (OperationService
  debrief). Client: `UI/WorkerBadge` (icon + stars billboard), `WorkerController` (clones the rigs into
  `Workspace.WorkersLocal` within 200 studs, animates within 90, walks them on cached PathfindingService routes,
  work props). Studio: `WorkerDev` `"fill"` / `"unfill"` (31 fake workers on all 6 islands). Robux product `CrewHire`
  retired (`ready = false`).
- Exploration album and map fog (docs/archive/21-explore-world-plan.md §3): `Config/DiscoveryConfig` (pages, ranges, Cash, fog grid),
  `DiscoveryRules` (pure: sighted / reached / stickers, flags `isles` and `fog`), `DiscoveryService`
  (server-observed positions only; `Workspace.Discovery` placeholder props; remotes `Discovery_State`,
  `Discovery_Found`, `Discovery_Get`), `DiscoveryController` (`IsRevealed(cell | islandId)`, `IsStamped`,
  `CellOf`, `State`, `Changed` for the map fog), `UI/Sticker` (art, stamp slam), `UI/Panels/Album`. The full map draws the fog (coarse cells).
- Talk: `src/shared/Dialogue.luau` (tree types, `check` / `choose`; the only trees are the quest givers' from
  `Quests/Rules.talk`); `TalkController` zooms in and shows 1 to 3 numbered replies.
- Quests (docs/23 (l) + (p), WP-21b / WP-27): `src/shared/Quests/Data.luau` (6 givers, 13 quests: find / deliver / salvage /
  rescue, Keeper Ives' 3-step lamp chain) and `Quests/Rules.luau` (pure, `tests/Quests.spec.luau`: one active quest,
  stages go -> back, one offer per giver per day from a day seed, a giver's pool cycles once all are done, save flag
  `quest`, `talk(npc, active, stage, offer)` -> a Dialogue tree whose replies carry `action`). Quests come to you:
  `server/World/QuestPontoons` builds each island's Lego quest pontoon (`HubLayout.Islands[i].quest.pontoon`) and
  quest tablet (`lots.QuestTablet`, part `QuestTablet`) in `Workspace.QuestPontoons.Island<i>`, and sails the givers'
  boats (`Workspace.QuestBoats`; the NpcFactory R15 rig rides in `Workspace.Npcs`, named by npc id, attributes
  `QuestIsland`, `Moored`, `Leaving`) in from 400 studs out to the 3 `quest.slots` and off again. `QuestService` keeps
  each claimed island's boats to its owner's active giver first, then that owner's offering givers (max 3); a
  hand-in sends that boat off and the next one in; unclaimed islands have none. It runs pick-up / drop / sub-salvage by
  proximity and the rescue quest's call (`OperationService.OfferCall(player, "PersonInWater", { zone })`, done on
  `OperationCompleted` with a survivor saved), pays flat Cash on hand-in and adds the chain's blueprint to
  `data.dockBuildings` (`DockConfig.Blueprints`, built by `DockService.Refresh`). Remote `Quest_Talk` C->S
  `(npcId, "accept" | "handIn" | "drop")`: only for a giver moored at the sender's own island, from within 16 studs of
  it or of their own quest tablet. Player attributes `QuestId`, `QuestStage`, `QuestTarget`,
  `QuestOffer_<npcId>`. `QuestController` draws the "!" / "?" over your own island's givers and puts the Quests
  prompt on your own tablet, which opens `UI/QuestTablet` (Kit panel of cards: tap focuses the giver's boat via
  `CameraController.SetOverride`; Accept / Hand in / Drop). `TalkController` builds a giver's tree from
  `Quests/Rules.talk` (another island's givers: the idle line only). No radio: every quest line is the giver's, in
  person. Studio: `ServerStorage.QuestDev:Invoke("accept", npcId | "tablet" | "tp" | "reach" | "hand" | "chain" |
  "reset")`.
- Badges and leaderboards: `BadgeConfig` (keys are stable; id 0 = off), `BadgeRules`, `BadgeService`
  (`Award`, `Count`, `Once`, `Has`), `LeaderboardService`.
- Analytics: `TelemetryNames` (fixed name lists), `Telemetry/Events` (pure funnel and economy mapping),
  `TelemetryService` (the only `AnalyticsService` caller), client `src/client/Telemetry.luau` (`once`,
  `send`, `shop` over `Telemetry_Client`: RewardSeen, Device, Shop, InputDead,
  StuckReset; values checked server-side). Spec and Phase 2 hook list: `docs/research/analytics.md`.
- Settings: `SettingsRules` (pure), `Camera/Comfort` (saved in `flags.cameraSettings`), `SettingsPanel`,
  `A11yPalette` (colour-blind palette and glyphs).
- Re-engagement: `PlatformPrompts` + `PlatformPromptService`; `NotifyDue` + `NotifyService`.
- Swimming: `SwimController` with `src/shared/Explore/Snorkel.luau` (surface float, face-down look).
- Audio: `AudioConfig`, `AudioController`, `VoiceTTS`.
- World: `WorldService`, `server/World/*` (dressing, swaps, rigs; `TownBuildings` / `CottageRig` /
  `StreetFurniture` now only dress the islands), `map/Build.luau` (greybox), `TerrainOnly`, ambient wildlife
  services. `StreetController` turns the lighthouse beams and waves the beach flag.

## Dev board

Dev-only admin panel (exempt from the no-choice rule): `DevConfig` (access: Studio, listed user ids, group
rank >= 254; action specs and validation, `tests/DevBoard.spec.luau`), `DevService` (`Dev_Grant` S->C,
`Dev_Action` C->S function), `DevController` + `UI/DevBoard` (tabs Move, Teleport, Spawn, Ops, Cutscenes,
World, Progress, Server).
