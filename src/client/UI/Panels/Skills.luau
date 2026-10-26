--!strict
-- Skills panel (docs/24 G, G-a): the player + crew skill tree on Kit/TreeView. Lanes are the
-- SkillRules branches; a node is bought with Cash through Skill_Buy, and the server's Skill_State
-- snapshot (or the PlayerDataChanged snapshot's `skills`) refreshes the states. The green Cash
-- counter rides on the title bar so the cost and the purse read together.
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
	Builder = { icon = "build", color = "orange" },
	Gatherer = { icon = "cash", color = "yellow" },
	Rescuer = { icon = "lifebuoy", color = "green" },
	Mechanic = { icon = "boost", color = "purple" },
	Medic = { icon = "lifebuoy", color = "pink" },
	Crew = { icon = "crew", color = "teal" },
}

local GROUPS: { TreeView.Group } = {}
for _, branch in SkillRules.BRANCHES do
	local look = GROUP_LOOK[branch] or { icon = "boost", color = "blue" }
	table.insert(GROUPS, { id = branch, name = branch, icon = look.icon, color = look.color })
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
	local cash = 0

	local tree = TreeView.new(panel.body, {
		nodes = {},
		groups = GROUPS,
		cash = cash,
		onBuy = function(id: string)
			task.spawn(function()
				pcall(function()
					Net.func("Skill_Buy"):InvokeServer(id)
				end)
			end)
		end,
	})
	tree.root.Size = UDim2.new(1, -8, 1, -16)

	local counter = Counter.new(panel.root, { kind = "cash", value = cash })
	counter.root.Name = "SkillsCash"
	counter.root.AnchorPoint = Vector2.new(1, 0.5)
	counter.root.Position = UDim2.new(1, -(Theme.Size.close + 10), 0, Theme.Size.titleBar * 0.5)
	counter.root.ZIndex = 6

	local function nodes(): { TreeView.Node }
		local out: { TreeView.Node } = {}
		for _, n in SkillRules.NODES do
			local state: "owned" | "buyable" | "locked"
			if owned[n.id] then
				state = "owned"
			else
				local ready = true
				for _, need in n.needs do
					if not owned[need] then
						ready = false
						break
					end
				end
				state = if ready then "buyable" else "locked"
			end
			table.insert(out, {
				id = n.id,
				name = n.name,
				icon = n.icon,
				price = n.cash,
				needs = n.needs,
				col = n.col,
				row = n.row,
				group = n.branch,
				effect = effectText(n.effect.kind, n.effect.amount),
				state = state,
			})
		end
		return out
	end

	local function apply(skills: any, purse: any)
		if type(purse) == "number" then
			cash = purse
			counter.set(cash)
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
			tree.setNodes(nodes(), cash)
		end
	end

	Net.event("Skill_State").OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" then
			apply(payload.owned, payload.cash)
		end
	end)
	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" and type(data.skills) == "table" then
			apply(data.skills, data.cash)
		end
	end)
	task.spawn(function() -- the first push may have landed before this panel was built
		local remote = Net.init():WaitForChild("Progression_GetData", 10)
		if remote and remote:IsA("RemoteFunction") then
			local ok, data = pcall(function()
				return remote:InvokeServer()
			end)
			if ok and type(data) == "table" then
				apply(data.skills, data.cash)
			end
		end
	end)

	apply(nil, nil)

	return {
		open = function()
			panel.open()
			tree.setNodes(nodes(), cash)
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Skills
