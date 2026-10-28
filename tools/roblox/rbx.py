#!/usr/bin/env python3
"""Play the published TEST place in the real Roblox app, as a player: real keys, real mouse, window screenshots.
No Studio, no Luau, no teleports. While a session runs it owns the keyboard and mouse: nobody else uses the Mac.

usage: python3 tools/roblox/rbx.py <command> [args]
  join                  open the test place (deploy/target.json placeId) in the Roblox app, wait for its window
  quit                  close the Roblox app
  look [name]           screenshot of the Roblox window -> build/rbx/<name>.png (1024 px wide); prints the path
  press KEY [KEY ...]   tap keys in order: A-Z, 0-9, Space, Return, Escape, Tab, Backspace, Shift, Ctrl, Alt,
                        Up/Down/Left/Right, Slash, F1-F12
Keys go through a virtual HID keyboard: start tools/roblox/keyd.sh (sudo) in a terminal first.
  hold KEY[+KEY] MS     hold keys together for MS ms (hold W 2000, hold Shift+W 3000, hold W+D 800)
  click X Y [right]     click at X,Y in the coordinates of the last `look` image
  holdclick X Y MS      hold the left button at X,Y for MS ms
  drag X1 Y1 X2 Y2 [right]  press, move, release (right-drag turns the camera)
  turn DX               turn the camera: right-drag DX image pixels from the centre (negative = left)
  scroll N              mouse wheel N notches (positive = zoom in, negative = out)
  type TEXT             type text into whatever has focus
  chat TEXT             Slash, type TEXT, Return"""
import json, os, struct, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
BIN = os.path.join(HERE, ".rbxin")
OUT = os.path.join(REPO, "build", "rbx")
STATE = os.path.join(OUT, ".last")  # window rect + image size from the last `look`

FIFO = "/tmp/rbxkeyd.fifo"  # tools/roblox/keyd.sh: virtual HID keyboard (Roblox ignores synthetic CGEvent keys)
KEYS = {**{chr(65 + i): 0x04 + i for i in range(26)}, **{str(i): 0x1E + i - 1 for i in range(1, 10)}, "0": 0x27,
        "Return": 0x28, "Enter": 0x28, "Escape": 0x29, "Esc": 0x29, "Backspace": 0x2A, "Tab": 0x2B, "Space": 0x2C,
        "Slash": 0x38, "Right": 0x4F, "Left": 0x50, "Down": 0x51, "Up": 0x52,
        **{"F%d" % i: 0x3A + i - 1 for i in range(1, 13)}, "Ctrl": 0xE0, "Shift": 0xE1, "Alt": 0xE2}
CHARS = {" ": 0x2C, "/": 0x38, ".": 0x37, ",": 0x36, "-": 0x2D, "!": (0x1E, True), "?": (0x38, True)}


def rb(*args, check=True):
    if not os.path.exists(BIN) or os.path.getmtime(BIN) < os.path.getmtime(BIN.replace(".rbxin", "rbxin.swift")):
        subprocess.run(["swiftc", "-O", os.path.join(HERE, "rbxin.swift"), "-o", BIN], check=True)
    r = subprocess.run([BIN, *map(str, args)], capture_output=True, text=True)
    if check and r.returncode:
        sys.exit("rbxin %s failed (%d)" % (args[0], r.returncode))
    return r.stdout.strip()


def window():
    out = rb("win", check=False)
    if not out:
        sys.exit("no Roblox window: run `join` first")
    return [int(v) for v in out.split()]  # id x y w h


def front():
    for _ in range(3):
        if subprocess.run([BIN, "act"]).returncode == 0:
            return
        time.sleep(0.5)
    sys.exit("could not bring Roblox to the front")


def kset(usages):
    if not os.path.exists(FIFO):
        sys.exit("keyboard daemon not running: start tools/roblox/keyd.sh in a terminal (sudo)")
    with open(FIFO, "w") as f:
        f.write("set %s\n" % " ".join(str(u) for u in usages))


def type_text(text):
    for ch in text:
        if ch.isalpha():
            ks = [KEYS[ch.upper()]] + ([KEYS["Shift"]] if ch.isupper() else [])
        elif ch.isdigit():
            ks = [KEYS[ch]]
        else:
            v = CHARS.get(ch)
            if v is None:
                continue
            ks = [v[0], KEYS["Shift"]] if isinstance(v, tuple) else [v]
        kset(ks); time.sleep(0.03); kset([]); time.sleep(0.03)


def key(name):
    k = KEYS.get(name if len(name) > 1 else name.upper())
    if k is None:
        sys.exit("unknown key %r; known: %s" % (name, " ".join(KEYS)))
    return k


def to_screen(x, y):
    st = json.load(open(STATE))
    _, wx, wy, ww, wh = st["win"]
    return wx + float(x) * ww / st["img"][0], wy + float(y) * wh / st["img"][1]


def look(name):
    os.makedirs(OUT, exist_ok=True)
    win = window()
    path = os.path.join(OUT, name + ".png")
    subprocess.run(["screencapture", "-x", "-o", "-l", str(win[0]), path], check=True)
    subprocess.run(["sips", "-Z", "1024", path, "--out", path], capture_output=True, check=True)
    with open(path, "rb") as f:
        w, h = struct.unpack(">II", f.read(24)[16:24])
    json.dump({"win": win, "img": [w, h]}, open(STATE, "w"))
    print("%s (%dx%d)" % (path, w, h))


def drag(x1, y1, x2, y2, b):
    rb("mv", x1, y1)
    rb("md", x1, y1, b)
    for i in range(1, 13):
        rb("dr", x1 + (x2 - x1) * i / 12, y1 + (y2 - y1) * i / 12, b)
        time.sleep(0.02)
    rb("mu", x2, y2, b)


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    cmd = a[0]
    if cmd == "join":
        place = json.load(open(os.path.join(REPO, "deploy", "target.json")))["placeId"]
        subprocess.run(["open", "roblox://experiences/start?placeId=%d" % place], check=True)
        for _ in range(90):
            time.sleep(1)
            if rb("win", check=False):
                time.sleep(15)  # loading screen
                return print("joined place %d" % place)
        sys.exit("Roblox window never appeared")
    if cmd == "quit":
        return subprocess.run(["osascript", "-e", 'quit app id "com.roblox.RobloxPlayer"'])
    if cmd == "look":
        return look(a[1] if len(a) > 1 else time.strftime("%H%M%S"))
    front()
    if cmd == "press":
        for k in a[1:]:
            kset([key(k)]); time.sleep(0.08); kset([]); time.sleep(0.15)
    elif cmd == "hold":
        kset([key(k) for k in a[1].split("+")])
        time.sleep(min(int(a[2]), 15000) / 1000)
        kset([])
    elif cmd in ("click", "holdclick"):
        x, y = to_screen(a[1], a[2])
        b = "r" if cmd == "click" and len(a) > 3 and a[3] == "right" else "l"
        rb("mv", x, y); time.sleep(0.1); rb("md", x, y, b)
        time.sleep(min(int(a[3]), 15000) / 1000 if cmd == "holdclick" else 0.08)
        rb("mu", x, y, b)
    elif cmd == "drag":
        x1, y1 = to_screen(a[1], a[2])
        x2, y2 = to_screen(a[3], a[4])
        drag(x1, y1, x2, y2, "r" if len(a) > 5 and a[5] == "right" else "l")
    elif cmd == "turn":
        st = json.load(open(STATE))
        cx, cy = to_screen(st["img"][0] / 2, st["img"][1] / 2)
        dx = float(a[1]) * st["win"][3] / st["img"][0]
        rb("mv", cx, cy); time.sleep(0.05)
        rb("turn", cx, cy, dx)
    elif cmd == "scroll":
        n = int(a[1])
        for _ in range(abs(n)):
            rb("sc", 1 if n > 0 else -1); time.sleep(0.05)
    elif cmd == "type":
        type_text(" ".join(a[1:]))
    elif cmd == "chat":
        kset([KEYS["Slash"]]); time.sleep(0.05); kset([]); time.sleep(0.4)
        type_text(" ".join(a[1:])); time.sleep(0.2)
        kset([KEYS["Return"]]); time.sleep(0.05); kset([])
    else:
        sys.exit(__doc__)
    print("ok")


if __name__ == "__main__":
    main()
