-- SpeciesModelsDivine: hand-authored, reference-faithful models for the Divine portal creatures
-- (Solaris, Aetherion, Eternity Owl, Genesis, Infinity Fox).
-- Location: ReplicatedStorage > Shared > SpeciesModelsDivine (ModuleScript), merged into SpeciesModels.

local K = require(script.Parent.ModelKit)
local V3, CF, ANG, PI, MAT, C = K.V3, K.CF, K.ANG, K.PI, K.MAT, K.C
local FACE, DOWN = ANG(0, PI / 2, 0), ANG(0, 0, PI)
local FLAT = ANG(PI / 2, 0, 0) -- turns an XY-plane ring into a horizontal (XZ) ring
local SIDES = { -1, 1 }

local M = {}

-- horizontal halo that floats and turns above `parent` (rig.halos)
local function halo(k, parent, cf, radius, count, col, col2)
	local e, p = k.pv(parent, "HaloPivot", cf)
	table.insert(k.rig.halos, e)
	k.ring(p, "Halo", FLAT, radius, count, 0.16, radius * 6.3 / count + 0.02, 0.16, col)
	if col2 then
		for i = 0, 3 do
			local a = i * PI / 2
			k.b(p, "HaloInset", 0.2, 0.18, 0.4, col2, k.c(math.cos(a) * radius, 0, math.sin(a) * radius) * ANG(0, -a, 0))
		end
	end
	return p, e
end

---------------------------------------------------------------- SOLARIS (Divine)
-- Floating sun knight: gold helmet with a white crown and an orange crystal, glowing visor eyes,
-- white-and-gold chest plate with an orange diamond, a long white shield-skirt with an orange stripe
-- tapering to a point, gold shoulder blocks, layered white/gold/orange wings, a ring of gold and orange
-- sun shards turning behind it, and a gold halo.
function M.Solaris(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local Y, YD, W, O, EY = C("#FFD02E"), C("#F2B81E"), C("#FAF7EC"), C("#FF9A1E"), C("#FFE45C")
	local BY = 2.3
	local body = k.body(1.3, 1.0, 0.9, Y, BY)
	rig.legKind = "none"
	k.tri(body, "ChestV", 0.14, 0.9, 1.3, W, c(0, 0.05, -0.47) * DOWN * FACE)
	k.b(body, "GemFrame", 0.55, 0.55, 0.1, W, c(0, 0.0, -0.55) * ANG(0, 0, PI / 4))
	k.diamond(body, "ChestGem", 0.6, 0.4, 0.14, O, c(0, 0.0, -0.6), MAT.Glass)
	-- shield skirt
	for i = 0, 2 do
		k.b(body, "Skirt", 0.95 - i * 0.18, 0.5, 0.6, W, c(0, -0.75 - i * 0.48, 0))
		k.b(body, "SkirtStripe", 0.3 - i * 0.04, 0.5, 0.62, O, c(0, -0.75 - i * 0.48, 0))
	end
	k.tri(body, "SkirtTip", 0.5, 0.7, 0.45, Y, c(0, -2.25, 0) * DOWN * FACE)
	for _, sd in ipairs(SIDES) do
		k.b(body, "Shoulder", 0.55, 0.6, 0.7, YD, c(sd * 0.8, 0.25, 0))
	end

	local head = k.head(body, 0.8, 0.75, 0.75, Y, c(0, 0.95, 0), V3(0, -0.35, 0.1))
	k.b(head, "Visor", 0.6, 0.25, 0.06, YD, c(0, 0.0, -0.39))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.15, 0.0, -0.42, 0.16, 0.08, EY, sd * 0.3)
		k.tri(head, "CrownSpike", 0.12, 0.45, 0.25, W, c(sd * 0.28, 0.55, -0.15) * FACE)
	end
	k.b(head, "CrownBand", 0.85, 0.2, 0.8, W, c(0, 0.38, 0))
	k.crystal(head, "CrownCrystal", 0.6, 0.22, O, c(0, 0.45, -0.3), MAT.Glass, 0.05)
	halo(k, head, c(0, 1.25, 0), 0.9, 14, Y, W)

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.8, 0.3, 0.2))
		k.featherWing(w, sd, { root = 0.2, z = 0.05, thick = 0.16, feathers = {
			{ 0.45, 2.8, 0.5, W, Y }, { 0.25, 3.0, 0.5, Y, O }, { 0.05, 2.9, 0.5, W, Y }, { -0.15, 2.6, 0.48, Y, O }, { -0.35, 2.2, 0.45, W, W } } })
		k.featherWing(w, sd, { root = 0.1, z = -0.06, thick = 0.18, feathers = {
			{ 0.35, 1.6, 0.42, O, O }, { 0.1, 1.7, 0.42, O, Y }, { -0.15, 1.5, 0.4, O, O } } })
	end
	local re, rp = k.pv(body, "SunRays", c(0, -0.2, 0.35))
	H.group(rig, "rays", re)
	for i = 0, 9 do
		local a = (i + 0.5) / 10 * PI * 2
		local L = (i % 2 == 0) and 1.3 or 0.9
		k.tri(rp, "SunShard", 0.14, L, 0.35, (i % 2 == 0) and Y or O, CF(math.cos(a) * 1.9 * s, math.sin(a) * 1.9 * s, 0) * ANG(0, 0, a - PI / 2) * FACE)
	end
end

---------------------------------------------------------------- AETHERION (Divine)
-- Celestial dragon: white armoured body with gold trim and a big cyan crystal in a gold chest frame,
-- legs with cyan bands and gold claws, long white neck with a cyan line, white head with swept gold
-- horns and a cyan crest, a spiked gold halo, enormous feathered wings (gold arm, white and cyan
-- blades), a long white tail with gold bands and cyan crystal spines ending in a gold-and-crystal arrow.
function M.Aetherion(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, WD, GO, CY, EY = C("#F7F8FA"), C("#E2E6EC"), C("#F2C230"), C("#8FE8F2"), C("#FFE45C")
	local BY = 2.3
	local body = k.body(1.7, 1.45, 2.4, W, BY)
	k.b(body, "ChestFrame", 1.05, 1.05, 0.12, GO, c(0, 0.05, -1.24) * ANG(0, 0, PI / 4))
	k.diamond(body, "ChestCrystal", 1.0, 0.6, 0.16, CY, c(0, 0.05, -1.3), MAT.Glass)
	for _, sd in ipairs(SIDES) do
		k.b(body, "GoldTrim", 0.1, 0.16, 2.0, GO, c(sd * 0.86, 0.45, 0.1))
	end

	local lf = { up = { 0.8, 0.75, 0.9 }, col = W, w2 = 0.66, d2 = 0.72, band = CY, paw = { 0.92, 0.35, 1.05 }, pawCol = W, toes = 3, toeCol = GO }
	k.leg(body, "LegFL", BY, -0.72, -0.5, -0.8, lf)
	k.leg(body, "LegFR", BY, 0.72, -0.5, -0.8, lf)
	lf.hind = true
	k.leg(body, "LegBL", BY, -0.74, -0.45, 0.85, lf)
	k.leg(body, "LegBR", BY, 0.74, -0.45, 0.85, lf)
	rig.legKind = "quad"

	for i = 0, 2 do
		local _, n = k.b(body, "Neck", 0.75 - i * 0.05, 0.75, 0.7, W, c(0, 0.8 + i * 0.6, -1.3 - i * 0.18) * ANG(-0.3, 0, 0))
		k.b(n, "NeckLine", 0.12, 0.76, 0.72, CY, c(0, 0, -0.02))
		k.tri(n, "NeckSpine", 0.1, 0.4, 0.35, GO, c(0, 0.1, 0.45) * ANG(0.9, 0, 0))
	end
	local head = k.head(body, 0.9, 0.7, 1.1, W, c(0, 2.45, -1.95), V3(0, -0.25, 0.4))
	k.w(head, "Snout", 0.62, 0.42, 0.6, W, c(0, -0.1, -0.8))
	k.b(head, "Brow", 0.95, 0.16, 0.5, GO, c(0, 0.35, -0.3))
	k.crystal(head, "Crest", 0.6, 0.2, CY, c(0, 0.4, 0.15) * ANG(0.7, 0, 0), MAT.Glass, 0.1)
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.26, 0.1, -0.56, 0.22, 0.09, EY, sd * 0.3)
		k.spike(head, "Horn", 1.1, 0.26, GO, c(sd * 0.3, 0.35, 0.25) * ANG(1.1, 0, -sd * 0.35))
		k.spike(head, "HornSmall", 0.6, 0.2, GO, c(sd * 0.45, 0.05, 0.35) * ANG(1.3, 0, -sd * 0.8))
	end
	local hp = halo(k, head, c(0, 1.35, 0.2), 0.75, 12, GO)
	for i = 0, 3 do
		local a = i * PI / 2
		k.spike(hp, "HaloSpike", 0.45, 0.14, GO, k.c(math.cos(a) * 0.75, 0.05, math.sin(a) * 0.75))
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.75, 0.6, -0.2))
		k.bar(w, "WingArm", V3(0, 0, 0), V3(sd * 1.4, 2.0, 0), 0.4, GO)
		k.bar(w, "WingArm", V3(sd * 1.4, 2.0, 0), V3(sd * 3.6, 2.6, 0), 0.34, GO)
		local fe, fp = k.pv(w, "FeatherRoot", c(sd * 1.4, 2.0, 0.05))
		local fw = {}
		for i = 0, 7 do
			table.insert(fw, { 0.55 - i * 0.24, 3.0 - math.abs(i - 2) * 0.18, 0.4, (i % 2 == 0) and W or CY })
		end
		k.featherWing(fp, sd, { root = 0.1, z = 0.04, feathers = fw })
	end

	local segs = {}
	for j = 1, 9 do
		local w = 0.75 - j * 0.05
		table.insert(segs, { w, w * 0.85, 0.6, W, j == 1 and 0.3 or -0.04 })
	end
	local rec = k.chain(body, c(0, 0.1, 1.15), segs, { name = "Tail", kind = "spine", i = 1, amp = 0.14, freq = 1.2, lag = 0.55 })
	for j, p in ipairs(rec.parts) do
		local w = 0.75 - j * 0.05
		if j % 2 == 0 then k.b(p, "TailBand", w + 0.06, w * 0.9, 0.16, GO, c(0, 0, 0)) end
		if j % 2 == 1 and j < 9 then k.crystal(p, "TailCrystal", 0.55, 0.15, CY, c(0, w * 0.42, 0) * ANG(0.4, 0, 0), MAT.Glass, 0.15) end
	end
	local last = rec.parts[#rec.parts]
	local tipRot = ANG(0, PI / 2, 0) * ANG(0, 0, PI / 2)
	k.tri(last, "Arrow", 0.14, 0.7, 0.9, GO, c(0, 0, 0.6) * tipRot)
	k.crystal(last, "ArrowCrystal", 0.8, 0.28, CY, c(0, 0, 0.7) * ANG(PI / 2, 0, 0), MAT.Glass, 0.1)
end

---------------------------------------------------------------- ETERNITY OWL (Divine)
-- Cosmic guardian owl: deep-purple body with pale-gold V armour, glowing cyan lines and a cyan chest
-- gem, gold talons, purple head with a gold face mask and beak, glowing cyan eyes, ear tufts, an
-- octagonal gold time-ring with four cyan gems (plus an inner ring) turning behind the head, raised
-- wings with purple arm panels, cyan glow stripes, gold wrist gems and a fan of pale-gold feathers.
function M.EternityOwl(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUL, GO, GOD, CY, EY = C("#3E1F6E"), C("#55308E"), C("#F0D890"), C("#D8BE72"), C("#6FF2E8"), C("#6FF2E8")
	local BY = 2.1
	local body = k.body(1.5, 1.6, 1.3, PU, BY)
	k.tri(body, "ArmorV", 0.14, 1.2, 1.4, GO, c(0, 0.0, -0.68) * DOWN * FACE)
	k.diamond(body, "ChestGem", 0.45, 0.32, 0.1, CY, c(0, 0.15, -0.77), MAT.Glass)
	local _, ln = k.b(body, "GlowLine", 0.08, 0.6, 0.06, CY, c(0, -0.35, -0.76), MAT.Neon)
	k.glow(ln, CY)
	for _, sd in ipairs(SIDES) do
		local _, l2 = k.bar(body, "GlowLine", V3(sd * 0.76, 0.4, -0.2), V3(sd * 0.76, -0.4, 0.3), 0.07, CY, MAT.Neon, nil, V3(1, 0, 0))
		k.glow(l2, CY)
	end
	local lg = { up = { 0.5, 0.4, 0.55 }, col = PU, w2 = 0.4, d2 = 0.45, paw = { 0.65, 0.25, 0.7 }, pawCol = GO, toes = 3, toeCol = GO }
	k.leg(body, "LegL", BY, -0.4, -0.8, 0, lg)
	k.leg(body, "LegR", BY, 0.4, -0.8, 0, lg)
	rig.legKind = "biped"

	local head = k.head(body, 1.1, 1.0, 1.0, PU, c(0, 1.25, -0.1), V3(0, -0.45, 0.2))
	k.tri(head, "FaceMask", 0.12, 0.8, 1.0, GO, c(0, 0.0, -0.53) * DOWN * FACE)
	k.w(head, "Beak", 0.26, 0.4, 0.3, GOD, c(0, -0.2, -0.68) * DOWN)
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.24, 0.12, -0.6, 0.24, 0.1, EY, sd * 0.35)
		local ear = k.ear(head, sd, c(sd * 0.4, 0.45, 0) * ANG(0, 0, -sd * 0.25))
		k.tri(ear, "Tuft", 0.2, 0.55, 0.5, PU, c(0, 0.27, 0) * FACE)
		k.tri(ear, "TuftGold", 0.07, 0.38, 0.28, GO, c(0, 0.22, -0.1) * FACE)
	end
	local re, rp = k.pv(head, "TimeRing", c(0, 0.45, 0.65))
	H.group(rig, "rays", re)
	k.ring(rp, "Ring", CF(), 1.5, 8, 0.16, 1.18, 0.14, GO)
	k.ring(rp, "InnerRing", CF(), 1.05, 10, 0.1, 0.6, 0.1, GOD)
	for i = 0, 3 do
		local a = i * PI / 2 + PI / 2
		k.b(rp, "RingGemFrame", 0.4, 0.4, 0.16, GO, k.c(math.cos(a) * 1.5, math.sin(a) * 1.5, 0))
		local _, g = k.b(rp, "RingGem", 0.24, 0.24, 0.18, CY, k.c(math.cos(a) * 1.5, math.sin(a) * 1.5, -0.02), MAT.Neon)
		k.glow(g, CY)
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.7, 0.4, 0.1))
		k.bar(w, "WingArm", V3(0, 0, 0), V3(sd * 1.0, 1.6, 0), 0.55, PU)
		k.bar(w, "WingArm", V3(sd * 1.0, 1.6, 0), V3(sd * 2.0, 2.4, 0), 0.45, PUL)
		local _, st = k.bar(w, "WingGlow", V3(sd * 0.3, 0.6, -0.3), V3(sd * 1.5, 1.95, -0.25), 0.08, CY, MAT.Neon)
		k.glow(st, CY)
		k.b(w, "WristGemFrame", 0.45, 0.45, 0.2, GO, c(sd * 0.3, 0.35, -0.2))
		local _, wg = k.b(w, "WristGem", 0.24, 0.24, 0.22, CY, c(sd * 0.3, 0.35, -0.22), MAT.Neon)
		k.glow(wg, CY)
		local fw = {}
		for i = 0, 7 do table.insert(fw, { 1.1 - i * 0.26, 2.3 - math.abs(i - 2) * 0.14, 0.38, (i % 3 == 2) and GOD or GO }) end
		k.featherWing(w, sd, { root = 0.4, z = 0.05, feathers = fw })
	end
	local te, tp = k.pv(body, "TailRoot", c(0, -0.5, 0.6) * ANG(1.1, 0, 0))
	table.insert(rig.tail, te)
	for i, a in ipairs({ -0.4, -0.13, 0.13, 0.4 }) do
		k.tri(tp, "TailFeather", 0.1, 1.4, 0.4, (i % 2 == 0) and GO or PU, ANG(0, 0, a) * c(0, 0.65, 0) * FACE)
	end
end

---------------------------------------------------------------- GENESIS (Divine)
-- Creator dragon: white armoured body with gold trim and a cyan chest gem, gold-clawed legs, spiky
-- white mane, white head with a long gold unicorn horn and swept gold horns, a horizontal gold halo,
-- a gold arc behind with crystal shards and a crystal floating above, a crystal orb in a broken gold
-- ring floating at its claw, angular wings (white bones, gold edges, translucent cyan panels), a
-- spiked white tail with a gold ring and a cyan crystal tip.
function M.Genesis(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, WD, GO, CY, EY = C("#F5F3F6"), C("#E2DEE6"), C("#F0C43A"), C("#9FEFF5"), C("#3FD8E8")
	local BY = 2.3
	local body = k.body(1.7, 1.5, 2.3, W, BY)
	k.b(body, "ChestFrame", 0.75, 0.75, 0.12, GO, c(0, 0.15, -1.2) * ANG(0, 0, PI / 4))
	k.diamond(body, "ChestGem", 0.8, 0.5, 0.16, CY, c(0, 0.15, -1.26), MAT.Glass)
	for _, sd in ipairs(SIDES) do
		k.b(body, "ShoulderFrame", 0.12, 0.8, 0.8, GO, c(sd * 0.86, 0.15, -0.6))
		k.b(body, "ShoulderPlate", 0.1, 0.6, 0.6, W, c(sd * 0.92, 0.15, -0.6))
	end
	for i = 0, 4 do
		k.tri(body, "BackSpike", 0.12, 0.55, 0.45, GO, c(0, 0.85, -0.8 + i * 0.45) * ANG(0.5, 0, 0))
	end

	local lf = { up = { 0.8, 0.75, 0.9 }, col = W, w2 = 0.66, d2 = 0.72, band = GO, paw = { 0.92, 0.35, 1.05 }, pawCol = W, toes = 3, toeCol = GO }
	k.leg(body, "LegFL", BY, -0.72, -0.5, -0.8, lf)
	k.leg(body, "LegFR", BY, 0.72, -0.5, -0.8, lf)
	lf.hind = true
	k.leg(body, "LegBL", BY, -0.74, -0.45, 0.85, lf)
	k.leg(body, "LegBR", BY, 0.74, -0.45, 0.85, lf)
	rig.legKind = "quad"

	-- crystal orb in a broken gold ring, floating at the front claw
	local oe, op = k.pv(body, "Orb", c(0.95, 0.6, -1.7))
	H.group(rig, "palmCrystal", oe)
	k.crystal(op, "OrbCrystal", 0.6, 0.28, CY, k.c(0, -0.3, 0), MAT.Glass, 0.1)
	k.ring(op, "OrbRing", CF(), 0.5, 8, 0.1, 0.25, 0.1, GO)

	k.b(body, "Neck", 0.75, 1.2, 0.75, W, c(0, 0.95, -1.3) * ANG(-0.35, 0, 0))
	for i = 0, 3 do
		local sd = (i % 2 == 0) and -1 or 1
		k.tri(body, "Mane", 0.12, 0.8, 0.45, (i < 2) and W or WD, c(sd * 0.4, 1.3 - i * 0.2, -1.2) * ANG(0.4, 0, -sd * 1.0))
	end
	local head = k.head(body, 0.9, 0.75, 1.1, W, c(0, 1.85, -1.75), V3(0, -0.3, 0.4))
	k.w(head, "Snout", 0.62, 0.42, 0.6, W, c(0, -0.12, -0.8))
	k.spike(head, "UnicornHorn", 1.8, 0.3, GO, c(0, 0.35, -0.35) * ANG(-0.55, 0, 0))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.26, 0.1, -0.56, 0.22, 0.09, EY, sd * 0.3)
		k.spike(head, "Horn", 1.0, 0.24, GO, c(sd * 0.32, 0.35, 0.25) * ANG(1.1, 0, -sd * 0.4))
		k.tri(head, "Frill", 0.1, 0.6, 0.4, W, c(sd * 0.5, 0.0, 0.25) * ANG(0.6, 0, -sd * 1.2))
	end
	halo(k, head, c(0, 1.0, 0.1), 0.8, 12, GO)
	local ae, ap = k.pv(head, "Arc", c(0, 0.6, 0.8))
	H.group(rig, "rays", ae)
	for i = 0, 6 do
		local a = PI * 0.15 + i / 6 * PI * 0.7
		k.b(ap, "ArcSeg", 0.18, 0.5, 0.16, GO, k.c(math.cos(a) * 1.5, math.sin(a) * 1.5, 0) * ANG(0, 0, a))
		if i % 3 == 0 then k.crystal(ap, "ArcShard", 0.45, 0.16, CY, k.c(math.cos(a) * 1.75, math.sin(a) * 1.75, 0) * ANG(0, 0, a - PI / 2), MAT.Glass, 0.1) end
	end
	k.crystal(head, "FloatingCrystal", 0.7, 0.24, CY, c(0, 1.5, 0.1), MAT.Glass, 0.1)

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.75, 0.6, -0.2))
		k.batWing(w, sd, { wrist = Vector2.new(1.6, 2.2), bone = W, mem = CY, memMat = MAT.Glass, memTr = 0.3, boneW = 0.36, cap = GO,
			tips = { Vector2.new(4.2, 1.6), Vector2.new(3.8, 0.2), Vector2.new(2.8, -0.7), Vector2.new(1.4, -0.8) } })
		k.bar(w, "WingEdge", V3(sd * 1.6, 2.2, -0.08), V3(sd * 4.2, 1.6, -0.08), 0.18, GO)
	end

	local segs = {}
	for j = 1, 9 do
		local w = 0.7 - j * 0.045
		table.insert(segs, { w, w * 0.85, 0.55, (j % 2 == 0) and WD or W, j == 1 and 0.35 or -0.06 })
	end
	local rec = k.chain(body, c(0, 0.1, 1.1), segs, { name = "Tail", kind = "spine", i = 1, amp = 0.15, freq = 1.2, lag = 0.55 })
	for j, p in ipairs(rec.parts) do
		local w = 0.7 - j * 0.045
		k.tri(p, "TailSpike", 0.1, 0.35, 0.3, GO, c(0, w * 0.42 + 0.14, 0) * ANG(0.4, 0, 0))
	end
	local last = rec.parts[#rec.parts]
	k.ring(last, "TailRing", k.c(0, 0, 0.1), 0.45, 8, 0.1, 0.36, 0.1, GO)
	k.crystal(last, "TailCrystal", 0.9, 0.3, CY, c(0, 0, 0.3) * ANG(PI / 2, 0, 0), MAT.Glass, 0.1)
end

---------------------------------------------------------------- INFINITY FOX (Divine)
-- Void fox spirit: dark-purple body with pink stripe plates and cyan diamond gems, slim legs with pink
-- bands, fox head with tall pink-lined ears, a cyan forehead gem and glowing cyan eyes, angular wings
-- (purple blades with pink and cyan glow stripes), a double pink halo with a floating diamond, and nine
-- segmented tails fanning out behind it (purple/pink links ending in diamond tips with cyan cores).
function M.Infinity(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUL, PK, PKL, CY, EY = C("#3A1F5E"), C("#5A3290"), C("#F27AC8"), C("#F5A8DC"), C("#7FF0F5"), C("#7FF0F5")
	local BY = 2.1
	local body = k.body(1.0, 1.0, 1.8, PU, BY)
	for _, sd in ipairs(SIDES) do
		k.b(body, "Stripe", 0.06, 0.2, 1.5, PK, c(sd * 0.51, 0.25, 0))
		k.diamond(body, "HipGem", 0.55, 0.32, 0.08, CY, c(sd * 0.54, -0.05, 0.5) * ANG(0, -sd * PI / 2, 0), MAT.Glass)
		k.diamond(body, "ShoulderGem", 0.45, 0.28, 0.08, CY, c(sd * 0.54, -0.05, -0.5) * ANG(0, -sd * PI / 2, 0), MAT.Glass)
	end
	k.b(body, "Collar", 1.05, 0.3, 0.3, PK, c(0, 0.4, -0.85))

	local lg = { up = { 0.4, 0.8, 0.48 }, col = PU, w2 = 0.32, d2 = 0.4, band = PK, paw = { 0.4, 0.34, 0.48 }, pawCol = PUL }
	k.leg(body, "LegFL", BY, -0.3, -0.4, -0.7, lg)
	k.leg(body, "LegFR", BY, 0.3, -0.4, -0.7, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.3, -0.4, 0.7, lg)
	k.leg(body, "LegBR", BY, 0.3, -0.4, 0.7, lg)
	rig.legKind = "quad"

	k.b(body, "Neck", 0.55, 0.9, 0.6, PU, c(0, 0.7, -0.9) * ANG(-0.35, 0, 0))
	local head = k.head(body, 0.75, 0.7, 0.85, PU, c(0, 1.3, -1.25), V3(0, -0.3, 0.3))
	k.w(head, "Snout", 0.45, 0.34, 0.6, PUL, c(0, -0.15, -0.7))
	k.b(head, "Nose", 0.14, 0.1, 0.08, C("#1A0E2A"), c(0, -0.27, -0.97))
	k.diamond(head, "ForeheadGem", 0.28, 0.18, 0.06, CY, c(0, 0.2, -0.44), MAT.Glass)
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.2, 0.08, -0.44, 0.2, 0.09, EY, sd * 0.35)
		k.tri(head, "Cheek", 0.1, 0.5, 0.35, PKL, c(sd * 0.45, -0.15, 0.05) * ANG(0, 0, -sd * 1.4))
		local ear = k.ear(head, sd, c(sd * 0.24, 0.32, 0.1) * ANG(0, 0, -sd * 0.15))
		k.tri(ear, "Ear", 0.16, 0.9, 0.5, PU, c(0, 0.45, 0) * FACE)
		k.tri(ear, "EarInner", 0.06, 0.6, 0.28, PK, c(0, 0.36, -0.09) * FACE)
	end
	local hp = halo(k, head, c(0, 0.95, 0.2), 0.75, 10, PK)
	k.ring(hp, "HaloOuter", FLAT * CF(0, 0, -0.25 * s), 1.05, 12, 0.1, 0.5, 0.1, PKL)
	k.diamond(hp, "HaloDiamond", 0.55, 0.32, 0.1, CY, k.c(0, 0.55, -1.05), MAT.Glass)

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.45, 0.45, -0.2))
		k.featherWing(w, sd, { root = 0.1, z = 0.06, thick = 0.16, feathers = {
			{ 1.25, 2.6, 0.55, PU, PUL }, { 1.0, 2.3, 0.5, PK, PK }, { 0.75, 1.9, 0.45, PU, PUL } } })
		local _, gl = k.bar(w, "WingGlow", V3(sd * 0.3, 0.9, -0.12), V3(sd * 0.75, 2.2, -0.12), 0.1, CY, MAT.Neon)
		k.glow(gl, CY)
	end

	-- nine fan tails radiating in a lower semicircle behind the body (fan chains, roster check: exactly 9)
	local hub = c(0, -0.05, 0.95)
	k.b(body, "TailHub", 0.7, 0.7, 0.3, PUL, hub)
	for i = 1, 9 do
		local th = (i - 5) * 0.55
		local radial = V3(math.sin(th), -math.cos(th), 0)
		local dir = (radial * 0.75 + V3(0, 0, 1)).Unit
		local pos = V3(0, -0.05, 1.05) + radial * 0.3
		local segs = {}
		for j = 1, 5 do
			table.insert(segs, { 0.2, 0.2, 0.42, (j % 2 == 0) and PK or PU, 0 })
		end
		local rec = k.chain(body, CFrame.lookAt(pos * s, (pos - dir) * s), segs,
			{ name = "FanTail", kind = "fan", i = i, n9 = 9, baseYaw = (i - 5) * 0.04, amp = 0.18, freq = 1.6, lag = 0.55 })
		local last = rec.parts[#rec.parts]
		local tip = k.c(0, 0, 0.55) * ANG(PI / 2, 0, 0)
		k.diamond(last, "TailTip", 0.75, 0.42, 0.12, PU, tip)
		k.diamond(last, "TailCore", 0.45, 0.24, 0.14, CY, tip, MAT.Glass)
	end
end

return M
