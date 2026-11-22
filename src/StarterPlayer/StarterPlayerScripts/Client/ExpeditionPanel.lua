-- Contextual expedition planning. The only world control is the prompt on the
-- player's own map table; mission identity, timestamps and rewards stay server-owned.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Creatures = require(Shared.CreatureData)
local Rules = require(Shared.ExpeditionConfig)
local Format = require(Shared.Format)
local variantModule = Shared:FindFirstChild("Variants")
local Variants = variantModule and require(variantModule)
local K = require(script.Parent.UIKit)
local T = K.Theme
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.ClientState)
local Sounds = require(script.Parent.Sounds)
local Panel = {}
local player = Players.LocalPlayer
local initialized, busy = false, false
local selectedUid, selectedRoute
local noticeText, noticeColor = "", T.Muted
local lastView, serverClock, localClock = nil, 0, 0
local anchor, prompt
local page, notice, activeBox, idleBox, petList, routeList, petSummary, preview, action, claim
local activeTitle, activeDetail, countdown, activeReward, activeHint, journalTitle, journalGrid
local petSearch, petEmpty
local introduction, journalHint
local petHeading, missionHeading, planningLayout
local render, renderPets, renderRoutes, updateSelection, updateClock

local function worldName(id)
	return Config.Worlds[id] and Config.Worlds[id].name or tostring(id)
end

local function duration(seconds)
	seconds = math.max(0, math.ceil(seconds or 0))
	return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
end

local function petName(pet)
	local def = pet and Creatures.ById[pet.c]
	if not def then
		return "Unknown creature"
	end
	return (Variants and Variants.Prefix(pet.s, pet.v) or "") .. def.name
end

local function petIncome(pet)
	return Creatures.Income(pet.c) * (Variants and Variants.Mult(pet.s, pet.v) or 1)
end

local function getView()
	return type(State.Data.Expeditions) == "table" and State.Data.Expeditions or nil
end

local function selectedPet()
	for _, pet in State.Data.Creatures or {} do
		if pet.u == selectedUid and Creatures.ById[pet.c] then
			return pet
		end
	end
end

local function routeById(id)
	local view = getView()
	for _, route in view and view.routes or {} do
		if route.id == id then
			return route
		end
	end
end

local function clockNow()
	return serverClock + math.max(0, os.clock() - localClock)
end

local function clearRows(parent)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function label(parent, text, height, size, color, bold, order)
	return K.label(text, UDim2.new(1, -12, 0, height), color or T.Text, {
		TextSize = size or 16,
		Font = bold and T.Bold or T.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = false,
		LayoutOrder = order or 0,
		Parent = parent,
	})
end

local function stack(parent, name, order)
	local f = K.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	K.list(Enum.FillDirection.Vertical, 10).Parent = f
	return f
end

local function scrollList(parent, name, height, order)
	local f = K.new("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, height),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = T.Violet,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	K.list(Enum.FillDirection.Vertical, 8).Parent = f
	K.pad(3).Parent = f
	return f
end

local function markSelected(button, chosen)
	local border = button:FindFirstChildOfClass("UIStroke")
	border.Color, border.Thickness = chosen and T.Gold or T.Border, chosen and 2 or 1
end

local function setNotice(text, color)
	noticeText, noticeColor = text or "", color or T.Muted
	if notice then
		notice.Text, notice.TextColor3 = noticeText, noticeColor
		notice.Visible = noticeText ~= ""
	end
end

local function request(actionName, argument)
	if busy then
		return
	end
	busy = true
	updateSelection()
	updateClock()
	local ok, message = State.Request(actionName, argument)
	busy = false
	setNotice(
		message or (ok and "Expedition updated." or "Could not update the expedition. Try again."),
		ok and T.Success or T.Danger
	)
	if ok then
		Sounds.Play("Upgrade")
		State.Request("Sync")
	end
	render()
end

updateSelection = function()
	local pet, route = selectedPet(), routeById(selectedRoute)
	local view = getView()
	local active = view and type(view.active) == "table" and view.active
	if pet then
		local def = Creatures.ById[pet.c]
		petSummary.Text = petName(pet)
			.. "  #"
			.. tostring(pet.u)
			.. "\n"
			.. def.rarity
			.. " | "
			.. worldName(def.world)
		petSummary.TextColor3 = T.Rarity(def.rarity, Config)
	else
		petSummary.Text, petSummary.TextColor3 = "Choose a creature for the expedition.", T.Muted
	end
	if pet and route then
		local matched = Creatures.ById[pet.c].world == route.world
		local incomePart = route.incomeCoinsPerSecond or Rules.IncomeFraction
		local multiplier = matched and (route.matchMultiplier or Rules.MatchingBiomeMultiplier) or 1
		local coins = math.floor((route.coins + petIncome(pet) * route.duration * incomePart) * multiplier)
		preview.Text = worldName(route.world)
			.. " | "
			.. duration(route.duration)
			.. " | "
			.. Format.Money(coins)
			.. "\n"
			.. (matched and "Native biome match: +25% reward." or "A pet from this biome earns a +25% reward.")
			.. "\n"
			.. (
				view.relics and view.relics[route.world] and "Biome relic already recovered."
				or "First completion recovers this biome's relic."
			)
		preview.TextColor3 = route.unlocked and T.Text or T.Muted
	else
		preview.Text, preview.TextColor3 = "Select a pet and an unlocked biome to see the duration and finds.", T.Muted
	end
	local enabled = State.Loaded and pet ~= nil and route ~= nil and route.unlocked == true and not active and not busy
	K.setButton(action, busy and "Sending pet..." or "Send on expedition", T.Gold)
	K.setEnabled(action, enabled)
end

renderPets = function()
	local oldScroll = petList.CanvasPosition
	clearRows(petList)
	local query = string.lower(petSearch.Text)
	local found = 0
	for i, pet in State.Data.Creatures or {} do
		local def = Creatures.ById[pet.c]
		if
			def
			and (
				query == ""
				or string.find(
					string.lower(petName(pet) .. " " .. def.rarity .. " " .. worldName(def.world)),
					query,
					1,
					true
				)
			)
		then
			found += 1
			local button = K.button(
				petName(pet) .. "  #" .. tostring(pet.u) .. "\n" .. def.rarity .. " | " .. worldName(def.world),
				T.Raised,
				nil,
				UDim2.new(1, -14, 0, 64),
				{
					Name = "Pet_" .. tostring(pet.u),
					LayoutOrder = i,
					Parent = petList,
				}
			)
			button.Label.RichText = false
			markSelected(button, selectedUid == pet.u)
			K.bind(button, function()
				selectedUid = pet.u
				renderPets()
				updateSelection()
			end)
		end
	end
	petEmpty.Visible = found == 0
	petEmpty.Text = #(State.Data.Creatures or {}) == 0
			and "Catch your first creature in the Launch Hall, then return to the map table."
		or "No creatures match this search."
	task.defer(function()
		if petList.Parent then
			petList.CanvasPosition = oldScroll
		end
	end)
end

renderRoutes = function()
	local oldScroll = routeList.CanvasPosition
	clearRows(routeList)
	local view = getView()
	for i, route in view and view.routes or {} do
		local title = worldName(route.world) .. " | " .. duration(route.duration)
		if not route.unlocked then
			title ..= "\nUnlock this biome to explore it."
		end
		local button = K.button(title, T.Raised, nil, UDim2.new(1, -14, 0, 58), {
			Name = "Route_" .. route.id,
			LayoutOrder = i,
			Parent = routeList,
		})
		button.Label.RichText = false
		markSelected(button, selectedRoute == route.id)
		K.setEnabled(button, route.unlocked == true)
		K.bind(button, function()
			selectedRoute = route.id
			renderRoutes()
			updateSelection()
		end)
	end
	task.defer(function()
		if routeList.Parent then
			routeList.CanvasPosition = oldScroll
		end
	end)
end

updateClock = function()
	local view = getView()
	local active = view and type(view.active) == "table" and view.active
	if not active then
		if prompt then
			prompt.ActionText = "Plan expedition"
		end
		return
	end
	local remaining = math.max(0, active.endsAt - clockNow())
	countdown.Text = remaining > 0 and duration(remaining) .. " remaining" or "Your pet has returned"
	countdown.TextColor3 = remaining > 0 and T.Text or T.Success
	K.setButton(claim, busy and "Claiming finds..." or "Claim finds", T.Gold)
	K.setEnabled(claim, remaining <= 0 and not busy)
	if prompt then
		prompt.ActionText = remaining <= 0 and "Claim expedition finds" or "View expedition"
	end
end

render = function()
	local view = getView()
	if view ~= lastView then
		lastView = view
		serverClock, localClock = view and view.serverNow or os.time(), os.clock()
	end
	local active = view and type(view.active) == "table" and view.active
	activeBox.Visible, idleBox.Visible = active ~= false and active ~= nil, active == false or active == nil
	setNotice(noticeText, noticeColor)
	if not State.Loaded or not view then
		setNotice("Loading expedition plans...", T.Muted)
		idleBox.Visible = false
	else
		if noticeText == "Loading expedition plans..." then
			setNotice("", T.Muted)
		end
		if active then
			local pet
			for _, owned in State.Data.Creatures or {} do
				if owned.u == active.petUid then
					pet = owned
					break
				end
			end
			local def = Creatures.ById[active.creature]
			activeTitle.Text = pet and petName(pet) or (def and def.name or "Your creature")
			activeDetail.Text = worldName(active.world) .. " expedition"
			activeReward.Text = "Finds: "
				.. Format.Money(active.coins)
				.. (active.matched and " | Native biome bonus included" or "")
			activeHint.Text = "Unavailable until return is claimed. Garden income pauses while away.\n"
				.. (
					view.relics and view.relics[active.world] and "This biome's relic is already in your journal."
					or "Its first return recovers a biome relic for your map table."
				)
		else
			if not selectedPet() then
				selectedUid = State.Data.Creatures[1] and State.Data.Creatures[1].u
			end
			if not routeById(selectedRoute) then
				selectedRoute = nil
				for _, route in view.routes or {} do
					if route.unlocked then
						selectedRoute = route.id
						break
					end
				end
			end
			renderPets()
			renderRoutes()
		end
	end
	local collected = 0
	clearRows(journalGrid)
	for i, id in Rules.Order do
		local recovered = view and view.relics and view.relics[id] == true
		if recovered then
			collected += 1
		end
		label(
			journalGrid,
			worldName(id) .. "\n" .. (recovered and "Recovered" or "Not found"),
			38,
			14,
			recovered and T.Success or T.Muted,
			false,
			i
		).Size =
			UDim2.new(0.5, -6, 0, 38)
	end
	journalTitle.Text = "Biome relics  |  " .. collected .. " / " .. #Rules.Order
	updateSelection()
	updateClock()
end

function Panel.Open()
	if not initialized or HUD.IsOpen("Expeditions") then
		return
	end
	HUD.Open("Expeditions")
	task.spawn(function()
		local ok, message = State.Request("Sync")
		if not ok then
			setNotice(message or "Your plans could not refresh. Try the table again.", T.Danger)
		end
	end)
end

local function attachPrompt()
	local bases = workspace:FindFirstChild("Bases")
	local index = player:GetAttribute("BaseIndex") or State.Data.BaseIndex
	local base = bases and index and bases:FindFirstChild("Base" .. tostring(index))
	local nextAnchor = base and base:FindFirstChild("ExpeditionAnchor", true)
	if nextAnchor == anchor then
		return
	end
	if prompt then
		prompt:Destroy()
	end
	anchor, prompt = nextAnchor, nil
	if not nextAnchor or not nextAnchor:IsA("BasePart") then
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
		Parent = nextAnchor,
	})
	prompt.Triggered:Connect(function(who)
		if who == player then
			Panel.Open()
		end
	end)
	updateClock()
end

function Panel.Init()
	if initialized then
		return
	end
	initialized = true
	page = HUD.MakePanel("Expeditions", "Pet expeditions", "Send a pet and recover biome relics.", "Compass")
	K.list(Enum.FillDirection.Vertical, 14).Parent = page.content
	notice = label(page.content, "", 58, 15, T.Muted, false, 0)
	notice.Name, notice.Visible = "ExpeditionNotice", false
	activeBox = K.surface(page.content, "ActiveExpedition", UDim2.new(1, -12, 0, 286), nil, T.Ink)
	activeBox.LayoutOrder = 1
	activeTitle = K.text(activeBox, "", 16, 10, -32, 46, 20, T.Text, true)
	activeDetail = K.text(activeBox, "", 16, 60, -32, 26, 16, T.Muted)
	countdown = K.text(activeBox, "", 16, 92, -32, 30, 20, T.Text, true)
	activeReward = K.text(activeBox, "", 16, 128, -32, 42, 15, T.Gold)
	activeHint = K.text(activeBox, "", 16, 175, -32, 58, 14, T.Muted)
	for _, l in { activeTitle, activeDetail, countdown, activeReward, activeHint } do
		l.RichText = false
	end
	claim = K.button(
		"Claim finds",
		T.Gold,
		nil,
		UDim2.new(1, -32, 0, 44),
		{ Name = "ClaimExpedition", Position = UDim2.new(0, 16, 1, -52), Parent = activeBox }
	)
	K.bind(claim, function()
		local view = getView()
		if view and type(view.active) == "table" then
			request("ClaimExpedition", view.active.id)
		end
	end)
	idleBox = stack(page.content, "ExpeditionPlanning", 2)
	planningLayout = idleBox:FindFirstChildOfClass("UIListLayout")
	petHeading = label(idleBox, "Choose a creature", 30, 20, T.Text, true, 0)
	introduction = label(
		idleBox,
		"Pets from the mission's biome recover 25% more coins. A dispatched creature is unavailable and pauses its garden income until you claim its return.",
		70,
		15,
		T.Muted,
		false,
		1
	)
	petSearch = K.search(idleBox, "Search creatures", UDim2.new(1, -12, 0, 44))
	petSearch.Parent.LayoutOrder = 2
	petSearch:GetPropertyChangedSignal("Text"):Connect(function()
		renderPets()
	end)
	petEmpty = label(idleBox, "", 60, 15, T.Muted, false, 3)
	petList = scrollList(idleBox, "ExpeditionPets", 204, 4)
	petSummary = label(idleBox, "", 58, 16, T.Text, true, 5)
	missionHeading = label(idleBox, "Choose a mission", 30, 20, T.Text, true, 6)
	routeList = scrollList(idleBox, "ExpeditionRoutes", 194, 7)
	preview = label(idleBox, "", 100, 15, T.Text, false, 8)
	action = K.button(
		"Send on expedition",
		T.Gold,
		nil,
		UDim2.new(1, -12, 0, 48),
		{ Name = "StartExpedition", LayoutOrder = 9, Parent = idleBox }
	)
	K.bind(action, function()
		if selectedUid and selectedRoute then
			request("StartExpedition", Http:JSONEncode({ route = selectedRoute, petUid = selectedUid }))
		end
	end)
	local journal = stack(page.content, "RelicJournal", 3)
	journalTitle = label(journal, "Biome relics", 30, 20, T.Text, true, 0)
	journalHint =
		label(journal, "First completion in each biome adds its relic to your map table.", 42, 14, T.Muted, false, 1)
	journalGrid = K.new("Frame", {
		Name = "BiomeRelics",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 176),
		LayoutOrder = 2,
		Parent = journal,
	})
	K.new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 38),
		CellPadding = UDim2.fromOffset(8, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = journalGrid,
	})
	page.refresh = render
	page.layout = function()
		local narrow = page.frame.Size.X.Offset < 540
		local desktop = page.frame.Size.X.Offset >= 760
		activeBox.Size = UDim2.new(1, -12, 0, narrow and 444 or 286)
		activeTitle.Size = UDim2.new(1, -32, 0, narrow and 66 or 46)
		activeDetail.Position = UDim2.fromOffset(16, narrow and 80 or 60)
		activeDetail.Size = UDim2.new(1, -32, 0, narrow and 42 or 26)
		countdown.Position = UDim2.fromOffset(16, narrow and 127 or 92)
		activeReward.Position = UDim2.fromOffset(16, narrow and 166 or 128)
		activeReward.Size = UDim2.new(1, -32, 0, narrow and 72 or 42)
		activeHint.Position = UDim2.fromOffset(16, narrow and 244 or 175)
		activeHint.Size = UDim2.new(1, -32, 0, narrow and 124 or 58)
		if desktop then
			-- Keep selecting and dispatching in one view; each catalogue scrolls
			-- independently and the final choice/reward remains beside Send.
			planningLayout.Parent = nil
			idleBox.AutomaticSize = Enum.AutomaticSize.None
			idleBox.Size = UDim2.new(1, -12, 0, 440)
			introduction.Position = UDim2.fromOffset(0, 0)
			introduction.Size = UDim2.new(1, -12, 0, 42)
			petHeading.Position = UDim2.fromOffset(0, 50)
			petHeading.Size = UDim2.new(0.48, -8, 0, 26)
			missionHeading.Position = UDim2.new(0.52, 0, 0, 50)
			missionHeading.Size = UDim2.new(0.48, -8, 0, 26)
			petSearch.Parent.Position = UDim2.fromOffset(0, 84)
			petSearch.Parent.Size = UDim2.new(0.48, -8, 0, 40)
			petEmpty.Position = UDim2.fromOffset(0, 136)
			petEmpty.Size = UDim2.new(0.48, -8, 0, 60)
			petList.Position = UDim2.fromOffset(0, 132)
			petList.Size = UDim2.new(0.48, -8, 0, 144)
			routeList.Position = UDim2.new(0.52, 0, 0, 84)
			routeList.Size = UDim2.new(0.48, -8, 0, 192)
			petSummary.Position = UDim2.fromOffset(0, 288)
			petSummary.Size = UDim2.new(0.48, -8, 0, 64)
			preview.Position = UDim2.new(0.52, 0, 0, 288)
			preview.Size = UDim2.new(0.48, -8, 0, 96)
			action.Position = UDim2.fromOffset(0, 392)
			action.Size = UDim2.new(1, -12, 0, 48)
		else
			-- The phone/tablet plan remains one readable vertical sequence.
			planningLayout.Parent = idleBox
			idleBox.AutomaticSize = Enum.AutomaticSize.Y
			idleBox.Size = UDim2.new(1, -12, 0, 0)
			petHeading.Size = UDim2.new(1, -12, 0, 30)
			missionHeading.Size = UDim2.new(1, -12, 0, 30)
			introduction.Size = UDim2.new(1, -12, 0, narrow and 110 or 70)
			petSearch.Parent.Size = UDim2.new(1, -12, 0, 44)
			petEmpty.Size = UDim2.new(1, -12, 0, 60)
			petList.Size = UDim2.new(1, -12, 0, 204)
			petSummary.Size = UDim2.new(1, -12, 0, 58)
			routeList.Size = UDim2.new(1, -12, 0, 194)
			preview.Size = UDim2.new(1, -12, 0, narrow and 154 or 100)
			action.Size = UDim2.new(1, -12, 0, 48)
		end
		journalHint.Size = UDim2.new(1, -12, 0, narrow and 64 or 42)
		journalGrid.Size = UDim2.new(1, -12, 0, narrow and 352 or 176)
		journalGrid:FindFirstChildOfClass("UIGridLayout").CellSize = UDim2.new(narrow and 1 or 0.5, -6, 0, 38)
	end
	State.Changed:Connect(function(full)
		local view = getView()
		local viewChanged = view ~= lastView
		if viewChanged then
			lastView = view
			serverClock, localClock = view and view.serverNow or os.time(), os.clock()
		end
		if HUD.IsOpen("Expeditions") and (viewChanged or full) then
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
		if HUD.IsOpen("Expeditions") then
			updateClock()
		end
	end)
	HUD.Rescale()
	render()
	attachPrompt()
end

return Panel
