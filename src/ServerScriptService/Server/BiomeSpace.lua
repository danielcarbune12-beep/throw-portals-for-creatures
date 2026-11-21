-- BiomeSpace: Space Galaxy, Z [1300, 1800). Reference: roblox pets/Maps/06_Space_Biome.png (1:1 inventory).
-- Authored as seen in the reference (K.mirror = true: design -X = screen-left).
--  LEFT : SL1 observatory (ribbed stone/brass dome with an open slot + brass telescope, drum with gold bands,
--         columned portico with blue emblem banners, wide stairs, segmented brass orbital arc, golden beacon star
--         with halo) · SL2 purple bonsai trees · SL3 gold-emblem obelisks · SL4 glowing blue crystals
--  RIGHT: SR1 crater ring (glowing blue bowl + half-sunk gold ring frame) · SR2 crashed satellite dish +
--         gold-banded capsule · SR3 purple trees, crystals, obelisk shards
--  BACK : jagged purple crystal rocks, giant ringed planet, asteroids, constellation lines
--  CENTRE: lavender lunar ground with shallow craters (flush rings — the terrain stays continuous).
-- Location: ServerScriptService > Server > BiomeSpace (ModuleScript)

local K = require(script.Parent.WorldKit)
local V3, CF, ANG, PI, M = K.V3, K.CF, K.ANG, K.PI, K.M
local C = K.C

local B = {}

local LUNAR, LUNAR_D, LUNAR_L = C(122, 124, 176), C(88, 88, 140), C(156, 158, 204)
local STONE, BRASS, GOLD = C(150, 152, 186), C(206, 164, 92), C(232, 190, 96)
local BLUE, VIOLET, TREE = C(110, 180, 255), C(150, 90, 255), C(176, 120, 230)
local BANNER = C(48, 52, 150)

local function rockCol() return LUNAR:Lerp(LUNAR_D, K.r(0, 0.8)):Lerp(LUNAR_L, K.r(0, 0.3)) end

local function facade(s, x1, top, za, zb)
	local z = za
	while z < zb - 1 do
		local l = math.min(K.r(4, 7), zb - z)
		local h = top + K.r(-0.3, 0.8)
		K.bevel(CF(s * (x1 + 1.1), h / 2 - 0.4, z + l / 2) * ANG(0, K.r(-0.06, 0.06), 0), V3(2.8, h + 0.6, l - 0.2), rockCol(), M.Slate)
		z += l
	end
end

-- segmented arc of brass blocks: centre cf, radius r, from angle a0 to a1 in the cf XY plane
local function arc(cf, r, a0, a1, n, thick, depth, col, mat)
	for i = 0, n - 1 do
		local t0, t1 = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
		local p0, p1 = cf * V3(math.cos(t0) * r, math.sin(t0) * r, 0), cf * V3(math.cos(t1) * r, math.sin(t1) * r, 0)
		K.block(CFrame.lookAt((p0 + p1) / 2, p1, cf.LookVector), V3(thick, depth, (p1 - p0).Magnitude + 0.3), col, mat or M.Metal)
	end
end

local function star(cf, r, col)
	for i = 0, 3 do K.block(cf * ANG(0, 0, i * PI / 4), V3(r * 0.35, r * 2, r * 0.35), col, M.Neon) end
end

-- SL2 / SR3: purple bonsai tree (curved trunk, flat tiered canopy discs)
local function bonsai(pos, s)
	local top, mid = K.limb(pos, pos + V3(1.5 * s, 3 * s, 0), pos + V3(-0.5 * s, 6 * s, 0.6 * s), 1.2 * s, 0.7 * s, 4, C(110, 70, 60), M.Wood, true)
	local side = mid + V3(2.6 * s, 1.4 * s, 0)
	K.limb(mid, mid + V3(1.2 * s, 1 * s, 0), side, 0.6 * s, 0.4 * s, 2, C(110, 70, 60), M.Wood)
	for _, p in ipairs({ { top + V3(0, 0.8 * s, 0), 7 }, { side + V3(0, 0.4 * s, 0), 4.5 }, { top + V3(-2 * s, -1.4 * s, 1.5 * s), 4 } }) do
		K.ellipsoid(CF(p[1]), V3(p[2], 1.4, p[2] * 0.85) * s, TREE, M.SmoothPlastic)
		K.ellipsoid(CF(p[1] + V3(0, 0.5 * s, 0)), V3(p[2] * 0.8, 0.9, p[2] * 0.65) * s, K.light(TREE, 0.18), M.SmoothPlastic)
	end
end

-- SL3 / SR3: obelisk with gold emblem
local function obelisk(pos, h, yaw)
	local cf = CF(pos) * ANG(0, yaw or 0, 0)
	K.bevel(cf * CF(0, 0.8, 0), V3(4.4, 1.6, 4.4), LUNAR_D, M.Slate)
	K.bevel(cf * CF(0, 1.6 + h / 2, 0), V3(3, h, 2.2), STONE, M.Slate)
	K.pyramid(cf * CF(0, 1.6 + h, 0), 3, 2.4, STONE, M.Slate, 2.2)
	K.cyl(cf * CF(0, 1.6 + h * 0.62, -1.15) * ANG(0, PI / 2, 0), 0.2, 1.8, GOLD, M.Metal)
	star(cf * CF(0, 1.6 + h * 0.62, -1.28), 0.5, GOLD)
end

-- SL1: the observatory
local function observatory(c)
	-- rock base, terrace and wide stairs facing the lane (+X design)
	K.bevel(CF(c + V3(0, 3, 0)), V3(46, 6, 50), rockCol(), M.Slate)
	K.bevel(CF(c + V3(-2, 8, 0)), V3(36, 4, 40), STONE, M.Slate)
	K.addSurface(c.X - 23, c.X + 23, c.Z - 25, c.Z + 25, 6)
	K.addSurface(c.X - 20, c.X + 16, c.Z - 20, c.Z + 20, 10)
	K.stairs(CF(c + V3(26, 0, 0)) * ANG(0, PI / 2, 0), 14, 8, 1.25, 1.6, STONE, M.Slate)
	-- drum with gold bands
	local d = c + V3(-4, 10, 0)
	K.vcyl(d, 12, 26, STONE, M.Slate, true)
	for _, y in ipairs({ 0.4, 11.6 }) do K.vcyl(d + V3(0, y, 0), 0.8, 26.6, GOLD, M.Metal) end
	-- dome: hemisphere + brass meridian ribs + open slot with telescope
	local top = d + V3(0, 12, 0)
	K.ellipsoid(CF(top), V3(25, 24, 25), C(132, 136, 176), M.Metal)
	for i = 0, 7 do
		local cf = CF(top) * ANG(0, i * PI / 8, 0)
		arc(cf, 12.7, 0, PI, 10, 0.8, 1, BRASS)
	end
	local slotCF = CF(top) * ANG(0, 0, 0)
	K.block(slotCF * CF(6, 6, 0) * ANG(0, 0, -0.9), V3(10, 3, 5.6), C(40, 36, 60), M.SmoothPlastic)
	K.cyl(CF(top + V3(8, 9, 0)) * ANG(0, 0, 0.6), 18, 3.6, BRASS, M.Metal)
	K.cyl(CF(top + V3(16, 14.6, 0)) * ANG(0, 0, 0.6), 2, 4.4, GOLD, M.Metal)
	K.cyl(CF(top + V3(3, 6, 0)) * ANG(0, 0, 0.6), 1.4, 4.4, GOLD, M.Metal)
	-- beacon star with halo
	local beacon = CF(top + V3(0, 15, 0))
	star(beacon, 2.2, C(255, 220, 140))
	K.lamp(K.block(beacon, V3(1, 1, 1), C(255, 220, 140), M.Neon), C(255, 220, 150), 40, 1.6)
	local halo = K.cyl(beacon * ANG(0, 0, PI / 2), 0.2, 9, C(255, 230, 170), M.Neon, false, 0.5)
	K.tag(halo, "TPFC_Spin", { Rate = 6 })
	K.vcyl(top + V3(0, 11, 0), 3, 0.6, GOLD, M.Metal)
	-- segmented brass orbital arc sweeping around the dome
	local orbit = CF(top + V3(0, 2, 0)) * ANG(0.35, 0.4, 0.5)
	arc(orbit, 26, -0.4, PI * 1.25, 22, 1.6, 2.6, BRASS)
	arc(orbit, 26, -0.4, PI * 1.25, 22, 0.4, 2.8, GOLD)
	-- portico: columns, lintel, banners with emblem, glowing doorway
	local px = d.X + 13.5
	for s = -1, 1, 2 do
		for k = 0, 1 do K.column(V3(px + 1, 10, d.Z + s * (4 + k * 5)), 10, 1.6, STONE, M.Slate, GOLD) end
		local b = K.block(CF(px + 2.2, 15, d.Z + s * 6.5), V3(0.2, 7, 2.6), BANNER, M.Fabric)
		K.tag(b, "TPFC_Sway", { Amp = 0.02, Period = 6 })
		star(CF(px + 2.35, 15.5, d.Z + s * 6.5) * ANG(0, PI / 2, 0), 0.6, GOLD)
	end
	K.block(CF(px + 1, 21.6, d.Z), V3(4, 1.4, 22), STONE, M.Slate)
	K.block(CF(px + 1, 22.5, d.Z), V3(4.4, 0.4, 22.4), GOLD, M.Metal)
	local door = K.block(CF(px + 0.2, 14.5, d.Z), V3(0.3, 8, 4.6), C(255, 210, 140), M.Neon, false, 0.25)
	K.lamp(door, C(255, 210, 150), 24, 1.2)
end

-- SR1: crater ring structure (raised rim, glowing bowl, half-sunk gold ring frame)
local function craterRing(c)
	for i = 0, 17 do
		local a = i / 18 * PI * 2
		K.bevel(CF(c + V3(math.cos(a) * 14, 1.4, math.sin(a) * 14)) * ANG(0, -a, 0.25), V3(5, 2.8, 5.4), rockCol(), M.Slate)
	end
	for i = 0, 2 do
		local disc = K.cyl(CF(c + V3(0, 0.2 + i * 0.08, 0)) * ANG(0, 0, PI / 2), 0.15, 22 - i * 6, i == 2 and C(170, 230, 255) or BLUE, M.Neon, false, 0.25 + i * 0.1)
		if i == 0 then K.lamp(disc, BLUE, 40, 1.4); K.tag(disc, "TPFC_Pulse", { Period = 8, Base = 0.25, Peak = 0.05 }) end
	end
	local ringCF = CF(c + V3(-6, 6, 0)) * ANG(0, PI / 2, 0)
	arc(ringCF, 12, -0.3, PI + 0.3, 20, 2.2, 3, BRASS)
	arc(ringCF, 12.9, -0.3, PI + 0.3, 20, 0.5, 3.2, GOLD)
	for s = -1, 1, 2 do obelisk(c + V3(-6, 0, s * 17), 8, PI / 2) end
end

-- SR2: crashed satellite dish + gold-banded capsule
local function satellite(c)
	local dish = CF(c + V3(0, 5, 0)) * ANG(0.5, -0.6, 0.3)
	K.ellipsoid(dish, V3(13, 2.2, 13), C(226, 228, 236), M.SmoothPlastic)
	K.ellipsoid(dish * CF(0, 0.5, 0), V3(11, 1.6, 11), C(196, 200, 214), M.SmoothPlastic)
	K.block(dish * CF(0, 3, 0), V3(0.4, 6, 0.4), C(150, 150, 166), M.Metal)
	K.ball((dish * CF(0, 6.2, 0)).Position, 1, C(200, 204, 216), M.Metal)
	for s = -1, 1, 2 do K.block(dish * CF(s * 2.4, 2.5, 0) * ANG(0, 0, -s * 0.5), V3(0.25, 5.5, 0.25), C(150, 150, 166), M.Metal) end
	K.block(CF(c + V3(0, 2, 0)) * ANG(0.2, 0, 0.3), V3(1.4, 5, 1.4), C(130, 132, 150), M.Metal)
	local cap = CF(c + V3(6, 2.6, 7)) * ANG(0, 0.6, 0.25)
	K.cyl(cap, 10, 5.2, C(196, 196, 210), M.Metal)
	for k = -1, 1 do K.cyl(cap * CF(k * 3.6, 0, 0), 0.6, 5.6, GOLD, M.Metal) end
	K.cyl(cap * CF(5.1, 0, 0), 0.3, 3.4, C(40, 36, 60), M.SmoothPlastic)
	K.lamp(K.block(cap * CF(5, 0, 0), V3(0.4, 0.4, 0.4), C(255, 200, 120), M.Neon), C(255, 200, 120), 12, 0.8)
	for _ = 1, 6 do K.bevel(CF(c + V3(K.r(-8, 10), 0.5, K.r(-6, 12))) * ANG(0, K.r(0, PI), K.r(-0.2, 0.2)), V3(K.r(1.6, 3), 1, K.r(1.6, 3)), rockCol(), M.Slate) end
end

-- flush lunar crater (rim + darker floor)
local function crater(pos, r)
	K.cyl(CF(pos + V3(0, 0.12, 0)) * ANG(0, 0, PI / 2), 0.16, r * 2 + 1.2, LUNAR_L, M.Slate)
	K.cyl(CF(pos + V3(0, 0.16, 0)) * ANG(0, 0, PI / 2), 0.16, r * 2, C(120, 122, 168), M.Slate)
	K.cyl(CF(pos + V3(0.3, 0.2, 0.3)) * ANG(0, 0, PI / 2), 0.16, r * 1.4, C(108, 110, 156), M.Slate)
end

function B.Build(b)
	K.Seed(6006)
	K.ResetSurfaces()
	K.mirror = true
	local z1, z2 = b[1], b[2]
	K.terraces(z1, z2, {
		rock = LUNAR, rockMat = M.Slate, cap = LUNAR_L, capMat = M.Slate, drip = false, tiers = 3,
		h1 = { 1.6, 3.4 }, h2 = { 5, 10 }, h3 = { 8, 18 },
		skip = { { -1, 1400, 1520 }, { 1, 1440, 1560 }, { 1, 1640, 1700 } },
		facade = facade,
	})
	---------------------------------------------------------------- LEFT
	observatory(V3(-84, 0, 1460))
	for _, p in ipairs({ { -56, 1420, 1.3 }, { -60, 1510, 1.5 }, { -70, 1350, 1.4 }, { -66, 1600, 1.6 }, { -58, 1720, 1.2 } }) do bonsai(K.at(p[1], p[2]), p[3]) end
	for _, p in ipairs({ { -54, 1380, 9 }, { -55, 1560, 11 }, { -56, 1700, 8 } }) do obelisk(K.at(p[1], p[2]), p[3], PI / 2) end
	---------------------------------------------------------------- RIGHT
	craterRing(V3(76, 0, 1500))
	satellite(V3(62, 0, 1670))
	for _, p in ipairs({ { 54, 1420, 1.3 }, { 60, 1600, 1.5 }, { 66, 1760, 1.4 }, { 58, 1340, 1.2 } }) do bonsai(K.at(p[1], p[2]), p[3]) end
	obelisk(K.at(56, 1380), 9, -PI / 2)
	obelisk(K.at(54, 1740), 10, -PI / 2)
	---------------------------------------------------------------- crystals on terrace tops + lane edges
	for _, r in ipairs(K.surfaces) do
		local xa, xb = math.max(r[1], -90), math.min(r[2], 90)
		if xb - xa > 3 then
			for _ = 1, math.floor((xb - xa) * (r[4] - r[3]) / 260) do
				local x, z = K.r(xa + 2, xb - 2), K.r(r[3] + 2, r[4] - 2)
				if math.abs(x) >= 48 then K.crystalCluster(V3(x, r[5], z), K.r(0.6, 1.1), { BLUE, C(150, 210, 255), VIOLET }, K.chance(0.4) and 0 or nil) end
			end
		end
	end
	for s = -1, 1, 2 do
		for z = z1 + 10, z2 - 8, 14 do
			local p = V3(s * K.r(38, 43), 0, z + K.r(-4, 4))
			if K.chance(0.5) then K.crystal(p, K.r(1.6, 3), 0.8, BLUE, ANG(0, K.r(0, PI), s * 0.4), K.chance(0.4))
			else K.bevel(CF(p + V3(0, 0.5, 0)) * ANG(0, K.r(0, PI), 0), V3(K.r(2, 3.4), 1.2, K.r(2, 3.4)), rockCol(), M.Slate) end
		end
	end
	---------------------------------------------------------------- CENTRE: flush craters
	for _ = 1, 14 do crater(V3(K.r(-24, 24), 0, K.r(z1 + 15, z2 - 15)), K.r(2.5, 6)) end
	---------------------------------------------------------------- BACK: jagged purple crystal rocks, planet, asteroids, constellations
	for s = -1, 1, 2 do
		for _ = 1, 6 do
			local p = V3(s * K.r(110, 150), 0, K.r(z1, z2 + 60))
			K.cone(p, K.r(14, 22), K.r(30, 60), 6, C(90, 76, 150), C(70, 56, 120), M.Slate, true)
			K.crystal(p + V3(-s * 6, 4, 0), K.r(10, 18), K.r(3, 5), VIOLET, ANG(0, 0, s * 0.3), true)
		end
	end
	local pc = V3(190, 190, 1900)
	K.ball(pc, 120, C(170, 160, 230), M.SmoothPlastic).CastShadow = false
	for i = 0, 2 do K.ball(pc + V3(0, -10 + i * 14, 0), 121 - math.abs(i - 1) * 8, i % 2 == 0 and C(150, 140, 214) or C(196, 186, 244), M.SmoothPlastic, 0.55).CastShadow = false end
	local ring = K.cyl(CF(pc) * ANG(0.25, 0, PI / 2 + 0.3), 0.8, 220, C(210, 200, 250), M.SmoothPlastic, false, 0.3)
	ring.CastShadow = false
	K.cyl(CF(pc) * ANG(0.25, 0, PI / 2 + 0.3), 0.9, 180, C(150, 140, 214), M.SmoothPlastic, false, 0.35).CastShadow = false
	for _ = 1, 10 do
		local s = K.chance(0.5) and 1 or -1
		local a = K.block(CF(s * K.r(80, 150), K.r(60, 120), K.r(z1, z2)) * ANG(K.r(0, PI), K.r(0, PI), 0), V3(1, 1, 1) * K.r(4, 10), C(120, 116, 150), M.Slate)
		K.tag(a, "TPFC_Spin", { Rate = K.r(2, 6) })
	end
	for _, cons in ipairs({ { V3(40, 190, 1820), 7 }, { V3(-60, 210, 1840), 6 } }) do
		local prev
		for _ = 1, cons[2] do
			local p = cons[1] + V3(K.r(-30, 30), K.r(-18, 18), K.r(-6, 6))
			K.ball(p, 1.6, C(255, 250, 220), M.Neon)
			if prev then K.block(CF((prev + p) / 2, p), V3(0.18, 0.18, (p - prev).Magnitude), C(200, 210, 255), M.Neon, false, 0.5) end
			prev = p
		end
	end
	---------------------------------------------------------------- transition to Shadow: fractured side rock, muted stars
	for s = -1, 1, 2 do
		for _ = 1, 3 do
			local p = V3(s * K.r(44, 58), 0, K.r(1782, 1798))
			K.rockMass(p, K.r(4, 7), K.r(3, 7), K.r(4, 7), C(80, 66, 100), M.Slate, 2)
		end
	end
	K.mirror = false
end

return B
