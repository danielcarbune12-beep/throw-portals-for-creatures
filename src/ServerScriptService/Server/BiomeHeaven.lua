-- BiomeHeaven: Heaven World, Z [2400, 3200). Reference: roblox pets/Maps/08_Heaven_Biome.png (1:1 inventory).
-- Authored as seen in the reference (K.mirror = true: design -X = screen-left).
--  LEFT : HL1 winged angel statue (hooded robe, praying hands, feathered wings, golden halo ring + star, gold-banded
--         plinth) · HL2 cascading blue waterfalls down grassy marble tiers · HL3 green bonsai trees · HL4 cypresses ·
--         HL5 puffy clouds · HL6 arched colonnade with blue star banners · HL7 floating islands with little temples
--  RIGHT: HR1 rainbow over the gardens (beside the lane) · HR2 bell arch (marble arch, gold bell, star) ·
--         HR3 waterfall pools, colonnades, cypresses, white lilies
--  END  : HE1 monumental winged gate beyond the last landing point (glowing portal glass, gold halo arch + star,
--         giant wings, curved colonnades, stairs)
--  CENTRE: cream marble floor with gold inlay borders and diamond-star medallions.
-- Location: ServerScriptService > Server > BiomeHeaven (ModuleScript)

local K = require(script.Parent.WorldKit)
local V3, CF, ANG, PI, M = K.V3, K.CF, K.ANG, K.PI, K.M
local C = K.C

local B = {}

local MARBLE, MARBLE_D, CREAM = C(246, 242, 232), C(222, 214, 198), C(240, 230, 210)
local GOLD, BLUE, SKY = C(232, 188, 88), C(70, 120, 210), C(150, 214, 250)
local GRASS, LEAF = C(116, 172, 70), { C(96, 156, 60), C(120, 176, 70), C(80, 138, 56) }
local LILY = C(255, 252, 246)

local function marbleCol() return MARBLE:Lerp(MARBLE_D, K.r(0, 0.6)) end

local function facade(s, x1, top, za, zb)
	local z = za
	while z < zb - 1 do
		local l = math.min(K.r(4, 7), zb - z)
		K.bevel(CF(s * (x1 + 1.1), top / 2 - 0.3, z + l / 2), V3(2.8, top + 0.6, l - 0.2), marbleCol(), M.Marble)
		K.block(CF(s * (x1 - 0.3), top - 0.6, z + l / 2), V3(0.15, 0.3, l - 0.3), GOLD, M.Metal)
		z += l
	end
end

local function star(cf, r)
	for i = 0, 3 do K.block(cf * ANG(0, 0, i * PI / 4), V3(r * (i % 2 == 0 and 0.35 or 0.22), r * (i % 2 == 0 and 2.2 or 1.2), 0.3), GOLD, M.Neon) end
end
-- full ring of gold segments in the cf XY plane
local function ring(cf, r, n, thick)
	for i = 0, n - 1 do
		local a0, a1 = i / n * PI * 2, (i + 1) / n * PI * 2
		local p0, p1 = cf * V3(math.cos(a0) * r, math.sin(a0) * r, 0), cf * V3(math.cos(a1) * r, math.sin(a1) * r, 0)
		K.block(CFrame.lookAt((p0 + p1) / 2, p1, cf.LookVector), V3(thick, thick, (p1 - p0).Magnitude + 0.2), GOLD, M.Metal)
	end
end

-- HL5: puffy cloud cluster
local function cloud(pos, s)
	for i = 1, K.ri(6, 9) do
		local d = K.r(4, 7) * s
		K.ball(pos + V3(K.r(-6, 6) * s, K.r(0, 3) * s, K.r(-4, 4) * s), d, i % 3 == 0 and C(232, 240, 252) or C(255, 255, 255), M.SmoothPlastic)
	end
end
-- HL4: cypress
local function cypress(pos, s)
	K.block(CF(pos + V3(0, 0.8 * s, 0)), V3(0.8, 1.6, 0.8) * s, C(110, 80, 56), M.Wood)
	K.ellipsoid(CF(pos + V3(0, 6 * s, 0)), V3(3.2, 11, 3.2) * s, C(52, 110, 60), M.SmoothPlastic)
	K.ellipsoid(CF(pos + V3(0.3 * s, 7 * s, -0.3 * s)), V3(2.2, 8, 2.2) * s, C(66, 128, 66), M.SmoothPlastic)
end
-- grassy marble ledge with lilies
local function gardenLedge(cf, size)
	K.bevel(cf, size, marbleCol(), M.Marble)
	K.block(cf * CF(0, size.Y / 2 + 0.2, 0), V3(size.X - 0.6, 0.4, size.Z - 0.6), GRASS, M.SmoothPlastic)
	for _ = 1, math.max(1, math.floor(size.X * size.Z / 90)) do
		K.lily((cf * CF(K.r(-size.X / 2 + 1.5, size.X / 2 - 1.5), size.Y / 2 + 0.4, K.r(-size.Z / 2 + 1.5, size.Z / 2 - 1.5))).Position, K.r(0.8, 1.1), LILY, C(255, 226, 150))
	end
end

-- HL1: winged angel statue
local function angel(pos, yaw)
	local cf = CF(pos) * ANG(0, yaw, 0)
	K.bevel(cf * CF(0, 1.5, 0), V3(10, 3, 10), MARBLE_D, M.Marble)
	K.block(cf * CF(0, 3.1, 0), V3(9.4, 0.4, 9.4), GOLD, M.Metal)
	K.bevel(cf * CF(0, 4.3, 0), V3(7, 2, 7), MARBLE, M.Marble)
	-- robe (tapered stacked blocks + flowing hem wedges), hood, hands
	for i = 0, 4 do
		local w = 5.2 - i * 0.6
		K.block(cf * CF(0, 6 + i * 2.4, 0), V3(w, 2.6, w * 0.8), CREAM, M.Marble)
	end
	for i = 0, 3 do K.wedge(cf * ANG(0, i * PI / 2, 0) * CF(0, 6.4, -2.6), V3(5, 2.6, 1.4), CREAM, M.Marble) end
	K.ellipsoid(cf * CF(0, 19.2, 0), V3(3.8, 4.4, 3.6), CREAM, M.Marble)
	K.ellipsoid(cf * CF(0, 18.8, -0.7), V3(2.4, 3, 2), C(200, 190, 176), M.Marble)
	K.block(cf * CF(0, 13.6, -1.8) * ANG(0.3, 0, 0), V3(1.4, 2.4, 1), CREAM, M.Marble)
	-- wings: three tiers of feather wedges fanning up and out
	for s = -1, 1, 2 do
		for t = 0, 2 do
			for f = 0, 5 - t do
				local ang = -0.2 + f * 0.28
				local len = 9 - t * 2 - f * 0.5
				K.wedge(cf * CF(s * 2.2, 15 - t * 2.4, 1.4 + t * 0.3) * ANG(0, 0, s * (ang + 0.5)) * CF(0, len / 2, 0) * ANG(0, s > 0 and PI / 2 or -PI / 2, 0),
					V3(0.6, len, 2.2 - t * 0.3), t == 0 and MARBLE or CREAM, M.Marble)
			end
		end
	end
	-- golden halo ring + star behind the head
	local hcf = cf * CF(0, 22, 1.6)
	ring(hcf, 4.6, 18, 0.5)
	star(hcf, 1.8)
	K.lamp(K.block(hcf, V3(0.5, 0.5, 0.5), GOLD, M.Neon), C(255, 230, 160), 22, 1)
end

-- HL2 / HR3: stepped garden cascade with waterfalls and pools (facing the lane, +X design local)
local function cascade(base, steps, w)
	for i = 0, steps - 1 do
		local cf = CF(base + V3(-i * 6, i * 3.2 + 1.6, 0))
		gardenLedge(cf, V3(8, 3.2 * (i + 1), w - i * 2))
		local fall = K.block(cf * CF(4.1, i * 1.6, 0), V3(0.6, 3.2, w * 0.35), C(120, 200, 245), M.Glass, false, 0.15)
		K.tag(fall, "TPFC_Pulse", { Period = K.r(3, 5), Base = 0.15, Peak = 0.02 })
		K.addSurface(base.X - i * 6 - 4, base.X - i * 6 + 4, base.Z - (w - i * 2) / 2, base.Z + (w - i * 2) / 2, 3.2 * (i + 1) + 0.4)
	end
	K.water(CF(base + V3(7, 0.3, 0)), V3(7, 0.3, w * 0.6), SKY, 0.2)
	K.ellipsoid(CF(base + V3(5, 0.5, 0)), V3(2.4, 1, w * 0.4), C(240, 250, 255), M.SmoothPlastic)
end

-- HL6 / HR3: arched colonnade along Z with blue star banners
local function colonnade(pos, n, span, h, bannerSide)
	local cf = CF(pos) * ANG(0, PI / 2, 0)
	for i = 0, n - 1 do
		local acf = cf * CF((i - (n - 1) / 2) * (span + 2.6), 0, 0)
		K.arch(acf, span, h, 2.4, MARBLE, M.Marble, GOLD, M.Metal, 7)
		if i % 2 == 0 then
			local b = K.block(acf * CF(0, h * 0.8, bannerSide * 1.4), V3(2.4, h * 0.7, 0.2), BLUE, M.Fabric)
			K.tag(b, "TPFC_Sway", { Amp = 0.02, Period = 6 })
			star(acf * CF(0, h * 0.85, bannerSide * 1.52), 0.7)
		end
	end
	K.block(cf * CF(0, h + span / 2 + 2.4, 0), V3(n * (span + 2.6) + 2, 1.6, 3), MARBLE, M.Marble)
	K.block(cf * CF(0, h + span / 2 + 3.3, 0), V3(n * (span + 2.6) + 2.4, 0.3, 3.2), GOLD, M.Metal)
end

-- HR2: bell arch
local function bellArch(pos, yaw)
	local cf = CF(pos) * ANG(0, yaw, 0)
	K.bevel(cf * CF(0, 0.6, 0), V3(12, 1.2, 4), MARBLE_D, M.Marble)
	K.arch(cf * CF(0, 1.2, 0), 7, 9, 2.4, MARBLE, M.Marble, GOLD, M.Metal, 7)
	K.ellipsoid(cf * CF(0, 13.4, 0), V3(3.4, 4, 3.4), GOLD, M.Metal)
	K.cyl(cf * CF(0, 11.6, 0) * ANG(0, 0, PI / 2), 0.5, 4.2, GOLD, M.Metal)
	K.ball((cf * CF(0, 11, 0)).Position, 0.8, C(200, 150, 60), M.Metal)
	K.block(cf * CF(0, 15.8, 0), V3(0.3, 1.4, 0.3), GOLD, M.Metal)
	star(cf * CF(0, 21.5, 0), 1.4)
end

-- HL7: floating island with a small temple
local function floatingIsland(pos, s)
	for i = 0, 3 do -- rock underside tapering downward
		local w = (17 - i * 4) * s
		K.block(CF(pos + V3(K.r(-0.5, 0.5), -(i + 0.5) * 3.4 * s, K.r(-0.5, 0.5))) * ANG(0, K.r(0, PI), 0), V3(w, 3.6 * s, w * 0.85), C(210, 204, 196):Lerp(C(176, 168, 160), i * 0.25), M.Slate)
	end
	K.ellipsoid(CF(pos + V3(0, 0.6 * s, 0)), V3(19, 2, 17) * s, GRASS, M.SmoothPlastic)
	for i = 0, 3 do
		local a = i / 4 * PI * 2 + PI / 4
		K.column(pos + V3(math.cos(a) * 3.6 * s, 1.2 * s, math.sin(a) * 3.6 * s), 5 * s, 0.8 * s, MARBLE, M.Marble, GOLD)
	end
	K.block(CF(pos + V3(0, 7.4 * s, 0)), V3(9, 0.8, 9) * s, MARBLE, M.Marble)
	K.pyramid(CF(pos + V3(0, 7.8 * s, 0)), 9 * s, 2.4 * s, CREAM, M.Marble)
	cloud(pos + V3(0, -6 * s, 0), s * 0.8)
end

-- HE1: the monumental winged gate beyond the end of the lane
local function endGate(z)
	local base = V3(0, 0, z)
	K.stairs(CF(base + V3(0, 0, 4)), 46, 6, 0.8, 2, MARBLE, M.Marble)
	K.bevel(CF(base + V3(0, 2.4, 22)), V3(80, 4.8, 24), MARBLE_D, M.Marble)
	-- main arch with glowing portal glass and halo
	K.arch(CF(base + V3(0, 4.8, 18)), 16, 22, 5, MARBLE, M.Marble, GOLD, M.Metal, 11)
	local portal = K.block(CF(base + V3(0, 4.8 + 15, 18)), V3(15.6, 30, 0.6), C(170, 220, 255), M.Neon, false, 0.25)
	K.lamp(portal, C(200, 230, 255), 60, 2)
	K.tag(portal, "TPFC_Pulse", { Period = 8, Base = 0.3, Peak = 0.1 })
	star(CF(base + V3(0, 4.8 + 16, 17.4)), 3)
	ring(CF(base + V3(0, 4.8 + 30, 19)), 16, 30, 1.2)
	star(CF(base + V3(0, 4.8 + 50, 19)), 4)
	K.block(CF(base + V3(0, 4.8 + 42, 19)), V3(0.8, 10, 0.8), GOLD, M.Metal)
	for s = -1, 1, 2 do
		K.column(base + V3(s * 13, 4.8, 15), 26, 2.8, MARBLE, M.Marble, GOLD)
		K.column(base + V3(s * 18, 4.8, 17), 22, 2.4, MARBLE, M.Marble, GOLD)
		-- giant wings sweeping up and out from the gate
		for t = 0, 2 do
			for f = 0, 6 - t do
				local ang = 0.15 + f * 0.2
				local len = 30 - t * 6 - f * 2
				K.wedge(CF(base + V3(s * 12, 26 - t * 5, 22 + t)) * ANG(0, 0, -s * ang) * CF(0, len / 2, 0) * ANG(0, s > 0 and -PI / 2 or PI / 2, 0),
					V3(1.4, len, 7 - t), t == 0 and MARBLE or CREAM, M.Marble)
			end
		end
		-- curved colonnades left and right
		for i = 0, 6 do
			local a = i / 6 * 0.9
			local p = base + V3(s * (26 + math.sin(a) * 40), 4.8, 22 - math.cos(a) * 12 + i * 3)
			K.column(p, 16, 2, MARBLE, M.Marble, GOLD)
		end
	end
end

function B.Build(b)
	K.Seed(8008)
	K.ResetSurfaces()
	K.mirror = true
	local z1, z2 = b[1], b[2]
	K.terraces(z1, z2, {
		rock = MARBLE_D, rockMat = M.Marble, cap = GRASS, capMat = M.SmoothPlastic, drip = true, tiers = 2,
		h1 = { 1.6, 3.4 }, h2 = { 4, 9 },
		skip = { { -1, 2480, 2640 }, { 1, 2620, 2760 } },
		facade = facade,
	})
	---------------------------------------------------------------- LEFT: angel + cascades, colonnade, trees, cypresses, clouds
	angel(V3(-70, 0, 2520), PI / 2)
	cascade(V3(-58, 0, 2580), 3, 18)
	cascade(V3(-60, 0, 2850), 2, 14)
	colonnade(V3(-66, 0, 2740), 5, 7, 8, 1)
	for _, p in ipairs({ { -84, 2490, 1.3 }, { -56, 2440, 1.1 }, { -64, 2960, 1.2 }, { -88, 3060, 1.4 } }) do K.bigTree(K.at(p[1], p[2]), p[3], LEAF, C(122, 86, 56)) end
	for _, p in ipairs({ { -52, 2470 }, { -54, 2660 }, { -52, 2800 }, { -56, 3000 }, { -50, 3120 } }) do cypress(K.at(p[1], p[2]), K.r(1.1, 1.5)) end
	---------------------------------------------------------------- RIGHT: rainbow, bell arch, pools, colonnade, cypresses
	local bands = { C(255, 110, 110), C(255, 176, 90), C(255, 234, 110), C(130, 222, 130), C(110, 180, 255), C(150, 130, 255), C(214, 140, 255) }
	for bi, col in ipairs(bands) do
		local r = 30 - bi * 1.6
		for i = 1, 16 do
			local a0, a1 = (i - 1) / 16 * PI, i / 16 * PI
			local p0 = V3(82, math.sin(a0) * r, 2690 + math.cos(a0) * r)
			local p1 = V3(82, math.sin(a1) * r, 2690 + math.cos(a1) * r)
			K.block(CFrame.lookAt((p0 + p1) / 2, p1), V3(1.6, 1.6, (p1 - p0).Magnitude + 0.3), col, M.SmoothPlastic, false, 0.08)
		end
	end
	cloud(V3(82, 1, 2660), 1)
	cloud(V3(82, 1, 2720), 1)
	bellArch(V3(60, 0, 2650), -PI / 2)
	cascade(V3(64, 0, 2740), 2, 14)
	colonnade(V3(66, 0, 2900), 6, 7, 8, -1)
	for _, p in ipairs({ { 52, 2470 }, { 54, 2600 }, { 52, 2820 }, { 56, 3060 } }) do cypress(K.at(p[1], p[2]), K.r(1.1, 1.5)) end
	for _, p in ipairs({ { 78, 2470, 1.2 }, { 60, 3000, 1.1 }, { 90, 3120, 1.4 } }) do K.bigTree(K.at(p[1], p[2]), p[3], LEAF, C(122, 86, 56)) end
	---------------------------------------------------------------- lilies + clouds along both sides
	for s = -1, 1, 2 do
		for z = z1 + 10, z2 - 10, 30 do
			K.lily(V3(s * K.r(38, 42), 0, z + K.r(-4, 4)), K.r(1, 1.3), LILY, C(255, 226, 150))
		end
		for z = z1, z2, 40 do cloud(V3(s * K.r(96, 130), K.r(0, 10), z + K.r(-10, 10)), K.r(1.6, 2.6)) end
	end
	for _, r in ipairs(K.surfaces) do
		local xa, xb = math.max(r[1], -90), math.min(r[2], 90)
		if xb - xa > 3 and r[5] < 10 then
			for _ = 1, math.floor((xb - xa) * (r[4] - r[3]) / 420) do
				local x, z = K.r(xa + 2, xb - 2), K.r(r[3] + 2, r[4] - 2)
				if math.abs(x) >= 48 then
					if K.chance(0.6) then K.lily(V3(x, r[5], z), K.r(0.9, 1.2), LILY, C(255, 226, 150)) else K.rosette(V3(x, r[5] + 1, z), K.r(0.5, 0.8), K.pick(LEAF)) end
				end
			end
		end
	end
	---------------------------------------------------------------- floating islands + light rays (high, beside the corridor)
	floatingIsland(V3(-80, 70, 2600), 1)
	floatingIsland(V3(90, 84, 2900), 1.2)
	floatingIsland(V3(-110, 96, 3080), 0.9)
	for k = 0, 2 do
		local ray = K.wedge(CF(-70 + k * 9, 90, 2560 + k * 20) * ANG(0, 0, 0.3), V3(5, 120, 12), C(255, 246, 210), M.Neon, false, 0.88)
		ray.CastShadow = false
		K.tag(ray, "TPFC_Pulse", { Period = 8 + k, Base = 0.9, Peak = 0.82 })
	end
	---------------------------------------------------------------- CENTRE: marble floor with gold inlay borders + diamond-star medallions
	for z = z1 + 1, z2 - 13, 14 do
		for x = -27.5, 27.5, 11 do
			K.block(CF(x + K.r(-0.1, 0.1), 0.18, z + 7), V3(10.8, 0.3, 13.8), C(244, 238, 226):Lerp(C(234, 226, 210), K.r(0, 1)), M.Marble)
		end
	end
	for s = -1, 1, 2 do
		K.block(CF(s * 31, 0.36, (z1 + z2) / 2), V3(0.6, 0.12, z2 - z1), GOLD, M.Metal)
		K.block(CF(s * 24, 0.36, (z1 + z2) / 2), V3(0.4, 0.12, z2 - z1), GOLD, M.Metal)
		K.block(CF(s * 35, 0.3, (z1 + z2) / 2), V3(4, 0.3, z2 - z1), MARBLE_D, M.Marble)
	end
	for z = z1 + 40, z2 - 30, 80 do
		K.block(CF(0, 0.37, z) * ANG(0, PI / 4, 0), V3(5, 0.12, 5), GOLD, M.Metal)
		K.block(CF(0, 0.4, z) * ANG(0, PI / 4, 0), V3(3.6, 0.12, 3.6), C(244, 238, 226), M.Marble)
		K.block(CF(0, 0.44, z), V3(0.5, 0.12, 2.6), GOLD, M.Neon)
		K.block(CF(0, 0.44, z), V3(2.6, 0.12, 0.5), GOLD, M.Neon)
	end
	---------------------------------------------------------------- END: the winged gate beyond the last landing point
	K.mirror = false
	endGate(z2 + 8)
end

return B
