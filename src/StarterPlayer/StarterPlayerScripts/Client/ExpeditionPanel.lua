-- Skyforge visual planning; all mission authority remains on the server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(RS.Shared.Config)
local Creatures = require(RS.Shared.CreatureData)
local Rules = require(RS.Shared.ExpeditionConfig)
local Planner = require(RS.Shared.ExpeditionPlanner)
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
local manualSelection, routeInitialized = false, false
local activeHint
local lastView, serverClock, localClock = nil, 0, 0
local page, notice, planning, activeBox, portraits, petLabel, reward, bonus, send, claim
local routeTitle, sceneFrame, stats, relicLink
local activeTitle, activeTime, activeReward, activePortrait, progressFill
local tracker, trackerText, trackerFill
local anchor, prompt, sceneId, petKey, activeKey
local selectedHero, petMeta, relicHint, routeCaption, rewardCaption, scoutCaption
local selectedHeroKey, sceneModel, activeSceneModel, activeSceneFrame
local journeyCaption, journeyLabels, activeMapCaption
local routeButtons = {}
local petForButton = {}
local refreshPortraits
local descriptions = {
	Forest = "Overgrown ruins and hidden woodland caches.",
	Volcano = "Lava channels guard the basalt shrine.",
	Frozen = "Icebound paths lead to the frozen relic.",
	Crystal = "Explore the luminous crystal hollows.",
	Candy = "Scout the ancient sugar-stone ruins.",
	Space = "Follow a beacon through the moonlands.",
	Shadow = "Find the lost shrine beyond the deadwood.",
	Heaven = "Ascend to the gilded sanctuary.",
}

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
	local hasText = text ~= nil and text ~= ""
	notice.Text = hasText and text or "Pet expedition"
	notice.TextColor3 = hasText and (color or T.Muted) or T.Text
	notice.TextSize = hasText and 14 or 20
	notice.Visible = true
end
local function portrait(parent, pet, size)
	local m = Renderer.BuildPreview(pet.c, pet.v)
	local vp = K.viewport(m, size, false)
	vp.Name = "PetPortrait"
	vp.Parent = parent
	vp.ImageTransparency = 1
	local loading = K.label("Loading scout...", size, T.Muted, {
		Name = "PortraitLoading",
		TextSize = 12,
		Parent = parent,
	})
	vp.Destroying:Connect(function()
		if loading.Parent then
			loading:Destroy()
		end
	end)
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({ m })
		end)
		if vp.Parent then
			vp.ImageTransparency = 0
			if loading.Parent then
				loading:Destroy()
			end
		end
	end)
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
	local ok, err = State.Request("Teleport", "Expedition")
	busy = false
	if not ok then
		message(err or "Could not reach your table.", T.Danger)
		return
	end
	message("")
	updateSelection()
	updateClock()
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
			routeInitialized, manualSelection = false, false
			HUD.Notify(err or "Expedition finds claimed.", "success")
		end
	end
	render()
end
refreshPortraits = function()
	if not page.frame.Visible or not planning.Visible then
		return
	end
	local left = portraits.AbsolutePosition.X - 90
	local right = portraits.AbsolutePosition.X + portraits.AbsoluteSize.X + 90
	for b, pet in petForButton do
		local show = b.AbsolutePosition.X + b.AbsoluteSize.X >= left and b.AbsolutePosition.X <= right
		local vp = b:FindFirstChild("PetPortrait")
		if show and not vp then
			portrait(b, pet, UDim2.fromScale(1, 1))
		elseif not show and vp then
			vp:Destroy()
		end
	end
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
		petForButton = {}
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
				petForButton[b] = p
				K.bind(b, function()
					selectedUid, manualSelection = p.u, true
					updateSelection()
				end)
			end
		end
	end
	task.defer(refreshPortraits)
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
	local r = route()
	if not manualSelection or not ownedPet() then
		selectedUid = Planner.Suggest(State.Data, r)
	end
	local p = ownedPet()
	local d = p and Creatures.ById[p.c]
	scoutCaption.Text = manualSelection and "Your chosen scout" or "Suggested scout"
	petLabel.Text = d and Variants.Prefix(p.s, p.v) .. d.name or "Choose a pet"
	bonus.Text = "Choose a scout for this route."
	reward.Text = ""
	reward.TextSize = page.premium and 28 or 20
	if p and d and r then
		local quote = Planner.Quote(p, r)
		local _, _, commitment = Planner.Commitment(State.Data, p.u)
		reward.Text = Format.Money(quote.coins) .. " coins"
		bonus.Text = quote.matched and ("+" .. quote.bonusPercent .. "% biome bonus / " .. commitment) or commitment
		bonus.TextColor3 = quote.matched and T.Success or T.Muted
		relicHint.Text = (view() and view().relics and view().relics[r.world]) and "Biome relic recovered"
			or "First return recovers this biome's relic"
	end
	if r then
		routeTitle.Text = worldName(r.world)
		routeCaption.Text = r.unlocked and (descriptions[r.world] or "Explore the biome and recover its relic.")
			or ("Unlock " .. worldName(r.world) .. " in the biome shop to explore here.")

		stats.Text = duration(r.duration) .. "  /  " .. (r.unlocked and "Unlocked" or "Locked biome")
		if page.frame.Size.Y.Offset < 260 then
			local _, status = Planner.Commitment(State.Data, p and p.u)
			stats.Text = duration(r.duration) .. " / " .. (r.unlocked and status or "Locked biome")
			local quote = p and Planner.Quote(p, r)
			if quote and quote.matched then
				reward.Text ..= " (+" .. quote.bonusPercent .. "%)"
			end
		end
		if sceneId ~= r.world then
			sceneId = r.world
			clear(sceneFrame)
			sceneModel = Scene.Build(r.world)
			local vp = K.viewport(sceneModel, UDim2.fromScale(1, 1), false)
			vp.Name = "BiomePreview"
			vp.Parent = sceneFrame
			vp.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-25, 21, -29), Vector3.new(0, 1, 0))
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
	K.setButton(
		send,
		busy and "Working..."
			or (r and not r.unlocked and "Unlock biome" or (not inRange() and "Go to table" or "Send pet")),
		T.Gold
	)
	K.setEnabled(send, State.Loaded and r ~= nil and (not r.unlocked or p ~= nil) and not activeTrip() and not busy)
	if #(State.Data.Creatures or {}) == 0 then
		petLabel.Text = "No pets yet"
		reward.Text = "Catch a pet to begin."
		reward.TextSize = 16
	end
	if d then
		petMeta.Text = d.rarity .. " / " .. worldName(d.world)
		petMeta.TextColor3 = T.Rarity(d.rarity, Config)
		local key = tostring(p.u) .. ":" .. tostring(p.v) .. ":" .. tostring(p.s)
		if selectedHeroKey ~= key then
			selectedHeroKey = key
			clear(selectedHero)
			portrait(selectedHero, p, UDim2.fromScale(1, 1))
		end
	else
		petMeta.Text = "Catch a pet in the Launch Hall"
		if selectedHeroKey ~= "empty" then
			selectedHeroKey = "empty"
			clear(selectedHero)
			K.Icon("Pet", selectedHero, UDim2.fromScale(1, 1), T.Text)
		end
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
	Scene.SetProgress(activeSceneModel, pct)
	local stage = left <= 0 and 3 or (pct < 0.15 and 1 or (pct < 0.75 and 2 or 3))
	journeyCaption.Text = left <= 0 and "Expedition complete" or ({ "Departing", "Exploring", "Returning" })[stage]
	for i, label in journeyLabels do
		label.TextColor3 = i <= stage and T.Success or T.Muted
		label.Font = i == stage and T.Bold or T.Font
	end

	activeHint.Text = a.wasPlaced and "Claim the return to resume this pet's garden income."
		or "Your garden keeps earning. Claim the return to use this scout again."
	activeTime.Text = left > 0 and duration(left) .. " remaining" or "Your pet has returned"
	activeTime.TextColor3 = left > 0 and T.Text or T.Success
	progressFill.Size = UDim2.fromScale(pct, 1)
	trackerFill.Size = UDim2.fromScale(pct, 1)
	trackerText.Text = left > 0 and (worldName(a.world) .. " / " .. duration(left))
		or ("Claim " .. Format.Money(a.coins))
	K.setButton(
		claim,
		busy and "Claiming..."
			or (
				left > 0 and journeyCaption.Text .. "..."
				or (inRange() and "Claim " .. Format.Money(a.coins) or "Go to table")
			),
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
		activeReward.Text = Format.Money(a.coins) .. " coins" .. (a.matched and " / biome bonus included" or "")
		if activeKey ~= a.id then
			activeKey = a.id
			clear(activePortrait)
			portrait(activePortrait, { c = a.creature, v = a.v }, UDim2.fromScale(1, 1))
			clear(activeSceneFrame)
			activeSceneModel = Scene.Build(a.world)
			local vp = K.viewport(activeSceneModel, UDim2.fromScale(1, 1), false)
			vp.Name = "ActiveBiomePreview"
			vp.Parent = activeSceneFrame
			vp.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-25, 21, -29), Vector3.new(0, 1, 0))
		end
	else
		if v and (not routeInitialized or not route()) then
			routeIndex = Planner.DefaultRoute(v.routes, v.relics)
			routeInitialized = true
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
	notice = page.title
	page.inlineMessage = message
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
		table.insert(routeButtons, b)
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
	portraits:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		refreshPortraits()
	end)
	portraits:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(refreshPortraits)
	end)

	petLabel = K.text(right, "", 0, 187, -4, 24, 15, T.Text, true)
	bonus = K.text(right, "", 0, 213, -160, 22, 13, T.Muted)
	bonus.Name = "ScoutCost"
	reward.Name = "QuotedReward"
	send = K.button(
		"Send pet",
		T.Gold,
		nil,
		UDim2.fromOffset(154, 44),
		{ Name = "StartExpedition", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Parent = right }
	)
	K.bind(send, function()
		local r = route()
		if r and not r.unlocked then
			HUD.Open("Worlds")
		elseif selectedUid and r then
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
	local track = K.surface(activeBox, "ReturnProgress", UDim2.new(0.68, -8, 0, 8), UDim2.new(0.32, 0, 0, 88), T.Inset)
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
	activeHint = K.text(activeBox, "", 0, 148, -8, 38, 14, T.Muted)
	local hint = activeHint
	hint.Name = "ScoutCommitment"
	hint.Position = UDim2.new(0.32, 0, 0, 148)
	hint.Size = UDim2.new(0.68, -8, 0, 38)
	local journal =
		HUD.MakePanel("Relics", "Biome relics", "First completion in each biome adds a relic to your table.", "Compass")
	local back = K.button("<  Expedition", T.Raised, nil, UDim2.fromOffset(152, 36), {
		Name = "BackToExpedition",
		Position = UDim2.new(1, -220, 0, 18),
		Parent = journal.frame,
	})
	K.bind(back, Panel.Open)
	journal.refresh = function()
		local bits = {}
		for _, id in Rules.Order do
			table.insert(bits, tostring(view() and view().relics and view().relics[id]))
		end
		local key = table.concat(bits, ":")
		if journal.renderKey == key and journal.content:FindFirstChild("RelicCollection") then
			return
		end
		journal.renderKey = key
		journal.content:ClearAllChildren()
		local grid = K.new("Frame", {
			Name = "RelicCollection",
			Size = UDim2.new(1, -8, 0, 400),
			BackgroundTransparency = 1,
			Parent = journal.content,
		})
		local layout = K.new("UIGridLayout", {
			CellSize = UDim2.new(0.25, -9, 0, 182),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = grid,
		})
		local count = 0
		for i, id in Rules.Order do
			local found = view() and view().relics and view().relics[id]
			if found then
				count += 1
			end
			local tint = Config.Worlds[id].groundColor:Lerp(T.Panel, 0.92)
			local card = K.surface(grid, "Relic_" .. id, UDim2.new(), nil, tint)
			card.LayoutOrder = i
			Sky.Relic(id, card, UDim2.fromOffset(112, 112), UDim2.new(0.5, -56, 0, 2), found)
			local name = K.text(card, worldName(id), 10, 112, -20, 32, 15, T.Text, true)
			name.Name = "RelicName"
			name.TextXAlignment = Enum.TextXAlignment.Center
			local status =
				K.text(card, found and "Recovered" or "Not found", 10, 150, -20, 22, 13, found and T.Success or T.Muted)
			status.Name = "RelicStatus"
			status.TextXAlignment = Enum.TextXAlignment.Center
		end
		journal.subtitle.Text = "Recovered " .. count .. " / 8  /  First return in each biome earns its relic."
		local function resize()
			local narrow = journal.frame.Size.X.Offset < 760
			journal.content.Position = UDim2.fromOffset(16, narrow and 82 or 108)
			journal.contentSize = UDim2.new(1, -32, 1, narrow and -96 or -124)
			journal.content.Size = journal.contentSize - UDim2.fromOffset(0, journal.feedback.Visible and 40 or 0)
			journal.subtitle.Position = UDim2.fromOffset(20, narrow and 52 or 60)
			journal.subtitle.Size = UDim2.new(1, -40, 0, narrow and 24 or 35)
			journal.subtitle.TextSize = narrow and 13 or 14
			layout.CellSize = UDim2.new(narrow and 0.5 or 0.25, narrow and -6 or -9, 0, narrow and 146 or 182)
			grid.Size = UDim2.new(1, -8, 0, narrow and 620 or 388)
			for _, card in grid:GetChildren() do
				if card:IsA("Frame") then
					local id = string.sub(card.Name, 7)
					local art = card:FindFirstChild("RelicArt_" .. id)
					art.Size = UDim2.fromOffset(narrow and 92 or 112, narrow and 92 or 112)
					art.Position = UDim2.new(0.5, narrow and -46 or -56, 0, 2)
					card.RelicName.Position = UDim2.fromOffset(10, narrow and 96 or 112)
					card.RelicName.Size = UDim2.new(1, -20, 0, narrow and 22 or 32)
					card.RelicName.TextSize = narrow and 14 or 15
					card.RelicStatus.Position = UDim2.fromOffset(10, narrow and 120 or 150)
					card.RelicStatus.Size = UDim2.new(1, -20, 0, 22)
				end
			end
		end
		journal.layout = resize
		resize()
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
	local tiny = K.surface(tracker, "Progress", UDim2.new(1, -70, 0, 5), UDim2.fromOffset(58, 43), T.Inset)
	tiny.ClipsDescendants = true
	trackerFill = K.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Gold, Parent = tiny })
	K.bind(tracker, Panel.Open)
	selectedHero = K.new("Frame", { Name = "SelectedScout", BackgroundTransparency = 1, Parent = right })
	petMeta = K.text(right, "", 0, 0, -4, 22, 13, T.Muted)
	relicHint = K.text(right, "", 0, 0, -4, 20, 13, T.Muted)
	routeCaption = K.text(planning, "", 0, 0, -4, 38, 14, T.Muted)
	rewardCaption = K.text(right, "Recovered coins", 0, 0, -4, 20, 13, T.Muted)
	scoutCaption = K.text(right, "Choose your scout", 0, 0, -4, 22, 15, T.Text, true)
	activeSceneFrame = K.new("Frame", { Name = "JourneyMap", BackgroundTransparency = 1, Parent = activeBox })
	activeMapCaption = K.text(activeBox, "Your scout follows the marked route.", 0, 0, -4, 30, 14, T.Muted)
	journeyCaption = K.text(activeBox, "Departing", 0, 0, -4, 24, 16, T.Success, true)
	journeyLabels = {}
	for _, text in { "01  Departure", "02  Exploration", "03  Return" } do
		local l = K.text(activeBox, text, 0, 0, -4, 38, 13, T.Muted)
		table.insert(journeyLabels, l)
	end
	page.refresh = render
	page.layout = function()
		local scale = HUD.Root:FindFirstChildOfClass("UIScale")
		local root = HUD.Root.AbsoluteSize / (scale and scale.Scale or 1)
		local premium = root.X >= 850 and root.Y >= 544
		page.premium = premium
		local h = math.min(premium and 462 or 334, root.Y - 82)
		page.frame.Size = UDim2.fromOffset(math.min(1000, root.X - 24), h)
		page.frame.AnchorPoint = Vector2.new(0.5, 1)
		page.targetPosition = UDim2.new(0.5, 0, 1, -12)
		page.frame.Position = page.targetPosition
		right.Position = UDim2.fromScale(0.32, 0)
		right.Size = UDim2.fromScale(0.68, 1)
		routeTitle.Parent = right
		routeTitle.Position = UDim2.fromOffset(44, 0)
		routeTitle.Size = UDim2.new(1, -88, 0, 30)
		routeTitle.TextSize = 20
		routeTitle.TextXAlignment = Enum.TextXAlignment.Center
		for i, b in routeButtons do
			b.Parent = right
			b.Position = UDim2.new(i == 1 and 0 or 1, i == 1 and 0 or -40, 0, 0)
		end
		sceneFrame.Position = UDim2.new()
		sceneFrame.Size = UDim2.new(0.3, -12, 1, -34)
		sceneFrame.BackgroundTransparency = 1
		relicLink.Position = UDim2.new(0, 0, 1, -30)
		relicLink.Size = UDim2.new(0.3, -12, 0, 30)
		send.Size = UDim2.fromOffset(154, 44)
		selectedHero.Visible = premium
		petMeta.Visible = premium
		relicHint.Visible = premium
		routeCaption.Visible = premium
		rewardCaption.Visible = premium
		scoutCaption.Visible = premium
		activeSceneFrame.Visible = premium
		activeMapCaption.Visible = premium
		journeyCaption.Visible = premium
		for _, label in journeyLabels do
			label.Visible = premium
		end
		activePortrait.Position = UDim2.new()
		activePortrait.Size = UDim2.new(0.28, 0, 1, -20)
		activeTitle.Position = UDim2.fromScale(0.32, 0)
		activeTitle.Size = UDim2.new(0.68, -8, 0, 30)
		claim.Position = UDim2.new(0.32, 0, 1, -48)
		claim.Size = UDim2.new(0.68, -8, 0, 44)
		hint.Position = UDim2.new(0.32, 0, 0, 148)
		hint.Size = UDim2.new(0.68, -8, 0, 38)
		track.Size = UDim2.new(0.68, -8, 0, 8)
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
		if premium then
			right.Position = UDim2.fromScale(0.48, 0)
			right.Size = UDim2.fromScale(0.52, 1)
			routeTitle.Parent = planning
			routeTitle.Position = UDim2.fromOffset(44, 2)
			routeTitle.Size = UDim2.new(0.44, -88, 0, 34)
			routeTitle.TextSize = 24
			for i, b in routeButtons do
				b.Parent = planning
				b.Position = UDim2.new(i == 1 and 0 or 0.44, i == 1 and 0 or -40, 0, 0)
			end
			sceneFrame.Position = UDim2.fromOffset(0, 48)
			sceneFrame.Size = UDim2.new(0.44, -12, 1, -136)
			sceneFrame.BackgroundTransparency = 0
			sceneFrame.BackgroundColor3 = Color3.fromRGB(234, 242, 237)
			if not sceneFrame:FindFirstChildOfClass("UICorner") then
				K.corner(10).Parent = sceneFrame
			end
			routeCaption.Position = UDim2.new(0, 0, 1, -82)
			routeCaption.Size = UDim2.new(0.44, -12, 0, 34)
			relicLink.Position = UDim2.new(0, 0, 1, -40)
			relicLink.Size = UDim2.new(0.44, -12, 0, 40)
			scoutCaption.Position = UDim2.fromOffset(0, 0)
			selectedHero.Position = UDim2.fromOffset(0, 28)
			selectedHero.Size = UDim2.fromOffset(136, 140)
			petMeta.Position = UDim2.fromOffset(152, 28)
			petMeta.Size = UDim2.new(1, -156, 0, 24)
			petLabel.Position = UDim2.fromOffset(152, 58)
			petLabel.Size = UDim2.new(1, -156, 0, 52)
			petLabel.TextSize = 22
			bonus.Position = UDim2.fromOffset(152, 116)
			bonus.Size = UDim2.new(1, -156, 0, 42)
			bonus.Visible = true
			portraits.Position = UDim2.fromOffset(0, 180)
			portraits.Size = UDim2.new(1, 0, 0, 84)
			for _, b in portraits:GetChildren() do
				if b:IsA("GuiObject") then
					b.Size = UDim2.fromOffset(78, 78)
				end
			end
			rewardCaption.Position = UDim2.fromOffset(0, 270)
			reward.Position = UDim2.fromOffset(0, 292)
			reward.Size = UDim2.new(0.6, 0, 0, 36)
			reward.TextSize = 28
			stats.Position = UDim2.new(0.6, 0, 0, 292)
			stats.Size = UDim2.new(0.4, 0, 0, 36)
			stats.TextSize = 15
			relicHint.Position = UDim2.fromOffset(0, 330)
			send.Size = UDim2.new(1, 0, 0, 48)
			activeSceneFrame.Position = UDim2.fromOffset(0, 8)
			activeSceneFrame.Size = UDim2.new(0.46, -12, 1, -54)
			activeSceneFrame.BackgroundTransparency = 0
			activeSceneFrame.BackgroundColor3 = Color3.fromRGB(234, 242, 237)
			if not activeSceneFrame:FindFirstChildOfClass("UICorner") then
				K.corner(10).Parent = activeSceneFrame
			end
			activeMapCaption.Position = UDim2.new(0, 0, 1, -38)
			activeMapCaption.Size = UDim2.new(0.46, -12, 0, 30)
			activeTitle.Position = UDim2.fromScale(0.5, 0)
			activeTitle.Size = UDim2.new(0.5, -8, 0, 34)
			activePortrait.Position = UDim2.new(0.5, 0, 0, 48)
			activePortrait.Size = UDim2.fromOffset(132, 132)
			journeyCaption.Position = UDim2.new(0.5, 144, 0, 48)
			journeyCaption.Size = UDim2.new(0.5, -152, 0, 24)
			activeTime.Position = UDim2.new(0.5, 144, 0, 80)
			activeTime.Size = UDim2.new(0.5, -152, 0, 30)
			activeReward.Position = UDim2.new(0.5, 144, 0, 118)
			activeReward.Size = UDim2.new(0.5, -152, 0, 54)
			track.Position = UDim2.new(0.5, 0, 0, 198)
			track.Size = UDim2.new(0.5, -8, 0, 10)
			for i, l in journeyLabels do
				l.Position = UDim2.new(0.5 + (i - 1) / 6, 0, 0, 222)
				l.Size = UDim2.new(1 / 6, -6, 0, 42)
			end
			hint.Position = UDim2.new(0.5, 0, 0, 300)
			hint.Size = UDim2.new(0.5, -8, 0, 38)
			claim.Position = UDim2.new(0.5, 0, 1, -48)
			claim.Size = UDim2.new(0.5, -8, 0, 48)
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
