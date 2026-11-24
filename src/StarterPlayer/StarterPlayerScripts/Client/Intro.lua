-- Intro: the opening throw you see when you join.
-- Location: StarterPlayer > StarterPlayerScripts > Client > Intro (ModuleScript)
--
--   Intro.Cover(hud)  runs the moment the client starts, entirely in 2D so it never waits on the map:
--                     a launch pad under a starry sky where a portal orb charges up while the loading
--                     bar fills as a THROW POWER meter, the title drops in word by word, tips rotate.
--   Intro.Play(hud)   once your courtyard, character and save are ready: the meter hits MAX, the orb is
--                     thrown off the screen and IntroShow follows it across the world until it lands,
--                     opens a portal and a powerful creature bursts out; then the camera dives to you.
--                     Skip button (or Space / Esc / Enter) skips.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local K = require(script.Parent.UIKit)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)
local T = require(script.Parent.UITheme)
local Reveal = require(script.Parent.RevealTitle)
local Settings = require(script.Parent.ClientSettings)
local State = require(script.Parent.ClientState)
local Readiness = require(script.Parent.IntroReadiness)
local Config = require(RS.Shared.Config)
local CreatureData = require(RS.Shared.CreatureData)
local Builder = require(RS.Shared.CreatureBuilder)
local okPortal, Portal = pcall(require, RS.Shared.PortalBuilder)
local okShow, IntroShow = pcall(require, script.Parent.IntroShow) -- the in-world creature show
if not okShow then IntroShow = nil end
if not okPortal then Portal = nil end

local function tw(o, t, props, style, dir)
	local duration = Settings.ReducedMotion and math.min(t, 0.12) or t
	local x = TweenService:Create(o, TweenInfo.new(duration, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end
local function fnt(name, fallback)
	local ok, f = pcall(function() return Enum.Font[name] end)
	return (ok and f) or fallback
end

local Intro = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end
local function smooth(k) return k * k * (3 - 2 * k) end

local ui -- built by Intro.Cover
local skipped = false
local skipConn

local VIOLET, CYAN, MAGENTA = Color3.fromRGB(150, 90, 255), Color3.fromRGB(90, 230, 255), Color3.fromRGB(255, 90, 210)

local function circle(parent, scale, color, transparency, z)
	local f = K.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(scale, scale),
		BackgroundColor3 = color or Color3.new(1, 1, 1), BackgroundTransparency = transparency or 0, ZIndex = z or 2, Parent = parent,
	})
	K.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	return f
end

-- a ring whose stroke carries a rotating arc gradient, so it reads as swirling energy
local function arcRing(parent, scale, thickness, c1, c2, z)
	local f = circle(parent, scale, nil, 1, z)
	local s = K.new("UIStroke", { Thickness = thickness, Color = Color3.new(1, 1, 1), Parent = f })
	local g = K.new("UIGradient", {
		Color = ColorSequence.new(c1, c2),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 0.15), NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.85, 0.25), NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = s,
	})
	return f, g, s
end

-- creatures shown bursting out of the loading portal: hand-built Rare+ first, shuffled
local function creaturePool()
	local pool = {}
	for _, c in ipairs(CreatureData.List) do
		local r = Config.Rarities[c.rarity]
		if r and r.order >= 3 then table.insert(pool, c) end
	end
	if #pool == 0 then pool = table.clone(CreatureData.List) end
	local rng = Random.new(os.clock() * 1000)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	return pool
end

local PI = math.pi
local TIPS = {
	"Tip: charge your throw to the PERFECT zone for extra distance",
	"Tip: rarer portals hold rarer creatures",
	"Tip: throw farther to reach new worlds",
	"Tip: send a team of 3 pets on expeditions",
	"Tip: swords and armour make your pets stronger",
	"Tip: feed pets at the Pantry to level them up",
	"Tip: Mythical, Secret and Divine pulls get their own cutscene",
}

-- The loading screen is a launch pad at night: stars twinkle, a portal orb charges on its pad while
-- the loading bar fills as a THROW POWER meter, the title drops in word by word and tips rotate.
-- When the world is ready the meter hits MAX and the orb is thrown off the top of the screen -
-- straight into IntroShow's flight over the world.
function Intro.Cover(hud)
	if ui then return ui end
	workspace:SetAttribute("TPFC_IntroPlaying", true)
	if hud then hud.Enabled = false end
	local calm = Settings.ReducedMotion
	local gui = K.new("ScreenGui", { Name = "Intro", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 50, Parent = player:WaitForChild("PlayerGui") })
	local black = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 30), Parent = gui })
	K.new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 12, 40)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(40, 24, 80)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 40, 110)) }), Parent = black })
	local blur = game:GetService("Lighting"):FindFirstChild("TPFC_IntroBlur") or Instance.new("BlurEffect")
	blur.Name = "TPFC_IntroBlur"
	blur.Size = (calm or Settings.LowVFX()) and 0 or 18
	blur.Parent = game:GetService("Lighting")

	local art = K.new("Frame", { Name = "LaunchPad", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	-- stars
	local stars = {}
	for i = 1, 60 do
		local s = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(math.random(), math.random() * 0.75),
			Size = UDim2.fromOffset(math.random(2, 4), math.random(2, 4)), BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = math.random() * 0.5, Parent = art })
		K.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = s })
		table.insert(stars, { f = s, p = math.random() * 6, w = 1 + math.random() * 3 })
	end
	-- distant hills and the launch pad
	for i, spec in ipairs({ { 0.2, 0.86, 0.7, Color3.fromRGB(30, 22, 60) }, { 0.75, 0.88, 0.8, Color3.fromRGB(24, 18, 48) } }) do
		local hill = circle(art, 1, spec[4], 0, 1)
		hill.SizeConstraint = Enum.SizeConstraint.RelativeXX
		hill.Size = UDim2.fromScale(spec[3], spec[3])
		hill.Position = UDim2.fromScale(spec[1], spec[2] + spec[3] * 0.4)

	end
	K.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.14, 0),
		BackgroundColor3 = Color3.fromRGB(18, 14, 36), ZIndex = 2, Parent = art })
	local pad = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.86, 0), Size = UDim2.fromOffset(220, 26),
		BackgroundColor3 = Color3.fromRGB(70, 60, 110), ZIndex = 3, Parent = art })
	K.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = pad })
	K.new("UIStroke", { Color = T.CinematicGold, Thickness = 3, Parent = pad })
	local padGlow = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.35),
		BackgroundColor3 = CYAN, ZIndex = 4, Parent = pad })
	K.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = padGlow })

	-- the portal orb charging on the pad
	local orb = K.new("Frame", { Name = "Orb", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.86, -18),
		Size = UDim2.fromOffset(120, 120), BackgroundTransparency = 1, ZIndex = 5, Parent = art })
	local orbScale = K.new("UIScale", { Scale = 1, Parent = orb })
	local aura = circle(orb, 1.7, VIOLET, 0.75, 5)
	local core = circle(orb, 1, Color3.new(1, 1, 1), 0, 6)
	local swirl = K.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, VIOLET), ColorSequenceKeypoint.new(0.35, CYAN),
		ColorSequenceKeypoint.new(0.7, MAGENTA), ColorSequenceKeypoint.new(1, VIOLET) }), Parent = core })
	local _, ringG = arcRing(orb, 1.02, 5, Color3.new(1, 1, 1), CYAN, 7)
	local shine = circle(orb, 0.32, Color3.new(1, 1, 1), 0.35, 8)
	shine.Position = UDim2.fromScale(0.34, 0.3)
	local sparks = {}
	for i = 1, 10 do
		local d = circle(orb, 0.07, i % 2 == 0 and CYAN or T.CinematicGold, 0, 9)
		table.insert(sparks, { f = d, a = i / 10 * PI * 2, r = 0.7 + (i % 3) * 0.08 })
	end

	-- title: four words dropping in one by one
	local title = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.new(0.94, 0, 0, 120),
		BackgroundTransparency = 1, Parent = gui })
	K.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 14), Parent = title })
	local titleScale = K.new("UIScale", { Scale = 1, Parent = title })
	local words = {}
	local labels = {}
	for i, spec in ipairs({ { "THROW", Color3.fromRGB(255, 214, 90) }, { "PORTALS", Color3.fromRGB(140, 230, 255) },
		{ "FOR", Color3.fromRGB(255, 255, 255) }, { "CREATURES", Color3.fromRGB(255, 140, 220) } }) do
		local holder = K.new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 110), LayoutOrder = i, Parent = title })
		local l = K.new("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 110),
			Text = spec[1], Font = fnt("MontserratBlack", Enum.Font.GothamBlack), TextSize = i == 3 and 44 or 76, TextColor3 = spec[2],
			TextTransparency = 1, Position = UDim2.fromOffset(0, -80), Parent = holder })
		K.new("UIStroke", { Color = Color3.fromRGB(12, 8, 24), Thickness = 5, Transparency = 1, Parent = l })
		K.new("UITextSizeConstraint", { MaxTextSize = i == 3 and 44 or 76, Parent = l })
		table.insert(words, l)
		table.insert(labels, l)
	end
	K.new("UISizeConstraint", { MaxSize = Vector2.new(1200, 120), Parent = title })
	local tip = K.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.34, 0),
		Size = UDim2.new(0.9, 0, 0, 22), Text = TIPS[math.random(1, #TIPS)], Font = fnt("MontserratBold", Enum.Font.GothamBold), TextSize = 16,
		TextColor3 = Color3.fromRGB(220, 210, 255), TextTransparency = 1, Parent = gui })

	-- loading bar = the THROW POWER meter
	local loading = K.new("TextLabel", { Text = Reveal.Track("Opening the portal"), Font = fnt("MontserratBold", Enum.Font.GothamBold), TextSize = 13,
		TextColor3 = T.CinematicGold, TextTransparency = 0.1, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -46), Size = UDim2.fromOffset(420, 18), ZIndex = 6, Parent = gui })
	local barBg = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.fromOffset(340, 16),
		BackgroundColor3 = Color3.fromRGB(20, 16, 36), BackgroundTransparency = 0.1, ZIndex = 6, Parent = gui })
	K.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barBg })
	K.new("UIStroke", { Color = T.CinematicGold, Thickness = 2, Parent = barBg })
	local bar = K.new("Frame", { Size = UDim2.fromScale(0.05, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 7, Parent = barBg })
	K.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
	K.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 230, 120)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 214, 90)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 90)) }), Parent = bar })
	local power = K.new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 10, 0.5, 0),
		Size = UDim2.fromOffset(110, 18), Text = "POWER", Font = fnt("MontserratBlack", Enum.Font.GothamBlack), TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = barBg })

	local skip = K.new("TextButton", { Text = Reveal.Track("Skip intro") .. "  >>", Font = fnt("MontserratBold", Enum.Font.GothamBold), TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0.1, BackgroundColor3 = Color3.fromRGB(30, 22, 50), BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(150, 36), ZIndex = 20, Parent = gui })
	K.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = skip })
	skip.Activated:Connect(function()
		skipped = true
	end)

	local titleShown = true
	local function hideTitle(t)
		if not titleShown then return end
		titleShown = false
		for _, l in ipairs(labels) do
			tw(l, t, { TextTransparency = 1 })
			tw(l:FindFirstChildOfClass("UIStroke"), t, { Transparency = 1 })
		end
		tw(tip, t, { TextTransparency = 1 })
	end
	local function dropWords(gap)
		for i, l in ipairs(words) do
			task.delay((i - 1) * gap, function()
				l.Position = UDim2.fromOffset(0, calm and 0 or -80)
				tw(l, 0.45, { TextTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Bounce)
				tw(l:FindFirstChildOfClass("UIStroke"), 0.3, { Transparency = 0.1 })
				pcall(Sounds.Play, "Land", 1 + i * 0.12)
			end)
		end
	end
	dropWords(0.22)
	task.delay(1.1, function()
		tw(tip, 0.5, { TextTransparency = 0.15 })
	end)
	-- rotate tips while loading
	task.spawn(function()
		while gui.Parent and ui and ui.waiting do
			task.wait(3.2)
			if not (gui.Parent and ui and ui.waiting) then break end
			tw(tip, 0.25, { TextTransparency = 1 })
			task.wait(0.27)
			tip.Text = TIPS[math.random(1, #TIPS)]
			tw(tip, 0.25, { TextTransparency = 0.15 })
		end
	end)

	local elapsed = 0
	local anim = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		for _, s in ipairs(stars) do
			s.f.BackgroundTransparency = 0.25 + 0.5 * (0.5 + 0.5 * math.sin(elapsed * s.w + s.p))
		end
		if calm then return end
		swirl.Rotation = (swirl.Rotation + dt * 120) % 360
		ringG.Rotation = (ringG.Rotation + dt * 200) % 360
		local charge = math.clamp(bar.Size.X.Scale, 0, 1)
		orb.Position = UDim2.new(0.5, math.sin(elapsed * 40) * 2 * charge, 0.86, -18 - math.abs(math.sin(elapsed * 2.4)) * 10)
		aura.BackgroundTransparency = 0.75 - charge * 0.3 + math.sin(elapsed * 6) * 0.05
		aura.Size = UDim2.fromScale(1.6 + charge * 0.5, 1.6 + charge * 0.5)
		padGlow.BackgroundTransparency = 0.5 - charge * 0.4
		for _, s in ipairs(sparks) do
			s.a += dt * (1.5 + charge * 4)
			s.f.Position = UDim2.fromScale(0.5 + math.cos(s.a) * s.r, 0.5 + math.sin(s.a) * s.r)
		end
		power.Text = charge >= 0.999 and "MAX!" or ("POWER " .. math.floor(charge * 100) .. "%")
		power.TextColor3 = charge >= 0.999 and Color3.fromRGB(255, 120, 120) or Color3.new(1, 1, 1)
	end)
	local function cleanup()
		if anim then anim:Disconnect(); anim = nil end
	end
	-- the throw: the orb winds back, then launches off the top of the screen
	local function zoom(t)
		if calm then return end
		tw(orbScale, t * 0.3, { Scale = 0.8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(t * 0.3, function()
			tw(orb, t * 0.7, { Position = UDim2.new(0.5, 0, -0.3, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tw(orbScale, t * 0.7, { Scale = 1.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			pcall(Sounds.Play, "Throw", 1)
		end)
	end
	local function fadeArt(t)
		cleanup()
		for _, d in ipairs(art:GetDescendants()) do
			if d:IsA("Frame") then tw(d, t, { BackgroundTransparency = 1 }) end
			if d:IsA("UIStroke") then tw(d, t, { Transparency = 1 }) end
		end
		tw(barBg, t, { BackgroundTransparency = 1 })
	end
	local function showTitle()
		titleShown = true
		for _, l in ipairs(words) do
			l.TextTransparency = 1
		end
		dropWords(0.12)
		titleScale.Scale = 1
	end
	gui.Destroying:Connect(cleanup)
	ui = { gui = gui, black = black, skip = skip, loading = loading, hideTitle = hideTitle, waiting = true, blur = blur,
		bar = bar, barBg = barBg, zoom = zoom, fadeArt = fadeArt, showTitle = showTitle }

	-- keyboard / gamepad skip; mouse and touch use the Skip button
	skipConn = UserInputService.InputBegan:Connect(function(input)
		local key = input.KeyCode
		if key == Enum.KeyCode.Space or key == Enum.KeyCode.Escape or key == Enum.KeyCode.Return or key == Enum.KeyCode.ButtonB then
			skipped = true
		end
	end)
	return ui
end

-- Wait on our actual arrival state. Other players, pets and effects cannot reset this timer.
local function waitForWorld(capSeconds)
	local t0 = os.clock()
	local readySince, lastStage
	while os.clock() - t0 < capSeconds do
		local index = player:GetAttribute("BaseIndex")
		local bases = workspace:FindFirstChild("Bases")
		local base = bases and index and bases:FindFirstChild("Base" .. index)
		local map = workspace:FindFirstChild("Map")
		local character = player.Character
		local stage, message, progress = Readiness.Resolve({
			loaded = game:IsLoaded(),
			map = map and map:FindFirstChild("Start") ~= nil,
			base = base and base:FindFirstChild("Center") ~= nil,
			character = character and character:FindFirstChild("HumanoidRootPart") ~= nil,
			data = State.Loaded and player:GetAttribute("Loaded") == true,
		})
		if ui and stage ~= lastStage then
			ui.loading.Text = Reveal.Track(message)
			tw(ui.bar, 0.18, { Size = UDim2.fromScale(progress, 1) })
			lastStage = stage
		end
		if stage == "ready" then
			readySince = readySince or os.clock()
			if os.clock() - readySince >= 0.2 then break end
		else
			readySince = nil
		end
		task.wait(0.1)
	end
end

-- a real portal gate hanging in the sky that the camera flies out of
local function skyGate(at, dir)
	if not Portal or not Portal.BuildGate then return nil end
	local id = (State.Data and Config.Portals[State.Data.EquippedPortal]) and State.Data.EquippedPortal or "Basic"
	local ok, gate, refs = pcall(Portal.BuildGate, id, 9)
	if not ok or not gate then return nil end
	gate:PivotTo(CFrame.lookAt(at, at + dir))
	gate:ScaleTo(0.6)
	gate.Parent = Effects.Folder or workspace
	return { model = gate, refs = refs, cf = CFrame.lookAt(at, at + dir), id = id }
end

local DURATION = 4.2

function Intro.Play(hud)
	local u = Intro.Cover(hud)
	-- wait behind the cover for the world, our base and our character
	waitForWorld(25)
	local t0 = os.clock()
	local idx = player:GetAttribute("BaseIndex")
	while not (idx and idx > 0) and os.clock() - t0 < 10 do
		task.wait(0.2)
		idx = player:GetAttribute("BaseIndex")
	end
	local base = workspace:FindFirstChild("Bases") and workspace.Bases:FindFirstChild("Base" .. tostring(idx))
	local char = player.Character or player.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart", 10)
	u.waiting = false
	u.bar.Size = UDim2.fromScale(1, 1)
	tw(u.loading, 0.3, { TextTransparency = 1 })
	tw(u.bar, 0.3, { BackgroundTransparency = 1 })
	tw(u.barBg, 0.3, { BackgroundTransparency = 1 })
	tw(u.blur, 0.8, { Size = 0 })
	task.delay(0.9, function() if u.blur.Parent then u.blur:Destroy() end end)

	-- camera path: out of the sky gate, spiralling down onto you
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local target = hrp and hrp.Position
		or (base and base:FindFirstChild("Center") and base.Center.Position)
		or Vector3.new(0, 5, 0)
	local look = hrp and hrp.CFrame.LookVector or Vector3.new(0, 0, -1)
	look = Vector3.new(look.X, 0, look.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local side = Vector3.new(-look.Z, 0, look.X)
	local focus = target + Vector3.new(0, 2, 0)
	local pts, looks = {}, {}
	local function key(pos, at) table.insert(pts, pos); table.insert(looks, at) end
	key(target - look * 95 + Vector3.new(0, 85, 0), focus + Vector3.new(0, 25, 0))
	key(target - look * 62 + side * 30 + Vector3.new(0, 52, 0), focus + Vector3.new(0, 8, 0))
	key(target - look * 34 - side * 16 + Vector3.new(0, 26, 0), focus)
	key(target - look * 14 + Vector3.new(0, 7, 0), focus)

	local gui, black, skip, hideTitle = u.gui, u.black, u.skip, u.hideTitle
	if hud then hud.Enabled = false end
	local finished = false
	local gate
	if not skipped and not Settings.ReducedMotion then
		workspace:SetAttribute("TPFC_IntroPlaying", true)
		-- the loading portal grows until it fills the screen
		if u.zoom then u.zoom(0.5) end
		hideTitle(0.35)
		local zoomStart = os.clock()
		while os.clock() - zoomStart < 0.5 and not skipped and not Settings.ReducedMotion do
			RunService.RenderStepped:Wait()
		end
		Effects.Letterbox(true)
		camera.CameraType = Enum.CameraType.Scriptable
		-- the creature show: sky portal, a dragon roaring past, a lion and a parade of pets
		local showEnd
		if IntroShow and not skipped and not Settings.ReducedMotion then
			if u.tapHint then u.tapHint.Visible = false end
			tw(black, 0.35, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
			if u.fadeArt then u.fadeArt(0.35) end
			local okShow, endCF = pcall(IntroShow.Run, {
				camera = camera,
				skipped = function()
					return skipped or Settings.ReducedMotion
				end,
				title = u.showTitle,
			})
			if okShow and typeof(endCF) == "CFrame" then
				showEnd = endCF
			elseif not okShow then
				warn("[IntroShow] " .. tostring(endCF))
			end
			hideTitle(0.4)
		end
		if showEnd then
			-- dive from where the show ended, straight down to you
			pts[1], looks[1] = showEnd.Position, showEnd.Position + showEnd.LookVector * 20
			camera.CFrame = showEnd
		else
			camera.CFrame = CFrame.lookAt(pts[1], looks[1])
			local dir = (pts[2] - pts[1]).Unit
			gate = skyGate(pts[1] + dir * 10, dir)
		end
		RunService.RenderStepped:Wait()
		tw(black, 0.35, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
		if u.fadeArt then u.fadeArt(0.35) end

		local start = os.clock()
		local segs = #pts - 1
		local burst = false
		local function at(list, j) return list[math.clamp(j, 1, #list)] end
		while not skipped and not Settings.ReducedMotion do
			local k = (os.clock() - start) / DURATION
			if k >= 1 then finished = true break end
			local e = smooth(k) * segs
			local i = math.min(math.floor(e) + 1, segs)
			local f = e - (i - 1)
			local pos = catmull(at(pts, i - 1), at(pts, i), at(pts, i + 1), at(pts, i + 2), f)
			local aim = catmull(at(looks, i - 1), at(looks, i), at(looks, i + 1), at(looks, i + 2), f)
			-- spiral roll that unwinds as you come in to land
			local roll = (1 - smooth(math.min(1, k / 0.7))) * 0.9 * math.pi
			camera.CFrame = CFrame.lookAt(pos, aim) * CFrame.Angles(0, 0, roll)
			if gate then
				if Portal.Spin then pcall(Portal.Spin, gate.refs, os.clock() - start) end
				if k > 0.08 and not burst then
					burst = true
					local seq = Portal.ColorSeq and Portal.ColorSeq(gate.id) or ColorSequence.new(CYAN, VIOLET)
					if Effects.Burst then Effects.Burst(gate.cf.Position, seq, 40, 22, 1.4) end
				end
				local shrink = math.clamp((k - 0.22) / 0.2, 0, 1)
				if shrink >= 1 then
					gate.model:Destroy()
					gate = nil
				else
					gate.model:ScaleTo(math.max(0.05, (1 - shrink) * 1))
					gate.model:PivotTo(gate.cf)
				end
			end
			RunService.RenderStepped:Wait()
		end
	end
	if gate then gate.model:Destroy() end
	if skipConn then skipConn:Disconnect() end
	workspace:SetAttribute("TPFC_IntroPlaying", nil)

	-- hand the camera back to the player
	Effects.Letterbox(false)
	camera.CameraType = Enum.CameraType.Custom
	if hud then hud.Enabled = true end
	hideTitle(0.3)
	tw(skip, 0.3, { TextTransparency = 1 })
	tw(black, 0.4, { BackgroundTransparency = 1 })
	if u.fadeArt then u.fadeArt(0.3) end
	if finished then
		Effects.Flash(Color3.new(1, 1, 1), 0.5, 0.3)
		Sounds.Play("Whoosh", 1.2)
		local feet = target - Vector3.new(0, 2.6, 0)
		if Effects.Shockwave then Effects.Shockwave(feet, CYAN, 14, 0.7) end
		if Effects.Burst then Effects.Burst(feet + Vector3.new(0, 1, 0), ColorSequence.new(CYAN, VIOLET), 30, 16, 1) end
	end
	task.delay(0.6, function() gui:Destroy() end)
	ui = nil
end

return Intro
