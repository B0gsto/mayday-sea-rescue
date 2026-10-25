--!strict
-- LightBars (client, RP-M5 stream B): animates every "CosmeticLightBar" (built by
-- src/server/Cosmetics/LightBars) and binds the boat toggle.
--   Flash: shared/LightBarFlash on the server clock (bars look the same on every screen). Pattern =
--   the bar's Pattern attribute, or the siren's (vehicle Siren / SirenOn true + SirenPattern or
--   SirenTone: Wail, Yelp, HiLo, Phaser). Only changed properties are written; no instances are made
--   per frame. Each bar has at most two short-range PointLights.
--   Toggle: "Lights", key L / DPadLeft (touch button) while driving a boat or jet ski with a bar; it
--   sets vehicle attribute LightsOn on the server.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LightBarFlash =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LightBarFlash"))

local LightBars = {}
LightBars.Priority = 120

local TAG = "CosmeticLightBar"
local DARK_LED = Color3.fromRGB(62, 64, 68)
local CULL = 1800 -- studs: farther bars are not updated

type LampRec = {
	part: BasePart,
	lamp: LightBarFlash.Lamp,
	color: Color3,
	lit: boolean,
}
type LightRec = { light: PointLight, side: number, on: boolean, color: Color3? }
type Bar = { container: Instance, lamps: { LampRec }, lights: { LightRec }, anyLit: boolean }

local bars: { [Instance]: Bar } = {}

local function register(container: Instance)
	if bars[container] then
		return
	end
	local lamps: { LampRec } = {}
	local lights: { LightRec } = {}
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Lamp" then
			local color = d:GetAttribute("LampColor")
			local side = d:GetAttribute("Side")
			table.insert(lamps, {
				part = d,
				lamp = {
					color = "",
					side = if type(side) == "number" then side else 1,
					invert = d:GetAttribute("Invert") == true,
					steady = d:GetAttribute("Steady") == true,
				},
				color = if typeof(color) == "Color3" then color else Color3.new(1, 1, 1),
				lit = false,
			})
		elseif d:IsA("PointLight") and d.Parent and d.Parent:IsA("Attachment") then
			local side = d.Parent:GetAttribute("Side")
			table.insert(lights, {
				light = d,
				side = if type(side) == "number" then side else 0,
				on = false,
				color = nil,
			})
		end
	end
	if #lamps == 0 then
		return
	end
	bars[container] = { container = container, lamps = lamps, lights = lights, anyLit = true }
end

local function setLamp(rec: LampRec, lit: boolean)
	if rec.lit == lit then
		return
	end
	rec.lit = lit
	rec.part.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
	rec.part.Color = if lit then rec.color else DARK_LED
end

local function setLight(rec: LightRec, on: boolean, color: Color3?)
	if rec.on ~= on then
		rec.on = on
		rec.light.Enabled = on
	end
	if on and color and rec.color ~= color then
		rec.color = color
		rec.light.Color = color
	end
end

local function allOff(bar: Bar)
	if not bar.anyLit then
		return
	end
	bar.anyLit = false
	for _, rec in bar.lamps do
		setLamp(rec, false)
	end
	for _, rec in bar.lights do
		setLight(rec, false, nil)
	end
end

local function step()
	local now = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for container, bar in bars do
		local vehicle = container.Parent
		if not vehicle then
			continue
		end
		if vehicle:GetAttribute("LightsOn") ~= true then
			allOff(bar)
			continue
		end
		if (bar.lamps[1].part.Position - eye).Magnitude > CULL then
			continue
		end
		bar.anyLit = true
		local sirenOn = vehicle:GetAttribute("Siren") == true
			or vehicle:GetAttribute("SirenOn") == true
		local siren = vehicle:GetAttribute("SirenPattern") or vehicle:GetAttribute("SirenTone")
		local pattern =
			LightBarFlash.patternFor(container:GetAttribute("Pattern") :: any, sirenOn, siren)
		-- per side: the colour of a lit flashing lamp wins over a steady work light
		local flashColor: { [number]: Color3? } = {}
		local steadyColor: { [number]: Color3? } = {}
		for _, rec in bar.lamps do
			local lit = LightBarFlash.lampOn(pattern, now, rec.lamp)
			setLamp(rec, lit)
			if lit then
				local side = rec.lamp.side
				if rec.lamp.steady then
					steadyColor[side] = steadyColor[side] or rec.color
				else
					flashColor[side] = flashColor[side] or rec.color
				end
			end
		end
		for _, rec in bar.lights do
			local c: Color3?
			if rec.side == 0 then
				c = flashColor[1] or flashColor[2] or steadyColor[1] or steadyColor[2]
			else
				c = flashColor[rec.side] or steadyColor[rec.side]
			end
			setLight(rec, c ~= nil, c)
		end
	end
end

function LightBars.Start(ctx: any)
	for _, c in CollectionService:GetTagged(TAG) do
		task.defer(register, c)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(c: Instance)
		task.defer(register, c)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(c: Instance)
		bars[c] = nil
	end)
	RunService.Heartbeat:Connect(step)

	ctx.bindVehicleAction({
		name = "LightBar",
		label = "Lights",
		key = Enum.KeyCode.L,
		gamepad = Enum.KeyCode.DPadLeft,
		callback = function()
			ctx.fire("LightBar_Toggle")
		end,
		visible = function(): boolean
			local model = ctx.currentVehicle()
			return model ~= nil and model:FindFirstChild(TAG) ~= nil
		end,
	})
end

return LightBars
