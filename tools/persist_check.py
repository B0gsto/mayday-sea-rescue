#!/usr/bin/env python3
"""Prove Mayday save data persists on the real Roblox backend.

Runs the game's own DataService (load -> mutate -> save + release) in the published test place through
the Open Cloud Luau Execution API, then loads the same profile in a SECOND execution session and
compares every saved field. A third check reads the stored entry through the Open Cloud DataStore API.
The test key (Player_<id>, default -77) is removed at the end unless --keep is passed.

usage: tools/persist_check.py [--player-id -77] [--version N] [--keep] [--json out.json]

The API key is read from ~/RobloxProjects/.roblox-api-key and never printed. The place/universe come
from deploy/target.json unless --universe/--place are given.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://apis.roblox.com"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_PATH = os.path.expanduser("~/RobloxProjects/.roblox-api-key")
TARGET_PATH = os.path.join(ROOT, "deploy", "target.json")
STORE_NAME = "PlayerData_v1"
STORE_MODULE = "ServerScriptService/Server/Services/DataService"
POLL = 3
TASK_DEADLINE = 360
OC_WAIT = 90

# Field list the report prints, in save-schema order. "flags.x" is one entry of data.flags.
REPORT_FIELDS = [
    ("cash", "Cash"),
    ("rep", "Rep"),
    ("rank", "Rank (derived)"),
    ("badgeCounters", "Badge counters"),
    ("flags.streak", "Streak"),
    ("flags.pets", "Pets"),
    ("cosmetics", "Cosmetics"),
    ("vehicleUpgrades", "Upgrades"),
    ("flags.monthlyLivery", "Other flags"),
    ("vehicles", "Vehicles"),
    ("totalRescues", "Total rescues"),
    ("coldOpenDone", "Cold open done"),
    ("badgesAwarded", "Badges awarded"),
    ("version", "Data version"),
]


class ApiError(Exception):
    def __init__(self, msg, status=None, body=""):
        super().__init__(msg)
        self.status, self.body = status, body


def api_key():
    try:
        with open(KEY_PATH) as f:
            return f.read().strip()
    except FileNotFoundError:
        sys.exit(f"missing API key file {KEY_PATH}")


def http(method, path, *, json_body=None, retries=5):
    url = path if path.startswith("http") else API + path
    headers = {"x-api-key": api_key()}
    body = None
    if json_body is not None:
        body = json.dumps(json_body).encode()
        headers["Content-Type"] = "application/json"
    for attempt in range(retries):
        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                raw = resp.read()
                return resp.status, (json.loads(raw) if raw else None)
        except urllib.error.HTTPError as e:
            text = e.read().decode(errors="replace")
            if (e.code == 429 or e.code >= 500) and attempt < retries - 1:
                wait = float(e.headers.get("Retry-After") or 2 ** attempt * 3)
                time.sleep(min(wait, 60))
                continue
            raise ApiError(f"{method} {path} -> {e.code}: {text[:500]}", e.code, text)
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            if attempt < retries - 1:
                time.sleep(2 ** attempt * 2)
                continue
            raise ApiError(f"{method} {path} -> network error {e}")


def run_task(universe, place, script, version=None):
    """Create a Luau execution task, poll it, and return its first return value."""
    path = f"/cloud/v2/universes/{universe}/places/{place}"
    if version:
        path += f"/versions/{version}"
    path += "/luau-execution-session-tasks"
    _, task = http("POST", path, json_body={"script": script})
    task_path = task.get("path")
    if not task_path:
        raise ApiError(f"no task path in response: {task}")
    get_path = f"/cloud/v2/{task_path}"
    deadline = time.time() + TASK_DEADLINE
    state = task.get("state")
    logs = None
    while state not in ("COMPLETE", "FAILED", "CANCELLED"):
        if time.time() > deadline:
            raise ApiError(f"task {task_path} still {state} after {TASK_DEADLINE}s")
        time.sleep(POLL)
        _, task = http("GET", get_path)
        state = task.get("state")
    if state != "COMPLETE":
        try:
            _, log_body = http("GET", f"{get_path}/logs")
            logs = log_body.get("luauExecutionSessionTaskLogs", [])
            logs = "\n".join("".join(chunk.get("messages") or []) for chunk in logs)
        except ApiError:
            pass
        err = task.get("error") or {}
        raise ApiError(f"task {state}: {err.get('message') or err}\nlogs:\n{logs or '(none)'}")
    results = (task.get("output") or {}).get("results") or []
    if not results:
        return None
    first = results[0]
    if isinstance(first, dict) and set(first) == {"value"}:
        first = first["value"]
    return first


def luau(value, indent=0):
    pad = "  " * indent
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "nil"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        if not value:
            return "{}"
        inner = ", ".join(luau(v, indent + 1) for v in value)
        return "{ " + inner + " }"
    if isinstance(value, dict):
        if not value:
            return "{}"
        rows = []
        for k in sorted(value):
            rows.append(f"[{json.dumps(k)}] = {luau(value[k], indent + 1)}")
        joiner = ",\n" + pad + "  "
        return "{\n" + pad + "  " + joiner.join(rows) + ",\n" + pad + "}"
    raise TypeError(f"cannot serialize {type(value)}")


def compare(expected, actual, path, out, limit=25):
    if len(out) >= limit:
        return
    if type(expected) is not type(actual) and not (
        isinstance(expected, (int, float)) and isinstance(actual, (int, float))
    ):
        out.append({"field": path, "expected": repr(expected), "actual": repr(actual)})
        return
    if isinstance(expected, dict):
        for k in expected:
            compare(expected[k], (actual or {}).get(k), f"{path}.{k}", out, limit)
        for k in actual or {}:
            if k not in expected and k != "lastSeen":  # the save timestamp (offline pay), set on every save
                out.append({"field": f"{path}.{k}", "expected": "<absent>", "actual": repr(actual[k])})
        return
    if expected != actual:
        out.append({"field": path, "expected": repr(expected), "actual": repr(actual)})


COMMON = r"""
local function fail(message, extra)
    local out = { ok = false, error = tostring(message) }
    if extra then
        for k, v in extra do
            out[k] = v
        end
    end
    return out
end

local Server = game:GetService("ServerScriptService"):FindFirstChild("Server")
local Services = Server and Server:FindFirstChild("Services")
local dsModule = Services and Services:FindFirstChild("DataService")
local Shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
local rulesModule = Shared and Shared:FindFirstChild("ProgressionRules")
if not dsModule or not rulesModule then
    return fail("published place is missing DataService or ProgressionRules")
end
local Rules = require(rulesModule)
local DS = require(dsModule)

local storeOk, store = pcall(function()
    return game:GetService("DataStoreService"):GetDataStore("__STORE__")
end)
if not storeOk then
    return fail("DataStore unavailable: " .. tostring(store))
end

local warnings = {}
local jobId = "__JOB_ID__"
DS._test.setDeps({
    jobId = function()
        return jobId
    end,
    now = os.time,
    clock = os.clock,
    wait = function(seconds)
        task.wait(seconds)
    end,
    spawn = function(fn, ...)
        task.spawn(fn, ...)
    end,
    random = math.random,
    budget = function()
        return math.huge
    end,
    warn = function(...)
        table.insert(warnings, table.concat({ ... }, " "))
    end,
})
DS._test.setStore(store)

local fake = {
    UserId = __PLAYER_ID__,
    Name = "PersistCheck",
    Parent = true,
    attrs = {},
}
function fake:GetAttribute(name)
    return self.attrs[name]
end
function fake:SetAttribute(name, value)
    self.attrs[name] = value
end
function fake:Kick(message)
    self.kicked = tostring(message)
end

local function compare(expected, actual, path, out, limit)
    limit = limit or 25
    if #out >= limit then
        return
    end
    if type(expected) ~= type(actual) then
        table.insert(out, {
            field = path,
            expected = tostring(expected),
            actual = tostring(actual),
        })
        return
    end
    if type(expected) ~= "table" then
        if expected ~= actual then
            table.insert(out, {
                field = path,
                expected = tostring(expected),
                actual = tostring(actual),
            })
        end
        return
    end
    for k, v in expected do
        compare(v, actual[k], `{path}.{tostring(k)}`, out, limit)
    end
    for k, v in actual do
        if expected[k] == nil and k ~= "lastSeen" then -- lastSeen: the save timestamp (offline pay), set on every save
            table.insert(out, {
                field = `{path}.{tostring(k)}`,
                expected = "<absent>",
                actual = tostring(v),
            })
        end
    end
end

local key = `Player_{fake.UserId}`
"""

WRITE_TEMPLATE = COMMON.replace("__STORE__", STORE_NAME) + r"""
DS._test.playerAdded(fake)
local loaded = DS.Get(fake) ~= nil
if not loaded then
    return fail("DataService did not load the fake profile", { warnings = warnings })
end
if fake:GetAttribute("DataTemporary") == true then
    return fail("DataService used a temporary profile (the store load failed)", { warnings = warnings })
end

-- Distinctive values in every persisted field. Ids are real config ids, so Rules.migrate keeps them.
local write = Rules.defaultData()
write.cash = 987654
write.rep = 54321
write.totalRescues = 321
write.coldOpenDone = true
write.vehicles = { JetSki = true, RIB = true }
write.vehicleUpgrades = { JetSki = 1, RIB = 5 }
write.badgeCounters = { Downwind = 7, FirstRescue = 1 }
write.badgesAwarded = { FirstRescue = true }
write.flags = {
    streak = { d = 20321, s = 5, c = 20314 },
    pets = { n = 3, a = 1, t = 12, p1 = "SealPup|0|1700000000|2|1" },
    monthlyLivery = "2026-10",
}
local cosmeticsModule = Shared:FindFirstChild("Cosmetics")
if not cosmeticsModule then
    return fail("published place is missing Cosmetics", { warnings = warnings })
end
local Cosmetics = require(cosmeticsModule)
local slot = Cosmetics.slots()[1]
local option = slot and Cosmetics.default(slot)
if not slot or not option then
    return fail("no default cosmetic to save", { warnings = warnings })
end
write.cosmetics[slot] = option

local data = DS.Get(fake)
for k, v in write do
    data[k] = DS.Logic.deepCopy(v)
end
for k in data do
    if write[k] == nil then
        data[k] = nil
    end
end

DS.MarkDirty(fake)
local saved = DS.Save(fake, true) -- release the session lock in the same write

local rawOk, raw = pcall(function()
    return store:GetAsync(key)
end)
local mismatches = {}
if not rawOk then
    table.insert(mismatches, { field = "store", expected = "readable", actual = tostring(raw) })
elseif type(raw) ~= "table" then
    table.insert(mismatches, { field = "store", expected = "record", actual = tostring(raw) })
else
    compare(write, raw.data, "data", mismatches)
    if raw.version ~= DS.Logic.RECORD_VERSION then
        table.insert(mismatches, {
            field = "record.version",
            expected = tostring(DS.Logic.RECORD_VERSION),
            actual = tostring(raw.version),
        })
    end
    if raw.session ~= nil then
        table.insert(mismatches, { field = "record.session", expected = "released", actual = "held" })
    end
end

return {
    ok = saved and #mismatches == 0 and fake.kicked == nil,
    phase = "write",
    jobId = jobId,
    key = key,
    saved = saved,
    kicked = fake.kicked,
    storedVersion = if type(raw) == "table" then raw.version else nil,
    sessionReleased = type(raw) == "table" and raw.session == nil,
    write = write,
    mismatches = mismatches,
    warnings = warnings,
}
"""

READ_TEMPLATE = COMMON.replace("__STORE__", STORE_NAME) + r"""
local expected = __EXPECTED__

DS._test.playerAdded(fake)
local data = DS.Get(fake)
if not data then
    return fail("DataService did not load the fake profile", { warnings = warnings })
end
if fake:GetAttribute("DataTemporary") == true then
    return fail("DataService used a temporary profile (the store read failed)", { warnings = warnings })
end

local mismatches = {}
local fields = {}
local function check(name, expectedValue, actualValue, label)
    local out = {}
    compare(expectedValue, actualValue, label or name, out)
    fields[name] = { ok = #out == 0, failures = #out }
    for _, item in out do
        table.insert(mismatches, item)
    end
end

for _, name in
    {
        "version",
        "cash",
        "rep",
        "totalRescues",
        "coldOpenDone",
        "vehicles",
        "vehicleUpgrades",
        "cosmetics",
        "badgeCounters",
        "badgesAwarded",
    }
do
    check(name, expected[name], data[name])
end
for flagName, flagValue in expected.flags do
    check(`flags.{flagName}`, flagValue, data.flags and data.flags[flagName], `flags.{flagName}`)
end
for flagName in data.flags or {} do
    if expected.flags[flagName] == nil then
        fields[`flags.{flagName}`] = { ok = false, failures = 1 }
        table.insert(mismatches, {
            field = `flags.{flagName}`,
            expected = "<absent>",
            actual = "present",
        })
    end
end


local rawOk, raw = pcall(function()
    return store:GetAsync(key)
end)
local storedOk = rawOk and type(raw) == "table"
if storedOk then
    local out = {}
    compare(expected, raw.data, "stored", out)
    fields.stored = { ok = #out == 0, failures = #out }
    for _, item in out do
        table.insert(mismatches, item)
    end
else
    fields.stored = { ok = false, failures = 1 }
    table.insert(mismatches, {
        field = "stored",
        expected = "readable record",
        actual = if rawOk then tostring(raw) else tostring(raw),
    })
end

local released = DS.Save(fake, true) -- release the lock this session claimed
return {
    ok = #mismatches == 0 and released,
    phase = "read",
    jobId = jobId,
    key = key,
    fields = fields,
    mismatches = mismatches,
    storedVersion = if storedOk then raw.version else nil,
    sessionReleased = released,
    warnings = warnings,
}
"""

CLEAN_TEMPLATE = r"""
local ok, err = pcall(function()
    return game:GetService("DataStoreService")
        :GetDataStore("__STORE__")
        :RemoveAsync("__KEY__")
end)
return { ok = ok, error = if ok then nil else tostring(err) }
"""


def entry_path(universe, key):
    return f"/cloud/v2/universes/{universe}/data-stores/{STORE_NAME}/entries/{urllib.parse.quote(key, safe='')}"


def read_entry(universe, key):
    try:
        _, body = http("GET", entry_path(universe, key))
    except ApiError as e:
        if e.status == 404:
            return None
        raise
    value = body.get("value")
    if isinstance(value, str):
        try:
            body["value"] = json.loads(value)
        except json.JSONDecodeError:
            pass
    return body


def wait_entry(universe, key, expected_data, timeout=OC_WAIT):
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        last = read_entry(universe, key)
        if last and isinstance(last.get("value"), dict) and last["value"].get("data") is not None:
            if last["value"]["data"] == expected_data:
                return last, []
        time.sleep(3)
    mism = []
    if last is None:
        mism.append({"field": "entry", "expected": "present", "actual": "404"})
    else:
        compare(expected_data, (last.get("value") or {}).get("data") or {}, "value.data", mism)
    return last, mism


def cleanup(universe, place, key, version, report):
    print("4/4 delete the test key ...")
    clean_script = CLEAN_TEMPLATE.replace("__STORE__", STORE_NAME).replace("__KEY__", key)
    try:
        cleaned = run_task(universe, place, clean_script, version)
    except ApiError as e:
        cleaned = {"ok": False, "error": str(e)}
    try:
        http("DELETE", entry_path(universe, key))
    except ApiError as e:
        if e.status != 404:
            cleaned = {"ok": False, "error": str(e)}
    gone = False
    deadline = time.time() + OC_WAIT
    while time.time() < deadline:
        left = read_entry(universe, key)
        if left is None or left.get("state") == "DELETED":
            gone = True
            break
        time.sleep(3)
    report["phases"]["cleanup"] = {"removeAsync": cleaned, "gone": gone}
    print(f"   {'PASS' if gone else 'FAIL'} test key removed")
    return gone


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--player-id", type=int, default=-77)
    parser.add_argument("--universe", type=int)
    parser.add_argument("--place", type=int)
    parser.add_argument("--version", type=int)
    parser.add_argument("--keep", action="store_true", help="do not delete the test key")
    parser.add_argument("--json", help="write the full result JSON here")
    args = parser.parse_args()

    universe, place = args.universe, args.place
    if not universe or not place:
        target = json.load(open(TARGET_PATH))
        universe = universe or int(target["universeId"])
        place = place or int(target["placeId"])
    key = f"Player_{args.player_id}"
    job_prefix = f"persist-{int(time.time())}"
    report = {"universeId": universe, "placeId": place, "key": key, "phases": {}}

    print(f"Persistence round-trip: universe {universe} place {place} key {key}")
    written = loaded = expected = None
    oc_ok = False
    gone = args.keep
    try:
        write_script = (
            WRITE_TEMPLATE.replace("__PLAYER_ID__", str(args.player_id))
            .replace("__JOB_ID__", job_prefix + "-w")
        )
        print("1/4 write + release in a Luau execution session ...")
        written = run_task(universe, place, write_script, args.version)
        report["phases"]["write"] = written
        if not written or not written.get("ok"):
            print("   FAIL:", (written or {}).get("error") or written)
            for m in (written or {}).get("mismatches", []):
                print("   ", m)
            return 1
        expected = written["write"]
        print(
            f"   ok: saved, stored version {written.get('storedVersion')}, "
            f"session released {written.get('sessionReleased')}"
        )

        read_script = (
            READ_TEMPLATE.replace("__PLAYER_ID__", str(args.player_id))
            .replace("__JOB_ID__", job_prefix + "-r")
            .replace("__EXPECTED__", luau(expected))
        )
        print("2/4 cold load in a second execution session ...")
        loaded = run_task(universe, place, read_script, args.version)
        report["phases"]["read"] = loaded
        if not loaded or loaded.get("error"):
            print("   FAIL:", (loaded or {}).get("error") or loaded)
            return 1
        fields = loaded.get("fields") or {}
        rank = loaded.get("rank") or {}
        for field, label in REPORT_FIELDS:
            state = fields.get(field)
            mark = "PASS" if state and state.get("ok") else "FAIL"
            print(f"   {mark:4} {label} ({field})")
        print(
            f"   rank: {rank.get('name')} (index {rank.get('index')}), "
            f"stored version {loaded.get('storedVersion')}, lock released {loaded.get('sessionReleased')}"
        )
        for m in loaded.get("mismatches", [])[:20]:
            print("   mismatch:", m)

        print("3/4 Open Cloud DataStore read ...")
        entry, oc_mism = wait_entry(universe, key, expected)
        oc_ok = entry is not None and not oc_mism
        report["phases"]["opencloud"] = {
            "ok": oc_ok,
            "state": (entry or {}).get("state"),
            "revisionId": (entry or {}).get("revisionId"),
            "mismatches": oc_mism,
        }
        print(
            f"   {'PASS' if oc_ok else 'FAIL'} stored entry "
            f"({'missing' if entry is None else entry.get('state')})"
        )
        for m in oc_mism[:10]:
            print("   mismatch:", m)
    finally:
        if args.keep:
            print("4/4 cleanup skipped (--keep)")
        else:
            gone = cleanup(universe, place, key, args.version, report)

    ok = bool(written and written.get("ok")) and bool(loaded and loaded.get("ok")) and oc_ok and gone
    summary(report, args.json, ok=ok)
    return 0 if ok else 1


def summary(report, json_path, ok):
    print("RESULT:", "PASS" if ok else "FAIL")
    if json_path:
        with open(json_path, "w") as f:
            json.dump(report, f, indent=2, sort_keys=True)
        print("full JSON:", json_path)


if __name__ == "__main__":
    sys.exit(main())
