-- SpeciesModelsShadow: hand-authored, reference-faithful models for the Shadow world
-- (Gloomling, Shade Cat, Night Moth, Void Wisp, Umbra Wolf, Wraith Lord, Nightmare Wyvern).
-- Location: ReplicatedStorage > Shared > SpeciesModelsShadow (ModuleScript), merged into SpeciesModels.

local K = require(script.Parent.ModelKit)
local V3, CF, ANG, PI, MAT, C = K.V3, K.CF, K.ANG, K.PI, K.MAT, K.C
local FACE, DOWN = ANG(0, PI / 2, 0), ANG(0, 0, PI)
local SIDES = { -1, 1 }

local M = {}

local function line(k, parent, A, B, w, col, up)
	local _, p = k.bar(parent, "GlowLine", A, B, w, col, MAT.Neon, nil, up, w * 0.6)
	k.glow(p, col)
end

-- flat kite panel in a wing pivot's XY plane (outward = side * X)
local function kite(k, pv, side, O, L, T, R, col, z)
	local function P(v) return V3(v.X * side, v.Y, z) end
	k.mem(pv, "WingPanel", P(O), P(L), P(R), 0.08, col)
	k.mem(pv, "WingPanel", P(T), P(L), P(R), 0.08, col)
end

---------------------------------------------------------------- GLOOMLING (Common)
-- Little hooded shade: big purple hood with a lavender rim around a dark face and glowing slit eyes,
-- a pointed purple cloak with a darker front panel, stubby arms with lavender cuffs.
function M.Gloomling(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUD, PUL, LV, DK, EY = C("#5A3A8A"), C("#45286E"), C("#7A52B0"), C("#A880F0"), C("#22163A"), C("#D8B8FF")
	local BY = 1.5
	local body = k.body(1.1, 1.0, 0.9, PU, BY)
	rig.legKind = "none"
	k.b(body, "FrontPanel", 0.45, 1.0, 0.1, PUD, c(0, -0.1, -0.48))
	k.tri(body, "FrontTip", 0.1, 0.5, 0.45, PUD, c(0, -0.85, -0.48) * DOWN * FACE)
	for i, d in ipairs({ { -0.4, -0.15, 1.1 }, { 0.4, -0.15, 1.1 }, { 0, 0.3, 1.3 }, { -0.35, 0.3, 0.9 }, { 0.35, 0.3, 0.9 } }) do
		local te, tp = k.pv(body, "CloakPivot", c(d[1], -0.45, d[2]) * ANG(0, 0, d[1] * 0.3))
		table.insert(rig.tail, te)
		k.tri(tp, "Cloak", 0.12, d[3], 0.6, (i % 2 == 0) and PUL or PU, c(0, -d[3] / 2, 0) * DOWN * FACE)
	end
	local head = k.head(body, 1.15, 1.05, 1.15, PU, c(0, 0.95, 0.05), V3(0, -0.45, 0.1))
	k.b(head, "HoodBack", 1.0, 0.7, 0.5, PUD, c(0, 0.25, 0.55) * ANG(-0.3, 0, 0))
	k.b(head, "Face", 0.8, 0.6, 0.1, DK, c(0, -0.05, -0.55))
	k.b(head, "RimTop", 1.0, 0.16, 0.14, LV, c(0, 0.33, -0.58))
	for _, sd in ipairs(SIDES) do
		k.b(head, "RimSide", 0.16, 0.75, 0.14, LV, c(sd * 0.47, -0.05, -0.58))
		k.eye(head, sd * 0.18, 0.0, -0.61, 0.2, 0.08, EY, sd * 0.3)
		local a = k.arm(body, sd, c(sd * 0.55, 0.1, -0.15))
		k.b(a, "Arm", 0.4, 0.4, 0.55, PUD, c(sd * 0.1, -0.25, -0.2))
		k.b(a, "Cuff", 0.42, 0.42, 0.14, LV, c(sd * 0.1, -0.25, -0.5))
	end
end

---------------------------------------------------------------- SHADE CAT (Uncommon)
-- Shadow cat: very dark purple angular body with lighter purple shoulder and hip plates, a lime collar
-- with a diamond pendant and a grey tag, spiky chin ruff, angular head with purple ear insides and
-- glowing lime eyes, dark clawed paws, a segmented tail rising to a purple blade tip.
function M.ShadeCat(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUD, PUL, LM, TG, EY = C("#3A2846"), C("#2C1E36"), C("#6A3E8A"), C("#C8F03A"), C("#8A7090"), C("#D8FF4A")
	local BY = 1.75
	local body = k.body(1.25, 1.1, 2.3, PU, BY)
	for _, sd in ipairs(SIDES) do
		k.b(body, "ShoulderPlate", 0.12, 0.55, 0.8, PUL, c(sd * 0.64, 0.15, -0.65) * ANG(0.3, 0, 0))
		k.b(body, "HipPlate", 0.12, 0.5, 0.75, PUL, c(sd * 0.64, 0.2, 0.75) * ANG(-0.3, 0, 0))
	end
	local _, collar = k.b(body, "Collar", 1.15, 0.18, 0.25, LM, c(0, 0.45, -1.15), MAT.Neon)
	k.glow(collar, LM)
	k.diamond(body, "Pendant", 0.55, 0.42, 0.08, LM, c(0, 0.05, -1.2))
	k.diamond(body, "PendantIn", 0.35, 0.24, 0.1, PU, c(0, 0.05, -1.22))
	k.b(body, "Tag", 0.25, 0.25, 0.1, TG, c(0.42, 0.25, -1.2))
	local lg = { up = { 0.5, 0.65, 0.6 }, col = PU, w2 = 0.42, d2 = 0.5, col2 = PUD, paw = { 0.6, 0.3, 0.7 }, pawCol = PUD, toes = 3, toeCol = PUL }
	k.leg(body, "LegFL", BY, -0.42, -0.45, -0.85, lg)
	k.leg(body, "LegFR", BY, 0.42, -0.45, -0.85, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.42, -0.45, 0.85, lg)
	k.leg(body, "LegBR", BY, 0.42, -0.45, 0.85, lg)
	rig.legKind = "quad"

	local head = k.head(body, 1.0, 0.85, 0.95, PU, c(0, 0.8, -1.4), V3(0, -0.35, 0.3))
	k.w(head, "Muzzle", 0.55, 0.35, 0.45, PUL, c(0, -0.22, -0.62))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.4, 0.12, 0.2, PUD, c(sd * 0.24, 0.16, -0.48) * ANG(0, 0, sd * 0.35))
		k.eye(head, sd * 0.24, 0.05, -0.49, 0.24, 0.1, EY, sd * 0.35)
		k.tri(head, "Ruff", 0.1, 0.5, 0.35, PUD, c(sd * 0.45, -0.3, -0.1) * ANG(0, 0, -sd * 1.6))
		local ear = k.ear(head, sd, c(sd * 0.32, 0.4, 0.1) * ANG(0, 0, -sd * 0.15))
		k.tri(ear, "Ear", 0.2, 0.8, 0.55, PU, c(0, 0.4, 0) * FACE)
		k.tri(ear, "EarInner", 0.07, 0.55, 0.32, PUL, c(0, 0.32, -0.1) * FACE)
	end
	local tip = k.tail(body, c(0, 0.35, 1.15), {
		{ 0.3, 0.3, 0.55, -0.7, PU }, { 0.28, 0.28, 0.55, -0.3, PU }, { 0.28, 0.28, 0.5, -0.3, PU }, { 0.26, 0.26, 0.45, 0.4, PU } })
	k.w(tip, "TailBlade", 0.3, 0.3, 0.75, PUL, c(0, 0, 0.55) * ANG(0, PI, 0))
end

---------------------------------------------------------------- NIGHT MOTH (Rare)
-- Night moth on six legs: purple body with a fluffy lavender collar ruff, a striped abdomen with glowing
-- cyan bands, angular head with glowing cyan eyes and feathery lavender antennae, four big kite wings
-- (purple frame, lavender panels, glowing cyan stripes).
function M.NightMoth(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUD, LV, CY, EY = C("#5A3A8A"), C("#45286E"), C("#BFA4F0"), C("#5FE8F0"), C("#7FF0FF")
	local BY = 1.6
	local body = k.body(0.95, 0.85, 1.0, PU, BY)
	for i = 0, 5 do
		local a = (i - 2.5) / 5 * 2.6
		k.b(body, "Ruff", 0.45, 0.4, 0.4, LV, c(math.sin(a) * 0.55, 0.35, -math.cos(a) * 0.45) * ANG(0.4, a, 0))
	end
	local ae, ap = k.pv(body, "AbdomenPivot", c(0, -0.05, 0.45) * ANG(0.3, 0, 0))
	H.group(rig, "abdomen", ae)
	for i = 0, 2 do
		local w = 0.85 - i * 0.18
		local _, seg = k.b(ap, "Abdomen", w, w * 0.85, 0.5, (i % 2 == 0) and PU or PUD, c(0, 0, 0.3 + i * 0.48))
		local _, band = k.b(seg, "AbdomenBand", w + 0.04, 0.1, 0.12, CY, c(0, 0.1, 0.15), MAT.Neon)
		k.glow(band, CY)
	end
	k.w(ap, "AbdomenTip", 0.4, 0.35, 0.5, LV, c(0, 0, 1.75) * ANG(0, PI, 0))

	local head = k.head(body, 0.8, 0.65, 0.7, PU, c(0, 0.45, -0.7), V3(0, -0.2, 0.25))
	k.w(head, "Snout", 0.55, 0.3, 0.3, PUD, c(0, -0.12, -0.45))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.2, 0.05, -0.36, 0.22, 0.12, EY, sd * 0.35)
		local ant = k.ear(head, sd, c(sd * 0.18, 0.3, 0.0) * ANG(0, 0, -sd * 0.3), "antenna")
		k.b(ant, "AntennaStem", 0.1, 0.9, 0.1, LV, c(0, 0.45, 0))
		for j = 1, 3 do
			k.b(ant, "AntennaBarb", 0.4, 0.08, 0.08, LV, c(sd * 0.18, 0.25 + j * 0.2, 0) * ANG(0, 0, sd * 0.6))
		end
	end

	local lg = { up = { 0.18, 0.55, 0.18 }, col = PU, w2 = 0.16, d2 = 0.16, col2 = PUD, paw = { 0.24, 0.24, 0.28 }, pawCol = LV, splay = 0.6 }
	for _, z in ipairs({ -0.35, 0, 0.35 }) do
		k.leg(body, "LegL", BY, -0.4, -0.35, z, lg)
		k.leg(body, "LegR", BY, 0.4, -0.35, z, lg)
	end
	rig.legKind = "bug6"

	local V2 = Vector2.new
	for _, sd in ipairs(SIDES) do
		for tier, w in ipairs({
			{ V2(0, 0), V2(0.5, 1.8), V2(3.0, 2.7), V2(2.2, 0.4), V2(0.6, 0.55), V2(0.85, 1.55), V2(2.4, 2.15), V2(1.9, 0.75) },
			{ V2(0, 0), V2(1.2, 0.3), V2(2.5, -0.6), V2(1.0, -0.95), V2(0.5, -0.1), V2(1.15, 0.05), V2(1.95, -0.45), V2(1.0, -0.65) },
		}) do
			local pv = k.wing(body, sd, c(sd * 0.42, 0.3, 0.05 + (tier - 1) * 0.15) * ANG(0, -sd * (0.35 + tier * 0.1), 0), tier)
			kite(k, pv, sd, w[1], w[2], w[3], w[4], PU, 0)
			kite(k, pv, sd, w[5], w[6], w[7], w[8], LV, -0.06)
			line(k, pv, V3(w[7].X * sd, w[7].Y, -0.1), V3((w[6].X * 0.6 + w[7].X * 0.4) * sd, w[6].Y * 0.6 + w[7].Y * 0.4, -0.1), 0.12, CY)
			line(k, pv, V3(w[7].X * sd, w[7].Y, -0.1), V3((w[8].X * 0.6 + w[7].X * 0.4) * sd, w[8].Y * 0.6 + w[7].Y * 0.4, -0.1), 0.12, CY)
		end
	end
end

---------------------------------------------------------------- VOID WISP (Epic)
-- Floating void sentinel: angular black core with purple framing around a glowing magenta slit eye, a
-- spiked black crown, a drill-shaped lower body with a magenta band, two black blade wings with magenta
-- glow stripes, and a broken ring of purple/magenta arcs turning around it.
function M.VoidWisp(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local BK, BKL, PU, MG = C("#2A1E36"), C("#3A2A4A"), C("#8A3ADF"), C("#FF4AD8")
	local BY = 2.0
	local body = k.body(1.4, 1.3, 1.2, BK, BY)
	rig.legKind = "none"
	k.b(body, "EyeFrame", 1.0, 0.9, 0.1, PU, c(0, 0, -0.62) * ANG(0, 0, PI / 4))
	k.b(body, "EyeSocket", 0.75, 0.68, 0.11, BKL, c(0, 0, -0.64) * ANG(0, 0, PI / 4))
	local e, p = k.b(body, "Eye", 0.45, 0.45, 0.08, C("#B8208E"), c(0, 0, -0.69), MAT.Neon)
	table.insert(rig.eyes, e)
	k.glow(p, MG)
	k.b(body, "Slit", 0.1, 0.4, 0.04, MG, c(0, 0, -0.74), MAT.Neon)
	for _, sd in ipairs(SIDES) do k.b(body, "SideFrame", 0.2, 1.0, 0.9, PU, c(sd * 0.72, 0, -0.1)) end

	local head = k.head(body, 1.1, 0.5, 1.0, BK, c(0, 0.85, 0), V3(0, -0.25, 0.1))
	k.spike(head, "CrownSpike", 1.1, 0.5, BK, c(0, 0.2, 0))
	for _, sd in ipairs(SIDES) do k.spike(head, "CrownSpike", 0.6, 0.35, BKL, c(sd * 0.4, 0.2, 0) * ANG(0, 0, -sd * 0.3)) end
	for i = 0, 2 do
		k.b(body, "Drill", 0.9 - i * 0.25, 0.4, 0.8 - i * 0.22, (i == 1) and BKL or BK, c(0, -0.85 - i * 0.38, 0))
	end
	local _, band = k.b(body, "DrillBand", 0.7, 0.08, 0.62, MG, c(0, -1.12, 0), MAT.Neon)
	k.glow(band, MG)
	k.spike(body, "DrillTip", 0.8, 0.35, PU, c(0, -1.75, 0) * DOWN)

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.8, 0.2, 0.1))
		k.b(w, "WingBlade", 1.6, 0.7, 0.4, BK, c(sd * 0.85, 0.1, 0) * ANG(0, 0, -sd * 0.15))
		k.w(w, "WingTip", 0.4, 0.7, 0.6, BK, c(sd * 1.95, 0.0, 0) * ANG(0, -sd * PI / 2, 0) * ANG(0, 0, 0))
		line(k, w, V3(sd * 0.4, 0.05, -0.22), V3(sd * 1.5, -0.12, -0.22), 0.14, MG)
	end
	local re, rp = k.pv(body, "ArcRing", c(0, 0, 0.1))
	H.group(rig, "rays", re)
	for i = 0, 5 do
		local a0 = i / 6 * PI * 2 + 0.25
		for j = 0, 1 do
			local a = a0 + j * 0.35
			k.b(rp, "Arc", 0.2, 0.6, 0.18, (j == 0) and PU or MG, k.c(math.cos(a) * 2.0, math.sin(a) * 2.0, 0) * ANG(0, 0, a))
		end
	end
end

---------------------------------------------------------------- UMBRA WOLF (Legendary)
-- Shadow wolf: dark purple body with angular armour plates traced by glowing violet lines, a big spiky
-- purple mane over neck, shoulders and spine, long legs with glowing bands and clawed paws, a long-snouted
-- head with tall ears and glowing violet eyes, a huge spiky bushy tail.
function M.UmbraWolf(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUD, PUL, NE = C("#4A2A6E"), C("#2E1C44"), C("#7A3ACF"), C("#C060FF")
	local BY = 2.1
	local body = k.body(1.3, 1.2, 2.6, PUD, BY)
	for _, sd in ipairs(SIDES) do
		k.b(body, "ShoulderPlate", 0.14, 0.8, 0.9, PU, c(sd * 0.68, 0.0, -0.7))
		line(k, body, V3(sd * 0.76, 0.3, -1.05), V3(sd * 0.76, -0.3, -0.75), 0.08, NE, V3(1, 0, 0))
		line(k, body, V3(sd * 0.76, -0.3, -0.75), V3(sd * 0.76, 0.3, -0.45), 0.08, NE, V3(1, 0, 0))
		k.b(body, "HipPlate", 0.14, 0.75, 0.8, PU, c(sd * 0.68, 0.05, 0.8))
		line(k, body, V3(sd * 0.76, 0.3, 0.5), V3(sd * 0.76, -0.25, 0.95), 0.08, NE, V3(1, 0, 0))
	end
	for i = 0, 6 do
		local z = -1.2 + i * 0.4
		k.spike(body, "SpineSpike", 0.9 - i * 0.05, 0.6, (i % 2 == 0) and PUL or PU, c(0, 0.55, z) * ANG(0.9, 0, (i % 2 == 0) and 0.25 or -0.25))
	end
	local lg = { up = { 0.55, 0.85, 0.65 }, col = PUD, w2 = 0.45, d2 = 0.55, band = NE, bandY = 0.25, paw = { 0.6, 0.35, 0.75 }, pawCol = PU, toes = 3, toeCol = PUL }
	k.leg(body, "LegFL", BY, -0.42, -0.45, -0.95, lg)
	k.leg(body, "LegFR", BY, 0.42, -0.45, -0.95, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.42, -0.45, 0.95, lg)
	k.leg(body, "LegBR", BY, 0.42, -0.45, 0.95, lg)
	rig.legKind = "quad"

	k.b(body, "Neck", 0.8, 1.0, 0.8, PUD, c(0, 0.65, -1.3) * ANG(-0.4, 0, 0))
	-- mane: spikes fanning around the neck
	for i = 0, 7 do
		local a = (i - 3.5) / 3.5 * 1.6
		k.spike(body, "Mane", 1.45 - math.abs(a) * 0.15, 0.85, (i % 2 == 0) and PUL or PU, c(math.sin(a) * 0.55, 0.9 + math.cos(a) * 0.2, -1.2) * ANG(0.75, 0, -a * 0.85))
	end
	local head = k.head(body, 0.85, 0.75, 1.0, PUD, c(0, 1.25, -1.75), V3(0, -0.3, 0.3))
	k.w(head, "Snout", 0.5, 0.4, 0.75, PUD, c(0, -0.15, -0.8))
	k.b(head, "Nose", 0.18, 0.14, 0.1, C("#120A1C"), c(0, -0.3, -1.12))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.35, 0.12, 0.2, PU, c(sd * 0.23, 0.2, -0.48) * ANG(0, 0, sd * 0.35))
		k.eye(head, sd * 0.23, 0.08, -0.51, 0.22, 0.09, NE, sd * 0.35)
		local ear = k.ear(head, sd, c(sd * 0.28, 0.35, 0.15) * ANG(0, 0, -sd * 0.12))
		k.tri(ear, "Ear", 0.18, 0.85, 0.45, PU, c(0, 0.42, 0) * FACE)
		k.tri(head, "CheekSpike", 0.12, 0.6, 0.4, PU, c(sd * 0.45, -0.15, 0.1) * ANG(0.3, 0, -sd * 1.3))
	end

	local tp = k.tail(body, c(0, 0.25, 1.25), { { 0.5, 0.5, 0.7, -0.3, PU }, { 0.55, 0.55, 0.7, 0.05, PU }, { 0.45, 0.45, 0.6, 0.1, PUL } })
	for i, e in ipairs(rig.tail) do
		for j, a in ipairs({ -0.7, 0, 0.7 }) do
			k.spike(e.part, "TailSpike", 1.25 - i * 0.08, 0.8, ((i + j) % 2 == 0) and PUL or PU, c(math.sin(a) * 0.22, math.cos(a) * 0.22, 0) * ANG(1.1, 0, -a * 1.2))
		end
	end
	k.spike(tp, "TailTip", 0.9, 0.45, PUL, c(0, 0, 0.3) * ANG(PI / 2, 0, 0))
end

---------------------------------------------------------------- WRAITH LORD (Legendary)
-- Floating wraith king: a tall layered cloak of dark and bright purple blades with glowing pink stripes,
-- a purple tabard with a pink diamond and chevron, huge angular shoulder pads with pink trim, arms ending in
-- clawed hands, a dark hood with glowing pink eyes and a spiked crown with a pink gem.
function M.Wraithlord(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUL, DK, DKL, PK = C("#7A2ADF"), C("#9A4AF0"), C("#2A1A3A"), C("#3A2A4C"), C("#FF3A7A")
	local BY = 2.6
	local body = k.body(1.6, 1.6, 1.1, DK, BY)
	rig.legKind = "none"
	local te, tp = k.pv(body, "Tabard", c(0, 0.3, -0.58))
	table.insert(rig.tail, te)
	k.b(tp, "Tabard", 0.6, 2.4, 0.1, PU, c(0, -1.0, 0))
	k.tri(tp, "TabardTip", 0.1, 0.45, 0.6, PU, c(0, -2.42, 0) * DOWN * FACE)
	k.diamond(tp, "TabardGem", 0.4, 0.28, 0.08, PK, c(0, -0.1, -0.06))
	k.tri(tp, "Chevron", 0.08, 0.25, 0.4, PK, c(0, -1.6, -0.06) * DOWN * FACE)
	for i = 0, 9 do
		local a = (i / 9 - 0.5) * 3.6
		local x, z = math.sin(a) * 0.95, math.cos(a) * 0.6 - 0.05
		local L = 2.4 - math.abs(math.sin(a)) * 0.5
		local ce, cp = k.pv(body, "CloakPivot", c(x, -0.4, z) * ANG(0, math.atan2(x, z), 0) * ANG(-0.45, 0, 0))
		table.insert(rig.tail, ce)
		local col = (i % 2 == 0) and PU or DKL
		k.tri(cp, "Cloak", 0.12, L, 0.9, col, c(0, -L / 2, 0) * DOWN * FACE)
		if i % 3 == 1 then k.tri(cp, "CloakStripe", 0.13, L * 0.7, 0.12, PK, c(0.15, -L * 0.42, -0.02) * DOWN * FACE) end
	end

	for _, sd in ipairs(SIDES) do
		local a = k.arm(body, sd, c(sd * 1.0, 0.5, 0))
		k.b(a, "Shoulder", 1.0, 0.5, 1.0, PU, c(sd * 0.2, 0.25, 0))
		k.w(a, "ShoulderPeak", 1.0, 0.5, 0.6, DKL, c(sd * 0.55, 0.5, 0) * ANG(0, -sd * PI / 2, 0))
		k.b(a, "ShoulderTrim", 1.02, 0.1, 1.02, PK, c(sd * 0.2, 0.0, 0))
		k.b(a, "Sleeve", 0.7, 1.1, 0.7, DK, c(sd * 0.3, -0.7, 0))
		k.b(a, "SleeveTrim", 0.74, 0.12, 0.74, PK, c(sd * 0.3, -1.1, 0))
		local _, hand = k.b(a, "Hand", 0.55, 0.45, 0.5, DKL, c(sd * 0.35, -1.5, -0.1))
		for f = 1, 3 do k.b(hand, "Claw", 0.12, 0.45, 0.12, DK, c((f - 2) * 0.17, -0.35, -0.1) * ANG(-0.3, 0, 0)) end
	end

	local head = k.head(body, 0.85, 0.9, 0.85, DK, c(0, 1.25, 0), V3(0, -0.4, 0.1))
	k.b(head, "Face", 0.6, 0.5, 0.05, C("#120A1A"), c(0, -0.05, -0.43))
	for _, sd in ipairs(SIDES) do k.eye(head, sd * 0.14, 0.02, -0.46, 0.14, 0.07, PK, sd * 0.25) end
	k.b(head, "CrownBand", 0.9, 0.16, 0.9, PU, c(0, 0.5, 0))
	for i = -2, 2 do k.spike(head, "CrownSpike", (i == 0) and 0.7 or 0.45, 0.16, DKL, c(i * 0.19, 0.58, -0.25)) end
	k.diamond(head, "CrownGem", 0.35, 0.24, 0.08, PK, c(0, 0.55, -0.46))
end

---------------------------------------------------------------- NIGHTMARE WYVERN (Mythical)
-- Shadow wyvern: two clawed hind legs and huge bat wings that reach down to the ground like front
-- legs (dark bones, purple membranes with red slashes), dark body with purple back spikes edged in red,
-- an S-curved neck, a dragon head with a hinged jaw, glowing red eyes and big curled purple horns,
-- a segmented tail curling up into a red stinger.
function M.NightmareWyvern(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local BK, BKL, PU, PUL, RD = C("#2A1C36"), C("#3A2A4A"), C("#7A2ACF"), C("#8E3AE0"), C("#FF2A4A")
	local BY = 2.4
	local body = k.body(1.7, 1.5, 2.4, BK, BY)
	for i = 0, 5 do
		local z = -0.9 + i * 0.4
		k.tri(body, "BackSpike", 0.16, 0.8 - i * 0.06, 0.55, PU, c(0, 0.95, z) * ANG(0.5, 0, 0))
		k.tri(body, "BackSpikeEdge", 0.17, 0.45, 0.2, RD, c(0, 0.95, z + 0.18) * ANG(0.5, 0, 0))
	end
	for i = 0, 2 do k.b(body, "BellyPlate", 0.9, 0.3, 0.14, (i % 2 == 0) and RD or PU, c(0, 0.3 - i * 0.38, -1.25)) end

	local lg = { up = { 0.9, 0.85, 1.0 }, col = BK, w2 = 0.7, d2 = 0.8, col2 = BKL, paw = { 1.0, 0.38, 1.15, -0.1 }, pawCol = BK, toes = 3, toeCol = PUL, hind = true }
	k.leg(body, "LegL", BY, -0.7, -0.5, 0.55, lg)
	k.leg(body, "LegR", BY, 0.7, -0.5, 0.55, lg)
	rig.legKind = "biped"

	-- S neck: three blocks leaning forward then back
	k.b(body, "Neck1", 0.85, 0.9, 0.8, BK, c(0, 0.8, -1.35) * ANG(-0.6, 0, 0))
	k.b(body, "Neck2", 0.75, 0.85, 0.75, PU, c(0, 1.45, -1.75) * ANG(-0.1, 0, 0))
	k.b(body, "Neck3", 0.7, 0.8, 0.7, BK, c(0, 2.1, -1.8) * ANG(0.25, 0, 0))
	k.b(body, "NeckStripe", 0.4, 1.4, 0.1, RD, c(0, 1.45, -2.13) * ANG(-0.1, 0, 0))
	local head = k.head(body, 0.95, 0.75, 1.3, BK, c(0, 2.65, -2.15), V3(0, -0.3, 0.45))
	k.b(head, "Snout", 0.75, 0.42, 0.7, BKL, c(0, -0.12, -0.9))
	local jaw = k.jb(head, "Jaw", 0.7, 0.2, 0.95, PU, c(0, -0.42, -0.6), V3(0, 0, 0.45))
	H.group(rig, "jaws", jaw)
	k.b(head, "Mouth", 0.6, 0.08, 0.6, RD, c(0, -0.33, -0.75))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.28, 0.12, -0.66, 0.24, 0.1, RD, sd * 0.35)
		local pts = { V3(sd * 0.35, 0.3, 0.25), V3(sd * 0.7, 0.8, 0.4), V3(sd * 0.8, 1.3, 0.75), V3(sd * 0.75, 1.1, 1.2), V3(sd * 0.7, 0.65, 1.1), V3(sd * 0.7, 0.75, 0.8) }
		for i = 1, #pts - 1 do k.bar(head, "Horn", pts[i], pts[i + 1], 0.4 - i * 0.05, (i % 2 == 0) and PUL or PU, nil, nil, V3(1, 0, 0)) end
	end

	-- wings: wrist reaches down and forward to the ground (wyvern stance), membrane spreads up and back
	for _, sd in ipairs(SIDES) do
		-- arm rises to a high elbow, the forearm comes down to a clawed wrist on the ground,
		-- two fingers fan back from the elbow and the membrane fills between them
		local w = k.wing(body, sd, c(sd * 0.8, 0.5, -0.5) * ANG(0, -sd * 0.6, 0))
		local function P(x, y, z) return V3(x * sd, y, z or 0) end
		local O, E, Wr, F1, F2 = P(0, 0), P(1.1, 1.5), P(1.7, -2.45), P(3.4, 0.5), P(3.1, -1.4)
		k.bar(w, "WingArm", O, E, 0.42, BK)
		k.bar(w, "WingForearm", E, Wr, 0.36, BK)
		k.bar(w, "WingFinger", E, F1, 0.26, BK)
		k.bar(w, "WingFinger", E, F2, 0.24, BK)
		k.b(w, "ElbowKnob", 0.5, 0.5, 0.5, BKL, k.sc(CF(E)))
		k.b(w, "WristClaw", 0.55, 0.4, 0.65, BKL, k.sc(CF(Wr)))
		k.mem(w, "Membrane", E + P(0, 0, 0.06), F1 + P(0, 0, 0.06), F2 + P(0, 0, 0.06), 0.06, PU)
		k.mem(w, "Membrane", E + P(0, 0, 0.06), F2 + P(0, 0, 0.06), Wr + P(0, 0, 0.06), 0.06, PU)
		k.mem(w, "Membrane", E + P(0, 0, 0.06), Wr + P(0, 0, 0.06), P(0.1, -0.9, 0.06), 0.06, PUL)
		k.bar(w, "WingSlash", P(1.9, 0.4, -0.05), P(2.8, 0.1, -0.05), 0.16, RD)
		k.bar(w, "WingSlash", P(1.9, -0.9, -0.05), P(2.6, -1.3, -0.05), 0.14, RD)
	end

	local segs = {}
	for j = 1, 9 do
		local w = 0.65 - j * 0.035
		table.insert(segs, { w, w * 0.9, 0.5, (j % 2 == 0) and PU or BK, j == 1 and 0.2 or ((j <= 4) and -0.05 or -0.45) })
	end
	local rec = k.chain(body, c(0, 0.15, 1.15), segs, { name = "Tail", kind = "spine", i = 1, amp = 0.12, freq = 1.2, lag = 0.55 })
	for j, p in ipairs(rec.parts) do
		if j % 2 == 0 then k.b(p, "TailMark", 0.1, 0.3, 0.3, RD, c(0, 0.3, 0)) end
	end
	k.spike(rec.parts[#rec.parts], "Stinger", 0.9, 0.35, RD, c(0, 0, 0.25) * ANG(PI / 2, 0, 0))
end

return M
