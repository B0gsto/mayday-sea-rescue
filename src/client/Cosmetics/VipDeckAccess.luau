--!strict
-- VipDeckAccess (RP-M5 E2, a CosmeticsController feature): the ladder prompts of the VIP roof deck
-- (src/server/World/VipDeck.luau). Owners of the VIP Crew Card ("Pass_VipCrewCard") get a local
-- ProximityPrompt "Climb to the roof deck" at the ladder foot; everyone on the deck gets "Climb
-- down" at its head. Non-owners only see the enamel sign: no prompt, no purchase dialog.
-- Prompts are ProximityPrompts, so keyboard (E), gamepad (X) and touch all work.
local CollectionService = game:GetService("CollectionService")

local VipDeckAccess = {}

local TAG = "VipDeckLadder"

function VipDeckAccess.Start(ctx: any)
	local prompts: { [BasePart]: ProximityPrompt } = {}

	local function sync(anchor: BasePart)
		local which = anchor:GetAttribute("VipDeck")
		local want = which == "Head" or (which == "Foot" and ctx.owns("VipCrewCard"))
		local prompt = prompts[anchor]
		if want and not prompt then
			local p = Instance.new("ProximityPrompt")
			p.Name = "VipDeckPrompt"
			p.ActionText = if which == "Foot" then "Climb to the roof deck" else "Climb down"
			p.ObjectText = if which == "Foot" then "VIP Crew Card" else "Roof deck"
			p.KeyboardKeyCode = Enum.KeyCode.E
			p.GamepadKeyCode = Enum.KeyCode.ButtonX
			p.HoldDuration = 0.4
			p.MaxActivationDistance = 9
			p.RequiresLineOfSight = false
			p.Triggered:Connect(function()
				ctx.fire("VipDeck", if which == "Foot" then "Up" else "Down")
			end)
			p.Parent = anchor
			prompts[anchor] = p
		elseif not want and prompt then
			prompt:Destroy()
			prompts[anchor] = nil
		end
	end

	local function add(inst: Instance)
		if inst:IsA("BasePart") then
			sync(inst)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		if inst:IsA("BasePart") then
			prompts[inst] = nil
		end
	end)
	for _, inst in CollectionService:GetTagged(TAG) do
		add(inst)
	end
	ctx.player:GetAttributeChangedSignal("Pass_VipCrewCard"):Connect(function()
		for anchor in prompts do
			sync(anchor)
		end
		for _, inst in CollectionService:GetTagged(TAG) do
			add(inst)
		end
	end)
end

return VipDeckAccess
