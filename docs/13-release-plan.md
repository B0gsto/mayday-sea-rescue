# 13 · Release plan

Audit of the repo against chapters 01 to 12 and [`CONTRACT.md`](../CONTRACT.md), and the work left before the public launch. Snapshot: 2026-10-18, private test place 85419402278824 at v13 (universe 10771468869), `tools/check.sh` green (238 Lune tests pass).

## 0. Summary and the scope decision

The game loop is real and deep: all three MVP operations run end to end, with every step backed by a real mechanic module and no step on the `Default` stub. What blocks a public launch is everything around that loop:

1. **No monetization code at all.** No `MarketplaceService`, no `ProcessReceipt`, no `MonetizationConfig.luau`, and no passes or products on the universe (`deploy/state.json` lists none).
2. **No settings menu.** The comfort settings exist as saved data (`src/client/Camera/Comfort.luau`), but no UI calls `Comfort.set`. There is no graphics, audio or Assist/Pro toggle.
3. **No certifications or training exercises.** These are in the MVP keep list (docs/01 §9.1), but rank-ups are Rep only.
4. **Almost no audio.** No engine sounds, no music, no recorded voice. The radio works as subtitles only (the docs/11 §6 fallback).
5. **Art is half done.** Wave 1 and 2a assets are uploaded but still waiting on art-director (AD) sign-off. About half of the P0 rows and all P1 rows are not started. The capsized ferry *Gale Queen*, the hospital, the dock, six houses, the Harbour Light, the breakwater and the seabed POIs are still built from parts.
6. **No analytics, badges, leaderboards, daily challenges, logbook or store page.**

**Scope decision (user).** By docs/01 §9, `[L]` "public launch" means the MVP plus the full main island, the Skerries and two outer islands, a player-flown helicopter, five more operations, eight ranks and more. That is several months of work. This plan recommends a two-step release:

- **Launch 1.0 (public):** the MVP scope finished to ship quality. That means P0 and P1 art, monetization limited to items whose effects need no new art, the store page, analytics, settings, mobile, data safety and badges.
- **Content updates (`[L]` remainder):** shipped as live updates after launch, as packages LU-1 to LU-6 in §2.4.

If the user wants the full `[L]` list in 1.0, the LU packages move in front of RP-L2.

## 1. Gap table

| Area | State | What's missing | Effort |
|---|---|---|---|
| Op 1 Person in the Water | Done end to end (11 steps, `src/shared/Ops/Definitions/PersonInWater.luau`, PIW mechanics, tests) | Expanding-square and sector search [L]; AD/feel playtest | S |
| Op 2 Disabled Vessel | Done end to end (11 steps, Tow mechanics, `MechTow.spec`) | Drifting Craft two-casualty variant [L] | S |
| Op 3 Capsized Ferry | Done end to end (8 steps, Ferry mechanics, 3 specs) | The *Gale Queen* hull is parts built at run time (`RescueService.buildFerry`); needs C2 art | M (art) |
| Ops 8.1 to 8.5 (sinking, fire, winch, rip, cliff) | Not started | Everything | L each, [L] |
| Assist / Pro | Server grading has assist logic (`OperationService`, `Grading`) | No player-facing toggle | S |
| Certifications and exercises (docs/09 §9.2, §11) | Not started; ranks have no certification gate | Helm, Casualty Care and Rescue Swimmer exercises and certifications, plus the Reopening Day drill (MVP) | M |
| Progression (docs/03) | 3 ranks, Cash and Rep, gear levels 1 to 3, RIB purchase (`ProgressionConfig`, `ProgressionService`, `HudShop`) | Ranks 4 to 8 and Service Stars [L]; rank-up ceremony; payouts tuned against the pacing model | M |
| Saving (`DataService`) | UpdateAsync with a session lock, retries and backoff, autosave every 60 s, `BindToClose`, memory fallback in Studio | Schema version and migration; receipt ledger; request-budget checks; save right after a purchase; a cap on how long `BindToClose` waits | S |
| Crew | Player crews of up to 4 (`CrewService`), NPC crew fill empty seats | Role picker for Helm, Nav, Swimmer and Medic (docs/09 §4); crew invite UI | M |
| Vehicles | Jet ski, RIB (`VehicleService`); pickup, Coastguard 4x4, ATV, boat trailer and ambulance (`LandVehicleConfig`, `Car/Trailer.luau`) | Lifeboat and helicopter [L]; final art for the pickup (V3), ambulance (V4), 4x4, trailer and ATV (V5) | M |
| Store (Chandlery and BoatDesk) | Walk-in Chandlery swapped to production art; BoatDesk launch UI; Cash purchases rate limited on the server | Robux product cards on the shelves; the harbourmaster desk for Storm Summon; the boatyard (H4) | M |
| Dispatcher and voice (docs/11) | Text radio works: `RadioPanel` subtitles, `RadioStitch`, `RadioTemplates`, `RadioWheel`, `VoiceManifest`; `assets/voice/lines.csv` script | Recorded lines (ElevenLabs credits, user); squelch and static SFX for the subtitle-only path | S code, M voice |
| Weather and storms | `StormService` full cycle; `WeatherController` rain and lighting; dev chat commands work in Studio only | Storm Summon product queue (docs/04 §5); FX1 and FX2 VFX art | M |
| Exploration (docs/10 §5) | 6 seabed and shore POIs in `WorldConfig.POIs`; 3 wrecks built from parts | Discovery detection, the logbook UI and its rewards; On watch / Off duty; snorkelling and duck dives (no code found); photo mode [L] | M |
| Map | 5,120 x 5,120 stud terrain (`map/generated`), streaming on, GTA-style map and minimap (`MapController`), road ribbons | The full island, the Skerries and the outer islands [L] (MVP coast only today) | L, [L] |
| Cold open and tutorial | Cold open on a jet ski, mid-rescue (`ColdOpenFlow.spec`, `BoatColdOpen.spec`), objective HUD | Arrival cinematic polish; first-session funnel measurement (RP-A1) | S |
| Settings | Comfort data model (FOV, head bob, shake, horizon stabilisation, speed FOV, G-lean, motion blur) saved on the profile; ocean and scatter read `SavedQualityLevel` | The settings panel; graphics override; audio volumes; voice on/off; Assist/Pro; a seasickness preset | M |
| Mobile and gamepad | 24 client files handle touch or gamepad; mechanic panels list touch and pad controls | Device pass on a real phone and a controller; safe-area check on every mechanic panel | M |
| Audio (docs/12 §4) | Only `assets/audio/candidates.csv`; a few SoundIds (weather, tow creak and snap, ferry UI) | Engines, hull slap, wind and sea ambience, UI, music, Bosun barks | M |
| Monetization (docs/04) | Nothing coded; no ids | `MonetizationConfig`, receipt processing, pass checks, effects, product cards | L |
| Analytics | None | `AnalyticsService` funnel, economy and custom events | S |
| Badges, leaderboards, challenges | None (the stock PlayerList is hidden) | `BadgeService` badges (docs/03 §8); leaderboards (OrderedDataStore); daily and weekly challenges [L] | M |
| Text safety | No player text input anywhere (no TextBox); chat is the stock TextChatService (filtered by Roblox) | Keep it that way. A future crew name or photo caption must go through `TextService:FilterStringAsync` | S |
| Policy | No paid random items; docs/04 §8 rules | `PolicyService` check before showing paid items, for regions where they are restricted | S |
| Performance | Streaming on (min 384, target 2048), LowMemory stream-out; LODs in the asset pipeline | No measured mobile budget. Need Low-tier measurements: memory, instances (≤ about 20k streamed, docs/10 §6.7), frame time | M |
| Store page (docs/07) | Specs, three icon concepts, a description draft (§7) | Icon (1024 PNG), 5 to 10 thumbnails, the 30 s video, final description, genre, social links | M |
| Art P0 done (uploaded, AD sign-off pending) | V1 jet ski, V2 RIB, H1 station and slipway, H2 Chandlery, K1 boulders, cliffs 01-05 and ledges 01-03, G1 land plants, B02 materials, CH1 swimmer casualty with R15 rig, CH6 Bosun model | AD sign-off for each | S |
| Art P0 in progress now | HP1 quay, HP2a harbour props, HP2b buoys and nav marks, R1a roads, H3 cottages, S1a *Morwenna* wreck, terrain pass, dune-plant fix | Finish (owned by other agents) | n/a |
| Art P0 not started | R1b street furniture, signs and beach flags; H6 Harbour Light and lifeguard tower; K1b cliffs 06-08, Ledge_04 and the Needle's Eye; S1b bell and Admiralty anchor; S2 kelp and wrack; E1 hand-held kit; E2 rigging kit; V3 lifeguard pickup; CH4 FP arms; CH5 casualty clips; CH7 Bosun rig and clips; AN1 gull; FX1 spray and foam; FX2 rain and flares | All of these | L |
| Art paused | CH1 custom humans and CH3 crew are replaced by R15 avatars (`NpcFactory`, `NpcOutfits`) | Nothing (decision stands) | n/a |
| Art P1 (needed before launch) | Not started | V4 ambulance, H4 harbourmaster and boatyard, H5 hospital, H7 town extras, C2 *Gale Queen* and liferaft, C3 moored boats; C1 *Optimist*, kayak and paddleboard (2a, not started) | L |
| Greybox left | `map/Build.luau` tags children of PortHaven, HarbourLight and Breakwater as `GREYBOX`. Swapped: Station, Slipway, Chandlery | Still greybox: Dock, Hospital, Houses (6), BoatDesk, HarbourLight, Breakwater. Also built from parts: HavenSands, DropOffs, the 3 seabed wrecks (`buildSchooner`, `buildSeaplane`, `buildAnchor`), the *Gale Queen*. That makes 12 visible greybox models plus 6 houses. Fallbacks (NPC block people, Bosun placeholder) are fine as is | M (I1 swaps) |
| TODO / FIXME | `grep TODO\|FIXME\|XXX` in `src/` and `map/` finds 0 hits. Every `greybox` hit is a documented fallback path | None | n/a |

## 2. Work packages

Each package is sized at 40 agent turns or fewer. **Files** lists what the package owns. Two packages can run in parallel only if their file sets don't overlap. Tags: `code`, `asset` (Blender, heavy), `studio-heavy` (Studio or a simulator, so it takes a heavy-job slot and obeys the 2-heavy-jobs limit), `user-only`.

### 2.1 Wave A: core systems (all can start now, in parallel)

| ID | Deliverable | Files (owned) | Tag | Depends on |
|---|---|---|---|---|
| RP-M1 | Monetization core. `MonetizationConfig.luau` in the shape `tools/dump-monetization.luau` and `deploy.py` read (`Products`, `GamePasses`, `ready`, id 0 = off). `MonetizationService` with idempotent `ProcessReceipt` (a receipt ledger on the profile; grant only after the save commits; return `NotProcessedYet` on failure), a `UserOwnsGamePass` cache, `PromptGamePassPurchaseFinished`, and a `PolicyService` gate. Port from `~/RobloxProjects/TameATitan/src/server/Services/Monetization.luau`. Lune spec | `src/shared/Config/MonetizationConfig.luau`, `src/server/Services/MonetizationService.luau`, `tests/Monetization.spec.luau`, `CONTRACT.md` (Monetization section only) | code | none |
| RP-D1 | Data hardening: schema `version` plus a migration table; a `receipts` ledger API (`DataService.CommitReceipt(player, id, grantFn)`); request-budget checks; save right after a grant; a cap on `BindToClose` (parallel saves, under 25 s); a `DataStoreErrors` metric hook | `src/server/Services/DataService.luau`, `tests/Data.spec.luau` (new) | code | none (RP-M1 codes against the API named here) |
| RP-S1 | Settings panel: comfort sliders (FOV, head bob, shake, horizon stabilisation, speed FOV, G-lean, motion blur), a "Seasick-safe" preset, a graphics override (ocean and scatter quality), volumes (master, SFX, radio, music), voice on/off, Assist/Pro. Opens from a HUD gear button and the gamepad Start button | `src/client/UI/SettingsPanel.luau` (new), `src/client/Camera/Comfort.luau`, `src/client/Ocean/OceanQuality.luau`, `src/client/Controllers/ScatterController.luau` (quality read only), one hook line in `HudController.luau` | code | none |
| RP-A1 | Analytics: `AnalyticsService` onboarding funnel (join, cold open steps 1 to n, first op complete, first rank, first Chandlery visit), economy events (every Cash source and sink), custom events (op grade, op fail reason, storm joined). The calls go in through a thin `Telemetry` module | `src/server/Services/TelemetryService.luau` (new), one-line call sites in `OperationService.luau`, `ProgressionService.luau` (Award, BuyGear only) | code | none; run after RP-M2 or with a lock on `ProgressionService` |
| RP-C1 | Certifications and training exercises (MVP): Helm, Casualty Care and Rescue Swimmer exercises as `Ops/Definitions` built from existing mechanics; certification flags on the profile; rank gates (docs/03 §3); the Reopening Day drill; debrief badges | `src/shared/Ops/Definitions/Exercise*.luau` (new), `src/shared/Config/ProgressionConfig.luau` (ranks block), `src/shared/ProgressionRules.luau` (rank gate), `tests/Certs.spec.luau` | code | none |
| RP-B1 | Badges and leaderboards: `BadgeService` awards (badge ids in config, 0 = off), weekly Rep and rescue leaderboards (OrderedDataStore, a station board SurfaceGui) | `src/server/Services/BadgeService.luau`, `src/server/Services/LeaderboardService.luau`, `src/shared/Config/BadgeConfig.luau` (all new) | code | ids from U-6 |
| RP-X1 | Exploration logbook (MVP part): discovery detection for `WorldConfig.POIs` (about 1 Hz on the server), a logbook UI, rewards (docs/03 §8.1), On watch / Off duty states; check that snorkel and duck dive work, or build them | `src/server/Services/ExplorationService.luau`, `src/client/UI/Logbook.luau` (new), `src/shared/Config/WorldConfig.luau` (POI reward fields only) | code | none |
| RP-AU1 | Audio pass: choose and verify ids from `assets/audio/candidates.csv` (public or owned by the creator); jet ski, RIB and car engines; hull slap; wind and sea beds; UI; squelch and static for the subtitle radio; 2 music cues | `src/shared/Config/AudioConfig.luau` (new), `src/client/Controllers/AudioController.luau` (new), sound calls in `BoatController.luau` and `CarController.luau` | code | AU1 search done |

### 2.2 Wave B: monetization effects and store (after RP-M1 and RP-D1)

| ID | Deliverable | Files (owned) | Tag | Depends on |
|---|---|---|---|---|
| RP-M2 | Effects that need no new art: 2x Cash, Starter Kit (Cash only until its livery exists), Quick Launch, the 4 Cash packs, Cash Boost, Crew Boost, Call the Storm and Call the Great Storm (queue of 2, cooldown, docs/04 §5). Cosmetic passes (VIP, Wardrobe, Water Dog Friends, liveries, horn and siren packs, Shanty Radio) stay `ready = false` | `src/server/Services/ProgressionService.luau` (Award multiplier), `src/server/Services/StormService.luau` (summon queue), `src/server/Services/VehicleService.luau` (Quick Launch path only), `MonetizationConfig.luau` (`ready` flags) | code | RP-M1, RP-D1 |
| RP-M3 | Diegetic product cards: Chandlery shelf cards, the BoatDesk Quick Launch card, a harbourmaster storm desk (a greybox desk on the quay until H4), "the player opens every prompt" (docs/04 §1) | `src/client/UI/HudShop.luau`, `src/client/UI/ProductCard.luau` (new), `src/server/World/ChandleryRig.luau`, `map/Build.luau` (`buildHarbourmasterDesk` only) | code | RP-M1 |
| RP-M4 | Create the items: `tools/make-item-icons.py`, then `deploy.py <dir> <universe> <place> --steps monetize,config --dry-run`, then a real run on the test universe, then on the launch universe after U-1 | `marketing/items/*.png`, `deploy/state.json`, `MonetizationConfig.luau` (ids) | code + user-only (API key scopes) | RP-M2, U-2 |

**Open Cloud is possible.** `~/RobloxProjects/tools/deploy.py` already creates game passes (`/game-passes/v1/universes/{u}/game-passes`) and developer products (`/developer-products/v2/universes/{u}/developer-products`). It sets prices and icons, adopts existing items with the same name, writes the real ids back into `MonetizationConfig.luau`, and skips items with `ready = false`. TameATitan already uses it. Mayday's `tools/publish.py` deliberately never calls `monetize`. The API key in `~/RobloxProjects/.roblox-api-key` needs the game-pass and developer-product write scopes for the Mayday universe (U-2). Badges have no such helper and are made by hand (U-6).

### 2.3 Wave C: art to ship quality (asset packages, 2 heavy jobs at a time)

The batches in progress now (HP1, HP2a, HP2b, R1a, H3, S1a, the terrain pass, the dune-plant fix) belong to other agents and are not repeated here. Each package below is one docs/12 batch: Blender build, validation, upload, a Studio pass, and an `art/status/<ID>.csv` row. Files: `art/source/<group>/<asset>/`, `art/status/<ID>.csv`, `assets/models|textures/<asset>*`, and the generated `AssetIds.luau` entries. These are disjoint per batch.

| ID | Batch content | Tag |
|---|---|---|
| RP-ART-AD1 | One Sonnet AD sign-off of the pending wave 1/2a set (V1, V2, H1, H2, K1, G1, B02, CH1, CH6): a contact sheet only, a verdict and fixes listed | asset (review) |
| RP-ART-R1b | Street lamps, benches, bins, bollards, signs, beach flags | asset |
| RP-ART-H6 | Harbour Light, lifeguard tower | asset |
| RP-ART-K1b | Cliff_06 to _08, Ledge_04, the Needle's Eye | asset |
| RP-ART-S1b | Ship's bell, Admiralty anchor, seaplane wreck (needed to swap `buildSeaplane`) | asset |
| RP-ART-S2 | Kelp and wrack | asset |
| RP-ART-E1 | Hand-held kit (throw bag, tube, lifebuoy, blanket, bags, VHF, tablet, flares) | asset |
| RP-ART-E2 | Rigging kit (horizontal lift, fenders and lines from HP2) | asset |
| RP-ART-V3 | Lifeguard pickup | asset |
| RP-ART-CH4 | FP arms (sleeve and glove variants) | asset |
| RP-ART-CH5 | Casualty clips on the CH1 R15 rig (tread water, wave, panic, float, shiver, sit wrapped) | asset + studio-heavy |
| RP-ART-CH7 | Bosun rig and clips | asset |
| RP-ART-FX1 / FX2 | Spray and foam flipbooks; rain and flare flipbooks | asset |
| RP-ART-AN1 | Herring gull and clips | asset |
| RP-ART-C1 | *The Optimist*, kayak, paddleboard (the PIW and DV casualty craft) | asset |
| RP-ART-C2 | *Gale Queen* and liferaft (replaces `RescueService.buildFerry`) | asset |
| RP-ART-H4 / H5 / H7 | Harbourmaster and boatyard; hospital; town extras | asset |
| RP-ART-C3 / V4 / V5 | Moored boats; ambulance; Coastguard 4x4, trailer, ATV | asset |
| RP-I1a, RP-I1b, RP-I1c | Integration after each third of the batches: `Swaps.luau` entries plus `map/Build.luau` greybox removal, until `GREYBOX` count = 0 and the wrecks and ferry use art. Only one I1 package runs at a time (both files are shared) | code + studio-heavy |

### 2.4 Wave D: launch prep (after waves A to C)

| ID | Deliverable | Files (owned) | Tag | Depends on |
|---|---|---|---|---|
| RP-P1 | Performance budget. Measure on the Studio device emulator (Low tier) and on one real phone: client memory under about 1.2 GB on a 3 GB phone (tune), streamed instances ≤ 20k, 30 fps or better on the jet ski in a storm. Tune `StreamingTargetRadius` per quality, scatter caps, ocean LOD. Write the numbers into docs/06 §3.5 | `map/Build.luau` (`setupStreaming` only), `src/client/Controllers/ScatterController.luau`, `src/client/Ocean/OceanQuality.luau`, `docs/06` §3.5 | studio-heavy | RP-I1c |
| RP-C2 | Mobile and gamepad device pass: every mechanic panel at 0.5x screenshot scale on a phone and a tablet, controller-only completion of all 3 ops, fixes | `src/client/Mechanics/**`, `src/client/UI/Layout.luau` | studio-heavy | RP-S1, RP-M3 |
| RP-Q1 | Full-session soak: 4 test clients, 30 min, 2 storms, all 3 ops, purchases in Studio test mode, server shutdown mid-save. Gate: no errors in output, data round-trips | `tools/studio/soak.py` (new) | studio-heavy | waves A and B |
| RP-SP1 | Store art: icon (1024 PNG, concept from docs/07 §2.2) and 5 to 10 thumbnails captured in-engine with the cinematic camera, plus a Medium-quality honesty check; contact sheet to a Sonnet AD | `marketing/icon.png`, `marketing/thumbnails/*.png` | studio-heavy | RP-I1c |
| RP-SP2 | 30 s gameplay video per the docs/07 §5.2 shot list (`studio-window-record`) | `marketing/video/*` | studio-heavy | RP-SP1 |
| RP-SP3 | Store text: final title, description from docs/07 §7 (honest, nothing the game lacks), the genre pick, server size (docs/02, 12 to 16 tune). `deploy.py --steps info` | `marketing/description.md`, deploy args | code | none |
| RP-L1 | Launch deploy: `deploy.py <dir> <launchUniverse> <launchPlace> --steps monetize,config,build,publish,info,media --server-size N`, then `verify-live.py`; `--public` only after U-1 to U-5 are done | `deploy/target.json` (launch entry), `deploy/state.json` | code + user-only | everything above |

### 2.5 Content updates after launch (`[L]` remainder, sequenced)

| ID | Content | Tag |
|---|---|---|
| LU-1 | Ranks 4 to 8, Service Stars, rank-up ceremony, daily and weekly challenges, Challenge Reroll product | code |
| LU-2 | Rip-current beach rescue and the cliff casualty (on the existing map) | code + asset |
| LU-3 | Lifeboat, Coxswain certification, Sinking vessel, Vessel fire | code + asset |
| LU-4 | Player helicopter, Pilot and Winch certifications, winch operations | code + asset |
| LU-5 | Map expansion: the rest of the main island, the Skerries, Puffin Isle, Gannet Rock, lighthouse missions, Trawler on the Rocks | asset + studio-heavy |
| LU-6 | Cosmetic passes (liveries, Bosun's Wardrobe, Water Dog Friends, horns and sirens), the Season Logbook, photo mode, voiced dispatcher (after U-7) | code + asset |

### 2.6 Parallel schedule (file-set safe)

- **Now (wave A, 8 in parallel):** RP-M1, RP-D1, RP-S1, RP-C1, RP-B1, RP-X1, RP-AU1, plus RP-ART-AD1. RP-A1 waits for RP-M2 because both edit `ProgressionService`.
- **Art (alongside, 2 heavy at a time):** R1b, H6, K1b, S1b, S2, E1, E2, V3, then C1, C2, CH4, CH5, CH7, FX1, FX2, then H4, H5, H7, C3, V4, V5, AN1. One I1 integration after each third.
- **Wave B:** RP-M2 and RP-M3 in parallel (disjoint files), then RP-M4 and RP-A1.
- **Wave D:** RP-P1 and RP-C2 together, then RP-Q1, then RP-SP1, RP-SP2 and RP-SP3, then RP-L1.

## 3. Definition of launch-ready

All of these hold on the launch universe's published build:

1. `tools/check.sh` passes. The RP-Q1 soak shows no server or client errors. Data saves and loads across a forced shutdown, and a purchase granted mid-shutdown is never lost or duplicated (receipt ledger).
2. A new player reaches the first completed rescue in under 3 minutes from joining (measured by the RP-A1 funnel in playtests). All 3 operations, the storm and the Capsized Ferry can be completed solo with NPC crew and in a 4-player crew, on keyboard and mouse, touch and gamepad.
3. Zero `GREYBOX`-tagged models and zero part-built hero objects anywhere a player can see. Every P0 and P1 row in docs/12 §2 has passed AD sign-off. The custom-human rows count as done through the R15 decision.
4. Every audible event has sound. The radio works with voice off (subtitles plus squelch).
5. Settings: the comfort options (FOV, head bob, shake, horizon stabilisation, seasick preset), graphics, volumes and Assist/Pro, all saved.
6. Performance on the Low tier: at least 30 fps on the reference phone in a storm. Memory and instance counts are inside the RP-P1 budget.
7. Monetization: every `ready` item has a real id, grants once, survives rejoin, and is shown only at a diegetic counter. Nothing in the docs/04 §7 "never sell" list is for sale. `PolicyService` gating is in place.
8. Store page: icon, 5 or more thumbnails, the video, description, genre and server size set. Everything shown exists in the game.
9. Analytics funnel and economy events are visible in the Creator Dashboard from the test universe.
10. Every user-only item in §4 is done.

## 4. Items only the user can do

| # | Item | When |
|---|---|---|
| U-1 | Decide the launch scope (§0): MVP-plus-polish 1.0 or the full `[L]` list. Decide whether to launch on a new production experience (recommended: keep "Mayday: Sea Rescue (Test)" for staging) or to rename and open the test universe | Now |
| U-2 | Give the Open Cloud API key game-pass and developer-product write scopes (and place publish, universe update) for the launch universe; create the launch experience in Creator Hub if a new one is used | Before RP-M4 |
| U-3 | Fill in the Maturity and Compliance questionnaire (content maturity label) in Creator Hub. This game has mild peril, unconscious casualties, CPR and drowning risk; answer honestly | Before going public |
| U-4 | Experience settings in Creator Hub: genre, devices (phone, tablet, console, desktop), Allow Third-Party Sales and Teleports (both off), private servers (docs/04 §6.1 price), social links (Discord, X, YouTube: the user's own accounts, age-gated by Roblox), voice-chat setting | Before going public |
| U-5 | Upload the source-language (English) icon and thumbnails in the Creator Dashboard (`deploy.py media` reports these as "manual"); the video upload (3 per month limit) | After RP-SP1 and RP-SP2 |
| U-6 | Create the badges in Creator Hub (the first 5 per day are free; check the current fee) and paste their ids, or approve RP-B1 shipping with badges off | Before RP-B1 goes live |
| U-7 | Buy ElevenLabs credits for the dispatcher voice (docs/11 §4 line counts and cost), or ship 1.0 with subtitles only | Any time; optional for 1.0 |
| U-8 | Audio and asset rights: uploaded audio must be owned by the publishing account or group (or be public Roblox library audio). If the launch universe sits under a different owner (for example a group), assets and audio must be re-uploaded or shared to it | Before RP-L1 |
| U-9 | Roblox account items: ID or age verification if Roblox asks for it before monetization or a public launch; DevEx and payout settings; accepting the Terms of Use and community standards for a monetized experience | Before going public |
| U-10 | A real-phone playtest (RP-P1 and RP-C2 need one low-end Android or older iPhone) and a final play-through sign-off | Before going public |
| U-11 | Press "Public" (or let `deploy.py --public` run after U-1 to U-10) | Launch day |
