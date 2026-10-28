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
| `Spin_Wheel` | S->C | SpinService: one spin `{ userId, plot, segment, startTime, duration, prize, name, rarity, kind, icon, variant, option, vehicle, duplicateCash? }`; the island's wheel animates on every client |
| `Spin_Flex` | S->C | SpinService: a Legendary / Mythic win `{ userId, name, prize, rarity, icon }` (banner + confetti) |
| `Skill_Buy` | C->S fn | SkillService: buys a skill node with Medals `(id) -> (ok, reason)` |
| `Skill_Reset` | C->S fn | SkillService: free reset, refunds every Medal `-> (ok, refunded)` |
| `Skill_State` | S->C | SkillService: `{ owned, medals }` on join and after every buy/reset/grant |

Service-owned: `Progression_GetData`, `Camera_SaveSettings` (ProgressionService), `Upgrade_Buy` (UpgradeService),
`PIW_Rescue` (Ops/PiwRescue), `Dock_Upgrade` / `Dock_Build` / `Dock_Finish` (DockService), `Quest_Talk` (QuestService),
`Streak_State` / `Streak_Get` / `Streak_Collect`, `Pet_State` / `Pet_Get` / `Pet_Equip` / `Pet_Variant`, `Cosmetics_Equip` /
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
  Cash, never the order), `settle(owned, prepaid) -> built` (unused since timed builds), `craftMissing`,
  `migrate(level, owned)`. Craft gates:
  `ProgressionConfig.Vehicles[id].needs`.
- `src/shared/DockPieces.luau`: `building(key, berthCFrame) -> Model` (the Lego set; doors in the owner's colour =
  parts named "Flag"), `base(berthCFrame)` (the fixed set on every plate), `trophies`, `buildStation`,
  `decoration`, `lotMarker(berth, at, size)` (an empty lot's pad + peg flag), `quayBands(parent, berth) -> { Frame }`
  (the quay walks' owner-colour tiles). A buy plays the Lego build: `Dock_Build` S->C `{ plot, parent, name }`, `shared/BuildSeq` drops
  the pieces client-side. `Dock_Upgrade` C->S fn `(key) -> ok, reason`; Robux = products with `dockBuilding`
  (keys `DockLevel2..5`, `DockHangar`, `DockSubPen`: the ids are the old dock levels'); a receipt whose
  prerequisites are missing is granted as prepaid (`data.dockPrepaid`, tablet chip "Paid"), built the moment they stand.
- Timed builds (docs/24 B): every Cash or Robux buy starts a construction, one per island (`Dock_Upgrade` reason
  `"Building"` while one runs; a Robux buy then waits in `dockPrepaid`). `src/shared/BuildTimer.luau` (pure,
  `tests/BuildTimer.spec.luau`): `work(cash, decor)`, `builders(workers)`, `units`, `rate`, `rateOf`, `advance`,
  `timeLeft`, `finishTier`, `text`. Saved as `data.construction = { key, progress 0..1, rate, at (os.time) }`,
  advanced offline on join; not owned (`dockBuildings`) until it finishes. Plot model attributes `SiteKey`,
  `SiteProgress`, `SiteRate`, `SiteBuilders`, the rising model `Site_<key>` under the plot; client
  `ConstructionController` draws the site and the owner's "Finish" prompt, `DockController`'s tablet the timer and
  its FinishNow price. `Dock_Finish` C->S (no args) prompts `FinishNow1..3` by the site's current time left (the
  server picks; a client tier is ignored); the receipt finishes through the same path, or pays 10% of the build's
  Cash if the site already stood. Studio: `WorkerDev` `"finishbuild"`. Layered meshes (`Lv<k>_L<nn>_`) rise layer by
  layer; a level's site keeps the lower levels hidden (the standing building shows them).
- Depot art (docs/25 D, K4): `DepotArtService` sets `DockPieces.meshes` (the Depot is `M_Bld_Depot`, a hut until it
  loads; the Bunkhouse's Lv1-5 are `M_Bld_Bunkhouse`, `BunkhouseMesh`, kept 1x, a cottage until it loads) and publishes
  `ReplicatedStorage.DepotTemplates.Barge`. The Workshop's Lv2 saw-bench lean-to and Lv3 boat
  frame are `M_Bld_WorkshopAddons` (`WorkshopMesh`, kept 1x, inside the code yard; the yard's sawhorse, timber and old
  boat frame give way); its `ATT_Work_*` are the Builders' Lv2/Lv3 yard spots (`WorkerService`, from `AssetIds`). The Fish Market's Lv2 flank stalls and Lv3
  smokehouse are `M_Bld_FishMarketAddons` (`FishMarketMesh`, kept 1x, beside the code market, which stays Lv1; its
  drying rack gives way to the smokehouse); its `ATT_Work_*` are the Fishers' Lv2/Lv3 spots. The Clinic's Lv2 pavilion and Lv3
  hospital + ambulance are `M_Bld_ClinicAddons` (`ClinicMesh`, kept 1x, on the tent's flanks; the flagpole gives way at
  Lv2, the bloom patch and corner tree at Lv3); its `ATT_Work_*` are the Medics' Lv2/Lv3 spots. The Lookout's Lv2
  gallery + lantern and Lv3 searchlight (`Lv3_L04_Searchlight`, swept at night by `WorkerController`) + radar are
  `M_Bld_LookoutAddons` (`LookoutMesh`, kept 1x); its `ATT_Watch_*` are the first one (Lv2) / two (Lv3) Rescuers' spots. The Boat Yard's Lv2 portal crane + hoisted engine + tool bench
  and Lv3 dry dock are `M_Bld_BoatYardAddons` (`BoatYardMesh`, kept 1x, beside the code workboat; the code gantry and
  tool chests give way at Lv2, the east slip planks at Lv3; the name sign moves onto the crane girder); its `ATT_Work_*`
  are the Mechanics' Lv2/Lv3 spots. The Rescue Boathouse's Lv2 RIB pontoon (`Lv2_L04_RIB`) and Lv3 lifeboat berth
  (`Lv3_L03_Lifeboat`) are `M_Bld_RescueBoathouseAddons` (`RescueBoathouseMesh`, kept 1x, the pen's -X / +X sides; the
  lifeguard chair gives way at Lv3; `WorkerController` bobs the two boats within LIVELY); its `ATT_Work_*` are the
  Rescuers' Lv2/Lv3 spots. The HQ's Lv4 radio wing + mast and Lv5 beacon tower + bridge are `M_Bld_HQAddons` (`HQMesh`,
  the station's -X side, 49..61 studs out at Lv5; the code radio mast and gold ball are only its fallback;
  `WorkerController` lights `Lv5_L05_Beacon` at night). The Air Station's Lv2 refuel pad + bowser apron and Lv3 patrol
  hut are `M_Bld_AirStationAddons` (`AirStationMesh`, the hangar's -X side and front; no Lv1 piece gives way;
  `WorkerController` sways `Lv2_L04_Windsock` about its pole within LIVELY); no worker uses its `ATT_*` yet. The Trophy Hall's Lv2 navy dome rotunda + 8 wing plinths and Lv3
  gold dome, portico and galleries + 6 plinths are `M_Bld_TrophyHallAddons` (`TrophyHallMesh`, round the code wall; the
  code gold dome is only its fallback); `DockService` fills its `ATT_Plinth_01..08` (Lv2) / `..14`
  (Lv3) in `TrophyRules.items` order (owned specials, Epic+ survivors rarest and best trait first as Lego statues in
  their category colour, wheel prizes as rarity-colour cups, then the milestone cups; a rarity ring and a
  rarity-colour name each) via `DockPieces.trophies(b, items, plaques, plinths)`; cups past them go on the shelf. The Sub Pen's Lv2 gantry +
  hanging mini-sub + dive rack and Lv3 salvage wet dock are `M_Bld_SubPenAddons` (`SubPenMesh`, the pen's -X rim and
  its back; no Lv1 piece gives way; `WorkerController` rolls `Lv2_L03_MiniSub` on its straps within LIVELY); no worker
  uses its `ATT_*` yet. The Boathouse's Lv3 quick-launch bay is `M_Bld_BoathouseAddons` (`BoathouseMesh`, kept 1x, on
  the cove side between the cove walk and the jetty head; no Lv1/Lv2 piece gives way; `WorkerController` hides its
  `Lv3_L07_Lifeboat` locally while your own Lifeboat is out, unanchored); no worker uses its `ATT_*` yet. The Depot model holds `DepotMesh` (the Lv1..n
  layers and `Marks`: `ATT_PickUp_*` / `ATT_DropOff_*` bays, `ATT_BargeMoor`, `ATT_QuayLoad`, `ATT_QuayLand`) and
  `FreightQuay` (west plate edge, sea level). Client: `DepotController` (barge from `BargeNext` via
  `shared/BargePath`, `Stack_1..4` from `DepotStock` / `DepotCap`, empty-crate icon on `SiteWaiting`) and
  `WorkerController` (Haulers, Job `Haul` or Category `Hauler`, and a site's Builders walk the marks, paced by
  `HaulRate` / `CarryRate`).
- Depot and bricks (docs/25 D, K4): `src/shared/DepotRules.luau` (pure, `tests/DepotRules.spec.luau`, also stepped by
  `tests/Pacing.spec.luau`): `cap(depotLevel)` (20 / 40 / 80, 0 with no Depot), `BARGE_PERIOD` 60 s,
  `bargeLoads(depotLevel, haulerUnits, refill?)` (crew drop 2 + `HAUL_PER` per Hauler unit, Lv2+ x2, Hand Carts'
  `depotRefill`), `loadsFor(work)` = `ceil(T / 10)`, `haulUnits(workers, owned, extraSlots)` (assigned Haulers:
  rarity value x carry loads), `crewRate(workers, skill)` (BuildTimer's rate with each Builder counted once per load
  carried: Strong 2, Brickbeard 3, Strong Backs' `buildersCarry` 2), `carrySpeed(rate, work)`, `advance(state, params,
  dt)` (one server tick or the whole time away; with no Depot the quay holds one drop, so a site never waits
  forever), `timeLeft(state, params)`, `nextAt(now, offset)`. Haulers work at the Depot (`DockConfig` `worker =
  "Hauler"`, `Job` `Haul`). Saved as `data.depot = { stock, at? }` (loads, os.time of the last step; a new save
  starts with `START` loads on the quay). `DockService` steps it every second per owner and on join; the site
  draws loads from it (FinishNow sets progress 1 and skips the bricks). Plot model attributes: `DepotStock` (whole
  loads), `DepotCap`, `BargeNext` (`Workspace:GetServerTimeNow()` of the next mooring; each island's barge runs
  `PlotIndex * 10` s late), `HaulRate` and `CarryRate` (loads per minute), `SiteWaiting` (true while the site waits
  on an empty Depot); `SiteRate` is the effective rate (`(1 - SiteProgress) * work / time left`, barge waits
  included), so `timeLeft` readers show the real time.
- Build tablet: the station tablet opens `DockController`'s top-down build mode (docs/25 A/J): one card per
  building (level stars, Build / Upgrade price, "MAX", padlock "Needs: HQ 2"; the HQ card's next-HQ needs as
  ticked icons), tap = camera focus on the building or its empty lot. Green Lego arrows (`BuildArrow`) bob over
  every level buildable right now. `DockBlueprints` (`needs`, `glyph`, drawn by `UI/BuildGlyph`); `DockBuild`
  (camera and spot maths); `shared/NextGoal` (the Next chip: next affordable level, else the HQ needs). `server/Dock/BoatBoard` builds
  every craft board (boat, hangar, sub) with scale models from `ReplicatedStorage.VehiclePreviews`; client
  `BoatBoardController` (one `BoardOpen` prompt per board -> `Menu.openBoard` -> `UI/Panels/Board` cards; Launch = Net `BoardLaunch` -> crane beat + `DockLaunch`). The boathouse paint
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
  `SurvivorSlot1..n`, `PetSeat`, `BowPoint`. A climbing survivor's `Victim` model carries `ClimbHull`
  (vehicle model name), `ClimbStart` (Vector3), `ClimbSide` (1/-1), `ClimbSeat` (CFrame), `ClimbStartTime`
  (`GetServerTimeNow`), all in hull space; `Ops/ClimbPath` plays them on each client until the weld's Part1
  is set.
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
  upright; a boat beached past recovery goes with `poof`; a craft nobody drives that is `lost` (far over or under
  the sea, off the map) goes back to its berth.
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
cleanup? }`, fallback `Mechanics/Default`, helpers `Mechanics/PIW`); UI `UI/OpsHud` (mounts `OpsStepCard`,
`OpsDebrief`), `UI/Waypoint`, `PickupRingController` (the orange ring),
`CasualtyController` (strobes, shouts), `PyroController` (flares). A new call is its flare, pin and screen
marker, and a beep (no pager card, no radio); driving at it takes it. Voices are NPCs only: `VoiceTTS` + `UI/VoiceCast`.

## First minutes

- Loading screen (`src/first/LoadingScreen.client.luau`): preloads, orbits the ring behind the overlay, waits
  for the character, cuts to the Custom camera behind it, then lifts the overlay (`shared/LoadingPath`; docs/25 J).
  LocalPlayer attributes `LoadingScreenActive`, `CinematicPlaying`.
- Cold open: `StartColdOpen` seats a new player on a jet ski (`VehicleService.SpawnColdOpen`) with a swimmer just
  off their cove; `Boat/ColdOpen` (ease, drop-off), `Boat/ColdOpenFlow`, `UI/ColdOpenCue`, `UI/OnboardingReward`.
  Profile `coldOpenDone`.
- Tutorial (docs/25 J): the first beat is the free Rescue Hut (`Onboarding.beat` `BuildHQ` -> `HQSite`); the cold
  open waits for it (`OperationService`: no start while `DockLevelHQ` is 0), then jet ski, survivor, Workshop, spin.
- `src/shared/Onboarding.luau` (pure): `goal()` (the tutorial chain, `CallTypes.TutorialChain`), `failsafeCall`,
  `newPlayerHud`; `OnboardingController` + `UI/OnboardingBeacon`; `OnboardingWeather` keeps the cold open calm.
  `tests/NewPlayerPace.spec.luau` and `tests/Pacing.spec.luau` check the pace.
- Bosun: `DogService` / `DogController` (`shared/Dog/*`); he points at the nearest survivor or flare (`DogPoint`).

## Progression and data

- `DataService`: `Get`, `MarkDirty`, `Save(player, release?, deadline?)`, `OnLoaded(fn)`,
  `CommitReceipt(player, purchaseId, grantFn)` (idempotent receipt ledger), `HasReceipt`; session locks.
- `ProgressionRules` (pure): `PlayerData { cash, vehicles, vehicleUpgrades, totalRescues, coldOpenDone,
  dockBuildings, dockPrepaid, workers, flags, cosmetics, ... }` (retired `rep`, `dockLevel`, `crew`, `certs`, `exercises` stay
  as saved, never read), `migrate` (old dock levels onto the tree, old crew hires paid back), `snapshot`,
  `canBuyVehicle`, `vehicleLock`. `ProgressionConfig`: craft unlocks (`needs` building, Cash price).
- `ProgressionService`: `Award(player, cash, reason, flat?)` (storm, pass, friend and live-ops multipliers unless
  `flat`), `GetData`, `CanUseVehicle`, `OwnsVehiclePass`, `SetFlag`, `RecordTraining(player, grade)`, `Refresh`.
  leaderstats Cash + Rescued. Studio: `ServerStorage.ProgressionDev`.
- Skills (docs/25 F, K3): `shared/SkillRules` (pure: the four sectors `Captain` 315°, `Rescue` 45°, `Crew` 135°,
  `Industry` 225° and the four `Bridge` nodes at 0/90/180/270; each keystone carries its `minor` path and
  `nodes()` expands the dots as `<keystone>_m<i>` with `ring`/`angle` (absolute degrees, 0 = up, clockwise;
  sector nodes stay inside their sector's ±36°, bridges sit at 0/90/180/270), `medals`, `needs` (any one owned),
  `effect`, `focus`, `keystone`, `soon`; `SECTORS`, `byId`, `canBuy(owned, id, medals) -> ok, reason`, `visible(owned) -> set` (owned + unlockable next),
  `effects(owned) -> totals`, `refund(owned)`, `rescueMedals`, `chestMedals`; `LEGACY` = the old Cash tree for the
  migration). `SkillService`: `Skill_Buy`, `Skill_Reset`, `data.skills`, `data.medals` and the `Medals` attribute,
  `grantMedals(player, n, reason)` (called by rescues, gold grades, quests and the daily chest; DockService pays
  `SkillRules.HQ_MEDALS` when an HQ level finishes building), `Skill_State`; it publishes the totals as player
  attributes `SkillSpeedMult`, `SkillGrip`, `SkillReach`, `SkillBoatScale`, `SkillPayBonus`, `SkillSwimMult`,
  `SkillBuildRate`, `SkillExtraBuilders`, `SkillBaseCrew`, `SkillGatherMult`, `SkillOfflineAdd`, `SkillSlots<category>`,
  `SkillTripScale`, `SkillRecruitChance`, `SkillTripPayMult`, the cap adds (`SkillSpeedCapAdd`, `SkillBoatCapAdd`,
  `SkillMedicCapAdd`, `SkillMedicPerUnit`), `SkillWorkerCapAdd`, `SkillRareChanceAdd`. Readers default to no change:
  WorkerRules/WorkerService, BuildTimer/DockService, VehicleService, Ops/Board reach, OperationService, SwimController.
  Effects marked `-- TODO reader` in `SkillRules` (Nitro, Golden Eye, Boat seats, Clover, Mentor, Golden Mayday,
  Salvage, Welcome Home, Foreman, Lifeguard, ...) are data only until their systems land.
- Workers (docs/23 (o)): `shared/WorkerRules` (pure: roll, admit, assign, effects, offline pay). RescueService
  rolls a survivor on pick-up (attributes `WorkerCategory` / `WorkerRarity` / `WorkerName`) and calls
  `WorkerService.Recruit` when they land at the driver's berth. `WorkerService`: `data.workers`, published as
  `ReplicatedStorage.Workers.<UserId>`, rigs in `ReplicatedStorage.WorkerRigs`, Gatherer pay, the Rescuers' NPC
  boat, `PayOffline` on join; effect attributes `WorkerBoatScale`, `WorkerCraftSpeed`, `WorkerPayBonus`
  (Builders cut build time, not Cash). Each published worker has string attribute `Job`: `Build` (at the
  island's construction site), `Haul`, `Fish`, `Repair`, `Rescue`, `Heal`, `Gather` or `Idle`. Client: `WorkerController` (each Job's 2-3 beat loop and the Bunkhouse night lights + "Zzz" from `shared/WorkLoop`, pure), `UI/WorkerBadge`, `UI/Portrait` (a worker's ViewportFrame head-and-shoulders card from their `WorkerRules.rigOf` template, built only while on screen: Crew panel, survivor card, Album specials). Studio: `WorkerDev` `"fill"` / `"unfill"`.
- Crew (players riding together): `CrewService` (`GetCrew`, `IsCrewmate`, `Join`, `Leave`). Friends:
  `FriendService.Count`, `shared/FriendBonus`. Group reward: `GroupRewardService` + `shared/GroupReward`.
- Join reward prompt (no world chest, owner 2026-10-28): `StreakService` + `StreakRules` / `StreakConfig` grant the
  daily streak on `Streak_Collect`; offline crew pay is granted on join (`WorkerService`, attribute `WorkerOffline`).
  Client `RewardController` shows `UI/RewardPrompt` (coin + amount, 7-day pip strip `UiImages.Pip`, crew row, one
  Collect) and plays `UI/CoinShower` (`play(playerGui, amount, from?)`, releases the local `CashHeld` attribute that
  `HudController` subtracts from the wallet).
- Quests (docs/23 (l), (p)): `Quests/Data` (6 givers, quest chains), `Quests/Rules` (pure, `tests/Quests.spec.luau`:
  one active quest, one offer per giver per day, `talk` -> a `Dialogue` tree). `server/World/QuestPontoons` builds
  each island's quest pontoon and tablet and sails the givers' boats in and out; `QuestService` runs the quest
  stages, pays on hand-in, adds a chain's blueprint to `data.dockBuildings`. `Quest_Talk` C->S `(npcId, "accept" |
  "handIn" | "drop")` (a giver moored at your own island; a hand-in within 16 studs of them or the tablet). Player
  attributes `QuestId`, `QuestStage`, `QuestTarget`, `QuestOffer_<npcId>`. Client: `QuestController`,
  `UI/QuestTablet` (`rows` / `fill`: the cards the menu's `Panels/Quests` and its badge share), `TalkController` (camera zoom
  + numbered replies, `shared/Dialogue`). Studio: `QuestDev`.

## Menu, HUD and map

- `src/client/UI/Menu.luau` (mounted by `HudController`): the left grid of kit icon buttons (HudLayout region
  `menu`): Shop, Quests, Album, Pet, Crew, Settings, Map, Boat (Boat to me). Panels (`UI/Kit/*`):
  `UI/Panels/Shop` (`ProductShelves.storeItems`), `Panels/Quests`, `Panels/Album`, `Panels/Companion` (Bosun or
  one pet; `Pet_Equip`), `Panels/Crew`, `SettingsPanel.newPanel`; `UI/BoatCard` via `Menu.openBoat(id)`. API
  `open`, `close`, `toggle`, `openBoat`, `isOpen`; player attribute `MenuOpen`. The quest tracker chip (region
  `quest`: island art, place, distance to `QuestTarget`; tap opens Quests) shows while a quest is active.
- `src/shared/HudLayout.luau` (pure, `tests/HudLayout.spec.luau`) places the regions (menu, wallet, objective,
  status, notice, prompt, minimap, gauges, right, quest, debrief) per device (phone-sized screens: the touch
  arrangement on every device), clear of Roblox's thumbstick and jump zones;
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
  recorded with `ready = false`), `MonetizationService` (`OnProduct`, `OnPassOwned`, `OwnsPass`, `GetPolicy`, receipts through
  `DataService.CommitReceipt`; helpers `Monetization/Core`, `Monetization/CashEffects`), effects in
  `src/shared/MonetizationEffects.luau`, shelves in `src/shared/ProductShelves.luau`. Player attributes
  `Pass_<Key>`, `DayPass_<Key>`, `PassesChecked`.
- Cosmetics: `src/shared/Config/Cosmetics/*` (one slot per file), `src/shared/Cosmetics.luau` registry,
  `CosmeticsService` (loads every `server/Cosmetics/*` feature; `Cos_<Slot>` attributes), `CosmeticsController`
  (loads every `client/Cosmetics/*` feature), `CosmeticLoadout` (earned rewards), `LiveryPaint` / `LiveryPattern`,
  `VehicleSounds`, `LightBarFlash`, `ShantyRadio`, `AvatarCosmetics`.
- Pets: `PetService`, `PetRules`, `PetSeat`, `PetAccessory`, `PetController`.
- Spin wheel (docs/24 D): `SpinRules` (pure: odds, pity, prizes, free-spin accrual, saved in `flags.spin`),
  `SpinService` (every roll; `Refresh`, `GiveFree`; Spin1/5/15 products are `paidRandom`, granted only when
  `MonetizationService.GetPolicy` allows paid random items; grand boat = `flags.spinBoat`), `PrizeWheel` (world build),
  `PushButton`, `PrizeWheelController` (world spin/reveal/flex), `WheelMath`.
  Attributes `FreeSpins`, `SpinPityEpic`, `SpinPityLegendary`. Studio: `ServerStorage.SpinDev` (`give` / `force`).
- Weather: `src/shared/Weather.luau` reads `ReplicatedStorage.Weather` attributes; `WeatherMath`, `Waves`;
  `StormService` (`ForceStorm`, `ForceCalm`, `QueueSummon`; always sunny by default; writes `Lighting.ClockTime` from
  `DayClock` every 0.5 s, dev offset = Workspace attribute `DayClockOffset`); `WeatherController`,
  `OceanController` (`GetVisualHeight`) + `client/Ocean/*`.
- Live ops: `LiveOps` (pure), `LiveOpsService`, `LiveOpsController`. Re-engagement: `PlatformPrompts` +
  `PlatformPromptService` / `PlatformPromptController`; `NotifyDue` + `NotifyService`.
- Badges and leaderboards: `BadgeConfig` (keys are stable; id 0 = off), `BadgeRules`, `BadgeService` (`Award`,
  `Count`, `Once`), `LeaderboardRules`, `LeaderboardService` (`Board(face)`: DockService stands one on each plaza with the HQ).
- Analytics: `TelemetryNames` (fixed name lists), `Telemetry/Events` (pure mapping), `TelemetryService` (the only
  `AnalyticsService` caller), client `src/client/Telemetry.luau` (`once`, `send`, `shop`, `stalled` over
  `Telemetry_Client`; values checked server-side).
- Settings: `SettingsRules` (pure), `Camera/Comfort` (saved in `flags.cameraSettings`), `SettingsPanel`,
  `A11yPalette`. Camera: `CameraController` (third person only; `SetOverride`, `PlayCinematic`), `Camera/Cinematic`,
  `Camera/CameraMath`. Audio: `AudioConfig`, `AudioController`, `Audio/AudioMix`. Swimming: `SwimController` +
  `Explore/Snorkel`.
- VFX (docs/26): `client/VFX/VFXKit` owns every effect: `VFXKit.play(name, cframeOrPart, { color, scale, radius,
  height }?)` (pooled `Emit` bursts, 250-stud cull, graphics-level scaling, Reduce motion halves bursts and drops
  light flashes). Presets are data in `client/VFX/Presets` (caps: feedback/state 40, ambience 12, spectacle 120;
  `tests/VFXPresets.spec.luau`); every texture id lives in `shared/Config/VFXTextures`. Callers play their own sound.

## Dev board

Dev-only admin panel (exempt from the no-choice rule): `DevConfig` (access: Studio, listed user ids, group rank
>= 254; action specs and validation, `tests/DevBoard.spec.luau`), `DevService` (`Dev_Grant` S->C, `Dev_Action`
C->S function), `DevController` + `UI/DevBoard` (Move, Teleport, Spawn, Ops, Cutscenes, World, Progress, VFX, Server).
Chat `/vfx <name|all>` (`DevConfig.vfxName`) fires the VFX bench on the dev's client.
