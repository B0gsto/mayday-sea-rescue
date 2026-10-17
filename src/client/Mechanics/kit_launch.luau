--!strict
-- kit_launch (docs 09 step 2, Kit and launch): read the tasking clues, load the right kit into
-- the vehicle's slots (jet ski 3, RIB 5; oxygen and the recovery strop don't fit a jet ski),
-- then drive down the slipway. Metric: kitFit (0..1); the server times the launch (elapsed).
-- Controls: click / tap a kit card to load or unload it, number keys 1-9; gamepad D-pad to move,
-- A to load, Y to launch. Launch: Enter / the Launch button / Y, then throttle off the slip.
local Medical = require(script.Parent.PIW.Medical)
local Record = require(script.Parent.PIW.Record)
local Step = require(script.Parent.PIW.Step)
local Ui = require(script.Parent.PIW.Ui)
local World = require(script.Parent.PIW.World)

local KitLaunch = {}

local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

function KitLaunch.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local s = Step.new(ctx, finish, "KitLaunch", 330)
	local vehicle = World.vehicle(ctx)
	local jet = World.isJetSki(vehicle)
	local profile = Record.profile(ctx)
	local needed = Medical.kitNeeded(profile.state, profile.lifejacket, jet)
	if Step.autoStub(s, { kitFit = 1 }) then
		return Step.cleanup(s)
	end
	local slots = Medical.kitSlots(jet)
	s.panel.Size = UDim2.fromOffset(560, 330)
	local clue = Step.line(s, `Coastguard: casualty {Medical.kitClue(profile)}.`, 54)
	clue.Size = UDim2.new(1, -24, 0, 40)
	local count = Step.line(s, "", 96)
	local picked: { string } = {}
	local buttons: { TextButton } = {}
	local cursor = 1
	local loaded = false

	local function refresh()
		count.Text = `Slots {#picked} / {slots}`
			.. (if jet then "  (jet ski: no oxygen or strop)" else "")
		for i, item in Medical.Kit do
			local b = buttons[i]
			local on = table.find(picked, item.id) ~= nil
			local blocked = jet and item.ribOnly == true
			b.BackgroundColor3 = if blocked
				then Ui.Theme.Colors.locked
				elseif on then Ui.Theme.Colors.accent
				else Ui.Theme.Colors.panelLight
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if Ui.isGamepad() and i == cursor then
				if not stroke then
					Ui.Theme.stroke(b, Ui.Theme.Colors.text, 2)
				end
			elseif stroke then
				stroke:Destroy()
			end
		end
	end

	local function toggle(i: number)
		local item = Medical.Kit[i]
		if loaded or not item or (jet and item.ribOnly) then
			return
		end
		local at = table.find(picked, item.id)
		if at then
			table.remove(picked, at)
		elseif #picked < slots then
			table.insert(picked, item.id)
			Ui.hands("stow_kit")
		else
			s.say("No room: unload something first")
		end
		refresh()
	end

	for i, item in Medical.Kit do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local b = Ui.button(
			s.panel,
			`{i}  {item.label}`,
			UDim2.fromOffset(172, 52),
			UDim2.fromOffset(12 + col * 180, 122 + row * 58),
			function()
				toggle(i)
			end
		)
		b.TextSize = 16
		buttons[i] = b
	end

	local function launch()
		if loaded then
			return
		end
		loaded = true
		local kit = {}
		for _, id in picked do
			kit[id] = true
		end
		Record.get(ctx.operation.id).kit = kit
		local fit = Medical.kitFit(picked, needed)
		Ui.hands("cast_off")
		count.Text = "Kit stowed. Down the slip: throttle on."
		local moved = 0
		Step.heartbeat(s, function(dt)
			local h = World.hull(World.vehicle(ctx))
			if h == nil then
				moved += dt -- on foot or no boat yet: the shore crew launches it
				if moved > 1 then
					Step.finish(s, { metrics = { kitFit = fit } })
				end
			elseif h.velocity.Magnitude > 6 then
				Step.finish(s, { metrics = { kitFit = fit } })
			end
		end)
	end

	local launchButton = Ui.button(
		s.panel,
		"Load and launch  (Enter / Y)",
		UDim2.new(1, -24, 0, 44),
		UDim2.new(0, 12, 1, -54),
		launch
	)
	launchButton.BackgroundColor3 = Ui.Theme.Colors.accent
	Ui.bind(
		s.bag,
		"KitKeys",
		function(state, input)
			if state ~= "Begin" then
				return
			end
			local k = table.find(KEYS, input.KeyCode)
			if k then
				toggle(k)
			elseif input.KeyCode == Enum.KeyCode.DPadRight then
				cursor = cursor % #Medical.Kit + 1
			elseif input.KeyCode == Enum.KeyCode.DPadLeft then
				cursor = (cursor - 2) % #Medical.Kit + 1
			elseif input.KeyCode == Enum.KeyCode.DPadDown then
				cursor = math.min(#Medical.Kit, cursor + 3)
			elseif input.KeyCode == Enum.KeyCode.DPadUp then
				cursor = math.max(1, cursor - 3)
			elseif input.KeyCode == Enum.KeyCode.ButtonA then
				toggle(cursor)
			elseif
				input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonY
			then
				launch()
			end
			refresh()
		end,
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three,
		Enum.KeyCode.Four,
		Enum.KeyCode.Five,
		Enum.KeyCode.Six,
		Enum.KeyCode.Seven,
		Enum.KeyCode.Eight,
		Enum.KeyCode.Nine,
		Enum.KeyCode.DPadLeft,
		Enum.KeyCode.DPadRight,
		Enum.KeyCode.DPadUp,
		Enum.KeyCode.DPadDown,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonY,
		Enum.KeyCode.Return
	)
	Ui.hint(s.panel, "Read the clues: the casualty's state tells you the kit.", s.assist).Position =
		UDim2.new(0, 12, 1, -76)
	refresh()
	return Step.cleanup(s)
end

return KitLaunch
