# Analytics spec: every funnel, event and hook (rebuilt 2026-10-24)

Owner request: "implement funnels for everything so we can know every player what does".
Code: `src/server/Services/TelemetryService.luau` (the only `AnalyticsService` caller), pure side
`src/server/Services/Telemetry/Events.luau` (tests: `tests/Telemetry.spec.luau`), names
`src/shared/TelemetryNames.luau` (tests: `tests/TelemetryNames.spec.luau`), client
`src/client/Telemetry.luau` + `src/client/Controllers/TelemetryController.luau`.
Game design this follows: docs/16 (loop, first 10 minutes), docs/20 (one goal, your call, racer, craft
spawn/board/despawn), docs/21 (islands, stamps, sticker album), one companion on the phone.

Roblox records analytics only from a **published** game, never Studio. In Studio read the log /
`ServerStorage.TelemetryDev:Invoke("recent")`; then publish to the test place and read the Creator
Dashboard (custom events aggregate daily: allow 24 h).

## 0. Roblox limits we design to

Source: create.roblox.com/docs/production/analytics/event-types, funnel-events, custom-events,
economy-events and the `AnalyticsService` reference (checked 2026-10-24).

| Limit | Roblox | Us |
|---|---|---|
| Custom event names | 100 | 21 |
| Funnels (onboarding included) | 10 | 6 |
| Steps per funnel | 100 | ≤ 13 |
| Custom fields per event | 3 (`CustomField01..03`) | ≤ 3, values clipped to 50 chars |
| Custom field values | 8,000 combined, then "Other" | kinds, keys, buckets only; client values checked against fixed sets |
| Economy currencies | 10 | 1 (`Cash`) |
| Transaction types | 20, then "Other" | 4 (IAP, TimedReward, Gameplay, Shop) |
| Item SKUs | 100, then "Other" | ~45 (`Op:<kind>`, pack keys, `Streak:Day1..7`/`Day8+`, `Vehicle:<id>`, `Upgrade:<veh>:<up>`) |
| Recurring funnel session ids | the 10 most recent per user per funnel count | per call / visit / spawn / island / species |
| Rate | 120 + 20 × CCU events per minute, all types | every step sent once per session; client remote: burst 8, then 1 per 2 s |

API used: `LogOnboardingFunnelStepEvent(player, step, stepName, fields?)`,
`LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName, fields?)`,
`LogEconomyEvent(player, flow, currency, amount, endingBalance, transactionType, itemSku, fields?)`,
`LogProgressionEvent(player, path, Enum.AnalyticsProgressionType.Complete, level, levelName)`,
`LogCustomEvent(player, eventName, value, fields?)`. A skipped funnel step counts every earlier step as
done; only the first log of a step counts (repeats still cost rate).

## 1. Onboarding funnel (one-time: Funnels > Onboarding)

Ordered by the docs/16 §4 beats. Rebuilt before launch; after launch only append.

| # | Step | Fires in | Status | Question |
|---|---|---|---|---|
| 1 | Joined | `TelemetryService` PlayerAdded | live | sessions that start |
| 2 | AtSea | `ColdOpenStarted` (OperationService.StartColdOpen) | live | does the cold open load? |
| 3 | FirstBoard | `Call(..., "Boarded")`; fallback `ColdOpenStep("recovery")` | live (fallback); Phase 2 H2 | does the first survivor climb on? |
| 4 | FirstDelivery | `OpFinished`, reason Complete, helped (the cold open) | live | **95% finish the first rescue** |
| 5 | RewardSeen | client `OnboardingController` reward burst | live | is the payoff seen? |
| 6 | Call2Accepted | active-op poll, first non-cold-open call | live | does call 2 start (< 2:00)? |
| 7 | Call2Delivered | `OpFinished`, first station call delivered | live | does the loop land? |
| 8 | Call3Delivered | `OpFinished`, `OpsCompleted` ≥ 3 | live | does it repeat untaught? |
| 9 | PhoneOpened | first `Shop` step 1 or 2 (any phone app) | live via apps; Phase 2 H9 | does the red dot pull them in? |
| 10 | FirstUpgrade | `UpgradeService` fit | live | first upgrade (≤ 6:00) |
| 11 | FirstRank | `ProgressionService.RankChanged` | live | first rank (≤ 11:00) |
| 12 | FirstVehicle | `ProgressionService` buy (Cash) | live | first new craft |
| 13 | Day2Return | `DataService.OnLoaded`, a later UTC day than `flags.lastSessionDay` | live | **D1 return** |

Read adjacent drops: 1→2 load/spawn, 2→4 the first rescue, 4→8 the call loop, 8→12 the phone/economy
hook, 12→13 retention. The daily crate is not a step (it can come any time after B1): see `DailyCrate`.

## 2. Recurring funnels (`LogFunnelStepEvent`, Funnels > add tab)

Fields are on every step; dashboard filters apply to step 1.

### 2.1 Call (session = `<job8>:<opId>`, one per call per player)

| # | Step | Fields | Fires in | Status |
|---|---|---|---|---|
| 1 | Offered | kind, context | OperationService offer | Phase 2 H1 |
| 2 | Accepted | kind, context | active-op poll (assigned) | live |
| 3 | Seated | kind, context | racer clock starts (seated, > 15 km/h, docs/20 WP-B) | Phase 2 H3 |
| 4 | Boarded | kind, context | `OperationService.OnVictimBoarded` (first survivor) | Phase 2 H2 |
| 5 | Delivered | kind, context | `OpFinished` reason Complete | live |

The outcome of every call is the `CallEnded` custom event: value = survivors saved, fields kind,
result (`Delivered` / `TooSlow` (NPC racer, reason Takeover) / `Timer` / `Abandoned` (died, left
craft, drove away, any other reason)), context (`ColdOpen` / `Big` / `Storm` / `Calm`). Helpers also
send `OpGrade` (0-3). Survivors per call = CallEnded value; Boarded counts the first only.

### 2.2 Shop (session = a GUID per phone visit; new at PhoneOpened or after 120 s idle)

| # | Step | Fields (app, item, currency) | Fires in | Status |
|---|---|---|---|---|
| 1 | PhoneOpened | last app, None, None | `Phone.setOpen(true)` | Phase 2 H9 |
| 2 | AppOpened | Vehicles / Store / Pets / Explore | `VehiclesApp.mount`, `StoreApp.mount` | live (Pets/Explore: Phase 2 H12) |
| 3 | ItemViewed | vehicle id (the first card shown); Store: None (a shelf tab) | `VehiclesApp` selectFor (once per mount), `StoreApp.showTab` | live |
| 4 | BuyTapped | item, Cash / Robux | VehiclesApp Cash / Robux / upgrade / Quick Launch buttons, `StoreApp.buy` | live |
| 5 | Bought | item, Cash / Robux | server: `ProgressionService` buy, `UpgradeService` fit, `RobuxPrompt` purchased | live |

Robux prompts also send `RobuxPrompt` (kind, key, `Shown` on tap / `Purchased` / `Cancelled` from
`MarketplaceService.Prompt{GamePass,Product}PurchaseFinished` in MonetizationService). Steps 1-4 come
from the client over `Telemetry_Client`; the server accepts only known apps, items that are config
keys (`VehicleConfig.Order`, `LandVehicleConfig.Order`, `VehicleUpgrades.UpgradeOrder`,
`MonetizationConfig` keys, `Vehicle:Upgrade`), and `Cash`/`Robux`.

### 2.3 Vehicle (session = a GUID per spawn)

| # | Step | Fields | Fires in | Status |
|---|---|---|---|---|
| 1 | Spawned | vehicle, where (`Phone` / `Quick` / `Bay` / `ColdOpen` / `Island` / `Road`) | VehicleService / LandVehicleService spawn | Phase 2 H4 |
| 2 | Boarded | vehicle | owner takes the driver seat | Phase 2 H5 |
| 3 | Underway | vehicle | owner seated and > 15 km/h | Phase 2 H6 |

Endings: `VehicleDespawned` (reason `Idle` / `Wrecked` / `WrongMedium` / `Replaced` / `OwnerLeft`,
vehicle, medium `Water`/`Land`) and `VehicleRecovered` (reason `Flipped` / `Stuck` / `Sunk` /
`OutOfBounds` / `Runaway`, vehicle). Phase 2 H7, H8.

### 2.4 Explore (session = island id; docs/21)

| # | Step | Fields | Fires in | Status |
|---|---|---|---|---|
| 1 | Sighted | island | the fog cell holding the island's outline clears / first within view range | Phase 2 H13 |
| 2 | Reached | island | first time on the island (landing trigger) | Phase 2 H13 |
| 3 | Stamped | island | the stamp post touched | Phase 2 H13 |

`Explore(player, island, "Stamped", stampCount)` also logs Progression path `Explorer`
(level = stamps, name = island). Collectibles: `StickerFound` (island, slot `Stamp`/`Critter`/`View`/
`Bottle`/`Secret`, sticker id), `AlbumPage` (island) on a completed page.

### 2.5 Companion (session = species; one companion out at a time)

| # | Step | Fields | Fires in | Status |
|---|---|---|---|---|
| 1 | Rescued | species | the WildlifeRescue call delivered (SanctuaryService credit) | Phase 2 H10 |
| 2 | Adopted | species | `PetService.AddRescue` | Phase 2 H10 |
| 3 | Chosen | species (`Bosun` for the dog) | `PetService.Equip` / the phone's companion choice | Phase 2 H11 |

`CompanionSwitch` (from, to) on every change of the companion that is out. `PetAdopted` (legacy,
PetService.Equip) stays until H11 replaces it.

## 3. Economy (`LogEconomyEvent`, currency `Cash`)

Every source travels as `extra.award { cash, reason }` through `ProgressionService.push`
(`TelemetryService.CashFlow`); every sink calls `TelemetryService.CashSpent` next to the deduction.

| Flow | Transaction | SKU | Site |
|---|---|---|---|
| Source | IAP | pack key, `StarterKit` | Monetization/CashEffects (`Purchase:<key>`) |
| Source | TimedReward | `Streak:Welcome`, `Streak:Day1..7`, `Streak:Day8+`, `Group:Crew` | StreakService crate |
| Source | Gameplay | `Op:<kind>`, `Op:<kind>:Takeover`, `Op:Share`, `Op:CapsizedFerry[:Casualty]`, `AmbientRescue`, future `Sticker:<slot>` | OperationService, AmbientRescueService, docs/21 stickers |
| Sink | Shop | `Vehicle:<id>` | ProgressionService buy |
| Sink | Shop | `Upgrade:<vehicle>:<upgrade>` | UpgradeService fit |

A new Cash grant that skips `extra.award`, or a new sink without `CashSpent`, will not show.

## 4. Progression (`LogProgressionEvent`, Complete)

| Path | Level | Level name | Site |
|---|---|---|---|
| Rank | rank index | rank display name | `ProgressionService.RankChanged` (live) |
| Explorer | stamps collected | island id | `Explore(..., "Stamped", n)` (Phase 2 H13) |

## 5. Custom events (`LogCustomEvent`, Explore view)

| Event | Value | Fields (01, 02, 03) | Site | Status |
|---|---|---|---|---|
| CallEnded | survivors saved | kind, result, context | `OpFinished` | live |
| OpGrade | 0-3 | kind, grade, rarity | `OpFinished` (helpers) | live |
| ColdOpenEnded | 1 | reason | OperationService endColdOpen | live |
| StormJoined | 1 | Great/Storm, Start/MidStorm | weather watch | live |
| DailyCrate | streak | Daily/Welcome, crate day | StreakService | live |
| PetAdopted | 1 | species, Rare/Common | PetService.Equip | live (legacy) |
| CompanionSwitch | 1 | from, to | companion choice | Phase 2 H11 |
| LiveEvent | 1 | event id | LiveOps poll | live |
| FriendBonus | percent | friend count | FriendService attributes | live |
| PromptShown | 1 | notify/favorite/invite | PlatformPromptService | live |
| PhotoMode | 1 | none | client | live |
| RobuxPrompt | 1 | kind, key, Shown/Purchased/Cancelled | client tap + MonetizationService | live |
| BadgeAwarded | 1 | badge key | BadgeService award | live |
| StickerFound | 1 | island, slot, sticker | docs/21 album | Phase 2 H13 |
| AlbumPage | 1 | island | docs/21 album | Phase 2 H13 |
| VehicleDespawned | 1 | reason, vehicle, medium | VehicleService / LandVehicleService | Phase 2 H7 |
| VehicleRecovered | 1 | reason, vehicle | VehicleService.resetVehicle | Phase 2 H8 |
| StuckReset | 1 | device, where | client (any unstuck / push-off) | Phase 2 H14 |
| InputDead | 1 | device, where | client controllers | Phase 2 H15 |
| SessionStart | days since first session | day bucket (D0, D1, D2-3, D4-7, D8-14, D15-30, D31+), gap (New, Same, 1d, 2-3d, 4-7d, 8d+), New/Returning | DataService.OnLoaded | live |
| SessionEnd | seconds played | length bucket (<1m … 60m+), device (Touch/Gamepad/Keyboard/Console/VR/Unknown), day bucket | PlayerRemoving | live |

Day-N return = `SessionStart` by day bucket (unique users) next to the Retention page; session length
by device = `SessionEnd`. `flags.firstSessionDay` is written on the first load (older profiles: the
first load after this ships, or their `lastSessionDay`).

## 6. Dashboard reading

- **Onboarding**: after every playtest and weekly; compare adjacent steps (section 1).
- **Call** tab: Offered→Accepted is offer appeal, Accepted→Seated is "find your craft" (docs/20 M6/M11),
  Seated→Boarded is driving (M10), Boarded→Delivered is the way home (M3/M9). `CallEnded` result
  split says why calls die.
- **Shop** tab: AppOpened→ItemViewed→BuyTapped→Bought per app; `RobuxPrompt` Shown vs Purchased.
- **Vehicle** tab: Spawned→Boarded is the docs/20 M11 "how do I get on my boat" leak.
- **Economy**: sources vs sinks; a growing balance means sinks are too weak.
- **Explore**, **Companion**: per-island / per-species reach once docs/21 and the companion phone land.

## 7. Phase 2 hooks (orchestrator: wire after the owning agents merge)

Server files call `Telemetry = require(script.Parent.TelemetryService)` (or OperationService's
`try("TelemetryService", ...)`). Client files call `require(<client>.Telemetry)`. Line numbers are from
`b5601a59`; find the line by its context.

- [ ] **H1 Call Offered**: `src/server/Services/OperationService.luau` `offerTo` (~1479), after
  `fire("Ops_Offered", player, offerPayload(op, tut))`:
  `try("TelemetryService", "Call", player, op.id, "Offered", op.kind)`; same line after each
  `Remotes.event("Ops_Offered"):FireClient(p|player, offerPayload(...))` (~1702 with `p, op`; ~2269 and
  ~2278 with `player, bigOp`).
- [ ] **H2 Call Boarded (+ onboarding FirstBoard)**: `OperationService.OnVictimBoarded` (~1281, empty
  stub, called by `RescueService` ~1001 after a survivor is aboard): body
  `local op = opOfScene(_scene) if op then try("TelemetryService", "Call", _player, op.id, "Boarded", op.kind) end`.
- [ ] **H3 Call Seated**: where docs/20 WP-B starts the racer clock (today `op.race = { acceptedAt = now() }`,
  OperationService ~1596; after WP-B the "seated and > 15 km/h" check):
  `try("TelemetryService", "Call", player, op.id, "Seated", op.kind)`. A WP-B "drove away" ending should
  `finish(op, "Abandoned")` (any non-Complete/Takeover/Timer reason maps to Abandoned).
- [ ] **H4 Vehicle Spawned**: `src/server/Services/VehicleService.luau` `spawnVehicle` (~869), after the
  craft is built and before returning success:
  `Telemetry.Vehicle(player, "Spawned", vehicleId, if quick then "Quick" elseif docked then "Phone" else "Bay")`;
  cold-open spawn path: `where = "ColdOpen"`; island docks: `"Island"`.
  `LandVehicleService.luau` `spawnVehicle` (~510): `Telemetry.Vehicle(player, "Spawned", vehicleId, "Road")`.
- [ ] **H5 Vehicle Boarded**: `VehicleService.onDriverChanged` (~426) inside `if player then`, when
  `player == record.owner`: `Telemetry.Vehicle(player, "Boarded", record.spec.id)`. Same in
  LandVehicleService's driver-seat handler.
- [ ] **H6 Vehicle Underway**: `VehicleService.checkVehicle` (~1093) after `speed` is computed:
  `if record.driver == record.owner and speed > 12 then Telemetry.Vehicle(record.owner, "Underway", record.spec.id) end`
  (12 studs/s ≈ 15 km/h; repeats are dropped per spawn).
- [ ] **H7 VehicleDespawned**: `VehicleService.sweepVehicles` (~685) before `despawnModel(model)`:
  `Telemetry.Custom(record.owner, "VehicleDespawned", 1, if idle then "Idle" else "Wrecked", record.spec.id, "Water")`;
  `clearOtherClasses` (~770) and `createVehicle` old craft (~808): reason `"Replaced"`; the docs/20
  WP-C wrong-medium despawn: `"WrongMedium"` with medium `"Land"` (boat on land) / `"Water"` (car in
  water); LandVehicleService `despawn` (~389) callers: `"Idle"` / `"Replaced"` / `"WrongMedium"`.
- [ ] **H8 VehicleRecovered**: `VehicleService.resetVehicle` (~922) first line:
  `Telemetry.Custom(record.owner, "VehicleRecovered", 1, if reason == "Flipped" or reason == "Stuck" or reason == "Sunk" then reason elseif reason == "out of bounds" then "OutOfBounds" else "Runaway", record.spec.id)`
  (never pass the raw reason: it carries numbers).
- [ ] **H9 Shop PhoneOpened**: `src/client/UI/Phone.luau` `Phone.setOpen` (~670) after `open = value`:
  `if value then Telemetry.shop("PhoneOpened") end`.
- [ ] **H10 Companion Rescued / Adopted**: `src/server/Services/SanctuaryService.luau` (~251) before
  `PetService.AddRescue(player, best.species, best.rare)`:
  `Telemetry.Companion(player, best.species, "Rescued")`; `src/server/Services/PetService.luau`
  `AddRescue` (~96) before `return entry`: `Telemetry.Companion(player, speciesId, "Adopted")`.
- [ ] **H11 Companion Chosen / Switch**: `PetService.Equip` (~148, where `PetAdopted` is logged now):
  replace with `Telemetry.Companion(player, pet.species, "Chosen")` and
  `Telemetry.Custom(player, "CompanionSwitch", 1, <previous species or "Bosun">, pet.species)`; the
  phone's "send the pet home / take Bosun" path (DogService or the companion app):
  `Telemetry.Companion(player, "Bosun", "Chosen")` + the same `CompanionSwitch`.
- [ ] **H12 Shop AppOpened for new apps**: the Pets / companion app and the Explore (album) app
  `mount`: `Telemetry.shop("AppOpened", "Pets")` / `Telemetry.shop("AppOpened", "Explore")`; a pet
  or sticker item key must be added to `knownItems` in `TelemetryService.Init` before it is sent.
- [ ] **H13 Explore**: the docs/21 discovery service (not written yet): fog cell with the island
  cleared → `Telemetry.Explore(player, islandId, "Sighted")`; landing trigger →
  `Telemetry.Explore(player, islandId, "Reached")`; stamp post →
  `Telemetry.Explore(player, islandId, "Stamped", stampCount)`; sticker →
  `Telemetry.Custom(player, "StickerFound", 1, islandId, slot, stickerId)`; page complete →
  `Telemetry.Custom(player, "AlbumPage", 1, islandId)`; sticker Cash as
  `ProgressionService.Award(player, cash, 0, "Sticker:" .. slot, true)` (economy SKU stays small).
- [ ] **H14 StuckReset**: the docs/20 WP-C wall push-off (BoatController / CarController) and any
  "unstuck" respawn: `Telemetry.send("StuckReset", "Boat" | "Car" | "Foot" | "Swim")` (client).
- [ ] **H15 InputDead**: `src/client/Controllers/BoatController.luau` drive step (~325, `local throttle = input`):
  when `math.abs(input) > 0.5` for 3 s while seated and `forwardSpeed < 1` (and not the cold-open
  auto-throttle), `Telemetry.send("InputDead", "Boat")` once per stall; same in `CarController`
  (`"Car"`) and the on-foot controller (`"Foot"`: move input held 3 s, root moved < 1 stud).
- [ ] **H16 Cold open**: once docs/20 WP-D lands, keep `ColdOpenStarted` at the moment the player
  is seated at sea (that is onboarding `AtSea`); `ColdOpenStep(player, "recovery")` becomes redundant
  after H2 and can go.

16 hooks; none changes behaviour, each is one or two lines.
