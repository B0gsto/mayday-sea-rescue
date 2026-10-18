--!strict
-- AvatarCosmetics (pure, RP-M5 E2): the rules behind the Captain's Locker / Storm Chaser outfits,
-- the whistle emote and the VIP Crew Card status (gold nameplate, radio tag, roof deck access).
-- No Roblox services: Lune-tested in tests/AvatarCosmetics.spec.luau. Used by
-- src/server/Cosmetics/{Outfits,VipStatus}.luau and src/client/Cosmetics/*.
--
--   AvatarCosmetics.plan(base, outfit?, cap?) -> Look
--       The look to apply: the player's own look (`base`, read from their applied
--       HumanoidDescription) with the outfit's layered clothing / classic shirt and pants and the
--       cap's hat swapped in. Options without clothing fields (the free defaults) keep `base`.
--   AvatarCosmetics.same(a, b) -> boolean            two looks are identical (skip re-applying)
--   AvatarCosmetics.gold(badgeId) -> boolean         the Badge slot shows the gold nameplate / tag
--   AvatarCosmetics.radioTag(badgeId) -> string?     "VIP" for the gold badge, else nil
--   AvatarCosmetics.whistleReady(lastAt?, now) -> boolean     per-player cooldown
--   AvatarCosmetics.canClimb(ownsVip, distance) -> (boolean, reason)   the roof-deck ladder
--   AvatarCosmetics.WHISTLE / AvatarCosmetics.DECK            tuning constants

export type Layer = { id: number, kind: string, order: number? }
export type Look = {
	layers: { Layer }, -- layered clothing, in wear order
	shirt: number, -- classic Shirt id, 0 = none
	pants: number,
	hats: { number }, -- rigid hat accessory ids
}

local AvatarCosmetics = {}

AvatarCosmetics.WHISTLE = {
	cooldown = 2.5, -- seconds between blasts per player
	radius = 140, -- studs: clients beyond this get no event; the Sound rolls off to this
	animSeconds = 1.4, -- the arm-raise is cut after this
}

AvatarCosmetics.DECK = {
	reach = 12, -- studs from the ladder foot / head to use the prompt (server check)
	sweep = 2, -- seconds between the server's non-owner sweep of the deck
}

local function copyLayers(layers: { Layer }): { Layer }
	local out: { Layer } = {}
	for i, l in layers do
		out[i] = { id = l.id, kind = l.kind, order = l.order or i }
	end
	return out
end

function AvatarCosmetics.plan(base: Look, outfit: { [string]: any }?, cap: { [string]: any }?): Look
	local look: Look = {
		layers = copyLayers(base.layers),
		shirt = base.shirt,
		pants = base.pants,
		hats = table.clone(base.hats),
	}
	if outfit and type(outfit.layers) == "table" and #outfit.layers > 0 then
		look.layers = {}
		for i, l in outfit.layers :: { any } do
			if type(l) == "table" and type(l.id) == "number" and type(l.kind) == "string" then
				table.insert(look.layers, { id = l.id, kind = l.kind, order = i })
			end
		end
		look.shirt = if type(outfit.shirt) == "number" then outfit.shirt else base.shirt
		look.pants = if type(outfit.pants) == "number" then outfit.pants else base.pants
	end
	if cap and type(cap.hat) == "number" and cap.hat > 0 then
		look.hats = { cap.hat }
	end
	return look
end

function AvatarCosmetics.same(a: Look, b: Look): boolean
	if a.shirt ~= b.shirt or a.pants ~= b.pants or #a.layers ~= #b.layers or #a.hats ~= #b.hats then
		return false
	end
	for i, l in a.layers do
		local o = b.layers[i]
		if o.id ~= l.id or o.kind ~= l.kind then
			return false
		end
	end
	for i, h in a.hats do
		if b.hats[i] ~= h then
			return false
		end
	end
	return true
end

function AvatarCosmetics.gold(badgeId: string?): boolean
	return badgeId == "Gold"
end

function AvatarCosmetics.radioTag(badgeId: string?): string?
	return if AvatarCosmetics.gold(badgeId) then "VIP" else nil
end

function AvatarCosmetics.whistleReady(lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= AvatarCosmetics.WHISTLE.cooldown
end

function AvatarCosmetics.canClimb(ownsVip: boolean, distance: number): (boolean, string)
	if not ownsVip then
		return false, "The roof deck is for VIP Crew Card holders"
	end
	if distance ~= distance or distance > AvatarCosmetics.DECK.reach then
		return false, "Too far from the ladder"
	end
	return true, "ok"
end

return AvatarCosmetics
