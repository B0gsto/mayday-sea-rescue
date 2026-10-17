--!strict
-- WorldService: example service (see the convention at the top of src/server/Main.server.luau).
-- Publishes world constants as Workspace attributes so clients and tools can read them.
-- Also, at Start:
--   * hides the authored marker volumes (Workspace.Zones, Map.WorldPoints, PromptAnchor parts): fully
--     transparent, no collide / query / touch / shadow, and strips any adornment or Highlight;
--   * adds the diegetic store prompts on the map's PromptAnchor parts (docs 04 section 1.1, no shop
--     button): "ShopCounter" (Chandlery gear counter) and "BoatDesk" (boatyard collection desk). The
--     prompts carry attribute Panel = anchor id; HudController opens the matching panel on the
--     client's own ProximityPromptService.PromptTriggered (no remote needed).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig")
)

local PROMPTS: { [string]: { action: string, object: string } } = {
	ShopCounter = { action = "Browse gear", object = "Chandlery counter" },
	BoatDesk = { action = "Collect a boat", object = "Boatyard desk" },
}

local WorldService = {}
WorldService.Priority = 10 -- world constants first, before services that read them

function WorldService.Init()
	Workspace:SetAttribute("SeaLevel", GameConfig.SeaLevel)
	Workspace:SetAttribute("MapRadius", GameConfig.MapRadius)
	-- Real gravity at 1 m = 3 studs (docs 02 section 4.2): 9.81 m/s^2 x 3. Owned by stream B (boats).
	-- On foot (tune): walk 12 studs/s = 4 m/s, a brisk jog (a real 1.4 m/s walk is too slow for the
	-- map); jump 3 studs = 1 m, so a dock step or gunwale is a hop (JumpHeight, so Roblox derives the
	-- jump speed from this gravity: sqrt(2 g h) = 13.3 studs/s, 0.9 s in the air).
	Workspace.Gravity = 29.43
	local StarterPlayer = game:GetService("StarterPlayer")
	StarterPlayer.CharacterWalkSpeed = 12
	StarterPlayer.CharacterUseJumpPower = false
	StarterPlayer.CharacterJumpHeight = 3
end

local function isAdornment(inst: Instance): boolean
	return inst:IsA("SelectionBox")
		or inst:IsA("SelectionSphere")
		or inst:IsA("HandleAdornment")
		or inst:IsA("SelectionLasso")
		or inst:IsA("SurfaceSelection")
		or inst:IsA("Highlight")
end

-- Marker volumes are data, never visuals: make them invisible and inert.
local function hideMarker(inst: Instance)
	if inst:IsA("BasePart") then
		inst.Transparency = 1
		inst.CanCollide = false
		inst.CanQuery = false
		inst.CanTouch = false
		inst.CastShadow = false
	elseif isAdornment(inst) then
		inst:Destroy()
	end
end

local function hideMarkers(root: Instance?)
	if not root then
		return
	end
	for _, inst in root:GetDescendants() do
		hideMarker(inst)
	end
	root.DescendantAdded:Connect(function(inst)
		task.defer(hideMarker, inst)
	end)
end

local function addStorePrompts(map: Instance)
	for _, inst in map:GetDescendants() do
		local id = inst:GetAttribute("PromptAnchor")
		local spec = if type(id) == "string" then PROMPTS[id] else nil
		if spec and inst:IsA("BasePart") and not inst:FindFirstChildOfClass("ProximityPrompt") then
			hideMarker(inst)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = `{id}Prompt`
			prompt.ActionText = spec.action
			prompt.ObjectText = spec.object
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("Panel", id)
			prompt.Parent = inst
		end
	end
end

-- Adds the store prompts under `root` (WorldDressingService calls it after moving a marker onto a Package).
WorldService.addStorePrompts = addStorePrompts

function WorldService.Start()
	hideMarkers(Workspace:FindFirstChild("Zones"))
	local map = Workspace:FindFirstChild("Map")
	if map then
		hideMarkers(map:FindFirstChild("WorldPoints"))
		addStorePrompts(map)
	else
		warn("[WorldService] Workspace.Map missing: no store prompts")
	end
	print(`[WorldService] sea level at Y = {Workspace:GetAttribute("SeaLevel")}`)
end

return WorldService
