-- SpeciesModelsHeaven: hand-authored, reference-faithful models for the Heaven world
-- (Cloud Lamb, Halo Chick, Seraphling, Golden Griffin, Celestial Pegasus, Seraph Lion, Archangel Drake,
-- Throne Guardian).
-- Location: ReplicatedStorage > Shared > SpeciesModelsHeaven (ModuleScript), merged into SpeciesModels.

local K = require(script.Parent.ModelKit)
local V3, CF, ANG, PI, MAT, C = K.V3, K.CF, K.ANG, K.PI, K.MAT, K.C
local FACE, DOWN = ANG(0, PI / 2, 0), ANG(0, 0, PI)
local FLAT = ANG(PI / 2, 0, 0)
local SIDES = { -1, 1 }

local M = {}

-- horizontal halo floating and turning above `parent`
local function halo(k, parent, cf, radius, count, col, thick)
	local e, p = k.pv(parent, "HaloPivot", cf)
	table.insert(k.rig.halos, e)
	k.ring(p, "Halo", FLAT, radius, count, thick or 0.16, radius * 6.3 / count + 0.03, thick or 0.16, col)
	return p, e
end

-- inner feather row from the shoulder, filling the wing between body and wrist
local function innerFeathers(k, w, side, colA, colB)
	k.featherWing(w, side, { root = 0.25, z = 0.07, feathers = {
		{ 0.75, 1.5, 0.42, colA }, { 0.4, 1.7, 0.42, colB }, { 0.05, 1.7, 0.42, colA }, { -0.3, 1.5, 0.4, colB } } })
end

-- curled horn as a chain of bars through `pts` (head-local units)
local function curl(k, parent, pts, w0, col, col2)
	for i = 1, #pts - 1 do
		k.bar(parent, "Horn", pts[i], pts[i + 1], w0 - i * 0.03, (col2 and i % 2 == 0) and col2 or col, nil, nil, V3(0, 0, 1))
	end
end

---------------------------------------------------------------- CLOUD LAMB (Common)
-- Woolly lamb: white block body with stepped cream wool tufts on the flanks and chest, dark hooves,
-- white head with a wool cap, glowing pink eyes, floppy white ears with pink insides, big cream curled
-- ram horns, a wool tuft tail.
function M.CloudLamb(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, WD, CR, HN, DK, P, EY = C("#F2F0F2"), C("#E2DEE4"), C("#F0E2BE"), C("#EED9A8"), C("#4A4A50"), C("#F5A8C8"), C("#FF5A9A")
	local BY = 1.6
	local body = k.body(1.7, 1.3, 2.0, W, BY)
	for _, sd in ipairs(SIDES) do
		for i, d in ipairs({ { -0.6, -0.35 }, { 0.1, -0.5 }, { 0.75, -0.3 }, { -0.2, 0.25 }, { 0.5, 0.3 } }) do
			k.b(body, "Wool", 0.25, 0.45, 0.6, (i % 2 == 0) and CR or W, c(sd * 0.92, d[2], d[1]))
		end
	end
	for i = 0, 2 do k.b(body, "BackWool", 0.9 - i * 0.15, 0.3, 0.55, (i % 2 == 0) and CR or WD, c(0, 0.75, -0.5 + i * 0.55)) end
	k.b(body, "ChestWool", 1.3, 0.8, 0.3, CR, c(0, -0.1, -1.05))
	k.b(body, "ChestWool2", 0.8, 0.4, 0.3, CR, c(0, -0.6, -1.0))
	local lg = { up = { 0.6, 0.5, 0.65 }, col = W, w2 = 0.52, d2 = 0.58, paw = { 0.6, 0.35, 0.7 }, pawCol = DK }
	k.leg(body, "LegFL", BY, -0.5, -0.5, -0.65, lg)
	k.leg(body, "LegFR", BY, 0.5, -0.5, -0.65, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.5, -0.5, 0.65, lg)
	k.leg(body, "LegBR", BY, 0.5, -0.5, 0.65, lg)
	rig.legKind = "quad"

	local head = k.head(body, 1.0, 1.0, 1.1, W, c(0, 0.95, -1.2), V3(0, -0.4, 0.35))
	k.b(head, "Snout", 0.85, 0.5, 0.45, W, c(0, -0.25, -0.7))
	k.b(head, "WoolCap", 1.05, 0.3, 0.9, W, c(0, 0.6, 0.05))
	k.b(head, "WoolCapFront", 0.7, 0.25, 0.3, WD, c(0, 0.5, -0.5))
	k.b(head, "EyeBand", 0.8, 0.2, 0.06, C("#3A2A3A"), c(0, 0.1, -0.56))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.2, 0.1, -0.59, 0.2, 0.1, EY, sd * 0.2)
		-- floppy ear hanging out and down in front of the horn curl
		local ear = k.ear(head, sd, c(sd * 0.5, 0.05, -0.3) * ANG(0, 0, sd * 0.7), "floppy")
		k.b(ear, "Ear", 0.14, 0.85, 0.48, W, c(0, -0.38, 0))
		k.b(ear, "EarInner", 0.06, 0.6, 0.28, P, c(-sd * 0.06, -0.4, -0.04))
		-- ram horn: a spiral lying in the side plane (reads as a circle from the side)
		curl(k, head, { V3(sd * 0.42, 0.45, 0.05), V3(sd * 0.6, 0.85, 0.35), V3(sd * 0.68, 0.7, 0.8), V3(sd * 0.72, 0.2, 0.85),
			V3(sd * 0.75, -0.05, 0.45), V3(sd * 0.78, 0.15, 0.15), V3(sd * 0.8, 0.45, 0.35) }, 0.44, HN)
	end
	k.tail(body, c(0, 0.3, 1.0), { { 0.55, 0.5, 0.4, -0.4, CR } })
end

---------------------------------------------------------------- HALO CHICK (Uncommon)
-- Big-headed pale-yellow chick: white V bib, gold beak, glowing gold eyes, a gold crest, a gold halo on a
-- little stalk, small wings (white blades with gold edges), stubby gold legs with three-toed feet.
function M.HaloChick(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local Y, YD, GO, W, EY = C("#F7EFA8"), C("#EEDF86"), C("#F2C230"), C("#F6F4F0"), C("#FFC81E")
	local BY = 1.5
	local body = k.body(1.3, 1.25, 1.2, Y, BY)
	k.tri(body, "Bib", 0.12, 0.8, 1.0, W, c(0, -0.1, -0.62) * DOWN * FACE)
	local lg = { up = { 0.38, 0.35, 0.42 }, col = GO, w2 = 0.3, d2 = 0.34, paw = { 0.7, 0.2, 0.75, -0.12 }, pawCol = GO, toes = 3, toeCol = GO }
	k.leg(body, "LegL", BY, -0.33, -0.6, 0.05, lg)
	k.leg(body, "LegR", BY, 0.33, -0.6, 0.05, lg)
	rig.legKind = "biped"

	local head = k.head(body, 1.2, 1.1, 1.1, Y, c(0, 1.2, -0.15), V3(0, -0.45, 0.2))
	k.w(head, "Beak", 0.42, 0.35, 0.45, GO, c(0, -0.12, -0.75))
	k.b(head, "BeakLow", 0.3, 0.12, 0.25, YD, c(0, -0.32, -0.65))
	for _, sd in ipairs(SIDES) do
		k.b(head, "EyeSocket", 0.32, 0.18, 0.05, C("#5A4A20"), c(sd * 0.28, 0.12, -0.56))
		k.eye(head, sd * 0.28, 0.12, -0.58, 0.26, 0.12, EY, sd * 0.25)
	end
	k.b(head, "Crest", 0.3, 0.4, 0.5, GO, c(0.05, 0.7, -0.1) * ANG(0.3, 0, 0))
	k.b(head, "Crest2", 0.26, 0.3, 0.4, GO, c(0.05, 0.65, 0.25) * ANG(0.6, 0, 0))
	k.b(head, "HaloStalk", 0.12, 0.6, 0.12, GO, c(0, 0.9, 0))
	halo(k, head, c(0, 1.25, 0), 0.6, 8, GO, 0.18)

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.62, 0.25, 0.05))
		k.featherWing(w, sd, { root = 0.1, z = 0.04, thick = 0.14, feathers = { { 0.5, 1.2, 0.36, W }, { 0.2, 1.1, 0.36, W }, { -0.1, 0.9, 0.34, Y } } })
		k.bar(w, "WingEdge", V3(sd * 0.1, 0.05, -0.08), V3(sd * 1.2, 0.65, -0.08), 0.12, GO)
	end
	k.tail(body, c(0, 0.15, 0.55), { { 0.7, 0.35, 0.5, -0.4, Y } })
end

---------------------------------------------------------------- SERAPHLING (Rare)
-- Small armoured angel: cream torso with a gold triangle gem, white tabard with gold border, cream plated
-- skirt, legs with white boots and gold bands, arms with white cuffs and fists, cream helmet with white
-- fin crests and glowing gold eyes, gold halo, big layered white/cream wings with gold stripes.
function M.Seraphling(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local CR, CRD, W, GO, EY = C("#F2E6CC"), C("#E2D2B0"), C("#F7F7F5"), C("#F5C83A"), C("#FFD84A")
	local BY = 2.3
	local body = k.body(0.9, 0.9, 0.6, CR, BY)
	k.tri(body, "ChestGem", 0.1, 0.35, 0.45, GO, c(0, 0.15, -0.32) * DOWN * FACE)
	k.b(body, "Belt", 0.95, 0.15, 0.65, GO, c(0, -0.45, 0))
	local te, tp = k.pv(body, "Tabard", c(0, -0.5, -0.32))
	table.insert(rig.tail, te)
	k.b(tp, "TabardBorder", 0.42, 0.95, 0.06, GO, c(0, -0.45, 0))
	k.b(tp, "Tabard", 0.3, 0.85, 0.08, W, c(0, -0.42, -0.02))
	for _, sd in ipairs(SIDES) do
		k.b(body, "SkirtPlate", 0.35, 0.6, 0.55, CRD, c(sd * 0.32, -0.75, 0.02) * ANG(0, 0, sd * 0.15))
		k.b(body, "Shoulder", 0.4, 0.35, 0.5, CR, c(sd * 0.58, 0.32, 0))
	end
	local lg = { up = { 0.3, 0.45, 0.32 }, col = CR, w2 = 0.28, d2 = 0.3, band = GO, bandY = 0.25, paw = { 0.32, 0.25, 0.36 }, pawCol = W, lh = 0.45 }
	k.leg(body, "LegL", BY, -0.2, -0.5, 0, lg)
	k.leg(body, "LegR", BY, 0.2, -0.5, 0, lg)
	rig.legKind = "biped"
	for _, sd in ipairs(SIDES) do
		local a = k.arm(body, sd, c(sd * 0.6, 0.2, 0))
		k.b(a, "UpperArm", 0.28, 0.5, 0.28, CR, c(sd * 0.05, -0.25, 0))
		k.b(a, "Cuff", 0.32, 0.22, 0.32, W, c(sd * 0.08, -0.6, -0.05))
		k.b(a, "Fist", 0.3, 0.3, 0.3, CR, c(sd * 0.08, -0.85, -0.08))
	end

	local head = k.head(body, 0.6, 0.55, 0.55, CR, c(0, 0.75, 0), V3(0, -0.27, 0.05))
	k.b(head, "Visor", 0.5, 0.2, 0.05, C("#5A4A30"), c(0, 0.0, -0.29))
	k.w(head, "FaceGuard", 0.45, 0.25, 0.15, W, c(0, -0.2, -0.3) * DOWN)
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.12, 0.0, -0.31, 0.14, 0.07, EY, sd * 0.3)
		k.tri(head, "Fin", 0.08, 0.5, 0.3, W, c(sd * 0.28, 0.3, 0.05) * ANG(0, 0, -sd * 0.4) * FACE)
	end
	k.tri(head, "CrestFin", 0.08, 0.55, 0.35, W, c(0, 0.45, 0))
	halo(k, head, c(0, 0.7, 0), 0.5, 10, GO, 0.1)

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.4, 0.25, 0.25) * ANG(0, -sd * 0.3, 0))
		k.bar(w, "WingArm", V3(0, 0, 0), V3(sd * 1.2, 1.0, 0), 0.32, CR)
		k.bar(w, "WingStripe", V3(sd * 0.3, 0.35, -0.12), V3(sd * 1.1, 1.0, -0.12), 0.1, GO)
		local _, fp = k.pv(w, "FeatherRoot", c(sd * 0.9, 0.85, 0.03))
		k.featherWing(fp, sd, { root = 0.1, z = 0.04, feathers = {
			{ 0.4, 1.6, 0.38, W }, { 0.05, 1.8, 0.38, CR }, { -0.35, 1.7, 0.38, W }, { -0.75, 1.4, 0.36, CR }, { -1.1, 1.0, 0.34, W } } })
	end
end

---------------------------------------------------------------- GOLDEN GRIFFIN (Epic)
-- Eagle-lion: golden body, eagle front with a layered cream feather bib, eagle front legs with cream
-- cuffs and bronze talons, lion hind legs with cream paws, eagle head with cream face, hooked beak,
-- glowing eyes and a bronze crown with a gem, raised golden wings with cream feathers, lion tail ending
-- in a cream feather fan.
function M.GoldGriffin(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local Y, YD, YL, CR, BR, EY = C("#F5C42E"), C("#DFA21E"), C("#F7D35A"), C("#F2DDB0"), C("#B9741E"), C("#FFE45C")
	local BY = 2.2
	local body = k.body(1.7, 1.5, 2.4, Y, BY)
	k.b(body, "Chest", 1.6, 1.5, 0.8, YL, c(0, 0.05, -1.1))
	for i = 0, 2 do
		for _, x in ipairs({ -0.35, 0, 0.35 }) do
			k.tri(body, "Bib", 0.12, 0.75, 0.42, (i % 2 == 0) and CR or C("#FFF4DC"), c(x, 0.45 - i * 0.4, -1.52 - i * 0.03) * DOWN * FACE)
		end
	end
	local lf = { up = { 0.7, 0.75, 0.8 }, col = Y, w2 = 0.55, d2 = 0.6, band = CR, paw = { 0.85, 0.35, 0.95 }, pawCol = Y, toes = 3, toeCol = BR }
	k.leg(body, "LegFL", BY, -0.6, -0.5, -0.85, lf)
	k.leg(body, "LegFR", BY, 0.6, -0.5, -0.85, lf)
	local lh = { up = { 0.8, 0.8, 0.95 }, col = Y, w2 = 0.6, d2 = 0.7, paw = { 0.8, 0.35, 0.9 }, pawCol = CR, toes = 3, toeCol = CR, hind = true }
	k.leg(body, "LegBL", BY, -0.62, -0.45, 0.85, lh)
	k.leg(body, "LegBR", BY, 0.62, -0.45, 0.85, lh)
	rig.legKind = "quad"

	local head = k.head(body, 0.95, 0.9, 1.0, Y, c(0, 1.3, -1.45), V3(0, -0.4, 0.3))
	k.b(head, "Face", 0.97, 0.6, 0.6, CR, c(0, -0.1, -0.22))
	k.w(head, "Beak", 0.45, 0.4, 0.55, YD, c(0, -0.05, -0.75))
	k.b(head, "BeakHook", 0.3, 0.3, 0.15, BR, c(0, -0.25, -1.0))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.4, 0.14, 0.2, YD, c(sd * 0.25, 0.22, -0.52) * ANG(0, 0, sd * 0.3))
		k.eye(head, sd * 0.25, 0.08, -0.53, 0.22, 0.1, EY, sd * 0.3)
	end
	k.b(head, "CrownBand", 0.9, 0.2, 0.85, BR, c(0, 0.52, 0))
	for i = -1, 1 do k.b(head, "Crenel", 0.18, 0.25, 0.18, BR, c(i * 0.33, 0.72, -0.35)) end
	k.diamond(head, "CrownGem", 0.35, 0.22, 0.08, YL, c(0, 0.55, -0.45), MAT.Glass)

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.75, 0.6, -0.3))
		k.bar(w, "WingArm", V3(0, 0, 0), V3(sd * 1.3, 2.3, 0), 0.42, Y)
		k.bar(w, "WingArm", V3(sd * 1.3, 2.3, 0), V3(sd * 3.4, 2.9, 0), 0.34, YD)
		local _, fp = k.pv(w, "FeatherRoot", c(sd * 1.2, 2.0, 0.04))
		local fw = {}
		for i = 0, 6 do table.insert(fw, { 0.5 - i * 0.22, 2.7 - math.abs(i - 1) * 0.2, 0.45, (i % 2 == 0) and CR or YL }) end
		k.featherWing(fp, sd, { root = 0.1, z = 0.04, feathers = fw })
		innerFeathers(k, w, sd, CR, YL)
	end

	local tip = k.tail(body, c(0, 0.2, 1.2), { { 0.3, 0.3, 0.7, 0.3, Y }, { 0.28, 0.28, 0.7, -0.4, Y }, { 0.26, 0.26, 0.6, -0.4, Y } })
	for _, a in ipairs({ -0.5, 0, 0.5 }) do
		k.tri(tip, "TailFeather", 0.1, 0.8, 0.3, CR, c(0, 0, 0.35) * ANG(PI / 2 - 0.3, a, 0) * c(0, 0.35, 0))
	end
end

---------------------------------------------------------------- CELESTIAL PEGASUS (Legendary)
-- Armoured white pegasus: gold trim and a gold star on the chest, long legs with gold bands and gold
-- hooves, pale-blue flowing mane with gold edging, a gold halo, huge wings (gold leading edge, white and
-- pale-blue feathers), long flowing blue and white tail ribbons.
function M.Pegasus(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, WD, BL, GO, EY = C("#F7F8FA"), C("#E4E8EE"), C("#B8D4F0"), C("#F2C230"), C("#FFE45C")
	local BY = 2.9
	local body = k.body(1.35, 1.3, 2.7, W, BY)
	k.b(body, "ChestPlate", 1.4, 1.2, 0.6, W, c(0, 0.05, -1.25))
	k.diamond(body, "ChestStar", 0.8, 0.5, 0.12, GO, c(0, 0.05, -1.57))
	k.diamond(body, "ChestStar2", 0.5, 0.8, 0.1, GO, c(0, 0.05, -1.56))
	for _, sd in ipairs(SIDES) do
		k.b(body, "Trim", 0.08, 0.14, 2.2, GO, c(sd * 0.69, 0.45, 0))
		k.b(body, "HipShield", 0.12, 0.8, 0.8, GO, c(sd * 0.7, 0.05, 0.9) * ANG(PI / 4, 0, 0))
		k.b(body, "HipShieldIn", 0.14, 0.6, 0.6, W, c(sd * 0.71, 0.05, 0.9) * ANG(PI / 4, 0, 0))
	end
	local lf = { up = { 0.55, 1.0, 0.65 }, col = W, w2 = 0.42, d2 = 0.5, band = GO, bandY = 0.3, paw = { 0.52, 0.4, 0.62 }, pawCol = GO, toes = 2, toeCol = GO }
	k.leg(body, "LegFL", BY, -0.42, -0.5, -1.0, lf)
	k.leg(body, "LegFR", BY, 0.42, -0.5, -1.0, lf)
	lf.hind = true
	k.leg(body, "LegBL", BY, -0.42, -0.45, 1.0, lf)
	k.leg(body, "LegBR", BY, 0.42, -0.45, 1.0, lf)
	rig.legKind = "quad"

	k.b(body, "Neck", 0.7, 1.45, 0.75, W, c(0, 1.05, -1.4) * ANG(-0.4, 0, 0))
	local head = k.head(body, 0.7, 0.7, 1.3, W, c(0, 1.95, -2.0), V3(0, -0.2, 0.5))
	k.w(head, "Snout", 0.6, 0.42, 0.6, W, c(0, -0.1, -0.85))
	k.b(head, "Faceplate", 0.72, 0.14, 0.8, GO, c(0, 0.36, -0.2))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.28, 0.12, -0.66, 0.18, 0.09, EY, sd * 0.3)
		local ear = k.ear(head, sd, c(sd * 0.24, 0.38, 0.2))
		k.tri(ear, "Ear", 0.12, 0.45, 0.28, W, c(0, 0.22, 0) * FACE)
	end
	halo(k, head, c(0, 0.9, 0.1), 0.6, 12, GO)
	local maneCols = { BL, W, BL, BL, W, BL, BL }
	for i = 1, 7 do
		local me, mp = k.pv(body, "ManeRoot", c(0, 1.8 - (i - 1) * 0.2, -1.55 + (i - 1) * 0.12) * ANG(0.9 + i * 0.07, 0, 0))
		if i % 2 == 0 then H.group(rig, "flutter", me) end
		k.tri(mp, "Mane", 0.25, 1.4 - i * 0.05, 0.6, maneCols[i], c(0, 0.65, 0))
		k.tri(mp, "ManeGold", 0.27, 0.6, 0.15, GO, c(0, 0.4, 0.22))
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.65, 0.6, -0.5))
		k.bar(w, "WingArm", V3(0, 0, 0), V3(sd * 1.2, 2.3, 0), 0.38, GO)
		k.bar(w, "WingArm", V3(sd * 1.2, 2.3, 0), V3(sd * 3.4, 3.1, 0), 0.3, GO)
		local _, fp = k.pv(w, "FeatherRoot", c(sd * 1.1, 2.0, 0.04))
		local fw = {}
		for i = 0, 6 do table.insert(fw, { 0.55 - i * 0.22, 2.8 - math.abs(i - 1) * 0.2, 0.42, (i % 2 == 0) and W or BL }) end
		k.featherWing(fp, sd, { root = 0.1, z = 0.04, feathers = fw })
		innerFeathers(k, w, sd, W, BL)
	end

	for i, d in ipairs({ { -0.2, BL }, { 0.1, W }, { 0.4, BL } }) do
		local segs = {}
		for j = 1, 4 do table.insert(segs, { 0.14, 0.75 - j * 0.06, 0.75, d[2], j == 1 and (0.5 + d[1]) or 0.15 }) end
		local rec = k.chain(body, c(d[1] * 0.4, 0.4, 1.35), segs, { name = "TailRibbon", kind = "trail", i = i, amp = 0.14, freq = 1.2, lag = 0.5 })
		k.b(rec.parts[2], "RibbonGold", 0.16, 0.12, 0.7, GO, c(0, 0.3, 0))
	end
end

---------------------------------------------------------------- SERAPH LION (Legendary)
-- Celestial lion: cream body with gold-framed shields on the hips, legs with gold bands and big cream
-- paws, a huge mane of white and gold blades, cream head with muzzle, dark nose, glowing gold eyes and a
-- forehead gem, a gold halo, raised white wings with gold tips, a tail ending in a white-and-gold tuft.
function M.SeraphLion(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local CR, CRD, W, GO, N, EY = C("#F2E6C8"), C("#E2D2AE"), C("#F7F7F5"), C("#F2C02E"), C("#4A4A4A"), C("#FFD23A")
	local BY = 2.0
	local body = k.body(1.8, 1.5, 2.6, CR, BY)
	for _, sd in ipairs(SIDES) do
		k.b(body, "HipShield", 0.12, 0.9, 0.75, GO, c(sd * 0.91, 0.1, 0.8))
		k.b(body, "HipShieldIn", 0.14, 0.7, 0.55, W, c(sd * 0.92, 0.1, 0.8))
		k.diamond(body, "HipGem", 0.45, 0.25, 0.06, GO, c(sd * 0.96, 0.1, 0.8) * ANG(0, -sd * PI / 2, 0))
	end
	local lg = { up = { 0.85, 0.7, 0.95 }, col = CR, w2 = 0.75, d2 = 0.82, band = GO, paw = { 0.95, 0.38, 1.1 }, pawCol = CR, toes = 3, toeCol = CRD }
	k.leg(body, "LegFL", BY, -0.6, -0.5, -0.9, lg)
	k.leg(body, "LegFR", BY, 0.6, -0.5, -0.9, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.6, -0.5, 0.95, lg)
	k.leg(body, "LegBR", BY, 0.6, -0.5, 0.95, lg)
	rig.legKind = "quad"

	local head = k.head(body, 1.1, 1.0, 1.0, CR, c(0, 1.0, -1.65), V3(0, -0.4, 0.35))
	k.b(head, "Muzzle", 0.65, 0.42, 0.45, CR, c(0, -0.28, -0.62))
	k.b(head, "Nose", 0.25, 0.14, 0.1, N, c(0, -0.1, -0.86))
	k.b(head, "Jaw", 0.5, 0.18, 0.35, CRD, c(0, -0.5, -0.55))
	k.diamond(head, "ForeheadGem", 0.35, 0.22, 0.08, GO, c(0, 0.28, -0.52))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.38, 0.12, 0.15, CRD, c(sd * 0.25, 0.14, -0.5) * ANG(0, 0, sd * 0.3))
		k.eye(head, sd * 0.25, 0.04, -0.51, 0.22, 0.09, EY, sd * 0.3)
	end
	-- mane: two rings of white/gold blades around the face
	local me, mp = k.pv(head, "Mane", c(0, 0.05, 0.1))
	for ring = 0, 1 do
		for i = 0, 9 do
			local a = (i + ring * 0.5) / 10 * PI * 2
			local col = ((i + ring) % 2 == 0) and GO or W
			-- broad blade facing forward, radiating out from the face and swept back
			k.tri(mp, "Mane", 0.14, 1.35 - ring * 0.3, 0.75, col, CF(math.sin(a) * 0.82 * s, math.cos(a) * 0.75 * s, (-0.1 + ring * 0.35) * s) * ANG(0, 0, -a) * ANG(0.3 + ring * 0.25, 0, 0) * c(0, 0.55, 0) * FACE)
		end
	end
	halo(k, head, c(0, 1.25, 0.2), 0.7, 14, GO, 0.12)

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.75, 0.6, -0.3))
		k.featherWing(w, sd, { root = 0.2, z = 0.05, thick = 0.18, feathers = {
			{ 1.0, 2.4, 0.5, W, GO }, { 0.75, 2.8, 0.52, W, GO }, { 0.5, 3.0, 0.52, W, GO }, { 0.25, 2.7, 0.5, W, GO }, { 0.0, 2.2, 0.48, W, GO } } })
	end

	local tip = k.tail(body, c(0, 0.3, 1.3), { { 0.32, 0.32, 0.7, 0.2, CR }, { 0.3, 0.3, 0.6, -0.3, CR }, { 0.28, 0.28, 0.55, -0.3, CRD } })
	k.spike(tip, "TailTuft", 0.8, 0.4, W, c(0, 0, 0.3) * ANG(PI / 2, 0, 0))
	k.spike(tip, "TailTuftGold", 0.6, 0.3, GO, c(0, 0.15, 0.3) * ANG(PI / 2 - 0.5, 0, 0))
end

---------------------------------------------------------------- ARCHANGEL DRAKE (Mythical)
-- Holy dragon: white and cream armoured body with a gold V chest plate, legs with gold bands and claws,
-- white neck with gold trim, head with a long gold unicorn horn, a gold crown and spiky white mane, a gold
-- halo with studs, enormous layered wings (gold arm, white/cream/gold blades), a spiked tail ending in a
-- gold arrowhead.
function M.ArchDrake(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local CR, W, GO, GOD, EY = C("#F2E8D0"), C("#F8F8F6"), C("#F2C230"), C("#D8A41E"), C("#FFD84A")
	local BY = 2.3
	local body = k.body(1.7, 1.45, 2.4, W, BY)
	k.tri(body, "ChestV", 0.16, 1.2, 1.5, GO, c(0, 0.1, -1.23) * DOWN * FACE)
	k.tri(body, "ChestVIn", 0.18, 0.8, 0.9, CR, c(0, 0.15, -1.25) * DOWN * FACE)
	for _, sd in ipairs(SIDES) do k.b(body, "SidePlate", 0.12, 0.8, 1.6, CR, c(sd * 0.86, 0.0, 0.3)) end
	local lf = { up = { 0.8, 0.75, 0.9 }, col = W, w2 = 0.66, d2 = 0.72, col2 = CR, band = GO, paw = { 0.92, 0.35, 1.05 }, pawCol = CR, toes = 3, toeCol = GO }
	k.leg(body, "LegFL", BY, -0.72, -0.5, -0.8, lf)
	k.leg(body, "LegFR", BY, 0.72, -0.5, -0.8, lf)
	lf.hind = true
	k.leg(body, "LegBL", BY, -0.74, -0.45, 0.85, lf)
	k.leg(body, "LegBR", BY, 0.74, -0.45, 0.85, lf)
	rig.legKind = "quad"

	for i = 0, 2 do
		local _, n = k.b(body, "Neck", 0.72 - i * 0.04, 0.75, 0.7, (i % 2 == 0) and W or CR, c(0, 0.8 + i * 0.6, -1.3 - i * 0.18) * ANG(-0.3, 0, 0))
		k.b(n, "NeckTrim", 0.74, 0.1, 0.72, GO, c(0, 0.3, 0))
	end
	local head = k.head(body, 0.85, 0.7, 1.1, W, c(0, 2.45, -1.95), V3(0, -0.25, 0.4))
	k.w(head, "Snout", 0.6, 0.4, 0.6, W, c(0, -0.1, -0.8))
	k.spike(head, "UnicornHorn", 1.6, 0.28, GO, c(0, 0.3, -0.3) * ANG(-0.5, 0, 0))
	k.b(head, "CrownBand", 0.8, 0.18, 0.7, GO, c(0, 0.4, 0.05))
	for i = -1, 1 do k.tri(head, "CrownSpike", 0.1, 0.35, 0.2, GO, c(i * 0.25, 0.62, 0.05) * FACE) end
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.25, 0.1, -0.56, 0.22, 0.09, EY, sd * 0.3)
		for i = 0, 2 do
			k.tri(head, "Mane", 0.12, 0.7 - i * 0.1, 0.4, (i == 1) and CR or W, c(sd * 0.45, 0.2 - i * 0.3, 0.3) * ANG(0.4, 0, -sd * (1.1 + i * 0.25)))
		end
	end
	local hp = halo(k, head, c(0, 1.25, 0.15), 0.75, 12, GO)
	for i = 0, 3 do
		local a = i * PI / 2 + PI / 4
		k.b(hp, "HaloStud", 0.2, 0.26, 0.2, GOD, k.c(math.cos(a) * 0.75, 0, math.sin(a) * 0.75))
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.75, 0.6, -0.2))
		k.bar(w, "WingArm", V3(0, 0, 0), V3(sd * 1.3, 2.3, 0), 0.42, GO)
		k.bar(w, "WingArm", V3(sd * 1.3, 2.3, 0), V3(sd * 3.5, 2.8, 0), 0.34, GO)
		local _, fp = k.pv(w, "FeatherRoot", c(sd * 1.3, 2.1, 0.04))
		local cols = { W, CR, GO, W, CR, W, GO }
		local fw = {}
		for i = 0, 6 do table.insert(fw, { 0.55 - i * 0.24, 2.9 - math.abs(i - 1) * 0.2, 0.44, cols[i + 1] }) end
		k.featherWing(fp, sd, { root = 0.1, z = 0.04, feathers = fw })
		innerFeathers(k, w, sd, W, CR)
	end

	local segs = {}
	for j = 1, 9 do
		local w = 0.72 - j * 0.045
		table.insert(segs, { w, w * 0.85, 0.55, (j % 2 == 0) and CR or W, j == 1 and 0.3 or -0.04 })
	end
	local rec = k.chain(body, c(0, 0.1, 1.15), segs, { name = "Tail", kind = "spine", i = 1, amp = 0.14, freq = 1.2, lag = 0.55 })
	for j, p in ipairs(rec.parts) do
		if j % 2 == 1 then
			local w = 0.72 - j * 0.045
			k.tri(p, "TailSpike", 0.1, 0.45, 0.35, GO, c(0, w * 0.42 + 0.18, 0) * ANG(0.4, 0, 0))
		end
	end
	local tipRot = ANG(0, PI / 2, 0) * ANG(0, 0, PI / 2)
	k.tri(rec.parts[#rec.parts], "Arrow", 0.14, 0.8, 0.9, GO, c(0, 0, 0.65) * tipRot)
end

---------------------------------------------------------------- THRONE GUARDIAN (Mythical)
-- Hovering throne angel: white armoured torso with a glowing gold gem in a gold frame, long gold tabard
-- with a white border, layered white/pale-gold robe blades, big stepped shoulder pads with gold trim,
-- big arms ending in open palms, white helmet with a gold crown and glowing eyes, a gold halo carrying
-- three crystals, huge layered wings with stepped gold bars.
function M.ThroneAngel(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, WD, GO, YL, GEM = C("#F2F2F4"), C("#DCDCE2"), C("#F2C230"), C("#F7E08A"), C("#FFD23A")
	local BY = 3.0
	local body = k.body(2.0, 1.8, 1.3, W, BY)
	rig.legKind = "none"
	k.b(body, "GemFrame", 0.9, 0.9, 0.12, GO, c(0, 0.25, -0.7) * ANG(0, 0, PI / 4))
	local _, gem = k.b(body, "Gem", 0.55, 0.55, 0.14, GEM, c(0, 0.25, -0.73) * ANG(0, 0, PI / 4), MAT.Neon)
	k.glow(gem, GEM)
	k.b(body, "Waist", 1.6, 0.4, 1.1, WD, c(0, -1.05, 0))
	local te, tp = k.pv(body, "Tabard", c(0, -1.1, -0.6))
	table.insert(rig.tail, te)
	k.b(tp, "TabardBorder", 0.95, 1.6, 0.08, W, c(0, -0.8, 0))
	k.b(tp, "Tabard", 0.7, 1.45, 0.1, GO, c(0, -0.75, -0.02))
	k.tri(tp, "TabardTip", 0.1, 0.5, 0.95, GO, c(0, -1.85, 0) * DOWN * FACE)
	for i, x in ipairs({ -0.85, -0.55, 0.55, 0.85, -0.3, 0.3 }) do
		local re, rp = k.pv(body, "RobePivot", c(x, -1.1, (i > 4) and 0.4 or 0) * ANG(0, 0, x * 0.25))
		table.insert(rig.tail, re)
		k.tri(rp, "Robe", 0.14, 1.9 - math.abs(x) * 0.5, 0.55, (i % 2 == 0) and YL or W, c(0, -(1.9 - math.abs(x) * 0.5) / 2, 0) * DOWN * FACE)
	end

	for _, sd in ipairs(SIDES) do
		local a = k.arm(body, sd, c(sd * 1.25, 0.55, 0))
		k.b(a, "Shoulder", 1.1, 0.7, 1.1, W, c(sd * 0.25, 0.25, 0))
		k.b(a, "ShoulderTrim", 1.12, 0.14, 1.12, GO, c(sd * 0.25, 0.0, 0))
		k.b(a, "ShoulderStep", 0.7, 0.3, 0.9, WD, c(sd * 0.4, 0.62, 0))
		k.b(a, "UpperArm", 0.75, 0.9, 0.75, W, c(sd * 0.3, -0.5, 0))
		k.b(a, "Forearm", 0.95, 0.8, 0.95, WD, c(sd * 0.35, -1.3, -0.15) * ANG(-0.5, 0, 0))
		k.b(a, "Cuff", 1.0, 0.16, 1.0, GO, c(sd * 0.35, -1.05, -0.05) * ANG(-0.5, 0, 0))
		local _, hand = k.b(a, "Palm", 0.85, 0.25, 0.8, W, c(sd * 0.4, -1.75, -0.65))
		for f = 1, 4 do k.b(hand, "Finger", 0.16, 0.3, 0.16, W, c((f - 2.5) * 0.2, 0.2, -0.4)) end
	end

	local head = k.head(body, 0.8, 0.8, 0.8, W, c(0, 1.3, -0.05), V3(0, -0.38, 0.1))
	k.b(head, "Visor", 0.62, 0.2, 0.05, C("#5A5A68"), c(0, 0.02, -0.41))
	for _, sd in ipairs(SIDES) do k.eye(head, sd * 0.15, 0.02, -0.44, 0.16, 0.08, GEM, sd * 0.25) end
	k.b(head, "CrownBand", 0.85, 0.18, 0.85, GO, c(0, 0.42, 0))
	for i = -2, 2 do k.tri(head, "CrownSpike", 0.1, (i == 0) and 0.5 or 0.32, 0.18, GO, c(i * 0.17, (i == 0) and 0.72 or 0.62, -0.35) * FACE) end
	local hp = halo(k, head, c(0, 1.1, 0.15), 0.95, 14, GO)
	for _, a in ipairs({ PI / 2, PI / 2 + 2.1, PI / 2 - 2.1 }) do
		local _, cr = k.b(hp, "HaloCrystalBase", 0.18, 0.12, 0.18, GO, k.c(math.cos(a) * 0.95, 0.08, -math.sin(a) * 0.95))
		k.crystal(hp, "HaloCrystal", 0.5, 0.18, YL, k.c(math.cos(a) * 0.95, 0.12, -math.sin(a) * 0.95), MAT.Glass, 0.05)
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.8, 0.55, 0.35))
		k.bar(w, "WingArm", V3(0, 0, 0), V3(sd * 1.2, 1.4, 0), 0.5, W)
		k.bar(w, "WingArm", V3(sd * 1.2, 1.4, 0), V3(sd * 2.6, 2.0, 0), 0.42, W)
		k.bar(w, "WingStep", V3(sd * 0.4, 0.55, -0.15), V3(sd * 1.3, 1.6, -0.15), 0.14, GO)
		k.bar(w, "WingStep", V3(sd * 1.3, 1.6, -0.15), V3(sd * 2.4, 2.05, -0.15), 0.14, GO)
		local _, fp = k.pv(w, "FeatherRoot", c(sd * 1.0, 1.2, 0.04))
		local fw = {}
		for i = 0, 6 do table.insert(fw, { 0.45 - i * 0.28, 2.7 - math.abs(i - 2) * 0.2, 0.45, (i % 2 == 0) and W or YL }) end
		k.featherWing(fp, sd, { root = 0.1, z = 0.04, feathers = fw })
	end
end

return M
