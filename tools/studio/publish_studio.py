#!/usr/bin/env python3
"""Publish the Rojo build to the PRIVATE test place from Roblox Studio, so Studio creates the PBR texture packs
(SurfaceAppearance / MaterialVariant) that an Open Cloud place upload never makes.

usage: python3 tools/studio/publish_studio.py [--skip-check] [--batch 15] [--gap 15]

  1. check.sh (unless --skip-check) and build.sh
  2. open the test place (deploy/target.json, never the launch universe) from Roblox in a fresh Studio process
     (roblox-studio: URL) and wait until the Studio MCP lists it
  3. tools/studio-load.py replaces its content with build/MaydaySeaRescue.rbxl
  4. wait for Studio's own texture-pack burst to end (it hits HTTP 429 / 504 on hundreds of packs at once), then
     re-trigger every pack slowly: blank and restore ColorMap on --batch surfaces every --gap seconds
  5. File > Publish to Roblox through the accessibility menu (tools/studio/studio-menu.swift), read the new
     version from the Studio log, write it to deploy/state.json, quit that Studio process

Holds the machine-wide Studio lock throughout. Exits non-zero (nothing published) when the paced pass still logs
texture-pack failures."""
import json, os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.expanduser("~/RobloxProjects/tools")
sys.path.insert(0, TOOLS)
from studio import StudioSession, studio_lock  # noqa: E402

TARGET = json.load(open(os.path.join(REPO, "deploy", "target.json")))
UNIVERSE, PLACE = TARGET["universeId"], TARGET["placeId"]
LAUNCH = os.path.join(REPO, "deploy", "state-launch.json")
PACK = re.compile(r"TexturePack|AssetResolutionWorkflow|Could not find asset with hash")
PACK_FAIL = re.compile(r"Failed to upload TexturePack|TexturePack asset creation has failed")
NUDGE = '''
local list = {}
for _, d in game:GetDescendants() do
	if (d:IsA("SurfaceAppearance") or d:IsA("MaterialVariant")) and d.ColorMap ~= "" then table.insert(list, d) end
end
local batch, saved = {}, {}
for i = %d, math.min(%d, #list) do table.insert(batch, list[i]) end
for i, d in batch do saved[i] = d.ColorMap; d.ColorMap = "" end
task.wait(0.5) -- a same-frame restore never reaches the texture-pack job
for i, d in batch do d.ColorMap = saved[i] end
return #list
'''


def arg(name, default):
    return float(sys.argv[sys.argv.index(name) + 1]) if name in sys.argv else default


def run(cmd, timeout=900):
    # env read per call: studio_lock adds ROBLOX_LOCKS_HELD, which makes studio-load re-entrant
    env = dict(os.environ, PATH=os.path.expanduser("~/.rokit/bin") + ":" + os.environ.get("PATH", ""))
    r = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=timeout, cwd=REPO)
    if r.returncode != 0:
        sys.exit("%s failed: %s" % (os.path.basename(cmd[1] if cmd[0] == sys.executable else cmd[0]),
                                    (r.stdout + r.stderr)[-1500:]))
    return r.stdout


def studio_pids():
    r = subprocess.run(["pgrep", "-f", "RobloxStudio -protocolString roblox-studio:1"], capture_output=True, text=True)
    return {int(p) for p in r.stdout.split()}


def log_of(pid):
    r = subprocess.run(["lsof", "-p", str(pid)], capture_output=True, text=True)
    m = re.search(r"(/\S+_Studio_\S+_last\.log)", r.stdout)
    return m.group(1) if m else None


def log_lines(path):
    with open(path, errors="replace") as f:
        return f.read().splitlines()


def settle(path, quiet=30, cap=600):
    """Wait until the Studio log has had no texture-pack line for `quiet` seconds."""
    end, last, seen = time.time() + cap, time.time(), -1
    while time.time() < end:
        n = sum(1 for l in log_lines(path) if PACK.search(l))
        if n != seen:
            seen, last = n, time.time()
        elif time.time() - last >= quiet:
            return
        time.sleep(3)


def find_place(s):
    ok, texts, _ = s.call("list_roblox_studios", {}, 30)
    for st in json.loads(texts[0]).get("studios", []) if ok and texts else []:
        if "placeId: %d)" % PLACE in (st.get("name") or ""):
            return st["id"]
    return None


def main():
    if os.path.exists(LAUNCH) and json.load(open(LAUNCH)).get("placeId") == PLACE:
        sys.exit("deploy/target.json points at the launch place: refusing")
    if "--skip-check" not in sys.argv:
        run([os.path.join(TOOLS, "check.sh"), REPO])
    run([os.path.join(TOOLS, "build.sh"), REPO])
    if studio_pids():
        sys.exit("a Studio already has a roblox-studio: place open; close it first (its edits would be published)")
    batch, gap = int(arg("--batch", 15)), arg("--gap", 15)
    with studio_lock(owner="mayday publish", timeout=3600, cap=3600):
        subprocess.run(["open", "-g", "roblox-studio:1+launchmode:edit+task:EditPlace+placeId:%d+universeId:%d"
                        % (PLACE, UNIVERSE)], check=True)
        pid, sid = None, None
        try:
            with StudioSession(settle=2) as s:
                end = time.time() + 300
                while time.time() < end and not sid:
                    time.sleep(5)
                    pid = pid or next(iter(studio_pids()), None)
                    sid = find_place(s)
                if not sid:
                    sys.exit("the test place never showed up in the Studio MCP")
                log = log_of(pid)
                print("studio pid %d, log %s" % (pid, log), flush=True)
                settle(log)  # Studio's on-open texture-pack pass
                print(run([sys.executable, os.path.join(TOOLS, "studio-load.py"), REPO, sid]).strip().splitlines()[0],
                      flush=True)
                settle(log)  # the burst for the freshly loaded surfaces
                time.sleep(60)  # let the upload rate limit cool down
                start = len(log_lines(log))
                i, total = 1, 1
                while i <= total:
                    ok, texts, _ = s.call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit",
                                                          "code": NUDGE % (i, i + batch - 1)}, 60)
                    if not ok:
                        sys.exit("nudge failed: " + " ".join(texts)[:300])
                    total = int(texts[0])
                    i += batch
                    time.sleep(gap)
                settle(log)
                fails = sum(1 for l in log_lines(log)[start:] if PACK_FAIL.search(l))
                print("texture packs re-triggered for %d surfaces, %d failures" % (total, fails), flush=True)
                if fails:
                    sys.exit("texture packs still failing (rate limit?): nothing published; re-run later or with "
                             "a larger --gap")
                start = len(log_lines(log))
                run(["swift", os.path.join(HERE, "studio-menu.swift"), str(pid), "File", "Publish to Roblox"], 120)
                end, version = time.time() + 600, None
                while time.time() < end and version is None:
                    time.sleep(3)
                    new = "\n".join(log_lines(log)[start:])
                    if "Go to PublishFail" in new:
                        sys.exit("Studio publish failed, see " + log)
                    m = re.search(r"Add publish notes to v(\d+)", new)
                    if m and "Published new changes" in new:
                        version = int(m.group(1))
                if version is None:
                    sys.exit("no publish confirmation in the Studio log after 10 min: " + log)
        finally:
            if pid:
                subprocess.run(["kill", "-9", str(pid)])  # published or abandoned: never leave a cloud-place window
    state_path = os.path.join(REPO, "deploy", "state.json")
    state = json.load(open(state_path)) if os.path.exists(state_path) else {}
    state["placeVersion"] = version
    with open(state_path, "w") as f:
        json.dump(state, f, indent=2)
    print("published place %d version %d from Studio: https://www.roblox.com/games/%d" % (PLACE, version, PLACE))


if __name__ == "__main__":
    main()
