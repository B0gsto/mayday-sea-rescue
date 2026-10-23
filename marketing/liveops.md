# LiveOps: owner-triggered events (G60)

One command makes a free, timed event run on **every server at once**, and players see it coming on
the harbour events board. It is the "admin event" pattern: a shared appointment that spikes
concurrent players without selling anything.

## Schedule one

```sh
# dry run (default): prints the two requests, sends nothing
tools/liveops.py schedule GoldenHour --at "2026-10-25 18:00" --minutes 60

# really send
tools/liveops.py schedule GoldenHour --at "2026-10-25 18:00" --minutes 60 --send
```

- `--at` is **UTC**, `YYYY-MM-DD HH:MM` (a `Z` suffix also works).
- `--minutes` is 1..180 (the game ignores anything longer than 3 h).
- Schedule at least ~15 minutes ahead so the board's countdown and the last-ten-minute HUD banner
  have time to gather players. Up to 7 days ahead is accepted.
- `list` reads the current MemoryStore entry; `cancel` clears the schedule everywhere.
- The universe id comes from `deploy/target.json` (or `deploy/state.json`); `--universe` overrides.
- The API key is read from `~/RobloxProjects/.roblox-api-key` and is never printed. It needs
  `universe-messaging-service:publish` and `memory-store.sorted-map:write` for the experience.

How it travels: the tool writes the JSON into the MemoryStore sorted map `LiveOpsActive` (key
`active`) and publishes the same message on MessagingService topic `LiveOps`. Running servers
subscribe; a server that boots later reads the map and joins/queues the event. Messages carry
`{ event, startsAt, duration, nonce }`; duplicate/old nonces, unknown events, > 7 days ahead, > 3 h
and finished events are ignored.

## The events

| Event | Players see | Effect (free) |
|---|---|---|
| **GoldenHour** | Warm gold sky, gold chip on the HUD | 2x Cash and Rep from rescues and live awards. Passive/flat rewards (crate, season tier) stay flat. Stacks with a Great Storm, like every other Cash multiplier |
| **CalmSeas** | Soft blue sky, gold chip | No new storms for the hour (the paid storm queue waits, the ticket is kept); relaxed, kid-friendly |

Pending events show as a countdown row on the harbour events board and the phone's Events page.
The last 10 minutes also put a gold banner icon + timer on the HUD. While the event runs, the chip
shows its 1-3 word name and the sky is tinted.

## Suggested weekly calendar (UTC)

| Day | Time | Event | Why |
|---|---|---|---|
| Saturday | 18:00 | GoldenHour (60 min) | Peak weekend play; a simple, obvious reward loop |
| Wednesday | 19:00 | CalmSeas (60 min) | Mid-week, low-pressure session for younger players |

Vary the times by an hour or two week to week so different time zones get a turn. One event at a
time; each is at most three hours. Nothing is ever sold by an event, so there is no paid timer to
miss.

## Fair rules (hard, docs/15 section 1)

Many players are children. Time pressure is used for **free, earnable** content only.

- Every LiveOps benefit is free and earned by playing. No event item, boost or ticket is for sale.
- No Robux price ever appears next to an event countdown. No paid random boxes.
- Missing an event loses nothing: no decay, no penalty, no streak break.
- Timers are a clock icon and numbers; events are a sky/world change plus a 1-3 word label.
- Announce in advance (the board row) so players can gather; the owner tool's default is a dry run.
- `cancel` is the off switch: it clears the schedule and every server goes back to normal.

