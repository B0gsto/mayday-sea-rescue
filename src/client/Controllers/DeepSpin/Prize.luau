--!strict
-- DeepSpin/Prize: the real prize as a local copy (a pet's rig, a boat's VehiclePreviews model, the RIB painted in a
-- skin's finish, a Lego cash stack), fitted to a size, and the Lego build (BuildSeq order, the reference's timing).
--   Prize.model(payload, size) -> Model             a whole copy, its pivot on its bottom centre
--   Prize.reveal(payload, at, duration) -> handle   handle:step(dt, at) builds and turns; :finish() :grey() :destroy()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildSeq = require(Shared:WaitForChild("BuildSeq"))
local Livery =
	require(Shared:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Livery"))
local LiveryPaint = require(Shared:WaitForChild("LiveryPaint"))
local LiveryPattern = require(Shared:WaitForChild("LiveryPattern"))
local SpinCurve = require(Shared:WaitForChild("SpinCurve"))
local WildlifeRig = require(Shared:WaitForChild("WildlifeRig"))

local rgb = Color3.fromRGB
local PLAIN = rgb(154, 163, 173) -- a skin's boat before the paint sweep
local GREY = rgb(124, 133, 145) -- an owned duplicate
local SKIN_BOAT = "RIB"
local function brick(model: Model, size: Vector3, at: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = "Brick"
	p.Size = size
	p.CFrame = at
	p.Color = color
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local Prize = {}

-- the reference's cash: stacks of gold bricks
local function cashStack(): Model
	local model = Instance.new("Model")
	model.Name = "Cash"
	local gold, shade = rgb(244, 194, 13), rgb(200, 147, 26)
	for _, stack in { { -2.5, -1.5, 4 }, { 0.5, -1.5, 6 }, { 2.5, 0.5, 3 }, { -1.5, 1.5, 2 } } do
		for y = 1, stack[3] do
			brick(
				model,
				Vector3.new(1.9, 0.95, 1.9),
				CFrame.new(stack[1], y - 0.5, stack[2]),
				if y % 2 == 0 then shade else gold
			)
		end
	end
	return model
end

local function fallbackBoat(): Model
	local model = Instance.new("Model")
	model.Name = "Boat"
	brick(model, Vector3.new(8, 1.6, 3.6), CFrame.new(0, 0.8, 0), rgb(70, 78, 88))
	brick(model, Vector3.new(8.1, 0.5, 3.7), CFrame.new(0, 1.8, 0), rgb(214, 48, 45))
	brick(model, Vector3.new(3, 1.6, 2.4), CFrame.new(-1, 2.8, 0), rgb(242, 240, 232))
	return model
end

local function preview(id: string?): Model
	local previews = ReplicatedStorage:FindFirstChild("VehiclePreviews")
	local source = previews and id and previews:FindFirstChild(id)
	if source and source:IsA("Model") then
		return source:Clone()
	end
	return fallbackBoat()
end

local function finishOption(payload: any): any
	for _, option in (Livery :: any).options do
		if option.id == payload.option then
			return option
		end
	end
	return nil
end

-- the code-made trim a real livery welds on (server/Cosmetics/Liveries `trim`): it is what makes "Red Stripes" stripes
local function layTrim(model: Model, option: any)
	if not LiveryPattern.known(option.pattern) then
		return
	end
	local hull: BasePart?, tubes: BasePart? = nil, nil
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			local _, token = LiveryPaint.parseName(d.Name)
			if token == "Hull" then
				hull = d
			elseif token == "Tubes" then
				tubes = d
			end
		end
	end
	local function lay(anchor: BasePart, surface: string)
		for _, spec in LiveryPattern.plan(option.pattern, surface, anchor.Size) do
			local p = Instance.new("Part")
			p.Name = "LiveryTrim"
			p.Size = spec.size
			p.CFrame = anchor.CFrame * CFrame.new(spec.offset) * CFrame.Angles(0, spec.yaw, 0)
			p.CastShadow = false
			p:SetAttribute("Paint", if spec.glow then nil else "Stripe1")
			if spec.glow then
				p.Color = if typeof(option.glow) == "Color3" then option.glow else option.stripe
				p.Material = Enum.Material.Neon
			else
				p.Material = Enum.Material.SmoothPlastic
			end
			p.Parent = model
		end
	end
	if hull then
		lay(hull, "hull")
		lay(hull, "deck")
	end
	if tubes then
		lay(tubes, "tube")
	end
end

-- each part's finished colour, by its paint role; a model with no roles takes the primary all over
local function paintTargets(model: Model, option: any): { [BasePart]: Color3 }
	local out: { [BasePart]: Color3 } = {}
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			local rule = LiveryPaint.meshRule(d.Name)
			local role = LiveryPaint.attrRole(d:GetAttribute("Paint"))
				or (rule and (rule :: any).role)
			local c = role and LiveryPaint.colorFor(option, role)
			if c then
				out[d] = c
			end
		end
	end
	if next(out) == nil then
		for _, p in parts do
			out[p] = option.primary
		end
	end
	for p in out do
		local look = p:FindFirstChildOfClass("SurfaceAppearance")
		if look then
			look:Destroy() -- shortcut: flat paint on the local copy, Liveries.apply's map-only looks are server side
		end
		if option.metallic then
			p.Material = Enum.Material.Metal
		elseif option.neon then
			p.Material = Enum.Material.SmoothPlastic
		end
	end
	return out
end

-- anchored, inert, the pivot on the bottom centre, the longest side = size
local function fit(model: Model, size: number): Model
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		elseif d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
			(d :: any).Enabled = false -- no wake or exhaust on a boat standing on a turntable
		end
	end
	local _, box = model:GetBoundingBox()
	local longest = math.max(box.X, box.Y, box.Z, 0.01)
	model:ScaleTo(model:GetScale() * size / longest)
	local cf, sized = model:GetBoundingBox()
	model.WorldPivot = cf * CFrame.new(0, -sized.Y / 2, 0)
	return model
end

local function make(payload: any): (Model, any)
	if payload.kind == "pet" then
		local rig = WildlifeRig.build(tostring(payload.pet or payload.name), false)
		if rig then
			return rig, nil
		end
	elseif payload.kind == "boat" then
		return preview(payload.vehicle), nil
	elseif payload.kind == "finish" then
		local model, option = preview(SKIN_BOAT), finishOption(payload)
		if option then
			layTrim(model, option)
		end
		return model, option
	end
	return cashStack(), nil
end

function Prize.model(payload: any, size: number): Model
	local model, option = make(payload)
	fit(model, size)
	if option then
		for p, c in paintTargets(model, option) do
			p.Color = c
		end
	end
	return model
end

function Prize.reveal(payload: any, parent: Instance, duration: number, size: number)
	local model, option = make(payload)
	fit(model, size)
	local pivot = model.WorldPivot
	local paints = if option then paintTargets(model, option) else nil
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local ys: { number } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			offsets[#parts] = pivot:ToObjectSpace(d.CFrame)
			ys[#parts] = d.CFrame.Y
			d.LocalTransparencyModifier = 1
			if paints and paints[d] then
				d.Color = PLAIN
			end
		end
	end
	-- BuildSeq's order, played to the reference's clock: each brick lands in 22% of the build
	local plan = BuildSeq.plan(ys, math.random(0, 1_000_000))
	local order: { number } = {}
	for k, s in plan do
		order[s.i] = if #plan > 1 then (k - 1) / (#plan - 1) else 0
	end
	local minX, maxX = math.huge, -math.huge
	for _, o in offsets do
		minX, maxX = math.min(minX, o.X), math.max(maxX, o.X)
	end
	local _, box = model:GetBoundingBox()
	local drop = math.max(box.Y, 2) * 1.2
	model.Parent = parent

	local t, yaw, greyed = 0, 0.72, false
	local handle: any = {}
	function handle.step(_: any, dt: number, at: CFrame)
		t += dt
		yaw += dt * 0.9
		local k = math.clamp(t / duration, 0, 1)
		local turn = at * CFrame.Angles(0, yaw, 0)
		-- the paint sweeps along the hull as the last bricks land
		local sweep = if paints
			then minX + (maxX - minX + 2) * SpinCurve.smooth(duration * 0.75, duration + 0.45, t) - 1
			else 0
		for i, p in parts do
			local l = math.clamp((k - order[i] * 0.78) / 0.22, 0, 1)
			p.LocalTransparencyModifier = if l > 0 then 0 else 1
			if l > 0 then
				p.CFrame = turn
					* CFrame.new(0, (1 - SpinCurve.easeOutBack(l)) * drop, 0)
					* offsets[i]
			end
			if paints and paints[p] and not greyed then
				p.Color = if offsets[i].X <= sweep then paints[p] else PLAIN
			end
		end
	end
	function handle.finish()
		t = math.max(t, duration)
	end
	-- an owned duplicate turns to grey plastic before it pays out
	function handle.grey()
		greyed = true
		for _, p in parts do
			local look = p:FindFirstChildOfClass("SurfaceAppearance")
			if look then
				look:Destroy()
			end
			p.Color = GREY
		end
	end
	function handle.hide()
		for _, p in parts do
			p.Transparency = 1
		end
	end
	function handle.destroy()
		model:Destroy()
	end
	return handle
end

return Prize
