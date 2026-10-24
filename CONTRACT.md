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

## Shared remotes (`src/shared/Net.luau`)

| Remote | Dir | Owner / payload |
|---|---|---|
| `VehicleSpawned` | S->C | VehicleService: `(model, bayName)` |
| `CrewJoin` / `CrewLeave` | both | CrewService: join `{ targetUserId }`; echo `{ leader, members }` |
| `PlayerDataChanged` | S->C | ProgressionService: the progression snapshot (plus `rankUp`, `award`, `bought` extras) |
| `StormChanged` | S->C | StormService: one-shot cue per phase change |
| `DogPoint` | S->C | DogService: Bosun points at a survivor or flare |
| `RequestVehicle` | C->S fn | VehicleService: `(vehicleId, docked?, near?) -> (ok, reasonOrVehicle)` |
| `BuyGear` | C->S fn | ProgressionService: buys a vehicle (`vehicleId`); the name is historical |

Service-owned remotes: `Progression_GetData`, `Camera_SaveSettings` (ProgressionService), `Upgrade_Buy`
(UpgradeService), `Vehicle_QuickLaunch` (VehicleService), `Land_Request` / `Land_Control`
(LandVehicleService), `PIW_Rescue` (Ops/PiwRescue), `Ops_*` (below), `Streak_State` / `Streak_Get` /
`Streak_Open`, `Pet_State` / `Pet_Get` / `Pet_Equip` / `Pet_Treat`, `Cosmetics_Equip` / `Cosmetics_Action` /
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

- `VehicleService` (boats and jet skis): one vehicle per player. Each bay has one `Launch` prompt that
  spawns the player's last-launched craft (`data.flags.lastVehicle`, K3); switching craft is the phone's
  Vehicles app. A returning player (`coldOpenDone`) spawns on the pier at their bay with that craft docked
  beside them (K11); player attribute `BayCFrame`. API: `GetBay`, `GetVehicle`, `GetDriver`,
  `GetOccupants`, `AddSurvivor(model, survivor) -> boolean` (false when full), `RemoveSurvivors`, `Climb`,
  `SpawnSeated`, `SpawnColdOpen`, `QuickLaunch`, `Stow`, `RefreshUpgrades`, `AttachTow` / `DetachTow`
  (scripted scenes only), signal `VehicleSpawned (player, model)`. Model attributes `VehicleId`, `Owner`,
  `Capacity`, `SurvivorCount`; hull attachments `SurvivorSlot1..n`, `PetSeat`, `TowHitch`, `BowPoint`.
- Capacity is the depth: jet ski 1, RIB 3, lifeboat 8 (`VehicleConfig`). `Boat/Buoyancy`,
  `Boat/Simulator`, `Boat/Unstick` are pure and tested in `tests/Boat*.spec.luau`.
- Auto-recovery: `src/shared/VehicleRecovery.luau` (pure, `tests/VehicleRecovery.spec.luau`) puts a
  flipped, stuck or sunk vehicle back upright (timers + lift-and-settle path); VehicleService and
  LandVehicleService both run it.
- Upgrades: `src/shared/VehicleUpgrades.luau` (pure: Engine = speed, Hull = steady in waves, Fit = +1
  aboard on RIB and lifeboat), fitted by `UpgradeService` (`Upgrade_Buy`), saved as a bitmask in
  `data.vehicleUpgrades`.
- Land vehicles (`src/shared/Car/*`, `LandVehicleConfig`, `LandVehicleService`, `CarController`): pure
  chassis/tyre/drivetrain sims; `Land_Request (vehicleId, pointId?, withTrailer?)`, `Land_Control (action,
  value)`; trailer slipway launch calls `VehicleService.SpawnSeated`.

## Operations (simple rescue)

Every op runs the same 4-step plan (`src/shared/Ops/Definitions/SimpleSteps.luau`, docs/16 K1):

| Step | Mechanic (`src/client/Mechanics/`) | What happens |
|---|---|---|
| `tasking` | `radio_ack` | the call is answered (auto-accepted when seated and heading to it, or R / tap) |
| `launch` | `launch` | get aboard your craft (a `RequestVehicle` from anywhere) |
| `recovery` | `auto_board` | drive up close and steady: survivors climb aboard if there is room (`effect = "board"`) |
| `transport` | `transport` | bring them to a drop-off pad (`effect = "deliver"`) |

`recovery` and `transport` loop per survivor (`perCasualty`): a full craft goes home and comes back.

- Kinds (`Ops/Definitions`): PersonInWater, RipCurrent, SinkingVessel, VesselFire, CliffCasualty (sea
  side), WildlifeRescue, CapsizedFerry (big call; relay -> [pickup -> movement]* -> account). The scene is
  spectacle only: `server/Ops/{SinkingScene,FireScene,RipFlow}`, `RescueDressing` (rare variants).
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
- NPC racer (K15): `server/Ops/NpcPickup.luau`, balance in `shared/Calls/RaceRules.luau` (Lune-tested).
  From the player's 4th call an NPC RIB idles off the bays with its siren on, casts off after a head start
  that leaves a straight-driving player (base craft) at most 70% of its time, runs below every base craft's
  speed through the harbour mouth, and with a wake toward the first casualty; if it gets there first it
  takes them and the call ends unpaid. No racer for 2 calls after a loss or where the water route is
  blocked (call spots must be reachable from the bays: `clearSpawn`). Studio: `OpsDev` `start <kind>
  <zone>`, `victims`; the server prints `[Race]` start delay and both arrival times. A taken-over call is always picked up by an NPC boat (never a drowning).
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
  passOwned)` is the cheapest unowned vehicle or upgrade the player can buy now; the phone's red dot and
  the Vehicles app's pulsing card read it.
- Crew: `CrewService` (`GetCrew`, `IsCrewmate`, `Join`, `Leave`; "Join crew" prompt on multi-seat boats).
  Friends: `FriendService.Count(player)`, attributes `FriendCount` / `FriendBonus` (+% Cash,
  `Shared/FriendBonus`). Group reward: `GroupRewardService.IsMember` (+10% daily crate, checked on join).
- Daily crate (K12): `StreakService` + `StreakRules` / `StreakConfig`; the crate and its day-pip sign are
  client-built at the player's bay (`World/StreakCrate`, `World/StreakSign`).

## Phone (all menus)

`src/client/UI/Phone.luau`: a portrait iPhone (P, gamepad L1, or the phone button left of the HUD). Six
apps (K9): Map, Vehicles, Store, Crew, Camera, Settings; dock Map, Vehicles, Store, Camera. The red dot and
bounce mean "something is affordable" and badge the Vehicles icon. `UI/VehiclesApp` (boats, jet skis,
cars: Spawn, Cash and Robux buy, upgrades), `UI/StoreApp` (every live product), Settings borrows
`SettingsPanel`, Map opens `MapController`, Camera opens `PhotoMode`.

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

- Pets and sanctuary: `PetService`, `PetRules`, `PetSeat`, `PetAccessory`, `PetController`.
- Talk: `src/shared/Dialogue.luau` trees keyed by NPC model name (`Workspace.Npcs`, `NpcService`);
  `TalkController` zooms in and shows 1 to 3 numbered replies.
- Badges and leaderboards: `BadgeConfig` (keys are stable; id 0 = off), `BadgeRules`, `BadgeService`
  (`Award`, `Count`, `Once`, `Has`), `LeaderboardService`.
- Analytics: `TelemetryNames` (fixed name lists), `Telemetry/Events` (pure funnel and economy mapping),
  `TelemetryService` (the only `AnalyticsService` caller), client `src/client/Telemetry.luau` (`once(name)`
  over `Telemetry_Client`: RewardSeen, PhotoModeOpen, PhotoTaken (First Shot badge), PetPetted).
- Settings: `SettingsRules` (pure), `Camera/Comfort` (saved in `flags.cameraSettings`), `SettingsPanel`,
  `A11yPalette` (colour-blind palette and glyphs).
- Re-engagement: `PlatformPrompts` + `PlatformPromptService`; `NotifyDue` + `NotifyService`.
- Swimming: `SwimController` with `src/shared/Explore/Snorkel.luau` (surface float, face-down look).
- Photo mode: `PhotoMath` + `UI/PhotoMode`. Audio: `AudioConfig`, `AudioController`, `VoiceTTS`.
- World: `WorldService`, `server/World/*` (dressing, swaps, rigs), `map/Build.luau` (greybox),
  `TerrainOnly`, `RoadNet`, traffic and ambient wildlife services.

## Dev board

Dev-only admin panel (exempt from the no-choice rule): `DevConfig` (access: Studio, listed user ids, group
rank >= 254; action specs and validation, `tests/DevBoard.spec.luau`), `DevService` (`Dev_Grant` S->C,
`Dev_Action` C->S function), `DevController` + `UI/DevBoard` (tabs Move, Teleport, Spawn, Ops, Cutscenes,
World, Progress, Server).
