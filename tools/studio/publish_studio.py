#!/usr/bin/env python3
"""Publish the Rojo build to the PRIVATE test place from Roblox Studio, so Studio creates the PBR texture packs
(SurfaceAppearance / MaterialVariant) that an Open Cloud place upload never makes.

usage: python3 tools/studio/publish_studio.py [--skip-check] [--launch] [--batch 8] [--gap 3] [--rounds 4]
  --launch  the launch experience (deploy/launch-target.json, deploy/state-launch.json, launch pass ids); ask the user first

  1. check.sh (unless --skip-check) and build.sh
  2. open the test place (deploy/target.json, never the launch universe) from Roblox in a fresh Studio process
     (roblox-studio: URL) and wait until the Studio MCP lists it
  3. tools/studio-load.py replaces its content with build/MaydaySeaRescue.rbxl plus the terrain bake staged in
     ServerStorage (build/MaydayPublish.rbxl, tools/world/make_work_place.luau): studio-load clears the voxels and
     never carries them, so tools/world/write_terrain.luau writes them (as studio_terrain.py does), the staging is
     removed, and a probe of the town platform must read solid ground
  4. wait for Studio's own texture-pack burst to end (it can hit HTTP 429 / 5xx on hundreds of packs at once); only
     when it logged failures, re-trigger packs: blank and restore ColorMap on --batch surfaces every --gap seconds,
     pausing until the 429's "will reset at <time>". The log never names the failed surface, so each failure is
     pinned to the batches nudged in the WINDOW seconds before it, and only those are retried, up to --rounds times
  5. File > Publish to Roblox through the accessibility menu (tools/studio/studio-menu.swift), read the new
     version from the Studio log, write it to deploy/state.json, quit that Studio process

Holds the machine-wide Studio lock throughout. When the last round still logs texture-pack failures it publishes
anyway if they are at most 1% of the surfaces (warning with the suspect paths: they render untextured on that
version, the next publish retries), else exits non-zero with nothing published."""
import glob, json, os, re, subprocess, sys, time
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.expanduser("~/RobloxProjects/tools")
sys.path.insert(0, TOOLS)
sys.path.insert(0, os.path.join(REPO, "tools", "world"))
from studio import StudioSession, studio_lock  # noqa: E402
import studio_terrain  # noqa: E402

LAUNCH = os.path.join(REPO, "deploy", "state-launch.json")
# --launch (only on the user's say-so): the launch experience, with its own pass / product ids in the build
IS_LAUNCH = "--launch" in sys.argv
TARGET = json.load(open(os.path.join(REPO, "deploy", "launch-target.json" if IS_LAUNCH else "target.json")))
UNIVERSE, PLACE = TARGET["universeId"], TARGET["placeId"]
STATE = LAUNCH if IS_LAUNCH else os.path.join(REPO, "deploy", "state.json")
if IS_LAUNCH:  # studio-load.py only loads into the game's owned place; name the launch one
    os.environ["STUDIO_LOAD_TARGET"] = os.path.join(REPO, "deploy", "launch-target.json")
MONETIZATION = os.path.join("src", "shared", "Config", "MonetizationConfig.luau")
AUTOSAVES = os.path.expanduser("~/Library/Application Support/Roblox/RobloxStudio/AutoSaves")
PACK = re.compile(r"TexturePack|AssetResolutionWorkflow|Could not find asset with hash")
PACK_FAIL = re.compile(r"Failed to upload TexturePack|TexturePack asset creation has failed")
RESET = re.compile(r"will reset at (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)Z")
WINDOW = 20  # s from a nudge to its failure line: Studio builds the pack, queues the upload (up to ~10 s), logs
SURFACES = '''
local list = {}
for _, d in game:GetDescendants() do
	if (d:IsA("SurfaceAppearance") or d:IsA("MaterialVariant")) and d.ColorMap ~= "" then table.insert(list, d) end
end
'''
NUDGE = SURFACES + '''
local batch, saved = {}, {}
for _, i in {%s} do table.insert(batch, list[i]) end
for i, d in batch do saved[i] = d.ColorMap; d.ColorMap = "" end
if #batch > 0 then task.wait(0.5) end -- a same-frame restore never reaches the texture-pack job
for i, d in batch do d.ColorMap = saved[i] end
return #list
'''
NAMES = SURFACES + '''
local out = {}
for _, i in {%s} do table.insert(out, list[i]:GetFullName()) end
return table.concat(out, "\\n")
'''
# the hub plateau (Y 4, docs/23 (k)) north-west of the HQ: solid voxels, else the terrain did not load
TOWN_PROBE = '''
local m = workspace.Terrain:ReadVoxels(Region3.new(Vector3.new(-104, -8, -64), Vector3.new(-96, 4, -56)), 4)
local solid = 0
for x = 1, m.Size.X do for y = 1, m.Size.Y do for z = 1, m.Size.Z do
	if m[x][y][z] ~= Enum.Material.Air then solid += 1 end
end end end
return solid
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


def utc(text, fmt):
    return datetime.strptime(text, fmt).replace(tzinfo=timezone.utc).timestamp()


def failures(lines):
    """[(log time, is 429)] for each texture-pack failure line."""
    return [(utc(l[:24], "%Y-%m-%dT%H:%M:%S.%fZ"), "StatusCode: 429" in l) for l in lines if PACK_FAIL.search(l)]


def cooldown(lines, now):
    """Seconds until uploads may resume: the latest "will reset at", else 30 s after the last bare 429."""
    resets = [utc(t, "%Y-%m-%d %H:%M:%S") + 1 for t in RESET.findall("\n".join(lines))]
    bare = [t + 30 for t, is429 in failures(lines) if is429]
    return max([now] + (resets or bare)) - now


def suspects(fails, batches):
    """Surface indices nudged in the WINDOW s before any failure (all of this round's when none fits)."""
    hit = {i for t, _ in fails for at, part in batches if t - WINDOW <= at <= t for i in part}
    return sorted(hit or (fails and {i for _, part in batches for i in part}))


def selftest():
    line = "2026-10-25T13:47:08.160Z,48.1,6df3b000,6,Error [FLog::CreatorError] Error: Failed to upload TexturePack " \
           "(Reason: ... HTTP StatusCode: 429, Message: {"
    reset = '  "message": "Rate limit exceeded for TexturePack uploads and will reset at 2026-10-25 13:47:09Z."'
    t = utc("2026-10-25T13:47:08.160Z", "%Y-%m-%dT%H:%M:%S.%fZ")
    assert failures([line, reset, "noise"]) == [(t, True)]
    assert abs(cooldown([line, reset], t) - 1.84) < 0.01 and abs(cooldown([line], t) - 30) < 0.01
    assert cooldown(["noise"], t) == 0
    assert suspects([(t, True)], [(t - 30, [1, 2]), (t - 5, [3, 4]), (t + 1, [5])]) == [3, 4]
    assert suspects([(t, True)], [(t + 1, [5, 6])]) == [5, 6] and suspects([], [(t, [1])]) == []
    print("selftest ok")


def find_place(s):
    ok, texts, _ = s.call("list_roblox_studios", {}, 30)
    for st in json.loads(texts[0]).get("studios", []) if ok and texts else []:
        if "placeId: %d)" % PLACE in (st.get("name") or ""):
            return st["id"]
    return None


def main():
    if not IS_LAUNCH and os.path.exists(LAUNCH) and json.load(open(LAUNCH)).get("placeId") == PLACE:
        sys.exit("deploy/target.json points at the launch place: refusing")
    if "--skip-check" not in sys.argv:
        run([os.path.join(TOOLS, "check.sh"), REPO])
    if IS_LAUNCH:
        # the repo keeps the test universe's ids; build with the launch ones, then put the file back
        if subprocess.run(["git", "diff", "--quiet", "--", MONETIZATION], cwd=REPO).returncode != 0:
            sys.exit(MONETIZATION + " has uncommitted changes; commit them first")
        key = os.path.expanduser(TARGET.get("apiKey", "~/RobloxProjects/.roblox-api-key"))
        os.environ["ROBLOX_API_KEY_FILE"] = key
        try:
            run([sys.executable, os.path.join(TOOLS, "deploy.py"), REPO, str(UNIVERSE), str(PLACE),
                 "--state", os.path.relpath(STATE, REPO), "--steps", "config"])
            run([os.path.join(TOOLS, "build.sh"), REPO])
        finally:
            subprocess.run(["git", "checkout", "--", MONETIZATION], cwd=REPO)
    else:
        run([os.path.join(TOOLS, "build.sh"), REPO])
    run(["lune", "run", os.path.join(REPO, "tools", "world", "make_work_place.luau"),
         os.path.join(REPO, "build", "MaydaySeaRescue.rbxl"), os.path.join(REPO, "build", "MaydayPublish.rbxl"),
         os.path.join(REPO, "map", "generated")])
    if studio_pids():
        sys.exit("a Studio already has a roblox-studio: place open; close it first (its edits would be published)")
    batch, gap, rounds = int(arg("--batch", 8)), arg("--gap", 3), int(arg("--rounds", 4))
    with studio_lock(owner="mayday publish", timeout=3600, cap=3600):
        # a killed earlier run leaves an auto-recovery file, whose startup modal disables File > Publish to Roblox
        for f in glob.glob(os.path.join(AUTOSAVES, "%d_AutoRecovery_*.rbxl" % PLACE)):
            os.makedirs(os.path.join(AUTOSAVES, "Archived"), exist_ok=True)
            os.replace(f, os.path.join(AUTOSAVES, "Archived", "%d_%s" % (time.time(), os.path.basename(f))))
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
                start = len(log_lines(log))
                print(run([sys.executable, os.path.join(TOOLS, "studio-load.py"), REPO, sid, "--build", "MaydayPublish"])
                      .strip().splitlines()[0], flush=True)

                def luau(code, timeout=600):
                    ok, texts, _ = s.call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit", "code": code},
                                          timeout)
                    if not ok:
                        sys.exit("terrain write failed, nothing published: " + " ".join(texts)[:1500])
                    return " ".join(texts)
                studio_terrain.write(lambda a: luau(studio_terrain.lua_args(a) + studio_terrain.WRITER))
                luau('game:GetService("ServerStorage").__WorldTerrain:Destroy() return "ok"')
                solid = int(luau(TOWN_PROBE).strip())
                print("town platform probe: %d solid voxels" % solid, flush=True)
                if solid < 6:
                    sys.exit("the loaded place has no terrain at the town platform: nothing published")
                settle(log)  # the burst for the freshly loaded surfaces

                def nudge(idx, code=NUDGE):
                    ok, texts, _ = s.call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit",
                                                          "code": code % ",".join(map(str, idx))}, 120)
                    if not ok:
                        sys.exit("nudge failed: " + " ".join(texts)[:300])
                    return texts[0]
                total = int(nudge([]))
                lines = log_lines(log)[start:]
                fails = failures(lines)
                todo = list(range(1, total + 1)) if fails else []  # burst failures can't be pinned to a surface
                print("%d surfaces, load burst: %d texture-pack failures" % (total, len(fails)), flush=True)
                for rnd in range(1, rounds + 1):
                    if not todo:
                        break
                    time.sleep(cooldown(lines, time.time()))
                    mark = seen = len(log_lines(log))
                    batches = []
                    for k in range(0, len(todo), batch):
                        part = todo[k:k + batch]
                        batches.append((time.time(), part))
                        nudge(part)
                        new = log_lines(log)[seen:]
                        seen += len(new)
                        time.sleep(max(gap, cooldown(new, time.time())))
                    settle(log)
                    lines = log_lines(log)[mark:]
                    fails = failures(lines)
                    todo = suspects(fails, batches)
                    print("round %d: re-triggered %d surfaces, %d failures (%d x 429), %d suspects"
                          % (rnd, sum(len(p) for _, p in batches), len(fails), sum(f[1] for f in fails), len(todo)),
                          flush=True)
                if fails:
                    names = nudge(todo, NAMES)
                    if len(fails) > total // 100:
                        sys.exit("%d texture packs still failing after %d rounds (> 1%% of %d): nothing published; "
                                 "re-run later. Suspects:\n%s" % (len(fails), rounds, total, names))
                    print("WARNING: publishing with %d failed texture packs (<= 1%%); one of these renders untextured "
                          "until the next publish:\n%s" % (len(fails), names), flush=True)
                start = len(log_lines(log))
                menu = ["swift", os.path.join(HERE, "studio-menu.swift"), str(pid), "File"]
                end = time.time() + 300  # Studio can still be busy after the pack pass: wait for the item to enable
                while True:
                    r = subprocess.run(menu + ["Publish to Roblox"], capture_output=True, text=True, timeout=120)
                    if r.returncode == 0:
                        break
                    if r.returncode != 3 or time.time() > end:
                        files = subprocess.run(menu, capture_output=True, text=True, timeout=60).stdout
                        sys.exit("File > Publish to Roblox failed: %s\nFile menu:\n%s" % (r.stdout.strip(), files))
                    time.sleep(10)
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
    state = json.load(open(STATE)) if os.path.exists(STATE) else {}
    state["placeVersion"] = version
    with open(STATE, "w") as f:
        json.dump(state, f, indent=2)
    print("published place %d version %d from Studio: https://www.roblox.com/games/%d" % (PLACE, version, PLACE))


if __name__ == "__main__":
    selftest() if "--selftest" in sys.argv else main()
