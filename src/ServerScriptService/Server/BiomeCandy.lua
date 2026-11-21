-- BiomeCandy: Candy World, Z [900, 1300). Reference: roblox pets/Maps/05_Candy_Biome_Final.png (1:1 inventory).
-- Authored as seen in the reference (K.mirror = true: design -X = screen-left). ONE palace, no plots/hall/houses.
--  LEFT : CaL1 faceted chocolate cliff with icing caps, three-step chocolate waterfall + gold-edged canal ·
--         CaL2 chunky pink candy trees · CaL3 swirl lollipops on striped sticks · CaL4 pink crystals ·
--         CaL5 sugar-coated orange gumdrops
--  RIGHT: CaR1 grand palace (cream facade, chocolate wedge buttresses, candy-stripe columns with gold caps,
--         glowing pink crystal gate in a gold frame, pointed pink windows, steps, whipped-cream swirl dome +
--         gold spire, gold-tipped spires) · CaR2 lollipops, pink trees, gumdrops, crystals
--  CENTRE: pink sugar lane with a wavy cream ribbon along both edges; chocolate peaks with icing far away.
-- Location: ServerScriptService > Server > BiomeCandy (ModuleScript)

local K = require(script.Parent.WorldKit)
local V3, CF, ANG, PI, M = K.V3, K.CF, K.ANG, K.PI, K.M
local C = K.C

local B = {}

local CHOC, CHOC_D, CHOC_L = C(104, 58, 36), C(72, 38, 24), C(132, 78, 48)
local CREAM, ICING = C(250, 236, 214), C(255, 250, 244)
local PINK, PINK_L, PINK_D = C(250, 150, 196), C(255, 196, 222), C(230, 104, 160)
local GOLD, ORANGE, RED = C(226, 176, 74), C(255, 170, 60), C(232, 64, 84)

-- CaL2 / CaR2: pink candy tree (chocolate trunk, faceted pink canopy)
local function candyTree(pos, s)
	local top, mid = K.limb(pos, pos + V3(0.6, 4 * s, 0), pos + V3(-0.4, 8 * s, 0.4), 1.4 * s, 0.9 * s, 4, CHOC, M.SmoothPlastic, true)
	for i = 0, 2 do
		local a = i / 3 * PI * 2 + K.r(-0.3, 0.3)
		local d = V3(math.cos(a), 0, math.sin(a))
		K.limb(mid, mid + d * 1.5 * s + V3(0, 1.5 * s, 0), mid + d * 3.5 * s + V3(0, 3 * s, 0), 0.6 * s, 0.35 * s, 2, CHOC)
	end
	for i = 1, 6 do
		local p = top + V3(K.r(-3.5, 3.5) * s, K.r(-0.5, 3.5) * s, K.r(-3.5, 3.5) * s)
		K.block(CF(p) * ANG(K.r(-0.4, 0.4), K.r(0, PI), K.r(-0.4, 0.4)), V3(K.r(3.4, 5), K.r(2.6, 3.6), K.r(3.4, 5)) * s, PINK:Lerp(i % 2 == 0 and PINK_L or PINK_D, K.r(0, 0.6)), M.SmoothPlastic)
	end
	K.block(CF(top + V3(0, 4.4 * s, 0)) * ANG(0.3, K.r(0, PI), 0.2), V3(4, 2.4, 4) * s, PINK_L, M.SmoothPlastic)
end

-- CaL3 / CaR2: swirl lollipop on a striped stick (spiral on both faces of the disc)
local function lollipop(pos, s, yaw)
	local h = 9 * s
	for i = 0, 7 do
		K.cyl(CF(pos + V3(0, (i + 0.5) * h / 8, 0)) * ANG(0, 0, PI / 2), h / 8 + 0.02, 0.7 * s, i % 2 == 0 and PINK_D or ICING, M.SmoothPlastic, i == 0)
	end
	local cf = CF(pos + V3(0, h + 3.6 * s, 0)) * ANG(0, yaw or 0, 0)
	K.cyl(cf * ANG(0, PI / 2, 0), 1.2 * s, 7.6 * s, ICING, M.SmoothPlastic)
	K.cyl(cf * ANG(0, PI / 2, 0), 1.3 * s, 7.9 * s, PINK_D, M.SmoothPlastic, false)
	K.cyl(cf * ANG(0, PI / 2, 0), 1.25 * s, 7.6 * s, ICING, M.SmoothPlastic)
	for side = -1, 1, 2 do
		local n = 26
		for i = 1, n do
			local t0, t1 = (i - 1) / n * PI * 5, i / n * PI * 5
			local r0, r1 = 0.15 + t0 / (PI * 5) * 3.4, 0.15 + t1 / (PI * 5) * 3.4
			local a = cf * V3(math.cos(t0) * r0 * s, math.sin(t0) * r0 * s, side * 0.64 * s)
			local b = cf * V3(math.cos(t1) * r1 * s, math.sin(t1) * r1 * s, side * 0.64 * s)
			K.block(CFrame.lookAt((a + b) / 2, b, cf.LookVector * side), V3(0.55 * s, 0.1, (a - b).Magnitude + 0.15), PINK, M.SmoothPlastic)
		end
	end
end

-- CaL5 / CaR2: sugar-coated gumdrop (truncated pyramid)
local function gumdrop(pos, s, col)
	K.block(CF(pos + V3(0, 0.8 * s, 0)) * ANG(0, K.r(0, PI), 0), V3(3.6, 1.6, 3.6) * s, col, M.Sand, true)
	local cf = CF(pos + V3(0, 1.6 * s, 0)) * ANG(0, K.r(0, PI), 0)
	for i = 0, 3 do K.wedge(cf * ANG(0, i * PI / 2, 0) * CF(0, 0.6 * s, -1.3 * s), V3(3.6 * s, 1.2 * s, 1 * s), col, M.Sand) end
	K.block(cf * CF(0, 1.1 * s, 0), V3(1.6, 0.2, 1.6) * s, K.light(col, 0.2), M.Sand)
end

-- icing drapes along a ledge edge (cf = edge centre, front = -Z local)
local function icing(cf, w, n)
	K.block(cf, V3(w, 0.6, 2), ICING, M.SmoothPlastic)
	for _ = 1, n do
		local d = K.r(0.8, 2.2)
		K.ellipsoid(cf * CF(K.r(-w / 2 + 0.6, w / 2 - 0.6), -d * 0.45, -0.9), V3(K.r(0.9, 1.6), d, 0.9), ICING, M.SmoothPlastic)
	end
end

-- CaL1: chocolate cliff with three-step waterfall pouring toward the lane
local function chocoCliff(c)
	K.cone(c + V3(-16, 0, 0), 30, 50, 9, CHOC, CHOC_D, M.SmoothPlastic, true)
	for i = 0, 2 do
		local x = c.X - i * 7
		local y = 6 + i * 8
		K.bevel(CF(x, y / 2, c.Z), V3(14, y, 30 - i * 4), CHOC:Lerp(CHOC_D, i * 0.2), M.SmoothPlastic)
		icing(CF(x + 7, y + 0.2, c.Z) * ANG(0, -PI / 2, 0), 30 - i * 4, 7)
		K.addSurface(x - 7, x + 7, c.Z - 15 + i * 2, c.Z + 15 - i * 2, y + 0.4)
		-- falls from this ledge to the one below
		local fall = K.block(CF(x + 7.3, y - 3.5, c.Z), V3(0.8, 7.4, 10 - i), C(120, 66, 38), M.SmoothPlastic)
		K.tag(fall, "TPFC_Pulse", { Period = 5 + i, Base = 0, Peak = 0.08 })
		K.ellipsoid(CF(x + 8.6, (i == 0) and 0.4 or (y - 7.6), c.Z), V3(3, 1.2, 11 - i), CREAM, M.SmoothPlastic)
	end
	for _ = 1, 6 do K.wedge(CF(c + V3(K.r(-24, -8), K.r(30, 48), K.r(-18, 18))) * ANG(0, K.r(0, PI), 0), V3(K.r(6, 10), K.r(4, 7), K.r(5, 8)), CHOC_L, M.SmoothPlastic) end
	K.cone(c + V3(-16, 44, 0), 9, 10, 7, ICING, CREAM, M.SmoothPlastic)
end

-- CaR1 helpers
local function stripeColumn(pos, h, w)
	K.vcyl(pos, h, w, ICING, M.SmoothPlastic, true)
	local n = math.floor(h / 1.2)
	for i = 0, n do
		local a = i * 0.9
		K.block(CF(pos + V3(0, i * 1.2 + 0.6, 0)) * ANG(0, a, 0) * CF(0, 0, -w / 2) * ANG(0, 0, 0.6), V3(w * 0.75, 1.1, 0.22), PINK_D, M.SmoothPlastic)
	end
	K.block(CF(pos + V3(0, h + 0.5, 0)), V3(w + 1, 1, w + 1), GOLD, M.Metal)
	K.cone(pos + V3(0, h + 1, 0), w * 0.5, w * 1.4, 6, GOLD, K.dark(GOLD, 0.15), M.Metal)
end
local function buttress(pos, h, d, yaw)
	local cf = CF(pos) * ANG(0, yaw, 0)
	K.wedge(cf * CF(0, h / 2, 0), V3(4, h, d), CHOC, M.SmoothPlastic, true)
	K.wedge(cf * CF(0, h / 2 + 0.3, 0.6) * CF(0, 0, -0.2), V3(1, h * 0.9, d * 0.9), CREAM, M.SmoothPlastic)
	K.block(cf * CF(0, h + 0.4, d / 2 - 1), V3(4.6, 0.8, 2.4), GOLD, M.Metal)
end
local function pointedWindow(cf, w, h)
	K.block(cf, V3(w + 0.8, h + 0.8, 0.3), GOLD, M.Metal)
	local g = K.block(cf * CF(0, 0, -0.1), V3(w, h, 0.3), PINK, M.Glass, false, 0.1)
	K.wedge(cf * CF(-w / 4, h / 2 + w / 4, 0) * ANG(0, PI / 2, 0), V3(0.3, w / 2, w / 2), GOLD, M.Metal)
	K.wedge(cf * CF(w / 4, h / 2 + w / 4, 0) * ANG(0, -PI / 2, 0), V3(0.3, w / 2, w / 2), GOLD, M.Metal)
	return g
end
local function creamSwirl(pos, r, h)
	local n = 7
	for i = 0, n - 1 do
		local k = 1 - i / n
		K.ellipsoid(CF(pos + V3(math.cos(i * 1.2) * r * 0.08, i * h / n, math.sin(i * 1.2) * r * 0.08)) * ANG(0, i * 0.7, 0.12), V3(r * 2 * k + 1, h / n * 1.6, r * 2 * k + 1), i % 2 == 0 and ICING or CREAM, M.SmoothPlastic)
	end
	K.cone(pos + V3(0, h, 0), 0.8, 4, 5, GOLD, K.dark(GOLD, 0.15), M.Metal)
	K.pyramid(CF(pos + V3(0, h + 4.2, 0)) * ANG(0, PI / 4, 0), 1.2, 1.6, GOLD, M.Neon)
end

local function palace(c)
	-- plinth + front steps (facing the lane, -X design)
	K.bevel(CF(c + V3(10, 1, 0)), V3(60, 2, 96), CREAM, M.SmoothPlastic)
	K.addSurface(c.X - 20, c.X + 40, c.Z - 48, c.Z + 48, 2)
	K.stairs(CF(c + V3(-22, 0, 0)) * ANG(0, -PI / 2, 0), 16, 5, 0.6, 1.4, ICING, M.SmoothPlastic)
	-- main hall: cream body with chocolate base and roof band
	K.bevel(CF(c + V3(14, 2 + 15, 0)), V3(30, 30, 40), CREAM, M.SmoothPlastic)
	K.block(CF(c + V3(14, 2 + 2, 0)), V3(31, 4, 41), CHOC, M.SmoothPlastic)
	K.block(CF(c + V3(14, 2 + 30.6, 0)), V3(32, 1.2, 42), CHOC, M.SmoothPlastic)
	K.block(CF(c + V3(14, 2 + 31.4, 0)), V3(32.4, 0.4, 42.4), GOLD, M.Metal)
	K.gable(CF(c + V3(14, 2 + 31.6, 0)) * ANG(0, 0, 0), 30, 12, 40, CREAM, M.SmoothPlastic)
	-- central gate: gold frame, glowing pink crystal doors, pointed top, gem
	local gx = c.X - 1.2
	local gate = K.block(CF(gx, 2 + 8, c.Z), V3(0.4, 14, 10), PINK, M.Neon, false, 0.3)
	K.lamp(gate, PINK, 30, 1.4)
	K.tag(gate, "TPFC_Pulse", { Period = 7, Base = 0.3, Peak = 0.1 })
	K.pointedArch(CF(gx - 0.4, 2, c.Z) * ANG(0, PI / 2, 0), 10, 14, 6, 1.6, GOLD, M.Metal)
	K.block(CF(gx - 0.6, 2 + 24, c.Z) * ANG(PI / 4, 0, 0), V3(0.6, 4, 4), PINK, M.Neon)
	K.block(CF(gx - 0.5, 2 + 24, c.Z) * ANG(PI / 4, 0, 0), V3(0.5, 5.4, 5.4), GOLD, M.Metal)
	-- facade windows + side wings
	for s = -1, 1, 2 do
		pointedWindow(CF(gx - 0.2, 2 + 14, c.Z + s * 11) * ANG(0, -PI / 2, 0), 3.2, 7)
		K.bevel(CF(c + V3(18, 2 + 11, s * 34)), V3(26, 22, 28), CREAM, M.SmoothPlastic)
		K.block(CF(c + V3(18, 2 + 22.5, s * 34)), V3(27, 1, 29), CHOC, M.SmoothPlastic)
		for k = -1, 1 do pointedWindow(CF(c.X + 4.8, 2 + 11, c.Z + s * 34 + k * 8) * ANG(0, -PI / 2, 0), 2.6, 6) end
		-- chocolate wedge buttresses with cream inlay
		buttress(V3(c.X + 2, 2, c.Z + s * 21), 26, 14, s > 0 and PI or 0)
		buttress(V3(c.X + 4, 2, c.Z + s * 47), 20, 12, s > 0 and PI or 0)
		-- candy-stripe columns with gold caps
		stripeColumn(V3(c.X - 3, 2, c.Z + s * 17), 30, 4)
		stripeColumn(V3(c.X + 2, 2, c.Z + s * 52), 34, 5)
		-- gold-tipped spires on the wings
		K.cone(c + V3(18, 2 + 23, s * 34), 6, 14, 6, CHOC, CHOC_D, M.SmoothPlastic)
		K.cone(c + V3(18, 2 + 37, s * 34), 1.4, 5, 5, GOLD, K.dark(GOLD, 0.15), M.Metal)
	end
	-- central tower with whipped-cream swirl dome + gold spire
	K.bevel(CF(c + V3(20, 2 + 40, 0)), V3(16, 20, 16), CREAM, M.SmoothPlastic)
	for s = -1, 1, 2 do pointedWindow(CF(c.X + 11.8, 2 + 42, c.Z + s * 3.5) * ANG(0, -PI / 2, 0), 2, 6) end
	creamSwirl(c + V3(20, 2 + 50, 0), 9, 16)
	for s = -1, 1, 2 do
		K.bevel(CF(c + V3(30, 2 + 36, s * 10)), V3(6, 10, 6), CHOC, M.SmoothPlastic)
		K.cone(c + V3(30, 2 + 41, s * 10), 3.6, 10, 6, CHOC_L, CHOC, M.SmoothPlastic)
		K.cone(c + V3(30, 2 + 50.5, s * 10), 0.8, 3, 5, GOLD, K.dark(GOLD, 0.15), M.Metal)
	end
end

local function chocoPeak(pos, w, h)
	K.cone(pos, w, h, 7, CHOC, CHOC_D, M.SmoothPlastic, true)
	K.cone(pos + V3(0, h * 0.62, 0), w * 0.42, h * 0.38, 7, ICING, CREAM, M.SmoothPlastic)
end

function B.Build(b)
	K.Seed(5005)
	K.ResetSurfaces()
	K.mirror = true
	local z1, z2 = b[1], b[2]
	-- low pink sugar terraces with cream caps and pink crystal fronts
	K.terraces(z1, z2, {
		rock = C(236, 150, 186), rockMat = M.SmoothPlastic, cap = C(255, 214, 230), capMat = M.SmoothPlastic, drip = true, tiers = 2,
		h1 = { 1.4, 3 }, h2 = { 4, 9 },
		skip = { { 1, 1010, 1190 }, { -1, 950, 1060 } },
		facade = function(s, x1, top, za, zb)
			local z = za
			while z < zb - 1 do
				local l = math.min(K.r(4, 7), zb - z)
				K.bevel(CF(s * (x1 + 1.1), top / 2 - 0.3, z + l / 2), V3(2.8, top + 0.6, l - 0.2), C(240, 160, 196):Lerp(C(250, 186, 212), K.r(0, 1)), M.SmoothPlastic)
				z += l
			end
		end,
	})
	---------------------------------------------------------------- LEFT: chocolate cliff + waterfall + canal, trees, lollipops, crystals, gumdrops
	chocoCliff(V3(-62, 0, 1000))
	-- gold-edged chocolate canal running along the lane edge from the falls
	K.block(CF(-47, 0.2, 1100), V3(6, 0.25, 200), C(110, 62, 36), M.SmoothPlastic)
	for s = -1, 1, 2 do K.block(CF(-47 + s * 3.3, 0.35, 1100), V3(0.6, 0.7, 200), GOLD, M.Metal) end
	for _ = 1, 6 do K.ellipsoid(CF(-47 + K.r(-1.5, 1.5), 0.38, K.r(1004, 1196)), V3(K.r(1, 2), 0.1, K.r(3, 6)), CHOC_L, M.SmoothPlastic) end
	for _, p in ipairs({ { -56, 960, 1.4 }, { -64, 1068, 1.6 }, { -58, 1150, 1.3 }, { -70, 1230, 1.7 }, { -60, 1280, 1.2 }, { -90, 1110, 2 }, { -96, 1200, 2.2 } }) do
		candyTree(K.at(p[1], p[2]), p[3])
	end
	lollipop(K.at(-52, 1030), 1.4, PI / 2)
	lollipop(K.at(-56, 1180), 1.1, PI / 2)
	lollipop(K.at(-54, 1260), 1.3, PI / 2)
	---------------------------------------------------------------- RIGHT: the palace + trees, lollipops
	palace(V3(78, 0, 1100))
	lollipop(K.at(56, 960), 1.5, -PI / 2)
	lollipop(K.at(58, 1228), 1.3, -PI / 2)
	for _, p in ipairs({ { 54, 990, 1.5 }, { 62, 1215, 1.6 }, { 60, 1270, 1.3 }, { 96, 960, 2 }, { 110, 1250, 2.2 } }) do
		candyTree(K.at(p[1], p[2]), p[3])
	end
	---------------------------------------------------------------- crystals + gumdrops at both lane edges (low)
	for s = -1, 1, 2 do
		for z = z1 + 10, z2 - 8, 12 do
			local p = V3(s * K.r(39, 44), 0, z + K.r(-4, 4))
			local q = K.r(0, 1)
			if q < 0.45 then gumdrop(p, K.r(0.9, 1.3), K.chance(0.65) and ORANGE or RED)
			elseif q < 0.8 then K.crystal(p, K.r(2, 3.6), K.r(0.9, 1.3), K.chance(0.5) and PINK or PINK_L, ANG(0, K.r(0, PI), s * 0.3))
			else K.crystalCluster(p, K.r(0.6, 0.9), { PINK, PINK_L, PINK_D }, nil) end
		end
	end
	for _, r in ipairs(K.surfaces) do
		local xa, xb = math.max(r[1], -90), math.min(r[2], 90)
		if xb - xa > 3 and r[5] < 9 then
			for _ = 1, math.floor((xb - xa) * (r[4] - r[3]) / 160) do
				local x, z = K.r(xa + 2, xb - 2), K.r(r[3] + 2, r[4] - 2)
				if math.abs(x) >= 48 and not (x > 45 and z > 1040 and z < 1160) then
					local p = V3(x, r[5], z)
					if K.chance(0.5) then gumdrop(p, K.r(0.9, 1.4), K.chance(0.6) and ORANGE or RED) else K.crystal(p, K.r(2.5, 4.5), 1.2, PINK, ANG(0, 0, K.r(-0.3, 0.3))) end
				end
			end
		end
	end
	---------------------------------------------------------------- CENTRE: wavy cream ribbon along both lane edges (flush)
	for s = -1, 1, 2 do
		local prev
		for z = z1 + 2, z2 - 2, 6 do
			local x = s * (33 + math.sin(z * 0.035 + s) * 2.4)
			local p = V3(x, 0.14, z)
			if prev then K.block(CF((prev + p) / 2, p), V3(2.4, 0.22, (p - prev).Magnitude + 0.6), CREAM, M.SmoothPlastic) end
			prev = p
		end
	end
	---------------------------------------------------------------- far chocolate peaks with icing + pink crystal spires
	for s = -1, 1, 2 do
		for _ = 1, 5 do chocoPeak(V3(s * K.r(130, 175), 0, K.r(z1, z2 + 60)), K.r(18, 28), K.r(40, 80)) end
		for _ = 1, 4 do K.crystal(V3(s * K.r(115, 140), 0, K.r(z1, z2)), K.r(24, 40), K.r(5, 8), PINK_L, ANG(0, 0, K.r(-0.15, 0.15))) end
	end
	---------------------------------------------------------------- transition to Space: darker chocolate strata becoming lunar rock
	for s = -1, 1, 2 do
		for _ = 1, 3 do
			local p = V3(s * K.r(44, 58), 0, K.r(1282, 1298))
			K.rockMass(p, K.r(4, 7), K.r(3, 6), K.r(4, 7), C(70, 56, 60), M.Slate, 2)
		end
	end
	K.mirror = false
end

return B
