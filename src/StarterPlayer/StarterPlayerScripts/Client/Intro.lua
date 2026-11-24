-- Intro: the portal arrival you see when you join.
-- Location: StarterPlayer > StarterPlayerScripts > Client > Intro (ModuleScript)
--
--   Intro.Cover(hud)  runs the moment the client starts, entirely in 2D so it never waits on the map:
--                     a living portal swirls in the middle of the screen and creatures from the game
--                     burst out of it one after another (black silhouette -> pop into colour, name and
--                     rarity), while the title slams in and the real loading stages tick along below.
--   Intro.Play(hud)   once your courtyard, character and save are ready: the portal swallows the
--                     screen, the camera flies out through a real portal gate in the sky, spirals down
--                     and lands behind you with a shockwave. About four seconds; click/tap/key skips.

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

function Intro.Cover(hud)
	if ui then return ui end
	workspace:SetAttribute("TPFC_IntroPlaying", true)
	if hud then hud.Enabled = false end
	local gui = K.new("ScreenGui", { Name = "Intro", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 50, Parent = player:WaitForChild("PlayerGui") })
	local black = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(12, 7, 26), Parent = gui })
	K.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 20, 80), Color3.fromRGB(8, 5, 18)), Parent = black })
	local blur = game:GetService("Lighting"):FindFirstChild("TPFC_IntroBlur") or Instance.new("BlurEffect")
	blur.Name = "TPFC_IntroBlur"
	blur.Size = (Settings.ReducedMotion or Settings.LowVFX()) and 0 or 18
	blur.Parent = game:GetService("Lighting")

	------------------------------------------------------------ the living portal
	local art = K.new("Frame", { Name = "PortalArt", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	local portal = K.new("Frame", {
		Name = "Portal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.36, 0.36), BackgroundTransparency = 1, Parent = art,
	})
	K.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = portal })
	K.new("UISizeConstraint", { MaxSize = Vector2.new(330, 330), Parent = portal })
	local portalScale = K.new("UIScale", { Scale = 0.05, Parent = portal })
	local halo = circle(portal, 1.55, VIOLET, 0.82, 1)
	local halo2 = circle(portal, 1.25, MAGENTA, 0.8, 1)
	local core = circle(portal, 0.98, Color3.new(1, 1, 1), 0, 2)
	local swirl = K.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, VIOLET), ColorSequenceKeypoint.new(0.3, CYAN), ColorSequenceKeypoint.new(0.55, MAGENTA),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 40, 160)), ColorSequenceKeypoint.new(1, VIOLET),
		}),
		Parent = core,
	})
	local depth = circle(portal, 0.66, Color3.fromRGB(16, 8, 40), 0.15, 3)
	K.new("UIGradient", { Transparency = NumberSequence.new(0.6, 0), Rotation = 90, Parent = depth })
	local rings = {}
	for i, spec in ipairs({ { 0.98, 7, CYAN, VIOLET, 140 }, { 0.84, 4, MAGENTA, CYAN, -210 }, { 0.62, 3, Color3.new(1, 1, 1), VIOLET, 300 } }) do
		local _, g = arcRing(portal, spec[1], spec[2], spec[3], spec[4], 4 + i)
		table.insert(rings, { g = g, speed = spec[5] })
	end
	local frameRing = circle(portal, 1.08, nil, 1, 8)
	K.new("UIStroke", { Thickness = 5, Color = T.CinematicGold, Parent = frameRing })
	local sparks = {}
	for i = 1, 16 do
		local d = circle(portal, 0.03 + (i % 3) * 0.012, i % 2 == 0 and CYAN or T.CinematicGold, 0, 9)
		table.insert(sparks, { f = d, a = i / 16 * math.pi * 2, r = 0.56 + (i % 4) * 0.05, w = 0.6 + (i % 5) * 0.25 })
	end

	------------------------------------------------------------ creatures bursting out
	local stage = K.new("Frame", {
		Name = "Emerging", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.25, 1.25), BackgroundTransparency = 1, ZIndex = 10, Parent = portal,
	})
	local stageScale = K.new("UIScale", { Scale = 0.4, Parent = stage })
	local nameplate = K.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 14), Size = UDim2.new(1.6, 0, 0, 30),
		BackgroundTransparency = 1, Text = "", TextScaled = true, Font = fnt("MontserratBlack", Enum.Font.GothamBlack),
		TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, ZIndex = 12, Parent = portal,
	})
	K.new("UITextSizeConstraint", { MaxTextSize = 28, Parent = nameplate })
	local nameStroke = K.new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(10, 8, 18), Transparency = 1, Parent = nameplate })
	local rarityLine = K.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 44), Size = UDim2.new(1.2, 0, 0, 16),
		BackgroundTransparency = 1, Text = "", TextScaled = true, Font = fnt("MontserratBold", Enum.Font.GothamBold),
		TextColor3 = T.CinematicGold, TextTransparency = 1, ZIndex = 12, Parent = portal,
	})
	K.new("UITextSizeConstraint", { MaxTextSize = 15, Parent = rarityLine })

	------------------------------------------------------------ title
	local title = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.new(0.92, 0, 0, 190), BackgroundTransparency = 1, Parent = gui })
	K.new("UISizeConstraint", { MaxSize = Vector2.new(1100, 190), Parent = title })
	local titleScale = K.new("UIScale", { Scale = 1, Parent = title })
	local INK = Color3.fromRGB(10, 8, 18)
	local labels = {}
	local function line(text, font, color, y, h, maxPx, stroke)
		local l = K.new("TextLabel", { Text = text, Font = font, TextColor3 = color, TextScaled = true, BackgroundTransparency = 1, TextTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y), Size = UDim2.new(1, 0, 0, h), Parent = title })
		K.new("UITextSizeConstraint", { MaxTextSize = maxPx, Parent = l })
		K.new("UIStroke", { Color = INK, Thickness = stroke, Transparency = 1, Parent = l })
		table.insert(labels, l)
		return l
	end
	local line1 = line("THROW PORTALS", fnt("MontserratBlack", Enum.Font.GothamBlack), Color3.new(1, 1, 1), 0.38, 96, 96, 4)
	local line2 = line(Reveal.Track("For creatures"), fnt("MontserratBold", Enum.Font.GothamBold), T.CinematicGold, 0.74, 28, 28, 1.6)
	local shine = K.new("UIGradient", { Rotation = 12, Offset = Vector2.new(-1, 0), Parent = line1,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.42, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, CYAN), ColorSequenceKeypoint.new(0.58, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) }) })
	-- a real Skip button (clicks elsewhere are for tapping the portal)
	local skip = K.new("TextButton", { Text = Reveal.Track("Skip intro") .. "  >>", Font = fnt("MontserratBold", Enum.Font.GothamBold), TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0.1, BackgroundColor3 = Color3.fromRGB(30, 22, 50), BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(150, 36), ZIndex = 20, Parent = gui })
	K.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = skip })
	skip.Activated:Connect(function()
		skipped = true
	end)
	local tapHint = K.new("TextLabel", { Text = "TAP THE PORTAL!", Font = fnt("MontserratBlack", Enum.Font.GothamBlack), TextSize = 18,
		TextColor3 = T.CinematicGold, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64),
		Size = UDim2.fromOffset(420, 22), TextStrokeTransparency = 0.4, Parent = gui })
	local summoned = 0
	local loading = K.new("TextLabel", { Text = Reveal.Track("Opening the portal"), Font = fnt("MontserratBold", Enum.Font.GothamBold), TextSize = 13,
		TextColor3 = T.CinematicGold, TextTransparency = 0.1, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(420, 18), Parent = gui })
	local barBg = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.fromOffset(280, 3),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.85, Parent = gui })
	K.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barBg })
	local bar = K.new("Frame", { Size = UDim2.fromScale(0.05, 1), BackgroundColor3 = CYAN, BackgroundTransparency = 0, Parent = barBg })
	K.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })

	local titleShown = true
	local function hideTitle(t)
		if not titleShown then return end
		titleShown = false
		for _, l in ipairs(labels) do
			tw(l, t, { TextTransparency = 1 })
			tw(l:FindFirstChildOfClass("UIStroke"), t, { Transparency = 1 })
		end
		tw(titleScale, t, { Scale = 0.94 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end

	------------------------------------------------------------ animation loop
	local calm = Settings.ReducedMotion
	local pool, poolIndex = creaturePool(), 0
	local current -- { vp, t, popped, id }
	local function nextCreature()
		if current and current.vp then current.vp:Destroy() end
		current = nil
		poolIndex = poolIndex % #pool + 1
		local def = pool[poolIndex]
		local ok, model = pcall(function() return (Builder.Build(def.id)) end)
		if not ok or not model then return end
		local vp = K.viewport(model, UDim2.fromScale(1, 1), false, true)
		vp.ZIndex = 11
		vp.Parent = stage
		current = { vp = vp, t = 0, def = def }
		nameplate.TextTransparency, nameStroke.Transparency, rarityLine.TextTransparency = 1, 1, 1
	end
	local function burstSparks()
		for i = 1, 10 do
			local d = circle(art, 0.012, i % 2 == 0 and CYAN or T.CinematicGold, 0, 9)
			K.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = d })
			d.Position = portal.Position
			local a = i / 10 * math.pi * 2
			tw(d, 0.6, { Position = portal.Position + UDim2.fromScale(math.cos(a) * 0.16, math.sin(a) * 0.22), BackgroundTransparency = 1 })
			task.delay(0.65, function() d:Destroy() end)
		end
	end
	local elapsed = 0
	local anim = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if not calm then
			swirl.Rotation = (swirl.Rotation + dt * 70) % 360
			for _, r in ipairs(rings) do r.g.Rotation = (r.g.Rotation + dt * r.speed) % 360 end
			halo.Size = UDim2.fromScale(1.55 + math.sin(elapsed * 2.2) * 0.06, 1.55 + math.sin(elapsed * 2.2) * 0.06)
			halo2.BackgroundTransparency = 0.78 + math.sin(elapsed * 3.1) * 0.06
			for _, s in ipairs(sparks) do
				s.a += dt * s.w
				local r = s.r + math.sin(elapsed * 3 + s.a) * 0.03
				s.f.Position = UDim2.fromScale(0.5 + math.cos(s.a) * r, 0.5 + math.sin(s.a) * r)
			end
		end
		local c = current
		if not c then
			if elapsed > 0.5 and ui and ui.waiting then nextCreature() end
			return
		end
		c.t += dt
		if c.t < 0.5 then
			-- silhouette gathering in the portal
			local q = c.t / 0.5
			stageScale.Scale = 0.35 + 0.35 * smooth(q)
			stage.Position = UDim2.fromScale(0.5 + (calm and 0 or math.sin(c.t * 60) * 0.006 * q), 0.52)
		elseif not c.popped then
			c.popped = true
			tw(c.vp, 0.18, { ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 0 })
			stageScale.Scale = 0.8
			tw(stageScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
			tw(stage, 0.45, { Position = UDim2.fromScale(0.5, 0.36) }, Enum.EasingStyle.Back)
			local rarity = Config.Rarities[c.def.rarity]
			nameplate.Text = string.upper(c.def.name)
			rarityLine.Text = Reveal.Track(c.def.rarity)
			rarityLine.TextColor3 = rarity and rarity.color or T.CinematicGold
			tw(nameplate, 0.25, { TextTransparency = 0 })
			tw(nameStroke, 0.25, { Transparency = 0.2 })
			tw(rarityLine, 0.25, { TextTransparency = 0 })
			if not calm then burstSparks() end
		elseif c.t > 1.75 and not c.leaving then
			c.leaving = true
			tw(c.vp, 0.25, { ImageTransparency = 1 })
			tw(stageScale, 0.25, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tw(nameplate, 0.2, { TextTransparency = 1 })
			tw(nameStroke, 0.2, { Transparency = 1 })
			tw(rarityLine, 0.2, { TextTransparency = 1 })
		elseif c.t > 2.05 then
			nextCreature()
		end
	end)

	-- the portal opens and the title slams in straight away
	tw(portalScale, 0.7, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.15, function()
		titleScale.Scale = calm and 1 or 1.7
		for _, l in ipairs({ line1, line2 }) do
			tw(l, 0.25, { TextTransparency = 0 })
			tw(l:FindFirstChildOfClass("UIStroke"), 0.25, { Transparency = 0.25 })
		end
		tw(titleScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		tw(shine, 1.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		Sounds.Play("Rare", 0.9)
	end)

	local function cleanup()
		if anim then anim:Disconnect(); anim = nil end
		if current and current.vp then current.vp:Destroy() end
		current = nil
	end
	-- portal swallows the screen: the hand-off into the world
	local function zoom(t)
		if current and current.vp then tw(current.vp, t * 0.6, { ImageTransparency = 1 }) end
		tw(nameplate, 0.15, { TextTransparency = 1 })
		tw(nameStroke, 0.15, { Transparency = 1 })
		tw(rarityLine, 0.15, { TextTransparency = 1 })
		tw(portalScale, t, { Scale = 9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	local function fadeArt(t)
		cleanup()
		for _, d in ipairs(art:GetDescendants()) do
			if d:IsA("Frame") then tw(d, t, { BackgroundTransparency = 1 }) end
			if d:IsA("UIStroke") then tw(d, t, { Transparency = 1 }) end
		end
	end
	gui.Destroying:Connect(cleanup)

	-- tap the portal while the world loads: a creature bursts out every time
	local tap = K.new("TextButton", { Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.15, 1.15), ZIndex = 15, Parent = portal })
	tap.Activated:Connect(function()
		if not ui or not ui.waiting then return end
		summoned += 1
		tapHint.Text = "SUMMONED: " .. summoned .. (summoned >= 10 and "  - PORTAL MASTER!" or "")
		tapHint.TextColor3 = summoned >= 10 and Color3.fromRGB(255, 120, 200) or T.CinematicGold
		portalScale.Scale = 0.9
		tw(portalScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		if not calm then burstSparks() end
		pcall(Sounds.Play, "Spawn", 1 + math.min(summoned, 12) * 0.04)
		nextCreature()
	end)

	-- the title slams back in during the creature show
	local function showTitle()
		titleShown = true
		titleScale.Scale = calm and 1 or 1.8
		for _, l in ipairs({ line1, line2 }) do
			tw(l, 0.2, { TextTransparency = 0 })
			tw(l:FindFirstChildOfClass("UIStroke"), 0.2, { Transparency = 0.25 })
		end
		shine.Offset = Vector2.new(-1, 0)
		tw(titleScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		tw(shine, 1, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		pcall(Sounds.Play, "Rare", 1.05)
	end
	ui = { gui = gui, black = black, skip = skip, loading = loading, hideTitle = hideTitle, waiting = true, blur = blur,
		bar = bar, barBg = barBg, zoom = zoom, fadeArt = fadeArt, showTitle = showTitle, tapHint = tapHint }

	-- keyboard / gamepad skip; mouse and touch are for the portal and the Skip button
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
