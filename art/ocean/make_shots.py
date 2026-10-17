#!/usr/bin/env python3
"""Writes art/ocean/shots.json (calm pass) and shots-storm.json (storm pass) for capture.sh.

Round 4: every camera sits over open water on the real Gale Isles terrain (WorldConfig, doc 10:
+X east, +Z south / out to sea; the harbour mouth is at z 368, Haven Sands runs (640,130)-(1340,590),
the Morwenna wreck lies at (620,-21.5,860)). Low shots aim by the sun / moon, then turn (up to 80 deg)
until horizontal terrain rays across the frame find no land within 2400 studs. The storm pass spawns
a client-local jet ski and RIB (Boat Builder, anchored, floated on Waves each frame) running south-east
at 22 studs/s; the camera tracks them so both stay in frame with their wakes.
usage: python3 art/ocean/make_shots.py
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))

PRE = (
    'local rp = RaycastParams.new() rp.FilterType = Enum.RaycastFilterType.Include '
    'rp.FilterDescendantsInstances = {workspace.Terrain} '
    'local function clearDir(p, f) for _, a in {0, 0.26, -0.26, 0.52, -0.52, 0.79, -0.79, 1.05, -1.05, 1.4, -1.4} do '
    'local g = CFrame.Angles(0, a, 0):VectorToWorldSpace(f) local ok = true '
    'for _, e in {0, 0.5, -0.5} do if workspace:Raycast(Vector3.new(p.X, 3, p.Z), '
    'CFrame.Angles(0, e, 0):VectorToWorldSpace(g) * 2400, rp) then ok = false break end end '
    'if ok then return g end end return f end '
    'local function flat(v) return Vector3.new(v.X, 0, v.Z).Unit end '
    'local function shoot(p, f, pitch) local c = workspace.CurrentCamera c.CameraType = Enum.CameraType.Scriptable '
    'c.CFrame = CFrame.lookAt(p, p + f * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)) '
    'workspace:SetAttribute("ShotCF", c.CFrame) end '
)


def light(base, clock):
    return f'game.Lighting:SetAttribute("WeatherBase", "{base}") game.Lighting.ClockTime = {clock} '


def shot(name, cam, look, lua):
    return {"name": name, "cam": cam, "look": look, "settle": 4, "lua": PRE + lua}


def v(p):
    return "Vector3.new(%s, %s, %s)" % tuple(p)


calm = [
    # Golden hour, low over deep water (-63) south-west of the harbour; open sea to the west.
    shot("golden_low_sunward", [-900, 7, 1500], [-1000, 7, 1500],
         light("Calm", 17.3) + f'local p = {v([-900, 7, 1500])} '
         'shoot(p, clearDir(p, flat(game.Lighting:GetSunDirection())), -0.03)'),
    shot("golden_low_away", [-900, 7, 1500], [-800, 7, 1500],
         light("Calm", 17.3) + f'local p = {v([-900, 7, 1500])} '
         'shoot(p, clearDir(p, -flat(game.Lighting:GetSunDirection())), -0.03)'),
    # Noon glitter from 90 studs, 930 studs south of the harbour mouth, looking sunward and down.
    shot("noon_high_clear", [200, 90, 1300], [200, 0, 1460],
         light("Clear", 12.5) + f'local p = {v([200, 90, 1300])} '
         'shoot(p, clearDir(p, flat(game.Lighting:GetSunDirection())), -0.5)'),
    shot("overcast_low", [300, 7, 1200], [450, 0, 1500],
         light("Overcast", 13) + f'local p = {v([300, 7, 1200])} '
         'shoot(p, clearDir(p, Vector3.new(0.5, 0, 1).Unit), -0.02)'),
    shot("night_moon", [0, 8, 2000], [0, 8, 2100],
         light("Clear", 22.5) + f'local p = {v([0, 8, 2000])} '
         'local d = game.Lighting:GetMoonDirection() '
         'shoot(p, clearDir(p, flat(d)), math.clamp(math.asin(d.Y) - 0.42, -0.2, 0.25))'),
    # Haven Sands: over 6-7 studs of water on the real sand (eelgrass at (860,520)), looking
    # obliquely shoreward and down across the shelving seabed.
    shot("shallow_sand_rock", [880, 18, 560], [935, -6, 495],
         light("Clear", 13) + 'local p = Vector3.new(880, 18, 560) local c = workspace.CurrentCamera '
         'c.CameraType = Enum.CameraType.Scriptable c.CFrame = CFrame.lookAt(p, Vector3.new(935, -6, 495)) '
         'workspace:SetAttribute("ShotCF", c.CFrame)'),
    # Underwater beside the Morwenna (1902 schooner, seabed -21.5), 55 studs off her port side.
    shot("underwater", [588, -12, 818], [620, -19, 860],
         light("Clear", 13) + 'local p = Vector3.new(588, -12, 818) local c = workspace.CurrentCamera '
         'c.CameraType = Enum.CameraType.Scriptable c.CFrame = CFrame.lookAt(p, Vector3.new(620, -19, 860)) '
         'workspace:SetAttribute("ShotCF", c.CFrame)'),
]

# Storm pass: spawn (once) a jet ski and a RIB and run them south-east from (200, 1150); each frame the
# boats are floated (pitch and roll from the wave heights) and ShotCF follows them by the
# workspace attribute ShotBoatCam ("close" = high 3/4 side, "low" = jet-ski level, ahead).
BOATS = (
    'local RS = game:GetService("RunService") local Sh = game.ReplicatedStorage.Shared '
    'local Builder = require(Sh.Boat.Builder) local Sim = require(Sh.Boat.Simulator) '
    'local VC = require(Sh.Config.VehicleConfig) '
    'if not workspace:FindFirstChild("ShotBoats") then '
    'local fold = Instance.new("Folder") fold.Name = "ShotBoats" fold.Parent = workspace '
    'local O, D, V = Vector3.new(200, 0, 1150), Vector3.new(0.6, 0, 0.8).Unit, 22 '
    'local R = D:Cross(Vector3.yAxis) local boats = {} '
    'for _, b in {{"JetSki", 0, 0}, {"RIB", -24, 13}} do '
    'local m = Builder.build(VC.get(b[1])) m.Name = "Shot_" .. b[1] '
    'for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true end end '
    'm.Parent = fold table.insert(boats, {m = m, a = b[2], r = b[3]}) end '
    'local t0 = os.clock() pcall(function() RS:UnbindFromRenderStep("ShotBoats") end) '
    'RS:BindToRenderStep("ShotBoats", Enum.RenderPriority.Camera.Value - 1, function() '
    'local s = (os.clock() - t0) * V local now = workspace:GetServerTimeNow() '
    'for _, b in boats do local p = O + D * (s + b.a) + R * b.r '
    'local cf = Sim.restCFrame(b.m, p.X, p.Z, D, now) local L = 6 '
    'local hf = Sim.waterHeight(p.X + D.X * L, p.Z + D.Z * L, now) local hb = Sim.waterHeight(p.X - D.X * L, p.Z - D.Z * L, now) '
    'local hr = Sim.waterHeight(p.X + R.X * 2.5, p.Z + R.Z * 2.5, now) local hl = Sim.waterHeight(p.X - R.X * 2.5, p.Z - R.Z * 2.5, now) '
    'b.m:PivotTo(cf * CFrame.Angles(math.atan2(hf - hb, 2 * L), 0, math.atan2(hr - hl, 5) * 0.7)) '
    'if b.m.PrimaryPart then b.m.PrimaryPart.AssemblyLinearVelocity = D * V end end '
    'local jet = O + D * s local cam, look '
    'if workspace:GetAttribute("ShotBoatCam") == "low" then cam = jet + D * 24 - R * 13 + Vector3.new(0, 4.5, 0) '
    'look = jet - D * 8 + R * 5 + Vector3.new(0, 1.2, 0) '
    'else cam = jet + D * 6 - R * 42 + Vector3.new(0, 9, 0) look = jet - D * 14 + R * 6 end '
    'workspace:SetAttribute("ShotCF", CFrame.lookAt(cam, look)) end) end '
)

storm = [
    shot("storm_close", [206, 9, 1113], [194, 0, 1139],
         light("Overcast", 14.5) + 'workspace:SetAttribute("ShotBoatCam", "close") ' + BOATS),
    shot("jetski_storm", [222, 4.5, 1186], [195, 1.2, 1146],
         light("Overcast", 14.5) + 'workspace:SetAttribute("ShotBoatCam", "low") ' + BOATS),
]

for fname, shots in (("shots.json", calm), ("shots-storm.json", storm)):
    with open(os.path.join(HERE, fname), "w") as f:
        json.dump(shots, f, indent=1)
    print(fname, len(shots))
