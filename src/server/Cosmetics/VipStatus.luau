--!strict
-- VipStatus (RP-M5 E2, a CosmeticsService feature): the VIP Crew Card's status perks.
-- * Badge slot (src/shared/Config/Cosmetics/Badge.luau): buying the card switches the gold
--   nameplate + radio tag on once (isNewPurchase only); owners switch it off in the picker. The
--   nameplate and the tag are drawn by clients from the "Cos_Badge" attribute.
-- * The roof deck (src/server/World/VipDeck.luau), built on the station shell once WorldDressing
--   has swapped it in (Workspace.Dressing.Station.M_Bld_Station). Cosmetics_Action "VipDeck"
--   ("Up" | "Down"): owners within reach of the ladder foot are moved onto the deck, anyone on the
--   deck down to the foot. A sweep every 2 s returns non-owners found on the deck to the foot.
--   Non-owners only see the sign; no prompt or purchase dialog opens by itself.
-- * The free daily challenge reroll waits for the challenge board (LU-1): not built here.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AvatarCosmetics =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AvatarCosmetics"))

local VipStatus = {}
VipStatus.Priority = 60

local PASS = "VipCrewCard"

local service: any = nil
local deck: any = nil

local function rootOf(player: Player): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function inside(pos: Vector3): boolean
	if not deck then
		return false
	end
	local p = deck.volume:PointToObjectSpace(pos)
	local h = deck.volumeSize / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

local function move(player: Player, to: CFrame)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not c or not hum or hum.Health <= 0 then
		return
	end
	if hum.SeatPart then
		hum.Sit = false
		task.wait(0.1)
	end
	c:PivotTo(to + Vector3.new(0, hum.HipHeight + 1, 0))
end

local function onDeck(player: Player, which: any)
	if not deck then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	if which == "Up" then
		local ok, reason = AvatarCosmetics.canClimb(
			service.Owns(player, PASS),
			(root.Position - deck.foot.Position).Magnitude
		)
		if ok then
			move(player, deck.headStand)
		else
			service.FireClient(player, "VipDeckRefused", reason)
		end
	elseif which == "Down" then
		if
			inside(root.Position)
			or (root.Position - deck.head.Position).Magnitude <= AvatarCosmetics.DECK.reach
		then
			move(player, deck.footStand)
		end
	end
end

local function stationAsset(): Model?
	local dressing = Workspace:FindFirstChild("Dressing")
	local shell = dressing and dressing:FindFirstChild("Station")
	if not shell then
		return nil
	end
	-- WorldDressingService parents the clone as "M_Bld_Station" or "M_Bld_Station_<LOD>"
	for _, child in shell:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, 13) == "M_Bld_Station" then
			return child
		end
	end
	local first = shell:FindFirstChildWhichIsA("Model")
	return first
end

local function buildDeck()
	local asset: Model? = nil
	for _ = 1, 120 do -- WorldDressingService swaps the station in once its assets load
		asset = stationAsset()
		if asset then
			break
		end
		task.wait(2)
	end
	if not asset then
		warn("[VipStatus] no station shell in Workspace.Dressing.Station: no VIP deck")
		return
	end
	local VipDeck = (require :: any)(
		script.Parent.Parent:WaitForChild("World"):WaitForChild("VipDeck")
	)
	local ok, result = pcall(VipDeck.build, asset)
	if not ok then
		warn(`[VipStatus] VIP deck failed: {result}`)
		return
	end
	deck = result
	while deck and deck.folder.Parent do
		task.wait(AvatarCosmetics.DECK.sweep)
		for _, p in Players:GetPlayers() do
			local root = rootOf(p)
			if root and inside(root.Position) and not service.Owns(p, PASS) then
				move(p, deck.footStand)
			end
		end
	end
end

function VipStatus.Init(cosmeticsService: any)
	service = cosmeticsService
	service.OnAction("VipDeck", onDeck)
end

function VipStatus.Start()
	local okM, Monetization = pcall(function()
		return (require :: any)(
			script.Parent.Parent:WaitForChild("Services"):WaitForChild("MonetizationService")
		)
	end)
	if okM and Monetization then
		Monetization.OnPassOwned(PASS, function(player: Player, isNew: boolean)
			if isNew then
				service.Equip(player, "Badge", "Gold")
			end
		end)
	end
	task.spawn(buildDeck)
end

return VipStatus
