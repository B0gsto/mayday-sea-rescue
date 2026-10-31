# NEXT: open code work (handoff, 2026-10-25 evening)

Read first: `docs/00-design.md` (current design), `docs/23-dock-and-core-loop.md` (a)–(n) (why and numbers),
`CONTRACT.md`, `CLAUDE.md`. Main is at the last pushed commit; the test place runs **v42** (forest hub, islands,
cuts; no quests/radio-cut yet). Builders: DeepSeek V4.1 Flash (`opencode/deepseek-v4.1-flash-free`, variant max)
via T3 `delegate_task`; Opus reviews. Checks: `~/RobloxProjects/tools/check.sh .`. Publish: `python3 tools/publish.py`.
Keep this file current: tick items off, add new ones.

## 1. In flight when this was written (merge into main when done)

Each is a branch; check `git log main..<branch>` and `git status` in its worktree. A branch with uncommitted work
means its builder stopped mid-task: finish it there (review the diff first), then merge, run check.sh, push.

| Work | Branch | Worktree | Builder |
|---|---|---|---|




| Docs rewrite, second half (01–04, 07, 15, store text) | `t3/rewrite-current-design-docs` | `t3-d7464e33` | DeepSeek Flash |
| Join reward prompt (rwd1): no daily chest; one Collect prompt (streak + welcome-back + offline crew pay) and the CoinShower; merge, then publish | `t3/4958c3c3` | `t3-4958c3c3` | Opus |
| Sea rework step 1: mesh ocean back on (`USE_MESH_OCEAN`), Part grid fallback; needs a real-client check before publish | `t3/f96b0b89` | `t3-f96b0b89` | Opus |

Stale, safe to delete (cancelled, no changes): worktrees `t3-394fa9ed`, `t3-52b73544`, `t3-6558e19d`, `t3-d3311682`,
`t3-b9289b21`. Not ours (a sibling thread): `t3/cut-seasonal-clock-events`, `t3/cut-side-progressions` — ask
before touching.

Merged since: tutorial playtest fixes (station marker hid during the jet-ski chase camera, ring on the pad, one goal at a time, kit chips; spin beat now points at the wheel; untested: watching the build, F on the Next chip). docs/24 E tutorial + Next chip (Builder-first survivor, arrow to the tablet, Workshop pulse + exact top-up, call during the build, free spin, then the permanent Next chip; untested in Studio; CONTRACT not updated). docs/24 F progression pass (first build 0.8 min: Workshop 500 Cash; tree ~15.1 h, short of 17 h because late Robux skip prices cap late Cash prices; Clinic needs Pontoon; docs/23 (r)). docs/24 C r1 (open work yards, arched hangar, domed sub pen/trophy hall, clutter cut, plaza; parts 654/864/1216; AD r1 "not ship, close", r2 fixes in flight; sheets build/art10). Robux Finish now (FinishNow1/2/3 9/25/49 R$, ready=false, tablet button + site prompt). docs/24 D (spin wheel: SpinService/SpinRules, Spin1/5/15 ready=false, pet variants, boat finishes + wakes, flex banner; Opus-reviewed, 8 fixes, PolicyService gate; not yet seen in Studio; open: no back-pay of free spins for old rescues, restricted-player receipts stay unprocessed). docs/24 B (timed builds, Builders cut time, construction site look; Opus-reviewed, not yet seen in Studio; open: quest blueprints still instant, first build ~8.6 min, 0.25 s flash at site start). docs/24 A (boats board at any speed within 14 studs, no auto-brake, jet ski 52 kn + grippier handling; not yet felt in Studio). WP-23b UI kit (`src/client/UI/Kit/`, FredokaOne, icons in `UiImages.Kit`; art director "ship" on round 3; leftover polish: portrait panels shrink to content, clearer Owned state, stronger studs/tab/subtitle contrast, bigger desktop labels, desktop panel ~50% width); docs rewrite first half (05/06/08/10/12/13/18/19 + archive); flaky Waves timing test fixed. WP-16 asset diet (asset ids 1,478 → 259, texture-pack surfaces 455 → 195, no look changes). Not yet seen in Studio: WP-14c blueprint table + `BuildSeq` Lego build; WP-15 crew lineup (gate dock Lv5 + Coxswain; Mechanic/Lifeguard/Dispatcher 12k/9k/15k Cash, wages 400/300/500 per session). Mechanic now cuts the "Boat to me" cooldown 60 → 42 s. `check.sh` failed once then passed 3× (possible flaky test).

WP-23c: the left-bar "Boat to me" ring uses the server's rule (`MonetizationEffects.boatToMeWait` x `CrewHire.boatToMeScale` from the `CrewMechanic` attribute). The HUD's left side now starts right of the menu strip (HudLayout `menu`); on touch the narrow strip reaches into the top of the thumbstick zone (spec allows only it).

## 2. Queued (in order)

0i. **PERFECT PASS (owner /goal 2026-10-31, thread "Polish Game Art and Progression"): every asset, sprite, VFX, animation and feel item to AD > 9/10.** Tracker: `docs/28-perfect-pass.md`. Wave 1 running: PERF-UI1 (sprites, worktree), PERF-TOUR1 (Studio baseline scores -> build/status/2026-10-31/perfect/tour/SCORES.md), PERF-FEEL1 (feel/progression review), PERF-BL1 (jetty crane, Blender lane: one asset at a time).
0h. **GOAL (owner /goal 2026-10-28): finish the whole game, playtested and perfect from every angle and every kind of progress (music, assets, game feel, everything) so the owner can publish.** Plan, in order:
  WHEEL1 2026-10-31 (branch t3/deca2eee, unpublished, NOT SEEN IN STUDIO: owner stopped Roblox): Lego prize wheel M_Prop_PrizeWheel (Blender, ids in art/source/props/M_Prop_PrizeWheel/RESULT.md) swapped in by PrizeWheel.build(at, handlers, art); Parts stay the fallback; controller swings the flapper by PivotTo (hinge pivot). AD r1 7/10; WHEEL2 (branch t3/3e6adf73, on top of r1): housing + chunky flapper, gems on discs, white trim, raised dividers, brick columns, AD r2 7.5/10; WHEEL3 (branch t3/b4e00ad0, on top of r2): tinted smaller gem discs, warm grey Common + silver gem, crisp bevels (no base smear), stars on the housing plate, slim hub ring, re-uploaded, AD r3 8.4/10 (ships). Needs: Studio spin x several (result lands under pointer), flapper click look, zfight_scan, phone-distance look.
  ONB-STUCK 2026-10-30 (branch t3/a6bf8d9e, unpublished): StuckReset is the boat wall push-off, not a reset. After the first delivery you stay on the jet ski with the station beacon on land; driving at it bounced off the beach again and again. Now a craft pinned against walkable shore with nobody aboard steps you ashore (VehicleExitController.Ashore). The next call waits up to 120 s for the Workshop site (before: offered and auto-accepted in the delivery tick, so its "Go" strip and craft pin competed with the beacon). Island quest pontoons get an invisible skirt (a jet ski slid under the deck, rider wedged). Open: the U-turn after boarding often overshoots the narrow cove mouth into the island beach (push-off frees it).
  ONB-SHORE 2026-10-31 (branch t3/2e9049d7, unpublished): live v21 FirstDelivery 19 -> WorkshopPlaced 8, quitters still seated at sea. Delivery fires on crossing the 80-stud drop zone at speed, so the rider coasts past with the station beacon 60-130 studs away on land, and ambient survivors re-board (1/1 pips) to pull them back out. Now the first delivery docks the jet ski (VehicleService.StepAshore) and stands the rider 8 studs in front of the tablet with the camera on it (OnboardingController.stepToStation; a server PivotTo was undone by the client-owned character); the reward burst plays there. Studio: delivery -> E -> Workshop 500 placed in ~5 s.
  ONB-FIRST10 2026-10-31 (branch t3/18df8f0d, unpublished, NOT SEEN IN STUDIO: owner stopped Studio mid-task): owner's phone first login showed only the tablet frame + a grey prompt. Hut-less spawn moves to DockConfig.newSpawn (22 back, 7 aside, facing the tablet; tablet prompt range 15 -> 24); OnboardingController.frameSpawn plays a 2.6 s crane-down shot ending on the Foot framing (any tap/key skips; reduced motion and respawns just set the framing; join card waits via player attribute Establishing); UI/TabletCue replaces the grey prompt (Custom style: green kit pill, tap-hand / E keycap / X glyph + "Build", one pop; the green build arrow bobs over it while the tablet is the tutorial goal, the beacon mutes). New art: art/source/ui/tap.svg (asset 133375972498905, moderation Reviewing at upload). Needs: phone-view Studio pass (844x390, HudDevice=Touch), shot framing tune (yaw -14, pitch -13, start 40 back 42 up), AD score of the first 10 s.
  ONB-HOLD 2026-10-31 (branch t3/fd44ecc2, unpublished): live v23 trails, the jet ski still pulled new players off. The bay Launch put a seated jet ski out before the Hut (trail A), and after the first delivery they re-boarded the docked ski (B, C). Now OperationService sets player attribute CraftHeld from the delivery until the Workshop is placed or 120 s (stationHoldUntil); VehicleService refuses Launch / Boat to me / a seated Menu spawn before the Hut or while held, and disables the owner's helm seats while held; BoatController hides Launch, Board and the craft pin, the Boat tile rests grey. Studio fresh save: both reproduced on old code, fixed; release on Workshop and at the 120 s cap; returning save unaffected; 0 errors.
  STATUS 2026-10-31 (morning): test place v89, LAUNCH place v24 (= v89, 677a9dab: LIVE7 jet ski held before the Hut and through the Workshop beat 603b0af3, LIVE8 tablet Workshop card scrolls into view on phones + tap the tablet screen opens it b5684cee). Studio fresh-save playtest at a phone view (viewport 844x390, HudDevice=Touch): spawn at the tablet, Boat tile grey, tapping the tablet screen opens build mode, free Hut placed; before the Hut no Launch prompt on the jetty by Berth1; after the first delivery CraftHeld=true, helm seat disabled, Board prompt off, Boat tile grey; tablet opens with the Workshop card on top, Workshop (500) placed in the world 93 s after the delivery -> CraftHeld cleared, seat + Board back, a call live; 0 game-script errors. Returning save (DockDev building all + DataDev rejoin + respawn): Boat tile spawns and seats the jet ski, call O4 offered within 2 min.
  PREV STATUS 2026-10-31 01:55: test place v88, LAUNCH place v23 (= v88, 38dfbc7d: LIVE4 Hut-less spawn at the tablet + no calls/Boat before the Hut 67499869, LIVE5 first delivery docks you at the tablet ba21c3cd, LIVE6 step-off drops the SeatWeld first 6eb43f91, call hold releases on Workshop placed 5dbda327). Studio fresh-save playtest (desktop viewport; play.py has no device emulation): spawn at the tablet, Boat tile grey, Collect, E opens the tablet, free Hut -> cold open starts; after the delivery you stand at the tablet; Workshop placed -> call O2 offered at once (before WorkshopBuilt); step off at the jetty: ski level (upY 0.99+), drift <0.5 studs/30 s, no VehicleRecovered; 0 game-script errors. Returning save (DockDev building all + DataDev rejoin + respawn): spawn at home, Boat tile spawns the jet ski, call O4 offered within 2 min.
  PREV STATUS 2026-10-30 12:45: test place v86, LAUNCH place v21 (= v86, b1fc2c6a: empty hulls server-owned 6f53df9c, step ashore + next call held for the Workshop + pontoon skirt 720c499e, Shop ItemViewed only when open 1e585f41, trail custom fields 2ac3c129). Studio fresh-save playtest x4: spawn -> reward -> free Hut -> cold-open rescue -> delivery clean, 0 game-script errors. (a) no call before the Workshop for 120 s in every run, then one at the cap (the "call right after placing it" half not seen in play: OperationService stationBeat passes no constructionKey, so a placed-but-unbuilt Workshop site still reads BuildStation and the call waits for the build or the 120 s cap). (b) driving the empty jet ski into the shore stepped ashore (3 of 3). (c) the parked jet ski at the jetty stayed level, server-owned, no recoveries for 2+ min (runs 1, 4); run 2 logged one VehicleRecovered Flipped right after the delivery when the ridden ski went under the jetty beams (rider dumped in the water), not a loop.
  PREV STATUS 2026-10-30 01:50: test place v78, LAUNCH place v13 (= v78; universe PUBLIC since 2f206377, ads running). v76/v77/v78 published 2026-10-29/30 (session trails, economy pass, conveyors, quest gate at HQ2, build-mode view, site billboard). Studio fresh-save playtest of v76 clean (spawn -> join reward -> tablet -> free Hut -> cold-open rescue -> Next chip -> map; 0 console errors; onboarding funnel 1-7 in TelemetryDev recent). Session trails verified live: real-client join of test v78, then `python3 tools/trail.py --test --hours 1` showed the session (pos every 30 s, SessionEnd). Asset 203785492 'Asset type does not match' warning: the Rojo Studio plugin's own notification sound, not in the game (LIVE11, 2026-10-31).
  STATUS 2026-10-31: test place v94, LAUNCH place v29 (PUBLIC with ads since 10-29; every checked change goes to test then prod, one publish at a time from an isolated worktree via a Haiku PUB agent; publishes take heavy slots at priority 5). Studio windows hold one of 2 machine heavy slots (tools/studio/hold_window.py); Blender MCP is one shared GUI — Blender agents take turns. Shipped since 10-29: funnel rebuild, tutorial trail (AD 8.6, strip + ring removed), map pin self-calibrating, waypoint rules, HUD preload, economy rebalance + free-roam in the pacing sim, conveyor belts, quests gated to HQ2, build-site billboard + Finish button, sea plates P1/P2 + ramp (docs/27, owner picks in section 7), fuller sea + sea life, idle-worker commons, walk-in actions, HQ interior (8.5) + Trophy Hall Lv1 (8.5), Blender kiosk (8.3) + jetty crane (8.4), asset permissions for the group place (no fallback blocks; empty lot + retry on live), save-flag slots, DEV Free player. Playtests 10-31: new-player 7/10 (fixed: home pin after free-roam, ramp wedge, build watch beat, swimmers near home, jet-ski beaching). Open: real-phone checks (map pin tap, DEV close X, phone portrait), build mode pale frame on real client?, commons props + sea plates need Blender art, owner ideas from WALKIN1 (Workshop bench assist, Fish Market bell, rescue horn), docs/27 Update 1-3, keyd.sh real-client tests.
  PREV STATUS 2026-10-29 (night): test place v75, LAUNCH place v12 (universe PRIVATE). Studio pause lifted; owner rule: the main session delegates all Studio/client work to agents. On main, unpublished: worker crew badge above the name tags + Info prompt nearest-only, no repeated name (5e5358cb). In flight (Opus worktree agents; merge, check.sh, push, then ONE agent publishes test -> full fresh-save playtest -> launch): FUN1 onboarding funnel rebuilt to the current tutorial order (ads launch); STEPS ground trail of arrow tiles to the next tutorial goal + blank Spin strip icon + dark wallet coin; MAPFIX full map drew in px inside the Kit UIScale (pins ~0.82x off, arrow off-centre; patch build/status/2026-10-29/mapfix/map.patch); PROG1 every-save-state Lune audit (fresh/tutorial/mid/late/legacy, soft-locks); AUD1 music/SFX/VFX pairing audit. After: art director on the STEPS trail (8.5+). Badges FriendCrew/FerryHero: scheduled task 2026-10-30 10:00, then republish launch.
  PREV STATUS 2026-10-29 (evening): test place v73, LAUNCH place v10 (= v72, universe PRIVATE). OWNER PAUSED Studio and the Roblox client (no playtests, no publishes) until they say so. Merged in main since v73, unpublished: DEV crew recruit names (059240b4), wallet/offline-pay fix f1063b0a (DataService.OnLoaded hands every handler the LIVE save instead of a BindableEvent copy; WorkerService sets WorkerOffline before paying; also fixes DockService.applyOffline writing to a copy and NotifyService keeping a frozen profile) — verified in Studio by WAL1 before the pause; REV1 (read-only review of all OnLoaded handlers) running. When the owner resumes: publish v74 (test) + launch, real-client rechecks: workers walking up close (DEV Spawn > Crew), offline pay wallet, step off a craft onto the jetty (needs keyd.sh / Space), notification opt-in after a debrief (account eligibility permitting). Badges: Crew Up + Ferry Hero by the scheduled task 2026-10-30 10:00 (free quota). Owner items: thumbnails, maturity questionnaire (paid random items = Yes), genre, keyd.sh, flip the launch universe public.
  PREV STATUS 2026-10-29 (late): test place v72, LAUNCH place v10 (= v72, universe still PRIVATE; going public is the owner's switch). Since v70: build strip/list fixes, step off onto the jetty, DEV click teleport, chat window off the menu (desktop bottom-right), goal pointer clear of the menu, tablet scrolls to its card, chips hide under the debrief, SE Map/Pet fixes, Next chip hidden in build mode, notification opt-in after a rescue debrief (owner), launch badges: 15/17 created (Crew Up + Ferry Hero by the scheduled task 2026-10-30 10:00, free quota). Owner decisions 2026-10-29: ship the faceted Part sea (mesh ocean off), FX1 ships as is. Studio 2026-10-28 UI change: Start Page lost its File menu and File > Publish to Roblox became Publish; studio-open.py uses roblox-studio EditFile, publish_studio accepts Publish. Owner items: thumbnails, maturity questionnaire (paid random items = Yes), genre, keyd.sh for keyboard real-client tests, flip the launch universe public.
  PREV STATUS 2026-10-28 02:45: **v62 published to the test place** (final Studio playtest: ship; 60 fps maxed island at dusk; no game-script errors). In since v61: add-on meshes for every building (HQ Lv1-5, Bunkhouse Lv1-5, all Lv2/Lv3), Trophy Hall statues, lighting study winner C + moonlit night, work loops + commute, music (APM/Monstercat) + soundscape, VFXKit + our Lego flipbooks (AD 8.6; effects 8.5+ except wheel_spin/rescue_done tweaked after r3), skill tree rework, Crew portraits, pets/album polish, store icons (test + launch), save/Robux fixes, perf fixes. Running: RC1 real-client mouse-only pass (keyd.sh not running: keys need the owner's sudo), MOB1 phone/tablet/gamepad emulation. Left: their fixes, owner items (restart test servers, maturity questionnaire, thumbnails, genre/badges), launch publish (`publish_studio.py --launch`).
  1. DONE: every building shows visible Lv2/Lv3 (HQ Lv1-5, Bunkhouse Lv1-5) as AD-passed (8.5+) Blender meshes in game; store icons + UI glyphs; sounds/VFX for key moments; day/night (DayClock.ON) + commute + night lights; work loops; skill tree rework (owner 2026-10-28: only unlockable nodes, fit zoom, corner minimap + card, no Captain zoom, soon nodes after a finished sector); no flashing orange (CLAUDE.md rule).
  2. RUNNING: A1b Studio verify + polish audit (-> build/status/2026-10-28/AUDIT.md), M1 music/soundscape (licensed APM/Monstercat via tools/audio-search.py), R1 save/migration/data-safety/monetization review, R2 late-game + 6-player perf review.
  3. NEXT: fix waves from AUDIT/R1/R2 by area (parallel worktrees); then progression playtests in Studio (one window at a time): new player 0-30 min, mid-game (HQ3), late game (HQ5, all maxed), returning player (offline pay), Robux buyer path vs free path, 2+ players (bridges, neighbours), touch + gamepad, a perf run (tools/studio/perf.luau); fix; publish test (publish_studio.py; restart test servers); real-client playtest on the test place (rbx.py); launch-universe product icons (tools/upload-item-icons.py --launch ...); launch publish (memory: approved after checks + real-client playtest); owner: thumbnails, maturity questionnaire (paid random items = Yes), Creator Hub genre/badges.
0g. **Publish-ready polish push (owner 2026-10-27: "do everything so I can publish ... nothing may look cheap")**. STUDIO PAUSED by the owner (~21:00) until they say continue: no playtests/screenshots/publish. Merged since v61: W6 work loops, F1 sounds+VFX for 11 moments, F2 day/night clock (20-min cycle, DayClock.ON switch; owner to confirm vs the 10-22 'always sunny'), commute + Bunkhouse night lights, z-fight fix (plaza/streets/stubs heights), Bunkhouse r4 (Lv1-5 8.5), building add-on meshes in game: Clinic, Lookout (night lantern + searchlight sweep), Boat Yard (Clinic lot moved 15 back). In the AD loop: Rescue Boathouse r2, HQ Lv4/Lv5 (DeepSeek), Air Station (DeepSeek), Sub Pen (DeepSeek), store icons r2 (Blender; Gemini quota out ~39 h). Queued: Trophy Hall + Boathouse Lv3 add-ons. Waiting on Studio: the A1 polish audit (cancelled, rerun), walk-in checks of every new add-on, dusk/night look review, Lookout watch spot 31 studs up (pathing), Clinic/Boat Yard placement, then publish test + real-client playtest + launch.
0f. **docs/25 wave PUBLISHED as v61 to the test place (2026-10-27)** (WP-29; owner changes docs/25 J, contracts K1-K4). In: HQ 5 levels + building levels/merges, empty start + free Rescue Hut tutorial, build tablet level cards + focus + green arrows, Depot/bricks/barge/Haulers (DepotRules, K4), survivors v2 (6 rarities, traits, specials, pity, name tags + card), radial skill tree + Medals with readers for crew + rescue skills, golden calls, Album specials; Blender meshes (AD 8.5): Rescue Hut/Post, Depot + quay + barge, Bunkhouse Lv1-5 (Lv1-5 stack 8.0), Workshop Lv2/Lv3, Fish Market Lv2/Lv3. Open: restart old test servers (they downgrade v2 survivors); Bunkhouse stair collision snag (fix running); owner to decide a 4th AD round for the Bunkhouse Lv5 terrace (lit bulbs at night + sagging hammocks); W6 job animations + day/night (survivors walk home, Bunkhouse windows light at dusk); skill readers left: DoubleSite, Foreman (Depot side), Celebrity (soon), AirPatrol (soon, Update 2); a dev command to force a golden call; empty-crate icon unverified in Studio. docs/24 G-a2 is dropped.
0e. **In-world wheel + clickable buttons MERGED** (PrizeWheel, PushButton, WheelMath, PrizeWheelController; 52 parts per island; Spin panel gone) (owner 2026-10-26: "no UI, spin in the game visually", "clickable buttons in the game"): D2 task msr-24-D2-r1 (physical Lego wheel on the plaza, ClickDetector push buttons + prompts for gamepad, token machine, odds board; Spin panel removed). After merge: repoint the tutorial spin beat to the wheel; reuse the push button for Finish now on the construction sign.
0d. **docs/24 G skill trees** (owner 2026-10-26): G-b merged (SkillRules 31 nodes, SkillService, Skill* attributes, hooks; tree+skills 17.84 h; open: Crew panel ignores skill caps); G-a1 merged (Kit TreeView + TreeMath, Skills panel + menu button, SkillGrip read by boat handling); next G-a2: the build tablet as a TreeView.
0a. **Owner 2026-10-26: both approved.** (1) Spin products live: after D merges, create the 1/5/15-spin dev products
   (icons via Gemini) on the test and launch universes with `deploy.py ... --steps monetize --only <keys>`, set
   `ready = true`; the owner re-answers the maturity questionnaire (paid random items) in Creator Hub. (2) Robux
   "Finish now" on a running build (after B merges): tiered dev products by time left, same receipt flow.
0b. **Icons blocked**: Gemini image quota (429) until ~2026-10-29 morning: spin.png, spin_1/5/15.png, finish_now.png,
   hourglass.png in `marketing/ui/icons/` (brief: delegate task msr-24-icons-r1). Placeholders until then; products can be
   created without icons and get them later. 2026-10-27: Blender icons landed: Spin1/5/15 + FinishNow1/2/3 product
   icons on the TEST universe (`tools/upload-item-icons.py --only ...`; launch: same with `--launch` and the brightwake
   key, not done yet); Kit glyphs finish_now, waves, sun uploaded. Still open: spin, spin_1/5/15, hourglass glyphs.
0c. ~~Climb lag at speed~~ merged 2026-10-26 (client replays the climb relative to its own hull, `Ops/ClimbPath`); playtest it.
0. **docs/24 wave 2** after A-D merge: E tutorial, F progression/core loop pass (pacing sims with build times + spins), Opus review + Studio playtest, art-director render of C.

1. ~~**WP-14d build tablet**~~ merged 2026-10-25 (build station on Spare3, top-down build mode, Build/Decor tabs, 6 Cash decorations; not yet seen in Studio). Was: replace the blueprint table with a tablet on a stand at a Lego build station near the
   island spawn. Using it tweens the camera to a top-down view of your island; a bottom bar of UI-kit cards lists
   buildable things (Cash + rank / R$ / padlock); picking one pulses its empty lot as a flat outline (never a 3D
   preview); buying plays the BuildSeq Lego build; exit returns the camera. Needs 14c + the kit. docs/23 (n).
2. ~~**WP-23c delete the phone**~~ done on `t3/replace-phone-kit-panels` (also removed the radio strip and goal regions). Was:: remove `Phone.luau` and its apps; left column of kit IconButtons (Shop, Quests,
   Album, Companion, Crew, Settings, Boat to me) opening kit Panels; full map on M with the **fog overlay** drawn
   (DiscoveryController exposes `HubCellOf` / `IsHubRevealed`; nothing draws fog today). Store items move to the
   Shop panel. docs/23 (m).
3. **WP-23d restyle every screen on the kit**: HUD counters, call card + debrief, dock/price cards, boat/craft
   boards, quest talk replies, crew card, settings. (The radio-subtitle strip went in WP-23c.)
4. **Icons**: redo `boat_to_me`, `settings`, `crew` in `marketing/ui/icons/` with Gemini (Antigravity
   `gemini-3.8-flash-high`; its image quota ran out today), then upload and update `UiImages.Kit`.
5. **Map image refresh** after WP-24 (`tools/world/make_map_image.py`, upload changed tiles, `MapConfig.Tiles`).
6. ~~**Launch place server size**~~ done 2026-10-26 (see Launch checklist).
   (The old-design stale data was fixed 2026-10-25: rank `unlocks` name current craft/dock/crew, `CallTypes` says
   islands at 1,100 studs, and the pacing sim already had no garage/seaplane purchases; numbers in docs/23 (i)(7).)
7. ~~**CONTRACT.md refresh** + **code sweep**~~ done 2026-10-26: dead modules / functions / remotes / config cut,
   stale comments fixed, `RingLayout` renamed `RingLayout`, CONTRACT rewritten to match the code. docs/10 still
   names `RingLayout` (docs rewrite thread).
8. **Real-client Opus playtest** of everything since v40 (none was done): a full first session, quests (salvage and
   rescue never tested end to end), dock levels, heli/sub, and **two players spawning boats at once**.
9. **Publish**: test place after each merged batch; the public launch place is approved once checks + the
   real-client playtest pass (memory: publish-launch-approved), with products created there first.

Merged 2026-10-25 night, live in v44 (except plates): phone removed + left menu (WP-23c), build mode v2 (WP-14e), loading flyover, 80-stud drop-off zone, Lego baseplate islands (WP-24, merged after v44). Merged 2026-10-26: WP-27 ring layout (plates 470 studs out, ring bridges, quest pontoon + quest tablet with sail-in givers, rip moved to Puffin Isle, ferry 1,000 S, own-berth-only home; open: chain giver arrives twice, moored boats don't bob, debrief showed +0 twice, unused Aggie/crew dialogue). In flight: WP-28 no ranks + unlock tree (Opus).

## 2a. Goal (owner, 2026-10-26): finish the whole game, fully playable and polished

Path: WP-28 (no ranks + tree, running) → WP-26 workers → quest follow-ups (double giver boat, bobbing, debrief +0,
unused Aggie/crew dialogue) → WP-25 art pass every stage + phone layout (menu vs thumbstick) → code sweep + CONTRACT
refresh → decor Robux products (prices per docs/23 (i) rule) → real-client Opus playtest + fix loop → publish test,
then launch place (server size 6, products created there). In parallel now: ocean far-plane fix (Opus), 3 icons (Gemini).

## 2b. Queued next (owner, 2026-10-25 night)

Order: current batch → **WP-28 no ranks + unlock tree** (docs/23 (q)) → WP-27 ring → WP-26 workers → WP-25 art pass.

- **WP-28 done (awaiting merge)**: ranks/Rep gone; tree in `DockConfig.Buildings`, rules `shared/UnlockTree`;
  old dock levels migrate. Follow-ups: sync the renamed dock products (DockLevel2..5 = Pontoon / Boathouse / Lookout
  / Station, new prices) and rename the 5 rank badges in Creator Hub (now 10/50/200/500/2,000 rescued); Robux
  products for the Cash-only buildings (workshop, crane, helipad, workers) if wanted; worker-building spots need a
  look after the WP-24/27 plates.

- ~~**WP-27 ring layout**~~ done on branch `worktree-agent-ab2f6537443b69f26` (awaiting merge; docs/23 (p) "Done"):
  hub removed, ring at 470, neighbour bridges, quest pontoon + tablet + boats, rip/ferry moved, own-berth home, map
  tiles re-uploaded (moderation "Reviewing"). Open: the cold-open arrival cinematic was hub-only (deleted), pet nap
  spot now your island's station; Dialogue still holds Chief Aggie's / the crew's unused trees. Then WP-26 workers,
  then WP-25 art pass.

- **WP-26 workers done (awaiting merge)** (docs/23 (o), numbers (i) 9): survivors roll category + rarity on pick-up
  (badge billboard), become workers at your berth (`WorkerRules`, `WorkerService`, `data.workers`), walk to their
  building or idle on the jetty, effects via player attributes, Gatherer pay, Rescuer NPC boat, 2 h offline pay; the
  crew lineup is gone (old hires paid back). Follow-ups: real bunkhouse + worker idle art in WP-25 (placeholder
  Lego boat, stock Idle loops, NPCs walk straight lines through walls); the cap fills in ~1:20 of play (then only a
  rarer rescue replaces the first lowest-rarity worker: owner to confirm); ~31 R15 NPCs per full island (x6 servers:
  watch perf); a paid slot expansion if wanted.

- **WP-25 island art pass done (awaiting merge)**: one Lego kit in `DockPieces` (stud plinths, slope-brick roofs, white
  windows, doors in the owner's colour); worker buildings are Lego cottages, re-placed (DockConfig spots) so the plate
  composes; a fixed set on every plate (`DockPieces.base`: grey stud paths spawn -> lanes -> quay -> cove walks ->
  bridges, trees, flower beds, lamps, bunkhouse, lifebuoy stand, capped quay edge with bollards and fenders); the
  name arch is 2x bigger (name on both faces), rescue and boat boards have content, station/hangar have gable roofs,
  no sky beam on the station; Lego bridges (Persistent streaming). AD rounds r1-r3 all "not ship"; open from r3: the
  top-down still reads sparse on the 320-stud plate (lot markers / more groves / hedges), worker billboards overlap
  building signs (WorkerController), helipad windsock, quay walk tile bands. Sheets: build/art/island_r1..r3.png.
  r4-r5 (branch worktree-agent-aeb5393b7d7fa8b6d): lot markers (tan stud pad + peg flag, owner colour), hedges, more trees,
  windsock, owner-colour bands on the quay walks; parts bare 747 / ~50% 944 / full 1246. AD r4, r5 "not ship"; open:
  pads read as dirt (light grey?), hedges/pegs too small from the build camera, trees as clumps, detail in the lower
  quadrants, bloom over the berth; bare start is at the 750 budget (merge parts first).
  r6 (branch worktree-agent-ad77b89e302c8d4b3): lot pads light grey stud plates with an owner-colour rim + corner
  tiles, bigger peg flags, thicker darker hedges, trees in 5 mixed-size clumps, a playground and a beach volleyball
  court in the lower quadrants, softer Harbour Master beacon, board display models drop their lights (the sub
  headlight blew out the cove). Parts bare 741 / ~50% 958 / full 1240. AD r6 "not ship" before its quick fixes
  (applied, sheet build/art/island_r6b.png not re-reviewed); open: bare has ~9 parts of headroom.
  r7 (branch worktree-agent-a6c5959a043f94d59): tan stud beach step + corner rocks round every plate, lighter inner
  lawn, tan paths and bridge decks, slim red/white bridge rails + foot lamps, grey lot pads with a centre build glyph,
  1-part tulip fields on the empty lawn, darker lot beds under built buildings, navy/white berth + slip cranes and
  paint booth, bridge-axis trees removed. Parts bare 729 / ~50% 926 / full 1239. AD r7a and r7b "not ship" (r7b:
  "close"); r7b quick fixes applied (sheet build/art/island_r7c.png, not re-reviewed). Open: buildings small vs
  their lots, small clusters in empty lot corners. Render tool (local, gitignored): build/art7/render.py.
  r8 (branch worktree-agent-a6d23375e7d4de152): huts/tower/slip/hangar/boathouse scaled 1.15-1.4x round their spots
  (DockConfig `scale`, size = scaled footprint; walks, slipway, board slot, paint booth stay 1x), 3-part prop clusters
  in 6 empty corners, a signal mast at the back, a tree per hut, a clinic ambulance, lot flags show the price. Parts
  bare 750 (at budget) / ~50% 959 / full 1283. AD r8 "not ship, close" (open: raised levels, roofline variety);
  quick fixes applied, sheet build/art/island_r8b.png not re-reviewed. Berth notch + slip ramp check: build/art8.
  r9 (branch worktree-agent-a70f5626a3351674a): huts/slip/tower 1.45-1.5x, boathouse 1.2, hangar 1.3 (no-overlap spec
  passes); wide roof eaves with a dark trim; a red/white Lego flag tower behind the station (the sea landmark); once
  the whole tree is built, empty lots become gardens (DockPieces.lotGarden) and 14 garden clusters fill the lawn
  (DockPieces.finish); hedges get red/yellow flower breaks; the bridge-foot lamp sits off the deck. Parts bare 747 /
  ~50% 968 / full 1385. AD r9 "ship" (3 quick fixes applied; sheet build/art/island_r9.png, reviewed one
  island_r9_ad.png). Berth + slip check OK (build/art9, local).
- **WP-25 island art pass** (after WP-24 plates and WP-14e build mode v2 merge): the island/dock must look good at
  EVERY stage (Lv1 bare plate → Lv5 + hangar + sub pen + decor). Owner screenshot issues: the name-sign arch reads
  "the other way around" (make it read correctly from the jetty/boat approach and from land: text on both faces),
  two blank navy boards (boat-board backboard, rescue board) with no content, an over-bright cyan tablet screen,
  muddy terrain textures (gone with the plates). Opus builder renders each stage (contact sheet) → short-lived Opus
  art-director critique → fix, max 3 rounds. Lego style for new pieces; don't redesign existing finished models.

## 3. Decisions (owner, 2026-10-25: "go with your recommendation")

- **Quest chains**: the next chain step unlocks right after the previous one. Done.
- **"Too slow" removed**: calls never fail; a slow rescue gets bronze and less pay. Done.
- **Late-game Cash sink**: island decorations and expansions (extra lots) bought with Cash on the build tablet;
  add with/after WP-14d. Crew wages also help.
- **Sea Chests**: after the first public launch (docs/04 design; re-answer the maturity questionnaire that day).
- **Crew hire Robux price**: propose one when WP-15 lands (above the Cash-pack rate, like dock items), then create
  with `deploy.py ... --steps monetize --only <keys>`.
- **`deploy.py --only`**: stays uncommitted in `~/RobloxProjects/tools/deploy.py` (TameATitan repo, another thread
  has edits in the same file); that thread commits it. Re-add it locally if it disappears.

## Launch checklist (2026-10-26)

Done on the launch universe (10772117922 / place 74810284434342, Brightwake Games, still private):
- Robux items: the 40 live test items (ready ~= false, real test id) exist with the same names, prices,
  descriptions and icons; 23 created today (15 dock, 6 decor products; Rescue Helicopter, Submarine passes), 17
  older ones re-synced. Ids in `deploy/state-launch.json` (retired DockGarage / SeaplanePass pinned to 0).
  New live item later: `ROBLOX_API_KEY_FILE=~/RobloxProjects/.roblox-api-key-brightwake python3 ~/RobloxProjects/tools/deploy.py . 10772117922 74810284434342 --state deploy/state-launch.json --steps monetize --only <keys>`.
- Start place name "Mayday: Sea Rescue", description from `marketing/listing.json`, server size 6 (`--steps info --server-size 6`).
- `publish_studio.py --launch` writes the state-launch ids into MonetizationConfig for the build, then restores
  the file; simulated today: 40 live items, all launch ids, no test ids.

Left, in order:
1. Real-client playtest on an account that owns no passes (shop prompts, dock/decor buys, free path).
2. Creator Hub: store icon upload (thumbnails: the owner makes and uploads their own) (API can't set source-language media), genre/subgenre,
   badge names and descriptions.
3. `python3 tools/studio/publish_studio.py --launch`, then make it public.

## Status 2026-10-26 late: test place v60 (v59 + live Spin1/5/15 + FinishNow1/2/3, also created on the launch universe; placeholder icons marketing/items/{Spin*,FinishNow*}.png = copies of WakeTrails/DockWorkshop, replace when Gemini returns) = docs/24 A-G (any-speed pick-up + handling, timed builds + builders + Finish now, open island r1-r4, in-world prize wheel, tutorial + Next chip, progression pass, build tree + Skills tree). Open: real icons for the 6 products + spin/hourglass glyphs (Gemini quota until ~10-29), owner re-answers the maturity questionnaire (paid random items = Yes), late Robux re-price question, real-client playtest, launch publish.

## Status 2026-10-26 (test place v56, launch place v56 build, private)

Playable end to end in Studio: loading flyover → cold open → calls (ring assist, generous home zone, routing round islands) → build tablet + unlock tree + Lego builds → quest pontoon/tablet → workers (categories, rarity, offline earnings) → Lifeboat / Submarine (diver) / Helicopter (winch cable, auto-land) → ring bridges. 3 Opus playtests, all findings fixed. Launch universe prepped (40 products, server size 6, listing).
Store media ready locally (not uploaded): icon `marketing/icon_v4/icon_final.png` (alt A/B/C); thumbnails come from the owner (ours deleted 2026-10-27).
Verified in Studio since: no-pass mode (`DevNoPasses`, Studio only): free Boat-to-me cooldown, Cash craft buys, Robux gating; real keyboard steering incl. big-craft pick-ups. Saves verified on the real Roblox backend: `python3 tools/persist_check.py` (Luau Execution API on the published test place: write → release → reload in a second session → Open Cloud read) PASS on v52; JSON round-trip spec for a full late-game profile; flag-number cap bug fixed. Waiting on the owner: (1) art: 9 art-director rounds, final verdict SHIP (parts 747 bare / 1,385 full); (2) run `tools/roblox/keyd.sh` (sudo) for a real-client Opus playtest on an account without passes (free Boat-to-me cooldown, Cash craft buys, real steering, real DataStore saves); (3) Creator Hub: upload the icon (the owner brings their own thumbnails), genre/subgenre, rename the 5 badges to rescue milestones; the v53 build is ALREADY published to the launch place (version 6, universe still PRIVATE, launch product ids) — going live = switch the launch universe to Public in Creator Hub (or `deploy.py ... --steps info --public` after the media is up).
Verify 2 (branch `worktree-agent-a246a7dacda24723f`, findings `build/verify2/findings.md`): Studio-only `DevNoPasses` Workspace attribute (no passes / day passes, Studio guard spec'd); free Boat-to-me cooldown, Cash buys (tablet buildings, RIB, Lifeboat), Robux prices + Needs gating, no bolt all verified; real keyboard steering works (RIB turning circle too wide to hit the ring at full throttle); fixed Lifeboat exit reseating you. Real saves blocked: owner must enable Game Settings > Security > "Enable Studio Access to API Services" on the test universe. Open: board card names squeezed when Cash + Robux buttons show.
