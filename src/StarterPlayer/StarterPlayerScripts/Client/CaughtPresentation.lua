-- Caught card for an already confirmed catch, styled after Actions/02_Rarity_Reveal_and_Capture ("03 ADDED"):
-- purple card with a double gold frame and diamond crest, light rays behind the pet, the creature's name,
-- a "CAUGHT" ribbon with laurels, an "ADDED TO PETS" plaque, then the card flies into the live Pets button.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Data = require(RS.Shared.CreatureData)
local Config = require(RS.Shared.Config)
local Format = require(RS.Shared.Format)
local Timeline = require(RS.Shared.PresentationTimeline)
local K = require(script.Parent.UIKit)
local T = K.Theme
local HUD = require(script.Parent.HUD)
local Renderer = require(script.Parent.CreatureRenderer)
local Settings = require(script.Parent.ClientSettings)
local Plaque = require(script.Parent.Plaque)

local GOLD = Color3.fromRGB(232, 188, 98)
local GOLD_HI = Color3.fromRGB(255, 234, 168)
local PLUM = Color3.fromRGB(40, 20, 56)
local W, H = 300, 392

local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(Settings.ReducedMotion and 0 or t, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do f[k] = v end
	f.Parent = parent
	return f
end

local function montserrat(weight)
	local ok, f = pcall(function() return Font.new("rbxasset://fonts/families/Montserrat.json", weight) end)
	return ok and f or Font.fromEnum(Enum.Font.GothamBold)
end

return function(id)
	local def = Data.ById[id]
	if not def then
		return
	end
	if HUD.AnyPanelOpen() then
		HUD.Notify("Caught " .. def.name .. ". Added to your creatures.", "success")
		return
	end
	local rarityColor = T.Rarity(def.rarity, Config)

	local card = frame(HUD.Root, {
		Name = "CatchReceipt", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 30,
	})
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(196, 170, 246)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(150, 104, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(86, 44, 150)),
	})
	g.Parent = card
	local outer = Instance.new("UIStroke")
	outer.Color = GOLD
	outer.Thickness = 4
	outer.Parent = card
	-- inner gold hairline frame
	local inner = frame(card, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -16, 1, -16),
		BackgroundTransparency = 1, ZIndex = 31,
	})
	Instance.new("UICorner", inner).CornerRadius = UDim.new(0, 9)
	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = GOLD_HI
	innerStroke.Thickness = 1.5
	innerStroke.Transparency = 0.25
	innerStroke.Parent = inner

	-- light rays behind the pet, clipped to the portrait window
	local window = frame(card, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(W - 36, 196),
		BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 32,
	})
	local rays = frame(window, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(420, 420),
		BackgroundTransparency = 1, ZIndex = 32,
	})
	for i = 1, 10 do
		local bar = frame(rays, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, i % 2 == 0 and 10 or 22, 1, 0),
			Rotation = (i - 1) * 18, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 32,
		})
		local bg = Instance.new("UIGradient")
		bg.Rotation = 90
		bg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.9), NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.65, 0.9), NumberSequenceKeypoint.new(1, 1),
		})
		bg.Parent = bar
	end
	local glow = frame(window, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(200, 120),
		BackgroundColor3 = Color3.fromRGB(255, 246, 220), BackgroundTransparency = 0.55, ZIndex = 32,
	})
	Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
	gg.Parent = glow

	local vp = K.viewport(Renderer.BuildPreview(id), UDim2.fromOffset(W - 36, 196), false)
	vp.AnchorPoint = Vector2.new(0.5, 0)
	vp.Position = UDim2.new(0.5, 0, 0, 58)
	vp.ZIndex = 33
	vp.Parent = card

	-- diamond crest on the top edge
	local crest = frame(card, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(34, 34), Rotation = 45,
		BackgroundColor3 = GOLD, ZIndex = 36,
	})
	local cs = Instance.new("UIStroke")
	cs.Color = GOLD_HI
	cs.Thickness = 2
	cs.Parent = crest
	frame(crest, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.fromRGB(120, 66, 196), ZIndex = 37,
	})

	-- name + rarity/income
	local name = Instance.new("TextLabel")
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 0, 0, 22)
	name.Size = UDim2.fromOffset(W - 40, 32)
	name.BackgroundTransparency = 1
	name.FontFace = Plaque.SerifHeavy
	name.TextScaled = true
	name.Text = def.name
	name.TextColor3 = Color3.new(1, 1, 1)
	name.ZIndex = 36
	local ns = Instance.new("UIStroke")
	ns.Color = PLUM
	ns.Thickness = 2
	ns.Transparency = 0.1
	ns.Parent = name
	name.Parent = card

	local info = Instance.new("TextLabel")
	info.AnchorPoint = Vector2.new(0.5, 0)
	info.Position = UDim2.new(0.5, 0, 0, 258)
	info.Size = UDim2.fromOffset(W - 40, 18)
	info.BackgroundTransparency = 1
	info.FontFace = montserrat(Enum.FontWeight.Bold)
	info.TextScaled = true
	info.RichText = true
	info.Text = string.format('<font color="#%s">%s</font>   ·   %s / sec', rarityColor:Lerp(Color3.new(1, 1, 1), 0.6):ToHex(), string.upper(def.rarity), Format.Money(Data.Income(id)))
	info.TextColor3 = Color3.new(1, 1, 1)
	info.ZIndex = 36
	local is = Instance.new("UIStroke")
	is.Color = PLUM
	is.Thickness = 1.5
	is.Transparency = 0.2
	is.Parent = info
	info.Parent = card

	-- CAUGHT ribbon with laurels, ADDED TO PETS plaque
	local ribbon = Plaque.Make(card, "CAUGHT", "Caught", 214, 42, { Position = UDim2.new(0.5, 0, 0, 308), ZIndex = 37, Font = Plaque.SerifHeavy })
	Plaque.Laurel(ribbon, -6, 21, 40, -1, GOLD, 36)
	Plaque.Laurel(ribbon, 220, 21, 40, 1, GOLD, 36)
	Plaque.Make(card, "ADDED TO PETS", "Ivory", 200, 32, { Position = UDim2.new(0.5, 0, 0, 356), ZIndex = 37 })

	-- enter
	local scale = Instance.new("UIScale")
	scale.Scale = Settings.ReducedMotion and 1 or 0.7
	scale.Parent = card
	tw(scale, Timeline.Card.enter, { Scale = 1 }, Enum.EasingStyle.Back)
	local spin
	if not Settings.ReducedMotion then
		spin = game:GetService("RunService").RenderStepped:Connect(function(dt)
			rays.Rotation += 8 * dt
		end)
	end

	-- hold, then fly into the live Pets button
	task.delay(Timeline.Card.enter + Timeline.Card.hold, function()
		if not card.Parent then
			if spin then spin:Disconnect() end
			return
		end
		local pets = HUD.SideButtons.Pets
		local travel = Timeline.Card.travel or 0.45
		if pets and pets.Visible and not Settings.ReducedMotion then
			local rootAbs = HUD.Root.AbsolutePosition
			local target = pets.AbsolutePosition + pets.AbsoluteSize / 2 - rootAbs
			card.AnchorPoint = Vector2.new(0.5, 0.5)
			tw(card, travel, { Position = UDim2.fromOffset(target.X, target.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tw(scale, travel, { Scale = 0.12 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(travel * 0.6, function()
				if card.Parent then Plaque.Fade(card, 1, travel * 0.4, tw) end
			end)
		else
			Plaque.Fade(card, 1, 0.3, tw)
		end
		task.delay(travel + 0.05, function()
			if spin then spin:Disconnect() end
			if card.Parent then card:Destroy() end
			if pets and pets.Visible then K.pop(pets) end
		end)
	end)
end
