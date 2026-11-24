-- The caught-creature showcase: a big card in the middle of the screen right after a catch.
-- The creature turns slowly in 3D in front of spinning rays in its rarity colour, with a ribbon
-- ("NEW SPECIES!" or "CAUGHT!"), its name, rarity stars, health, attack and income. It pops in,
-- holds (longer for rarer pets), then shrinks away toward the bottom of the screen. Click to dismiss.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(RS.Shared.Config)
local Data = require(RS.Shared.CreatureData)
local Timeline = require(RS.Shared.PresentationTimeline)
local Variants = require(RS.Shared.Variants)
local Format = require(RS.Shared.Format)
local PetCombat = require(RS.Shared.PetCombat)
local PetGear = require(RS.Shared.PetGear)
local K = require(script.Parent.UIKit)
local T = K.Theme
local HUD = require(script.Parent.HUD)
local Renderer = require(script.Parent.CreatureRenderer)
local Settings = require(script.Parent.ClientSettings)
local Sounds = require(script.Parent.Sounds)

local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(Settings.ReducedMotion and math.min(t, 0.1) or t, style or Enum.EasingStyle.Quart,
		dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

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
	local rc = Config.Rarities[def.rarity]
	local order = rc and rc.order or 1
	local color = def.rarity == "Secret" and Color3.fromRGB(0, 255, 200) or (rc and rc.color or Color3.new(1, 1, 1))
	local vcol = Variants.Color(size, material)
	local compact = workspace.CurrentCamera.ViewportSize.Y < 520
	local W, H = compact and 300 or 380, compact and 400 or 500

	local root = K.new("Frame", { Name = "CatchReceipt", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, ZIndex = 30, Parent = HUD.Root })
	root:SetAttribute("Discovery", discovery == true)
	local scale = K.new("UIScale", { Scale = 0.2, Parent = root })

	-- spinning rays and a soft glow behind the creature
	local glow = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(1.3, 1.05),
		BackgroundColor3 = color, BackgroundTransparency = 0.55, ZIndex = 30, Parent = root })
	K.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = glow })
	K.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.6),
		NumberSequenceKeypoint.new(1, 1) }), Parent = glow })
	local rays = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(W * 1.5, W * 1.5),
		BackgroundTransparency = 1, ZIndex = 30, Parent = root })
	for i = 0, 11 do
		local ray = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 26, 0.5, 0),
			Rotation = i * 30, BackgroundColor3 = color, BackgroundTransparency = 0.6, ZIndex = 30, Parent = rays })
		K.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.2), Parent = ray })
	end

	-- the card itself
	local card = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, H * 0.08), Size = UDim2.new(0.86, 0, 0.9, 0),
		BackgroundColor3 = Color3.fromRGB(22, 18, 34), BackgroundTransparency = 0.12, ZIndex = 31, Parent = root })
	K.new("UICorner", { CornerRadius = UDim.new(0, 18), Parent = card })
	K.new("UIStroke", { Color = color, Thickness = 3, Parent = card })
	K.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(60, 50, 90), Color3.fromRGB(18, 14, 28)), Parent = card })

	-- ribbon
	local ribbon = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.8, 0, 0, compact and 38 or 46),
		BackgroundColor3 = discovery and Color3.fromRGB(255, 196, 60) or color, ZIndex = 34, Parent = card })
	K.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = ribbon })
	K.new("UIStroke", { Color = Color3.fromRGB(20, 14, 30), Thickness = 2, Parent = ribbon })
	K.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = discovery and "NEW SPECIES!" or "CAUGHT!",
		Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.2, ZIndex = 35, Parent = ribbon })

	-- the creature, big and turning
	local okModel, model = pcall(Renderer.BuildPreview, id, material)
	if okModel and model then
		local vp = K.viewport(model, UDim2.new(1, -20, 0.52, 0), true, false, true)
		vp.Position = UDim2.new(0, 10, 0.07, 0)
		vp.ZIndex = 33
		vp.Parent = card
	end

	-- name, rarity stars, stats
	local name = K.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0.6, 0), Size = UDim2.new(1, -20, 0.1, 0),
		Text = Variants.Prefix(size, material) .. def.name, Font = Enum.Font.GothamBlack, TextScaled = true,
		TextColor3 = vcol and vcol:Lerp(Color3.new(1, 1, 1), 0.25) or Color3.new(1, 1, 1), ZIndex = 33, Parent = card })
	K.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.3, Parent = name })
	local stars = string.rep("★", math.min(order, 8))
	K.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0.705, 0), Size = UDim2.new(1, -20, 0.07, 0),
		Text = string.upper(def.rarity) .. "   " .. stars, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = color,
		TextStrokeTransparency = 0.4, ZIndex = 33, Parent = card })
	local hp, atk = PetCombat.Stats({ c = id, s = size, v = material })
	local income = Data.Income(id) * Variants.Mult(size, material)
	local stats = K.new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0.8, 0), Size = UDim2.new(1, -28, 0.13, 0), ZIndex = 33, Parent = card })
	K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8), Parent = stats })
	for _, s in ipairs({
		{ "HP", PetGear.Short(hp), Color3.fromRGB(96, 214, 110) },
		{ "ATK", PetGear.Short(atk), Color3.fromRGB(255, 170, 90) },
		{ "INCOME", Format.Money(income) .. "/s", Color3.fromRGB(150, 230, 255) },
	}) do
		local chip = K.new("Frame", { Size = UDim2.new(0.31, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(40, 34, 58), ZIndex = 33, Parent = stats })
		K.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = chip })
		K.new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.4), Text = s[1], Font = Enum.Font.GothamBold, TextScaled = true,
			TextColor3 = s[3], ZIndex = 34, Parent = chip })
		K.new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.38), Size = UDim2.fromScale(1, 0.58), Text = s[2],
			Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = 34, Parent = chip })
	end
	local hint = K.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.new(1, 0, 0, 16), Text = "click to continue", Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = Color3.fromRGB(220, 215, 235), TextTransparency = 0.3, TextStrokeTransparency = 0.6, ZIndex = 33, Parent = card })

	-- pop in with a bounce, spin the rays, then fly away
	local closed = false
	local spin = RunService.RenderStepped:Connect(function(dt)
		if not root.Parent then return end
		rays.Rotation = (rays.Rotation + dt * (12 + order * 3)) % 360
		glow.BackgroundTransparency = 0.55 + math.sin(os.clock() * 3) * 0.08
	end)
	local function close()
		if closed then return end
		closed = true
		tw(scale, Timeline.Card.travel, { Scale = 0.15 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tw(root, Timeline.Card.travel, { Position = UDim2.new(0.5, 0, 1, -40) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(Timeline.Card.travel + 0.05, function()
			spin:Disconnect()
			root:Destroy()
		end)
	end
	local clicker = K.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = root })
	clicker.Activated:Connect(close)
	root.Destroying:Connect(function()
		spin:Disconnect()
	end)
	tw(scale, Timeline.Card.enter, { Scale = 1 }, Enum.EasingStyle.Back)
	pcall(Sounds.Play, discovery and "Rare" or "Collect", discovery and 1.1 or 1)
	local hold = Timeline.Card.hold + (order >= 5 and 0.8 or (order >= 3 and 0.3 or 0))
	task.delay(Timeline.Card.enter + hold, close)
	hint.Visible = true
end
