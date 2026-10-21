# 13 · Release plan

Audit of the repo against chapters 01 to 15 and [`CONTRACT.md`](../CONTRACT.md), and the work left before the public launch. Snapshot: 2026-10-20, private test place 85419402278824 at v14 (universe 10771468869). `tools/check.sh` is red today: 766 pass, 4 `RescueAlbum` failures from the in-flight G63 variants.

## Status 2026-10-20

Playable on the private test place (v14): the cold open, eight operation kinds (PIW, tow, ferry, rip, cliff, sinking, fire, wildlife) plus the certification exercises, ranks 1-8 and Service Stars, certifications, storms and clock events, season, streaks, pets, stock, friends, vehicle upgrades, settings and accessibility, plus 11 paid items live on the test universe. Dozens of systems landed since 2026-10-18; most are tested in Lune and unverified in Studio.

Unverified: every item in `docs/research/studio-pending.md`, the persistence round-trip (no DataStore in an unpublished place), a real phone, the analytics dashboard, and any live purchase. Biggest risks: G63 is mid-flight and has the check red, store art and the dispatcher voice are still absent, badges are dark, the first-session funnel is unmeasured, and the art set has no AD sign-off.

## 0. Summary and the scope decision

The game loop is real and deep: the three MVP operations and five more kinds run end to end, with every step backed by a real mechanic module and no step on the `Default` stub. What blocks a public launch is now verification and media, not core systems:

1. **Monetization is built.** `MonetizationConfig`, idempotent receipts, the policy gate and diegetic cards are in; 11 `ready` items exist on the test universe. Launch-universe ids and a live purchase round-trip are open.
2. **Settings and accessibility are built.** Comfort, Seasick preset, graphics, volumes, voice, Assist/Pro, colour assist, text size, reduce motion and hold-to-tap all save; the Studio panel pass is pending.
3. **Certifications and exercises are built.** Helm, Casualty Care, Rescue Swimmer and Coxswain gate the ranks; the Reopening Day drill exists.
4. **Audio is wired with stand-in clips.** Engines, weather, radio, UI and music stings play; the recorded dispatcher voice is still missing (`VoiceManifest` is empty).
5. **Art is largely shipped.** I2a-c and I2f put the harbour, roads, houses, vehicles, hospital and boatyard in game, and the C2 ferry is wired through `FerryRig`. AD sign-off, C1 casualty craft and the store media are open.
6. **Analytics, badges, leaderboards, challenges, logbook and photo mode are built.** All 31 badges are `id = 0` until U-6; the dashboard is unverified.

**Scope decision (user).** By docs/01 §9, `[L]` "public launch" means the MVP plus the full main island, the Skerries and two outer islands, a player-flown helicopter, five more operations, eight ranks and more. That is several months of work. This plan recommends a two-step release:

- **Launch 1.0 (public):** the MVP scope finished to ship quality. That means P0 and P1 art, monetization limited to items whose effects need no new art, the store page, analytics, settings, mobile, data safety and badges.
- **Content updates (`[L]` remainder):** shipped as live updates after launch, as packages LU-1 to LU-6 in §2.4.

If the user wants the full `[L]` list in 1.0, the LU packages move in front of RP-L2.

## 1. Gap table

| Area | State | What's missing | Effort |
|---|---|---|---|
| Op 1 Person in the Water | done — 11 steps, PIW mechanics, drag / throw arc / 10 s swim-to-player variants (RP-R1), tests | AD/feel playtest | S |
| Op 2 Disabled Vessel | done — 11 steps, Tow mechanics, live tow length, server-side parting, POB per vessel | Real-input play of the tow variants | S |
| Op 3 Capsized Ferry | done — 8 steps, 3 specs; `FerryRig` wires the C2 *Gale Queen* and liferafts (greybox fallback); `art/status/C2.csv` is stale | Studio look at the ferry art | S |
| Ops 8.1, 8.2, 8.4, 8.5 (sinking, fire, rip, cliff) | done — definitions, scenes, mechanics, specs; `soak.py` plays all four | Vessel fire with real input (G11 open) | S |
| Op 8.3 winch | missing — needs the player helicopter (LU-4) | Everything | L, [L] |
| Assist / Pro | done — `SettingsPanel` + `SettingsService` write `OpsPro`; the cold open forces Assist | Studio toggle check | S |
| Certifications and exercises (docs/09 §9.2, §11) | done — Helm, Casualty Care, Rescue Swimmer and Coxswain exercises; Reopening Day drill; rank gates live | O7: prove the care actions with real keys; Studio board pass | S |
| Progression (docs/03) | done — ranks 1-8, Service Stars, rank-up ceremony, pacing sim asserts its bands | Rank 2 lands at ~14-16 min (design call); live payout tuning | S |
| Saving (`DataService`) | done — schema version + migrations, receipt ledger, request-budget checks, save after grant, `BindToClose` cap | Round-trip on a published place (G25b skipped it) | S |
| Crew | done — roles by action, role icons, invite, crew-up flare; NPC crew fills empty seats | Real-friend and 4-player crew paths untested | S |
| Vehicles | done — jet ski, RIB, lifeboat, land fleet with art, trailer launch; 3 upgrades per boat | Helicopter (LU-4); real-phone driving feel | M, [L] |
| Store (Chandlery and BoatDesk) | done — diegetic cards, harbourmaster storm desk, boatyard, Chandlery art; 11 `ready` items have test-universe ids | Launch-universe ids and a live purchase | S |
| Dispatcher and voice (docs/11) | partial — text radio, subtitles and squelch path work; the 1,818-line script exists | Record and upload the lines; paste ids into `VoiceManifest` | M voice |
| Weather and storms | done — full cycle, hourly Great Storm, Ghost Light, storm queue, FX flipbooks | Studio check of the summon queue | S |
| Exploration (docs/10 §5) | done — all `WorldConfig.POIs`, logbook, rewards, On watch / Off duty, snorkel and duck dive, photo mode | Swimming and dive feel unverified in Studio | S |
| Map | partial — 5,120 stud coast map, streaming, GTA-style map and minimap | The rest of the main island, the Skerries and outer islands (LU-5) | L, [L] |
| Cold open and tutorial | done — reward at 0:42 on a fresh profile with real keys (O2), staged HUD, auto-aim after 2 misses | Funnel targets and day-2 return are not measured | S |
| Settings | done — comfort + Seasick preset, graphics, volumes, voice, Assist/Pro, colour assist, text size, reduce motion, hold-to-tap; all saved | Studio panel pass | S |
| Mobile and gamepad | partial — input audit, touch rects and 44 px targets, gamepad bindings | Real phone/tablet pass; controller-only play of every op | M |
| Audio (docs/12 §4) | partial — engines, weather, radio, UI, music stings and barks wired; some stand-ins (puffin, otter) | Recorded dispatcher voice; final recordings | M |
| Monetization (docs/04) | done — config, idempotent receipts, policy gate, effects, cards; 11 `ready` items live on the test universe | Launch ids and a real purchase round-trip | S |
| Analytics | done — 15-step onboarding funnel, 21 custom events, every Cash source and sink | Creator Dashboard visibility unverified | S |
| Badges, leaderboards, challenges | partial — leaderboards and daily/weekly challenges done; all 31 badges are `id = 0` | U-6 badge ids, or ship with badges off | S |
| Text safety | done — no TextBox anywhere; stock TextChatService only | Keep it that way | S |
| Policy | done for 1.0 — nothing paid-random is on sale; the gate exists for later Sea Chests | Maturity questionnaire (U-3) | S |
| Performance | partial — Low-tier caps and streaming numbers in docs/06, measured on desktop Studio | Real-phone memory, instances and frame time (U-10) | M |
| Store page (docs/07) | partial — description draft and 3 in-engine shots in `marketing/thumbnails` | Icon, 5-10 thumbnails, 30 s video, genre and server size (O4, RP-SP1..3) | M |
| Art P0 shipped | partial — V1, V2, H1, H2, K1, G1, B02, CH1, CH6 and the I2f batch are in game | One AD sign-off of the set | S |
| Art P0 in progress | done — HP1, HP2a, HP2b, R1a, H3, S1a, terrain and dune pass shipped (I2a-c) | — | n/a |
| Art P0 not started | done — R1b, H6, K1b, S1b, S2, E1, V3, AN1, FX1, FX2 shipped; CH4 and CH7 replaced by RP-ARMS1 / RP-DOG1 | E2 horizontal lift held (WEAK); CH5 casualty clips unverified | S |
| Art paused | done — R15 avatars replace CH1/CH3 | Decision stands | n/a |
| Art P1 (needed before launch) | partial — V4, H4, H5, C3 shipped; C2 *Gale Queen* + liferaft wired | C1 *Optimist*, kayak and paddleboard; H7 town extras | M |
| Greybox left | partial — houses, station, Chandlery, hospital, harbourmaster, Harbour Light, dock and breakwater swapped; Morwenna and anchor art placed | Fresh `GREYBOX` count (the Chandlery greybox is still tagged in `map/Build.luau`); seaplane wreck still parts (I2d deferred) | S |
| TODO / FIXME | done — 0 hits in `src/` and `map/` | None | n/a |
| Server clock events (docs/15 H1) | done — `EventClock` / `EventService`, hourly Great Storm, 3-hourly Ghost Light, lantern boat | Studio events-board pass (G52) | S |
| Rare calls + Rescue Album (H2) | done — 5 rarities, album, sets, wildlife rows; G63 adds ~16 variants | G63 is red: 4 `RescueAlbum.spec` failures right now | S |
| Rotating Chandlery stock (H3) | done — 10-min UTC restock, 6-8 items, per-player limits, Cash only | Studio shelf and clock check (G17/G62) | S |
| Animal sanctuary + pets (H4) | done — WildlifeRescue, 6 pens, 10-min recovery, adopt, tricks, bond vest | Studio pet visuals (G48/G62) | S |
| Daily streak + welcome back (H5) | done — porch crate, calm day, drop 3 never zero, welcome-back crate | Studio crate check (G19/G62) | S |
| Station idle income (H6) | done — strongbox pot, workshop/radio/kennel levels, capped and flat | Touch/pad is prompt-only; Studio check | S |
| Season Logbook (H8) | done — 30-tier free track, desk + phone app; paid track stays `ready = false` | Studio phone pass | S |
| Friends (H9) | done — +10% Cash per friend (cap 3), crew-up flare, friend spawn | Real-friend path untested solo | S |
| Live ops (G60) | done — MessagingService/MemoryStore, 4 events, board row, `tools/liveops.py` | Studio fake-message test pending | S |
| Come-back notifications (G49) | done code — opt-in, `NotifyDue`, `tools/notify.py` dry run green | User: 3 notification templates and ids; launchd sender | S |
| Seasonal events (H7, G21/G56) | done — Halloween 24 Oct-2 Nov, Frost Fleet 12 Dec-4 Jan, stalls, liveries, collars | Studio checks (G21/G56) | S |
| Vehicle upgrades (G66) | done — 3 upgrades per boat, real stat deltas, visible parts, bitmask save | Fit stands need a Studio look | S |
| Lighthouse missions (G67) | partial — G67 running: relight 4 lights, zone unlocks | Finish, then Studio | S |
| Accessibility (G61) | done — colour-assist symbols, text size, reduce motion, hold-to-tap | Studio check (studio-pending item 12) | S |
| Group reward (G68) | done code — pennant, noticeboard sign, flat +10% crate | User creates the group and pastes `GroupId` | S |

## 2. Work packages

Each package is sized at 40 agent turns or fewer. **Files** lists what the package owns. Two packages can run in parallel only if their file sets don't overlap. Tags: `code`, `asset` (Blender, heavy), `studio-heavy` (Studio or a simulator, so it takes a heavy-job slot and obeys the 2-heavy-jobs limit), `user-only`.

**Status 2026-10-20:** Waves A and B landed (monetization, data hardening, settings, analytics, certifications, badges, logbook, audio, effects, cards). Wave C shipped through I2a-c, I2f and C2; AD sign-off and C1 remain. This section stays as the plan of record; running and queued work is tracked in [`art/bench/QUEUE.md`](../art/bench/QUEUE.md).

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
| RP-M5 (after launch, LU-7) | Rep monetization (docs/04 §3, §4.4): 2x Reputation pass, Rep Boost, Crew Rep Boost, Sea Time Credit (half-band cap per rank), Fast-Track (offered from 75% of a band, price by next rank); Rep multipliers in `ProgressionService.Award`; promotion still waits for its certification; the 5 R$ row (docs/04 §4.6) | `src/shared/MonetizationEffects.luau`, `src/server/Services/Monetization/RepEffects.luau` (new), `src/shared/Config/MonetizationConfig.luau`, tests | code | RP-M2 |
| RP-M6 (after launch, LU-7) | Sea Chests (docs/04 §4.5): odds tables in config, duplicate protection with Cash refunds, pity counter on the profile, `PolicyService` gating with the Cash Driftwood Chest as the unpaid path, salvage-corner chests and the odds slate, lid-lift open in first person | `src/server/Services/Monetization/Chests.luau` (new), `src/shared/Config/ChestConfig.luau` (new), Chandlery props, tests | code + art | RP-M3, cosmetic items |
| RP-M7 (after launch, LU-7) | Signature Vehicles (docs/04 §3.4): four variants (models, engine notes, horns), hooded bay display and plaque, rank-gated drive check in `VehicleService`, unveil at promotion | `src/server/Services/VehicleService.luau`, vehicle art | code + art | RP-M2, vehicle art |

**Open Cloud is possible.** `~/RobloxProjects/tools/deploy.py` already creates game passes (`/game-passes/v1/universes/{u}/game-passes`) and developer products (`/developer-products/v2/universes/{u}/developer-products`). It sets prices and icons, adopts existing items with the same name, writes the real ids back into `MonetizationConfig.luau`, and skips items with `ready = false`. TameATitan already uses it. Mayday's `tools/publish.py` deliberately never calls `monetize`. The API key in `~/RobloxProjects/.roblox-api-key` needs the game-pass and developer-product write scopes for the Mayday universe (U-2). Badges have no such helper and are made by hand (U-6).

### 2.3 Wave C: art to ship quality (asset packages, 2 heavy jobs at a time)

> **Resumed 2026-10-20:** the core landed and the queue shipped through I2f. Remaining art work is RP-ART-AD1, C1, the E2 horizontal lift retry and the store media.

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
| ~~RP-ART-CH4~~ | ~~FP arms~~ Cancelled 2026-10-18: simple arms (RP-ARMS1) | n/a |
| RP-ART-CH5 | Casualty clips on the CH1 R15 rig (tread water, wave, panic, float, shiver, sit wrapped) | asset + studio-heavy |
| ~~RP-ART-CH7~~ | ~~Bosun rig and clips~~ Cancelled 2026-10-18: Bosun goes simple (RP-DOG1) | n/a |
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
| LU-7 | RP-M5 Rep products, RP-M6 Sea Chests, RP-M7 Signature Vehicles (moved out of 1.0 on 2026-10-18 to ship sooner; 1.0 sells the 11 `ready` items) | code + art |

### 2.7 Playtest feedback packages (2026-10-18)

From the user playtest in [document 14](14-playtest-feedback-and-direction.md). These come before Wave D: a launch with the F-1 to F-4 issues open is not launch-ready.

| ID | Deliverable | Tag | Depends on |
|---|---|---|---|
| RP-UX1 | UI audit: icons and short labels instead of text; every element works on keyboard, touch and gamepad (14 §1 F-1, F-2) | code | none |
| RP-UX2 | Cold open rework so the goal reads from the world (14 §1 F-3, §3) | code | RP-R1 |
| RP-UX3 | Space never sinks the swimmer to the seabed (14 §1 F-4) | code | none |
| RP-R1 | Person in the Water rescue variants: drag, throw with aim arc and ghost, casualty swims to the player within 10 s (14 §3) | code | none |
| RP-CH1 | Dressed R15 casualty replaces `M_Chr_Casualty_Swimmer`; R15 clips (14 §4) | code | none |
| RP-DOG1 | Simple Bosun: low-poly dog, no fur cards, simple rig, Roblox animations; refit the harness and Wardrobe cosmetics (14 §4). Replaces RP-ART-CH7 | code + asset | none |
| RP-ARMS1 | First person: hide the body; simple arms only during action animations (wave, phone, throw, haul, grab, CPR and more) (14 §1 F-5, §4). Replaces RP-ART-CH4 | code | none |
| RP-NPC1 | Living town: walkers, joggers, dog walkers, residents at their houses, traffic, weather routines, per-tier caps (14 §5) | code | none |
| RP-PH1 | The phone: free cursor, simple app icons, no shop (14 §6) | code | RP-UX1 |

### 2.6 Parallel schedule (file-set safe)

- **Now (wave A, 8 in parallel):** RP-M1, RP-D1, RP-S1, RP-C1, RP-B1, RP-X1, RP-AU1, plus RP-ART-AD1. RP-A1 waits for RP-M2 because both edit `ProgressionService`.
- **Art (alongside, 2 heavy at a time):** R1b, H6, K1b, S1b, S2, E1, E2, V3, then C1, C2, CH4, CH5, CH7, FX1, FX2, then H4, H5, H7, C3, V4, V5, AN1. One I1 integration after each third.
- **Wave B:** RP-M2 and RP-M3 in parallel (disjoint files), then RP-M4 and RP-A1.
- **Wave D:** RP-P1 and RP-C2 together, then RP-Q1, then RP-SP1, RP-SP2 and RP-SP3, then RP-L1.

## 3. Definition of launch-ready

All of these hold on the launch universe's published build. A tick means true today in code and tests; a bracket left open means unverified or unfinished.

1. [ ] `tools/check.sh` passes. **Today 766 pass, 4 fail** (`RescueAlbum`, G63 in flight). The RP-Q1 soak was 0 errors (10 min, 43 ops). Data saves and loads across a forced shutdown: unverified; the receipt ledger exists but no live purchase round-trip has run.
2. [ ] A new player reaches the first completed rescue under 3 minutes. O2 measured the cold-open reward at 0:42 with real keys on a fresh profile; the 95/70/50 funnel, day-2 return, 4-player crew and the keyboard, touch and gamepad paths are unmeasured.
3. [ ] Zero `GREYBOX`-tagged models and zero part-built hero objects; every P0/P1 row AD-signed. Most swaps shipped and C2 is wired; a fresh greybox count and the AD sign-off are open.
4. [x] Every audible event has sound; the radio works with voice off (subtitles plus squelch). Stand-in clips only; the recorded dispatcher voice is still absent.
5. [ ] Settings: comfort, graphics, volumes, Assist/Pro and accessibility all saved. Code complete; Studio panel pass pending.
6. [ ] Low tier: 30 fps on the reference phone in a storm, memory and instances inside the RP-P1 budget. Desktop Studio numbers only.
7. [ ] Monetization: every `ready` item has a real id, grants once, survives rejoin, and is sold only at a diegetic counter. 11 items exist on the test universe; launch ids and a live purchase are open. Nothing on the docs/04 §7 "never sell" list is for sale; the `PolicyService` gate is in.
8. [ ] Store page: icon, 5+ thumbnails, video, description, genre, server size, and everything shown exists in the game. O4 is queued.
9. [ ] Analytics funnel and economy events visible in the Creator Dashboard. Code done; dashboard unverified.
10. [ ] Every user-only item in §4 is done.

### What's left, by owner

**(a) Agent work running or queued** (`art/bench/QUEUE.md`, 2026-10-20):

- G62 Studio verify batch 1 (touch HUD, pets, cosmetics, lifeboat, winter) — running.
- G63 ~16 rescue variants and seasonal stickers — running; 4 `RescueAlbum` tests red.
- O4 store art capture path and icon — queued (Opus slot).
- O7 real-key care actions and the PIW debrief — running.
- G67 lighthouse missions — running.
- G68 group reward and board text — running.
- G69 call offer pacing — running.
- G70 this document — running.

**(b) Studio checks pending** — one look each, in this order from `docs/research/studio-pending.md`: fresh-profile journey; casualty care as world actions (O5/O7); the G50 bug batch; touch HUD (G51); pets (G48); cosmetics (G38); lifeboat (G39); platform prompts (G47); events board and winter (G52/G56), next-goal and pulse (G58), LiveOps fake message (G60); persistence round-trip (G25b, needs a published place); store art (O4); accessibility (G61); vehicle upgrades (G66).

**(c) The user's own steps:**

- **Badges:** create the 31 badges in Creator Hub and paste ids into `BadgeConfig`, or ship with badges off (`marketing/badges.md`).
- **Group:** create the Roblox group, upload its emblem, paste the id into `SocialConfig.GroupId` (`marketing/products.md`).
- **Notification templates:** create the 3 notification strings, paste their ids into `marketing/notifications.json`, confirm the API key's notification and DataStore scopes, and install the launchd sender if wanted (`marketing/notifications.md`).
- **Products:** after U-1, run `deploy.py ... --steps monetize` on the launch universe so the 11 `ready` items get real ids (`marketing/products.md`).
- **Published test place:** publish a place with API access for the persistence round-trip and the G25b sweep; Studio cannot test DataStore.
- **Real phone test:** one low-end Android or older iPhone for RP-P1/RP-C2 and the touch layout.
- **Store art review:** approve the O4 icon and thumbnail contact sheet, then upload via U-5.
- **Launch deploy:** U-1 to U-11, then RP-L1 and `--public`.

## 4. Items only the user can do

| # | Item | When |
|---|---|---|
| U-1 | **Done 2026-10-20:** the launch experience "Mayday: Sea Rescue" is published (private, Team Create off) under the Brightwake Games group: universe 10772117922, place 74810284434342 (`deploy/launch-target.json`, key `.roblox-api-key-brightwake`). "Mayday: Sea Rescue (Test)" stays as staging. Still open: decide the launch scope (§0): MVP-plus-polish 1.0 or the full `[L]` list | Now |
| U-2 | ~~Give the Open Cloud API key game-pass and developer-product write scopes~~ **Done (user, 2026-10-18):** the key already has these scopes from the other published games. Still create the launch experience in Creator Hub if a new one is used | Done |
| U-3 | Fill in the Maturity and Compliance questionnaire (content maturity label) in Creator Hub. This game has mild peril, unconscious casualties, CPR and drowning risk; answer honestly | Before going public |
| U-4 | **Partly done 2026-10-20 (API):** name, description, server size 16, Discord link (title "Join the crew"; "Discord" is moderated), private servers R$25. Still in Creator Hub: genre, Third-Party Sales/Teleports off check. Experience settings in Creator Hub: genre, devices (phone, tablet, console, desktop), Allow Third-Party Sales and Teleports (both off), private servers (docs/04 §6.1 price), social links (Discord, X, YouTube: the user's own accounts, age-gated by Roblox), voice-chat setting | Before going public |
| U-5 | Review the O4 icon and thumbnail contact sheet, then upload the source-language (English) icon and thumbnails in the Creator Dashboard (`deploy.py media` reports these as "manual"); the video upload (3 per month limit) | After O4, RP-SP1 and RP-SP2 |
| U-6 | Create the 31 badges in Creator Hub (the first 5 per day are free; check the current fee) and paste their ids, or approve shipping with badges off. Names, descriptions and icon concepts are in `marketing/badges.md` | Before RP-B1 goes live |
| U-7 | ~~Buy ElevenLabs credits for the dispatcher voice~~ **Done (user, 2026-10-18)** | Done |
| U-8 | **Done 2026-10-20:** 1,758 user-owned assets granted Use to universe 10772117922 (asset-permissions API); a server preload probe matches the test universe exactly. Audio and asset rights: uploaded audio must be owned by the publishing account or group (or be public Roblox library audio). If the launch universe sits under a different owner (for example a group), assets and audio must be re-uploaded or shared to it | Before RP-L1 |
| U-9 | Roblox account items: ID or age verification if Roblox asks for it before monetization or a public launch; DevEx and payout settings; accepting the Terms of Use and community standards for a monetized experience | Before going public |
| U-10 | A real-phone playtest (RP-P1 and RP-C2 need one low-end Android or older iPhone) and a final play-through sign-off | Before going public |
| U-11 | Press "Public" (or let `deploy.py --public` run after U-1 to U-10) | Launch day |
| U-12 | **Done:** Brightwake Games (548313786) owns the launch experience; `SocialConfig.GroupId` set. Create the Roblox group, upload its emblem, and paste the numeric id into `SocialConfig.GroupId` (0 keeps the sign, pennant and crate bonus off) | Before the group reward goes live |
| U-13 | Create the 3 notification strings in Creator Dashboard, paste their ids into `marketing/notifications.json`, and confirm the API key's `user-notification:write` and universe DataStore scopes | Before `tools/notify.py --send` |
| U-14 | **Done 2026-10-20 except the live purchase:** the 11 `ready` items exist on universe 10772117922 and their ids are in `MonetizationConfig` (`deploy/state-launch.json`; staging ids stay in `deploy/state.json`). Create the 11 `ready` products on the launch universe with `deploy.py ... --steps monetize` after U-1, then run one real purchase round-trip | Before RP-L1 |
| U-15 | Publish a test place with API access and let the G25b sweep prove the persistence round-trip | Before RP-L1 |
