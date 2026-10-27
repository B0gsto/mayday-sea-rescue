# Mayday: Sea Rescue: dev rules

Current design: `docs/00-design.md` (hub forest island + 6 Lego-baseplate player islands, no phone, no town, no cars, no radio). Old designs: `docs/archive/`, git tag `pre-hub-cut`. **Open work and in-flight branches: `docs/NEXT.md`** (read it first in a new thread; keep it current).


- **No choice UI in gameplay.** Never build a menu, card or list where the player picks an option (press 1 / 2 / 3, choose a method, pick a kit). Mechanics are actions in the world only: grab, throw, drive, pull, knock, hold. What to do reads from the world, more than one action works, and nothing is explained in sentences. A device glyph next to a world action is fine. Menus only outside gameplay (the left-button panels: shop, settings, album; in-world counters and boards; the build tablet's top-down build mode). Exception (user, 2026-10-21): talking to an NPC zooms the camera in and shows numbered reply options (1, 2, 3).
- **Show, don't tell.** Icons and 1 to 3 word labels; no paragraph text. Every action works on keyboard, touch and gamepad.
- **Gameplay code uses placeholders until art lands:** code-built Parts or existing assets; core gameplay first.
- **Blender work goes to DeepSeek V4.1 Flash.** Delegate every Blender modelling task through T3 `delegate_task` with
  provider `opencode`, model `opencode-go/deepseek-v4.1-flash`, variant `max`, following `art/bench/PROD_BRIEF.md`.
  Run at most 3 at a time (OpenCode Go rolling limit, 2-slot Blender lock). Queue and status: `art/bench/QUEUE.md`.
- **Asset escalation (owner, 2026-10-27): DeepSeek -> Sonnet -> Opus.** Every asset's art-director round is scored
  out of 10 (ships above 8; at most 3 rounds, a 4th only if truly necessary). When DeepSeek's round fails the bar (or
  it stalls), the next round goes to Sonnet 5.5 at high effort (`claudeAgent`, `claude-sonnet-5-5`, effort `high`);
  when Sonnet's round fails, the next goes to Opus 5.5 at high effort. This project rule overrides "no Sonnet".
- **Code builders: DeepSeek V4.1 Flash Free** (`opencode/deepseek-v4.1-flash-free`, variant max; the OpenCode Go subscription is capped and cancelled) via T3 `delegate_task`, several in parallel; Opus reviews. The free model stalls on cooldowns: a DeepSeek task still running after 2 hours has stalled (owner, 2026-10-27; usually rate limits), so cancel it and finish the work with Opus agents in the same worktree (assets: the next model up, per the escalation rule below). New things are Lego-style; never redesign existing finished assets.
- Module ownership and APIs: `CONTRACT.md`. Checks: `~/RobloxProjects/tools/check.sh .`. Studio driver: `tools/studio/smoke.py`.
- **Playtests are Opus only, never Haiku** (Studio `tools/studio/play.py` or the real client): including quick pass/fail play checks.
- **Thumbnails are the owner's (2026-10-27).** Never make, render, generate or store game/store thumbnails or key art (no `marketing/thumbnails*`); the owner supplies their own. Icons, badges and in-game art are still ours.
- **Publish every tested + checked change to the test place**: once a change passes `check.sh` and its playtest, publish it with `python3 tools/studio/publish_studio.py` (private test place) and commit "Published vN (...)". The launch place (`--launch`) stays a separate step.
