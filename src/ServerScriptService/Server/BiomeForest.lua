-- BiomeForest: Green Forest, Z [0, 150). Reference: roblox pets/Maps/01_Forest_Biome.png (built 1:1 from
-- its element inventory). Authored as seen in the reference (K.mirror = true: design -X = screen-left).
--  LEFT : L1 big curved-trunk tree (near) · L2 vine-covered ruin arch with carved leaf panels ·
--         L3 turquoise pool + small fall behind the arch · L4 corner bed: lilies, spotted mushrooms, ferns,
--         clover · L5 stepping slabs · L6 chamfered mossy terrace blocks · L7 stone marker ·
--         L8 stepped terraces, bushes, trees · L9 watchtower on a rocky plateau · L10 distant aqueduct ruin
--  RIGHT: R1 giant oak with sprawling roots over stone terraces · R2 leaf-rune standing stones ·
--         R3 two-step waterfall, turquoise pool, stream toward the viewer, stepping slabs ·
--         R4 lilies + big ferns · R5 mossy foreground outcrop · R6 round trees · R7 scorched transition
--  CENTRE: calm grass with clover patches, carved leaf threshold, scorched path toward the volcano.
-- Location: ServerScriptService > Server > BiomeForest (ModuleScript)

local K = require(script.Parent.WorldKit)
local V3, CF, ANG, PI, M = K.V3, K.CF, K.ANG, K.PI, K.M
local C = K.C

local B = {}

local LEAF = { C(150, 196, 70), C(118, 176, 60), C(96, 156, 54), C(132, 188, 66) }
local BARK, BARK_D = C(134, 90, 56), C(102, 66, 40)
local STONE, STONE_D, MOSS = C(208, 196, 168), C(172, 160, 134), C(112, 166, 60)
local WATER, FOAM = C(104, 212, 196), C(220, 250, 244)
local PINK, WHITE = C(255, 168, 206), C(255, 246, 250)

local function stoneCol() return STONE:Lerp(STONE_D, K.r(0, 1)) end

-- terrace front made of chamfered mossy cut blocks (L6 / R5)
local function facade(s, x1, top, za, zb)
	local z = za
	while z < zb - 1 do
		local l = math.min(K.r(3.5, 6), zb - z)
		local h = top + K.r(-0.3, 0.6)
		K.bevel(CF(s * (x1 + 1.1), h / 2 - 0.3, z + l / 2) * ANG(0, K.r(-0.05, 0.05), 0), V3(2.8, h + 0.6, l - 0.15), stoneCol(), M.Limestone, MOSS)
		z += l
	end
end

-- R2 / L7: standing stone with carved leaf rune and moss top
local function runeStone(pos, yaw, h)
	h = h or 5
	local cf = CF(pos) * ANG(0, yaw, 0)
	K.bevel(cf * CF(0, 0.5, 0), V3(3.4, 1, 2.6), STONE_D, M.Limestone, MOSS)
	K.bevel(cf * CF(0, 1 + h / 2, 0), V3(2.4, h, 1.5), STONE, M.Limestone)
	K.wedge(cf * CF(0, 1 + h + 0.5, 0), V3(2.4, 1, 1.5), STONE, M.Limestone)
	K.leafGlyph(cf * CF(0, 1 + h * 0.55, -0.78), 1.1, K.light(STONE, 0.2))
	local glow = K.block(cf * CF(0, 1 + h * 0.55, -0.74), V3(0.5, 0.5, 0.05), C(190, 255, 140), M.Neon, false, 0.4)
	K.tag(glow, "TPFC_Pulse", { Period = K.r(10, 15), Base = 0.7, Peak = 0.2 })
	K.block(cf * CF(0.2, 1 + h + 1.05, 0), V3(1.8, 0.3, 1.2), MOSS, M.SmoothPlastic)
end

-- R1: the giant oak (trunk base at pos on the plateau)
local function giantOak(pos, S)
	local top = pos + V3(-2, 21, 0) * S
	-- folded trunk: a core plus four twisting strands
	K.limb(pos, pos + V3(0, 15, 0) * S, top, 11 * S, 7.5 * S, 6, BARK, M.Wood, true)
	for i = 0, 3 do
		local a = i / 4 * PI * 2 + 0.3
		local d = V3(math.cos(a), 0, math.sin(a))
		local twist = V3(math.cos(a + 1), 0, math.sin(a + 1))
		K.limb(pos + d * 4.5 * S, pos + twist * 5 * S + V3(0, 14, 0) * S, top + d * 2.5 * S, 4.2 * S, 3 * S, 6, i % 2 == 0 and BARK_D or BARK, M.Wood)
	end
	-- sprawling roots draping over the tiers (lane-side roots reach the lower terrace)
	for i = 0, 8 do
		local a = i / 9 * PI * 2 + 0.2
		local d = V3(math.cos(a), 0, math.sin(a))
		local reach = K.r(16, 24) * S
		local drop = (d.X < -0.3) and -7.5 or -2.5
		local _, mid = K.limb(pos + d * 4.5 * S + V3(0, 4, 0), pos + d * (reach * 0.45) + V3(0, 3.5 * S, 0), pos + d * reach + V3(0, drop, 0), 3.4 * S, 1.2 * S, 5, i % 2 == 0 and BARK or BARK_D, M.Wood)
		if K.chance(0.6) then
			local side = V3(-d.Z, 0, d.X) * (K.chance(0.5) and 1 or -1)
			K.limb(mid, mid + side * 3 * S + d * 2 * S, mid + side * 6 * S + d * 4 * S + V3(0, -2.5, 0), 1.4 * S, 0.6 * S, 3, BARK_D)
		end
	end
	-- glowing knot rune on the lane side of the trunk
	local knot = K.block(CF(pos + V3(-7.6 * S, 16 * S, 0)) * ANG(0, PI / 2, 0), V3(3, 3.4, 0.3) * S, C(255, 214, 110), M.Neon, false, 0.2)
	K.tag(knot, "TPFC_Pulse", { Period = 8, Base = 0.4, Peak = 0.05 })
	K.lamp(knot, C(255, 210, 120), 28, 0.9)
	K.leafGlyph(CF(pos + V3(-7.9 * S, 16 * S, 0)) * ANG(0, PI / 2, 0), 2 * S, C(255, 230, 150))
	-- six great limbs, each with two sub-branches and a rosette canopy
	for i = 0, 5 do
		local a = i / 6 * PI * 2 + 0.5
		local d = V3(math.cos(a), 0, math.sin(a))
		local reach = ((d.X < -0.4) and 20 or 25) * S
		local tip, mid = K.limb(top - V3(0, 3, 0) * S, top + d * 11 * S + V3(0, 6, 0) * S, top + d * reach + V3(0, 6, 0) * S, 4 * S, 1.5 * S, 6, BARK, M.Wood)
		for f = -1, 1, 2 do
			local side = V3(-d.Z, 0, d.X) * f
			local t2 = mid + (side * 10 + d * 6 + V3(0, 5, 0)) * S
			K.limb(mid, mid + (side * 4 + V3(0, 5, 0)) * S, t2, 1.8 * S, 0.7 * S, 3, BARK_D)
			K.canopy(t2 + V3(0, 2, 0) * S, 6 * S, 3 * S, 4, 1.9 * S, LEAF, true)
			K.vine(mid + side * 3 * S + V3(0, -1, 0), K.r(6, 14))
		end
		K.canopy(tip + V3(0, 3, 0) * S, 8 * S, 4 * S, 6, 2.1 * S, LEAF, true)
	end
	K.canopy(top + V3(0, 13, 0) * S, 16 * S, 5 * S, 16, 2.3 * S, LEAF, true)
end

-- L2: ruin arch (plane along the lane, angled toward the viewer) with carved panels and vines
local function ruinArch(pos, yaw)
	local cf = CF(pos) * ANG(0, yaw, 0)
	K.stairs(cf * CF(0, 0, -3.2) * ANG(0, PI, 0), 13, 2, 0.5, 1.4, STONE_D, M.Limestone)
	K.bevel(cf * CF(0, 0.4, 0), V3(14, 0.8, 4.4), STONE_D, M.Limestone, MOSS)
	K.arch(cf * CF(0, 0.8, 0), 7, 8.5, 2.6, STONE, M.Limestone, nil, nil, 7)
	for s = -1, 1, 2 do
		local px = s * 4.75
		for y = 2.5, 7.5, 2.5 do K.block(cf * CF(px, y + 0.8, 0), V3(2.75, 0.12, 2.75), STONE_D, M.Limestone) end -- stacked joints
		K.block(cf * CF(px, 5.3, -1.33), V3(1.8, 2.6, 0.1), STONE_D, M.Limestone)
		K.leafGlyph(cf * CF(px, 5.3, -1.42), 1, K.light(STONE, 0.18))
	end
	K.leafGlyph(cf * CF(0, 14.3, -1.6), 1.1, K.light(STONE, 0.2))
	-- vines over the arch and down the piers
	for _ = 1, 10 do
		local x = K.r(-6, 6)
		local y = 0.8 + 8.5 + math.sqrt(math.max(0, 22 - x * x)) * 1.05
		K.vine(cf * V3(x, y, -1.4), K.r(2, 6))
	end
	for s = -1, 1, 2 do K.vine(cf * V3(s * 6.2, 9.6, -0.6), K.r(5, 8)) end
	K.rosette(cf * V3(4.5, 14.6, 0), 0.45, LEAF[2])
	K.rosette(cf * V3(-3, 15.2, 0.2), 0.4, LEAF[1])
	-- fallen blocks
	for _ = 1, 3 do
		local p = pos + cf.RightVector * K.r(-8, 8) + cf.LookVector * K.r(3, 6) + V3(0, 0.7, 0)
		K.bevel(CF(p) * ANG(0, K.r(0, PI), K.r(-0.15, 0.15)), V3(2.2, 1.4, 2.2), STONE, M.Limestone, MOSS)
	end
end

-- L9: watchtower on a rocky plateau (two-tier roof, railing with balusters, ladder)
local function watchtower(pos)
	local wood, plank, roof = C(124, 84, 52), C(160, 116, 72), C(150, 82, 56)
	for i = 0, 2 do
		local w = 18 - i * 3
		K.bevel(CF(pos + V3(K.r(-1, 1), i * 4 + 2, K.r(-1, 1))), V3(w, 4, w), stoneCol(), M.Limestone, MOSS)
	end
	local base = pos + V3(0, 12, 0)
	K.addSurface(pos.X - 6, pos.X + 6, pos.Z - 6, pos.Z + 6, 12)
	for _, c in ipairs({ { -3.5, -3.5 }, { 3.5, -3.5 }, { -3.5, 3.5 }, { 3.5, 3.5 } }) do
		K.block(CF(base + V3(c[1], 8, c[2])), V3(1.2, 16, 1.2), wood, M.Wood, true)
		K.block(CF(base + V3(c[1], 0.5, c[2])), V3(1.8, 1, 1.8), STONE_D, M.Limestone)
	end
	for _, y in ipairs({ 5, 11 }) do
		for s = -1, 1, 2 do
			K.block(CF(base + V3(s * 3.5, y, 0)) * ANG(0.62, 0, 0), V3(0.5, 8.8, 0.5), wood, M.Wood)
			K.block(CF(base + V3(0, y, s * 3.5)) * ANG(0, 0, 0.62), V3(8.8, 0.5, 0.5), wood, M.Wood)
		end
	end
	K.block(CF(base + V3(0, 16.4, 0)), V3(10.5, 0.8, 10.5), plank, M.WoodPlanks, true)
	for s = -1, 1, 2 do
		K.block(CF(base + V3(s * 5, 18, 0)), V3(0.4, 0.4, 10.5), wood, M.Wood)
		K.block(CF(base + V3(0, 18, s * 5)), V3(10.5, 0.4, 0.4), wood, M.Wood)
		for k = -4, 4, 2 do
			K.block(CF(base + V3(s * 5, 17.4, k)), V3(0.25, 1.4, 0.25), wood, M.Wood)
			K.block(CF(base + V3(k, 17.4, s * 5)), V3(0.25, 1.4, 0.25), wood, M.Wood)
		end
	end
	for _, c in ipairs({ { -4.6, -4.6 }, { 4.6, -4.6 }, { -4.6, 4.6 }, { 4.6, 4.6 } }) do
		K.block(CF(base + V3(c[1], 20, c[2])), V3(0.6, 6, 0.6), wood, M.Wood)
	end
	K.block(CF(base + V3(0, 23.1, 0)), V3(13, 0.5, 13), K.dark(roof, 0.25), M.WoodPlanks)
	K.pyramid(CF(base + V3(0, 23.3, 0)), 13, 3.4, roof, M.WoodPlanks)
	K.block(CF(base + V3(0, 26.4, 0)), V3(5, 2.4, 5), wood, M.Wood)
	K.pyramid(CF(base + V3(0, 27.6, 0)), 7.5, 3.6, roof, M.WoodPlanks)
	K.pyramid(CF(base + V3(0, 31.1, 0)), 0.8, 1.4, C(220, 180, 90), M.Metal)
	local lamp = K.block(CF(base + V3(0, 19, 0)), V3(1, 1.2, 1), C(255, 210, 140), M.Glass, false, 0.1)
	K.lamp(lamp, C(255, 200, 130), 18, 0.8)
	for y = 1, 16, 1.6 do K.block(CF(base + V3(4.3, y, 0)), V3(0.3, 0.3, 2), wood, M.Wood) end
	for s = -1, 1, 2 do K.block(CF(base + V3(4.3, 8.5, s)), V3(0.3, 17, 0.3), wood, M.Wood) end
end

-- R3 + L3: water pieces (turquoise glass with foam lips)
local function water(cf, size)
	local w = K.water(cf, size, WATER, 0.22)
	K.tag(w, "TPFC_Glint", { Period = K.r(9, 14) })
	return w
end
local function fall(topPos, h, w, faceYaw)
	K.waterfall(topPos, h, w, faceYaw, C(150, 228, 214), FOAM)
end

-- R7: scorched dead tree with glowing cracks
local function deadTree(pos, s)
	local burnt = C(58, 42, 36)
	K.limb(pos, pos + V3(0.5, 4 * s, 0), pos + V3(-0.5, 9 * s, 0.5), 1.6 * s, 0.7 * s, 4, burnt, M.Wood, true)
	for i = 1, 4 do
		local a = i / 4 * PI * 2 + K.r(-0.4, 0.4)
		local d = V3(math.cos(a), 0, math.sin(a))
		local b0 = pos + V3(0, K.r(4, 8) * s, 0)
		K.limb(b0, b0 + d * 2 * s + V3(0, 1.5 * s, 0), b0 + d * 4.5 * s + V3(0, K.r(1, 3.5) * s, 0), 0.6 * s, 0.25 * s, 2, burnt)
	end
	for k = 0, 2 do
		local crack = K.block(CF(pos + V3(0, (1.5 + k * 2.2) * s, 0)) * ANG(0, k * 2.1, 0) * CF(0, 0, -0.82 * s), V3(0.22, 1.6 * s, 0.1), C(255, 110, 30), M.Neon)
		K.tag(crack, "TPFC_Pulse", { Period = K.r(7, 12), Base = 0.2, Peak = 0 })
	end
end

function B.Build(b)
	K.Seed(1001)
	K.ResetSurfaces()
	K.mirror = true
	local z1, z2 = b[1], b[2]
	---------------------------------------------------------------- terraces (L6/L8 left, R5 right-front)
	K.terraces(z1 - 4, z2 - 14, {
		rock = STONE_D, rockMat = M.Limestone, cap = MOSS, capMat = M.SmoothPlastic, drip = true, tiers = 3,
		h1 = { 2.6, 4 }, h2 = { 5, 9 }, h3 = { 8, 15 },
		skip = { { 1, 40, 160 }, { -1, 108, 160 } },
		facade = facade,
	})
	---------------------------------------------------------------- R1 oak plateau
	K.block(CF(84, -1, 96), V3(72, 8, 112), STONE_D, M.Limestone, true) -- tier A top 3
	K.block(CF(84, 3.3, 96), V3(72, 0.6, 112), MOSS, M.SmoothPlastic)
	K.addSurface(48, 120, 40, 152, 3.6)
	facade(1, 46.5, 3.6, 40, 152)
	K.block(CF(92, 4, 100), V3(60, 8, 90), STONE, M.Limestone, true) -- tier B top 8
	K.block(CF(92, 8.3, 100), V3(60, 0.6, 90), MOSS, M.SmoothPlastic)
	K.addSurface(62, 122, 55, 145, 8.6)
	facade(1, 60.5, 8.6, 55, 145)
	K.stairs(CF(57, 3.6, 124) * ANG(0, -PI / 2, 0), 6, 4, 1.25, 1.5, STONE, M.Limestone)
	giantOak(V3(96, 8.6, 96), 1.7)
	-- R2 rune stones around the roots
	runeStone(V3(55, 3.6, 62), PI / 2 + 0.2, 4.5)
	runeStone(V3(57, 3.6, 92), PI / 2 - 0.15, 3.6)
	runeStone(V3(68, 8.6, 74), PI / 2 + 0.3, 6.5)
	runeStone(V3(70, 8.6, 128), PI / 2 - 0.3, 4)
	-- R3 two-step waterfall -> pool on tier A -> fall over the front -> stream toward the viewer
	fall(V3(61.6, 8.4, 70), 4.8, 7, PI / 2)
	water(CF(55, 3.75, 68), V3(11, 0.3, 14))
	for i = 1, 6 do K.bevel(CF(55 + K.r(-6, 6), 3.9, (i <= 3) and 60.2 or 75.8), V3(2.4, 1, 2.2), stoneCol(), M.Limestone, MOSS) end
	fall(V3(47.6, 3.6, 64), 3.4, 5, PI / 2)
	for _, sg in ipairs({ { 44, 64, 40 }, { 42.5, 40, 22 }, { 44, 22, 4 } }) do
		local zc, len = (sg[2] + sg[3]) / 2, sg[2] - sg[3]
		water(CF(sg[1], 0.14, zc), V3(5.5, 0.22, len + 3))
		K.block(CF(sg[1], 0.05, zc), V3(7, 0.1, len + 3), C(150, 140, 116), M.Slate)
	end
	for _ = 1, 6 do K.block(CF(43.5 + K.r(-1, 1), 0.35, K.r(8, 60)) * ANG(0, K.r(0, PI), 0), V3(2, 0.4, 1.8), STONE, M.Limestone) end
	-- R4 flowers and big ferns around the pool and stream
	for _ = 1, 5 do K.lily(V3(K.r(50, 60), 3.6, K.r(46, 84)), K.r(0.9, 1.2), K.chance(0.6) and PINK or WHITE) end
	for _ = 1, 3 do K.lily(V3(K.r(37, 39.5), 0, K.r(10, 40)), K.r(0.9, 1.1), PINK) end
	K.fernBig(V3(50, 3.6, 30), 1.8)
	K.fernBig(V3(39, 0, 52), 1.3)
	K.fernBig(V3(60, 3.6, 110), 1.5)
	K.fernBig(V3(52, 3.6, 140), 1.4)
	-- R6 round trees
	K.bigTree(V3(110, 8.6, 146), 1.6, LEAF, BARK)
	K.bigTree(K.at(72, 16), 1.8, LEAF, BARK, V3(-0.2, 0, 0))
	K.bigTree(V3(114, 3.6, 46), 1.5, LEAF, BARK)

	---------------------------------------------------------------- LEFT
	-- L1 big curved tree (near-left)
	K.bigTree(K.at(-62, 18), 2.3, LEAF, BARK, V3(0.2, 0, 0.1))
	-- L2 ruin arch + L3 pool and small fall behind it
	ruinArch(K.at(-58, 38), PI / 2 - 0.3)
	local pp = K.at(-70, 46)
	water(CF(pp + V3(0, 0.15, 0)), V3(12, 0.3, 16))
	for i = 1, 7 do K.bevel(CF(pp + V3(K.r(-7, 7), 0.4, (i % 2 == 0) and -8.4 or 8.4)), V3(2.2, 1, 2.2), stoneCol(), M.Limestone, MOSS) end
	fall(pp + V3(-6.5, 5.5, 0), 5.2, 6, -PI / 2)
	-- L4 corner bed: lilies, spotted mushrooms, ferns, clover
	K.lily(V3(-45, 0, 10), 1.3, PINK)
	K.lily(V3(-41, 0, 16), 1.1, WHITE)
	K.lily(V3(-47, 0, 21), 1.2, PINK)
	K.lily(V3(-39, 0, 28), 0.9, WHITE)
	K.toadstool(V3(-46, 0, 30), 1.35)
	K.toadstool(V3(-43.5, 0, 33), 0.8)
	K.fernBig(V3(-40, 0, 6), 1.2)
	K.fernBig(V3(-44, 0, 40), 1.1)
	for _ = 1, 10 do K.clover(V3(-K.r(36, 46), 0, K.r(4, 44)), K.r(0.9, 1.3)) end
	-- L5 stepping slabs
	for i = 0, 4 do K.block(CF(-37 - (i % 2) * 2.4, 0.12, 22 + i * 3.6) * ANG(0, K.r(0, 1), 0), V3(K.r(2.4, 3.2), 0.22, K.r(2, 2.6)), C(222, 214, 192), M.Limestone) end
	-- L7 marker
	K.bevel(CF(-44.5, 1.6, 50), V3(1.6, 3.2, 1.6), STONE, M.Limestone, MOSS)
	K.leafGlyph(CF(-44.5, 1.8, 50) * ANG(0, -PI / 2, 0) * CF(0, 0, -0.85), 0.6, K.light(STONE, 0.2))
	-- L8 terrace dressing: rosette bushes, lilies, trees
	for _ = 1, 14 do
		local p = K.at(-K.r(54, 74), K.r(z1 + 4, 106))
		if K.chance(0.6) then K.rosette(p + V3(0, 1, 0), K.r(0.45, 0.7), K.pick(LEAF)) else K.lily(p, K.r(0.8, 1), K.chance(0.5) and PINK or WHITE) end
	end
	K.bigTree(K.at(-74, 72), 1.9, LEAF, BARK)
	K.bigTree(K.at(-92, 98), 2.2, LEAF, BARK)
	K.bigTree(K.at(-104, 44), 2.4, LEAF, BARK)
	K.bigTree(K.at(-96, 0), 2, LEAF, BARK)
	-- L9 watchtower on its plateau (left, back)
	watchtower(V3(-80, 0, 124))
	K.bigTree(V3(-104, 0, 128), 1.4, LEAF, BARK)
	K.bigTree(V3(-62, 0, 116), 1.0, LEAF, BARK)
	-- L10 distant aqueduct ruin (far left skyline)
	for i = 0, 2 do
		K.arch(CF(-128, 0, 150 + i * 13) * ANG(0, PI / 2, 0), 8, 16, 3, STONE_D, M.Limestone, nil, nil, 7)
	end
	K.block(CF(-128, 27.5, 163), V3(3.4, 2, 40), STONE_D, M.Limestone)

	---------------------------------------------------------------- CENTRE
	-- carved leaf threshold across the start of the lane (flush)
	K.block(CF(0, 0.07, 11), V3(60, 0.14, 3), C(214, 204, 178), M.Limestone)
	K.block(CF(0, 0.1, 11) * ANG(0, PI / 4, 0), V3(2.6, 0.14, 2.6), C(214, 204, 178), M.Limestone)
	K.block(CF(0, 0.16, 11) * ANG(0, PI / 4, 0), V3(1.4, 0.14, 1.4), MOSS, M.SmoothPlastic)
	for x = -27, 27, 9 do K.block(CF(x, 0.11, 11), V3(0.2, 0.14, 3), C(176, 164, 138), M.Limestone) end
	-- clover patches and a few pale stone breaks
	for _ = 1, 34 do
		local x = K.r(18, 34) * (K.chance(0.5) and 1 or -1)
		K.clover(V3(x, 0, K.r(14, 132)), K.r(0.9, 1.4))
	end
	-- R7 scorched path + transition (z 126..150)
	for _ = 1, 8 do
		K.block(CF(K.r(-14, 14), 0.06, K.r(130, 150)) * ANG(0, K.r(0, PI), 0), V3(K.r(6, 10), 0.12, K.r(4, 7)), C(112, 84, 60), M.Ground)
	end
	for s = -1, 1, 2 do
		deadTree(V3(s * K.r(47, 52), 0, K.r(136, 142)), 1.2)
		deadTree(V3(s * K.r(60, 70), 0, K.r(144, 150)), 1.5)
		for _ = 1, 2 do
			local p = V3(s * K.r(40, 46), 0, K.r(132, 148))
			K.rockMass(p, K.r(3, 5), K.r(2, 3.5), K.r(3, 5), C(70, 56, 50), M.Basalt, 2)
		end
		for _ = 1, 3 do
			local crack = K.block(CF(s * K.r(32, 40), 0.08, K.r(134, 150)) * ANG(0, K.r(0, PI), 0), V3(0.3, 0.1, K.r(3, 6)), C(255, 110, 30), M.Neon, false, 0.2)
			K.tag(crack, "TPFC_Pulse", { Period = K.r(9, 14), Base = 0.25, Peak = 0 })
		end
	end
	-- skyline
	-- forested green hills behind the terraces (no grey rock walls) + soft distant ridges
	local T = K.terrain
	T:SetMaterialColor(M.LeafyGrass, C(92, 146, 62))
	for s = -1, 1, 2 do
		for z = z1 - 30, z2 + 30, 18 do
			T:FillBall(V3(s * K.r(128, 150), K.r(-14, -4), z + K.r(-6, 6)), K.r(22, 32), M.LeafyGrass)
			T:FillBall(V3(s * K.r(170, 200), K.r(-10, 6), z + K.r(-8, 8)), K.r(28, 40), M.LeafyGrass)
		end
	end
	-- dense ground cover on every terrace top within view (bushes, ferns, flowers, mossy stones, saplings)
	for _, r in ipairs(K.surfaces) do
		local xa, xb = math.max(r[1], -84), math.min(r[2], 84)
		if xb - xa > 3 then
			local n = math.floor((math.min(xb, 74) - xa) * (r[4] - r[3]) / 42)
			for _ = 1, n do
				local x, z = K.r(xa + 1.5, xb - 1.5), K.r(r[3] + 1.5, r[4] - 1.5)
				if math.abs(x) >= 46 and math.abs(x) <= 74 and (V3(x, 0, z) - V3(96, 0, 96)).Magnitude > 22 then
					local p = V3(x, r[5], z)
					local q = K.r(0, 1)
					if q < 0.5 then K.rosette(p + V3(0, 1.1, 0), K.r(0.7, 1.15), K.pick(LEAF))
					elseif q < 0.65 then K.fernBig(p, K.r(1, 1.5))
					elseif q < 0.78 then K.lily(p, K.r(1, 1.4), K.chance(0.6) and PINK or WHITE)
					elseif q < 0.9 then K.bevel(CF(p + V3(0, 0.7, 0)) * ANG(0, K.r(0, PI), 0), V3(K.r(2, 3.4), 1.6, K.r(2, 3.4)), stoneCol(), M.Limestone, MOSS)
					else K.bigTree(p, K.r(0.8, 1.1), LEAF, BARK) end
				end
			end
		end
	end
	-- lane-edge beds right against the corridor (low): lilies, ferns, clover, mossy stones
	for s = -1, 1, 2 do
		for z = 16, 128, 10 do
			local p = V3(s * K.r(36, 42), 0, z + K.r(-2, 2))
			local q = K.r(0, 1)
			if q < 0.35 then K.lily(p, K.r(1.2, 1.6), K.chance(0.6) and PINK or WHITE)
			elseif q < 0.6 then K.fernBig(p, K.r(1.1, 1.5))
			elseif q < 0.8 then K.bevel(CF(p + V3(s * 2, 0.6, 0)) * ANG(0, K.r(0, PI), 0), V3(K.r(2.2, 3.4), 1.4, K.r(2.2, 3.4)), stoneCol(), M.Limestone, MOSS)
			else K.rosette(p + V3(s * 1.5, 0.8, 0), K.r(0.5, 0.7), K.pick(LEAF)) end
			K.clover(p + V3(-s * K.r(3, 6), 0, K.r(-2, 2)), K.r(1.2, 1.7))
		end
	end
	K.mirror = false
end

return B
