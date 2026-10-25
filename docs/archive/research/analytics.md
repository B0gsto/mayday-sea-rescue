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
| 3 | FirstBoard | `Call(..., "Boarded")`; fallback `ColdOpenStep("recovery")` | live | does the first survivor climb on? |
| 4 | FirstDelivery | `OpFinished`, reason Complete, helped (the cold open) | live | **95% finish the first rescue** |
| 5 | RewardSeen | client `OnboardingController` reward burst | live | is the payoff seen? |
| 6 | Call2Accepted | active-op poll, first non-cold-open call | live | does call 2 start (< 2:00)? |
| 7 | Call2Delivered | `OpFinished`, first station call delivered | live | does the loop land? |
| 8 | Call3Delivered | `OpFinished`, `OpsCompleted` ≥ 3 | live | does it repeat untaught? |
| 9 | PhoneOpened | first `Shop` step 1 or 2 (`Phone.setOpen`, any app) | live | does the red dot pull them in? |
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
| 1 | Offered | kind, context | OperationService offer | live |
| 2 | Accepted | kind, context | active-op poll (assigned) | live |
| 3 | Seated | kind, context | owner seated afloat and under way (`raceTick`) | live |
| 4 | Boarded | kind, context | `OperationService.OnVictimBoarded` (first survivor) | live |
| 5 | Delivered | kind, context | `OpFinished` reason Complete | live |

The outcome of every call is the `CallEnded` custom event: value = survivors saved, fields kind,
result (`Delivered` / `TooSlow` (NPC racer, reason Takeover) / `Timer` / `Abandoned` (died, left
craft, drove away, any other reason)), context (`ColdOpen` / `Big` / `Storm` / `Calm`). Helpers also
send `OpGrade` (0-3). Survivors per call = CallEnded value; Boarded counts the first only.

### 2.2 Shop (session = a GUID per phone visit; new at PhoneOpened or after 120 s idle)

| # | Step | Fields (app, item, currency) | Fires in | Status |
|---|---|---|---|---|
| 1 | PhoneOpened | last app, None, None | `Phone.setOpen(true)` | live |
| 2 | AppOpened | Vehicles / Store / Pets / Explore | `VehiclesApp.mount`, `StoreApp.mount` | live (Pets live; Explore: discovery agent) |
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
| 1 | Spawned | vehicle, where (`Phone` / `Quick` / `Bay` / `ColdOpen` / `Island` / `Road`) | VehicleService / LandVehicleService spawn | live |
| 2 | Boarded | vehicle | owner takes the driver seat | live |
| 3 | Underway | vehicle | owner seated and > 15 km/h | live |

Endings: `VehicleDespawned` (reason `Idle` / `Wrecked` / `WrongMedium` / `Replaced` / `Stowed`,
vehicle, medium `Water`/`Land` = the vehicle's) and `VehicleRecovered` (reason `Flipped` / `Stuck` / `Sunk` /
`OutOfBounds` / `Flooded` / `Runaway`, vehicle). Live.

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
| 1 | Rescued | species | the WildlifeRescue call delivered (SanctuaryService credit) | live |
| 2 | Adopted | species | `PetService.AddRescue` | live |
| 3 | Chosen | species (`Bosun` for the dog) | `PetService.Equip` (the phone's companion choice, Bosun included) | live |

`CompanionSwitch` (from, to) on every change of the companion that is out (`PetAdopted` is gone).

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
| CompanionSwitch | 1 | from, to | `PetService.Equip` | live |
| Race | 1 | Started/RacerWon, kind | OperationService `startRace` / racer claim | live |
| LiveEvent | 1 | event id | LiveOps poll | live |
| FriendBonus | percent | friend count | FriendService attributes | live |
| PromptShown | 1 | notify/favorite/invite | PlatformPromptService | live |
| PhotoMode | 1 | none | client | live |
| RobuxPrompt | 1 | kind, key, Shown/Purchased/Cancelled | client tap + MonetizationService | live |
| BadgeAwarded | 1 | badge key | BadgeService award | live |
| StickerFound | 1 | island, slot, sticker | docs/21 album | Phase 2 H13 |
| AlbumPage | 1 | island | docs/21 album | Phase 2 H13 |
| VehicleDespawned | 1 | reason, vehicle, medium | VehicleService / LandVehicleService | live |
| VehicleRecovered | 1 | reason, vehicle | `TelemetryService.VehicleRecovered` (boat + car resets) | live |
| StuckReset | 1 | device, where | BoatController wall push-off | live |
| InputDead | 1 | device, where | Boat / CarController (`Telemetry.stalled`) | live |
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

## 7. Phase 2 hooks (wired 2026-10-24)

Server files call `Telemetry = require(script.Parent.TelemetryService)` (OperationService: `try("TelemetryService", ...)`);
client files call `require(<client>.Telemetry)`. Find each by its `analytics H<n>` comment.

- [x] **H1 Call Offered**: `OperationService.luau` `offerTo`, the big-call pager in `startBigOp`, and
  `OperationService.OfferBigCall` (each after its `Ops_Offered` fire). The cold open has no offer: it starts at Accepted.
- [x] **H2 Call Boarded (+ onboarding FirstBoard)**: `OperationService.OnVictimBoarded` (RescueService calls it after a
  survivor is aboard). `ColdOpenStep("recovery")` stays as the FirstBoard fallback (deduped).
- [x] **H3 Call Seated**: `OperationService.luau` `raceTick` → `underway(owner)` (seated afloat, > `RaceRules.UNDERWAY`),
  once per call for every call (not only racer calls); `startRace` uses the same `underway`. No WP-B "drove away"
  ending exists; every non-Complete/Takeover/Timer reason is already `Abandoned` in `CallEnded`.
- [x] **Race** (new custom event, NPC racer): `OperationService.luau` `startRace` (`Started`) and its `claim`
  (`RacerWon`, before `startTakeover`); field 2 = call kind. Player-first races = Started − RacerWon.
- [x] **H4 Vehicle Spawned**: `VehicleService.luau` `spawnVehicle` (new `where` arg: bay prompt and returning
  player `Bay`, RequestVehicle `Phone`, QuickLaunch / DevLaunch `Quick`), `VehicleService.SpawnSeated` (`ColdOpen`),
  `LandVehicleService.luau` `spawnVehicle` (`Road`). Island docks come through the phone (`Phone`).
- [x] **H5 Vehicle Boarded**: `VehicleService.luau` `onDriverChanged` (owner), `LandVehicleService.luau` `onSeatChanged`.
- [x] **H6 Vehicle Underway**: `VehicleService.luau` `checkVehicle`, `LandVehicleService.luau` `check` (> 12 studs/s).
- [x] **H7 VehicleDespawned**: `despawnModel(model, reason)` / `despawn(record, reason)` log it; medium is the
  vehicle's (`Water` boat, `Land` car). Boat: `sweepVehicles` `Idle`/`Wrecked`, `clearOtherClasses` and
  `createVehicle` `Replaced`, `RefreshUpgrades` `Replaced`, `despawnMisplaced` `WrongMedium`, `stowVehicle` `Stowed`.
  Car: `spawnVehicle` `Replaced`, `checkDespawn` `Idle`, `despawnMisplaced` `WrongMedium`. Owner-left despawns
  are not logged (the player is gone).
- [x] **H8 VehicleRecovered**: `TelemetryService.VehicleRecovered` maps the raw reason (`Flipped`/`Stuck`/`Sunk`/
  `OutOfBounds`/`Flooded`/`Runaway`); called from `VehicleService.luau` `resetVehicle` and `LandVehicleService.luau` `resetTo`.
- [x] **H9 Shop PhoneOpened**: `src/client/UI/Phone.luau` `Phone.setOpen`.
- [x] **H10 Companion Rescued / Adopted**: `SanctuaryService.luau` credit (before `PetService.AddRescue`),
  `PetService.AddRescue` (after the save).
- [x] **H11 Companion Chosen / Switch**: `PetService.Equip` (Bosun = pet id 0 goes through the same path):
  `Companion(..., "Chosen")` + `CompanionSwitch` (from, to; `Bosun` when no pet is out). `PetAdopted` removed.
- [x] **H12 Shop AppOpened**: `src/client/UI/PetsApp.luau` `PetsApp.mount` (`Pets`). `Explore` belongs to the
  discovery agent (AlbumApp).
- [ ] **H13 Explore**: owned by the discovery agent (DiscoveryService / AlbumApp), not wired here.
- [x] **H14 StuckReset**: `BoatController.luau` `unstickBoat` when the wall push-off fires (`Boat`). Cars have no
  push-off (the server's `resetTo` logs `VehicleRecovered`); no on-foot unstuck exists.
- [x] **H15 InputDead**: `Telemetry.stalled(context, stalled, dt)` (client, once per 3 s stall), called from
  `BoatController.luau` `step` (throttle > 0.5, speed < 1, not the cold-open auto-throttle) and
  `CarController.luau` `drive` (throttle > 0.5, no handbrake, not flooded, speed < 1). On foot is not wired.
- [x] **H16 Cold open**: `ColdOpenStarted` already fires right after `SpawnColdOpen` seats the player (AtSea).

Client values are checked on the server (`TelemetryService` `clientStep`): `InputDead` / `StuckReset` contexts
against `Events.InputContexts`, Shop apps against `Events.ShopApps`, rate limited by `Events.allow`.
