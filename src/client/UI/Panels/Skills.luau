--!strict
-- Skills panel (docs/25 F): the radial tree's temporary old-layout view on Kit/TreeView until the
-- full-screen radial view lands. Lanes are SkillRules' sectors; a node is bought with Medals through
-- Skill_Buy, and the server's Skill_State snapshot (or PlayerDataChanged's `skills`) refreshes the
-- states. The Medal counter rides on the title bar so the cost and the purse read together.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local SkillRules = require(Shared:WaitForChild("SkillRules"))

local Kit = script.Parent.Parent:WaitForChild("Kit")
local Counter = require(Kit:WaitForChild("Counter"))
local Panel = require(Kit:WaitForChild("Panel"))
local Theme = require(Kit:WaitForChild("Theme"))
local TreeView = require(Kit:WaitForChild("TreeView"))

local Skills = {}

local GROUP_LOOK: { [string]: { icon: string, color: string } } = {
	Captain = { icon = "boat_to_me", color = "blue" },
	Rescue = { icon = "lifebuoy", color = "green" },
	Crew = { icon = "crew", color = "teal" },
	Industry = { icon = "build", color = "orange" },
	Bridge = { icon = "lock", color = "locked" },
}

local GROUPS: { TreeView.Group } = {}
for _, sector in SkillRules.SECTORS do
	local look = GROUP_LOOK[sector] or { icon = "boost", color = "blue" }
	table.insert(GROUPS, { id = sector, name = sector, icon = look.icon, color = look.color })
end

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
	elseif kind == "boatSeats" then
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

function Skills.new(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Skills",
		icon = "boost",
		size = Vector2.new(1080, 620),
		wide = true,
		onClose = onClose,
	})
	panel.body.ScrollingEnabled = false
	panel.body.AutomaticCanvasSize = Enum.AutomaticSize.None
	panel.body.CanvasSize = UDim2.new()
	panel.body.ScrollBarThickness = 0

	local owned: { [string]: boolean } = {}
	local medals = 0

	local tree = TreeView.new(panel.body, {
		nodes = {},
		groups = GROUPS,
		cash = medals,
		onBuy = function(id: string)
			task.spawn(function()
				pcall(function()
					Net.func("Skill_Buy"):InvokeServer(id)
				end)
			end)
		end,
	})
	tree.root.Size = UDim2.new(1, -8, 1, -16)

	local counter = Counter.new(panel.root, { kind = "medal", value = medals })
	counter.root.Name = "SkillsMedals"
	counter.root.AnchorPoint = Vector2.new(1, 0.5)
	counter.root.Position = UDim2.new(1, -(Theme.Size.close + 10), 0, Theme.Size.titleBar * 0.5)
	counter.root.ZIndex = 6

	local function nodes(): { TreeView.Node }
		local out: { TreeView.Node } = {}
		for _, n in SkillRules.nodes() do
			local state: "owned" | "buyable" | "locked"
			if owned[n.id] then
				state = "owned"
			else
				local ready = #n.needs == 0
				for _, need in n.needs do
					if owned[need] then
						ready = true
						break
					end
				end
				state = if ready and not n.soon then "buyable" else "locked"
			end
			table.insert(out, {
				id = n.id,
				name = n.name,
				icon = n.icon,
				price = n.medals,
				needs = n.needs,
				col = n.ring,
				row = n.angle / 36,
				group = n.sector,
				effect = effectText(n.effect.kind, n.effect.amount),
				state = state,
			})
		end
		return out
	end

	local function apply(skills: any, purse: any)
		if type(purse) == "number" then
			medals = purse
			counter.set(medals)
		end
		if type(skills) == "table" then
			owned = {}
			for id, on in skills do
				if on == true and SkillRules.byId[id] then
					owned[id] = true
				end
			end
		end
		-- rebuild only while visible: PlayerDataChanged arrives on every award
		if panel.isOpen() then
			tree.setNodes(nodes(), medals)
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

	apply(nil, nil)

	return {
		open = function()
			panel.open()
			tree.setNodes(nodes(), medals)
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Skills
