-- BiomeShadow: Shadow Dimension, Z [1800, 2400). Reference: roblox pets/Maps/07_Shadow_Biome.png (1:1 inventory).
-- Authored as seen in the reference (K.mirror = true: design -X = screen-left).
--  LEFT : ShL1 decorative side chasm (teal glowing veins, mist) · ShL2 twisted bare trees · ShL3 crimson plants ·
--         ShL4 broken double-arch ruin · ShL5 red banner posts, small shrines
--  RIGHT: ShR1 fractured gothic cathedral (tall gable facade, huge pointed rose window with teal tracery, slim
--         spires, buttresses, broken arched walls, grand stairs, red/gold banners) · ShR2 leaning broken obelisk
--         with teal rune · ShR3 twisted trees · ShR4 crimson plants, braziers with red flame
--  BACK : floating rock shards around a swirling purple vortex (off the corridor), glowing ruined columns
--  CENTRE: pale lavender tiled road with gold inlay borders.
-- Location: ServerScriptService > Server > BiomeShadow (ModuleScript)

local K = require(script.Parent.WorldKit)
local V3, CF, ANG, PI, M = K.V3, K.CF, K.ANG, K.PI, K.M
local C = K.C

local B = {}

local STONE, STONE_D, STONE_L = C(112, 92, 128), C(78, 62, 96), C(150, 130, 166)
local PLUM, TEAL, CRIMSON, GOLD = C(64, 40, 70), C(80, 230, 210), C(196, 36, 60), C(214, 170, 90)
local TILE, TILE_L = C(176, 158, 196), C(196, 180, 214)

local function rockCol() return STONE:Lerp(STONE_D, K.r(0, 0.8)):Lerp(STONE_L, K.r(0, 0.2)) end

local function facade(s, x1, top, za, zb)
	local z = za
	while z < zb - 1 do
		local l = math.min(K.r(4, 7), zb - z)
		local h = top + K.r(-0.3, 0.8)
		K.bevel(CF(s * (x1 + 1.1), h / 2 - 0.4, z + l / 2) * ANG(0, K.r(-0.06, 0.06), 0), V3(2.8, h + 0.6, l - 0.2), rockCol(), M.Slate)
		z += l
	end
end

local function rune(cf, h)
	local r = K.block(cf, V3(0.25, h, 0.5), TEAL, M.Neon, false, 0.1)
	K.tag(r, "TPFC_Pulse", { Period = K.r(10, 16), Base = 0.55, Peak = 0.05 })
	return r
end

-- ShL2 / ShR3: twisted bare tree with angular branches
local function twistedTree(pos, s)
	local top, mid = K.limb(pos, pos + V3(2 * s, 4 * s, 0), pos + V3(-1 * s, 9 * s, 1 * s), 1.6 * s, 0.8 * s, 5, PLUM, M.Wood, true)
	for i = 1, 6 do
		local base = (i <= 3) and top or mid
		local a = i / 6 * PI * 2 + K.r(-0.4, 0.4)
		local d = V3(math.cos(a), 0, math.sin(a))
		local _, m2 = K.limb(base, base + d * 2.5 * s + V3(0, 1.5 * s, 0), base + d * 5.5 * s + V3(0, K.r(2, 4) * s, 0), 0.6 * s, 0.2 * s, 3, PLUM)
		K.limb(m2, m2 + d * 1 * s + V3(0, 1.4 * s, 0), m2 + V3(-d.Z, 0, d.X) * 2 * s + V3(0, 2.6 * s, 0), 0.3 * s, 0.12 * s, 2, PLUM)
	end
	for i = 0, 2 do
		local a = i / 3 * PI * 2
		K.limb(pos + V3(0, 1.4 * s, 0), pos + V3(math.cos(a), 0.4, math.sin(a)) * 1.6 * s, pos + V3(math.cos(a), -0.2, math.sin(a)) * 3 * s, 0.8 * s, 0.3 * s, 2, PLUM)
	end
end

-- ShL3 / ShR4: crimson spiky plant
local function crimson(pos, s)
	for i = 0, 5 do
		local a = i / 6 * PI * 2 + K.r(-0.2, 0.2)
		K.wedge(CF(pos) * ANG(0, a, 0) * CF(0, 0.7 * s, -1.2 * s) * ANG(-0.6, 0, 0), V3(1, 0.25, 2.6) * s, i % 2 == 0 and CRIMSON or C(220, 56, 80), M.SmoothPlastic)
	end
	for i = 0, 3 do
		local a = i / 4 * PI * 2 + 0.4
		K.wedge(CF(pos) * ANG(0, a, 0) * CF(0, 1.2 * s, -0.6 * s) * ANG(-1.0, 0, 0), V3(0.8, 0.2, 1.8) * s, C(236, 70, 96), M.SmoothPlastic)
	end
end

-- ShL5 / ShR1: red banner with gold emblem on a stone post
local function bannerPost(pos, yaw, h)
	h = h or 10
	local cf = CF(pos) * ANG(0, yaw, 0)
	K.bevel(cf * CF(0, 0.6, 0), V3(2.6, 1.2, 2.6), STONE_D, M.Slate)
	K.block(cf * CF(0, h / 2 + 1, 0), V3(1, h, 1), STONE, M.Slate, true)
	K.pyramid(cf * CF(0, h + 1, 0), 1.6, 1.4, STONE_L, M.Slate)
	K.block(cf * CF(0, h - 0.2, -1), V3(0.3, 0.3, 3.2), GOLD, M.Metal)
	local b = K.block(cf * CF(0, h - 3.4, -1.6), V3(0.2, 6, 2.6), CRIMSON, M.Fabric)
	K.tag(b, "TPFC_Sway", { Amp = 0.02, Period = 6 })
	K.block(cf * CF(0.13, h - 3, -1.6) * ANG(PI / 4, 0, 0), V3(0.1, 1.2, 1.2), GOLD, M.Metal)
	K.block(cf * CF(0.12, h - 0.8, -1.6), V3(0.1, 0.25, 2.6), GOLD, M.Metal)
	K.wedge(cf * CF(0, h - 6.9, -2.25) * ANG(PI, 0, 0), V3(0.2, 1, 1.3), CRIMSON, M.Fabric)
	K.wedge(cf * CF(0, h - 6.9, -0.95) * ANG(PI, PI, 0), V3(0.2, 1, 1.3), CRIMSON, M.Fabric)
end

-- ShR4: brazier (stone pedestal with teal rune, red flame)
local function brazier(pos)
	K.bevel(CF(pos + V3(0, 1, 0)), V3(3.4, 2, 3.4), STONE_D, M.Slate)
	K.bevel(CF(pos + V3(0, 2.8, 0)), V3(2.6, 1.6, 2.6), STONE, M.Slate)
	for i = 0, 3 do K.wedge(CF(pos + V3(0, 4.1, 0)) * ANG(0, i * PI / 2, 0) * CF(0, 0, -1.2), V3(3, 1, 0.6), GOLD, M.Metal) end
	rune(CF(pos + V3(-1.32, 2.8, 0)) * ANG(0, PI / 2, 0) * ANG(0, PI / 2, 0), 1)
	local core = K.block(CF(pos + V3(0, 4.4, 0)), V3(1.2, 0.6, 1.2), C(255, 90, 70), M.Neon)
	local f = Instance.new("Fire"); f.Color = C(255, 70, 60); f.SecondaryColor = C(255, 160, 80); f.Size = 4; f.Heat = 6; f.Parent = core
	K.lamp(core, C(255, 90, 80), 16, 1)
end

-- ShR2: leaning broken obelisk with a teal rune
local function brokenObelisk(pos, h, lean)
	local cf = CF(pos) * ANG(0, K.r(0, PI), 0)
	for i = 1, 4 do K.bevel(cf * CF(K.r(-3, 3), 0.7, K.r(-3, 3)) * ANG(0, K.r(0, PI), K.r(-0.2, 0.2)), V3(K.r(1.8, 3), 1.4, K.r(1.8, 3)), rockCol(), M.Slate) end
	local o = CF(pos + V3(0, h / 2, 0)) * ANG(0, 0, lean)
	K.bevel(o, V3(4.4, h, 3.2), STONE_L, M.Slate)
	K.wedge(o * CF(0, h / 2 + 1.5, 0), V3(4.4, 3, 3.2), STONE_L, M.Slate)
	rune(o * CF(-2.25, 1, 0), h * 0.45)
	K.block(o * CF(-2.25, h * 0.12, 0) * ANG(PI / 4, 0, 0), V3(0.3, 1.4, 1.4), TEAL, M.Neon)
end

-- ShL4: broken double-arch ruin
local function doubleArch(pos)
	local cf = CF(pos) * ANG(0, PI / 2, 0)
	K.arch(cf * CF(-5, 0, 0), 6, 9, 2.4, STONE, M.Slate, nil, nil, 7)
	K.arch(cf * CF(5, 0, 0), 6, 9, 2.4, STONE, M.Slate, nil, nil, 7)
	K.block(cf * CF(0, 14.6, 0), V3(22, 1.4, 3), STONE_L, M.Slate)
	for i = 1, 4 do K.bevel(CF(pos + V3(K.r(-4, 4), 0.7, K.r(-12, 12))) * ANG(0, K.r(0, PI), K.r(-0.2, 0.2)), V3(K.r(1.6, 2.6), 1.4, K.r(1.6, 2.6)), STONE, M.Slate) end
end

-- ShL1: decorative side chasm (outside the corridor): dark void floor + rock walls with teal veins + mist
local function chasm(z1, z2)
	local zc = (z1 + z2) / 2
	K.block(CF(-60, 0.06, zc), V3(20, 0.12, z2 - z1), C(18, 10, 26), M.SmoothPlastic)
	for z = z1, z2 - 4, 6 do
		for _, x in ipairs({ -50, -70 }) do
			local h = K.r(3, 7)
			K.bevel(CF(x + K.r(-1, 1), h / 2 - 0.3, z + 3), V3(K.r(4, 6), h + 0.6, 6), rockCol(), M.Slate)
			if K.chance(0.4) then rune(CF(x + (x < -60 and 2.6 or -2.6), h * 0.5, z + 3), h * 0.7) end
		end
	end
	local mist = K.block(CF(-60, 1, zc), V3(16, 1, z2 - z1 - 6), C(200, 190, 230), M.SmoothPlastic, false, 1)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Color = ColorSequence.new(C(220, 210, 240))
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.75), NumberSequenceKeypoint.new(1, 1) })
	pe.Size = NumberSequence.new(4, 8)
	pe.Lifetime = NumberRange.new(6, 9)
	pe.Rate = 3
	pe.Speed = NumberRange.new(0.3, 0.8)
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.Parent = mist
end

-- ShR1: the fractured gothic cathedral (front faces the lane, -X design)
local function cathedral(c)
	-- raised plinth + grand stairs
	K.bevel(CF(c + V3(8, 2, 0)), V3(56, 4, 90), rockCol(), M.Slate)
	K.addSurface(c.X - 20, c.X + 36, c.Z - 45, c.Z + 45, 4)
	K.stairs(CF(c + V3(-24, 0, 0)) * ANG(0, -PI / 2, 0), 18, 6, 0.7, 1.5, STONE_L, M.Slate)
	for s = -1, 1, 2 do K.bevel(CF(c + V3(-24, 2.4, s * 10)), V3(9.6, 4.8, 2), STONE, M.Slate) end
	-- central gable facade with the huge pointed rose window
	local fx = c.X - 2
	K.bevel(CF(fx + 3, 4 + 18, c.Z), V3(6, 36, 30), STONE, M.Slate)
	K.wedge(CF(fx + 3, 4 + 36 + 6, c.Z - 7.5) * ANG(0, PI, 0), V3(6, 12, 15), STONE, M.Slate)
	K.wedge(CF(fx + 3, 4 + 36 + 6, c.Z + 7.5), V3(6, 12, 15), STONE, M.Slate)
	K.pointedArch(CF(fx - 0.2, 4 + 6, c.Z) * ANG(0, PI / 2, 0), 14, 16, 9, 2, STONE_L, M.Slate, TEAL)
	local glass = K.block(CF(fx - 0.1, 4 + 18, c.Z), V3(0.3, 22, 13), C(40, 120, 130), M.Glass, false, 0.2)
	K.lamp(glass, TEAL, 34, 1.4)
	for i = 0, 5 do -- rose tracery: spokes + rings
		K.block(CF(fx - 0.4, 4 + 22, c.Z) * ANG(i * PI / 6, 0, 0), V3(0.25, 11, 0.35), TEAL, M.Neon)
	end
	for _, r in ipairs({ 5.2, 2.4 }) do
		for i = 0, 15 do
			local a0, a1 = i / 16 * PI * 2, (i + 1) / 16 * PI * 2
			local p0 = V3(fx - 0.45, 4 + 22 + math.sin(a0) * r, c.Z + math.cos(a0) * r)
			local p1 = V3(fx - 0.45, 4 + 22 + math.sin(a1) * r, c.Z + math.cos(a1) * r)
			K.block(CFrame.lookAt((p0 + p1) / 2, p1), V3(0.3, 0.3, (p1 - p0).Magnitude + 0.1), TEAL, M.Neon)
		end
	end
	for k = -1, 1 do K.block(CF(fx - 0.4, 4 + 11, c.Z + k * 3.4), V3(0.25, 12, 0.35), TEAL, M.Neon) end
	-- doorway below the window
	K.pointedArch(CF(fx - 0.6, 4, c.Z) * ANG(0, PI / 2, 0), 6, 6, 3, 1.4, STONE_L, M.Slate)
	K.block(CF(fx - 0.2, 4 + 4, c.Z), V3(0.3, 8, 5.8), C(24, 16, 34), M.SmoothPlastic)
	-- flanking towers with slim spires + buttresses
	for s = -1, 1, 2 do
		local tz = c.Z + s * 20
		K.bevel(CF(fx + 4, 4 + 22, tz), V3(10, 44, 10), rockCol(), M.Slate)
		K.cone(V3(fx + 4, 4 + 44, tz), 5.4, 22, 6, STONE_D, STONE, M.Slate)
		K.cone(V3(fx + 4, 4 + 66, tz), 0.8, 4, 5, GOLD, K.dark(GOLD, 0.2), M.Metal)
		K.pointedArch(CF(fx - 1.1, 4 + 22, tz) * ANG(0, PI / 2, 0), 3, 7, 3, 0.8, STONE_L, M.Slate, TEAL)
		K.block(CF(fx - 1, 4 + 26, tz), V3(0.2, 9, 3), C(40, 120, 130), M.Glass, false, 0.2)
		bannerPost(V3(fx - 9, 4, c.Z + s * 9), PI / 2, 12)
		for k = 0, 2 do
			local bz = c.Z + s * (30 + k * 10)
			K.wedge(CF(fx + 2, 4 + 9, bz) * ANG(0, -PI / 2, 0), V3(3, 18, 8), STONE_D, M.Slate)
			K.cone(V3(fx + 6, 4 + 18, bz), 1.6, 9, 5, STONE, STONE_D, M.Slate)
			-- broken nave wall with pointed windows
			K.bevel(CF(fx + 10, 4 + 10 - k * 2, bz), V3(4, 20 - k * 4, 9), rockCol(), M.Slate)
			K.pointedArch(CF(fx + 7.8, 4 + 6, bz) * ANG(0, PI / 2, 0), 3, 6, 2.6, 0.8, STONE_L, M.Slate)
		end
	end
	-- fractured roofline: broken chunks + slowly drifting stones
	for _ = 1, 5 do
		K.bevel(CF(c + V3(K.r(10, 30), 4 + K.r(0.5, 1.5), K.r(-40, 40))) * ANG(K.r(-0.3, 0.3), K.r(0, PI), K.r(-0.3, 0.3)), V3(K.r(2, 4), K.r(1.5, 3), K.r(2, 4)), STONE, M.Slate)
	end
	for _ = 1, 5 do
		local st = K.block(CF(c + V3(K.r(0, 30), K.r(48, 70), K.r(-30, 30))) * ANG(K.r(0, 1), K.r(0, 3), 0), V3(1, 1, 1) * K.r(3, 6), STONE_D, M.Slate)
		K.tag(st, "TPFC_Bob", { Amp = 1.2, Period = K.r(8, 12), Spin = K.r(2, 4) })
	end
end

function B.Build(b)
	K.Seed(7007)
	K.ResetSurfaces()
	K.mirror = true
	local z1, z2 = b[1], b[2]
	K.terraces(z1, z2, {
		rock = STONE, rockMat = M.Slate, cap = C(96, 74, 110), capMat = M.Slate, drip = false, tiers = 3,
		h1 = { 1.6, 3.4 }, h2 = { 5, 10 }, h3 = { 8, 18 },
		skip = { { 1, 2040, 2200 }, { -1, 1870, 1990 } },
		facade = facade,
	})
	---------------------------------------------------------------- LEFT: chasm, trees, crimson plants, double arch, banner posts
	chasm(1870, 1990)
	for _, p in ipairs({ { -54, 1850, 1.6 }, { -60, 2010, 1.8 }, { -66, 2150, 1.5 }, { -58, 2290, 1.7 }, { -84, 1940, 2 } }) do twistedTree(K.at(p[1], p[2]), p[3]) end
	doubleArch(K.at(-60, 2080))
	doubleArch(K.at(-74, 2340))
	for _, p in ipairs({ { -50, 1830 }, { -52, 2050 }, { -50, 2230 } }) do bannerPost(K.at(p[1], p[2]), PI / 2, 10) end
	---------------------------------------------------------------- RIGHT: cathedral, obelisk, trees, braziers
	cathedral(V3(80, 0, 2120))
	brokenObelisk(K.at(56, 1990), 18, 0.18)
	brokenObelisk(K.at(60, 2280), 14, -0.15)
	for _, p in ipairs({ { 56, 1860, 1.7 }, { 62, 2240, 1.6 }, { 58, 2370, 1.8 } }) do twistedTree(K.at(p[1], p[2]), p[3]) end
	for _, p in ipairs({ { 50, 2030 }, { 50, 2210 }, { 52, 1900 } }) do brazier(K.at(p[1], p[2])) end
	---------------------------------------------------------------- crimson plants on terrace tops + lane edges
	for _, r in ipairs(K.surfaces) do
		local xa, xb = math.max(r[1], -90), math.min(r[2], 90)
		if xb - xa > 3 then
			for _ = 1, math.floor((xb - xa) * (r[4] - r[3]) / 220) do
				local x, z = K.r(xa + 2, xb - 2), K.r(r[3] + 2, r[4] - 2)
				if math.abs(x) >= 48 and not (x > 55 and z > 2070 and z < 2170) then crimson(V3(x, r[5], z), K.r(0.9, 1.5)) end
			end
		end
	end
	for s = -1, 1, 2 do
		for z = z1 + 10, z2 - 8, 13 do
			local p = V3(s * K.r(38, 43), 0, z + K.r(-4, 4))
			if K.chance(0.55) then crimson(p, K.r(0.9, 1.3))
			else K.bevel(CF(p + V3(0, 0.6, 0)) * ANG(0, K.r(0, PI), 0), V3(K.r(2, 3.4), 1.4, K.r(2, 3.4)), rockCol(), M.Slate) end
		end
	end
	---------------------------------------------------------------- CENTRE: pale lavender tiled road with gold inlay borders
	for z = z1 + 1, z2 - 13, 14 do
		for x = -27.5, 27.5, 11 do
			K.block(CF(x + K.r(-0.15, 0.15), 0.18, z + 7), V3(10.7, 0.3, 13.7), TILE:Lerp(TILE_L, K.r(0, 1)), M.Slate)
		end
	end
	for s = -1, 1, 2 do
		K.block(CF(s * 33.4, 0.36, (z1 + z2) / 2), V3(0.6, 0.12, z2 - z1), GOLD, M.Metal)
		K.block(CF(s * 35.2, 0.3, (z1 + z2) / 2), V3(3, 0.3, z2 - z1), C(150, 130, 170), M.Slate)
		for z = z1 + 40, z2 - 40, 80 do
			K.block(CF(s * 29, 0.37, z) * ANG(0, s * 0.8, 0), V3(0.5, 0.12, 12), GOLD, M.Metal)
			K.block(CF(s * 29, 0.37, z + 9) * ANG(0, -s * 0.8, 0), V3(0.5, 0.12, 12), GOLD, M.Metal)
		end
	end
	---------------------------------------------------------------- BACK: vortex (off to the side) with floating shards, glowing ruined columns
	local vc = CF(-96, 46, 2380) * ANG(0, PI / 2 - 0.5, 0)
	for k = 0, 3 do
		for i = 0, 17 do
			local a0, a1 = i / 18 * PI * 2 + k * 0.5, (i + 1) / 18 * PI * 2 + k * 0.5
			local r = 30 - k * 6
			local p0, p1 = vc * V3(math.cos(a0) * r, math.sin(a0) * r, k * 2), vc * V3(math.cos(a1) * r, math.sin(a1) * r, k * 2)
			local seg = K.block(CFrame.lookAt((p0 + p1) / 2, p1), V3(3 - k * 0.4, 5 - k, (p1 - p0).Magnitude), C(170 + k * 20, 120 + k * 20, 220), M.Neon, false, 0.55 + k * 0.08)
			seg.CastShadow = false
		end
	end
	for _ = 1, 10 do
		local st = K.block(vc * CF(K.r(-40, 40), K.r(-30, 34), K.r(-10, 10)) * ANG(K.r(0, PI), K.r(0, PI), 0), V3(K.r(3, 7), K.r(5, 10), K.r(3, 6)), rockCol(), M.Slate)
		K.tag(st, "TPFC_Bob", { Amp = 1.5, Period = K.r(8, 14), Spin = K.r(1, 3) })
	end
	for s = -1, 1, 2 do
		for i = 0, 4 do
			local p = V3(s * K.r(60, 100), 0, 2300 + i * 20)
			K.column(p, K.r(14, 24), 2.4, STONE_L, M.Slate, GOLD)
			local g = K.block(CF(p + V3(0, 9, 0)), V3(0.5, 12, 0.5), C(255, 220, 160), M.Neon, false, 0.2)
			g.CastShadow = false
		end
	end
	---------------------------------------------------------------- transition to Heaven: warm light in cracks, pale stone columns
	for s = -1, 1, 2 do
		for _ = 1, 3 do
			local p = V3(s * K.r(44, 56), 0, K.r(2382, 2398))
			K.column(p, K.r(5, 9), 1.6, C(236, 228, 214), M.Marble, GOLD)
			K.block(CF(p + V3(0, 0.1, 0)), V3(4, 0.12, 0.3), C(255, 220, 150), M.Neon)
		end
	end
	K.mirror = false
end

return B
