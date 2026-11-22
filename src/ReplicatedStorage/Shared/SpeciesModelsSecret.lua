-- SpeciesModelsSecret: hand-authored, reference-faithful models for the Secret portal creatures
-- (Glitchling, Void Emperor, Error Cat, Null Bunny, The Watcher).
-- Location: ReplicatedStorage > Shared > SpeciesModelsSecret (ModuleScript), merged into SpeciesModels.

local K = require(script.Parent.ModelKit)
local V3, CF, ANG, PI, MAT, C = K.V3, K.CF, K.ANG, K.PI, K.MAT, K.C
local FACE, DOWN = ANG(0, PI / 2, 0), ANG(0, 0, PI)
local FLAT = ANG(PI / 2, 0, 0)
local SIDES = { -1, 1 }

local M = {}

-- glowing line between two points on a part (Neon bar registered as a glow)
local function line(k, parent, A, B, w, col, up)
	local _, p = k.bar(parent, "GlowLine", A, B, w, col, MAT.Neon, nil, up, w * 0.6)
	k.glow(p, col)
end

---------------------------------------------------------------- GLITCHLING (Secret)
-- Corrupted pup: black blocky body traced with magenta lines and turquoise plates, a turquoise visor
-- framing a dark screen with one big glowing magenta pixel eye, turquoise chin, tall black ears with
-- magenta edges, black legs with turquoise feet bands, a zigzag pixel tail and loose pixel cubes that
-- drift around it (they scatter on the power move).
function M.Glitchling(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local BK, BKL, TQ, MG = C("#1A1A1F"), C("#2A2A32"), C("#3FF0C0"), C("#FF2AA8")
	local BY = 1.55
	local body = k.body(1.4, 1.2, 1.7, BK, BY)
	k.b(body, "BackPlate", 1.2, 0.2, 1.0, TQ, c(0, 0.62, 0.2))
	for _, sd in ipairs(SIDES) do
		line(k, body, V3(sd * 0.71, 0.4, -0.7), V3(sd * 0.71, 0.4, 0.1), 0.1, MG, V3(1, 0, 0))
		line(k, body, V3(sd * 0.71, 0.4, 0.1), V3(sd * 0.71, -0.3, 0.1), 0.1, MG, V3(1, 0, 0))
		k.b(body, "SidePlate", 0.08, 0.35, 0.5, TQ, c(sd * 0.72, -0.35, 0.55))
	end
	local lg = { up = { 0.6, 0.5, 0.65 }, col = BK, w2 = 0.5, d2 = 0.6, band = TQ, bandY = 0.35, paw = { 0.7, 0.3, 0.8 }, pawCol = BK }
	k.leg(body, "LegFL", BY, -0.45, -0.45, -0.6, lg)
	k.leg(body, "LegFR", BY, 0.45, -0.45, -0.6, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.45, -0.45, 0.6, lg)
	k.leg(body, "LegBR", BY, 0.45, -0.45, 0.6, lg)
	rig.legKind = "quad"

	local head = k.head(body, 1.15, 1.0, 1.0, BK, c(0, 0.9, -0.95), V3(0, -0.4, 0.3))
	k.b(head, "VisorTop", 1.25, 0.28, 1.05, TQ, c(0, 0.4, -0.02))
	for _, sd in ipairs(SIDES) do k.b(head, "VisorSide", 0.22, 0.75, 1.05, TQ, c(sd * 0.55, 0.0, -0.02)) end
	k.b(head, "Screen", 0.8, 0.55, 0.06, BKL, c(0, 0.0, -0.52))
	local e, p = k.b(head, "PixelEye", 0.3, 0.3, 0.06, MG, c(0, 0.0, -0.56), MAT.Neon)
	table.insert(rig.eyes, e)
	k.glow(p, MG)
	k.w(head, "Chin", 0.9, 0.3, 0.4, TQ, c(0, -0.55, -0.4) * DOWN)
	for _, sd in ipairs(SIDES) do
		local ear = k.ear(head, sd, c(sd * 0.32, 0.5, 0.1) * ANG(0, 0, -sd * 0.12))
		k.tri(ear, "Ear", 0.25, 1.2, 0.6, BK, c(0, 0.6, 0) * FACE)
		k.tri(ear, "EarEdge", 0.06, 0.95, 0.12, MG, c(-sd * 0.0, 0.5, -0.14) * ANG(0, 0, sd * 0.25) * FACE, MAT.Neon)
	end

	local tip = k.tail(body, c(0, 0.3, 0.85), {
		{ 0.3, 0.3, 0.55, -0.9, BK }, { 0.3, 0.3, 0.5, 0.9, BK }, { 0.28, 0.28, 0.5, -1.2, TQ }, { 0.28, 0.28, 0.45, 0.6, BK } })
	k.b(tip, "TailPixel", 0.32, 0.32, 0.2, MG, c(0, 0, 0.3), MAT.Neon)

	-- drifting pixel cubes
	for i, d in ipairs({ { -1.2, 2.1, -0.6 }, { 1.3, 1.9, -0.8 }, { -1.4, 1.0, 0.4 }, { 1.4, 0.8, 0.2 }, { -0.9, 2.6, 0.8 }, { 1.0, 2.5, 0.6 } }) do
		local fe, fp = k.pv(body, "Fragment", c(d[1], d[2] - BY, d[3]))
		fe.fragIndex = i
		H.group(rig, "fragments", fe)
		k.b(fp, "Cube", 0.4, 0.22, 0.25, BK, CF())
		k.b(fp, "CubeFace", 0.42, 0.08, 0.27, (i % 2 == 0) and TQ or MG, c(0, 0.08, 0), MAT.Neon)
	end
end

---------------------------------------------------------------- VOID EMPEROR (Secret)
-- Dark armoured emperor: black torso with purple plates and a glowing turquoise Y on the chest, purple
-- tabard with crystal gems, a purple cape, huge shoulder pads with purple gems and turquoise trim, a
-- closed fist and an open clawed hand, black helmet with a spiked crown and purple crystal, glowing
-- turquoise eyes, curled black-purple horns, heavy feet with turquoise stripes.
function M.VoidEmperor(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local BK, BKL, PU, PUL, TQ, GEM = C("#24202C"), C("#34303E"), C("#6A2AA8"), C("#8A3ACF"), C("#3FF0D0"), C("#B060FF")
	local BY = 3.4
	local body = k.body(2.4, 2.2, 1.5, BK, BY)
	line(k, body, V3(0, -0.4, -0.78), V3(0, 0.2, -0.78), 0.14, TQ)
	line(k, body, V3(0, 0.2, -0.78), V3(-0.4, 0.65, -0.78), 0.14, TQ)
	line(k, body, V3(0, 0.2, -0.78), V3(0.4, 0.65, -0.78), 0.14, TQ)
	for _, sd in ipairs(SIDES) do
		k.b(body, "ChestPlate", 0.75, 1.0, 0.2, PU, c(sd * 0.75, 0.2, -0.78))
		line(k, body, V3(sd * 0.95, -0.2, -0.86), V3(sd * 0.75, -0.75, -0.86), 0.1, TQ)
	end
	local te, tp = k.pv(body, "Tabard", c(0, -0.6, -0.8))
	table.insert(rig.tail, te)
	k.b(tp, "Tabard", 0.7, 1.9, 0.1, PU, c(0, -0.9, 0))
	k.tri(tp, "TabardTip", 0.1, 0.5, 0.7, PU, c(0, -2.1, 0) * DOWN * FACE)
	k.diamond(tp, "TabardGem", 0.5, 0.3, 0.1, GEM, c(0, -1.3, -0.07), MAT.Glass)
	k.diamond(body, "BeltGem", 0.4, 0.3, 0.1, GEM, c(0, -0.55, -0.88), MAT.Glass)
	for _, x in ipairs({ -0.8, 0, 0.8 }) do
		local ce, cp = k.pv(body, "Cape", c(x, 0.7, 0.78) * ANG(0, 0, x * 0.15))
		table.insert(rig.tail, ce)
		k.tri(cp, "CapePanel", 0.12, 3.5, 1.0, PU, c(0, -1.75, 0) * DOWN * FACE)
	end
	k.b(body, "Hips", 2.0, 0.6, 1.3, BKL, c(0, -1.3, 0))

	local lg = { up = { 1.0, 0.7, 1.0 }, col = BK, w2 = 0.9, d2 = 0.95, paw = { 1.3, 0.5, 1.5, -0.1 }, pawCol = BK }
	for _, sd in ipairs(SIDES) do
		local _, _, knee, lh = k.leg(body, sd < 0 and "LegL" or "LegR", BY, sd * 0.6, -1.5, 0, lg)
		local _, st = k.b(knee, "FootStripe", 1.32, 0.1, 0.06, TQ, c(0, -lh - 0.25, -0.86), MAT.Neon)
		k.glow(st, TQ)
	end
	rig.legKind = "biped"

	for _, sd in ipairs(SIDES) do
		local a = k.arm(body, sd, c(sd * 1.55, 0.6, 0))
		k.b(a, "Shoulder", 1.5, 0.8, 1.4, PU, c(sd * 0.2, 0.3, 0))
		k.b(a, "ShoulderTop", 1.2, 0.3, 1.1, BKL, c(sd * 0.2, 0.8, 0))
		k.diamond(a, "ShoulderGem", 0.5, 0.3, 0.1, GEM, c(sd * 0.2, 0.35, -0.75), MAT.Glass)
		line(k, a, V3(sd * -0.5, -0.05, -0.72), V3(sd * 0.9, -0.05, -0.72), 0.1, TQ)
		k.b(a, "UpperArm", 0.95, 1.0, 0.95, BK, c(sd * 0.3, -0.6, 0))
		k.b(a, "Forearm", 1.3, 1.0, 1.3, PU, c(sd * 0.35, -1.5, -0.05))
		if sd > 0 then
			local _, fist = k.b(a, "Fist", 1.45, 1.15, 1.4, BK, c(sd * 0.35, -2.45, -0.1))
			for f = 1, 3 do k.b(fist, "Knuckle", 0.4, 0.34, 0.2, BKL, c((f - 2) * 0.44, 0.2, -0.75)) end
		else
			local _, hand = k.b(a, "Palm", 1.2, 0.4, 1.1, BK, c(sd * 0.35, -2.2, -0.2))
			for f = 1, 4 do k.b(hand, "Claw", 0.22, 0.65, 0.22, PU, c((f - 2.5) * 0.3, -0.45, -0.35) * ANG(-0.4, 0, 0)) end
		end
	end

	local head = k.head(body, 1.0, 1.05, 0.95, BK, c(0, 1.6, -0.1), V3(0, -0.5, 0.1))
	k.b(head, "FacePlate", 0.8, 0.5, 0.06, BKL, c(0, 0.05, -0.49))
	for _, sd in ipairs(SIDES) do k.eye(head, sd * 0.18, 0.1, -0.53, 0.2, 0.09, TQ, 0) end
	local _, band = k.b(head, "CrownBand", 1.05, 0.16, 1.0, TQ, c(0, 0.42, 0), MAT.Neon)
	k.glow(band, TQ)
	for i = -2, 2 do k.spike(head, "CrownSpike", (i == 0) and 0.6 or 0.4, 0.15, BK, c(i * 0.2, 0.52, -0.3)) end
	k.crystal(head, "CrownCrystal", 0.75, 0.24, GEM, c(0, 0.5, -0.35), MAT.Glass, 0.05)
	for _, sd in ipairs(SIDES) do
		-- ram horn: up and out, then curling down and back in
		local pts = { V3(sd * 0.4, 0.45, 0.1), V3(sd * 0.8, 0.95, 0.15), V3(sd * 1.25, 0.85, 0.2), V3(sd * 1.38, 0.35, 0.15), V3(sd * 1.12, 0.02, 0.0) }
		for i = 1, #pts - 1 do k.bar(head, "Horn", pts[i], pts[i + 1], 0.42 - i * 0.06, (i % 2 == 0) and PU or BKL, nil, nil, V3(0, 0, 1)) end
	end
end

---------------------------------------------------------------- ERROR CAT (Secret)
-- Glitched cat: black body with magenta armour plates and glowing green circuit lines, black legs with
-- magenta paws, black head under a magenta mask shifted off-centre with dead-pixel squares, glowing green
-- eyes, magenta ears with black insides, magenta whiskers, a segmented zigzag tail ending in a magenta blade.
function M.Errorcat(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local MG, MGD, BK, BKL, GN = C("#F21FC8"), C("#C8189E"), C("#1C1C22"), C("#2C2C34"), C("#2AF07A")
	local BY = 1.75
	local body = k.body(1.3, 1.1, 2.3, BK, BY)
	k.b(body, "BackPlate", 1.0, 0.18, 1.3, MG, c(0, 0.6, -0.2))
	k.tri(body, "ChestV", 0.12, 0.9, 1.0, MG, c(0, -0.05, -1.17) * DOWN * FACE)
	for _, sd in ipairs(SIDES) do
		k.b(body, "SidePlate", 0.1, 0.55, 1.0, MG, c(sd * 0.66, 0.15, 0.1) * ANG(-0.25, 0, 0))
		line(k, body, V3(sd * 0.67, -0.3, -0.9), V3(sd * 0.67, -0.3, 0.2), 0.07, GN, V3(1, 0, 0))
		line(k, body, V3(sd * 0.67, -0.3, 0.2), V3(sd * 0.67, 0.0, 0.6), 0.07, GN, V3(1, 0, 0))
	end
	local lg = { up = { 0.5, 0.65, 0.6 }, col = BK, w2 = 0.42, d2 = 0.5, paw = { 0.6, 0.3, 0.7 }, pawCol = MG, toes = 3, toeCol = MG }
	local function legLine(knee, lh) line(k, knee, V3(0.22, -0.1, -0.26), V3(0.22, -lh + 0.1, -0.26), 0.06, GN, V3(1, 0, 0)) end
	local _, _, k1, l1 = k.leg(body, "LegFL", BY, -0.42, -0.45, -0.85, lg); legLine(k1, l1)
	local _, _, k2, l2 = k.leg(body, "LegFR", BY, 0.42, -0.45, -0.85, lg); legLine(k2, l2)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.42, -0.45, 0.85, lg)
	k.leg(body, "LegBR", BY, 0.42, -0.45, 0.85, lg)
	rig.legKind = "quad"

	local head = k.head(body, 1.05, 0.95, 1.0, BK, c(0, 0.85, -1.4), V3(0, -0.4, 0.3))
	k.w(head, "Muzzle", 0.55, 0.35, 0.4, BKL, c(0, -0.28, -0.65))
	-- glitch mask: magenta block shifted toward the creature's left, with dead-pixel squares
	k.b(head, "GlitchMask", 0.7, 0.75, 0.12, MG, c(-0.2, 0.15, -0.53) * ANG(0, 0, 0.12))
	k.b(head, "DeadPixel", 0.1, 0.16, 0.04, BK, c(-0.42, 0.35, -0.6))
	k.b(head, "DeadPixel", 0.1, 0.24, 0.04, BK, c(-0.42, 0.05, -0.6))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.22, 0.05, (sd < 0) and -0.61 or -0.53, 0.2, 0.1, GN, sd * 0.3)
		local ear = k.ear(head, sd, c(sd * 0.35, 0.45, 0.1) * ANG(0, 0, -sd * 0.2))
		k.tri(ear, "Ear", 0.2, 0.75, 0.55, MG, c(0, 0.37, 0) * FACE)
		k.tri(ear, "EarInner", 0.07, 0.5, 0.3, BK, c(0, 0.3, -0.1) * FACE)
		for i = -1, 1 do
			k.b(head, "Whisker", 0.6, 0.04, 0.04, MG, c(sd * 0.65, -0.2 + i * 0.09, -0.5) * ANG(0, 0, sd * i * 0.15))
		end
	end

	local tip = k.tail(body, c(0, 0.35, 1.15), {
		{ 0.3, 0.3, 0.55, -1.1, BK }, { 0.3, 0.3, 0.5, 0.5, BK }, { 0.28, 0.28, 0.5, -0.8, BK }, { 0.28, 0.28, 0.45, 0.6, BK } })
	for _, e in ipairs(rig.tail) do k.b(e.part, "TailBand", 0.32, 0.06, 0.08, GN, c(0, 0.16, 0), MAT.Neon) end
	k.w(tip, "TailBlade", 0.3, 0.3, 0.9, MG, c(0, 0, 0.6) * ANG(0, PI, 0))
end

---------------------------------------------------------------- NULL BUNNY (Secret)
-- Void rabbit: black body traced with white edge lines and a white V on the chest, red glowing chevrons on
-- the haunches, white clawed paws, black head with a white muzzle and a glowing red visor slit, tall ears
-- framed in white, and segmented red/black arcs curling around the ears.
function M.NullBunny(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local BK, BKL, W, RD = C("#16161A"), C("#26262C"), C("#F2F2F2"), C("#FF2238")
	local BY = 1.55
	local body = k.body(1.4, 1.25, 1.9, BK, BY)
	for _, sd in ipairs(SIDES) do
		k.b(body, "Haunch", 0.45, 1.05, 1.1, BK, c(sd * 0.72, -0.05, 0.45))
		k.bar(body, "WhiteEdge", V3(sd * 0.95, 0.5, 0.0), V3(sd * 0.95, -0.55, 0.95), 0.1, W, nil, nil, V3(1, 0, 0))
		line(k, body, V3(sd * 0.96, 0.35, 0.35), V3(sd * 0.96, 0.0, 0.6), 0.14, RD, V3(1, 0, 0))
		line(k, body, V3(sd * 0.96, 0.0, 0.6), V3(sd * 0.96, -0.35, 0.35), 0.14, RD, V3(1, 0, 0))
		k.bar(body, "ChestV", V3(sd * 0.6, 0.5, -0.98), V3(0, -0.25, -0.98), 0.12, W)
	end
	local lf = { up = { 0.45, 0.4, 0.5 }, col = BK, w2 = 0.4, d2 = 0.45, paw = { 0.55, 0.25, 0.75 }, pawCol = W, toes = 3, toeCol = W }
	k.leg(body, "LegFL", BY, -0.42, -0.45, -0.7, lf)
	k.leg(body, "LegFR", BY, 0.42, -0.45, -0.7, lf)
	local lh = { up = { 0.5, 0.4, 0.7 }, col = BK, w2 = 0.45, d2 = 0.6, paw = { 0.65, 0.3, 1.1 }, pawCol = W, toes = 3, toeCol = W, hind = true }
	k.leg(body, "LegBL", BY, -0.65, -0.45, 0.55, lh)
	k.leg(body, "LegBR", BY, 0.65, -0.45, 0.55, lh)
	rig.legKind = "quad"

	local head = k.head(body, 1.05, 1.0, 1.1, BK, c(0, 0.95, -1.15), V3(0, -0.4, 0.35))
	k.b(head, "Muzzle", 0.8, 0.45, 0.35, W, c(0, -0.3, -0.62))
	local e, p = k.b(head, "Visor", 0.85, 0.2, 0.06, RD, c(0, 0.12, -0.57), MAT.Neon)
	table.insert(rig.eyes, e)
	k.glow(p, RD)
	for _, sd in ipairs(SIDES) do
		local ear = k.ear(head, sd, c(sd * 0.3, 0.5, 0.1) * ANG(-0.15, 0, -sd * 0.12), "bunny")
		k.b(ear, "EarFrame", 0.42, 1.7, 0.2, W, c(0, 0.85, 0))
		k.b(ear, "Ear", 0.3, 1.55, 0.24, BK, c(0, 0.85, -0.02))
		k.tri(ear, "EarTip", 0.42, 0.3, 0.2, W, c(0, 1.85, 0))
		-- red/black arc curling around the ear
		local pts = { V3(sd * 0.45, 0.3, 0.1), V3(sd * 1.0, 0.75, 0.15), V3(sd * 1.15, 1.35, 0.2), V3(sd * 0.85, 1.75, 0.2), V3(sd * 0.4, 1.85, 0.15) }
		for i = 1, #pts - 1 do
			k.bar(head, "Arc", pts[i] + (pts[i + 1] - pts[i]) * 0.08, pts[i + 1] - (pts[i + 1] - pts[i]) * 0.08, 0.2, (i % 2 == 0) and RD or BKL, (i % 2 == 0) and MAT.Neon or nil, nil, V3(0, 0, 1))
		end
	end
	k.tail(body, c(0, 0.3, 0.95), { { 0.7, 0.6, 0.5, -0.4, W } })
end

---------------------------------------------------------------- THE WATCHER (Secret)
-- Floating void eye: a black angular body around a big glowing turquoise eye with a slit pupil inside a
-- magenta diamond frame, a black hood with a turquoise stripe and spikes on top, black stalactite spikes
-- with magenta edges hanging below, and a tilted hexagonal ring (half magenta, half turquoise) turning around it.
function M.TheWatcher(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local BK, BKL, MG, TQ = C("#24182E"), C("#34263F"), C("#E0288A"), C("#3FF0C0")
	local BY = 1.8
	local body = k.body(1.9, 1.5, 1.4, BK, BY)
	rig.legKind = "none"
	k.diamond(body, "EyeFrame", 1.55, 1.9, 0.12, MG, c(0, 0, -0.72) * ANG(0, 0, PI / 2))
	k.diamond(body, "EyeRim", 1.35, 1.6, 0.13, BK, c(0, 0, -0.74) * ANG(0, 0, PI / 2))
	-- wide diamond eye (the neon core block carries the blink), slit pupil
	k.diamond(body, "EyeShape", 1.0, 1.35, 0.1, TQ, c(0, 0, -0.78) * ANG(0, 0, PI / 2), MAT.Neon)
	local e, p = k.b(body, "Eye", 0.55, 0.45, 0.06, TQ, c(0, 0, -0.84), MAT.Neon)
	table.insert(rig.eyes, e)
	k.glow(p, TQ)
	k.b(body, "Pupil", 0.1, 0.62, 0.04, BK, c(0, 0, -0.88))

	local he = k.head(body, 1.7, 0.6, 1.3, BK, c(0, 0.95, 0.05), V3(0, -0.3, 0.2))
	k.w(he, "HoodFront", 1.7, 0.5, 0.6, BKL, c(0, 0.0, -0.9))
	local _, st = k.b(he, "HoodStripe", 0.25, 0.64, 1.34, TQ, c(0, 0, 0), MAT.Neon)
	k.glow(st, TQ)
	for i, x in ipairs({ -0.65, -0.3, 0.3, 0.65 }) do
		k.spike(he, "HoodSpike", 0.9 - math.abs(x) * 0.4, 0.35, BK, c(x, 0.25, 0.1) * ANG(0, 0, -x * 0.4))
		if i == 1 or i == 4 then k.b(he, "SpikeMark", 0.08, 0.3, 0.08, TQ, c(x * 1.05, 0.5, -0.08), MAT.Neon) end
	end

	for i, x in ipairs({ -0.7, -0.35, 0, 0.35, 0.7 }) do
		local L = 1.6 - math.abs(x) * 1.0
		k.spike(body, "Stalactite", L, 0.45, BK, c(x, -0.7, 0.05) * DOWN)
		k.tri(body, "StalactiteEdge", 0.06, L * 0.7, 0.18, MG, c(x, -0.75 - L * 0.32, -0.2) * DOWN * FACE)
	end

	local re, rp = k.pv(body, "Ring", c(0, -0.15, 0) * ANG(0.4, 0, 0.2))
	H.group(rig, "rings", re)
	for i = 0, 5 do
		local a0, a1 = i / 6 * PI * 2, (i + 1) / 6 * PI * 2
		local A = V3(math.cos(a0) * 1.95, 0, math.sin(a0) * 1.55)
		local B = V3(math.cos(a1) * 1.95, 0, math.sin(a1) * 1.55)
		k.bar(rp, "RingSeg", A, B, 0.2, (i < 3) and TQ or MG, nil, nil, V3(0, 1, 0))
	end
end

return M
