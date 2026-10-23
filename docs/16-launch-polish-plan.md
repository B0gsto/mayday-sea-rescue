# 16 · Launch polish plan

2026-10-23. Goal: a publishable game. Cut what a first-launch player doesn't need, make what stays obvious, and
teach through action and need. This chapter wins over docs/02, 03, 09 and 15 where they disagree.

Inputs: memory notes (simple-rescue, show-dont-tell, ui-on-phone, phone-iphone-store, camera-third-person,
no-deepseek), docs/14, docs/15, docs/02, docs/research/playtest-first-20-min.md, a read of every service,
controller, UI module and op definition.

Handled in other threads (not planned here): removing Crew Pay / Pay Rise idle income (StationService, CrewPay),
vehicle auto-reset, vehicle store arrows, cobblestone road edges and hatched road paint, the pet ring.

## 1. Core loop at launch

You're a lifeboat rider in Port Haven. Someone is in trouble on the water: a flare goes up, Bosun barks and
points, and a blip shows on the minimap. You jump on your craft (jet ski, RIB, lifeboat or a premium boat), drive
up close and steady, and the survivors climb aboard by themselves. You bring them home to a drop-off pad and get
paid in Cash and Rep. Depth comes from the situation, never from steps: how many people your craft holds
(jet ski 1, RIB 3, lifeboat 8), waves that make "steady" a skill, ramming that knocks people back, survivors who
tire, and an NPC boat that takes anyone you're too slow to reach (no pay). Cash buys vehicles and upgrades in
the phone's Vehicles app. Rep raises your rank, and rank unlocks bigger boats. The situations vary (swimmer,
rip, sinking boat, boat on fire, cliff foot, animal in a net, capsized ferry), but the action is always the
same: get near, hold steady, bring them home.

## 2. CUT list

"Risk" covers saved data and money. Profile flags of cut systems stay in saves and do no harm, so no migration
is needed unless the row says so.

| # | What | Files | Why cut | Risk |
|---|---|---|---|---|
| C1 | Procedural rescue mechanics: kit-up, heaving line, bridle, take strain, survey, treat, cliff access/recover, fire approach/fight, sinking assess/save, panic calm, throw-bag recovery, search, approach coaching, berth, radio close-out, lighthouse crank | `client/Mechanics/{Tow,Cliff,Fire,Sinking,Rip}/`, ~30 `client/Mechanics/*.luau` (everything except `radio_ack`, `launch`, `auto_board`, `transport`, `Default`), the unused `client/Mechanics/PIW/*` (Care, Medical, Rhythm, Panic, Search, Throw, Pick, Recovery, Approach, Record; keep Step, Ui, Units, World, Swimmer and Ways if cold open/auto_board need them), `shared/Ops/CasualtyCare`, `server/Ops/PiwMetrics` if unused | simple-rescue (user 10-21): "too complicated the other stuff". 6 of 8 live ops still run these steps | None. Tests Mech*, CasualtyCare, Cliff, FireSpread, SinkingVessel and Pick get deleted with them |
| C2 | Disabled Vessel (tow) op. It is also tutorial call 2 | `Ops/Definitions/DisabledVessel`, `server/Tow/`, `shared/Tow/`, `client/Mechanics/Tow`, `CallTypes` Tow kind and TutorialChain[2], `MechTow.spec` | 11 steps; towing is the opposite of "get near and bring home" | None. Ghost Light used it (C9) |
| C3 | Certifications, exercises, exercise board | `ExerciseBoardService`, `ExerciseBoardController`, `UI/ExerciseBoard`, `Ops/Definitions/Exercise*` + `Exercises`, `ProgressionConfig.Certifications`/`CertOrder` and rank `cert`/`certs` gates, `Certs.spec` | Kit-up and first-person drills are the procedure the user rejected. The cert gate holds offers (`Onboarding.holdsOffers`) and gates ranks 2 to 4 | **Remove the rank gates in the same change**, or players stall at Lifeguard. `CertX` badges become unearnable (fine) |
| C4 | Gear (Engine Tune, Strong Grip) and the Chandlery counter | `ProgressionConfig.Gear*`, gear branch of `ProgressionService`/`ProgressionRules`, `UI/HudShop`, the `ShopCounter` prompt in `WorldService`, its wiring in `HudController` | Duplicates the Vehicles-app jet ski "Tuned engine" (same 300 Cash, same +8%). Strong Grip does nothing with auto_board. An in-world shop breaks ui-on-phone | Data: owners of `gear.EngineTune` get the jet ski Engine upgrade fitted; Strong Grip owners get its Cash back. `BuyGear(vehicleId)` stays: VehiclesApp buys vehicles through it |
| C5 | In-world Robux shelves (product cards, Storm/Horn boards, the BoatDesk Quick Launch card) | `UI/ProductCard`, `shared/QuickLaunchCard`, `ProductShelf` tags in `server/World/ChandleryRig` and `map/Build.luau`, the world-card half of `shared/ProductShelves` (keep `storeItems`/`cardState`/`mayPrompt`) | The same products are in the Store app. World kiosks are banned (ui-on-phone) | No revenue loss: the Store app sells every live id. In-world cosmetic equip (CosmeticPicker) needs a phone home once cosmetic passes ship (none have launch ids) |
| C6 | Rotating Chandlery stock | `StockService`, `StockController`, `shared/StockRotation`, `Config/StockConfig`, `StockRotation.spec`; references in `PetService`, `ProgressionService` | A third shop with a restock clock, overlapping upgrades and cosmetics | Cash only, no Robux |
| C7 | Halloween "Ghost Ship" (opens 10-24) | `HalloweenService`, `HalloweenController`, `client/World/HalloweenWorld`, Halloween part of `Config/SeasonalEvents`, `SeasonalRules`, `Seasonal.spec` | A second currency (Candy), a pumpkin stall (world shop) and forced big calls every few minutes, landing on a loop that is being rebuilt | Lose one FOMO beat. Nothing is paid. Optional: keep the pumpkin dressing only, behind a flag |
| C8 | Winter "Frost Fleet" (12-12) | `WinterService`, `WinterController`, `client/World/WinterWorld`, winter config | Same as C7. Re-add after launch on the simplified loop | None |
| C9 | Server-clock events. Great Storm is already off (`ALWAYS_SUNNY`); Ghost Light is night fog plus a tow call | `EventService`, `EventController`, `shared/EventClock`, `EventClock.spec`; references in `BadgeService`, `RescueVariants`, `OperationService`, `StormService`, `LiveOpsService` | The game is "always sunny, no night", so all that's left is a tow call in fog | `CallTheStorm`/`CallTheGreatStorm` have ids but `ready=false`; keep them hidden. StormService stays (sunny) |
| C10 | Events app, EventBoard, EventCalendar | `UI/EventBoard`, `EventBoardController`, `shared/EventCalendar`, the Events entry in `Phone.luau`, `EventCalendar.spec` | After C6 to C9 and C11 only the daily crate is left, and the crate shows itself in the world | None |
| C11 | Season Logbook (30-tier track) | `SeasonService`, `SeasonController`, `UI/SeasonBook`, `shared/SeasonRules`, `Config/Season`, the Season app, the `SeasonLogbook` product row | A second XP bar next to rank | The paid track has no launch id |
| C12 | Daily/weekly challenges and their station board | `ChallengeService`, `ChallengeController`, `UI/ChallengeBoard`, `ChallengeRules`, `Config/ChallengeConfig`, `StationChallengeBoard`; references in `StreakService`, `AlbumService`, `Livery`; `ChallengeReroll` row | A text board in the hall. Its 770-Cash payout on call 2 wrecks early pacing | `ChallengeReroll` has no launch id. A Livery unlock may reference it: re-point it to a rank |
| C13 | Rescue Album (sticker board) | `AlbumService`, `AlbumController`, `UI/AlbumBoard`, `shared/RescueAlbum`, `RescueAlbum.spec`. **Keep** `Config/RescueVariants` (rare looks, bonus Cash, Legendary sky flare) | A third collection next to pets and ranks, read on a wall board | `flags.album` stays in saves |
| C14 | Exploration logbook and the On watch / Off duty switch | `ExplorationService`, `ExplorationController`, `UI/Logbook`, `shared/Explore/Discovery` (keep `Snorkel`), the Logbook app and J key, the OffDuty skip in `OperationService`, `Explore.spec` | "Off duty" switches the core loop off; discovery pop-ups are noise | One-time Cash only |
| C15 | Lighthouse missions | `LighthouseService`, `shared/Lighthouses`, `lighthouse_crank`, the station-yard board, `Lighthouses.spec`, NextGoal "Light" | Another board, another mechanic, another goal chain | Keep the beams lit as dressing |
| C16 | Assist/Pro switch and patient monitor | `SettingsService`, the Pro row in `SettingsPanel`, `UI/OpsConditionMonitor`, `OpsPro` reads (OperationService, OpsHud, OpsDebrief, BoatController), `Settings.spec` | With auto_board there's nothing to assist; it's a mode a kid can't read | None |
| C17 | Crew roles, crew-up flare, "Join crew" sign | `CrewRoleController`, `shared/CrewRoles` (after WP1 drops its use), the flare half of `FriendController`/`FriendService`, `client/World/CrewSign` + `CrewSignController` | Roles came from the steps that C1 removes. The sign is a world stand. **Keep** joining via the boat prompt and the friend Cash bonus | The group reward stays (checked on join) |
| C18 | VIP roof deck | `server/World/VipDeck`, `client/Cosmetics/VipDeckAccess`, `server/Cosmetics/VipStatus` | Gated area for `VipCrewCard`, which has no launch id | Re-add with the pass |
| C19 | Dead or example code | `CallService`, `CallController`, `UI/CallCard`, `HelloController` (refs in VehicleService, RescueService, DogService) | Retired stubs | None |
| C20 | Duck-dive (C / B / DIVE button) | the dive half of `SwimController` | Nothing underwater once C14 goes; the DIVE button is HUD clutter | Keep floating (F-4 fix) |
| C21 | LiveOps effects tied to cut systems | `DoubleCandy`, `LegendaryRush` in `shared/LiveOps`/`LiveOpsService` | Their targets are gone. Keep `GoldenHour` and `CalmSeas` | None |
| C22 | Radio app (repeat the last line) | the Radio entry in `Phone.luau` | Subtitles already show it; one less icon | None |

## 3. KEEP but fix

| # | System | Now | Fix |
|---|---|---|---|
| K1 | Ops kept: PersonInWater, RipCurrent, SinkingVessel, VesselFire, CliffCasualty (sea side only), WildlifeRescue, CapsizedFerry | Only PIW and Ferry use the simple plan | Every op becomes `radio_ack → launch → auto_board → transport`. The scene is spectacle: listing hull, fire and smoke, rip pull, cliff foot, net. Survivors are swimmers or jumpers beside it. Fire and sinking add urgency (survivors tire faster); rip adds drift; cliff surf adds waves |
| K2 | Taking a call | Pager card plus "R answers" and a 45 s timeout that fails to NPC; the first call can also be taken at the station board | Auto-accept when you're seated in a craft and head toward it (or press R/tap). The pager shows only the type icon. The world shows the way: a flare (`PyroController`) over the scene, a minimap blip, and Bosun pointing. No timeout fail on the answer |
| K3 | Launching at the bays | Three prompts overlap ("Launch Jet Ski / RIB / Lifeboat") | One "Launch" prompt per bay that spawns your last-used owned craft. Switching craft lives in the Vehicles app (Spawn + FootTrail, already there) |
| K4 | Objective strip (`OpsStepCard`) | Step labels like "Answer the Coastguard" or "Come in slow" | Icon plus at most 1 to 2 words: flare + "Go", ring + aboard count `1/3`, pad + "Home" |
| K5 | Debrief (`OpsDebrief`) | Medal and grading text | Stars, Cash roll and time. Mastery icons only (smooth ride, nobody left, fast) |
| K6 | Next-goal chip (`NextGoal`, `NextGoalController`) | Can show Cert, Gear, Season or Light; a new player sees "Helm 0/3" | Two kinds only: the rank bar, or the next vehicle's silhouette with Cash progress (nearest wins) |
| K7 | Ranks (`ProgressionConfig.Ranks`) | Cert-gated; RIB at rank 3 for 4,000 Cash (~30 min) | Rep only. Tune RIB to rank 2 for ~2,500 so the capacity need (beat B4) has an answer in ~15 to 20 min. RIBPass stays the instant path (small monetization trade-off; the user decides) |
| K8 | Vehicle upgrades (`VehicleUpgrades`, VehiclesApp) | Third upgrade "Fit" has a blank name and effect | Engine = speed, Hull = steady in waves (boarding locks faster). Give "Fit" a real effect (+1 aboard on RIB and lifeboat) or drop it |
| K9 | Phone (`Phone.luau`) | Up to 11 apps (Map, Radio, Camera, Events, Season, Logbook, Crew, Settings, Vehicles, Store, plus Crew Pay being removed) | 6 apps: Map, Vehicles, Store, Crew, Camera, Settings. Dock: Map, Vehicles, Store, Camera. The red dot and bounce now mean "something is affordable" and badge the Vehicles icon |
| K10 | HUD | Wallet, rank, goal chip, friend chip, objective, subtitle, minimap, phone, DIVE | Wallet, rank bar, goal chip, objective strip, subtitle, minimap, phone. Friend bonus only as a `+20%` on the Cash pop |
| K11 | Returning spawn | Cold open first, then the station (friends spawn at QuaySpawn) | Returning players spawn at their bay, next to their craft and the daily crate |
| K12 | Daily crate (`StreakService`, `StreakCrate`, `StreakSign`) | Crate on the station porch; text sign | Crate at your bay (on the spawn path); the sign shows day pips, not text |
| K13 | Free-roam swimmers (`AmbientRescueService`) | Up to 4 server-wide, spawn ≥120 studs away | Core of the loop. One always visible from the harbour mouth while the player is idle. The first one is seeded in Calm Bay as the cold open ends |
| K14 | Bosun (`DogService`, `DogController`) | Point-and-bark exists | He's the guide: on the craft he points and barks at the nearest survivor or flare when the player is idle more than 8 s |
| K15 | Fail rule (NPC boat) | NPC pickup exists (`server/Ops/NpcPickup`) | Make the race visible: from call 4 an NPC RIB leaves the harbour toward the survivor with a wake and a siren. That's the need for the Engine upgrade |
| K16 | Wildlife → pets (`SanctuaryService`, `PetService`) | Free (hold) + carry mechanics | auto_board: the net drops when they're aboard, the animal sits on the craft, walks to the bay pen and follows you once recovered. The pet core is unchanged |
| K17 | Radio voice lines (`RadioLines`, `RadioController`) | Long Coastguard phrasing on the subtitles | Subtitle ≤ 6 words ("Person in the water. Launch."); keep the voice |
| K18 | Cold open | Already auto_board with world cues (`ColdOpenCue`) | Keep. Fix the storm already running at spawn (playtest R4 #3). After the drop-off the jet ski stays with the player (Handover "Ride") |

## 4. Teach by action: the first 10 minutes

No tutorial text. Allowed: icons, rings, smoke, flares, Bosun, the minimap blip, device glyphs, 1 to 3 word labels.

| Beat | Time | What makes the player want or need it | Code now | Change |
|---|---|---|---|---|
| B0 Spawn, first rescue | 0:00–0:40 | Already on a jet ski. A survivor waves inside an orange ring, with smoke and a flare if no headway in 10 s | `ColdOpen`, `ColdOpenCue`, `auto_board` | Keep. Calm weather at spawn guaranteed |
| B1 Bring them home | 0:40–1:30 | Smoke and a pulse ring at the slipway pad; the survivor sits behind you | `ColdOpenCue` shore cues, `transport` | Keep. The reward burst (`OnboardingReward`) flies coins into the wallet; the jet ski stays with you |
| B2 Second survivor | 1:30–3:00 | From the pad, a flare goes up in Calm Bay, Bosun barks toward it, a blip appears | `Onboarding` Station → CallBoard goals walk you into the hall to a leaderboard to accept | Delete the Station and CallBoard goals. Call 2 (Swimmer, Calm Bay) is offered while you're still seated and auto-accepts (K2) |
| B3 Calls 2 and 3 for Cash | 3:00–5:00 | Each delivery rolls Cash into the wallet. Calls 1 to 3 can't fail | `TutorialChain` = Swimmer, Tow, DriftingCraft | Chain = Swimmer, DriftingCraft (1 person), DriftingCraft (2 people) |
| B4 Capacity | ~4:30 | Call 3 has two people. One climbs on; the other's ring turns red (no room). Two trips work, a bigger boat would be faster | `auto_board` red ring exists | Make sure the jet ski is full at 1 and the red ring reads. The RIB silhouette appears on the goal chip (K6) |
| B5 First upgrade | ~5:30 | Cash ≥ 300: the phone button bounces with a red dot. Call 4: an NPC boat races you (K15). Vehicles opens on your jet ski with the Engine card pulsing; buy it, sparks fly and the speed bar grows | Gear beacon to the Chandlery counter (`Onboarding` Gear, `HudShop`) | Delete the Gear goal and the counter. The `Phone` red dot = affordable; VehiclesApp opens on the owned craft with the cheapest affordable upgrade highlighted |
| B6 Phone | first open at B5 | The bounce and dot are the only invitation; tapping the minimap opens Map | `Phone` red dot = event live | Repoint the red dot (K9). Nothing forces the phone before B5 |
| B7 Rank-up | ~8–11 | Rep bar fills, `RankCeremony` plays, the unlock shows the RIB with a lock opening | Cert beacon to the exercise board (`Onboarding` Cert, `holdsOffers`) | Delete the Cert goal and `holdsOffers`. Ranks by Rep only (K7) |
| B8 Daily crate | first time home after B1 | A glowing crate at your bay pops when you walk into it | Crate on the station porch | Move it to the bay (K12) |
| B9 First pet (optional) | ~10+ | Call 5 or 6 is a seal pup in a net; it rides home on your craft and waddles to the pen | WildlifeRescue free + carry | auto_board (K16); TutorialChain[5] = WildlifeRescue |

After B9, `Onboarding.goal` returns nil and the normal mix runs (OfferPacing).

## 5. Work packages

All builders are Opus (high effort) and follow ponytail. Haiku runs check.sh and the real-client playtest.
Run each package in a worktree and merge in the listed order, re-running `~/RobloxProjects/tools/check.sh .`
after each merge.

**Hot-file rule.** A package that deletes a module must remove every `require` of it in the same package, or
`Main.server.luau`'s loader dies (its `require` is not xpcall-guarded). Small removal hunks are allowed in these
shared files, merged in order: `shared/Net.luau`, `DevService`, `DevController`, `TelemetryService`,
`Telemetry/Events`, `TelemetryNames`, `MonetizationConfig`, `DataService`. Dead remotes may stay until WP10.
Outside these, the "Files" column is exclusive.

**Cross-thread conflicts.** VehiclesApp is also touched by the store-arrows thread, VehicleService by the
auto-reset thread, and Phone.luau by the Crew Pay removal (uncommitted). WP7 and WP8 start only after those land.

| # | Package | Files (owned) | Goal | Acceptance |
|---|---|---|---|---|
| WP1 | Simple ops everywhere | `shared/Ops/**` (incl. deleting the Exercise* definitions), `shared/Calls/**`, `client/Mechanics/**`, `server/Ops/**`, `server/Tow/`, `shared/Tow/`, `OperationService`, `RescueService`, Ops/Mech tests | C1, C2, C3 (definitions part), the OffDuty and exercise hooks in OperationService, K1, K16, TutorialChain (B3/B9), CrewRoles use removed | Every definition's mechanics ⊆ {radio_ack, launch, auto_board, transport}; no file in `client/Mechanics` is unreferenced; `smoke.py ops` completes all 7 ops; specs pass |
| WP2 | Progression and shops | `ProgressionConfig`, `ProgressionRules`, `ProgressionService`, `VehicleUpgrades`, `NextGoal`, `NextGoalController`, `RankCeremonyController`, `UI/RankBadge`, `UI/HudShop` (delete), `UI/ProductCard` (delete), `QuickLaunchCard` (delete), `ProductShelves`, `ChandleryRig`, `WorldService`, `HudController`, `ExerciseBoard*` (delete), their specs | C3 (rest), C4, C5, K6, K7, K8, K10, gear data migration | Ranks.spec: a fresh profile reaches rank 3 on Rep alone; a saved `gear.EngineTune` loads as the jet ski Engine upgrade; no shop ProximityPrompt left in Workspace; the Store app still lists every launch id |
| WP3 | Ops UI | `OpsController`, `UI/OpsHud`, `UI/OpsTaskingCard`, `UI/OpsStepCard`, `UI/OpsDebrief`, `UI/OpsConditionMonitor` (delete), `SettingsService` (delete), `SettingsPanel` (Pro row), `BoatController` (OpsPro read) | K2, K4, K5, C16 | Seated player within the offer's heading accepts with no key; no step label over 2 words; no OpsPro reference left; keyboard, touch and gamepad paths checked |
| WP4 | Cut seasonal and clock events | `HalloweenService`/`Controller`/`World`, `WinterService`/`Controller`/`World`, `SeasonalEvents`, `SeasonalRules`, `EventService`, `EventController`, `EventClock`, `LiveOps` + `LiveOpsService` (prune), `StormService` (event refs), `BadgeService`, `RescueVariants` (event refs), their specs | C7, C8, C9, C21 | `grep -r "Halloween\|Winter\|EventService\|EventClock" src` is empty; server log shows every service started with 0 `[Main] … failed` |
| WP5 | Cut side progressions | `Season*`, `SeasonRules`, `Config/Season`, `Challenge*`, `ChallengeRules`, `ChallengeConfig`, `Album*`, `RescueAlbum`, `Exploration*`, `Explore/Discovery`, `Lighthouse*`, `Lighthouses`, `Stock*`, `StockRotation`, `StockConfig`, `StreakService` (challenge/group refs), `PetService` (stock ref), `Livery` (challenge ref), their specs | C6, C11 to C15 | Same grep and boot check; StreakService and PetService specs still pass |
| WP6 | Cut small stuff | `CrewService`, `CrewRoleController`, `CrewRoles`, `FriendService`/`FriendController` (flare), `World/CrewSign`, `CrewSignController`, `VipDeck`, `VipDeckAccess`, `VipStatus`, `CallService`, `CallController`, `UI/CallCard`, `HelloController`, `SwimController` (dive), `VehicleService`/`DogService` (CallService refs only) | C17 to C20 | Crew join via the boat prompt still works (CrewRoles.spec replaced); swimming floats with no DIVE button |
| WP7 | Phone | `UI/Phone`, `UI/VehiclesApp`, `UI/StoreApp`, `UI/EventBoard`, `UI/SeasonBook`, `UI/Logbook` (delete), `EventBoardController`, `EventCalendar` (delete) | C10, C22, K9, B5/B6 (affordable dot, Engine card highlight), K3 (VehiclesApp side) | 6 apps; every app works on keyboard, touch and gamepad; contact sheet of the home screen + Vehicles reviewed by an Opus art-director agent (≤3 rounds) |
| WP8 | Bay, spawn, guide | `VehicleService` (single bay prompt, spawn at bay), `client/World/StreakCrate`, `StreakSign`, `AmbientRescueService`, `DogController`, `server/Npc` NPC racer if separate from `NpcPickup` | K3, K11, K12, K13, K14, K15 | One prompt per bay; a returning player spawns at the bay; with the player idle, a swimmer is visible from the harbour mouth within 45 s; Bosun points within 8 s idle |
| WP9 | First 10 minutes | `Onboarding`, `OnboardingController`, `UI/OnboardingBeacon`, `UI/OnboardingReward`, `UI/ColdOpenCue`, `OnboardingWeather`, `RadioLines` build input (`assets/voice/lines.csv` subtitles), `NewPlayerPace.spec`, `Onboarding.spec`, `Pacing.spec` | Section 4 (B0 to B9), K17, K18 | Pace model: call 2 starts < 2:00, first upgrade ≤ 6:00, rank-up ≤ 11:00; no `holdsOffers`; Haiku fresh-profile real-client run (`tools/roblox/rbx.py`) reaches B7 with no text read |
| WP10 | Sweep and docs | `shared/Net.luau` (dead remotes), `CONTRACT.md`, `DevService`/`DevController`/`UI/DevBoard` tabs, `TelemetryService` funnel, docs/02, 03, 09, 15 (point to this chapter) | Remove what the cuts left behind | `check.sh` clean; `soak.py 12`: 0 errors; no remote without a handler |
| WP11 | Sign-off | read-only | Haiku real-client playtest on the private test place, then one Opus sign-off on the diff and screenshots | All beats hit; publish to the test place via Studio (publish-via-studio) |

**Order and parallelism.** Wave 1 (parallel, disjoint): WP1, WP2, WP4, WP5, WP6. Wave 2: WP3 (after WP1),
WP7 and WP8 (after the other threads land), WP9 (after WP1 and WP2). Wave 3: WP10, then WP11. Impact on a new
player, highest first: WP1, WP9, WP2, WP3, WP7, WP8, WP5, WP4, WP6, WP10.
