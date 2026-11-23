-- OuterHub: the world OUTSIDE the Portal Sanctuary walls (|X| > ~120 and Z < -470), from the
-- outer-world design canvas (sheet "00 Hub") and Maps/00_Portal_Sanctuary_Hub.png. The lobby itself
-- (SanctuaryHub) is untouched. World coordinates, no mirror: viewer-left down the lane is world +X.
--  LEFT  (+X): lilac crags just past the walls, a stepped cliff with a two-step waterfall, flowering
--              trees on the ledges, portal rings in the sky.
--  RIGHT (-X): a two-tier ivory aqueduct on the ridge between two crags, a castle on a far peak.
--  BEHIND:     a grand three-step cascade framed by tall crags, a giant portal ring floating above it.
--  ALL ROUND:  mist banks at the crag feet, lavender ranges fading into the sanctuary haze, cumulus.
-- Only tall silhouettes matter: the walls are 25-48 high, so the ground outside is barely seen.
-- Location: ServerScriptService > Server > OuterHub (ModuleScript), called by WorldBuilder.buildStart.

local K = require(script.Parent.WorldKit)
local V3, CF, ANG, PI, M, C = K.V3, K.CF, K.ANG, K.PI, K.M, K.C

local O = {}

local ROCK, ROCK_L = C(150, 140, 168), C(172, 162, 188) -- matches the sanctuary perimeter stone
local IVORY, GOLD, VIOLET, ROOF = C(227, 219, 205), C(202, 157, 74), C(87, 56, 135), C(86, 48, 145)
local LILAC = C(150, 96, 232) -- deeper than the lobby lilac: neon washes toward pink at range
local GRASS = C(118, 174, 72)
local LEAF = { C(96, 156, 62), C(122, 176, 70), C(222, 146, 200), C(206, 128, 186) }
-- saturated enough to read against the pale lilac stone
local WATER, FOAM = C(96, 196, 236), C(236, 250, 255)

---------------------------------------------------------------- pieces
-- lilac crag: a main faceted spire plus two smaller shoulders (never mirror-symmetric)
local function crag(x, z, R, H, col)
	col = col or ROCK
	local c2 = K.light(col, 0.12)
	K.cone(V3(x, -8, z), R, H + 8, 6, col, c2, M.Limestone)
	K.cone(V3(x + K.r(-0.5, 0.5) * R, -8, z + K.r(0.45, 0.75) * R), R * 0.62, (H + 8) * K.r(0.55, 0.7), 5, c2, col, M.Limestone)
	K.cone(V3(x + K.r(-0.6, 0.6) * R, -8, z - K.r(0.45, 0.75) * R), R * 0.5, (H + 8) * K.r(0.42, 0.58), 5, col, c2, M.Limestone)
end

-- rounded broadleaf / blossom tree for ledges (6 parts)
local function blobTree(pos, s, col)
	col = col or K.pick(LEAF)
	K.block(CF(pos + V3(0, 7 * s, 0)), V3(2.6, 16, 2.6) * s, C(110, 76, 50), M.Wood)
	local c = pos + V3(0, 17 * s, 0)
	K.ellipsoid(CF(c), V3(22, 13, 22) * s, K.dark(col, 0.12), M.SmoothPlastic)
	for i = 0, 2 do
		local a = i / 3 * PI * 2 + K.r(0, 1)
		K.ellipsoid(CF(c + V3(math.cos(a) * 7, K.r(2, 4), math.sin(a) * 7) * s), V3(14, 10, 14) * s, col, M.SmoothPlastic)
	end
	local top = K.ellipsoid(CF(c + V3(0, 6, 0) * s), V3(12, 7, 12) * s, K.light(col, 0.15), M.SmoothPlastic)
	K.tag(top, "TPFC_Sway", { Amp = 0.01, Period = K.r(6, 9) })
end

-- grass-capped stone tier (one step of a cliff)
local function tier(cx, y0, cz, sx, h, sz, col)
	K.block(CF(cx, y0 + h / 2, cz), V3(sx, h, sz), col or ROCK, M.Limestone)
	K.block(CF(cx, y0 + h + 0.5, cz), V3(sx - 1, 1, sz - 1), GRASS, M.Grass)
	return y0 + h
end

-- portal ring: violet neon band, gold outer rim, faint glassy membrane; one Model so it can spin/bob
local function portalRing(center, r, facing, spin, bob)
	local prev = K.Folder()
	local m = Instance.new("Model")
	m.Name = "SkyPortalRing"
	K.SetFolder(m)
	local cf = CFrame.lookAt(center, facing)
	local n = 22
	for i = 0, n - 1 do
		local a = i / n * PI * 2
		local seg = 2 * PI * r / n * 1.1
		K.block(cf * CF(math.cos(a) * r, math.sin(a) * r, 0) * ANG(0, 0, a), V3(r * 0.12, seg, r * 0.1), LILAC, M.Neon)
		K.block(cf * CF(math.cos(a) * r * 1.13, math.sin(a) * r * 1.13, 0) * ANG(0, 0, a), V3(r * 0.07, seg * 1.13, r * 0.14), GOLD, M.Metal)
	end
	local disc = K.cyl(cf * ANG(0, PI / 2, 0), 0.4, r * 1.9, C(196, 160, 246), M.Glass, false, 0.72)
	disc.CastShadow = false
	K.tag(disc, "TPFC_Pulse", { Period = K.r(5, 8), Base = 0.78, Peak = 0.55 })
	m.Parent = prev
	K.SetFolder(prev)
	if spin then K.tag(m, "TPFC_Spin", { Rate = spin }) end
	if bob then K.tag(m, "TPFC_Bob", { Amp = bob, Period = K.r(9, 13), Spin = 0 }) end
	return m
end

-- matte waterfall for long-range viewing: K.waterfall's glass reflects the bright sky and reads
-- white from the lobby. Solid sheet + darker flow stripes + foam, facing faceYaw (look vector).
local function fall(top, h, w, faceYaw)
	local cf = CF(top) * ANG(0, faceYaw, 0)
	local sheet = K.block(cf * CF(0, -h / 2, -0.6), V3(w, h, 1.2), WATER, M.SmoothPlastic, false, 0.08)
	sheet.CastShadow = false
	for i = 1, math.max(2, math.floor(w / 4)) do
		local x = -w / 2 + (i - 0.5) * w / math.max(2, math.floor(w / 4))
		local stripe = K.block(cf * CF(x + K.r(-0.6, 0.6), -h / 2, -1.3), V3(K.r(0.5, 1.1), h * K.r(0.7, 0.95), 0.2), K.light(WATER, 0.35), M.SmoothPlastic, false, 0.2)
		stripe.CastShadow = false
		K.tag(stripe, "TPFC_Pulse", { Period = K.r(2.5, 4), Base = 0.35, Peak = 0.05 })
	end
	K.block(cf * CF(0, 0.2, -0.2), V3(w + 1, 0.8, 2.4), K.light(WATER, 0.25), M.SmoothPlastic)
	for i = -1, 1 do
		K.ellipsoid(cf * CF(i * w * 0.32, -h + 0.8, -2.4), V3(w * 0.45, 3, 4.5), FOAM, M.SmoothPlastic)
	end
end

local function mist(x, y, z, sx, sz)
	local p = K.ellipsoid(CF(x, y, z) * ANG(0, K.r(0, PI), 0), V3(sx, 12, sz), C(219, 232, 233), M.SmoothPlastic, 0.91)
	p.Name = "DistantMistBank"
	p.CastShadow = false
end

-- Terrain.Clouds provides the moving sky; solid cotton-ball cloud meshes are retired.
local function range(x1, x2, z1, z2, n, R, H, col)
	for i = 0, n - 1 do
		local z = z1 + (z2 - z1) * (i + K.r(0.2, 0.8)) / n
		K.cone(V3(K.r(x1, x2), -30, z), K.r(R[1], R[2]), K.r(H[1], H[2]) + 30, 6, col, K.dark(col, 0.06), M.SmoothPlastic)
	end
end

---------------------------------------------------------------- LEFT (+X)
local function leftSide()
	crag(160, -445, 34, 120)
	crag(188, -380, 42, 168)
	crag(178, -195, 38, 150)
	crag(150, -132, 26, 96)
	crag(168, -42, 32, 130)
	-- stepped cliff with a two-step waterfall at z -280 (faces the lobby, -X)
	local z = -282
	local t1 = tier(182, -2, z, 64, 72, 74)
	local t2 = tier(190, t1, z - 4, 46, 48, 56, ROCK_L)
	local t3 = tier(196, t2, z - 6, 30, 16, 38)
	fall(V3(180.6, t3 + 0.4, z - 6), t3 - t2 + 0.4, 16, PI / 2)
	K.water(CF(176, t2 + 0.8, z - 6), V3(14, 0.6, 26), WATER, 0.25)
	fall(V3(149.6, t1 + 0.6, z - 2), t1 - 1, 26, PI / 2)
	K.water(CF(158, t1 + 0.8, z - 2), V3(16, 0.6, 34), WATER, 0.25)
	-- blossom and green trees on the ledges
	blobTree(V3(205, t1 + 1, z + 26), 1.3, LEAF[3])
	blobTree(V3(200, t2 + 1, z + 14), 1.1, LEAF[1])
	blobTree(V3(166, t1 + 1, z - 28), 1.2, LEAF[4])
	blobTree(V3(203, t3 + 1, z - 4), 1.0, LEAF[2])
	-- ledge shelves with trees on two crags
	for _, s in ipairs({ { 150, 62, -195 }, { 158, 74, -42 } }) do
		local top = tier(s[1], s[2] - 10, s[3], 26, 10, 26, ROCK_L)
		blobTree(V3(s[1] + 2, top + 1, s[3] + K.r(-4, 4)), 1.1, K.pick(LEAF))
	end
end

---------------------------------------------------------------- RIGHT (-X)
local function rightSide()
	crag(-165, -450, 36, 135)
	crag(-210, -330, 34, 138)
	crag(-206, -66, 34, 132)
	crag(-150, -190, 24, 80)
	-- two-tier aqueduct along the ridge between the crags (z -300..-100)
	local x = -206
	for i = 0, 5 do
		local z = -284 + i * 32
		K.arch(CF(x, 0, z) * ANG(0, PI / 2, 0), 21, 78, 11, IVORY, M.Limestone, nil, nil, 7)
	end
	for zz = -296, -108, 16 do
		K.block(CF(x, 104, zz), V3(9, 14, 4), IVORY, M.Limestone)
		K.block(CF(x, 97.5, zz), V3(10, 1, 5), GOLD, M.Metal)
	end
	K.block(CF(x, 113, -202), V3(15, 4, 210), IVORY, M.Limestone)
	K.block(CF(x, 111.2, -202), V3(15.6, 0.6, 210.6), GOLD, M.Metal)
	for sd = -1, 1, 2 do
		K.block(CF(x + sd * 6.6, 116.4, -202), V3(1.8, 2.8, 210), IVORY, M.Limestone)
	end
	K.water(CF(x, 115.4, -202), V3(10.8, 0.6, 208), WATER, 0.25)
	-- the channel spills over the near end in a thin fall
	fall(V3(x, 115.4, -96.6), 112, 7, PI)
	-- castle on a far peak
	local cx, cz = -560, -262
	-- flat-topped mesa (a cone's tip can't carry a castle) with crag shoulders for the silhouette
	local by = tier(cx, -2, cz, 150, 100, 130, ROCK_L)
	by = tier(cx, by, cz, 110, 46, 96)
	crag(cx + 70, cz - 50, 46, 120)
	crag(cx - 64, cz + 56, 52, 135, ROCK_L)
	K.block(CF(cx, by + 15, cz), V3(84, 30, 64), C(226, 220, 234), M.Limestone)
	K.block(CF(cx, by + 30.6, cz), V3(86, 1.2, 66), GOLD, M.Metal)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local p = V3(cx + c[1] * 42, by, cz + c[2] * 32)
		K.vcyl(p, 58, 15, C(232, 226, 240), M.Limestone)
		K.vcyl(p + V3(0, 57, 0), 1.2, 17, GOLD, M.Metal)
		K.cone(p + V3(0, 58, 0), 9.5, 26, 6, ROOF, K.light(ROOF, 0.15), M.SmoothPlastic)
	end
	K.vcyl(V3(cx, by, cz), 92, 26, C(236, 230, 244), M.Limestone)
	K.vcyl(V3(cx, by + 91, cz), 1.5, 28, GOLD, M.Metal)
	K.cone(V3(cx, by + 92, cz), 15, 44, 6, ROOF, K.light(ROOF, 0.15), M.SmoothPlastic)
	K.block(CF(cx, by + 140, cz), V3(1.2, 10, 1.2), GOLD, M.Metal)
	for _, y in ipairs({ by + 40, by + 62 }) do
		local w = K.block(CF(cx + 13.2, y, cz), V3(0.6, 7, 3), C(255, 214, 150), M.Neon)
		w.CastShadow = false
	end
	local banner = K.block(CF(cx + 13.3, by + 76, cz), V3(0.5, 22, 8), VIOLET, M.Fabric)
	K.tag(banner, "TPFC_Sway", { Amp = 0.02, Period = 7 })
end

---------------------------------------------------------------- BEHIND (Z < -470)
local function behind()
	-- grand three-step cascade, centred on the avenue axis
	local t1 = tier(0, -2, -585, 150, 92, 62)
	local t2 = tier(0, t1, -596, 100, 58, 46, ROCK_L)
	local t3 = tier(0, t2, -604, 60, 26, 34)
	fall(V3(0, t3 + 0.4, -587.4), t3 - t2 + 0.4, 16, PI)
	K.water(CF(0, t2 + 0.8, -580), V3(34, 0.6, 14), WATER, 0.25)
	fall(V3(0, t2 + 0.6, -573.4), t2 - t1 + 0.6, 24, PI)
	K.water(CF(0, t1 + 0.8, -563), V3(50, 0.6, 18), WATER, 0.25)
	fall(V3(0, t1 + 0.6, -554.4), t1 + 2, 30, PI)
	local pool = K.water(CF(0, 0.4, -540), V3(70, 0.8, 26), WATER, 0.25)
	K.tag(pool, "TPFC_Glint", { Period = 10 })
	-- flanking crags (taller toward the outside)
	crag(-96, -574, 40, 190)
	crag(102, -578, 42, 205)
	crag(-210, -610, 54, 240, ROCK_L)
	crag(214, -604, 50, 225, ROCK_L)
	crag(-150, -520, 26, 92)
	crag(146, -526, 24, 86)
	-- blossom trees on the cascade tiers
	for _, s in ipairs({ { -52, t1, -570 }, { 50, t1, -572 }, { -36, t2, -588 }, { 34, t2, -590 } }) do
		blobTree(V3(s[1], s[2] + 1, s[3]), 1.2, (s[1] < 0) and LEAF[3] or LEAF[4])
	end
	-- the giant portal ring hangs above the cascade, facing the lobby
	portalRing(V3(0, 238, -600), 46, V3(0, 200, -200), nil, 4)
end

---------------------------------------------------------------- build
function O.Build()
	local parentFolder = K.Folder()
	local f = Instance.new("Folder")
	f.Name = "Outer"
	f.Parent = parentFolder
	K.SetFolder(f)
	K.Seed(3301)
	K.mirror = false
	local T = K.terrain
	-- ground beyond the walls (the lobby's own fill stops at |X| 145 and Z -495), 40 thick so the
	-- forest's background hills that reach into Z < 0 no longer hang over empty space
	T:SetMaterialColor(M.LeafyGrass, C(92, 146, 62))
	for s = -1, 1, 2 do
		T:FillBlock(CF(s * 582.5, -22, -450), V3(875, 40, 900), M.LeafyGrass)
	end
	T:FillBlock(CF(0, -22, -697.5), V3(290, 40, 405), M.LeafyGrass)
	for s = -1, 1, 2 do
		T:FillBlock(CF(s * 215, -120, -40), V3(170, 156, 80), M.Air)
	end

	leftSide()
	rightSide()
	behind()

	-- floating portal rings to the sides (never over the avenue), slowly turning
	portalRing(V3(262, 158, -318), 22, V3(0, 40, -230), 9)
	portalRing(V3(336, 212, -118), 28, V3(0, 40, -230), 6)
	portalRing(V3(-300, 182, -404), 24, V3(0, 40, -230), 8)
	portalRing(V3(-392, 232, -58), 30, V3(0, 40, -230), 5)

	-- mist banks at the crag feet, both sides and behind
	for s = -1, 1, 2 do
		for z = -470, -20, 75 do
			mist(s * K.r(150, 240), K.r(8, 18), z + K.r(-20, 20), K.r(120, 180), K.r(80, 120))
		end
	end
	for x = -260, 260, 104 do
		mist(x + K.r(-20, 20), K.r(10, 20), K.r(-530, -500), K.r(130, 180), K.r(70, 100))
	end

	-- lavender ranges fading into the sanctuary haze (fog ends at 850, so nothing further)
	range(440, 780, -820, 60, 6, { 110, 160 }, { 220, 340 }, C(182, 172, 206))
	range(-440, -780, -820, 60, 6, { 110, 160 }, { 220, 340 }, C(178, 168, 204))
	range(-700, 700, -980, -860, 6, { 140, 200 }, { 280, 440 }, C(196, 188, 220))


	K.mirror = false
	K.SetFolder(parentFolder)
end

return O
