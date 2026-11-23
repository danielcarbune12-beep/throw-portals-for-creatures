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
	local panel = K.surface(HUD.Root, "KnightGuide", UDim2.fromOffset(430, 120), nil, T.Panel)
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Visible = false
	local portrait = K.viewport(Knight.Build(), UDim2.fromOffset(74, 96), false, false, true)
	portrait.Position = UDim2.fromOffset(6, 10)
	portrait.Parent = panel
	local title = K.text(panel, "Sir Rowan", 90, 10, -140, 22, 17, T.Text, true)
	title.FontFace = T.TitleFace
	local text = K.text(panel, "", 90, 35, -104, 71, 14, T.Text)
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
	local function route(pos, target, b, step)
		local center = b and b:FindFirstChild("Center")
		if center then
			local z = center.Position.Z
			if step == 3 then
				if math.abs(pos.X) > 34 and math.abs(pos.Z - z) < 35 then
					return target
				end
				if math.abs(pos.Z - z) > 7 then
					return Vector3.new(0, 0.8, z)
				end
				return target
			elseif math.abs(pos.X) > 33 and math.abs(pos.Z - z) < 35 then
				if math.abs(pos.Z - z) > 4 then
					return Vector3.new(pos.X, 0.8, z)
				end
				return Vector3.new(0, 0.8, z)
			end
		end
		if math.abs(pos.X) > 8 and math.abs(pos.Z - target.Z) > 8 then
			return Vector3.new(0, 0.8, pos.Z)
		end
		return target
	end
	local function attachKnight()
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
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.12 then
			return
		end
		elapsed = 0
		local step = State.Data.TutorialStep or 5
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local visible = State.Loaded
			and step < 5
			and root ~= nil
			and HUD.Gui.Enabled
			and not HUD.AnyPanelOpen()
			and not TC.IsFollowing()
			and not player.PlayerGui:FindFirstChild("Intro")
		panel.Visible = visible
		panel:SetAttribute("GuideStep", step)
		local scale = HUD.Root:FindFirstChildOfClass("UIScale")
		local size = HUD.Root.AbsoluteSize / (scale and scale.Scale or 1)
		local compact = HUD.Compact
		panel.AnchorPoint = compact and Vector2.new(0.5, 1) or Vector2.new(0, 1)
		panel.Position = compact and UDim2.new(0.5, 0, 1, -12) or UDim2.new(0, 90, 1, -16)
		panel.Size =
			UDim2.fromOffset(compact and math.min(416, math.max(280, size.X - 270)) or 430, compact and 84 or 120)
		portrait.Size = UDim2.fromOffset(compact and 54 or 74, compact and 64 or 96)
		title.Position = UDim2.fromOffset(compact and 66 or 90, 8)
		title.Size = UDim2.new(1, compact and -124 or -148, 0, 22)
		title.TextSize = compact and 14 or 17
		title.Text = "Sir Rowan · " .. math.min(step, 4) .. "/4"
		text.Position = UDim2.fromOffset(compact and 66 or 90, compact and 30 or 34)
		text.Size = UDim2.new(1, compact and -76 or -104, 1, compact and -34 or -40)
		text.TextSize = compact and 12 or 14
		text.Text = messages[step] or ""
		panel:SetAttribute("StepTitle", titles[step] or "Complete")
		attachKnight()
		local b = base()
		local target = root and targetFor(step, b)
		if visible and target then
			local camera = workspace.CurrentCamera
			local screen = camera:WorldToViewportPoint(target + Vector3.new(0, 2, 0))
			local delta2 = Vector2.new(screen.X - camera.ViewportSize.X / 2, screen.Y - camera.ViewportSize.Y / 2)
			if screen.Z < 0 then
				delta2 = -delta2
			end
			compass.Rotation = math.deg(math.atan2(delta2.X, -delta2.Y))
			compass:SetAttribute("AccessibleLabel", titles[step])
		end
		local point = visible and target and route(root.Position, target, b, step)
		local delta = point and Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
		for i, pair in ipairs(parts) do
			local show = visible and delta and delta.Magnitude > i * 4.2
			for _, item in ipairs(pair) do
				item.part.Transparency = show
						and (Settings.ReducedMotion and 0.12 or (0.15 + 0.1 * math.sin(os.clock() * 2.5 - i * 0.5)))
					or 1
				if show then
					local pos = root.Position + delta.Unit * (i * 4.2)
					local y = (math.abs(pos.X) < 24 and pos.Z > -272 and pos.Z < -200) and 0.85 or 0.65
					local center = b and b:FindFirstChild("Center")
					if center and math.abs(pos.X) > 29 and math.abs(pos.Z - center.Position.Z) < 34 then
						y = 1.15
					end
					if step == 3 and target and (Vector3.new(pos.X, target.Y, pos.Z) - target).Magnitude < 7 then
						y = 1.8
					end
					pos = Vector3.new(pos.X, y, pos.Z)
					item.part.CFrame = CFrame.lookAt(pos, pos + delta.Unit)
						* CFrame.new(item.side * 0.4, 0, 0.4)
						* CFrame.Angles(0, item.side * math.pi / 4, 0)
				end
			end
		end
		if visible and not busy then
			local close = target and (root.Position - target).Magnitude < (step == 3 and 13 or 18)
			local canAdvance = (step == 1 and Config.InThrowZone(root.Position))
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
	end)
end
return Guide
