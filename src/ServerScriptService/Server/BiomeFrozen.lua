-- BiomeFrozen: Frozen Kingdom, Z [350, 600). Reference: roblox pets/Maps/03_Frozen_Biome.png (1:1 inventory).
-- Authored as seen in the reference (K.mirror = true: design -X = screen-left).
--  LEFT : FL1 two natural ice-rock arches with snow drapes, icicles, glowing ice · FL2 ice cave with glowing
--         crystals + snowman (goggles, scarf, satchel) + sled and lantern · FL3 small frozen fall + pond with
--         ice floes · FL4 snowy pines, blue crystal clusters · FL5 carved stairs
--  RIGHT: FR1 ice citadel (very tall central crystal spire, spiked turrets, glowing pointed gate, snowflake
--         emblem, snowflake banners) · FR2 grand stairs · FR3 big glowing frozen waterfall into an ice-floe
--         pool · FR4 second snowman vignette, pines, crystals
--  CENTRE: snow lane with a honeycomb of pale-blue hexagonal ice tiles; ice cliffs and aurora beyond.
-- Location: ServerScriptService > Server > BiomeFrozen (ModuleScript)

local K = require(script.Parent.WorldKit)
local V3, CF, ANG, PI, M = K.V3, K.CF, K.ANG, K.PI, K.M
local C = K.C

local B = {}

local ROCK, ROCK_D = C(132, 146, 186), C(100, 112, 156)
local SNOW = C(246, 250, 255)
local ICE, ICE_D, GLOW = C(196, 230, 252), C(126, 186, 238), C(110, 214, 255)
local BANNER, PINE = C(36, 86, 186), C(40, 100, 82)

local function rockCol() return ROCK:Lerp(ROCK_D, K.r(0, 1)) end

-- flat hexagon (three rotated slabs)
local function hex(pos, r, col, mat, transp)
	for i = 0, 2 do
		K.block(CF(pos) * ANG(0, i * PI / 3, 0), V3(r * 2, 0.12, r * 1.155), col, mat or M.SmoothPlastic, false, transp)
	end
end
local function icicles(cf, w, n, maxH)
	for _ = 1, n do
		local h = K.r(1, maxH or 3)
		K.wedge(cf * CF(K.r(-w / 2, w / 2), -h / 2, 0) * ANG(PI, K.r(0, PI), 0), V3(0.6, h, 0.6), ICE, M.Ice)
	end
end
-- thick snow cap with rounded drapes along its front edge (frontSign = side of the cap facing the lane)
local function snowCap(cf, size, frontSign)
	K.block(cf, size, SNOW, M.Snow)
	for z = -size.Z / 2 + 1, size.Z / 2 - 1, K.r(1.8, 2.8) do
		local d = K.r(0.9, 1.8)
		K.ellipsoid(cf * CF(frontSign * size.X / 2, -d * 0.3, z), V3(1.4, d, K.r(1.6, 2.6)), SNOW, M.Snow)
	end
end
local function vein(cf, h)
	local v = K.block(cf, V3(0.18, h, 0.45), GLOW, M.Neon, false, 0.15)
	K.tag(v, "TPFC_Glint", { Period = K.r(9, 16) })
end

-- terrace front: blue rock blocks with draping snow and glowing veins
local function facade(s, x1, top, za, zb)
	local z = za
	while z < zb - 1 do
		local l = math.min(K.r(3.5, 6), zb - z)
		local h = top + K.r(-0.3, 0.5)
		K.bevel(CF(s * (x1 + 1.1), h / 2 - 0.4, z + l / 2), V3(2.8, h + 0.6, l - 0.15), rockCol(), M.Slate)
		snowCap(CF(s * (x1 + 1.1), h + 0.15, z + l / 2), V3(3, 0.6, l), -s)
		if K.chance(0.3) then vein(CF(s * (x1 - 0.32), h * 0.5, z + l / 2) * ANG(K.r(-0.4, 0.4), 0, 0), h * 0.6) end
		z += l
	end
end

-- FL2 / FR4: snowman with goggles, scarf, carrot nose, stick arms, satchel
local function snowman(pos, yaw)
	local cf = CF(pos) * ANG(0, yaw, 0)
	K.ball((cf * CF(0, 2, 0)).Position, 4.2, SNOW, M.Snow)
	K.ball((cf * CF(0, 5.2, 0)).Position, 3.2, SNOW, M.Snow)
	K.ball((cf * CF(0, 7.6, 0)).Position, 2.5, SNOW, M.Snow)
	K.block(cf * CF(0, 6.5, 0), V3(2.9, 0.5, 2.9), BANNER, M.Fabric)
	K.block(cf * CF(0.9, 5.5, -1.3) * ANG(0, 0, 0.15), V3(0.6, 2, 0.3), BANNER, M.Fabric)
	K.wedge(cf * CF(0, 7.6, -1.6) * ANG(0, PI, 0), V3(0.4, 0.4, 1.4), C(255, 140, 40), M.SmoothPlastic)
	for s = -1, 1, 2 do
		K.cyl(cf * CF(s * 0.5, 8.1, -1.05) * ANG(0, PI / 2, 0), 0.25, 0.75, C(60, 50, 46), M.Metal)
		K.cyl(cf * CF(s * 0.5, 8.1, -1.12) * ANG(0, PI / 2, 0), 0.1, 0.55, C(120, 200, 240), M.Glass)
		K.block(cf * CF(s * 2.6, 5.6, 0) * ANG(0, 0, s * -0.7), V3(0.25, 3, 0.25), C(110, 76, 50), M.Wood)
	end
	K.block(cf * CF(0, 8.15, 0), V3(2.6, 0.25, 2.6), C(60, 50, 46), M.Fabric)
	K.block(cf * CF(0, 9.1, 0), V3(1.9, 0.7, 1.9), C(110, 76, 50), M.Fabric)
	for i = 0, 2 do K.ball((cf * CF(0, 4.6 + i * 0.9, -1.55)).Position, 0.35, C(50, 44, 50), M.SmoothPlastic) end
	K.block(cf * CF(-1.8, 4.6, 0.4) * ANG(0, 0, 0.2), V3(0.7, 1.6, 1.5), C(150, 100, 60), M.Fabric)
end

local function sled(pos, yaw)
	local cf = CF(pos) * ANG(0, yaw, 0)
	for s = -1, 1, 2 do
		K.block(cf * CF(0, 0.25, s * 1.2), V3(4.6, 0.3, 0.3), C(120, 82, 50), M.Wood)
		K.wedge(cf * CF(2.6, 0.6, s * 1.2) * ANG(0, -PI / 2, 0), V3(0.3, 0.8, 0.8), C(120, 82, 50), M.Wood)
	end
	K.block(cf * CF(0, 0.9, 0), V3(4, 0.4, 2.6), C(156, 108, 66), M.WoodPlanks)
	K.block(cf * CF(-0.4, 1.6, 0), V3(2.2, 1, 1.8), C(110, 70, 50), M.Fabric)
	K.lantern((cf * CF(2.8, 0, 1.6)).Position, C(60, 54, 70), C(255, 210, 150), 2.4)
end

-- FL1: natural ice-rock arch (span along Z) with snow drape, icicles and glowing ice lining
local function iceArch(pos, span, h)
	local cf = CF(pos) * ANG(0, PI / 2, 0)
	K.arch(cf, span, h, 6, rockCol(), M.Slate, GLOW, M.Neon, 9)
	local r = span / 2 + 3
	for i = 1, 9 do
		local a = (i - 0.5) / 9 * PI
		K.ellipsoid(CF(cf * V3(math.cos(a) * r, h + math.sin(a) * r + 2.2, 0)), V3(4.6, 2.2, 7.4), SNOW, M.Snow)
	end
	icicles(cf * CF(0, h + r - 3.6, -3.2), span * 0.7, 9, 3.5)
	icicles(cf * CF(0, h + r - 3.6, 3.2), span * 0.7, 7, 3)
	for s = -1, 1, 2 do
		K.crystalCluster(pos + V3(3, 0, s * (span / 2 + 5)), 0.9, { GLOW, ICE }, 0)
		K.ellipsoid(CF(pos + V3(0, 0.6, s * (span / 2 + 3))), V3(8, 2.4, 7), SNOW, M.Snow)
	end
end

-- FL2: ice cave in a rock outcrop
local function cave(pos)
	K.bevel(CF(pos + V3(-9, 9, 0)), V3(20, 18, 28), rockCol(), M.Slate)
	snowCap(CF(pos + V3(-9, 18.3, 0)), V3(21, 1, 29), 1)
	K.arch(CF(pos + V3(1.2, 0, 0)) * ANG(0, PI / 2, 0), 9, 6, 3, ROCK_D, M.Slate, GLOW, M.Neon, 7)
	K.block(CF(pos + V3(0.4, 5.5, 0)), V3(0.4, 11, 9), C(24, 40, 80), M.SmoothPlastic)
	local core = K.crystalCluster(pos + V3(-0.5, 0.4, -1), 1.5, { GLOW, C(170, 240, 255) }, 0)
	K.lamp(core, GLOW, 26, 1.6)
	K.crystalCluster(pos + V3(-0.5, 0.4, 2.5), 0.9, { GLOW, ICE }, nil)
	icicles(CF(pos + V3(2.6, 11.4, 0)) * ANG(0, PI / 2, 0), 11, 8, 2.5)
	snowman(pos + V3(9, 0, 9), PI / 2 + 0.4)
	sled(pos + V3(10, 0, -7), PI / 2 - 0.3)
	for _ = 1, 3 do K.crystal(pos + V3(K.r(4, 8), 0, K.r(-14, -10)), K.r(2.5, 4), 1, GLOW, ANG(0, 0, K.r(-0.4, 0.4))) end
end

-- FR1: crystal-tipped turret (square shaft, snow ledge, crenels, glowing window, tall glass spire)
local function turret(pos, w, h, spire)
	K.bevel(CF(pos + V3(0, h / 2, 0)), V3(w, h, w), ICE, M.Ice)
	K.block(CF(pos + V3(0, h * 0.35, 0)), V3(w + 0.6, 1, w + 0.6), ICE_D, M.Ice)
	K.block(CF(pos + V3(0, h + 0.5, 0)), V3(w + 1.6, 1, w + 1.6), SNOW, M.Snow)
	for i = 0, 3 do
		K.block(CF(pos + V3(0, h + 1.6, 0)) * ANG(0, i * PI / 2, 0) * CF(0, 0, -(w / 2 + 0.3)), V3(w * 0.3, 1.4, 0.8), ICE, M.Ice)
	end
	K.cone(pos + V3(0, h + 1, 0), w * 0.55, spire or w * 2.6, 6, C(150, 212, 252), C(116, 186, 240), M.Glass)
	local win = K.block(CF(pos + V3(-w / 2 - 0.05, h * 0.62, 0)), V3(0.2, h * 0.24, w * 0.28), GLOW, M.Neon, false, 0.15)
	K.tag(win, "TPFC_Glint", { Period = K.r(8, 14) })
	K.wedge(CF(pos + V3(-w / 2 - 0.05, h * 0.62 + h * 0.15, 0)) * ANG(0, PI / 2, 0), V3(w * 0.28, h * 0.08, 0.2), GLOW, M.Neon)
end

local function snowflake(cf, s)
	for i = 0, 2 do
		K.block(cf * ANG(0, 0, i * PI / 3), V3(0.3, 5 * s, 0.6), C(226, 248, 255), M.Neon)
		for k = -1, 1, 2 do
			K.block(cf * ANG(0, 0, i * PI / 3) * CF(0, k * 1.6 * s, 0) * ANG(0, 0, 0.8), V3(0.25, 1.4 * s, 0.5), C(226, 248, 255), M.Neon)
			K.block(cf * ANG(0, 0, i * PI / 3) * CF(0, k * 1.6 * s, 0) * ANG(0, 0, -0.8), V3(0.25, 1.4 * s, 0.5), C(226, 248, 255), M.Neon)
		end
	end
end

local function citadel(c)
	-- cliff plateau tiers with snow drapes, veins and icicles
	K.bevel(CF(c.X, -1, c.Z), V3(76, 10, 160), rockCol(), M.Slate)
	snowCap(CF(c.X, 4.3, c.Z), V3(76, 0.8, 160), -1)
	K.addSurface(c.X - 38, c.X + 38, c.Z - 80, c.Z + 80, 4.7)
	K.bevel(CF(c.X + 14, 5, c.Z), V3(48, 14, 120), rockCol(), M.Slate)
	snowCap(CF(c.X + 14, 12.4, c.Z), V3(48, 0.8, 120), -1)
	K.addSurface(c.X - 10, c.X + 38, c.Z - 60, c.Z + 60, 12.8)
	for _, z in ipairs({ -36, 36 }) do icicles(CF(c.X - 10.2, 11.9, c.Z + z) * ANG(0, PI / 2, 0), 40, 12, 3.5) end
	for _ = 1, 10 do vein(CF(c.X - 10.2, K.r(5, 10), c.Z + K.r(-55, 55)) * ANG(K.r(-0.6, 0.6), 0, 0), K.r(3, 6)) end
	-- FR2 grand stairs with ice balustrades
	K.stairs(CF(c.X - 15, 4.7, c.Z) * ANG(0, -PI / 2, 0), 14, 7, 1.15, 1.4, SNOW, M.Snow)
	for s = -1, 1, 2 do
		K.block(CF(c.X - 15, 8, c.Z + s * 7.6), V3(10, 7, 1.2), ICE, M.Ice, true)
		for k = 0, 3 do K.cone(V3(c.X - 19.5 + k * 3, 4.7 + k * 2.3 + 3.5, c.Z + s * 7.6), 0.6, 1.6, 5, GLOW, ICE, M.Glass) end
	end
	-- keep: hall, gable, pointed glowing gate, big snowflake, banners
	local kx = c.X + 18
	K.bevel(CF(kx, 12.8 + 12, c.Z), V3(24, 24, 36), ICE, M.Ice)
	K.block(CF(kx, 12.8 + 24.4, c.Z), V3(25.6, 0.8, 37.6), SNOW, M.Snow)
	K.gable(CF(kx, 12.8 + 24.8, c.Z) * ANG(0, PI / 2, 0), 24, 10, 36, C(170, 218, 250), M.Glass)
	K.pointedArch(CF(kx - 12.2, 12.8, c.Z) * ANG(0, PI / 2, 0), 9, 10, 6, 1.6, SNOW, M.Snow, GLOW)
	local door = K.block(CF(kx - 12.1, 12.8 + 7.5, c.Z), V3(0.3, 14, 8.6), C(80, 170, 240), M.Neon, false, 0.35)
	K.lamp(door, GLOW, 32, 1.5)
	K.tag(door, "TPFC_Pulse", { Period = 7, Base = 0.35, Peak = 0.15 })
	snowflake(CF(kx - 12.4, 12.8 + 20.5, c.Z) * ANG(0, PI / 2, 0), 1.2)
	for s = -1, 1, 2 do
		local b = K.block(CF(kx - 12.4, 12.8 + 13, c.Z + s * 10), V3(0.3, 11, 4), BANNER, M.Fabric)
		K.tag(b, "TPFC_Sway", { Amp = 0.02, Period = 6 })
		snowflake(CF(kx - 12.6, 12.8 + 14, c.Z + s * 10) * ANG(0, PI / 2, 0), 0.35)
		K.wedge(CF(kx - 12.4, 12.8 + 7, c.Z + s * 10 - 1) * ANG(PI, 0, 0), V3(0.3, 1, 2), BANNER, M.Fabric)
		K.wedge(CF(kx - 12.4, 12.8 + 7, c.Z + s * 10 + 1) * ANG(PI, PI, 0), V3(0.3, 1, 2), BANNER, M.Fabric)
	end
	-- turrets: very tall central crystal spire + ring of spiked turrets + crenellated walls
	turret(V3(kx + 6, 12.8, c.Z), 11, 40, 34)
	for _, t in ipairs({ { -8, -22, 7, 26 }, { -8, 22, 7, 26 }, { 14, -36, 8, 30 }, { 14, 36, 8, 30 }, { 2, -14, 5, 34 }, { 2, 14, 5, 34 }, { 24, -20, 6, 22 }, { 24, 20, 6, 22 } }) do
		turret(V3(kx + t[1], 12.8, c.Z + t[2]), t[3], t[4])
	end
	for _, z in ipairs({ -44, 44 }) do
		K.bevel(CF(kx - 9, 12.8 + 4.5, c.Z + z), V3(3, 9, 30), ICE_D, M.Ice)
		K.block(CF(kx - 9, 12.8 + 9.3, c.Z + z), V3(3.6, 0.6, 30.4), SNOW, M.Snow)
		for dz = -13.5, 13.5, 3 do K.block(CF(kx - 9, 12.8 + 10.3, c.Z + z + dz), V3(3, 1.4, 1.5), ICE_D, M.Ice) end
	end
	-- FR3 big frozen waterfall from tier B into an ice-floe pool on tier A
	local fz = c.Z + 52
	for i = 0, 3 do
		local seg = K.block(CF(c.X - 10.8, 12.4 - i * 2 - 1, fz + K.r(-0.5, 0.5)), V3(1, 2.2, 14 - i), i % 2 == 0 and C(150, 228, 250) or GLOW, M.Glass, false, 0.1)
		K.tag(seg, "TPFC_Glint", { Period = K.r(6, 10) })
	end
	icicles(CF(c.X - 11.4, 4.8, fz) * ANG(0, PI / 2, 0), 14, 6, 2)
	K.block(CF(c.X - 19, 4.6, fz), V3(16, 0.4, 22), C(90, 176, 226), M.Glass, false, 0.15)
	for _ = 1, 7 do hex(V3(c.X - 19 + K.r(-6, 6), 4.85, fz + K.r(-9, 9)), K.r(1.2, 2.4), SNOW, M.Snow) end
end

function B.Build(b)
	K.Seed(3003)
	K.ResetSurfaces()
	K.mirror = true
	local z1, z2 = b[1], b[2]
	---------------------------------------------------------------- terraces (blue rock, draping snow, veins)
	K.terraces(z1, z2, {
		rock = ROCK, rockMat = M.Slate, cap = SNOW, capMat = M.Snow, drip = true, tiers = 3,
		h1 = { 2.2, 4 }, h2 = { 6, 11 }, h3 = { 10, 20 },
		skip = { { 1, 392, 560 } },
		facade = facade,
	})
	---------------------------------------------------------------- RIGHT: citadel + stairs + frozen waterfall
	citadel(V3(86, 0, 476))
	snowman(V3(50, 0, 368), -PI / 2 + 0.5)
	for _ = 1, 4 do K.crystalCluster(V3(K.r(44, 50), 0, K.r(370, 390)), K.r(0.6, 0.9), { GLOW, ICE }, nil) end
	---------------------------------------------------------------- LEFT: ice arches, cave + vignette, frozen fall + pond, stairs
	iceArch(K.at(-62, 396), 16, 9)
	iceArch(K.at(-86, 452), 20, 12)
	cave(K.at(-62, 566))
	local pond = K.at(-58, 492)
	K.block(CF(pond + V3(0, 0.15, 0)), V3(14, 0.3, 22), C(100, 184, 228), M.Glass, false, 0.15)
	for _ = 1, 5 do hex(pond + V3(K.r(-4, 4), 0.36, K.r(-8, 8)), K.r(1, 1.8), SNOW, M.Snow) end
	for i = 0, 2 do
		local seg = K.block(CF(pond + V3(-8.2, 2 + i * 1.6, 0)), V3(0.8, 1.8, 8 - i * 1.5), i % 2 == 0 and C(160, 230, 250) or GLOW, M.Glass, false, 0.1)
		K.tag(seg, "TPFC_Glint", { Period = K.r(7, 12) })
	end
	K.stairs(CF(K.at(-52, 430)) * ANG(0, PI / 2, 0), 8, 4, 1, 1.4, SNOW, M.Snow)
	---------------------------------------------------------------- pines + crystals + snow mounds on terrace tops within view
	for _, r in ipairs(K.surfaces) do
		local xa, xb = math.max(r[1], -96), math.min(r[2], 96)
		if xb - xa > 3 then
			local n = math.floor((xb - xa) * (r[4] - r[3]) / 180)
			for _ = 1, n do
				local x, z = K.r(xa + 2, xb - 2), K.r(r[3] + 2, r[4] - 2)
				local onCitadel = x > 40 and z > 392 and z < 560 and r[5] > 4
				if math.abs(x) >= 48 and not onCitadel then
					local p = V3(x, r[5], z)
					local q = K.r(0, 1)
					if q < 0.4 then K.pine(p, K.r(1.2, 1.9), PINE, true)
					elseif q < 0.8 then K.crystalCluster(p, K.r(0.6, 1), { GLOW, ICE, C(170, 236, 255) }, nil)
					else K.ellipsoid(CF(p + V3(0, 0.6, 0)), V3(K.r(4, 7), K.r(1.6, 2.6), K.r(4, 7)), SNOW, M.Snow) end
				end
			end
		end
	end
	for _ = 1, 6 do K.pine(V3(K.r(52, 70), 4.7, K.r(400, 556)), K.r(1, 1.4), PINE, true) end
	---------------------------------------------------------------- CENTRE: honeycomb of hexagonal ice tiles + edge drifts
	local rH = 3.6
	for row = 0, math.floor((z2 - z1 - 8) / (rH * 1.5)) do
		local z = z1 + 6 + row * rH * 1.5
		local off = (row % 2) * rH * 0.866
		for x = -27 + off, 27, rH * 1.732 do
			if K.chance(0.55) then hex(V3(x, 0.08, z), rH * 0.92, ICE:Lerp(SNOW, K.r(0.2, 0.6)), M.SmoothPlastic) end
		end
	end
	for s = -1, 1, 2 do
		for z = z1 + 6, z2 - 6, 9 do
			K.ellipsoid(CF(s * K.r(36, 42), 0.4, z + K.r(-3, 3)), V3(K.r(5, 9), K.r(1.2, 2.2), K.r(6, 10)), SNOW, M.Snow)
			if K.chance(0.35) then K.crystal(V3(s * K.r(38, 43), 0, z), K.r(1.6, 2.6), 0.7, GLOW, ANG(0, K.r(0, PI), s * 0.4)) end
		end
	end
	---------------------------------------------------------------- aurora ribbons on the far skyline
	for i = 0, 2 do
		for k = 0, 9 do
			local seg = K.block(CF(-150 + k * 32, 150 + i * 14 + math.sin(k * 0.8 + i) * 10, 720 + i * 30) * ANG(0, 0, math.sin(k * 0.9 + i) * 0.25),
				V3(34, 18, 1), (i == 1) and C(120, 255, 200) or C(90, 230, 255), M.Neon, false, 0.72)
			seg.CastShadow = false
			K.tag(seg, "TPFC_Pulse", { Period = 10 + i * 3, Base = 0.78, Peak = 0.6 })
		end
	end
	---------------------------------------------------------------- transition to Crystal: blue mineral veins in deeper rock
	for s = -1, 1, 2 do
		for _ = 1, 3 do
			local p = V3(s * K.r(46, 60), 0, K.r(584, 598))
			K.rockMass(p, K.r(4, 7), K.r(4, 8), K.r(4, 7), C(70, 64, 110), M.Slate, 2)
			K.crystal(p + V3(0, 1, 0), K.r(3, 5), 1, C(150, 120, 255), ANG(0, 0, s * 0.3))
		end
	end
	K.mountains(z1, z2, M.Glacier, 170, 230, 50, 110)
	K.mirror = false
end

return B
