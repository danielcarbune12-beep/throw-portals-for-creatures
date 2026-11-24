-- BattleStage: the floating sky-island arena the battle scene plays on. A round island of the biome
-- hangs in the sky with rocky roots underneath, a rune circle in the middle, the team's portal on
-- one side and the monsters' portal on the other, themed scenery around the rim, smaller islands
-- drifting in the distance, weather particles and a colour grade. Built at `origin` in the world
-- by the client that watches the battle (nobody else sees it).
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local okPortal, Portal = pcall(require, RS.Shared.PortalBuilder)
local Stage = {}
local V, C, ANG = Vector3.new, Color3.fromRGB, CFrame.Angles
local PI = math.pi

local LOOK = {
	Forest = { top = Enum.Material.Grass, rock = C(112, 98, 84), glow = C(255, 214, 120), accent = C(80, 170, 90), weather = "leaf",
		tint = C(240, 255, 232), portal = "Forest" },
	Volcano = { top = Enum.Material.Basalt, rock = C(62, 52, 52), glow = C(255, 120, 40), accent = C(230, 80, 30), weather = "ember",
		tint = C(255, 228, 210), portal = "Lava" },
	Frozen = { top = Enum.Material.Snow, rock = C(150, 172, 190), glow = C(160, 220, 255), accent = C(120, 190, 240), weather = "snow",
		tint = C(228, 242, 255), portal = "Ice" },
	Crystal = { top = Enum.Material.Slate, rock = C(84, 76, 116), glow = C(200, 150, 255), accent = C(140, 100, 230), weather = "sparkle",
		tint = C(242, 232, 255), portal = "Galaxy" },
	Candy = { top = Enum.Material.SmoothPlastic, rock = C(200, 150, 120), glow = C(255, 160, 215), accent = C(240, 110, 170), weather = "confetti",
		tint = C(255, 240, 250), portal = "Rainbow" },
	Space = { top = Enum.Material.Slate, rock = C(70, 72, 92), glow = C(150, 225, 255), accent = C(110, 120, 230), weather = "star",
		tint = C(222, 228, 255), portal = "Galaxy" },
	Shadow = { top = Enum.Material.Slate, rock = C(46, 40, 60), glow = C(180, 100, 255), accent = C(130, 60, 200), weather = "mote",
		tint = C(226, 212, 246), portal = "Dark" },
	Heaven = { top = Enum.Material.Marble, rock = C(230, 224, 210), glow = C(255, 232, 150), accent = C(240, 196, 80), weather = "gold",
		tint = C(255, 250, 236), portal = "Divine" },
}
Stage.Look = LOOK

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

-- key places on the island, relative to origin: the team faces +X, monsters face -X
Stage.TeamSlots = { V(-5, 0, 0), V(-7.2, 0, 2.8), V(-7.2, 0, -2.8) }
Stage.TeamPortal = V(-13, 0, 0)
Stage.MonsterSpot = V(5, 0, 0)
Stage.BossSpot = V(6, 0, 0)
Stage.MonsterPortal = V(13, 0, 0)
Stage.Ground = 0.5 -- island surface height

function Stage.Build(worldId, origin)
	local def = Config.Worlds[worldId] or Config.Worlds.Forest
	local look = LOOK[worldId] or LOOK.Forest
	local ground = def.groundColor
	local model = Instance.new("Model")
	model.Name = "BattleStage"
	local seed = #worldId * 7919 + 13
	local function rand(a, b)
		seed = (seed * 48271) % 2147483647
		local r = seed / 2147483647
		return a and (a + (b - a) * r) or r
	end
	local function part(name, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, CFrame.new(origin) * cf, color
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Parent = model
		return p
	end
	local function wedge(name, size, cf, color, material)
		local p = Instance.new("WedgePart")
		p.Name, p.Size, p.CFrame, p.Color = name, size, CFrame.new(origin) * cf, color
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	local function light(p, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness, l.Shadows = color, range or 12, brightness or 1.5, false
		l.Parent = p
	end
	local flat = ANG(0, 0, PI / 2) -- cylinders lying flat (axis up)

	-- the island: layered disc, a rim, and rocky roots hanging into the sky
	part("IslandTop", V(1.2, 44, 44), CFrame.new(0, -0.1, 0) * flat, ground, look.top, Enum.PartType.Cylinder)
	part("IslandEdge", V(2.4, 46, 46), CFrame.new(0, -1.5, 0) * flat, ground:Lerp(look.rock, 0.5), Enum.Material.Slate, Enum.PartType.Cylinder)
	part("IslandBody", V(5, 40, 40), CFrame.new(0, -5, 0) * flat, look.rock, Enum.Material.Slate, Enum.PartType.Cylinder)
	for i = 1, 14 do
		local a = rand(0, PI * 2)
		local r = rand(4, 16)
		local h = rand(6, 16)
		local w = rand(4, 9)
		local root = wedge("IslandRoot", V(w, h, w), CFrame.new(math.cos(a) * r, -7.5 - h / 2, math.sin(a) * r) * ANG(PI, rand(0, PI * 2), 0),
			look.rock:Lerp(C(0, 0, 0), rand(0, 0.3)), Enum.Material.Slate)
		if rand() < 0.3 then
			local gem = part("RootGem", V(0.8, 1.6, 0.8), root.CFrame * CFrame.new(0, -h * 0.2, w * 0.3), look.glow, Enum.Material.Neon)
			light(gem, look.glow, 10, 1)
		end
	end

	-- arena floor: a stone ring with glowing runes where the fights happen
	part("ArenaRing", V(0.3, 26, 26), CFrame.new(0, 0.55, 0) * flat, look.rock:Lerp(C(255, 255, 255), 0.35), Enum.Material.Cobblestone, Enum.PartType.Cylinder)
	part("ArenaCenter", V(0.34, 20, 20), CFrame.new(0, 0.56, 0) * flat, ground:Lerp(look.rock, 0.3), look.top, Enum.PartType.Cylinder)
	for i = 0, 23 do
		local a = i / 24 * PI * 2
		local rune = part("Rune", V(1, 0.08, 0.3), CFrame.new(math.cos(a) * 11.6, 0.75, math.sin(a) * 11.6) * ANG(0, -a, 0), look.glow, Enum.Material.Neon)
		rune.Transparency = 0.15
	end
	local ring = part("RuneRing", V(0.06, 16, 16), CFrame.new(0, 0.74, 0) * flat, look.glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.8
	light(ring, look.glow, 20, 1)

	-- the two portals: the team arrives on the left, monsters come out on the right
	local portals = {}
	for side, spot in { team = Stage.TeamPortal, monster = Stage.MonsterPortal } do
		part("PortalBase", V(0.6, 8, 8), CFrame.new(spot + V(0, 0.6, 0)) * flat, look.rock, Enum.Material.Slate, Enum.PartType.Cylinder)
		if okPortal and Portal and Portal.BuildGate then
			local id = side == "team" and "Basic" or (Config.Portals[look.portal] and look.portal or "Basic")
			local ok, gate, refs = pcall(Portal.BuildGate, id, 3.4)
			if ok and gate then
				local at = origin + spot + V(0, 3.4 + 1, 0)
				local facing = side == "team" and V(1, 0, 0) or V(-1, 0, 0)
				gate:PivotTo(CFrame.lookAt(at, at + facing))
				for _, d in ipairs(gate:GetDescendants()) do
					if d:IsA("BasePart") then d.Anchored = true end
				end
				gate.Parent = model
				portals[side] = { model = gate, refs = refs, at = at }
			end
		end
	end

	-- rim scenery themed per biome (kept clear of the fight in the middle)
	for i = 1, 26 do
		local a = rand(0, PI * 2)
		local r = rand(14.5, 20.5)
		local x, z = math.cos(a) * r, math.sin(a) * r
		-- keep the side facing the camera (-Z) open so nothing hides the fight
		if (math.abs(z) > 4 or math.abs(x) < 10) and (z > -6 or math.abs(x) > 17) then
			local s = rand(0.8, 1.5)
			local base = CFrame.new(x, 0.5, z)
			if worldId == "Forest" then
				part("Trunk", V(0.9, 4 * s, 0.9), base * CFrame.new(0, 2 * s, 0), C(96, 70, 48), Enum.Material.Wood)
				for lv = 0, 2 do
					local w = (3.8 - lv * 1) * s
					part("Leaves", V(w, 1.5 * s, w), base * CFrame.new(0, (3.8 + lv * 1.2) * s, 0) * ANG(0, lv * 0.6, 0), C(64 + lv * 14, 136 + lv * 12, 62), Enum.Material.Grass)
				end
			elseif worldId == "Volcano" then
				wedge("Spire", V(2 * s, 5 * s, 2 * s), base * CFrame.new(0, 2.5 * s, 0) * ANG(0, rand(0, 3), 0), C(56, 48, 50), Enum.Material.Basalt)
				if rand() < 0.5 then
					local lava = part("Lava", V(0.2, 3 * s, 3 * s), base * CFrame.new(1.5, 0.12, 0) * flat, C(255, 110, 30), Enum.Material.Neon, Enum.PartType.Cylinder)
					light(lava, C(255, 120, 40), 12, 2)
				end
			elseif worldId == "Frozen" then
				part("IceSpike", V(1.3 * s, 5 * s, 1.3 * s), base * CFrame.new(0, 2.4 * s, 0) * ANG(rand(-0.2, 0.2), rand(0, 3), rand(-0.2, 0.2)), C(176, 224, 248), Enum.Material.Ice)
				part("SnowPile", V(3 * s, 0.9, 2.4 * s), base * CFrame.new(0.8, 0, 0), C(248, 252, 255), Enum.Material.Snow)
			elseif worldId == "Crystal" then
				local col = rand() < 0.5 and C(160, 120, 250) or C(110, 225, 240)
				for c = 1, 3 do
					local cr = part("Crystal", V(0.9 * s, (2 + c) * s, 0.9 * s), base * CFrame.new(c * 0.6 - 1.2, (1 + c * 0.5) * s, 0) * ANG(rand(-0.35, 0.35), rand(0, 3), rand(-0.35, 0.35)), col, Enum.Material.Neon)
					cr.Transparency = 0.12
					if c == 2 then light(cr, col, 10, 1.2) end
				end
			elseif worldId == "Candy" then
				for band = 0, 4 do
					part("Cane", V(0.8 * s, 0.9 * s, 0.8 * s), base * CFrame.new(0, (0.45 + band * 0.9) * s, 0), band % 2 == 0 and C(240, 80, 110) or C(255, 250, 250))
				end
				local gum = part("Gumdrop", V(2 * s, 1.4 * s, 2 * s), base * CFrame.new(1.8, 0.7 * s, 0.8), rand() < 0.5 and C(130, 220, 170) or C(255, 170, 90), Enum.Material.Glass, Enum.PartType.Ball)
				gum.Transparency = 0.15
			elseif worldId == "Space" then
				part("MoonRock", V(2.4 * s, 1.6 * s, 2.4 * s), base * CFrame.new(0, 0.6 * s, 0), C(120, 124, 140), Enum.Material.Slate, Enum.PartType.Ball)
				if rand() < 0.4 then
					local b = part("Beacon", V(0.5, 0.5, 0.5), base * CFrame.new(0, 1.8 * s, 0), C(150, 230, 255), Enum.Material.Neon, Enum.PartType.Ball)
					light(b, C(150, 230, 255), 10, 1.5)
				end
			elseif worldId == "Shadow" then
				part("DeadTree", V(0.6, 5 * s, 0.6), base * CFrame.new(0, 2.5 * s, 0) * ANG(0, 0, rand(-0.2, 0.2)), C(58, 52, 70), Enum.Material.Wood)
				part("Branch", V(0.35, 2.2 * s, 0.35), base * CFrame.new(0.6, 3.8 * s, 0) * ANG(0, rand(0, 3), -0.8), C(58, 52, 70), Enum.Material.Wood)
				if rand() < 0.5 then
					local orb = part("SoulOrb", V(0.6, 0.6, 0.6), base * CFrame.new(1, 1.5, 1), C(180, 100, 255), Enum.Material.Neon, Enum.PartType.Ball)
					light(orb, C(170, 90, 255), 10, 1.4)
				end
			else -- Heaven
				part("Column", V(1.2, 5 * s, 1.2), base * CFrame.new(0, 2.5 * s, 0), C(244, 240, 228), Enum.Material.Marble)
				part("ColumnCap", V(1.8, 0.4, 1.8), base * CFrame.new(0, 5 * s + 0.2, 0), C(240, 200, 90), Enum.Material.Metal)
			end
		end
	end
	-- torches around the arena ring
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * PI * 2
		local at = CFrame.new(math.cos(a) * 13.4, 0.5, math.sin(a) * 13.4)
		if math.abs(math.sin(a)) > 0.3 then
			part("TorchPost", V(0.35, 3, 0.35), at * CFrame.new(0, 1.5, 0), C(80, 58, 40), Enum.Material.Wood)
			local bowl = part("TorchBowl", V(0.8, 0.35, 0.8), at * CFrame.new(0, 3.1, 0), C(60, 56, 60), Enum.Material.Metal)
			local fire = Instance.new("Fire")
			fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 2.4, 6, look.glow, look.glow:Lerp(C(255, 255, 255), 0.4)
			fire.Parent = bowl
			light(bowl, look.glow, 14, 1.8)
		end
	end

	-- smaller islands drifting in the distance
	local islets = {}
	for i = 1, 9 do
		local a = rand(0, PI * 2)
		local r = rand(48, 90)
		local y = rand(-25, 18)
		local w = rand(6, 14)
		local top = part("Islet", V(1, w, w), CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * flat, ground, look.top, Enum.PartType.Cylinder)
		local under = wedge("IsletRoot", V(w * 0.8, w * 0.9, w * 0.8), CFrame.new(math.cos(a) * r, y - w * 0.45, math.sin(a) * r) * ANG(PI, rand(0, 3), 0), look.rock, Enum.Material.Slate)
		local deco = part("IsletDeco", V(1, w * 0.4, 1), CFrame.new(math.cos(a) * r, y + w * 0.2, math.sin(a) * r), look.accent, Enum.Material.SmoothPlastic)
		table.insert(islets, { parts = { top, under, deco }, base = { top.CFrame, under.CFrame, deco.CFrame }, phase = rand(0, 6) })
	end

	-- weather over the island
	local sky = part("Weather", V(50, 1, 50), CFrame.new(0, 24, 0), C(255, 255, 255))
	sky.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = look.weather == "ember" and FIRE or (look.weather == "snow" and SMOKE or SPARK)
	e.Rate = 34
	e.Lifetime = NumberRange.new(5, 8)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Color = ColorSequence.new(look.glow, look.glow:Lerp(C(255, 255, 255), 0.5))
	e.LightEmission = (look.weather == "snow" or look.weather == "leaf") and 0 or 0.8
	e.Size = NumberSequence.new(look.weather == "snow" and 0.45 or 0.3)
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	if look.weather == "leaf" then
		e.Color = ColorSequence.new(C(120, 180, 80), C(220, 180, 70))
	elseif look.weather == "ember" or look.weather == "mote" or look.weather == "gold" then
		sky.CFrame = CFrame.new(origin + V(0, 0.2, 0))
		e.EmissionDirection = Enum.NormalId.Top
	end
	e.Parent = sky

	return {
		model = model, look = look, portals = portals,
		-- gentle motion for the background islets and the portals' swirl
		animate = function(t)
			for _, isl in ipairs(islets) do
				local dy = math.sin(t * 0.6 + isl.phase) * 0.8
				for j, p in ipairs(isl.parts) do
					p.CFrame = isl.base[j] + V(0, dy, 0)
				end
			end
			if Portal and Portal.Spin then
				for _, pr in pairs(portals) do
					pcall(Portal.Spin, pr.refs, t)
				end
			end
			ring.Transparency = 0.75 + math.sin(t * 2) * 0.08
		end,
	}
end

function Stage.Grade(camera, worldId)
	local look = LOOK[worldId] or LOOK.Forest
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StageGrade"
	cc.TintColor = look.tint
	cc.Saturation = 0.12
	cc.Contrast = 0.08
	cc.Parent = camera
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "StageBloom"
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.6, 28, 0.92
	bloom.Parent = camera
	return { cc, bloom }
end

return Stage
