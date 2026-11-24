-- The hall is the entry point. Explicit copies, visible odds, then a consumption confirmation.
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local Rules = require(RS.Shared.ForgeRules)
local Data = require(RS.Shared.CreatureData)
local Variants = require(RS.Shared.Variants)
local Planner = require(RS.Shared.ExpeditionPlanner)
local State = require(script.Parent.ClientState)
local K = require(script.Parent.UIKit)
local HUD = require(script.Parent.HUD)
local Renderer = require(script.Parent.CreatureRenderer)
local T = K.Theme
local Panel = {}
local player = game.Players.LocalPlayer
local ready, target, selectedKey, selected, groups = false, "Gold", nil, {}, {}
local armed, busy, pendingId, detailMode, previewKey = false, false, nil, false, nil
local panel, catalogue, detail, copies, copiesLayout, previewHost, nameLabel, hint, action, back, gold, ruby
local groupButtons, copyButtons, prompts = {}, {}, {}
local result, awaitingResultId, lastAnimatedResult

local function readResult()
	local receipt = State.Data.LastForge
	if awaitingResultId and receipt and receipt.id == awaitingResultId then
		result, awaitingResultId = receipt, nil
		selectedKey, selected, detailMode = nil, {}, true
	end
	return result
end

local function forgeResponse(id, ok, message)
	local receipt = State.Data.LastForge
	if receipt and receipt.id == id then
		return true, receipt.message, receipt.succeeded
	end
	return ok, message, nil
end

local function isAway(uid)
	local active = State.Data.Expeditions and State.Data.Expeditions.active
	return Planner.OnTeam(active, uid)
end
local function selection()
	local ids = {}
	for uid, chosen in pairs(selected) do
		if chosen then
			table.insert(ids, uid)
		end
	end
	table.sort(ids)
	return ids
end
local function groupKey(pet)
	return pet.c .. "|" .. (pet.s or "")
end
local function resetConfirmation()
	armed, pendingId = false, nil
end
local function selectedGroup()
	for _, group in ipairs(groups) do
		if group.key == selectedKey then
			return group
		end
	end
end
local function updateSelection()
	local ids, group = selection(), selectedGroup()
	local chance = Rules.Chances[#ids]
	for uid, button in pairs(copyButtons) do
		button:SetAttribute("Selected", selected[uid] == true)
		local label = button.Label.Text:gsub("^✓ ", "")
		button.Label.Text = (selected[uid] and "✓ " or "") .. label
		button.BackgroundColor3 = selected[uid] and T.Gold or T.Raised
		button.Label.TextColor3 = selected[uid] and T.Readable(T.Gold) or T.Text
		K.setEnabled(button, not busy)
	end
	for _, button in pairs(groupButtons) do
		if button:IsA("GuiButton") then
			K.setEnabled(button, not busy)
		end
	end
	K.setEnabled(gold, not busy)
	K.setEnabled(ruby, not busy)
	back.Label.TextColor3 = T.Text
	K.setEnabled(back, not busy)
	local chanceText = chance and (math.floor(chance * 100 + 0.5) .. "% success") or "Select 2 to 5 pets"
	hint.Text = chance == 1 and ("Guaranteed · " .. #ids .. " selected pets become one " .. target .. ".")
		or chance and (chanceText .. " · All " .. #ids .. " pets consumed, even on failure.")
		or "Choose matching copies. Following and expedition pets stay safe."
	hint.TextColor3 = armed and T.Danger or T.Text
	action.Label.Text = busy and "Forging..."
		or (
			armed and ("Consume " .. #ids .. " · Forge " .. target)
			or (
				"Review "
				.. #ids
				.. " pets · "
				.. (chance and math.floor(chance * 100 + 0.5) .. "%" or "select copies")
			)
		)
	K.setEnabled(action, not busy and group ~= nil and chance ~= nil)
	back.Label.Text = armed and "Cancel" or "Matching pets"
	if result then
		hint.Text = result.message
		hint.TextColor3 = result.succeeded and T.Success or T.Danger
		action.Label.Text = "Choose matching pets"
		K.setEnabled(action, not busy)
	end
end

local render
local function choose(group)
	if busy then
		return
	end
	selectedKey, selected, detailMode = group.key, {}, true
	result, awaitingResultId = nil, nil
	for i = 1, math.min(5, #group.pets) do
		selected[group.pets[i].u] = true
	end
	resetConfirmation()
	render()
end

render = function()
	if not ready then
		return
	end
	local data = State.Data
	readResult()
	local byKey, eligible = {}, {}
	groups = {}
	for _, pet in ipairs(data.Creatures) do
		if (pet.v or "") == Rules.Input[target] and not Rules.Protected(data, pet, isAway) and Data.ById[pet.c] then
			local key = groupKey(pet)
			if not byKey[key] then
				byKey[key] = { key = key, pet = pet, pets = {} }
				table.insert(groups, byKey[key])
			end
			table.insert(byKey[key].pets, pet)
			eligible[pet.u] = true
		end
	end
	table.sort(groups, function(a, b)
		if (#a.pets >= 2) ~= (#b.pets >= 2) then
			return #a.pets >= 2
		end
		return Data.ById[a.pet.c].name < Data.ById[b.pet.c].name
	end)
	for _, group in ipairs(groups) do
		table.sort(group.pets, function(a, b)
			local ap, bp = State.IsPlaced(a.u), State.IsPlaced(b.u)
			if ap ~= bp then
				return not ap
			end
			if (a.l or 1) ~= (b.l or 1) then
				return (a.l or 1) < (b.l or 1)
			end
			return a.u < b.u
		end)
	end
	for uid in pairs(selected) do
		if not eligible[uid] then
			selected[uid] = nil
			resetConfirmation()
		end
	end
	for _, b in pairs(groupButtons) do
		b:Destroy()
	end
	groupButtons = {}
	for i, group in ipairs(groups) do
		local label = Variants.Prefix(group.pet.s, nil) .. Data.ById[group.pet.c].name
		local b = K.button(
			label .. "  ·  " .. #group.pets .. " available",
			T.Raised,
			nil,
			UDim2.new(1, -8, 0, 48),
			{ Name = "Group_" .. group.pet.c, LayoutOrder = i, Parent = catalogue }
		)
		b.Label.TextXAlignment = Enum.TextXAlignment.Left
		b.Label.TextSize = 14
		b:SetAttribute("Selected", selectedKey == group.key)
		K.bind(b, function()
			choose(group)
		end)
		table.insert(groupButtons, b)
	end
	if #groups == 0 then
		local empty = K.label(
			target == "Gold" and "Catch matching ordinary pets first. Five guarantee a Gold pet."
				or "Forge matching Gold pets first. Five guarantee a Ruby pet.",
			UDim2.new(1, -16, 0, 90),
			T.Text,
			{ Name = "ForgeEmpty", TextSize = 16, LayoutOrder = 0, Parent = catalogue }
		)
		table.insert(groupButtons, empty)
	end
	local group = selectedGroup()
	if not group and not result then
		selectedKey, selected, detailMode = nil, {}, false
	end
	gold:SetAttribute("Selected", target == "Gold")
	ruby:SetAttribute("Selected", target == "Ruby")
	gold.BackgroundColor3 = target == "Gold" and T.Gold or T.Raised
	ruby.BackgroundColor3 = target == "Ruby" and T.Gold or T.Raised
	gold.Label.TextColor3 = T.Readable(gold.BackgroundColor3)
	ruby.Label.TextColor3 = T.Readable(ruby.BackgroundColor3)
	nameLabel.Text = group and (Variants.Prefix(group.pet.s, target) .. Data.ById[group.pet.c].name)
		or "Choose a matching species"
	local key = group and group.key .. ":" .. target or ""
	if result then
		local species = Data.ById[result.species]
		nameLabel.Text = result.succeeded and (result.target .. " " .. (species and species.name or "pet"))
			or "Forge unsuccessful"
		key = "receipt:" .. result.id
	end
	if key ~= previewKey then
		previewKey = key
		previewHost:ClearAllChildren()
		if result and result.succeeded and Data.ById[result.species] then
			local vp = K.viewport(
				Renderer.BuildPreview(result.species, result.target),
				UDim2.fromScale(1, 1),
				false,
				false,
				true
			)
			vp.Name, vp.Parent = "ForgedPet", previewHost
			if HUD.IsOpen("Forge") and lastAnimatedResult ~= result.id then
				lastAnimatedResult = result.id
				K.Motion.Enter(vp, UDim2.new(), UDim2.fromOffset(0, 6))
			end
		elseif result then
			K.label("Forge cooled", UDim2.fromScale(1, 1), T.Muted, { TextSize = 14, Parent = previewHost })
		elseif group then
			K.viewport(Renderer.BuildPreview(group.pet.c, target), UDim2.fromScale(1, 1), false, false, true).Parent =
				previewHost
		end
	end
	for _, b in pairs(copyButtons) do
		b:Destroy()
	end
	copyButtons = {}
	if group then
		for i, pet in ipairs(group.pets) do
			local b = K.button(
				"Lv " .. (pet.l or 1) .. (State.IsPlaced(pet.u) and " · courtyard" or " · stored"),
				T.Raised,
				nil,
				UDim2.new(1, -8, 0, 38),
				{ Name = "Copy_" .. pet.u, LayoutOrder = i, Parent = copies }
			)
			b:SetAttribute("PetUid", pet.u)
			copyButtons[pet.u] = b
			K.bind(b, function()
				if busy then
					return
				end
				if selected[pet.u] then
					selected[pet.u] = nil
				elseif #selection() < 5 then
					selected[pet.u] = true
				end
				resetConfirmation()
				updateSelection()
			end)
		end
	end
	panel.layout()
	updateSelection()
end

function Panel.Open(nextTarget)
	if not ready or busy then
		return
	end
	target = Rules.Input[nextTarget] ~= nil and nextTarget or "Gold"
	result, awaitingResultId = nil, nil
	selectedKey, selected, detailMode = nil, {}, false
	resetConfirmation()
	HUD.Open("Forge")
end

function Panel.Init()
	if ready then
		return
	end
	panel = HUD.MakePanel(
		"Forge",
		"The Great Forge",
		"Ordinary pets become Gold. Matching Gold pets become Ruby.",
		"Strength"
	)
	panel.inlineMessage = function(message, color)
		panel.subtitle.Text = message ~= "" and message or "Ordinary pets become Gold. Matching Gold pets become Ruby."
		panel.subtitle.TextColor3 = color or T.Muted
	end
	panel.content.ScrollingEnabled = false
	panel.content.AutomaticCanvasSize = Enum.AutomaticSize.None
	gold =
		K.button("Gold forge", T.Gold, nil, UDim2.new(0.5, -4, 0, 38), { Name = "GoldRecipe", Parent = panel.content })
	ruby = K.button(
		"Ruby forge",
		T.Raised,
		nil,
		UDim2.new(0.5, -4, 0, 38),
		{ Name = "RubyRecipe", Position = UDim2.new(0.5, 4, 0, 0), Parent = panel.content }
	)
	for _, item in { { gold, "Gold" }, { ruby, "Ruby" } } do
		K.bind(item[1], function()
			if busy then
				return
			end
			target = item[2]
			result, awaitingResultId = nil, nil
			selectedKey, selected, detailMode = nil, {}, false
			resetConfirmation()
			render()
		end)
	end
	catalogue = K.new("ScrollingFrame", {
		Name = "MatchingPets",
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel.content,
	})
	K.list(nil, 6, Enum.HorizontalAlignment.Left).Parent = catalogue
	detail = K.new("Frame", { Name = "ForgeRecipe", BackgroundTransparency = 1, Parent = panel.content })
	back = K.button(
		"Matching pets",
		T.Raised,
		nil,
		UDim2.fromOffset(142, 34),
		{ Name = "ForgeBack", Position = UDim2.new(1, -204, 0, 14), Parent = panel.frame }
	)
	back.Label.TextSize = 13
	K.bind(back, function()
		if busy then
			return
		end
		resetConfirmation()
		result, awaitingResultId = nil, nil
		detailMode = false
		render()
	end)
	nameLabel = K.text(detail, "", 0, 0, 0, 28, 21, T.Text, true)
	nameLabel.FontFace = T.TitleFace
	previewHost =
		K.new("Frame", { Name = "OutputPreview", BackgroundTransparency = 1, ClipsDescendants = true, Parent = detail })
	copies = K.new("ScrollingFrame", {
		Name = "SelectedCopies",
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		Parent = detail,
	})
	copiesLayout = K.list(nil, 5, Enum.HorizontalAlignment.Left)
	copiesLayout.Parent = copies
	hint = K.text(detail, "", 0, 0, 0, 42, 14, T.Text)
	hint.TextWrapped = true
	action = K.button(
		"Review forge",
		T.Gold,
		nil,
		UDim2.new(1, 0, 0, 44),
		{ Name = "ConfirmForge", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = detail }
	)
	K.bind(action, function()
		if result and not busy then
			result, awaitingResultId = nil, nil
			selectedKey, selected, detailMode = nil, {}, false
			resetConfirmation()
			render()
			return
		end
		if busy or not Rules.Chances[#selection()] then
			return
		end
		if not armed then
			armed, pendingId = true, Http:GenerateGUID(false)
			updateSelection()
			return
		end
		local request = { id = pendingId, target = target, uids = selection() }
		busy = true
		updateSelection()
		local ok, message = State.Request("Forge", Http:JSONEncode(request))
		local succeeded
		ok, message, succeeded = forgeResponse(request.id, ok, message)
		busy = false
		-- Retain the id on network failure: retrying can recover a committed result.
		if ok then
			awaitingResultId = request.id
			resetConfirmation()
			selected = {}
		end
		HUD.SetPanelMessage(
			"Forge",
			message or "Could not forge. Try again.",
			not ok and T.Danger or (succeeded == nil and T.Muted or (succeeded and T.Success or T.Danger))
		)
		render()
	end)
	panel.layout = function()
		local compact = panel.compact
		panel.frame:SetAttribute("CompactHeader", compact)
		local contentTop = compact and 66 or 108
		panel.content.Position = UDim2.fromOffset(16, contentTop)
		panel.content.Size = UDim2.new(1, -32, 1, -contentTop - 16)
		panel.subtitle.Position = UDim2.fromOffset(20, compact and 45 or 60)
		panel.subtitle.Size = UDim2.new(1, -92, 0, compact and 16 or 35)
		panel.subtitle.TextSize = compact and 11 or 14
		local y = compact and 38 or 46
		local h = math.max(100, panel.frame.Size.Y.Offset - contentTop - 16 - y)
		gold.Size = UDim2.new(0.5, -4, 0, compact and 30 or 38)
		ruby.Size = gold.Size
		catalogue.Position, catalogue.Size =
			UDim2.fromOffset(0, y), UDim2.new(compact and 1 or 0.39, compact and 0 or -14, 0, h)
		catalogue.Visible = not compact or not detailMode
		detail.Visible = not compact or detailMode
		detail.Position = compact and UDim2.fromOffset(0, y) or UDim2.new(0.4, 8, 0, y)
		detail.Size = UDim2.new(compact and 1 or 0.6, compact and 0 or -8, 0, h)
		back.Visible = detailMode or armed
		nameLabel.Size = UDim2.new(1, 0, 0, compact and 20 or 30)
		nameLabel.TextSize = compact and 18 or 21
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		previewHost.Position, previewHost.Size =
			UDim2.fromOffset(0, compact and 22 or 44), UDim2.fromOffset(compact and 42 or 162, compact and 42 or 162)
		copies.Position = UDim2.fromOffset(compact and 50 or 176, compact and 24 or 44)
		copies.Size = UDim2.new(1, compact and -50 or -176, 0, compact and 42 or math.max(76, h - 152))
		copies.AutomaticCanvasSize = compact and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
		copies.ScrollingDirection = compact and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
		copiesLayout.FillDirection = compact and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
		for uid, b in pairs(copyButtons) do
			b.Size = compact and UDim2.fromOffset(68, 40) or UDim2.new(1, -8, 0, 38)
			b.Label.TextSize = compact and 11 or 14
			local pet
			for _, owned in ipairs(State.Data.Creatures) do
				if owned.u == uid then
					pet = owned
					break
				end
			end
			if pet then
				b.Label.Text = "Lv "
					.. (pet.l or 1)
					.. (
						compact and (State.IsPlaced(uid) and "\nyard" or "\nstored")
						or (State.IsPlaced(uid) and " · courtyard" or " · stored")
					)
			end
		end
		hint.Position = compact and UDim2.fromOffset(0, 68) or UDim2.new(0, 0, 1, -105)
		hint.Size = UDim2.new(1, 0, 0, compact and 36 or 56)
		hint.TextSize = compact and 11 or 14
		action.Size = UDim2.new(1, 0, 0, compact and 40 or 44)
	end
	-- HUD already routes state updates to the open panel. Money-only updates do not
	-- change recipes; rebuilding both lists also resets their scroll/focus unnecessarily.
	panel.refresh = function(full)
		if full ~= false or awaitingResultId then
			render()
		end
	end
	panel.onClose = function()
		resetConfirmation()
		result, awaitingResultId = nil, nil
	end
	ready = true
	local function attach()
		local map = workspace:FindFirstChild("Map")
		local hall = map and map:FindFirstChild("Start") and map.Start:FindFirstChild("GreatForgeHall")
		if not hall then
			return
		end
		for _, recipe in { "Gold", "Ruby" } do
			local existing = prompts[recipe]
			if existing and existing.Parent and existing:IsDescendantOf(hall) then
				continue
			end
			local anchor = hall:FindFirstChild(recipe .. "Station", true)
			if anchor and (not prompts[recipe] or prompts[recipe].Parent ~= anchor) then
				if prompts[recipe] then
					prompts[recipe]:Destroy()
				end
				local prompt = K.new("ProximityPrompt", {
					Name = "Use" .. recipe .. "Forge",
					ActionText = "Forge " .. recipe,
					ObjectText = "Great Hall",
					MaxActivationDistance = 11,
					HoldDuration = 0,
					RequiresLineOfSight = false,
					Parent = anchor,
				})
				prompt.Triggered:Connect(function(who)
					if who == player then
						Panel.Open(recipe)
					end
				end)
				prompts[recipe] = prompt
			end
		end
	end
	attach()
	task.spawn(function()
		while panel.frame.Parent do
			task.wait(1)
			if panel.frame.Parent then
				attach()
			end
		end
	end)
	HUD.Rescale()
end
return Panel
