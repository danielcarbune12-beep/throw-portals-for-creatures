-- RevealTitle: on-screen title for a creature reveal, styled after Actions/02_Rarity_Reveal_and_Capture.
-- Location: StarterPlayer > StarterPlayerScripts > Client > RevealTitle (ModuleScript)
--
--   Common / Uncommon      nothing on screen: the carved plaque above the pet carries it (restrained tiers)
--   Rare / Epic            header plaque with long gold rules + serif name, high on screen so the pet stays clear
--   Legendary and above    full-screen moment in warm gold light: flash, soft glow, thin turning rays,
--                          a halo ring, laurel plaque, huge serif name with a gold sheen, rising gold sparks
-- Asset free (frames + gradients), never takes input, respects Reduced Motion and graphics quality.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(script.Parent.ClientSettings)
local Plaque = require(script.Parent.Plaque)

local R = {}
local player = Players.LocalPlayer

local THIN = utf8.char(0x2009)
local GOLD = Color3.fromRGB(240, 196, 104)
local GOLD_HI = Color3.fromRGB(255, 236, 170)
local PLUM = Color3.fromRGB(40, 20, 56)
local WHITE = Color3.new(1, 1, 1)

-- letter-spaced caps for small eyebrow lines
function R.Track(s)
	local out = {}
	for _, c in utf8.codes(string.upper(s)) do
		local ch = utf8.char(c)
		table.insert(out, ch == " " and (THIN .. THIN .. THIN) or ch)
	end
	return table.concat(out, THIN)
end

local function quality()
	local ok, q = pcall(function() return UserSettings().GameSettings.SavedQualityLevel.Value end)
	if not ok or q == 0 then return 10 end
	return q
end

local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

local function new(class, props)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
		o.BackgroundTransparency = 1
		pcall(function() o.Interactable = false end)
	end
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	o.Parent = props.Parent
	return o
end

local function montserrat(weight)
	local ok, f = pcall(function() return Font.new("rbxasset://fonts/families/Montserrat.json", weight) end)
	return ok and f or Font.fromEnum(Enum.Font.GothamBold)
end
local SANS = montserrat(Enum.FontWeight.SemiBold)

local function label(parent, s, face, color, props)
	local l = new("TextLabel", {
		Text = s, FontFace = face, TextColor3 = color, TextScaled = true, AnchorPoint = Vector2.new(0.5, 0.5),
		TextTransparency = 1, Parent = parent,
	})
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

local function stroke(l, color, th, tr)
	return new("UIStroke", { Color = color or PLUM, Thickness = th or 2, Transparency = tr or 0.1, Parent = l })
end

-- gold sheen across text: a vertical gold gradient, with one bright highlight sweep on arrival
local function goldSheen(l, delay)
	local base = new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, GOLD_HI), ColorSequenceKeypoint.new(0.55, WHITE), ColorSequenceKeypoint.new(1, GOLD),
		}),
		Parent = l,
	})
	task.delay(delay or 0.5, function()
		if not l.Parent then return end
		base.Enabled = false
		local sweep = new("UIGradient", {
			Rotation = 15, Offset = Vector2.new(-1, 0),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, GOLD), ColorSequenceKeypoint.new(0.45, GOLD_HI),
				ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(0.55, GOLD_HI), ColorSequenceKeypoint.new(1, GOLD),
			}),
			Parent = l,
		})
		tw(sweep, 1.0, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Connect(function()
			if sweep.Parent then sweep:Destroy() end
			base.Enabled = true
		end)
	end)
end

-- long gold rule with a diamond at its inner end (reference header lines)
local function rule(parent, xCenter, y, length, side, delay, z)
	local r = new("Frame", {
		AnchorPoint = Vector2.new(side < 0 and 1 or 0, 0.5), Position = UDim2.new(0.5, xCenter, 0, y),
		Size = UDim2.fromOffset(0, 2), BackgroundColor3 = GOLD, BackgroundTransparency = 0, ZIndex = z, Parent = parent,
	})
	new("UIGradient", { Transparency = NumberSequence.new(side < 0 and 1 or 0, side < 0 and 0 or 1), Parent = r })
	local gem = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, xCenter, 0, y), Size = UDim2.fromOffset(9, 9),
		Rotation = 45, BackgroundColor3 = GOLD, ZIndex = z, Parent = parent,
	})
	task.delay(delay, function()
		if not r.Parent then return end
		tw(r, 0.8, { Size = UDim2.fromOffset(length, 2) }, Enum.EasingStyle.Quint)
		tw(gem, 0.3, { BackgroundTransparency = 0 })
	end)
end

---------------------------------------------------------------- screen
local gui
local current
local function screen()
	if gui and gui.Parent then return gui end
	gui = Instance.new("ScreenGui")
	gui.Name = "TPFC_Reveal"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 35
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local EYEBROW = {
	Legendary = "A legendary discovery",
	Mythical = "A mythical discovery",
	Secret = "A secret revealed",
	Divine = "A divine ascension",
}

---------------------------------------------------------------- Rare / Epic: header plaque
local function header(root, def, chance)
	local view = workspace.CurrentCamera.ViewportSize
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(700, 150), Parent = root })
	new("UIScale", { Scale = math.min(1, (view.X - 24) / 700), Parent = box })
	local plaque = Plaque.Make(box, string.upper(def.rarity), def.rarity, 220, 40, { Position = UDim2.new(0.5, 0, 0, 22), ZIndex = 4 })
	local ps = new("UIScale", { Scale = 0.5, Parent = plaque })
	tw(ps, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	rule(box, -126, 22, 170, -1, 0.15, 3)
	rule(box, 126, 22, 170, 1, 0.15, 3)
	local nm = label(box, def.name, Plaque.SerifHeavy, WHITE, { Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.fromOffset(700, 58), ZIndex = 5 })
	new("UITextSizeConstraint", { MaxTextSize = 54, Parent = nm })
	stroke(nm, PLUM, 3, 0.05)
	local od = label(box, chance and R.Track(chance) or "", SANS, Color3.fromRGB(250, 244, 255), { Position = UDim2.new(0.5, 0, 0, 128), Size = UDim2.fromOffset(500, 18), ZIndex = 5 })
	stroke(od, PLUM, 1.5, 0.2)
	local ns = new("UIScale", { Scale = 1.12, Parent = nm })
	task.delay(0.12, function()
		tw(nm, 0.4, { TextTransparency = 0 })
		tw(ns, 0.6, { Scale = 1 }, Enum.EasingStyle.Quint)
	end)
	task.delay(0.35, function() tw(od, 0.4, { TextTransparency = 0 }) end)
	return 2.8
end

---------------------------------------------------------------- Legendary and above: full screen
local function fullscreen(root, def, chance, order)
	local q = quality()
	local rich = q > 3
	local view = workspace.CurrentCamera.ViewportSize
	local D = math.max(view.X, view.Y) * 1.5
	local accent = (Config.Rarities[def.rarity] and Config.Rarities[def.rarity].color) or GOLD
	if def.rarity == "Secret" then accent = Color3.fromRGB(150, 222, 238) end
	local light = GOLD:Lerp(accent, 0.35)
	local conns = {}
	local center = UDim2.fromScale(0.5, 0.3)

	-- warm flash, then a gentle top/bottom shade so gold reads over any sky
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 244, 214), BackgroundTransparency = 0.05, ZIndex = 20, Parent = root })
	tw(flash, 0.9, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	for _, top in ipairs({ true, false }) do
		local e = new("Frame", {
			AnchorPoint = Vector2.new(0, top and 0 or 1), Position = UDim2.fromScale(0, top and 0 or 1), Size = UDim2.fromScale(1, top and 0.55 or 0.3),
			BackgroundColor3 = Color3.fromRGB(26, 14, 36), ZIndex = 1, Parent = root,
		})
		new("UIGradient", { Rotation = top and 90 or 270, Transparency = NumberSequence.new(0.35, 1), Parent = e })
		tw(e, 0.6, { BackgroundTransparency = 0 })
	end

	-- soft radial glow (many faint ellipses = smooth falloff)
	for i = 1, 10 do
		local d = D * (0.04 + i * 0.035)
		local c = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.fromOffset(d, d * 0.7),
			BackgroundColor3 = light, ZIndex = 2, Parent = root })
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = c })
		tw(c, 0.7, { BackgroundTransparency = 0.94 })
	end

	-- thin turning rays
	if rich then
		local rays = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.fromOffset(D, D), ZIndex = 2, Parent = root })
		local N = order >= 7 and 14 or 12
		for i = 1, N do
			local bar = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, D * (i % 2 == 0 and 0.008 or 0.016), 1, 0), Rotation = (i - 1) * 180 / N,
				BackgroundColor3 = GOLD_HI, ZIndex = 2, Parent = rays,
			})
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.96), NumberSequenceKeypoint.new(0.5, 0.55),
				NumberSequenceKeypoint.new(0.7, 0.96), NumberSequenceKeypoint.new(1, 1),
			}), Parent = bar })
			tw(bar, 0.9, { BackgroundTransparency = 0 })
		end
		local sc = new("UIScale", { Scale = 0.5, Parent = rays })
		tw(sc, 1.4, { Scale = 1 }, Enum.EasingStyle.Quint)
		table.insert(conns, RunService.RenderStepped:Connect(function(dt) rays.Rotation += 5 * dt end))
	end

	-- halo ring behind the name (reference: thin gold ring with a diamond crest)
	local haloD = math.min(view.Y * 0.62, 520)
	local halo = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.fromOffset(haloD * 1.5, haloD * 0.46), ZIndex = 3, Parent = root })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = halo })
	local hs = new("UIStroke", { Color = GOLD_HI, Thickness = 3, Transparency = 1, Parent = halo })
	local crest = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(16, 16), Rotation = 45,
		BackgroundColor3 = GOLD_HI, ZIndex = 3, Parent = halo })
	local hsc = new("UIScale", { Scale = 0.6, Parent = halo })
	tw(hsc, 1.0, { Scale = 1 }, Enum.EasingStyle.Quint)
	tw(hs, 0.6, { Transparency = 0.15 })
	tw(crest, 0.6, { BackgroundTransparency = 0 })

	-- rising gold sparks
	if rich then
		local count = q >= 7 and 40 or 20
		for _ = 1, count do
			task.delay(math.random() * 1.8, function()
				if not root.Parent then return end
				local s = math.random(4, 10)
				local x, y = 0.15 + math.random() * 0.7, 0.3 + math.random() * 0.6
				local sp = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(s, s), Rotation = 45,
					BackgroundColor3 = math.random() < 0.5 and WHITE or GOLD_HI, ZIndex = 4, Parent = root,
				})
				local life = 1.3 + math.random() * 1.2
				tw(sp, 0.25, { BackgroundTransparency = 0.05 })
				tw(sp, life, { Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.05, y - 0.22 - math.random() * 0.2) }, Enum.EasingStyle.Sine)
				task.delay(life * 0.6, function()
					if sp.Parent then tw(sp, life * 0.4, { BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1) }) end
				end)
				task.delay(life + 0.1, function() sp:Destroy() end)
			end)
		end
	end

	-- typography block, centred on the halo
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.fromOffset(1000, 260), ZIndex = 6, Parent = root })
	new("UIScale", { Scale = math.min(1, (view.X - 24) / 1000), Parent = box })
	local eb = label(box, R.Track(EYEBROW[def.rarity] or "A rare discovery"), SANS, GOLD_HI, { Position = UDim2.new(0.5, 0, 0, 18), Size = UDim2.fromOffset(600, 18), ZIndex = 7 })
	stroke(eb, PLUM, 1.5, 0.25)
	local plaque = Plaque.Make(box, string.upper(def.rarity), def.rarity, 260, 46, { Position = UDim2.new(0.5, 0, 0, 62), ZIndex = 8, Font = Plaque.SerifHeavy })
	local ps = new("UIScale", { Scale = 0.4, Parent = plaque })
	task.delay(0.2, function() tw(ps, 0.55, { Scale = 1 }, Enum.EasingStyle.Back) end)
	local nm = label(box, def.name, Plaque.SerifHeavy, WHITE, { Position = UDim2.new(0.5, 0, 0, 146), Size = UDim2.fromOffset(1000, 104), ZIndex = 9 })
	new("UITextSizeConstraint", { MaxTextSize = 96, Parent = nm })
	stroke(nm, PLUM, 4, 0)
	goldSheen(nm, 0.7)
	local od = label(box, chance and R.Track(chance) or "", SANS, WHITE, { Position = UDim2.new(0.5, 0, 0, 222), Size = UDim2.fromOffset(600, 20), ZIndex = 9 })
	stroke(od, PLUM, 1.5, 0.2)
	rule(box, -170, 222, 150, -1, 0.7, 7)
	rule(box, 170, 222, 150, 1, 0.7, 7)
	local ns = new("UIScale", { Scale = 1.3, Parent = nm })
	task.delay(0.15, function()
		tw(nm, 0.4, { TextTransparency = 0 })
		tw(ns, 1.0, { Scale = 1 }, Enum.EasingStyle.Quint)
	end)
	task.delay(0.35, function() tw(eb, 0.5, { TextTransparency = 0 }) end)
	task.delay(0.65, function() tw(od, 0.5, { TextTransparency = 0 }) end)

	local hold = ({ [5] = 3.2, [6] = 3.6 })[order] or 4.0
	task.delay(hold + 0.6, function()
		for _, c in ipairs(conns) do c:Disconnect() end
	end)
	return hold
end

---------------------------------------------------------------- entry
-- def: CreatureData entry; chanceText: "1 in 2,500" (optional)
function R.Show(def, chanceText)
	local order = (Config.Rarities[def.rarity] or Config.Rarities.Common).order
	if order < 3 then return end -- restrained tiers: the world plaque above the pet is enough
	if current then current:Destroy() end
	local root = new("Frame", { Name = "Reveal", Size = UDim2.fromScale(1, 1), Parent = screen() })
	current = root
	local hold
	if order >= 5 and not Settings.ReducedMotion then
		hold = fullscreen(root, def, chanceText, order)
	else
		hold = header(root, def, chanceText)
	end
	task.delay(hold, function()
		if not root.Parent then return end
		Plaque.Fade(root, 1, 0.45, tw)
		task.delay(0.5, function() root:Destroy() end)
	end)
end

return R
