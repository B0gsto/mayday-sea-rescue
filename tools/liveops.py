#!/usr/bin/env python3
"""Owner tool for Mayday: Sea Rescue live events (G60).

usage:
  tools/liveops.py schedule GoldenHour --at "2026-10-25 18:00" --minutes 60 [--send]
  tools/liveops.py list [--send]
  tools/liveops.py cancel [--send]

`schedule` publishes {event, startsAt (UTC epoch s), duration (s), nonce} on the MessagingService
topic "LiveOps" and writes the same JSON into the MemoryStore sorted map "LiveOpsActive" (key
"active"), so every running server hears it and every server booting later reads it. `cancel`
deletes that entry and publishes {event: "Cancel"}.

Default is a dry run: prints the requests and sends nothing. Real sends need --send and the API key
at ~/RobloxProjects/.roblox-api-key (never printed). The key needs, for the universe:
  universe-messaging-service:publish            (topic LiveOps)
  memory-store.sorted-map:write                 (LiveOpsActive)

Fair rules (docs/15 section 1): every event is free and earnable by playing; nothing is sold.
Suggested weekly calendar and the full rules: marketing/liveops.md.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_PATH = os.path.expanduser("~/RobloxProjects/.roblox-api-key")
API = "https://apis.roblox.com"
TOPIC = "LiveOps"
SORTED_MAP = "LiveOpsActive"
ITEM_ID = "active"

MIN_MINUTES = 1
MAX_MINUTES = 180
MAX_LEAD = 7 * 86400
MAX_NONCE = 64

# Mirrors src/shared/LiveOps.luau: label and default length. The game owns the rules.
EVENTS = {
    "GoldenHour": ("Golden hour", 60),
    "LegendaryRush": ("Legendary rush", 30),
    "CalmSeas": ("Calm seas", 60),
    "DoubleCandy": ("Double candy", 60),
}


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
                value = json.load(f).get("universeId")
            if value:
                return int(value)
    sys.exit("deploy/target.json or deploy/state.json needs a universeId")


def event_name(text):
    wanted = text.strip().lower()
    for key in EVENTS:
        if key.lower() == wanted:
            return key
    raise SystemExit(f"unknown event {text!r}; choose one of: {', '.join(EVENTS)}")


# ------------------------------------------------------------------------- request building

def parse_at(text):
    """A UTC wall-clock time: 'YYYY-MM-DD HH:MM', 'YYYY-MM-DDTHH:MM', with optional :SS and Z."""
    clean = text.strip().replace("Z", "")
    for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d"):
        try:
            return int(datetime.strptime(clean, fmt).replace(tzinfo=timezone.utc).timestamp())
        except ValueError:
            continue
    raise SystemExit(f"cannot read the time {text!r}; use 'YYYY-MM-DD HH:MM' in UTC")


def utc_text(seconds):
    return datetime.fromtimestamp(int(seconds), tz=timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


def build_message(event, starts_at, minutes, now=None, nonce=None):
    now = int(now if now is not None else time.time())
    name = event_name(event)
    minutes = int(minutes)
    if minutes < MIN_MINUTES or minutes > MAX_MINUTES:
        raise SystemExit(f"--minutes must be {MIN_MINUTES}..{MAX_MINUTES} (the game ignores over 3 h)")
    starts_at = int(starts_at)
    if starts_at + minutes * 60 <= now:
        raise SystemExit("that start is already over; pick a future time (or use cancel)")
    if starts_at - now > MAX_LEAD:
        raise SystemExit("the game ignores events more than 7 days ahead")
    nonce = nonce or uuid.uuid4().hex
    if not nonce or len(nonce) > MAX_NONCE:
        raise SystemExit(f"--nonce must be 1..{MAX_NONCE} characters")
    return {
        "event": name,
        "startsAt": starts_at,
        "duration": minutes * 60,
        "nonce": nonce,
    }


def publish_request(universe, message):
    body = {"message": json.dumps(message, separators=(",", ":"))}
    return ("POST", f"/messaging-service/v1/universes/{int(universe)}/topics/{TOPIC}", body)


def item_path(universe):
    return (
        f"/cloud/v2/universes/{int(universe)}/memory-store/sorted-maps/{SORTED_MAP}"
        f"/items/{ITEM_ID}"
    )


def write_request(universe, message, now=None):
    now = int(now if now is not None else time.time())
    seconds = max(60, message["startsAt"] + message["duration"] - now + 86400)
    seconds = min(seconds, 45 * 86400)  # MemoryStore's maximum item lifetime
    path = item_path(universe) + "?" + urllib.parse.urlencode({"allowMissing": "true"})
    body = {"value": json.dumps(message, separators=(",", ":")), "ttl": f"{seconds}s"}
    return ("PATCH", path, body)


def delete_request(universe):
    return ("DELETE", item_path(universe), None)


def read_request(universe):
    return ("GET", item_path(universe), None)


def cancel_message(now=None, nonce=None):
    return {"event": "Cancel", "nonce": nonce or uuid.uuid4().hex}


# ------------------------------------------------------------------------- transport

class Transport:
    """HTTP calls. 429 is retried with Retry-After/backoff; nothing else is retried."""

    def __init__(self, key):
        self.key = key

    def call(self, method, path, body=None, allow_404=False, attempts=4):
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
                if e.code == 404 and allow_404:
                    return None
                if e.code == 429 and attempt < attempts - 1:
                    wait = float(e.headers.get("Retry-After") or 2 ** attempt)
                    time.sleep(min(wait, 60))
                    continue
                raise ApiError(f"{method} {url} -> {e.code}: {text[:300]}", e.code, text)
            except (urllib.error.URLError, TimeoutError, OSError) as e:
                raise ApiError(f"{method} {url} -> network error {e}")
        raise ApiError(f"{method} {url} -> gave up")


def execute(transport, requests):
    out = []
    for method, path, body in requests:
        out.append(transport.call(method, path, body, allow_404=(method == "DELETE")))
    return out


def describe(requests):
    lines = []
    for method, path, body in requests:
        lines.append(f"{method} {API}{path}")
        if body is not None:
            lines.append(json.dumps(body, indent=2))
    return "\n".join(lines)


# ------------------------------------------------------------------------- commands

def schedule(args, now=None):
    message = build_message(
        args.event, parse_at(args.at), args.minutes, now=now, nonce=args.nonce
    )
    universe = args.universe or universe_id()
    requests = [write_request(universe, message, now=now), publish_request(universe, message)]
    if args.send:
        execute(Transport(api_key()), requests)
        print(f"sent {message['event']} {utc_text(message['startsAt'])} for {message['duration'] // 60} min")
    else:
        print(f"dry run (add --send): {message['event']} {utc_text(message['startsAt'])} "
              f"for {message['duration'] // 60} min")
        print(describe(requests))
    return message


def cancel(args, now=None):
    universe = args.universe or universe_id()
    message = cancel_message(now=now, nonce=args.nonce)
    requests = [delete_request(universe), publish_request(universe, message)]
    if args.send:
        execute(Transport(api_key()), requests)
        print("cancelled the LiveOps schedule")
    else:
        print("dry run (add --send): cancel the LiveOps schedule")
        print(describe(requests))
    return message


def list_schedule(args, now=None):
    universe = args.universe or universe_id()
    now = int(now if now is not None else time.time())
    if not args.send:
        print(f"dry run (add --send): read {SORTED_MAP}/{ITEM_ID}")
        print(describe([read_request(universe)]))
        return None
    item = Transport(api_key()).call("GET", item_path(universe), allow_404=True)
    if not item or not item.get("value"):
        print("no scheduled LiveOps event")
        return None
    message = json.loads(item["value"])
    starts = int(message.get("startsAt") or 0)
    duration = int(message.get("duration") or 0)
    if now >= starts + duration:
        phase = "over"
    elif now >= starts:
        phase = "active"
    else:
        phase = "pending"
    print(f"{message.get('event')}: {utc_text(starts)} for {duration // 60} min ({phase}) "
          f"nonce {message.get('nonce')}")
    return message


def main():
    ap = argparse.ArgumentParser(description="Schedule Mayday live events across every server.")
    ap.add_argument("--universe", type=int, help="override deploy/target.json")
    sub = ap.add_subparsers(dest="command", required=True)

    sched = sub.add_parser("schedule", help="publish a future or running event")
    sched.add_argument("event", help=", ".join(EVENTS))
    sched.add_argument("--at", required=True, help="UTC start, 'YYYY-MM-DD HH:MM'")
    sched.add_argument("--minutes", type=int, required=True, help="1..180")
    sched.add_argument("--nonce", default=None, help="idempotency key (default: random)")
    sched.add_argument("--send", action="store_true", help="really send (default: dry run)")

    lst = sub.add_parser("list", help="show the scheduled event in MemoryStore")
    lst.add_argument("--send", action="store_true", help="really read (default: dry run)")

    can = sub.add_parser("cancel", help="clear the schedule everywhere")
    can.add_argument("--nonce", default=None, help="idempotency key (default: random)")
    can.add_argument("--send", action="store_true", help="really send (default: dry run)")

    args = ap.parse_args()
    try:
        if args.command == "schedule":
            schedule(args)
        elif args.command == "cancel":
            cancel(args)
        else:
            list_schedule(args)
    except ApiError as e:
        sys.exit(f"API error: {e}")


if __name__ == "__main__":
    main()
