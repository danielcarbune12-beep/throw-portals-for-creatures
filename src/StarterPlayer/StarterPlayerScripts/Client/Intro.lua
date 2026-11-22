-- Intro: cinematic fly-over when you join. The camera sweeps down the whole lane (every zone),
-- past the Portal Launch Hall, and lands at your base while the title animates in.
-- Click / tap / any key to skip.
-- Location: StarterPlayer > StarterPlayerScripts > Client > Intro (ModuleScript)
--
-- Two stages so it never lags or starts late:
--   Intro.Cover(hud)  runs the moment the client starts: black screen + title, HUD hidden.
--                     The player never sees half-loaded gameplay behind it.
--   Intro.Play(hud)   waits (behind the cover) until the server-built map has finished replicating,
--                     then fades the cover and flies the camera, so the flight isn't fighting
--                     thousands of parts still streaming in.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local K = require(script.Parent.UIKit)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)
local T = require(script.Parent.UITheme)
local Reveal = require(script.Parent.RevealTitle)

local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props)
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

function Intro.Cover(hud)
	if ui then return ui end
	if hud then hud.Enabled = false end
	local gui = K.new("ScreenGui", { Name = "Intro", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 50, Parent = player:WaitForChild("PlayerGui") })
	local black = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 8, 26), Parent = gui })
	K.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0),
	}), Parent = black })
	-- blur whatever the world has rendered so far (sky, hub) behind a soft dark tint
	local blur = game:GetService("Lighting"):FindFirstChild("TPFC_IntroBlur") or Instance.new("BlurEffect")
	blur.Name = "TPFC_IntroBlur"
	blur.Size = 28
	blur.Parent = game:GetService("Lighting")
	task.delay(0.4, function()
		if black.Parent and ui and ui.waiting then tw(black, 1.2, { BackgroundTransparency = 0.38 }, Enum.EasingStyle.Sine) end
	end)
	local title = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(0.92, 0, 0, 230), BackgroundTransparency = 1, Parent = gui })
	K.new("UISizeConstraint", { MaxSize = Vector2.new(1100, 230), Parent = title })
	local titleScale = K.new("UIScale", { Scale = 1.12, Parent = title })
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
	local eyebrow = line(Reveal.Track("Welcome to"), fnt("MontserratBold", Enum.Font.GothamBold), T.CinematicGold, 0.08, 16, 16, 1.2)
	local line1 = line("THROW PORTALS", fnt("MontserratBlack", Enum.Font.GothamBlack), Color3.new(1, 1, 1), 0.42, 104, 104, 3.5)
	local line2 = line(Reveal.Track("For creatures"), fnt("MontserratBold", Enum.Font.GothamBold), T.CinematicGold, 0.72, 26, 26, 1.5)
	local sub = line(Reveal.Track("Throw   ·   catch   ·   collect"), fnt("MontserratMedium", Enum.Font.GothamMedium), T.Muted, 0.95, 14, 14, 1)
	local shine = K.new("UIGradient", { Rotation = 12, Offset = Vector2.new(-1, 0), Parent = line1,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.42, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, T.CinematicGold), ColorSequenceKeypoint.new(0.58, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) }) })
	local ruleBars = {}
	for side = -1, 1, 2 do
		local r = K.new("Frame", { AnchorPoint = Vector2.new(side < 0 and 1 or 0, 0.5), Position = UDim2.new(0.5, side * 110, 0.08, 0), Size = UDim2.new(0, 0, 0, 1),
			BackgroundColor3 = T.CinematicGold, Parent = title })
		K.new("UIGradient", { Transparency = NumberSequence.new(side < 0 and 1 or 0, side < 0 and 0 or 1), Parent = r })
		table.insert(ruleBars, r)
	end
	local skip = K.new("TextLabel", { Text = Reveal.Track("Click to skip"), Font = fnt("MontserratMedium", Enum.Font.GothamMedium), TextSize = 12,
		TextColor3 = T.Muted, TextTransparency = 0.35, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -26), Size = UDim2.fromOffset(220, 16), TextXAlignment = Enum.TextXAlignment.Right, Parent = gui })
	local loading = K.new("TextLabel", { Text = Reveal.Track("Building the world"), Font = fnt("MontserratBold", Enum.Font.GothamBold), TextSize = 13,
		TextColor3 = T.Gold, TextTransparency = 1, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -74), Size = UDim2.fromOffset(420, 18), Parent = gui })
	local barBg = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -60), Size = UDim2.fromOffset(280, 2),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = gui })
	local bar = K.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Gold, BackgroundTransparency = 1, Parent = barBg })
	local function showLine(l, t)
		tw(l, t, { TextTransparency = 0 })
		tw(l:FindFirstChildOfClass("UIStroke"), t, { Transparency = 0.3 })
	end
	local titleShown = true
	local function hideTitle(t)
		if not titleShown then return end
		titleShown = false
		for _, l in ipairs(labels) do
			tw(l, t, { TextTransparency = 1 })
			tw(l:FindFirstChildOfClass("UIStroke"), t, { Transparency = 1 })
		end
		for _, r in ipairs(ruleBars) do tw(r, t, { BackgroundTransparency = 1 }) end
		tw(titleScale, t, { Scale = 0.96 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	ui = { gui = gui, black = black, skip = skip, loading = loading, hideTitle = hideTitle, waiting = true, blur = blur, bar = bar, barBg = barBg }

	-- the title animates in on black straight away, while the world loads
	task.delay(0.2, function()
		showLine(line1, 0.9)
		tw(titleScale, 1.6, { Scale = 1 }, Enum.EasingStyle.Quint)
		tw(shine, 1.4, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		Sounds.Play("Rare", 0.9)
	end)
	task.delay(0.6, function()
		showLine(eyebrow, 0.6)
		for _, r in ipairs(ruleBars) do tw(r, 0.9, { Size = UDim2.new(0.18, 0, 0, 1) }, Enum.EasingStyle.Quint) end
	end)
	task.delay(0.9, function() showLine(line2, 0.7) end)
	task.delay(1.4, function() showLine(sub, 0.7) end)
	task.delay(2.6, function()
		if ui and ui.waiting then
			tw(loading, 0.6, { TextTransparency = 0.1 })
			tw(barBg, 0.6, { BackgroundTransparency = 0.85 })
			tw(bar, 0.6, { BackgroundTransparency = 0 })
		end
	end)
	skipConn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.Keyboard then
			skipped = true
		end
	end)
	return ui
end

-- returns once the map exists and nothing new has replicated for a short moment (or a hard cap passes)
local function waitForWorld(capSeconds)
	local t0 = os.clock()
	local lastAdd = os.clock()
	local added = 0
	local conn = workspace.DescendantAdded:Connect(function()
		lastAdd = os.clock()
		added += 1
	end)
	while os.clock() - t0 < capSeconds do
		if ui then
			local pct = math.clamp(math.floor(added / 520), 0, 99)
			ui.loading.Text = Reveal.Track("Building the world") .. "   " .. pct .. "%"
			ui.bar.Size = UDim2.fromScale(pct / 100, 1)
		end
		if game:IsLoaded() and workspace:FindFirstChild("Map") and os.clock() - lastAdd > 0.9 then break end
		task.wait(0.2)
	end
	conn:Disconnect()
end

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
	tw(u.blur, 1.2, { Size = 0 })
	task.delay(1.3, function() if u.blur.Parent then u.blur:Destroy() end end)

	-- camera path: positions + where it looks
	local pts, looks = {}, {}
	local function key(pos, look) table.insert(pts, pos); table.insert(looks, look) end
	key(Vector3.new(0, 150, 3050), Vector3.new(0, 20, 2500))   -- high above Heaven
	key(Vector3.new(50, 100, 2050), Vector3.new(0, 10, 1500))  -- Shadow / Space
	key(Vector3.new(-40, 65, 1150), Vector3.new(0, 5, 700))    -- Candy / Crystal
	key(Vector3.new(30, 40, 380), Vector3.new(0, 5, 60))       -- Frozen / Volcano
	key(Vector3.new(0, 22, 45), Vector3.new(0, 10, -30))       -- the Launch Hall's open front
	if base and base:FindFirstChild("Center") then
		local c = base.Center.CFrame
		key((c * CFrame.new(0, 26, -55)).Position, c.Position + Vector3.new(0, 4, 0)) -- swing over to your base
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		key(hrp.Position - hrp.CFrame.LookVector * 14 + Vector3.new(0, 7, 0), hrp.Position + Vector3.new(0, 2, 0))
	end

	local gui, black, skip, hideTitle = u.gui, u.black, u.skip, u.hideTitle
	if hud then hud.Enabled = false end
	local finished = false
	if not skipped then
		workspace:SetAttribute("TPFC_IntroPlaying", true)
		Effects.Letterbox(true)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(pts[1], looks[1])
		-- let the first frames of the fly-over render before revealing it
		RunService.RenderStepped:Wait()
		RunService.RenderStepped:Wait()
		tw(black, 1.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)

		local DURATION = 9
		local start = os.clock()
		local segs = #pts - 1
		local function at(list, j) return list[math.clamp(j, 1, #list)] end
		while not skipped do
			local k = (os.clock() - start) / DURATION
			if k >= 1 then finished = true break end
			local e = smooth(k) * segs
			local i = math.min(math.floor(e) + 1, segs)
			local f = e - (i - 1)
			local pos = catmull(at(pts, i - 1), at(pts, i), at(pts, i + 1), at(pts, i + 2), f)
			local look = catmull(at(looks, i - 1), at(looks, i), at(looks, i + 1), at(looks, i + 2), f)
			camera.CFrame = CFrame.lookAt(pos, look)
			if k > 0.45 then hideTitle(0.7) end
			RunService.RenderStepped:Wait()
		end
	end
	if skipConn then skipConn:Disconnect() end
	workspace:SetAttribute("TPFC_IntroPlaying", nil)

	-- hand the camera back to the player
	Effects.Letterbox(false)
	camera.CameraType = Enum.CameraType.Custom
	if hud then hud.Enabled = true end
	hideTitle(0.3)
	tw(skip, 0.3, { TextTransparency = 1 })
	tw(black, 0.4, { BackgroundTransparency = 1 })
	if finished then Effects.Flash(Color3.new(1, 1, 1), 0.6, 0.35) end
	Sounds.Play("Whoosh", 1.2)
	task.delay(0.6, function() gui:Destroy() end)
	ui = nil
end

return Intro
