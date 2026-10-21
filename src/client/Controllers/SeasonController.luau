--!strict
-- SeasonController: the client side of the Season Logbook (docs/15 H8). The phone's Season app
-- shows UI/SeasonBook (Open / Close; the Phone borrows the book's frame onto its screen).
-- Pulls Season_Get once, then takes Season_State pushes; Season_Claim claims a tier and the reply
-- carries the reward for a short flash on its tile. Escape / B / Close put the book away.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local UI = script.Parent.Parent:WaitForChild("UI")
local InputGlyph = require(UI:WaitForChild("InputGlyph"))
local Layout = require(UI:WaitForChild("Layout"))
local SeasonBook = require(UI:WaitForChild("SeasonBook"))

local SeasonController = {}
SeasonController.Priority = 87

local player = Players.LocalPlayer
local book: SeasonBook.Book? = nil
local modal: InputGlyph.Modal? = nil
local getFn: RemoteFunction? = nil
local claimFn: RemoteFunction? = nil
local claiming = false

local function apply(view: any)
	if book and type(view) == "table" then
		book.update(view :: SeasonBook.View)
	end
end

local function claim(tier: number)
	if claiming or not claimFn then
		return
	end
	claiming = true
	local ok, result = pcall(function()
		return (claimFn :: RemoteFunction):InvokeServer(tier)
	end)
	if ok and type(result) == "table" and result.ok then
		apply(result.view)
		AudioController.play("Logbook_Page", nil, 1, 1)
		task.delay(0.12, function()
			AudioController.play("Logbook_Chime", nil, 1, 1.02)
		end)
		if book then
			book.flash(tier)
		end
	end
	claiming = false
end

local function setOpen(value: boolean)
	local b = book
	local m = modal
	if not b or not m then
		return
	end
	if value and Layout.coldOpen() then
		return
	end
	b.setOpen(value)
	if value then
		if getFn then
			local ok, view = pcall(function()
				return (getFn :: RemoteFunction):InvokeServer()
			end)
			if ok and type(view) == "table" then
				apply(view)
			end
		end
		m.open(b.firstButton())
		ContextActionService:BindActionAtPriority("SeasonBookClose", function(_, state)
			if state == Enum.UserInputState.Begin then
				setOpen(false)
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Escape)
	else
		ContextActionService:UnbindAction("SeasonBookClose")
		m.close()
	end
end

function SeasonController.Open()
	setOpen(true)
end

function SeasonController.Close()
	setOpen(false)
end

function SeasonController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SeasonHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 31 -- above the Ops pager (30): a tasking offer must not cover the book's close key
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Layout.prepare(gui)
	gui.Parent = player:WaitForChild("PlayerGui")

	book = SeasonBook.build(gui, claim)
	modal = InputGlyph.modal("SeasonBook", function()
		setOpen(false)
	end)

	Layout.onColdOpen(function(active: boolean)
		if active and book and book.isOpen() then
			setOpen(false)
		end
	end)
	GuiService.MenuOpened:Connect(function()
		if book and book.isOpen() then
			setOpen(false)
		end
	end)
end

function SeasonController.Start()
	local net = ReplicatedStorage:WaitForChild("Net", 30)
	if not net then
		return
	end
	local state = net:WaitForChild("Season_State", 30)
	if state and state:IsA("RemoteEvent") then
		state.OnClientEvent:Connect(function(view: any)
			if type(view) == "table" then
				apply(view)
			end
		end)
	end
	local get = net:WaitForChild("Season_Get", 30)
	if get and get:IsA("RemoteFunction") then
		getFn = get
	end
	local claimRemote = net:WaitForChild("Season_Claim", 30)
	if claimRemote and claimRemote:IsA("RemoteFunction") then
		claimFn = claimRemote
	end
	if getFn then
		task.spawn(function()
			for _ = 1, 10 do
				local ok, view = pcall(function()
					return (getFn :: RemoteFunction):InvokeServer()
				end)
				if ok and type(view) == "table" then
					apply(view)
					return
				end
				task.wait(1)
			end
		end)
	end
end

return SeasonController
