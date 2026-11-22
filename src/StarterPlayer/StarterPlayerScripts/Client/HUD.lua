-- Compact sanctuary HUD and one shared, responsive panel layer.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Format = require(RS.Shared.Format)
local K = require(script.Parent.UIKit)
local T = K.Theme
local Sky = require(script.Parent.SkyforgeUI)
local State = require(script.Parent.ClientState)
local Settings = require(script.Parent.ClientSettings)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)
local HUD = { Panels = {}, SideButtons = {}, InZone = false, TrainHeld = false, AutoTrain = false }
local player = Players.LocalPlayer
local gui = K.new("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,
	DisplayOrder = 10,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local root = K.new("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local scaler = K.new("UIScale", { Parent = root })
HUD.Gui, HUD.Root = gui, root
local world =
	K.new("Frame", { Name = "Gameplay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })
local top = K.new("Frame", { Name = "Resources", BackgroundTransparency = 1, Parent = world })
local stats = {}
local function stat(key, icon, caption, accent)
	local f = K.surface(top, key, UDim2.fromOffset(170, 54), nil, T.Panel)
	K.Icon(icon, f, UDim2.fromOffset(25, 25), accent, UDim2.fromOffset(12, 14))
	local value = K.text(f, "0", 48, 5, -54, 25, 21, T.Text, true)
	local sub = K.text(f, caption, 48, 31, -54, 17, 13, T.Muted)
	table.insert(stats, f)
	return value, sub, f
end
local money, income, moneyIcon = stat("Money", "Coin", "Income", T.Gold)
local shownMoney = 0
local power, distance = stat("Reach", "Arrow", "Throw range", T.Cyan)
local strength = stat("Strength", "Strength", "Strength", T.Violet)
local placed, storage = stat("Capacity", "Pet", "Garden slots", T.Success)
Effects.MoneyTarget = moneyIcon
Effects.OnCoinArrive = function()
	K.pop(moneyIcon)
end
local side = K.new("Frame", { Name = "Navigation", BackgroundTransparency = 1, Parent = world })
K.new("UIGridLayout", {
	CellSize = UDim2.fromOffset(78, 62),
	CellPadding = UDim2.fromOffset(6, 6),
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = side,
})

-- Portal Sanctuary style, matching the lobby gate: white marble, gold trim, purple medallions.
local SANCT = {
	Marble = Color3.fromRGB(248, 245, 252),
	Marble2 = Color3.fromRGB(221, 214, 236),
	Purple = Color3.fromRGB(112, 72, 196),
	PurpleLight = Color3.fromRGB(156, 118, 242),
	PurpleDeep = Color3.fromRGB(58, 34, 112),
	Gold = Color3.fromRGB(241, 202, 115),
	Cream = Color3.fromRGB(255, 242, 205),
}
HUD.SanctuaryColors = SANCT

-- Approved enamel art, one consistent restrained Skyforge tile.
local function sanctuaryTile(name, icon, size, parent, order)
	local b = K.button("", T.Panel, nil, size or UDim2.fromOffset(148, 126), {
		Name = "Nav_" .. name,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Sky.Trim(b)
	K.Icon(icon, b, UDim2.fromOffset(70, 70), T.Text, UDim2.new(0.5, -35, 0, 5))
	b.Label.Text = name
	b.Label.Position = UDim2.new(0, 4, 1, -40)
	b.Label.Size = UDim2.new(1, -8, 0, 32)
	b.Label.TextColor3 = T.Text
	b.Label.TextSize = 16
	return b
end
HUD.SanctuaryTile = sanctuaryTile
local navOrder = {}
local menuBtn = K.button("Menu", T.Panel, nil, UDim2.fromOffset(100, 48), {
	Name = "Menu",
	Parent = world,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -12),
	Visible = false,
})
menuBtn.Label.Position = UDim2.fromOffset(35, 0)
menuBtn.Label.Size = UDim2.new(1, -42, 1, 0)
Sky.Trim(menuBtn)
K.Icon("Menu", menuBtn, UDim2.fromOffset(20, 20), T.Text, UDim2.fromOffset(10, 14))
Sky.Trim(moneyIcon)
local homeBtn = K.button("Home", T.Panel, nil, UDim2.fromOffset(84, 48), {
	Name = "QuickHome",
	Parent = world,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 120, 1, -12),
	Visible = false,
})
function HUD.AddSideButton(name, icon, _a, _b, callback)
	if HUD.SideButtons[name] then
		return HUD.SideButtons[name]
	end
	local b = sanctuaryTile(name, icon, nil, side, #navOrder + 1)
	K.bind(b, callback)
	HUD.SideButtons[name] = b
	table.insert(navOrder, { name = name, icon = icon, callback = callback })
	return b
end
local launch = K.surface(world, "LaunchGuide", UDim2.fromOffset(354, 102), UDim2.new(1, -370, 1, -126), T.Panel)
local launchTitle = K.text(launch, "Enter the Launch Hall", 16, 12, -32, 24, 17, T.Text, true)
local launchHint = K.text(launch, "Charge a portal to discover a creature.", 16, 40, -32, 22, 14, T.Muted)
local bar = K.new("Frame", {
	Name = "ChargeTrack",
	Size = UDim2.new(1, -32, 0, 8),
	Position = UDim2.fromOffset(16, 79),
	BackgroundColor3 = T.Inset,
	Parent = launch,
}, { K.corner(4) })
K.new("Frame", {
	Name = "PerfectZone",
	Position = UDim2.fromScale(0.92, 0),
	Size = UDim2.fromScale(0.08, 1),
	BackgroundColor3 = T.Gold,
	Parent = bar,
}, { K.corner(3) })
local fill = K.new(
	"Frame",
	{ Name = "ChargeFill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Violet, Parent = bar },
	{ K.corner(3) }
)
local throwBtn = K.button(
	"Charge portal",
	T.Gold,
	nil,
	UDim2.fromOffset(164, 52),
	{ Name = "Throw", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Parent = world }
)
HUD.ThrowButton = throwBtn
throwBtn.InputBegan:Connect(function(i)
	if
		(i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1)
		and not HUD.AnyPanelOpen()
		and HUD.TC
	then
		HUD.TC.BeginCharge("Pointer")
	end
end)
Input.InputEnded:Connect(function(i)
	if
		(i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1)
		and HUD.TC
		and HUD.TC.Charging
	then
		HUD.TC.EndCharge("Pointer")
	end
end)
-- Compatibility for the retired lifting proximity hook; no gym controls exist.
function HUD.SetGym(_level)
	HUD.TrainHeld = false
end
local collect = K.button(
	"Collect creature",
	T.Success,
	nil,
	UDim2.fromOffset(300, 48),
	{ Name = "Collect", Position = UDim2.new(0.5, -150, 0, 78), Parent = world, Visible = false }
)
local collectTarget
K.bind(collect, function()
	if collectTarget and HUD.OnCollect then
		HUD.OnCollect(collectTarget)
	end
end)
function HUD.SetCollectable(id, name, color)
	collectTarget = id
	collect.Visible = id ~= nil
	if id then
		K.setButton(collect, "Collect " .. name, color or T.Success)
	end
end
local carry = K.label("", UDim2.fromOffset(450, 26), T.Success, {
	Name = "CarryHint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 74),
	Parent = world,
	Visible = false,
	TextSize = 14,
})
function HUD.SetCarry(n)
	carry.Visible = n > 0
	carry.Text = "Bring " .. n .. " creatures home to your garden."
end

local notices = K.new("Frame", {
	Name = "Notices",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 78),
	Size = UDim2.fromOffset(420, 280),
	BackgroundTransparency = 1,
	ZIndex = 40,
	Parent = root,
}, { K.list(Enum.FillDirection.Vertical, 6) })
local lastNotice, lastNoticeTime
function HUD.Notify(text, kind)
	if text == lastNotice and os.clock() - (lastNoticeTime or 0) < 1 then
		return
	end
	lastNotice, lastNoticeTime = text, os.clock()
	local col = kind == "error" and T.Danger or kind == "success" and T.Success or T.Cyan
	if kind == "error" then
		Sounds.Play("Error")
	end
	local f = K.surface(notices, "Toast", UDim2.new(1, 0, 0, 58), nil, T.Panel)
	K.Icon(kind == "error" and "Close" or "Check", f, UDim2.fromOffset(20, 20), col, UDim2.fromOffset(14, 19))
	K.text(f, text, 47, 7, -60, 44, 15, T.Text)
	task.delay(4, function()
		if f.Parent then
			f:Destroy()
		end
	end)
	local list = {}
	for _, v in notices:GetChildren() do
		if v:IsA("Frame") then
			table.insert(list, v)
		end
	end
	if #list > 3 then
		list[1]:Destroy()
	end
end
function HUD.ShowThrowHere(_title, sub)
	HUD.Notify(
		sub
			or (
				HUD.InZone and "Hold F or the charge button, then release to throw."
				or "Enter the Launch Hall at the end of the avenue."
			),
		"info"
	)
end
function HUD.SetInZone(value)
	HUD.InZone = value
end
function HUD.ThrowFeedback(_power, isPerfect)
	if isPerfect then
		HUD._PerfectUntil = os.clock() + 0.85
	end
end

local dim = K.new("TextButton", {
	Name = "Backdrop",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = T.Ink,
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 20,
	Parent = root,
})
local layer = K.new(
	"Frame",
	{ Name = "Panels", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = root }
)
local openPanel, previousFocus
local width, height = 1280, 720
function HUD.MakePanel(name, title, subtitle, icon)
	local frame = K.surface(layer, name, UDim2.fromOffset(1000, 620), UDim2.fromScale(0.5, 0.5), T.Panel)
	Sky.Trim(frame)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Visible = false
	K.Icon(icon or "Portal", frame, UDim2.fromOffset(28, 28), T.Gold, UDim2.fromOffset(20, 20))
	local titleLabel = K.text(frame, title, 62, 15, -130, 35, 26, T.Text, true)
	local subtitleLabel = K.text(frame, type(subtitle) == "string" and subtitle or "", 20, 60, -92, 35, 14, T.Muted)
	local close = K.button(
		"",
		T.Raised,
		nil,
		UDim2.fromOffset(44, 44),
		{ Name = "Close", Position = UDim2.new(1, -58, 0, 14), Parent = frame }
	)
	K.Icon("Close", close, UDim2.fromOffset(18, 18), T.Text, UDim2.fromOffset(13, 13))
	local content = K.new("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.fromOffset(16, 108),
		Size = UDim2.new(1, -32, 1, -124),
		BackgroundTransparency = 1,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = T.Violet,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = frame,
	})
	local p =
		{ name = name, frame = frame, content = content, close = close, title = titleLabel, subtitle = subtitleLabel }
	HUD.Panels[name] = p
	K.bind(close, function()
		HUD.Close()
	end)
	return p
end
function HUD.AnyPanelOpen()
	return openPanel ~= nil
end
function HUD.IsOpen(name)
	return openPanel ~= nil and openPanel.name == name
end
function HUD.Open(name)
	local p = HUD.Panels[name]
	if not p then
		return
	end
	if openPanel == p then
		HUD.Close()
		return
	end
	if HUD.TC then
		HUD.TC.CancelCharge("menu opened")
		HUD.TC.StopFollow(true)
	end
	if openPanel then
		openPanel.frame.Visible = false
		if openPanel.onClose then
			openPanel.onClose()
		end
	else
		previousFocus = GuiService.SelectedObject
	end
	openPanel = p
	if HUD.TC then
		HUD.TC.InputBlocked = true
	end
	HUD.TrainHeld = false
	world.Visible = p.contextual == true
	dim.BackgroundTransparency = 1
	dim.Visible = true
	p.frame.Visible = true
	if p.refresh then
		p.refresh()
	end
	-- Static ViewportFrames created while hidden need a camera invalidation on reveal.
	task.defer(function()
		RunService.RenderStepped:Wait()
		if not p.frame.Visible then
			return
		end
		for _, v in p.frame:GetDescendants() do
			if v:IsA("ViewportFrame") and v.CurrentCamera then
				v.CurrentCamera.CFrame = v.CurrentCamera.CFrame * CFrame.new(0.001, 0, 0)
			end
		end
	end)

	local target = p.targetPosition or UDim2.fromScale(0.5, 0.5)
	p.frame.Position = target + UDim2.fromOffset(0, Settings.ReducedMotion and 0 or 8)
	K.tween(p.frame, 0.18, { Position = target })
	if Input.GamepadEnabled then
		GuiService.SelectedObject = p.close
	end
end
function HUD.Close()
	if not openPanel then
		return
	end
	local old = openPanel
	openPanel = nil
	if HUD.TC then
		HUD.TC.InputBlocked = false
	end
	old.frame.Visible = false
	dim.Visible = false
	world.Visible = true
	if old.onClose then
		old.onClose()
	end
	if previousFocus and previousFocus.Parent and Input.GamepadEnabled then
		GuiService.SelectedObject = previousFocus
	else
		GuiService.SelectedObject = nil
	end
end
dim.Activated:Connect(HUD.Close)
Input.InputBegan:Connect(function(i, processed)
	if Input:GetFocusedTextBox() then
		return
	end
	if i.KeyCode == Enum.KeyCode.ButtonB and openPanel then
		HUD.Close()
		return
	end
	if processed then
		return
	end
	local keys = {
		[Enum.KeyCode.P] = "Portals",
		[Enum.KeyCode.U] = "Upgrades",
		[Enum.KeyCode.I] = "Creatures",
		[Enum.KeyCode.M] = "Worlds",
		[Enum.KeyCode.ButtonY] = "Menu",
	}
	if keys[i.KeyCode] then
		HUD.Open(keys[i.KeyCode])
	end
end)
local menuPanel = HUD.MakePanel("Menu", "Your sanctuary", "Everything you need, in four places.", "Compass")
menuPanel.refresh = function()
	menuPanel.content:ClearAllChildren()
	K.new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -8, 0, 126),
		CellPadding = UDim2.fromOffset(8, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menuPanel.content,
	})
	for i, n in ipairs(navOrder) do
		local b = sanctuaryTile(n.name, n.icon, nil, menuPanel.content, i)
		b.Name = "Menu_" .. n.name
		K.bind(b, function()
			HUD.Close()
			n.callback()
		end)
	end
end
menuPanel.layout = function()
	local w = math.min(700, width - 24)
	menuPanel.frame.Size = UDim2.fromOffset(w, math.min(height - 24, w < 540 and 404 or 292))
	local grid = menuPanel.content:FindFirstChildOfClass("UIGridLayout")
	if grid then
		grid.CellSize = UDim2.new(w < 540 and 0.5 or 0.25, -8, 0, 126)
	end
end
K.bind(menuBtn, function()
	HUD.Open("Menu")
end)
K.bind(homeBtn, function()
	local n = HUD.SideButtons.Home
	if n then
		for _, v in navOrder do
			if v.name == "Home" then
				v.callback()
				break
			end
		end
	end
end)
function HUD.Refresh()
	local d = State.Data
	gui:SetAttribute("DataLoaded", State.Loaded)
	gui:SetAttribute("EquippedPortal", d.EquippedPortal)
	gui:SetAttribute("Money", d.Money or 0)
	-- The displayed balance settles in the existing render loop; server data stays exact.
	income.Text = "+" .. Format.Money(d.Income or 0) .. " / sec"
	power.Text = math.floor(d.MaxDistance or 0) .. " m"
	distance.Text = "Throw level " .. (d.Upgrades.ThrowPower or 1)
	strength.Text = Format.Short(d.Strength or 0)
	placed.Text = #d.Placed .. " / " .. d.SlotsOpen
	storage.Text = "Stored " .. (#d.Creatures - #d.Placed) .. " / " .. d.StorageCap
	HUD.SetCarry(d.Carry and #d.Carry or 0)
end
local function rescale()
	local v = root.Parent.AbsoluteSize
	local scale = (Input.TouchEnabled or v.X < 700) and 1 or math.clamp(math.min(v.X / 1440, v.Y / 820), 0.8, 1.1)
	scaler.Scale = scale
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	width, height = v.X / scale, v.Y / scale
	local compact = Input.TouchEnabled or width < 700 or height < 580
	HUD.Compact = compact

	top.Size = UDim2.fromOffset(math.min(250, width - 144), 50)
	top.Position = UDim2.fromOffset(12, 8)
	for i, f in ipairs(stats) do
		f.Visible = i == 1
		f.Size = UDim2.fromOffset(top.Size.X.Offset, 50)
		f.Position = UDim2.fromOffset(0, 0)
	end
	-- The four destinations are inside Menu on every device.
	side.Visible = false
	menuBtn.Visible = true
	homeBtn.Visible = false
	menuBtn.AnchorPoint = Vector2.zero
	menuBtn.Position = UDim2.fromOffset(top.Size.X.Offset + 20, 8)
	menuBtn.Size = UDim2.fromOffset(104, 50)
	throwBtn.Position = UDim2.new(1, -16, 1, Input.TouchEnabled and -138 or -16)
	launch.Size = UDim2.fromOffset(Input.TouchEnabled and math.min(300, width - 24) or 354, 102)
	launch.Position = Input.TouchEnabled and UDim2.new(0.5, -launch.Size.X.Offset / 2, 1, -110)
		or UDim2.new(1, -370, 1, -182)
	notices.Size = UDim2.fromOffset(math.min(420, width - 24), 240)
	notices.Position = UDim2.new(0.5, 0, 0, compact and 126 or 78)
	for _, p in pairs(HUD.Panels) do
		p.frame.Size = UDim2.fromOffset(math.min(1060, width - 24), math.min(680, height - 24))
		p.compact = p.frame.Size.X.Offset < 760
		p.title.TextSize = p.compact and 22 or 26
		p.frame:SetAttribute("Compact", p.compact)
		if p.layout then
			p.layout()
		end
	end
end
HUD.Rescale = rescale
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
State.Changed:Connect(function(full)
	HUD.Refresh()
	if openPanel and openPanel.refresh then
		openPanel.refresh(full)
	end
end)
RunService.RenderStepped:Connect(function(dt)
	local targetMoney = State.Data.Money or 0
	shownMoney = math.abs(targetMoney - shownMoney) < 1 and targetMoney
		or shownMoney + (targetMoney - shownMoney) * (1 - math.exp(-18 * dt))
	money.Text = Format.Money(shownMoney)
	local tc = HUD.TC
	local p = tc and tc.Power or 0
	launch.Visible = tc ~= nil and (tc.Charging or tc.Submitting or (tc.MyThrow ~= nil and tc.Phase == "Flying"))
	throwBtn.Visible = HUD.InZone and not (tc and (tc.MyThrow or tc.Submitting))
	if tc and tc.Charging then
		local d = math.clamp((State.Data.MaxDistance or 40) * p * (p >= 0.92 and 1.15 or 1), 8, Config.LaneLength - 15)
		launchTitle.Text = string.format("%d%% charge  |  %d m", p * 100, d)
		launchHint.Text = p >= 0.92 and "Perfect zone: release now for +15% distance"
			or "Release to launch. Gold marks the perfect zone."
		fill.Size = UDim2.fromScale(p, 1)
		fill.BackgroundColor3 = p >= 0.92 and T.Gold or T.Violet
		throwBtn.Label.Text = "Release to throw"
	elseif tc and tc.Submitting then
		launchTitle.Text = "Launching portal..."
		launchHint.Text = "Waiting for the server to confirm your throw."
		fill.Size = UDim2.fromScale(0, 1)
	elseif tc and tc.MyThrow then
		launchTitle.Text = (HUD._PerfectUntil or 0) > os.clock() and "Perfect throw · +15% distance"
			or "Portal in flight"
		launchHint.Text = tc.TargetZone and ("Heading to " .. Config.Worlds[tc.TargetZone].name)
			or "Your creature will be caught automatically."
		fill.Size = UDim2.fromScale(0, 1)
		throwBtn.Label.Text = "Portal active"
	else
		launchTitle.Text = "Ready to launch"
		launchHint.Text = Input.GamepadEnabled and "Hold R2, then release."
			or Input.TouchEnabled and "Hold Charge portal, then release."
			or "Hold F or click, then release."
		fill.Size = UDim2.fromScale(0, 1)
		throwBtn.Label.Text = "Hold to throw"
	end
	throwBtn.Label.TextTransparency = HUD.InZone and 0 or 0.25
end)
task.defer(rescale)
return HUD
