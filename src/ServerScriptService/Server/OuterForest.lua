-- OuterForest: the world OUTSIDE the Forest lane, from the outer-world design canvas (sheet "01 Forest").
-- The lane module (BiomeForest) owns |X| < ~130; this owns |X| >= 130 out to the skyline.
-- Authored in design coordinates with K.mirror = true (design -X = screen-left from the hall camera).
--  LEFT  (wild):  terraced overgrown cliff + root spills + high-ledge waterfall into a gorge pool,
--                 a cliff-top giant tree, broadleaf clusters on rolling hills, the hero tree on the horizon.
--  RIGHT (ruins): ivy ruin walls, broken arch row, cut-stone terraces, an aqueduct across the valley
--                 (one span broken), a stone watchtower on a ridge, a few orchard trees.
--  FAR:           four blue-green ranges, each layer paler (fog does the rest); big soft cumulus.
-- Kept cheap on purpose: big simple masses, ~1k parts; far trees are 6-part blobs, not rosettes.
-- Location: ServerScriptService > Server > OuterForest (ModuleScript), called by WorldBuilder.

local K = require(script.Parent.WorldKit)
local V3, CF, ANG, PI, M, C = K.V3, K.CF, K.ANG, K.PI, K.M, K.C

local O = {}

local LEAF = { C(78, 143, 53), C(110, 170, 62), C(140, 198, 63), C(96, 156, 54) }
local BARK, BARK_D = C(138, 90, 52), C(104, 68, 40)
local STONE, STONE_D, MOSS = C(207, 198, 168), C(160, 150, 124), C(94, 138, 58)
local CLIFF = C(132, 126, 104)
local IVY = C(84, 140, 58)
local GOLD, BANNER, ROOF = C(229, 181, 74), C(181, 40, 46), C(150, 82, 56)
local WATER, FOAM = C(104, 212, 214), C(225, 250, 248)

-- terrain is not mirrored by WorldKit: do it here
local function mx(x) return K.mirror and -x or x end

---------------------------------------------------------------- ground + hills
local hills = {}
local function hill(x, z, r, top)
	local cy = top - r
	table.insert(hills, { x, z, r, cy })
	K.terrain:FillBall(V3(mx(x), cy, z), r, M.LeafyGrass)
end
local function hillY(x, z)
	local y = 0
	for _, h in ipairs(hills) do
		local d2 = (x - h[1]) ^ 2 + (z - h[2]) ^ 2
		if d2 < h[3] * h[3] then y = math.max(y, h[4] + math.sqrt(h[3] * h[3] - d2)) end
	end
	return y
end

---------------------------------------------------------------- pieces
-- far/mid broadleaf: trunk + 5 lumpy canopy ellipsoids (reads as the reference's rounded crowns at range)
local function blobTree(pos, s)
	local col = K.pick(LEAF)
	K.block(CF(pos + V3(0, 9 * s, 0)) * ANG(0, K.r(0, PI), K.r(-0.06, 0.06)), V3(3.4, 20, 3.4) * s, BARK, M.Wood)
	local c = pos + V3(0, 22 * s, 0)
	K.ellipsoid(CF(c), V3(30, 17, 30) * s, K.dark(col, 0.12), M.SmoothPlastic)
	for i = 0, 2 do
		local a = i / 3 * PI * 2 + K.r(0, 1)
		K.ellipsoid(CF(c + V3(math.cos(a) * 9, K.r(2, 5), math.sin(a) * 9) * s), V3(18, 12, 18) * s * K.r(0.85, 1.15), col, M.SmoothPlastic)
	end
	local top = K.ellipsoid(CF(c + V3(-1, 8, -1) * s), V3(16, 9, 16) * s, K.light(col, 0.16), M.SmoothPlastic)
	if K.chance(0.4) then K.tag(top, "TPFC_Sway", { Amp = 0.01, Period = K.r(6, 9) }) end
end

-- faceted mountain peak (K.cone) sunk below ground so the base never shows
local function peak(x, z, R, H, col)
	-- SmoothPlastic: Slate's texture greys the teal out at range
	K.cone(V3(x, -30, z), R, H + 30, 6, col, K.dark(col, 0.07), M.SmoothPlastic)
end

-- one range layer: n peaks spread along Z, x jittered, all the same tint
local function range(x, x2, z1, z2, n, R, H, col)
	for i = 0, n - 1 do
		local z = z1 + (z2 - z1) * (i + K.r(0.2, 0.8)) / n
		peak(K.r(x, x2), z, K.r(R[1], R[2]), K.r(H[1], H[2]), col)
	end
end

---------------------------------------------------------------- LEFT: wild
local function leftCliff(z1, z2)
	-- three stepped tiers climbing away from the lane; a gorge notch at z 84..108 for the waterfall
	local tiers = { { 134, 150, 18, 24 }, { 150, 168, 32, 42 }, { 168, 192, 50, 64 } }
	local z = z1
	while z < z2 do
		local len = math.min(K.r(22, 30), z2 - z)
		local zc = z + len / 2
		local gorge = zc > 80 and zc < 112
		for ti, t in ipairs(tiers) do
			if not (gorge and ti < 3) then
				local h = K.r(t[3], t[4])
				local w = t[2] - t[1]
				local col = CLIFF:Lerp(K.dark(CLIFF, 0.2), K.r(0, 1))
				K.block(CF(-(t[1] + t[2]) / 2, h / 2 - 2, zc), V3(w, h + 4, len + 0.3), col, M.Limestone)
				K.block(CF(-(t[1] + t[2]) / 2 - 0.4, h + 0.5, zc), V3(w + 0.8, 1, len + 0.5), MOSS:Lerp(K.light(MOSS, 0.15), K.r(0, 1)), M.SmoothPlastic)
				-- moss drips down the lane-facing face
				for _ = 1, K.ri(0, 2) do
					local dh = K.r(3, h * 0.45)
					K.block(CF(-t[1] + 0.2, h - dh / 2 + 0.3, K.r(z + 2, z + len - 2)), V3(0.6, dh, K.r(2, 4)), MOSS, M.SmoothPlastic)
				end
				-- leaf blobs on the shelves
				if K.chance(0.55) then K.rosette(V3(-K.r(t[1] + 3, t[2] - 3), h + 2.5, K.r(z + 3, z + len - 3)), K.r(1.6, 2.4), K.pick(LEAF), true) end
			end
		end
		z += len
	end
end

local function waterfall()
	-- ledge lip on tier 3, fall down the gorge, pool at the bottom
	local top = 58
	K.block(CF(-172, top + 1, 96), V3(10, 2, 26), STONE_D, M.Limestone)
	K.block(CF(-172, top + 2.2, 96), V3(10.4, 0.6, 26.4), MOSS, M.SmoothPlastic)
	K.water(CF(-178, top + 1.6, 96), V3(10, 0.5, 14), WATER, 0.2)
	K.waterfall(V3(-166.5, top + 1.5, 96), top + 1.5, 14, -PI / 2, C(150, 228, 226), FOAM)
	local pool = K.water(CF(-150, 0.35, 96), V3(32, 0.5, 26), WATER, 0.22)
	K.tag(pool, "TPFC_Glint", { Period = 11 })
	for i = 1, 8 do
		local zz = (i % 2 == 0) and 82.5 or 109.5
		K.bevel(CF(-K.r(136, 164), 0.7, zz + K.r(-1, 1)) * ANG(0, K.r(0, PI), 0), V3(K.r(3, 5), 1.8, K.r(3, 5)), STONE, M.Limestone, MOSS, false)
	end
	-- gorge walls so the notch reads as cut rock, not a gap
	for _, zz in ipairs({ 82, 110 }) do
		K.block(CF(-151, 14, zz), V3(34, 32, 3), K.dark(CLIFF, 0.15), M.Limestone)
	end
end

local function rootSpills()
	for _, z in ipairs({ 18, 52, 128, 146 }) do
		local p0 = V3(-186, 60, z)
		local _, mid = K.limb(p0, V3(-166, 66, z + K.r(-4, 4)), V3(-146, K.r(20, 26), z + K.r(-6, 6)), 6, 2.2, 6, K.chance(0.5) and BARK or BARK_D, M.Wood)
		K.limb(mid, mid + V3(4, -2, 5), V3(-138, K.r(2, 8), z + K.r(4, 9)), 2.4, 1, 3, BARK_D, M.Wood)
	end
	K.bigTree(V3(-184, 60, 34), 2.4, LEAF, BARK, V3(0.25, 0, 0))
	K.bigTree(V3(-182, 58, 138), 2.0, LEAF, BARK, V3(0.2, 0, -0.1))
end

local function leftForest(z1, z2)
	-- every hill stays inside z 0..250 (the ground plate + edge slope) so no sphere underside shows
	hill(-235, 80, 80, 30)
	hill(-300, 130, 110, 48)
	hill(-380, 120, 130, 64)
	hill(-470, 110, 140, 80)
	for _ = 1, 26 do
		local x, z = -K.r(205, 470), K.r(z1 - 10, z2 + 10)
		blobTree(V3(x, hillY(x, z) - 1, z), K.r(1.1, 1.7))
	end
end

local function heroTree()
	-- far enough ahead to clear the lane canopy from the hub camera; it stands on its own hill that
	-- rises out of the haze (stepped terrain cylinders, widest at the bottom, so no underside shows)
	local base = V3(-470, 30, 540) -- top of the stepped hill below
	for i = 0, 7 do
		K.terrain:FillCylinder(CF(mx(base.X), -195 + i * 30, base.Z), 30, 270 - i * 20, M.LeafyGrass)
	end
	for i = 1, 6 do
		local a = i / 6 * PI * 2 + 0.4
		local r = K.r(95, 120)
		blobTree(V3(base.X + math.cos(a) * r, base.Y - 2, base.Z + math.sin(a) * r), K.r(1.6, 2.2))
	end
	-- trunk: tapered limb with flaring roots
	local top = base + V3(14, 205, -6)
	K.limb(base + V3(0, 20, 0), base + V3(-10, 110, 0), top, 46, 26, 8, BARK, M.Wood)
	for i = 0, 5 do
		local a = i / 6 * PI * 2 + 0.3
		local d = V3(math.cos(a), 0, math.sin(a))
		K.limb(base + V3(0, 46, 0), base + d * 40 + V3(0, 26, 0), base + d * 82 + V3(0, 22, 0), 22, 9, 3, BARK_D, M.Wood)
	end
	-- great limbs + layered crown above the fog
	for i = 0, 5 do
		local a = i / 6 * PI * 2
		local d = V3(math.cos(a), 0, math.sin(a))
		local tip = K.limb(top - V3(0, 10, 0), top + d * 40 + V3(0, 30, 0), top + d * 95 + V3(0, K.r(40, 70), 0), 18, 7, 4, BARK, M.Wood)
		K.ellipsoid(CF(tip + V3(0, 14, 0)), V3(110, 62, 110) * K.r(0.85, 1.15), K.pick(LEAF), M.SmoothPlastic)
	end
	K.ellipsoid(CF(top + V3(0, 70, 0)), V3(230, 110, 210), K.dark(LEAF[1], 0.08), M.SmoothPlastic)
	K.ellipsoid(CF(top + V3(-10, 112, 6)), V3(170, 80, 160), LEAF[2], M.SmoothPlastic)
	local crown = K.ellipsoid(CF(top + V3(-16, 140, 0)), V3(100, 46, 96), K.light(LEAF[3], 0.12), M.SmoothPlastic)
	K.tag(crown, "TPFC_Sway", { Amp = 0.004, Period = 14 })
end

---------------------------------------------------------------- RIGHT: ruins
local function ivyStrips(x, za, zb, h)
	for _ = 1, math.floor((zb - za) / 5) do
		local len = K.r(4, h * 0.7)
		K.block(CF(x, h - len / 2, K.r(za + 1, zb - 1)), V3(0.5, len, K.r(1.2, 2.6)), IVY:Lerp(MOSS, K.r(0, 1)), M.SmoothPlastic)
	end
end

local function ruinWalls()
	-- long wall with a stepped, broken top (design +X = screen-right)
	local z = 4
	while z < 76 do
		local len = K.r(6, 9)
		local h = 30 - math.abs(z - 34) * K.r(0.35, 0.5) + K.r(-3, 2)
		h = math.max(8, h)
		K.block(CF(140, h / 2, z + len / 2), V3(5, h, len - 0.2), STONE:Lerp(STONE_D, K.r(0, 0.6)), M.Brick)
		K.block(CF(140, h + 0.4, z + len / 2), V3(5.6, 0.8, len), K.light(STONE, 0.05), M.Limestone)
		ivyStrips(137.3, z, z + len, h)
		z += len
	end
	-- lower second wall behind, fallen blocks at its foot
	for zz = 34, 92, 9 do
		local h = K.r(10, 18)
		K.block(CF(152, h / 2, zz), V3(4, h, 8.6), STONE_D, M.Brick)
	end
	for _ = 1, 6 do
		K.bevel(CF(K.r(134, 148), 1, K.r(6, 88)) * ANG(K.r(-0.2, 0.2), K.r(0, PI), K.r(-0.2, 0.2)), V3(K.r(3, 5), 2.4, K.r(3, 5)), STONE, M.Limestone, MOSS, false)
	end
end

local function archRow()
	for i, z in ipairs({ 100, 120, 140 }) do
		local h = (i == 2) and 30 or 24
		K.arch(CF(146, 0, z) * ANG(0, PI / 2, 0), 12, h, 4, STONE, M.Limestone, GOLD, M.Metal, 7)
		ivyStrips(143.2, z - 2, z + 2, h)
	end
	-- lintel joining the first two, broken off over the third
	K.block(CF(146, 40, 110), V3(4.4, 2.4, 24), STONE_D, M.Limestone)
end

local function rightTerraces(z1, z2)
	-- kept low so the aqueduct behind (X 248) still reads above them from the lane camera
	local tiers = { { 160, 176, 10, 14 }, { 176, 194, 20, 26 } }
	local z = z1
	while z < z2 do
		local len = math.min(K.r(24, 34), z2 - z)
		for _, t in ipairs(tiers) do
			local h = K.r(t[3], t[4])
			K.block(CF((t[1] + t[2]) / 2, h / 2 - 2, z + len / 2), V3(t[2] - t[1], h + 4, len - 0.4), STONE_D:Lerp(STONE, K.r(0, 0.5)), M.Limestone)
			K.block(CF((t[1] + t[2]) / 2 - 0.4, h + 0.4, z + len / 2), V3(t[2] - t[1] + 0.8, 0.8, len), MOSS, M.SmoothPlastic)
			-- cut-block joint lines on the lane face
			for y = 6, h - 3, 6 do K.block(CF(t[1] - 0.05, y, z + len / 2), V3(0.3, 0.3, len - 0.6), K.dark(STONE_D, 0.18), M.Limestone) end
		end
		z += len
	end
end

local function aqueduct(z1, z2)
	local x, step = 248, 20
	local i = 0
	for z = z1, z2, step do
		i += 1
		local broken = (i == 6)
		if not broken then
			K.arch(CF(x, 0, z) * ANG(0, PI / 2, 0), 14, 34, 8, STONE, M.Limestone, nil, nil, 7)
			-- upper tier: short piers carrying the channel
			for k = -1, 1, 2 do K.block(CF(x, 52, z + k * 5), V3(6, 12, 3), STONE_D, M.Limestone) end
		else
			-- broken span: just a stump and a rubble pile
			K.block(CF(x, 9, z), V3(7, 18, 7), STONE_D, M.Limestone)
			for _ = 1, 5 do K.bevel(CF(x + K.r(-8, 8), 1.4, z + K.r(-8, 8)) * ANG(K.r(-0.3, 0.3), K.r(0, PI), 0), V3(K.r(4, 7), 3, K.r(4, 7)), STONE, M.Limestone, MOSS, false) end
		end
	end
	-- channel deck in two pieces either side of the break, with jagged ends
	local zb = z1 + step * 5
	for _, seg in ipairs({ { z1 - 8, zb - 12 }, { zb + 12, z2 + 8 } }) do
		local len, zc = seg[2] - seg[1], (seg[1] + seg[2]) / 2
		K.block(CF(x, 59.5, zc), V3(10, 3, len), STONE, M.Limestone)
		for k = -1, 1, 2 do K.block(CF(x + k * 4.3, 62, zc), V3(1.4, 2, len), STONE_D, M.Limestone) end
		K.water(CF(x, 61.2, zc), V3(6.4, 0.4, len - 1), WATER, 0.25)
		ivyStrips(x - 5.3, seg[1], seg[2], 58)
	end
end

local function watchtower()
	hill(330, 140, 100, 40)
	local x, z = 276, 140
	local y = hillY(x, z) - 2
	local base = V3(x, y, z)
	K.block(CF(base + V3(0, 4, 0)), V3(32, 8, 32), STONE_D, M.Limestone)
	K.block(CF(base + V3(0, 58, 0)), V3(22, 100, 22), STONE, M.Limestone)
	for yy = 20, 100, 20 do K.block(CF(base + V3(0, yy, 0)), V3(22.6, 1.2, 22.6), K.dark(STONE, 0.14), M.Limestone) end
	for _, yy in ipairs({ 44, 74 }) do K.block(CF(base + V3(-11.1, yy, 0)), V3(0.4, 7, 3), C(40, 34, 30), M.SmoothPlastic) end
	-- parapet with crenellations
	K.block(CF(base + V3(0, 109, 0)), V3(27, 3, 27), STONE_D, M.Limestone)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
		K.block(CF(base + V3(c[1] * 11.5, 112.5, c[2] * 11.5)), V3(4, 4, 4), STONE, M.Limestone)
	end
	K.pyramid(CF(base + V3(0, 113, 0)), 20, 22, ROOF, M.WoodPlanks)
	K.block(CF(base + V3(0, 138, 0)), V3(0.8, 6, 0.8), GOLD, M.Metal)
	-- red banner on the lane-facing side
	local b = K.block(CF(base + V3(-11.6, 84, 0)), V3(0.5, 30, 9), BANNER, M.Fabric)
	K.tag(b, "TPFC_Sway", { Amp = 0.02, Period = 6 })
	K.block(CF(base + V3(-11.7, 99.5, 0)), V3(0.6, 1, 10), GOLD, M.Metal)
	local lamp = K.block(CF(base + V3(-11.4, 107, 0)), V3(1.2, 2, 2), C(255, 210, 140), M.Neon)
	K.lamp(lamp, C(255, 200, 130), 30, 0.8)
end

local function orchard()
	for _ = 1, 7 do
		local x, z = K.r(285, 420), K.r(10, 120)
		blobTree(V3(x, hillY(x, z) - 1, z), K.r(0.9, 1.3))
	end
end

---------------------------------------------------------------- build
function O.Build(b)
	local parentFolder = K.Folder()
	local f = Instance.new("Folder")
	f.Name = "Outer"
	f.Parent = parentFolder
	K.SetFolder(f)
	K.Seed(2001)
	K.mirror = true
	hills = {}
	local z1, z2 = b[1], b[2]
	local zEnd = z2 + 10 -- outer scenery overlaps the volcano blend a little

	-- ground beyond the lane valley (the zone fill stops at |X| 130); surface renders at y ~ 0.
	-- 40 thick so hill undersides above y -42 are buried; past the zone it slopes down into the haze
	-- instead of ending in a cut edge.
	local T = K.terrain
	T:SetMaterialColor(M.LeafyGrass, C(92, 146, 62))
	for s = -1, 1, 2 do
		T:FillBlock(CF(s * 575, -22, (z1 + zEnd) / 2), V3(890, 40, zEnd - z1), M.LeafyGrass)
	end

	leftCliff(z1 - 6, zEnd)
	waterfall()
	rootSpills()
	leftForest(z1, zEnd)
	watchtower() -- (its ridge hill must exist before the carve below)
	-- carve every hill below the plate's underside, then add the edge slope (top y -2 at zEnd down to
	-- y -42 eighty studs later; a wedge is tallest at its local +Z, so it is turned to face back)
	for s = -1, 1, 2 do
		T:FillBlock(CF(s * 575, -152, (z1 + 340) / 2), V3(890, 220, 340 - z1), M.Air)
		T:FillWedge(CF(s * 575, -22, zEnd + 40) * ANG(0, PI, 0), V3(890, 40, 80), M.LeafyGrass)
	end
	heroTree()

	ruinWalls()
	archRow()
	rightTerraces(z1 - 6, zEnd)
	aqueduct(z1 + 20, z2 + 40)
	orchard()

	-- far ranges: four layers, each paler and further (left and right never mirror)
	range(560, 760, 380, 700, 4, { 90, 130 }, { 200, 260 }, C(94, 140, 136))
	range(-880, -1120, 300, 900, 6, { 150, 210 }, { 300, 420 }, C(127, 168, 162))
	range(1100, 1500, 450, 1050, 5, { 220, 300 }, { 400, 560 }, C(169, 200, 192))
	range(-1450, -1800, 450, 1150, 5, { 260, 340 }, { 550, 700 }, C(195, 218, 210))

	-- The shared Terrain.Clouds sky owns cloud shape, weather and sunlight.

	K.mirror = false
	K.SetFolder(parentFolder)
end

return O
