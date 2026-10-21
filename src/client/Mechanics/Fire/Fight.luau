--!strict
-- fire_fight (docs/09 8.2, Boundary cooling): from the lifeboat, hold the monitor's jet on the
-- base of the fire, then sweep the hull beside it so the hot panels cannot spread the fire. The
-- reticle is the aim; the flames and the four boundary marks read the result in the world.
-- Metrics: base (share of the needed hold on the base, 0..1), panels (cooled boundary, 0..1),
-- elapsed and spread (server, the fire's own growth while it was ignored).
-- Controls: aim (mouse / right stick / drag), hold Spray (left click / touch Action / A, RT).
local Scene = require(script.Parent:WaitForChild("Scene"))
local Step = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Step"))
local Ui = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Ui"))
local Units = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("Units"))
local World = require(script.Parent.Parent:WaitForChild("PIW"):WaitForChild("World"))

local Fight = {}

Fight.RANGE = 120 -- studs: the monitor's reach
Fight.BASE_ANGLE = 9 -- deg off the base that still lands water
Fight.PANEL_ANGLE = 13 -- deg off a boundary mark
Fight.BASE_NEED = 5 -- s of water on the base
Fight.PANEL_SECONDS = 2 -- s per boundary mark
Fight.PANELS = 4

local function marker(parent: Instance, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = "FireBoundaryMark"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.1, 1.1, 1.1)
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.45
	p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
	p.Parent = parent
	return p
end

function Fight.start(ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()): (() -> ())?
	local s = Step.new(ctx, finish, "FireFight", 160)
	if Step.autoStub(s, { base = 1, panels = 1 }) then
		return Step.cleanup(s)
	end
	local info = Step.line(s, "", 54)
	local setBase = Ui.meter(s.panel, "On the base", UDim2.fromOffset(12, 78), 300)
	local hullLabel =
		Ui.text(s.panel, "Hull", UDim2.fromOffset(60, 18), UDim2.fromOffset(330, 86), 15)
	hullLabel.TextColor3 = Ui.Theme.Colors.textDim
	local dots: { Frame } = {}
	for i = 1, Fight.PANELS do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(26, 14)
		dot.Position = UDim2.fromOffset(330 + (i - 1) * 32, 108)
		dot.BackgroundColor3 = Ui.Theme.Colors.locked
		dot.BorderSizePixel = 0
		dot.Parent = s.panel
		Ui.Theme.corner(dot, 4)
		table.insert(dots, dot)
	end
	local holding = false
	Ui.action(s.bag, s.gui, "Spray", function()
		holding = true
	end, function()
		holding = false
	end)

	local jet = Instance.new("Part")
	jet.Name = "FireJet"
	jet.Size = Vector3.new(0.35, 0.35, 1)
	jet.Material = Enum.Material.SmoothPlastic
	jet.Color = Color3.fromRGB(196, 224, 236)
	jet.Transparency = 1
	jet.Anchored, jet.CanCollide, jet.CanQuery, jet.CastShadow = true, false, false, false
	jet.Parent = workspace.CurrentCamera
	Ui.add(s.bag, jet)

	local baseSeconds = 0
	local panelSeconds = { 0, 0, 0, 0 }
	local cooled = { false, false, false, false }
	local marks: { Part } = {}
	local markAt: { [number]: boolean } = {}

	local function marksFor(model: Model)
		local boundary = Scene.boundary(model)
		for i = 1, #boundary do
			if not markAt[i] then
				markAt[i] = true
				local m = marker(workspace.CurrentCamera, Color3.fromRGB(150, 70, 30))
				m.Name = `FireBoundary_{i}`
				table.insert(marks, m)
			end
		end
	end

	Step.heartbeat(s, function(dt)
		local model = Scene.burning()
		local hull = World.hull(World.vehicle(ctx))
		local base = Scene.base(model)
		if not (model and hull and base) then
			info.Text = "Take a boat"
			jet.Transparency = 1
			holding = false
			return
		end
		if #marks == 0 then
			marksFor(model)
		end
		local firePos = base.WorldPosition
		local distance = Units.flatDistance(hull.position, firePos)
		local boundary = Scene.boundary(model)
		local target: Vector3? = nil
		local onBase = false
		if holding and distance <= Fight.RANGE then
			if World.lookError(firePos) <= Fight.BASE_ANGLE then
				baseSeconds += dt
				target = firePos
				onBase = true
			else
				local best, bestAngle = 0, math.huge
				for i, a in boundary do
					local angle = World.lookError(a.WorldPosition)
					if not cooled[i] and angle <= Fight.PANEL_ANGLE and angle < bestAngle then
						best, bestAngle = i, angle
					end
				end
				if best > 0 then
					target = boundary[best].WorldPosition
					panelSeconds[best] += dt
					if panelSeconds[best] >= Fight.PANEL_SECONDS then
						cooled[best] = true
						dots[best].BackgroundColor3 = Ui.Theme.Colors.ready
					end
				end
			end
		end
		if target then
			local from = hull.position + hull.forward * (hull.length * 0.4) + Vector3.new(0, 1, 0)
			local dist = (target - from).Magnitude
			jet.Size = Vector3.new(0.35, 0.35, math.max(dist, 0.1))
			jet.CFrame = CFrame.lookAt((from + target) / 2, target)
			jet.Transparency = 0.35
		else
			jet.Transparency = 1
		end
		for i, m in marks do
			local a = boundary[i]
			if a then
				m.CFrame = CFrame.new(a.WorldPosition)
			end
			m.Transparency = if cooled[i] then 0.6 else 0.35
			m.Color = if cooled[i]
				then Color3.fromRGB(70, 150, 210)
				else Color3.fromRGB(220, 90, 30)
		end
		local cooledCount = 0
		for i = 1, Fight.PANELS do
			if cooled[i] then
				cooledCount += 1
			end
		end
		setBase(math.clamp(baseSeconds / Fight.BASE_NEED, 0, 1), 0.99, 1)
		info.Text = if distance > Fight.RANGE
			then "Get closer"
			elseif onBase then "On the base"
			elseif target then "Cooling the hull"
			else "Aim"
		info.TextColor3 = if target then Ui.Theme.Colors.ready else Ui.Theme.Colors.text
		if baseSeconds >= Fight.BASE_NEED and cooledCount >= Fight.PANELS then
			Step.finish(s, {
				metrics = {
					base = 1,
					panels = cooledCount / Fight.PANELS,
				},
			})
		end
	end)
	return Step.cleanup(s)
end

return Fight
