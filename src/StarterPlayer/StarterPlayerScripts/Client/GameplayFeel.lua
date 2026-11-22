-- Quiet, state-driven feedback around the complete play loop. No extra HUD buttons.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Format = require(RS.Shared.Format)
local State = require(script.Parent.ClientState)
local Settings = require(script.Parent.ClientSettings)
local Sounds = require(script.Parent.Sounds)
local Effects = require(script.Parent.Effects)
local Feel = {}
local player = Players.LocalPlayer
local started = false
function Feel.Start(TC, HUD)
	if started then
		return
	end
	started = true
	local route = Instance.new("Folder")
	route.Name = "FirstThrowGuide"
	route.Parent = Effects.Folder
	local markers = {}
	for i = 1, 4 do
		local p = Instance.new("Part")
		p.Name = "ApproachMarker"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.new(1.3, 0.035, 1.3)
		p.Color = Color3.fromRGB(241, 202, 115)
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = CFrame.new(0, 0.29, -55 + i * 4.6) * CFrame.Angles(0, math.pi / 4, 0)
		p.Transparency = 1
		p.Parent = route
		markers[i] = p
	end
	local lastCount, firstCatchHint, readyHint = nil, false, false
	local lastStep, lastZone = 0, nil
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local active = State.Loaded
			and #State.Data.Creatures == 0
			and root
			and root.Position.Z < Config.ThrowZone.minZ
			and root.Position.Z > -125
			and not TC.Charging
			and not TC.Submitting
			and not TC.MyThrow
			and not HUD.AnyPanelOpen()
		for i, p in markers do
			p.Transparency = active
					and (Settings.ReducedMotion and 0.4 or 0.45 + 0.18 * math.sin(os.clock() * 2 - i * 0.7))
				or 1
		end
		if not State.Loaded then
			return
		end
		if HUD.InZone and not readyHint and #State.Data.Creatures == 0 and not HUD.AnyPanelOpen() then
			readyHint = true
			HUD.Notify("Hold to charge. Release in the gold zone for a perfect throw.", "info")
		end
		local count = #State.Data.Creatures
		if lastCount == 0 and count > lastCount and not firstCatchHint then
			firstCatchHint = true
			task.delay(4, function()
				if not HUD.AnyPanelOpen() then
					HUD.Notify("Your garden earns coins. Walk up to its treasury to collect them.", "info")
				end
			end)
		end
		lastCount = count
		-- One progress notification when training or upgrades newly unlock a zone's reach.
		local max = (State.Data.MaxDistance or 40) * 1.15
		local zone = "Forest"
		for _, id in Config.WorldOrder do
			if max >= Config.ZoneBounds[id][1] then
				zone = id
			end
		end
		if lastZone and zone ~= lastZone and max > lastStep then
			HUD.Notify(Config.Worlds[zone].name .. " is now within throw range.", "success")
		end
		lastZone, lastStep = zone, max
	end)
end
local pendingAmount, pendingPosition = 0, nil
local moneyScheduled = false
local lastMoneySound = -10
function Feel.Money(amount, position)
	pendingAmount += amount
	pendingPosition = position
	if moneyScheduled then
		return
	end
	moneyScheduled = true
	task.delay(0.12, function()
		local value, pos = pendingAmount, pendingPosition
		pendingAmount, pendingPosition, moneyScheduled = 0, nil, false
		if not pos or value <= 0 then
			return
		end
		if os.clock() - lastMoneySound > 0.65 then
			Sounds.Play("Money")
			lastMoneySound = os.clock()
		end
		Effects.Coins(pos, Settings.LowVFX() and 3 or math.clamp(math.floor(math.log10(value + 1) * 3), 4, 12))
		Effects.FloatingText(pos + Vector3.new(0, 3, 0), "+" .. Format.Money(value), Color3.fromRGB(159, 223, 180), 1)
		if not Settings.LowVFX() then
			Effects.Burst(pos + Vector3.new(0, 0.5, 0), Color3.fromRGB(241, 202, 115), 8, 5, 0.25)
		end
	end)
end
return Feel
