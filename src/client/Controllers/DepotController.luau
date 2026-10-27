--!strict
-- DepotController (docs/25 D, K4): the Depot's life on the islands near you, client-side only, read from the plot's
-- K4 attributes: the supply barge (ReplicatedStorage.DepotTemplates.Barge) sails in to ATT_BargeMoor at BargeNext,
-- stays 20 s while its crates go and leaves (shared/BargePath); the pile's Stack_1..4 show DepotStock / DepotCap in
-- quarters; an empty-crate icon hangs over the pile while SiteWaiting. Until the server publishes them the Depot
-- reads full and the barge comes every BARGE_PERIOD s. Islands past NEAR get no barge and no per-frame work.
-- WorkerController walks the Haulers and Builders on the marks (DepotController.mark / .moored).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BargePath = require(Shared:WaitForChild("BargePath"))

local DepotController = {}

local NEAR, FAR = 420, 480 -- studs from you to the Depot: barge made within NEAR, dropped past FAR
local rules = Shared:FindFirstChild("DepotRules") -- K4 (lands with the server's Depot)
local PERIOD = if rules then tonumber(((require :: any)(rules)).BARGE_PERIOD) or 60 else 60
local RED = Color3.fromRGB(224, 56, 40)
local WHITE = Color3.fromRGB(242, 240, 232)

type Island = {
	plot: Model,
	depot: Model?,
	barge: Model?,
	crates: { BasePart },
	icon: BillboardGui?,
}
local islands: { [Model]: Island } = {}

local function eye(): Vector3
	local root = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

-- The plot's standing Depot when it is the uploaded model (it carries the marks), else nil.
function DepotController.depot(plot: Model): Model?
	local d = plot:FindFirstChild("Depot")
	return if d and d:IsA("Model") and d:FindFirstChild("DepotMesh") then d else nil
end

-- A mark's world CFrame (ATT_PickUp_Lv1, ATT_DropOff_Lv2, ATT_BargeMoor, ATT_QuayLoad, ATT_QuayLand, ...).
function DepotController.mark(depot: Model, name: string): CFrame?
	local a = depot:FindFirstChild(name, true)
	return if a and a:IsA("Attachment") then a.WorldCFrame else nil
end

-- Every mark whose name starts with `prefix` (the bays: ATT_PickUp_, ATT_DropOff_), in name order.
function DepotController.marks(depot: Model, prefix: string): { CFrame }
	local found = {}
	for _, a in depot:GetDescendants() do
		if a:IsA("Attachment") and string.sub(a.Name, 1, #prefix) == prefix then
			table.insert(found, a)
		end
	end
	table.sort(found, function(x, y)
		return x.Name < y.Name
	end)
	local out = {}
	for _, a in found do
		table.insert(out, (a :: Attachment).WorldCFrame)
	end
	return out
end

-- The plot of the island whose owner has this UserId (Workspace.Marina.Plot<DockPlot>).
function DepotController.plotOf(userId: number): Model?
	local owner = Players:GetPlayerByUserId(userId)
	local i = owner and owner:GetAttribute("DockPlot")
	local marina = Workspace:FindFirstChild("Marina")
	local plot = marina and type(i) == "number" and marina:FindFirstChild(`Plot{i}`)
	return if plot and plot:IsA("Model") then plot else nil
end

local function nextAt(plot: Model): number
	local n = plot:GetAttribute("BargeNext")
	return if type(n) == "number"
		then n
		else BargePath.fallbackNext(Workspace:GetServerTimeNow(), PERIOD)
end

-- True while the barge lies at the quay (Haulers load then).
function DepotController.moored(plot: Model): boolean
	return BargePath.moored(Workspace:GetServerTimeNow(), nextAt(plot), PERIOD)
end

-- Stack_1..4 (of every bay) show the stock in quarters; any stock shows one.
local function showStock(isl: Island)
	local depot = isl.depot
	if not depot then
		return
	end
	local stock, cap = isl.plot:GetAttribute("DepotStock"), isl.plot:GetAttribute("DepotCap")
	local shown = 4
	if type(stock) == "number" and type(cap) == "number" and cap > 0 then
		shown = math.clamp(math.ceil(4 * stock / cap - 1e-6), 0, 4)
	end
	for _, d in depot:GetDescendants() do
		local k = tonumber(string.match(d.Name, "_Stack_(%d)$"))
		if k and d:IsA("BasePart") then
			d.LocalTransparencyModifier = if k > shown then 1 else 0
		end
	end
end

-- An open, empty crate on a red disc over the pile: builders are waiting on bricks.
local function showWaiting(isl: Island)
	local want = isl.depot ~= nil and isl.plot:GetAttribute("SiteWaiting") == true
	if want and not isl.icon then
		local pile = (isl.depot :: Model):FindFirstChild("Lv1_Stack_2", true)
		if not (pile and pile:IsA("BasePart")) then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "DepotEmpty"
		gui.Adornee = pile
		gui.Size = UDim2.fromScale(4, 4) -- studs
		gui.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
		gui.MaxDistance = 160
		gui.LightInfluence = 0
		local disc = Instance.new("Frame")
		disc.Size = UDim2.fromScale(1, 1)
		disc.BackgroundColor3 = RED
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = disc
		local ring = Instance.new("UIStroke")
		ring.Color, ring.Thickness = WHITE, 3
		ring.Parent = disc
		disc.Parent = gui
		local box = Instance.new("Frame") -- the crate: an outline, nothing in it
		box.AnchorPoint = Vector2.new(0.5, 0)
		box.Position = UDim2.fromScale(0.5, 0.42)
		box.Size = UDim2.fromScale(0.5, 0.34)
		box.BackgroundTransparency = 1
		local edge = Instance.new("UIStroke")
		edge.Color, edge.Thickness = WHITE, 4
		edge.Parent = box
		box.Parent = disc
		local lid = Instance.new("Frame") -- tipped open
		lid.AnchorPoint = Vector2.new(0.5, 0.5)
		lid.Position = UDim2.fromScale(0.42, 0.3)
		lid.Size = UDim2.fromScale(0.5, 0.07)
		lid.Rotation = -28
		lid.BackgroundColor3 = WHITE
		lid.BorderSizePixel = 0
		lid.Parent = disc
		gui.Parent = pile
		isl.icon = gui
	elseif not want and isl.icon then
		isl.icon:Destroy()
		isl.icon = nil
	end
end

local function dropBarge(isl: Island)
	if isl.barge then
		isl.barge:Destroy()
	end
	isl.barge, isl.crates = nil, {}
end

local function makeBarge(isl: Island)
	local templates = ReplicatedStorage:FindFirstChild("DepotTemplates")
	local tpl = templates and templates:FindFirstChild("Barge")
	if not (tpl and tpl:IsA("Model")) then
		return
	end
	local barge = tpl:Clone()
	isl.crates = {}
	for _, d in barge:GetDescendants() do
		if d:IsA("BasePart") and string.match(d.Name, "^Crate_%d$") then
			table.insert(isl.crates, d)
		end
	end
	table.sort(isl.crates, function(a, b)
		return a.Name < b.Name
	end)
	barge.Parent = nil -- parented by the frame step when in sight
	isl.barge = barge
end

-- Per frame, near islands only: the barge's place on its path, its crates through the stay.
local function step()
	local now = Workspace:GetServerTimeNow()
	for _, isl in islands do
		local barge, depot = isl.barge, isl.depot
		if not (barge and depot) then
			continue
		end
		local moor = DepotController.mark(depot, "ATT_BargeMoor")
		local nxt = nextAt(isl.plot)
		local at = moor and BargePath.at(now, nxt, PERIOD)
		if not (moor and at) then
			barge.Parent = nil
			continue
		end
		-- the mark faces out to sea along the quay; the barge comes in bow first, so the path's -Z is the other way
		barge:PivotTo(moor * CFrame.Angles(0, math.pi, 0) * at)
		local done = BargePath.unloaded(now, nxt, PERIOD)
		for k, crate in isl.crates do
			crate.LocalTransparencyModifier = if done and done > k / (#isl.crates + 1) then 1 else 0
		end
		if barge.Parent ~= Workspace then
			barge.Parent = Workspace
		end
	end
end

local function watch(plot: Model)
	if islands[plot] then
		return
	end
	local isl: Island = { plot = plot, crates = {} }
	islands[plot] = isl
	for _, name in { "DepotStock", "DepotCap" } do
		plot:GetAttributeChangedSignal(name):Connect(function()
			showStock(isl)
		end)
	end
	plot:GetAttributeChangedSignal("SiteWaiting"):Connect(function()
		showWaiting(isl)
	end)
end

-- Once a second: which Depots are near, a rebuilt Depot (a new level) gets its pile and icon again.
local function pass()
	local marina = Workspace:FindFirstChild("Marina")
	for i = 1, 6 do
		local plot = marina and marina:FindFirstChild(`Plot{i}`)
		if plot and plot:IsA("Model") then
			watch(plot)
		end
	end
	local at = eye()
	for plot, isl in islands do
		if not plot.Parent then
			dropBarge(isl)
			islands[plot] = nil
			continue
		end
		local depot = DepotController.depot(plot)
		if depot ~= isl.depot then
			if isl.icon then
				isl.icon:Destroy()
				isl.icon = nil
			end
			isl.depot = depot
			showStock(isl)
			showWaiting(isl)
		end
		local d = if depot then (depot:GetPivot().Position - at).Magnitude else math.huge
		if isl.barge and d > FAR then
			dropBarge(isl)
		elseif not isl.barge and d < NEAR then
			makeBarge(isl)
		end
	end
end

function DepotController.Start()
	RunService.Heartbeat:Connect(step)
	while true do
		pass()
		task.wait(1)
	end
end

return DepotController
