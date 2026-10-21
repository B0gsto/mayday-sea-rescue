# Experience notifications: come-back sends from this Mac

The game asks eligible 13+ players for notification permission once, after their first daily crate
(`ExperienceNotificationService`, see `src/client/Controllers/PlatformPromptController.luau`). The
engine reports only that the prompt closed (no accept/decline result), so the game records the
opt-in then as `data.flags.notifyOptIn`; Roblox itself only delivers to players who really opted in.

When an opted-in player leaves, the server writes one entry to the `NotifyDue` DataStore:
the UTC second their next daily crate is ready, the UTC second their strongbox fills, and the UTC
second we last notified them. Nothing runs on a Roblox server while they are offline;
`tools/notify.py` on this Mac reads those entries through Open Cloud and sends at most one
notification per player per 24 h. **No keys in the repo, no sending from a Roblox server.**

## Setup (one time, Creator Hub)

1. Creator Dashboard → your experience → **Engagement → Notifications → Create a Notification
   String**. Identifiers are only for you; the published text is what players see (99 characters
   max, `{experienceName}` allowed). Create three:

   | Identifier | Text |
   | --- | --- |
   | `storm_soon` | `{experienceName}: Great Storm in 10 min` |
   | `strongbox_full` | `Your strongbox is full` |
   | `crate_ready` | `Your daily crate is ready` |

   Copy each string's asset id (`message_id`) into `marketing/notifications.json`, replacing each
   `TODO`:

   ```json
   {
     "crate_ready": "<crate id>",
     "strongbox_full": "<strongbox id>",
     "storm_soon": "<storm id>"
   }
   ```

2. Creator Dashboard → **Credentials → API Keys** → create a key with:
   - `user.user-notification:write`, restricted to this experience;
   - `universe-datastores.objects:list`, `:read` and `:update`, restricted to this universe.

   Store it outside the repo at `~/RobloxProjects/.roblox-api-key` (one line, no quotes). The tool
   never prints it.
3. The universe id comes from `deploy/target.json` (or `deploy/state.json`).

## Run the sender

```bash
python3 tools/notify.py          # dry run (default): prints what it would send, sends nothing
python3 tools/notify.py --send   # real sends
```

`--send` is refused while any id in `marketing/notifications.json` is `TODO`. Each run reads the
`NotifyDue` entries, skips anyone notified in the last 24 h, sends the crate message first (it
repeats daily) or the strongbox message, then writes that player's new "last notified" time back.
A 429 is retried with backoff; if it persists the player is marked as notified for today so the
same send is never repeated. `storm_soon` is not sent automatically (the due entry has no storm
time); keep it for manual sends.

Every 30 minutes from this Mac (a launchd example; nothing in this repo installs it):

```bash
cp tools/com.mayday.notify.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.mayday.notify.plist
# stop it with: launchctl unload ~/Library/LaunchAgents/com.mayday.notify.plist
```

Output and errors go to `/tmp/mayday-notify.log` and `/tmp/mayday-notify.err`.

## Request shape (Open Cloud)

```bash
POST https://apis.roblox.com/cloud/v2/users/${USER_ID}/notifications
x-api-key: <key>
{
  "source": { "universe": "universes/${UNIVERSE_ID}" },
  "payload": { "message_id": "<from notifications.json>", "type": "MOMENT" },
  "join_experience": { "launch_data": "panel=dailycrate" },
  "analytics_data": { "category": "crate_ready" }
}
```

`payload.type` is always `MOMENT`. `launch_data` is a short `key=value` list (nothing reads it
yet; it is there for a future `Player:GetJoinData()` route). `analytics_data.category` groups
delivery/join stats in the Creator Dashboard.

## Fair rules (docs/15 section 1)

- One per player per day, whatever the reason; never repeat a send after Roblox throttles it.
- Free content only: storms, the strongbox and the daily crate are all earnable by playing.
- No notification about a Robux offer, a countdown to a purchase, or a "last chance" on paid stock.
- The in-game offer stays once, then at most weekly after a decline (`PlatformPrompts.NOTIFY_RETRY`).
