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
| WP-24 player islands → flat Lego baseplates (`IslandPlates`, terrain re-bake, bridges, HubLayout Y) | `t3/add-player-island-baseplates` | `~/.t3/worktrees/MaydaySeaRescue/t3-a3bff4ae` | DeepSeek Flash |
| Docs rewrite, second half (01–04, 07, 15, store text) | `t3/rewrite-current-design-docs` | `t3-d7464e33` | DeepSeek Flash |
| WP-23c delete the phone, left button column + kit panels, map fog overlay, kit polish | a `t3/...` branch | `~/.t3/worktrees/MaydaySeaRescue/` | DeepSeek Flash |
| Loading screen + top-down circling flyover onto your island (Chad Tycoon style; ref video `~/RobloxProjects/chad-loading-transition/`) | a `t3/...` branch | `~/.t3/worktrees/MaydaySeaRescue/` | DeepSeek Flash |

Stale, safe to delete (cancelled, no changes): worktrees `t3-394fa9ed`, `t3-52b73544`, `t3-6558e19d`, `t3-d3311682`,
`t3-b9289b21`. Not ours (a sibling thread): `t3/cut-seasonal-clock-events`, `t3/cut-side-progressions` — ask
before touching.

Merged since: WP-23b UI kit (`src/client/UI/Kit/`, FredokaOne, icons in `UiImages.Kit`; art director "ship" on round 3; leftover polish: portrait panels shrink to content, clearer Owned state, stronger studs/tab/subtitle contrast, bigger desktop labels, desktop panel ~50% width); docs rewrite first half (05/06/08/10/12/13/18/19 + archive); flaky Waves timing test fixed. WP-16 asset diet (asset ids 1,478 → 259, texture-pack surfaces 455 → 195, no look changes). Not yet seen in Studio: WP-14c blueprint table + `BuildSeq` Lego build; WP-15 crew lineup (gate dock Lv5 + Coxswain; Mechanic/Lifeguard/Dispatcher 12k/9k/15k Cash, wages 400/300/500 per session). Mechanic now cuts the "Boat to me" cooldown 60 → 42 s. `check.sh` failed once then passed 3× (possible flaky test).

When merging WP-23c: the mechanic fix put the shortened cooldown into the old phone `VehiclesApp` ring (`MonetizationEffects` cooldown arg + the `CrewMechanic` player attribute); make sure the new left-bar "Boat to me" ring uses the same rule.

## 2. Queued (in order)

1. ~~**WP-14d build tablet**~~ merged 2026-10-25 (build station on Spare3, top-down build mode, Build/Decor tabs, 6 Cash decorations; not yet seen in Studio). Was: replace the blueprint table with a tablet on a stand at a Lego build station near the
   island spawn. Using it tweens the camera to a top-down view of your island; a bottom bar of UI-kit cards lists
   buildable things (Cash + rank / R$ / padlock); picking one pulses its empty lot as a flat outline (never a 3D
   preview); buying plays the BuildSeq Lego build; exit returns the camera. Needs 14c + the kit. docs/23 (n).
2. **WP-23c delete the phone**: remove `Phone.luau` and its apps; left column of kit IconButtons (Shop, Quests,
   Album, Companion, Crew, Settings, Boat to me) opening kit Panels; full map on M with the **fog overlay** drawn
   (DiscoveryController exposes `HubCellOf` / `IsHubRevealed`; nothing draws fog today). Store items move to the
   Shop panel. docs/23 (m).
3. **WP-23d restyle every screen on the kit**: HUD counters, call card + debrief, dock/price cards, boat/craft
   boards, quest talk replies, crew card, settings; remove the empty radio-subtitle strip (`HudLayout` + spec).
4. **Icons**: redo `boat_to_me`, `settings`, `crew` in `marketing/ui/icons/` with Gemini (Antigravity
   `gemini-3.8-flash-high`; its image quota ran out today), then upload and update `UiImages.Kit`.
5. **Map image refresh** after WP-24 (`tools/world/make_map_image.py`, upload changed tiles, `MapConfig.Tiles`).
6. **Launch place server size**: set the LAUNCH place to 6 (done on the test place via the Open Cloud places API, `serverSize`).
   (The old-design stale data was fixed 2026-10-25: rank `unlocks` name current craft/dock/crew, `CallTypes` says
   islands at 1,100 studs, and the pacing sim already had no garage/seaplane purchases; numbers in docs/23 (i)(7).)
7. **CONTRACT.md refresh** after 23c/23d (it still lists the phone and other removed modules), then a **code sweep**: comments, strings and names still mentioning Port Haven, the phone, the radio, the town, cars
   (after 23c/23d so it doesn't collide).
8. **Real-client Opus playtest** of everything since v40 (none was done): a full first session, quests (salvage and
   rescue never tested end to end), dock levels, heli/sub, and **two players spawning boats at once**.
9. **Publish**: test place after each merged batch; the public launch place is approved once checks + the
   real-client playtest pass (memory: publish-launch-approved), with products created there first.

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
- Launch universe has none of today's 10 products yet.
