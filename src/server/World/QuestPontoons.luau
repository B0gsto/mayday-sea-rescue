--!strict
-- QuestPontoons (docs/23 (p), WP-27): each island's Lego quest pontoon (RingLayout.Islands[i].quest.pontoon) and quest
-- tablet on its stand (lots.QuestTablet; Island<i>.TabletStand, only while the owner's quests are open; the screen
-- part is named "QuestTablet", QuestController binds its prompt on your own island), in Workspace.QuestPontoons.Island<i>. And the quest boats: a giver (NpcFactory R15, in
-- Workspace.Npcs, named by npc id) stands in a small Lego boat that sails in from out at sea to a free mooring slot
-- (quest.slots), and sails off again (turn, out to sea, gone). QuestService decides who comes; this module moves them.
-- Rig attributes: QuestIsland (island index), Moored (true once tied up), Leaving (true while sailing off). The boat
-- (Workspace.QuestBoats.QuestBoat) has Giver (npc id), QuestIsland and Moored; QuestController bobs moored ones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Quests"):WaitForChild("Data"))
local NpcFactory = require(script.Parent.Parent:WaitForChild("Npc"):WaitForChild("NpcFactory"))
local RingLayout = require(Shared:WaitForChild("Config"):WaitForChild("RingLayout"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))

local QuestPontoons = {}

local OUT = 400 -- studs out to sea a boat appears / vanishes
local LANE = 7 -- studs beside its slot (away from the pontoon) a boat runs in on, clear of the other slots
local IN_TIME, OUT_TIME = 26, 22 -- s
local FEET = Vector3.new(0, 1.4, -1.6) -- where the giver stands in the boat (boat space)

local M = Enum.Material
local RED = Color3.fromRGB(224, 56, 40)
local YELLOW = Color3.fromRGB(250, 208, 40)
local BLUE = Color3.fromRGB(40, 96, 208)
local GREEN = Color3.fromRGB(80, 190, 90)
local WHITE = Color3.fromRGB(242, 240, 232)
local ORANGE = Color3.fromRGB(250, 140, 30)
local GREY = Color3.fromRGB(70, 76, 82)
local STEEL = Color3.fromRGB(190, 194, 198)
local GOLD = Color3.fromRGB(255, 196, 40)
local HULLS = { RED, BLUE, GREEN, ORANGE, YELLOW, Color3.fromRGB(250, 120, 190) } -- by giver, Data.Npcs order

export type Boat = {
	npc: string,
	island: number,
	slot: number,
	home: CFrame, -- the mooring slot
	lane: CFrame,
	side: number, -- +1 / -1: the pontoon is to the boat's right / left
	state: "in" | "moored" | "out",
	model: Model,
	rig: Model?,
	rel: CFrame, -- rig pivot relative to its feet
	path: ((number) -> CFrame)?,
	t0: number,
	dur: number,
	done: (() -> ())?,
	gone: boolean,
}

local fleets: { [number]: { [number]: Boat } } = {}
local stands: { [number]: Model } = {} -- island -> its quest tablet stand
local boatFolder: Folder
local npcFolder: Instance

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material?,
	collide: boolean?
): Part
	local p = Instance.new("Part")
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat or M.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch = true, collide == true, false
	p.CanQuery = collide == true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function stud(parent: Instance, cf: CFrame, color: Color3)
	part(parent, Vector3.new(0.5, 1.2, 1.2), cf * CFrame.Angles(0, 0, math.pi / 2), color).Shape =
		Enum.PartType.Cylinder
end

-- The pontoon (deck top at P, LookVector out to sea): three bright bricks with studs, floats under it, a bollard by
-- each mooring slot and a gold quest flag at the sea end. Then the tablet on its stand (copy of the build tablet).
local function buildIsland(i: number, isl: RingLayout.Island, parent: Instance)
	local m = Instance.new("Model")
	m.Name = `Island{i}`
	local P = isl.quest.pontoon
	local w, len = RingLayout.QUEST_PONTOON.X, RingLayout.QUEST_PONTOON.Y
	local brick = len / 3
	for k, color in { YELLOW, BLUE, RED } do
		local fwd = -len / 2 + brick * (k - 0.5)
		part(
			m,
			Vector3.new(w, 1, brick),
			P * CFrame.new(0, -0.5, -fwd),
			color,
			M.SmoothPlastic,
			true
		)
		part(
			m,
			Vector3.new(w + 0.4, 1.6, 1.6),
			P * CFrame.new(0, -2.2, -fwd),
			WHITE,
			M.SmoothPlastic
		).Shape =
			Enum.PartType.Cylinder
		for z = -brick / 2 + 1.5, brick / 2 - 1.5, 3 do
			for _, x in { -w / 4, w / 4 } do
				stud(m, P * CFrame.new(x, 0.25, -(fwd + z)), color)
			end
		end
	end
	for _, slot in isl.quest.slots do
		local s = P:PointToObjectSpace(slot.Position)
		local at = P * CFrame.new(math.sign(s.X) * (w / 2 - 0.6), 0.6, s.Z)
		part(m, Vector3.new(1.2, 1.1, 1.1), at * CFrame.Angles(0, 0, math.pi / 2), RED).Shape =
			Enum.PartType.Cylinder
		part(
			m,
			Vector3.new(0.3, 1.4, 1.4),
			at * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2),
			WHITE
		).Shape =
			Enum.PartType.Cylinder
	end
	local pole = P * CFrame.new(-w / 2 + 0.6, 4, -(len / 2 - 0.6))
	part(m, Vector3.new(0.4, 8, 0.4), pole, WHITE)
	part(m, Vector3.new(0.15, 1.8, 2.8), pole * CFrame.new(0, 3, 1.4), GOLD, M.Fabric)

	-- the tablet: a yellow Lego brick, the build tablet's stand and post, the screen facing back onto the plate
	-- (its own model, parented only while its owner's quests are open: ShowTablet)
	local t = Instance.new("Model")
	t.Name = "TabletStand"
	stands[i] = t
	local T = isl.lots.QuestTablet.cframe
	part(t, Vector3.new(3.2, 0.8, 3.2), T * CFrame.new(0, 0.4, 0), YELLOW, M.SmoothPlastic, true)
	for _, x in { -0.8, 0.8 } do
		for _, z in { -0.8, 0.8 } do
			stud(t, T * CFrame.new(x, 0.9, z), YELLOW)
		end
	end
	local stand = T * CFrame.new(0, 0.8, 0)
	part(t, Vector3.new(2.2, 0.6, 2.2), stand * CFrame.new(0, 0.3, 0), GREY, M.Metal, true)
	part(t, Vector3.new(0.6, 3.6, 0.6), stand * CFrame.new(0, 2.4, 0), STEEL, M.Metal, true)
	local tablet = part(
		t,
		Vector3.new(6.4, 4.2, 0.35),
		stand * CFrame.new(0, 5.4, 0) * CFrame.Angles(math.rad(-8), 0, 0),
		Color3.fromRGB(24, 28, 38),
		M.SmoothPlastic,
		true
	)
	tablet.Name = "QuestTablet"
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Screen"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.LightInfluence = 1
	gui.Parent = tablet
	local screen = Instance.new("Frame")
	screen.Name = "Display"
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	screen.Position = UDim2.fromScale(0.5, 0.5)
	screen.Size = UDim2.new(1, -28, 1, -28)
	screen.BackgroundColor3 = Color3.fromRGB(30, 58, 104) -- WP-25: a calm deep blue, not glaring
	screen.BorderSizePixel = 0
	screen.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 24)
	round.Parent = screen
	local icon = Instance.new("ImageLabel")
	icon.Name = "QuestIcon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.7, 0.7)
	icon.BackgroundTransparency = 1
	icon.Image = UiImages.Kit.quests
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = screen
	m.Parent = parent
end

-- A small Lego boat (~12 x 5), pivot at sea level, LookVector = bow.
local function boatModel(npc: string, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "QuestBoat"
	local idx = 1
	for k, n in Data.Npcs do
		if n.id == npc then
			idx = k
		end
	end
	local hull = HULLS[(idx - 1) % #HULLS + 1]
	part(m, Vector3.new(5, 1.6, 10), cf * CFrame.new(0, 0.4, 1), hull)
	part(m, Vector3.new(3.4, 1.6, 2), cf * CFrame.new(0, 0.4, -5), hull)
	part(m, Vector3.new(4.4, 0.2, 10.4), cf * CFrame.new(0, 1.3, 0), WHITE)
	part(m, Vector3.new(3.6, 2.4, 3), cf * CFrame.new(0, 2.6, 3.6), WHITE)
	part(
		m,
		Vector3.new(3.2, 1, 0.2),
		cf * CFrame.new(0, 3, 2.05),
		Color3.fromRGB(60, 90, 130),
		M.Glass
	)
	part(m, Vector3.new(4, 0.6, 3.4), cf * CFrame.new(0, 4.1, 3.6), hull)
	for _, x in { -1, 1 } do
		stud(m, cf * CFrame.new(x, 4.6, 3.6), hull)
	end
	m.WorldPivot = cf
	m.Parent = boatFolder
	return m
end

local function place(b: Boat, cf: CFrame)
	b.model:PivotTo(cf)
	local rig = b.rig
	if rig and rig.Parent then
		local feet = cf * CFrame.new(FEET)
		-- faces the pontoon side, where you talk to them from
		rig:PivotTo(
			CFrame.lookAt(feet.Position, (feet * CFrame.new(b.side, 0, 0)).Position) * b.rel
		)
	end
end

local function ease(a: number): number
	return a * a * (3 - 2 * a)
end

local function run(b: Boat, dur: number, path: (number) -> CFrame, done: () -> ())
	b.path, b.t0, b.dur, b.done = path, os.clock(), dur, done
end

local function setRig(b: Boat, name: string, value: any)
	if name == "Moored" then
		b.model:SetAttribute(name, value)
	end
	if b.rig then
		b.rig:SetAttribute(name, value)
	end
end

local function destroy(b: Boat)
	b.gone = true
	b.path = nil
	b.model:Destroy()
	if b.rig then
		b.rig:Destroy()
	end
	local fleet = fleets[b.island]
	if fleet and fleet[b.slot] == b then
		fleet[b.slot] = nil
	end
end

-- slot -> boat (arriving, moored or leaving) at island i
function QuestPontoons.Boats(i: number): { [number]: Boat }
	fleets[i] = fleets[i] or {}
	return fleets[i]
end

-- the boat bringing / holding giver `npc` at island i (not one sailing off)
function QuestPontoons.Find(i: number?, npc: string): Boat?
	local fleet = if i then fleets[i] else nil
	for _, b in fleet or {} :: { [number]: Boat } do
		if b.npc == npc and b.state ~= "out" then
			return b
		end
	end
	return nil
end

-- the giver's boat when it is tied up at island i
function QuestPontoons.Giver(i: number?, npc: string): Boat?
	local b = QuestPontoons.Find(i, npc)
	return if b and b.state == "moored" then b else nil
end

-- where island i's quest tablet screen is
function QuestPontoons.TabletAt(i: number): Vector3
	return RingLayout.Islands[i].lots.QuestTablet.cframe.Position + Vector3.new(0, 4, 0)
end

-- a point on the pontoon deck beside the boat (dev teleports, the pin)
function QuestPontoons.Beside(b: Boat): Vector3
	local P = RingLayout.Islands[b.island].quest.pontoon
	return (P * CFrame.new(0, 3, P:PointToObjectSpace(b.home.Position).Z)).Position
end

-- Giver `npc` sails in to the first free slot at island i; nil when all three are taken.
function QuestPontoons.Arrive(i: number, npc: Data.Npc): Boat?
	local fleet = QuestPontoons.Boats(i)
	local slots = RingLayout.Islands[i].quest.slots
	local slot: number? = nil
	for k = 1, #slots do
		if not fleet[k] then
			slot = k
			break
		end
	end
	if not slot then
		return nil
	end
	local home = slots[slot]
	local P = RingLayout.Islands[i].quest.pontoon
	local side = math.sign(home:PointToObjectSpace(P.Position).X)
	local lane = home * CFrame.new(-side * LANE, 0, 0)
	local start = lane * CFrame.new(0, 0, OUT) -- home's LookVector points at the plate: +Z is out to sea
	local b: Boat = {
		npc = npc.id,
		island = i,
		slot = slot,
		home = home,
		lane = lane,
		side = side,
		state = "in",
		model = boatModel(npc.id, start),
		rig = nil,
		rel = CFrame.identity,
		path = nil,
		t0 = 0,
		dur = 1,
		done = nil,
		gone = false,
	}
	fleet[slot] = b
	b.model:SetAttribute("Giver", npc.id)
	b.model:SetAttribute("QuestIsland", i)
	run(b, IN_TIME, function(a: number): CFrame
		if a < 0.85 then
			local u = a / 0.85
			return start:Lerp(lane, 1 - (1 - u) * (1 - u))
		end
		return lane:Lerp(home, ease((a - 0.85) / 0.15))
	end, function()
		b.state = "moored"
		setRig(b, "Moored", true)
	end)
	task.spawn(function()
		local at = b.model:GetPivot() * CFrame.new(FEET)
		local rig = NpcFactory.spawn(
			npc.role,
			{ name = npc.id, pose = "Idle", seed = npc.seed, cframe = at }
		)
		if b.gone then
			rig:Destroy()
			return
		end
		b.rel = at:ToObjectSpace(rig:GetPivot())
		rig:SetAttribute("QuestIsland", i)
		rig.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the menu's Quests panel lists them from afar
		rig:SetAttribute("Moored", b.state == "moored" or nil)
		rig:SetAttribute("Leaving", b.state == "out" or nil)
		b.rig = rig
		rig.Parent = npcFolder
		place(b, b.model:GetPivot())
	end)
	return b
end

-- Untie, turn round and sail out to sea; the boat and its giver are removed out there.
function QuestPontoons.Leave(b: Boat)
	if b.state == "out" or b.gone then
		return
	end
	local from = b.model:GetPivot()
	b.state = "out"
	setRig(b, "Moored", nil)
	setRig(b, "Leaving", true)
	local lane = b.lane
	local turned = lane * CFrame.Angles(0, math.pi, 0)
	run(b, OUT_TIME, function(a: number): CFrame
		if a < 0.12 then
			return from:Lerp(lane, ease(a / 0.12))
		elseif a < 0.3 then
			return lane * CFrame.Angles(0, math.pi * ease((a - 0.12) / 0.18), 0)
		end
		local u = (a - 0.3) / 0.7
		return turned * CFrame.new(0, 0, -OUT * u * u)
	end, function()
		destroy(b)
	end)
end

-- Dev: an arriving boat ties up now.
function QuestPontoons.Snap(b: Boat)
	local done = b.done
	if b.state == "in" and done then
		b.path, b.done = nil, nil
		place(b, b.home)
		done()
	end
end

-- The quest tablet of island i stands only while its owner has quests open (QuestService.sail).
function QuestPontoons.ShowTablet(i: number, on: boolean)
	local t, m = stands[i], Workspace:FindFirstChild("QuestPontoons")
	local isl = m and m:FindFirstChild(`Island{i}`)
	if t and isl then
		t.Parent = if on then isl else nil
	end
end

-- Every boat at island i gone at once (its owner left or a new one claimed it).
function QuestPontoons.Clear(i: number)
	for _, b in QuestPontoons.Boats(i) do
		destroy(b)
	end
end

function QuestPontoons.Build(npcs: Instance)
	npcFolder = npcs
	boatFolder = Instance.new("Folder")
	boatFolder.Name = "QuestBoats"
	boatFolder.Parent = Workspace
	local folder = Instance.new("Folder")
	folder.Name = "QuestPontoons"
	for i, isl in RingLayout.Islands do
		buildIsland(i, isl, folder)
	end
	folder.Parent = Workspace
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, fleet in fleets do
			for _, b in fleet do
				local path = b.path
				if path then
					local a = math.min((now - b.t0) / b.dur, 1)
					place(b, path(a))
					if a >= 1 then
						local done = b.done
						b.path, b.done = nil, nil
						if done then
							done()
						end
					end
				end
			end
		end
	end)
end

return QuestPontoons
