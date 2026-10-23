#!/usr/bin/env python3
"""Send Mayday's "come back" notifications from the NotifyDue data store (G49).

usage: tools/notify.py [--send]

The game writes one NotifyDue entry per opted-in player when they leave:
  { "c": <next crate UTC second>, "l": <last notified> }   (older entries may hold "b", ignored)
This tool reads those entries through Open Cloud and sends at most one notification per player per
24 h. Default is a dry run; --send needs every message id in marketing/notifications.json filled in
(the Refusing list names the TODOs). The API key is read from ~/RobloxProjects/.roblox-api-key and
never printed. Fair rules: one per player per day, free content only (docs/15 section 1).

The key needs, for this universe/experience:
  universe-datastores.objects:list, :read, :update   (NotifyDue)
  user.user-notification:write                       (send to players)

shortcut: listing a DataStore returns ids only, so every entry is read each run; past a few
thousand opted-in players switch NotifyDue to an OrderedDataStore due index.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_PATH = os.path.expanduser("~/RobloxProjects/.roblox-api-key")
TEMPLATES_PATH = os.path.join(ROOT, "marketing", "notifications.json")
API = "https://apis.roblox.com"
DAY = 86400
STORE = "NotifyDue"

# kind -> (launch data, analytics category), matching marketing/notifications.md
MESSAGES = {
    "crate_ready": ("panel=dailycrate", "crate_ready"),
    "storm_soon": ("event=greatstorm", "storm_soon"),
}
TEMPLATE_KEYS = ("crate_ready", "storm_soon")


class ApiError(Exception):
    def __init__(self, msg, status=None, body=""):
        super().__init__(msg)
        self.status = status
        self.body = body


def api_key():
    try:
        with open(KEY_PATH) as f:
            return f.read().strip()
    except FileNotFoundError:
        sys.exit(f"missing API key file {KEY_PATH}")


def universe_id():
    for name in ("target.json", "state.json"):
        path = os.path.join(ROOT, "deploy", name)
        if os.path.isfile(path):
            with open(path) as f:
                return int(json.load(f)["universeId"])
    sys.exit("deploy/target.json or deploy/state.json needs a universeId")


def load_templates():
    with open(TEMPLATES_PATH) as f:
        return json.load(f)


def missing_templates(templates):
    return [k for k in TEMPLATE_KEYS if str(templates.get(k) or "").strip() in ("", "TODO")]


class Transport:
    """HTTP calls. 429 is retried with Retry-After/backoff; nothing else is retried."""

    def __init__(self, key):
        self.key = key

    def call(self, method, path, body=None, attempts=4):
        headers = {"x-api-key": self.key}
        data = None
        if body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        url = path if path.startswith("http") else API + path
        for attempt in range(attempts):
            req = urllib.request.Request(url, data=data, method=method, headers=headers)
            try:
                with urllib.request.urlopen(req, timeout=60) as resp:
                    raw = resp.read()
                    return json.loads(raw) if raw else {}
            except urllib.error.HTTPError as e:
                text = e.read().decode(errors="replace")
                if e.code == 429 and attempt < attempts - 1:
                    wait = float(e.headers.get("Retry-After") or 2 ** attempt)
                    time.sleep(min(wait, 60))
                    continue
                raise ApiError(f"{method} {url} -> {e.code}: {text[:300]}", e.code, text)
            except (urllib.error.URLError, TimeoutError, OSError) as e:
                raise ApiError(f"{method} {url} -> network error {e}")
        raise ApiError(f"{method} {url} -> gave up")

    def get(self, path):
        return self.call("GET", path)

    def post(self, path, body):
        return self.call("POST", path, body)

    def patch(self, path, body):
        return self.call("PATCH", path, body)


def kind_for(entry, now):
    """The daily crate when it is ready; None otherwise."""
    return "crate_ready" if int(entry.get("c") or 0) <= now else None


def can_send(entry, now):
    return kind_for(entry, now) is not None and now - int(entry.get("l") or 0) >= DAY


def notification_body(universe, template_id, kind):
    launch, category = MESSAGES[kind]
    return {
        "source": {"universe": f"universes/{universe}"},
        "payload": {"message_id": template_id, "type": "MOMENT"},
        "join_experience": {"launch_data": launch},
        "analytics_data": {"category": category},
    }


def entry_path(universe, user_id):
    quoted = urllib.parse.quote(str(user_id), safe="")
    return f"/cloud/v2/universes/{universe}/data-stores/{STORE}/entries/{quoted}"


def list_due(transport, universe, now):
    """Read the NotifyDue entries and return (userId, entry, kind) for the ones inside the cap."""
    ids = []
    token = None
    while True:
        query = {"maxPageSize": 256}
        if token:
            query["pageToken"] = token
        path = f"/cloud/v2/universes/{universe}/data-stores/{STORE}/entries?{urllib.parse.urlencode(query)}"
        body = transport.get(path)
        ids.extend(e["id"] for e in body.get("dataStoreEntries") or [] if e.get("id"))
        token = body.get("nextPageToken")
        if not token:
            break
    due = []
    for user_id in ids:
        try:
            value = transport.get(entry_path(universe, user_id)).get("value")
        except ApiError as e:
            if e.status == 404:
                continue
            raise
        if isinstance(value, dict) and can_send(value, now):
            due.append((user_id, value, kind_for(value, now)))
    return due


def execute(transport, universe, templates, due, now):
    """Send and record each due entry. A 429 is treated as delivered-for-today: never repeat it."""
    sent = throttled = failed = 0
    for user_id, entry, kind in due:
        did_send = True
        try:
            transport.post(f"/cloud/v2/users/{user_id}/notifications", notification_body(universe, templates[kind], kind))
        except ApiError as e:
            if e.status != 429:
                print(f"FAILED {kind} -> {user_id}: {e}")
                failed += 1
                continue
            print(f"throttled {user_id}, not retrying today")
            did_send = False
        try:
            transport.patch(entry_path(universe, user_id), {"value": dict(entry, l=now)})
        except ApiError as e:
            print(f"{'sent' if did_send else 'throttled'} but could not record last-notified for {user_id}: {e}")
            failed += 1
            continue
        if did_send:
            sent += 1
        else:
            throttled += 1
    return sent, throttled, failed


def main(argv=None):
    parser = argparse.ArgumentParser(description="Send Mayday come-back notifications (dry run by default).")
    parser.add_argument("--send", action="store_true", help="really send; refused while a template id is TODO")
    args = parser.parse_args(argv)

    templates = load_templates()
    missing = missing_templates(templates)
    if args.send and missing:
        sys.exit(f"refusing to send: fill these message ids in marketing/notifications.json: {', '.join(missing)}")

    universe = universe_id()
    now = int(time.time())
    transport = Transport(api_key())
    try:
        due = list_due(transport, universe, now)
    except ApiError as e:
        if e.status == 404:
            print("NotifyDue has no entries yet (the store appears when an opted-in player leaves)")
            return 0
        sys.exit(f"notify: {e}")

    if not args.send:
        for user_id, entry, kind in due:
            print(
                f"would send {kind} to {user_id} "
                f"(crate {int(entry.get('c') or 0)}, "
                f"last {int(entry.get('l') or 0)})"
            )
        print(f"dry run: {len(due)} due, nothing sent")
        return 0

    sent, throttled, failed = execute(transport, universe, templates, due, now)
    print(f"sent {sent}, throttled {throttled}, failed {failed}, of {len(due)} due")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
