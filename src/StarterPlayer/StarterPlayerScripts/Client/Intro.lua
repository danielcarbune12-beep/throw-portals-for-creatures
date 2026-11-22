-- Intro: cinematic fly-over when you join. The camera sweeps down the whole lane (every zone),
-- past the Portal Launch Hall, and lands at your base while the title animates in.
-- Click / tap / any key to skip.
-- Location: StarterPlayer > StarterPlayerScripts > Client > Intro (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local K = require(script.Parent.UIKit)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)
local T = require(script.Parent.UITheme)
local Reveal = require(script.Parent.RevealTitle)
local TweenService = game:GetService("TweenService")

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

function Intro.Play(hud)
	-- wait for the world and our base to exist
	local t0 = os.clock()
	while not workspace:FindFirstChild("Map") and os.clock() - t0 < 30 do task.wait(0.2) end
	local idx
	repeat idx = player:GetAttribute("BaseIndex"); task.wait(0.2) until (idx and idx > 0) or os.clock() - t0 > 30
	local base = workspace:FindFirstChild("Bases") and workspace.Bases:FindFirstChild("Base" .. tostring(idx))
	local char = player.Character or player.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.5)

	-- camera path: positions + where it looks
	local pts, looks = {}, {}
	local function key(pos, look) table.insert(pts, pos); table.insert(looks, look) end
	key(Vector3.new(0, 170, 3050), Vector3.new(0, 20, 2500))   -- high above Heaven
	key(Vector3.new(50, 110, 2050), Vector3.new(0, 10, 1500))  -- Shadow / Space
	key(Vector3.new(-40, 70, 1150), Vector3.new(0, 5, 700))    -- Candy / Crystal
	key(Vector3.new(30, 40, 380), Vector3.new(0, 5, 60))       -- Frozen / Volcano
	key(Vector3.new(0, 22, 45), Vector3.new(0, 10, -30))       -- the Launch Hall's open front
	if base then
		local c = base.Center.CFrame
		key((c * CFrame.new(0, 26, -55)).Position, c.Position + Vector3.new(0, 4, 0)) -- swing over to your base
	end
	-- end just behind your character, where the normal camera will take over
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		key(hrp.Position - hrp.CFrame.LookVector * 14 + Vector3.new(0, 7, 0), hrp.Position + Vector3.new(0, 2, 0))
	end

	-- UI: black fade, trailer-style title card, skip hint
	local gui = K.new("ScreenGui", { Name = "Intro", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 50, Parent = player.PlayerGui })
	local black = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = gui })
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
	local eyebrow = line(Reveal.Track("Welcome to"), fnt("MontserratBold", Enum.Font.GothamBold), T.Gold, 0.08, 16, 16, 1.2)
	local line1 = line("THROW PORTALS", fnt("MontserratBlack", Enum.Font.GothamBlack), Color3.new(1, 1, 1), 0.42, 104, 104, 3.5)
	local line2 = line(Reveal.Track("For creatures"), fnt("MontserratBold", Enum.Font.GothamBold), T.Gold, 0.72, 26, 26, 1.5)
	local sub = line(Reveal.Track("Throw   ·   catch   ·   collect"), fnt("MontserratMedium", Enum.Font.GothamMedium), T.Muted, 0.95, 14, 14, 1)
	local shine = K.new("UIGradient", { Rotation = 12, Offset = Vector2.new(-1, 0), Parent = line1,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.42, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, T.Gold), ColorSequenceKeypoint.new(0.58, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) }) })
	local ruleBars = {}
	for side = -1, 1, 2 do
		local r = K.new("Frame", { AnchorPoint = Vector2.new(side < 0 and 1 or 0, 0.5), Position = UDim2.new(0.5, side * 110, 0.08, 0), Size = UDim2.new(0, 0, 0, 1),
			BackgroundColor3 = T.Gold, Parent = title })
		K.new("UIGradient", { Transparency = NumberSequence.new(side < 0 and 1 or 0, side < 0 and 0 or 1), Parent = r })
		table.insert(ruleBars, r)
	end
	local skip = K.new("TextLabel", { Text = Reveal.Track("Click to skip"), Font = fnt("MontserratMedium", Enum.Font.GothamMedium), TextSize = 12,
		TextColor3 = T.Muted, TextTransparency = 0.35, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -26), Size = UDim2.fromOffset(220, 16), TextXAlignment = Enum.TextXAlignment.Right, Parent = gui })
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

	if hud then hud.Enabled = false end
	Effects.Letterbox(true)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(pts[1], looks[1])
	tw(black, 1.4, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	task.delay(0.6, function()
		showLine(line1, 0.9)
		tw(titleScale, 1.6, { Scale = 1 }, Enum.EasingStyle.Quint)
		tw(shine, 1.4, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		Sounds.Play("Rare", 0.9)
	end)
	task.delay(1.0, function()
		showLine(eyebrow, 0.6)
		for _, r in ipairs(ruleBars) do tw(r, 0.9, { Size = UDim2.new(0.18, 0, 0, 1) }, Enum.EasingStyle.Quint) end
	end)
	task.delay(1.3, function() showLine(line2, 0.7) end)
	task.delay(1.9, function() showLine(sub, 0.7) end)

	local skipped = false
	local conn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.Keyboard then
			skipped = true
		end
	end)

	local DURATION = 11
	local start = os.clock()
	local segs = #pts - 1
	while not skipped do
		local k = (os.clock() - start) / DURATION
		if k >= 1 then break end
		local e = smooth(k) * segs
		local i = math.min(math.floor(e) + 1, segs)
		local f = e - (i - 1)
		local function at(list, j) return list[math.clamp(j, 1, #list)] end
		local pos = catmull(at(pts, i - 1), at(pts, i), at(pts, i + 1), at(pts, i + 2), f)
		local look = catmull(at(looks, i - 1), at(looks, i), at(looks, i + 1), at(looks, i + 2), f)
		camera.CFrame = CFrame.lookAt(pos, look)
		if k > 0.62 then hideTitle(0.7) end
		RunService.RenderStepped:Wait()
	end
	conn:Disconnect()

	-- hand the camera back to the player
	Effects.Letterbox(false)
	camera.CameraType = Enum.CameraType.Custom
	if hud then hud.Enabled = true end
	hideTitle(0.3)
	tw(skip, 0.3, { TextTransparency = 1 })
	Effects.Flash(Color3.new(1, 1, 1), 0.6, 0.35)
	Sounds.Play("Whoosh", 1.2)
	task.delay(0.6, function() gui:Destroy() end)
end

return Intro
