-- BiomeVolcano: Volcano World, Z [150, 350). Reference: roblox pets/Maps/02_Volcano_Biome.png (1:1 inventory).
-- Authored as seen in the reference (K.mirror = true: design -X = screen-left).
--  LEFT : VL1 giant jagged volcano (spiky peaks, crater, smoke plume, two winding lava rivers) ·
--         VL2 cliff lavafall into a glowing pool · VL3 hexagonal basalt column clusters with molten seams ·
--         VL4 cooled-lava swirl plates · VL5 red spiky plants · VL6 gold-trimmed arch ruin glowing inside
--  RIGHT: VR1 smoking vent cones · VR2 gold-trimmed arch with red banner · VR3 basalt steps, red plants,
--         orange crystal shards · VR4 snow-capped peaks far right (transition into Frozen)
--  CENTRE: dark slab road with a raised border curb and branching glowing cracks; broken arched bridge in
--          the distance (side spans only — nothing crosses the throw corridor).
-- Location: ServerScriptService > Server > BiomeVolcano (ModuleScript)

local K = require(script.Parent.WorldKit)
local V3, CF, ANG, PI, M = K.V3, K.CF, K.ANG, K.PI, K.M
local C = K.C

local B = {}

local BASALT, DARK, ASH, HILITE = C(64, 54, 62), C(38, 32, 40), C(92, 82, 90), C(104, 90, 104)
local LAVA, LAVA_HOT, EMBER = C(236, 92, 22), C(255, 162, 52), C(206, 44, 34)
local GOLD = C(212, 162, 74)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function rockCol() return BASALT:Lerp(DARK, K.r(0, 0.6)):Lerp(HILITE, K.r(0, 0.25)) end

local function smoke(p, rate, size, col)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SMOKE
	pe.Color = ColorSequence.new(col or C(110, 100, 104), C(170, 160, 164))
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.25, 0.4), NumberSequenceKeypoint.new(1, 1) })
	pe.Size = NumberSequence.new(size * 0.5, size * 1.8)
	pe.Lifetime = NumberRange.new(6, 9)
	pe.Rate = rate
	pe.Speed = NumberRange.new(4, 7)
	pe.SpreadAngle = Vector2.new(10, 10)
	pe.Acceleration = V3(2.5, 1, 0)
	pe.RotSpeed = NumberRange.new(-10, 10)
	pe.LightInfluence = 0.7
	pe.Parent = p
end

-- VL3: hexagonal prism (three rotated slabs) with a lighter top
local function hexCol(pos, w, h, col, seam)
	for i = 0, 2 do
		K.block(CF(pos + V3(0, h / 2, 0)) * ANG(0, i * PI / 3, 0), V3(w, h, w * 0.577), col, M.Basalt, i == 0)
	end
	for i = 0, 2 do
		K.block(CF(pos + V3(0, h + 0.15, 0)) * ANG(0, i * PI / 3, 0), V3(w * 0.9, 0.3, w * 0.52), K.light(col, 0.12), M.Basalt)
	end
	if seam then
		local s = K.block(CF(pos + V3(0, h * 0.5, 0)) * ANG(0, PI / 6, 0) * CF(0, 0, -w * 0.29 - 0.02), V3(w * 0.2, h * 0.7, 0.1), LAVA, M.Neon)
		K.tag(s, "TPFC_Pulse", { Period = K.r(8, 14), Base = 0.15, Peak = 0 })
	end
end
local function colonnade(pos, n, r, hMin, hMax)
	for _ = 1, n do
		local a, d = K.r(0, PI * 2), K.r(0, r)
		hexCol(pos + V3(math.cos(a) * d, 0, math.sin(a) * d), K.r(2.6, 3.8), K.r(hMin, hMax), rockCol(), K.chance(0.4))
	end
end

-- branching molten crack network (flush)
local function cracks(pos, n, len, y)
	for _ = 1, n do
		local a = K.r(0, PI * 2)
		local p = pos
		for k = 0, K.ri(2, 4) do
			local l = len * K.r(0.5, 1) * (1 - k * 0.15)
			local d = V3(math.cos(a), 0, math.sin(a))
			local seg = K.block(CF(p + d * l / 2 + V3(0, y or 0.06, 0), p + d * l + V3(0, y or 0.06, 0)), V3(0.3, 0.12, l), LAVA, M.Neon, false, 0.1)
			if k == 0 then K.tag(seg, "TPFC_Pulse", { Period = K.r(10, 16), Base = 0.1, Peak = 0 }) end
			p = p + d * l
			a += K.r(-0.7, 0.7)
		end
	end
end

-- VR1: vent cone with glowing crater and smoke
local function vent(pos, s)
	for i = 0, 7 do
		local a = i / 8 * PI * 2 + K.r(-0.2, 0.2)
		K.block(CF(pos + V3(math.cos(a) * 2.6 * s, 1.3 * s, math.sin(a) * 2.6 * s)) * ANG(0, -a, 0) * ANG(0, 0, 0.45),
			V3(1.8, 3.2, 2.4) * s, rockCol(), M.Basalt, true)
	end
	K.vcyl(pos, 1.2 * s, 6.5 * s, DARK, M.Basalt, true)
	local core = K.vcyl(pos + V3(0, 1.2 * s, 0), 0.25, 3 * s, LAVA_HOT, M.Neon)
	K.tag(core, "TPFC_Pulse", { Period = K.r(9, 15), Base = 0.35, Peak = 0 })
	K.lamp(core, LAVA, 16 * s, 1.2)
	smoke(core, 1.5, 3.5 * s)
	cracks(pos, 3, 2.5 * s, 0.07)
end

-- VL5: red spiky plant
local function redPlant(pos, s)
	for i = 0, 6 do
		local a = i / 7 * PI * 2 + K.r(-0.2, 0.2)
		K.wedge(CF(pos) * ANG(0, a, 0) * CF(0, 0.9 * s, -1.1 * s) * ANG(-0.8, 0, 0), V3(0.7, 0.25, 2.6) * s, EMBER, M.SmoothPlastic)
	end
	for i = 0, 3 do
		local a = i / 4 * PI * 2 + 0.4
		K.wedge(CF(pos) * ANG(0, a, 0) * CF(0, 1.4 * s, -0.5 * s) * ANG(-1.15, 0, 0), V3(0.5, 0.2, 2) * s, C(255, 88, 52), M.SmoothPlastic)
	end
	K.block(CF(pos + V3(0, 0.7 * s, 0)), V3(0.7, 0.7, 0.7) * s, LAVA_HOT, M.Neon)
end
-- VR3: orange crystal shard cluster
local function shards(pos, s)
	K.crystalCluster(pos, s, { C(255, 120, 40), C(255, 160, 70), C(230, 70, 40) }, 0)
end

-- VL4: cooled-lava swirl plate: stacked discs with dark spiral grooves and a molten rim
local function swirl(pos, s)
	K.cyl(CF(pos + V3(0, 0.08, 0)) * ANG(0, 0, PI / 2), 0.12, 11 * s, LAVA, M.Neon)
	for i = 0, 3 do
		local d = (10 - i * 2.4) * s
		K.cyl(CF(pos + V3(i * 0.25, 0.3 + i * 0.35, i * 0.2)) * ANG(0, 0, PI / 2), 0.4, d, i % 2 == 0 and BASALT or DARK, M.Basalt, i == 0)
		K.cyl(CF(pos + V3(i * 0.25, 0.52 + i * 0.35, i * 0.2)) * ANG(0, 0, PI / 2), 0.06, d - 0.8 * s, K.dark(DARK, 0.3), M.Basalt)
	end
end

-- VL6 / VR2: gold-trimmed basalt arch; glow = molten portal light inside; banner = red cloth
local function goldArch(pos, yaw, glow, banner)
	local cf = CF(pos) * ANG(0, yaw, 0)
	K.bevel(cf * CF(0, 0.5, 0), V3(13, 1, 5), DARK, M.Basalt)
	K.arch(cf * CF(0, 1, 0), 8, 9, 3, BASALT, M.Basalt, GOLD, M.Metal, 7)
	K.block(cf * CF(0, 19.2, 0), V3(3.6, 1.6, 3.6), GOLD, M.Metal)
	K.pyramid(cf * CF(0, 20, 0), 3, 2, GOLD, M.Metal)
	for s = -1, 1, 2 do
		K.block(cf * CF(s * 5.5, 10.4, 0), V3(3.4, 0.5, 3.8), GOLD, M.Metal)
		local seam = K.block(cf * CF(s * 5.5, 5, -1.56), V3(0.5, 7, 0.1), LAVA, M.Neon)
		K.tag(seam, "TPFC_Pulse", { Period = K.r(9, 13), Base = 0.2, Peak = 0 })
		hexCol(pos + cf.RightVector * s * K.r(9, 11) + cf.LookVector * K.r(-2, 2), K.r(2.4, 3), K.r(3, 7), rockCol(), false)
	end
	if glow then
		local g = K.block(cf * CF(0, 7.5, 0.2), V3(7.6, 12, 0.3), LAVA_HOT, M.Neon, false, 0.35)
		K.tag(g, "TPFC_Pulse", { Period = 6, Base = 0.35, Peak = 0.15 })
		K.lamp(g, LAVA, 24, 1.4)
	end
	if banner then
		local b = K.block(cf * CF(0, 9.5, 0), V3(4, 7, 0.2), C(158, 30, 34), M.Fabric)
		K.tag(b, "TPFC_Sway", { Amp = 0.02, Period = 6 })
		K.block(cf * CF(0, 10, -0.13) * ANG(0, 0, PI / 4), V3(1.4, 1.4, 0.1), GOLD, M.Neon)
		K.block(cf * CF(0, 13.2, 0), V3(5.2, 0.4, 0.4), GOLD, M.Metal)
		K.wedge(cf * CF(-1, 5.5, 0) * ANG(0, PI / 2, PI), V3(0.2, 1, 2), C(158, 30, 34), M.Fabric)
		K.wedge(cf * CF(1, 5.5, 0) * ANG(0, -PI / 2, PI), V3(0.2, 1, 2), C(158, 30, 34), M.Fabric)
	end
end

-- jagged spiky peak: faceted cone + offset secondary cone + optional snow cap
local function peak(pos, w, h, col, snowy)
	K.cone(pos, w * 0.6, h, 7, col, K.dark(col, 0.18), M.Basalt, true)
	K.cone(pos + V3(K.r(-0.3, 0.3) * w, 0, K.r(-0.3, 0.3) * w), w * 0.42, h * K.r(0.6, 0.8), 6, K.light(col, 0.08), col, M.Basalt)
	if snowy then K.cone(pos + V3(0, h * 0.68, 0), w * 0.2, h * 0.32, 6, C(236, 242, 250), C(214, 224, 238), M.Snow) end
end

-- VL1: the giant volcano (centre c): faceted cone, inner jagged cone, crater rim spikes, two lava rivers
local function volcano(c)
	local R, H = 62, 104
	K.cone(c, R, H, 10, BASALT, DARK, M.Basalt, true)
	K.cone(c + V3(6, 0, -4), R * 0.7, H * 1.02, 8, HILITE, BASALT, M.Basalt)
	K.cone(c + V3(-10, 0, 12), R * 0.55, H * 0.8, 7, rockCol(), DARK, M.Basalt)
	local top = H - 9
	for i = 0, 9 do
		local a = i / 10 * PI * 2
		K.cone(c + V3(math.cos(a) * 9, top - 4, math.sin(a) * 8), K.r(3, 5), K.r(9, 16), 5, DARK, BASALT, M.Basalt)
	end
	local crater = K.block(CF(c + V3(0, top + 0.5, 0)), V3(14, 1, 12), LAVA_HOT, M.Neon)
	K.lamp(crater, LAVA, 70, 2.2)
	K.tag(crater, "TPFC_Pulse", { Period = 7, Base = 0, Peak = 0.2 })
	local plume = K.block(CF(c + V3(0, top + 6, 0)), V3(6, 1, 6), DARK, M.Basalt, false, 1)
	smoke(plume, 4, 18)
	-- two lava rivers flowing down the lane-facing facets (+X design side), crust edges beside them
	for k = 0, 1 do
		local a = (k == 0) and -0.25 or 0.3
		local dir = V3(math.cos(a), 0, math.sin(a))
		local p0 = c + V3(0, top, 0) + dir * 6
		local p1 = c + dir * (R * 0.98) + V3(0, 1, 0)
		local n = 8
		for i = 0, n - 1 do
			local a0 = p0:Lerp(p1, i / n) + V3(math.sin(i * 1.3) * 1.5, 1.4, 0)
			local a1 = p0:Lerp(p1, (i + 1) / n) + V3(math.sin((i + 1) * 1.3) * 1.5, 1.4, 0)
			local w = 2.2 + i * 0.45
			K.block(CF((a0 + a1) / 2, a1), V3(w, 0.8, (a1 - a0).Magnitude + 0.6), LAVA, M.Neon)
			K.block(CF((a0 + a1) / 2, a1) * CF(0, -0.35, 0), V3(w + 1.6, 0.8, (a1 - a0).Magnitude + 0.6), K.dark(DARK, 0.2), M.Basalt)
		end
	end
	return top
end

function B.Build(b)
	K.Seed(2002)
	K.ResetSurfaces()
	K.mirror = true
	local z1, z2 = b[1], b[2]
	---------------------------------------------------------------- terraces: layered basalt, hex-column fronts
	K.terraces(z1, z2, {
		rock = BASALT, rockMat = M.Basalt, cap = ASH, capMat = M.Basalt, drip = false, tiers = 2,
		h1 = { 1.5, 3 }, h2 = { 4, 8 },
		skip = { { -1, 196, 300 } },
		facade = function(s, x1, top, za, zb)
			local z = za
			while z < zb - 1 do
				local l = math.min(K.r(3, 5.5), zb - z)
				hexCol(V3(s * (x1 + 1.2), -0.5, z + l / 2), l * 0.95, top + 0.5 + K.r(-0.3, 0.8), rockCol(), K.chance(0.25))
				z += l
			end
		end,
	})
	---------------------------------------------------------------- VL1 volcano + VL2 lavafall cliff and pool
	volcano(V3(-142, 0, 296))
	for _ = 1, 7 do peak(V3(-K.r(150, 190), 0, K.r(170, 350)), K.r(26, 40), K.r(60, 110), rockCol(), false) end
	local cx, cz = -72, 232
	K.block(CF(cx - 6, 15, cz), V3(18, 30, 26), rockCol(), M.Basalt, true)
	for _ = 0, 4 do K.wedge(CF(cx - 6 + K.r(-6, 6), 31.5, cz + K.r(-10, 10)) * ANG(0, K.r(0, PI), 0), V3(K.r(5, 8), K.r(3, 6), K.r(4, 7)), DARK, M.Basalt) end
	local topP, botP = V3(cx + 3, 29, cz), V3(cx + 7.5, 0.6, cz)
	local sheetCF = CF((topP + botP) / 2, botP) * ANG(PI / 2, 0, 0)
	local len = (topP - botP).Magnitude
	K.block(sheetCF, V3(9, len, 1.6), LAVA, M.Neon)
	K.block(sheetCF * CF(0, 0, -0.85), V3(3, len, 0.2), LAVA_HOT, M.Neon)
	for s = -1, 1, 2 do K.block(sheetCF * CF(s * 4.9, 0, 0), V3(1.2, len, 2.2), C(120, 40, 20), M.Basalt) end
	local pool = K.block(CF(-54, 0.22, cz), V3(16, 0.44, 24), LAVA, M.Neon)
	K.lamp(pool, LAVA, 40, 1.6)
	K.tag(pool, "TPFC_Pulse", { Period = 6, Base = 0.05, Peak = 0 })
	K.block(CF(-54, 0.12, cz), V3(19, 0.24, 27), DARK, M.Basalt)
	smoke(pool, 1, 8)
	for i = 1, 5 do hexCol(V3(-54 + K.r(-7, 7), 0, cz + (i % 2 == 0 and 14 or -14)), K.r(2.4, 3.2), K.r(1.5, 3.5), rockCol(), false) end
	---------------------------------------------------------------- VL3 colonnades, VL4 swirl plates, VL5 plants, VL6 arch
	colonnade(V3(-64, 0, 178), 12, 8, 6, 20)
	colonnade(V3(-60, 0, 312), 10, 7, 5, 16)
	colonnade(V3(-88, 0, 200), 8, 6, 10, 26)
	swirl(V3(-46, 0, 194), 1.1)
	swirl(V3(-50, 0, 210), 0.8)
	swirl(V3(-44, 0, 262), 0.9)
	goldArch(V3(-56, 0, 258), PI / 2 - 0.35, true, false)
	for _ = 1, 9 do redPlant(V3(-K.r(40, 48), 0, K.r(170, 340)), K.r(0.9, 1.4)) end
	---------------------------------------------------------------- RIGHT: vents, banner arch, colonnades, plants, shards, snowy peaks
	vent(K.at(52, 198), 1.3)
	vent(K.at(56, 262), 1.6)
	vent(K.at(50, 318), 1.1)
	goldArch(K.at(58, 236), -PI / 2 + 0.35, false, true)
	colonnade(K.at(74, 180), 8, 6, 6, 16)
	colonnade(K.at(80, 290), 10, 8, 8, 22)
	for _ = 1, 9 do redPlant(V3(K.r(40, 46), 0, K.r(160, 345)), K.r(0.9, 1.4)) end
	for _ = 1, 6 do shards(K.at(K.r(50, 66), K.r(170, 340)), K.r(0.8, 1.2)) end
	for _ = 1, 8 do redPlant(K.at(K.r(50, 72), K.r(165, 345)), K.r(0.9, 1.3)) end
	for i = 1, 6 do peak(V3(K.r(140, 185), 0, K.r(300, 400)), K.r(28, 40), K.r(70, 120), C(120, 124, 140), i % 2 == 0) end
	for _ = 1, 3 do peak(V3(K.r(140, 180), 0, K.r(170, 290)), K.r(26, 36), K.r(55, 90), rockCol(), false) end
	---------------------------------------------------------------- distant broken arched bridge (side spans only)
	for s = -1, 1, 2 do
		for k = 0, 1 do K.block(CF(s * (54 + k * 16), 11, 336), V3(5, 22, 7), BASALT, M.Basalt, true) end
		K.arch(CF(s * 62, 0, 336), 11, 15, 6, BASALT, M.Basalt, nil, nil, 7)
		K.block(CF(s * 60, 24, 336), V3(26, 2.4, 8), DARK, M.Basalt)
		for k = 0, 2 do K.block(CF(s * (47.5 - k * 1.2), 24 - k * 1.6, 336) * ANG(0, 0, s * 0.3), V3(2.6, 2, 7), DARK, M.Basalt) end
	end
	---------------------------------------------------------------- CENTRE: slab road seams, curb, crack network
	for s = -1, 1, 2 do
		K.block(CF(s * 35.5, 0.3, (z1 + z2) / 2), V3(3, 0.6, z2 - z1), DARK, M.Basalt)
		K.block(CF(s * 33.8, 0.34, (z1 + z2) / 2), V3(0.4, 0.68, z2 - z1), ASH, M.Basalt)
	end
	-- dark basalt slab road (flush tiles with seams; landing still hits the terrain underneath)
	for z = z1 + 1, z2 - 13, 14 do
		for x = -27.5, 27.5, 11 do
			K.block(CF(x + K.r(-0.15, 0.15), 0.18, z + 7), V3(10.7, 0.3, 13.7), C(62, 54, 60):Lerp(C(78, 68, 74), K.r(0, 1)), M.Slate)
		end
	end
	for _ = 1, 8 do cracks(V3(K.r(-24, 24), 0, K.r(z1 + 15, z2 - 15)), K.ri(2, 3), K.r(3, 6)) end
	---------------------------------------------------------------- transition to Frozen: cooled rock + frost (z 330..350)
	for s = -1, 1, 2 do
		for _ = 1, 3 do
			local p = V3(s * K.r(40, 52), 0, K.r(334, 348))
			K.rockMass(p, K.r(4, 6), K.r(2.5, 4.5), K.r(4, 6), C(110, 116, 132), M.Slate, 2)
			K.block(CF(p + V3(0, 3.2, 0)), V3(3.6, 0.5, 3.6), C(236, 244, 252), M.Snow)
		end
	end
	K.mirror = false
end

return B
