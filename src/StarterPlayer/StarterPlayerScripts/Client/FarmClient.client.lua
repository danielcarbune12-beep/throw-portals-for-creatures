-- FarmClient: client side of the courtyard farm (server: FarmService).
-- Location: StarterPlayer > StarterPlayerScripts > Client > FarmClient (LocalScript)
--  * Shows only YOUR courtyard's farm prompts (beds, feeding, board, chest); others' stay hidden.
--  * Updates permanent physical farm signs. No screen toasts or character message bursts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local okSounds, Sounds = pcall(require, script.Parent:WaitForChild("Sounds"))
local function play(name, vol)
	if okSounds and Sounds and Sounds.Play then
		pcall(Sounds.Play, name, vol)
	end
end

---------------------------------------------------------------- prompt ownership
local prompts, signs = {}, {}
local function applyPrompt(p)
	local index = player:GetAttribute("BaseIndex")
	local owned = index ~= nil and p:GetAttribute("BaseIndex") == index
	local enabled = owned and p:GetAttribute("FarmAvailable") ~= false
	if p.Enabled ~= enabled then
		p.Enabled = enabled
	end
end
local function track(inst)
	if inst:IsA("TextLabel") and inst:GetAttribute("FarmFeedback") and not signs[inst] then
		local connection
		connection = inst.AncestryChanged:Connect(function()
			if not inst:IsDescendantOf(game) then
				signs[inst] = nil
				connection:Disconnect()
			end
		end)
		signs[inst] = connection
	end
	if inst:IsA("ProximityPrompt") and inst:GetAttribute("FarmPrompt") and not prompts[inst] then
		local connections = {}
		prompts[inst] = connections
		applyPrompt(inst)
		for _, attribute in { "FarmAvailable", "BaseIndex" } do
			table.insert(
				connections,
				inst:GetAttributeChangedSignal(attribute):Connect(function()
					applyPrompt(inst)
				end)
			)
		end
		table.insert(
			connections,
			inst.AncestryChanged:Connect(function()
				if not inst:IsDescendantOf(game) then
					prompts[inst] = nil
					for _, connection in connections do
						connection:Disconnect()
					end
				end
			end)
		)
	end
end
task.spawn(function()
	local bases = workspace:WaitForChild("Bases", 60)
	if not bases then
		return
	end
	for _, d in ipairs(bases:GetDescendants()) do
		track(d)
	end
	bases.DescendantAdded:Connect(track)
end)
player:GetAttributeChangedSignal("BaseIndex"):Connect(function()
	for p in pairs(prompts) do
		applyPrompt(p)
	end
end)

local feedbackVersion = setmetatable({}, { __mode = "k" })
local function feedback(station, text)
	if station == "Stand" then
		station = "Pantry"
	end
	local ownedFarm
	for prompt in pairs(prompts) do
		if prompt:GetAttribute("BaseIndex") == player:GetAttribute("BaseIndex") then
			ownedFarm = prompt:FindFirstAncestor("Farm")
			break
		end
	end
	if not ownedFarm then
		return
	end
	for label in pairs(signs) do
		if not label.Parent then
			signs[label] = nil
		elseif label:IsDescendantOf(ownedFarm) and label:GetAttribute("FarmFeedback") == station then
			local version = (feedbackVersion[label] or 0) + 1
			feedbackVersion[label] = version
			label.Text = text
			task.delay(8, function()
				if label.Parent and feedbackVersion[label] == version then
					label.Text = label:GetAttribute("DefaultText") or ""
				end
			end)
		end
	end
end

---------------------------------------------------------------- weather (server-wide farm events)
-- Local weather fields follow the player at low frequency. SceneLighting owns the grade.
local okSettings, Settings = pcall(require, script.Parent:WaitForChild("ClientSettings"))
local function lowVfx()
	return okSettings and Settings and Settings.LowVFX and Settings.LowVFX() or false
end
-- SceneLighting composes weather into the biome grade. Farming owns only
-- its weather geometry, so weather and scene grading cannot fight each other.
local LOOKS = { Rain = true, GoldenHour = true, Starfall = true, Aurora = true }
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local weatherFolder

-- Particle fields sit over the local character (offset), re-centred a few times a second (not per
-- frame): a lobby-wide field spreads too thin to read from the player's camera.
local followers = {}
local shelterHall, shelterFloor
local function weatherOrigin()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	return root and root.Position or (camera and camera.CFrame.Position)
end

local function forgeSheltered(at)
	local map = workspace:FindFirstChild("Map")
	local start = map and map:FindFirstChild("Start")
	local hall = start and start:FindFirstChild("GreatForgeHall")
	if hall ~= shelterHall then
		shelterHall, shelterFloor = hall, nil
	end
	if not hall or hall:GetAttribute("HallStyle") ~= "MedievalForge" or not hall:GetAttribute("TPFCGenerated") then
		return false
	end
	if not shelterFloor or not shelterFloor:IsDescendantOf(hall) then
		shelterFloor = hall:FindFirstChild("HallFoundation", true)
	end
	if not shelterFloor or not shelterFloor:IsA("BasePart") then
		return false
	end
	-- The slate roof covers this footprint; its lowest edge is 22 studs above the floor.
	-- Test local space so a moved/rotated hall works without raycasting thousands of details.
	local p = shelterFloor.CFrame:PointToObjectSpace(at)
	local size = shelterFloor.Size
	return math.abs(p.X) < size.X / 2 - 0.5 and math.abs(p.Z) < size.Z / 2 - 0.5 and p.Y >= size.Y / 2 and p.Y < 21
end

local function updateWeatherField(f, at, sheltered)
	if not f.part.Parent then
		return
	end
	if at then
		f.part.CFrame = CFrame.new(at) * f.offset
	end
	local enabled = at ~= nil and not sheltered
	if f.emitter.Enabled ~= enabled then
		f.emitter.Enabled = enabled
		if not enabled then
			-- Clear existing drops once on entering the hall, rather than letting them cross the roof.
			f.emitter:Clear()
		end
	end
end

local function field(offset, size, props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency, p.Size = 1, size
	p.Parent = weatherFolder
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Bottom
	for k, v in pairs(props) do
		e[k] = v
	end
	if lowVfx() then
		e.Rate = 0
	end
	e.Parent = p
	local f = { part = p, offset = offset, emitter = e }
	local at = weatherOrigin()
	updateWeatherField(f, at, at ~= nil and forgeSheltered(at))
	table.insert(followers, f)
	return p, e
end

local function ribbon(cf, len, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Color, p.Transparency = Enum.Material.Neon, color, 0.55
	p.Size, p.CFrame, p.CastShadow = Vector3.new(len, 6, 1), cf, false
	p.Parent = weatherFolder
	TweenService:Create(
		p,
		TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.8, CFrame = cf * CFrame.new(0, 8, 0) }
	):Play()
end

local AREA = Vector3.new(120, 1, 120)
task.spawn(function()
	while script.Parent do
		task.wait(0.3)
		if #followers > 0 then
			local at = weatherOrigin()
			local sheltered = at ~= nil and forgeSheltered(at)
			for _, f in ipairs(followers) do
				updateWeatherField(f, at, sheltered)
			end
		end
	end
end)
local function applyWeather(id)
	if weatherFolder then
		weatherFolder:Destroy()
		weatherFolder = nil
	end
	table.clear(followers)
	if not LOOKS[id] or lowVfx() then
		return
	end
	weatherFolder = Instance.new("Folder")
	weatherFolder.Name = "FarmWeatherFx"
	weatherFolder.Parent = workspace
	if id == "Rain" then
		field(CFrame.new(0, 55, 0), AREA, {
			-- tuned in a play test: smaller/softer drops (smoke texture, 0.28) were invisible on camera
			Texture = SPARK,
			Rate = 700,
			Lifetime = NumberRange.new(0.75, 0.85),
			Speed = NumberRange.new(80, 95),
			Size = NumberSequence.new(0.75),
			Squash = NumberSequence.new(-2.5),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Color = ColorSequence.new(Color3.fromRGB(220, 236, 255)),
			Transparency = NumberSequence.new(0.05),
			LightEmission = 0.4,
			SpreadAngle = Vector2.new(3, 3),
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		})
	elseif id == "GoldenHour" then
		field(CFrame.new(0, 18, 0), AREA, {
			Texture = SPARK,
			Rate = 18,
			Lifetime = NumberRange.new(5, 8),
			Speed = NumberRange.new(1, 3),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.6),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 214, 120)),
			LightEmission = 1,
		})
	elseif id == "Starfall" then
		field(CFrame.new(-60, 160, 0) * CFrame.Angles(0, 0, 0.35), Vector3.new(300, 1, 300), {
			Texture = SPARK,
			Rate = 10,
			Lifetime = NumberRange.new(2, 2.6),
			Speed = NumberRange.new(110, 140),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 0.4) }),
			Squash = NumberSequence.new(-2.5),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Color = ColorSequence.new(Color3.fromRGB(255, 246, 210), Color3.fromRGB(255, 190, 90)),
			LightEmission = 1,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		})
		field(CFrame.new(0, 18, 0), AREA, {
			Texture = SPARK,
			Rate = 30,
			Lifetime = NumberRange.new(4, 6),
			Speed = NumberRange.new(0.5, 2),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.4, 0.5),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Color = ColorSequence.new(Color3.fromRGB(255, 230, 170)),
			LightEmission = 1,
		})
	elseif id == "Aurora" then
		local cols = { Color3.fromRGB(255, 120, 210), Color3.fromRGB(120, 255, 190), Color3.fromRGB(170, 130, 255) }
		for k = 1, (okSettings and Settings.ReducedMotion and 0 or 3) do
			ribbon(
				CFrame.new(-60 + k * 40, 210 + k * 14, -380 + k * 60) * CFrame.Angles(0, 0.5 - k * 0.3, 0.15),
				520,
				cols[k]
			)
		end
		field(CFrame.new(0, 18, 0), AREA, {
			Texture = SPARK,
			Rate = 14,
			Lifetime = NumberRange.new(4, 7),
			Speed = NumberRange.new(0.5, 2),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.4, 0.6),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, cols[1]),
				ColorSequenceKeypoint.new(0.5, cols[2]),
				ColorSequenceKeypoint.new(1, cols[3]),
			}),
			LightEmission = 1,
		})
	end
end
applyWeather(workspace:GetAttribute("FarmWeather"))
workspace:GetAttributeChangedSignal("FarmWeather"):Connect(function()
	applyWeather(workspace:GetAttribute("FarmWeather"))
end)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FarmFx = Remotes:WaitForChild("FarmFx", 30)
if not FarmFx then
	return
end
if okSettings and Settings.Changed then
	Settings.Changed.Event:Connect(function(key)
		if key == "VFXQuality" or key == "ReducedMotion" or key == "ReducedFlashes" then
			applyWeather(workspace:GetAttribute("FarmWeather"))
		end
	end)
end

FarmFx.OnClientEvent:Connect(function(kind, d)
	d = d or {}
	-- Catch-up can process hundreds of harvests. It updates the Pantry, not a sound/message queue.
	if d.auto then
		return
	end
	if kind == "harvest" then
		local name = (d.tag and (d.tag .. " ") or "") .. (d.crop or "crop")
		feedback(
			"Stand",
			d.sold and ("Pantry full. Sold " .. name .. " for " .. Format.Money(d.sold))
				or (name .. " harvested. Sell crops beside the Great Hall, or feed pets at home.")
		)
		play(d.tag and "Rare" or "Money", 0.5)
	elseif kind == "mutation" then
		feedback(
			"Stand",
			(d.mutation or "Lucky")
				.. " "
				.. (d.crop or "crop")
				.. " planted. Its bonus applies to sale value and pet XP."
		)
		play("Upgrade", 0.5)
	elseif kind == "almanac" then
		feedback(
			"Stand",
			"New discovery: "
				.. (d.name or "crop")
				.. ". Almanac "
				.. tostring(d.count)
				.. "/"
				.. tostring(d.total)
				.. ", +"
				.. tostring(d.bonus)
				.. "% crop value and food XP."
		)
	elseif kind == "fed" then
		local detail = d.wellFed and "Well Fed: +20% income for 30 min."
			or ("Meal progress " .. tostring(d.progress or 0) .. "/5 toward Well Fed.")
		if (d.ups or 0) > 0 then
			detail = tostring(d.ups) .. " pet level ups. " .. detail
		end
		feedback(
			"Pantry",
			"Served " .. tostring(d.count) .. " food, " .. tostring(d.remaining or 0) .. " left. " .. detail
		)
		play("Upgrade", 0.6)
	elseif kind == "sold" then
		feedback(
			"Pantry",
			"Sold "
				.. tostring(d.count)
				.. " produce for "
				.. Format.Money(d.amount or 0)
				.. ". Your next harvest goes to the Pantry."
		)
		play("Money", 0.6)
	elseif kind == "msg" or kind == "buy" then
		local station = "Stand"
		local closest = math.huge
		if d.pos then
			for label in pairs(signs) do
				local plate = label.Parent and label.Parent.Parent
				if plate and plate:IsA("BasePart") then
					local distance = (plate.Position - d.pos).Magnitude
					if distance < closest then
						closest, station = distance, label:GetAttribute("FarmFeedback")
					end
				end
			end
		end
		feedback(station, d.text or "")
		play(kind == "buy" and "Upgrade" or "Click", 0.5)
	elseif kind == "level" then
		local extra = d.unlocks and #d.unlocks > 0 and (" Unlocked " .. table.concat(d.unlocks, ", ") .. ".") or ""
		feedback("Stand", "Farmer level " .. tostring(d.level) .. "." .. extra)
		play("Upgrade", 0.6)
	elseif kind == "bounty" then
		feedback(
			"Bounty",
			"Claimed "
				.. tostring(d.count)
				.. " rewards: "
				.. Format.Money(d.amount or 0)
				.. ". New jobs are on the board."
		)
		play("Money", 0.6)
	elseif kind == "daily" then
		feedback(
			"Daily",
			"Day " .. tostring(d.day) .. ": " .. Format.Money(d.amount or 0) .. " collected. Next gift in 20 hours."
		)
		play("Money", 0.6)
	end
end)
