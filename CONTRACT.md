# Build contract

Who owns what, and the APIs between modules, for the game as it is now (`docs/00-design.md` is the design
source of truth; `docs/23-dock-and-core-loop.md` is the change log). Use another module's API; don't edit its
files without a reason. Cut systems (Port Haven, cars, the phone, the dispatch radio, ranks and Rep, the hub
island, the crew lineup, the seaplane, land calls, first person, photo mode) live in git tag `pre-hub-cut` and in
history, not here.

## Rules (every module)

- No choice UI in gameplay: no menu, card or list where the player picks an option. Mechanics are world
  actions (drive, grab, hold), readable without text; a device glyph is fine. Menus live only in the left menu
  panels, the build tablet's build mode and in-world boards. Exception: talking to a quest giver shows numbered
  replies (docs/23 (l)).
- Show, don't tell: icons and 1 to 3 word labels; keyboard, touch and gamepad for every action.
- Placeholders (code-built Parts) until art lands; gameplay never waits on art. New things are Lego-style.
- Modules in `src/server/Services/` and `src/client/Controllers/` export `Init()` and `Start()` plus an
  optional `Priority` (lower first, default 100); `Main.server.luau` / `Main.client.luau` load every
  ModuleScript there (nested folders are private helpers). Deleting a module means deleting every `require`.
- Remotes: the shared ones are typed in `src/shared/Net.luau` (`Net.event(name)`, `Net.func(name)`); the ops
  ones in `src/shared/Ops/Remotes.luau`; a service may create its own `<Prefix>_<Name>` remote under
  `ReplicatedStorage.Net`. Every remote has a server handler and a client user; drop it with its last user.
  Saved-data keys and remote names never change without a migration.
- Studio hooks are `ServerStorage.<Name>Dev` BindableFunctions (OpsDev, DockDev, QuestDev, WorkerDev, ...).
- Gate: `~/RobloxProjects/tools/check.sh .` (stylua, selene, luau-lsp, Lune specs in `tests/`) must pass.
  Studio: `python3 tools/studio/smoke.py run` and `smoke.py ops`.

## Remotes

| Remote | Dir | Owner / payload |
|---|---|---|
| `VehicleSpawned` | S->C | VehicleService: `(model, bayName)` |
| `CrewJoin` / `CrewLeave` | both | CrewService: join `{ targetUserId }`; echo `{ leader, members }` |
| `PlayerDataChanged` | S->C | ProgressionService: the progression snapshot (plus `award`, `bought` extras) |
| `StormChanged` | S->C | StormService: one-shot cue per phase change |
| `DogPoint` | S->C | DogService: Bosun points at a survivor or flare |
| `RequestVehicle` | C->S fn | VehicleService: `(vehicleId, docked?, near?) -> (ok, reasonOrVehicle)`; `near` = Boat to me (id ignored) |
| `BuyGear` | C->S fn | ProgressionService: buys a craft (`vehicleId`); the name is historical |

Service-owned: `Progression_GetData`, `Camera_SaveSettings` (ProgressionService), `Upgrade_Buy` (UpgradeService),
`PIW_Rescue` (Ops/PiwRescue), `Dock_Upgrade` / `Dock_Build` (DockService), `Quest_Talk` (QuestService),
`Streak_State` / `Streak_Get` / `Streak_Open`, `Pet_State` / `Pet_Get` / `Pet_Equip`, `Cosmetics_Equip` /
`Cosmetics_Action` / `Cosmetics_Event`, `Monetization_GetCatalogue` / `Monetization_Purchased`,
`Discovery_State` / `Discovery_Found` / `Discovery_Get`, `PlatformPrompt_Ask` / `_Offer` / `_OptIn`,
`Telemetry_Client`, `Dev_Grant` / `Dev_Action`, and the `Ops_*` table below.

## World: the ring of player islands

- `src/shared/Config/RingLayout.luau` (pure, `tests/RingLayout.spec.luau` checks it against the bake), built from
  the generated `WorldConfig.Ring` (`tools/world/layout.py`): `Center` (the open lagoon), `Ring` (470),
  `Islands` / `byId` (Plot1..6: `center`, `facing` (out to sea), `frame`, `spawn`, `berths` Boat / Sub, `lots`
  Station, Boathouse, Helipad (`clearRadius`), Hangar, SubPen, Jetty, LifeguardTower, Spare1..3, QuestTablet;
  `quest` = { pontoon, slots }), `Bridges` (island i -> i + 1) + `deckY` / `deckAt`, `IslandPlate` + `onPlate` /
  `plateContains`, `seaRoute(from, to) -> (leg, length)` (round the plates, into a cove through its mouth).
- `WorldDressingService` places the world at run time: `server/World/Seamarks`, `CoastArt`,
  `SkerryLight`, `Islands` (one module per outer island: Penwyn, GannetRock, MermaidLagoon, ...), `Bridges` (the
  six Lego neighbour bridges), `IslandPlates` (one Persistent `Plate<n>` per island), plus the scattered rocks'
  collision hulls (`ScatterController` draws the meshes). Outer-island kits: `TownBuildings` (Penwyn's terraces),
  `CottageRig` / `CottageLights` (cottage glass, night lights, smoke), `StreetFurniture`, `SharedSetsRig`.
- `map/Build.luau` builds the greybox and `Map.Spawns` (one SpawnLocation per island spawn); the bake is open water
  with a sand seabed. Also `WorldService`, `TerrainOnly` (+ `TerrainOnlyService` / `TerrainOnlyController`),
  `StreetController` (lighthouse beams, beach flag), `SeamarkController`, `WildlifeController`,
  `WildlifeArtService`.

## Your island (DockService)

- `src/shared/Marina.luau` (pure, `tests/Marina.spec.luau`): `berth`, `spawn`, `assign` (lowest free island),
  `harbourMaster`, `lock`, `flagColor`. A joining player claims an island when the profile loads (freed on leave);
  what they built is `data.dockBuildings`.
- `DockService` API: `GetBerth(player) -> BasePart?`, `GetPlot`, `GetSpawn` (VehicleService stands every spawn
  there), `Owns(player, key)` (the pontoon's 2nd berth, the crane's no-wait relaunch), `Berths()`, `Refresh`.
  Player attributes `DockPlot`, `BayCFrame`, `Dock<key>` per building; berth attributes `LaunchBay`, `PlotIndex`,
  `Owner`, `<key>`, `HarbourMaster`.
- Unlock tree (docs/23 (q)): `src/shared/Config/DockConfig.luau` `Buildings` (one row per building: `name`,
  `desc`, `cash`, `needs`, optional `product` / `robux`, `spot` + `size` in the berth frame, `vehicles`, `worker`),
  `BUILDINGS` (card order), `LEVEL_ITEMS` (old dock level -> tree items, the save migration), decorations and
  `Blueprints` (quest-chain buildings). Rules: `src/shared/UnlockTree.luau` (pure, `tests/UnlockTree.spec.luau`):
  `missing`, `canBuy(key, owned, cash) -> ok, "Owned" | "Needs" | "Cash", price, need`, `canRobux` (Robux skips the
  Cash, never the order), `craftMissing`, `migrate(level, owned)`. Craft gates:
  `ProgressionConfig.Vehicles[id].needs`.
- `src/shared/DockPieces.luau`: `building(key, berthCFrame) -> Model` (the Lego set; doors in the owner's colour =
  parts named "Flag"), `base(berthCFrame)` (the fixed set on every plate), `trophies`, `buildStation`,
  `decoration`. A buy plays the Lego build: `Dock_Build` S->C `{ plot, parent, name }`, `shared/BuildSeq` drops
  the pieces client-side. `Dock_Upgrade` C->S fn `(key) -> ok, reason`; Robux = products with `dockBuilding`
  (keys `DockLevel2..5`, `DockHangar`, `DockSubPen`: the ids are the old dock levels'), granted once the
  prerequisites stand.
- Build tablet: the station tablet opens `DockController`'s top-down build mode (`DockBlueprints`: `onIsland`,
  `needs`, `glyph`, drawn by `UI/BuildGlyph`; `DockBuild`: camera and spot maths). `server/Dock/BoatBoard` builds
  every craft board (boat, hangar, sub) with scale models from `ReplicatedStorage.VehiclePreviews`; client
  `BoatBoardController` (owned: crane beat + `DockLaunch`; locked: `Menu.openBoat(id)`). The boathouse paint
  booth (`DockConfig.PAINT_BOOTH`) opens `DockController`'s paint card (`UI/CosmeticPicker`). Harbour Master:
  most people rescued among islands with a Station gets a gold name board and beacon.
- Studio: `DockDev:Invoke("building", key | "all")`, DevBoard "Build (target)".

## Craft (VehicleService)

- One craft out per player (two with the pontoon), always launched at the player's own berth (berth `Launch`
  prompt: the last-launched craft, `data.flags.lastVehicle`; the boat board; Boat to me; the cold open).
  Spawns are serialized per berth (`Marina.lock`). API: `GetBay`, `BerthLaunch(player, id) -> CFrame?`,
  `GetVehicle`, `GetDriver`, `GetOccupants`, `AddSurvivor(model, survivor) -> boolean` (false when full),
  `RemoveSurvivors`, `Climb`, `SpawnSeated`, `SpawnColdOpen`, `DevLaunch`, `DockLaunch(player, id, target?)`,
  `DockSpot(player, id) -> CFrame?`, `Stow`, `RefreshUpgrades`, `BuildProp`, signal `VehicleSpawned (player,
  model)`. Model attributes `VehicleId`, `Owner`, `Capacity`, `SurvivorCount`; hull attachments
  `SurvivorSlot1..n`, `PetSeat`, `BowPoint`.
- Boat to me: `RequestVehicle(nil, false, true)` brings your current or last craft to the open water nearest
  you; free calls wait `MonetizationEffects.boatToMeWait` (player attribute `BoatToMeAt`, scaled by
  `WorkerBoatScale`); the Quick Launch pass or day pass skips the wait.
- `VehicleConfig` (`Order` = boats, `CraftOrder` = RescueHelicopter, Submarine; capacity: jet ski 1, RIB 3,
  lifeboat 8). Pure, tested: `Boat/Buoyancy`, `Boat/Simulator`, `Boat/Unstick`, `Boat/Helm`, `Boat/RespawnPolicy`,
  `Boat/BayLaunch`, `Boat/Wake`, `Heli/Flight`, `Heli/Winch`, `Sub/Dive`. `Services/Vehicle/Craft` builds and
  idles the heli and sub; clients: `BoatController`, `HeliController`, `SubController`, `VehicleExitController`,
  `BeaconController`, `Camera/Chase`.
- `src/shared/Crowding.luau`: player boats ghost through each other (collision group `PlayerBoat`); idle timers
  scale with the player count. `src/shared/VehicleRecovery.luau`: flipped / stuck / sunk craft are put back
  upright; a boat beached past recovery goes with `poof`.
- Upgrades: `src/shared/VehicleUpgrades.luau` (Engine, Hull, Fit), fitted by `UpgradeService` (`Upgrade_Buy`),
  bitmask in `data.vehicleUpgrades`; sold on `UI/BoatCard`.

## Operations (calls)

Every op runs the same plan (`Ops/Definitions/SimpleSteps.luau`): `tasking` (`answer`) -> `launch` (`launch`)
-> `recovery` (`auto_board`: drive close and steady, they climb aboard if there is room) -> `transport`
(`transport`: home to your own berth's drop-off zone). `recovery` and `transport` loop per survivor. Calls never
fail: a slow one grades Bronze (`Condition.overdue`; the big call ends on its cap).

- Kinds (`Ops/Definitions`): PersonInWater, RipCurrent (off Puffin Isle's beach, `shared/RipCurrent`),
  SinkingVessel, VesselFire, WildlifeRescue, Diver (sub owners only, `server/Ops/DiverRescue`), CapsizedFerry (the
  big call on its own clock, `OfferPacing.nextBigCallAt`; `Ferry/FerryRig`, `Ferry/HullKnock`). Scenes:
  `server/Ops/{SinkingScene,FireScene,RipFlow}`.
- Shared data: `Ops/Types`, `Operations` (registry, `roll`, `atRisk`), `Condition`, `Grading` (step / op grades,
  `payout`, `mastery`), `Board` (the pick-up rule and ring: `ready`, `assistThrottle`, `RING`), `CraftBoard`
  (heli winch, sub ring).
- Call positions: `Calls/CallTypes` + `Calls/CallLogic` (pure, `tests/Call.spec.luau`): calls 1-2 just off your
  own cove; later ones in the outer sea by reach (the best craft you can launch); pay grows with distance. No calls
  inside the ring (`CallLogic.isWater`). Fixed sites: the ferry south of the ring, the rip off Puffin Isle.
- `OperationService`: offers and pacing (`Calls/OfferPacing`), the condition tick, pay at the debrief. API:
  `GetActiveOperations()`, `GetOperationOf(player)`, `GetVictimPositions(player)`, `OfferCall(player, kind,
  opts)`, `OfferBigCall`, `ForceBigCall()`, `StartColdOpen(player, cframe?)`, `ColdOpenHoldsWeather()`,
  `CanAct`, `RecordAction`, `OnVictimBoarded` / `OnVictimLost` / `OnVictimsDelivered`, `DevStart` / `DevEnd`,
  signal `OperationCompleted (info, helpers)`. Studio: `ServerStorage.OpsDev`.
- `RescueService`: the scene (rigged swimmers, drift, waving, boarding, delivery): `SpawnCall`, `BoardVictim`,
  `RemoveVictim`, `GetTargets`, `Cleanup`; `server/Ops/PiwRescue` / `PiwWays` make a survivor answer the boat
  (`PIW_Rescue` C->S). `NpcService` owns `Workspace.Npcs` (the cold open shore party; `server/Npc/NpcFactory`
  builds every R15 NPC from `Config/NpcOutfits`).
- Free-roam swimmers: `AmbientRescueService` keeps up to 8 mission-less swimmers, one in view off each
  player's cove; boarded with `Ops/Board`, paid on delivery.
- Wildlife: `SanctuaryService` dresses the WildlifeRescue survivor as an animal (`WildlifeRig`); it recovers in
  `PetService`'s sanctuary, then can follow you as your companion.

### Ops remotes (`src/shared/Ops/Remotes.luau`)

| Remote | Dir | Payload |
|---|---|---|
| `Ops_Offered` | S->C | `{ opId, kind, title, zoneName, position, isBig, offerExpiresAt, cash }` |
| `Ops_Accept` | C->S | `(opId)` |
| `Ops_State` | S->C | the operation snapshot for this player |
| `Ops_StepStart` | S->C | the mechanic `ctx` (`operation`, `step`, `casualty`, `vehicle`, `attempt`, `scene`) |
| `Ops_StepResult` | C->S | `(opId, stepKey, { metrics, events?, failed?, stub? })` |
| `Ops_StepAck` | S->C | `{ opId, stepKey, accepted, grade?, reason? }` |
| `Ops_Debrief` | S->C | `{ opId, kind, grade, stepGrade, reason, steps, condition, saved, total, cash, me }` |
| `Ops_Closed` | S->C | `{ opId, reason }` |

Client: `OpsController` plays one mechanic per step (`src/client/Mechanics/`: `{ start(ctx, finish) ->
cleanup? }`, fallback `Mechanics/Default`, helpers `Mechanics/PIW`); UI `UI/OpsHud` (mounts `OpsTaskingCard`
(the pager), `OpsStepCard`, `OpsDebrief`), `UI/Waypoint`, `PickupRingController` (the orange ring),
`CasualtyController` (strobes, shouts), `PyroController` (flares). A new call is the pager card, its flare and
pin, and a beep (no radio). Voices are NPCs only: `VoiceTTS` + `UI/VoiceCast`.

## First minutes

- Loading screen (`src/first/LoadingScreen.client.luau`): preloads, orbits the ring, then a flyover
  (`shared/LoadingPath`) down to the player's island. LocalPlayer attributes `LoadingScreenActive`,
  `CinematicPlaying`.
- Cold open: `StartColdOpen` seats a new player on a jet ski (`VehicleService.SpawnColdOpen`) with a swimmer just
  off their cove; `Boat/ColdOpen` (ease, drop-off), `Boat/ColdOpenFlow`, `UI/ColdOpenCue`, `UI/OnboardingReward`.
  Profile `coldOpenDone`.
- `src/shared/Onboarding.luau` (pure): `goal()` (the tutorial chain, `CallTypes.TutorialChain`), `failsafeCall`,
  `newPlayerHud`; `OnboardingController` + `UI/OnboardingBeacon`; `OnboardingWeather` keeps the cold open calm.
  `tests/NewPlayerPace.spec.luau` and `tests/Pacing.spec.luau` check the pace.
- Bosun: `DogService` / `DogController` (`shared/Dog/*`); he points at the nearest survivor or flare (`DogPoint`).

## Progression and data

- `DataService`: `Get`, `MarkDirty`, `Save(player, release?, deadline?)`, `OnLoaded(fn)`,
  `CommitReceipt(player, purchaseId, grantFn)` (idempotent receipt ledger), `HasReceipt`; session locks.
- `ProgressionRules` (pure): `PlayerData { cash, vehicles, vehicleUpgrades, totalRescues, coldOpenDone,
  dockBuildings, workers, flags, cosmetics, ... }` (retired `rep`, `dockLevel`, `crew`, `certs`, `exercises` stay
  as saved, never read), `migrate` (old dock levels onto the tree, old crew hires paid back), `snapshot`,
  `canBuyVehicle`, `vehicleLock`. `ProgressionConfig`: craft unlocks (`needs` building, Cash price).
- `ProgressionService`: `Award(player, cash, reason, flat?)` (storm, pass, friend and live-ops multipliers unless
  `flat`), `GetData`, `CanUseVehicle`, `OwnsVehiclePass`, `SetFlag`, `RecordTraining(player, grade)`, `Refresh`.
  leaderstats Cash + Rescued. Studio: `ServerStorage.ProgressionDev`.
- Workers (docs/23 (o)): `shared/WorkerRules` (pure: roll, admit, assign, effects, offline pay). RescueService
  rolls a survivor on pick-up (attributes `WorkerCategory` / `WorkerRarity` / `WorkerName`) and calls
  `WorkerService.Recruit` when they land at the driver's berth. `WorkerService`: `data.workers`, published as
  `ReplicatedStorage.Workers.<UserId>`, rigs in `ReplicatedStorage.WorkerRigs`, Gatherer pay, the Rescuers' NPC
  boat, `PayOffline` on join; effect attributes `WorkerBuildDiscount`, `WorkerBoatScale`, `WorkerCraftSpeed`,
  `WorkerPayBonus`. Client: `WorkerController`, `UI/WorkerBadge`. Studio: `WorkerDev` `"fill"` / `"unfill"`.
- Crew (players riding together): `CrewService` (`GetCrew`, `IsCrewmate`, `Join`, `Leave`). Friends:
  `FriendService.Count`, `shared/FriendBonus`. Group reward: `GroupRewardService` + `shared/GroupReward`.
- Daily crate: `StreakService` + `StreakRules` / `StreakConfig`; client `StreakController`, `World/StreakCrate`,
  `World/StreakSign`, `UI/StreakReward`.
- Quests (docs/23 (l), (p)): `Quests/Data` (6 givers, quest chains), `Quests/Rules` (pure, `tests/Quests.spec.luau`:
  one active quest, one offer per giver per day, `talk` -> a `Dialogue` tree). `server/World/QuestPontoons` builds
  each island's quest pontoon and tablet and sails the givers' boats in and out; `QuestService` runs the quest
  stages, pays on hand-in, adds a chain's blueprint to `data.dockBuildings`. `Quest_Talk` C->S `(npcId, "accept" |
  "handIn" | "drop")` (own island only, within 16 studs). Player attributes `QuestId`, `QuestStage`,
  `QuestTarget`, `QuestOffer_<npcId>`. Client: `QuestController`, `UI/QuestTablet`, `TalkController` (camera zoom
  + numbered replies, `shared/Dialogue`). Studio: `QuestDev`.

## Menu, HUD and map

- `src/client/UI/Menu.luau` (mounted by `HudController`): the left grid of kit icon buttons (HudLayout region
  `menu`): Shop, Quests, Album, Pet, Crew, Settings, Map, Boat (Boat to me). Panels (`UI/Kit/*`):
  `UI/Panels/Shop` (`ProductShelves.storeItems`), `Panels/Quests`, `Panels/Album`, `Panels/Companion` (Bosun or
  one pet; `Pet_Equip`), `Panels/Crew`, `SettingsPanel.newPanel`; `UI/BoatCard` via `Menu.openBoat(id)`. API
  `open`, `close`, `toggle`, `openBoat`, `isOpen`; player attribute `MenuOpen`. The quest tracker chip (region
  `quest`: island art, place, distance to `QuestTarget`; tap opens Quests) shows while a quest is active.
- `src/shared/HudLayout.luau` (pure, `tests/HudLayout.spec.luau`) places the regions (menu, wallet, objective,
  status, notice, prompt, minimap, gauges, right, quest) per device, clear of Roblox's thumbstick and jump zones;
  `UI/Layout` turns them into frames (`region`, `coldOpen`, `newPlayer`, `promptBusy`, `hudBoxes`: world pins keep out). `HudController`: wallet,
  award pops. `UI/HudTheme`, `UI/Kit/*` (Theme, Style, Panel, Card, PriceButton, IconButton, Tabs, ...),
  `UI/InputGlyph`, `UI/Glyph`.
- `MapController` (minimap and full map on M / Select / tap; `SetBlips`, `SetWaypoint`, `GetObjective`),
  `MapService`, `MapConfig`. The one objective pin: your accepted call, then your quest (`QuestTarget`), then a
  call offer, then your own waypoint. By boat the pin / line point at its next `RingLayout.seaRoute` leg.
- Album and map fog: `Config/DiscoveryConfig`, `DiscoveryRules` (pure), `DiscoveryService` (server-observed
  positions; `Discovery_*` remotes), `DiscoveryController` (`IsRevealed`, `IsStamped`, `State`), `UI/Sticker`,
  `UI/Panels/Album`.

## Monetization, cosmetics and the rest

- `MonetizationConfig` (`Products` / `GamePasses`; `id = 0` or `ready = false` = not for sale; cut passes stay
  recorded with `ready = false`), `MonetizationService` (`OnProduct`, `OnPassOwned`, `OwnsPass`, receipts through
  `DataService.CommitReceipt`; helpers `Monetization/Core`, `Monetization/CashEffects`), effects in
  `src/shared/MonetizationEffects.luau`, shelves in `src/shared/ProductShelves.luau`. Player attributes
  `Pass_<Key>`, `DayPass_<Key>`, `PassesChecked`.
- Cosmetics: `src/shared/Config/Cosmetics/*` (one slot per file), `src/shared/Cosmetics.luau` registry,
  `CosmeticsService` (loads every `server/Cosmetics/*` feature; `Cos_<Slot>` attributes), `CosmeticsController`
  (loads every `client/Cosmetics/*` feature), `CosmeticLoadout` (earned rewards), `LiveryPaint` / `LiveryPattern`,
  `VehicleSounds`, `LightBarFlash`, `ShantyRadio`, `AvatarCosmetics`.
- Pets: `PetService`, `PetRules`, `PetSeat`, `PetAccessory`, `PetController`.
- Weather: `src/shared/Weather.luau` reads `ReplicatedStorage.Weather` attributes; `WeatherMath`, `Waves`;
  `StormService` (`ForceStorm`, `ForceCalm`, `QueueSummon`; always sunny by default); `WeatherController`,
  `OceanController` (`GetVisualHeight`) + `client/Ocean/*`.
- Live ops: `LiveOps` (pure), `LiveOpsService`, `LiveOpsController`. Re-engagement: `PlatformPrompts` +
  `PlatformPromptService` / `PlatformPromptController`; `NotifyDue` + `NotifyService`.
- Badges and leaderboards: `BadgeConfig` (keys are stable; id 0 = off), `BadgeRules`, `BadgeService` (`Award`,
  `Count`, `Once`), `LeaderboardRules`, `LeaderboardService` (a rescue board beside every island's spawn).
- Analytics: `TelemetryNames` (fixed name lists), `Telemetry/Events` (pure mapping), `TelemetryService` (the only
  `AnalyticsService` caller), client `src/client/Telemetry.luau` (`once`, `send`, `shop`, `stalled` over
  `Telemetry_Client`; values checked server-side).
- Settings: `SettingsRules` (pure), `Camera/Comfort` (saved in `flags.cameraSettings`), `SettingsPanel`,
  `A11yPalette`. Camera: `CameraController` (third person only; `SetOverride`, `PlayCinematic`), `Camera/Cinematic`,
  `Camera/CameraMath`. Audio: `AudioConfig`, `AudioController`, `Audio/AudioMix`. Swimming: `SwimController` +
  `Explore/Snorkel`.

## Dev board

Dev-only admin panel (exempt from the no-choice rule): `DevConfig` (access: Studio, listed user ids, group rank
>= 254; action specs and validation, `tests/DevBoard.spec.luau`), `DevService` (`Dev_Grant` S->C, `Dev_Action`
C->S function), `DevController` + `UI/DevBoard` (Move, Teleport, Spawn, Ops, Cutscenes, World, Progress, Server).
