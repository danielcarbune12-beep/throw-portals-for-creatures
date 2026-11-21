-- BiomeCrystal: Crystal Caves, Z [600, 900). Reference: roblox pets/Maps/04_Crystal_Biome_Final.png (1:1 inventory).
-- Authored as seen in the reference (K.mirror = true: design -X = screen-left). NO creature landmark.
--  LEFT : CL1 giant split geode (purple shell, pale-pink quartz rim, huge cyan + violet crystal fan, stepped
--         ledges) · CL2 turquoise mineral pool with ledges · CL3 rune monolith (dark slab, gold trim, cyan
--         diamond) · CL4 tall glowing cyan mushrooms · CL5 pink crystal clusters on purple rock steps
--  RIGHT: CR1 layered pink sandstone strata mounds + pink sand · CR2 turquoise pools + small cyan fall ·
--         CR3 two rune monoliths · CR4 pink mushrooms · CR5 violet/cyan crystal clusters
--  BACK : tall canyon walls with crystal ledges, light shafts from above (beside, not over, the corridor)
--  CENTRE: quiet dark slab road.
-- Location: ServerScriptService > Server > BiomeCrystal (ModuleScript)

local K = require(script.Parent.WorldKit)
local V3, CF, ANG, PI, M = K.V3, K.CF, K.ANG, K.PI, K.M
local C = K.C

local B = {}

local ROCK, ROCK_D, ROCK_L = C(86, 66, 132), C(54, 42, 92), C(112, 90, 160)
local CYAN, VIOLET, PINK, MAGENTA = C(90, 232, 255), C(170, 100, 255), C(255, 120, 210), C(230, 70, 220)
local QUARTZ, SAND = C(250, 222, 240), C(252, 196, 214)
local GOLD, POOL = C(222, 172, 84), C(70, 224, 222)

local function rockCol() return ROCK:Lerp(ROCK_D, K.r(0, 0.8)):Lerp(ROCK_L, K.r(0, 0.3)) end

local function facade(s, x1, top, za, zb)
	local z = za
	while z < zb - 1 do
		local l = math.min(K.r(3.5, 6.5), zb - z)
		local h = top + K.r(-0.3, 0.8)
		K.bevel(CF(s * (x1 + 1.1), h / 2 - 0.4, z + l / 2) * ANG(0, K.r(-0.06, 0.06), 0), V3(2.8, h + 0.6, l - 0.2), rockCol(), M.Slate)
		if K.chance(0.22) then K.crystal(V3(s * (x1 + 0.6), h + 0.1, z + l / 2), K.r(1.6, 3), K.r(0.6, 0.9), K.chance(0.5) and PINK or CYAN, ANG(0, K.r(0, PI), s * -0.3), true) end
		z += l
	end
end

-- CL3 / CR3: rune monolith with gold trim and a glowing cyan diamond
local function monolith(pos, yaw, h)
	h = h or 16
	local cf = CF(pos) * ANG(0, yaw, 0)
	K.bevel(cf * CF(0, 1, 0), V3(6, 2, 4.4), ROCK_D, M.Slate)
	K.block(cf * CF(0, 2.15, 0), V3(5.4, 0.3, 3.8), GOLD, M.Metal)
	K.bevel(cf * CF(0, 2 + h / 2, 0), V3(4, h, 2.4), C(70, 62, 100), M.Slate)
	K.wedge(cf * CF(0, 2 + h + 1.2, 0), V3(4, 2.4, 2.4), C(70, 62, 100), M.Slate)
	for s = -1, 1, 2 do K.block(cf * CF(s * 1.75, 2 + h / 2, -1.25), V3(0.3, h - 1, 0.15), GOLD, M.Metal) end
	local gy = 2 + h * 0.55
	K.block(cf * CF(0, gy, -1.25) * ANG(0, 0, PI / 4), V3(2.6, 2.6, 0.2), GOLD, M.Metal)
	local gem = K.block(cf * CF(0, gy, -1.4) * ANG(0, 0, PI / 4), V3(1.8, 1.8, 0.3), CYAN, M.Neon)
	K.lamp(gem, CYAN, 20, 1.2)
	K.tag(gem, "TPFC_Pulse", { Period = K.r(9, 14), Base = 0, Peak = 0.4 })
end

-- CL4 / CR4: tall glowing mushroom
local function glowShroom(pos, s, col)
	K.vcyl(pos, 3.2 * s, 0.8 * s, K.light(col, 0.55), M.SmoothPlastic)
	local under = K.ellipsoid(CF(pos + V3(0, 3.2 * s, 0)), V3(3.6, 0.5, 3.6) * s, col, M.Neon)
	K.ellipsoid(CF(pos + V3(0, 3.5 * s, 0)), V3(4, 1.8, 4) * s, K.dark(col, 0.15), M.SmoothPlastic)
	for i = 0, 3 do
		local a = i / 4 * PI * 2 + 0.3
		K.ellipsoid(CF(pos + V3(math.cos(a) * 0.9 * s, 4.25 * s, math.sin(a) * 0.9 * s)), V3(0.5, 0.15, 0.5) * s, K.light(col, 0.6), M.Neon)
	end
	if s >= 1.2 then K.lamp(under, col, 12 * s, 0.7) end
end
local function shroomCluster(pos, s, col)
	glowShroom(pos, s, col)
	glowShroom(pos + V3(K.r(1.5, 2.5) * s, 0, K.r(-1.5, 1.5) * s), s * 0.6, col)
	glowShroom(pos + V3(K.r(-2.5, -1.5) * s, 0, K.r(-1, 1) * s), s * 0.45, col)
end

-- CR1: layered pink sandstone strata mound with sand skirt and crystals
local function strata(pos, s)
	local y = 0
	local yaw = K.r(0, PI)
	for i = 0, 4 do
		local w = (14 - i * 2.3) * s
		local th = K.r(1.8, 2.6) * s
		local cf = CF(pos + V3(K.r(-0.8, 0.8) * s, y + th / 2, K.r(-0.8, 0.8) * s)) * ANG(0, yaw + K.r(-0.25, 0.25), 0)
		K.bevel(cf, V3(w, th, w * 0.75), i % 2 == 0 and C(244, 150, 196) or C(250, 190, 216), M.Sandstone)
		K.block(cf * CF(0, -th * 0.15, 0), V3(w + 0.1, th * 0.18, w * 0.75 + 0.1), C(226, 112, 170), M.Sandstone)
		y += th * 0.9
	end
	K.ellipsoid(CF(pos + V3(0, 0.3, 0)), V3(18, 0.8, 15) * s, SAND, M.Sand)
	K.crystalCluster(pos + V3(K.r(-2, 2) * s, y, K.r(-2, 2) * s), s * 0.9, { PINK, MAGENTA, C(255, 170, 230) }, 0)
end

-- CL2 / CR2: turquoise mineral pool with stepped rock rim
local function pool(pos, w, d)
	local water = K.block(CF(pos + V3(0, 0.3, 0)), V3(w, 0.3, d), POOL, M.Glass, false, 0.18)
	K.tag(water, "TPFC_Pulse", { Period = K.r(7, 11), Base = 0.18, Peak = 0.05 })
	K.lamp(water, POOL, 18, 0.6)
	K.block(CF(pos + V3(0, 0.1, 0)), V3(w, 0.2, d), C(30, 100, 120), M.Slate)
	for i = 0, math.floor((w + d) / 2.4) do
		local t = i / math.floor((w + d) / 2.4) * PI * 2
		local p = pos + V3(math.cos(t) * (w / 2 + 1.2), 0, math.sin(t) * (d / 2 + 1.2))
		K.bevel(CF(p + V3(0, 0.6, 0)) * ANG(0, -t, 0), V3(2.6, K.r(1, 1.8), 2.6), rockCol(), M.Slate)
	end
	for _ = 1, 3 do K.crystal(pos + V3(K.r(-w / 2, w / 2), 0, (K.chance(0.5) and 1 or -1) * (d / 2 + 1.5)), K.r(2, 3.5), 0.9, K.chance(0.5) and PINK or CYAN, ANG(0, 0, K.r(-0.4, 0.4)), true) end
end

-- CL1: the split geode (opening faces the lane, +X design)
local function geode(c)
	-- stepped ledges in front
	for i = 0, 3 do
		K.bevel(CF(c + V3(14 - i * 5, 1 + i * 1.6, 0)), V3(10, 2 + i * 3.2, 70 - i * 8), rockCol(), M.Slate)
		K.addSurface(c.X + 9 - i * 5, c.X + 19 - i * 5, c.Z - 35 + i * 4, c.Z + 35 - i * 4, 2 + i * 3.2)
	end
	-- outer shell: a half dome of faceted rock slabs around the back
	for i = 0, 18 do
		local a = (i / 18) * PI
		local p = c + V3(-math.sin(a) * 30, 0, math.cos(a) * 42)
		local h = 30 + math.sin(a) * 32
		K.block(CF(p + V3(0, h / 2, 0)) * ANG(0, -a, -0.18), V3(12, h, 12), rockCol(), M.Slate, true)
		-- the shell crown curls toward the lane
		K.block(CF(p + V3(4, h + 3, 0)) * ANG(0, -a, -0.6), V3(12, 8, 12), rockCol(), M.Slate)
		-- glowing magenta cracks on the outer face
		if i % 3 == 0 then
			local cr = K.block(CF(p + V3(-6.1, h * 0.55, 0)) * ANG(0, -a, 0) * ANG(K.r(-0.5, 0.5), 0, 0), V3(0.2, h * 0.4, 0.5), MAGENTA, M.Neon)
			K.tag(cr, "TPFC_Pulse", { Period = K.r(9, 14), Base = 0.2, Peak = 0 })
		end
	end
	-- pale-pink quartz ring around the opening (lumpy band in the lane-facing plane)
	local rimX, H, Wd = c.X + 6, 46, 58
	for i = 0, 30 do
		local t = i / 30 * PI
		local p = V3(rimX + K.r(-0.6, 0.6), math.sin(t) * H, math.cos(t) * Wd / 2 + c.Z)
		K.block(CF(p) * ANG(t, K.r(-0.3, 0.3), K.r(-0.3, 0.3)), V3(K.r(3.5, 5), K.r(4, 6), K.r(4, 6)), QUARTZ:Lerp(SAND, K.r(0, 0.6)), M.SmoothPlastic)
		if i % 2 == 0 then K.block(CF(p + V3(1.4, 0, 0)) * ANG(t, 0.4, 0.4), V3(2.2, 2.4, 2.2), K.light(QUARTZ, 0.4), M.Glass, false, 0.2) end
	end
	-- the crystal fan bursting from the back of the geode
	local fan = c + V3(-2, 0, 0)
	for i = 0, 14 do
		local a = (i / 14 - 0.5) * 2.6
		local len = 40 - math.abs(i - 7) * 3
		local col = (i % 3 == 0) and VIOLET or ((i % 3 == 1) and CYAN or C(150, 200, 255))
		local cr = K.crystal(fan + V3(0, 0, math.sin(a) * 10), len, K.r(8, 10), col, ANG(0, 0, -0.75) * ANG(a * 0.5, 0, 0), i % 3 == 0)
		if i == 7 then K.lamp(cr, CYAN, 70, 3) end
		if i % 4 == 0 then K.tag(cr, "TPFC_Pulse", { Period = 3 + i * 0.3, Base = 0, Peak = 0.3 }) end
	end
	for _ = 1, 14 do
		K.crystal(c + V3(K.r(-12, 6), K.r(2, 8), K.r(-28, 28)), K.r(3, 8), K.r(1.2, 2.2), K.chance(0.5) and PINK or CYAN, ANG(K.r(-0.5, 0.5), 0, K.r(-0.8, 0.2)), K.chance(0.3))
	end
end

-- canyon wall segment with crystal ledges (far sides)
local function canyon(x, z, h)
	K.bevel(CF(x, h / 2, z), V3(26, h, K.r(26, 40)), rockCol(), M.Slate)
	K.block(CF(x - (x > 0 and 4 or -4), h + 2, z) * ANG(0, 0, (x > 0 and -1 or 1) * 0.3), V3(22, 6, 30), rockCol(), M.Slate)
	for _ = 1, 3 do
		K.crystalCluster(V3(x - (x > 0 and 12 or -12), K.r(8, h - 4), z + K.r(-10, 10)), K.r(0.8, 1.3), { PINK, CYAN, VIOLET }, K.ri(0, 4))
	end
end

function B.Build(b)
	K.Seed(4004)
	K.ResetSurfaces()
	K.mirror = true
	local z1, z2 = b[1], b[2]
	K.terraces(z1, z2, {
		rock = ROCK, rockMat = M.Slate, cap = ROCK_L, capMat = M.Slate, drip = false, tiers = 3,
		h1 = { 1.6, 3.4 }, h2 = { 5, 10 }, h3 = { 8, 18 },
		skip = { { -1, 690, 830 } },
		facade = facade,
	})
	---------------------------------------------------------------- LEFT: geode, pool, monolith, mushrooms, crystals
	geode(V3(-82, 0, 760))
	pool(V3(-56, 0, 664), 14, 20)
	monolith(K.at(-60, 640), PI / 2, 18)
	monolith(K.at(-58, 852), PI / 2, 14)
	shroomCluster(K.at(-50, 690), 1.4, CYAN)
	shroomCluster(K.at(-52, 842), 1.1, CYAN)
	---------------------------------------------------------------- RIGHT: strata mounds, pools + fall, monoliths, pink mushrooms
	strata(K.at(66, 650), 1.2)
	strata(K.at(74, 730), 1.5)
	strata(K.at(62, 812), 1.1)
	strata(K.at(84, 872), 1.3)
	pool(V3(54, 0, 700), 12, 16)
	pool(V3(56, 0, 860), 10, 14)
	for i = 0, 2 do
		local seg = K.block(CF(60.5, 3 + i * 1.8, 700), V3(0.7, 2, 4 - i * 0.6), i % 2 == 0 and POOL or K.light(POOL, 0.3), M.Glass, false, 0.1)
		K.tag(seg, "TPFC_Pulse", { Period = K.r(4, 6), Base = 0.1, Peak = 0.02 })
	end
	monolith(K.at(56, 760), -PI / 2, 16)
	monolith(K.at(58, 888), -PI / 2, 13)
	shroomCluster(K.at(50, 740), 1.2, PINK)
	shroomCluster(K.at(52, 620), 1, PINK)
	---------------------------------------------------------------- dressing: crystal clusters on every terrace top within view
	for _, r in ipairs(K.surfaces) do
		local xa, xb = math.max(r[1], -90), math.min(r[2], 90)
		if xb - xa > 3 then
			for _ = 1, math.floor((xb - xa) * (r[4] - r[3]) / 170) do
				local x, z = K.r(xa + 2, xb - 2), K.r(r[3] + 2, r[4] - 2)
				if math.abs(x) >= 48 then
					local q = K.r(0, 1)
					local p = V3(x, r[5], z)
					if q < 0.6 then K.crystalCluster(p, K.r(0.6, 1.2), { PINK, CYAN, VIOLET, MAGENTA }, K.chance(0.3) and 0 or nil)
					elseif q < 0.8 then glowShroom(p, K.r(0.8, 1.2), K.chance(0.5) and CYAN or PINK)
					else K.bevel(CF(p + V3(0, 0.8, 0)) * ANG(0, K.r(0, PI), 0), V3(K.r(2.4, 4), 1.8, K.r(2.4, 4)), rockCol(), M.Slate) end
				end
			end
		end
	end
	-- lane edge crystals + small rocks (low)
	for s = -1, 1, 2 do
		for z = z1 + 8, z2 - 6, 11 do
			local p = V3(s * K.r(37, 43), 0, z + K.r(-3, 3))
			if K.chance(0.5) then K.crystal(p, K.r(1.6, 3), K.r(0.6, 1), K.pick({ PINK, CYAN, VIOLET }), ANG(0, K.r(0, PI), s * 0.4), K.chance(0.3))
			else K.bevel(CF(p + V3(0, 0.5, 0)) * ANG(0, K.r(0, PI), 0), V3(K.r(2, 3.2), 1.2, K.r(2, 3.2)), rockCol(), M.Slate) end
		end
	end
	---------------------------------------------------------------- BACK: canyon walls, far crystal ledges, light shafts beside the corridor
	for s = -1, 1, 2 do
		for z = z1, z2, 34 do canyon(s * K.r(118, 132), z + K.r(-6, 6), K.r(40, 70)) end
	end
	---------------------------------------------------------------- CENTRE: quiet dark slab road
	for z = z1 + 1, z2 - 13, 14 do
		for x = -27.5, 27.5, 11 do
			K.block(CF(x + K.r(-0.15, 0.15), 0.18, z + 7), V3(10.7, 0.3, 13.7), C(70, 62, 96):Lerp(C(84, 76, 110), K.r(0, 1)), M.Slate)
		end
	end
	---------------------------------------------------------------- transition to Candy: rounded pink mineral/sugar insets
	for s = -1, 1, 2 do
		for _ = 1, 3 do
			local p = V3(s * K.r(44, 56), 0, K.r(882, 898))
			K.ellipsoid(CF(p + V3(0, 1, 0)), V3(K.r(4, 6), K.r(2, 3), K.r(4, 6)), C(255, 190, 220), M.SmoothPlastic)
			K.crystal(p + V3(0, 1.5, 0), K.r(2, 3), 0.8, PINK, ANG(0, 0, s * 0.3))
		end
	end
	K.mirror = false
end

return B
