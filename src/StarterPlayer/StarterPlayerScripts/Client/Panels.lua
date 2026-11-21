-- Panels: Portal Shop, Upgrades, Creatures (inventory), Index, Worlds and Base customization.
-- Location: StarterPlayer > StarterPlayerScripts > Client > Panels (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CreatureData = require(Shared.CreatureData)
local PortalBuilder = require(Shared.PortalBuilder)
local Format = require(Shared.Format)
local Odds = require(Shared.Odds)
local K = require(script.Parent.UIKit)
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.ClientState)
local Sounds = require(script.Parent.Sounds)
local Effects = require(script.Parent.Effects)
local Renderer = require(script.Parent.CreatureRenderer)

local Panels = {}
local GREEN, GREEN2 = Color3.fromRGB(110, 220, 90), Color3.fromRGB(40, 150, 60)
local GREY, GREY2 = Color3.fromRGB(170, 170, 185), Color3.fromRGB(110, 110, 125)
local BLUE, BLUE2 = Color3.fromRGB(90, 170, 255), Color3.fromRGB(50, 90, 220)
local GOLD, GOLD2 = Color3.fromRGB(255, 210, 70), Color3.fromRGB(235, 140, 30)

local function request(action, arg, successText)
	local ok, msg = State.Request(action, arg)
	if ok then
		Sounds.Play("Upgrade")
		if successText or msg then HUD.Notify(msg or successText, "success") end
	else
		HUD.Notify(msg or "Can't do that", "error")
	end
	return ok
end

local function grid(content, cell, pad)
	content:ClearAllChildren()
	K.pad(6).Parent = content
	K.new("UIGridLayout", { CellSize = cell, CellPadding = pad or UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = content })
end
local function vlist(content)
	content:ClearAllChildren()
	K.pad(6).Parent = content
	K.list(Enum.FillDirection.Vertical, 10).Parent = content
end

local function card(parent, order, accent)
	return K.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, Parent = parent },
		{ K.corner(16), K.stroke(3), K.grad(Color3.new(1, 1, 1), accent:Lerp(Color3.new(1, 1, 1), 0.6), 90) })
end

-- creature preview cache (cloning is far cheaper than rebuilding)
local previewCache = {}
local function creatureViewport(id, size, silhouette)
	if not previewCache[id] then previewCache[id] = (Renderer.BuildPreview(id)) end
	return K.viewport(previewCache[id]:Clone(), size, false, silhouette)
end

---------------------------------------------------------------- PORTAL SHOP
local shop = HUD.MakePanel("Portals", "🌀 Portal Shop", Color3.fromRGB(170, 110, 255), Color3.fromRGB(100, 50, 220))
local function oddsText(P)
	local parts, total = {}, 0
	for _, w in pairs(P.weights) do total += w end
	for _, r in ipairs(Config.RarityOrder) do
		local w = P.weights[r]
		if w then
			local pct = w / total * 100
			local hexc = Config.Rarities[r].color:ToHex()
			table.insert(parts, string.format("<font color='#%s'>%s %s%%</font>", hexc, r, pct >= 1 and string.format("%d", math.floor(pct + 0.5)) or string.format("%.1f", pct)))
		end
	end
	return table.concat(parts, "  ")
end
shop.refresh = function()
	local d = State.Data
	grid(shop.content, UDim2.fromOffset(240, 300))
	for i, id in ipairs(Config.PortalOrder) do
		local P = Config.Portals[id]
		local c = card(shop.content, i, P.color)
		local gate = PortalBuilder.BuildGate(id, 3)
		local vp = K.viewport(gate, UDim2.new(1, -20, 0, 130), true)
		vp.Position = UDim2.fromOffset(10, 6)
		vp.Parent = c
		K.label(P.name, UDim2.new(1, -16, 0, 30), Color3.new(1, 1, 1), { Position = UDim2.fromOffset(8, 138), Parent = c })
		local odds = K.label(oddsText(P), UDim2.new(1, -16, 0, 56), Color3.new(1, 1, 1), { Position = UDim2.fromOffset(8, 170), Parent = c, TextWrapped = true })
		odds.TextScaled = true
		local owned, equipped = d.OwnedPortals[id], d.EquippedPortal == id
		local text = equipped and "EQUIPPED" or (owned and "EQUIP" or Format.Money(P.price))
		local c1, c2 = GREEN, GREEN2
		if equipped then c1, c2 = GREY, GREY2 elseif owned then c1, c2 = BLUE, BLUE2 elseif d.Money < P.price then c1, c2 = Color3.fromRGB(255, 110, 110), Color3.fromRGB(200, 50, 70) end
		local b = K.button(text, c1, c2, UDim2.new(1, -24, 0, 48), { Position = UDim2.new(0, 12, 1, -58), Parent = c })
		b.Activated:Connect(function()
			if equipped then return end
			if owned then request("EquipPortal", id) else
				if request("BuyPortal", id, "Bought " .. P.name .. "!") then
					Effects.Flash(P.color, 0.4, 0.35)
					Effects.Coins(nil, 8)
				end
			end
		end)
	end
end

---------------------------------------------------------------- UPGRADES
local upg = HUD.MakePanel("Upgrades", "⬆ Upgrades", Color3.fromRGB(255, 190, 60), Color3.fromRGB(235, 110, 30))
local UPG_ORDER = { "ThrowPower", "BaseSlots", "Storage", "Training" }
local UPG_ICON = { ThrowPower = "⚡", BaseSlots = "🏠", Storage = "🎒", Training = "💪" }
local function upgradeEffect(kind, lvl)
	if kind == "ThrowPower" then return math.floor(Config.ThrowDistance(lvl, State.Data.Strength or 0)) .. "m throw" end
	if kind == "BaseSlots" then return (Config.StartSlots + lvl) .. " slots" end
	if kind == "Storage" then return (Config.StartStorage + lvl * Config.StoragePerLevel) .. " storage" end
	if kind == "Training" then return "+" .. math.floor(lvl * Config.TrainingBonus * 100) .. "% income" end
	return ""
end
upg.refresh = function()
	local d = State.Data
	vlist(upg.content)
	for i, kind in ipairs(UPG_ORDER) do
		local U = Config.Upgrades[kind]
		local lvl = d.Upgrades[kind]
		local idx = kind == "ThrowPower" and lvl - 1 or lvl
		local maxed = idx >= U.max
		local cost = Config.UpgradeCost(kind, idx)
		local row = card(upg.content, i, GOLD)
		row.Size = UDim2.new(1, -12, 0, 100)
		local icon = K.new("Frame", { Size = UDim2.fromOffset(76, 76), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), Parent = row },
			{ K.corner(16), K.stroke(3), K.grad(GOLD, GOLD2, 90) })
		K.label(UPG_ICON[kind], UDim2.fromScale(0.7, 0.7), nil, { Position = UDim2.fromScale(0.15, 0.15), Parent = icon })
		K.label(U.name .. "  <font color='#FFE38A'>Lv." .. idx .. "/" .. U.max .. "</font>", UDim2.new(0.55, 0, 0, 34), nil,
			{ Position = UDim2.fromOffset(104, 10), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		K.label(U.desc, UDim2.new(0.55, 0, 0, 22), Color3.fromRGB(90, 70, 120),
			{ Position = UDim2.fromOffset(104, 44), TextXAlignment = Enum.TextXAlignment.Left, Parent = row }):FindFirstChildOfClass("UIStroke"):Destroy()
		K.label(upgradeEffect(kind, lvl) .. (maxed and "" or ("  ➜  <font color='#7CFF8A'>" .. upgradeEffect(kind, lvl + 1) .. "</font>")), UDim2.new(0.55, 0, 0, 24), nil,
			{ Position = UDim2.fromOffset(104, 68), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local affordable = d.Money >= cost
		local b = K.button(maxed and "MAX" or Format.Money(cost), maxed and GREY or (affordable and GREEN or Color3.fromRGB(255, 110, 110)),
			maxed and GREY2 or (affordable and GREEN2 or Color3.fromRGB(200, 50, 70)), UDim2.fromOffset(170, 60),
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Parent = row })
		b.Activated:Connect(function()
			if maxed then return end
			if request("Upgrade", kind) then
				K.pop(row, 1.05)
				Effects.Burst((workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -10)).Position, GOLD, 25, 10, 0.6)
			end
		end)
	end
end

---------------------------------------------------------------- CREATURES (inventory)
local inv = HUD.MakePanel("Creatures", "🐾 My Creatures", Color3.fromRGB(110, 200, 255), Color3.fromRGB(50, 120, 230))
local selectedUid = nil
local invInfo = K.label("", UDim2.new(0.5, 0, 1, 0), Color3.fromRGB(70, 50, 110), { TextXAlignment = Enum.TextXAlignment.Left, Parent = inv.subbar })
invInfo:FindFirstChildOfClass("UIStroke"):Destroy()
local bestBtn = K.button("⭐ Equip Best", GOLD, GOLD2, UDim2.fromOffset(170, 44), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Parent = inv.subbar })
bestBtn.Activated:Connect(function() request("EquipBest", nil, "Placed your best creatures!") end)

local actionBar = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 70), Size = UDim2.fromOffset(560, 64),
	BackgroundColor3 = K.Panel, Visible = false, Parent = inv.frame }, { K.corner(18), K.stroke(4) })
local actionName = K.label("", UDim2.new(0.4, 0, 1, -16), Color3.new(1, 1, 1), { Position = UDim2.fromOffset(12, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = actionBar })
local placeBtn = K.button("Place", GREEN, GREEN2, UDim2.fromOffset(150, 48), { Position = UDim2.new(0.42, 0, 0, 8), Parent = actionBar })
local sellBtn = K.button("Sell", Color3.fromRGB(255, 110, 110), Color3.fromRGB(200, 50, 70), UDim2.fromOffset(150, 48), { Position = UDim2.new(0.42, 160, 0, 8), Parent = actionBar })
local sellArmed = false
placeBtn.Activated:Connect(function()
	if not selectedUid then return end
	if State.IsPlaced(selectedUid) then request("Unplace", selectedUid) else request("Place", selectedUid) end
end)
sellBtn.Activated:Connect(function()
	if not selectedUid then return end
	if not sellArmed then
		sellArmed = true
		K.setButton(sellBtn, "Confirm?")
		task.delay(2.5, function() sellArmed = false; K.setButton(sellBtn, "Sell") end)
		return
	end
	sellArmed = false
	K.setButton(sellBtn, "Sell")
	if request("Sell", selectedUid) then
		selectedUid = nil
		actionBar.Visible = false
		Effects.Coins(nil, 10)
	end
end)

local function selectCreature(entry)
	selectedUid = entry.u
	local def = CreatureData.ById[entry.c]
	actionBar.Visible = true
	actionName.Text = def.name
	actionName.TextColor3 = Config.Rarities[def.rarity].color
	K.setButton(placeBtn, State.IsPlaced(entry.u) and "Remove" or "Place", State.IsPlaced(entry.u) and BLUE or GREEN, State.IsPlaced(entry.u) and BLUE2 or GREEN2)
	K.pop(actionBar, 1.06)
end

inv.refresh = function()
	local d = State.Data
	invInfo.Text = string.format("In base: %d/%d   •   Storage: %d/%d   •   +%s/s", #d.Placed, d.SlotsOpen, #d.Creatures - #d.Placed, d.StorageCap, Format.Money(d.Income))
	grid(inv.content, UDim2.fromOffset(140, 170))
	local list = table.clone(d.Creatures)
	table.sort(list, function(a, b)
		local pa, pb = State.IsPlaced(a.u), State.IsPlaced(b.u)
		if pa ~= pb then return pa end
		return CreatureData.Income(a.c) > CreatureData.Income(b.c)
	end)
	if #list == 0 then
		K.label("No creatures yet! Throw a portal to find one.", UDim2.fromOffset(500, 40), Color3.fromRGB(90, 70, 120), { Parent = inv.content })
	end
	for i, entry in ipairs(list) do
		local def = CreatureData.ById[entry.c]
		if def then
			local rc = Config.Rarities[def.rarity]
			local c = K.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, Parent = inv.content },
				{ K.corner(16), K.stroke(selectedUid == entry.u and 5 or 3, selectedUid == entry.u and Color3.fromRGB(255, 220, 60) or K.Dark),
					K.grad(Color3.new(1, 1, 1), rc.color:Lerp(Color3.new(1, 1, 1), 0.35), 90) })
			local vp = creatureViewport(entry.c, UDim2.new(1, -10, 0, 100))
			vp.Position = UDim2.fromOffset(5, 4)
			vp.Parent = c
			K.label(def.name, UDim2.new(1, -8, 0, 24), Color3.new(1, 1, 1), { Position = UDim2.fromOffset(4, 104), Parent = c })
			K.label(Format.Money(CreatureData.Income(entry.c)) .. "/s", UDim2.new(1, -8, 0, 20), Color3.fromRGB(150, 255, 150), { Position = UDim2.fromOffset(4, 128), Parent = c })
			K.label(def.rarity, UDim2.new(1, -8, 0, 16), rc.color, { Position = UDim2.fromOffset(4, 149), Parent = c })
			if State.IsPlaced(entry.u) then
				local badge = K.new("Frame", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(-6, -6), BackgroundColor3 = GREEN, Parent = c, ZIndex = 3 }, { K.round(), K.stroke(2) })
				K.label("✓", UDim2.fromScale(0.8, 0.8), nil, { Position = UDim2.fromScale(0.1, 0.1), Parent = badge, ZIndex = 4 })
			end
			c.Activated:Connect(function()
				Sounds.Play("Click")
				selectCreature(entry)
				inv.refresh()
			end)
		end
	end
	if selectedUid then
		local still = false
		for _, e in ipairs(d.Creatures) do if e.u == selectedUid then still = true; selectCreature(e) end end
		if not still then selectedUid = nil; actionBar.Visible = false end
	end
end

---------------------------------------------------------------- INDEX
local idx = HUD.MakePanel("Index", "📖 Creature Index", Color3.fromRGB(255, 130, 190), Color3.fromRGB(210, 60, 140))
local idxFilter = "Forest"
local tabs = K.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = idx.subbar }, { K.list(Enum.FillDirection.Horizontal, 6) })
local idxCount = nil
local filters = table.clone(Config.WorldOrder)
table.insert(filters, "Any")
for i, w in ipairs(filters) do
	local name = w == "Any" and "Special" or Config.Worlds[w].name:gsub(" World", ""):gsub("Green ", ""):gsub(" Kingdom", ""):gsub(" Dimension", ""):gsub(" Galaxy", ""):gsub(" Caves", "")
	local b = K.button(name, Color3.fromRGB(255, 160, 210), Color3.fromRGB(220, 90, 160), UDim2.fromOffset(82, 40), { LayoutOrder = i, Parent = tabs })
	b.Activated:Connect(function() idxFilter = w; idx.refresh() end)
end
idx.refresh = function()
	local d = State.Data
	grid(idx.content, UDim2.fromOffset(140, 180))
	local total, found = #CreatureData.List, 0
	for _ in pairs(d.Discovered) do found += 1 end
	K.label(string.format("Discovered %d / %d\n\nOdds use your equipped portal", found, total), UDim2.new(1, -20, 0, 34), Color3.fromRGB(90, 60, 130),
		{ LayoutOrder = 0, Parent = idx.content, Size = UDim2.fromOffset(140, 180), TextWrapped = true })
	for i, def in ipairs(CreatureData.ByWorld[idxFilter] or {}) do
		local known = d.Discovered[def.id]
		local rc = Config.Rarities[def.rarity]
		local c = card(idx.content, i, known and rc.color or GREY)
		local vp = creatureViewport(def.id, UDim2.new(1, -10, 0, 104), not known)
		vp.Position = UDim2.fromOffset(5, 4)
		vp.Parent = c
		K.label(known and def.name or "???", UDim2.new(1, -8, 0, 24), Color3.new(1, 1, 1), { Position = UDim2.fromOffset(4, 108), Parent = c })
		K.label(def.rarity, UDim2.new(1, -8, 0, 20), rc.color, { Position = UDim2.fromOffset(4, 132), Parent = c })
		-- "1 in X" with your equipped portal and your best throw
		local p = Odds.ChanceFor(def.id, d.EquippedPortal, (d.MaxDistance or 45) * 1.15)
		K.label(p > 0 and Odds.OneIn(p) or "Better portal needed", UDim2.new(1, -8, 0, 20), Color3.fromRGB(255, 240, 160), { Position = UDim2.fromOffset(4, 154), Parent = c })
		if known then
			c.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					HUD.Notify(def.name .. ": " .. def.desc, def.rarity)
				end
			end)
		end
	end
end

---------------------------------------------------------------- WORLDS
local worlds = HUD.MakePanel("Worlds", "📏 Zones", Color3.fromRGB(100, 220, 200), Color3.fromRGB(30, 150, 160))
worlds.refresh = function()
	local d = State.Data
	vlist(worlds.content)
	local maxD = (d.MaxDistance or 45) * 1.15
	local tip = card(worlds.content, 0, GOLD)
	tip.Size = UDim2.new(1, -12, 0, 60)
	K.label(string.format("Your best throw reaches <font color='#FFE38A'>%dm</font>. Train and upgrade Throw Power to reach new zones!", math.floor(maxD)),
		UDim2.new(1, -24, 1, -12), nil, { Position = UDim2.fromOffset(12, 6), Parent = tip })
	for i, id in ipairs(Config.WorldOrder) do
		local W = Config.Worlds[id]
		local b = Config.ZoneBounds[id]
		local reach = maxD >= b[1]
		local row = card(worlds.content, i, W.groundColor)
		row.Size = UDim2.new(1, -12, 0, 92)
		local sw = K.new("Frame", { Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(12, 11), BackgroundColor3 = Color3.new(1, 1, 1), Parent = row },
			{ K.corner(16), K.stroke(3), K.grad(W.groundColor:Lerp(Color3.new(1, 1, 1), 0.3), W.atmo, 90) })
		K.label(reach and tostring(i) or "🔒", UDim2.fromScale(0.6, 0.6), nil, { Position = UDim2.fromScale(0.2, 0.2), Parent = sw })
		K.label(W.name .. "  <font color='#FFE38A'>" .. b[1] .. "m – " .. b[2] .. "m</font>", UDim2.new(0.62, 0, 0, 36), nil,
			{ Position = UDim2.fromOffset(96, 10), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local found, total = 0, 0
		for _, c in ipairs(CreatureData.ByWorld[id] or {}) do
			total += 1
			if d.Discovered[c.id] then found += 1 end
		end
		K.label(string.format("%s  •  Creatures found: %d/%d  •  x%s income", reach and "In range!" or ("Need a " .. b[1] .. "m throw"), found, total, Format.Short(W.incomeMult)),
			UDim2.new(0.8, 0, 0, 26), reach and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 200, 200),
			{ Position = UDim2.fromOffset(96, 50), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	end
end

---------------------------------------------------------------- ADMIN
local admin = HUD.MakePanel("Admin", "🛠 Admin Panel", Color3.fromRGB(255, 90, 90), Color3.fromRGB(160, 30, 60))
local function adminCmd(cmd, value)
	local json = game:GetService("HttpService"):JSONEncode({ cmd = cmd, value = value })
	request("Admin", json)
end
admin.refresh = function()
	vlist(admin.content)
	local amountRow = card(admin.content, 1, Color3.fromRGB(255, 120, 120))
	amountRow.Size = UDim2.new(1, -12, 0, 70)
	K.label("Amount:", UDim2.fromOffset(120, 40), nil, { Position = UDim2.fromOffset(14, 15), Parent = amountRow })
	local box = K.new("TextBox", { Text = "1000000", PlaceholderText = "number / creature id", Font = K.Font, TextScaled = true, ClearTextOnFocus = false,
		Size = UDim2.new(1, -160, 0, 46), Position = UDim2.fromOffset(140, 12), BackgroundColor3 = Color3.new(1, 1, 1), TextColor3 = K.Dark, Parent = amountRow },
		{ K.corner(12), K.stroke(3) })
	local function val() return tonumber(box.Text) or box.Text end

	local btns = K.new("Frame", { Size = UDim2.new(1, -12, 0, 240), BackgroundTransparency = 1, LayoutOrder = 2, Parent = admin.content },
		{ K.new("UIGridLayout", { CellSize = UDim2.fromOffset(180, 52), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
	local function add(text, c1, c2, fn)
		local b = K.button(text, c1, c2, nil, { Parent = btns })
		b.Activated:Connect(fn)
	end
	add("+ Money", GREEN, GREEN2, function() adminCmd("money", val()) end)
	add("- Money", Color3.fromRGB(255, 110, 110), Color3.fromRGB(200, 50, 70), function() adminCmd("money", -(tonumber(box.Text) or 0)) end)
	add("+ Strength", Color3.fromRGB(255, 120, 90), Color3.fromRGB(210, 50, 60), function() adminCmd("strength", val()) end)
	add("Set Throw Lv", GOLD, GOLD2, function() adminCmd("throwlevel", val()) end)
	add("Max Upgrades", GOLD, GOLD2, function() adminCmd("maxupgrades") end)
	add("All Portals", Color3.fromRGB(180, 120, 255), Color3.fromRGB(110, 60, 220), function() adminCmd("allportals") end)
	add("Complete Index", Color3.fromRGB(255, 140, 200), Color3.fromRGB(210, 60, 140), function() adminCmd("discoverall") end)
	add("WalkSpeed", BLUE, BLUE2, function() adminCmd("speed", val()) end)
	add("Give Creature (id)", BLUE, BLUE2, function() adminCmd("give", box.Text) end)
	add("Force Next Throw (id)", Color3.fromRGB(255, 160, 60), Color3.fromRGB(210, 90, 30), function() adminCmd("forcenext", box.Text) end)
	local resetArmed = false
	add("RESET MY DATA", Color3.fromRGB(90, 90, 100), Color3.fromRGB(40, 40, 50), function()
		if not resetArmed then
			resetArmed = true
			HUD.Notify("Click RESET again within 3s to wipe your data", "error")
			task.delay(3, function() resetArmed = false end)
			return
		end
		resetArmed = false
		adminCmd("reset")
	end)

	K.label("Teleport to zone", UDim2.new(1, -12, 0, 30), Color3.fromRGB(160, 40, 70), { LayoutOrder = 3, Parent = admin.content })
	local tp = K.new("Frame", { Size = UDim2.new(1, -12, 0, 130), BackgroundTransparency = 1, LayoutOrder = 4, Parent = admin.content },
		{ K.new("UIGridLayout", { CellSize = UDim2.fromOffset(170, 50), CellPadding = UDim2.fromOffset(10, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
	local zoneIds = { "Start" }
	for _, id in ipairs(Config.WorldOrder) do table.insert(zoneIds, id) end
	for _, id in ipairs(zoneIds) do
		local W = Config.Worlds[id]
		local c = W and W.atmo or GREEN
		local b = K.button(W and W.name or "Start", c, c:Lerp(Color3.new(0, 0, 0), 0.35), nil, { Parent = tp })
		b.Activated:Connect(function() adminCmd("zone", id); HUD.Close() end)
	end

	K.label("Give creature (click one)", UDim2.new(1, -12, 0, 30), Color3.fromRGB(160, 40, 70), { LayoutOrder = 5, Parent = admin.content })
	local list = K.new("Frame", { Size = UDim2.new(1, -12, 0, math.ceil(#CreatureData.List / 4) * 46), BackgroundTransparency = 1, LayoutOrder = 6, Parent = admin.content },
		{ K.new("UIGridLayout", { CellSize = UDim2.fromOffset(180, 38), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
	for _, def in ipairs(CreatureData.List) do
		local rc = Config.Rarities[def.rarity].color
		local b = K.button(def.name, rc, rc:Lerp(Color3.new(0, 0, 0), 0.35), nil, { Parent = list })
		b.Activated:Connect(function() adminCmd("give", def.id) end)
	end
end

---------------------------------------------------------------- BASE CUSTOMIZATION
local basePanel = HUD.MakePanel("Base", "🏡 Decorate Base", Color3.fromRGB(150, 220, 110), Color3.fromRGB(70, 160, 70))
basePanel.refresh = function()
	local d = State.Data
	vlist(basePanel.content)
	K.label("Decorations", UDim2.new(1, -12, 0, 34), Color3.fromRGB(70, 130, 60), { LayoutOrder = 0, Parent = basePanel.content })
	for i, id in ipairs(Config.DecorOrder) do
		local D = Config.Decor[id]
		local row = card(basePanel.content, i, GREEN)
		row.Size = UDim2.new(1, -12, 0, 64)
		K.label(D.name, UDim2.new(0.6, 0, 0, 40), nil, { Position = UDim2.fromOffset(16, 12), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local owned = d.Decor[id]
		local b = K.button(owned and "OWNED" or Format.Money(D.price), owned and GREY or GREEN, owned and GREY2 or GREEN2, UDim2.fromOffset(160, 48),
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Parent = row })
		b.Activated:Connect(function() if not owned then request("BuyDecor", id, D.name .. " added to your base!") end end)
	end
	K.label("Floor Themes", UDim2.new(1, -12, 0, 34), Color3.fromRGB(70, 130, 60), { LayoutOrder = 50, Parent = basePanel.content })
	for i, t in ipairs(Config.FloorThemes) do
		local row = card(basePanel.content, 50 + i, t.color)
		row.Size = UDim2.new(1, -12, 0, 64)
		K.label(t.name, UDim2.new(0.6, 0, 0, 40), nil, { Position = UDim2.fromOffset(16, 12), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local active, owned = d.FloorTheme == t.id, d.OwnedFloors[t.id]
		local b = K.button(active and "ACTIVE" or (owned and "USE" or Format.Money(t.price)), active and GREY or (owned and BLUE or GREEN),
			active and GREY2 or (owned and BLUE2 or GREEN2), UDim2.fromOffset(160, 48), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Parent = row })
		b.Activated:Connect(function() if not active then request("Floor", t.id) end end)
	end
end

---------------------------------------------------------------- side buttons
function Panels.Init()
	HUD.AddSideButton("Shop", "🌀", Color3.fromRGB(180, 120, 255), Color3.fromRGB(110, 60, 220), function() HUD.Open("Portals") end)
	HUD.AddSideButton("Upgrade", "⬆", Color3.fromRGB(255, 200, 70), Color3.fromRGB(235, 120, 30), function() HUD.Open("Upgrades") end)
	HUD.AddSideButton("Pets", "🐾", Color3.fromRGB(110, 200, 255), Color3.fromRGB(50, 120, 230), function() HUD.Open("Creatures") end)
	HUD.AddSideButton("Index", "📖", Color3.fromRGB(255, 140, 200), Color3.fromRGB(210, 60, 140), function() HUD.Open("Index") end)
	HUD.AddSideButton("Zones", "📏", Color3.fromRGB(100, 220, 200), Color3.fromRGB(30, 150, 160), function() HUD.Open("Worlds") end)
	HUD.AddSideButton("Base", "🏡", Color3.fromRGB(150, 220, 110), Color3.fromRGB(70, 160, 70), function() HUD.Open("Base") end)
	HUD.AddSideButton("Home", "🏠", Color3.fromRGB(255, 150, 110), Color3.fromRGB(220, 80, 60), function()
		if request("Teleport", "Home") then Effects.Flash(Color3.new(1, 1, 1), 0.4, 0.4) end
	end)
	-- admin button only for admins (server decides via the IsAdmin attribute)
	local player = game:GetService("Players").LocalPlayer
	local function checkAdmin()
		if player:GetAttribute("IsAdmin") and not HUD.SideButtons["Admin"] then
			HUD.AddSideButton("Admin", "🛠", Color3.fromRGB(255, 90, 90), Color3.fromRGB(160, 30, 60), function() HUD.Open("Admin") end)
		end
	end
	player:GetAttributeChangedSignal("IsAdmin"):Connect(checkAdmin)
	checkAdmin()
end

return Panels
