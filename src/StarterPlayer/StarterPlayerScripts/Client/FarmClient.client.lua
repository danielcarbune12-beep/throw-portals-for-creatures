-- FarmClient: client side of the courtyard farm (server: FarmService).
-- Location: StarterPlayer > StarterPlayerScripts > Client > FarmClient (LocalScript)
--  * Shows only YOUR courtyard's farm prompts (beds, stand, board, chest); others' stay hidden.
--  * Turns FarmFx events into in-world floating text bursts with sound. No screen toasts (DESIGN.md).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local okSounds, Sounds = pcall(require, script.Parent:WaitForChild("Sounds"))
local function play(name, vol)
	if okSounds and Sounds and Sounds.Play then
		pcall(Sounds.Play, name, vol)
	end
end

---------------------------------------------------------------- prompt ownership
local prompts = {}
local function applyPrompt(p)
	p.Enabled = p:GetAttribute("BaseIndex") == player:GetAttribute("BaseIndex")
end
local function track(inst)
	if inst:IsA("ProximityPrompt") and inst:GetAttribute("FarmPrompt") then
		prompts[inst] = true
		applyPrompt(inst)
		inst.AncestryChanged:Connect(function()
			if not inst:IsDescendantOf(game) then
				prompts[inst] = nil
			end
		end)
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

---------------------------------------------------------------- floating text
local function burst(pos, text, color, size, life)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency, anchor.Size = 1, Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(pos)
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size and size * 9 or 320, size or 44)
	gui.AlwaysOnTop, gui.LightInfluence, gui.MaxDistance = true, 0, 120
	gui.Parent = anchor
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	t.Font, t.TextScaled, t.RichText, t.Text = Enum.Font.GothamBlack, true, true, text
	t.TextColor3 = color or Color3.fromRGB(255, 246, 225)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Color, stroke.Transparency = 2, Color3.fromRGB(40, 28, 52), 0.1
	stroke.Parent = t
	t.Parent = gui
	life = life or 1.8
	TweenService:Create(gui, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	task.delay(life * 0.55, function()
		TweenService:Create(t, TweenInfo.new(life * 0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(life * 0.45), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(anchor, life + 0.2)
end

local function headPos()
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	return head and head.Position + Vector3.new(0, 3.5, 0) or (workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector * 12)
end

local GOLD = Color3.fromRGB(255, 214, 110)
local GREEN = Color3.fromRGB(170, 255, 170)
local VIOLET = Color3.fromRGB(214, 170, 255)
local WHITE = Color3.fromRGB(250, 246, 236)
local MUT = {
	Rainbow = Color3.fromRGB(255, 140, 220),
	Giant = Color3.fromRGB(255, 190, 80),
	Golden = Color3.fromRGB(255, 210, 80),
	Watered = Color3.fromRGB(130, 200, 255),
}

---------------------------------------------------------------- weather (server-wide farm events)
-- Local-only visuals: static particle fields over the lobby and courtyards (not camera-following)
-- and a separate colour grade, so the lobby's own lighting/effects scripts are left untouched.
local Lighting = game:GetService("Lighting")
local okSettings, Settings = pcall(require, script.Parent:WaitForChild("ClientSettings"))
local function lowVfx()
	return okSettings and Settings and Settings.LowVFX and Settings.LowVFX() or false
end
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "FarmWeatherCC"
cc.Parent = Lighting
local NEUTRAL = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }
local LOOKS = {
	Rain = { Brightness = -0.06, Contrast = 0.02, Saturation = -0.18, TintColor = Color3.fromRGB(212, 226, 255) },
	GoldenHour = { Brightness = 0.04, Contrast = 0.04, Saturation = 0.18, TintColor = Color3.fromRGB(255, 230, 192) },
	Starfall = { Brightness = -0.05, Contrast = 0.06, Saturation = 0.05, TintColor = Color3.fromRGB(214, 214, 255) },
	Aurora = { Brightness = 0.02, Contrast = 0.04, Saturation = 0.25, TintColor = Color3.fromRGB(246, 224, 255) },
}
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local weatherFolder

-- Particle fields sit over the local character (offset), re-centred a few times a second (not per
-- frame): a lobby-wide field spreads too thin to read from the player's camera.
local followers = {}
local function field(offset, size, props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency, p.Size, p.CFrame = 1, size, CFrame.new(0, 60, -235) * offset
	p.Parent = weatherFolder
	table.insert(followers, { part = p, offset = offset })
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Bottom
	for k, v in pairs(props) do
		e[k] = v
	end
	if lowVfx() then
		e.Rate = e.Rate * 0.3
	end
	e.Parent = p
	return p, e
end

local function ribbon(cf, len, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Color, p.Transparency = Enum.Material.Neon, color, 0.55
	p.Size, p.CFrame, p.CastShadow = Vector3.new(len, 6, 1), cf, false
	p.Parent = weatherFolder
	TweenService:Create(p, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.8, CFrame = cf * CFrame.new(0, 8, 0) }):Play()
end

local AREA = Vector3.new(120, 1, 120)
task.spawn(function()
	while true do
		task.wait(0.3)
		if #followers > 0 then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local at = root and root.Position or workspace.CurrentCamera.CFrame.Position
			for _, f in ipairs(followers) do
				if f.part.Parent then
					f.part.CFrame = CFrame.new(at.X, at.Y, at.Z) * f.offset
				end
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
	local look = LOOKS[id] or NEUTRAL
	TweenService:Create(cc, TweenInfo.new(3), look):Play()
	if not LOOKS[id] then
		return
	end
	weatherFolder = Instance.new("Folder")
	weatherFolder.Name = "FarmWeatherFx"
	weatherFolder.Parent = workspace
	if id == "Rain" then
		field(CFrame.new(0, 55, 0), AREA, {
			-- tuned in a play test: smaller/softer drops (smoke texture, 0.28) were invisible on camera
			Texture = SPARK, Rate = 2600, Lifetime = NumberRange.new(0.75, 0.85), Speed = NumberRange.new(80, 95),
			Size = NumberSequence.new(0.75), Squash = NumberSequence.new(-2.5),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Color = ColorSequence.new(Color3.fromRGB(220, 236, 255)), Transparency = NumberSequence.new(0.05),
			LightEmission = 0.4, SpreadAngle = Vector2.new(3, 3),
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		})
	elseif id == "GoldenHour" then
		field(CFrame.new(0, 18, 0), AREA, {
			Texture = SPARK, Rate = 60, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(1, 3),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 0) }),
			Color = ColorSequence.new(Color3.fromRGB(255, 214, 120)), LightEmission = 1,
		})
	elseif id == "Starfall" then
		field(CFrame.new(-60, 160, 0) * CFrame.Angles(0, 0, 0.35), Vector3.new(300, 1, 300), {
			Texture = SPARK, Rate = 10, Lifetime = NumberRange.new(2, 2.6), Speed = NumberRange.new(110, 140),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 0.4) }),
			Squash = NumberSequence.new(-2.5), Orientation = Enum.ParticleOrientation.VelocityParallel,
			Color = ColorSequence.new(Color3.fromRGB(255, 246, 210), Color3.fromRGB(255, 190, 90)), LightEmission = 1,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		})
		field(CFrame.new(0, 18, 0), AREA, {
			Texture = SPARK, Rate = 30, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(0.5, 2),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.5), NumberSequenceKeypoint.new(1, 0) }),
			Color = ColorSequence.new(Color3.fromRGB(255, 230, 170)), LightEmission = 1,
		})
	elseif id == "Aurora" then
		local cols = { Color3.fromRGB(255, 120, 210), Color3.fromRGB(120, 255, 190), Color3.fromRGB(170, 130, 255) }
		for k = 1, 3 do
			ribbon(CFrame.new(-60 + k * 40, 210 + k * 14, -380 + k * 60) * CFrame.Angles(0, 0.5 - k * 0.3, 0.15), 520, cols[k])
		end
		field(CFrame.new(0, 18, 0), AREA, {
			Texture = SPARK, Rate = 50, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.5, 2),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.6), NumberSequenceKeypoint.new(1, 0) }),
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, cols[1]), ColorSequenceKeypoint.new(0.5, cols[2]), ColorSequenceKeypoint.new(1, cols[3]) }),
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
FarmFx.OnClientEvent:Connect(function(kind, d)
	d = d or {}
	if kind == "harvest" then
		-- produce goes to the Pantry; mutations are the big moments
		local name = (d.tag and (d.tag .. " ") or "") .. (d.crop or "crop")
		if d.sold then
			burst(d.pos, "Pantry full: sold " .. name .. " +" .. Format.Money(d.sold), GREEN, 34, 2)
			play("Money")
		elseif d.tag == "Rainbow" then
			burst(d.pos, "RAINBOW " .. (d.crop or ""):upper() .. "!", MUT.Rainbow, 72, 3)
			play("Rare")
		elseif d.tag == "Giant" then
			burst(d.pos, "GIANT " .. (d.crop or ""):upper() .. "!", MUT.Giant, 62, 2.6)
			play("Rare", 0.8)
		elseif d.tag == "Golden" then
			burst(d.pos, "+1 Golden " .. (d.crop or ""), MUT.Golden, 46, 2.2)
			play("Rare", 0.6)
		else
			burst(d.pos, "+1 " .. name, d.tag and MUT[d.tag] or GREEN, 36)
			play("Money")
		end
		if d.auto and d.tag then
			burst(d.pos + Vector3.new(0, -1.5, 0), "harvested by your Harvest Spirit", VIOLET, 26, 2.2)
		end
	elseif kind == "mutation" then
		-- rolled at planting: a lucky bed you can now watch grow
		local big = d.mutation == "Rainbow" or d.mutation == "Giant"
		burst(d.pos, (d.mutation or ""):upper() .. " " .. (d.crop or "") .. " sprouted!", MUT[d.mutation] or GOLD, big and 60 or 42, big and 3 or 2.2)
		play(big and "Rare" or "Upgrade", big and 1 or 0.7)
	elseif kind == "almanac" then
		burst(d.pos or headPos(), "NEW IN YOUR ALMANAC: " .. (d.name or ""):upper(), Color3.fromRGB(190, 255, 200), 50, 2.8)
		task.delay(0.5, burst, (d.pos or headPos()) - Vector3.new(0, 1.6, 0),
			tostring(d.count) .. " / " .. tostring(d.total) .. "  ·  +" .. tostring(d.bonus) .. "% crop value forever", WHITE, 30, 2.8)
		play("Upgrade")
	elseif kind == "weather" then
		burst(headPos(), (d.name or "Weather"):upper() .. "!", Color3.fromRGB(170, 220, 255), 66, 3.2)
		task.delay(0.5, burst, headPos() - Vector3.new(0, 1.6, 0), (d.desc or "") .. "  ·  " .. math.floor((d.duration or 0) / 60) .. " min", WHITE, 30, 3.2)
		play("Rare", 0.6)
	elseif kind == "weatherEnd" then
		burst(headPos(), "The weather clears", WHITE, 30, 2)
	elseif kind == "fed" then
		burst(d.pos, "Fed " .. tostring(d.count) .. " food to your pets", GREEN, 40, 2.2)
		if d.wellFed then
			task.delay(0.9, burst, d.pos - Vector3.new(0, 3.2, 0), "Well fed! +20% income for 30 min", GREEN, 34, 2.6)
		end
		if (d.ups or 0) > 0 then
			local line = tostring(d.ups) .. (d.ups == 1 and " level up!" or " level ups!")
			if d.star then
				line ..= "  " .. d.star .. " is Lv " .. tostring(d.level)
			end
			task.delay(0.45, burst, d.pos - Vector3.new(0, 1.6, 0), line, GOLD, 46, 2.6)
			play("Rare", 0.8)
		else
			play("Upgrade")
		end
	elseif kind == "sold" then
		burst(d.pos, "Sold " .. tostring(d.count) .. " produce  +" .. Format.Money(d.amount or 0), GOLD, 46, 2.2)
		play("Money")
	elseif kind == "plant" then
		burst(d.pos, "Planted", WHITE, 30, 1.1)
		play("Click")
	elseif kind == "msg" then
		burst(d.pos or headPos(), d.text or "", WHITE, 32, 2.0)
		play("Click")
	elseif kind == "buy" then
		burst(d.pos or headPos(), d.text or "Bought!", GOLD, 44, 2.0)
		play("Upgrade")
	elseif kind == "level" then
		burst(headPos(), "FARMER LEVEL " .. tostring(d.level) .. "!", GOLD, 70, 3.0)
		local extra = {}
		if d.unlocks and #d.unlocks > 0 then
			table.insert(extra, "New seed: " .. table.concat(d.unlocks, ", "))
		end
		if d.spirit then
			table.insert(extra, "Harvest Spirit for hire at the Farm Stand")
		end
		if #extra > 0 then
			task.delay(0.5, burst, headPos() - Vector3.new(0, 1.5, 0), table.concat(extra, "  ·  "), VIOLET, 32, 3.0)
		end
		play("Rare")
	elseif kind == "bountyReady" then
		burst(headPos(), "Bounty complete! Claim it at your board", GOLD, 34, 2.4)
		play("Upgrade")
	elseif kind == "bounty" then
		burst(d.pos or headPos(), "+" .. Format.Money(d.amount or 0) .. "  ·  " .. tostring(d.count) .. (d.count == 1 and " bounty" or " bounties"), GOLD, 50, 2.4)
		play("Rare", 0.8)
	elseif kind == "daily" then
		burst(d.pos or headPos(), "DAY " .. tostring(d.day) .. " GIFT!  +" .. Format.Money(d.amount or 0), GOLD, 60, 2.8)
		if (d.streak or 0) > 1 then
			task.delay(0.4, burst, (d.pos or headPos()) - Vector3.new(0, 1.6, 0), tostring(d.streak) .. "-day streak", VIOLET, 30, 2.6)
		end
		play("Rare")
	end
end)
