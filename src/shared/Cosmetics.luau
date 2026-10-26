--!strict
-- Cosmetics (pure, client and server; RP-M5 spine): the cosmetic slots players equip with the game
-- passes they own (equipped in the world: the paint booth, never from a HUD shop). Lune-tested in tests/Cosmetics.spec.luau.
--
-- Slot data lives one file per slot in src/shared/Config/Cosmetics/*.luau (each builder owns one).
-- A file returns a slot table or a list of slot tables:
--   { slot = "Horn", options = { { id, name, pass = <GamePasses key, nil = free>, ...free-form } },
--     default = "<id of a free option>" }
--
--   Cosmetics.slots(): { string }                   every slot, in SLOT_ORDER then by name
--   Cosmetics.slot(name): Slot?                     the slot table
--   Cosmetics.option(slot, id): Option?
--   Cosmetics.default(slot): string?                the free default option id
--   Cosmetics.attribute(slot): string               "Cos_<Slot>", the player attribute
--   Cosmetics.canEquip(slot, id, owns): boolean     the option exists and is free, its pass owned,
--                                                 or its `earn` key owned (earned rewards)
--   Cosmetics.sanitize(saved, owns): { [slot]: id } every slot, default where not allowed
--   Cosmetics.ownedOptions(slot, owns): { Option }  the equippable options, in config order
--   Cosmetics.cycle(slot, current, owns, step): id  the next / previous equippable option
--   Cosmetics.slotsForPass(passKey): { string }     slots with at least one option from that pass
--   Cosmetics.passesForSlot(slot): { string }       the passes that sell options of a slot
--   Cosmetics.ownsSlot(slot, owns): boolean         the player owns a pass with options in the slot
--   Cosmetics.validate(): { string }                config problems (empty when fine)
--   Cosmetics.build(modules): Registry              a registry over other slot tables (tests)
-- `owns` is a function (passKey) -> boolean (server: MonetizationService.OwnsPass, client: the
-- "Pass_<Key>" attribute).

export type Option = {
	id: string,
	name: string,
	pass: string?,
	[string]: any,
}
export type Slot = {
	slot: string,
	options: { Option },
	default: string,
	[string]: any,
}
export type Owns = (passKey: string) -> boolean

local SLOT_ORDER = {
	"Outfit",
	"Badge",
	"Livery",
	"Decal",
	"Title",
	"Horn",
	"Siren",
	"LightBar",
	"Wake",
	"Radio",
	"Dog",
	"DogWear",
	"DogCoat",
	"DogBandana",
}

local function isSlotTable(value: any): boolean
	return type(value) == "table" and type(value.slot) == "string"
end

local function build(modules: { any })
	local bySlot: { [string]: Slot } = {}
	local optionIndex: { [string]: { [string]: Option } } = {}
	local problems: { string } = {}
	local order: { string } = {}

	local function add(entry: any)
		if not isSlotTable(entry) then
			table.insert(problems, "a cosmetics config entry has no `slot` name")
			return
		end
		local slot = entry :: Slot
		if bySlot[slot.slot] then
			table.insert(problems, `slot {slot.slot} is defined twice`)
			return
		end
		local index: { [string]: Option } = {}
		for i, option in (if type(slot.options) == "table" then slot.options else {}) :: { Option } do
			if type(option) ~= "table" or type(option.id) ~= "string" or option.id == "" then
				table.insert(problems, `{slot.slot} option {i} has no id`)
			elseif index[option.id] then
				table.insert(problems, `{slot.slot} option {option.id} is listed twice`)
			else
				index[option.id] = option
				if type(option.name) ~= "string" then
					table.insert(problems, `{slot.slot}.{option.id} has no name`)
				end
				if option.pass ~= nil and type(option.pass) ~= "string" then
					table.insert(problems, `{slot.slot}.{option.id} pass must be a string`)
				end
				if option.earn ~= nil and type(option.earn) ~= "string" then
					table.insert(problems, `{slot.slot}.{option.id} earn must be a string`)
				end
			end
		end
		local default = index[slot.default]
		if not default then
			table.insert(
				problems,
				`{slot.slot} default "{tostring(slot.default)}" is not an option`
			)
		elseif default.pass ~= nil then
			table.insert(problems, `{slot.slot} default must be free (pass = nil)`)
		end
		if #slot.slot > 24 then
			table.insert(problems, `slot name {slot.slot} is longer than 24 characters`)
		end
		bySlot[slot.slot] = slot
		optionIndex[slot.slot] = index
		table.insert(order, slot.slot)
	end

	for _, module in modules do
		if isSlotTable(module) then
			add(module)
		elseif type(module) == "table" then
			for _, entry in module do
				add(entry)
			end
		else
			table.insert(problems, "a cosmetics config file returned neither a slot nor a list")
		end
	end

	table.sort(order, function(a, b)
		local ia = table.find(SLOT_ORDER, a) or math.huge
		local ib = table.find(SLOT_ORDER, b) or math.huge
		if ia ~= ib then
			return ia < ib
		end
		return a < b
	end)

	local R = {}

	function R.slots(): { string }
		return table.clone(order)
	end

	function R.slot(name: string): Slot?
		return bySlot[name]
	end

	function R.option(slot: string, id: string): Option?
		local index = optionIndex[slot]
		return if index and type(id) == "string" then index[id] else nil
	end

	function R.default(slot: string): string?
		local s = bySlot[slot]
		return if s and optionIndex[slot][s.default] then s.default else nil
	end

	function R.attribute(slot: string): string
		return "Cos_" .. slot
	end

	local function allowed(option: Option, owns: Owns): boolean
		if option.pass ~= nil and owns(option.pass) ~= true then
			return false
		end
		if option.earn ~= nil and owns(option.earn) ~= true then
			return false
		end
		return true
	end

	function R.canEquip(slot: string, id: string, owns: Owns): boolean
		local option = R.option(slot, id)
		return option ~= nil and allowed(option, owns)
	end

	function R.sanitize(saved: any, owns: Owns): { [string]: string }
		local out: { [string]: string } = {}
		local source = if type(saved) == "table" then saved else {}
		for _, slot in order do
			local want = source[slot]
			if type(want) == "string" and R.canEquip(slot, want, owns) then
				out[slot] = want
			else
				local d = R.default(slot)
				if d then
					out[slot] = d
				end
			end
		end
		return out
	end

	function R.ownedOptions(slot: string, owns: Owns): { Option }
		local out: { Option } = {}
		local s = bySlot[slot]
		if s then
			for _, option in s.options do
				if optionIndex[slot][option.id] == option and allowed(option, owns) then
					table.insert(out, option)
				end
			end
		end
		return out
	end

	function R.cycle(slot: string, current: string?, owns: Owns, step: number): string?
		local list = R.ownedOptions(slot, owns)
		if #list == 0 then
			return nil
		end
		local at = 0
		for i, option in list do
			if option.id == current then
				at = i
				break
			end
		end
		if at == 0 then
			return if step < 0 then list[#list].id else list[1].id
		end
		local dir = if step < 0 then -1 else 1
		return list[(at - 1 + dir) % #list + 1].id
	end

	function R.passesForSlot(slot: string): { string }
		local out: { string } = {}
		local s = bySlot[slot]
		if s then
			for _, option in s.options do
				local pass = option.pass
				if type(pass) == "string" and not table.find(out, pass) then
					table.insert(out, pass)
				end
			end
		end
		return out
	end

	function R.slotsForPass(passKey: string): { string }
		local out: { string } = {}
		for _, slot in order do
			if table.find(R.passesForSlot(slot), passKey) then
				table.insert(out, slot)
			end
		end
		return out
	end

	function R.ownsSlot(slot: string, owns: Owns): boolean
		for _, pass in R.passesForSlot(slot) do
			if owns(pass) == true then
				return true
			end
		end
		return false
	end

	function R.validate(): { string }
		return table.clone(problems)
	end

	-- every pass key the slots use (MonetizationService.OnPassOwned registrations)
	function R.passes(): { string }
		local out: { string } = {}
		for _, slot in order do
			for _, pass in R.passesForSlot(slot) do
				if not table.find(out, pass) then
					table.insert(out, pass)
				end
			end
		end
		table.sort(out)
		return out
	end

	R.build = build
	return R
end

-- The real slots: every ModuleScript in Config/Cosmetics, sorted by name.
local folder = script.Parent:WaitForChild("Config"):WaitForChild("Cosmetics")
local files = {}
for _, child in folder:GetChildren() do
	if child:IsA("ModuleScript") then
		table.insert(files, child)
	end
end
table.sort(files, function(a, b)
	return a.Name < b.Name
end)
local modules = {}
for _, file in files do
	table.insert(modules, (require :: any)(file))
end

export type Registry = typeof(build({}))

return build(modules)
