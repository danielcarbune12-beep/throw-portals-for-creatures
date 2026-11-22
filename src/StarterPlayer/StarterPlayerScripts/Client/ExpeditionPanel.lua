-- Skyforge visual planning; all mission authority remains on the server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(RS.Shared.Config)
local Creatures = require(RS.Shared.CreatureData)
local Rules = require(RS.Shared.ExpeditionConfig)
local Format = require(RS.Shared.Format)
local Variants = require(RS.Shared.Variants)
local K = require(script.Parent.UIKit)
local T = K.Theme
local Sky = require(script.Parent.SkyforgeUI)
local Scene = require(script.Parent.ExpeditionScene)
local Renderer = require(script.Parent.CreatureRenderer)
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.ClientState)
local Sounds = require(script.Parent.Sounds)
local Panel = {}
local player = Players.LocalPlayer
local ready, busy = false, false
local selectedUid, routeIndex = nil, 1
local lastView, serverClock, localClock = nil, 0, 0
local page, notice, planning, activeBox, portraits, petLabel, reward, bonus, send, claim
local routeTitle, sceneFrame, stats, relicLink
local activeTitle, activeTime, activeReward, activePortrait, progressFill
local tracker, trackerText, trackerFill
local anchor, prompt, sceneId, petKey, activeKey
local render, updateClock, updateSelection, renderPets
local function view()
	return type(State.Data.Expeditions) == "table" and State.Data.Expeditions or nil
end
local function activeTrip()
	local v = view()
	return v and type(v.active) == "table" and v.active or nil
end
local function route()
	local v = view()
	return v and v.routes and v.routes[routeIndex]
end
local function worldName(id)
	return Config.Worlds[id] and Config.Worlds[id].name or tostring(id)
end
local function duration(n)
	n = math.max(0, math.ceil(n))
	return string.format("%dm %02ds", math.floor(n / 60), n % 60)
end
local function clockNow()
	return serverClock + math.max(0, os.clock() - localClock)
end
local function ownedPet()
	for _, p in State.Data.Creatures or {} do
		if p.u == selectedUid then
			return p
		end
	end
end
local function inRange()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return anchor and root and (root.Position - anchor.Position).Magnitude <= Rules.TableRange
end
local function message(text, color)
	notice.Text = text or ""
	notice.TextColor3 = color or T.Muted
	notice.Visible = notice.Text ~= ""
end
local function portrait(parent, pet, size)
	local m = Renderer.BuildPreview(pet.c, pet.v)
	local vp = K.viewport(m, size, false)
	vp.Name = "PetPortrait"
	vp.Parent = parent
	return vp
end
local function clear(parent)
	for _, c in parent:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end
local function goToTable()
	if busy then
		return
	end
	busy = true
	local ok, err = State.Request("Teleport", "Home")
	busy = false
	if not ok then
		message(err or "Could not return home.", T.Danger)
		return
	end
	HUD.Close()
	task.delay(0.5, function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if anchor and hum then
			hum:MoveTo(anchor.Position + Vector3.new(0, 0, -5))
		end
	end)
	HUD.Notify("Approach your map table to send or claim your pet.", "info")
end
local function request(name, arg)
	if busy then
		return
	end
	if not inRange() then
		goToTable()
		return
	end
	busy = true
	updateSelection()
	updateClock()
	local ok, err = State.Request(name, arg)
	busy = false
	message(ok and "" or (err or "Please try again."), T.Danger)
	if ok then
		Sounds.Play("Upgrade")
		State.Request("Sync")
		if name == "StartExpedition" then
			HUD.Close()
			HUD.Notify("Pet dispatched. Your timer is on the HUD.", "success")
		else
			HUD.Notify(err or "Expedition finds claimed.", "success")
		end
	end
	render()
end
renderPets = function()
	local keys = {}
	for _, p in State.Data.Creatures or {} do
		table.insert(keys, tostring(p.u) .. ":" .. p.c .. ":" .. tostring(p.v) .. ":" .. tostring(p.s))
	end
	local nextKey = table.concat(keys, "|")
	if nextKey ~= petKey then
		petKey = nextKey
		clear(portraits)
		local short = page.frame.Size.Y.Offset < 310
		local size = page.frame.Size.Y.Offset < 260 and 44 or (short and 58 or 78)
		for i, p in State.Data.Creatures or {} do
			if Creatures.ById[p.c] then
				local b = K.button(
					"",
					T.Raised,
					nil,
					UDim2.fromOffset(size, size),
					{ Name = "Pet_" .. p.u, LayoutOrder = i, Parent = portraits }
				)
				portrait(b, p, UDim2.fromScale(1, 1))
				K.bind(b, function()
					selectedUid = p.u
					updateSelection()
				end)
			end
		end
	end
	for _, b in portraits:GetChildren() do
		if b:IsA("TextButton") then
			local st = b:FindFirstChildOfClass("UIStroke")
			local chosen = b.Name == "Pet_" .. tostring(selectedUid)
			st.Color = chosen and T.Gold or T.Border
			st.Thickness = chosen and 2 or 1
		end
	end
end
updateSelection = function()
	if not ready then
		return
	end
	local p, r = ownedPet(), route()
	local d = p and Creatures.ById[p.c]
	petLabel.Text = d and Variants.Prefix(p.s, p.v) .. d.name or "Choose a pet"
	bonus.Text = "Income pauses while away."
	reward.Text = ""
	reward.TextSize = 20
	if p and d and r then
		local matched = d.world == r.world
		local coins = math.floor(
			(
				r.coins
				+ Creatures.Income(p.c)
					* Variants.Mult(p.s, p.v)
					* r.duration
					* (r.incomeCoinsPerSecond or Rules.IncomeFraction)
			) * (matched and (r.matchMultiplier or Rules.MatchingBiomeMultiplier) or 1)
		)
		reward.Text = Format.Money(coins) .. " coins"
		bonus.Text = matched and "+25% biome bonus / income pauses" or "Income pauses while away."
	end
	if r then
		routeTitle.Text = worldName(r.world)
		stats.Text = duration(r.duration) .. "  /  " .. (r.unlocked and "Unlocked" or "Locked biome")
		if page.frame.Size.Y.Offset < 260 then
			stats.Text = duration(r.duration) .. " / " .. (r.unlocked and "Income pauses while away." or "Locked biome")
			if d and d.world == r.world then
				reward.Text ..= " (+25%)"
			end
		end
		if sceneId ~= r.world then
			sceneId = r.world
			clear(sceneFrame)
			local vp = K.viewport(Scene.Build(r.world), UDim2.fromScale(1, 1), false)
			vp.Name = "BiomePreview"
			vp.Parent = sceneFrame
			vp.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-13, 12, -18), Vector3.new(0, 1, 0))
		end
	end
	local count = 0
	local v = view()
	for _, yes in v and v.relics or {} do
		if yes then
			count += 1
		end
	end
	relicLink.Label.Text = "Relics " .. count .. " / 8"
	K.setButton(send, busy and "Sending..." or (not inRange() and "Go to table" or "Send pet"), T.Gold)
	K.setEnabled(send, State.Loaded and p ~= nil and r ~= nil and r.unlocked == true and not activeTrip() and not busy)
	if #(State.Data.Creatures or {}) == 0 then
		petLabel.Text = "No pets yet"
		reward.Text = "Catch a pet to begin."
		reward.TextSize = 16
	end
	renderPets()
end
updateClock = function()
	if not ready then
		return
	end
	local a = activeTrip()
	tracker.Visible = a ~= nil
	if not a then
		if prompt then
			prompt.ActionText = "Plan expedition"
		end
		return
	end
	local left = math.max(0, a.endsAt - clockNow())
	local pct = math.clamp(1 - left / math.max(1, a.endsAt - a.startedAt), 0, 1)
	activeTime.Text = left > 0 and duration(left) .. " remaining" or "Your pet has returned"
	activeTime.TextColor3 = left > 0 and T.Text or T.Success
	progressFill.Size = UDim2.fromScale(pct, 1)
	trackerFill.Size = UDim2.fromScale(pct, 1)
	trackerText.Text = left > 0 and (worldName(a.world) .. " / " .. duration(left))
		or ("Claim " .. Format.Money(a.coins))
	K.setButton(
		claim,
		busy and "Claiming..." or (inRange() and "Claim " .. Format.Money(a.coins) or "Go to table"),
		T.Gold
	)
	K.setEnabled(claim, left <= 0 and not busy)
	if prompt then
		prompt.ActionText = left > 0 and "View expedition" or "Claim return"
	end
end
render = function()
	local v = view()
	if v ~= lastView then
		lastView = v
		serverClock = v and v.serverNow or os.time()
		localClock = os.clock()
	end
	local a = activeTrip()
	planning.Visible = a == nil and State.Loaded and v ~= nil
	activeBox.Visible = a ~= nil
	if not State.Loaded or not v then
		message("Loading expedition...", T.Muted)
	elseif notice.Text == "Loading expedition..." then
		message("")
	end
	if a then
		activeTitle.Text = worldName(a.world)
		activeReward.Text = Format.Money(a.coins) .. " coins" .. (a.matched and " / +25% bonus included" or "")
		if activeKey ~= a.id then
			activeKey = a.id
			clear(activePortrait)
			portrait(activePortrait, { c = a.creature, v = a.v }, UDim2.fromScale(1, 1))
		end
	else
		if not ownedPet() then
			selectedUid = State.Data.Creatures[1] and State.Data.Creatures[1].u
		end
		if not route() then
			routeIndex = 1
		end
	end
	updateSelection()
	updateClock()
end
function Panel.Open()
	if not ready or HUD.IsOpen("Expeditions") then
		return
	end
	HUD.Open("Expeditions")
	task.spawn(function()
		local ok, err = State.Request("Sync")
		if not ok then
			message(err or "Could not load expedition.", T.Danger)
		end
	end)
end
local function attachPrompt()
	local bases = workspace:FindFirstChild("Bases")
	local index = player:GetAttribute("BaseIndex") or State.Data.BaseIndex
	local base = bases and bases:FindFirstChild("Base" .. tostring(index))
	local nextAnchor = base and base:FindFirstChild("ExpeditionAnchor", true)
	if anchor == nextAnchor then
		return
	end
	if prompt then
		prompt:Destroy()
	end
	anchor, prompt = nextAnchor, nil
	if not anchor then
		return
	end
	prompt = K.new("ProximityPrompt", {
		Name = "OwnExpeditionPrompt",
		ActionText = "Plan expedition",
		ObjectText = "Expedition table",
		KeyboardKeyCode = Enum.KeyCode.E,
		GamepadKeyCode = Enum.KeyCode.ButtonX,
		MaxActivationDistance = Rules.TableRange,
		HoldDuration = 0,
		RequiresLineOfSight = false,
		Parent = anchor,
	})
	prompt.Triggered:Connect(function(who)
		if who == player then
			Panel.Open()
		end
	end)
end
function Panel.Init()
	if ready then
		return
	end
	page = HUD.MakePanel("Expeditions", "Pet expedition", "", "Compass")
	page.contextual = true
	page.subtitle.Visible = false
	page.title.Position = UDim2.fromOffset(58, 8)
	page.title.Size = UDim2.new(1, -130, 0, 30)
	page.title.TextSize = 20
	page.close.Position = UDim2.new(1, -48, 0, 4)
	page.close.Size = UDim2.fromOffset(40, 40)
	page.content.Position = UDim2.fromOffset(14, 48)
	page.content.Size = UDim2.new(1, -28, 1, -58)
	page.content.AutomaticCanvasSize = Enum.AutomaticSize.None
	page.content.ScrollingEnabled = false
	notice = K.text(page.frame, "", 14, -32, -28, 28, 14, T.Muted)
	notice.Name = "ExpeditionNotice"
	notice.Visible = false
	planning = K.new(
		"Frame",
		{ Name = "ExpeditionPlanning", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = page.content }
	)
	sceneFrame = K.new(
		"Frame",
		{ Name = "BiomeScene", Size = UDim2.new(0.3, -12, 1, -34), BackgroundTransparency = 1, Parent = planning }
	)
	relicLink = K.button(
		"Relics 0 / 8",
		T.Raised,
		nil,
		UDim2.new(0.3, -12, 0, 30),
		{ Name = "OpenRelics", Position = UDim2.new(0, 0, 1, -30), Parent = planning }
	)
	K.bind(relicLink, function()
		HUD.Open("Relics")
	end)
	local right = K.new("Frame", {
		Name = "MissionSelection",
		Position = UDim2.fromScale(0.32, 0),
		Size = UDim2.fromScale(0.68, 1),
		BackgroundTransparency = 1,
		Parent = planning,
	})
	routeTitle = K.text(right, "", 44, 0, -88, 30, 20, T.Text, true)
	routeTitle.TextXAlignment = Enum.TextXAlignment.Center
	for _, def in { { -1, "<", 0 }, { 1, ">", 1 } } do
		local b = K.button(def[2], T.Raised, nil, UDim2.fromOffset(40, 40), {
			Name = def[1] == -1 and "PreviousBiome" or "NextBiome",
			Position = UDim2.new(def[3], def[3] == 0 and 0 or -40, 0, 0),
			Parent = right,
		})
		K.bind(b, function()
			local routes = view() and view().routes or {}
			if #routes == 0 then
				return
			end
			routeIndex = ((routeIndex - 1 + def[1]) % #routes) + 1
			message("")
			updateSelection()
		end)
	end
	stats = K.text(right, "", 0, 38, -4, 22, 14, T.Muted)
	reward = K.text(right, "", 0, 63, -4, 26, 20, T.Gold, true)
	portraits = K.new("ScrollingFrame", {
		Name = "ExpeditionPets",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 86),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.Violet,
		Parent = right,
	})
	K.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left).Parent = portraits
	K.pad(3).Parent = portraits
	petLabel = K.text(right, "", 0, 187, -4, 24, 15, T.Text, true)
	bonus = K.text(right, "", 0, 213, -160, 22, 13, T.Muted)
	send = K.button(
		"Send pet",
		T.Gold,
		nil,
		UDim2.fromOffset(154, 44),
		{ Name = "StartExpedition", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Parent = right }
	)
	K.bind(send, function()
		local r = route()
		if selectedUid and r then
			request("StartExpedition", game.HttpService:JSONEncode({ route = r.id, petUid = selectedUid }))
		end
	end)
	activeBox = K.new(
		"Frame",
		{ Name = "ActiveExpedition", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = page.content }
	)
	activePortrait = K.new(
		"Frame",
		{ Name = "AwayPet", Size = UDim2.new(0.28, 0, 1, -20), BackgroundTransparency = 1, Parent = activeBox }
	)
	activeTitle = K.text(activeBox, "", 0, 0, -8, 30, 22, T.Text, true)
	activeTitle.Position = UDim2.fromScale(0.32, 0)
	activeTitle.Size = UDim2.new(0.68, -8, 0, 30)
	activeTime = K.text(activeBox, "", 0, 44, -8, 28, 18, T.Text, true)
	activeTime.Position = UDim2.new(0.32, 0, 0, 44)
	activeTime.Size = UDim2.new(0.68, -8, 0, 28)
	activeReward = K.text(activeBox, "", 0, 108, -8, 30, 16, T.Gold)
	activeReward.Position = UDim2.new(0.32, 0, 0, 108)
	activeReward.Size = UDim2.new(0.68, -8, 0, 30)
	local track = K.surface(activeBox, "ReturnProgress", UDim2.new(0.68, -8, 0, 8), UDim2.new(0.32, 0, 0, 88), T.Ink)
	track.ClipsDescendants = true
	progressFill =
		K.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Gold, Parent = track })
	claim = K.button(
		"Claim",
		T.Gold,
		nil,
		UDim2.new(0.68, -8, 0, 44),
		{ Name = "ClaimExpedition", Position = UDim2.new(0.32, 0, 1, -48), Parent = activeBox }
	)
	K.bind(claim, function()
		local a = activeTrip()
		if a then
			request("ClaimExpedition", a.id)
		end
	end)
	local hint = K.text(activeBox, "Pet income resumes when you claim its return.", 0, 148, -8, 38, 14, T.Muted)
	hint.Position = UDim2.new(0.32, 0, 0, 148)
	hint.Size = UDim2.new(0.68, -8, 0, 38)
	local journal =
		HUD.MakePanel("Relics", "Biome relics", "First completion in each biome adds a relic to your table.", "Compass")
	journal.refresh = function()
		journal.content:ClearAllChildren()
		K.list(Enum.FillDirection.Vertical, 8).Parent = journal.content
		local back = K.button(
			"<  Expedition",
			T.Raised,
			nil,
			UDim2.new(1, -8, 0, 40),
			{ LayoutOrder = 0, Parent = journal.content }
		)
		K.bind(back, function()
			Panel.Open()
		end)
		for i, id in Rules.Order do
			local found = view() and view().relics and view().relics[id]
			local l = K.label(
				worldName(id) .. " / " .. (found and "Recovered" or "Not found"),
				UDim2.new(1, -8, 0, 36),
				found and T.Success or T.Muted,
				{ LayoutOrder = i, Parent = journal.content }
			)
			l.RichText = false
		end
	end
	tracker = K.button(
		"",
		T.Panel,
		nil,
		UDim2.fromOffset(276, 64),
		{ Name = "ExpeditionTracker", Position = UDim2.fromOffset(12, 70), Visible = false, Parent = HUD.Root.Gameplay }
	)
	Sky.Trim(tracker)
	K.Icon("Compass", tracker, UDim2.fromOffset(48, 48), T.Text, UDim2.fromOffset(4, 2))
	trackerText = K.text(tracker, "", 58, 5, -66, 30, 14, T.Text, true)
	local tiny = K.surface(tracker, "Progress", UDim2.new(1, -70, 0, 5), UDim2.fromOffset(58, 43), T.Ink)
	tiny.ClipsDescendants = true
	trackerFill = K.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Gold, Parent = tiny })
	K.bind(tracker, Panel.Open)
	page.refresh = render
	page.layout = function()
		local root = HUD.Root.AbsoluteSize
		local h = math.min(334, root.Y - 82)
		page.frame.Size = UDim2.fromOffset(math.min(1000, root.X - 24), h)
		page.frame.AnchorPoint = Vector2.new(0.5, 1)
		page.targetPosition = UDim2.new(0.5, 0, 1, -12)
		page.frame.Position = page.targetPosition
		local short = h < 310
		reward.Position = UDim2.fromOffset(0, short and 58 or 63)
		reward.Size = UDim2.new(1, -4, 0, short and 22 or 26)
		portraits.Position = UDim2.fromOffset(0, short and 84 or 96)
		portraits.Size = UDim2.new(1, 0, 0, short and 65 or 86)
		for _, b in portraits:GetChildren() do
			if b:IsA("GuiObject") then
				b.Size = UDim2.fromOffset(short and 58 or 78, short and 58 or 78)
			end
		end
		petLabel.Position = UDim2.fromOffset(0, short and 150 or 187)
		petLabel.Size = UDim2.new(1, short and -160 or -4, 0, 24)
		bonus.Position = UDim2.new(0, 0, 1, -24)
		bonus.Visible = true
		hint.Visible = not short
		portraits.Size = UDim2.new(1, 0, 0, short and 65 or 86)
		petLabel.TextSize = 15
		stats.Position = UDim2.fromOffset(44, 38)
		stats.Size = UDim2.new(1, -88, 0, 22)
		stats.TextSize = 14
		activeTime.Position = UDim2.new(0.32, 0, 0, 44)
		activeReward.Position = UDim2.new(0.32, 0, 0, 108)
		activeReward.Size = UDim2.new(0.68, -8, 0, 30)
		track.Position = UDim2.new(0.32, 0, 0, 88)
		if h < 260 then
			stats.Position = UDim2.fromOffset(44, 30)
			stats.Size = UDim2.new(1, -88, 0, 18)
			stats.TextSize = 13
			reward.Position = UDim2.fromOffset(0, 50)
			reward.Size = UDim2.new(1, -164, 0, 22)
			petLabel.Position = UDim2.fromOffset(0, 70)
			petLabel.Size = UDim2.new(1, -164, 0, 18)
			petLabel.TextSize = 13
			portraits.Position = UDim2.fromOffset(0, 90)
			portraits.Size = UDim2.new(1, -164, 0, 48)
			bonus.Visible = false
			for _, b in portraits:GetChildren() do
				if b:IsA("GuiObject") then
					b.Size = UDim2.fromOffset(44, 44)
				end
			end
			activeTime.Position = UDim2.new(0.32, 0, 0, 30)
			track.Position = UDim2.new(0.32, 0, 0, 60)
			activeReward.Position = UDim2.new(0.32, 0, 0, 72)
			activeReward.Size = UDim2.new(0.68, -8, 0, 18)
		end
	end
	State.Changed:Connect(function(full)
		local v = view()
		if v ~= lastView then
			lastView = v
			serverClock = v and v.serverNow or os.time()
			localClock = os.clock()
		end
		if HUD.IsOpen("Expeditions") or full then
			render()
		else
			updateClock()
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 then
			return
		end
		elapsed = 0
		attachPrompt()
		if prompt then
			prompt.Enabled = State.Loaded and not HUD.AnyPanelOpen()
		end
		updateClock()
		if HUD.IsOpen("Expeditions") then
			updateSelection()
		end
	end)
	ready = true
	attachPrompt()
	HUD.Rescale()
	render()
end
return Panel
