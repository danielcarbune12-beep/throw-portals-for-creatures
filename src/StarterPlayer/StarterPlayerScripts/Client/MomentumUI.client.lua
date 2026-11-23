-- MomentumUI: shows the perfect-throw streak and the server-wide Rift Storm.
-- Location: StarterPlayer > StarterPlayerScripts > Client > MomentumUI (LocalScript)
--
--   * Streak badge (bottom centre): appears after a perfect throw, "PERFECT STREAK x3 · +15% luck",
--     and fades after a few seconds. Driven by the player attribute ThrowCombo (server-owned).
--   * Rift Storm banner (top centre) with a live countdown while workspace RiftStormEnds is in the
--     future, plus a gentle storm grade on the sky (no flashing; respects Reduced Motion).
-- Display only: the luck itself is applied on the server.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local T = require(script.Parent.UITheme)
local Settings = require(script.Parent.ClientSettings)

local player = Players.LocalPlayer

local function tw(o, t, props)
	local x = TweenService:Create(o, TweenInfo.new(Settings.ReducedMotion and 0 or t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

local gui = Instance.new("ScreenGui")
gui.Name = "MomentumUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 12
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- parchment plate in the sanctuary UI style: light panel, brass rim, Merriweather heading
local function plate(name, size, pos, anchor)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = anchor
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = T.Raised
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = T.TrimGold
	s.Thickness = 2
	s.Transparency = 1
	s.Parent = f
	f.Parent = gui
	local function line(text, y, h, face, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.new(0, 14, 0, y)
		l.Size = UDim2.new(1, -28, 0, h)
		l.FontFace = face
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		l.TextTransparency = 1
		l.Parent = f
		return l
	end
	return f, s, line
end

local function show(f, s, labels, on)
	tw(f, 0.35, { BackgroundTransparency = on and 0.05 or 1 })
	tw(s, 0.35, { Transparency = on and 0 or 1 })
	for _, l in ipairs(labels) do
		tw(l, 0.35, { TextTransparency = on and 0 or 1 })
	end
end

---------------------------------------------------------------- perfect streak
local streak, streakStroke, sl = plate("PerfectStreak", UDim2.fromOffset(300, 58), UDim2.new(0.5, 0, 1, -150), Vector2.new(0.5, 1))
local streakTitle = sl("", 6, 26, T.TitleFace, T.Gold)
local streakSub = sl("", 34, 17, Font.fromEnum(T.Font), T.Muted)
local streakToken = 0
local function onCombo()
	local n = player:GetAttribute("ThrowCombo") or 0
	streakToken += 1
	local token = streakToken
	if n <= 0 then
		show(streak, streakStroke, { streakTitle, streakSub }, false)
		return
	end
	streakTitle.Text = n >= Config.Combo.max and "Perfect streak · MAX" or ("Perfect streak ×" .. n)
	streakSub.Text = "+" .. math.floor(Config.Combo.perStep * n * 100 + 0.5) .. "% luck on your next roll"
	show(streak, streakStroke, { streakTitle, streakSub }, true)
	if not Settings.ReducedMotion then
		local sc = streak:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		sc.Scale = 1.08
		sc.Parent = streak
		tw(sc, 0.3, { Scale = 1 })
	end
	task.delay(4, function()
		if streakToken == token then
			show(streak, streakStroke, { streakTitle, streakSub }, false)
		end
	end)
end
player:GetAttributeChangedSignal("ThrowCombo"):Connect(onCombo)

---------------------------------------------------------------- Rift Storm
local storm, stormStroke, rl = plate("RiftStorm", UDim2.fromOffset(340, 62), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0))
local stormTitle = rl("Rift Storm", 6, 28, T.TitleFace, T.Jade)
local stormSub = rl("", 36, 18, Font.fromEnum(T.Font), T.Muted)

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "RiftStormGrade"
grade.Enabled = true
grade.Parent = Lighting

local active = false
local function setActive(on)
	if on == active then return end
	active = on
	show(storm, stormStroke, { stormTitle, stormSub }, on)
	-- a cool, charged sky while the rift is open; no flashing
	tw(grade, 3, on and { TintColor = Color3.fromRGB(228, 236, 255), Contrast = 0.06, Saturation = 0.04 } or { TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0 })
	if on then
		pcall(function() require(script.Parent.Sounds).Play("Rare", 0.8) end)
	end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then return end
	acc = 0
	local left = (workspace:GetAttribute("RiftStormEnds") or 0) - os.time()
	if left > 0 then
		setActive(true)
		stormSub.Text = string.format("×%.1f luck for everyone · %d:%02d", Config.RiftStorm.luck, math.floor(left / 60), left % 60)
	else
		setActive(false)
	end
end)
