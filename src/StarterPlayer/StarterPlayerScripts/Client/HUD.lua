-- Direct Pets, Shop and Expeditions navigation with a shared responsive panel layer.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Prompts = game:GetService("ProximityPromptService")
local previousPromptState
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Format = require(RS.Shared.Format)
local K = require(script.Parent.UIKit)
local T = K.Theme
local Sky = require(script.Parent.SkyforgeUI)
local Craft = require(script.Parent.SanctuaryUI)
local State = require(script.Parent.ClientState)
local Effects = require(script.Parent.Effects)
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
local capacityWarning = K.button("Pets full · Manage pets or visit the forge", T.Danger, nil, UDim2.fromOffset(336, 44), {
	Name = "PetCapacityWarning", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Visible = false, Parent = world,
})
capacityWarning.Label.TextSize = 14
K.bind(capacityWarning, function()
	HUD.Open("Creatures")
end)
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
local navGrid = K.new("UIGridLayout", {
	CellSize = UDim2.fromOffset(64, 64),
	CellPadding = UDim2.fromOffset(8, 8),
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = side,
})

-- Small cutout icons sit directly on the world without captions or backplates.
local navOrder = {}
local settingsBtn = K.button("Settings", T.Panel, nil, UDim2.fromOffset(44, 44), {
	Name = "SettingsShortcut",
	Parent = world,
})
settingsBtn.Label.Visible = false
settingsBtn:SetAttribute("AccessibleLabel", "Settings")
Sky.Trim(settingsBtn)
K.Icon("Settings", settingsBtn, UDim2.fromOffset(36, 36), T.Text, UDim2.fromOffset(4, 4))
Sky.Trim(moneyIcon)

local function directButton(name, icon, order)
	local b = K.button("", T.Panel, nil, UDim2.fromOffset(64, 64), {
		Name = "Nav_" .. name,
		Parent = side,
		LayoutOrder = order,
		BackgroundTransparency = 1,
	})
	b:FindFirstChildOfClass("UIStroke").Transparency = 1
	local art = K.Icon(icon, b, UDim2.fromOffset(56, 56), T.Text, UDim2.fromOffset(4, 4))
	art.Name = "NavigationArt"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	b.Label.Visible = false
	b:SetAttribute("AccessibleLabel", name)
	local focus = K.new("Frame", {
		Name = "Focus",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = b,
	}, { K.corner(10), K.stroke(2, T.Gold) })
	local ring = focus:FindFirstChildOfClass("UIStroke")
	ring.Transparency = 1
	local function highlight(on)
		ring.Transparency = on and 0 or 1
	end
	b.MouseEnter:Connect(function()
		highlight(true)
	end)
	b.MouseLeave:Connect(function()
		highlight(false)
	end)
	b.SelectionGained:Connect(function()
		highlight(true)
	end)
	b.SelectionLost:Connect(function()
		highlight(false)
	end)
	return b
end

function HUD.AddSideButton(name, icon, _a, _b, callback)
	if HUD.SideButtons[name] then
		return HUD.SideButtons[name]
	end
	if name == "Settings" then
		K.bind(settingsBtn, callback)
		HUD.SideButtons.Settings = settingsBtn
		return settingsBtn
	end
	local b = directButton(name, icon, #navOrder + 1)
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

-- No floating notifications. Errors belong to the active panel only.
local openPanel, previousFocus
function HUD.SetPanelMessage(name, text, color)
	local p = HUD.Panels[name]
	if not p then
		return
	end
	if p.inlineMessage then
		p.inlineMessage(text, color)
		return
	end
	p.feedback.Text = text or ""
	p.feedback.TextColor3 = color or T.Danger
	p.feedback.Visible = p.feedback.Text ~= ""
	p.content.Size = p.contentSize - UDim2.fromOffset(0, p.feedback.Visible and 40 or 0)
	if p.layout then
		p.layout()
	end
end
function HUD.Notify(text, kind)
	if kind == "storage_full" or (kind == "error" and type(text) == "string" and text:lower():find("storage full", 1, true)) then
		HUD.StorageFull = true
		capacityWarning.Visible = not HUD.AnyPanelOpen()
	end
	if openPanel and kind == "error" then
		HUD.SetPanelMessage(openPanel.name, text, T.Danger)
	end
end
function HUD.ShowThrowHere(_title, _sub)
	-- Compatibility for launch-zone callbacks; gameplay uses contextual controls.
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
local width, height = 1280, 720
function HUD.MakePanel(name, title, subtitle, icon)
	local frame = K.surface(layer, name, UDim2.fromOffset(1000, 620), UDim2.fromScale(0.5, 0.5), T.Panel)
	Craft.Shell(frame)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Visible = false
	frame:SetAttribute("MenuKind", icon or "Portal")
	Craft.Crest(frame, UDim2.fromOffset(28, 28), UDim2.fromOffset(20, 19), name == "Shop" and T.TrimGold or nil)
	local titleLabel = K.text(frame, title, 62, 15, -130, 35, 26, name == "Shop" and T.OnAccent or T.Text, true)
	titleLabel.FontFace = T.TitleFace
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
	local feedback = K.text(frame, "", 20, 0, -40, 32, 14, T.Danger)
	feedback.Name = "InlineFeedback"
	feedback.Position = UDim2.new(0, 20, 1, -46)
	feedback.Visible = false
	feedback.RichText = false
	local p = {
		name = name,
		frame = frame,
		content = content,
		close = close,
		title = titleLabel,
		subtitle = subtitleLabel,
		feedback = feedback,
		contentSize = content.Size,
	}
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
		K.Motion.Cancel(openPanel.frame)
		openPanel.frame.Visible = false
		if openPanel.onClose then
			openPanel.onClose()
		end
	else
		previousFocus = GuiService.SelectedObject
		previousPromptState = Prompts.Enabled
	end
	HUD.SetPanelMessage(p.name, "")
	openPanel = p
	Prompts.Enabled = false
	player:SetAttribute("TPFC_MenuOpen", true)
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
	K.Motion.Enter(p.frame, target, UDim2.fromOffset(0, p.contextual and 12 or 8))
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
	if previousPromptState ~= nil then
		Prompts.Enabled = previousPromptState
	end
	previousPromptState = nil
	player:SetAttribute("TPFC_MenuOpen", false)
	if HUD.TC then
		HUD.TC.InputBlocked = false
	end
	HUD.SetPanelMessage(old.name, "")
	K.Motion.Cancel(old.frame)
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
	if i.KeyCode == Enum.KeyCode.ButtonY and not openPanel then
		GuiService.SelectedObject = HUD.SideButtons.Pets
		return
	end
	local keys = {
		[Enum.KeyCode.P] = "Portals",
		[Enum.KeyCode.U] = "Upgrades",
		[Enum.KeyCode.I] = "Creatures",
		[Enum.KeyCode.M] = "Worlds",
	}
	if keys[i.KeyCode] then
		HUD.Open(keys[i.KeyCode])
	end
end)
function HUD.Refresh()
	local d = State.Data
	HUD.StorageFull = State.Loaded and #d.Creatures + #(d.Carry or {}) >= (d.SlotsOpen or 0) + (d.StorageCap or 0)
	gui:SetAttribute("DataLoaded", State.Loaded)
	gui:SetAttribute("EquippedPortal", d.EquippedPortal)
	gui:SetAttribute("Money", d.Money or 0)
	-- The displayed balance settles in the existing render loop; server data stays exact.
	income.Text = "Treasury " .. Format.Money(d.Uncollected or 0) .. "  /  +" .. Format.Rate(d.Income or 0) .. "/s"
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
	capacityWarning.Size = UDim2.fromOffset(math.min(compact and 310 or 336, width - 32), 44)
	capacityWarning.Position = UDim2.new(0.5, 0, 0, compact and 74 or 12)

	local tileW, tileH = compact and 52 or 64, compact and 52 or 64
	local navWidth = compact and (3 * tileW + 16) or tileW
	top.Size = UDim2.fromOffset(math.min(290, compact and (width - navWidth - 36) or (width - 80)), 50)
	top.Position = UDim2.fromOffset(12, 8)
	for i, f in ipairs(stats) do
		f.Visible = i == 1
		f.Size = UDim2.fromOffset(top.Size.X.Offset, 50)
		f.Position = UDim2.fromOffset(0, 0)
	end
	-- Primary actions remain one press away; short screens use a top-right horizontal row.
	side.Visible = true
	navGrid.FillDirection = compact and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	navGrid.CellSize = UDim2.fromOffset(tileW, tileH)
	side.AnchorPoint = compact and Vector2.new(1, 0) or Vector2.zero
	side.Position = compact and UDim2.new(1, -12, 0, 8)
		or UDim2.fromOffset(12, math.max(76, (height - (3 * tileH + 16)) / 2))
	side.Size = UDim2.fromOffset(navWidth, compact and tileH or (3 * tileH + 16))
	for _, entry in ipairs(navOrder) do
		local button = HUD.SideButtons[entry.name]
		local art = button.NavigationArt
		local artSize = compact and 44 or 56
		art.Size = UDim2.fromOffset(artSize, artSize)
	end
	settingsBtn.Position = compact and UDim2.fromOffset(12, 66) or UDim2.fromOffset(top.Size.X.Offset + 20, 8)
	income.TextTruncate = Enum.TextTruncate.AtEnd
	throwBtn.Position = UDim2.new(1, -16, 1, Input.TouchEnabled and -138 or -16)
	launch.Size = UDim2.fromOffset(Input.TouchEnabled and math.min(300, width - 24) or 354, 102)
	launch.Position = Input.TouchEnabled and UDim2.new(0.5, -launch.Size.X.Offset / 2, 1, -110)
		or UDim2.new(1, -370, 1, -182)
	for _, p in pairs(HUD.Panels) do
		K.Motion.Cancel(p.frame)
		p.frame.Size = UDim2.fromOffset(math.min(1060, width - 24), math.min(680, height - 24))
		p.compact = p.frame.Size.X.Offset < 760 or p.frame.Size.Y.Offset < 460
		p.title.TextSize = p.compact and 22 or 26
		p.frame:SetAttribute("Compact", p.compact)
		if p.layout then
			p.layout()
		end
		p.frame.Position = p.targetPosition or UDim2.fromScale(0.5, 0.5)
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
	capacityWarning.Visible = HUD.StorageFull == true and not HUD.AnyPanelOpen()
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
