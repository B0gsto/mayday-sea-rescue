--!strict
-- SurvivorController (docs/25 J + K1): a name tag on every survivor, and an info card on click/tap.
--   - water: every Workspace.CallProps model with Survivor = true once it is a person (a CasualtyRig,
--     Rigged, or K1 attributes); Wildlife is skipped. The invisible root carries the info prompt.
--   - home: WorkerController calls SurvivorController.attach(rig) for every worker it draws.
-- One tag per survivor. ClickDetector for mouse/touch (person cursor), ProximityPrompt for
-- keyboard/gamepad on Q / Y, clear of the Pull aboard prompt's E / X. The card is info only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))
local SurvivorCard = require(UI:WaitForChild("SurvivorCard"))
local SurvivorTag = require(UI:WaitForChild("SurvivorTag"))

local SurvivorController = {}

local player = Players.LocalPlayer

local CLICK = "SurvivorInfoClick"
local PROMPT = "SurvivorInfoPrompt"
local CLOSE_DISTANCE = 40 -- studs from the survivor that close their card

local card: SurvivorCard.Card? = nil
local shown: Model? = nil
local attached: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Model]: { RBXScriptConnection } } = setmetatable({}, { __mode = "k" }) :: any
local hooked: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function inWater(model: Model): boolean
	local parent = model.Parent
	return parent ~= nil and parent.Name == "CallProps"
end

local function open(model: Model)
	if not card then
		return
	end
	shown = model
	card.open(SurvivorTag.info(model), inWater(model))
	task.spawn(function() -- walking or sailing away closes it
		while shown == model and card and card.isOpen() do
			task.wait(0.5)
			local char = player.Character
			local me = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				shown == model
				and me
				and (me.Position - model:GetPivot().Position).Magnitude > CLOSE_DISTANCE
			then
				shown = nil
				card.close()
			end
		end
	end)
	if not hooked[model] then
		hooked[model] = true
		model.Destroying:Once(function()
			if shown == model then
				shown = nil
				if card then
					card.close()
				end
			end
			hooked[model] = nil
		end)
	end
end

local function click(part: BasePart, model: Model)
	if part:FindFirstChild(CLICK) then
		return
	end
	local detector = Instance.new("ClickDetector")
	detector.Name = CLICK
	detector.MaxActivationDistance = 20
	-- default pointing hand: a CursorIcon draws at the image's native size (the 256 px crew button was a huge square)
	detector.Parent = part
	detector.MouseClick:Connect(function(who: Player)
		if who == player then
			open(model)
		end
	end)
end

-- Tag, mouse/touch detectors on the root and the visible body, and the info prompt on the root.
function SurvivorController.attach(model: Model)
	if attached[model] then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local rootPart: BasePart? = if root and root:IsA("BasePart") then root else nil
	local parts: { BasePart } = {}
	if rootPart then
		table.insert(parts, rootPart)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and not d:GetAttribute("WorkProp") then
			table.insert(parts, d)
		end
	end
	if not rootPart then
		rootPart = parts[1]
	end
	if not rootPart then
		return -- the body has not streamed in yet: the CallProps watcher tries again on ChildAdded
	end
	attached[model] = true
	SurvivorTag.attach(model, inWater(model))
	for i = 1, math.min(#parts, 40) do
		click(parts[i], model)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT
	prompt.ActionText = "Info" -- no ObjectText: the name tag over the head already says who (owner 2026-10-29)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.Q
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton -- the nearest one only, still beside E / X
	prompt.Parent = rootPart
	prompt.Triggered:Connect(function(who: Player)
		if who == player then
			open(model)
		end
	end)
end

local function personish(model: Model): boolean
	if model:GetAttribute("Wildlife") ~= nil then
		return false
	end
	if model:FindFirstChild("CasualtyRig") or model:GetAttribute("Rigged") == true then
		return true
	end
	for _, key in { "SurvivorName", "WorkerName", "Category", "WorkerCategory" } do
		if model:GetAttribute(key) ~= nil then
			return true
		end
	end
	return false
end

local function stopWatch(model: Model)
	local conns = watched[model]
	if not conns then
		return
	end
	watched[model] = nil
	for _, c in conns do
		c:Disconnect()
	end
end

-- WildlifeRescue dresses the same Victim model as an animal a beat after spawn (SanctuaryService), so a
-- tag drawn for the person it started as is taken back down.
local function detach(model: Model)
	attached[model] = nil
	SurvivorTag.remove(model)
	for _, d in model:GetDescendants() do
		if d.Name == PROMPT or (d:IsA("ClickDetector") and d.Name == CLICK) then
			d:Destroy()
		end
	end
	if shown == model then
		shown = nil
		if card then
			card.close()
		end
	end
end

-- A CallProps survivor can stream in before its rig or its roll lands: wait for either, then attach.
local function watch(inst: Instance)
	if not inst:IsA("Model") or watched[inst] then
		return
	end
	local model = inst
	if model:GetAttribute("Survivor") ~= true then
		return
	end
	local conns: { RBXScriptConnection } = {}
	local function try()
		if model.Parent == nil then
			stopWatch(model)
			return
		end
		if model:GetAttribute("Wildlife") ~= nil then
			detach(model)
			stopWatch(model)
			return
		end
		if personish(model) then
			SurvivorController.attach(model)
		end
	end
	table.insert(conns, model.ChildAdded:Connect(try))
	for _, key in
		{ "Wildlife", "Rigged", "SurvivorName", "WorkerName", "Category", "WorkerCategory" }
	do
		table.insert(conns, model:GetAttributeChangedSignal(key):Connect(try))
	end
	table.insert(
		conns,
		model.Destroying:Connect(function()
			stopWatch(model)
		end)
	)
	watched[model] = conns
	try()
end

function SurvivorController.Init()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivorCards"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 35 -- over the HUD (and menu), under the onboarding and the map
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	card = SurvivorCard.new(Style.canvas(gui))
end

function SurvivorController.Start()
	local folder = Workspace:WaitForChild("CallProps", 60)
	if not folder then
		return
	end
	folder.ChildAdded:Connect(watch)
	for _, inst in folder:GetChildren() do
		watch(inst)
	end
end

return SurvivorController
