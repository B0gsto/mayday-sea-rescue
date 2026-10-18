--!strict
-- Outfits (RP-M5 E2, a CosmeticsService feature): dresses the player's R15 avatar in the equipped
-- "Outfit" and "Cap" cosmetics (src/shared/Config/Cosmetics/Outfit.luau) through a
-- HumanoidDescription, and serves the Captain's Locker whistle emote.
--
-- * The player's own look is read once per player (Players:GetHumanoidDescriptionFromUserId, else
--   the first applied description of their character) and kept as the base. AvatarCosmetics.plan
--   swaps in the outfit's layered clothing / classic shirt and pants and the cap's hat; the free
--   defaults ("Station", "None") restore the base. Re-applied on spawn and whenever the Cos_Outfit /
--   Cos_Cap attribute changes. Accessories other than hats and layered clothing (hair, face, back) are kept.
-- * Whistle: Cosmetics_Action "Whistle" (CaptainsLocker owners, on foot or aboard, 2.5 s cooldown)
--   -> Cosmetics_Event "Whistle" (player) to clients within 140 studs; each client plays the
--   Fox 40 blast (AudioConfig Emote_Whistle, SFX group) at the player's head. The arm raise is
--   played by the whistler's own client (src/client/Cosmetics/Whistle.luau) and replicates.
-- * Buying Captain's Locker puts the bright wetsuit on once (isNewPurchase only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AvatarCosmetics = require(Shared:WaitForChild("AvatarCosmetics"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))

local Outfits = {}
Outfits.Priority = 50

local service: any = nil
local bases: { [Player]: HumanoidDescription } = {}
local applying: { [Player]: number } = {}
local lastWhistle: { [Player]: number } = {}
local layeredTypes: { [string]: boolean } = {}
for _, name in
	{
		"TShirt",
		"Shirt",
		"Pants",
		"Jacket",
		"Sweater",
		"Shorts",
		"DressSkirt",
		"LeftShoe",
		"RightShoe",
	}
do
	layeredTypes[name] = true
end

local function warnf(message: string)
	warn(`[Outfits] {message}`)
end

local function idList(ids: { number }): string
	local parts = {}
	for _, id in ids do
		table.insert(parts, tostring(id))
	end
	return table.concat(parts, ",")
end

local function parseIds(s: string): { number }
	local out = {}
	for token in string.gmatch(s, "%d+") do
		local n = tonumber(token)
		if n and n > 0 then
			table.insert(out, n)
		end
	end
	return out
end

-- the base Look of a description (layered clothing, classic shirt / pants, hats)
local function lookOf(desc: HumanoidDescription): AvatarCosmetics.Look
	local layers: { AvatarCosmetics.Layer } = {}
	local ok, list = pcall(function()
		return desc:GetAccessories(false)
	end)
	if ok and type(list) == "table" then
		for _, a in list :: { any } do
			if a.IsLayered and a.AssetId and a.AccessoryType then
				table.insert(
					layers,
					{ id = a.AssetId, kind = a.AccessoryType.Name, order = a.Order }
				)
			end
		end
	end
	return {
		layers = layers,
		shirt = desc.Shirt,
		pants = desc.Pants,
		hats = parseIds(desc.HatAccessory),
	}
end

local function baseOf(player: Player, humanoid: Humanoid): HumanoidDescription?
	local b = bases[player]
	if b then
		return b
	end
	if player.UserId > 0 then
		local ok, d = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok and d then
			bases[player] = d
			return d
		end
	end
	local ok, d = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if ok and d then
		bases[player] = d
		return d
	end
	return nil
end

-- the description for the player's equipped outfit and cap over their own look
local function describe(player: Player, base: HumanoidDescription): HumanoidDescription
	local outfit = Cosmetics.option("Outfit", service.Equipped(player, "Outfit"))
	local cap = Cosmetics.option("Cap", service.Equipped(player, "Cap"))
	local look = AvatarCosmetics.plan(lookOf(base), outfit, cap)
	local d = base:Clone()
	d.Shirt, d.Pants = look.shirt, look.pants
	if outfit and type(outfit.layers) == "table" and #outfit.layers > 0 then
		d.GraphicTShirt = 0
	end
	d.HatAccessory = idList(look.hats)
	local rigid = {}
	local ok, list = pcall(function()
		return d:GetAccessories(false)
	end)
	if ok and type(list) == "table" then
		for _, a in list :: { any } do
			if not a.IsLayered then
				table.insert(rigid, a)
			end
		end
	end
	local all = table.clone(rigid)
	for i, l in look.layers do
		local kind = layeredTypes[l.kind] and (Enum.AccessoryType :: any)[l.kind]
		if kind then
			table.insert(
				all,
				{ AssetId = l.id, AccessoryType = kind, IsLayered = true, Order = l.order or i }
			)
		end
	end
	pcall(function()
		d:SetAccessories(all, false)
	end)
	return d
end

local function dress(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local token = (applying[player] or 0) + 1
	applying[player] = token
	local base = baseOf(player, humanoid)
	if not base or applying[player] ~= token or humanoid.Parent ~= character then
		return
	end
	local want = describe(player, base)
	local okNow, current = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if okNow and current and AvatarCosmetics.same(lookOf(current), lookOf(want)) then
		return
	end
	local ok, err = pcall(function()
		humanoid:ApplyDescriptionAsync(want)
	end)
	if not ok then
		warnf(`could not dress {player.Name}: {err}`)
	end
end

local function onCharacter(player: Player, character: Model)
	local loaded = player:HasAppearanceLoaded()
	if not loaded then
		local t0 = os.clock()
		while not player:HasAppearanceLoaded() and os.clock() - t0 < 10 and character.Parent do
			task.wait(0.25)
		end
	end
	if player.Character == character then
		dress(player)
	end
end

local function watch(player: Player)
	-- the Cos_<Slot> attributes are the effective choice (CosmeticsService sets them)
	for _, slot in { "Outfit", "Cap" } do
		player:GetAttributeChangedSignal(Cosmetics.attribute(slot)):Connect(function()
			task.spawn(dress, player)
		end)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

local function onWhistle(player: Player)
	if not service.Owns(player, "CaptainsLocker") then
		return
	end
	local now = os.clock()
	if not AvatarCosmetics.whistleReady(lastWhistle[player], now) then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	lastWhistle[player] = now
	service.FireNear(head.Position, AvatarCosmetics.WHISTLE.radius, "Whistle", player)
end

function Outfits.Init(cosmeticsService: any)
	service = cosmeticsService
	service.OnAction("Whistle", onWhistle)
end

function Outfits.Start()
	local okM, Monetization = pcall(function()
		return (require :: any)(
			script.Parent.Parent:WaitForChild("Services"):WaitForChild("MonetizationService")
		)
	end)
	if okM and Monetization then
		Monetization.OnPassOwned("CaptainsLocker", function(player: Player, isNew: boolean)
			if isNew and service.Equipped(player, "Outfit") == Cosmetics.default("Outfit") then
				service.Equip(player, "Outfit", "Wetsuit")
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		bases[player] = nil
		applying[player] = nil
		lastWhistle[player] = nil
	end)
end

return Outfits
