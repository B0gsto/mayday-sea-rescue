#!/usr/bin/env python3
"""Player-only play test in Studio (fast checks; tools/roblox/rbx.py is the real-client pass). Same commands as
rbx.py. The tester sees and does only what a player can: no Luau, no teleports.

usage: python3 tools/studio/play.py <command> [args]
  open                  build and open the place (own tag $MAYDAY_STUDIO_TAG, default "mayday-play")
  start | stop          start / stop the play test (fresh session each start)
  close                 close the window without saving
  look [name]           screenshot of the game view -> build/play/<name>.png; prints the path
  press KEY [KEY ...]   tap keys (Roblox KeyCode names: E, Space, One, Escape, Return, Slash, LeftShift ...)
  hold KEY[+KEY] MS     hold keys together for MS ms (hold W 2000, hold W+A 800, hold LeftShift+W 3000)
  click X Y [right]     click at X,Y in the coordinates of the last `look` image
  holdclick X Y MS      hold the left button at X,Y
  drag X1 Y1 X2 Y2 [right]  press, move, release
  turn DX               right-drag DX image pixels from the centre (third person only: Studio's input does not
                        turn a locked first-person camera)
  scroll N              mouse wheel (positive = zoom in)
  chat TEXT             Slash, type TEXT, Return
Each command takes the machine-wide `studio` lock only for its own duration."""
import json, os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
os.environ.setdefault("MAYDAY_STUDIO_TAG", "mayday-play")
sys.path.insert(0, HERE)
import smoke  # noqa: E402  (reads MAYDAY_STUDIO_TAG at import)
from studio import StudioSession, studio_lock  # noqa: E402

OUT = os.path.join(smoke.REPO, "build", "play")
STATE = os.path.join(OUT, ".last")  # viewport px per image px, from the last `look`


def img_size(path):
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", path], capture_output=True, text=True).stdout
    return int(re.search(r"pixelWidth: (\d+)", out).group(1)), int(re.search(r"pixelHeight: (\d+)", out).group(1))


def to_vp(x, y):
    sx, sy = json.load(open(STATE)) if os.path.exists(STATE) else (1.0, 1.0)
    return round(float(x) * sx), round(float(y) * sy)


def send(s, tool, actions):
    ok, texts, _ = smoke.call(s, tool, {"datamodel_type": "Client", "actions": actions}, 60)
    print("ok" if ok else "FAILED: " + " ".join(texts)[:200])


def drag(s, x1, y1, x2, y2, b):
    steps = [{"action": "moveTo", "x": x1, "y": y1}, {"action": "mouseButtonDown", "mouse_button": b}]
    for i in range(1, 13):
        steps += [{"action": "moveTo", "x": x1 + (x2 - x1) * i // 12, "y": y1 + (y2 - y1) * i // 12},
                  {"action": "wait", "wait_time_ms": 20}]
    send(s, "user_mouse_input", steps + [{"action": "mouseButtonUp", "mouse_button": b}])


def look(s, name):
    os.makedirs(OUT, exist_ok=True)
    src = smoke.cmd_shot(s, "play_" + name)
    if not src:
        sys.exit("screenshot failed")
    path = os.path.join(OUT, name + ".png")
    subprocess.run(["sips", "-s", "format", "png", src, "--out", path], capture_output=True, check=True)
    os.remove(src)
    w, h = img_size(path)
    _, text = smoke.lua(s, "Client", "local v = workspace.CurrentCamera.ViewportSize return v.X .. ',' .. v.Y")
    m = re.search(r"([\d.]+),([\d.]+)", text)
    if m:
        json.dump([float(m.group(1)) / w, float(m.group(2)) / h], open(STATE, "w"))
    print("%s (%dx%d)" % (path, w, h))


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    cmd = a[0]
    with studio_lock(owner="mayday play", timeout=1800):
        if cmd == "open":
            return smoke.cmd_open()
        if cmd == "close":
            return smoke.cmd_close()
        with StudioSession() as s:
            if cmd in ("start", "stop"):
                smoke.cmd_play(s, cmd)
            elif cmd == "look":
                look(s, a[1] if len(a) > 1 else time.strftime("%H%M%S"))
            elif cmd == "press":
                acts = []
                for k in a[1:]:
                    acts += [{"action": "keyPress", "key_code": k}, {"action": "wait", "wait_time_ms": 150}]
                send(s, "user_keyboard_input", acts)
            elif cmd == "hold":
                ks = a[1].split("+")
                send(s, "user_keyboard_input", [{"action": "keyDown", "key_code": k} for k in ks]
                     + [{"action": "wait", "wait_time_ms": min(int(a[2]), 10000)}]
                     + [{"action": "keyUp", "key_code": k} for k in ks])
            elif cmd in ("click", "holdclick"):
                x, y = to_vp(a[1], a[2])
                b = "right" if cmd == "click" and len(a) > 3 and a[3] == "right" else "left"
                hold = min(int(a[3]), 10000) if cmd == "holdclick" else 80
                send(s, "user_mouse_input", [{"action": "moveTo", "x": x, "y": y},
                                             {"action": "mouseButtonDown", "mouse_button": b},
                                             {"action": "wait", "wait_time_ms": hold},
                                             {"action": "mouseButtonUp", "mouse_button": b}])
            elif cmd == "drag":
                x1, y1 = to_vp(a[1], a[2])
                x2, y2 = to_vp(a[3], a[4])
                drag(s, x1, y1, x2, y2, "right" if len(a) > 5 and a[5] == "right" else "left")
            elif cmd == "turn":
                sx, _ = json.load(open(STATE)) if os.path.exists(STATE) else (1.0, 1.0)
                _, text = smoke.lua(s, "Client", "local v = workspace.CurrentCamera.ViewportSize return v.X .. ',' .. v.Y")
                m = re.search(r"([\d.]+),([\d.]+)", text)
                cx, cy = (int(float(m.group(1)) / 2), int(float(m.group(2)) / 2)) if m else (400, 300)
                drag(s, cx, cy, cx + int(float(a[1]) * sx), cy, "right")
            elif cmd == "scroll":
                n = int(a[1])
                send(s, "user_mouse_input", [{"action": "scrollUp" if n > 0 else "scrollDown"}] * abs(n))
            elif cmd == "chat":
                send(s, "user_keyboard_input", [{"action": "keyPress", "key_code": "Slash"},
                                                {"action": "wait", "wait_time_ms": 300},
                                                {"action": "textInput", "text_inputs": " ".join(a[1:])},
                                                {"action": "keyPress", "key_code": "Return"}])
            else:
                sys.exit(__doc__)


if __name__ == "__main__":
    main()
