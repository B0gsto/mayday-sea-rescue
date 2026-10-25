#!/usr/bin/env python3
"""cap.py <out.png> [client_trigger.luau] [--server pre.luau] [--hold KEY]
Holds the studio lock; grows the window and measures the viewport first; runs the optional Server pre-script
(e.g. place a hull) and Client trigger (blocks until the subject is on its mark), then grabs the frame at once
(no waits between the trigger returning and the screencapture) and crops/resizes it to 1920x1080."""
import os, sys, threading, time
os.environ.setdefault("MAYDAY_STUDIO_TAG", "mayday-store2")
sys.path.insert(0, "/Users/bogdan/RobloxProjects/MaydaySeaRescue/tools/studio")
import smoke
real_sleep = time.sleep
sw = smoke.sw
args = sys.argv[1:]
opt = lambda k: args[args.index(k) + 1] if k in args else None
hold, server = opt("--hold"), opt("--server")
pos = [a for i, a in enumerate(args) if not a.startswith("--") and (i == 0 or not args[i - 1].startswith("--"))]
out = os.path.abspath(pos[0])
trigger = pos[1] if len(pos) > 1 else None
def key(s, action):
    smoke.call(s, "user_keyboard_input", {"datamodel_type": "Client", "actions": [{"action": action, "key_code": hold}]}, 30)
with smoke.studio_lock(owner="mayday store2 cap", timeout=1800):
    smoke.front()
    title = smoke.title()
    pid = sw.pid_of(title)
    sw.osa(sw.in_process(pid, "tell window %s\nset position to {0, 25}\nset size to {4000, 3000}\nend tell" % sw.q(title)))
    time.sleep(1.5)
    rect = None
    for _ in range(5):
        rect = sw.viewport_rect(title)
        if rect:
            break
        time.sleep(1)
    cache = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".viewport")
    if rect:
        open(cache, "w").write(repr(tuple(rect)))
    elif os.path.exists(cache):
        rect = eval(open(cache).read())  # the AX query is flaky: reuse the last good rect (same window size)
    print("viewport", rect)
    real_osa = sw.osa
    sw.osa = lambda script, *a, **k: None if "set size" in str(script) else real_osa(script, *a, **k)
    sw.viewport_rect = lambda _t: rect
    real_front = smoke.front
    smoke.front = lambda: None
    done = threading.Event()
    def keep_front():  # a background Studio window is throttled and grabs stale frames: keep ours in front
        while not done.is_set():
            real_front()
            done.wait(1.5)
    threading.Thread(target=keep_front, daemon=True).start()
    with smoke.StudioSession() as s:
        if hold:
            key(s, "keyDown")
        if server:
            ok, text = smoke.lua(s, "Server", open(server).read(), 120)
            print("server:", ok, text[:200])
        if trigger:
            ok, text = smoke.lua(s, "Client", open(trigger).read(), 400)
            print("trigger:", ok, text[:200])
        smoke.time.sleep = lambda _s: None  # the window is already big
        try:
            smoke.cmd_shot_full("tv3", out)
        finally:
            done.set()
            smoke.time.sleep = real_sleep
            if hold:
                key(s, "keyUp")
            smoke.lua(s, "Client", "if _G.TourStop then _G.TourStop() end return 1", 30)
