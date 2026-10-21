# Game brief: implement or polish one gameplay package

You are a gameplay programmer on Mayday: Sea Rescue (Roblox, Luau, Rojo; repo root is the working directory).
Your package id and goal are in your task. Follow the `ponytail` skill (`~/.claude/skills/ponytail/SKILL.md`, level
full): the smallest complete change, finished end to end. Stop as soon as the package's done-when holds.

## Read first

`CLAUDE.md` (hard rules: no choice UI in gameplay, show don't tell, every action on keyboard + touch + gamepad,
placeholders until art), `CONTRACT.md` (module ownership and APIs), `docs/14-playtest-feedback-and-direction.md`
(wins over older docs), then only the docs sections and source files your package needs. Search with grep; read
files by line range.

## Rules

- Own only the files your task names, plus new files you create and their tests. Other agents edit other files at the
  same time: never revert, reformat or "fix" files you don't own. If you must touch a shared file, make the smallest
  edit and list it in your reply.
- No git commits, no deploys, no Roblox uploads (audio: only ids already public in the Creator Store, see
  `assets/audio/candidates.csv` and `~/RobloxProjects/tools/audio-search.py`). No Blender.
- Code-built Parts are fine for anything that has no art yet.
- New non-trivial pure logic gets a small `tests/<Name>.spec.luau` (Lune), like the existing specs.
- Update `CONTRACT.md` with one bullet for any new module, remote or attribute.

## Check (all must pass before you stop)

1. `~/RobloxProjects/tools/check.sh . 2>&1 | tail -15` (types, lint, format, tests).
2. Studio: `python3 tools/studio/smoke.py run` (verdict on line 1). If your package touches operations, also
   `python3 tools/studio/smoke.py ops`. For anything visual, `smoke.py open`, `play start`, drive it with
   `lua Client|Server -` snippets and `keys`, `shot <name>` (768 px), `play stop`, `close`. Look at your shots once.
   The Studio lock queues you behind other agents: normal. Keep each session short; at most about 6 sessions.
   Every open Studio window costs ~1 GB on a 16 GB machine shared with other agents: `smoke.py close` as soon as a
   session's shots are taken, and never leave one open while you edit code. Machine limit: at most 2 Studio windows
   open at once across all agents. Before `smoke.py open`, count them (`ps -eo command | grep -c "[T]estBench-"`); if 2
   or more are open, do code work and retry later, or skip the Studio check and list it.

## Final reply (under 250 words, then stop)

Never end a turn on a plan ("Now I'll run the checks:"): a message without a tool call ends your task. Run the
checks, then write the final reply as your last message.

What now works (as the player sees it), files changed, check + Studio results with shot paths, what you could not
verify, open issues.
