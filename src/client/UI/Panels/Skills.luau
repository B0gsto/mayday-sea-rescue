--!strict
-- Skills panel (docs/25 F, J): the full-screen radial tree, its Medal wallet, buying through Skill_Buy
-- and the state snapshot (Skill_State / PlayerDataChanged / Progression_GetData). The tree shows only
-- the nodes you own or can unlock next (SkillRules.visible). Tapping a node shrinks the tree into a
-- corner, shows its card and moves the camera to your rarest survivor of its category (Any: of any
-- type); Captain nodes leave the camera alone (owner 2026-10-28: you don't zoom into yourself).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local SkillRules = require(Shared:WaitForChild("SkillRules"))

local Client = script.Parent.Parent.Parent
local Controllers = Client:WaitForChild("Controllers")
local AudioController = require(Controllers:WaitForChild("AudioController"))
local CameraController = require(Controllers:WaitForChild("CameraController"))
local SkillTreeView =
	require(script.Parent.Parent:WaitForChild("Kit"):WaitForChild("SkillTreeView"))

local player = Players.LocalPlayer
local Skills = {}

local FOCUS_DISTANCE = 8
local FOCUS_HEIGHT = 3.2
local FOCUS_FOV = 50
local FOCUS_TIME = 0.5

local function pct(amount: number): string
	return `{math.floor(amount * 100 + 0.5)}%`
end

-- 1-3 words on the detail card, the same for the tree and the board.
local function effectText(kind: string, amount: number): string
	if kind == "speedMult" then
		return `+{pct(amount)} speed`
	elseif kind == "grip" then
		return `+{pct(amount)} grip`
	elseif kind == "reach" then
		return `+{math.floor(amount)} reach`
	elseif kind == "boatScale" then
		return `-{pct(amount)} call wait`
	elseif kind == "payBonus" then
		return `+{pct(amount)} pay`
	elseif kind == "swimMult" then
		return `+{pct(amount)} swim`
	elseif kind == "buildRate" then
		return `+{pct(amount)} build`
	elseif kind == "extraBuilders" then
		return `+{math.floor(amount)} builders`
	elseif kind == "baseCrew" then
		return `+{math.floor(amount)} crew`
	elseif kind == "gatherMult" then
		return `+{pct(amount)} fish pay`
	elseif kind == "offlineRate" then
		return `+{pct(amount)} offline`
	elseif kind == "tripScale" then
		return `-{pct(amount)} trip time`
	elseif kind == "recruitChance" then
		return `+{pct(amount)} recruits`
	elseif kind == "tripPayMult" then
		return `+{pct(amount)} trip pay`
	elseif kind == "speedCapAdd" then
		return `+{pct(amount)} speed cap`
	elseif kind == "boatCapAdd" then
		return `+{pct(amount)} call cap`
	elseif kind == "medicCapAdd" then
		return `+{pct(amount)} pay cap`
	elseif kind == "medicPerUnit" then
		return `+{pct(amount)} per Medic`
	elseif kind == "workerCapAdd" then
		return `+{math.floor(amount)} worker cap`
	elseif kind == "rareChanceAdd" then
		return `+{pct(amount)} rare finds`
	elseif kind == "extraSlots" then
		return `+{math.floor(amount)} slot`
	elseif kind == "nitro" then
		return "Nitro burst"
	elseif kind == "goldenEye" then
		return "Epic+ from afar"
	elseif kind == "boatSeats" or kind == "craftSeats" then
		return `+{math.floor(amount)} seats`
	elseif kind == "traitReroll" then
		return "Best of two"
	elseif kind == "mentor" then
		return "Mentor a Common"
	elseif kind == "goldenCalls" then
		return `Golden calls x{math.floor(amount)}`
	elseif kind == "salvage" then
		return "Salvage crates"
	elseif kind == "arrivalPay" then
		return "Arrivals pay"
	elseif kind == "foreman" then
		return "Crew build bonus"
	elseif kind == "offlineCapAdd" then
		return `+{math.floor(amount / 3600)} h offline`
	elseif kind == "teamSpirit" then
		return `+{pct(amount)} team`
	elseif kind == "doubleBuild" then
		return "Two sites"
	elseif kind == "depotRefill" then
		return `+{pct(amount)} Depot`
	elseif kind == "buildersCarry" then
		return `Carry {math.floor(amount)}`
	elseif kind == "rarityUp" then
		return "Rarity up"
	elseif kind == "pilots" then
		return "Air patrol"
	elseif kind == "stormRider" then
		return "Storm Rider"
	elseif kind == "celebrity" then
		return "Celebrity visits"
	elseif kind == "lumberjacks" then
		return "Lumberjacks"
	elseif kind == "miners" then
		return "Miners"
	end
	return kind
end

-- The rarest shown survivor of a category, then its live rig on this client or its published footing.
local function workerPoint(category: string?): Vector3?
	local root = ReplicatedStorage:FindFirstChild("Workers")
	local folder = root and root:FindFirstChild(tostring(player.UserId))
	if not folder then
		return nil
	end
	local best: Configuration? = nil
	local bestRarity = 0
	for _, child in folder:GetChildren() do
		if child:IsA("Configuration") then
			local cat = child:GetAttribute("WorkerCategory") or child:GetAttribute("Category")
			local rarity = tonumber(
				child:GetAttribute("WorkerRarity") or child:GetAttribute("Rarity")
			) or 0
			if (category == nil or cat == category) and rarity > bestRarity then
				best, bestRarity = child, rarity
			end
		end
	end
	if not best then
		return nil
	end
	local name = best:GetAttribute("WorkerName")
	local cat = best:GetAttribute("WorkerCategory") or best:GetAttribute("Category")
	local rarity = best:GetAttribute("WorkerRarity") or best:GetAttribute("Rarity")
	local localRoot = Workspace:FindFirstChild("WorkersLocal")
	if localRoot then
		for _, child in localRoot:GetChildren() do
			if
				child:IsA("Model")
				and child:GetAttribute("WorkerName") == name
				and child:GetAttribute("WorkerCategory") == cat
				and child:GetAttribute("WorkerRarity") == rarity
			then
				local torso = child:FindFirstChild("HumanoidRootPart")
				if torso and torso:IsA("BasePart") then
					return torso.Position + Vector3.new(0, 0.4, 0)
				end
				return child:GetPivot().Position
			end
		end
	end
	local spot = best:GetAttribute("Spot")
	if typeof(spot) == "CFrame" then
		return spot.Position + Vector3.new(0, 2.6, 0)
	end
	return nil
end

local function focusPoint(kind: string): Vector3?
	if kind == "Captain" then
		return nil
	end
	return workerPoint(if kind == "Any" then nil else kind)
end

function Skills.new(canvas: Frame, onClose: () -> ())
	local owned: { [string]: boolean } = {}
	local medals = 0
	local newest: string? = nil
	local view: SkillTreeView.View
	local close: () -> ()
	local focus: { from: CFrame, to: CFrame, fromFov: number, toFov: number, t: number }? = nil
	local focusing = false

	local function endFocus()
		focus = nil
		if focusing then
			focusing = false
			CameraController.ClearOverride()
		end
	end

	local function startFocus(at: Vector3): boolean
		local camera = Workspace.CurrentCamera
		if not camera then
			return false
		end
		local flat = camera.CFrame.LookVector
		flat = Vector3.new(flat.X, 0, flat.Z)
		if flat.Magnitude < 1e-3 then
			flat = Vector3.new(0, 0, -1)
		end
		flat = flat.Unit
		local eye = at - flat * FOCUS_DISTANCE + Vector3.new(0, FOCUS_HEIGHT, 0)
		focus = {
			from = camera.CFrame,
			to = CFrame.lookAt(eye, at + Vector3.new(0, 0.4, 0)),
			fromFov = camera.FieldOfView,
			toFov = FOCUS_FOV,
			t = 0,
		}
		focusing = true
		CameraController.SetOverride(camera.CFrame, camera.FieldOfView)
		return true
	end

	RunService.RenderStepped:Connect(function(dt: number)
		local f = focus
		if not f then
			return
		end
		f.t = math.min(1, f.t + dt / FOCUS_TIME)
		local k = f.t * f.t * (3 - 2 * f.t)
		CameraController.SetOverride(f.from:Lerp(f.to, k), f.fromFov + (f.toFov - f.fromFov) * k)
		if f.t >= 1 then
			focus = nil
		end
	end)

	local function nodeList(): { SkillTreeView.Node }
		local out: { SkillTreeView.Node } = {}
		local shown = SkillRules.visible(owned)
		for _, n in SkillRules.nodes() do
			if not shown[n.id] then
				continue
			end
			table.insert(out, {
				id = n.id,
				name = n.name,
				icon = n.icon,
				effect = effectText(n.effect.kind, n.effect.amount),
				price = n.medals,
				ring = n.ring,
				angle = n.angle,
				sector = n.sector,
				keystone = n.keystone,
				state = if owned[n.id] then "owned" else "buyable",
				focus = n.focus,
				needs = n.needs,
			})
		end
		return out
	end

	local function newestId(): string?
		if newest and owned[newest] then
			return newest
		end
		local best: string? = nil
		local ring = -1
		for _, n in SkillRules.nodes() do
			if owned[n.id] and n.ring > ring then
				best, ring = n.id, n.ring
			end
		end
		return best
	end

	local function chime()
		AudioController.play("UI_Click", nil, 2.5, 0.7) -- the node locks in
		for i = 1, 3 do
			task.delay((i - 1) * 0.06, function()
				AudioController.play("UI_Step", nil, 0.7, 1 + (i - 1) * 0.14)
			end)
		end
	end

	view = SkillTreeView.new(canvas, {
		nodes = {},
		medals = 0,
		onBuy = function(id: string, done: SkillTreeView.Done)
			task.spawn(function()
				local ok, bought = pcall(function()
					return Net.func("Skill_Buy"):InvokeServer(id)
				end)
				local won = ok and bought == true
				if won then
					newest = id
					chime()
				end
				done(won)
			end)
		end,
		onSelect = function(n: SkillTreeView.Node)
			local kind = n.focus
			local at = kind and focusPoint(kind)
			if not (at and startFocus(at)) then
				endFocus()
			end
		end,
		onEndFocus = endFocus,
		onReset = function()
			task.spawn(pcall, function()
				return Net.func("Skill_Reset"):InvokeServer() -- Skill_State brings the refunded tree back
			end)
		end,
		onClose = function()
			close()
		end,
	})

	close = function()
		endFocus()
		view.close()
		onClose()
	end

	local function sameOwned(a: { [string]: boolean }, b: { [string]: boolean }): boolean
		for id in a do
			if not b[id] then
				return false
			end
		end
		for id in b do
			if not a[id] then
				return false
			end
		end
		return true
	end

	local function apply(skills: any, purse: any)
		local changed = false
		if type(purse) == "number" and purse ~= medals then
			medals = purse
			changed = true
		end
		if type(skills) == "table" then
			local nextOwned: { [string]: boolean } = {}
			for id, on in skills do
				if on == true and SkillRules.byId[id] then
					nextOwned[id] = true
				end
			end
			if not sameOwned(owned, nextOwned) then
				owned = nextOwned
				changed = true
			end
		end
		if changed and view.isOpen() then
			view.setNodes(nodeList(), medals)
		end
	end

	Net.event("Skill_State").OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" then
			apply(payload.owned, payload.medals)
		end
	end)
	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" and type(data.skills) == "table" then
			apply(data.skills, data.medals)
		end
	end)
	task.spawn(function() -- the first push may have landed before this panel was built
		local remote = Net.init():WaitForChild("Progression_GetData", 10)
		if remote and remote:IsA("RemoteFunction") then
			local ok, data = pcall(function()
				return remote:InvokeServer()
			end)
			if ok and type(data) == "table" then
				apply(data.skills, data.medals)
			end
		end
	end)

	return {
		open = function()
			endFocus()
			view.root.Visible = true
			view.setNodes(nodeList(), medals)
			view.openAt(newestId())
		end,
		close = close,
		isOpen = view.isOpen,
		root = view.root,
	}
end

return Skills
