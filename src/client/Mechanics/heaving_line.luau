--!strict
-- Heaving line (docs 09 section 6 step 4): hold station upwind of the casualty at throwing range
-- (both boats drift downwind, so the line and the drift carry toward them), then aim and throw:
-- hold to charge, release to throw underarm. The weighted knot flies on a ballistic arc at the
-- project gravity with wind drift (Tow/Ballistics). It must land across their deck, not on a
-- person. A miss: coil it back in (4 s) and rethrow. Metrics: throws, hitPerson.
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Ballistics = require(script.Parent:WaitForChild("Tow"):WaitForChild("Ballistics"))
local Kit = require(script.Parent:WaitForChild("Tow"):WaitForChild("Kit"))

local M = {}

local RANGE_MIN, RANGE_MAX = 12, 42 -- studs from their hull (4 to 14 m) (tune)
local STATION_SPEED = 7 -- studs/s
local COIL_SECONDS = 4
local CHARGE_SECONDS = 1.1
local ACTION = "TowHeavingLineThrow"

function M.start(ctx: any, finish: (any) -> ()): (() -> ())?
	local gui = Kit.gui("TowHeavingLine")
	local complete, cleanup, bag = Kit.session(gui, finish)
	if Kit.autoStub(complete, { throws = 1, hitPerson = 0 }) then
		return cleanup
	end
	local model = Kit.casualtyModel(ctx)
	local hull = model and (model.PrimaryPart or Kit.part(model, "Hull"))
	local throws, hitPerson = 0, 0
	local state = "station" -- station | charging | flying | coiling | done
	local charge = 0
	local onStation = false
	local lastCall = 0

	-- the predicted arc (Assist only): a dotted line of small beads
	local arcFolder = Instance.new("Folder")
	arcFolder.Name = "HeavingLineArc"
	arcFolder.Parent = Workspace.CurrentCamera
	table.insert(bag, function()
		arcFolder:Destroy()
	end)
	local beads: { BasePart } = {}
	if ctx.isAssist then
		for i = 1, 14 do
			local b = Instance.new("Part")
			b.Name = `Bead{i}`
			b.Shape = Enum.PartType.Ball
			b.Size = Vector3.new(0.25, 0.25, 0.25)
			b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
			b.Material = Enum.Material.Neon
			b.Color = Color3.fromRGB(255, 240, 200)
			b.Transparency = 1
			b.Parent = arcFolder
			beads[i] = b
		end
	end

	Kit.brief(
		gui,
		"Hold her upwind of the casualty, about 5 to 12 metres off. Then throw across their deck."
	)

	local function deckBox(): { cframe: CFrame, size: Vector3 }?
		if not hull then
			return nil
		end
		return {
			cframe = hull.CFrame * CFrame.new(0, hull.Size.Y / 2, 0),
			size = Vector3.new(hull.Size.X, 1, hull.Size.Z),
		}
	end

	local function aim(root: BasePart): (Vector3, Vector3)
		local cam = Workspace.CurrentCamera
		local look = if cam then cam.CFrame.LookVector else -root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local yaw = math.atan2(-flat.X, -flat.Z)
		local pitch = math.clamp(
			math.asin(math.clamp(look.Y, -1, 1)) + math.rad(35),
			math.rad(15),
			math.rad(60)
		)
		local origin = root.Position + Vector3.new(0, 4, 0)
		return origin, Ballistics.launchVelocity(yaw, pitch, Ballistics.speedFor(charge))
	end

	local function throw()
		local root = Kit.vehicleRoot(ctx)
		local deck = deckBox()
		if not root or not deck or not hull then
			state = "station"
			return
		end
		state = "flying"
		throws += 1
		Kit.hands("throw_heaving_line")
		local origin, vel = aim(root)
		local wind = Kit.wind(ctx)
		local waterY = hull.Position.Y - hull.Size.Y / 2
		local landing = Ballistics.simulate(origin, vel, wind, waterY, deck, nil)
		-- fly the monkey's fist along the path with the line paying out behind it
		local fist = Instance.new("Part")
		fist.Name = "MonkeysFist"
		fist.Shape = Enum.PartType.Ball
		fist.Size = Vector3.new(0.45, 0.45, 0.45)
		fist.Anchored, fist.CanCollide, fist.CanQuery = true, false, false
		fist.Color = Color3.fromRGB(230, 225, 200)
		fist.Material = Enum.Material.Fabric
		fist.CFrame = CFrame.new(origin)
		fist.Parent = Workspace
		local a0 = Instance.new("Attachment")
		a0.Parent = root
		a0.WorldPosition = origin
		local a1 = Instance.new("Attachment")
		a1.Parent = fist
		local line = Instance.new("Beam")
		line.Attachment0, line.Attachment1 = a0, a1
		line.Width0, line.Width1 = 0.08, 0.08
		line.FaceCamera = true
		line.Color = ColorSequence.new(Color3.fromRGB(240, 235, 210))
		line.Parent = fist
		table.insert(bag, function()
			fist:Destroy()
			a0:Destroy()
		end)
		local path = landing.path
		local t0 = os.clock()
		local conn: RBXScriptConnection? = nil
		conn = RunService.RenderStepped:Connect(function()
			local f = math.clamp((os.clock() - t0) / math.max(landing.time, 0.1), 0, 1)
			local idx = 1 + f * (#path - 1)
			local i0 = math.floor(idx)
			local i1 = math.min(i0 + 1, #path)
			fist.CFrame = CFrame.new(path[i0]:Lerp(path[i1], idx - i0))
			line.CurveSize0 = 1.5 * (1 - f)
			if f >= 1 and conn then
				conn:Disconnect()
				local verdict = Ballistics.judge(landing, origin, deck, Kit.people(model :: Model))
				if verdict == "deck" or verdict == "person" then
					if verdict == "person" then
						hitPerson += 1
						Kit.say(gui, "Skipper", "Ow! Watch it!", 2.5)
					else
						Kit.say(gui, "Crew", "Line's across!", 2.5)
					end
					state = "done"
					task.delay(1.5, function()
						Kit.say(gui, "Skipper", "Got it, hauling in!", 2)
						Kit.shared(ctx).heavingLine = true
						complete({ metrics = { throws = throws, hitPerson = hitPerson } })
					end)
				else
					local call = if verdict == "short"
						then "Short! Coil it and go again."
						elseif verdict == "long" then "Over the top! Coil and rethrow."
						else "Wide, the wind took it. Aim off upwind."
					Kit.say(gui, "Crew", call, 3)
					state = "coiling"
					Kit.hands("coil_line")
					task.delay(COIL_SECONDS, function()
						fist:Destroy()
						a0:Destroy()
						if state == "coiling" then
							state = "station"
						end
					end)
				end
			end
		end)
		table.insert(bag, conn :: RBXScriptConnection)
	end

	ContextActionService:BindAction(ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			if state == "station" then
				if onStation then
					state = "charging"
					charge = 0
					Kit.hands("ready_heaving_line")
				else
					Kit.say(gui, "Crew", "Get us upwind of her first, and steady.", 2.5)
				end
			end
		elseif inputState == Enum.UserInputState.End then
			if state == "charging" then
				throw()
			end
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle(ACTION, "Throw")
	table.insert(bag, function()
		ContextActionService:UnbindAction(ACTION)
	end)

	table.insert(
		bag,
		RunService.Heartbeat:Connect(function(dt: number)
			local root = Kit.vehicleRoot(ctx)
			if not root or not hull or not hull.Parent then
				return
			end
			local flatD = Vector3.new(
				hull.Position.X - root.Position.X,
				0,
				hull.Position.Z - root.Position.Z
			).Magnitude
			local wind = Kit.wind(ctx)
			local up = Ballistics.upwindness(root.Position, hull.Position, wind)
			local speed = Kit.speed(root)
			onStation = up > 0.35
				and flatD >= RANGE_MIN
				and flatD <= RANGE_MAX
				and speed < STATION_SPEED
			if os.clock() - lastCall > 4 and state == "station" then
				lastCall = os.clock()
				if flatD < RANGE_MIN then
					Kit.say(gui, "Crew", "Too close! Back off a touch.", 2.5)
				elseif up <= 0.35 then
					Kit.say(
						gui,
						"Crew",
						"We're downwind of her. Go round and come up to windward.",
						3
					)
				elseif flatD > RANGE_MAX then
					Kit.say(gui, "Crew", "Bit closer, it won't reach from here.", 2.5)
				elseif speed >= STATION_SPEED then
					Kit.say(gui, "Crew", "Ease off, hold her there.", 2.5)
				else
					Kit.say(gui, "Crew", "That's it, hold her there. Throw when ready.", 2.5)
				end
			end
			if state == "charging" then
				charge = math.min(1, charge + dt / CHARGE_SECONDS)
			end
			if #beads > 0 then
				local show = state == "charging" or (state == "station" and onStation)
				if show then
					local origin, vel = aim(root)
					local deck = deckBox()
					local waterY = hull.Position.Y - hull.Size.Y / 2
					local pred = Ballistics.simulate(origin, vel, wind, waterY, deck, nil)
					for i, b in beads do
						local idx =
							math.clamp(math.floor(i / #beads * #pred.path + 0.5), 1, #pred.path)
						b.CFrame = CFrame.new(pred.path[idx])
						b.Transparency = 0.35
					end
				else
					for _, b in beads do
						b.Transparency = 1
					end
				end
			end
		end)
	)
	return cleanup
end

return M
