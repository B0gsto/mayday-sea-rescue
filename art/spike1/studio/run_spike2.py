#!/usr/bin/env python3
"""Spike 1 Studio session 2: closer texture close-ups (1-px zones at 2x and 3x the session-1 magnification),
tentacle side views with bone world positions, the play-mode SurfaceAppearance swap probe (fixed) with a
LookDev-locked client capture. Same window/tag as run_spike.py; never saves; closes the window."""
import base64, json, os, subprocess, sys, time, traceback
import run_spike as rs
from run_spike import HERE, REPO, CAP, R, log, lua, capture, smoke, StudioSession

rs.save = lambda: json.dump(R, open(os.path.join(HERE, "results.json"), "w"), indent=1)


def main():
    open(os.path.join(HERE, "log.txt"), "w").close()
    smoke.cmd_open()
    sid = smoke.sid()
    try:
        for n in ["TexPlane", "Tentacle20", "Tentacle40"]:
            r = subprocess.run([sys.executable, os.path.expanduser("~/RobloxProjects/tools/studio-insert.py"),
                                os.path.join(REPO, "assets/models/M_Spike1_%s.rbxm" % n), sid, "Workspace",
                                "--game", "MaydaySeaRescue"], capture_output=True, text=True, timeout=180)
            log("insert", n, r.returncode, (r.stdout + r.stderr).strip()[-120:])
        with StudioSession() as s:
            run(s, sid)
    except Exception:
        R["fatal"] = traceback.format_exc()
        log("FATAL", R["fatal"][-1500:])
    finally:
        rs.save()
        try:
            with StudioSession() as s:
                if smoke.mode(s).lower() != "edit":
                    smoke.cmd_play(s, "stop")
                lua(s, "Edit", 'pcall(function() settings().Rendering.EditQualityLevel = Enum.QualityLevel.Automatic end) '
                    'workspace.CurrentCamera.FieldOfView = 70 return "restored"')
        except Exception as e:  # noqa: BLE001
            log("restore failed", e)
        smoke.cmd_close()
        log("closed; total", round(time.time() - rs.T0, 1), "s")
        rs.save()


def run(s, sid):
    ok, text = lua(s, "Edit", open(os.path.join(HERE, "setup.luau")).read(), 240)
    R["setup"] = json.loads(text[text.index("{"):text.rindex("}") + 1])
    log("setup", ok, json.dumps(R["setup"].get("quality")))
    shots = R["setup"]["shots"]
    smoke.front()
    capture(s, sid, "warmup", shots[0]["cam"], shots[0]["look"], 10)
    time.sleep(1.5)
    R["captures"] = {}
    for sh in shots:
        if not sh["name"].startswith("tex") or "EM" in sh["name"]:
            continue
        for k in (1, 0.5, 0.333):
            if k != 1 and not sh["name"].endswith("z1px"):
                continue
            cam = [l + (c - l) * k for c, l in zip(sh["cam"], sh["look"])]
            name = "%s_d%g" % (sh["name"], round(sh["dist"] * k, 1))
            p = capture(s, sid, name, cam, sh["look"], 10)
            R["captures"][name] = {**sh, "name": name, "cam": cam, "dist": sh["dist"] * k, "path": p}
    log("tex captures", len(R["captures"]))

    # tentacles: geometry facts and side views (+X and +Z), bends about Z and X
    INFO = ('local out = {} for _, n in {"M_Spike1_Tentacle20", "M_Spike1_Tentacle40"} do '
            'local mp = workspace.Spike1[n]:FindFirstChildWhichIsA("MeshPart", true) local bs = {} '
            'for _, d in mp:GetDescendants() do if d:IsA("Bone") then bs[d.Name] = d end end '
            'local last = bs[string.format("Bone_%02d", (n:sub(-2) == "20" and 19 or 39))] '
            'out[n] = {pos = tostring(mp.Position), rot = tostring(mp.Orientation), size = tostring(mp.Size), '
            'b0 = tostring(bs.Bone_00.WorldPosition), b0rot = tostring(bs.Bone_00.WorldOrientation), '
            'bLast = tostring(last.WorldPosition), b0parent = bs.Bone_00.Parent.Name} end '
            'return game:GetService("HttpService"):JSONEncode(out)')
    ok, text = lua(s, "Edit", INFO)
    R["tentacle_info"] = text[:1500]
    log("tentacle info", text[:600])
    BEND = ('local mp = workspace.Spike1["%s"]:FindFirstChildWhichIsA("MeshPart", true) '
            'local b = mp:FindFirstChild("%s", true) _G.__rest = _G.__rest or {} _G.__rest[b] = _G.__rest[b] or b.CFrame '
            'b.CFrame = _G.__rest[b] * CFrame.Angles(math.rad(%d), 0, math.rad(%d)) return "ok"')
    R["tentacle"] = {}
    for name, bones in (("M_Spike1_Tentacle20", ["Bone_10"]), ("M_Spike1_Tentacle40", ["Bone_10", "Bone_30"])):
        ok, pos = lua(s, "Edit", 'return tostring(workspace.Spike1["%s"]:FindFirstChildWhichIsA("MeshPart", true).Position)' % name)
        c = [float(v) for v in pos.strip().split(",")]
        short = name[-10:]
        for view, off in (("X", [40, 0, 0]), ("Z", [0, 0, 40])):
            cam = [c[i] + off[i] for i in range(3)]
            R["tentacle"]["%s_%s_rest" % (short, view)] = capture(s, sid, "%s_%s_rest" % (short, view), cam, c, 45)
            for b in bones:
                lua(s, "Edit", BEND % (name, b, 50, 50))
                time.sleep(0.4)
                R["tentacle"]["%s_%s_%s" % (short, view, b)] = capture(s, sid, "%s_%s_%s" % (short, view, b), cam, c, 45)
                lua(s, "Edit", BEND % (name, b, 0, 0))
    rs.save()

    # play-mode swap probe
    src = open(os.path.join(HERE, "probe_server.luau")).read()
    lua(s, "Edit", 'local sc = Instance.new("Script") sc.Name = "Spike1Probe" sc.Source = %s '
        'sc.Parent = game:GetService("ServerScriptService") workspace.CurrentCamera.FieldOfView = 70 return "ok"' % json.dumps(src))
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
    log("play server", attrs[:700])
    time.sleep(2)
    ok, text = lua(s, "Client", 'local mp = workspace.Spike1.Plane2048:FindFirstChildWhichIsA("MeshPart", true) local out = {} '
                   'for _, c in mp:GetChildren() do if c:IsA("SurfaceAppearance") then '
                   'table.insert(out, c.Name .. " " .. tostring(c.Color)) end end return table.concat(out, "; ")')
    R["play_client"] = text[:600]
    log("play client", text[:300])
    ok, text = lua(s, "Client", open(os.path.join(REPO, "art/lookdev/shot-setup.luau")).read(), 120)
    lua(s, "Client", "return _G.LookDev.apply('Clear', false)")
    smoke.front()
    R["play_captures"] = {}
    for sh in shots:
        if sh["name"] in ("over1024", "over2048", "over4096"):
            lua(s, "Client", "_G.LookDev.shot({%s}, {%s}) return 'ok'" % (
                ",".join(map(str, sh["cam"])), ",".join(map(str, sh["look"]))))
            time.sleep(1.2)
            ok, texts, images = s.call("screen_capture", {"studio_id": sid, "capture_id": "play_" + sh["name"]}, 60)
            if images:
                p = os.path.join(CAP, "play_" + sh["name"] + ".png")
                open(p, "wb").write(base64.b64decode(images[0]))
                R["play_captures"][sh["name"]] = p
    ok, texts, _ = smoke.call(s, "get_console_output", {}, 60)
    console = "\n".join(texts)
    open(os.path.join(HERE, "console2.txt"), "w").write(console)
    R["console_errors"] = smoke.error_lines(console)[:30]
    smoke.cmd_play(s, "stop")
    rs.save()


if __name__ == "__main__":
    main()
