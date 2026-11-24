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
local render

local function duration(seconds)
	if seconds < 60 then
		return math.ceil(seconds) .. "s"
	end
	if seconds < 3600 then
		return math.ceil(seconds / 60) .. " min"
	end
	return string.format("%.0f hr", seconds / 3600)
end

local function trade(request)
	if busy or not State.Loaded then
		return
	end
	busy = true
	render()
	local ok, message = State.Request("FarmMarket", Http:JSONEncode(request))
	busy = false
	HUD.SetPanelMessage(
		"FarmMarket",
		message or (ok and "Updated." or "Please try again."),
		ok and T.Success or T.Danger
	)
	render()
end

local function row(height, order)
	local r = K.new("Frame", {
		Name = "MarketRow",
		Size = UDim2.new(1, -8, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = page.content,
	})
	table.insert(rows, r)
	return r
end

render = function()
	if not ready then
		return
	end
	local canvas = page.content.CanvasPosition
	for _, r in rows do
		r:Destroy()
	end
	table.clear(rows)
	local view = State.Data.FarmMarket
	page.title.Text = side == "Sell" and "Crop buyer" or (supplies and "Farm supplies" or "Seed merchant")
	if not view then
		local r = row(50, 1)
		K.text(r, "Loading your garden...", 0, 0, -8, 40, 16, T.Muted)
	elseif side == "Sell" then
		if #view.produce == 0 then
			local r = row(90, 1)
			K.text(r, "Your crop bag is empty", 0, 0, -8, 30, 21, T.Text, true)
			K.text(r, "Harvest a ripe crop in your garden, then bring it here.", 0, 34, -8, 48, 16, T.Muted)
		end
		for i, item in view.produce do
			local r = row(70, i)
			K.text(r, item.name, 0, 0, -8, 28, 18, T.Text, true)
			K.text(r, item.count .. " crops  ·  " .. Format.Money(item.value), 0, 32, -8, 24, 15, T.Muted)
		end
	elseif supplies then
		for i, item in view.upgrades do
			local r = row(102, i)
			K.text(r, item.name, 0, 0, -8, 28, 19, T.Text, true)
			local locked = item.level and view.level < item.level
			local text = item.owned and "Owned"
				or (locked and ("Farmer Lv " .. item.level) or ("Buy · " .. Format.Money(item.price or 0)))
			local b =
				K.button(text, T.Gold, nil, UDim2.new(1, -8, 0, 42), { Position = UDim2.fromOffset(0, 40), Parent = r })
			K.setEnabled(
				b,
				not busy and not item.owned and not locked and State.Data.Money >= (item.price or math.huge)
			)
			K.bind(b, function()
				trade({ op = "Upgrade", supply = item.id })
			end)
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
			local r = row(126, i)
			K.text(r, seed.name, 0, 0, -108, 28, 19, T.Text, true)
			K.text(r, "Grows in " .. duration(seed.grow) .. "  ·  Owned " .. seed.stock, 0, 34, -8, 26, 14, T.Muted)
			local use = K.button(
				seed.selected and "Selected" or "Use seed",
				T.Raised,
				nil,
				UDim2.fromOffset(96, 32),
				{ Position = UDim2.new(1, -104, 0, 0), Parent = r }
			)
			use:SetAttribute("Selected", seed.selected)
			K.setEnabled(use, not busy and seed.stock > 0 and not seed.selected)
			K.bind(use, function()
				trade({ op = "Select", crop = seed.id })
			end)
			for _, quantity in { 1, 5 } do
				local price = seed.price * quantity
				local b = K.button(
					seed.unlocked and ("Buy " .. quantity .. " · " .. Format.Money(price))
						or ("Farmer Lv " .. seed.level),
					T.Gold,
					nil,
					UDim2.new(0.5, -8, 0, 42),
					{ Position = UDim2.new(quantity == 1 and 0 or 0.5, 0, 0, 70), Parent = r }
				)
				K.setEnabled(b, not busy and seed.unlocked and State.Data.Money >= price)
				K.bind(b, function()
					trade({ op = "Buy", crop = seed.id, quantity = quantity })
				end)
			end
		end
	end
	footer.Label.Text = side == "Sell"
			and (busy and "Selling..." or ("Sell all · " .. Format.Money(view and view.total or 0)))
		or (supplies and "Back to seeds" or "Farm supplies")
	K.setEnabled(footer, not busy and view ~= nil and (side ~= "Sell" or view.count > 0))
	page.content.CanvasPosition = canvas
end

function Panel.Open(kind)
	if not ready or busy then
		return
	end
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
		if not ok and HUD.IsOpen("FarmMarket") then
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
	page.refresh = function(full)
		if full ~= false then
			render()
		end
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
