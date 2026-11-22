-- SpeciesModelsCandy: hand-authored, reference-faithful models for the Candy world
-- (Gumdrop, Cocoa Cub, Lollipup, Marshmallow Ghost, Sugarcorn, Cotton Candy Kirin, Candy Queen Bee,
-- Chocolate Colossus).
-- Location: ReplicatedStorage > Shared > SpeciesModelsCandy (ModuleScript), merged into SpeciesModels.

local K = require(script.Parent.ModelKit)
local V3, CF, ANG, PI, MAT, C = K.V3, K.CF, K.ANG, K.PI, K.MAT, K.C
local FACE, DOWN = ANG(0, PI / 2, 0), ANG(0, 0, PI)
local SIDES = { -1, 1 }

local M = {}

---------------------------------------------------------------- GUMDROP (Common)
-- Pink candy crawler: big boxy body with a sloped hood, white side panels, glowing white slit eyes,
-- white chin, a striped candy lid on top that pops up on the power move, four splayed legs with
-- light-pink shins and white feet.
function M.Gumdrop(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local P, PD, PL, W, EY = C("#F0559A"), C("#D9407F"), C("#F7B5D0"), C("#FFFFFF"), C("#FFF4FA")
	local BY = 1.45
	local body = k.body(2.1, 1.3, 2.3, P, BY)
	k.w(body, "Hood", 2.1, 0.55, 0.9, P, c(0, 0.92, -0.6))
	k.b(body, "Top", 2.1, 0.55, 1.4, P, c(0, 0.92, 0.45))
	k.b(body, "Face", 1.7, 0.8, 0.2, P, c(0, 0.0, -1.2))
	k.b(body, "Chin", 1.1, 0.4, 0.6, W, c(0, -0.6, -0.95))
	for _, sd in ipairs(SIDES) do
		k.eye(body, sd * 0.42, 0.05, -1.31, 0.4, 0.14, EY, 0)
		k.b(body, "SidePanel", 0.14, 0.95, 1.3, W, c(sd * 1.08, 0.35, 0.05) * ANG(0, 0, -sd * 0.2))
		k.b(body, "Cheek", 0.12, 0.6, 0.8, PL, c(sd * 1.07, -0.25, -0.6))
	end
	local lid = k.opener(body, "CandyHinge", c(0, 1.2, 0.75), V3(1, 0, 0), 0.55)
	local _, candy = k.b(lid, "Candy", 1.2, 0.32, 1.0, W, c(0, 0.16, -0.5))
	for i = -1, 1, 2 do
		k.b(candy, "CandyStripe", 0.26, 0.34, 0.9, P, c(i * 0.3, 0, 0) * ANG(0, 0.6, 0))
	end
	k.b(lid, "Latch", 0.3, 0.2, 0.25, PD, c(0, 0.05, -1.05))

	local lg = { up = { 0.7, 0.5, 0.75 }, col = P, w2 = 0.6, d2 = 0.65, col2 = PL, paw = { 0.8, 0.3, 0.85 }, pawCol = W, splay = 0.3 }
	k.leg(body, "LegFL", BY, -0.95, -0.35, -0.75, lg)
	k.leg(body, "LegFR", BY, 0.95, -0.35, -0.75, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.95, -0.35, 0.8, lg)
	k.leg(body, "LegBR", BY, 0.95, -0.35, 0.8, lg)
	rig.legKind = "quad"
end

---------------------------------------------------------------- COCOA CUB (Uncommon)
-- Stocky chocolate bear: tan V bib, dark collar with a pink shield tag, pink chevrons on the
-- shoulder plates, big square head with tan muzzle, dark nose, angry brows over glowing pink eyes,
-- square ears with tan insides, tan paws with claw lines, stub tail.
function M.CocoaCub(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local B, BD, T, TD = C("#8B4A2B"), C("#6E3820"), C("#E8B98A"), C("#D4A274")
	local P, DK, EY = C("#F2668B"), C("#3E2216"), C("#FF7AA0")
	local BY = 1.85
	local body = k.body(1.8, 1.5, 2.2, B, BY)
	k.b(body, "Chest", 1.85, 1.55, 0.9, B, c(0, 0.1, -0.95))
	k.b(body, "Bib", 1.0, 0.9, 0.12, T, c(0, -0.05, -1.45))
	k.tri(body, "BibTip", 0.12, 0.45, 1.0, T, c(0, -0.72, -1.45) * DOWN * FACE)
	k.b(body, "Collar", 1.5, 0.2, 0.2, DK, c(0, 0.6, -1.44))
	k.diamond(body, "Tag", 0.65, 0.5, 0.1, DK, c(0, 0.22, -1.5))
	k.diamond(body, "TagInner", 0.48, 0.34, 0.12, P, c(0, 0.22, -1.52))
	for _, sd in ipairs(SIDES) do
		k.b(body, "ShoulderPlate", 0.14, 1.0, 1.0, BD, c(sd * 0.95, 0.15, -0.95))
		k.b(body, "Chevron", 0.06, 0.18, 0.6, P, c(sd * 1.03, 0.4, -0.7) * ANG(0.55, 0, 0))
		k.b(body, "Chevron", 0.06, 0.18, 0.6, P, c(sd * 1.03, 0.4, -1.2) * ANG(-0.55, 0, 0))
	end

	local lf = { up = { 0.85, 0.65, 0.9 }, col = B, w2 = 0.75, d2 = 0.8, paw = { 0.95, 0.35, 1.05 }, pawCol = T, toes = 3, toeCol = TD }
	k.leg(body, "LegFL", BY, -0.6, -0.5, -0.85, lf)
	k.leg(body, "LegFR", BY, 0.6, -0.5, -0.85, lf)
	lf.hind = true
	k.leg(body, "LegBL", BY, -0.6, -0.5, 0.8, lf)
	k.leg(body, "LegBR", BY, 0.6, -0.5, 0.8, lf)
	rig.legKind = "quad"

	local head = k.head(body, 1.5, 1.3, 1.3, B, c(0, 1.15, -1.45), V3(0, -0.5, 0.4))
	local fz = -0.65
	k.b(head, "Muzzle", 0.85, 0.55, 0.5, T, c(0, -0.3, fz - 0.22))
	k.b(head, "Nose", 0.36, 0.18, 0.14, DK, c(0, -0.12, fz - 0.5))
	k.b(head, "Mouth", 0.4, 0.05, 0.05, DK, c(0, -0.45, fz - 0.48))
	k.b(head, "Crown", 1.3, 0.25, 0.9, BD, c(0, 0.62, 0.1))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.6, 0.22, 0.3, BD, c(sd * 0.36, 0.22, fz - 0.04) * ANG(0, 0, sd * 0.3))
		k.eye(head, sd * 0.36, 0.04, fz - 0.03, 0.34, 0.13, EY, sd * 0.3)
		k.b(head, "Cheek", 0.3, 0.6, 0.6, BD, c(sd * 0.72, -0.2, -0.2))
		local ear = k.ear(head, sd, c(sd * 0.55, 0.65, 0.1), "round")
		k.b(ear, "Ear", 0.52, 0.5, 0.28, B, c(0, 0.22, 0))
		k.b(ear, "EarInner", 0.3, 0.28, 0.08, T, c(0, 0.2, -0.15))
	end
	k.tail(body, c(0, 0.35, 1.1), { { 0.5, 0.5, 0.45, -0.5, B } })
end

---------------------------------------------------------------- LOLLIPUP (Rare)
-- Light-pink candy dog: hot-pink shoulder/hip patches, blue zigzag stripes, blue collar with a swirl
-- tag, pink blaze over the head, glowing cyan eyes, big floppy pink ears with blue stripes, blue leg
-- bands and pink paws, a curling tail carrying a big swirl lollipop.
function M.Lollipup(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PL, PLD, P, B, EY = C("#F8CDDC"), C("#EDB4C8"), C("#EC5B97"), C("#5BB8E8"), C("#66E6FF")
	local BY = 1.8
	local body = k.body(1.55, 1.3, 2.4, PL, BY)
	k.b(body, "Chest", 1.6, 1.4, 0.8, PL, c(0, 0.08, -1.05))
	for _, sd in ipairs(SIDES) do
		k.b(body, "ShoulderPatch", 0.12, 0.85, 0.9, P, c(sd * 0.81, 0.05, -0.95))
		k.b(body, "HipPatch", 0.12, 0.8, 0.8, P, c(sd * 0.79, 0.1, 0.8))
		k.b(body, "Stripe", 0.06, 0.1, 1.0, B, c(sd * 0.81, -0.25, -0.1))
		k.b(body, "Stripe", 0.06, 0.1, 0.6, B, c(sd * 0.81, -0.05, 0.55) * ANG(-0.6, 0, 0))
	end
	k.b(body, "Collar", 1.3, 0.22, 0.22, B, c(0, 0.55, -1.47))
	k.b(body, "Tag", 0.4, 0.4, 0.1, PL, c(0, 0.25, -1.52))
	k.b(body, "TagSwirl", 0.22, 0.22, 0.11, P, c(0, 0.25, -1.53) * ANG(0, 0, PI / 4))

	local lf = { up = { 0.7, 0.6, 0.8 }, col = PL, w2 = 0.58, d2 = 0.65, band = B, paw = { 0.75, 0.3, 0.85 }, pawCol = P, toes = 3, toeCol = P }
	k.leg(body, "LegFL", BY, -0.52, -0.45, -0.95, lf)
	k.leg(body, "LegFR", BY, 0.52, -0.45, -0.95, lf)
	lf.hind = true
	k.leg(body, "LegBL", BY, -0.52, -0.45, 0.9, lf)
	k.leg(body, "LegBR", BY, 0.52, -0.45, 0.9, lf)
	rig.legKind = "quad"

	local head = k.head(body, 1.4, 1.2, 1.3, PL, c(0, 1.2, -1.5), V3(0, -0.45, 0.4))
	local fz = -0.65
	k.b(head, "Blaze", 0.34, 1.22, 1.32, P, c(0, 0.01, 0))
	k.b(head, "Muzzle", 0.8, 0.5, 0.6, PL, c(0, -0.3, fz - 0.25))
	k.b(head, "Nose", 0.36, 0.22, 0.2, P, c(0, -0.12, fz - 0.6))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.5, 0.18, 0.25, PLD, c(sd * 0.4, 0.2, fz - 0.03) * ANG(0, 0, sd * 0.25))
		k.eye(head, sd * 0.38, 0.04, fz - 0.03, 0.32, 0.14, EY, sd * 0.25)
		k.b(head, "CheekStripe", 0.06, 0.1, 0.5, B, c(sd * 0.71, -0.25, -0.2))
		local ear = k.ear(head, sd, c(sd * 0.62, 0.45, 0.05), "floppy")
		local _, flap = k.b(ear, "Ear", 0.22, 1.35, 0.95, P, c(sd * 0.12, -0.45, 0) * ANG(0, 0, sd * 0.18))
		k.b(flap, "EarRim", 0.24, 1.2, 0.2, PL, c(0, 0, -0.42))
		k.b(flap, "EarStripe", 0.25, 0.08, 0.6, B, c(0, -0.35, 0.1))
	end

	local tip = k.tail(body, c(0, 0.4, 1.15), {
		{ 0.32, 0.32, 0.6, -0.55, PL }, { 0.3, 0.3, 0.55, -0.35, P }, { 0.28, 0.28, 0.5, -0.4, PL } })
	local dc = c(0, 0, 1.05)
	for i, r in ipairs({ 1.7, 1.25, 0.85, 0.45 }) do
		local col = (i % 2 == 1) and P or PL
		k.b(tip, "Lollipop", 0.2 + i * 0.02, r, r, col, dc)
		k.b(tip, "Lollipop", 0.2 + i * 0.02, r, r, col, dc * ANG(PI / 4, 0, 0))
	end
end

---------------------------------------------------------------- MARSHMALLOW GHOST (Epic)
-- Floating hooded marshmallow spirit: white hood with a pink centre stripe and a dark face showing
-- glowing pink eyes, layered collar plates that flare like wings, a pink emblem, a hem of hanging
-- white/pink spikes, two floating fists with glowing pink bands.
function M.Marshghost(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, WD, PL, P = C("#FAF6F8"), C("#ECE3E8"), C("#F6C3D8"), C("#F06FA8")
	local DK, EY = C("#2A1626"), C("#FF6FC0")
	local BY = 2.5
	local body = k.body(1.5, 1.7, 1.25, W, BY)
	rig.legKind = "none"
	k.b(body, "Mantle", 1.9, 0.5, 1.4, W, c(0, 0.75, 0.05))
	k.b(body, "Emblem", 0.5, 0.14, 0.1, P, c(0, 0.25, -0.66))
	k.b(body, "EmblemStem", 0.18, 0.5, 0.1, P, c(0, 0.0, -0.66))

	local head = k.head(body, 1.35, 1.2, 1.35, W, c(0, 1.55, -0.05), V3(0, -0.5, 0.2))
	k.b(head, "HoodStripe", 0.26, 1.24, 1.39, P, c(0, 0.02, 0))
	k.w(head, "HoodPeak", 1.35, 0.6, 0.9, W, c(0, 0.85, 0.1))
	k.b(head, "Face", 0.95, 0.55, 0.12, DK, c(0, -0.1, -0.66))
	k.b(head, "Brim", 1.1, 0.12, 0.12, WD, c(0, 0.24, -0.7))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.22, -0.08, -0.73, 0.24, 0.1, EY, sd * 0.2)
		k.b(head, "BrimSide", 0.12, 0.6, 0.12, WD, c(sd * 0.53, -0.08, -0.7))
	end

	local robe = { { -0.5, -0.45, 1.8, W }, { 0, -0.5, 2.0, PL }, { 0.5, -0.45, 1.8, W }, { -0.35, 0.35, 1.6, PL },
		{ 0.35, 0.35, 1.6, W }, { -0.75, 0, 1.4, PL }, { 0.75, 0, 1.4, PL } }
	for _, d in ipairs(robe) do
		local te, tp = k.pv(body, "RobePivot", c(d[1], -0.7, d[2]))
		table.insert(rig.tail, te)
		k.tri(tp, "Robe", 0.18, d[3], 0.75, d[4], c(0, -d[3] / 2, 0) * DOWN * FACE)
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.85, 0.75, 0.15))
		k.featherWing(w, sd, { root = 0.1, z = 0.06, thick = 0.18, feathers = {
			{ 0.9, 1.3, 0.5, W, PL }, { 0.5, 1.6, 0.55, PL, PL }, { 0.15, 1.5, 0.55, W, W }, { -0.25, 1.3, 0.5, PL, PL } } })
		local a = k.arm(body, sd, c(sd * 0.9, 0.1, -0.2))
		local _, fist = k.b(a, "Fist", 0.62, 0.62, 0.62, W, c(sd * 0.45, -0.75, -0.25))
		local _, band = k.b(fist, "FistBand", 0.66, 0.14, 0.66, P, c(0, 0.18, 0), MAT.Neon)
		k.glow(band, P)
		for f = 1, 3 do k.b(fist, "Finger", 0.18, 0.2, 0.12, WD, c((f - 2) * 0.2, -0.05, -0.34)) end
	end
end

---------------------------------------------------------------- SUGARCORN (Legendary)
-- Armoured candy unicorn: white body with light-pink chest/hip/shoulder plates and pink chevrons,
-- a pink chest gem, long legs with pink knee bands and split pink hooves, long neck, horse head with
-- a white/pink striped horn, flowing pink/white mane and a big swept tail of pink and white blades.
function M.Sugarcorn(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, PL, P, PD, EY = C("#FFF4F8"), C("#F9C5DA"), C("#EF5A9A"), C("#D6407E"), C("#FF5AA8")
	local BY = 2.95
	local body = k.body(1.45, 1.35, 2.8, W, BY)
	k.b(body, "ChestPlate", 1.55, 1.3, 0.7, PL, c(0, 0.05, -1.25))
	k.b(body, "GemFrame", 0.7, 0.7, 0.1, W, c(0, 0.05, -1.6) * ANG(0, 0, PI / 4))
	k.diamond(body, "ChestGem", 0.85, 0.55, 0.16, P, c(0, 0.05, -1.64), MAT.Glass)
	k.b(body, "HipPlate", 1.55, 1.1, 0.9, PL, c(0, 0.15, 1.05))
	for _, sd in ipairs(SIDES) do
		k.b(body, "ShoulderPad", 0.18, 0.9, 1.0, PL, c(sd * 0.8, 0.2, -1.0))
		k.b(body, "PadChevron", 0.06, 0.14, 0.7, P, c(sd * 0.9, 0.35, -0.8) * ANG(0.5, 0, 0))
		k.b(body, "HipChevron", 0.06, 0.14, 0.7, P, c(sd * 0.79, 0.3, 1.15) * ANG(-0.5, 0, 0))
	end

	local lf = { up = { 0.62, 1.0, 0.75 }, col = W, w2 = 0.48, d2 = 0.58, band = P, bandY = 0.25, paw = { 0.6, 0.42, 0.72 }, pawCol = P, toes = 2, toeCol = PD }
	k.leg(body, "LegFL", BY, -0.45, -0.5, -1.0, lf)
	k.leg(body, "LegFR", BY, 0.45, -0.5, -1.0, lf)
	local lh = { up = { 0.7, 1.05, 0.85 }, col = W, w2 = 0.5, d2 = 0.6, band = P, bandY = 0.25, paw = { 0.62, 0.42, 0.74 }, pawCol = P, toes = 2, toeCol = PD, hind = true }
	k.leg(body, "LegBL", BY, -0.45, -0.45, 1.0, lh)
	k.leg(body, "LegBR", BY, 0.45, -0.45, 1.0, lh)
	rig.legKind = "quad"

	k.b(body, "Neck", 0.75, 1.5, 0.8, W, c(0, 1.05, -1.45) * ANG(-0.45, 0, 0))
	local head = k.head(body, 0.75, 0.75, 1.35, W, c(0, 1.95, -2.05), V3(0, -0.2, 0.5))
	k.w(head, "Snout", 0.62, 0.45, 0.6, W, c(0, -0.1, -0.85))
	k.b(head, "Nostril", 0.5, 0.08, 0.06, PL, c(0, -0.25, -1.13))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.3, 0.12, -0.68, 0.18, 0.1, EY, sd * 0.3)
		local ear = k.ear(head, sd, c(sd * 0.25, 0.38, 0.2))
		k.tri(ear, "Ear", 0.14, 0.45, 0.3, W, c(0, 0.22, 0) * FACE)
		k.tri(ear, "EarInner", 0.05, 0.3, 0.16, P, c(0, 0.18, -0.08) * FACE)
	end
	local hb = c(0, 0.38, -0.35) * ANG(-0.35, 0, 0)
	for i = 0, 3 do
		k.b(head, "Horn", 0.26 - i * 0.05, 0.28, 0.26 - i * 0.05, (i % 2 == 0) and W or P, hb * c(0, 0.14 + i * 0.27, 0))
	end
	k.spike(head, "HornTip", 0.5, 0.12, W, hb * c(0, 1.2, 0))

	local maneCols = { P, W, PL, P, W, PL }
	for i = 1, 6 do
		local me, mp = k.pv(body, "ManeRoot", c(0, 1.8 - (i - 1) * 0.21, -1.55 + (i - 1) * 0.12) * ANG(0.9 + i * 0.08, 0, 0))
		if i % 2 == 0 then H.group(rig, "flutter", me) end
		k.tri(mp, "Mane", 0.25, 1.3 - i * 0.05, 0.6, maneCols[i], c(0, 0.6, 0))
		k.tri(mp, "Mane", 0.22, 1.0, 0.45, P, c((i % 2 == 0) and -0.15 or 0.15, 0.45, 0.1) * ANG(0, 0, (i % 2 == 0) and 0.4 or -0.4))
	end

	local te, tp = k.pv(body, "TailRoot", c(0, 0.45, 1.45) * ANG(1.0, 0, 0))
	table.insert(rig.tail, te)
	for i, d in ipairs({ { -0.5, 2.0, P }, { -0.2, 2.4, W }, { 0.1, 2.3, PL }, { 0.4, 2.0, P }, { 0.7, 1.6, W }, { -0.8, 1.6, PL } }) do
		k.tri(tp, "TailBlade", 0.3, d[2], 0.75, d[3], ANG(d[1], 0, 0) * c((i % 2 == 0) and 0.12 or -0.12, d[2] * 0.45, 0))
	end
end

---------------------------------------------------------------- COTTON CANDY KIRIN (Legendary)
-- Slender floating kirin in pink, sky blue and white: framed blue gems on the chest and hips, slim
-- legs with white cuffs and blue hooves, long neck, white horn, layered pink/blue/white mane and a
-- huge peacock fan tail whose blades spread wider on the power move.
function M.CottonCandyCloud(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PK, PKD, BL, W = C("#F7B9D3"), C("#EBA0C0"), C("#A9D8F2"), C("#FFFFFF")
	local GEM, EY = C("#BDE6FF"), C("#C9A8FF")
	local BY = 2.8
	local body = k.body(1.25, 1.2, 2.6, PK, BY)
	k.b(body, "Chest", 1.3, 1.2, 0.6, PK, c(0, 0.05, -1.2))
	k.b(body, "ChestFrame", 0.75, 0.75, 0.12, W, c(0, 0.05, -1.52) * ANG(0, 0, PI / 4))
	k.diamond(body, "ChestGem", 0.8, 0.55, 0.16, GEM, c(0, 0.05, -1.58), MAT.Glass)
	for _, sd in ipairs(SIDES) do
		k.b(body, "ShoulderPlate", 0.14, 0.8, 0.9, W, c(sd * 0.67, 0.15, -0.9))
		k.b(body, "HipFrame", 0.12, 0.85, 0.85, W, c(sd * 0.66, 0.15, 0.95) * ANG(PI / 4, 0, 0))
		k.diamond(body, "HipGem", 0.7, 0.5, 0.14, GEM, c(sd * 0.74, 0.15, 0.95) * ANG(0, -sd * PI / 2, 0), MAT.Glass)
	end

	local lf = { up = { 0.5, 0.95, 0.6 }, col = PK, w2 = 0.36, d2 = 0.42, band = W, paw = { 0.48, 0.38, 0.55 }, pawCol = BL }
	k.leg(body, "LegFL", BY, -0.38, -0.45, -0.95, lf)
	k.leg(body, "LegFR", BY, 0.38, -0.45, -0.95, lf)
	lf.hind = true
	k.leg(body, "LegBL", BY, -0.38, -0.45, 0.95, lf)
	k.leg(body, "LegBR", BY, 0.38, -0.45, 0.95, lf)
	rig.legKind = "quad"

	k.b(body, "Neck", 0.62, 1.4, 0.7, PK, c(0, 1.0, -1.35) * ANG(-0.5, 0, 0))
	local head = k.head(body, 0.65, 0.65, 1.25, PK, c(0, 1.85, -1.95), V3(0, -0.2, 0.45))
	k.w(head, "Snout", 0.55, 0.4, 0.55, PK, c(0, -0.08, -0.8))
	k.b(head, "Brow", 0.68, 0.12, 0.6, W, c(0, 0.32, -0.25))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.26, 0.1, -0.63, 0.16, 0.09, EY, sd * 0.3)
		local ear = k.ear(head, sd, c(sd * 0.24, 0.32, 0.25))
		k.tri(ear, "Ear", 0.12, 0.42, 0.28, W, c(0, 0.2, 0) * FACE)
		k.tri(ear, "EarInner", 0.05, 0.28, 0.15, BL, c(0, 0.17, -0.07) * FACE)
	end
	k.spike(head, "Horn", 1.5, 0.3, W, c(0, 0.33, -0.2) * ANG(-0.25, 0, 0))

	local maneCols = { PK, BL, W, PK, BL, W, PK }
	for i = 1, 7 do
		local me, mp = k.pv(body, "ManeRoot", c(0, 1.7 - (i - 1) * 0.18, -1.45 + (i - 1) * 0.1) * ANG(1.0 + i * 0.06, 0, 0))
		if i % 2 == 1 then H.group(rig, "flutter", me) end
		k.tri(mp, "Mane", 0.22, 1.4 - i * 0.06, 0.55, maneCols[i], c(0, 0.65, 0))
		k.tri(mp, "Mane", 0.2, 1.0, 0.4, maneCols[(i % 7) + 1], c((i % 2 == 0) and -0.14 or 0.14, 0.45, 0.05) * ANG(0, 0, (i % 2 == 0) and 0.45 or -0.45))
	end

	local te, tp = k.pv(body, "TailRoot", c(0, 0.3, 1.35) * ANG(0.25, 0, 0))
	table.insert(rig.tail, te)
	local cols = { PK, BL, W, PK, BL, W, PK }
	for i = 1, 7 do
		local a = 0.25 + (i - 1) * 0.36
		local L = 2.4 - math.abs(i - 4) * 0.15
		local fp = k.opener(tp, "TailFeather", ANG(a, 0, 0), V3(1, 0, 0), (i - 4) * 0.1)
		k.b(fp, "Fan", 0.18 + (i % 2) * 0.04, L, 0.62, cols[i], c(0, L * 0.5 + 0.3, 0))
		k.tri(fp, "FanTip", 0.16, 0.4, 0.62, cols[i], c(0, L + 0.5, 0))
	end
	k.b(tp, "FanHub", 0.5, 0.5, 0.5, W, c(0, 0.1, 0))
end

---------------------------------------------------------------- CANDY QUEEN BEE (Mythical)
-- Hovering royal bee: dark thorax with a pink ruff collar and a gold-framed brooch, big yellow/dark
-- striped abdomen with a pink stinger, dark head under a gold helmet crowned with pink crystals,
-- glowing pink eyes, segmented antennae with pink tips, six thin legs with pink feet, two pairs of
-- pink gold-framed wings.
function M.QueenBee(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local Y, DK, DKL, P, PD, EY = C("#F5C62E"), C("#4A2A1A"), C("#5E3A26"), C("#F06AA0"), C("#D84A86"), C("#FF7AB8")
	local BY = 2.3
	local body = k.body(1.05, 1.05, 1.0, DK, BY)
	for i = 0, 5 do
		local a = (i - 2.5) / 5 * 2.4
		k.b(body, "Ruff", 0.5, 0.45, 0.45, (i % 2 == 0) and P or PD, c(math.sin(a) * 0.6, 0.45, -math.cos(a) * 0.5) * ANG(0.3, a, 0))
	end
	k.b(body, "BroochFrame", 0.42, 0.42, 0.08, Y, c(0, 0.12, -0.53) * ANG(0, 0, PI / 4))
	k.diamond(body, "Brooch", 0.5, 0.36, 0.1, P, c(0, 0.12, -0.57), MAT.Glass)

	local ae, ap = k.pv(body, "AbdomenPivot", c(0, 0.0, 0.45) * ANG(0.35, 0, 0))
	H.group(rig, "abdomen", ae)
	for i, d in ipairs({ { 1.25, Y }, { 1.45, DK }, { 1.5, Y }, { 1.35, DK }, { 1.1, Y }, { 0.8, DK } }) do
		k.b(ap, "Abdomen", d[1], d[1] * 0.92, 0.5, d[2], c(0, 0, 0.3 + (i - 1) * 0.48))
	end
	k.spike(ap, "Stinger", 0.9, 0.35, P, c(0, 0, 2.95) * ANG(PI / 2, 0, 0))

	local head = k.head(body, 0.8, 0.8, 0.8, DK, c(0, 0.95, -0.25), V3(0, -0.35, 0.15))
	k.b(head, "Helmet", 0.9, 0.42, 0.9, Y, c(0, 0.25, 0.02))
	k.b(head, "HelmetCheek", 0.9, 0.5, 0.3, Y, c(0, -0.05, 0.3))
	k.b(head, "Face", 0.62, 0.38, 0.06, DKL, c(0, -0.12, -0.42))
	k.b(head, "CrownBand", 0.75, 0.14, 0.75, Y, c(0, 0.5, 0))
	for _, d in ipairs({ { 0, 0.7 }, { -0.26, 0.5 }, { 0.26, 0.5 } }) do
		k.crystal(head, "CrownGem", d[2], 0.18, P, c(d[1], 0.55, -0.15) * ANG(0, 0, -d[1] * 0.6), MAT.Glass)
	end
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.17, -0.1, -0.46, 0.2, 0.1, EY, -sd * 0.3)
		k.tri(head, "CrownSpike", 0.08, 0.35, 0.22, Y, c(sd * 0.36, 0.62, 0.15) * FACE)
		local ant = k.ear(head, sd, c(sd * 0.22, 0.45, 0.05), "antenna")
		local p1, p2, p3 = V3(0, 0, 0), V3(sd * 0.2, 0.55, -0.1), V3(sd * 0.45, 0.95, -0.25)
		k.bar(ant, "Antenna", p1, p2, 0.11, DK, nil, nil, V3(1, 0, 0))
		k.bar(ant, "Antenna", p2, p3, 0.1, Y, nil, nil, V3(1, 0, 0))
		k.b(ant, "AntennaTip", 0.2, 0.2, 0.2, P, c(p3.X, p3.Y, p3.Z))
	end

	local lg = { up = { 0.16, 0.45, 0.16 }, col = DK, w2 = 0.14, d2 = 0.14, col2 = Y, paw = { 0.2, 0.28, 0.2 }, pawCol = P, lh = 0.55, splay = 0.5 }
	for _, z in ipairs({ -0.3, 0, 0.3 }) do
		k.leg(body, "LegL", BY, -0.4, -0.45, z, lg)
		k.leg(body, "LegR", BY, 0.4, -0.45, z, lg)
	end
	rig.legKind = "bug6"

	for _, sd in ipairs(SIDES) do
		for tier, d in ipairs({ { 0.5, 2.6, 1.0, 0.0 }, { 0.12, 1.9, 0.75, 0.3 } }) do
			-- d = { angle above horizontal, length, width, z offset }
			local w = k.wing(body, sd, c(sd * 0.45, 0.45, 0.05 + d[4]) * ANG(0, -sd * 0.35, 0), tier)
			local dir = V3(math.cos(d[1]) * sd, math.sin(d[1]), 0)
			local A, B = dir * 0.2, dir * d[2]
			local nrm = V3(-dir.Y, dir.X, 0) * d[3] * 0.5
			k.bar(w, "WingPanel", A, B, d[3], P, nil, 0.05, nil, 0.06)
			k.bar(w, "WingFrame", A + nrm, B + nrm, 0.1, Y)
			k.bar(w, "WingFrame", A - nrm, B - nrm, 0.1, Y)
			k.bar(w, "WingFrame", B + nrm, B - nrm, 0.1, Y)
			k.bar(w, "WingVein", A, B * 0.9, 0.07, Y)
		end
	end
end

---------------------------------------------------------------- CHOCOLATE COLOSSUS (Mythical)
-- Chocolate golem: broad torso with pink trim, a V of pink piping and a pink heart gem, pink belt and
-- loin panel, chocolate-bar shoulder pads (grooved grid), big arms with pink bands and huge fists,
-- column legs with pink knee bands and pink soles, small horned head under a pink crown.
function M.ChocoTitan(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local CH, CHD, CHL = C("#7A4426"), C("#5E321B"), C("#8E5532")
	local PL, P, HN, EY = C("#F6B8C8"), C("#F0478A"), C("#F2E6D8"), C("#FF6FA8")
	local BY = 3.6
	local body = k.body(2.5, 2.1, 1.7, CH, BY)
	k.b(body, "Collar", 2.3, 0.22, 0.2, PL, c(0, 0.75, -0.88))
	for _, sd in ipairs(SIDES) do
		k.b(body, "Pec", 1.1, 0.9, 0.25, CHL, c(sd * 0.6, 0.35, -0.86))
		k.b(body, "TrimV", 0.2, 1.1, 0.12, PL, c(sd * 0.55, 0.15, -1.0) * ANG(0, 0, -sd * 0.5))
	end
	k.diamond(body, "HeartGem", 0.85, 0.55, 0.16, P, c(0, 0.2, -1.07), MAT.Glass)
	k.b(body, "Belt", 2.2, 0.28, 1.55, PL, c(0, -0.95, 0))
	k.b(body, "Hips", 2.0, 0.6, 1.4, CH, c(0, -1.35, 0))
	k.b(body, "Loin", 0.9, 1.0, 0.12, CHD, c(0, -1.55, -0.76))
	k.tri(body, "LoinV", 0.1, 0.7, 0.55, P, c(0, -1.5, -0.83) * DOWN * FACE)

	local lg = { up = { 1.1, 0.8, 1.1 }, col = CH, w2 = 1.0, d2 = 1.05, band = PL, bandY = 0.15, paw = { 1.4, 0.5, 1.55, -0.1 }, pawCol = CH }
	for _, sd in ipairs(SIDES) do
		local _, _, knee, lh = k.leg(body, sd < 0 and "LegL" or "LegR", BY, sd * 0.65, -1.55, 0, lg)
		k.b(knee, "Sole", 1.45, 0.14, 1.6, P, c(0, -lh - 0.43, -0.1))
	end
	rig.legKind = "biped"

	for _, sd in ipairs(SIDES) do
		local a = k.arm(body, sd, c(sd * 1.5, 0.55, 0))
		local _, pad = k.b(a, "ShoulderBar", 1.5, 0.85, 1.5, CH, c(sd * 0.2, 0.3, 0))
		k.b(pad, "Groove", 1.52, 0.04, 0.07, CHD, c(0, 0.43, 0))
		k.b(pad, "Groove", 0.07, 0.04, 1.52, CHD, c(0, 0.43, 0))
		k.b(pad, "Groove", 0.04, 0.87, 0.07, CHD, c(sd * 0.76, 0, 0))
		k.b(pad, "Groove", 0.04, 0.07, 1.52, CHD, c(sd * 0.76, 0, 0))
		k.b(pad, "Groove", 0.07, 0.87, 0.04, CHD, c(0, 0, -0.76))
		k.b(pad, "Groove", 1.52, 0.07, 0.04, CHD, c(0, 0, -0.76))
		k.b(a, "PadTrim", 1.45, 0.2, 1.45, PL, c(sd * 0.2, -0.2, 0))
		k.b(a, "UpperArm", 0.95, 0.9, 0.95, CH, c(sd * 0.3, -0.75, 0))
		k.b(a, "ArmBand", 1.05, 0.2, 1.05, PL, c(sd * 0.3, -1.25, 0))
		k.b(a, "Forearm", 1.35, 1.0, 1.35, CHL, c(sd * 0.35, -1.85, -0.05))
		k.b(a, "Cuff", 1.4, 0.2, 1.4, PL, c(sd * 0.35, -2.3, -0.05))
		local _, fist = k.b(a, "Fist", 1.6, 1.25, 1.5, CH, c(sd * 0.35, -2.95, -0.1))
		for f = 1, 4 do k.b(fist, "Finger", 0.34, 0.4, 0.2, CHD, c((f - 2.5) * 0.37, 0.2, -0.8)) end
		k.b(fist, "Knuckles", 1.62, 0.18, 1.52, PL, c(0, 0.5, 0))
	end

	local head = k.head(body, 1.05, 1.05, 1.0, CH, c(0, 1.55, -0.15), V3(0, -0.5, 0.1))
	k.b(head, "Brow", 1.1, 0.22, 0.3, CHD, c(0, 0.2, -0.45))
	k.b(head, "Mouth", 0.45, 0.06, 0.05, CHD, c(0, -0.3, -0.52))
	k.b(head, "CrownBand", 0.95, 0.22, 0.9, P, c(0, 0.6, 0.0))
	for i = -2, 2 do
		k.tri(head, "CrownSpike", 0.12, (i == 0) and 0.6 or 0.4, 0.32, P, c(i * 0.22, (i == 0) and 0.95 or 0.85, -0.45) * FACE)
	end
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.24, 0.05, -0.53, 0.26, 0.11, EY, sd * 0.2)
		k.spike(head, "Horn", 0.55, 0.22, HN, c(sd * 0.55, 0.3, -0.05) * ANG(0, 0, -sd * 1.0))
	end
end

return M
