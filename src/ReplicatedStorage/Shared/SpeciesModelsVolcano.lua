-- SpeciesModelsVolcano: hand-authored, reference-faithful models for the Volcano world
-- (Emberpup, Magmite, Cinderchick, Obsidian Golem, Phoenix Lumen, Magma Kraken, Infernadrake, Solar Serpent).
-- Location: ReplicatedStorage > Shared > SpeciesModelsVolcano (ModuleScript), merged into SpeciesModels.
-- Built from the owner's character sheets (hero / front / side + idle, anticipate, power move, recover).

local K = require(script.Parent.ModelKit)
local V3, CF, ANG, PI, MAT, C = K.V3, K.CF, K.ANG, K.PI, K.MAT, K.C
local FACE, DOWN = ANG(0, PI / 2, 0), ANG(0, 0, PI) -- triangle plate facing front / pointing down
local SIDES = { -1, 1 }

local M = {}

---------------------------------------------------------------- EMBERPUP (Common)
-- Chunky orange fox-pup: deep chest with cream bib, four thick legs with cream three-toed paws,
-- boxy head with cream muzzle, dark nose, heavy brows over glowing yellow slit eyes, tall pointed ears
-- with yellow insides, three-segment tail curling up to a glowing ember tip.
function M.Emberpup(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local O, OD, CR, CRD = C("#F27A2E"), C("#D9621F"), C("#F7D8AE"), C("#E6C092")
	local Y, N, EY = C("#FFC62E"), C("#3B2418"), C("#FFE14A")
	local BY = 1.75
	local body = k.body(1.6, 1.3, 2.3, O, BY)
	k.b(body, "Chest", 1.7, 1.45, 0.95, O, c(0, 0.08, -1.0))
	k.b(body, "Bib", 0.9, 0.75, 0.1, CR, c(0, 0.15, -1.5))
	k.tri(body, "BibTip", 0.1, 0.55, 0.9, CR, c(0, -0.5, -1.5) * DOWN * FACE)
	k.b(body, "Belly", 1.1, 0.2, 1.7, CR, c(0, -0.62, 0.1))
	k.b(body, "BackRidge", 1.1, 0.16, 1.6, OD, c(0, 0.68, 0.3))
	for _, sd in ipairs(SIDES) do
		k.b(body, "Shoulder", 0.3, 0.95, 0.95, OD, c(sd * 0.82, 0.05, -0.85))
		k.b(body, "Haunch", 0.3, 0.9, 0.95, OD, c(sd * 0.82, 0.05, 0.8))
	end

	local legF = { up = { 0.75, 0.6, 0.85 }, w2 = 0.6, d2 = 0.7, paw = { 0.85, 0.32, 1.0 }, col = O, pawCol = CR, toes = 3, toeCol = CRD }
	local legH = { up = { 0.82, 0.7, 1.0 }, w2 = 0.62, d2 = 0.72, paw = { 0.85, 0.32, 1.0 }, col = O, pawCol = CR, toes = 3, toeCol = CRD, hind = true }
	k.leg(body, "LegFL", BY, -0.55, -0.45, -0.9, legF)
	k.leg(body, "LegFR", BY, 0.55, -0.45, -0.9, legF)
	k.leg(body, "LegBL", BY, -0.55, -0.45, 0.85, legH)
	k.leg(body, "LegBR", BY, 0.55, -0.45, 0.85, legH)
	rig.legKind = "quad"

	local head = k.head(body, 1.45, 1.15, 1.25, O, c(0, 1.2, -1.5), V3(0, -0.45, 0.4))
	local fz = -0.625
	k.b(head, "Crown", 1.2, 0.22, 0.8, OD, c(0, 0.62, 0.15))
	k.b(head, "Muzzle", 0.8, 0.5, 0.6, CR, c(0, -0.3, fz - 0.25))
	k.b(head, "Jowl", 1.25, 0.32, 0.5, CR, c(0, -0.45, fz + 0.1))
	for _, sd in ipairs(SIDES) do k.w(head, "CheekTuft", 0.35, 0.45, 0.5, O, c(sd * 0.82, -0.2, -0.05) * ANG(0, -sd * PI / 2, 0)) end
	k.w(head, "Bridge", 0.7, 0.25, 0.45, O, c(0, 0.07, fz - 0.22))
	k.b(head, "Nose", 0.34, 0.2, 0.16, N, c(0, -0.12, fz - 0.58))
	k.b(head, "Mouth", 0.5, 0.05, 0.05, N, c(0, -0.47, fz - 0.56))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.62, 0.2, 0.32, OD, c(sd * 0.36, 0.25, fz - 0.05) * ANG(0, 0, sd * 0.28))
		k.eye(head, sd * 0.36, 0.06, fz - 0.03, 0.36, 0.14, EY, sd * 0.28)
		local ear = k.ear(head, sd, c(sd * 0.45, 0.5, 0.1) * ANG(0, 0, -sd * 0.15))
		k.tri(ear, "Ear", 0.24, 1.0, 0.72, O, c(0, 0.5, 0) * FACE)
		k.tri(ear, "EarInner", 0.08, 0.66, 0.42, Y, c(0, 0.4, -0.13) * FACE)
	end

	local tip = k.tail(body, c(0, 0.45, 1.1), {
		{ 0.5, 0.5, 0.6, -0.7, O }, { 0.46, 0.46, 0.55, -0.35, O }, { 0.42, 0.42, 0.5, -0.25, OD } })
	local _, flame = k.b(tip, "TailEmber", 0.55, 0.45, 0.8, Y, c(0, 0.05, 0.6) * ANG(-0.3, 0, 0), MAT.Neon)
	k.glow(flame, Y)
end

---------------------------------------------------------------- MAGMITE (Uncommon)
-- Lava turtle: dark rock body over a glowing yellow core, two orange shell halves split by a glowing
-- seam (they lift apart on the power move), a rock knob with a yellow zigzag on top, low brown head
-- under an orange visor helmet with cheek guards, four stubby splayed legs with orange feet.
function M.Magmite(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local O, OD, BR, BRD = C("#F2661E"), C("#D4521A"), C("#5A2A18"), C("#44200F")
	local Y, EY = C("#FFBC1E"), C("#FFD84A")
	local BY = 1.15
	local body = k.body(2.0, 1.0, 2.2, BR, BY)
	local _, core = k.b(body, "Core", 2.1, 0.55, 1.9, Y, c(0, 0.05, 0), MAT.Neon)
	k.glow(core, Y)
	local _, seam = k.b(body, "Seam", 0.34, 0.5, 2.25, Y, c(0, 0.72, 0.05), MAT.Neon)
	k.glow(seam, Y)
	for _, sd in ipairs(SIDES) do
		local half = k.opener(body, "ShellHinge", c(sd * 0.2, 0.5, 0), V3(0, 0, 1), sd * 0.35)
		k.b(half, "Shell", 0.9, 0.62, 2.4, O, c(sd * 0.42, 0.25, 0.05))
		k.w(half, "ShellEdge", 2.4, 0.55, 0.5, OD, c(sd * 1.12, 0.05, 0.05) * ANG(0, -sd * PI / 2, 0))
		k.w(half, "ShellFront", 0.9, 0.45, 0.45, O, c(sd * 0.42, 0.25, -1.45))
		k.b(half, "ShellBack", 0.9, 0.5, 0.4, OD, c(sd * 0.42, 0.15, 1.38))
	end
	local _, knob = k.b(body, "Rock", 1.0, 0.6, 0.85, BR, c(0, 1.25, 0.3))
	k.b(knob, "RockTop", 0.8, 0.2, 0.7, BRD, c(0, 0.38, 0.05))
	for i, x in ipairs({ -0.33, -0.11, 0.11, 0.33 }) do
		local _, z = k.b(knob, "Zigzag", 0.3, 0.08, 0.05, Y, c(x, 0.02, -0.44) * ANG(0, 0, (i % 2 == 1) and 0.75 or -0.75), MAT.Neon)
		k.glow(z, Y)
	end

	local head = k.head(body, 1.2, 0.7, 0.8, BR, c(0, -0.05, -1.35), V3(0, -0.2, 0.35))
	k.b(head, "Helmet", 1.45, 0.3, 1.0, O, c(0, 0.45, -0.05))
	k.w(head, "Visor", 1.4, 0.24, 0.3, O, c(0, 0.42, -0.68))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Guard", 0.22, 0.85, 0.85, O, c(sd * 0.72, 0.05, -0.1) * ANG(0, 0, sd * 0.12))
		k.eye(head, sd * 0.28, -0.02, -0.42, 0.3, 0.16, EY, 0)
	end

	local lg = { up = { 0.8, 0.45, 0.85 }, w2 = 0.72, d2 = 0.78, paw = { 1.0, 0.32, 1.0 }, col = BR, col2 = BRD, pawCol = O, splay = 0.45 }
	k.leg(body, "LegFL", BY, -0.85, -0.25, -0.75, lg)
	k.leg(body, "LegFR", BY, 0.85, -0.25, -0.75, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.85, -0.25, 0.75, lg)
	k.leg(body, "LegBR", BY, 0.85, -0.25, 0.75, lg)
	rig.legKind = "quad"
end

---------------------------------------------------------------- CINDERCHICK (Rare)
-- Amber chick-bird on two legs: cream breast, short neck, boxy head with cream beak and red-orange
-- glowing eyes, five-spike flame crest, folded wings with a red bar and cream flight feathers,
-- flame-feather tail fan, cream three-toed feet.
function M.Cinderchick(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local A, AD, CR = C("#F5A623"), C("#E08A12"), C("#F8DFA8")
	local R, Y, EY = C("#F0521E"), C("#FFB52E"), C("#FF5A1A")
	local BY = 2.05
	local body = k.body(1.35, 1.45, 1.5, A, BY)
	k.b(body, "Breast", 0.95, 1.1, 0.14, CR, c(0, -0.05, -0.78))
	k.b(body, "Belly", 1.0, 0.25, 1.1, CR, c(0, -0.75, 0))
	local lg = { up = { 0.5, 0.5, 0.55 }, col = A, w2 = 0.3, d2 = 0.32, col2 = AD, paw = { 0.75, 0.2, 0.8, -0.12 }, pawCol = CR, toes = 3, toeCol = CR }
	k.leg(body, "LegL", BY, -0.38, -0.7, 0.1, lg)
	k.leg(body, "LegR", BY, 0.38, -0.7, 0.1, lg)
	rig.legKind = "biped"

	k.b(body, "Neck", 0.62, 0.8, 0.55, A, c(0, 0.95, -0.3))
	k.b(body, "NeckBand", 0.66, 0.2, 0.59, CR, c(0, 0.75, -0.3))
	local head = k.head(body, 1.0, 0.85, 1.0, A, c(0, 1.65, -0.45), V3(0, -0.4, 0.2))
	k.w(head, "Beak", 0.55, 0.42, 0.6, CR, c(0, -0.1, -0.8))
	k.b(head, "BeakLow", 0.4, 0.15, 0.35, CR, c(0, -0.33, -0.65))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.45, 0.16, 0.2, AD, c(sd * 0.28, 0.24, -0.5) * ANG(0, 0, sd * 0.3))
		k.eye(head, sd * 0.28, 0.08, -0.52, 0.26, 0.16, EY, sd * 0.3)
	end
	for _, d in ipairs({ { 0, 1.0, R }, { -0.22, 0.8, Y }, { 0.22, 0.8, Y }, { -0.4, 0.6, R }, { 0.4, 0.6, R } }) do
		k.tri(head, "Crest", 0.14, d[2], 0.45, d[3], c(d[1], 0.4 + d[2] * 0.4, 0.05 + math.abs(d[1]) * 0.3) * ANG(0.5, 0, -d[1] * 0.8))
	end

	for _, sd in ipairs(SIDES) do
		-- folded wing held slightly out: amber covert with a red bar, a fan of long cream flight feathers below
		local w = k.wing(body, sd, c(sd * 0.68, 0.4, 0.0) * ANG(0, -sd * 0.5, 0))
		local _, wp = k.pv(w, "WingPlate", ANG(0, 0, -sd * 0.45))
		k.b(wp, "WingCovert", 1.1, 0.7, 0.28, A, c(sd * 0.5, -0.1, 0))
		k.b(wp, "WingBar", 1.0, 0.18, 0.3, R, c(sd * 0.55, 0.15, -0.02))
		k.featherWing(wp, sd, { root = 0.35, z = 0.05, thick = 0.12, feathers = {
			{ -0.5, 1.2, 0.34, CR }, { -0.8, 1.3, 0.34, CR }, { -1.1, 1.25, 0.32, CR }, { -1.4, 1.05, 0.3, CR } } })
	end

	local te, tp = k.pv(body, "TailFan", c(0, 0.15, 0.72) * ANG(0.75, 0, 0))
	table.insert(rig.tail, te)
	for i, a in ipairs({ -0.85, -0.45, 0, 0.45, 0.85 }) do
		local L = 1.35 - math.abs(a) * 0.35
		local col = (i == 3) and Y or ((i % 2 == 0) and A or R)
		k.tri(tp, "TailFlame", 0.12, L, 0.5, col, c(math.sin(a) * L * 0.5, math.cos(a) * L * 0.5, 0) * ANG(0, 0, -a) * FACE)
		k.tri(tp, "TailFlameCore", 0.13, L * 0.55, 0.28, Y, c(math.sin(a) * L * 0.32, math.cos(a) * L * 0.32, -0.02) * ANG(0, 0, -a) * FACE)
	end
end

---------------------------------------------------------------- OBSIDIAN GOLEM (Epic)
-- Hulking obsidian brute: broad torso with V chest plates and glowing lava cracks, small crested
-- helmet head with orange slit eyes, huge shoulder pads crowned by amber crystal spikes, orange arm
-- and fist bands, giant fists, column legs with orange stripes on the feet.
function M.Obsidigolem(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local D, DD, DL = C("#3A2A3E"), C("#2A1E2E"), C("#4A3850")
	local O, Y, LAVA = C("#F08A2A"), C("#FFB43A"), C("#FF8A1E")
	local function crack(parent, pts, z)
		for i = 1, #pts - 1 do
			local _, p = k.bar(parent, "Crack", V3(pts[i][1], pts[i][2], z), V3(pts[i + 1][1], pts[i + 1][2], z), 0.09, LAVA, MAT.Neon, nil, nil, 0.05)
			k.glow(p, LAVA)
		end
	end
	local BY = 3.3
	local body = k.body(2.3, 1.9, 1.6, D, BY)
	for _, sd in ipairs(SIDES) do
		k.b(body, "Pec", 1.2, 0.9, 0.3, DL, c(sd * 0.52, 0.3, -0.85) * ANG(0, 0, -sd * 0.22))
		k.spike(body, "BackSpike", 0.9, 0.5, Y, c(sd * 0.7, 0.95, 0.4) * ANG(0.3, 0, -sd * 0.3))
	end
	crack(body, { { -0.85, 0.55 }, { -0.45, 0.1 }, { 0, -0.3 }, { 0.45, 0.1 }, { 0.85, 0.55 } }, -1.02)
	crack(body, { { -0.95, -0.05 }, { -0.75, -0.4 }, { -0.9, -0.7 } }, -0.82)
	crack(body, { { 0.7, -0.35 }, { 0.9, -0.65 } }, -0.82)
	k.b(body, "Waist", 1.6, 0.6, 1.2, DD, c(0, -1.2, 0))
	k.b(body, "Hips", 1.9, 0.55, 1.3, D, c(0, -1.5, 0))

	local lg = { up = { 1.0, 0.6, 1.0 }, w2 = 0.9, d2 = 0.95, col = D, col2 = DD, paw = { 1.3, 0.5, 1.55, -0.12 }, pawCol = D }
	for _, sd in ipairs(SIDES) do
		local _, _, knee, lh = k.leg(body, sd < 0 and "LegL" or "LegR", BY, sd * 0.6, -1.6, 0, lg)
		for t = -1, 1 do
			k.b(knee, "FootStripe", 0.18, 0.42, 0.06, O, c(t * 0.35, -lh - 0.25, -0.9))
		end
	end
	rig.legKind = "biped"

	for _, sd in ipairs(SIDES) do
		local arm = k.arm(body, sd, c(sd * 1.45, 0.6, 0))
		k.b(arm, "Shoulder", 1.25, 0.75, 1.25, DL, c(sd * 0.2, 0.25, 0))
		for _, d in ipairs({ { 0.0, 0.85 }, { 0.32, 0.65 }, { -0.32, 0.65 } }) do
			k.spike(arm, "ShoulderSpike", d[2] + 0.3, 0.5, Y, c(sd * (0.25 + math.abs(d[1]) * 0.3), 0.55, d[1]) * ANG(0, 0, -sd * 0.35))
		end
		k.b(arm, "UpperArm", 0.85, 0.9, 0.85, D, c(sd * 0.25, -0.5, 0))
		k.b(arm, "ArmBand", 0.95, 0.22, 0.95, O, c(sd * 0.25, -1.0, 0))
		k.b(arm, "Forearm", 1.2, 0.9, 1.2, DL, c(sd * 0.3, -1.5, -0.05))
		local _, fist = k.b(arm, "Fist", 1.4, 1.1, 1.35, D, c(sd * 0.3, -2.4, -0.1))
		for f = 1, 3 do k.b(fist, "Knuckle", 0.38, 0.34, 0.2, DD, c((f - 2) * 0.42, 0.25, -0.72)) end
		k.b(fist, "FistBand", 1.45, 0.2, 1.4, O, c(0, 0.5, 0))
		crack(arm, { { sd * 0.05, -1.3 }, { sd * 0.3, -1.6 }, { sd * 0.12, -1.85 } }, -0.67)
	end

	local head = k.head(body, 1.0, 0.9, 1.0, D, c(0, 1.35, -0.2), V3(0, -0.45, 0.1))
	k.b(head, "Brow", 1.05, 0.25, 0.35, DL, c(0, 0.15, -0.4))
	k.b(head, "Visor", 0.8, 0.22, 0.08, DD, c(0, -0.02, -0.52))
	k.b(head, "Jaw", 0.8, 0.25, 0.6, DD, c(0, -0.45, -0.15))
	for _, sd in ipairs(SIDES) do k.eye(head, sd * 0.2, -0.02, -0.56, 0.26, 0.1, LAVA, sd * 0.2) end
	k.tri(head, "Crest", 0.35, 0.6, 1.0, DL, c(0, 0.75, 0))
	k.tri(head, "CrestGlow", 0.37, 0.35, 0.5, O, c(0, 0.7, -0.12))
end

---------------------------------------------------------------- PHOENIX LUMEN (Legendary)
-- Upright armoured phoenix: orange body with a yellow breastplate and crimson chest gem, slim neck,
-- hooked yellow beak, yellow/crimson crest, two huge raised wings (orange primaries with yellow tips
-- over crimson coverts), yellow talons, three long crimson tail streamers ending in yellow spearheads.
function M.PhoenixLumen(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local O, OD, Y = C("#F26A1E"), C("#D9541A"), C("#FFC52E")
	local R, RD, EY = C("#E8285A"), C("#C21E4A"), C("#FFE45C")
	local BY = 2.85
	local body = k.body(1.1, 1.5, 1.15, O, BY)
	k.b(body, "Breast", 0.9, 0.9, 0.14, Y, c(0, 0.15, -0.6))
	k.diamond(body, "ChestGem", 0.75, 0.5, 0.12, R, c(0, 0.15, -0.69), MAT.Glass)
	k.b(body, "Belly", 0.85, 0.5, 0.9, OD, c(0, -0.65, 0.05))
	local lg = { up = { 0.55, 0.6, 0.65 }, col = O, w2 = 0.3, d2 = 0.32, col2 = Y, paw = { 0.75, 0.22, 0.8, -0.12 }, pawCol = Y, toes = 3, toeCol = Y, band = R }
	k.leg(body, "LegL", BY, -0.33, -0.7, 0.05, lg)
	k.leg(body, "LegR", BY, 0.33, -0.7, 0.05, lg)
	rig.legKind = "biped"

	k.b(body, "Neck", 0.5, 0.75, 0.5, O, c(0, 0.95, -0.25) * ANG(-0.25, 0, 0))
	k.b(body, "NeckRuff", 0.62, 0.3, 0.6, Y, c(0, 0.7, -0.3))
	local head = k.head(body, 0.72, 0.68, 0.85, O, c(0, 1.55, -0.45), V3(0, -0.3, 0.2))
	k.w(head, "Beak", 0.36, 0.3, 0.5, Y, c(0, -0.08, -0.65))
	k.b(head, "BeakTip", 0.22, 0.25, 0.14, Y, c(0, -0.22, -0.86))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.3, 0.1, 0.15, R, c(sd * 0.22, 0.2, -0.42) * ANG(0, 0, sd * 0.35))
		k.eye(head, sd * 0.22, 0.08, -0.43, 0.2, 0.1, EY, sd * 0.35)
		k.tri(head, "CheekSpike", 0.1, 0.45, 0.3, Y, c(sd * 0.38, -0.05, 0.1) * ANG(0.9, 0, -sd * 0.6))
	end
	for _, d in ipairs({ { 0, 0.9, Y }, { -0.18, 0.7, R }, { 0.18, 0.7, R }, { -0.3, 0.5, Y }, { 0.3, 0.5, Y } }) do
		k.tri(head, "Crest", 0.12, d[2], 0.4, d[3], c(d[1], 0.3 + d[2] * 0.4, 0.15) * ANG(0.6, 0, -d[1] * 1.2))
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.5, 0.5, 0.2))
		k.featherWing(w, sd, { root = 0.15, z = 0.05, thick = 0.12, feathers = {
			{ 1.25, 2.5, 0.42, O, Y }, { 1.0, 2.9, 0.45, O, Y }, { 0.75, 3.1, 0.45, OD, Y }, { 0.5, 2.9, 0.45, O, Y },
			{ 0.25, 2.5, 0.42, O, Y }, { 0.0, 2.0, 0.4, OD, Y } } })
		k.featherWing(w, sd, { root = 0.1, z = -0.05, thick = 0.13, feathers = {
			{ 1.05, 1.6, 0.36, R, R }, { 0.75, 1.7, 0.36, R, RD }, { 0.45, 1.5, 0.34, R, R }, { 0.15, 1.2, 0.32, R, RD } } })
		k.bar(w, "WingEdge", V3(0, 0.1, -0.2), V3(sd * 0.9, 1.7, -0.2), 0.3, Y)
	end

	local tipRot = ANG(0, PI / 2, 0) * ANG(0, 0, PI / 2) -- flat triangle, apex along +Z
	local backRot = ANG(0, -PI / 2, 0) * ANG(0, 0, PI / 2) -- flat triangle, apex along -Z
	for i, x in ipairs({ -0.3, 0, 0.3 }) do
		local segs = {}
		for j = 1, 7 do
			table.insert(segs, { 0.3 - j * 0.015, 0.24, 0.55, (j % 2 == 0) and R or RD, j == 1 and 1.1 or -0.15, j == 1 and x * 0.5 or 0 })
		end
		local rec = k.chain(body, c(x, -0.5, 0.45), segs, { name = "Streamer", kind = "trail", i = i, amp = 0.12, freq = 1.6, lag = 0.5 })
		local last = rec.parts[#rec.parts]
		k.tri(last, "SpearTip", 0.08, 0.75, 0.55, Y, c(0, 0, 0.62) * tipRot)
		k.tri(last, "SpearBack", 0.08, 0.3, 0.55, Y, c(0, 0, 0.12) * backRot)
		k.tri(last, "SpearCore", 0.1, 0.45, 0.25, R, c(0, 0.01, 0.5) * tipRot)
	end
end

---------------------------------------------------------------- MAGMA KRAKEN (Legendary)
-- Dark maroon mantle with glowing yellow eyes, a crown of eight orange/red petal plates (yellow
-- stripes, a gem on the front plate) around a glowing lava core that flare open on the power move,
-- eight segmented tentacles banded red/orange/maroon with yellow suckers and yellow tips.
function M.MagmaKraken(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local R, O, BR, BRD = C("#E8401E"), C("#F2662A"), C("#5A1E14"), C("#401510")
	local Y, CORE, EY = C("#FFC233"), C("#FFB01E"), C("#FFD84A")
	local BY = 1.55
	local body = k.body(2.0, 1.3, 2.0, BR, BY)
	rig.legKind = "none"
	k.b(body, "Brow", 2.05, 0.3, 0.4, BRD, c(0, 0.15, -0.85))
	for _, sd in ipairs(SIDES) do k.eye(body, sd * 0.42, -0.12, -1.02, 0.36, 0.18, EY, -sd * 0.2) end
	local _, core = k.b(body, "Core", 1.15, 0.5, 1.15, CORE, c(0, 0.75, 0), MAT.Neon)
	k.glow(core, CORE)
	k.b(body, "CoreRim", 1.5, 0.3, 1.5, BRD, c(0, 0.6, 0))

	for i = 0, 7 do
		local a = i / 8 * PI * 2
		local d = V3(math.sin(a), 0, -math.cos(a))
		local pos = V3(0, 0.45, 0) + d * 0.85
		local front = i == 0
		local pet = k.opener(body, "Petal", CFrame.lookAt(pos * s, (pos + d) * s), V3(1, 0, 0), -0.35)
		local h = front and 2.1 or 1.85
		local _, plate = k.b(pet, "PetalPlate", front and 1.25 or 1.15, h, 0.26, (i % 2 == 0) and O or R, ANG(-0.75, 0, 0) * c(0, h * 0.45, 0))
		k.b(plate, "PetalStripe", 0.18, h * 0.75, 0.26, Y, c(-0.25, 0, 0))
		if front then k.diamond(plate, "PetalGem", 1.0, 0.55, 0.1, Y, c(0, -0.05, -0.14)) end
	end

	for i = 0, 7 do
		local a = (i + 0.5) / 8 * PI * 2
		local d = V3(math.sin(a), 0, -math.cos(a))
		local pos = V3(0, -0.5, 0) + d * 0.7
		local segs = {}
		for j = 1, 6 do
			local w = 0.55 - j * 0.045
			local col = (j % 3 == 1) and R or ((j % 3 == 2) and O or BR)
			table.insert(segs, { w, w * 0.85, 0.5, col, j == 1 and 0.65 or -0.18 })
		end
		local rec = k.chain(body, CFrame.lookAt(pos * s, (pos - d) * s), segs, { name = "Tentacle", kind = "tentacle", i = i + 1, amp = 0.18, freq = 1.4, lag = 0.55 })
		for j, p in ipairs(rec.parts) do
			if j == 2 or j == 4 then
				local w = 0.55 - j * 0.045
				local _, cup = k.b(p, "Sucker", 0.26, 0.08, 0.26, Y, c(0, w * 0.43 + 0.03, 0))
				k.b(cup, "SuckerHole", 0.12, 0.09, 0.12, BRD, c(0, 0.01, 0))
			end
		end
		k.w(rec.parts[#rec.parts], "TentacleTip", 0.3, 0.26, 0.55, Y, c(0, 0, 0.5) * ANG(0, PI, 0))
	end
end

---------------------------------------------------------------- INFERNADRAKE (Mythical)
-- Red armoured dragon on four legs: maroon chest with an orange belly-plate ladder and glowing seams,
-- yellow back spikes, two-block neck, horned head with a hinged jaw and yellow teeth, huge bat wings
-- (red bones, orange membranes), long spiked tail ending in a glowing flame fan.
function M.Infernadrake(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local RD, RK, MR = C("#B3221C"), C("#7E1814"), C("#4A1A1C")
	local O, OL, Y, LAVA = C("#F2962E"), C("#FFB54A"), C("#FFC233"), C("#FFB01E")
	local BY = 2.35
	local body = k.body(1.9, 1.6, 2.5, RD, BY)
	k.b(body, "Chest", 1.7, 1.5, 0.9, MR, c(0, 0.05, -1.15))
	for i = 0, 3 do
		k.b(body, "BellyPlate", 1.0 - i * 0.08, 0.32, 0.16, (i % 2 == 0) and O or OL, c(0, 0.35 - i * 0.38, -1.62 + i * 0.12) * ANG(-0.2, 0, 0))
	end
	for _, sd in ipairs(SIDES) do
		local _, seam = k.bar(body, "Seam", V3(sd * 0.72, 0.6, -1.62), V3(sd * 0.4, -0.5, -1.62), 0.09, LAVA, MAT.Neon, nil, nil, 0.05)
		k.glow(seam, LAVA)
	end
	for i = 0, 4 do
		k.tri(body, "BackSpike", 0.16, 0.7 - i * 0.08, 0.6, Y, c(0, 1.05, -0.9 + i * 0.5) * ANG(0.45, 0, 0))
	end

	local lf = { up = { 0.85, 0.75, 0.95 }, col = RD, w2 = 0.72, d2 = 0.8, col2 = MR, paw = { 1.05, 0.38, 1.2, -0.1 }, pawCol = RD, toes = 3, toeCol = Y, band = LAVA }
	local lh = { up = { 1.0, 0.85, 1.15 }, col = RD, w2 = 0.78, d2 = 0.85, col2 = MR, paw = { 1.1, 0.4, 1.25, -0.1 }, pawCol = RD, toes = 3, toeCol = Y, band = LAVA, hind = true }
	k.leg(body, "LegFL", BY, -0.8, -0.55, -0.85, lf)
	k.leg(body, "LegFR", BY, 0.8, -0.55, -0.85, lf)
	k.leg(body, "LegBL", BY, -0.85, -0.5, 0.9, lh)
	k.leg(body, "LegBR", BY, 0.85, -0.5, 0.9, lh)
	rig.legKind = "quad"

	k.b(body, "Neck1", 1.0, 1.0, 0.9, RD, c(0, 0.75, -1.45) * ANG(-0.5, 0, 0))
	k.b(body, "Neck2", 0.9, 0.9, 0.85, RK, c(0, 1.35, -1.75) * ANG(-0.3, 0, 0))
	k.b(body, "Throat", 0.6, 1.2, 0.3, O, c(0, 1.0, -2.0) * ANG(-0.4, 0, 0))
	local head = k.head(body, 1.15, 0.9, 1.3, RD, c(0, 2.05, -2.15), V3(0, -0.35, 0.4))
	k.b(head, "Snout", 0.85, 0.5, 0.75, RD, c(0, -0.15, -0.95))
	k.b(head, "Brow", 1.2, 0.25, 0.5, RK, c(0, 0.35, -0.45))
	local jaw = k.jb(head, "Jaw", 0.8, 0.25, 1.1, MR, c(0, -0.5, -0.65), V3(0, 0, 0.5))
	H.group(rig, "jaws", jaw)
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.34, 0.12, -0.66, 0.3, 0.11, Y, sd * 0.3)
		k.spike(head, "Horn", 1.3, 0.38, Y, c(sd * 0.42, 0.4, 0.3) * ANG(1.0, 0, -sd * 0.35))
		k.spike(head, "HornSmall", 0.7, 0.26, Y, c(sd * 0.55, 0.0, 0.45) * ANG(1.3, 0, -sd * 0.8))
		k.b(head, "Tooth", 0.12, 0.18, 0.12, Y, c(sd * 0.3, -0.45, -1.25))
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.8, 0.65, -0.35))
		k.batWing(w, sd, { wrist = Vector2.new(1.5, 2.3), bone = RD, mem = O, boneW = 0.32, cap = RK,
			tips = { Vector2.new(4.0, 1.1), Vector2.new(3.4, -0.4), Vector2.new(2.3, -1.0), Vector2.new(1.1, -0.9) } })
		k.spike(w, "WingClaw", 0.5, 0.22, Y, c(sd * 1.5, 2.3, 0) * ANG(0, 0, -sd * 0.3))
	end

	local segs = {}
	for j = 1, 8 do
		local w = 0.85 - j * 0.07
		table.insert(segs, { w, w * 0.85, 0.6, (j % 2 == 0) and MR or RD, j == 1 and 0.35 or -0.08 })
	end
	local rec = k.chain(body, c(0, 0.1, 1.2), segs, { name = "Tail", kind = "spine", i = 1, amp = 0.16, freq = 1.4, lag = 0.55 })
	for j, p in ipairs(rec.parts) do
		local w = 0.85 - j * 0.07
		k.tri(p, "TailSpike", 0.12, 0.45 - j * 0.02, 0.4, Y, c(0, w * 0.42 + 0.18, 0) * ANG(0.4, 0, 0))
	end
	local last = rec.parts[#rec.parts]
	for i, a in ipairs({ -0.7, -0.25, 0.25, 0.7 }) do
		k.spike(last, "TailFlame", 1.0 - math.abs(a) * 0.4, 0.4, (i == 2 or i == 3) and Y or O, c(0, 0, 0.3) * ANG(PI / 2 - 0.5, 0, a), MAT.Neon)
	end
end

---------------------------------------------------------------- SOLAR SERPENT (Mythical)
-- Upright white serpent resting on its coils: yellow/orange side bands, gems along the body, a chest
-- gem, feathered wings (white/yellow/orange blades) at the shoulders, horned head with a yellow visor,
-- a sun-ring halo with three gems turning behind the head, flame fin at the tail tip.
function M.SolarSerpent(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, Y, O = C("#F7F3EA"), C("#FFC52E"), C("#F2822A")
	local GEM, EY = C("#F4FAFF"), C("#FF9A2A")
	local BY = 0.55
	local body = k.body(1.1, 1.0, 1.1, W, BY)
	rig.legKind = "none"
	k.b(body, "BodyBand", 1.16, 0.6, 0.7, Y, c(0, 0.05, 0))
	k.b(body, "BodyBelly", 1.0, 0.18, 1.0, O, c(0, -0.42, 0))

	-- neck rises from the coil; on neck segments +Z runs up the neck and +Y faces the creature's front
	local nseg = { -1.35, -0.15, -0.2, -0.25 }
	local segs = {}
	for j, p in ipairs(nseg) do
		local w = 1.0 - j * 0.06
		table.insert(segs, { w, w, 0.85, W, p })
	end
	local neck = k.chain(body, c(0, 0.3, -0.25), segs, { name = "Neck", kind = "neck", i = 1, amp = 0.06, freq = 0.9 })
	local acc = 0
	for j, p in ipairs(neck.parts) do
		acc += nseg[j]
		local w = 1.0 - j * 0.06
		k.b(p, "Belly", w * 0.75, 0.1, 0.8, W, c(0, w * 0.5, 0))
		k.b(p, "BackPlate", w * 0.85, 0.12, 0.55, Y, c(0, -w * 0.5, 0))
		for _, sd in ipairs(SIDES) do
			k.b(p, "SideBand", 0.1, w * 0.8, 0.5, (j % 2 == 0) and O or Y, c(sd * w * 0.5, 0, 0))
		end
		if j == 2 then k.diamond(p, "ChestGem", 0.7, 0.45, 0.14, GEM, c(0, w * 0.56, 0) * ANG(PI / 2, 0, 0), MAT.Glass) end
	end

	local last = neck.parts[#neck.parts]
	local head = k.head(last, 0.95, 0.75, 1.15, W, c(0, 0, 0.55) * ANG(-acc, 0, 0) * c(0, 0.15, -0.3), V3(0, -0.3, 0.35))
	k.b(head, "Snout", 0.7, 0.4, 0.55, W, c(0, -0.12, -0.75))
	k.b(head, "SnoutBand", 0.74, 0.14, 0.4, O, c(0, 0.0, -0.65))
	k.b(head, "Visor", 0.98, 0.22, 0.6, Y, c(0, 0.3, -0.2))
	for _, sd in ipairs(SIDES) do
		k.b(head, "EyeShade", 0.32, 0.18, 0.06, O, c(sd * 0.27, 0.12, -0.6))
		k.eye(head, sd * 0.27, 0.12, -0.62, 0.24, 0.1, EY, sd * 0.25)
		k.tri(head, "Fin", 0.1, 0.7, 0.8, Y, c(sd * 0.5, 0.25, 0.25) * ANG(0.4, 0, -sd * 0.5))
		k.b(head, "Fang", 0.08, 0.16, 0.08, W, c(sd * 0.2, -0.38, -0.95))
	end
	k.spike(head, "Horn", 1.6, 0.3, Y, c(0, 0.45, -0.3) * ANG(1.2, 0, 0))
	local he, hp = k.pv(head, "HaloPivot", c(0, 0.45, 0.8))
	H.group(rig, "rays", he)
	k.ring(hp, "Halo", CF(), 1.35, 14, 0.2, 0.62, 0.16, Y)
	for _, a in ipairs({ PI / 2, PI / 2 + 2.1, PI / 2 - 2.1 }) do
		k.b(hp, "GemFrame", 0.55, 0.55, 0.12, Y, c(math.cos(a) * 1.35, math.sin(a) * 1.35, 0.02) * ANG(0, 0, PI / 4))
		k.diamond(hp, "HaloGem", 0.7, 0.45, 0.14, GEM, c(math.cos(a) * 1.35, math.sin(a) * 1.35, -0.06), MAT.Glass)
	end

	local p2, acc2 = neck.parts[2], nseg[1] + nseg[2]
	for _, sd in ipairs(SIDES) do
		local w = k.wing(p2, sd, c(sd * 0.45, -0.1, 0) * ANG(-acc2, 0, 0))
		k.b(w, "WingMount", 0.6, 0.6, 0.6, Y, c(sd * 0.2, 0.1, 0))
		k.featherWing(w, sd, { root = 0.2, z = 0.05, feathers = {
			{ 1.1, 2.4, 0.42, W, W }, { 0.8, 2.7, 0.44, Y, Y }, { 0.5, 2.6, 0.44, W, O }, { 0.2, 2.2, 0.42, O, O }, { -0.1, 1.7, 0.4, W, W } } })
	end

	-- compact S on the ground: swings out to one side, back across, and curls again
	local yaws = { 0.9, 0.55, -0.6, -0.9, -0.7, 0.5, 0.9, 0.6 }
	local tsegs = {}
	for j = 1, 8 do
		local w = 1.0 - j * 0.055
		table.insert(tsegs, { w, w * 0.92, 0.62, W, 0, yaws[j] })
	end
	local tail = k.chain(body, c(0, -0.04, 0.4), tsegs, { name = "Coil", kind = "spine", i = 2, amp = 0.08, freq = 1.0, lag = 0.6 })
	for j, p in ipairs(tail.parts) do
		local w = 1.0 - j * 0.055
		k.b(p, "CoilBand", w + 0.06, w * 0.5, 0.32, Y, c(0, 0.05, 0))
		k.b(p, "CoilBelly", w * 0.9, 0.1, 0.7, O, c(0, -w * 0.46, 0))
		if j % 2 == 1 then
			for _, sd in ipairs(SIDES) do
				k.diamond(p, "CoilGem", 0.4, 0.26, 0.08, GEM, c(sd * (w * 0.5 + 0.06), 0.05, 0) * ANG(0, -sd * PI / 2, 0), MAT.Glass)
			end
		end
	end
	local tl = tail.parts[#tail.parts]
	for i, a in ipairs({ -0.6, -0.2, 0.2, 0.6 }) do
		k.spike(tl, "TailFlame", 1.4 - math.abs(a) * 0.6, 0.45, (i == 2 or i == 3) and Y or O, c(0, 0.1, 0.35) * ANG(0.6, 0, a), MAT.Neon)
	end
end

return M
