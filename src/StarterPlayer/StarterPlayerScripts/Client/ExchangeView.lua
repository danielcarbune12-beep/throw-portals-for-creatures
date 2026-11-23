-- Four direct trade signs linked to an architectural model of the sanctuary.
local K = require(script.Parent.UIKit)
local T = K.Theme
local Craft = require(script.Parent.SanctuaryUI)
local Guild = require(script.Parent.GuildModel)
local Merchant = require(script.Parent.MerchantDisplay)
local RS = game:GetService("ReplicatedStorage")
local Portal, Config = require(RS.Shared.PortalBuilder), require(RS.Shared.Config)
local Format, State = require(RS.Shared.Format), require(script.Parent.ClientState)
local E = {}
function E.Mount(hub, HUD)
	hub.frame:SetAttribute("GatefoldExchange", true)
	hub.content.AutomaticCanvasSize, hub.content.ScrollingEnabled = Enum.AutomaticSize.None, false
	hub.subtitle.Visible = false
	local stage = K.new("Frame", { Name = "TradeCourt", BackgroundTransparency = 1, Parent = hub.content })
	local backMap = Craft.Paper(stage, "FoldedMap", UDim2.fromScale(0.92, 0.92), UDim2.fromScale(0.04, 0.04))
	backMap.Rotation = 3
	local survey = Craft.Paper(stage, "SurveyMap", UDim2.fromScale(0.94, 0.92), UDim2.fromScale(0.03, 0.02))
	survey.Rotation = -2
	local mapRule = K.stroke(1, T.Brass)
	mapRule.Transparency, mapRule.Parent = 0.35, survey
	local scene = K.viewport(Guild.Build(), UDim2.fromScale(1, 1), false, false, false)
	scene.Name, scene.Parent = "ExchangeArchitecture", stage
	scene.Ambient, scene.LightColor = Color3.fromRGB(177, 190, 181), Color3.fromRGB(255, 244, 218)
	scene.LightDirection = Vector3.new(-0.6, -1, -0.35)
	local updateLines
	local function frameScene()
		local aspect = math.max(0.5, scene.AbsoluteSize.X / math.max(1, scene.AbsoluteSize.Y))
		local target = Vector3.new(0, 1.5, 0)
		scene.CurrentCamera.FieldOfView = 32
		scene.CurrentCamera.CFrame =
			CFrame.lookAt(target + Vector3.new(0, 0.9, 1).Unit * math.max(62, 76 / aspect), target)
		if updateLines then
			updateLines()
		end
	end
	scene:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameScene)
	task.defer(frameScene)
	local purse = K.text(hub.frame, "", 0, 15, 210, 30, 20, T.CinematicGold, true)
	purse.Name = "ShopBalance"
	local entries, names = {}, { "Forge", "Upgrades", "Courtyard", "Atlas" }
	for i, def in
		{
			{ "Portals", "Portal forge", "Choose your next gate", "Portals", "Portal" },
			{ "Upgrades", "The smithy", "Improve your reach & earnings", "Upgrades", "Upgrade" },
			{ "Courtyard", "Courtyard works", "Shape your creature sanctuary", "Base", "Home" },
			{ "Biomes", "The atlas", "Open the next biome", "Worlds", "Compass" },
		}
	do
		local leader = K.new("Frame", {
			Name = "TradeLeader",
			BackgroundColor3 = T.StoneEdge,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = hub.content,
		})
		local node = K.new("Frame", {
			Name = "TradeMarker",
			BackgroundColor3 = T.Brass,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			Rotation = 45,
			Parent = hub.content,
		})
		local button =
			K.button("", T.Raised, nil, UDim2.fromOffset(228, 120), { Name = "Shop_" .. def[1], Parent = hub.content })
		Craft.Leaf(button)
		local slip = Craft.Paper(button, "TradeSlip", UDim2.new(1, -12, 0, 68), UDim2.fromOffset(6, 48))
		for _, x in { 0, 1 } do
			K.new(
				"Frame",
				{
					Name = "SlipPin",
					Size = UDim2.fromOffset(4, 4),
					Position = UDim2.new(x, x == 0 and 4 or -8, 0, 4),
					BackgroundColor3 = T.Brass,
					Parent = slip,
				}
			)
		end
		local sign = K.viewport(Guild.Sign(), UDim2.new(1, -4, 0, 48), false, false, false)
		sign.Name, sign.Position, sign.Parent = "CarvedTradeSign", UDim2.fromOffset(2, 2), button
		sign.Ambient, sign.LightColor, sign.LightDirection =
			Color3.fromRGB(210, 215, 210), Color3.new(1, 1, 1), Vector3.new(-0.4, -0.4, -1)
		sign.CurrentCamera.FieldOfView = 10
		sign.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -28), Vector3.zero)
		local title = K.text(button, def[2], 18, 10, -36, 28, 19, T.OnAccent, true)
		title.FontFace = T.TitleFace
		local desc = K.text(button, def[3], 14, 56, -28, 20, 13, T.Muted)
		local status = K.text(button, "", 14, 82, -28, 28, 13, T.Gold)
		local arrow = K.text(button, "›", 0, 10, 18, 24, 24, T.Gold, true)
		arrow.Position = UDim2.new(1, -26, 0, 10)
		local subject = def[5] == "Portal" and Portal.BuildGate("Forest", 2) or Merchant.Emblem(def[5])
		local emblem = K.viewport(subject, UDim2.fromOffset(66, 78), false, false, true)
		emblem.Name, emblem.Parent = "TradeEmblem", button
		entries[i] = {
			button = button,
			slip = slip,
			title = title,
			desc = desc,
			status = status,
			emblem = emblem,
			arrow = arrow,
			sign = sign,
			leader = leader,
			node = node,
		}
		K.bind(button, function()
			HUD.Open(def[4])
		end)
		local hovered, focused = false, false
		local function focus()
			local on = hovered or focused
			Craft.Selected(button, on)
			button.BackgroundTransparency = on and 0.12 or 1
			button:FindFirstChildOfClass("UIStroke").Transparency = on and 0 or 1
			leader.BackgroundColor3, node.BackgroundColor3 =
				on and T.CinematicGold or T.TrimGold, on and T.Gold or T.Brass
			local pad = scene.PreviewWorld.TheFourTrades:FindFirstChild("Pad_" .. names[i])
			if pad then
				pad.Color = on and Color3.fromRGB(204, 183, 116) or pad:GetAttribute("RestColor")
			end
		end
		button.MouseEnter:Connect(function()
			hovered = true
			focus()
		end)
		button.MouseLeave:Connect(function()
			hovered = false
			focus()
		end)
		button.SelectionGained:Connect(function()
			focused = true
			focus()
		end)
		button.SelectionLost:Connect(function()
			focused = false
			focus()
		end)
		focus()
	end
	-- The connectors are projected from the SAME camera as the model, so the signs
	-- stay attached to the right trade when UI scale or the window size changes.
	updateLines = function()
		if not stage.Visible then
			return
		end
		local scale = HUD.Root:FindFirstChildOfClass("UIScale").Scale
		local size = scene.AbsoluteSize
		local tanY = math.tan(math.rad(scene.CurrentCamera.FieldOfView / 2))
		local aspect = size.X / math.max(1, size.Y)
		for i, ref in entries do
			local point = scene.CurrentCamera.CFrame:PointToObjectSpace(
				Vector3.new(i % 2 == 1 and -10 or 10, 0.5, i <= 2 and -5 or 7)
			)
			local x = size.X * (0.5 + point.X / (-point.Z * tanY * aspect) / 2)
				+ stage.AbsolutePosition.X
				- hub.content.AbsolutePosition.X
			local y = size.Y * (0.5 - point.Y / (-point.Z * tanY) / 2)
				+ stage.AbsolutePosition.Y
				- hub.content.AbsolutePosition.Y
			local b = ref.button
			local start = b.AbsolutePosition
				- hub.content.AbsolutePosition
				+ Vector2.new(i % 2 == 1 and b.AbsoluteSize.X or 0, b.AbsoluteSize.Y * 0.64)
			local delta = Vector2.new(x, y) - start
			local center = start + delta / 2
			ref.leader.Position, ref.leader.Size =
				UDim2.fromOffset(center.X / scale, center.Y / scale), UDim2.fromOffset(delta.Magnitude / scale, 1)
			ref.leader.Rotation = math.deg(math.atan2(delta.Y, delta.X))
			ref.node.Position = UDim2.fromOffset(x / scale, y / scale)
		end
	end
	hub.refresh = function()
		purse.Text = "Purse  " .. Format.Money(State.Data.Money)
		local owned, unlocked = 0, 0
		for _, yes in State.Data.OwnedPortals do
			if yes then
				owned += 1
			end
		end
		for _, yes in State.Data.UnlockedWorlds do
			if yes then
				unlocked += 1
			end
		end
		entries[1].status.Text = owned .. " owned · " .. Config.Portals[State.Data.EquippedPortal].name
		entries[2].status.Text = math.floor(State.Data.MaxDistance or 45) .. " m throw range"
		entries[3].status.Text = "Floors · lanterns · furnishings"
		entries[4].status.Text = unlocked .. " / 8 routes unlocked"
	end
	hub.layout = function()
		local short = hub.compact or hub.frame.Size.Y.Offset < 520
		hub.content.Position = UDim2.fromOffset(16, short and 66 or 84)
		hub.contentSize = UDim2.new(1, -32, 1, short and -82 or -108)
		hub.content.Size = hub.contentSize - UDim2.fromOffset(0, hub.feedback.Visible and 40 or 0)
		hub.title.Position = UDim2.fromOffset(62, short and 8 or 15)
		hub.title.Size = UDim2.new(1, short and -148 or -360, 0, short and 28 or 35)
		purse.Position = short and UDim2.fromOffset(62, 37) or UDim2.new(1, -290, 0, 16)
		purse.Size = short and UDim2.new(1, -145, 0, 16) or UDim2.fromOffset(212, 30)
		purse.TextSize, purse.TextXAlignment =
			short and 13 or 18, short and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
		stage.Visible = not short
		stage.Position, stage.Size = UDim2.fromScale(0.17, 0.03), UDim2.fromScale(0.66, 0.96)
		for i, ref in entries do
			local left, top = i % 2 == 1, i <= 2
			if short then
				ref.button.Position = UDim2.new(left and 0 or 0.5, left and 2 or 5, top and 0 or 0.5, top and 2 or 4)
				ref.button.Size = UDim2.new(0.5, -9, 0.5, -8)
			else
				ref.button.Position = UDim2.new(left and 0 or 1, left and 4 or -232, top and 0.12 or 0.65, 0)
				ref.button.Size = UDim2.fromOffset(228, 120)
			end
			ref.emblem.Visible, ref.sign.Visible, ref.leader.Visible, ref.node.Visible =
				short, not short, not short, not short
			ref.slip.Position = short and UDim2.fromOffset(2, 2) or UDim2.fromOffset(6, 48)
			ref.slip.Size = short and UDim2.new(1, -4, 1, -4) or UDim2.new(1, -12, 0, 68)
			ref.emblem.Position = UDim2.fromOffset(4, 8)
			ref.emblem.Size = UDim2.fromOffset(66, math.max(56, math.min(84, hub.frame.Size.Y.Offset * 0.23)))
			ref.title.Position = UDim2.fromOffset(short and 78 or 18, 10)
			ref.title.Size = UDim2.new(1, short and -102 or -36, 0, 28)
			ref.title.TextSize, ref.title.TextColor3 = short and 17 or 19, short and T.Text or T.OnAccent
			ref.title.TextXAlignment = short and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
			ref.desc.Visible, ref.arrow.Visible = not short, short
			ref.status.Position = UDim2.fromOffset(short and 78 or 14, short and 42 or 82)
			ref.status.Size = UDim2.new(1, short and -96 or -28, 0, short and 38 or 28)
			ref.status.TextSize = short and 12 or 13
		end
		task.defer(frameScene)
	end
	return entries
end
return E
