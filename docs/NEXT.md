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

Stale, safe to delete (cancelled, no changes): worktrees `t3-394fa9ed`, `t3-52b73544`, `t3-6558e19d`, `t3-d3311682`,
`t3-b9289b21`. Not ours (a sibling thread): `t3/cut-seasonal-clock-events`, `t3/cut-side-progressions` — ask
before touching.

Merged since: WP-23b UI kit (`src/client/UI/Kit/`, FredokaOne, icons in `UiImages.Kit`; art director "ship" on round 3; leftover polish: portrait panels shrink to content, clearer Owned state, stronger studs/tab/subtitle contrast, bigger desktop labels, desktop panel ~50% width); docs rewrite first half (05/06/08/10/12/13/18/19 + archive); flaky Waves timing test fixed. WP-16 asset diet (asset ids 1,478 → 259, texture-pack surfaces 455 → 195, no look changes). Not yet seen in Studio: WP-14c blueprint table + `BuildSeq` Lego build; WP-15 crew lineup (gate dock Lv5 + Coxswain; Mechanic/Lifeguard/Dispatcher 12k/9k/15k Cash, wages 400/300/500 per session). Mechanic now cuts the "Boat to me" cooldown 60 → 42 s. `check.sh` failed once then passed 3× (possible flaky test).

WP-23c: the left-bar "Boat to me" ring uses the server's rule (`MonetizationEffects.boatToMeWait` x `CrewHire.boatToMeScale` from the `CrewMechanic` attribute). The HUD's left side now starts right of the menu strip (HudLayout `menu`); on touch the narrow strip reaches into the top of the thumbstick zone (spec allows only it).

## 2. Queued (in order)

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
6. **Launch place server size**: set the LAUNCH place to 6 (done on the test place via the Open Cloud places API, `serverSize`).
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
- Launch universe has none of today's 10 products yet.
