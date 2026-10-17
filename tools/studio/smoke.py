#!/usr/bin/env python3
"""Mayday: Sea Rescue play-test driver (adapted from ~/RobloxProjects/Gulp/tools/studio/smoke.py).

usage: python3 tools/studio/smoke.py <command> [args]

  open                 build (tools/build.sh) and open build/MaydaySeaRescue.rbxl as TestBench-<tag> (an old
                       window of that tag is closed first); the studio_id is kept in build/smoke/.sid
  play start|stop      start/stop the play test (waits for the mode), Studio brought to the front
  lua <Server|Client|Edit> <file.luau | -> [--quiet]  run Luau, print its output
  keys <key> <ms>      hold a key on the client (e.g. keys W 2000)
  console              save the console to build/smoke/console.txt; print error lines and the last 25 lines
  shot <name>          screen_capture to build/smoke/<name>.png, downscaled to 768 px
  close                close TestBench-<tag> without saving, give focus back to the previous app
  run                  open, play, console check, one shot, stop, close (verdict on the first line)
  ops                  open, play, then play operations end to end with the stub mechanics (PersonInWater,
                       DisabledVessel, the cold open): the client's OpsAutoStub attribute auto-completes
                       every stub and auto-accepts offers; checks each operation reaches its debrief

Every command holds the machine-wide `studio` lock only for its own duration (keep holds short).
Never touches any other TestBench or place window. The tag is $MAYDAY_STUDIO_TAG (default "mayday-smoke").
"""
import base64, os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.expanduser("~/RobloxProjects/tools")
sys.path.insert(0, TOOLS)
import studio_window as sw  # noqa: E402
from studio import StudioSession, studio_lock  # noqa: E402

# Each tool opens its own TestBench window so one never closes another's: smoke.py "mayday-smoke"
# (default), art/ocean/capture.sh "mayday-ocean", lookdev captures "mayday-lookdev" (set MAYDAY_STUDIO_TAG).
TAG = os.environ.get("MAYDAY_STUDIO_TAG", "mayday-smoke")
OWNER = TAG
OUT = os.path.join(REPO, "build", "smoke")
SID_FILE = os.path.join(OUT, ".sid-" + TAG)
PREV_FILE = os.path.join(OUT, ".previous_app-" + TAG)
PLACE = os.path.join(REPO, "build", "MaydaySeaRescue.rbxl")
ENV = dict(os.environ, PATH=os.path.expanduser("~/.rokit/bin") + ":" + os.environ.get("PATH", ""))
LOG_ERROR = re.compile(r"\] ERROR: |failed: ")


def error_lines(console):
    """Engine errors are followed by a "Stack Begin" line; [Main] X.Init failed warnings count too."""
    lines = console.splitlines()
    out = []
    for i, line in enumerate(lines):
        followed = i + 1 < len(lines) and lines[i + 1].strip() == "Stack Begin"
        if (followed and line.strip() not in ("Stack Begin", "Stack End")) or LOG_ERROR.search(line):
            out.append(line)
    return out


def sid():
    return open(SID_FILE).read().strip()


def title():
    path = os.path.join(OUT, ".title-" + TAG)
    return open(path).read().strip() if os.path.exists(path) else "TestBench-%s" % TAG


def front():
    """A background Studio window is throttled, and screen_capture needs it in front."""
    pid = sw.pid_of(title())
    if pid:
        subprocess.run(["osascript", "-e", 'tell application "System Events" to set frontmost of (first process whose '
                        "unix id is %d) to true" % pid], capture_output=True, timeout=15)
        time.sleep(0.5)


def call(s, tool, args=None, timeout=120):
    a = {"studio_id": sid()}
    a.update(args or {})
    return s.call(tool, a, timeout)


def mode(s):
    ok, texts, _ = call(s, "get_studio_state", {}, 30)
    m = re.search(r"Current Studio Mode:\s*(\w+)", "\n".join(texts))
    return m.group(1) if m else "?"


def wait_mode(s, want, timeout):
    end = time.time() + timeout
    while time.time() < end:
        if mode(s).lower() == want.lower():
            return True
        time.sleep(0.5)
    return False


def lua(s, dm, code, timeout=60):
    ok, texts, _ = call(s, "execute_luau", {"datamodel_type": dm, "code": code}, timeout)
    return ok, "\n".join(texts)


def cmd_open():
    os.makedirs(OUT, exist_ok=True)
    b = subprocess.run([os.path.join(TOOLS, "build.sh"), REPO], env=ENV, capture_output=True, text=True)
    if b.returncode != 0:
        sys.exit("build failed: " + (b.stdout + b.stderr)[-600:])
    with open(PREV_FILE, "w") as f:
        f.write(sw.frontmost() or "")
    subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), "--close", TAG, "--owner", OWNER],
                   capture_output=True, text=True, timeout=180)
    r = subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), PLACE, "--tag", TAG, "--owner", OWNER],
                       capture_output=True, text=True, timeout=600, cwd=REPO)
    m = re.search(r"^studio_id: (\S+)", r.stdout, re.M)
    if r.returncode != 0 or not m:
        sys.exit("studio-open failed (%d): %s %s" % (r.returncode, r.stdout[-400:], r.stderr[-400:]))
    with open(SID_FILE, "w") as f:
        f.write(m.group(1))
    t = re.search(r"^title: (.*)$", r.stdout, re.M)
    with open(os.path.join(OUT, ".title-" + TAG), "w") as f:
        f.write(t.group(1).strip() if t else "TestBench-%s" % TAG)
    print("opened, studio_id:", m.group(1))


def cmd_play(s, what):
    if what == "start":
        front()
        if mode(s).lower() != "edit":
            call(s, "start_stop_play", {"is_start": False}, 120)
            wait_mode(s, "edit", 60)
        call(s, "start_stop_play", {"is_start": True}, 120)
        ok = wait_mode(s, "play", 60)
        end = time.time() + 60
        while ok and time.time() < end:
            _, text = lua(s, "Client", 'local p = game:GetService("Players").LocalPlayer '
                                      'return "client " .. (if p and p.Character then p.Name else "none")')
            if "client " in text and "client none" not in text:
                break
            time.sleep(0.5)
        print("play:", ok)
    else:
        call(s, "start_stop_play", {"is_start": False}, 120)
        print("edit:", wait_mode(s, "edit", 60))


def cmd_console(s):
    ok, texts, _ = call(s, "get_console_output", {}, 60)
    console = "\n".join(texts)
    with open(os.path.join(OUT, "console.txt"), "w") as f:
        f.write(console)
    errs = error_lines(console)
    print("%d lines, %d errors" % (len(console.splitlines()), len(errs)))
    for e in errs[:15]:
        print("ERR", e[:300])
    print("--- tail")
    print("\n".join(l[:240] for l in console.splitlines()[-25:]))
    return errs


def cmd_shot(s, name):
    front()
    ok, texts, images = call(s, "screen_capture", {"capture_id": name}, 60)
    if not images:
        print("no image:", " ".join(texts)[:200])
        return None
    path = os.path.join(OUT, name + ".png")
    with open(path, "wb") as f:
        f.write(base64.b64decode(images[0]))
    subprocess.run(["sips", "-Z", "768", path, "--out", path], capture_output=True)
    print("saved", path)
    return path


def cmd_close():
    subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), "--close", TAG, "--owner", OWNER],
                   capture_output=True, text=True, timeout=180)
    if os.path.exists(PREV_FILE):
        prev = open(PREV_FILE).read().strip()
        if prev:
            sw.restore(prev)
    print("closed", title())


OPS_SETUP = """
local p = game:GetService("Players"):GetPlayers()[1]
p:SetAttribute("OpsAutoStub", true)
return "timescale " .. tostring(game:GetService("ServerStorage"):WaitForChild("OpsDev"):Invoke("timescale", 0.05))
"""

OPS_STATUS = """
local s = game:GetService("ServerStorage").OpsDev:Invoke("status")
return string.format("op=%s results=%s current=%s lastGrade=%s completed=%s", tostring(s.op), tostring(s.results),
  tostring(s.current), tostring(s.lastGrade), tostring(s.completed))
"""


def cmd_ops(s):
    """Plays operations end to end with the stub mechanics; returns a list of failures."""
    fails = []
    _, text = lua(s, "Server", OPS_SETUP)
    print("setup:", text.strip()[:200])
    for kind in ("PersonInWater", "DisabledVessel", "ColdOpen"):
        _, before = lua(s, "Server", OPS_STATUS)
        m = re.search(r"completed=(\w+)", before)
        done_before = m.group(1) if m else "nil"
        if kind == "ColdOpen":
            code = 'return tostring(game:GetService("ServerStorage").OpsDev:Invoke("coldopen"))'
        else:
            code = 'return tostring(game:GetService("ServerStorage").OpsDev:Invoke("start", "%s"))' % kind
        _, started = lua(s, "Server", code)
        print("%s start: %s" % (kind, started.strip()[:120]))
        end = time.time() + 150
        status = ""
        ok = False
        while time.time() < end:
            time.sleep(3)
            _, status = lua(s, "Server", OPS_STATUS)
            m = re.search(r"completed=(\w+)", status)
            if m and m.group(1) != done_before and "op=nil" in status:
                ok = True
                break
        print("%s %s: %s" % (kind, "DONE" if ok else "STUCK", status.strip()[:200]))
        if not ok:
            fails.append(kind)
        _, ui = lua(s, "Client", 'local g = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("OpsGreybox") '
                                 'local d = g and g:FindFirstChild("Debrief") '
                                 'local t = {} if d then for _, c in d:GetDescendants() do '
                                 'if c:IsA("TextLabel") then table.insert(t, c.Text) end end end '
                                 'return "debrief visible=" .. tostring(d and d.Visible) .. " | " .. table.concat(t, " | ")')
        print("  client:", ui.strip()[:400].replace("\n", " / "))
    return fails


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    cmd = args[0]
    with studio_lock(owner="mayday smoke", timeout=1800):
        if cmd == "open":
            return cmd_open()
        if cmd == "close":
            return cmd_close()
        if cmd in ("run", "ops"):
            cmd_open()
        with StudioSession() as s:
            if cmd == "play":
                cmd_play(s, args[1])
            elif cmd == "lua":
                code = sys.stdin.read() if args[2] == "-" else (open(args[2]).read() if os.path.exists(args[2])
                                                                 else args[2])
                ok, text = lua(s, args[1], code, 120)
                print(("" if ok else "LUA FAILED: ") + text[:4000])
            elif cmd == "keys":
                ok, texts, _ = call(s, "user_keyboard_input", {"datamodel_type": "Client", "actions": [
                    {"action": "keyDown", "key_code": args[1]}, {"action": "wait", "wait_time_ms": int(args[2])},
                    {"action": "keyUp", "key_code": args[1]}]}, 60)
                print("keys:", ok, " ".join(texts)[:200])
            elif cmd == "console":
                cmd_console(s)
            elif cmd == "shot":
                cmd_shot(s, args[1])
            elif cmd == "run":
                try:
                    cmd_play(s, "start")
                    time.sleep(8)
                    errs = cmd_console(s)
                    cmd_shot(s, "smoke")
                    cmd_play(s, "stop")
                    print("smoke: %s" % ("FAIL" if errs else "PASS"))
                finally:
                    cmd_close()
            elif cmd == "ops":
                try:
                    cmd_play(s, "start")
                    time.sleep(6)
                    fails = cmd_ops(s)
                    errs = cmd_console(s)
                    cmd_shot(s, "ops")
                    cmd_play(s, "stop")
                    print("ops smoke: %s" % ("FAIL " + ",".join(fails) if fails or errs else "PASS"))
                finally:
                    cmd_close()
            else:
                sys.exit(__doc__)


if __name__ == "__main__":
    main()
