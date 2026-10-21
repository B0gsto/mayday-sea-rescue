--!strict
-- Take the strain (docs 09 section 6 step 6): dead slow ahead until the line lifts out of the
-- water, hold, then build speed gradually. The line is the TowLine spring-damper: throttle on a
-- slack line and it snatches taut (drips fly off it, the creak rises, the bow dips); far enough
-- and it parts. Pro reads the line itself; Assist also gets a small tension gauge.
-- Metric: peakTension (1 = the working limit). On success the server attaches the tow.

local Kit = require(script.Parent:WaitForChild("Tow"):WaitForChild("Kit"))
local TowLine = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Tow")
		:WaitForChild("TowLine")
)

local M = {}

local UNDER_WAY = 3.5 -- studs/s of the casualty (just over 2 knots)
local HOLD_SECONDS = 4

function M.start(ctx: any, finish: (any) -> ()): (() -> ())?
	local gui = Kit.gui("TowTakeStrain")
	local complete, cleanup, bag = Kit.session(gui, finish)
	if Kit.autoStub(complete, { peakTension = 0.6 }) then
		return cleanup
	end
	local rig = Kit.shared(ctx).rig or { lengthStuds = 75, bridle = true, strongPoint = true }
	Kit.releaseFor(ctx) -- a fresh line on every attempt (a parted line was re-passed)
	local link =
		Kit.link(ctx, rig.lengthStuds, { bridle = rig.bridle, strongPoint = rig.strongPoint })
	if not link then
		Kit.brief(gui, "No casualty")
		task.delay(2, complete, { metrics = { peakTension = 1 }, failed = true })
		return cleanup
	end
	local l = link :: Kit.Link
	l.line.peak = 0
	local setGauge = if ctx.isAssist then Kit.gauge(gui, "Tow line") else nil
	Kit.brief(gui, "Dead slow · take the strain")
	Kit.say(gui, "Crew", "Line's fast. Take up slowly.", 3)
	local held = 0
	local lifted = false
	local lastSnatch = 0
	l.onUpdate = function(lk: Kit.Link, dt: number)
		local line = lk.line
		if setGauge then
			setGauge(line.tension)
		end
		if line.parted then
			Kit.snapSound(lk.ropeA0)
			Kit.hands("duck")
			Kit.say(gui, "Crew", "Line's parted! Heads down! Re-passing.", 4)
			local peak = line.peak
			lk.onUpdate = nil
			Kit.release(lk)
			task.delay(2.5, complete, { metrics = { peakTension = peak }, failed = true })
			return
		end
		if not lifted and not line.slack then
			lifted = true
			Kit.say(gui, "Crew", "She's lifting... line's coming up.", 2.5)
		end
		if line.snatch > 0.2 and os.clock() - lastSnatch > 2 then
			lastSnatch = os.clock()
			Kit.say(gui, "Crew", "Easy! She snatched.", 2)
		end
		local hullSpeed = math.sqrt(line.vx * line.vx + line.vz * line.vz) * TowLine.STUDS_PER_M
		if hullSpeed >= UNDER_WAY and line.tension < TowLine.GREEN then
			held += dt
		else
			held = math.max(0, held - dt * 0.5)
		end
		if held >= HOLD_SECONDS then
			lk.onUpdate = nil
			Kit.say(gui, "Crew", "She's following nicely. Tow's established.", 3)
			complete({ metrics = { peakTension = line.peak } })
		end
	end
	table.insert(bag, function()
		if l.onUpdate then
			l.onUpdate = nil
		end
	end)
	return cleanup
end

return M
