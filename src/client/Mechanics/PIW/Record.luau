--!strict
-- PIW/Record: what this client saw and did during one operation, so later steps build on it:
-- the kit carried (greys out missing options), the survey findings, the treatments in order (the
-- ATMIST handover reads them back), the recovery method. Per operation id; dropped after a while.
local Medical = require(script.Parent.Medical)

local Record = {}

export type Entry = {
	opId: string,
	startedAt: number,
	kit: { [string]: boolean }?, -- nil until kit_launch ran (then everything is assumed carried)
	findings: { [string]: number },
	surveyed: boolean,
	applied: { string },
	method: string?,
	calmed: boolean,
	profile: Medical.Profile?,
}

local entries: { [string]: Entry } = {}

function Record.get(opId: string): Entry
	local e = entries[opId]
	if not e then
		e = {
			opId = opId,
			startedAt = os.clock(),
			kit = nil,
			findings = {},
			surveyed = false,
			applied = {},
			method = nil,
			calmed = false,
			profile = nil,
		}
		entries[opId] = e
		-- forget old operations
		for id, other in entries do
			if id ~= opId and os.clock() - other.startedAt > 3600 then
				entries[id] = nil
			end
		end
	end
	return e
end

-- The casualty's profile (same on every client: derived from the casualty id and state).
function Record.profile(ctx: { [string]: any }): Medical.Profile
	local e = Record.get(ctx.operation.id)
	local c = ctx.casualty or {}
	local id = tostring(c.id or ctx.operation.id)
	local p = e.profile
	if not p or p.state ~= (c.state or "Alert") then
		p = Medical.profile(id, c.state or "Alert", c.lifejacket == true, ctx.operation.kind)
		e.profile = p
	end
	return p :: Medical.Profile
end

function Record.carried(opId: string, item: string): boolean
	local kit = Record.get(opId).kit
	return kit == nil or kit[item] == true
end

return Record
