#!/usr/bin/env python3
"""Spike 1 Studio session driver: one session, everything scripted. Run under the studio + heavy locks.
Opens TestBench-mayday-spike1 (smoke.py open), inserts the M_Spike1 rbxms, runs setup.luau, captures, runs the
importer / shot-setup checks, a play-mode probe, then closes the window (never saves). Writes results.json + captures/."""
import base64, io, json, os, subprocess, sys, time, traceback

os.environ["MAYDAY_STUDIO_TAG"] = "mayday-spike1"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "studio"))
import smoke  # noqa: E402
from studio import StudioSession  # noqa: E402

CAP = os.path.join(HERE, "captures")
os.makedirs(CAP, exist_ok=True)
R = {"t0": time.time(), "steps": {}}
T0 = time.time()


def log(*a):
    msg = "[%5.1fs] " % (time.time() - T0) + " ".join(str(x) for x in a)
    print(msg[:600], flush=True)
    with open(os.path.join(HERE, "log.txt"), "a") as f:
        f.write(msg + "\n")


def save():
    json.dump(R, open(os.path.join(HERE, "results.json"), "w"), indent=1)


def main():
    open(os.path.join(HERE, "log.txt"), "w").close()
    smoke.cmd_open()
    sid = smoke.sid()
    log("opened", sid)
    try:
        for n in ["ScaleCube", "RefBox", "TexPlane", "Tris09990", "Tris19990", "Tris20500", "Tris21500", "Tris30000",
                  "Tentacle20", "Tentacle40"]:
            r = subprocess.run([sys.executable, os.path.expanduser("~/RobloxProjects/tools/studio-insert.py"),
                                os.path.join(REPO, "assets/models/M_Spike1_%s.rbxm" % n), sid, "Workspace",
                                "--game", "MaydaySeaRescue"], capture_output=True, text=True, timeout=180)
            log("insert", n, r.returncode, (r.stdout + r.stderr).strip()[-200:])
        with StudioSession() as s:
            run(s, sid)
    except Exception:
        R["fatal"] = traceback.format_exc()
        log("FATAL", R["fatal"][-1500:])
    finally:
        save()
        try:
            with StudioSession() as s:
                if smoke.mode(s).lower() != "edit":
                    smoke.cmd_play(s, "stop")
                lua(s, "Edit", 'pcall(function() settings().Rendering.EditQualityLevel = Enum.QualityLevel.Automatic end) '
                    'workspace.CurrentCamera.FieldOfView = 70 return "restored"')
        except Exception as e:  # noqa: BLE001
            log("restore failed", e)
        smoke.cmd_close()
        log("closed; total", round(time.time() - T0, 1), "s")
        save()


def lua(s, dm, code, timeout=120):
    ok, text = smoke.lua(s, dm, code, timeout)
    return ok, text


def capture(s, sid, name, cam, look, fov):
    lua(s, "Edit", "workspace.CurrentCamera.FieldOfView = %s return 'ok'" % fov)
    time.sleep(0.4)
    ok, texts, images = s.call("screen_capture", {"studio_id": sid, "capture_id": name, "camera_position": cam,
                                                  "look_at_position": look}, 60)
    if not images:
        log("capture failed", name, " ".join(texts)[:200])
        return None
    path = os.path.join(CAP, name + ".png")
    with open(path, "wb") as f:
        f.write(base64.b64decode(images[0]))
    return path


def run(s, sid):
    ok, text = lua(s, "Edit", open(os.path.join(HERE, "setup.luau")).read(), 240)
    log("setup ok=%s" % ok, text[:300])
    try:
        R["setup"] = json.loads(text[text.index("{"):text.rindex("}") + 1])
    except ValueError:
        R["setup_raw"] = text
        raise
    save()
    st = R["setup"]

    # importer on the 4th plane (dry = 1024 maps, wet = 4096 maps)
    cfg = ('_G.ImportAssetConfig = {name = "M_Spike1_TexPlaneImported", source = "Workspace/Spike1/PlaneImport", '
           'tier = "hero", parent = "Spike1", cframe = {60, 320, 0, 0}, sets = {Plane = {ALB = "133497070455294", '
           'NOR = "71516326342804", RGH = "106584681481305", MET = "108926989495989", Wet = {ALB = "77900366731410", '
           'NOR = "79130005892903", RGH = "128068413526739", MET = "134209066827654"}}}}\n')
    ok, text = lua(s, "Edit", cfg + open(os.path.join(REPO, "tools/studio/import_asset.luau")).read(), 120)
    R["importer"] = {"ok": ok, "out": text[:3000]}
    log("importer ok=%s" % ok, text[:400])
    WETQ = ('local m = workspace.Spike1:FindFirstChild("M_Spike1_TexPlaneImported") '
            'if not m then return "no imported model" end local mp = m:FindFirstChildWhichIsA("MeshPart", true) '
            'local sa = mp:FindFirstChildOfClass("SurfaceAppearance") local cfg = mp:FindFirstChild("SurfaceVariants") '
            'local kids = {} if cfg then for _, c in cfg:GetChildren() do table.insert(kids, c.Name) end end '
            'return string.format("SA=%s ColorMap=%s variants=[%s] tagged=%s", sa and sa.Name or "nil", '
            'sa and sa.ColorMap or "", table.concat(kids, ","), '
            'tostring(game:GetService("CollectionService"):HasTag(mp, "HasWetVariant")))')
    R["importer"]["state"] = lua(s, "Edit", WETQ)[1]

    # shot-setup in Edit
    ok, text = lua(s, "Edit", open(os.path.join(REPO, "art/lookdev/shot-setup.luau")).read(), 120)
    R["shotsetup_edit"] = {"load": [ok, text[:600]]}
    for preset, wet in (("Overcast", "false"), ("Storm", "true"), ("Night", "false"), ("Overcast", "true")):
        ok, text = lua(s, "Edit", "return _G.LookDev.apply('%s', %s)" % (preset, wet))
        ok2, st2 = lua(s, "Edit", WETQ)
        R["shotsetup_edit"]["%s_%s" % (preset, wet)] = [ok, text[:300], st2[:300]]
    ok, text = lua(s, "Edit", "local r = _G.LookDev.apply('Clear', false) return r .. ' | devGui=' .. "
                   "tostring(game:GetService('StarterGui').ShowDevelopmentGui)")
    R["shotsetup_edit"]["Clear_false"] = [ok, text[:300], lua(s, "Edit", WETQ)[1][:300]]
    log("shot-setup edit", json.dumps(R["shotsetup_edit"])[:600])
    save()

    # captures (Edit)
    smoke.front()
    shots = st.get("shots", [])
    if shots:
        capture(s, sid, "warmup", shots[0]["cam"], shots[0]["look"], shots[0]["fov"])
        time.sleep(1.5)
    R["captures"] = {}
    for sh in shots:
        p = capture(s, sid, sh["name"], sh["cam"], sh["look"], sh["fov"])
        R["captures"][sh["name"]] = {"path": p, **sh}
    log("tex captures", len(R["captures"]))

    # tentacle deformation
    R["tentacle"] = {}
    BEND = ('local m = workspace.Spike1:FindFirstChild("%s") local mp = m:FindFirstChildWhichIsA("MeshPart", true) '
            'local b = mp:FindFirstChild("%s", true) if not b then return "no bone" end '
            '_G.__rest = _G.__rest or {} _G.__rest[b] = _G.__rest[b] or b.CFrame '
            'b.CFrame = _G.__rest[b] * CFrame.Angles(0, 0, math.rad(%d)) return "bent " .. b:GetFullName()')
    for name, bones in (("M_Spike1_Tentacle20", ["Bone_10"]), ("M_Spike1_Tentacle40", ["Bone_10", "Bone_30"])):
        t = st.get("tentacles", {}).get(name)
        if not t:
            continue
        c = t["center"]
        cam, look = [c[0], c[1], c[2] + 45], c
        short = name[-10:]
        R["tentacle"][short + "_rest"] = capture(s, sid, short + "_rest", cam, look, 35)
        for b in bones:
            ok, text = lua(s, "Edit", BEND % (name, b, 70))
            time.sleep(0.5)
            R["tentacle"][short + "_" + b] = [text[:200], capture(s, sid, "%s_%s" % (short, b), cam, look, 35)]
            lua(s, "Edit", BEND % (name, b, 0))
    log("tentacle", json.dumps(R["tentacle"])[:500])
    save()

    # play-mode probe
    src = open(os.path.join(HERE, "probe_server.luau")).read()
    ok, text = lua(s, "Edit", 'local sc = Instance.new("Script") sc.Name = "Spike1Probe" sc.Source = %s '
                   'sc.Parent = game:GetService("ServerScriptService") workspace.CurrentCamera.FieldOfView = 70 '
                   'return "probe installed"' % json.dumps(src))
    log("probe", ok, text[:200])
    smoke.cmd_play(s, "start")
    end = time.time() + 40
    attrs = ""
    while time.time() < end:
        ok, attrs = lua(s, "Server", 'local f = workspace:FindFirstChild("Spike1") if not f then return "no folder" end '
                        'return game:GetService("HttpService"):JSONEncode(f:GetAttributes())')
        if "rt_done" in attrs:
            break
        time.sleep(1)
    R["play_server"] = attrs[:2000]
    log("play server", attrs[:600])
    time.sleep(2)
    ok, text = lua(s, "Client", 'local f = workspace:FindFirstChild("Spike1") if not f then return "no Spike1 on client" end '
                   'local m = f:FindFirstChild("Plane2048") local mp = m and m:FindFirstChildWhichIsA("MeshPart", true) '
                   'if not mp then return "no Plane2048 part on client" end local out = {} '
                   'for _, c in mp:GetChildren() do if c:IsA("SurfaceAppearance") then '
                   'table.insert(out, c.Name .. " " .. c.ColorMap .. " " .. tostring(c.Color)) end end '
                   'local em = f:FindFirstChild("PlaneEM") '
                   'return "client SAs on Plane2048: " .. table.concat(out, "; ") .. " | PlaneEM on client: " .. '
                   'tostring(em ~= nil) .. (em and (" MeshId=" .. em.MeshId .. " size=" .. tostring(em.Size)) or "")')
    R["play_client"] = text[:1000]
    log("play client", text[:400])
    # play capture of the swapped plane (red tint expected) and the untouched-but-recoloured 1024 plane
    smoke.front()
    for sh in shots:
        if sh["name"] in ("over2048", "over1024"):
            ok, texts, images = s.call("screen_capture", {"studio_id": sid, "capture_id": "play_" + sh["name"],
                                                          "camera_position": sh["cam"], "look_at_position": sh["look"]}, 60)
            if images:
                p = os.path.join(CAP, "play_" + sh["name"] + ".png")
                open(p, "wb").write(base64.b64decode(images[0]))
                R.setdefault("play_captures", []).append(p)
    # shot-setup in the Client datamodel
    ok, text = lua(s, "Client", open(os.path.join(REPO, "art/lookdev/shot-setup.luau")).read(), 120)
    R["shotsetup_client"] = {"load": [ok, text[:500]]}
    ok, text = lua(s, "Client", "return _G.LookDev.apply('Overcast', false)")
    R["shotsetup_client"]["Overcast_false"] = [ok, text[:300]]
    ok, text = lua(s, "Client", 'local pg = game:GetService("Players").LocalPlayer.PlayerGui local on, all = {}, 0 '
                   'for _, g in pg:GetDescendants() do if g:IsA("ScreenGui") then all += 1 if g.Enabled then '
                   'table.insert(on, g.Name) end end end return string.format("ScreenGuis %d, still enabled: [%s]", all, '
                   'table.concat(on, ","))')
    R["shotsetup_client"]["guis"] = text[:400]
    ok, text = lua(s, "Client", "return _G.LookDev.apply('Storm', true)")
    R["shotsetup_client"]["Storm_true"] = [ok, text[:300]]
    log("shot-setup client", json.dumps(R["shotsetup_client"])[:600])
    ok, texts, _ = smoke.call(s, "get_console_output", {}, 60)
    console = "\n".join(texts)
    open(os.path.join(HERE, "console.txt"), "w").write(console)
    R["console_errors"] = smoke.error_lines(console)[:30]
    smoke.cmd_play(s, "stop")
    save()


if __name__ == "__main__":
    main()
