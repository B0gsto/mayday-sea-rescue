#!/usr/bin/env python3
"""Mayday: Sea Rescue play-test driver (adapted from ~/RobloxProjects/Gulp/tools/studio/smoke.py).

usage: python3 tools/studio/smoke.py <command> [args]

  open                 build (tools/build.sh) and open build/MaydaySeaRescue.rbxl as TestBench-mayday (an old
                       window of that tag is closed first); the studio_id is kept in build/smoke/.sid
  play start|stop      start/stop the play test (waits for the mode), Studio brought to the front
  lua <Server|Client|Edit> <file.luau | -> [--quiet]  run Luau, print its output
  keys <key> <ms>      hold a key on the client (e.g. keys W 2000)
  console              save the console to build/smoke/console.txt; print error lines and the last 25 lines
  shot <name>          screen_capture to build/smoke/<name>.png, downscaled to 768 px
  close                close TestBench-mayday without saving, give focus back to the previous app
  run                  open, play, console check, one shot, stop, close (verdict on the first line)

Every command holds the machine-wide `studio` lock only for its own duration (keep holds short).
Never touches any other TestBench or place window."""
import base64, os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.expanduser("~/RobloxProjects/tools")
sys.path.insert(0, TOOLS)
import studio_window as sw  # noqa: E402
from studio import StudioSession, studio_lock  # noqa: E402

TAG = "mayday"
OWNER = "mayday-smoke"
OUT = os.path.join(REPO, "build", "smoke")
SID_FILE = os.path.join(OUT, ".sid")
PREV_FILE = os.path.join(OUT, ".previous_app")
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
    path = os.path.join(OUT, ".title")
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
    with open(os.path.join(OUT, ".title"), "w") as f:
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
        if cmd == "run":
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
            else:
                sys.exit(__doc__)


if __name__ == "__main__":
    main()
