--!strict
-- SaleRules: the HUD sale button's pure rules (UI/Menu; tests/SaleRules.spec.luau).
local SaleRules = {}

-- Seconds left as the button's clock: "h:mm" from an hour up (days roll into hours, "37:12"), "m:ss" under it.
function SaleRules.countdown(left: number): string
	local s = math.max(0, math.floor(left))
	if s >= 3600 then
		return string.format("%d:%02d", s // 3600, (s % 3600) // 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

-- The button shows while the sale runs and the player does not own the item.
function SaleRules.visible(endsAt: number?, now: number, owned: boolean): boolean
	return type(endsAt) == "number" and now < endsAt and not owned
end

return SaleRules
