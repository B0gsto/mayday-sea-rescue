# Build contract

Who owns what, and the APIs between modules, for the game as it is now (docs/16 is the design source of
truth). Use another module's API; don't edit its files without a reason. History of cut systems lives in
git and docs/16 section 2, not here.

## Rules (every module)

- No choice UI in gameplay: no menu, card or list where the player picks an option. Mechanics are world
  actions (drive, grab, hold), readable without text; a device glyph is fine. Menus live only in the phone
  (settings, Vehicles, Store, Crew) and outside play. Exception: talking to a town NPC shows numbered
  replies (docs/14 §2).
- Show, don't tell: icons and 1 to 3 word labels; keyboard, touch and gamepad for every action.
- Placeholders (code-built Parts) until art lands; gameplay never waits on art.
- Modules in `src/server/Services/` and `src/client/Controllers/` export `Init()` and `Start()` plus an
  optional `Priority` (lower first, default 100). `Main.server.luau`'s `require` is not xpcall-guarded:
  deleting a module means deleting every `require` of it.
- Remotes: the shared ones are typed in `src/shared/Net.luau` (`Net.event(name)`, `Net.func(name)`); a
  service may create its own `<Prefix>_<Name>` remote under `ReplicatedStorage.Net`. Every remote has a
  server handler or a client listener; drop it with its last user.
- Gate: `~/RobloxProjects/tools/check.sh .` (stylua, selene, luau-lsp, Lune specs in `tests/`) must pass.

## Core loop (docs/16 section 1)

A call goes up, you drive a craft near the survivors, they climb aboard by themselves, you bring them to a
drop-off pad and get Cash and Rep. Cash buys vehicles and upgrades in the phone; Rep raises your rank, and
rank unlocks bigger boats.
Pick-up ring (docs/23 e.1): `PickupRingController` draws an orange `Board.RING` ring on the water round every
survivor still in the water (grey while your craft is full) and `BoatController` runs the throttle through its
`Assist` (`Board.assistThrottle`: eases to `ASSIST_SPEED` by the ring). Ram knock-back only from `Board.KNOCK_RANK`.

## Shared remotes (`src/shared/Net.luau`)

| Remote | Dir | Owner / payload |
|---|---|---|
| `VehicleSpawned` | S->C | VehicleService: `(model, bayName)` |
| `CrewJoin` / `CrewLeave` | both | CrewService: join `{ targetUserId }`; echo `{ leader, members }` |
| `PlayerDataChanged` | S->C | ProgressionService: the progression snapshot (plus `rankUp`, `award`, `bought` extras) |
| `StormChanged` | S->C | StormService: one-shot cue per phase change |
| `DogPoint` | S->C | DogService: Bosun points at a survivor or flare |
| `RequestVehicle` | C->S fn | VehicleService: `(vehicleId, docked?, near?) -> (ok, reasonOrVehicle)`; `near` = Boat to me (id ignored) |
| `BuyGear` | C->S fn | ProgressionService: buys a vehicle (`vehicleId`); the name is historical |

Service-owned remotes: `Progression_GetData`, `Camera_SaveSettings` (ProgressionService), `Upgrade_Buy`
(UpgradeService), `Vehicle_QuickLaunch` (VehicleService), `PIW_Rescue` (Ops/PiwRescue), `Ops_*` (below), `Streak_State` / `Streak_Get` /
`Streak_Open`, `Pet_State` / `Pet_Get` / `Pet_Equip`, `Cosmetics_Equip` / `Cosmetics_Action` /
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

- `DockService` (docs/23 WP-1): the marina west of the west breakwater (`src/shared/Marina.luau`, pure,
  `tests/Marina.spec.luau`): 16 plots in two rows of 8 off a pontoon spine, each a deck strip + a water berth
  (Lv 1: bare jetty, name board, flag in the player's colour; empty plots are a plain jetty). A joining player
  gets the lowest free plot, freed on leave; `data.dockLevel` (default 1) is the level later packages build.
  API: `GetBerth(player) -> BasePart?`, `GetPlot`, `GetLevel`, `Berths()`. Player attributes `DockPlot`,
  `BayCFrame` (the berth CFrame); berth part attributes `LaunchBay`, `PlotIndex`, `Owner`.
- Dock levels 2..5 (WP-4): `src/shared/Config/DockConfig.luau` (pure, `tests/DockConfig.spec.luau`: Cash, rank,
  Robux, `canBuy`, `BOARD_SLOT` = the boat board's spot in the Lv 3 boathouse, berth frame) and
  `src/shared/DockPieces.luau` (`build(level, berthCFrame) -> Model`, placeholder Parts). DockService builds each
  owner's levels on their plot (everyone sees them, the new pieces rise in) and sets player attribute
  `DockLevel`; remote `Dock_Upgrade` C->S fn `(level) -> ok, reason` (Cash + rank); Robux = products
  `DockLevel2..5` (`MonetizationConfig`, `dockLevel` field, kept off the phone Store); rescue boards show
  `badgeCounters.Rescue100`. `DockController` (client): the next level as a blue ghost on your own plot only, a
  `Build` prompt and the price card (Cash / Robux). Lv 4 skips VehicleService's relaunch cooldown. Studio:
  `ServerStorage.DockDev:Invoke("level", n)`.
- Dock buildings (docs/23 h, WP-10b): `DockConfig.Buildings` Hangar / SubPen (Cash + rank or Robux
  products `DockHangar` / `DockSubPen`, `dockBuilding` field; `canBuyBuilding`; the helipad needs
  Lv 3), owned in `data.dockBuildings`, geometry `DockPieces.building(key, frame)` + `DockPieces.Buildings`
  (prompt spot, board rack, spawn targets). Hangar + helipad on the boathouse roof, sub pen east of the jetty.
  `Dock_Upgrade(key)` buys one; berth attributes and player attributes `Dock<key>`; ghosts in `DockController`.
  `server/Dock/BoatBoard` builds every board (boat, hangar, sub) from one def list: the heli on the pad and the
  sub in the pen (`VehicleService.DockLaunch(player, id, target?)`), the seaplane at the berth. The car garage
  (`DockGarage`, data key `Garage`) was cut 2026-10-25: product kept with `ready = false`. Studio:
  `DockDev:Invoke("building", key | "all")`.
- Dock WP-13: plots are claimed when the profile loads (`GetBerth` claims earlier; nil before Init). Harbour
  Master = `Marina.harbourMaster` (highest rank among Lv 5 docks, ties keep the holder) on join / leave / level
  change: gold name board + tall gold flag, berth attribute `HarbourMaster`; a joining one gets the head plot
  (`Marina.HEAD`) if free, nobody else moves. Lv 5 trophy hall on the boathouse's jetty wall: `BadgeRules.trophies`
  cups + island-stamp plaques (`DockPieces.trophies`). Lv 3 paint booth (`DockConfig.PAINT_BOOTH`): seated in it
  on your own plot → `DockController` paint card (CosmeticPicker Livery + Decal). `MonetizationEffects.passActive`
  = pass or day pass (server `OwnsPass` and the client's Boat to me ring).
- `VehicleService` (boats and jet skis): one vehicle per player, always launched at the player's own berth
  (phone, Quick Launch, berth `Launch` prompt, the cold open via `BerthLaunch`). Spawns are serialized per berth
  (`Marina.lock`). Each berth has one owner-only `Launch` prompt that spawns the player's last-launched craft
  (`data.flags.lastVehicle`, K3); switching craft is the boat board (`server/Dock/BoatBoard` + client
  `BoatBoardController`, docs/23 WP-5: a rack of scale models on each owned plot, tag `BoatBoard`; owned →
  crane beat + `DockLaunch` docked at the berth, locked → the phone card via `Phone.openApp(name, mount)`). Every spawn stands the player on
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

Every op runs the same 4-step plan (`src/shared/Ops/Definitions/SimpleSteps.luau`, docs/16 K1):

| Step | Mechanic (`src/client/Mechanics/`) | What happens |
|---|---|---|
| `tasking` | `radio_ack` | the call is answered (auto-accepted when seated and heading to it, or R / tap) |
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
| `Ops_Offered` | S->C | `{ opId, kind, title, radioLine, zoneName, position, isBig, offerExpiresAt, cash, rep }` |
| `Ops_Accept` | C->S | `(opId)` |
| `Ops_State` | S->C | the operation snapshot for this player |
| `Ops_StepStart` | S->C | the mechanic `ctx` (`operation`, `step`, `casualty`, `vehicle`, `attempt`, `scene`) |
| `Ops_StepResult` | C->S | `(opId, stepKey, { metrics, events?, failed?, stub? })` |
| `Ops_StepAck` | S->C | `{ opId, stepKey, accepted, grade?, reason? }` |
| `Ops_Radio` | S->C | `{ opId, from, text }` |
| `Ops_Debrief` | S->C | `{ opId, kind, grade, stepGrade, reason, takeover?, steps, condition, saved, total, cash, rep, tip, me }` (drawn as stars, Cash and mastery icons, K5) |
| `Ops_Closed` | S->C | `{ opId, reason, message?, silent? }` |

Client: `OpsController` plays one mechanic per step (`{ start(ctx, finish) -> cleanup? }`, fallback
`Mechanics/Default`); UI in `UI/OpsHud`, `OpsTaskingCard` (pager icon), `OpsStepCard` (icon + at most 2
words, K4), `OpsDebrief`. Radio subtitles: `src/client/UI/RadioSubtitle.luau` (pure, ≤ 6 words, the voice
says the full line; `tests/RadioSubtitle.spec.luau`), lines in `RadioLines`, voiced by `VoiceTTS`.

## First 10 minutes (docs/16 section 4)

- Cold open (B0, B1): `StartColdOpen` seats a new player on a jet ski (`VehicleService.SpawnColdOpen`) with
  a swimmer ahead; auto_board, the slipway pad, `ColdOpenCue` world cues, `OnboardingReward` coins. The
  jet ski stays with the player after (`ColdOpenFlow` handover `Ride`). Profile `coldOpenDone`.
- `src/shared/Onboarding.luau` (pure, `tests/Onboarding.spec.luau`): `goal()` is the next tutorial call
  (`CallTypes.TutorialChain`: Swimmer, DriftingCraft x1, DriftingCraft x2, Swimmer, WildlifeRescue) marked
  by a flare, the beacon and the minimap blip; `failsafeCall(n)` holds condition above Critical for the
  cold open and the next three calls. No text, no station walk, nothing holds offers.
- Beats: B4 capacity (red ring when the jet ski is full, RIB on the goal chip), B5 first upgrade (phone
  red dot, Vehicles opens on the affordable card), B7 rank-up (`RankCeremony`), B8 daily crate at the bay,
  B9 first pet. `tests/NewPlayerPace.spec.luau` checks the pace.
- Bosun (K14): `DogService` / `DogController` (`Shared/Dog/BosunMotion`); he points and barks at the
  nearest survivor or flare when the player is idle (`DogPoint`).

## Progression and data

- `DataService`: `Get`, `MarkDirty`, `Save(player, release?, deadline?)`, `OnLoaded(fn)`,
  `CommitReceipt(player, purchaseId, grantFn)` (idempotent receipt ledger), `HasReceipt`; session locks;
  `tests/Data.spec.luau`.
- `ProgressionRules` (pure): `PlayerData { cash, rep, vehicles, vehicleUpgrades, totalRescues, coldOpenDone,
  flags, cosmetics, badgeCounters?, badgesAwarded? }` (retired `certs` / `certLive` / `exercises` are kept
  as saved, never read), `migrate` (retired gear is paid back), `snapshot`, `rankIndex` (Rep only, K7),
  `canBuyVehicle`. `ProgressionConfig`: ranks Recruit to Admiral, Service Stars, vehicle unlocks (RIB rank
  2 for 2,500 Cash).
- `ProgressionService`: `Award(player, cash, rep, reason, flat?)` (storm, pass, friend and crew
  multipliers on Cash), `GetData`, `CanUseVehicle`, `OwnsVehiclePass`, `SetFlag`, `RecordTraining(player,
  grade)`, `Refresh`, `RankChanged`. Studio: `ServerStorage.ProgressionDev`.
- Next goal (K6): `src/shared/NextGoal.luau`: the next rank or the next vehicle, nearest first.
- Affordable (B5/B6): `src/shared/Affordable.luau` (pure, `tests/Affordable.spec.luau`): `cheapest(snapshot,
  passOwned)` is the cheapest unowned vehicle or upgrade the player can buy now; the Vehicles app's
  pulsing card reads it.
- Crew: `CrewService` (`GetCrew`, `IsCrewmate`, `Join`, `Leave`; "Join crew" prompt on multi-seat boats).
  Friends: `FriendService.Count(player)`, attributes `FriendCount` / `FriendBonus` (+% Cash,
  `Shared/FriendBonus`). Group reward: `GroupRewardService.IsMember` (+10% daily crate, checked on join).
- Daily crate (K12): `StreakService` + `StreakRules` / `StreakConfig`; the crate and its day-pip sign are
  client-built at the player's bay (`World/StreakCrate`, `World/StreakSign`).

## Phone (all menus)

`src/client/UI/Phone.luau`: a portrait iPhone (P, gamepad L1, or the phone button left of the HUD). Six
apps (K9): Map, Vehicles, Store, Crew, Pets, Settings; dock Map, Vehicles, Store, Settings. The red dot is
off since buys moved to the dock boards (WP-11a). `UI/VehiclesApp` (phone: Boat to me + the
Boat to me only since WP-10b; a dock board opens one craft's card: Cash and Robux buy, upgrades), `UI/StoreApp` (every live product), `UI/PetsApp` (pick the one companion: Bosun or a
recovered pet; `Pet_Equip` 0 = Bosun, player attribute `CompanionPet`), Settings borrows
`SettingsPanel`, Map opens `MapController`. `UI/AlbumApp` is the sticker album
(docs/21 §3; a seventh app on the grid).

## HUD and map

- HUD (K10): wallet, rank bar, goal chip, objective strip, subtitle, minimap, phone button.
  `src/shared/HudLayout.luau` (pure) places the regions per device.
- `MapController` (minimap and full map on M / Select / tap), `MapService`, `MapConfig` (styles, blips);
  `SetBlips(group, items)` for static blips (seamarks). Player attributes `MapWaypoint`, `MapOpen`.

## Monetization and cosmetics

- `MonetizationConfig` (`Products` / `GamePasses`, `id = 0` or `ready = false` = not for sale),
  `MonetizationService` (`OnProduct`, `OnPassOwned`, `OwnsPass`; receipts through
  `DataService.CommitReceipt`), effects in `src/shared/MonetizationEffects.luau` (Cash only, never Rep or
  rank). Player attributes `Pass_<Key>`, `PassesChecked`.
- Cosmetics: `src/shared/Config/Cosmetics/*` (one slot per file), `src/shared/Cosmetics.luau` registry,
  `CosmeticsService` (`Cos_<Slot>` attributes), `CosmeticsController`, `CosmeticLoadout` (earned rewards).

## Other systems

- Hub and six islands (docs/23 (k), WP-18): `src/shared/Config/HubLayout.luau` (pure, `tests/HubLayout.spec.luau`
  checks it against the bake), built from the generated `WorldConfig.Hub`: `Hub` (center, frame, spawn, lots HQ /
  CallBoard / ShopCounter, dropOff), `Islands` / `byId` (Plot1..6: center, facing, frame, spawn, berths Boat / Sub,
  lots Station, Boathouse, PaintBooth, Helipad (clearRadius 45), Hangar, SubPen, Jetty, BlueprintTable,
  CrewQuarters, LifeguardTower, Spare1..3), `Bridges` + `deckY` / `deckAt`. `server/World/Bridges` builds the six
  suspension bridges from it (WorldDressingService I2 list). WP-19a: `map/Build.luau` builds `Map.Hub` (HubSpawn,
  greybox Station under `Swaps.Station`, CallBoard model tag `CallBoard`, ShopCounter whose prompt tag `ShopCounter`
  opens the phone Store via HudController, Quay dressing) and the only drop-off pad `Map.DropOffs.DropOff_Dock`
  (`DropOff = "Dock"`) at `HubLayout.Hub.dropOff`; StationRig puts the HQ radio in the hall (tag `StationRadio`).
  The old Port Haven harbour (Harbour.luau, breakwaters, slipway, hospital, moorings) is gone.
- Pets and sanctuary: `PetService`, `PetRules`, `PetSeat`, `PetAccessory`, `PetController`.
- Exploration album and map fog (docs/21 §3): `Config/DiscoveryConfig` (pages, ranges, Cash, fog grid),
  `DiscoveryRules` (pure: sighted / reached / stickers, flags `isles` and `fog`), `DiscoveryService`
  (server-observed positions only; `Workspace.Discovery` placeholder props; remotes `Discovery_State`,
  `Discovery_Found`, `Discovery_Get`), `DiscoveryController` (`IsRevealed(cell | islandId)`, `IsStamped`,
  `CellOf`, `State`, `Changed` for the map fog), `UI/Sticker` (art, stamp slam), `UI/AlbumApp` (phone Album).
- Talk: `src/shared/Dialogue.luau` trees keyed by NPC model name (`Workspace.Npcs`, `NpcService`);
  `TalkController` zooms in and shows 1 to 3 numbered replies.
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
