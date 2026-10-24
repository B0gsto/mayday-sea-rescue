--!strict
-- DiscoveryController: the client side of the exploration album and map fog (docs/21 §3). It mirrors
-- DiscoveryService's state, plays the stamp slam / sticker pop (UI/Sticker) when the server grants one,
-- floats the island's stamp over each unstamped stamp post, and hides the collectibles this player has
-- found (Workspace.Discovery props are shared; hiding is local).
-- API for the map fog and the Album app:
--   DiscoveryController.IsRevealed(cellOrIsland) -> boolean   a fog cell index (DiscoveryRules.cellOf) is
--                                                            cleared, or an island id has been sighted
--   DiscoveryController.IsStamped(islandId) -> boolean        the map's "?" becomes the stamp
--   DiscoveryController.CellOf(pos) -> number?                DiscoveryRules.cellOf (grid: DiscoveryConfig.Fog)
--   DiscoveryController.State() -> DiscoveryRules.State       island id -> bit mask (DiscoveryRules.has)
--   DiscoveryController.Changed                               RBXScriptSignal, fires after every update
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Rules = require(Shared:WaitForChild("DiscoveryRules"))
local Sticker = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Sticker"))

local DiscoveryController = {}

local changed = Instance.new("BindableEvent")
DiscoveryController.Changed = changed.Event

local state: Rules.State = {}
local fog = Rules.newFog()
local markers: { [string]: BasePart } = {}

function DiscoveryController.IsRevealed(cellOrIsland: number | string): boolean
	if type(cellOrIsland) == "string" then
		return Rules.has(state, cellOrIsland, Rules.SIGHTED)
	end
	return Rules.revealed(fog, cellOrIsland)
end

function DiscoveryController.IsStamped(islandId: string): boolean
	return Rules.has(state, islandId, 4)
end

DiscoveryController.CellOf = Rules.cellOf

function DiscoveryController.State(): Rules.State
	return state
end

local function bitOf(model: Instance): number?
	local page = Rules.ById[model:GetAttribute("Island") :: any]
	if not page then
		return nil
	end
	for _, s in page.stickers do
		if s.id == model:GetAttribute("Sticker") then
			return s.bit
		end
	end
	return nil
end

local function paintProp(model: Instance)
	local bit = bitOf(model)
	if not bit then
		return
	end
	local found = Rules.has(state, model:GetAttribute("Island") :: string, bit)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if found then 1 else 0
		elseif d:IsA("Sparkles") then
			d.Enabled = not found
		end
	end
end

local function paint()
	local folder = Workspace:FindFirstChild("Discovery")
	for _, m in (if folder then folder:GetChildren() else {}) do
		paintProp(m)
	end
	for id, marker in markers do
		local gui = marker:FindFirstChildOfClass("BillboardGui")
		if gui then
			gui.Enabled = not DiscoveryController.IsStamped(id)
		end
	end
	changed:Fire()
end

local function apply(payload: any)
	if type(payload) ~= "table" then
		return
	end
	state = Rules.decode(payload.isles)
	fog = Rules.decodeFog(payload.fog)
	paint()
end

-- the island's stamp floating over its post, bobbing, until stamped
local function buildMarkers()
	local folder = Instance.new("Folder")
	folder.Name = "DiscoveryMarkers"
	folder.Parent = Workspace
	for _, page in Rules.Pages do
		local p = Instance.new("Part")
		p.Name = page.id
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Position = page.island.stamp + Vector3.new(0, 7, 0)
		p.Parent = folder
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(5, 5)
		gui.MaxDistance = 450
		gui.LightInfluence = 0
		gui.Parent = p
		Sticker.draw(gui, page.id, "Stamp", true)
		markers[page.id] = p
	end
	RunService.RenderStepped:Connect(function()
		local y = math.sin(os.clock() * 2) * 0.6
		for _, p in markers do
			local gui = p:FindFirstChildOfClass("BillboardGui")
			if gui and gui.Enabled then
				gui.StudsOffset = Vector3.new(0, y, 0)
			end
		end
	end)
end

function DiscoveryController.Start()
	local folder = Net.init()
	local stateRemote = folder:WaitForChild("Discovery_State", 30)
	local foundRemote = folder:WaitForChild("Discovery_Found", 30)
	local get = folder:WaitForChild("Discovery_Get", 30)
	if
		not (
			stateRemote
			and stateRemote:IsA("RemoteEvent")
			and foundRemote
			and foundRemote:IsA("RemoteEvent")
			and get
			and get:IsA("RemoteFunction")
		)
	then
		warn("[DiscoveryController] remotes missing")
		return
	end
	buildMarkers()
	stateRemote.OnClientEvent:Connect(apply)
	foundRemote.OnClientEvent:Connect(function(e: any)
		if type(e) == "table" and type(e.island) == "string" and type(e.sticker) == "string" then
			task.spawn(Sticker.slam, e.island, e.sticker, e.page == true)
		end
	end)
	local props = Workspace:WaitForChild("Discovery", 30)
	if props then
		props.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				local model: Instance? = d
				while model and model.Parent ~= props do
					model = model.Parent
				end
				if model then
					paintProp(model)
				end
			end
		end)
	end
	local ok, payload = pcall(function()
		return (get :: RemoteFunction):InvokeServer()
	end)
	if ok then
		apply(payload)
	end
end

return DiscoveryController
