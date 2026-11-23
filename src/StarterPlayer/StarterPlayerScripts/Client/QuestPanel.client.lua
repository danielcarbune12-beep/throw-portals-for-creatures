-- QuestPanel: compact parchment card on the right edge with today's quests, rebirth and boosts.
-- Location: StarterPlayer > StarterPlayerScripts > Client > QuestPanel (LocalScript)
--
-- Reads the server's Progress view from ClientState (Daily, Rebirths, RebirthCost, FriendsHere,
-- PotionUntil, Passes). The edge arrow hides/restores the tracker. Boost buttons only appear for game passes /
-- products whose ids are set in Config.Progression (0 = not created, nothing is sold).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.ClientState)
local T = require(script.Parent.UITheme)

local player = Players.LocalPlayer
local C = Config.Progression

local gui = Instance.new("ScreenGui")
gui.Name = "QuestPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 8
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(1, 0)
card.Position = UDim2.new(1, -12, 0, 120)
card.Size = UDim2.fromOffset(232, 40)
card.AutomaticSize = Enum.AutomaticSize.Y
card.BackgroundColor3 = T.Raised
card.BackgroundTransparency = 0.06
card.BorderSizePixel = 0
card.Parent = gui
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
local rim = Instance.new("UIStroke")
rim.Color = T.TrimGold
rim.Thickness = 2
rim.Parent = card
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 10)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
pad.Parent = card
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = card

local function label(text, h, face, color, order, parent)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, h)
	l.FontFace = face
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.TextColor3 = color
	l.LayoutOrder = order
	l.Parent = parent or card
	return l
end
local SANS = Font.fromEnum(T.Font)
local BOLD = Font.fromEnum(T.Bold)

local header = Instance.new("TextButton")
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 24)
header.FontFace = T.TitleFace
header.TextScaled = true
header.TextXAlignment = Enum.TextXAlignment.Left
header.Text = "Daily quests"
header.TextColor3 = T.Gold
header.LayoutOrder = 0
header.Parent = card

local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, 0, 0, 0)
body.AutomaticSize = Enum.AutomaticSize.Y
body.LayoutOrder = 1
body.Parent = card
local bodyList = Instance.new("UIListLayout")
bodyList.Padding = UDim.new(0, 6)
bodyList.SortOrder = Enum.SortOrder.LayoutOrder
bodyList.Parent = body

-- Keep one small edge tab available while the entire tracker is hidden.
local collapsed = player:GetAttribute("TPFC_QuestsCollapsed") == true
local toggle = Instance.new("TextButton")
toggle.Name = "QuestToggle"
toggle.AnchorPoint = Vector2.new(1, 0)
toggle.Size = UDim2.fromOffset(40, 40)
toggle.BackgroundColor3 = T.Raised
toggle.BorderSizePixel = 0
toggle.Text = ""
toggle.SelectionOrder = 1
toggle.Parent = gui
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)
local toggleRim = Instance.new("UIStroke")
toggleRim.Color, toggleRim.Thickness = T.TrimGold, 2
toggleRim.Parent = toggle
local arrow = Instance.new("Frame")
arrow.Name = "Arrow"
arrow.BackgroundTransparency = 1
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Position = UDim2.fromScale(0.5, 0.5)
arrow.Size = UDim2.fromOffset(16, 16)
arrow.Parent = toggle
for _, side in { -1, 1 } do
	local arm = Instance.new("Frame")
	arm.BorderSizePixel = 0
	arm.BackgroundColor3 = T.Gold
	arm.AnchorPoint = Vector2.new(0.5, 0.5)
	arm.Position = UDim2.fromOffset(8, 8 + side * 3.5)
	arm.Size = UDim2.fromOffset(11, 2)
	arm.Rotation = -side * 45
	arm.Parent = arrow
end
local function applyCollapsed()
	local available = State.Data.Progress ~= nil
	card.Visible = available and not collapsed
	toggle.Visible = available
	toggle.Position = UDim2.new(1, collapsed and -12 or -248, 0, 120)
	toggle:SetAttribute("Action", collapsed and "Show daily quests" or "Hide daily quests")
	arrow.Rotation = collapsed and 180 or 0
end
local function toggleQuests()
	collapsed = not collapsed
	player:SetAttribute("TPFC_QuestsCollapsed", collapsed)
	applyCollapsed()
end
toggle.Activated:Connect(toggleQuests)
header.Activated:Connect(toggleQuests)

-- quest rows
local rows = {}
for i = 1, 3 do
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, 0, 0, 30)
	r.LayoutOrder = i
	r.Parent = body
	local t = label("", 16, SANS, T.Text, 1, r)
	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.new(0, 0, 0, 21)
	barBg.Size = UDim2.new(1, 0, 0, 6)
	barBg.BackgroundColor3 = T.Inset
	barBg.BorderSizePixel = 0
	barBg.Parent = r
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = T.Jade
	bar.BorderSizePixel = 0
	bar.Parent = barBg
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	rows[i] = { frame = r, text = t, bar = bar }
end

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, 0, 0, 1)
divider.BackgroundColor3 = T.Border
divider.BorderSizePixel = 0
divider.LayoutOrder = 10
divider.Parent = body

local bonus = label("", 15, SANS, T.Muted, 11, body)

local function button(text, order, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = color or T.Timber
	b.AutoButtonColor = true
	b.FontFace = BOLD
	b.TextScaled = true
	b.Text = text
	b.TextColor3 = T.OnAccent
	b.LayoutOrder = order
	b.Parent = body
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local p = Instance.new("UIPadding")
	p.PaddingTop, p.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	p.Parent = b
	return b
end

local rebirthBtn = button("Rebirth", 20, T.Jade)
local armed = false
rebirthBtn.MouseButton1Click:Connect(function()
	local prog = State.Data.Progress
	if not prog or (State.Data.Money or 0) < (prog.RebirthCost or math.huge) then return end
	if not armed then
		armed = true
		rebirthBtn.Text = "Confirm: reset money and throw power"
		task.delay(4, function()
			armed = false
		end)
		return
	end
	armed = false
	local ok, msg = State.Request("Rebirth")
	pcall(function() require(script.Parent.HUD).Notify(msg or (ok and "Rebirth!" or "Can't rebirth"), ok and "success" or "error") end)
end)

-- boosts: only the ones whose ids are configured
local boosts = {}
local BOOSTS = {
	{ key = "DoubleLuck", text = "×2 Luck forever", kind = "pass" },
	{ key = "DoubleIncome", text = "×2 Income forever", kind = "pass" },
	{ key = "ExtraPet", text = "+1 pet slot", kind = "pass" },
	{ key = "LuckPotion", text = "Luck potion · 15 min", kind = "product" },
}
for i, b in ipairs(BOOSTS) do
	local id = b.kind == "pass" and C.Passes[b.key] or C.Products[b.key]
	if id and id > 0 then
		local btn = button(b.text, 30 + i, T.Brass)
		btn.MouseButton1Click:Connect(function()
			if b.kind == "pass" then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
		boosts[b.key] = btn
	end
end

local function refresh()
	local d = State.Data
	local prog = d.Progress
	applyCollapsed()
	if not prog then
		return
	end
	local quests = prog.Daily and prog.Daily.quests or {}
	local doneCount = 0
	for i, r in ipairs(rows) do
		local q = quests[i]
		r.frame.Visible = q ~= nil
		if q then
			local def = C.QuestById[q.id]
			r.text.Text = (q.done and "✓ " or "") .. string.format(def and def.text or q.id, q.goal) .. "  " .. q.progress .. "/" .. q.goal
			r.text.TextColor3 = q.done and T.Success or T.Text
			r.bar.Size = UDim2.fromScale(math.clamp(q.progress / q.goal, 0, 1), 1)
			if q.done then doneCount += 1 end
		end
	end
	header.Text = "Daily quests  " .. doneCount .. "/" .. #quests
	-- active luck/income sources
	local parts = {}
	if (prog.Rebirths or 0) > 0 then
		table.insert(parts, "Rebirth " .. prog.Rebirths)
	end
	if (prog.FriendsHere or 0) > 0 then
		table.insert(parts, math.min(C.Friends.max, prog.FriendsHere) .. " friend(s) +" .. math.floor(math.min(C.Friends.max, prog.FriendsHere) * C.Friends.luckPer * 100) .. "% luck")
	end
	if (prog.PotionUntil or 0) > os.time() then
		local left = prog.PotionUntil - os.time()
		table.insert(parts, string.format("Potion %d:%02d", math.floor(left / 60), left % 60))
	end
	bonus.Text = #parts > 0 and table.concat(parts, " · ") or "Play with friends for +10% luck each"
	local cost = prog.RebirthCost or 0
	local can = (d.Money or 0) >= cost
	if not armed then
		rebirthBtn.Text = can and ("Rebirth now · income ×" .. string.format("%.2f", 1 + ((prog.Rebirths or 0) + 1) * C.Rebirth.incomePer))
			or ("Rebirth at " .. Format.Money(cost))
	end
	rebirthBtn.BackgroundColor3 = can and T.Jade or T.Border
	rebirthBtn.AutoButtonColor = can
	for key, btn in pairs(boosts) do
		btn.Visible = not (prog.Passes and prog.Passes[key])
	end
end

State.Changed:Connect(refresh)
task.spawn(function()
	while true do
		task.wait(1)
		refresh()
	end
end)
refresh()
