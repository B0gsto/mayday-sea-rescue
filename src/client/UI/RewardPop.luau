--!strict
-- RewardPop (FX2b): the two screen layers behind a reward moment (medal flip, skill unlock, coins landing):
--   RewardPop.rays(parent, at, size, time)   a gold sunburst that swells in, turns slowly and fades out
--   RewardPop.stars(parent, at, radius, n)   gold star stickers thrown out round a point, spinning, then gone
--   RewardPop.shards(parent, at, radius, n, color)  flat rounded plates knocked off (a lock breaking), falling
-- Claude SVG stickers (UiImages.Badges.Rays / StarOn). Callers skip them under Reduce motion. Client only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
)

local RewardPop = {}

local function sticker(
	parent: Instance,
	image: string,
	at: Vector2,
	size: number,
	z: number
): ImageLabel
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromOffset(at.X, at.Y)
	img.Size = UDim2.fromOffset(size, size)
	img.Image = image
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = z
	img.Parent = parent
	return img
end

function RewardPop.rays(parent: Instance, at: Vector2, size: number, time: number): ImageLabel
	local img = sticker(parent, UiImages.Badges.Rays, at, size, 0)
	img.ImageTransparency = 1
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = img
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(img, TweenInfo.new(0.15), { ImageTransparency = 0.1 }):Play()
	TweenService:Create(img, TweenInfo.new(time, Enum.EasingStyle.Linear), { Rotation = 40 * time })
		:Play()
	-- a second tween on one property cancels the first even while it waits out a delay: start it later
	task.delay(math.max(time - 0.3, 0.15), function()
		TweenService
			:Create(img, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				ImageTransparency = 1,
			})
			:Play()
	end)
	task.delay(time + 0.05, img.Destroy, img)
	return img
end

function RewardPop.stars(parent: Instance, at: Vector2, radius: number, n: number)
	for i = 1, n do
		local a = (i / n + math.random() * 0.08) * math.pi * 2
		local d = radius * (0.75 + math.random() * 0.4)
		local size = radius * (0.32 + math.random() * 0.12)
		local star = sticker(parent, UiImages.Badges.StarOn, at, size, 3)
		star.Rotation = math.random(-30, 30)
		local sc = Instance.new("UIScale")
		sc.Scale = 0.2
		sc.Parent = star
		local out = TweenInfo.new(0.45, Enum.EasingStyle.Quint)
		TweenService:Create(star, out, {
			Position = UDim2.fromOffset(at.X + math.cos(a) * d, at.Y + math.sin(a) * d),
			Rotation = star.Rotation + math.random(-140, 140),
		}):Play()
		TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(0.4, function()
			TweenService
				:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Scale = 0,
				})
				:Play()
		end)
		task.delay(0.7, star.Destroy, star)
	end
end

function RewardPop.shards(parent: Instance, at: Vector2, radius: number, n: number, color: Color3)
	for i = 1, n do
		local a = (i / n + math.random() * 0.1) * math.pi * 2
		local plate = Instance.new("Frame")
		plate.AnchorPoint = Vector2.new(0.5, 0.5)
		plate.Position = UDim2.fromOffset(at.X, at.Y)
		plate.Size = UDim2.fromOffset(radius * 0.22, radius * 0.16)
		plate.BackgroundColor3 = color
		plate.BorderSizePixel = 0
		plate.ZIndex = 3
		plate.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = plate
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.fromHex("14121C")
		edge.Thickness = 2
		edge.Parent = plate
		local d = radius * (0.7 + math.random() * 0.4)
		-- out, then down (a hop off the art), turning and fading
		local fall = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
		TweenService:Create(plate, fall, {
			Position = UDim2.fromOffset(
				at.X + math.cos(a) * d,
				at.Y + math.sin(a) * d * 0.6 + radius * 0.5
			),
			Rotation = math.random(-200, 200),
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(edge, fall, { Transparency = 1 }):Play()
		task.delay(0.55, plate.Destroy, plate)
	end
end

return RewardPop
