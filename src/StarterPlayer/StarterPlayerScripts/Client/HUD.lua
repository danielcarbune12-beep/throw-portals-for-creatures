-- HUD: money / throw-power counters, side menu buttons, throw meter, mobile throw button,
-- carry hint, toasts and the animated panel framework used by Panels.
-- Location: StarterPlayer > StarterPlayerScripts > Client > HUD (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local K = require(script.Parent.UIKit)
local State = require(script.Parent.ClientState)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)

local HUD = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local gui = K.new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local root = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local uiScale = K.new("UIScale", { Parent = root })
HUD.Gui, HUD.Root = gui, root

-- scale whole UI to the screen (phones get a slightly larger relative size)
local function rescale()
	local v = camera.ViewportSize
	local s = math.min(v.X / 1280, v.Y / 720)
	if isTouch then s *= 1.15 end
	uiScale.Scale = math.clamp(s, 0.55, 1.25)
	root.Size = UDim2.fromScale(1 / uiScale.Scale, 1 / uiScale.Scale)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

---------------------------------------------------------------- top counters
local top = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(900, 64),
	BackgroundTransparency = 1, Parent = root }, { K.list(Enum.FillDirection.Horizontal, 14) })

local function pill(iconText, c1, c2, width)
	local f = K.new("Frame", { Size = UDim2.fromOffset(width, 58), BackgroundColor3 = Color3.new(1, 1, 1), Parent = top },
		{ K.corner(29), K.stroke(3), K.grad(c1, c2, 90) })
	local icon = K.new("Frame", { Size = UDim2.fromOffset(62, 62), Position = UDim2.fromOffset(-10, -2), BackgroundColor3 = Color3.new(1, 1, 1), Parent = f },
		{ K.round(), K.stroke(3), K.grad(c1:Lerp(Color3.new(1, 1, 1), 0.4), c1, 90) })
	K.label(iconText, UDim2.fromScale(0.7, 0.7), Color3.new(1, 1, 1), { Position = UDim2.fromScale(0.15, 0.15), Parent = icon })
	local main = K.label("0", UDim2.new(1, -66, 0.62, 0), Color3.new(1, 1, 1), { Position = UDim2.fromOffset(58, 3), TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	local sub = K.label("", UDim2.new(1, -66, 0.32, 0), Color3.fromRGB(255, 255, 220), { Position = UDim2.new(0, 58, 0.62, -2), TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	return f, main, sub, icon
end

local moneyPill, moneyLabel, incomeLabel, moneyIcon = pill("$", Color3.fromRGB(120, 230, 90), Color3.fromRGB(40, 160, 60), 260)
local powerPill, powerLabel, distLabel = pill("⚡", Color3.fromRGB(255, 200, 60), Color3.fromRGB(240, 120, 30), 220)
local strengthPill, strengthLabel, strengthSub = pill("💪", Color3.fromRGB(255, 110, 110), Color3.fromRGB(200, 40, 70), 200)
local carryPill, carryLabel, carrySub = pill("🐾", Color3.fromRGB(150, 120, 255), Color3.fromRGB(90, 60, 200), 170)
Effects.MoneyTarget = moneyIcon
Effects.OnCoinArrive = function() K.pop(moneyIcon, 1.25) end

local shownMoney = 0
RunService.RenderStepped:Connect(function(dt)
	local target = State.Data.Money or 0
	if math.abs(target - shownMoney) < 1 then shownMoney = target
	else shownMoney += (target - shownMoney) * math.min(1, dt * 8) end
	moneyLabel.Text = Format.Money(shownMoney)
end)

function HUD.Refresh()
	local d = State.Data
	incomeLabel.Text = "+" .. Format.Money(d.Income or 0) .. "/s"
	powerLabel.Text = math.floor(d.MaxDistance or 0) .. "m"
	distLabel.Text = "Throw Lv." .. (d.Upgrades and d.Upgrades.ThrowPower or 1)
	local newStr = Format.Short(d.Strength or 0)
	if strengthLabel.Text ~= newStr then
		strengthLabel.Text = newStr
		K.pop(strengthPill, 1.08)
	end
	strengthSub.Text = "Strength"
	if HUD._lastMax ~= d.MaxDistance and HUD.DrawTicks then
		HUD._lastMax = d.MaxDistance
		HUD.DrawTicks()
	end
	local carry = d.Carry and #d.Carry or 0
	local stored = #d.Creatures - #d.Placed
	carryLabel.Text = (#d.Placed) .. "/" .. (d.SlotsOpen or 0)
	carrySub.Text = "Bag " .. stored .. "/" .. (d.StorageCap or 0)
	HUD.SetCarry(carry)
end

---------------------------------------------------------------- side buttons
local side = K.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(96, 560),
	BackgroundTransparency = 1, Parent = root }, { K.list(Enum.FillDirection.Vertical, 10) })
HUD.SideButtons = {}
function HUD.AddSideButton(name, icon, c1, c2, callback)
	local b = K.button("", c1, c2, UDim2.fromOffset(84, 70), { Parent = side, LayoutOrder = #HUD.SideButtons + 1 })
	b.Label.Text = icon
	b.Label.Size = UDim2.new(1, -12, 0.62, 0)
	K.label(name, UDim2.new(1, -4, 0.32, 0), Color3.new(1, 1, 1), { Position = UDim2.new(0, 2, 0.64, -2), Parent = b, ZIndex = 2 })
	b.Activated:Connect(callback)
	HUD.SideButtons[name] = b
	return b
end

---------------------------------------------------------------- POWER BOX (right side of the screen)
local powerBox = K.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.45, 0), Size = UDim2.fromOffset(150, 430),
	BackgroundColor3 = Color3.new(1, 1, 1), Parent = root }, { K.corner(22), K.stroke(4), K.grad(Color3.fromRGB(120, 80, 220), Color3.fromRGB(60, 30, 130), 90) })
local meterScale = K.new("UIScale", { Scale = 1, Parent = powerBox })
K.label("⚡ POWER", UDim2.new(1, -16, 0, 34), Color3.fromRGB(255, 235, 120), { Position = UDim2.fromOffset(8, 6), Parent = powerBox })
-- the vertical bar
local meter = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 10, 0, 46), Size = UDim2.new(0, 46, 0, 280),
	BackgroundColor3 = Color3.fromRGB(30, 20, 50), Parent = powerBox }, { K.corner(14), K.stroke(3) })
-- zone ticks: where each zone starts at your current max distance
local ticks = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = meter })
local function drawTicks()
	ticks:ClearAllChildren()
	local maxD = (State.Data.MaxDistance or 45) * 1.15
	for _, id in ipairs(Config.WorldOrder) do
		local from = Config.ZoneBounds[id][1]
		if from > 0 and from < maxD then
			local y = 1 - from / maxD
			K.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Config.Worlds[id].atmo, BorderSizePixel = 0, ZIndex = 4, Parent = ticks })
			K.label(Config.Worlds[id].name:match("%S+$"), UDim2.fromOffset(58, 16), Config.Worlds[id].atmo:Lerp(Color3.new(1, 1, 1), 0.4),
				{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -4, y, 0), ZIndex = 4, Parent = ticks })
		end
	end
end
HUD.DrawTicks = drawTicks
local perfect = K.new("Frame", { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.08), BackgroundColor3 = Color3.fromRGB(255, 220, 80),
	BorderSizePixel = 0, ZIndex = 2, Parent = meter }, { K.corner(14) })
local fill = K.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0, ZIndex = 2, Parent = meter },
	{ K.corner(14), K.new("UIGradient", { Rotation = -90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 200, 255)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(170, 100, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 160)) }) }) })
local marker = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 18, 0, 9),
	BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = meter }, { K.corner(4), K.stroke(3) })
local meterText = K.label(isTouch and "Hold THROW" or "Hold Click / F", UDim2.new(1, -14, 0, 86), Color3.new(1, 1, 1),
	{ Position = UDim2.new(0, 7, 0, 334), Parent = powerBox, TextWrapped = true })
local perfectText = K.label("PERFECT!", UDim2.fromOffset(240, 56), Color3.fromRGB(255, 225, 90),
	{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -10, 0, 70), Parent = powerBox, TextTransparency = 1 })
perfectText:FindFirstChildOfClass("UIStroke").Transparency = 1

HUD.TC = nil
local wasCharging = false
RunService.RenderStepped:Connect(function()
	local tc = HUD.TC
	if not tc then return end
	local p = tc.Power
	fill.Size = UDim2.fromScale(1, p)
	marker.Position = UDim2.fromScale(0.5, 1 - p)
	if tc.Charging then
		local dist = (State.Data.MaxDistance or 45) * p * (p >= 0.92 and 1.15 or 1)
		local luck = Config.LuckFromDistance(dist)
		meterText.Text = string.format("%d%%\n%dm\n%s\nLuck x%.2f", math.floor(p * 100), math.floor(dist),
			Config.Worlds[Config.WorldAt(Vector3.new(0, 0, dist))].name, luck)
		perfect.BackgroundColor3 = p >= 0.92 and Color3.fromRGB(255, 255, 160) or Color3.fromRGB(255, 220, 80)
		if not wasCharging then K.tween(meterScale, 0.25, { Scale = 1.06 }, Enum.EasingStyle.Back) end
	elseif wasCharging then
		K.tween(meterScale, 0.3, { Scale = 1 })
		meterText.Text = HUD.InZone and (isTouch and "Hold THROW" or "Hold Click / F") or "Go to the Launch Hall"
	end
	wasCharging = tc.Charging
end)

function HUD.ThrowFeedback(power, isPerfect)
	if isPerfect then
		perfectText.TextTransparency = 0
		local st = perfectText:FindFirstChildOfClass("UIStroke"); st.Transparency = 0
		K.pop(perfectText, 1.6)
		task.delay(0.8, function()
			K.tween(perfectText, 0.3, { TextTransparency = 1 })
			K.tween(st, 0.3, { Transparency = 1 })
		end)
	end
end

-- power bar floating over your head while charging
local headBB = K.new("BillboardGui", { Size = UDim2.fromOffset(170, 26), StudsOffset = Vector3.new(0, 3.6, 0), AlwaysOnTop = true, Enabled = false, ResetOnSpawn = false, Parent = gui })
local headBar = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 30, 60), Parent = headBB }, { K.corner(13), K.stroke(3) })
K.new("Frame", { Position = UDim2.fromScale(0.92, 0), Size = UDim2.fromScale(0.08, 1), BackgroundColor3 = Color3.fromRGB(255, 220, 80), BorderSizePixel = 0, Parent = headBar }, { K.corner(13) })
local headFill = K.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = headBar },
	{ K.corner(13), K.grad(Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 90, 170), 0) })
RunService.RenderStepped:Connect(function()
	local tc = HUD.TC
	local head = player.Character and player.Character:FindFirstChild("Head")
	headBB.Adornee = head
	headBB.Enabled = tc ~= nil and tc.Charging and head ~= nil
	if headBB.Enabled then headFill.Size = UDim2.fromScale(tc.Power, 1) end
end)

---------------------------------------------------------------- training button
local trainBtn = K.button("💪 LIFT", Color3.fromRGB(255, 120, 90), Color3.fromRGB(210, 50, 60), UDim2.fromOffset(260, 74),
	{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Parent = root, Visible = false })
local autoBtn = K.button("AUTO: OFF", Color3.fromRGB(150, 150, 170), Color3.fromRGB(100, 100, 120), UDim2.fromOffset(140, 50),
	{ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 140, 1, -162), Parent = root, Visible = false })
HUD.TrainHeld, HUD.AutoTrain, HUD.TrainStation = false, false, nil
trainBtn.InputBegan:Connect(function(i)
	if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and HUD.TrainStation then HUD.TrainHeld = true end
end)
trainBtn.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then HUD.TrainHeld = false end
end)
autoBtn.Activated:Connect(function()
	HUD.AutoTrain = not HUD.AutoTrain
	K.setButton(autoBtn, HUD.AutoTrain and "AUTO: ON" or "AUTO: OFF", HUD.AutoTrain and Color3.fromRGB(110, 220, 90) or Color3.fromRGB(150, 150, 170),
		HUD.AutoTrain and Color3.fromRGB(40, 150, 60) or Color3.fromRGB(100, 100, 120))
end)
-- PERSONAL GYM: LIFT (hold) + AUTO + UPGRADE (buy the next equipment with money)
local upgradeBtn = K.button("⬆ UPGRADE", Color3.fromRGB(110, 220, 90), Color3.fromRGB(40, 150, 60), UDim2.fromOffset(300, 50),
	{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -232), Parent = root, Visible = false })
HUD.OnUpgradeGym = nil
upgradeBtn.Activated:Connect(function() if HUD.OnUpgradeGym then HUD.OnUpgradeGym() end end)
-- level = your gym level when standing in your gym, or nil
function HUD.SetGym(level)
	HUD.TrainStation = level
	trainBtn.Visible = level ~= nil
	autoBtn.Visible = level ~= nil
	upgradeBtn.Visible = false
	if not level then HUD.TrainHeld = false return end
	local st = Config.TrainingStations[level]
	K.setButton(trainBtn, "💪 LIFT  +" .. Format.Short(st.gain), Color3.fromRGB(255, 120, 90), Color3.fromRGB(210, 50, 60))
	local nextSt = Config.TrainingStations[level + 1]
	if nextSt then
		local can = (State.Data.Money or 0) >= nextSt.price
		upgradeBtn.Visible = true
		K.setButton(upgradeBtn, "⬆ " .. nextSt.name .. "  " .. Format.Money(nextSt.price), can and Color3.fromRGB(110, 220, 90) or Color3.fromRGB(150, 150, 170),
			can and Color3.fromRGB(40, 150, 60) or Color3.fromRGB(100, 100, 120))
	end
end
function HUD.TrainPulse() K.pop(trainBtn, 1.12) end

---------------------------------------------------------------- collect popup (collect from anywhere)
local collectBtn = K.button("✨ COLLECT", Color3.fromRGB(120, 230, 255), Color3.fromRGB(60, 120, 255), UDim2.fromOffset(330, 64),
	{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 124), Parent = root, Visible = false })
HUD.OnCollect = nil
local collectTarget = nil
collectBtn.Activated:Connect(function()
	if collectTarget and HUD.OnCollect then HUD.OnCollect(collectTarget) end
end)
function HUD.SetCollectable(throwId, name, color)
	local was = collectBtn.Visible
	collectTarget = throwId
	collectBtn.Visible = throwId ~= nil
	if throwId then
		K.setButton(collectBtn, "✨ COLLECT " .. name .. " ✨", color, color:Lerp(Color3.new(0, 0, 0), 0.35))
		if not was then K.pop(collectBtn, 1.25) end
	end
end
RunService.RenderStepped:Connect(function()
	if collectBtn.Visible then collectBtn.Rotation = math.sin(os.clock() * 5) * 2 end
end)

---------------------------------------------------------------- "throw from here" animation (limit reached / not on the throw line)
local throwHere = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(760, 210),
	BackgroundTransparency = 1, Visible = false, Parent = root })
local thScale = K.new("UIScale", { Scale = 0, Parent = throwHere })
local thTitle = K.label("🛑 YOU CAN'T GO FURTHER!", UDim2.new(1, 0, 0.42, 0), Color3.fromRGB(255, 90, 110), { Parent = throwHere })
local thSub = K.label("THROW YOUR PORTAL FROM HERE!", UDim2.new(1, 0, 0.32, 0), Color3.fromRGB(255, 230, 120), { Position = UDim2.fromScale(0, 0.42), Parent = throwHere })
local thArrow = K.label("⬇ ⬇ ⬇", UDim2.new(1, 0, 0.26, 0), Color3.new(1, 1, 1), { Position = UDim2.fromScale(0, 0.74), Parent = throwHere })
local thUntil = 0
function HUD.ShowThrowHere(title, sub)
	thTitle.Text = title or "🛑 YOU CAN'T GO FURTHER!"
	thSub.Text = sub or (isTouch and "Throw your portal from the Launch Hall — hold THROW!" or "Throw your portal from the Launch Hall — hold CLICK!")
	local wasVisible = throwHere.Visible and os.clock() < thUntil
	thUntil = os.clock() + 2.6
	throwHere.Visible = true
	if not wasVisible then
		thScale.Scale = 0
		K.tween(thScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		Sounds.Play("Error")
	end
	if HUD.ThrowButton then K.pop(HUD.ThrowButton, 1.2) end
end
RunService.RenderStepped:Connect(function()
	if not throwHere.Visible then return end
	local t = os.clock()
	throwHere.Rotation = math.sin(t * 6) * 2.5
	thArrow.Position = UDim2.fromScale(0, 0.74 + math.abs(math.sin(t * 5)) * 0.08)
	thTitle.TextColor3 = Color3.fromRGB(255, 90, 110):Lerp(Color3.fromRGB(255, 200, 90), (math.sin(t * 8) + 1) / 2)
	if t > thUntil and thScale.Scale > 0.99 then
		K.tween(thScale, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.3, function() if os.clock() > thUntil then throwHere.Visible = false end end)
	end
end)

-- meter/throw button react to whether you're standing on the throw line
HUD.InZone = true
function HUD.SetInZone(inZone)
	if HUD.InZone == inZone then return end
	HUD.InZone = inZone
	if not (HUD.TC and HUD.TC.Charging) then
		meterText.Text = inZone and (isTouch and "Hold THROW" or "Hold Click / F") or "Go to the Launch Hall"
		if inZone then
			HUD.ShowThrowHere("🌀 PORTAL LAUNCH HALL", isTouch and "Hold THROW, release to launch your portal!" or "Hold CLICK, release to launch your portal!")
		end
	end
end

-- big throw button (always shown on touch; smaller on PC)
local throwBtn = K.button("THROW", Color3.fromRGB(255, 120, 200), Color3.fromRGB(170, 60, 255),
	isTouch and UDim2.fromOffset(150, 150) or UDim2.fromOffset(120, 120),
	{ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24), Parent = root })
throwBtn:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
throwBtn.Label.Size = UDim2.new(0.8, 0, 0.3, 0)
throwBtn.Label.Position = UDim2.fromScale(0.1, 0.35)
throwBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		if HUD.TC then HUD.TC.BeginCharge() end
	end
end)
throwBtn.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		if HUD.TC then HUD.TC.EndCharge() end
	end
end)
HUD.ThrowButton = throwBtn
RunService.RenderStepped:Connect(function()
	local r = throwBtn:FindFirstChild("UIStroke")
	if r then r.Color = (HUD.TC and HUD.TC.Charging) and Color3.fromRGB(255, 240, 120) or K.Dark end
	throwBtn.Label.TextTransparency = HUD.InZone and 0 or 0.55
end)

---------------------------------------------------------------- carry hint
local carryHint = K.label("", UDim2.fromOffset(520, 34), Color3.fromRGB(200, 255, 200),
	{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Parent = root, Visible = false })
function HUD.SetCarry(n)
	carryHint.Visible = n > 0
	carryHint.Text = "Carrying " .. n .. "/" .. Config.CarryLimit .. " creatures — bring them to your base! ➜"
end
RunService.RenderStepped:Connect(function()
	if carryHint.Visible then carryHint.Rotation = math.sin(os.clock() * 3) * 1.5 end
end)

---------------------------------------------------------------- toasts
local toastHolder = K.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -184, 0, 90), Size = UDim2.fromOffset(380, 400),
	BackgroundTransparency = 1, Parent = root }, { K.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right) })
local KIND_COLORS = { info = Color3.fromRGB(110, 140, 255), error = Color3.fromRGB(255, 80, 90), money = Color3.fromRGB(80, 210, 90),
	discover = Color3.fromRGB(255, 170, 60), success = Color3.fromRGB(80, 210, 120) }
function HUD.Notify(text, kind)
	local col = KIND_COLORS[kind] or (Config.Rarities[kind] and Config.Rarities[kind].color) or KIND_COLORS.info
	if kind == "error" then Sounds.Play("Error") end
	local f = K.new("Frame", { Size = UDim2.fromOffset(380, 56), BackgroundColor3 = Color3.new(1, 1, 1), Parent = toastHolder },
		{ K.corner(14), K.stroke(3), K.grad(col:Lerp(Color3.new(1, 1, 1), 0.25), col:Lerp(Color3.new(0, 0, 0), 0.25), 90) })
	K.label(text, UDim2.new(1, -20, 1, -12), Color3.new(1, 1, 1), { Position = UDim2.fromOffset(10, 6), Parent = f })
	local s = K.new("UIScale", { Scale = 0, Parent = f })
	K.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(4, function()
		K.tween(s, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.3, function() f:Destroy() end)
	end)
	local kids = {}
	for _, c in ipairs(toastHolder:GetChildren()) do if c:IsA("Frame") then table.insert(kids, c) end end
	if #kids > 5 then kids[1]:Destroy() end
end

---------------------------------------------------------------- panel framework
local blur = Instance.new("BlurEffect"); blur.Size = 0; blur.Parent = game:GetService("Lighting")
local openPanel = nil
HUD.Panels = {}

function HUD.MakePanel(name, title, c1, c2)
	local frame = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(820, 540),
		BackgroundColor3 = K.Panel, Visible = false, Parent = root }, { K.corner(24), K.stroke(5) })
	local scale = K.new("UIScale", { Scale = 0, Parent = frame })
	local header = K.new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = Color3.new(1, 1, 1), Parent = frame },
		{ K.corner(24), K.grad(c1, c2, 90) })
	K.new("Frame", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = header }, { K.grad(c2, c2, 90) })
	K.label(title, UDim2.new(1, -140, 0, 52), Color3.new(1, 1, 1), { Position = UDim2.fromOffset(24, 9), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	local close = K.button("X", Color3.fromRGB(255, 90, 90), Color3.fromRGB(200, 40, 60), UDim2.fromOffset(54, 54),
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Parent = header, ZIndex = 3 })
	local subbar = K.new("Frame", { Size = UDim2.new(1, -40, 0, 46), Position = UDim2.fromOffset(20, 80), BackgroundTransparency = 1, Parent = frame })
	local content = K.new("ScrollingFrame", { Size = UDim2.new(1, -32, 1, -146), Position = UDim2.fromOffset(16, 132), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 8, ScrollBarImageColor3 = c2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		Parent = frame }, { K.pad(6) })
	local panel = { name = name, frame = frame, scale = scale, content = content, subbar = subbar, refresh = nil }
	close.Activated:Connect(function() HUD.Close() end)
	HUD.Panels[name] = panel
	return panel
end

function HUD.Open(name)
	local p = HUD.Panels[name]
	if not p then return end
	if openPanel == p then HUD.Close() return end
	if openPanel then
		local old = openPanel
		old.frame.Visible = false
		old.scale.Scale = 0
	end
	openPanel = p
	p.frame.Visible = true
	p.scale.Scale = 0.6
	p.frame.Position = UDim2.fromScale(0.5, 0.6)
	K.tween(p.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	K.tween(p.frame, 0.35, { Position = UDim2.fromScale(0.5, 0.53) }, Enum.EasingStyle.Back)
	K.tween(blur, 0.3, { Size = 12 })
	if p.refresh then p.refresh() end
end

function HUD.Close()
	local p = openPanel
	if not p then return end
	openPanel = nil
	K.tween(p.scale, 0.2, { Scale = 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	K.tween(blur, 0.25, { Size = 0 })
	task.delay(0.2, function() if openPanel ~= p then p.frame.Visible = false end end)
end

function HUD.IsOpen(name) return openPanel ~= nil and openPanel.name == name end

State.Changed:Connect(function(full)
	HUD.Refresh()
	if full and openPanel and openPanel.refresh then openPanel.refresh() end
end)

return HUD
