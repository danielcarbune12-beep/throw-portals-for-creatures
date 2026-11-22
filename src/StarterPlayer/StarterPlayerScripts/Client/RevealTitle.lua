-- RevealTitle: cinematic title cards for a creature reveal, scaled to how rare the find is.
-- Location: StarterPlayer > StarterPlayerScripts > Client > RevealTitle (ModuleScript)
--
--   Common / Uncommon      quiet lower caption (tracked rarity eyebrow, name, odds)
--   Rare / Epic            gold-rule title card with a light sweep across the name
--   Legendary and above    full-screen moment: flash, veil, turning light rays, shock rings,
--                          rising sparkles, huge name with a shine sweep, then a clean fade
-- Asset free (frames + gradients only), never takes input, respects Reduced Motion and quality.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local T = require(script.Parent.UITheme)
local Settings = require(script.Parent.ClientSettings)

local R = {}
local player = Players.LocalPlayer

local function font(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	return (ok and f) or fallback
end
local F = {
	Black = font("MontserratBlack", Enum.Font.GothamBlack),
	Bold = font("MontserratBold", Enum.Font.GothamBold),
	Medium = font("MontserratMedium", Enum.Font.GothamMedium),
}
local GOLD = T.Gold
local TextService = game:GetService("TextService")
local function halfWidth(s, size, fnt)
	local ok, v = pcall(function() return TextService:GetTextSize(s, size, fnt, Vector2.new(4000, 200)).X end)
	return (ok and v or #s * size * 0.6) / 2 + 18
end
local INK = Color3.fromRGB(10, 8, 18)
local THIN = utf8.char(0x2009)

-- letter-spaced caps ("L E G E N D A R Y"), the trailer-title look
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

local function text(parent, s, fnt, color, props)
	local l = new("TextLabel", {
		Text = s, Font = fnt, TextColor3 = color, TextScaled = true, RichText = false,
		AnchorPoint = Vector2.new(0.5, 0.5), TextTransparency = 1, Parent = parent,
	})
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

local function maxSize(l, px)
	new("UITextSizeConstraint", { MaxTextSize = px, Parent = l })
end

-- soft dark shadow under text: a blurred-looking stroke
local function shadow(l, th, tr)
	return new("UIStroke", { Color = INK, Thickness = th or 2, Transparency = tr or 0.35, Parent = l })
end

-- a moving highlight across text (UIGradient offset sweep)
local function shine(l, base, tint, delay, dur)
	local g = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, base), ColorSequenceKeypoint.new(0.42, base),
			ColorSequenceKeypoint.new(0.5, tint), ColorSequenceKeypoint.new(0.58, base), ColorSequenceKeypoint.new(1, base),
		}),
		Offset = Vector2.new(-1, 0), Rotation = 12, Parent = l,
	})
	task.delay(delay or 0.3, function()
		if g.Parent then tw(g, dur or 0.9, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) end
	end)
	return g
end

-- two gold hairlines that draw outward from the centre
local function rules(parent, y, width, color, delay, gap)
	local out = {}
	for side = -1, 1, 2 do
		local r = new("Frame", {
			AnchorPoint = Vector2.new(side < 0 and 1 or 0, 0.5),
			Position = UDim2.new(0.5, side * (gap or 14), y, 0), Size = UDim2.new(0, 0, 0, 1),
			BackgroundColor3 = color, BackgroundTransparency = 0, Parent = parent,
		})
		new("UIGradient", {
			Transparency = NumberSequence.new(side < 0 and 1 or 0, side < 0 and 0 or 1), Parent = r,
		})
		task.delay(delay or 0, function()
			if r.Parent then tw(r, 0.7, { Size = UDim2.new(width, 0, 0, 1) }, Enum.EasingStyle.Quint) end
		end)
		table.insert(out, r)
	end
	return out
end

local function fadeOut(root, t)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextLabel") then tw(d, t, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then tw(d, t, { Transparency = 1 })
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then tw(d, t, { BackgroundTransparency = 1 }) end
	end
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
	Legendary = "Legendary discovery",
	Mythical = "Mythical discovery",
	Secret = "Secret creature found",
	Divine = "Divine ascension",
}

---------------------------------------------------------------- tiers
local function caption(root, def, accent, chance)
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.new(0.9, 0, 0, 92), Parent = root })
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 92), Parent = box })
	local band = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 1, Parent = box })
	new("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.5), NumberSequenceKeypoint.new(0.75, 0.5), NumberSequenceKeypoint.new(1, 1),
	}), Parent = band })
	local eb = text(box, R.Track(def.rarity), F.Bold, accent, { Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.new(1, 0, 0, 14) })
	local nm = text(box, def.name, F.Black, T.Text, { Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(1, 0, 0, 32) })
	shadow(nm, 1.5)
	local od = text(box, chance and R.Track(chance) or "", F.Medium, T.Muted, { Position = UDim2.fromScale(0.5, 0.84), Size = UDim2.new(1, 0, 0, 13) })
	local sc = new("UIScale", { Scale = 0.96, Parent = box })
	tw(sc, 0.4, { Scale = 1 })
	tw(band, 0.3, { BackgroundTransparency = 0 })
	for i, l in ipairs({ eb, nm, od }) do
		task.delay(0.05 * i, function() tw(l, 0.35, { TextTransparency = 0 }) end)
	end
	return 2.1
end

local function card(root, def, accent, chance)
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.74), Size = UDim2.new(0.9, 0, 0, 150), Parent = root })
	new("UISizeConstraint", { MaxSize = Vector2.new(720, 150), Parent = box })
	local band = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, Parent = box })
	new("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.42), NumberSequenceKeypoint.new(0.8, 0.42), NumberSequenceKeypoint.new(1, 1),
	}), Parent = band })
	tw(band, 0.01, { BackgroundTransparency = 0 })
	local eb = text(box, R.Track("New creature"), F.Bold, GOLD, { Position = UDim2.fromScale(0.5, 0.16), Size = UDim2.new(1, 0, 0, 14) })
	rules(box, 0.16, 0.2, GOLD, 0.1, halfWidth(eb.Text, 14, F.Bold))
	local nm = text(box, def.name, F.Black, Color3.new(1, 1, 1), { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 56) })
	maxSize(nm, 56)
	shadow(nm, 2.5)
	shine(nm, T.Text, accent:Lerp(Color3.new(1, 1, 1), 0.35), 0.35, 0.9)
	local od = text(box, R.Track(def.rarity .. (chance and ("   ·   " .. chance) or "")), F.Bold, accent, { Position = UDim2.fromScale(0.5, 0.84), Size = UDim2.new(1, 0, 0, 15) })
	local sc = new("UIScale", { Scale = 1.08, Parent = nm })
	tw(sc, 0.6, { Scale = 1 }, Enum.EasingStyle.Quint)
	tw(eb, 0.4, { TextTransparency = 0 })
	task.delay(0.1, function() tw(nm, 0.45, { TextTransparency = 0 }) end)
	task.delay(0.3, function() tw(od, 0.4, { TextTransparency = 0 }) end)
	return 2.8
end

local function fullscreen(root, def, accent, chance, order)
	local q = quality()
	local rich = q > 3
	local view = workspace.CurrentCamera.ViewportSize
	local D = math.max(view.X, view.Y) * 1.6
	local conns = {}

	-- veil + flash
	local veil = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 1, ZIndex = 1, Parent = root })
	tw(veil, 0.5, { BackgroundTransparency = order >= 7 and 0.22 or 0.34 })
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.6), BackgroundTransparency = 0.15, ZIndex = 9, Parent = root })
	tw(flash, 0.7, { BackgroundTransparency = 1 })

	-- edge glow in the rarity colour (top and bottom gradients)
	for _, top in ipairs({ true, false }) do
		local e = new("Frame", {
			AnchorPoint = Vector2.new(0, top and 0 or 1), Position = UDim2.fromScale(0, top and 0 or 1),
			Size = UDim2.fromScale(1, 0.32), BackgroundColor3 = accent, BackgroundTransparency = 1, ZIndex = 2, Parent = root,
		})
		new("UIGradient", { Rotation = top and 90 or 270, Transparency = NumberSequence.new(0.55, 1), Parent = e })
		tw(e, 0.8, { BackgroundTransparency = 0 })
	end

	-- light rays turning slowly behind the name
	local center = UDim2.fromScale(0.5, 0.46)
	if rich then
		local rays = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.fromOffset(D, D), ZIndex = 2, Parent = root })
		local N = order >= 7 and 10 or 8
		for i = 1, N do
			local bar = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, D * (i % 2 == 0 and 0.018 or 0.034), 1, 0), Rotation = (i - 1) * 180 / N,
				BackgroundColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.25), BackgroundTransparency = 1, ZIndex = 2, Parent = rays,
			})
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.97), NumberSequenceKeypoint.new(0.5, 0.8),
				NumberSequenceKeypoint.new(0.7, 0.97), NumberSequenceKeypoint.new(1, 1),
			}), Parent = bar })
			tw(bar, 0.9, { BackgroundTransparency = 0 })
		end
		local sc = new("UIScale", { Scale = 0.6, Parent = rays })
		tw(sc, 1.2, { Scale = 1 }, Enum.EasingStyle.Quint)
		local spin = order >= 7 and 9 or 6
		table.insert(conns, RunService.RenderStepped:Connect(function(dt) rays.Rotation += spin * dt end))
	end

	-- core glow behind the name
	for i = 1, 9 do
		local d = D * (0.03 + i * 0.03)
		local core = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.fromOffset(d, d * 0.62), BackgroundColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.3), ZIndex = 3, Parent = root })
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = core })
		tw(core, 0.6, { BackgroundTransparency = 0.93 })
	end

	-- shock rings
	for i = 1, (rich and 2 or 1) do
		task.delay((i - 1) * 0.22, function()
			if not root.Parent then return end
			local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.fromOffset(40, 40), ZIndex = 4, Parent = root })
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
			local st = new("UIStroke", { Color = accent:Lerp(Color3.new(1, 1, 1), 0.4), Thickness = 5, Transparency = 0.1, Parent = ring })
			tw(ring, 1.3, { Size = UDim2.fromOffset(D * 0.8, D * 0.8) }, Enum.EasingStyle.Quint)
			tw(st, 1.3, { Transparency = 1, Thickness = 1 })
			task.delay(1.4, function() ring:Destroy() end)
		end)
	end

	-- sparkles rising through the frame
	if rich then
		local count = q >= 7 and 34 or 18
		for _ = 1, count do
			task.delay(math.random() * 1.6, function()
				if not root.Parent then return end
				local s = math.random(5, 12)
				local x, y = math.random(), 0.35 + math.random() * 0.7
				local sp = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(s, s), Rotation = 45,
					BackgroundColor3 = math.random() < 0.5 and Color3.new(1, 1, 1) or accent:Lerp(Color3.new(1, 1, 1), 0.5),
					BackgroundTransparency = 1, ZIndex = 5, Parent = root,
				})
				local life = 1.4 + math.random() * 1.2
				tw(sp, 0.3, { BackgroundTransparency = 0.1 })
				tw(sp, life, { Position = UDim2.fromScale(x + (math.random() - 0.5) * 0.06, y - 0.25 - math.random() * 0.2), Rotation = 45 + math.random(-90, 90) }, Enum.EasingStyle.Sine)
				task.delay(life * 0.6, function() if sp.Parent then tw(sp, life * 0.4, { BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1) }) end end)
				task.delay(life + 0.1, function() sp:Destroy() end)
			end)
		end
	end

	-- typography
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.new(0.92, 0, 0, 230), ZIndex = 6, Parent = root })
	new("UISizeConstraint", { MaxSize = Vector2.new(1100, 230), Parent = box })
	local eb = text(box, R.Track(EYEBROW[def.rarity] or (def.rarity .. " discovery")), F.Bold, GOLD, { Position = UDim2.fromScale(0.5, 0.12), Size = UDim2.new(1, 0, 0, 18), ZIndex = 7 })
	shadow(eb, 1.5, 0.4)
	rules(box, 0.12, 0.22, GOLD, 0.35, halfWidth(eb.Text, 18, F.Bold))
	local nm = text(box, def.name, F.Black, Color3.new(1, 1, 1), { Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.new(1, 0, 0, 110), ZIndex = 7 })
	maxSize(nm, 104)
	shadow(nm, 2.5, 0.3)
	shine(nm, Color3.new(1, 1, 1), accent:Lerp(Color3.new(1, 1, 1), 0.2), 0.75, 1.1)
	local od = text(box, R.Track(def.rarity .. (chance and ("   ·   " .. chance) or "")), F.Bold, accent:Lerp(Color3.new(1, 1, 1), 0.15), { Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.new(1, 0, 0, 20), ZIndex = 7 })
	shadow(od, 1.5, 0.35)
	local ns = new("UIScale", { Scale = 1.35, Parent = nm })
	task.delay(0.12, function()
		tw(nm, 0.35, { TextTransparency = 0 })
		tw(ns, 0.9, { Scale = 1 }, Enum.EasingStyle.Quint)
	end)
	task.delay(0.3, function() tw(eb, 0.5, { TextTransparency = 0 }) end)
	task.delay(0.6, function() tw(od, 0.5, { TextTransparency = 0 }) end)

	local hold = ({ [5] = 3.2, [6] = 3.6 })[order] or 4.0
	task.delay(hold + 0.6, function() for _, c in ipairs(conns) do c:Disconnect() end end)
	return hold
end

---------------------------------------------------------------- entry
-- def: CreatureData entry; chanceText: "1 in 2,500" (optional)
function R.Show(def, chanceText)
	if current then current:Destroy() end
	local root = new("Frame", { Name = "Reveal", Size = UDim2.fromScale(1, 1), Parent = screen() })
	current = root
	local rc = Config.Rarities[def.rarity] or Config.Rarities.Common
	local accent = T.Rarity(def.rarity, Config)
	local order = rc.order
	local hold
	if Settings.ReducedMotion then
		hold = order >= 3 and card(root, def, accent, chanceText) or caption(root, def, accent, chanceText)
	elseif order >= 5 then
		hold = fullscreen(root, def, accent, chanceText, order)
	elseif order >= 3 then
		hold = card(root, def, accent, chanceText)
	else
		hold = caption(root, def, accent, chanceText)
	end
	task.delay(hold, function()
		if not root.Parent then return end
		fadeOut(root, 0.45)
		task.delay(0.5, function() root:Destroy() end)
	end)
end

return R
