--!strict
-- Crew panel: the four seats, with the leader ringed. Invite opens Roblox's own invite sheet;
-- Leave is the same remote the boat prompt uses. The server echoes both changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Kit = script.Parent.Parent:WaitForChild("Kit")
local Panel = require(Kit:WaitForChild("Panel"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local player = Players.LocalPlayer
local Crew = {}

local function crewName(id: number): string
	local member = Players:GetPlayerByUserId(id)
	return if member then member.DisplayName else `Player {id}`
end

function Crew.new(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Crew",
		icon = "crew",
		size = Vector2.new(720, 560),
		onClose = onClose,
	})
	local ids: { number } = {}
	local leader = 0
	local refresh: () -> ()

	local function paint()
		for _, c in panel.body:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local host = Instance.new("Frame")
		host.Name = "Seats"
		host.BackgroundTransparency = 1
		host.Size = UDim2.fromScale(1, 0)
		host.AutomaticSize = Enum.AutomaticSize.Y
		host.Parent = panel.body
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(250, 230)
		grid.CellPadding = UDim2.fromOffset(16, 16)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = host
		local members = if #ids > 0 then ids else { player.UserId }
		for i = 1, 4 do
			local id = members[i]
			local card = Instance.new("Frame")
			card.Name = `Seat{i}`
			card.LayoutOrder = i
			card.Size = UDim2.fromOffset(250, 230)
			card.BackgroundTransparency = 1
			card.Parent = host
			local _, face = Style.block(card, Style.grad(if id then "teal" else "disabled"))
			local art = Instance.new("ImageLabel")
			art.Name = "Face"
			art.AnchorPoint = Vector2.new(0.5, 0)
			art.Position = UDim2.fromScale(0.5, 0.08)
			art.Size = UDim2.fromOffset(136, 136)
			art.BackgroundColor3 = Color3.new(1, 1, 1)
			art.BackgroundTransparency = if id then 0 else 0.65
			art.Image = if id then `rbxthumb://type=AvatarHeadShot&id={id}&w=150&h=150` else ""
			Style.corner(art, 999)
			art.Parent = face
			if id and id == leader then
				Style.stroke(art, 6, true).Color = Theme.Grad.yellow.top
			else
				Style.stroke(art, 3, true)
			end
			local name = Style.label(
				face,
				if id then if id == player.UserId then "You" else crewName(id) else "Open seat",
				Theme.Text.small
			)
			name.Position = UDim2.new(0, 8, 0.72, 0)
			name.Size = UDim2.new(1, -16, 0, 30)
			name.TextWrapped = false
			local role = Style.label(
				face,
				if id == leader then "Leader" elseif id then "Crew" else "",
				Theme.Text.small
			)
			role.Position = UDim2.new(0, 8, 0.84, 0)
			role.Size = UDim2.new(1, -16, 0, 26)
			role.TextWrapped = false
		end

		local buttons = Instance.new("Frame")
		buttons.BackgroundTransparency = 1
		buttons.Size = UDim2.new(1, 0, 0, 80)
		buttons.Parent = panel.body
		local row = Style.list(buttons, true, 12)
		row.HorizontalAlignment = Enum.HorizontalAlignment.Center
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		local invite = Style.button(buttons, UDim2.fromOffset(280, 68))
		invite.LayoutOrder = 1
		local _, iFace = Style.block(invite, Style.grad("buy"))
		Style.label(iFace, "Invite", Theme.Text.button)
		Style.press(invite, function()
			task.spawn(function()
				local ok, can = pcall(function()
					return SocialService:CanSendGameInviteAsync(player)
				end)
				if ok and can then
					pcall(function()
						SocialService:PromptGameInvite(player)
					end)
				end
			end)
		end)
		local leave = Style.button(buttons, UDim2.fromOffset(220, 68))
		leave.LayoutOrder = 2
		leave.Visible = #ids > 0
		local _, lFace = Style.block(leave, Style.grad("close"))
		Style.label(lFace, "Leave", Theme.Text.button)
		Style.press(leave, function()
			Net.event("CrewLeave"):FireServer()
		end)
	end

	refresh = function()
		if panel.isOpen() then
			paint()
		end
	end
	Net.event("CrewJoin").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.members) == "table" then
			ids = payload.members
			leader = tonumber(payload.leader) or 0
			refresh()
		end
	end)
	Net.event("CrewLeave").OnClientEvent:Connect(function()
		ids, leader = {}, 0
		refresh()
	end)
	paint()

	return {
		open = function()
			panel.open()
			paint()
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Crew
