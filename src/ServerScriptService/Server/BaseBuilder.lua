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

---------------------------------------------------------------- one base
local function buildBase(index)
	return require(script.Parent.SanctuaryBase).Build(index)
end

---------------------------------------------------------------- gym equipment (by level)
local function buildGymEquipment(base, level)
	local f = base.gym
	f:ClearAllChildren()
	local st = Config.TrainingStations[level]
	local g = base.cf * CFrame.new(Config.GymOffset) * CFrame.new(0, 1.25, 3)
	local STEEL, DARKSTEEL = Color3.fromRGB(150, 155, 168), Color3.fromRGB(60, 62, 72)
	local HZ = Enum.PartType.Cylinder -- part cylinders run along X (horizontal)
	-- every tier has its own geometry (not a recolour); positions stay inside the gym pad
	if level == 1 then
		-- Wooden Dumbbell: soft mat, low wooden rack, two rounded wooden dumbbells, instruction plate
		part(f, Vector3.new(7, 0.2, 5), g * CFrame.new(0, 0.1, 0), Color3.fromRGB(110, 170, 120), Enum.Material.Fabric, false)
		part(f, Vector3.new(6, 0.5, 1.6), g * CFrame.new(0, 1.4, 2.2), Color3.fromRGB(170, 120, 70), Enum.Material.WoodPlanks)
		for _, s in ipairs({ -1, 1 }) do part(f, Vector3.new(0.5, 1.4, 1.4), g * CFrame.new(s * 2.7, 0.7, 2.2), Color3.fromRGB(140, 95, 55), Enum.Material.Wood) end
		for _, x in ipairs({ -1.4, 1.4 }) do
			part(f, Vector3.new(1.6, 0.35, 0.35), g * CFrame.new(x, 1.95, 2.2), Color3.fromRGB(150, 105, 60), Enum.Material.Wood, false, HZ)
			for _, s in ipairs({ -1, 1 }) do ball(f, 0.95, g * CFrame.new(x + s * 0.85, 1.95, 2.2), st.color, Enum.Material.Wood, false) end
		end
		part(f, Vector3.new(3, 1.4, 0.2), g * CFrame.new(0, 2.6, 3.3), Color3.fromRGB(245, 235, 210), Enum.Material.Wood, false)
	elseif level == 2 then
		-- Iron Barbell: rubber mat, steel uprights with J-hooks, plates + collars
		part(f, Vector3.new(9, 0.2, 7), g * CFrame.new(0, 0.1, 0), Color3.fromRGB(40, 40, 46), Enum.Material.Rubber, false)
		for _, s in ipairs({ -1, 1 }) do
			part(f, Vector3.new(0.5, 5, 0.5), g * CFrame.new(s * 3.4, 2.5, 1.5), DARKSTEEL, Enum.Material.Metal)
			part(f, Vector3.new(0.5, 0.3, 0.9), g * CFrame.new(s * 3.4, 4.15, 1.2), STEEL, Enum.Material.Metal, false) -- J-hook
			for k = 0, 2 do
				part(f, Vector3.new(0.28, 2.6 - k * 0.5, 2.6 - k * 0.5), g * CFrame.new(s * (2.4 + k * 0.3), 4.4, 1.5), Color3.fromRGB(50, 52, 60), Enum.Material.Metal, false, HZ)
			end
			part(f, Vector3.new(0.3, 0.8, 0.8), g * CFrame.new(s * 3.3, 4.4, 1.5), STEEL, Enum.Material.Metal, false, HZ) -- collar
		end
		part(f, Vector3.new(8.4, 0.32, 0.32), g * CFrame.new(0, 4.4, 1.5), STEEL, Enum.Material.Metal, false, HZ)
	elseif level == 3 then
		-- Golden Kettlebell: pedestal rack with three real kettlebells (body + arched handle)
		part(f, Vector3.new(8, 0.2, 6), g * CFrame.new(0, 0.1, 0), Color3.fromRGB(60, 40, 30), Enum.Material.Rubber, false)
		part(f, Vector3.new(7.5, 1.2, 2.4), g * CFrame.new(0, 0.6, 1.5), Color3.fromRGB(240, 232, 215), Enum.Material.Marble)
		part(f, Vector3.new(7.7, 0.2, 2.6), g * CFrame.new(0, 1.25, 1.5), st.color, Enum.Material.Metal, false)
		for k = -1, 1 do
			local bcf = g * CFrame.new(k * 2.3, 2.45, 1.5)
			ball(f, 2.1, bcf, st.color, Enum.Material.Metal, false)
			for seg = 0, 4 do -- handle arch
				local a = seg / 4 * math.pi
				part(f, Vector3.new(0.75, 0.3, 0.3), bcf * CFrame.new(math.cos(a) * 0.7, 1.05 + math.sin(a) * 0.65, 0) * CFrame.Angles(0, 0, a + math.pi / 2), st.color, Enum.Material.Metal, false, HZ)
			end
		end
	elseif level == 4 then
		-- Crystal Weights: reinforced grip, faceted crystal plates, mounting brackets, luminous channels
		part(f, Vector3.new(9, 0.2, 7), g * CFrame.new(0, 0.1, 0), Color3.fromRGB(35, 30, 50), Enum.Material.Rubber, false)
		for _, s in ipairs({ -1, 1 }) do
			part(f, Vector3.new(0.7, 4.6, 1.2), g * CFrame.new(s * 3.6, 2.3, 1.5), Color3.fromRGB(70, 60, 95), Enum.Material.Metal)
			part(f, Vector3.new(0.72, 3.8, 0.15), g * CFrame.new(s * 3.6, 2.3, 0.88), st.color, Enum.Material.Neon, false) -- recessed channel
			for k = 0, 1 do
				local plate = part(f, Vector3.new(0.5, 2.4 - k * 0.6, 2.4 - k * 0.6), g * CFrame.new(s * (2.5 + k * 0.5), 4.4, 1.5) * CFrame.Angles(math.rad(45), 0, 0), st.color, Enum.Material.Glass, false)
				plate.Transparency = 0.12
			end
		end
		part(f, Vector3.new(7.6, 0.4, 0.4), g * CFrame.new(0, 4.4, 1.5), Color3.fromRGB(200, 200, 215), Enum.Material.Metal, false, HZ)
		part(f, Vector3.new(2.4, 0.5, 0.5), g * CFrame.new(0, 4.4, 1.5), Color3.fromRGB(60, 50, 80), Enum.Material.Fabric, false, HZ) -- grip
	else
		-- Cosmic Gravity Machine: A-frame, three offset orbital rings, contained core, safe grips
		part(f, Vector3.new(10, 0.2, 8), g * CFrame.new(0, 0.1, 0), Color3.fromRGB(20, 25, 45), Enum.Material.Rubber, false)
		for _, s in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -0.6, 0.6 }) do
				part(f, Vector3.new(0.5, 8.5, 0.5), g * CFrame.new(s * 4.2, 4, 1.5 + z) * CFrame.Angles(z * 0.25, 0, 0), Color3.fromRGB(45, 50, 75), Enum.Material.Metal)
			end
			part(f, Vector3.new(1.6, 0.4, 0.4), g * CFrame.new(s * 1.8, 3.2, -0.3), Color3.fromRGB(200, 205, 220), Enum.Material.Metal, false, HZ) -- grip
		end
		part(f, Vector3.new(8.8, 0.5, 0.5), g * CFrame.new(0, 8.2, 1.5), Color3.fromRGB(45, 50, 75), Enum.Material.Metal, false, HZ)
		for k = 1, 3 do
			local ring = part(f, Vector3.new(0.35, 5 + k * 1.2, 5 + k * 1.2), g * CFrame.new(0, 5, 1.5) * CFrame.Angles(k * 0.9, k * 0.5, 0), st.color, Enum.Material.Neon, false, Enum.PartType.Cylinder, 0.25)
			ring.Name = "GravityRing" .. k
		end
		local glass = ball(f, 3.4, g * CFrame.new(0, 5, 1.5), Color3.fromRGB(180, 230, 255), Enum.Material.Glass, false)
		glass.Transparency = 0.6
		local core = ball(f, 1.8, g * CFrame.new(0, 5, 1.5), Color3.new(1, 1, 1), Enum.Material.Neon, false)
		core.Name = "GravityCore"
		light(core, st.color, 18, 2)
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = SPARKLE; pe.Color = ColorSequence.new(st.color); pe.Rate = 6; pe.LightEmission = 1
		pe.Speed = NumberRange.new(0.5, 1.5); pe.Size = NumberSequence.new(0.4, 0); pe.Parent = core
	end
	-- WORKOUT BENCH (every level): you sit here and press the weights. Faces away from the rack.
	local benchCF = g * CFrame.new(0, 0, -2.4)
	local IVORY, GOLD, PURPLE = Color3.fromRGB(243, 235, 219), Color3.fromRGB(234, 196, 111), Color3.fromRGB(96, 60, 168)
	for _, s in ipairs({ -1, 1 }) do
		part(f, Vector3.new(0.35, 1.3, 0.35), benchCF * CFrame.new(s * 0.85, 0.65, 0.8), DARKSTEEL, Enum.Material.Metal)
		part(f, Vector3.new(0.35, 1.3, 0.35), benchCF * CFrame.new(s * 0.85, 0.65, -0.8), DARKSTEEL, Enum.Material.Metal)
	end
	part(f, Vector3.new(2.3, 0.3, 2.4), benchCF * CFrame.new(0, 1.35, 0), IVORY, Enum.Material.Limestone)
	part(f, Vector3.new(2.42, 0.1, 2.52), benchCF * CFrame.new(0, 1.22, 0), GOLD, Enum.Material.Metal, false)
	-- padded backrest behind the sitter, tilted slightly back
	local back = benchCF * CFrame.new(0, 2.55, 1.15) * CFrame.Angles(math.rad(-12), 0, 0)
	part(f, Vector3.new(2.2, 2.6, 0.45), back, PURPLE, Enum.Material.Fabric)
	part(f, Vector3.new(2.32, 0.12, 0.5), back * CFrame.new(0, 1.32, 0), GOLD, Enum.Material.Metal, false)
	part(f, Vector3.new(0.3, 2.1, 0.3), benchCF * CFrame.new(0, 1.9, 1.35), DARKSTEEL, Enum.Material.Metal)
	local seat = Instance.new("Seat")
	seat.Name = "WorkoutSeat"
	seat.Size = Vector3.new(2.1, 0.35, 2.1)
	seat.CFrame = benchCF * CFrame.new(0, 1.65, 0)
	seat.Color = PURPLE
	seat.Material = Enum.Material.Fabric
	seat.Anchored = true
	seat.TopSurface, seat.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	seat.Parent = f

	BaseBuilder.SetGymSign(base, level)
end

-- Gym sign in the Portal Sanctuary style: violet board, gold frame and keystone, cream/gold lettering.
function BaseBuilder.SetGymSign(base, level)
	local label = base.gymLabel
	local bb = label and label.Parent
	if not bb then return end
	if not bb:FindFirstChild("SanctuaryPanel") then
		bb.Size = UDim2.fromScale(9, 3.4)
		bb.MaxDistance = 70
		local panel = Instance.new("Frame")
		panel.Name = "SanctuaryPanel"
		panel.Size = UDim2.fromScale(1, 1)
		panel.BackgroundColor3 = Color3.new(1, 1, 1)
		local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0.12, 0); corner.Parent = panel
		local stroke = Instance.new("UIStroke"); stroke.Thickness = 3; stroke.Color = Color3.fromRGB(234, 196, 111); stroke.Parent = panel
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new(Color3.fromRGB(112, 74, 190), Color3.fromRGB(64, 40, 118))
		grad.Parent = panel
		local key = Instance.new("Frame")
		key.Name = "Keystone"
		key.AnchorPoint = Vector2.new(0.5, 0.5)
		key.Position = UDim2.fromScale(0.5, 0)
		key.Size = UDim2.fromScale(0.09, 0.24)
		key.SizeConstraint = Enum.SizeConstraint.RelativeYY
		key.Rotation = 45
		key.BackgroundColor3 = Color3.fromRGB(234, 196, 111)
		key.BorderSizePixel = 0
		key.Parent = panel
		panel.Parent = bb
		label.Parent = panel
		label.Size = UDim2.fromScale(0.9, 0.8)
		label.Position = UDim2.fromScale(0.05, 0.12)
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 242, 205)
		local ls = label:FindFirstChildOfClass("UIStroke")
		if ls then ls.Color = Color3.fromRGB(40, 22, 80); ls.Thickness = 1.5; ls.Transparency = 0 end
	end
	local st = Config.TrainingStations[level]
	local nextSt = Config.TrainingStations[level + 1]
	label.Text = string.format("<font color='#F1CA73'><b>PERSONAL GYM</b></font>\n%s\n<font color='#C9F2D2'>+%d STRENGTH / LIFT</font>\n<font color='#CDB8FF'>%s</font>",
		string.upper(st.name), st.gain, nextSt and ("NEXT: " .. string.upper(nextSt.name)) or "MAXED OUT")
end

---------------------------------------------------------------- decorations
local DecorBuild = {}
local function D(base, spot) return base.cf * CFrame.new(spot) end

function DecorBuild.FlowerBed(f, cf)
	-- stone border + soil + three distinct flower shapes (tulip, daisy, bell) with leaves
	part(f, Vector3.new(8.4, 0.8, 4.4), cf * CFrame.new(0, 1.3, 0), Color3.fromRGB(175, 170, 165), Enum.Material.Cobblestone)
	part(f, Vector3.new(7.6, 0.3, 3.6), cf * CFrame.new(0, 1.75, 0), Color3.fromRGB(95, 65, 45), Enum.Material.Ground, false)
	for i = 1, 9 do
		local x, z = -3 + (i - 1) % 5 * 1.5, i > 5 and 0.9 or -0.9
		local base = cf * CFrame.new(x, 1.9, z)
		part(f, Vector3.new(0.15, 1.1, 0.15), base * CFrame.new(0, 0.55, 0), Color3.fromRGB(70, 150, 60), nil, false)
		ball(f, 1, base * CFrame.new(0.25, 0.35, 0) * CFrame.Angles(0, 0, -0.6), Color3.fromRGB(90, 180, 70), Enum.Material.Grass, false).Size = Vector3.new(0.6, 0.2, 0.35)
		local kind = i % 3
		local col = Color3.fromHSV((i * 0.13) % 1, 0.55, 1)
		if kind == 0 then -- tulip cup
			ball(f, 1, base * CFrame.new(0, 1.25, 0), col, nil, false).Size = Vector3.new(0.55, 0.75, 0.55)
		elseif kind == 1 then -- daisy: petal disc + centre
			part(f, Vector3.new(0.12, 0.95, 0.95), base * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 252, 245), nil, false, Enum.PartType.Cylinder)
			ball(f, 0.35, base * CFrame.new(0, 1.28, 0), Color3.fromRGB(255, 210, 60), nil, false)
		else -- bell: drooping bloom
			ball(f, 1, base * CFrame.new(0.2, 1.05, 0), col, nil, false).Size = Vector3.new(0.45, 0.55, 0.45)
		end
	end
end
function DecorBuild.Lanterns(f, cf)
	-- real post + bracket + caged lantern bodies (warm glass inserts); one light per pair
	for s = -1, 1, 2 do
		local base = cf * CFrame.new(s * 2.5, 0, 0)
		part(f, Vector3.new(1.2, 0.6, 1.2), base * CFrame.new(0, 1.3, 0), Color3.fromRGB(70, 60, 80), Enum.Material.Metal)
		part(f, Vector3.new(0.4, 7, 0.4), base * CFrame.new(0, 4.6, 0), Color3.fromRGB(60, 50, 70), Enum.Material.Metal)
		part(f, Vector3.new(1.6, 0.25, 0.25), base * CFrame.new(-s * 0.6, 8, 0), Color3.fromRGB(60, 50, 70), Enum.Material.Metal, false)
		local lcf = base * CFrame.new(-s * 1.3, 6.9, 0)
		local glass = part(f, Vector3.new(0.9, 1.3, 0.9), lcf, Color3.fromRGB(255, 190, 110), Enum.Material.Neon, false)
		for _, c in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
			part(f, Vector3.new(0.12, 1.5, 0.12), lcf * CFrame.new(c[1] * 0.5, 0, c[2] * 0.5), Color3.fromRGB(45, 38, 50), Enum.Material.Metal, false)
		end
		part(f, Vector3.new(1.2, 0.3, 1.2), lcf * CFrame.new(0, 0.8, 0), Color3.fromRGB(45, 38, 50), Enum.Material.Metal, false)
		if s == 1 then light(glass, Color3.fromRGB(255, 190, 110), 16) end
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
	-- an original sitting fox-like creature sculpted from masses, on a plinth with an inscription plate
	local gold = Color3.fromRGB(255, 200, 60)
	part(f, Vector3.new(4.4, 1.6, 4.4), cf * CFrame.new(0, 1.8, 0), Color3.fromRGB(230, 230, 235), Enum.Material.Marble)
	part(f, Vector3.new(3.8, 0.4, 3.8), cf * CFrame.new(0, 2.8, 0), Color3.fromRGB(210, 210, 218), Enum.Material.Marble)
	part(f, Vector3.new(2.2, 0.7, 0.15), cf * CFrame.new(0, 1.9, -2.25), gold, Enum.Material.Metal, false)
	local s = cf * CFrame.new(0, 3, 0)
	ball(f, 1, s * CFrame.new(0, 1.3, 0.3), gold, Enum.Material.Metal).Size = Vector3.new(2.2, 2.4, 2.6) -- seated body
	ball(f, 1, s * CFrame.new(0, 2.9, -0.6), gold, Enum.Material.Metal).Size = Vector3.new(1.7, 1.5, 1.6) -- head
	ball(f, 1, s * CFrame.new(0, 2.6, -1.4), gold, Enum.Material.Metal, false).Size = Vector3.new(0.8, 0.6, 0.9) -- muzzle
	for side = -1, 1, 2 do
		local ear = part(f, Vector3.new(0.5, 1.1, 0.3), s * CFrame.new(side * 0.55, 3.9, -0.5) * CFrame.Angles(0, 0, -side * 0.35), gold, Enum.Material.Metal, false)
		ear.Shape = Enum.PartType.Block
		ball(f, 1, s * CFrame.new(side * 0.6, 0.4, -0.9), gold, Enum.Material.Metal, false).Size = Vector3.new(0.7, 0.6, 1.1) -- front paws
	end
	ball(f, 1, s * CFrame.new(1.2, 0.7, 1.2) * CFrame.Angles(0, 0.6, 0), gold, Enum.Material.Metal, false).Size = Vector3.new(0.9, 0.9, 2.6) -- curled tail
end
function DecorBuild.Rainbow(f, cf)
	-- continuous seven-band arch with cloud feet and neat end caps
	local cols = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 160, 50), Color3.fromRGB(255, 230, 70), Color3.fromRGB(90, 220, 110),
		Color3.fromRGB(80, 170, 255), Color3.fromRGB(110, 100, 255), Color3.fromRGB(200, 100, 255) }
	local segs = 14
	for b, col in ipairs(cols) do
		local r = 6.2 - b * 0.42
		for i = 1, segs do
			local a0, a1 = (i - 1) / segs * math.pi, i / segs * math.pi
			local p0 = Vector3.new(math.cos(a0) * r, math.sin(a0) * r, 0)
			local p1 = Vector3.new(math.cos(a1) * r, math.sin(a1) * r, 0)
			local mid = (p0 + p1) / 2
			part(f, Vector3.new(0.45, (p1 - p0).Magnitude + 0.08, 0.6), cf * CFrame.new(0, 1.2, 0) * CFrame.new(mid) * CFrame.Angles(0, 0, (a0 + a1) / 2), col, Enum.Material.Neon, false)
		end
	end
	for s = -1, 1, 2 do
		for k = 0, 2 do
			ball(f, 1, cf * CFrame.new(s * (4.6 + k * 0.5 - 0.5), 1.4 + (k % 2) * 0.3, (k - 1) * 0.7), Color3.fromRGB(255, 255, 255), nil, false).Size = Vector3.new(2, 1.4, 1.8)
		end
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
	for _, old in ipairs(workspace:GetChildren()) do
		if old.Name == "Bases" and old:IsA("Folder") and (old:GetAttribute("TPFCGenerated") or old:FindFirstChild("Base1")) then old:Destroy() end
	end
	BaseBuilder.Bases = {}
	local f = Instance.new("Folder"); f.Name = "Bases"; f.Parent = workspace
	f:SetAttribute("TPFCGenerated", true)
	for i = 1, Config.MaxBases do
		BaseBuilder.Bases[i] = buildBase(i)
		buildGymEquipment(BaseBuilder.Bases[i], 1)
		task.wait()
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
	for _, l in ipairs(base.signLabels) do l.Text = "UNCLAIMED GARDEN" end
	base.model:SetAttribute("OwnerId", nil)
	base.decor:ClearAllChildren()
	base.gym:ClearAllChildren()
	buildGymEquipment(base, 1)
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
			base.floor.Color = theme.id == "Meadow" and Color3.fromRGB(108, 161, 76) or theme.color
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
