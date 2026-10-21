--!strict
-- ExplorationController: the client side of the logbook (server: ExplorationService). Builds the
-- Logbook UI, keeps the found set and the duty state, shows a notice on each discovery and puts the
-- discovered entries on the map (MapController.SetBlips("Logbook", ...), style Discovery).
-- Input: the phone's Logbook app opens it (J / gamepad L3 there), gamepad B closes it.
-- API: Open(), Close(), IsOpen(), SetOffDuty(bool), IsOffDuty(), GetFound().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Discovery = require(Shared:WaitForChild("Explore"):WaitForChild("Discovery"))
local Logbook = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Logbook"))
local MapController = require(script.Parent.MapController)

local ExplorationController = {}
ExplorationController.Priority = 130 -- after MapController (120)

local player = Players.LocalPlayer
local found: { [string]: boolean } = {}
local offDuty = false
local book: Logbook.Logbook? = nil
local dutyRemote: RemoteEvent? = nil

local function refreshMap()
	local items = {}
	for _, e in Discovery.Entries do
		if found[e.id] then
			table.insert(items, { id = e.id, position = e.position, style = "Discovery" })
		end
	end
	MapController.SetBlips("Logbook", items)
end

local function push()
	if book then
		book.update(found, offDuty)
	end
	refreshMap()
end

function ExplorationController.Open()
	if book then
		book.setOpen(true)
	end
end

function ExplorationController.Close()
	if book then
		book.setOpen(false)
	end
end

function ExplorationController.IsOpen(): boolean
	return book ~= nil and book.isOpen()
end

function ExplorationController.IsOffDuty(): boolean
	return offDuty
end

function ExplorationController.SetOffDuty(v: boolean)
	offDuty = v
	push()
	if dutyRemote then
		dutyRemote:FireServer(v)
	end
end

function ExplorationController.GetFound(): { [string]: boolean }
	return table.clone(found)
end

function ExplorationController.Init()
	book = Logbook.build(function(v: boolean)
		offDuty = v
		refreshMap()
		if dutyRemote then
			dutyRemote:FireServer(v)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if not book then
			return
		end
		-- J / L3 open the phone's Logbook app (UI/Phone)
		if input.KeyCode == Enum.KeyCode.ButtonB and book.isOpen() then
			book.setOpen(false)
		end
	end)
	player:GetAttributeChangedSignal("OffDuty"):Connect(function()
		local v = player:GetAttribute("OffDuty") == true
		if v ~= offDuty then
			offDuty = v
			push()
		end
	end)
end

function ExplorationController.Start()
	local net = ReplicatedStorage:WaitForChild("Net")
	dutyRemote = net:WaitForChild("Explore_SetDuty", 30) :: RemoteEvent?
	local foundRemote = net:WaitForChild("Explore_Found", 30) :: RemoteEvent?
	local state = net:WaitForChild("Explore_State", 30) :: RemoteFunction?
	if foundRemote then
		foundRemote.OnClientEvent:Connect(function(msg: any)
			if type(msg) ~= "table" or type(msg.id) ~= "string" then
				return
			end
			found[msg.id] = true
			push()
			if book then
				book.notify(
					msg.id,
					tonumber(msg.cash) or 0,
					if type(msg.pages) == "table" then msg.pages else {}
				)
			end
		end)
	end
	if state then
		-- the profile may still be loading: ask a few times
		for _ = 1, 10 do
			local ok, res = pcall(function()
				return state:InvokeServer()
			end)
			if ok and type(res) == "table" and type(res.found) == "table" then
				for id, v in res.found do
					if v == true then
						found[id] = true
					end
				end
				offDuty = res.offDuty == true
				push()
				if next(res.found) ~= nil or player:GetAttribute("OffDuty") ~= nil then
					break
				end
			end
			task.wait(3)
		end
	end
end

return ExplorationController
