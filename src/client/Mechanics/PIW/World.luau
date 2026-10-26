--!strict
-- PIW/World: what the mechanics read from the live scene (the casualty model, the boat, the
-- camera) and the real-world cues they add locally: the lifejacket strobe, an orange smoke float
-- on the search start, a dan buoy marker. Client-only; nothing here replicates.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Flipbooks = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Fx")
		:WaitForChild("Flipbooks")
)
local Ui = require(script.Parent.Ui)
local Units = require(script.Parent.Units)

local World = {}

-- The casualty's model: Workspace.CallProps "Victim" with CallId = the operation id, the one
-- closest to the server's casualty position.
function World.victim(ctx: { [string]: any }): Model?
	local folder = Workspace:FindFirstChild("CallProps")
	if not folder then
		return nil
	end
	local opId = ctx.operation and ctx.operation.id
	local near = ctx.casualty and ctx.casualty.position
	local best: Model?, bestD = nil, math.huge
	for _, m in folder:GetChildren() do
		if
			m:IsA("Model")
			and m.Name == "Victim"
			and m:GetAttribute("CallId") == opId
			and m.PrimaryPart
		then
			local d = if typeof(near) == "Vector3"
				then (m.PrimaryPart.Position - near).Magnitude
				else 0
			if d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

function World.casualtyPos(ctx: { [string]: any }, model: Model?): Vector3
	if model and model.PrimaryPart and model.Parent then
		return model.PrimaryPart.Position
	end
	local p = ctx.casualty and ctx.casualty.position
	if typeof(p) == "Vector3" then
		return p
	end
	local t = ctx.scene and ctx.scene.targets and ctx.scene.targets[1]
	if typeof(t) == "Vector3" then
		return t
	end
	return if typeof(ctx.operation.position) == "Vector3"
		then ctx.operation.position
		else Vector3.zero
end

-- The boat the player drives or rides (ctx.vehicle, else the seat they sit in).
function World.vehicle(ctx: { [string]: any }): Model?
	local v = ctx.vehicle
	if typeof(v) == "Instance" and v:IsA("Model") and v.Parent then
		return v
	end
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local model = seat and seat:FindFirstAncestorOfClass("Model")
	if model and model.Parent and model.Parent.Name == "Vehicles" then
		return model
	end
	return nil
end

export type Hull = {
	root: BasePart,
	position: Vector3,
	velocity: Vector3,
	forward: Vector3,
	length: number,
	beam: number,
	cframe: CFrame,
}

function World.hull(model: Model?): Hull?
	local root = model and model.PrimaryPart
	if not root then
		return nil
	end
	return {
		root = root,
		position = root.Position,
		velocity = root.AssemblyLinearVelocity,
		forward = Units.unitOr(root.CFrame.LookVector, Vector3.new(0, 0, -1)),
		length = root.Size.Z,
		beam = root.Size.X,
		cframe = root.CFrame,
	}
end

function World.seat(model: Model?): VehicleSeat?
	if not model then
		return nil
	end
	return model:FindFirstChildWhichIsA("VehicleSeat", true)
end

function World.isJetSki(model: Model?): boolean
	if not model then
		return false
	end
	local id = model:GetAttribute("VehicleId") or model:GetAttribute("Kind") or model.Name
	return string.find(string.lower(tostring(id)), "jet") ~= nil
end

function World.isDriver(model: Model?): boolean
	local seat = World.seat(model)
	local char = Players.LocalPlayer.Character
	return seat ~= nil and char ~= nil and seat.Occupant ~= nil and seat.Occupant.Parent == char
end

-- Sitting in any craft in Workspace.Vehicles (the helm or a passenger seat).
function World.seated(): boolean
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local folder = Workspace:FindFirstChild("Vehicles")
	return seat ~= nil and folder ~= nil and seat:IsDescendantOf(folder)
end

-- The boat's hull only while the player sits in a craft: a boat left behind (the swimmer jumped off)
-- must not stand in for where they are.
function World.aboardHull(ctx: { [string]: any }): Hull?
	return if World.seated() then World.hull(World.vehicle(ctx)) else nil
end

-- On the water: in a craft, or swimming (docs/14 section 3: a swimmer can reach and drag them).
function World.afloat(): boolean
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return World.seated() or (hum ~= nil and hum:GetState() == Enum.HumanoidStateType.Swimming)
end

-- Slam strength this frame from the boat simulation (BoatController telemetry), 0 if unknown.
function World.slam(): number
	local ok, value = pcall(function()
		local controllers = script.Parent.Parent.Parent:FindFirstChild("Controllers")
		local bc = controllers and controllers:FindFirstChild("BoatController")
		if not bc then
			return 0
		end
		local tel = (require :: any)(bc).GetTelemetry()
		return if tel then tel.slam else 0
	end)
	return if ok and type(value) == "number" then value else 0
end

function World.camera(): Camera
	return Workspace.CurrentCamera :: Camera
end

function World.onScreen(point: Vector3): (Vector2?, boolean)
	local v, visible = World.camera():WorldToViewportPoint(point)
	if not visible then
		return nil, false
	end
	return Vector2.new(v.X, v.Y), true
end

-- A dan buoy on the search start, with a smoke float trailing orange smoke downwind.
function World.marker(bag: Ui.Bag, position: Vector3, windDirection: number, smoke: boolean): Model
	local m = Instance.new("Model")
	m.Name = "PIW_SearchStart"
	local float = Instance.new("Part")
	float.Shape = Enum.PartType.Cylinder
	float.Size = Vector3.new(1.2, 1.6, 1.6)
	float.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	float.Color = Color3.fromRGB(255, 120, 20)
	float.Material = Enum.Material.SmoothPlastic
	float.Anchored, float.CanCollide, float.CanQuery = true, false, false
	float.Parent = m
	local pole = Instance.new("Part")
	pole.Size = Vector3.new(0.15, 6, 0.15)
	pole.CFrame = CFrame.new(position + Vector3.new(0, 3.4, 0))
	pole.Color = Color3.fromRGB(30, 30, 30)
	pole.Anchored, pole.CanCollide, pole.CanQuery = true, false, false
	pole.Parent = m
	local flag = Instance.new("Part")
	flag.Size = Vector3.new(0.05, 1.2, 1.6)
	flag.CFrame = CFrame.new(position + Vector3.new(0, 5.8, 0.8))
	flag.Color = Color3.fromRGB(255, 200, 0)
	flag.Anchored, flag.CanCollide, flag.CanQuery = true, false, false
	flag.Parent = m
	if smoke then
		local emitter = Instance.new("ParticleEmitter")
		-- FX2 orange smoke: a Mantaflow billow per particle (the sheet is already orange)
		Flipbooks.apply(emitter, "FX_Smoke_Orange")
		local sheet = Flipbooks.uploaded("FX_Smoke_Orange")
		emitter.Color = if sheet
			then ColorSequence.new(Color3.fromRGB(255, 196, 160)) -- pushes the amber sheet to signal orange
			else ColorSequence.new(Color3.fromRGB(255, 130, 40), Color3.fromRGB(255, 170, 110))
		emitter.Size = if sheet
			then NumberSequence.new({
				NumberSequenceKeypoint.new(0, 4),
				NumberSequenceKeypoint.new(1, 13),
			})
			else NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.5),
				NumberSequenceKeypoint.new(1, 9),
			})
		emitter.Rotation = NumberRange.new(-10, 10)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(5, 8)
		emitter.Rate = 14
		emitter.Speed = NumberRange.new(1.5, 3)
		emitter.SpreadAngle = Vector2.new(20, 20)
		emitter.Acceleration = Units.windVector(windDirection) * 3 + Vector3.new(0, 0.6, 0)
		emitter.LightEmission = 0
		emitter.LightInfluence = 1
		emitter.Parent = float
	end
	m.Parent = Workspace
	Ui.add(bag, m)
	return m
end

-- Thin local line on the water (Assist overlays: approach cone edges, search legs, throw arc).
function World.line(bag: Ui.Bag, a: Vector3, b: Vector3, color: Color3, width: number?): Part
	local p = Instance.new("Part")
	local len = (b - a).Magnitude
	p.Size = Vector3.new(width or 0.25, 0.05, math.max(len, 0.1))
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = 0.45
	p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
	p.Parent = Workspace.CurrentCamera
	Ui.add(bag, p)
	return p
end

return World
