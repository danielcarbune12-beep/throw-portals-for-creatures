-- Sanctuary shops, collection, index, customization and settings.
-- All spending and ownership changes use the existing authoritative server actions.
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local Config = require(RS.Shared.Config)
local Data = require(RS.Shared.CreatureData)
local Portal = require(RS.Shared.PortalBuilder)
local Format = require(RS.Shared.Format)
local Odds = require(RS.Shared.Odds)
local Variants = require(RS.Shared.Variants)
local K = require(script.Parent.UIKit)
local T = K.Theme
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.ClientState)
local Settings = require(script.Parent.ClientSettings)
local Renderer = require(script.Parent.CreatureRenderer)
local Sounds = require(script.Parent.Sounds)
local Panels = {}
local function request(action, arg, message)
	if not State.Loaded then
		HUD.Notify("Your data is loading. Please wait.", "error")
		return false
	end
	local ok, msg = State.Request(action, arg)
	HUD.Notify(
		msg or (ok and (message or "Updated successfully.") or "Could not complete this action. Try again."),
		ok and "success" or "error"
	)
	if ok then
		Sounds.Play("Upgrade")
	end
	return ok
end
local function scroll(parent, name, size, pos)
	return K.new("ScrollingFrame", {
		Name = name,
		Size = size or UDim2.fromScale(1, 1),
		Position = pos or UDim2.new(),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = T.Violet,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	}, { K.pad(3) })
end
local function list(parent, gap)
	K.list(Enum.FillDirection.Vertical, gap or 10).Parent = parent
end
local function heading(parent, text, order)
	local l = K.label(text, UDim2.new(1, -12, 0, 36), T.Text, {
		TextSize = 20,
		Font = T.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	return l
end
local function empty(parent, title, hint)
	local f = K.surface(parent, "Empty", UDim2.new(1, -12, 0, 124))
	K.text(f, title, 16, 16, -32, 28, 19, T.Text, true)
	K.text(f, hint, 16, 49, -32, 56, 15, T.Muted)
	return f
end
local previewCache = {}
local function petView(id, size, silhouette, material)
	local cacheKey = material and (id .. "|" .. material) or id
	if not previewCache[cacheKey] then
		previewCache[cacheKey] = (Renderer.BuildPreview(id, material))
	end
	return K.viewport(previewCache[cacheKey]:Clone(), size, false, silhouette)
end
local function bindGrid(container, minWidth, cellHeight)
	local g = K.new(
		"UIGridLayout",
		{ CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = container }
	)
	local function resize()
		local w = container.AbsoluteSize.X / HUD.Root:FindFirstChildOfClass("UIScale").Scale - 12
		local cols = math.max(1, math.floor((w + 10) / (minWidth + 10)))
		g.CellSize = UDim2.new(1 / cols, -(10 * (cols - 1) + 12) / cols, 0, cellHeight)
	end
	container:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	task.defer(resize)
	return g
end
-- On small screens the catalogue and detail are separate views, not squeezed columns.
local function split(p)
	p.content.AutomaticCanvasSize = Enum.AutomaticSize.None
	p.content.ScrollingEnabled = false
	local catalogue = scroll(p.content, "Catalogue")
	local detail = scroll(p.content, "Details", UDim2.new(0.43, -8, 1, 0), UDim2.new(0.57, 8, 0, 0))
	local back = K.button(
		"Back to all items",
		T.Raised,
		nil,
		UDim2.new(1, -8, 0, 44),
		{ Name = "BackToCatalogue", Position = UDim2.fromOffset(4, 0), Parent = p.content, Visible = false }
	)
	K.bind(back, function()
		p.showDetail = false
		p.layout()
	end)
	p.layout = function()
		if p.compact then
			catalogue.Size = UDim2.fromScale(1, 1)
			catalogue.Visible = not p.showDetail
			detail.Position = UDim2.fromOffset(0, 54)
			detail.Size = UDim2.new(1, 0, 1, -54)
			detail.Visible = p.showDetail or false
			back.Visible = p.showDetail or false
		else
			catalogue.Size = UDim2.new(0.56, -8, 1, 0)
			catalogue.Visible = true
			detail.Position = UDim2.new(0.57, 8, 0, 0)
			detail.Size = UDim2.new(0.43, -12, 1, 0)
			detail.Visible = true
			back.Visible = false
		end
	end
	p.layout()
	return catalogue, detail
end
local function showDetail(p)
	p.showDetail = true
	p.layout()
end

---------------------------------------------------------------- Portal shop
local shop = HUD.MakePanel(
	"Portals",
	"Portal forge",
	"Permanent purchases with earned coins. Select a portal to inspect it.",
	"Portal"
)
local catalogue, portalDetail = split(shop)
bindGrid(catalogue, 155, 204)
local portalRows = {}
local selectedPortal = "Basic"
local builtPortal
local portalAction, portalStatus
for i, id in ipairs(Config.PortalOrder) do
	local def = Config.Portals[id]
	local b = K.button("", T.Raised, nil, nil, { Name = "Portal_" .. id, LayoutOrder = i, Parent = catalogue })
	local vp = K.viewport(Portal.BuildGate(id, 3), UDim2.new(1, -10, 0, 114), false)
	vp.Position = UDim2.fromOffset(5, 2)
	vp.Parent = b
	K.text(b, def.name, 12, 119, -24, 25, 16, T.Text, true)
	local status = K.text(b, "", 12, 146, -24, 20, 14, T.Muted)
	local price =
		K.text(b, def.price == 0 and "Starter portal" or Format.Money(def.price), 12, 173, -24, 20, 15, T.Gold, true)
	portalRows[id] = { button = b, status = status, price = price }
	K.bind(b, function()
		selectedPortal = id
		builtPortal = nil
		shop.refresh()
		showDetail(shop)
	end)
end
local function refreshPortalDetail()
	if builtPortal == selectedPortal then
		return
	end
	builtPortal = selectedPortal
	portalDetail:ClearAllChildren()
	K.pad(4).Parent = portalDetail
	list(portalDetail, 8)
	local def = Config.Portals[selectedPortal]
	local preview = K.surface(portalDetail, "Hero", UDim2.new(1, -12, 0, 178), nil, T.Inset)
	preview.LayoutOrder = 1
	local vp = K.viewport(Portal.BuildGate(selectedPortal, 4), UDim2.fromScale(1, 1), false)
	vp.Parent = preview
	heading(portalDetail, def.name, 2)
	portalStatus =
		K.label("", UDim2.new(1, -12, 0, 30), T.Muted, { TextSize = 15, LayoutOrder = 3, Parent = portalDetail })
	portalAction = K.button(
		"",
		T.Gold,
		nil,
		UDim2.new(1, -12, 0, 48),
		{ Name = "PortalAction", LayoutOrder = 4, Parent = portalDetail }
	)
	K.bind(portalAction, function()
		local id = selectedPortal
		if State.Data.OwnedPortals[id] then
			request("EquipPortal", id, "Portal equipped.")
		else
			request("BuyPortal", id, Config.Portals[id].name .. " purchased.")
		end
	end)
	heading(portalDetail, "Base rarity weights", 5)
	local sum = 0
	for _, weight in pairs(def.weights) do
		sum += weight
	end
	for i, r in ipairs(Config.RarityOrder) do
		local weight = def.weights[r]
		if weight then
			local row = K.new("Frame", {
				Size = UDim2.new(1, -12, 0, 24),
				BackgroundTransparency = 1,
				LayoutOrder = 5 + i,
				Parent = portalDetail,
			})
			K.text(row, r, 0, 0, -80, 24, 14, T.Rarity(r, Config))
			local pct = string.format("%.2f%%", 100 * weight / sum):gsub("%.00%%", "%%")
			K.label(pct, UDim2.fromOffset(76, 24), T.Text, {
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(1, -76, 0, 0),
				Parent = row,
			})
		end
	end
	K.label(
		"These are normalized base weights. Landing zone and distance luck affect the final creature odds; see the Index for attainable odds.",
		UDim2.new(1, -12, 0, 76),
		T.Muted,
		{ TextSize = 14, LayoutOrder = 30, Parent = portalDetail }
	)
end
shop.refresh = function()
	refreshPortalDetail()
	local d = State.Data
	for id, row in pairs(portalRows) do
		local equipped = d.EquippedPortal == id
		local owned = d.OwnedPortals[id]
		row.status.Text = equipped and "Equipped" or owned and "Owned" or "View portal"
		row.status.TextColor3 = equipped and T.Success or T.Muted
		row.button:FindFirstChildOfClass("UIStroke").Color = selectedPortal == id and T.Gold or T.Border
	end
	local def = Config.Portals[selectedPortal]
	local owned = d.OwnedPortals[selectedPortal]
	local equipped = d.EquippedPortal == selectedPortal
	portalStatus.Text = equipped and "Your active portal"
		or owned and "Owned permanently"
		or "Price: " .. Format.Money(def.price) .. " coins"
	K.setButton(
		portalAction,
		equipped and "Equipped"
			or owned and "Equip portal"
			or d.Money < def.price and "Need " .. Format.Money(def.price - d.Money) .. " more"
			or "Buy portal · " .. Format.Money(def.price),
		T.Gold
	)
	K.setEnabled(portalAction, State.Loaded and not equipped and (owned or d.Money >= def.price))
end

---------------------------------------------------------------- Upgrades
local upg =
	HUD.MakePanel("Upgrades", "Sanctuary upgrades", "See the improvement and the exact cost before buying.", "Upgrade")
list(upg.content, 12)
local upgradeRefs = {}
local upgradeIcons = { ThrowPower = "Arrow", BaseSlots = "Home", Storage = "Bag", Training = "Strength" }
local function effect(kind, lvl)
	if kind == "ThrowPower" then
		return math.floor(Config.ThrowDistance(lvl, State.Data.Strength or 0)) .. " m range"
	end
	if kind == "BaseSlots" then
		return Config.StartSlots + lvl .. " garden slots"
	end
	if kind == "Storage" then
		return Config.StartStorage + lvl * Config.StoragePerLevel .. " storage"
	end
	return "+" .. math.floor(lvl * Config.TrainingBonus * 100) .. "% income"
end
for i, kind in ipairs({ "ThrowPower", "BaseSlots", "Storage", "Training" }) do
	local def = Config.Upgrades[kind]
	local row = K.surface(upg.content, "Upgrade_" .. kind, UDim2.new(1, -12, 0, 142))
	row.LayoutOrder = i
	K.Icon(upgradeIcons[kind], row, UDim2.fromOffset(26, 26), T.Gold, UDim2.fromOffset(16, 18))
	local title = K.text(row, def.name, 54, 10, -72, 28, 19, T.Text, true)
	K.text(row, def.desc, 16, 45, -32, 35, 14, T.Muted)
	local value = K.text(row, "", 16, 91, -196, 39, 15, T.Cyan)
	local b = K.button(
		"",
		T.Gold,
		nil,
		UDim2.fromOffset(164, 44),
		{ Name = "Buy_" .. kind, Position = UDim2.new(1, -180, 1, -56), Parent = row }
	)
	K.bind(b, function()
		request("Upgrade", kind, def.name .. " improved.")
	end)
	upgradeRefs[kind] = { title = title, value = value, button = b }
end
upg.refresh = function()
	for kind, ref in pairs(upgradeRefs) do
		local def = Config.Upgrades[kind]
		local lvl = State.Data.Upgrades[kind]
		local idx = kind == "ThrowPower" and lvl - 1 or lvl
		local maxed = idx >= def.max
		local cost = Config.UpgradeCost(kind, idx)
		ref.title.Text = def.name .. " · " .. idx .. "/" .. def.max
		ref.value.Text = effect(kind, lvl) .. (maxed and "" or " → " .. effect(kind, lvl + 1))
		K.setButton(
			ref.button,
			maxed and "Maximum level"
				or State.Data.Money < cost and "Need " .. Format.Money(cost - State.Data.Money)
				or "Buy · " .. Format.Money(cost),
			T.Gold
		)
		K.setEnabled(ref.button, State.Loaded and not maxed and State.Data.Money >= cost)
	end
end

---------------------------------------------------------------- Inventory
local inv = HUD.MakePanel(
	"Creatures",
	"Your creatures",
	"Select a creature to place it, remove it or review its sell value.",
	"Pet"
)
local invCatalogue, invDetail = split(inv)
local invSearch = K.search(invCatalogue, "Search creatures", UDim2.new(1, -12, 0, 46), UDim2.fromOffset(4, 4))
invCatalogue.AutomaticCanvasSize = Enum.AutomaticSize.None
invCatalogue.ScrollingEnabled = false
local best = K.button(
	"Place best",
	T.Gold,
	nil,
	UDim2.new(1, -12, 0, 44),
	{ Name = "EquipBest", Position = UDim2.fromOffset(4, 58), Parent = invCatalogue }
)
K.bind(best, function()
	request("EquipBest", nil, "Best earners placed in your garden.")
end)
local invGrid = scroll(invCatalogue, "Creatures", UDim2.new(1, 0, 1, -116), UDim2.fromOffset(0, 112))
local selectedUid, inventoryKey, detailKey, armedUid, armToken = nil, nil, nil, nil, 0
local inventoryButtons = {}
local function clearArm()
	armedUid = nil
	armToken += 1
end
local function renderCreatureDetail()
	local d = State.Data
	local entry
	for _, e in ipairs(d.Creatures) do
		if e.u == selectedUid then
			entry = e
			break
		end
	end
	local awayUid = d.Expeditions and d.Expeditions.active and d.Expeditions.active.petUid
	local key = entry
			and entry.u .. ":" .. tostring(State.IsPlaced(entry.u)) .. ":" .. tostring(armedUid) .. ":" .. tostring(
				awayUid
			)
		or "empty"
	if detailKey == key then
		return
	end
	detailKey = key
	invDetail:ClearAllChildren()
	K.pad(4).Parent = invDetail
	list(invDetail, 10)
	if not entry then
		empty(invDetail, "Choose a creature", "Throw a portal in the Launch Hall to start your collection.")
		return
	end
	local def = Data.ById[entry.c]
	local color = T.Legible(Variants.Color(entry.s, entry.v) or T.Rarity(def.rarity, Config))
	local entryIncome = Data.Income(entry.c) * Variants.Mult(entry.s, entry.v)
	local hero = K.surface(invDetail, "CreaturePreview", UDim2.new(1, -12, 0, 180), nil, T.Inset)
	hero.LayoutOrder = 1
	petView(entry.c, UDim2.fromScale(1, 1), nil, entry.v).Parent = hero
	heading(invDetail, Variants.Prefix(entry.s, entry.v) .. def.name, 2)
	K.label(
		def.rarity
			.. " · "
			.. Format.Money(entryIncome)
			.. " / sec"
			.. (Variants.Mult(entry.s, entry.v) > 1 and ("  (x" .. Variants.Mult(entry.s, entry.v) .. ")") or ""),
		UDim2.new(1, -12, 0, 28),
		color,
		{ TextSize = 16, LayoutOrder = 3, Parent = invDetail }
	)
	K.label(def.desc or "", UDim2.new(1, -12, 0, 56), T.Muted, { TextSize = 14, LayoutOrder = 4, Parent = invDetail })
	local isPlaced = State.IsPlaced(entry.u)
	local away = awayUid == entry.u
	local place = K.button(
		away and "On expedition" or isPlaced and "Remove from garden" or "Place in garden",
		T.Gold,
		nil,
		UDim2.new(1, -12, 0, 46),
		{ Name = "PlaceCreature", LayoutOrder = 5, Parent = invDetail }
	)
	K.bind(place, function()
		clearArm()
		request(State.IsPlaced(entry.u) and "Unplace" or "Place", entry.u, "Garden updated.")
	end)
	local cap = isPlaced and (#d.Creatures - #d.Placed >= d.StorageCap) or (not isPlaced and #d.Placed >= d.SlotsOpen)
	if cap and not away then
		K.setButton(place, isPlaced and "Storage is full" or "Garden is full")
	end
	K.setEnabled(place, not cap and not away)
	local sellValue = math.floor(entryIncome * Config.SellMultiplier)
	local sell = K.button(
		armedUid == entry.u and "Confirm sale · " .. Format.Money(sellValue)
			or "Sell creature · " .. Format.Money(sellValue),
		armedUid == entry.u and T.Danger or T.Raised,
		nil,
		UDim2.new(1, -12, 0, 46),
		{ Name = "SellCreature", LayoutOrder = 6, Parent = invDetail }
	)
	K.setEnabled(sell, not away)
	K.bind(sell, function()
		if away then
			return
		end
		if selectedUid ~= entry.u then
			clearArm()
			return
		end
		if armedUid ~= entry.u then
			armedUid = entry.u
			armToken += 1
			local token = armToken
			detailKey = nil
			renderCreatureDetail()
			task.delay(4, function()
				if armToken == token then
					clearArm()
					detailKey = nil
					if HUD.IsOpen("Creatures") then
						renderCreatureDetail()
					end
				end
			end)
		else
			clearArm()
			if request("Sell", entry.u, "Creature sold.") then
				selectedUid = nil
				detailKey = nil
				inv.refresh()
			end
		end
	end)
	K.label(
		away and "Your pet is exploring. Claim its return at the expedition table to make it available again."
			or armedUid == entry.u and "This permanently removes " .. def.name .. ". Select Confirm sale within 4 seconds."
			or "Selling permanently removes this creature. A second confirmation is required.",
		UDim2.new(1, -12, 0, 60),
		armedUid == entry.u and T.Danger or T.Muted,
		{ TextSize = 14, LayoutOrder = 7, Parent = invDetail }
	)
end
inv.refresh = function()
	local d = State.Data
	inv.subtitle.Text = string.format(
		"Garden %d/%d · Stored %d/%d · Income %s / sec",
		#d.Placed,
		d.SlotsOpen,
		#d.Creatures - #d.Placed,
		d.StorageCap,
		Format.Money(d.Income)
	)
	local ids = {}
	for _, e in ipairs(d.Creatures) do
		table.insert(ids, e.u .. ":" .. tostring(State.IsPlaced(e.u)))
	end
	local key = table.concat(ids, ",") .. invSearch.Text:lower()
	if inventoryKey ~= key then
		inventoryKey = key
		invGrid:ClearAllChildren()
		inventoryButtons = {}
		bindGrid(invGrid, 140, 192)
		local items = table.clone(d.Creatures)
		table.sort(items, function(a, b)
			return Data.Income(a.c) * Variants.Mult(a.s, a.v) > Data.Income(b.c) * Variants.Mult(b.s, b.v)
		end)
		local count = 0
		for i, entry in ipairs(items) do
			local def = Data.ById[entry.c]
			if def and def.name:lower():find(invSearch.Text:lower(), 1, true) then
				count += 1
				local b = K.button(
					"",
					T.Raised,
					nil,
					nil,
					{ Name = "Creature_" .. entry.u, LayoutOrder = i, Parent = invGrid }
				)
				petView(entry.c, UDim2.new(1, -8, 0, 108), nil, entry.v).Parent = b
				K.text(
					b,
					Variants.Prefix(entry.s, entry.v) .. def.name,
					10,
					110,
					-20,
					38,
					15,
					T.Legible(Variants.Color(entry.s, entry.v) or T.Text),
					true
				)
				K.text(b, def.rarity, 10, 151, -20, 18, 13, T.Rarity(def.rarity, Config))
				K.text(
					b,
					State.IsPlaced(entry.u) and "In garden" or "In storage",
					10,
					171,
					-20,
					18,
					13,
					State.IsPlaced(entry.u) and T.Success or T.Muted
				)
				inventoryButtons[entry.u] = b
				K.bind(b, function()
					clearArm()
					selectedUid = entry.u
					detailKey = nil
					inv.refresh()
					showDetail(inv)
				end)
			end
		end
		if count == 0 then
			invGrid:ClearAllChildren()
			empty(
				invGrid,
				#items == 0 and "Your collection starts here" or "No matching creatures",
				#items == 0
						and "Enter the Launch Hall and throw your first portal. Caught creatures appear here automatically."
					or "Try a different name or clear your search."
			)
		end
	end
	for uid, b in pairs(inventoryButtons) do
		b:FindFirstChildOfClass("UIStroke").Color = uid == selectedUid and T.Gold or T.Border
	end
	if selectedUid then
		local found = false
		for _, e in d.Creatures do
			if e.u == selectedUid then
				found = true
			end
		end
		if not found then
			selectedUid = nil
			clearArm()
			detailKey = nil
		end
	end
	renderCreatureDetail()
end
inv.onClose = function()
	clearArm()
	detailKey = nil
end
invSearch:GetPropertyChangedSignal("Text"):Connect(function()
	inv.refresh()
end)

---------------------------------------------------------------- Discovery index
local idx = HUD.MakePanel(
	"Index",
	"Creature index",
	"Discover every species. Odds reflect your equipped portal and best perfect throw.",
	"Book"
)
idx.content.ScrollingEnabled = false
idx.content.AutomaticCanvasSize = Enum.AutomaticSize.None
local tabs = K.new("ScrollingFrame", {
	Name = "Filters",
	Size = UDim2.new(1, -4, 0, 48),
	BackgroundTransparency = 1,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = T.Violet,
	Parent = idx.content,
}, { K.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left) })
local idxGrid = scroll(idx.content, "Species", UDim2.new(1, 0, 1, -62), UDim2.fromOffset(0, 60))
local idxFilter = "Forest"
local idxKey
local idxTabs = {}
local filters = table.clone(Config.WorldOrder)
table.insert(filters, "Any")
for i, id in ipairs(filters) do
	local name = id == "Any" and "Special" or id
	local b = K.button(
		name,
		T.Raised,
		nil,
		UDim2.fromOffset(100, 44),
		{ Name = "Filter_" .. id, LayoutOrder = i, Parent = tabs }
	)
	idxTabs[id] = b
	K.bind(b, function()
		idxFilter = id
		idxKey = nil
		idxGrid.CanvasPosition = Vector2.zero
		idx.refresh()
	end)
end
idx.refresh = function()
	local d = State.Data
	local found = 0
	for _ in pairs(d.Discovered) do
		found += 1
	end
	idx.title.Text = "Creature index · " .. found .. "/" .. #Data.List
	local key = idxFilter .. ":" .. found .. ":" .. d.EquippedPortal .. ":" .. math.floor(d.MaxDistance or 0)
	for id, b in pairs(idxTabs) do
		K.setButton(b, nil, id == idxFilter and T.Violet or T.Raised)
	end
	if idxKey == key then
		return
	end
	idxKey = key
	idxGrid:ClearAllChildren()
	bindGrid(idxGrid, 146, 222)
	for i, def in ipairs(Data.ByWorld[idxFilter] or {}) do
		local known = d.Discovered[def.id]
		local b = K.button("", T.Raised, nil, nil, { Name = "Species_" .. def.id, LayoutOrder = i, Parent = idxGrid })
		petView(def.id, UDim2.new(1, -8, 0, 112), not known).Parent = b
		K.text(b, known and def.name or "Undiscovered", 10, 116, -20, 36, 15, T.Text, true)
		K.text(b, def.rarity, 10, 154, -20, 20, 14, T.Rarity(def.rarity, Config))
		local status, p = Odds.Attainable(def.id, d.EquippedPortal, (d.MaxDistance or 45) * 1.15)
		local odds = status == "ok" and Odds.OneIn(p)
			or status == "out_of_range" and "Out of throw range"
			or "Different portal needed"
		K.text(b, odds, 10, 178, -20, 36, 13, T.Muted)
		K.bind(b, function()
			HUD.SetPanelMessage(
				"Index",
				known and def.name .. ": " .. def.desc or "Land in the correct zone to discover this species.",
				T.Muted
			)
		end)
	end
end

---------------------------------------------------------------- Zones
local worlds = HUD.MakePanel(
	"Worlds",
	"Explore the zones",
	"Throw distance determines the landing zone. Throw Power upgrades extend your reach.",
	"Compass"
)
list(worlds.content, 10)
local worldRefs = {}
for i, id in ipairs(Config.WorldOrder) do
	local W = Config.Worlds[id]
	local bounds = Config.ZoneBounds[id]
	local row = K.surface(worlds.content, "Zone_" .. id, UDim2.new(1, -12, 0, 122))
	row.LayoutOrder = i
	K.Icon("Compass", row, UDim2.fromOffset(28, 28), W.atmo:Lerp(T.Text, 0.2), UDim2.fromOffset(16, 16))
	K.text(row, W.name, 56, 12, -72, 30, 19, T.Text, true)
	K.text(
		row,
		bounds[1] .. "–" .. bounds[2] .. " m · " .. Format.Short(W.incomeMult) .. "× income",
		16,
		49,
		-32,
		24,
		15,
		T.Cyan
	)
	worldRefs[id] = K.text(row, "", 16, 82, -32, 26, 15, T.Muted)
end
worlds.refresh = function()
	local max = (State.Data.MaxDistance or 45) * 1.15
	worlds.subtitle.Text = "Your best perfect throw: "
		.. math.floor(max)
		.. " m. Upgrade Throw Power to reach the next zone."
	for id, label in pairs(worldRefs) do
		local found, total = 0, 0
		for _, def in ipairs(Data.ByWorld[id] or {}) do
			total += 1
			if State.Data.Discovered[def.id] then
				found += 1
			end
		end
		label.Text = (
			max >= Config.ZoneBounds[id][1] and "In range"
			or "Need " .. math.ceil(Config.ZoneBounds[id][1] - max) .. " m more range"
		)
			.. " · Discovered "
			.. found
			.. "/"
			.. total
	end
end

---------------------------------------------------------------- Garden shop
local base = HUD.MakePanel(
	"Base",
	"Garden workshop",
	"Decorations appear in your garden. Floor purchases are applied immediately.",
	"Decor"
)
list(base.content, 10)
local baseRefs = {}
local floorRefs = {}
heading(base.content, "Decorations", 0)
local decorCopy = {
	FlowerBed = "Color for the edge of your garden.",
	Lanterns = "Warm lights around your plot.",
	MushroomRing = "A small magical garden feature.",
	Fountain = "Add a decorative portal fountain.",
	CrystalTree = "A faceted crystal centerpiece.",
	Statue = "A golden garden monument.",
	Rainbow = "Frame your garden with a rainbow arch.",
	FloatingIsland = "A floating display above your plot.",
}
local function shopRow(parent, id, title, desc, icon, order)
	local row = K.surface(parent, id, UDim2.new(1, -12, 0, 130))
	row.LayoutOrder = order
	K.Icon(icon, row, UDim2.fromOffset(26, 26), T.Violet, UDim2.fromOffset(16, 14))
	K.text(row, title, 54, 10, -70, 28, 18, T.Text, true)
	K.text(row, desc, 16, 43, -32, 28, 14, T.Muted)
	local b = K.button(
		"",
		T.Gold,
		nil,
		UDim2.fromOffset(190, 44),
		{ Name = "Buy_" .. id, Position = UDim2.new(1, -206, 1, -55), Parent = row }
	)
	return b, row
end
for i, id in ipairs(Config.DecorOrder) do
	local def = Config.Decor[id]
	local b = shopRow(base.content, id, def.name, decorCopy[id] or "Garden decoration.", "Decor", i)
	baseRefs[id] = b
	K.bind(b, function()
		request("BuyDecor", id, def.name .. " added to your garden.")
	end)
end
heading(base.content, "Floor finishes", 30)
for i, def in ipairs(Config.FloorThemes) do
	local b, row = shopRow(base.content, def.id, def.name, "Choose the surface beneath your creatures.", "Home", 30 + i)
	K.new("Frame", {
		Position = UDim2.fromOffset(16, 82),
		Size = UDim2.fromOffset(70, 32),
		BackgroundColor3 = def.color,
		Parent = row,
	}, { K.corner(4), K.stroke(1) })
	floorRefs[def.id] = b
	K.bind(b, function()
		request("Floor", def.id, "Floor applied.")
	end)
end
base.refresh = function()
	local d = State.Data
	for id, b in pairs(baseRefs) do
		local price = Config.Decor[id].price
		local owned = d.Decor[id]
		K.setButton(
			b,
			owned and "Owned"
				or d.Money < price and "Need " .. Format.Money(price - d.Money)
				or "Buy · " .. Format.Money(price),
			T.Gold
		)
		K.setEnabled(b, State.Loaded and not owned and d.Money >= price)
	end
	for id, b in pairs(floorRefs) do
		local def
		for _, f in Config.FloorThemes do
			if f.id == id then
				def = f
				break
			end
		end
		local active = d.FloorTheme == id
		local owned = d.OwnedFloors[id]
		K.setButton(
			b,
			active and "Applied"
				or owned and "Apply floor"
				or d.Money < def.price and "Need " .. Format.Money(def.price - d.Money)
				or "Buy & apply · " .. Format.Money(def.price),
			T.Gold
		)
		K.setEnabled(b, State.Loaded and not active and (owned or d.Money >= def.price))
	end
end

---------------------------------------------------------------- Accessible presentation settings
local settings = HUD.MakePanel(
	"Settings",
	"Presentation settings",
	"Changes last for this session and do not affect rewards or creature odds.",
	"Settings"
)
list(settings.content, 10)
local settingRefs = {}
for i, def in ipairs({
	{ "ReducedMotion", "Reduced motion", "Shorter camera movements and instant interface transitions." },
	{ "ReducedFlashes", "Reduced flashes", "Suppress full-screen flashes during reveals." },
	{ "CameraShake", "Camera shake", "Allow impact shake during large reveals." },
	{ "VFXQuality", "Visual effects", "Low reduces extra particles and trails." },
	{ "AmbientMotes", "Ambient motes", "Optional floating motes in the world." },
}) do
	local b = shopRow(settings.content, def[1], def[2], def[3], "Settings", i)
	settingRefs[def[1]] = b
	K.bind(b, function()
		local value = Settings[def[1]]
		if typeof(value) == "boolean" then
			Settings.Set(def[1], not value)
		else
			Settings.Set(def[1], value == "High" and "Low" or "High")
		end
		settings.refresh()
	end)
end
settings.refresh = function()
	for key, b in pairs(settingRefs) do
		local value = Settings[key]
		K.setButton(
			b,
			typeof(value) == "boolean" and (value and "On" or "Off") or value,
			((value == true) or value == "High") and T.Violet or T.Raised
		)
	end
end

---------------------------------------------------------------- Admin: existing authorized server commands retained
local admin = HUD.MakePanel(
	"Admin",
	"Studio administration",
	"Server permissions still apply. Use the explicit confirmation to reset your data.",
	"Settings"
)
list(admin.content, 10)
local adminBox, adminSearch = K.search(admin.content, "Amount or creature ID", UDim2.new(1, -12, 0, 48), UDim2.new())
adminBox.Text = "1000000"
adminSearch.LayoutOrder = 1
local adminGrid = K.new("Frame", {
	Size = UDim2.new(1, -12, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Parent = admin.content,
})
bindGrid(adminGrid, 190, 46)
local function cmd(name, value)
	return request("Admin", Http:JSONEncode({ cmd = name, value = value }))
end
local adminCommands = {
	{ "Add money", "money" },
	{ "Add strength", "strength" },
	{ "Set throw level", "throwlevel" },
	{ "Max upgrades", "maxupgrades" },
	{ "Unlock portals", "allportals" },
	{ "Complete index", "discoverall" },
	{ "Set walk speed", "speed" },
	{ "Give creature", "give" },
	{ "Force next creature", "forcenext" },
}
for i, def in ipairs(adminCommands) do
	local b = K.button(def[1], T.Raised, nil, nil, { Name = "Admin_" .. def[2], LayoutOrder = i, Parent = adminGrid })
	K.bind(b, function()
		cmd(def[2], tonumber(adminBox.Text) or adminBox.Text)
	end)
end
local reset = K.button(
	"Reset my data",
	T.Raised,
	nil,
	UDim2.new(1, -12, 0, 46),
	{ Name = "ResetMyData", LayoutOrder = 3, Parent = admin.content }
)
local resetArmed = false
local resetToken = 0
K.bind(reset, function()
	if not resetArmed then
		resetArmed = true
		resetToken += 1
		local token = resetToken
		K.setButton(reset, "Confirm reset: deletes all progress", T.Danger)
		task.delay(4, function()
			if resetToken == token then
				resetArmed = false
				K.setButton(reset, "Reset my data", T.Raised)
			end
		end)
	else
		resetArmed = false
		resetToken += 1
		cmd("reset")
		K.setButton(reset, "Reset my data", T.Raised)
	end
end)
admin.onClose = function()
	resetArmed = false
	resetToken += 1
	K.setButton(reset, "Reset my data", T.Raised)
end
heading(admin.content, "Teleport to zone", 4)
local zones = K.new("Frame", {
	Size = UDim2.new(1, -12, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 5,
	Parent = admin.content,
})
bindGrid(zones, 180, 44)
local zonesOrder = { "Start" }
for _, id in Config.WorldOrder do
	table.insert(zonesOrder, id)
end
for i, id in zonesOrder do
	local b = K.button(id, T.Raised, nil, nil, { Name = "AdminZone_" .. id, LayoutOrder = i, Parent = zones })
	K.bind(b, function()
		if cmd("zone", id) then
			HUD.Close()
		end
	end)
end
admin.refresh = function() end

-- Secondary tools remain reachable without adding primary HUD destinations.
local function headerLink(panel, name, title, target)
	local b = K.button(title, T.Raised, nil, UDim2.fromOffset(176, 36), {
		Name = name,
		Position = UDim2.fromOffset(20, 64),
		Parent = panel.frame,
	})
	panel.subtitle.Visible = false
	K.bind(b, function()
		HUD.Open(target)
	end)
	return b
end
headerLink(inv, "OpenCollection", "Collection", "Index")
headerLink(idx, "BackToPets", "<  Pets", "Creatures")
local hub = HUD.MakePanel("Shop", "Sanctuary shop", "Choose what you want to improve.", "Shop")
K.new("UIGridLayout", {
	CellSize = UDim2.new(0.5, -8, 0, 128),
	CellPadding = UDim2.fromOffset(12, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = hub.content,
})
for i, def in
	{
		{ "Portals", "Portal", "Portals", "Buy and equip your portal." },
		{ "Upgrades", "Upgrade", "Upgrades", "Throw power, slots and income." },
		{ "Courtyard", "Home", "Base", "Flooring and base details." },
		{ "Biomes", "Compass", "Worlds", "Unlock and travel to new zones." },
	}
do
	local b = K.button("", T.Raised, nil, nil, { Name = "Shop_" .. def[1], LayoutOrder = i, Parent = hub.content })
	K.Icon(def[2], b, UDim2.fromOffset(40, 40), T.Gold, UDim2.fromOffset(14, 16))
	b.Label.Position = UDim2.fromOffset(64, 12)
	b.Label.Size = UDim2.new(1, -76, 0, 32)
	b.Label.Text = def[1]
	b.Label.TextSize = 19
	b.Label.TextXAlignment = Enum.TextXAlignment.Left
	K.text(b, def[4], 14, 66, -28, 48, 14, T.Muted)
	K.bind(b, function()
		HUD.Open(def[3])
	end)
end
for _, panel in { shop, upg, base, worlds } do
	headerLink(panel, "BackToShop", "<  Shop", "Shop")
end
local home = K.button("Return to courtyard", T.Raised, nil, UDim2.new(1, -12, 0, 44), {
	Name = "ReturnHome",
	LayoutOrder = 90,
	Parent = settings.content,
})
K.bind(home, function()
	if request("Teleport", "Home", "Returned home.") then
		HUD.Close()
	end
end)
local adminLink = K.button("Developer tools", T.Raised, nil, UDim2.new(1, -12, 0, 44), {
	Name = "DeveloperTools",
	LayoutOrder = 91,
	Parent = settings.content,
	Visible = false,
})
K.bind(adminLink, function()
	HUD.Open("Admin")
end)
headerLink(admin, "BackToSettings", "<  Settings", "Settings")
function Panels.Init()
	for _, def in
		{
			{ "Pets", "Pet", "Creatures" },
			{ "Shop", "Shop", "Shop" },
			{ "Expeditions", "Compass", "Expeditions" },
			{ "Settings", "Settings", "Settings" },
		}
	do
		HUD.AddSideButton(def[1], def[2], nil, nil, function()
			if def[3] == "Expeditions" then
				require(script.Parent.ExpeditionPanel).Open()
			else
				HUD.Open(def[3])
			end
		end)
	end
	local p = Players.LocalPlayer
	local function refreshAdmin()
		adminLink.Visible = p:GetAttribute("IsAdmin") == true
	end
	p:GetAttributeChangedSignal("IsAdmin"):Connect(refreshAdmin)
	refreshAdmin()
	HUD.Rescale()
end
return Panels
