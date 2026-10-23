#!/usr/bin/env python3
"""G25b systems sweep: one Studio session that exercises every operation kind, the clock events,
the seasonal Ghost Ship, a Legendary variant, the streak/stock/season/album/pet/cosmetic
systems, the friend bonus and the rank ceremony, then does a profile round-trip (save, stop, new
play session, check the flags came back).

usage: python3 tools/studio/soak.py [minutes]     (default 12; report: build/smoke/sweep.txt)

Runs on top of smoke.py: same build/open/play/lua helpers and the same OpsDev hooks, so the
operations auto-complete with the stubs (OpsAutoStub, DevTimeScale 0.05). Prints one
`SYSTEM ok|FAIL <detail>` line per system. Output is Studio's combined server+client console:
errors are the lines smoke.py counts. Holds the shared Studio lock for the whole session; run no
other Studio tool meanwhile.
"""
import os
import re
import subprocess
import sys
import time
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import smoke  # noqa: E402

REPORT = os.path.join(smoke.OUT, "sweep.txt")
OP_KINDS = (
    "PersonInWater",
    "DisabledVessel",
    "CapsizedFerry",
    "CliffCasualty",
    "RipCurrent",
    "SinkingVessel",
    "VesselFire",
    "WildlifeRescue",
    "ExerciseCoxswain",
)
OP_WAIT = 100
CONSOLE_EVERY = 8
WARN_LINE = re.compile(r"(?i)\b(warn|warning|failed|failure|error|cannot|could not|missing|unavailable)\b")
VEHICLE = """
local net = game:GetService("ReplicatedStorage"):WaitForChild("Net", 30)
local ok, spawned, res = pcall(function()
	return net:WaitForChild("RequestVehicle", 30):InvokeServer("JetSki")
end)
return tostring(ok) .. "|" .. tostring(spawned) .. "|" .. tostring(res)
"""
UNSEAT = """
local p = game:GetService("Players"):GetPlayers()[1]
local c = p and p.Character
local h = c and c:FindFirstChildOfClass("Humanoid")
if h then h.Sit = false end
return "unseated"
"""
EXERCISE_SETUP = """
local p = game:GetService("Players"):GetPlayers()[1]
p:SetAttribute("ColdOpenDone", true)
return tostring(game:GetService("ServerStorage").ProgressionDev:Invoke("certs"))
"""
PROBE = """
local ok, err = pcall(function()
	return game:GetService("DataStoreService"):GetDataStore("PlayerData_v1"):GetAsync("__sweep_probe")
end)
return tostring(ok) .. "|" .. tostring(err and tostring(err):sub(1, 90))
"""
TELEPORT = """
local p = game:GetService("Players"):GetPlayers()[1]
local c = p and p.Character
if c then c:PivotTo(CFrame.new(%s)) end
return "tp"
"""

SYSTEMS = []


def system(name, ok, detail=""):
    line = "SYSTEM %s %s %s" % ("ok" if ok else "FAIL", name, detail.strip()[:200])
    print(line, flush=True)
    SYSTEMS.append((name, bool(ok), detail.strip()[:200]))
    return ok


def skip(name, detail=""):
    line = "SYSTEM SKIP %s %s" % (name, detail.strip()[:200])
    print(line, flush=True)
    SYSTEMS.append((name, None, detail.strip()[:200]))


def open_studio():
    """smoke.cmd_open, but the Open dialog loses focus when the machine is busy: retry the open
    (after one build) instead of exiting."""
    os.makedirs(smoke.OUT, exist_ok=True)
    b = subprocess.run([os.path.join(smoke.TOOLS, "build.sh"), smoke.REPO], env=smoke.ENV,
                       capture_output=True, text=True)
    if b.returncode != 0:
        sys.exit("build failed: " + (b.stdout + b.stderr)[-600:])
    with open(smoke.PREV_FILE, "w") as f:
        f.write(smoke.sw.frontmost() or "")
    for attempt in range(3):
        subprocess.run([sys.executable, os.path.join(smoke.TOOLS, "studio-open.py"), "--close",
                        smoke.TAG, "--owner", smoke.OWNER], capture_output=True, text=True, timeout=180)
        r = subprocess.run([sys.executable, os.path.join(smoke.TOOLS, "studio-open.py"), smoke.PLACE,
                            "--tag", smoke.TAG, "--owner", smoke.OWNER],
                           capture_output=True, text=True, timeout=600, cwd=smoke.REPO)
        m = re.search(r"^studio_id: (\S+)", r.stdout, re.M)
        if r.returncode == 0 and m:
            with open(smoke.SID_FILE, "w") as f:
                f.write(m.group(1))
            t = re.search(r"^title: (.*)$", r.stdout, re.M)
            with open(os.path.join(smoke.OUT, ".title-" + smoke.TAG), "w") as f:
                f.write(t.group(1).strip() if t else "TestBench-%s" % smoke.TAG)
            print("opened, studio_id:", m.group(1))
            return
        print("open failed (%d/3): %s" % (attempt + 1, (r.stdout + r.stderr).strip()[-300:]),
              file=sys.stderr)
        time.sleep(15)
    sys.exit("studio-open failed after 3 tries")


def console_text(s):
    _, texts, _ = smoke.call(s, "get_console_output", {}, 60)
    return "\n".join(texts)


def new_part(prev, cur):
    """The console only grows; return what came after the previous read. Studio caps the log, so
    try shorter overlaps first when the old text has already scrolled out.
    shortcut: after more than ~20k chars dropped between reads, a few lines are recounted."""
    if not prev:
        return cur
    for k in (20000, 8000, 3000, 1000, 300):
        tail = prev[-k:]
        i = cur.find(tail)
        if i >= 0:
            return cur[i + len(tail):]
    return cur


def notable(chunk):
    """(message, is_error) for every error/warning line in a chunk of console output."""
    lines = chunk.splitlines()
    out = []
    for i, line in enumerate(lines):
        s = line.strip()
        if not s or s.startswith("[TRUNCATED"):
            continue
        error = (i + 1 < len(lines) and lines[i + 1].strip() == "Stack Begin") or bool(
            smoke.LOG_ERROR.search(s))
        if not error and not WARN_LINE.search(s):
            continue
        if s.startswith(("Stack Begin", "Stack End", "CorePackages.")):
            continue
        if re.match(r"^\w+\.\w+\.\w+:\d+ function ", s):
            continue
        out.append((s[:240], error))
    return out


def status(s):
    _, text = smoke.lua(s, "Server", smoke.OPS_STATUS)
    m = re.search(r"completed=(\w+)", text)
    return (m.group(1) if m else "nil"), text


def server(s, code, timeout=60):
    return smoke.lua(s, "Server", code, timeout)[1].strip()


def client(s, code, timeout=60):
    return smoke.lua(s, "Client", code, timeout)[1].strip()


def op_once(s, kind):
    done_before, _ = status(s)
    if kind == "ColdOpen":
        code = 'return tostring(game:GetService("ServerStorage").OpsDev:Invoke("coldopen"))'
    elif kind.startswith("Exercise"):
        server(s, EXERCISE_SETUP)
        code = 'return tostring(game:GetService("ServerStorage").OpsDev:Invoke("exercise", "%s"))' % kind
    else:
        code = 'return tostring(game:GetService("ServerStorage").OpsDev:Invoke("start", "%s"))' % kind
    started = server(s, code)
    end = time.monotonic() + OP_WAIT
    ok = False
    text = ""
    while time.monotonic() < end:
        time.sleep(2)
        done, text = status(s)
        if kind.startswith("Exercise"):
            if "op=nil" in text and ("lastKind=" + kind) in text:
                ok = True
                break
        elif done != done_before and "op=nil" in text:
            ok = True
            break
    return ok, started, text


def wait_for(fn, timeout, step=1.0):
    end = time.monotonic() + timeout
    last = None
    while time.monotonic() < end:
        last = fn()
        if last and str(last).strip() not in ("", "nil"):
            return last
        time.sleep(step)
    return last


def main():
    minutes = float(sys.argv[1]) if len(sys.argv) > 1 else 12.0
    counts, sev = Counter(), {}
    prev = [""]
    next_console = [0.0]
    started = time.monotonic()

    def pump(s, force=False):
        now = time.monotonic()
        if not force and now < next_console[0]:
            return
        next_console[0] = now + CONSOLE_EVERY
        cur = console_text(s)
        chunk = new_part(prev[0], cur)
        prev[0] = cur
        for msg, is_error in notable(chunk):
            counts[msg] += 1
            sev.setdefault(msg, "error" if is_error else "warn")

    with smoke.studio_lock(owner="mayday sweep", timeout=1800):
        open_studio()
        try:
            with smoke.StudioSession() as s:
                try:
                    smoke.cmd_play(s, "start")
                    time.sleep(4)
                    prev[0] = console_text(s)  # boot/build noise is not part of the sweep
                    probe = server(s, PROBE)
                    persistent = probe.startswith("true")
                    print("datastore probe:", probe, "persistent:", persistent)
                    _, text = smoke.lua(s, "Server", smoke.OPS_SETUP)
                    print("setup:", text.strip()[:200])
                    client(s, 'game:GetService("Players").LocalPlayer:SetAttribute("OpsAutoStub", true) return "stub"')
                    # cold open (the auto-started one, or a replay when this profile already finished it)
                    cold = server(s, 'return tostring(game:GetService("ServerStorage").OpsDev:Invoke("coldopen"))')
                    ok = wait_for(lambda: "op=nil" in status(s)[1], 70, 2)
                    system("ColdOpen", ok, cold)

                    for kind in OP_KINDS:
                        t0 = time.monotonic()
                        ok, started_text, last = op_once(s, kind)
                        detail = "%.0fs %s" % (time.monotonic() - t0, (last or started_text).split("lastGrade=")[-1])
                        system(kind, ok, detail)
                        pump(s)

                    server(s, 'game:GetService("Workspace"):SetAttribute("RescueVariantForce", "GoldenGull") return "ok"')
                    ok, last = False, ""
                    for _attempt in range(2):
                        # a follow-up call can be auto-accepted the moment the last op ends; wait it out
                        wait_for(lambda: "op=nil" in status(s)[1], 30, 1)
                        time.sleep(2)
                        done_before, _ = status(s)
                        server(s, 'return tostring(game:GetService("ServerStorage").OpsDev:Invoke("start", "PersonInWater"))')
                        end = time.monotonic() + OP_WAIT
                        while time.monotonic() < end:
                            done, last = status(s)
                            if done != done_before and "op=nil" in last:
                                ok = "lastKind=PersonInWater" in last
                                break
                            time.sleep(2)
                        if ok:
                            break
                    server(s, 'game:GetService("Workspace"):SetAttribute("RescueVariantForce", nil) return "ok"')
                    album = ""
                    for _ in range(8):
                        album = client(s, 'local v=game:GetService("ReplicatedStorage").Net.Album_Get:InvokeServer() return "golden="..tostring(v and v.owned and v.owned.GoldenGull)')
                        if "golden=true" in album:
                            break
                        time.sleep(1)
                    system("LegendaryVariant", ok and "golden=true" in album, "%s %s" % (album, last))

                    # ---- dev-hook systems ---------------------------------------------------
                    server(s, UNSEAT)
                    time.sleep(1.5)
                    server(s, 'local p=game:GetService("Players"):GetPlayers()[1] local c=p.Character if c then c:PivotTo(CFrame.new(-112, 8, -36)) end return "tp"')
                    server(s, 'return tostring(game:GetService("ServerStorage").StreakDev:Invoke("day", 7))')
                    streak = client(s, 'local r=game:GetService("ReplicatedStorage").Net.Streak_Open:InvokeServer() return tostring(r and r.ok).."|"..tostring(r and r.streak)')
                    system("StreakCrate", streak == "true|7", streak)

                    server(s, 'return tostring(game:GetService("ServerStorage").ProgressionDev:Invoke("award", 30000, 0))')
                    # find the next stock window that actually has a Gear item, then jump to it
                    found = server(s, """
local SR = require(game:GetService("ReplicatedStorage").Shared.StockRotation)
local cur = SR.windowIndex(os.time())
for d = 0, 40 do
	local slots = SR.roll((cur + d) * SR.Period + 1)
	for slot, entry in slots do
		if entry.item.kind == "Gear" then
			return d .. "|" .. slot
		end
	end
end
return ""
""")
                    shift, _, gear_slot = found.partition("|")
                    server(s, 'return tostring(game:GetService("ServerStorage").StockDev:Invoke("shift", %s))' % (shift or "0"))
                    # the dev buy still has the in-world counter check: stand at the Chandlery counter
                    shop = server(s, """
local p = game:GetService("Players"):GetPlayers()[1]
local target = nil
for _, d in game:GetService("Workspace"):GetDescendants() do
	if d:IsA("ProximityPrompt") and d:GetAttribute("Panel") == "ShopCounter" and d.Parent and d.Parent:IsA("BasePart") then
		target = d.Parent.Position
		break
	end
end
local c = p and p.Character
if target and c then c:PivotTo(CFrame.new(target + Vector3.new(0, 3, 8))) end
return tostring(target)
""")
                    time.sleep(1)
                    bought = server(s, 'local ok, why = game:GetService("ServerStorage").StockDev:Invoke("buy", %s) return tostring(ok).."|"..tostring(why)' % (gear_slot or "1"))
                    gear = client(s, 'local d=game:GetService("ReplicatedStorage").Net.Progression_GetData:InvokeServer() return "gear="..tostring(d and d.gear and (d.gear.EngineTune or d.gear.StrongGrip))')
                    system("StockPurchase", bought.startswith("true") and "gear=" in gear and not gear.endswith("nil"), "%s slot=%s shop=%s %s" % (bought, gear_slot, shop, gear))

                    server(s, 'game:GetService("ServerStorage").SeasonDev:Invoke("force", true) return "ok"')
                    server(s, 'return tostring(game:GetService("ServerStorage").SeasonDev:Invoke("set", 200))')
                    claimed = server(s, 'local r=game:GetService("ServerStorage").SeasonDev:Invoke("claim", 1) return tostring(r and r.ok).."|"..tostring(r and r.reward and r.reward.tier)')
                    system("SeasonClaim", claimed == "true|1", claimed)

                    granted = server(s, 'return tostring(game:GetService("ServerStorage").AlbumDev:Invoke("grant", "Swimmer"))')
                    album = client(s, 'local v=game:GetService("ReplicatedStorage").Net.Album_Get:InvokeServer() return "swimmer="..tostring(v and v.owned and v.owned.Swimmer)')
                    system("AlbumCredit", granted == "true" and "swimmer=true" in album, album)

                    server(s, 'local p=game:GetService("Players"):GetPlayers()[1] local c=p.Character if c then c:PivotTo(CFrame.new(-105, 8, -30)) end return "tp"')
                    add = server(s, 'return tostring(game:GetService("ServerStorage").SanctuaryDev:Invoke("add", "SealPup", false))')
                    ready = server(s, 'return tostring(game:GetService("ServerStorage").SanctuaryDev:Invoke("ready"))')
                    equip = server(s, 'local ok, why = game:GetService("ServerStorage").SanctuaryDev:Invoke("equip", 1) return tostring(ok).."|"..tostring(why)')
                    pets = client(s, 'local v=game:GetService("ReplicatedStorage").Net.Pet_Get:InvokeServer() return "pets="..tostring(v and #v.pets).." active="..tostring(v and v.pets[1] and v.pets[1].active)')
                    system("PetAdopt", add != "nil" and ready == "true" and equip.startswith("true") and "active=true" in pets, "%s %s %s" % (equip, add, pets))

                    server(s, 'return tostring(game:GetService("ServerStorage").CosmeticDev:Invoke("stock"))')
                    cosmetic = client(s, 'local ok, why = game:GetService("ReplicatedStorage").Net.Cosmetics_Equip:InvokeServer("Livery", "StockRed") return tostring(ok).."|"..tostring(why).."|"..tostring(game:GetService("Players").LocalPlayer:GetAttribute("Cos_Livery"))')
                    system("CosmeticEquip", cosmetic.startswith("true|ok") or cosmetic.startswith("true|"), cosmetic)

                    server(s, 'game:GetService("Workspace"):SetAttribute("FriendCountForce", 3) return "ok"')
                    time.sleep(1.5)
                    friends = client(s, 'local p=game:GetService("Players").LocalPlayer return "count="..tostring(p:GetAttribute("FriendCount")).." bonus="..tostring(p:GetAttribute("FriendBonus"))')
                    system("FriendBonus", "count=3" in friends and "bonus=0" not in friends, friends)
                    server(s, 'game:GetService("Workspace"):SetAttribute("FriendCountForce", nil) return "ok"')

                    before = client(s, 'return tostring(game:GetService("Players").LocalPlayer:GetAttribute("RankIndex"))').strip()
                    before = before if before.isdigit() else "0"
                    server(s, 'return tostring(game:GetService("ServerStorage").ProgressionDev:Invoke("award", 0, 200000))')
                    after = wait_for(lambda: client(s, """
local p = game:GetService("Players").LocalPlayer
local idx = tonumber(p:GetAttribute("RankIndex")) or 0
if idx > %s and p.PlayerGui:FindFirstChild("RankCeremony") then
	return "rank=" .. idx .. "|guis=" .. tostring(#p.PlayerGui:GetChildren())
end
return ""
""" % (before or "0")), 10, 1) or ""
                    system("RankCeremony", after != "", "rank %s -> %s" % (before, after))
                    pump(s)

                    vehicle = client(s, VEHICLE)
                    if "|true|" not in vehicle:
                        server(s, UNSEAT)
                        time.sleep(2)
                        vehicle = client(s, VEHICLE)
                    system("VehicleLaunch", "|true|" in vehicle, vehicle)
                    pump(s, force=True)

                    # ---- save + round trip --------------------------------------------------
                    time.sleep(65)  # let the 60 s autosave commit the dev-hook flags
                    pump(s, force=True)
                    smoke.cmd_play(s, "stop")
                    time.sleep(4)
                    smoke.cmd_play(s, "start")
                    time.sleep(6)
                    prev[0] = console_text(s)
                    client(s, 'game:GetService("Players").LocalPlayer:SetAttribute("OpsAutoStub", true) return "stub"')
                    loaded = wait_for(lambda: "nil" not in client(s, 'local d=game:GetService("ReplicatedStorage").Net.Progression_GetData:InvokeServer() return tostring(d ~= nil)'), 90, 3)
                    pump(s)

                    if persistent:
                        streak = client(s, 'local v=game:GetService("ReplicatedStorage").Net.Streak_Get:InvokeServer() return "streak="..tostring(v and v.streak).." available="..tostring(v and v.available)')
                        system("PersistStreak", "streak=7" in streak, streak)
                        pets = client(s, 'local v=game:GetService("ReplicatedStorage").Net.Pet_Get:InvokeServer() return "pets="..tostring(v and #v.pets).." active="..tostring(v and v.pets[1] and v.pets[1].active)')
                        system("PersistPets", "pets=0" not in pets and "active=true" in pets, pets)
                        album = client(s, 'local v=game:GetService("ReplicatedStorage").Net.Album_Get:InvokeServer() return "swimmer="..tostring(v and v.owned and v.owned.Swimmer).." golden="..tostring(v and v.owned and v.owned.GoldenGull)')
                        system("PersistAlbum", "swimmer=true" in album, album)
                        season = client(s, 'local v=game:GetService("ReplicatedStorage").Net.Season_Get:InvokeServer() return "xp="..tostring(v and v.xp).." claimed="..tostring(v and v.tiers and v.tiers[1] and v.tiers[1].claimed)')
                        system("PersistSeason", "claimed=true" in season, season)
                        gear = client(s, 'local d=game:GetService("ReplicatedStorage").Net.Progression_GetData:InvokeServer() return "gear="..tostring(d and d.gear and (d.gear.EngineTune or d.gear.StrongGrip))')
                        system("PersistStock", "gear=" in gear and not gear.endswith("nil"), gear)
                        cosmetic = client(s, 'return tostring(game:GetService("Players").LocalPlayer:GetAttribute("Cos_Livery"))')
                        system("PersistCosmetic", cosmetic.strip() == "StockRed", cosmetic)
                    else:
                        skip("PersistRoundTrip", "DataStore unavailable in Studio (place not published): stop/start restarts in memory mode, so flags reset - open issue")
                    print("profile loaded:", loaded)
                    smoke.cmd_play(s, "stop")
                finally:
                    smoke.cmd_close()
        finally:
            pass

    errors = sum(n for m, n in counts.items() if sev[m] == "error")
    warnings = sum(n for m, n in counts.items() if sev[m] == "warn")
    ok_count = sum(1 for _, ok, _ in SYSTEMS if ok is True)
    fail_count = sum(1 for _, ok, _ in SYSTEMS if ok is False)
    skip_count = sum(1 for _, ok, _ in SYSTEMS if ok is None)
    verdict = "PASS" if errors == 0 and fail_count == 0 else "FAIL"
    head = ("SWEEP: %s - %d ok, %d FAIL, %d skipped, %d errors, %d warnings, %.1f min"
            % (verdict, ok_count, fail_count, skip_count, errors, warnings, (time.monotonic() - started) / 60))
    lines = [head, "", "== systems"]
    lines += ["SYSTEM %s %-16s %s" % ("ok" if ok is True else "FAIL" if ok is False else "SKIP", name, detail)
              for name, ok, detail in SYSTEMS]
    lines += ["", "== unique console errors/warnings (top 10)"]
    lines += ["%s %4d  %s" % ("E" if sev[m] == "error" else "W", n, m) for m, n in counts.most_common(10)] or ["(none)"]
    report = "\n".join(lines)
    os.makedirs(smoke.OUT, exist_ok=True)
    with open(REPORT, "w") as f:
        f.write(report + "\n")
    print(report)
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
