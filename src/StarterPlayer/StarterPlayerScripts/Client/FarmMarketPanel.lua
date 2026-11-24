-- Two physical entrances, one small shop. No additional HUD destination.
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local Format = require(RS.Shared.Format)
local K = require(script.Parent.UIKit)
local HUD = require(script.Parent.HUD)
local State = require(script.Parent.ClientState)
local T = K.Theme
local Panel = {}
local player = Players.LocalPlayer
local page, status, footer, ready, busy
local side, supplies = "Buy", false
local prompts, rows = {}, {}
local pending, visit = nil, 0
local render

local function duration(seconds)
	seconds = math.max(0, math.ceil(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	local remainder = seconds % 60
	local parts = {}
	if hours > 0 then
		table.insert(parts, hours .. "h")
	end
	if minutes > 0 then
		table.insert(parts, minutes .. "m")
	end
	if remainder > 0 or #parts == 0 then
		table.insert(parts, remainder .. "s")
	end
	return table.concat(parts, " ")
end

local function trade(request)
	if busy or not State.Loaded then
		return
	end
	local ticket = visit
	busy, pending = true, request
	render()
	local ok, message = State.Request("FarmMarket", Http:JSONEncode(request))
	busy, pending = false, nil
	if ticket == visit and HUD.IsOpen("FarmMarket") then
		HUD.SetPanelMessage(
			"FarmMarket",
			message or (ok and "Updated." or "Please try again."),
			ok and T.Success or T.Danger
		)
		render()
	end
end

-- Keyed rows survive wallet, selection and stock updates. Focus/scroll stay native.
local function row(key, height, order)
	local r = rows[key]
	if not r or not r.frame.Parent then
		local frame = K.new("Frame", { Name = key, BackgroundTransparency = 1, Parent = page.content })
		r = { frame = frame }
		r.title = K.text(frame, "", 0, 0, -8, 28, 19, T.Text, true)
		r.detail = K.text(frame, "", 0, 34, -8, 36, 14, T.Muted)
		rows[key] = r
	end
	r.used = true
	r.frame.Size, r.frame.LayoutOrder = UDim2.new(1, -8, 0, height), order
	return r
end

local function setButton(button, text, enabled, color)
	K.setButton(button, text, color or T.Gold)
	K.setEnabled(button, enabled)
end

render = function()
	if not ready then
		return
	end
	for _, r in rows do
		r.used = false
	end
	local view = State.Data.FarmMarket
	page.title.Text = side == "Sell" and "Crop buyer" or (supplies and "Farm supplies" or "Seed merchant")
	local available = State.Loaded and not busy
	if not view then
		row("Loading", 50, 1).title.Text = "Loading your garden..."
	elseif side == "Sell" then
		if #view.produce == 0 then
			local r = row("EmptyHarvest", 90, 1)
			r.title.Text = "Your crop bag is empty"
			r.detail.Text = "Harvest a ripe crop in your garden, then bring it here."
		end
		for i, item in view.produce do
			local r = row("Produce_" .. (item.key or item.name), 74, i)
			r.title.Text = item.name
			r.detail.Text = item.count .. " crops  ·  " .. Format.Money(item.value)
		end
	elseif supplies then
		for i, item in view.upgrades do
			local r = row("Supply_" .. item.id, 104, i)
			r.data, r.title.Text = item, item.name
			local locked = item.level and view.level < item.level
			r.detail.Text = item.owned and "Already part of your garden"
				or (locked and ("Farmer Lv " .. item.level) or "")
			r.detail.Position, r.detail.Size = UDim2.fromOffset(0, 30), UDim2.new(1, -8, 0, 22)
			if not r.buy then
				r.buy = K.button(
					"",
					T.Gold,
					nil,
					UDim2.new(1, -8, 0, 44),
					{ Position = UDim2.fromOffset(0, 56), Parent = r.frame }
				)
				K.bind(r.buy, function()
					trade({ op = "Upgrade", supply = r.data.id })
				end)
			end
			local text = item.owned and "Owned" or (locked and "Locked" or ("Buy · " .. Format.Money(item.price or 0)))
			if busy and pending.op == "Upgrade" and pending.supply == item.id then
				text = "Buying..."
			end
			setButton(
				r.buy,
				text,
				available and not item.owned and not locked and State.Data.Money >= (item.price or math.huge)
			)
		end
	else
		local nextLockedShown = false
		for i, seed in view.seeds do
			if not seed.unlocked and nextLockedShown then
				continue
			end
			if not seed.unlocked then
				nextLockedShown = true
			end
			local r = row("Seed_" .. seed.id, seed.unlocked and 142 or 82, i)
			r.data, r.title.Text = seed, seed.name
			r.title.Size = UDim2.new(1, seed.unlocked and -112 or -8, 0, seed.unlocked and 44 or 28)
			r.title.TextColor3 = seed.unlocked and T.Text or T.Muted
			r.detail.Position = UDim2.fromOffset(0, seed.unlocked and 50 or 34)
			r.detail.Size = UDim2.new(1, -8, 0, seed.unlocked and 28 or 40)
			r.detail.Text = seed.unlocked and ("Owned " .. seed.stock .. "  ·  Grows in " .. duration(seed.grow))
				or ("Farmer Lv " .. seed.level .. "  ·  Grows in " .. duration(seed.grow))
			if not r.use then
				r.use = K.button(
					"",
					T.Raised,
					nil,
					UDim2.fromOffset(100, 44),
					{ Position = UDim2.new(1, -108, 0, 0), Parent = r.frame }
				)
				K.bind(r.use, function()
					trade({ op = "Select", crop = r.data.id })
				end)
				r.purchases = {}
				for _, quantity in { 1, 5 } do
					local button = K.button(
						"",
						T.Gold,
						nil,
						UDim2.new(0.5, -8, 0, 44),
						{ Position = UDim2.new(quantity == 1 and 0 or 0.5, 0, 0, 86), Parent = r.frame }
					)
					r.purchases[quantity] = button
					K.bind(button, function()
						trade({ op = "Buy", crop = r.data.id, quantity = quantity })
					end)
				end
			end
			r.use.Visible = seed.unlocked
			r.use:SetAttribute("Selected", seed.selected and seed.stock > 0)
			setButton(
				r.use,
				seed.stock == 0 and "No seeds" or (seed.selected and "Selected" or "Use seed"),
				available and seed.unlocked and seed.stock > 0 and not seed.selected,
				T.Raised
			)
			for quantity, button in r.purchases do
				local price = seed.price * quantity
				button.Visible = seed.unlocked
				local text = "Buy " .. quantity .. " · " .. Format.Money(price)
				if busy and pending.op == "Buy" and pending.crop == seed.id and pending.quantity == quantity then
					text = "Buying..."
				end
				setButton(button, text, available and seed.unlocked and State.Data.Money >= price)
			end
		end
	end
	for key, r in rows do
		if not r.used then
			r.frame:Destroy()
			rows[key] = nil
		end
	end
	local text = side == "Sell"
			and (busy and "Selling..." or ("Sell all · " .. Format.Money(view and view.total or 0)))
		or (supplies and "Back to seeds" or "Farm supplies")
	setButton(footer, text, available and view ~= nil and (side ~= "Sell" or view.count > 0))
end

function Panel.Open(kind)
	if not ready or busy then
		return
	end
	visit += 1
	local ticket = visit
	side, supplies = kind == "Sell" and "Sell" or "Buy", false
	if HUD.IsOpen("FarmMarket") then
		render()
	else
		HUD.Open("FarmMarket")
	end
	page.content.CanvasPosition = Vector2.zero
	page.inlineMessage("")
	task.spawn(function()
		local ok, message = State.Request("Sync")
		if not ok and ticket == visit and HUD.IsOpen("FarmMarket") then
			HUD.SetPanelMessage("FarmMarket", message or "Could not load garden.", T.Danger)
		end
	end)
end

function Panel.Init()
	if ready then
		return
	end
	page = HUD.MakePanel("FarmMarket", "Seed merchant", "", "Shop")
	page.subtitle.Visible = false
	K.list(nil, 12, Enum.HorizontalAlignment.Left).Parent = page.content
	status = K.text(page.frame, "", 20, 0, -40, 36, 14, T.Muted)
	footer = K.button(
		"Farm supplies",
		T.Gold,
		nil,
		UDim2.new(1, -40, 0, 44),
		{ Name = "MarketAction", Position = UDim2.new(0, 20, 1, -64), Parent = page.frame }
	)
	K.bind(footer, function()
		if side == "Sell" then
			trade({ op = "Sell" })
		else
			supplies = not supplies
			page.content.CanvasPosition = Vector2.zero
			render()
		end
	end)
	page.inlineMessage = function(message, color)
		status.Text = message ~= "" and message
			or (
				side == "Sell" and "Harvest at your garden, then sell your crops here."
				or "Buy seeds, then plant them at your garden."
			)
		status.TextColor3 = color or T.Muted
	end
	page.layout = function()
		local top = page.compact and 64 or 82
		local tight = page.frame.Size.Y.Offset < 300
		page.content.Position, page.content.Size =
			UDim2.fromOffset(20, top), UDim2.new(1, -40, 1, -top - (tight and 104 or 112))
		status.Position = UDim2.new(0, 20, 1, tight and -100 or -106)
		status.Size = UDim2.new(1, -40, 0, tight and 32 or 36)
		status.TextSize = tight and 13 or 14
	end
	page.refresh = render
	page.onClose = function()
		visit += 1
	end
	ready = true
	task.spawn(function()
		while page.frame.Parent do
			local map = workspace:FindFirstChild("Map")
			local start = map and map:FindFirstChild("Start")
			local market = start and start:FindFirstChild("FarmMarket")
			for _, kind in { "Buy", "Sell" } do
				local existing = prompts[kind]
				if existing and existing.Parent and market and existing:IsDescendantOf(market) then
					continue
				end
				local stall = market and market:FindFirstChild(kind .. "Stall")
				local anchor = stall and stall:FindFirstChild(kind .. "Anchor")
				if anchor then
					if existing then
						existing:Destroy()
					end
					local p = K.new("ProximityPrompt", {
						Name = kind .. "FarmMarket",
						ActionText = kind == "Buy" and "Buy seeds" or "Sell crops",
						ObjectText = "Great Hall market",
						MaxActivationDistance = 9,
						RequiresLineOfSight = false,
						HoldDuration = 0,
						KeyboardKeyCode = Enum.KeyCode.E,
						GamepadKeyCode = Enum.KeyCode.ButtonX,
						Parent = anchor,
					})
					p.Triggered:Connect(function(who)
						if who == player then
							Panel.Open(kind)
						end
					end)
					prompts[kind] = p
				end
			end
			task.wait(1)
		end
	end)
	HUD.Rescale()
end

return Panel
