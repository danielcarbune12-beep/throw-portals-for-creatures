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
local Farm = require(RS.Shared.FarmConfig)
local K = require(script.Parent.UIKit)
local T = K.Theme
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.ClientState)
local Settings = require(script.Parent.ClientSettings)
local Renderer = require(script.Parent.CreatureRenderer)
local Sounds = require(script.Parent.Sounds)
local Craft = require(script.Parent.SanctuaryUI)
local Guild = require(script.Parent.GuildModel)
local Exchange = require(script.Parent.ExchangeView)
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
	l.FontFace = T.TitleFace
	return l
end
local function empty(parent, title, hint)
	local f = K.surface(parent, "Empty", UDim2.new(1, -12, 0, 124))
	K.text(f, title, 16, 16, -32, 28, 19, T.Text, true)
	K.text(f, hint, 16, 49, -32, 56, 15, T.Muted)
	return f
end
local previewCache = {}
local function petView(id, size, silhouette, material, pedestal)
	local cacheKey = material and (id .. "|" .. material) or id
	if not previewCache[cacheKey] then
		previewCache[cacheKey] = (Renderer.BuildPreview(id, material))
	end
	local model = previewCache[cacheKey]:Clone()
	if pedestal then
		K.bakeWelds(model)
		Guild.Pedestal(model)
	end
	return K.viewport(model, size, false, silhouette, true)
end
local function bindGrid(container, minWidth, cellHeight)
	local g = K.new(
		"UIGridLayout",
		{ CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = container }
	)
	local function resize()
		local w = container.AbsoluteSize.X / HUD.Root:FindFirstChildOfClass("UIScale").Scale - 12
		local cols = math.max(1, math.floor((w + 10) / (minWidth + 10)))
		local h = type(cellHeight) == "function" and cellHeight() or cellHeight
		g.CellSize = UDim2.new(1 / cols, -(10 * (cols - 1) + 12) / cols, 0, h)
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
		{ Name = "BackToCatalogue", Position = UDim2.fromOffset(4, 0), Parent = p.frame, Visible = false }
	)
	K.bind(back, function()
		p.showDetail = false
		p.layout()
	end)
	p.onClose = function()
		p.showDetail = false
	end
	p.layout = function()
		p.content.Position = UDim2.fromOffset(16, p.compact and 64 or 108)
		p.contentSize = UDim2.new(1, -32, 1, p.compact and -80 or -124)
		p.content.Size = p.contentSize - UDim2.fromOffset(0, p.feedback.Visible and 40 or 0)
		p.title.Position = UDim2.fromOffset(62, p.compact and 8 or 15)
		p.title.Size = UDim2.new(1, p.compact and -270 or -130, 0, p.compact and 28 or 35)
		local link = p.frame:FindFirstChild("BackToShop") or p.frame:FindFirstChild("OpenCollection")
		if link then
			link.Visible = not p.compact or not p.showDetail
			link.Size = p.compact and UDim2.fromOffset(128, 44) or UDim2.fromOffset(176, 36)
			link.Position = p.compact and UDim2.new(1, -194, 0, 14) or UDim2.fromOffset(20, 64)
		end
		local wallet = p.frame:FindFirstChild("Purse")
		if wallet then
			wallet.Position = p.compact and UDim2.fromOffset(62, 37) or UDim2.new(1, -270, 0, 64)
			wallet.Size = p.compact and UDim2.new(1, -280, 0, 16) or UDim2.fromOffset(210, 36)
			wallet.TextSize = p.compact and 13 or 15
			wallet.TextXAlignment = p.compact and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
		end
		if p.compact then
			catalogue.Size = UDim2.fromScale(1, 1)
			catalogue.Visible = not p.showDetail
			detail.Position = UDim2.new()
			detail.Size = UDim2.fromScale(1, 1)
			detail.Visible = p.showDetail or false
			back.Visible = p.showDetail or false
			back.Size = UDim2.fromOffset(128, 44)
			back.Position = UDim2.new(1, -194, 0, 14)
			back.Label.Text = p.name == "Creatures" and "All pets" or "All portals"
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
	local vp = K.viewport(Portal.BuildGate(id, 3), UDim2.new(1, -10, 0, 114), false, false, true)
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
	local vp = K.viewport(Portal.BuildGate(selectedPortal, 4), UDim2.fromScale(1, 1), false, false, true)
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
		row.button:SetAttribute("Selected", selectedPortal == id)
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
	"The bestiary",
	"Select a creature to place it, remove it or review its sell value.",
	"Pet"
)
local invCatalogue, invDetail = split(inv)
local invSearch, best, invGrid
local inventoryButtons = {}
local resizeRoster
local binding = K.new("Frame", {
	Name = "BestiaryBinding",
	BackgroundColor3 = T.StoneEdge,
	Size = UDim2.new(0, 1, 1, -18),
	Position = UDim2.new(0.445, 0, 0, 6),
	Parent = inv.content,
})
for _, y in { 0.15, 0.85 } do
	K.new("Frame", {
		Name = "FolioHinge",
		BackgroundColor3 = T.Brass,
		Size = UDim2.fromOffset(7, 22),
		Position = UDim2.new(0, -3, y, -11),
		Parent = binding,
	})
end
local function inventoryCardHeight()
	if not inv.compact then
		return 86
	end
	local scale = HUD.Root:FindFirstChildOfClass("UIScale").Scale
	return math.clamp((invGrid and invGrid.AbsoluteSize.Y / scale or 142) - 6, 110, 136)
end
local inventoryLayout = inv.layout
inv.layout = function()
	inventoryLayout()
	local compact = inv.compact
	binding.Visible = not compact
	if not compact then
		invDetail.Position, invDetail.Size = UDim2.new(), UDim2.new(0.425, -4, 1, 0)
		invCatalogue.Position, invCatalogue.Size = UDim2.fromScale(0.47, 0), UDim2.fromScale(0.53, 1)
	else
		invCatalogue.Position = UDim2.new()
	end
	if resizeRoster then
		resizeRoster()
	end
	inv.content.Position = UDim2.fromOffset(16, compact and 64 or 108)
	inv.contentSize = UDim2.new(1, -32, 1, compact and -80 or -124)
	inv.content.Size = inv.contentSize - UDim2.fromOffset(0, inv.feedback.Visible and 40 or 0)
	inv.title.Size = UDim2.new(1, compact and -270 or -130, 0, 35)
	local collection = inv.frame:FindFirstChild("OpenCollection")
	if collection then
		collection.Size = compact and UDim2.fromOffset(128, 44) or UDim2.fromOffset(176, 36)
		collection.Position = compact and UDim2.new(1, -194, 0, 14) or UDim2.fromOffset(20, 64)
	end
	if invSearch then
		invSearch.Parent.Size = UDim2.new(1, -152, 0, 44)
		best.Size = UDim2.fromOffset(136, 44)
		best.Position = UDim2.new(1, -140, 0, 4)
		invGrid.Position = UDim2.fromOffset(0, 56)
		invGrid.Size = UDim2.new(1, 0, 1, -60)
	end
	for _, button in pairs(inventoryButtons) do
		local view = button:FindFirstChildWhichIsA("ViewportFrame")
		if view then
			view.Size = compact and UDim2.new(1, -8, 0, inventoryCardHeight() - 46) or UDim2.fromOffset(86, 78)
			view.Position = UDim2.fromOffset(4, 3)
		end
		local name, rarity, status =
			button:FindFirstChild("PetName"), button:FindFirstChild("PetRarity"), button:FindFirstChild("PetStatus")
		if name then
			local thumb = inventoryCardHeight() - 46
			name.Position = UDim2.fromOffset(compact and 10 or 102, compact and thumb + 2 or 8)
			name.Size = UDim2.new(1, compact and -20 or -134, 0, compact and 20 or 28)
			name.TextSize = compact and 13 or 17
			name.TextWrapped = not compact
			name.TextTruncate = compact and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
			rarity.Position = UDim2.fromOffset(compact and 10 or 102, compact and thumb + 23 or 38)
			rarity.Size = UDim2.new(1, compact and -20 or -134, 0, 18)
			rarity.TextSize = compact and 12 or 13
			status.Position = UDim2.fromOffset(102, 59)
			status.Size = UDim2.new(1, -134, 0, 18)
			status.Visible = not compact
		end
	end
	local preview = invDetail:FindFirstChild("CreaturePreview")
	if preview then
		local identityHeight = compact and math.clamp(inv.frame.Size.Y.Offset - 190, 66, 124) or 210
		local tight = compact and identityHeight < 92
		invDetail:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, compact and 6 or 8)
		local place = invDetail:FindFirstChild("PlaceCreature")
		if place then
			place.Size = UDim2.new(1, -12, 0, compact and 44 or 46)
		end
		preview.LayoutOrder = 1
		preview.Size = UDim2.new(1, -12, 0, identityHeight)
		local view = preview:FindFirstChildWhichIsA("ViewportFrame")
		view.Size = compact and UDim2.new(0.30, -4, 1, -8) or UDim2.fromScale(1, 1)
		view.Position = compact and UDim2.new(0.70, 0, 0, 4) or UDim2.new()
		for i, name in { "PetNameHeading", "PetRates", "PetExperience" } do
			local label = invDetail:FindFirstChild(name, true)
			if label then
				label.Parent = compact and preview or invDetail
				local heights = tight and { 22, 20, 18 } or { 36, 24, 20 }
				local offsets = tight and { 0, 24, 46 } or { 4, 46, 76 }
				local sizes = tight and { 18, 14, 13 } or { 20, 16, 14 }
				label.Size = compact and UDim2.new(0.68, -8, 0, heights[i])
					or UDim2.new(1, -12, 0, i == 1 and 36 or i == 2 and 28 or 24)
				label.TextSize = sizes[i]
				label.Position = compact and UDim2.fromOffset(2, offsets[i]) or UDim2.new()
			end
		end
	end
end
invSearch = K.search(invCatalogue, "Search creatures", UDim2.new(1, -12, 0, 46), UDim2.fromOffset(4, 4))
invCatalogue.AutomaticCanvasSize = Enum.AutomaticSize.None
invCatalogue.ScrollingEnabled = false
best = K.button(
	"Place best",
	T.Gold,
	nil,
	UDim2.new(1, -12, 0, 44),
	{ Name = "EquipBest", Position = UDim2.fromOffset(4, 58), Parent = invCatalogue }
)
K.bind(best, function()
	request("EquipBest", nil, "Best earners placed in your garden.")
end)
invGrid = scroll(invCatalogue, "Creatures", UDim2.new(1, 0, 1, -116), UDim2.fromOffset(0, 112))
invGrid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if inv.compact then
		task.defer(inv.layout)
	elseif resizeRoster then
		resizeRoster()
	end
end)
local selectedUid, inventoryKey, detailKey, armedUid, armToken = nil, nil, nil, nil, 0
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
	if entry then
		key ..= ":" .. tostring(entry.l or 1) .. ":" .. tostring(entry.e or 0) .. ":" .. table.concat(
			d.EquippedPets or {},
			","
		)
	end
	if detailKey == key then
		return
	end
	detailKey = key
	invDetail:ClearAllChildren()
	K.pad(4).Parent = invDetail
	list(invDetail, 8)
	if not entry then
		empty(
			invDetail,
			#d.Creatures > 0 and "No matching creature" or "Your ledger begins here",
			#d.Creatures > 0 and "Clear your search to see your creatures again."
				or "Throw a portal in the Launch Hall to start your collection."
		)
		return
	end
	local def = Data.ById[entry.c]
	local color = T.Legible(Variants.Color(entry.s, entry.v) or T.Rarity(def.rarity, Config))
	local entryIncome = Data.Income(entry.c) * Variants.Mult(entry.s, entry.v)
	local level = entry.l or 1
	local hero = K.surface(invDetail, "CreaturePreview", UDim2.new(1, -12, 0, 210), nil, T.Panel)
	hero.BackgroundTransparency = 1
	hero:FindFirstChildOfClass("UIStroke").Transparency = 1
	hero.LayoutOrder = 1
	petView(entry.c, UDim2.fromScale(1, 1), nil, entry.v, true).Parent = hero
	local petHeading = heading(invDetail, Variants.Prefix(entry.s, entry.v) .. def.name, 2)
	petHeading.Name = "PetNameHeading"
	K.label(
		def.rarity
			.. " · "
			.. Format.Rate(entryIncome * Farm.PetMult(level))
			.. " / sec"
			.. (Variants.Mult(entry.s, entry.v) > 1 and ("  (x" .. Variants.Mult(entry.s, entry.v) .. ")") or ""),
		UDim2.new(1, -12, 0, 28),
		color,
		{
			Name = "PetRates",
			TextSize = 16,
			LayoutOrder = 3,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = invDetail,
		}
	)
	local xp = level >= Farm.PetMaxLevel and "Max level"
		or (math.floor(entry.e or 0) .. " / " .. Farm.PetXpToNext(level) .. " XP")
	local progress = K.label(
		"Level " .. level .. " / " .. xp,
		UDim2.new(1, -12, 0, 24),
		T.Muted,
		{ TextSize = 14, LayoutOrder = 4, TextXAlignment = Enum.TextXAlignment.Left, Parent = invDetail }
	)
	progress.Name = "PetExperience"

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
	-- equip: up to Config.EquipLimit pets follow you and give luck/income buffs
	local equippedList = d.EquippedPets or {}
	local isEquipped = table.find(equippedList, entry.u) ~= nil
	local buff = Config.EquipBuff[def.rarity] or { luck = 0, income = 0 }
	local full = not isEquipped and #equippedList >= Config.EquipLimit
	local secondary = K.new("Frame", {
		Name = "SecondaryPetActions",
		Size = UDim2.new(1, -12, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = 6,
		Parent = invDetail,
	})
	local equip = K.button(
		away and "On expedition" or isEquipped and "Stop following" or full and "Followers full" or "Follow me",
		isEquipped and T.Raised or T.Violet,
		nil,
		UDim2.new(1, -12, 0, 46),
		{ Name = "EquipCreature", Size = UDim2.new(0.5, -4, 1, 0), Parent = secondary }
	)
	K.setEnabled(equip, not away and not full)
	K.bind(equip, function()
		if away or full then
			return
		end
		clearArm()
		if request("ToggleEquip", entry.u, isEquipped and "Pet unequipped." or "Pet equipped. It follows you now.") then
			detailKey = nil
			renderCreatureDetail()
		end
	end)
	local sellValue = math.floor(entryIncome * Config.SellMultiplier)
	local sell = K.button(
		armedUid == entry.u and "Confirm · " .. Format.Money(sellValue) or "Sell · " .. Format.Money(sellValue),
		armedUid == entry.u and T.Danger or T.Raised,
		nil,
		UDim2.new(1, -12, 0, 46),
		{
			Name = "SellCreature",
			Size = UDim2.new(0.5, -4, 1, 0),
			Position = UDim2.fromScale(0.5, 0) + UDim2.fromOffset(4, 0),
			Parent = secondary,
		}
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
		away and "Claim your pet's return at the expedition table to use it again."
			or armedUid == entry.u and ("Permanently sell " .. def.name .. "? Confirm within 4 seconds.")
			or string.format(
				"Following: +%d%% luck, +%d%% income. Selling requires confirmation.",
				math.floor(buff.luck * 100 + 0.5),
				math.floor(buff.income * 100 + 0.5)
			),
		UDim2.new(1, -12, 0, 44),
		armedUid == entry.u and T.Danger or T.Muted,
		{ TextSize = 13, LayoutOrder = 7, TextXAlignment = Enum.TextXAlignment.Left, Parent = invDetail }
	)
	K.label(
		(def.desc or "") .. " Feed crops at your courtyard Pantry to level this pet.",
		UDim2.new(1, -12, 0, 48),
		T.Muted,
		{ TextSize = 13, LayoutOrder = 8, TextXAlignment = Enum.TextXAlignment.Left, Parent = invDetail }
	)
	inv.layout()
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
		table.insert(ids, e.u .. ":" .. tostring(State.IsPlaced(e.u)) .. ":" .. tostring(e.l or 1))
	end
	local key = table.concat(ids, ",")
		.. invSearch.Text:lower()
		.. ":"
		.. tostring(d.Expeditions and d.Expeditions.active and d.Expeditions.active.petUid)
		.. ":"
		.. table.concat(d.EquippedPets or {}, ",")
	if inventoryKey ~= key then
		inventoryKey = key
		invGrid:ClearAllChildren()
		inventoryButtons = {}
		local grid = K.new(
			"UIGridLayout",
			{ CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = invGrid }
		)
		resizeRoster = function()
			if not grid.Parent then
				return
			end
			local width = invGrid.AbsoluteSize.X / HUD.Root:FindFirstChildOfClass("UIScale").Scale - 12
			local cols = inv.compact and math.max(1, math.floor((width + 8) / 148)) or 1
			grid.CellSize = UDim2.new(1 / cols, -(8 * (cols - 1) + 12) / cols, 0, inventoryCardHeight())
		end
		task.defer(resizeRoster)
		local items = table.clone(d.Creatures)
		table.sort(items, function(a, b)
			return Data.Income(a.c) * Variants.Mult(a.s, a.v) * Farm.PetMult(a.l)
				> Data.Income(b.c) * Variants.Mult(b.s, b.v) * Farm.PetMult(b.l)
		end)
		local firstMatch, selectionMatches
		for _, entry in items do
			local def = Data.ById[entry.c]
			if def and def.name:lower():find(invSearch.Text:lower(), 1, true) then
				firstMatch = firstMatch or entry.u
				selectionMatches = selectionMatches or entry.u == selectedUid
			end
		end
		if not selectionMatches then
			selectedUid = firstMatch
			clearArm()
			detailKey = nil
		end
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
				Craft.Leaf(b)
				petView(entry.c, UDim2.new(1, -8, 0, 108), nil, entry.v).Parent = b
				local nameLabel = K.text(
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
				nameLabel.Name = "PetName"
				local rarityLabel = K.text(
					b,
					def.rarity .. " · Lv " .. (entry.l or 1),
					10,
					151,
					-20,
					18,
					13,
					T.Rarity(def.rarity, Config)
				)
				rarityLabel.Name = "PetRarity"
				local statusLabel = K.text(
					b,
					(d.Expeditions and d.Expeditions.active and d.Expeditions.active.petUid == entry.u)
							and "On expedition"
						or table.find(d.EquippedPets or {}, entry.u) and "Following"
						or State.IsPlaced(entry.u) and "In courtyard"
						or "Stored",
					10,
					171,
					-20,
					18,
					13,
					State.IsPlaced(entry.u) and T.Success or T.Muted
				)
				statusLabel.Name = "PetStatus"
				b:SetAttribute("Rarity", def.rarity)
				b:SetAttribute(
					"AccessibleLabel",
					Variants.Prefix(entry.s, entry.v) .. def.name .. ", " .. def.rarity .. ", level " .. (entry.l or 1)
				)
				inventoryButtons[entry.u] = b
				K.bind(b, function()
					clearArm()
					invDetail.CanvasPosition = Vector2.zero
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
		Craft.Selected(b, uid == selectedUid)
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
	inv.layout()
end
inv.onClose = function()
	inv.showDetail = false
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
idx.layout = function()
	local compact = idx.compact
	idx.content.Position = UDim2.fromOffset(16, compact and 64 or 108)
	idx.contentSize = UDim2.new(1, -32, 1, compact and -80 or -124)
	idx.content.Size = idx.contentSize - UDim2.fromOffset(0, idx.feedback.Visible and 40 or 0)
	idx.title.Size = UDim2.new(1, compact and -270 or -130, 0, 35)
	local back = idx.frame:FindFirstChild("BackToPets")
	if back then
		back.Position = compact and UDim2.new(1, -194, 0, 14) or UDim2.fromOffset(20, 64)
		back.Size = UDim2.fromOffset(compact and 128 or 176, compact and 44 or 36)
	end
	local grid = idxGrid:FindFirstChildOfClass("UIGridLayout")
	if grid then
		local scale = HUD.Root:FindFirstChildOfClass("UIScale").Scale
		local width = idxGrid.AbsoluteSize.X / scale - 12
		local cols = compact and 1 or math.max(1, math.floor((width + 10) / 156))
		grid.CellSize = UDim2.new(1 / cols, -(10 * (cols - 1) + 12) / cols, 0, compact and 86 or 222)
	end
	for _, card in idxGrid:GetChildren() do
		if card:IsA("GuiButton") then
			local vp = card:FindFirstChildOfClass("ViewportFrame")
			vp.Size = compact and UDim2.fromOffset(72, 76) or UDim2.new(1, -8, 0, 112)
			vp.Position = compact and UDim2.fromOffset(4, 4) or UDim2.new()
			card.SpeciesName.Position = UDim2.fromOffset(compact and 88 or 10, compact and 4 or 116)
			card.SpeciesName.Size = UDim2.new(1, compact and -104 or -20, 0, compact and 24 or 36)
			card.SpeciesRarity.Position = UDim2.fromOffset(compact and 88 or 10, compact and 30 or 154)
			card.SpeciesRarity.Size = UDim2.new(1, compact and -104 or -20, 0, 20)
			card.SpeciesOdds.Position = UDim2.fromOffset(compact and 88 or 10, compact and 55 or 178)
			card.SpeciesOdds.Size = UDim2.new(1, compact and -104 or -20, 0, compact and 24 or 36)
		end
	end
end
idxGrid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(idx.layout)
end)
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
	K.new(
		"UIGridLayout",
		{ CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = idxGrid }
	)
	for i, def in ipairs(Data.ByWorld[idxFilter] or {}) do
		local known = d.Discovered[def.id]
		local b = K.button("", T.Raised, nil, nil, { Name = "Species_" .. def.id, LayoutOrder = i, Parent = idxGrid })
		petView(def.id, UDim2.new(1, -8, 0, 112), not known).Parent = b
		K.text(b, known and def.name or "Undiscovered", 10, 116, -20, 36, 15, T.Text, true).Name = "SpeciesName"
		K.text(b, def.rarity, 10, 154, -20, 20, 14, T.Rarity(def.rarity, Config)).Name = "SpeciesRarity"
		local status, p = Odds.Attainable(def.id, d.EquippedPortal, (d.MaxDistance or 45) * 1.15)
		local odds = status == "ok" and Odds.OneIn(p)
			or status == "out_of_range" and "Out of throw range"
			or "Different portal needed"
		K.text(b, odds, 10, 178, -20, 36, 13, T.Muted).Name = "SpeciesOdds"
		K.bind(b, function()
			HUD.SetPanelMessage(
				"Index",
				known and def.name .. ": " .. def.desc or "Land in the correct zone to discover this species.",
				T.Muted
			)
		end)
	end
	idx.layout()
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
	"Courtyard workshop",
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
local hub = HUD.MakePanel("Shop", "The exchange", "", "Shop")
Exchange.Mount(hub, HUD)
for _, panel in { shop, upg, base, worlds } do
	headerLink(panel, "BackToShop", "<  Shop", "Shop")
	local wallet = K.text(panel.frame, "", 0, 64, 210, 36, 15, T.Gold, true)
	wallet.Name = "Purse"
	wallet.Position = UDim2.new(1, -270, 0, 64)
	wallet.TextXAlignment = Enum.TextXAlignment.Right
	local previous = panel.refresh
	panel.refresh = function()
		wallet.Text = "Purse  " .. Format.Money(State.Data.Money)
		if previous then
			previous()
		end
	end
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
