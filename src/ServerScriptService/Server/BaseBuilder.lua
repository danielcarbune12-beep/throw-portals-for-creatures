-- BaseBuilder: builds the 8 player bases (with a personal gym each) and their decorations.
-- Location: ServerScriptService > Server > BaseBuilder (ModuleScript)
--
-- Layout of one base (local space, -Z = entrance facing the street):
--   entrance gateway + stone path -> central fountain with a ring of glowing pet slots
--   front-left: money collect pad      front-right: personal GYM
--   back-left:  pet cottage            back-right:  pond
--   string lights between the four corner lamps; pets roam the whole plot

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local BaseBuilder = {}
BaseBuilder.Bases = {}

local HALF = 34
local SLOT_RADIUS = 14
local MAX_SLOTS = 24
local COLLECT_POS = Vector3.new(-19, 0, -21)
local DECOR_SPOTS = {
	Vector3.new(-30, 0, -4), Vector3.new(30, 0, -4), Vector3.new(-30, 0, 9), Vector3.new(30, 0, 9),
	Vector3.new(-7, 0, 29), Vector3.new(7, 0, 29), Vector3.new(0, 0, 22), Vector3.new(0, 22, 4),
}
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

---------------------------------------------------------------- helpers
local function part(parent, size, cf, color, mat, collide, shape, transp)
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.Transparency = transp or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function sphereMesh(p) local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p; return p end
local function ball(parent, d, cf, color, mat, collide) return sphereMesh(part(parent, Vector3.new(d, d, d), cf, color, mat, collide)) end
local function vcylCF(cf, h, d) return cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(h, d, d) end
local function cyl(parent, cf, h, d, color, mat, collide, transp)
	local c, s = vcylCF(cf, h, d)
	return part(parent, s, c, color, mat, collide, Enum.PartType.Cylinder, transp)
end
local function light(p, color, range, b) local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = b or 1.4; l.Parent = p; return l end

local function billboard(adornee, text, size, offset, color, maxDist)
	local bb = Instance.new("BillboardGui")
	bb.Size = size or UDim2.fromScale(8, 2)
	bb.StudsOffset = offset or Vector3.new(0, 4, 0)
	bb.MaxDistance = maxDist or 140
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Label"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.RichText = true
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = Color3.fromRGB(30, 20, 40); st.Parent = t
	t.Parent = bb
	bb.Parent = adornee
	return t
end

---------------------------------------------------------------- one base
local function buildBase(index)
	local side = (index <= 4) and -1 or 1
	local row = (index - 1) % 4
	local pos = Vector3.new(side * 63, 0, -84 - row * 76)
	local cf = CFrame.lookAt(pos, Vector3.new(0, 0, pos.Z)) -- -Z faces the street (entrance)
	local L = function(x, y, z) return cf * CFrame.new(x, y, z) end

	local model = Instance.new("Model")
	model.Name = "Base" .. index

	-- foundation + grass floor
	local stone = Color3.fromRGB(210, 205, 198)
	part(model, Vector3.new(HALF * 2 + 3, 1.2, HALF * 2 + 3), L(0, 0.3, 0), stone, Enum.Material.Cobblestone)
	local floor = part(model, Vector3.new(HALF * 2, 1, HALF * 2), L(0, 0.5, 0), Color3.fromRGB(120, 200, 95), Enum.Material.Grass)
	floor.Name = "Floor"
	model.PrimaryPart = floor

	-- flowering hedges (gap at the entrance)
	local hedgeCol = Color3.fromRGB(70, 155, 75)
	local function hedge(hcf, len)
		ball(model, 1, hcf * CFrame.new(0, 3, 0), hedgeCol, Enum.Material.Grass).Size = Vector3.new(len, 5, 4)
		for k = 1, math.floor(len / 4) do
			ball(model, 1, hcf * CFrame.new(-len / 2 + k * 4 - 2, 5.4, (k % 2 == 0) and 1.2 or -1.2), Color3.fromHSV((k * 0.17) % 1, 0.5, 1), nil, false)
		end
	end
	hedge(L(0, 0.5, HALF), HALF * 2)
	hedge(L(-HALF, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0), HALF * 2)
	hedge(L(HALF, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0), HALF * 2)
	for _, s in ipairs({ -1, 1 }) do hedge(L(s * (HALF / 2 + 5), 0.5, -HALF), HALF - 10) end

	-- ENTRANCE GATEWAY: crystal pillars + rainbow arch + name sign
	for _, s in ipairs({ -1, 1 }) do
		part(model, Vector3.new(3.4, 14, 3.4), L(s * 8, 7.5, -HALF), stone, Enum.Material.Marble)
		local crystal = part(model, Vector3.new(2, 4, 2), L(s * 8, 16.5, -HALF) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(170, 120, 255), Enum.Material.Neon, false)
		light(crystal, Color3.fromRGB(180, 140, 255), 24, 2)
	end
	for i = 0, 16 do
		local a = i / 16 * math.pi
		ball(model, 1.8, L(math.cos(a) * 8, 18 + math.sin(a) * 5, -HALF), Color3.fromHSV(i / 16, 0.55, 1), Enum.Material.Neon, false)
	end
	local signBoard = part(model, Vector3.new(14, 3.4, 0.6), L(0, 12.5, -HALF), Color3.fromRGB(255, 248, 230), Enum.Material.SmoothPlastic)
	signBoard.Name = "Sign"
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(480, 110)
	sg.LightInfluence = 0
	local sl = Instance.new("TextLabel")
	sl.Name = "Owner"
	sl.Size = UDim2.fromScale(1, 1)
	sl.BackgroundTransparency = 1
	sl.Font = Enum.Font.FredokaOne
	sl.TextScaled = true
	sl.TextColor3 = Color3.fromRGB(110, 60, 170)
	sl.Text = "Empty Base"
	sl.Parent = sg
	sg.Parent = signBoard
	local sg2 = sg:Clone(); sg2.Face = Enum.NormalId.Back; sg2.Parent = signBoard
	local incomeLabel = billboard(signBoard, "+$0/s", UDim2.fromScale(12, 2.4), Vector3.new(0, 9, 0), Color3.fromRGB(130, 255, 150))

	-- stone path from the entrance to the fountain
	part(model, Vector3.new(6, 0.2, HALF - 6), L(0, 1.05, -HALF / 2 - 3), Color3.fromRGB(205, 195, 180), Enum.Material.Cobblestone, false)
	for z = -HALF + 4, -10, 6 do
		for _, s in ipairs({ -1, 1 }) do
			ball(model, 0.9, L(s * 3.6, 1.4, z), Color3.fromRGB(255, 220, 140), Enum.Material.Neon, false)
		end
	end

	-- CENTRAL FOUNTAIN with a floating income crystal
	cyl(model, L(0, 1, 0), 1.4, 12, stone, Enum.Material.Marble, true)
	cyl(model, L(0, 2.3, 0), 0.2, 10.6, Color3.fromRGB(90, 200, 255), Enum.Material.Glass, false, 0.25)
	cyl(model, L(0, 1, 0), 5, 1.8, stone, Enum.Material.Marble, true)
	local crystal = part(model, Vector3.new(2.6, 4.6, 2.6), L(0, 10, 0) * CFrame.Angles(0, math.rad(45), math.rad(10)), Color3.fromRGB(120, 255, 170), Enum.Material.Neon, false)
	crystal.Name = "IncomeCrystal"
	light(crystal, Color3.fromRGB(120, 255, 170), 26, 2)
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = SPARKLE
	spray.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255))
	spray.Rate = 25; spray.Speed = NumberRange.new(6, 9); spray.SpreadAngle = Vector2.new(20, 20)
	spray.Acceleration = Vector3.new(0, -18, 0); spray.Lifetime = NumberRange.new(0.8, 1.2); spray.LightEmission = 1
	spray.Size = NumberSequence.new(0.5, 0.1)
	local sprayAnchor = part(model, Vector3.new(0.2, 0.2, 0.2), L(0, 6.2, 0), Color3.new(1, 1, 1), nil, false, nil, 1)
	spray.Parent = sprayAnchor
	local crystalLabel = billboard(crystal, "", UDim2.fromScale(14, 3.2), Vector3.new(0, 4.5, 0), Color3.fromRGB(200, 255, 210), 90)

	-- glowing pet slots in a ring around the fountain
	local slots = {}
	local slotFolder = Instance.new("Folder"); slotFolder.Name = "Slots"; slotFolder.Parent = model
	for i = 1, MAX_SLOTS do
		local a = (i - 1) / MAX_SLOTS * math.pi * 2 + math.pi / 2
		local x, z = math.cos(a) * SLOT_RADIUS, math.sin(a) * SLOT_RADIUS
		local pad = cyl(slotFolder, L(x, 0.98, z), 0.12, 3.2, Color3.fromRGB(245, 242, 250), Enum.Material.Marble, false)
		pad.Name = "Slot" .. i
		pad:SetAttribute("Index", i)
		local ring = cyl(slotFolder, L(x, 0.96, z), 0.12, 3.7, Color3.fromRGB(150, 120, 255), Enum.Material.Neon, false)
		ring.Name = "SlotRing" .. i
		slots[i] = L(x, 1.1, z)
	end

	-- money collect pad (front-left)
	local collect = cyl(model, L(COLLECT_POS.X, 1, COLLECT_POS.Z), 0.4, 9, Color3.fromRGB(80, 230, 120), Enum.Material.Neon, false)
	collect.Name = "CollectPad"
	local collectLabel = billboard(collect, "$0", UDim2.fromScale(10, 2.4), Vector3.new(0, 5, 0), Color3.fromRGB(120, 255, 140))
	billboard(collect, "STEP TO COLLECT", UDim2.fromScale(8, 1), Vector3.new(0, 3, 0), Color3.new(1, 1, 1))
	for k = 1, 7 do
		local a = k * 0.9
		local coin = cyl(model, L(COLLECT_POS.X + math.cos(a) * 2, 1.2 + k * 0.08, COLLECT_POS.Z + math.sin(a) * 2), 0.3, 1.4, Color3.fromRGB(255, 205, 50), Enum.Material.Metal, false)
		coin.CFrame *= CFrame.Angles(0.3, 0, 0)
	end

	-- PERSONAL GYM floor (front-right); the equipment itself is built in Refresh by level
	local g = Config.GymOffset
	local gymPad = part(model, Vector3.new(15, 0.3, 15), L(g.X, 1.1, g.Z), Color3.fromRGB(45, 40, 55), Enum.Material.Rubber, false)
	gymPad.Name = "GymPad"
	for _, e in ipairs({ { 0, 7.5, 15, 0.4 }, { 0, -7.5, 15, 0.4 }, { 7.5, 0, 0.4, 15 }, { -7.5, 0, 0.4, 15 } }) do
		part(model, Vector3.new(e[3], 0.35, e[4]), L(g.X + e[1], 1.3, g.Z + e[2]), Color3.fromRGB(255, 120, 60), Enum.Material.Neon, false)
	end
	local gymSign = part(model, Vector3.new(0.2, 0.2, 0.2), L(g.X, 9, g.Z), Color3.new(1, 1, 1), nil, false, nil, 1)
	local gymLabel = billboard(gymSign, "💪 GYM", UDim2.fromScale(12, 3), Vector3.new(0, 0, 0), Color3.fromRGB(255, 200, 140), 80)

	-- PET COTTAGE (back-left)
	local hc = L(-20, 1, 24)
	part(model, Vector3.new(13, 8, 9), hc * CFrame.new(0, 4, 0), Color3.fromRGB(255, 236, 205), Enum.Material.WoodPlanks)
	for _, s in ipairs({ -1, 1 }) do
		part(model, Vector3.new(14.5, 0.8, 6.5), hc * CFrame.new(0, 10, s * 2.4) * CFrame.Angles(math.rad(s * 38), 0, 0), Color3.fromRGB(220, 90, 110), Enum.Material.Slate)
	end
	part(model, Vector3.new(3, 5, 0.4), hc * CFrame.new(0, 2.5, -4.6), Color3.fromRGB(120, 80, 50), Enum.Material.Wood)
	for _, s in ipairs({ -1, 1 }) do
		local win = part(model, Vector3.new(2.4, 2.4, 0.3), hc * CFrame.new(s * 4, 4.6, -4.6), Color3.fromRGB(255, 220, 120), Enum.Material.Neon, false)
		light(win, Color3.fromRGB(255, 210, 140), 10, 1)
	end
	part(model, Vector3.new(1.6, 4, 1.6), hc * CFrame.new(4, 12, 1.5), Color3.fromRGB(160, 110, 90), Enum.Material.Brick)
	billboard(part(model, Vector3.new(0.2, 0.2, 0.2), hc * CFrame.new(0, 15, 0), Color3.new(1, 1, 1), nil, false, nil, 1), "🏠 Pet Cottage", UDim2.fromScale(9, 1.8), Vector3.zero, Color3.fromRGB(255, 220, 240), 70)

	-- POND (back-right)
	local pc = L(21, 1, 23)
	cyl(model, pc, 0.8, 14, stone, Enum.Material.Cobblestone, false)
	cyl(model, pc * CFrame.new(0, 0.1, 0), 0.75, 12.4, Color3.fromRGB(60, 180, 230), Enum.Material.Glass, false, 0.2)
	for k = 1, 4 do
		local a = k * 1.4
		cyl(model, pc * CFrame.new(math.cos(a) * 3.5, 0.85, math.sin(a) * 3.5), 0.1, 1.8, Color3.fromRGB(90, 190, 90), Enum.Material.Grass, false)
		ball(model, 0.6, pc * CFrame.new(math.cos(a) * 3.5, 1.1, math.sin(a) * 3.5), Color3.fromRGB(255, 160, 210), Enum.Material.Neon, false)
	end
	for k = 1, 5 do
		ball(model, 2.4, pc * CFrame.new(5 + (k % 2), 1.2 + k * 0.3, -2 + k), Color3.fromRGB(140, 140, 150), Enum.Material.Slate, false)
	end

	-- corner lamps + string lights along the hedges
	local corners = {}
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local p = L(c[1] * (HALF - 2.5), 1, c[2] * (HALF - 2.5))
		part(model, Vector3.new(0.7, 11, 0.7), p * CFrame.new(0, 5.5, 0), Color3.fromRGB(50, 45, 60), Enum.Material.Metal)
		local orb = ball(model, 2, p * CFrame.new(0, 11.4, 0), Color3.fromRGB(255, 215, 150), Enum.Material.Neon, false)
		light(orb, Color3.fromRGB(255, 210, 150), 22, 1.5)
		table.insert(corners, (p * CFrame.new(0, 11, 0)).Position)
	end
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		if i ~= 1 then -- leave the entrance side (corner1 -> corner2) open for the gateway
			for k = 1, 13 do
				local t = k / 14
				local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 2.5, 0)
				ball(model, 0.7, CFrame.new(p), Color3.fromHSV((k * 0.13 + i * 0.2) % 1, 0.45, 1), Enum.Material.Neon, false)
			end
		end
	end

	local center = Instance.new("Part")
	center.Name = "Center"
	center.Size = Vector3.new(1, 1, 1)
	center.CFrame = L(0, 1, 0)
	center.Transparency = 1
	center.Anchored = true
	center.CanCollide = false
	center.CanQuery = false
	center.Parent = model

	local decor = Instance.new("Folder"); decor.Name = "Decor"; decor.Parent = model
	local gym = Instance.new("Folder"); gym.Name = "Gym"; gym.Parent = model

	model:SetAttribute("Index", index)
	model.Parent = workspace:FindFirstChild("Bases")
	return {
		index = index, model = model, cf = cf, floor = floor, slots = slots, slotFolder = slotFolder,
		collect = collect, collectLabel = collectLabel, incomeLabel = incomeLabel, crystalLabel = crystalLabel,
		signLabels = { sl, sg2.Owner }, decor = decor, gym = gym, gymLabel = gymLabel, owner = nil,
		training = gym, -- (old name, kept so nothing else breaks)
		spawnCF = cf * CFrame.new(0, 4, -HALF + 6) * CFrame.Angles(0, math.pi, 0),
	}
end

---------------------------------------------------------------- gym equipment (by level)
local function buildGymEquipment(base, level)
	local f = base.gym
	f:ClearAllChildren()
	local st = Config.TrainingStations[level]
	local g = base.cf * CFrame.new(Config.GymOffset) * CFrame.new(0, 1.25, 3)
	-- weight bench
	part(f, Vector3.new(2.4, 0.6, 6), g * CFrame.new(0, 1.6, -2), Color3.fromRGB(200, 50, 60), Enum.Material.Fabric)
	for _, s in ipairs({ -1, 1 }) do part(f, Vector3.new(0.4, 1.6, 0.4), g * CFrame.new(0, 0.8, -2 + s * 2.4), Color3.fromRGB(60, 60, 70), Enum.Material.Metal) end
	-- rack + the equipment
	for _, s in ipairs({ -1, 1 }) do part(f, Vector3.new(0.5, 5, 0.5), g * CFrame.new(s * 3.4, 2.5, 1.5), Color3.fromRGB(70, 70, 80), Enum.Material.Metal) end
	local mat = level >= 4 and Enum.Material.Neon or Enum.Material.Metal
	if level == 3 then
		for k = -1, 1 do
			ball(f, 2.2, g * CFrame.new(k * 2.2, 1.2, 1.5), st.color, Enum.Material.Metal)
			cyl(f, g * CFrame.new(k * 2.2, 2.2, 1.5) * CFrame.Angles(math.pi / 2, 0, 0), 0.4, 1.2, st.color, Enum.Material.Metal, false)
		end
	elseif level == 5 then
		for k = 1, 3 do
			part(f, Vector3.new(0.4, 7 + k * 1.5, 7 + k * 1.5), g * CFrame.new(0, 6, 1.5) * CFrame.Angles(k * 0.9, k * 0.5, 0), st.color, Enum.Material.Neon, false, Enum.PartType.Cylinder, 0.2)
		end
		local core = ball(f, 2.6, g * CFrame.new(0, 6, 1.5), Color3.new(1, 1, 1), Enum.Material.Neon, false)
		light(core, st.color, 24, 3)
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = SPARKLE; pe.Color = ColorSequence.new(st.color); pe.Rate = 10; pe.LightEmission = 1
		pe.Speed = NumberRange.new(1, 3); pe.Size = NumberSequence.new(0.5, 0); pe.Parent = core
	else
		part(f, Vector3.new(8, 0.5, 0.5), g * CFrame.new(0, 4.4, 1.5), Color3.fromRGB(80, 80, 90), Enum.Material.Metal, false, Enum.PartType.Cylinder)
		for _, s in ipairs({ -1, 1 }) do
			part(f, Vector3.new(0.8, 2.6 + level * 0.3, 2.6 + level * 0.3), g * CFrame.new(s * 3, 4.4, 1.5), st.color, mat, false, Enum.PartType.Cylinder)
		end
	end
	local nextSt = Config.TrainingStations[level + 1]
	base.gymLabel.Text = string.format("💪 GYM: %s\n<font color='#9CFFA8'>+%d Strength/lift</font>%s", st.name, st.gain,
		nextSt and ("\n<font color='#FFD36B'>Next: " .. nextSt.name .. "</font>") or "\n<font color='#FFD36B'>MAXED!</font>")
end

---------------------------------------------------------------- decorations
local DecorBuild = {}
local function D(base, spot) return base.cf * CFrame.new(spot) end

function DecorBuild.FlowerBed(f, cf)
	part(f, Vector3.new(8, 1, 4), cf * CFrame.new(0, 1.5, 0), Color3.fromRGB(120, 80, 50), Enum.Material.Wood)
	for i = 1, 10 do
		ball(f, 1, cf * CFrame.new(-3.2 + (i - 1) % 5 * 1.6, 2.4, i > 5 and 0.9 or -0.9), Color3.fromHSV((i * 0.13) % 1, 0.55, 1), nil, false).Size = Vector3.new(1.1, 0.7, 1.1)
	end
end
function DecorBuild.Lanterns(f, cf)
	for s = -1, 1, 2 do
		part(f, Vector3.new(0.5, 7, 0.5), cf * CFrame.new(s * 2.5, 4, 0), Color3.fromRGB(60, 50, 70), Enum.Material.Metal)
		local l = ball(f, 2, cf * CFrame.new(s * 2.5, 8, 0), Color3.fromRGB(255, 180, 90), Enum.Material.Neon, false)
		light(l, Color3.fromRGB(255, 190, 110), 16)
	end
end
function DecorBuild.MushroomRing(f, cf)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local p = cf * CFrame.new(math.cos(a) * 2.6, 1, math.sin(a) * 2.6)
		part(f, Vector3.new(0.6, 1.6, 0.6), p * CFrame.new(0, 0.8, 0), Color3.fromRGB(245, 235, 220), nil, false)
		ball(f, 1, p * CFrame.new(0, 1.8, 0), Color3.fromHSV(0.8 + i * 0.03, 0.7, 1), Enum.Material.Neon, false).Size = Vector3.new(1.8, 1, 1.8)
	end
end
function DecorBuild.Fountain(f, cf)
	cyl(f, cf * CFrame.new(0, 1, 0), 1.6, 7, Color3.fromRGB(220, 220, 235), Enum.Material.Marble, true)
	cyl(f, cf * CFrame.new(0, 2.5, 0), 0.2, 6, Color3.fromRGB(90, 190, 255), Enum.Material.Glass, false, 0.3)
	local orb = ball(f, 2.4, cf * CFrame.new(0, 5.5, 0), Color3.fromRGB(150, 110, 255), Enum.Material.Neon, false)
	light(orb, Color3.fromRGB(150, 110, 255), 16)
end
function DecorBuild.CrystalTree(f, cf)
	part(f, Vector3.new(1.4, 8, 1.4), cf * CFrame.new(0, 5, 0), Color3.fromRGB(230, 230, 255), Enum.Material.Glass)
	local last
	for i = 1, 7 do
		local a = i * 0.9
		last = part(f, Vector3.new(1, 3.5, 1), cf * CFrame.new(math.cos(a) * 2, 8 + (i % 3), math.sin(a) * 2) * CFrame.Angles(math.cos(a) * 0.6, 0, math.sin(a) * 0.6),
			Color3.fromHSV(0.55 + i * 0.05, 0.6, 1), Enum.Material.Neon, false)
	end
	light(last, Color3.fromRGB(150, 200, 255), 20)
end
function DecorBuild.Statue(f, cf)
	part(f, Vector3.new(4, 2, 4), cf * CFrame.new(0, 2, 0), Color3.fromRGB(230, 230, 235), Enum.Material.Marble)
	ball(f, 3, cf * CFrame.new(0, 4.8, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Metal)
	for s = -1, 1, 2 do ball(f, 1, cf * CFrame.new(s * 0.8, 6.8, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Metal).Size = Vector3.new(0.8, 2, 0.4) end
end
function DecorBuild.Rainbow(f, cf)
	for i = 0, 14 do
		local a = i / 14 * math.pi
		ball(f, 1.6, cf * CFrame.new(math.cos(a) * 5, 1 + math.sin(a) * 6, 0), Color3.fromHSV(i / 14, 0.65, 1), Enum.Material.Neon, false)
	end
end
function DecorBuild.FloatingIsland(f, cf)
	ball(f, 1, cf, Color3.fromRGB(120, 90, 70), Enum.Material.Slate, false).Size = Vector3.new(12, 5, 10)
	ball(f, 1, cf * CFrame.new(0, 2, 0), Color3.fromRGB(110, 210, 90), Enum.Material.Grass, false).Size = Vector3.new(12, 1.5, 10)
	part(f, Vector3.new(0.8, 4, 0.8), cf * CFrame.new(0, 4.5, 0), Color3.fromRGB(120, 80, 50), Enum.Material.Wood, false)
	ball(f, 1, cf * CFrame.new(0, 7, 0), Color3.fromRGB(255, 160, 210), Enum.Material.Grass, false).Size = Vector3.new(4.5, 4, 4.5)
end

---------------------------------------------------------------- public API
function BaseBuilder.BuildAll()
	local f = Instance.new("Folder"); f.Name = "Bases"; f.Parent = workspace
	for i = 1, Config.MaxBases do
		BaseBuilder.Bases[i] = buildBase(i)
	end
end

function BaseBuilder.Claim(player)
	for _, b in ipairs(BaseBuilder.Bases) do
		if not b.owner then
			b.owner = player
			for _, l in ipairs(b.signLabels) do l.Text = player.DisplayName .. "'s Base" end
			b.model:SetAttribute("OwnerId", player.UserId)
			return b
		end
	end
	return nil
end

function BaseBuilder.Release(base)
	base.owner = nil
	for _, l in ipairs(base.signLabels) do l.Text = "Empty Base" end
	base.model:SetAttribute("OwnerId", nil)
	base.decor:ClearAllChildren()
	base.gym:ClearAllChildren()
	base.gymLabel.Text = "💪 GYM"
	base.crystalLabel.Text = ""
	base.collectLabel.Text = "$0"
end

-- Rebuild decorations, floor theme, gym equipment and slot colours from player data
function BaseBuilder.Refresh(base, data)
	base.decor:ClearAllChildren()
	for i, id in ipairs(Config.DecorOrder) do
		if data.Decor[id] and DecorBuild[id] then
			local holder = Instance.new("Folder"); holder.Name = id; holder.Parent = base.decor
			DecorBuild[id](holder, D(base, DECOR_SPOTS[i]))
		end
	end
	for _, theme in ipairs(Config.FloorThemes) do
		if theme.id == data.FloorTheme then
			base.floor.Color = theme.color
			base.floor.Material = theme.material
		end
	end
	buildGymEquipment(base, math.clamp(data.EquipLevel or 1, 1, #Config.TrainingStations))
	local lvl = data.Upgrades.Training
	base.crystalLabel.Text = lvl > 0 and ("🐾 Pet Trainer Lv." .. lvl .. "  (+" .. math.floor(lvl * Config.TrainingBonus * 100) .. "% income)") or ""
	local slotsOpen = Config.StartSlots + data.Upgrades.BaseSlots
	for i = 1, #base.slots do
		local ring = base.slotFolder:FindFirstChild("SlotRing" .. i)
		local pad = base.slotFolder:FindFirstChild("Slot" .. i)
		local open = i <= slotsOpen
		if ring then
			ring.Color = open and Color3.fromRGB(150, 120, 255) or Color3.fromRGB(90, 90, 100)
			ring.Material = open and Enum.Material.Neon or Enum.Material.SmoothPlastic
			ring.Transparency = open and 0 or 0.5
		end
		if pad then pad.Transparency = open and 0 or 0.6 end
	end
end

return BaseBuilder
