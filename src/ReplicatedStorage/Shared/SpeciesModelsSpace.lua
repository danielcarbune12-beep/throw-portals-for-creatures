-- SpeciesModelsSpace: hand-authored, reference-faithful models for the Space world
-- (Astro Blob, Moon Mouse, Comet Fish, Nebula Jelly, Star Whale, Nova Phoenix, Cosmic Dragon, Singularity Cat).
-- Location: ReplicatedStorage > Shared > SpeciesModelsSpace (ModuleScript), merged into SpeciesModels.

local K = require(script.Parent.ModelKit)
local V3, CF, ANG, PI, MAT, C = K.V3, K.CF, K.ANG, K.PI, K.MAT, K.C
local FACE, DOWN = ANG(0, PI / 2, 0), ANG(0, 0, PI)
local FLAT = ANG(PI / 2, 0, 0)
local SIDES = { -1, 1 }

local M = {}

local function line(k, parent, A, B, w, col, up)
	local _, p = k.bar(parent, "GlowLine", A, B, w, col, MAT.Neon, nil, up, w * 0.6)
	k.glow(p, col)
end

-- small four-point star facing -Z on `parent`: two thin crossed bars and a turned square centre (3 parts)
local function star(k, parent, cf, size, col, mat)
	k.b(parent, "Star", size * 0.16, size, 0.06, col, cf, mat)
	k.b(parent, "Star", size, size * 0.16, 0.06, col, cf, mat)
	k.b(parent, "StarCore", size * 0.32, size * 0.32, 0.07, col, cf * ANG(0, 0, PI / 4), mat)
end

---------------------------------------------------------------- ASTRO BLOB (Common)
-- Little TV-head robot pup: mint block body on four stubby legs with dark-green feet, a dark collar
-- with a pale square button, a pale CRT head with a dark screen showing two glowing mint eyes, pale
-- side knobs, and two segmented antennae ending in mint cubes.
function M.AstroBlob(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local M1, MD, W, WD, DK, EY = C("#7FE3B8"), C("#64CDA0"), C("#DFF3EA"), C("#C8E6D8"), C("#2F6E52"), C("#5FF0D0")
	local BY = 1.45
	local body = k.body(1.5, 1.15, 1.7, M1, BY)
	k.b(body, "BackPanel", 1.1, 0.12, 1.1, MD, c(0, 0.6, 0.25))
	for _, sd in ipairs(SIDES) do k.b(body, "SidePanel", 0.08, 0.6, 1.0, MD, c(sd * 0.76, 0.0, 0.2)) end
	local lg = { up = { 0.55, 0.45, 0.6 }, col = M1, w2 = 0.5, d2 = 0.56, col2 = MD, paw = { 0.62, 0.3, 0.7 }, pawCol = DK }
	k.leg(body, "LegFL", BY, -0.45, -0.45, -0.55, lg)
	k.leg(body, "LegFR", BY, 0.45, -0.45, -0.55, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.45, -0.45, 0.55, lg)
	k.leg(body, "LegBR", BY, 0.45, -0.45, 0.55, lg)
	rig.legKind = "quad"
	k.b(body, "Collar", 1.4, 0.3, 0.6, DK, c(0, 0.5, -0.65))
	k.b(body, "CollarButton", 0.3, 0.28, 0.08, W, c(0, 0.45, -0.98))

	local head = k.head(body, 1.45, 1.15, 1.0, W, c(0, 1.2, -0.7), V3(0, -0.45, 0.25))
	k.b(head, "Bezel", 1.25, 0.95, 0.06, WD, c(0, 0, -0.52))
	k.b(head, "Screen", 1.05, 0.75, 0.08, DK, c(0, 0, -0.55))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.25, 0.02, -0.6, 0.3, 0.16, EY, 0)
		k.b(head, "EarKnob", 0.2, 0.5, 0.5, W, c(sd * 0.82, 0.05, 0))
		local ant = k.ear(head, sd, c(sd * 0.3, 0.58, 0.1), "antenna")
		k.b(ant, "AntennaBase", 0.22, 0.2, 0.22, DK, c(0, 0.1, 0))
		local p1, p2, p3 = V3(0, 0.15, 0), V3(sd * 0.25, 0.65, 0), V3(sd * 0.45, 1.05, -0.05)
		k.bar(ant, "Antenna", p1, p2, 0.16, M1, nil, nil, V3(0, 0, 1))
		k.b(ant, "AntennaJoint", 0.2, 0.2, 0.2, DK, c(p2.X, p2.Y, p2.Z))
		k.bar(ant, "Antenna", p2, p3, 0.15, M1, nil, nil, V3(0, 0, 1))
		k.b(ant, "AntennaTip", 0.3, 0.3, 0.3, M1, c(p3.X, p3.Y + 0.1, p3.Z) * ANG(0.3, 0.4, 0))
	end
end

---------------------------------------------------------------- MOON MOUSE (Uncommon)
-- Astronaut mouse: grey body in a white harness with pink straps and a belt buckle carrying a pink
-- crescent moon, a white backpack, grey legs with white boots, a grey head with white muzzle, pink nose
-- and pink eyes inside a faceted glass helmet, huge round ears (pink and white insides), and a thin
-- segmented tail curling up to a pink-and-white tip.
function M.MoonMouse(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local G, GD, W, WD, P, GL, EY = C("#B8B4C8"), C("#9E9AB2"), C("#F2F2F6"), C("#DCDCE4"), C("#F282B8"), C("#DDE8F5"), C("#FF6FB0")
	local BY = 1.45
	local body = k.body(1.35, 1.1, 1.6, G, BY)
	k.b(body, "Collar", 1.45, 0.3, 0.5, W, c(0, 0.45, -0.6))
	k.b(body, "Belt", 1.0, 0.4, 0.12, W, c(0, -0.05, -0.83))
	k.b(body, "Buckle", 0.5, 0.32, 0.06, GD, c(0, -0.05, -0.9))
	k.b(body, "Moon", 0.12, 0.22, 0.04, P, c(-0.04, -0.05, -0.94))
	k.b(body, "MoonTip", 0.08, 0.08, 0.04, P, c(0.04, 0.06, -0.94))
	k.b(body, "MoonTip", 0.08, 0.08, 0.04, P, c(0.04, -0.16, -0.94))
	for _, sd in ipairs(SIDES) do
		k.b(body, "Strap", 0.08, 1.15, 0.25, P, c(sd * 0.69, 0, -0.1) * ANG(0.35, 0, 0))
		k.b(body, "StrapBuckle", 0.1, 0.25, 0.32, W, c(sd * 0.71, -0.15, -0.05))
	end
	local _, pack = k.b(body, "Backpack", 1.0, 0.45, 0.9, W, c(0, 0.75, 0.25))
	k.b(pack, "PackStripe", 1.02, 0.08, 0.2, P, c(0, 0.24, 0.2))
	local lg = { up = { 0.5, 0.45, 0.55 }, col = G, w2 = 0.44, d2 = 0.5, paw = { 0.58, 0.32, 0.7 }, pawCol = W }
	k.leg(body, "LegFL", BY, -0.42, -0.45, -0.5, lg)
	k.leg(body, "LegFR", BY, 0.42, -0.45, -0.5, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.42, -0.45, 0.5, lg)
	k.leg(body, "LegBR", BY, 0.42, -0.45, 0.5, lg)
	rig.legKind = "quad"

	local head = k.head(body, 0.95, 0.85, 0.85, G, c(0, 1.15, -0.75), V3(0, -0.4, 0.25))
	k.b(head, "Muzzle", 0.55, 0.32, 0.25, W, c(0, -0.25, -0.5))
	k.b(head, "Nose", 0.18, 0.12, 0.08, P, c(0, -0.15, -0.66))
	for _, sd in ipairs(SIDES) do k.eye(head, sd * 0.22, 0.08, -0.44, 0.16, 0.18, EY, 0) end
	-- faceted glass helmet (two crossed boxes read as an octagon)
	k.b(head, "Helmet", 1.3, 1.2, 1.25, GL, c(0, 0.05, -0.05), MAT.Glass, 0.65)
	k.b(head, "Helmet", 1.1, 1.3, 1.1, GL, c(0, 0.05, -0.05) * ANG(0, PI / 4, 0), MAT.Glass, 0.7)
	for _, sd in ipairs(SIDES) do
		local ear = k.ear(head, sd, c(sd * 0.55, 0.55, 0.15) * ANG(0, 0, -sd * 0.25), "round")
		-- round-ish octagonal ear: two crossed rectangles
		k.b(ear, "Ear", 1.0, 0.7, 0.18, G, c(0, 0.5, 0))
		k.b(ear, "Ear", 0.7, 1.0, 0.18, G, c(0, 0.5, 0))
		k.b(ear, "EarPink", 0.6, 0.35, 0.06, P, c(0, 0.68, -0.1))
		k.b(ear, "EarWhite", 0.6, 0.3, 0.06, W, c(0, 0.36, -0.1))
	end

	local tip = k.tail(body, c(0, 0.2, 0.85), {
		{ 0.16, 0.16, 0.35, -0.5, G }, { 0.16, 0.16, 0.35, -0.35, G }, { 0.15, 0.15, 0.35, -0.4, G }, { 0.15, 0.15, 0.32, 0.2, G }, { 0.14, 0.14, 0.3, -0.3, G } })
	k.b(tip, "TailTip", 0.4, 0.28, 0.4, W, c(0, 0, 0.3))
	k.b(tip, "TailTipPink", 0.42, 0.12, 0.42, P, c(0, 0.18, 0.3))
end

---------------------------------------------------------------- COMET FISH (Rare)
-- Space shark: blue angular body with a white underside, a pointed snout with glowing yellow eyes,
-- white gill slits, a tall dorsal fin with white and yellow insets, white pectoral fins with yellow
-- stripes, a small ventral fin, and a segmented tail ending in a forked yellow lightning-bolt fin.
function M.CometFish(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local B, BD, W, Y, EY = C("#4AA8E8"), C("#3A8AD0"), C("#F2F4F6"), C("#FFD83A"), C("#FFD83A")
	local BY = 1.5
	local body = k.body(1.15, 1.0, 1.7, B, BY)
	rig.legKind = "none"
	k.b(body, "Belly", 1.0, 0.35, 1.6, W, c(0, -0.4, 0))
	k.b(body, "BackRidge", 0.7, 0.2, 1.4, BD, c(0, 0.55, 0.1))
	for _, sd in ipairs(SIDES) do
		for g = 0, 2 do k.b(body, "Gill", 0.06, 0.4, 0.08, W, c(sd * 0.58, -0.02, -0.35 + g * 0.16)) end
	end
	local head = k.head(body, 1.05, 0.85, 0.9, B, c(0, 0.05, -1.2), V3(0, 0, 0.4))
	k.w(head, "Snout", 0.95, 0.55, 0.65, B, c(0, 0.08, -0.75))
	k.w(head, "Jaw", 0.9, 0.35, 0.9, W, c(0, -0.32, -0.55) * DOWN)
	k.b(head, "Brow", 1.0, 0.18, 0.5, BD, c(0, 0.38, -0.2))
	for _, sd in ipairs(SIDES) do k.eye(head, sd * 0.38, 0.1, -0.46, 0.26, 0.1, EY, sd * 0.3) end
	local _, fin = k.pv(body, "Dorsal", c(0, 0.6, 0.0))
	k.tri(fin, "DorsalFin", 0.18, 1.2, 1.1, B, c(0, 0.55, 0.15) * ANG(0.45, 0, 0))
	k.tri(fin, "DorsalInset", 0.2, 0.8, 0.45, W, c(0, 0.45, 0.42) * ANG(0.45, 0, 0))
	k.tri(fin, "DorsalStripe", 0.21, 0.6, 0.18, Y, c(0, 0.4, 0.5) * ANG(0.45, 0, 0))
	k.tri(body, "VentralFin", 0.14, 0.5, 0.45, B, c(0, -0.7, -0.35) * DOWN * ANG(0.5, 0, 0))
	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.5, -0.3, -0.35) * ANG(0, -sd * 0.5, 0))
		k.bar(w, "Pectoral", V3(0, 0, 0), V3(sd * 1.3, -0.7, 0), 0.5, W, nil, nil, nil, 0.12)
		k.bar(w, "PectoralStripe", V3(sd * 0.2, -0.05, -0.08), V3(sd * 1.1, -0.55, -0.08), 0.14, Y, nil, nil, nil, 0.06)
	end
	local segs = {}
	for j = 1, 4 do
		local w = 0.75 - j * 0.1
		table.insert(segs, { w, w * 0.9, 0.55, (j % 2 == 0) and BD or B, (j == 1) and -0.05 or 0.02 })
	end
	local rec = k.chain(body, c(0, 0.05, 0.8), segs, { name = "Tail", kind = "spine", i = 1, amp = 0.3, freq = 2.0, lag = 0.6 })
	for j, p in ipairs(rec.parts) do
		local w = 0.75 - j * 0.1
		k.b(p, "TailBelly", w * 0.8, 0.12, 0.5, Y, c(0, -w * 0.42, 0))
		if j == 2 then k.tri(p, "TailFinlet", 0.12, 0.45, 0.35, B, c(0, w * 0.45 + 0.2, 0) * ANG(0.5, 0, 0)) end
	end
	-- forked lightning fin: two zigzag prongs
	local last = rec.parts[#rec.parts]
	for _, sd in ipairs({ -1, 1 }) do
		local _, pr = k.pv(last, "Prong", c(0, 0, 0.25) * ANG(-sd * 0.55, 0, 0))
		k.b(pr, "Bolt", 0.14, 0.3, 0.7, Y, c(0, 0, 0.35))
		k.b(pr, "Bolt", 0.14, 0.3, 0.6, Y, c(0, sd * 0.25, 0.75) * ANG(sd * 0.6, 0, 0))
		k.w(pr, "BoltTip", 0.14, 0.3, 0.55, Y, c(0, sd * 0.2, 1.25) * ANG(0, PI, 0))
	end
	k.w(last, "BoltCenter", 0.14, 0.3, 0.9, Y, c(0, 0, 0.75) * ANG(0, PI, 0))
end

---------------------------------------------------------------- NEBULA JELLY (Epic)
-- Space jellyfish: a stepped purple bell with angled purple fins traced by glowing cyan slots, a dark
-- visor with glowing cyan eyes, a skirt of eight pink plates with cyan slots, a glowing pink core below,
-- and eight segmented purple tentacles with cyan lights and pink spike tips.
function M.NebulaJelly(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUD, PUL, PK, CY, CORE = C("#9A4AE0"), C("#7A34C0"), C("#B068F0"), C("#F07AC8"), C("#5FE8F5"), C("#FF5AD0")
	local BY = 2.6
	local body = k.body(2.2, 0.9, 2.0, PU, BY)
	rig.legKind = "none"
	k.b(body, "BellMid", 1.7, 0.5, 1.6, PUL, c(0, 0.6, 0))
	k.b(body, "BellTop", 1.0, 0.4, 1.0, PU, c(0, 1.0, 0.05))
	local _, slot = k.b(body, "TopSlot", 0.3, 0.42, 0.6, CY, c(0, 1.02, -0.1), MAT.Neon)
	k.glow(slot, CY)
	k.b(body, "Visor", 1.3, 0.32, 0.06, C("#2A1240"), c(0, 0.15, -1.02))
	for _, sd in ipairs(SIDES) do
		k.eye(body, sd * 0.3, 0.15, -1.06, 0.3, 0.1, CY, -sd * 0.25)
		local _, f = k.pv(body, "Fin", c(sd * 0.95, 0.65, 0.0) * ANG(0, 0, -sd * 0.6))
		k.tri(f, "FinBlade", 0.2, 1.2, 0.9, PU, c(0, 0.55, 0) * FACE)
		line(k, f, V3(-sd * 0.0, 0.25, -0.12), V3(-sd * 0.0, 0.85, -0.12), 0.12, CY)
		k.tri(body, "Horn", 0.16, 0.6, 0.4, PK, c(sd * 0.45, 1.15, -0.2) * ANG(0, 0, -sd * 0.4) * FACE)
	end
	-- pink skirt plates with cyan slots (open on the power move)
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * PI * 2
		local d = V3(math.sin(a), 0, -math.cos(a))
		local pos = V3(0, -0.35, 0) + d * 0.95
		local pl = k.opener(body, "Plate", CFrame.lookAt(pos * s, (pos + d) * s), V3(1, 0, 0), -0.4)
		-- hanging panel facing outward, bottom edge flared out
		local _, plate = k.b(pl, "SkirtPlate", 0.85, 0.65, 0.16, PK, ANG(0.4, 0, 0) * c(0, -0.28, 0))
		local _, sl = k.b(plate, "PlateSlot", 0.5, 0.1, 0.06, CY, c(0, -0.1, -0.1), MAT.Neon)
		k.glow(sl, CY)
	end
	local _, core = k.b(body, "Core", 0.85, 0.55, 0.85, CORE, c(0, -0.7, -0.1), MAT.Neon)
	k.glow(core, CORE)
	k.b(body, "CoreTip", 0.45, 0.35, 0.45, CORE, c(0, -1.1, -0.1), MAT.Neon)
	-- eight tentacles (trail chains)
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * PI * 2
		local d = V3(math.sin(a), 0, -math.cos(a))
		local pos = V3(0, -0.5, 0) + d * 0.6
		local base = CFrame.lookAt(pos * s, (pos - d) * s) * ANG(1.25, 0, 0)
		local segs = {}
		for j = 1, 5 do table.insert(segs, { 0.24, 0.24, 0.42, (j % 2 == 0) and PUD or PU, (j == 1) and 0 or -0.06 }) end
		local rec = k.chain(body, base, segs, { name = "Tentacle", kind = "trail", i = i + 1, amp = 0.15, freq = 1.4, lag = 0.5 })
		for j, p in ipairs(rec.parts) do
			if j % 2 == 1 then
				local _, l = k.b(p, "TentacleLight", 0.08, 0.1, 0.22, CY, c(0, 0, 0) * CF(0.13 * s, 0, 0), MAT.Neon)
				k.glow(l, CY)
			end
		end
		k.spike(rec.parts[#rec.parts], "TentacleTip", 0.5, 0.28, PK, c(0, 0, 0.2) * ANG(PI / 2, 0, 0))
	end
end

---------------------------------------------------------------- STAR WHALE (Legendary)
-- Cosmic whale: navy body with a ridged light-blue belly, a gold stripe along each side, gold four-point
-- stars, a glowing yellow eye, big navy pectoral fins with light-blue edges and gold stars, a small dorsal
-- fin, a tail with horizontal flukes, and a tilted gold ring with square star gems orbiting the body.
function M.StarWhale(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local DB, DBL, LB, LBD, GO, EY = C("#2A3A9A"), C("#34479F"), C("#A8C8F0"), C("#8FB4E4"), C("#F2C230"), C("#FFE45C")
	local BY = 2.0
	local body = k.body(2.0, 1.6, 3.0, DB, BY)
	rig.legKind = "none"
	for i = 0, 5 do
		-- ridged light-blue belly filling the lower half and bulging below the navy back
		k.b(body, "BellyRidge", 2.1 - math.abs(i - 2.5) * 0.12, 0.85, 0.44, (i % 2 == 0) and LB or LBD, c(0, -0.62, -1.2 + i * 0.48))
		k.b(body, "BellyKeel", 1.5 - math.abs(i - 2.5) * 0.15, 0.25, 0.4, (i % 2 == 0) and LBD or LB, c(0, -1.1, -1.2 + i * 0.48))
	end
	k.b(body, "Head", 2.05, 1.2, 1.0, DBL, c(0, 0.15, -1.6))
	k.w(body, "Brow", 2.05, 0.35, 0.7, DB, c(0, 0.85, -1.55))
	for _, sd in ipairs(SIDES) do
		k.b(body, "GoldStripe", 0.06, 0.1, 3.2, GO, c(sd * 1.03, 0.0, -0.2))
		k.eye(body, sd * 1.04, 0.25, -1.4, 0.06, 0.12, EY, 0)
		local _, e = k.b(body, "EyeSide", 0.08, 0.14, 0.28, EY, c(sd * 1.04, 0.25, -1.4), MAT.Neon)
		k.glow(e, EY)
		for i, d in ipairs({ { 0.35, -0.3, 0.45 }, { 0.3, 0.6, 0.35 }, { 0.45, 1.1, 0.3 } }) do
			star(k, body, c(sd * 1.03, d[1], d[2]) * ANG(0, -sd * PI / 2, 0), d[3], GO)
		end
	end
	k.tri(body, "Dorsal", 0.16, 0.5, 0.6, DB, c(0, 0.95, 0.6) * ANG(0.5, 0, 0))

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.95, -0.35, -0.5) * ANG(0, -sd * 0.55, 0))
		k.bar(w, "Flipper", V3(0, 0, 0), V3(sd * 2.2, -0.9, 0), 0.9, DB, nil, nil, nil, 0.16)
		k.bar(w, "FlipperEdge", V3(sd * 0.2, -0.4, 0.02), V3(sd * 2.2, -1.25, 0.02), 0.3, LB, nil, nil, nil, 0.14)
		k.bar(w, "FlipperGold", V3(sd * 0.2, 0.3, -0.02), V3(sd * 2.0, -0.55, -0.02), 0.08, GO, nil, nil, nil, 0.18)
		star(k, w, c(sd * 1.3, -0.5, -0.1), 0.4, GO)
	end

	local segs = {}
	for j = 1, 4 do
		local w = 1.5 - j * 0.25
		table.insert(segs, { w, w * 0.8, 0.75, (j % 2 == 0) and DBL or DB, (j == 1) and -0.1 or -0.12 })
	end
	local rec = k.chain(body, c(0, 0.15, 1.45), segs, { name = "Tail", kind = "fluke", i = 1, amp = 0.15, freq = 1.0, lag = 0.6 })
	for j, p in ipairs(rec.parts) do
		local w = 1.5 - j * 0.25
		k.b(p, "TailBelly", w * 0.85, 0.12, 0.7, LB, c(0, -w * 0.38, 0))
	end
	local last = rec.parts[#rec.parts]
	for _, sd in ipairs(SIDES) do
		local _, fl = k.pv(last, "Fluke", c(sd * 0.2, 0, 0.3) * ANG(0, -sd * 0.5, 0))
		k.b(fl, "FlukePlate", 1.6, 0.14, 0.75, DB, c(sd * 0.75, 0, 0.2))
		k.b(fl, "FlukeEdge", 1.5, 0.15, 0.2, LB, c(sd * 0.75, 0, 0.6))
		k.b(fl, "FlukeGold", 1.3, 0.16, 0.06, GO, c(sd * 0.7, 0, 0.0))
	end

	local re, rp = k.pv(body, "Ring", c(0, 0.1, 0.2) * ANG(0.35, 0, 0.5))
	H.group(rig, "rings", re)
	k.ring(rp, "GoldRing", FLAT, 2.0, 18, 0.18, 0.75, 0.16, GO)
	for i = 0, 2 do
		local a = i / 3 * PI * 2
		local _, g = k.b(rp, "RingGem", 0.45, 0.45, 0.45, DB, k.c(math.cos(a) * 2.0, 0, math.sin(a) * 2.0))
		k.b(g, "RingGemFrame", 0.5, 0.5, 0.2, GO, CF())
		star(k, g, c(0, 0, -0.26), 0.3, GO)
	end
end

---------------------------------------------------------------- NOVA PHOENIX (Legendary)
-- Cosmic phoenix: dark-purple armoured body with pink plates and a cyan diamond, legs with cyan lines
-- and pink talons, a purple head with a pink hooked beak and a crest of pink spikes, glowing cyan eyes,
-- a cyan-and-pink halo over the head and another around the neck, huge layered wings (purple, pink and
-- cyan blades), and zigzag pink and cyan lightning tail streamers.
function M.NovaPhoenix(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUD, PK, PKL, CY, EY = C("#3A1F6E"), C("#2A1550"), C("#F07AC8"), C("#F5A0DC"), C("#7FE8F5"), C("#7FF0FF")
	local BY = 2.85
	local body = k.body(1.15, 1.5, 1.15, PU, BY)
	k.tri(body, "ChestPlate", 0.14, 1.1, 1.1, PK, c(0, 0.15, -0.6) * DOWN * FACE)
	k.diamond(body, "ChestGem", 0.6, 0.38, 0.1, CY, c(0, 0.1, -0.68), MAT.Glass)
	for _, sd in ipairs(SIDES) do k.b(body, "SidePlate", 0.1, 0.8, 0.8, PK, c(sd * 0.6, 0.1, 0.05) * ANG(0.3, 0, 0)) end
	local lg = { up = { 0.55, 0.6, 0.65 }, col = PU, w2 = 0.32, d2 = 0.34, col2 = PUD, band = CY, paw = { 0.75, 0.22, 0.8, -0.12 }, pawCol = PK, toes = 3, toeCol = PK }
	k.leg(body, "LegL", BY, -0.33, -0.7, 0.05, lg)
	k.leg(body, "LegR", BY, 0.33, -0.7, 0.05, lg)
	rig.legKind = "biped"

	k.b(body, "Neck", 0.5, 0.8, 0.5, PU, c(0, 0.95, -0.25) * ANG(-0.25, 0, 0))
	local ne, np = k.pv(body, "NeckHalo", c(0, 0.9, -0.2) * ANG(0.35, 0, 0))
	table.insert(rig.halos, ne)
	k.ring(np, "NeckHalo", FLAT, 0.8, 12, 0.12, 0.45, 0.12, CY)
	local head = k.head(body, 0.72, 0.68, 0.85, PU, c(0, 1.6, -0.45), V3(0, -0.3, 0.2))
	k.w(head, "Beak", 0.36, 0.3, 0.5, PK, c(0, -0.08, -0.65))
	k.b(head, "BeakTip", 0.22, 0.25, 0.14, PK, c(0, -0.22, -0.86))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.22, 0.08, -0.43, 0.2, 0.1, EY, sd * 0.35)
		k.tri(head, "CheekSpike", 0.1, 0.5, 0.3, PK, c(sd * 0.38, -0.05, 0.1) * ANG(0.9, 0, -sd * 0.6))
	end
	for _, d in ipairs({ { 0, 1.0, PK }, { -0.18, 0.75, PKL }, { 0.18, 0.75, PKL }, { -0.32, 0.55, CY }, { 0.32, 0.55, CY } }) do
		k.tri(head, "Crest", 0.12, d[2], 0.4, d[3], c(d[1], 0.3 + d[2] * 0.4, 0.15) * ANG(0.6, 0, -d[1] * 1.2))
	end
	local he, hp = k.pv(head, "Halo", c(0, 0.95, 0.1))
	table.insert(rig.halos, he)
	k.ring(hp, "Halo", FLAT, 0.75, 14, 0.12, 0.38, 0.12, CY)
	for i = 0, 3 do k.b(hp, "HaloPink", 0.14, 0.14, 0.45, PK, k.c(math.cos(i * PI / 2) * 0.75, 0, math.sin(i * PI / 2) * 0.75) * ANG(0, -i * PI / 2, 0)) end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.5, 0.5, 0.2))
		k.featherWing(w, sd, { root = 0.15, z = 0.05, thick = 0.12, feathers = {
			{ 1.25, 2.5, 0.42, PU, PK }, { 1.0, 2.9, 0.45, PK, PKL }, { 0.75, 3.1, 0.45, PU, PK }, { 0.5, 2.9, 0.45, PK, PKL },
			{ 0.25, 2.5, 0.42, PU, PK }, { 0.0, 2.0, 0.4, PK, PK } } })
		k.featherWing(w, sd, { root = 0.1, z = -0.05, thick = 0.13, feathers = {
			{ 1.05, 1.6, 0.36, CY }, { 0.75, 1.7, 0.36, PUD }, { 0.45, 1.5, 0.34, CY }, { 0.15, 1.2, 0.32, PUD } } })
	end

	for i, x in ipairs({ -0.35, -0.12, 0.12, 0.35 }) do
		local segs = {}
		for j = 1, 6 do
			local col = (i % 2 == 0) and ((j % 2 == 0) and CY or PK) or ((j % 2 == 0) and PK or PKL)
			table.insert(segs, { 0.22, 0.12, 0.55, col, (j == 1) and 0.9 or -0.12, (j == 1) and x * 0.6 or ((j % 2 == 0) and 0.45 or -0.45) })
		end
		local rec = k.chain(body, c(x, -0.5, 0.45), segs, { name = "Streamer", kind = "trail", i = i, amp = 0.12, freq = 1.6, lag = 0.5 })
		k.w(rec.parts[#rec.parts], "StreamerTip", 0.22, 0.12, 0.5, (i % 2 == 0) and CY or PK, c(0, 0, 0.5) * ANG(0, PI, 0))
	end
end

---------------------------------------------------------------- COSMIC DRAGON (Mythical)
-- Constellation dragon: purple armoured body with dark plates traced by glowing star constellations,
-- a pink chevron and star on the chest, clawed legs with pink claws, a horned head with glowing eyes,
-- a pink ring with square star nodes around the neck, huge bat wings with dark bones and magenta
-- membranes carrying glowing constellations, a spiked tail with a pink ring and a star spear tip.
function M.CosmicDragon(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUD, PUL, MG, PK, NE = C("#5A2A9A"), C("#3A1A6E"), C("#7A40C0"), C("#E070E0"), C("#F07AD0"), C("#FF9AF5")
	local function constellation(parent, pts, z, side)
		for i = 1, #pts - 1 do line(k, parent, V3(pts[i][1] * (side or 1), pts[i][2], z), V3(pts[i + 1][1] * (side or 1), pts[i + 1][2], z), 0.05, NE) end
		for _, p in ipairs(pts) do
			local _, d = k.b(parent, "StarDot", 0.14, 0.14, 0.08, NE, c(p[1] * (side or 1), p[2], z), MAT.Neon)
			k.glow(d, NE)
		end
	end
	local BY = 2.4
	local body = k.body(1.9, 1.6, 2.5, PU, BY)
	k.b(body, "Chest", 1.7, 1.5, 0.85, PUD, c(0, 0.05, -1.15))
	k.tri(body, "Chevron", 0.12, 0.6, 1.1, PK, c(0, -0.35, -1.6) * DOWN * FACE)
	star(k, body, c(0, 0.25, -1.62), 0.6, NE, MAT.Neon)
	for _, sd in ipairs(SIDES) do
		k.b(body, "ConstellationPlate", 0.14, 1.0, 1.0, PUD, c(sd * 0.98, 0.1, 0.1) * ANG(PI / 4, 0, 0))
		for _, seg in ipairs({ { V3(sd * 1.06, 0.45, -0.3), V3(sd * 1.06, 0.1, 0.05) }, { V3(sd * 1.06, 0.1, 0.05), V3(sd * 1.06, -0.25, -0.15) }, { V3(sd * 1.06, 0.1, 0.05), V3(sd * 1.06, 0.3, 0.45) } }) do line(k, body, seg[1], seg[2], 0.05, NE, V3(1, 0, 0)) end
		for _, p in ipairs({ V3(sd * 1.07, 0.45, -0.3), V3(sd * 1.07, 0.1, 0.05), V3(sd * 1.07, -0.25, -0.15), V3(sd * 1.07, 0.3, 0.45) }) do local _, d = k.b(body, "StarDot", 0.08, 0.14, 0.14, NE, k.sc(CF(p)), MAT.Neon); k.glow(d, NE) end
	end
	for i = 0, 5 do k.tri(body, "BackSpike", 0.16, 0.6 - i * 0.04, 0.5, PK, c(0, 0.95, -0.9 + i * 0.42) * ANG(0.5, 0, 0)) end

	local lf = { up = { 0.85, 0.75, 0.95 }, col = PU, w2 = 0.72, d2 = 0.8, col2 = PUL, paw = { 1.05, 0.38, 1.2, -0.1 }, pawCol = PUD, toes = 3, toeCol = PK }
	k.leg(body, "LegFL", BY, -0.8, -0.55, -0.85, lf)
	k.leg(body, "LegFR", BY, 0.8, -0.55, -0.85, lf)
	lf.hind = true
	k.leg(body, "LegBL", BY, -0.85, -0.5, 0.9, lf)
	k.leg(body, "LegBR", BY, 0.85, -0.5, 0.9, lf)
	rig.legKind = "quad"

	k.b(body, "Neck1", 1.0, 1.0, 0.9, PU, c(0, 0.75, -1.45) * ANG(-0.5, 0, 0))
	k.b(body, "Neck2", 0.9, 0.9, 0.85, PUL, c(0, 1.35, -1.75) * ANG(-0.3, 0, 0))
	local re, rp = k.pv(body, "NeckRing", c(0, 1.3, -1.7) * ANG(0.5, 0, 0))
	H.group(rig, "rings", re)
	k.ring(rp, "PinkRing", FLAT, 1.1, 14, 0.14, 0.5, 0.14, PK)
	for i = 0, 2 do
		local a = i / 3 * PI * 2
		local _, n = k.b(rp, "RingNode", 0.35, 0.35, 0.35, PUD, k.c(math.cos(a) * 1.1, 0, math.sin(a) * 1.1))
		star(k, n, c(0, 0, -0.19), 0.24, NE, MAT.Neon)
	end
	local head = k.head(body, 1.1, 0.85, 1.3, PU, c(0, 2.05, -2.15), V3(0, -0.35, 0.4))
	k.b(head, "Snout", 0.8, 0.48, 0.75, PU, c(0, -0.15, -0.95))
	k.b(head, "Brow", 1.15, 0.22, 0.5, PUD, c(0, 0.35, -0.45))
	local jaw = k.jb(head, "Jaw", 0.75, 0.22, 1.05, PUD, c(0, -0.48, -0.65), V3(0, 0, 0.5))
	H.group(rig, "jaws", jaw)
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.32, 0.12, -0.66, 0.28, 0.1, NE, sd * 0.3)
		k.spike(head, "Horn", 1.2, 0.34, PUL, c(sd * 0.4, 0.4, 0.3) * ANG(1.0, 0, -sd * 0.35))
		k.spike(head, "HornSmall", 0.6, 0.24, PK, c(sd * 0.52, 0.0, 0.45) * ANG(1.3, 0, -sd * 0.8))
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.8, 0.65, -0.35))
		k.batWing(w, sd, { wrist = Vector2.new(1.5, 2.3), bone = PUD, mem = MG, boneW = 0.34, cap = PU,
			tips = { Vector2.new(4.0, 1.1), Vector2.new(3.4, -0.4), Vector2.new(2.3, -1.0), Vector2.new(1.1, -0.9) } })
		local _, node = k.b(w, "WristNode", 0.45, 0.6, 0.35, PUD, c(sd * 1.5, 2.3, -0.05))
		star(k, node, c(0, 0, -0.19), 0.35, NE, MAT.Neon)
		constellation(w, { { 2.0, 1.2 }, { 2.6, 0.7 }, { 3.0, 0.9 }, { 2.7, 0.2 } }, -0.12, sd)
		constellation(w, { { 1.6, 0.2 }, { 2.0, -0.3 }, { 2.4, -0.2 } }, -0.12, sd)
	end

	local segs = {}
	for j = 1, 8 do
		local w = 0.8 - j * 0.06
		table.insert(segs, { w, w * 0.85, 0.6, (j % 2 == 0) and PUD or PU, (j == 1) and 0.3 or -0.06 })
	end
	local rec = k.chain(body, c(0, 0.1, 1.2), segs, { name = "Tail", kind = "spine", i = 1, amp = 0.15, freq = 1.3, lag = 0.55 })
	for j, p in ipairs(rec.parts) do
		local w = 0.8 - j * 0.06
		k.tri(p, "TailSpike", 0.12, 0.42 - j * 0.02, 0.35, PK, c(0, w * 0.42 + 0.17, 0) * ANG(0.4, 0, 0))
		if j == 6 then k.ring(p, "TailRing", CF(), w * 0.6, 8, 0.12, w * 0.5, 0.25, PK) end
	end
	local last = rec.parts[#rec.parts]
	local tipRot = ANG(0, PI / 2, 0) * ANG(0, 0, PI / 2)
	k.tri(last, "Spear", 0.14, 0.9, 0.8, PU, c(0, 0, 0.7) * tipRot)
	star(k, last, c(0, 0.09, 0.6) * ANG(-PI / 2, 0, 0), 0.4, NE, MAT.Neon)
end

---------------------------------------------------------------- SINGULARITY CAT (Mythical)
-- Void cat: black body with a white V on the chest and glowing purple lines, black legs with purple
-- bands and white paws, a black head with tall ears (purple and white insides) and a single vertical
-- glowing purple eye slit, a segmented tail curling up to three purple claw blades, and two big white
-- and purple orbit rings circling it (one flat, one upright).
function M.Singularity(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local BK, BKL, W, PU, EY = C("#1A1820"), C("#2A2832"), C("#F2F0F8"), C("#7A4AF0"), C("#B08AFF")
	local BY = 2.0
	local body = k.body(1.1, 1.0, 2.0, BK, BY)
	k.tri(body, "ChestV", 0.12, 0.9, 1.0, W, c(0, -0.05, -1.02) * DOWN * FACE)
	for _, sd in ipairs(SIDES) do
		line(k, body, V3(sd * 0.56, 0.2, -0.8), V3(sd * 0.56, 0.2, 0.6), 0.08, PU, V3(1, 0, 0))
		k.b(body, "HipPlate", 0.1, 0.5, 0.6, BKL, c(sd * 0.56, 0.0, 0.65))
	end
	local lg = { up = { 0.45, 0.75, 0.55 }, col = BK, w2 = 0.36, d2 = 0.45, band = PU, bandY = 0.2, paw = { 0.45, 0.35, 0.55 }, pawCol = W, toes = 2, toeCol = W }
	k.leg(body, "LegFL", BY, -0.33, -0.45, -0.75, lg)
	k.leg(body, "LegFR", BY, 0.33, -0.45, -0.75, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.33, -0.45, 0.75, lg)
	k.leg(body, "LegBR", BY, 0.33, -0.45, 0.75, lg)
	rig.legKind = "quad"

	local head = k.head(body, 0.8, 0.75, 0.8, BK, c(0, 0.85, -1.15), V3(0, -0.3, 0.25))
	k.w(head, "Muzzle", 0.5, 0.32, 0.4, BKL, c(0, -0.22, -0.55))
	k.b(head, "EyeSocket", 0.18, 0.5, 0.05, W, c(0, 0.08, -0.41))
	k.eye(head, 0, 0.08, -0.44, 0.1, 0.4, EY, 0)
	for _, sd in ipairs(SIDES) do
		local ear = k.ear(head, sd, c(sd * 0.25, 0.35, 0.05) * ANG(0, 0, -sd * 0.15))
		k.tri(ear, "Ear", 0.18, 0.95, 0.5, BK, c(0, 0.47, 0) * FACE)
		k.tri(ear, "EarPurple", 0.06, 0.65, 0.3, PU, c(0, 0.38, -0.1) * FACE, MAT.Neon)
		k.tri(ear, "EarWhite", 0.07, 0.35, 0.3, W, c(0, 0.15, -0.11) * FACE)
	end

	local tip = k.tail(body, c(0, 0.3, 1.05), {
		{ 0.24, 0.24, 0.5, 0.3, BK }, { 0.24, 0.24, 0.5, -0.4, BK }, { 0.22, 0.22, 0.45, -0.6, BKL }, { 0.22, 0.22, 0.45, -0.7, BK }, { 0.2, 0.2, 0.4, -0.6, BK } })
	for _, e in ipairs(rig.tail) do
		local _, l = k.b(e.part, "TailLight", 0.26, 0.05, 0.08, PU, c(0, 0.13, 0), MAT.Neon)
		k.glow(l, PU)
	end
	for i, a in ipairs({ -0.5, 0, 0.5 }) do
		k.tri(tip, "Claw", 0.1, 0.8 - math.abs(a) * 0.3, 0.25, (i == 2) and W or PU, c(0, 0, 0.25) * ANG(PI / 2 - 0.4, 0, a) * c(0, 0.35, 0))
	end

	local r1, rp1 = k.pv(body, "OrbitFlat", c(0, 0.05, 0) * ANG(0.15, 0, 0))
	H.group(rig, "rings", r1)
	k.ring(rp1, "OrbitRing", FLAT, 1.9, 16, 0.3, 0.8, 0.12, W)
	k.ring(rp1, "OrbitInner", FLAT, 1.6, 14, 0.12, 0.72, 0.13, PU, MAT.Neon)
	local r2, rp2 = k.pv(body, "OrbitUp", c(0, 0.2, 0.3))
	H.group(rig, "orbit", r2)
	k.ring(rp2, "OrbitRing", ANG(0, PI / 2, 0), 1.6, 14, 0.25, 0.75, 0.12, W)
	k.ring(rp2, "OrbitInner", ANG(0, PI / 2, 0), 1.35, 12, 0.1, 0.7, 0.13, PU, MAT.Neon)
end

return M
