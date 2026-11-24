-- A short saved guide, with a real knight portrait and ground arrows on known hub paths.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Rules = require(RS.Shared.ForgeRules)
local Knight = require(RS.Shared.GuideKnight)
local Config = require(RS.Shared.Config)
local State = require(script.Parent.ClientState)
local HUD = require(script.Parent.HUD)
local TC = require(script.Parent.ThrowController)
local Settings = require(script.Parent.ClientSettings)
local K = require(script.Parent.UIKit)
local T = K.Theme
local Guide = {}
local player = game.Players.LocalPlayer
local messages = {
	"Follow my brass arrows to the Launch Hall. We will catch your first companion.",
	"Hold to charge your portal, then release. Your pet will join your courtyard automatically.",
	"Your courtyard pets earn coins. Follow the arrows to your treasury and collect them.",
	"This is the Great Forge. Five matching pets guarantee Gold. Gold can become Ruby. Failed attempts consume the pets.",
}
local titles = { "First steps", "Catch a companion", "Your treasury", "The Great Forge" }

function Guide.Init()
	if Guide.Started then
		return
	end
	Guide.Started = true
	local panel = K.surface(HUD.Root, "KnightGuide", UDim2.fromOffset(430, 120), nil, T.Panel)
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Visible = false
	local portrait = K.viewport(Knight.Build(), UDim2.fromOffset(74, 96), false, false, true)
	portrait.Position = UDim2.fromOffset(6, 10)
	portrait.Parent = panel
	local title = K.text(panel, "Sir Rowan", 90, 10, -140, 22, 17, T.Text, true)
	title.FontFace = T.TitleFace
	local text = K.text(panel, "", 90, 35, -104, 71, 14, T.Text)
	text.Name = "Instruction"
	text.TextWrapped = true
	text.TextYAlignment = Enum.TextYAlignment.Top
	local skip = K.button(
		"Skip",
		T.Raised,
		nil,
		UDim2.fromOffset(46, 28),
		{ Name = "SkipGuide", Position = UDim2.new(1, -54, 0, 7), Parent = panel }
	)
	skip.Label.TextSize = 11
	local compass = K.text(panel, "▲", 0, 0, 0, 24, 22, T.Gold, true)
	compass.Name = "GuideDirection"
	compass.Position = UDim2.new(1, -88, 0, 7)
	compass.Size = UDim2.fromOffset(24, 24)
	K.bind(skip, function()
		State.Request("Tutorial", "Skip")
	end)
	local arrows = Instance.new("Folder")
	arrows.Name = "KnightGuideArrows"
	arrows.Parent = workspace
	local parts = {}
	for i = 1, 7 do
		parts[i] = {}
		for _, side in { -1, 1 } do
			local p = Instance.new("Part")
			p.Name = "BrassArrow"
			p.Size = Vector3.new(0.2, 0.08, 1.4)
			p.Color, p.Material = Color3.fromRGB(241, 202, 115), Enum.Material.Neon
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
			p.Transparency = 1
			p.Parent = arrows
			table.insert(parts[i], { part = p, side = side })
		end
	end
	local busy, elapsed, prompt = false, 0, nil
	local active, rendered, lastStep, lastLayout = false, false, nil, nil
	local currentRoot, currentBase, target, waypoint, center
	local panelPosition, panelTween, textTween, compassAngle
	local lastProbe, lastWaypoint, knightElapsed = nil, nil, 1
	local rayParams = RaycastParams.new()
	rayParams.RespectCanCollide = true
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local samples = {}
	for i = 1, #parts do
		samples[i] = { y = 0.65, opacity = 1 }
	end
	local function base()
		return workspace:FindFirstChild("Bases")
			and workspace.Bases:FindFirstChild("Base" .. (State.Data.BaseIndex or 0))
	end
	local function targetFor(step, b)
		if step <= 2 then
			return Vector3.new(0, 1.4, -14)
		end
		if step == 3 and b then
			local collect = b:FindFirstChild("CollectPad", true)
			return collect and collect.Position
		end
		return Rules.Door
	end
	local function route(pos, destination, baseCenter, step)
		local routeCenter = baseCenter
		if routeCenter then
			local z = routeCenter.Position.Z
			if step == 3 then
				if math.abs(pos.X) > 34 and math.abs(pos.Z - z) < 35 then
					return destination
				end
				if math.abs(pos.Z - z) > 7 then
					return Vector3.new(0, 0.8, z)
				end
				return destination
			elseif math.abs(pos.X) > 33 and math.abs(pos.Z - z) < 35 then
				if math.abs(pos.Z - z) > 4 then
					return Vector3.new(pos.X, 0.8, z)
				end
				return Vector3.new(0, 0.8, z)
			end
		end
		if math.abs(pos.X) > 8 and math.abs(pos.Z - destination.Z) > 8 then
			return Vector3.new(0, 0.8, pos.Z)
		end
		return destination
	end
	local function attachKnight()
		if prompt and prompt.Parent then
			return
		end
		local map = workspace:FindFirstChild("Map")
		local hall = map and map:FindFirstChild("Start") and map.Start:FindFirstChild("GreatForgeHall")
		local knight = hall and hall:FindFirstChild("SirRowan")
		if knight and (not prompt or prompt.Parent ~= knight.PrimaryPart) then
			if prompt then
				prompt:Destroy()
			end
			prompt = K.new("ProximityPrompt", {
				Name = "TalkToSirRowan",
				ObjectText = "Sir Rowan",
				ActionText = "Replay guide",
				MaxActivationDistance = 10,
				HoldDuration = 0.2,
				RequiresLineOfSight = false,
				Parent = knight.PrimaryPart,
			})
			prompt.Triggered:Connect(function(who)
				if who == player then
					State.Request("Tutorial", "Restart")
				end
			end)
		end
	end
	local function layout()
		local scale = HUD.Root:FindFirstChildOfClass("UIScale")
		local size = HUD.Root.AbsoluteSize / (scale and scale.Scale or 1)
		local compact = HUD.Compact == true
		local width = compact and math.min(416, math.max(280, size.X - 332)) or 430
		local key = tostring(compact) .. ":" .. math.floor(width)
		if key == lastLayout then
			return
		end
		lastLayout = key
		if panelTween then
			panelTween:Cancel()
		end
		panel.AnchorPoint = compact and Vector2.new(0, 0) or Vector2.new(0, 1)
		panelPosition = compact and UDim2.fromOffset(76, 70) or UDim2.new(0, 90, 1, -16)
		panel.Position = panelPosition
		panel.Size = UDim2.fromOffset(width, compact and (width < 340 and 106 or 94) or 120)
		portrait.Size = UDim2.fromOffset(compact and 54 or 74, compact and 74 or 96)
		local x = compact and 66 or 90
		title.Position = UDim2.fromOffset(x, 8)
		title.Size = UDim2.new(1, -x - 98, 0, 22)
		title.TextSize = compact and 14 or 17
		text.Position = UDim2.fromOffset(x, 40)
		text.Size = UDim2.new(1, -x - 12, 1, -48)
		text.TextSize = compact and 12 or 14
	end
	local function refreshStep(step)
		if step == lastStep then
			return
		end
		lastStep = step
		title.Text = "Sir Rowan · " .. math.min(step, 4) .. "/4"
		text.Text = messages[step] or ""
		panel:SetAttribute("GuideStep", step)
		panel:SetAttribute("StepTitle", titles[step] or "Complete")
		compass:SetAttribute("AccessibleLabel", titles[step] or "Complete")
		lastProbe, lastWaypoint, compassAngle = nil, nil, nil
		for _, sample in ipairs(samples) do
			sample.cf, sample.written, sample.opacity = nil, nil, 1
		end
		if textTween then
			textTween:Cancel()
		end
		text.TextTransparency = active and not Settings.ReducedMotion and 0.35 or 0
		if text.TextTransparency > 0 then
			textTween = K.tween(text, 0.18, { TextTransparency = 0 })
		end
	end
	local function hideArrows()
		for i, pair in ipairs(parts) do
			samples[i].opacity, samples[i].cf, samples[i].written = 1, nil, nil
			for _, item in ipairs(pair) do
				item.part.Transparency = 1
			end
		end
	end
	local function groundProbe()
		if not waypoint or not currentRoot then
			return
		end
		local pos = currentRoot.Position
		if
			lastProbe
			and (pos - lastProbe).Magnitude < 0.75
			and lastWaypoint
			and (waypoint - lastWaypoint).Magnitude < 0.75
		then
			return
		end
		lastProbe, lastWaypoint = pos, waypoint
		rayParams.FilterDescendantsInstances = { arrows, player.Character }
		local delta = Vector3.new(waypoint.X - pos.X, 0, waypoint.Z - pos.Z)
		local length = delta.Magnitude
		if length < 0.1 then
			return
		end
		local direction = delta / length
		for i, sample in ipairs(samples) do
			if i <= (Settings.LowVFX() and 4 or 7) and length > i * 4.2 then
				local point = pos + direction * (i * 4.2)
				-- Non-querying visual inlays sit above the collision floor. Preserve
				-- their authored clearance without changing the map's landing-ray contract.
				local minimum = (math.abs(point.X) < 24 and point.Z > -272 and point.Z < -200) and 0.9 or 0.5
				if center and math.abs(point.X) > 29 and math.abs(point.Z - center.Position.Z) < 34 then
					minimum = 1.15
				end
				if lastStep == 3 and (Vector3.new(point.X, target.Y, point.Z) - target).Magnitude < 7 then
					minimum = 1.8
				end
				local hit =
					workspace:Raycast(Vector3.new(point.X, pos.Y + 4, point.Z), Vector3.new(0, -18, 0), rayParams)
				if hit and hit.Normal.Y > 0.75 then
					sample.y = math.max(minimum, hit.Position.Y + 0.12)
				else
					sample.y = minimum
				end
			end
		end
	end
	local function render(dt)
		-- Render work is connected only while the guide is visible. No hierarchy scans,
		-- layout, raycasts, network requests or per-frame tween creation belong here.
		debug.profilebegin("TPFC.Guide.Render")
		local pos = currentRoot and currentRoot.Parent and currentRoot.Position
		local point = pos and route(pos, target, center, lastStep)
		local delta = point and Vector3.new(point.X - pos.X, 0, point.Z - pos.Z)
		local distance = delta and delta.Magnitude or 0
		local direction = distance > 0.1 and delta / distance or nil
		local alpha = Settings.ReducedMotion and 1 or 1 - math.exp(-22 * math.min(dt, 0.1))
		local camera = workspace.CurrentCamera
		if pos and camera then
			local screen = camera:WorldToViewportPoint(target + Vector3.new(0, 2, 0))
			local aim = Vector2.new(screen.X - camera.ViewportSize.X / 2, screen.Y - camera.ViewportSize.Y / 2)
			if screen.Z < 0 then
				aim = -aim
			end
			local angle = math.deg(math.atan2(aim.X, -aim.Y))
			local turn = compassAngle and ((angle - compassAngle + 180) % 360 - 180) or 0
			compassAngle = compassAngle and compassAngle + turn * alpha or angle
			compass.Rotation = compassAngle
		end
		local low = Settings.LowVFX()
		local now = os.clock()
		local guideHere = pos and lastStep == 2 and Config.InThrowZone(pos)
		compass.Visible = pos ~= nil and not guideHere and (pos - target).Magnitude > 7
		for i, pair in ipairs(parts) do
			local sample = samples[i]
			local show = direction and not guideHere and i <= (low and 4 or 7) and distance > i * 4.2
			local opacity = show and (Settings.ReducedMotion or low) and 0.18
				or show and (0.19 + 0.035 * math.sin(now * 2.5 - i * 0.5))
				or 1
			sample.opacity += (opacity - sample.opacity) * alpha
			if math.abs(sample.opacity - opacity) < 0.002 then
				sample.opacity = opacity
			end
			if show then
				local at = pos + direction * (i * 4.2)
				local goal =
					CFrame.lookAt(Vector3.new(at.X, sample.y, at.Z), Vector3.new(at.X, sample.y, at.Z) + direction)
				local previous = sample.cf
				-- Teleports/step changes start a fresh trail rather than sweeping arrows across the map.
				if not previous or (previous.Position - goal.Position).Magnitude > 12 then
					sample.cf = goal
				else
					sample.cf = previous:Lerp(goal, alpha)
				end
				local written = sample.written
				if
					not written
					or (written.Position - sample.cf.Position).Magnitude > 0.002
					or written.LookVector:Dot(sample.cf.LookVector) < 0.99999
				then
					sample.written = sample.cf
					for _, item in ipairs(pair) do
						item.part.CFrame = sample.cf
							* CFrame.new(item.side * 0.4, 0, 0.4)
							* CFrame.Angles(0, item.side * math.pi / 4, 0)
					end
				end
			end
			for _, item in ipairs(pair) do
				if math.abs(item.part.Transparency - sample.opacity) > 0.002 then
					item.part.Transparency = sample.opacity
				end
			end
		end
		debug.profileend()
	end
	local function visibility(show)
		if show == active then
			return
		end
		active = show
		if panelTween then
			panelTween:Cancel()
		end
		panel.Visible = show
		if show then
			lastProbe = nil
			groundProbe()
			panel.Position = panelPosition + UDim2.fromOffset(0, Settings.ReducedMotion and 0 or 8)
			panelTween = K.tween(panel, 0.18, { Position = panelPosition })
			RunService:BindToRenderStep("TPFC_KnightGuide", Enum.RenderPriority.Camera.Value + 1, render)
			rendered = true
		else
			RunService:UnbindFromRenderStep("TPFC_KnightGuide")
			rendered = false
			compassAngle = nil
			hideArrows()
		end
	end
	local function update()
		debug.profilebegin("TPFC.Guide.Update")
		local step = State.Data.TutorialStep or 5
		currentRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local show = State.Loaded
			and step >= 1
			and step < 5
			and currentRoot ~= nil
			and HUD.Gui.Enabled
			and not HUD.AnyPanelOpen()
			and not TC.IsFollowing()
			and not player.PlayerGui:FindFirstChild("Intro")
		refreshStep(step)
		if show then
			layout()
			currentBase = base()
			center = currentBase and currentBase:FindFirstChild("Center")
			target = targetFor(step, currentBase)
			show = target ~= nil
			waypoint = target and route(currentRoot.Position, target, center, step)
		end
		visibility(show)
		if show then
			groundProbe()
			if not busy then
				local close = (currentRoot.Position - target).Magnitude < (step == 3 and 13 or 18)
				local canAdvance = (step == 1 and Config.InThrowZone(currentRoot.Position))
					or (step == 2 and #State.Data.Creatures > 0)
					or ((step == 3 or step == 4) and close)
				if canAdvance then
					busy = true
					task.spawn(function()
						State.Request("Tutorial", "Advance:" .. step)
						task.wait(0.7)
						busy = false
					end)
				end
			end
		end
		debug.profileend()
	end
	-- State/menu changes react immediately; only proximity checks run at 10 Hz.
	local connections = {}
	table.insert(connections, State.Changed:Connect(update))
	table.insert(connections, player:GetAttributeChangedSignal("TPFC_MenuOpen"):Connect(update))
	table.insert(connections, HUD.Gui:GetPropertyChangedSignal("Enabled"):Connect(update))
	table.insert(
		connections,
		Settings.Changed.Event:Connect(function()
			lastProbe = nil
			if Settings.ReducedMotion then
				if panelTween then
					panelTween:Cancel()
				end
				if textTween then
					textTween:Cancel()
				end
				text.TextTransparency = 0
				if panelPosition then
					panel.Position = panelPosition
				end
			end
			update()
		end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt)
			knightElapsed += dt
			if knightElapsed >= 1 then
				knightElapsed %= 1
				attachKnight()
			end
			elapsed += dt
			if elapsed >= 0.1 then
				elapsed %= 0.1
				if (State.Data.TutorialStep or 5) < 5 then
					update()
				end
			end
		end)
	)
	panel.Destroying:Connect(function()
		if rendered then
			RunService:UnbindFromRenderStep("TPFC_KnightGuide")
		end
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		if prompt then
			prompt:Destroy()
		end
		arrows:Destroy()
		Guide.Started = false
	end)
	update()
end
return Guide
