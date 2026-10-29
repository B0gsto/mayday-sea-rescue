#!/usr/bin/env python3
"""Mayday: Sea Rescue play-test driver (adapted from ~/RobloxProjects/Gulp/tools/studio/smoke.py).

usage: python3 tools/studio/smoke.py <command> [args]

  open                 build (tools/build.sh) and open build/<checkout dir>.rbxl as TestBench-<tag> (an old
                       window of that tag is closed first); the studio_id is kept in build/smoke/.sid
  play start|stop      start/stop the play test (waits for the mode), Studio brought to the front
  lua <Server|Client|Edit> <file.luau | -> [--quiet]  run Luau, print its output. Never require the
                       PlayerModule / ControlModule from `lua Client`: it starts a second ControlModule
                       that takes over the W/A/S/D actions, so the real one stops driving (ThrottleFloat 0)
  keys <key> <ms>      hold a key on the client (e.g. keys W 2000)
  console              save the console to build/smoke/console.txt; print error lines and the last 25 lines
  shot <name>          screen_capture to build/smoke/<name>.png, downscaled to 768 px
  shot <name> --full [out.png]  full-size shot: grows the window to the screen, screencaptures it, keeps the
                       rendered game (drops Studio chrome and the top 8%: Roblox topbar buttons), centre-crops
                       16:9 and resizes to 1920x1080 (default out build/smoke/<name>.png); warns if smaller.
                       Close the Properties panel (Window menu) for a wider viewport on a laptop screen.
  close                close TestBench-<tag> without saving, give focus back to the previous app
  run                  open, play, console check, z-fight scan (tools/studio/zfight_scan.luau: any high-confidence
                       coplanar overlap fails), one shot, stop, close (verdict on the last line)
  ops                  open, play, then play operations end to end with the stub mechanics (PersonInWater,
                       CapsizedFerry, RipCurrent, SinkingVessel, VesselFire,
                       WildlifeRescue, the cold open): the client's
                       OpsAutoStub attribute auto-completes every stub and auto-accepts offers; checks each
                       operation reaches its debrief

Every command holds the machine-wide `studio` lock only for its own duration (keep holds short).
Never touches any other TestBench or place window. The tag is $MAYDAY_STUDIO_TAG (default "mayday-smoke").
"""
import base64, os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.expanduser("~/RobloxProjects/tools")
sys.path.insert(0, TOOLS)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import studio_window as sw  # noqa: E402
from studio import StudioSession, studio_lock  # noqa: E402
import hold_window  # noqa: E402  (tools/studio: a Studio window holds one of the 2 heavy slots)

# Each tool opens its own TestBench window so one never closes another's: smoke.py "mayday-smoke"
# (default), art/ocean/capture.sh "mayday-ocean", lookdev captures "mayday-lookdev" (set MAYDAY_STUDIO_TAG).
TAG = os.environ.get("MAYDAY_STUDIO_TAG", "mayday-smoke")
OWNER = TAG
OUT = os.path.join(REPO, "build", "smoke")
SID_FILE = os.path.join(OUT, ".sid-" + TAG)
PREV_FILE = os.path.join(OUT, ".previous_app-" + TAG)
PLACE = os.path.join(REPO, "build", os.path.basename(REPO) + ".rbxl")  # build.sh names it after the checkout dir
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


def game_area(im):
    """The rendered game inside the viewport panel: the longest run of rows, then columns, that are not mostly
    Studio's panel colour (drops the device-emulation bar, padding and the focus outline)."""
    import numpy as np
    a = np.asarray(im).astype(int)
    panel = np.abs(a - np.array([32, 34, 39])).sum(axis=2) < 3  # exact: a dark storm scene must not match

    def longest(mask):
        best, start = (0, 0), None
        for i, v in enumerate(list(mask) + [False]):
            if v and start is None:
                start = i
            elif not v and start is not None:
                if i - start > best[1] - best[0]:
                    best = (start, i)
                start = None
        return best if best[1] > best[0] else (0, len(mask))

    y0, y1 = longest(panel.mean(axis=1) < 0.9)
    x0, x1 = longest(panel[y0:y1].mean(axis=0) < 0.9)
    return im.crop((x0 + 2, y0 + 2, x1 - 2, y1 - 2))


def cmd_shot_full(name, out=None):
    """Full-size shot: Studio's screen_capture MCP tool is capped, so grab the window with screencapture instead."""
    from PIL import Image
    front()
    pid = sw.pid_of(title())
    if pid:  # as big as the screen allows (macOS clamps the size), so the viewport tops 1920x1080
        sw.osa(sw.in_process(pid, "tell window %s\nset position to {0, 25}\nset size to {4000, 3000}\nend tell"
                             % sw.q(title())))
        time.sleep(1.5)
    win = sw.find_window(title())
    if not win:
        sys.exit("no window " + title())
    path = os.path.abspath(out or os.path.join(OUT, name + ".png"))
    if not sw.capture(win["id"], path):
        sys.exit("screencapture failed (Screen Recording permission? window minimised?)")
    im = Image.open(path).convert("RGB")
    rect = sw.viewport_rect(win["name"])
    if rect:
        k = im.width / win["w"]  # pixels per point (2 on Retina)
        x, y, w, h = (round(v * k) for v in rect)
        im = im.crop((x, y, x + w, y + h))
    im = game_area(im)
    im = im.crop((0, im.height * 8 // 100, im.width, im.height))  # the Roblox topbar buttons (play mode)
    w, h = im.size
    cw, ch = min(w, h * 16 // 9), min(h, w * 9 // 16)
    im = im.crop(((w - cw) // 2, (h - ch) // 2, (w - cw) // 2 + cw, (h - ch) // 2 + ch))
    if cw < 1920:
        print("warning: viewport only %dx%d, upscaled" % (cw, ch))
    im.resize((1920, 1080), Image.LANCZOS).save(path)
    print("saved", path, "(from %dx%d)" % (cw, ch))
    return path


def cmd_zfight(s):
    """tools/studio/zfight_scan.luau on the Server: prints its report, returns the high-confidence z-fight count."""
    ok, text = lua(s, "Server", open(os.path.join(HERE, "zfight_scan.luau")).read(), 120)
    print(text[:4000])
    m = re.search(r"ZFIGHT \d+ findings \((\d+) high", text)
    return int(m.group(1)) if m else 1


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
return string.format("op=%s results=%s current=%s lastGrade=%s lastKind=%s completed=%s", tostring(s.op),
  tostring(s.results), tostring(s.current), tostring(s.lastGrade), tostring(s.lastKind), tostring(s.completed))
"""


DEBRIEF_UI = ('local pg = game:GetService("Players").LocalPlayer.PlayerGui '
              'local d = pg:FindFirstChild("DebriefTablet", true) '
              'local t = {} if d then for _, c in d:GetDescendants() do '
              'if c:IsA("TextLabel") and c.Text ~= "" then table.insert(t, c.Text) end end end '
              'return "debrief visible=" .. tostring(d and d.Visible) .. " | " .. table.concat(t, " | ")')


def cmd_ops(s):
    """Plays operations end to end with the stub mechanics; returns a list of failures."""
    fails = []
    _, text = lua(s, "Server", OPS_SETUP)
    print("setup:", text.strip()[:200])
    for kind in ("PersonInWater", "CapsizedFerry", "RipCurrent", "SinkingVessel", "VesselFire", "WildlifeRescue", "ColdOpen"):
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
            finished = m and m.group(1) != done_before
            if finished and "op=nil" in status:
                ok = True
                break
        print("%s %s: %s" % (kind, "DONE" if ok else "STUCK", status.strip()[:200]))
        if not ok:
            fails.append(kind)
        ui = ""
        end = time.time() + 50  # a new player's first debrief waits for the arrival shot and the reward burst (OpsHud caps it at 45 s)
        while time.time() < end:
            _, ui = lua(s, "Client", DEBRIEF_UI)
            if "debrief visible=true" in ui:
                time.sleep(1.5)  # the Cash counts up from +0 for ~1.25 s: read the final pay
                _, ui = lua(s, "Client", DEBRIEF_UI)
                break
            time.sleep(0.5)
        print("  client:", ui.strip()[:400].replace("\n", " / "))
        if "debrief visible=true" not in ui:
            fails.append(kind + "-debrief")
        elif re.search(r"\| \+0( |$)", ui):
            fails.append(kind + "-pay0")
    return fails


def claim_slot():
    """Queue for a heavy slot (outside the studio lock, so holders can still close) before opening our window."""
    pattern = r"RobloxStudio -protocolString.*TestBench-%s\.rbxl" % TAG
    if hold_window.alive(pattern):  # reopening: close ours first so its holder hands the slot back
        with studio_lock(owner="mayday smoke", timeout=1800):
            subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), "--close", TAG, "--owner", OWNER],
                           capture_output=True, text=True, timeout=180)
        time.sleep(12)
    os.makedirs(OUT, exist_ok=True)
    hold_window.heavy_slot(pattern, "mayday " + TAG, os.path.join(OUT, ".slot-" + TAG))


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    cmd = args[0]
    if cmd in ("open", "run", "ops"):
        claim_slot()
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
            elif cmd == "shot" and "--full" in args:
                rest = [a for a in args[2:] if a != "--full"]
                cmd_shot_full(args[1], rest[0] if rest else None)
            elif cmd == "shot":
                cmd_shot(s, args[1])
            elif cmd == "run":
                try:
                    cmd_play(s, "start")
                    time.sleep(8)
                    errs = cmd_console(s)
                    zf = cmd_zfight(s)
                    cmd_shot(s, "smoke")
                    cmd_play(s, "stop")
                    print("smoke: %s" % ("FAIL" if errs or zf else "PASS"))
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
