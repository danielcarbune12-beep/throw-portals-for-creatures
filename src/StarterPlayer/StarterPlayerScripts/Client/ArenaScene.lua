-- ArenaScene: turns the compact biome vignette (ExpeditionScene) into a full battle map for the
-- top-down battle scene: a wide arena ringed by cliffs, a stone-edged road lit by torches, an
-- entry portal, a boss arena with glowing runes, pillars and banners, lots of biome scenery,
-- drifting weather particles and a colour grade per world. Built in the scene's own coordinates
-- (the route from Shared/ExpeditionBattle); the caller moves it into place.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Battle = require(RS.Shared.ExpeditionBattle)
local okPortal, Portal = pcall(require, RS.Shared.PortalBuilder)
local Arena = {}
local V, C, ANG = Vector3.new, Color3.fromRGB, CFrame.Angles

local LOOK = {
	Forest = { glow = C(255, 196, 110), weather = "leaf", tint = C(235, 255, 225), sat = 0.15, accent = C(70, 150, 80), stone = C(110, 114, 104) },
	Volcano = { glow = C(255, 120, 40), weather = "ember", tint = C(255, 225, 205), sat = 0.2, accent = C(220, 70, 30), stone = C(70, 58, 56) },
	Frozen = { glow = C(150, 210, 255), weather = "snow", tint = C(225, 240, 255), sat = 0, accent = C(120, 190, 240), stone = C(170, 190, 205) },
	Crystal = { glow = C(190, 140, 255), weather = "sparkle", tint = C(240, 230, 255), sat = 0.2, accent = C(140, 100, 230), stone = C(90, 84, 120) },
	Candy = { glow = C(255, 150, 210), weather = "confetti", tint = C(255, 238, 248), sat = 0.25, accent = C(240, 110, 170), stone = C(230, 200, 220) },
	Space = { glow = C(140, 220, 255), weather = "star", tint = C(220, 225, 255), sat = 0.1, accent = C(110, 120, 230), stone = C(70, 74, 96) },
	Shadow = { glow = C(170, 90, 255), weather = "mote", tint = C(225, 210, 245), sat = -0.05, accent = C(130, 60, 200), stone = C(52, 46, 66) },
	Heaven = { glow = C(255, 230, 150), weather = "gold", tint = C(255, 250, 235), sat = 0.1, accent = C(240, 196, 80), stone = C(236, 230, 214) },
}
Arena.Look = LOOK

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function rng(seed)
	local s = seed
	return function(a, b)
		s = (s * 48271) % 2147483647
		local r = s / 2147483647
		return a and (a + (b - a) * r) or r
	end
end

function Arena.Decorate(model, worldId)
	local def = Config.Worlds[worldId] or Config.Worlds.Forest
	local look = LOOK[worldId] or LOOK.Forest
	local ground = def.groundColor
	local stone = look.stone
	local rand = rng(#worldId * 7919 + 17)

	local function part(name, size, cf, color, material, shape, class)
		local p = Instance.new(class or "Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Parent = model
		return p
	end
	local function light(p, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness, l.Shadows = color, range or 10, brightness or 1.5, false
		l.Parent = p
		return l
	end

	-- wide ground and a ring of cliffs closing the arena in
	part("ArenaGround", V(96, 1, 76), CFrame.new(0, -0.45, 0), ground:Lerp(C(0, 0, 0), 0.12), Enum.Material.Grass)
	part("ArenaGroundInner", V(40, 0.4, 28), CFrame.new(0, -0.05, 0), ground:Lerp(stone, 0.18))
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2
		local r = 40 + rand(-3, 3)
		local h = rand(9, 20)
		local w = rand(9, 14)
		local cliff = part("Cliff", V(w, h, rand(7, 11)), CFrame.new(math.cos(a) * r, h / 2 - 0.5, math.sin(a) * r * 0.8) * ANG(0, -a + rand(-0.3, 0.3), rand(-0.08, 0.08)),
			stone:Lerp(C(0, 0, 0), rand(0, 0.25)), Enum.Material.Slate)
		if rand() < 0.6 then
			part("CliffCap", V(w * 0.9, 0.6, cliff.Size.Z * 0.9), cliff.CFrame * CFrame.new(0, h / 2 + 0.25, 0), ground, Enum.Material.Grass)
		end
	end

	-- stone-edged road with torches
	local path = Battle.Path
	for li = 1, #path - 1 do
		local a, b = V(path[li][1], 0, path[li][2]), V(path[li + 1][1], 0, path[li + 1][2])
		local dir = (b - a).Unit
		local sideV = V(-dir.Z, 0, dir.X)
		local len = (b - a).Magnitude
		part("Road", V(2.6, 0.12, len + 1.2), CFrame.lookAt((a + b) / 2 + V(0, 0.42, 0), b + V(0, 0.42, 0)), stone:Lerp(C(150, 140, 120), 0.35), Enum.Material.Cobblestone)
		local steps = math.floor(len / 1.3)
		for s = 0, steps do
			local at = a + dir * (s * 1.3)
			for _, sx in { -1, 1 } do
				part("RoadEdge", V(0.5, 0.35, 0.9), CFrame.lookAt(at + sideV * sx * 1.6 + V(0, 0.5, 0), at + sideV * sx * 1.6 + dir + V(0, 0.5, 0)) * ANG(0, rand(-0.2, 0.2), 0),
					stone:Lerp(C(0, 0, 0), rand(0, 0.2)), Enum.Material.Slate)
			end
		end
		local torches = math.max(1, math.floor(len / 4.5))
		for tI = 1, torches do
			local at = a + dir * (len * tI / (torches + 1))
			local sx = (tI + li) % 2 == 0 and 1 or -1
			local foot = at + sideV * sx * 2.4
			part("TorchPost", V(0.3, 2.6, 0.3), CFrame.new(foot + V(0, 1.7, 0)), C(80, 58, 40), Enum.Material.Wood)
			local bowl = part("TorchBowl", V(0.7, 0.3, 0.7), CFrame.new(foot + V(0, 3.05, 0)), C(60, 56, 60), Enum.Material.Metal)
			local flame = part("TorchFlame", V(0.35, 0.5, 0.35), CFrame.new(foot + V(0, 3.4, 0)), look.glow, Enum.Material.Neon)
			flame.Transparency = 0.2
			local fire = Instance.new("Fire")
			fire.Size, fire.Heat = 2.2, 6
			fire.Color, fire.SecondaryColor = look.glow, look.glow:Lerp(C(255, 255, 255), 0.4)
			fire.Parent = bowl
			light(flame, look.glow, 12, 1.8)
		end
	end

	-- entry portal the team steps out of
	local sx, sz, dx, dz = Battle.PathPoint(0)
	if okPortal and Portal and Portal.BuildGate then
		local ok, gate = pcall(Portal.BuildGate, "Basic", 3.2)
		if ok and gate then
			local at = V(sx, 0.4 + 3.2 + 0.4, sz) - V(dx, 0, dz).Unit * 1.2
			gate:PivotTo(CFrame.lookAt(at, at + V(dx, 0, dz)))
			for _, d in ipairs(gate:GetDescendants()) do
				if d:IsA("BasePart") then d.Anchored = true end
			end
			gate.Parent = model
		end
	end

	-- boss arena: round platform, rune circle, pillars with banners and a back arch
	local boss = Battle.PathPoint(0.9)
	local bx, bz = Battle.PathPoint(0.9)
	local bossAt = V(bx, 0, bz)
	part("BossPlatform", V(0.6, 11, 11), CFrame.new(bossAt + V(0, 0.5, 0)) * ANG(0, 0, math.pi / 2), stone:Lerp(C(255, 255, 255), 0.15), Enum.Material.Marble, Enum.PartType.Cylinder)
	part("BossPlatformRim", V(0.4, 11.8, 11.8), CFrame.new(bossAt + V(0, 0.3, 0)) * ANG(0, 0, math.pi / 2), stone:Lerp(C(0, 0, 0), 0.3), Enum.Material.Slate, Enum.PartType.Cylinder)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local rune = part("Rune", V(0.7, 0.08, 0.25), CFrame.new(bossAt + V(math.cos(a) * 4.4, 0.83, math.sin(a) * 4.4)) * ANG(0, -a, 0), look.glow, Enum.Material.Neon)
		rune.Transparency = 0.1
	end
	local ring = part("RuneRing", V(0.1, 7.2, 7.2), CFrame.new(bossAt + V(0, 0.82, 0)) * ANG(0, 0, math.pi / 2), look.glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.75
	light(ring, look.glow, 16, 1.2)
	for i = 0, 3 do
		local a = math.pi / 4 + i * math.pi / 2
		local at = bossAt + V(math.cos(a) * 6.2, 0, math.sin(a) * 6.2)
		part("BossPillar", V(1.2, 7, 1.2), CFrame.new(at + V(0, 4, 0)), stone:Lerp(C(255, 255, 255), 0.25), Enum.Material.Marble)
		part("BossPillarCap", V(1.7, 0.5, 1.7), CFrame.new(at + V(0, 7.6, 0)), C(220, 180, 80), Enum.Material.Metal)
		local banner = part("Banner", V(0.08, 3.4, 1.3), CFrame.lookAt(at + V(0, 5, 0), bossAt + V(0, 5, 0)) * CFrame.new(0, 0, -0.7), look.accent, Enum.Material.Fabric)
		part("BannerTrim", V(0.1, 0.25, 1.35), banner.CFrame * CFrame.new(0, -1.6, 0), C(240, 200, 90), Enum.Material.Metal)
		local brazier = part("Brazier", V(0.9, 0.4, 0.9), CFrame.new(at + V(0, 8.05, 0)), C(60, 56, 60), Enum.Material.Metal)
		local f = Instance.new("Fire")
		f.Size, f.Heat, f.Color, f.SecondaryColor = 3, 8, look.glow, C(255, 240, 200)
		f.Parent = brazier
		light(brazier, look.glow, 14, 1.6)
	end

	-- scenery around the arena, themed per biome
	local function clear(x, z)
		-- keep props off the road and the play space
		return math.abs(x) > 15 or math.abs(z) > 11
	end
	for i = 1, 46 do
		local x, z = rand(-36, 36), rand(-29, 29)
		if clear(x, z) then
			local s = rand(0.8, 1.6)
			if worldId == "Forest" then
				part("Trunk", V(0.8, 4 * s, 0.8), CFrame.new(x, 2 * s, z), C(96, 70, 48), Enum.Material.Wood)
				for lv = 0, 2 do
					local w = (3.6 - lv * 0.9) * s
					part("Leaves", V(w, 1.4 * s, w), CFrame.new(x, (3.6 + lv * 1.1) * s, z) * ANG(0, lv * 0.5, 0), C(60 + lv * 12, 130 + lv * 10, 60), Enum.Material.Grass)
				end
			elseif worldId == "Volcano" then
				local rock = part("Basalt", V(2 * s, 3 * s, 2 * s), CFrame.new(x, 1.4 * s, z) * ANG(0, rand(0, 3), rand(-0.2, 0.2)), C(60, 52, 54), Enum.Material.Basalt)
				if rand() < 0.4 then
					local lava = part("LavaPool", V(0.2, 4 * s, 4 * s), CFrame.new(x + 2.5, 0.16, z) * ANG(0, 0, math.pi / 2), C(255, 110, 30), Enum.Material.Neon, Enum.PartType.Cylinder)
					light(lava, C(255, 120, 40), 14, 2)
				end
				if rand() < 0.3 then
					local e = Instance.new("ParticleEmitter")
					e.Texture, e.Rate, e.Lifetime, e.Speed = SMOKE, 3, NumberRange.new(3, 5), NumberRange.new(2, 3)
					e.Color = ColorSequence.new(C(70, 60, 60))
					e.Size = NumberSequence.new(1.5, 4)
					e.Transparency = NumberSequence.new(0.4, 1)
					e.Parent = rock
				end
			elseif worldId == "Frozen" then
				part("IceSpike", V(1.4 * s, 5 * s, 1.4 * s), CFrame.new(x, 2.3 * s, z) * ANG(rand(-0.15, 0.15), rand(0, 3), rand(-0.15, 0.15)), C(170, 220, 245), Enum.Material.Ice)
				part("Snowdrift", V(3.5 * s, 0.8, 2.5 * s), CFrame.new(x + 1, 0.1, z), C(245, 250, 255), Enum.Material.Snow)
			elseif worldId == "Crystal" then
				local col = rand() < 0.5 and C(150, 110, 240) or C(100, 220, 235)
				for c = 1, 3 do
					local cr = part("Crystal", V(0.9 * s, (2 + c) * s, 0.9 * s), CFrame.new(x + c * 0.6 - 1, (1 + c * 0.5) * s, z) * ANG(rand(-0.3, 0.3), rand(0, 3), rand(-0.3, 0.3)), col, Enum.Material.Neon)
					cr.Transparency = 0.15
					if c == 2 then light(cr, col, 10, 1.4) end
				end
			elseif worldId == "Candy" then
				for band = 0, 4 do
					part("CandyCane", V(0.8 * s, 0.9 * s, 0.8 * s), CFrame.new(x, (0.45 + band * 0.9) * s, z), band % 2 == 0 and C(240, 80, 110) or C(255, 250, 250))
				end
				part("Gumdrop", V(2 * s, 1.4 * s, 2 * s), CFrame.new(x + 2, 0.7 * s, z + 1), C(130, 220, 170), Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.2
			elseif worldId == "Space" then
				local moon = part("MoonRock", V(2.4 * s, 1.6 * s, 2.4 * s), CFrame.new(x, 0.6 * s, z) * ANG(0, rand(0, 3), 0), C(120, 124, 140), Enum.Material.Slate, Enum.PartType.Ball)
				if rand() < 0.35 then
					local beacon = part("Beacon", V(0.4, 0.4, 0.4), moon.CFrame * CFrame.new(0, 1.2 * s, 0), C(140, 230, 255), Enum.Material.Neon, Enum.PartType.Ball)
					light(beacon, C(140, 230, 255), 10, 1.5)
				end
			elseif worldId == "Shadow" then
				part("DeadTree", V(0.6, 5 * s, 0.6), CFrame.new(x, 2.5 * s, z) * ANG(0, 0, rand(-0.2, 0.2)), C(60, 54, 70), Enum.Material.Wood)
				part("Branch", V(0.35, 2.2 * s, 0.35), CFrame.new(x + 0.6, 3.8 * s, z) * ANG(0, rand(0, 3), -0.8), C(60, 54, 70), Enum.Material.Wood)
				if rand() < 0.4 then
					local orb = part("SoulOrb", V(0.6, 0.6, 0.6), CFrame.new(x + 1, 1.5, z + 1), C(180, 100, 255), Enum.Material.Neon, Enum.PartType.Ball)
					light(orb, C(170, 90, 255), 10, 1.4)
				end
			else -- Heaven
				part("Column", V(1.2, 5 * s, 1.2), CFrame.new(x, 2.5 * s, z), C(240, 236, 224), Enum.Material.Marble)
				part("Cloud", V(4 * s, 1.4 * s, 3 * s), CFrame.new(x + 1.5, 0.4, z + 1), C(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball).Transparency = 0.15
			end
		end
	end

	-- drifting weather over the whole arena
	local sky = part("Weather", V(70, 1, 56), CFrame.new(0, 22, 0), C(255, 255, 255))
	sky.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = look.weather == "ember" and FIRE or (look.weather == "snow" and SMOKE or SPARK)
	e.Rate = 40
	e.Lifetime = NumberRange.new(5, 8)
	e.EmissionDirection = (look.weather == "ember" or look.weather == "mote" or look.weather == "gold") and Enum.NormalId.Top or Enum.NormalId.Bottom
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(20, 20)
	e.Color = ColorSequence.new(look.glow, look.glow:Lerp(C(255, 255, 255), 0.5))
	e.LightEmission = (look.weather == "snow" or look.weather == "leaf") and 0 or 0.8
	e.Size = NumberSequence.new(look.weather == "snow" and 0.4 or 0.3)
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	if look.weather == "leaf" then
		e.Color = ColorSequence.new(C(120, 180, 80), C(220, 180, 70))
		e.Size = NumberSequence.new(0.35)
	elseif look.weather == "ember" then
		sky.CFrame = CFrame.new(0, -1, 0)
	elseif look.weather == "mote" or look.weather == "gold" then
		sky.CFrame = CFrame.new(0, 0, 0)
	end
	e.Parent = sky
	return look
end

-- colour grade + bloom on the camera while the battle scene is open
function Arena.Grade(camera, worldId)
	local look = LOOK[worldId] or LOOK.Forest
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "ArenaGrade"
	cc.TintColor = look.tint
	cc.Saturation = look.sat
	cc.Contrast = 0.08
	cc.Brightness = 0.02
	cc.Parent = camera
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "ArenaBloom"
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.6, 28, 0.92
	bloom.Parent = camera
	return { cc, bloom }
end

return Arena
