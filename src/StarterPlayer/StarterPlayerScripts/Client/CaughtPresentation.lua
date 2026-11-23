-- A brief bestiary slip for discoveries and Rare+ catches. Routine catches stay quiet.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Data = require(RS.Shared.CreatureData)
local Timeline = require(RS.Shared.PresentationTimeline)
local Variants = require(RS.Shared.Variants)
local K = require(script.Parent.UIKit)
local HUD = require(script.Parent.HUD)
local Renderer = require(script.Parent.CreatureRenderer)
local Settings = require(script.Parent.ClientSettings)
local Plaque = require(script.Parent.Plaque)

return function(key, discovery)
	local id, size, material = Variants.Parse(key)
	local def = Data.ById[id]
	if not def or not Timeline.ShouldPresent(def.rarity, discovery) or HUD.AnyPanelOpen() then
		return
	end
	local old = HUD.Root:FindFirstChild("CatchReceipt")
	if old then
		old:Destroy()
	end
	local slip = Instance.new("CanvasGroup")
	local compact = workspace.CurrentCamera.ViewportSize.Y < 480
	local width, slipHeight = compact and 220 or 272, compact and 64 or 80
	slip.Name = "CatchReceipt"
	slip.AnchorPoint = Vector2.new(0.5, 1)
	slip.Position = UDim2.new(0.5, 0, 1, -20)
	slip.Size = UDim2.fromOffset(width, slipHeight)
	slip.BackgroundColor3 = Color3.fromRGB(230, 220, 193)
	slip.BorderSizePixel = 0
	slip.GroupTransparency = Settings.ReducedMotion and 0 or 1
	slip.ZIndex = 30
	slip:SetAttribute("Discovery", discovery == true)
	slip.Parent = HUD.Root
	Instance.new("UICorner", slip).CornerRadius = UDim.new(0, 3)
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(131, 108, 65)
	edge.Thickness = 1
	edge.Parent = slip
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 250, 230), Color3.fromRGB(205, 191, 155))
	gradient.Rotation = 100
	gradient.Parent = slip
	local portraitSize = compact and 52 or 64
	local portrait = K.viewport(
		Renderer.BuildPreview(id, material),
		UDim2.fromOffset(portraitSize, portraitSize),
		false,
		false,
		true
	)
	portrait.Position = UDim2.fromOffset(6, compact and 6 or 8)
	portrait.ZIndex = 31
	portrait.Parent = slip
	local function line(name, text, y, height, sizePx, color, font)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		local left = compact and 66 or 80
		l.Position = UDim2.fromOffset(left, y)
		l.Size = UDim2.new(1, -left - 12, 0, height)
		l.Text = text
		l.TextSize = sizePx
		l.TextColor3 = color
		l.FontFace = font
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.ZIndex = 31
		l.Parent = slip
	end
	line(
		"Status",
		discovery and "NEW SPECIES" or "ADDED TO PETS",
		compact and 7 or 10,
		compact and 12 or 14,
		compact and 9 or 10,
		Color3.fromRGB(90, 79, 51),
		Font.fromEnum(Enum.Font.GothamBold)
	)
	line(
		"PetName",
		Variants.Prefix(size, material) .. def.name,
		compact and 21 or 26,
		compact and 22 or 25,
		compact and 18 or 20,
		Color3.fromRGB(49, 49, 39),
		Plaque.SerifHeavy
	)
	line(
		"Rarity",
		def.rarity,
		compact and 44 or 54,
		compact and 13 or 15,
		compact and 11 or 12,
		Color3.fromRGB(77, 82, 63),
		Font.fromEnum(Enum.Font.GothamMedium)
	)
	local function fade(value, duration)
		TweenService:Create(
			slip,
			TweenInfo.new(Settings.ReducedMotion and 0 or duration, Enum.EasingStyle.Quad),
			{ GroupTransparency = value }
		):Play()
	end
	fade(0, Timeline.Card.enter)
	task.delay(Timeline.Card.enter + Timeline.Card.hold, function()
		if not slip.Parent then
			return
		end
		fade(1, Timeline.Card.travel)
		task.delay(Timeline.Card.travel, function()
			slip:Destroy()
		end)
	end)
end
