# Mayday: Sea Rescue: dev rules

- **No choice UI in gameplay.** Never build a menu, card or list where the player picks an option (press 1 / 2 / 3, choose a method, pick a kit). Mechanics are actions in the world only: grab, throw, drive, pull, knock, hold. What to do reads from the world, more than one action works, and nothing is explained in sentences. A device glyph next to a world action is fine. Menus only outside gameplay (settings, the phone home screen, in-world shop counters). Exception (user, 2026-10-21): talking to a town NPC zooms the camera in and shows numbered reply options (1, 2, 3). See docs/14 §2.
- **Show, don't tell.** Icons and 1 to 3 word labels; no paragraph text. Every action works on keyboard, touch and gamepad.
- **Gameplay code uses placeholders until art lands:** code-built Parts or existing assets; core gameplay first.
- **Blender work goes to DeepSeek V4.1 Flash.** Delegate every Blender modelling task through T3 `delegate_task` with
  provider `opencode`, model `opencode-go/deepseek-v4.1-flash`, variant `max`, following `art/bench/PROD_BRIEF.md`.
  Run at most 3 at a time (OpenCode Go rolling limit, 2-slot Blender lock). Queue and status: `art/bench/QUEUE.md`.
- Module ownership and APIs: `CONTRACT.md`. Checks: `~/RobloxProjects/tools/check.sh .`. Studio driver: `tools/studio/smoke.py`.
