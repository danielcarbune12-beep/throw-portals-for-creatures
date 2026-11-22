-- SpeciesModelsFrozen: hand-authored, reference-faithful models for the Frozen world
-- (Frostpaw, Snowpuff, Icicle Owl, Glacier Yeti, Aurora Fox, Blizzard Bear, Crystalwing Dragon).
-- Location: ReplicatedStorage > Shared > SpeciesModelsFrozen (ModuleScript), merged into SpeciesModels.

local K = require(script.Parent.ModelKit)
local V3, CF, ANG, PI, MAT, C = K.V3, K.CF, K.ANG, K.PI, K.MAT, K.C
local FACE, DOWN = ANG(0, PI / 2, 0), ANG(0, 0, PI)
local SIDES = { -1, 1 }

local M = {}

---------------------------------------------------------------- FROSTPAW (Common)
-- Ice-blue kitten: white paws and muzzle, dark nose, cheek tufts, stern brows over glowing blue eyes,
-- pointed ears with white insides, a blue scarf with a knot and two hanging ends, a segmented tail
-- rising to a white tip.
function M.Frostpaw(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local IB, IBD, W, WD, SC, SCD, N, EY = C("#BFDDF2"), C("#A6CBE6"), C("#FFFFFF"), C("#E8EEF4"), C("#5AA8E8"), C("#4690D4"), C("#3A3A40"), C("#3FC8FF")
	local BY = 1.6
	local body = k.body(1.4, 1.2, 2.0, IB, BY)
	k.b(body, "Chest", 1.45, 1.25, 0.6, IB, c(0, 0.05, -0.9))
	local lg = { up = { 0.62, 0.55, 0.7 }, col = IB, w2 = 0.52, d2 = 0.6, paw = { 0.7, 0.32, 0.85 }, pawCol = W, toes = 2, toeCol = WD }
	k.leg(body, "LegFL", BY, -0.46, -0.45, -0.7, lg)
	k.leg(body, "LegFR", BY, 0.46, -0.45, -0.7, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.46, -0.45, 0.72, lg)
	k.leg(body, "LegBR", BY, 0.46, -0.45, 0.72, lg)
	rig.legKind = "quad"

	-- scarf: band, knot, two flapping ends
	k.b(body, "Scarf", 1.55, 0.32, 0.4, SC, c(0, 0.45, -1.05))
	k.b(body, "ScarfKnot", 0.4, 0.35, 0.2, SCD, c(0.15, 0.35, -1.3))
	for i, x in ipairs({ -0.05, 0.3 }) do
		local se, sp = k.pv(body, "ScarfEnd", c(x, 0.25, -1.3))
		H.group(rig, "scarfEnds", se)
		k.b(sp, "ScarfTail", 0.32, 0.9, 0.1, SC, c(0, -0.45, 0) * ANG(0, 0, (i == 1) and 0.1 or -0.1))
	end

	local head = k.head(body, 1.35, 1.15, 1.2, IB, c(0, 1.05, -1.2), V3(0, -0.45, 0.35))
	local fz = -0.6
	k.b(head, "Muzzle", 0.8, 0.42, 0.4, W, c(0, -0.3, fz - 0.15))
	k.b(head, "Nose", 0.24, 0.14, 0.1, N, c(0, -0.12, fz - 0.37))
	k.b(head, "Crown", 1.2, 0.2, 0.9, IBD, c(0, 0.6, 0.1))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.55, 0.18, 0.25, IBD, c(sd * 0.35, 0.24, fz - 0.03) * ANG(0, 0, sd * 0.3))
		k.eye(head, sd * 0.35, 0.06, fz - 0.03, 0.32, 0.15, EY, sd * 0.3)
		k.b(head, "CheekTuft", 0.3, 0.45, 0.6, IB, c(sd * 0.75, -0.1, -0.2))
		local ear = k.ear(head, sd, c(sd * 0.42, 0.5, 0.15) * ANG(0, 0, -sd * 0.15))
		k.tri(ear, "Ear", 0.22, 0.75, 0.6, IB, c(0, 0.37, 0) * FACE)
		k.tri(ear, "EarInner", 0.07, 0.48, 0.34, W, c(0, 0.3, -0.12) * FACE)
	end
	local tip = k.tail(body, c(0, 0.4, 1.0), {
		{ 0.38, 0.38, 0.55, -1.0, IB }, { 0.36, 0.36, 0.55, -0.2, IB }, { 0.34, 0.34, 0.5, -0.2, IB }, { 0.34, 0.34, 0.45, 0.3, IB } })
	k.b(tip, "TailTip", 0.5, 0.45, 0.5, W, c(0, 0, 0.4))
end

---------------------------------------------------------------- SNOWPUFF (Uncommon)
-- Snowball cube creature: white block body with side nubs, glowing angled blue eyes, a hat of jagged
-- ice-blue snow with a blue band and a snowflake badge, stepped white snowcap on top, stubby ice feet.
function M.Snowpuff(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, WD, IB, BL, EY = C("#F4F6F8"), C("#E1E6EC"), C("#BFDDF2"), C("#7FB8EC"), C("#3FA8FF")
	local BY = 1.25
	local body = k.body(1.7, 1.5, 1.6, W, BY)
	k.b(body, "Cheeks", 1.85, 0.9, 1.3, WD, c(0, -0.1, 0.05))
	for _, sd in ipairs(SIDES) do
		k.eye(body, sd * 0.4, -0.05, -0.81, 0.4, 0.16, EY, -sd * 0.3)
		local a = k.arm(body, sd, c(sd * 0.95, 0.0, -0.1))
		k.b(a, "Nub", 0.35, 0.5, 0.55, W, c(sd * 0.12, -0.15, 0))
	end
	local he, hat = k.pv(body, "Hat", c(0, 0.75, 0))
	table.insert(rig.bobbers, he)
	k.b(hat, "Brim", 2.05, 0.38, 1.95, IB, c(0, 0.15, 0))
	for i = 0, 5 do
		local x = -0.85 + i * 0.34
		k.b(hat, "BrimTooth", 0.3, (i % 2 == 0) and 0.4 or 0.25, 0.25, IB, c(x, -0.12 - ((i % 2 == 0) and 0.08 or 0), -0.88))
	end
	k.b(hat, "Band", 1.6, 0.3, 1.5, BL, c(0, 0.45, 0))
	k.b(hat, "Cap", 1.3, 0.45, 1.2, W, c(0, 0.8, 0))
	k.b(hat, "CapTop", 0.6, 0.4, 0.55, W, c(0, 1.2, 0))
	-- big snowflake badge on the hat's front-right (viewer's right = creature -X)
	local flake = c(-0.6, 0.5, -0.82)
	for i = 0, 2 do
		local r = ANG(0, 0, i * PI / 3)
		k.b(hat, "Snowflake", 0.15, 1.0, 0.1, BL, flake * r)
		for _, e in ipairs({ -1, 1 }) do
			k.b(hat, "FlakeTip", 0.32, 0.12, 0.1, BL, flake * r * c(0, e * 0.36, 0))
		end
	end
	local lg = { up = { 0.45, 0.2, 0.5 }, col = IB, w2 = 0.42, d2 = 0.48, paw = { 0.6, 0.25, 0.75 }, pawCol = IB }
	k.leg(body, "LegL", BY, -0.45, -0.7, 0, lg)
	k.leg(body, "LegR", BY, 0.45, -0.7, 0, lg)
	rig.legKind = "biped"
end

---------------------------------------------------------------- ICICLE OWL (Rare)
-- Ice owl: pale-blue body with a white V breast plate, white facial disc with a V brow, glowing blue
-- eyes, dark-blue hooked beak, tall ear tufts, layered wings (ice-blue coverts, dark-blue bar, long
-- white flight feathers), white tail feathers, white legs with dark-blue talons.
function M.IcicleOwl(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local IB, IBD, W, B, EY = C("#BFDDF2"), C("#A6CBE6"), C("#FFFFFF"), C("#3F7FC8"), C("#3FC8FF")
	local BY = 1.85
	local body = k.body(1.2, 1.4, 1.1, IB, BY)
	k.tri(body, "Breast", 0.12, 0.9, 1.0, W, c(0, -0.05, -0.58) * DOWN * FACE)
	k.b(body, "BreastTop", 1.0, 0.35, 0.12, W, c(0, 0.5, -0.58))
	local lg = { up = { 0.42, 0.35, 0.45 }, col = W, w2 = 0.34, d2 = 0.38, paw = { 0.55, 0.22, 0.6 }, pawCol = B, toes = 2, toeCol = B }
	k.leg(body, "LegL", BY, -0.3, -0.7, 0, lg)
	k.leg(body, "LegR", BY, 0.3, -0.7, 0, lg)
	rig.legKind = "biped"

	local head = k.head(body, 1.1, 0.95, 1.0, IB, c(0, 1.15, -0.1), V3(0, -0.45, 0.2))
	k.b(head, "FaceDisc", 1.0, 0.72, 0.12, W, c(0, -0.05, -0.53))
	k.w(head, "Beak", 0.25, 0.4, 0.3, B, c(0, -0.2, -0.68) * DOWN)
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.5, 0.16, 0.14, W, c(sd * 0.25, 0.3, -0.58) * ANG(0, 0, sd * 0.35))
		k.b(head, "EyeSocket", 0.3, 0.2, 0.05, C("#20304A"), c(sd * 0.24, 0.05, -0.6))
		k.eye(head, sd * 0.24, 0.05, -0.62, 0.22, 0.13, EY, sd * 0.25)
		local ear = k.ear(head, sd, c(sd * 0.4, 0.45, 0) * ANG(0, 0, -sd * 0.2))
		k.tri(ear, "Tuft", 0.2, 0.75, 0.5, IB, c(0, 0.37, 0) * FACE)
		k.tri(ear, "TuftInner", 0.07, 0.5, 0.28, B, c(0, 0.3, -0.1) * FACE)
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.62, 0.45, 0.05))
		-- half-spread wing sloping down and out: ice-blue covert, dark-blue bar, long white primaries below
		local _, wp = k.pv(w, "WingPlate", ANG(0, 0, -sd * 0.6))
		k.b(wp, "Covert", 1.7, 0.6, 0.85, IB, c(sd * 0.85, 0, 0.1))
		k.b(wp, "WingBar", 1.5, 0.2, 0.87, B, c(sd * 0.95, -0.38, 0.1))
		k.featherWing(wp, sd, { root = 0.5, z = 0.05, feathers = {
			{ -0.55, 1.5, 0.38, W }, { -0.8, 1.6, 0.38, W }, { -1.05, 1.55, 0.36, W }, { -1.3, 1.35, 0.34, W }, { -1.55, 1.1, 0.32, W } } })
	end
	local tp, te = nil, nil
	te, tp = k.pv(body, "TailRoot", c(0, -0.45, 0.5) * ANG(0.9, 0, 0))
	table.insert(rig.tail, te)
	for i, a in ipairs({ -0.35, 0, 0.35 }) do
		k.tri(tp, "TailFeather", 0.1, 1.1, 0.35, (i == 2) and IBD or W, ANG(0, 0, a) * c(0, 0.5, 0) * FACE)
	end
end

---------------------------------------------------------------- GLACIER YETI (Epic)
-- Ice yeti golem: white blocky body, ice-blue fur shards over shoulders and back, a stepped white
-- beard, dark-blue face plate with glowing eyes, curled dark-blue ram horns, ice-blue loin panel with
-- a dark-blue border, huge arms ending in dark-blue fists, white legs with dark-blue feet.
function M.GlacierYeti(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, WD, IB, B, BD, EY = C("#F2F5F8"), C("#DDE4EC"), C("#A9D4F2"), C("#3A66B0"), C("#2C5096"), C("#3FC8FF")
	local BY = 3.1
	local body = k.body(2.2, 2.0, 1.5, W, BY)
	k.b(body, "Belly", 1.6, 1.0, 0.2, WD, c(0, -0.3, -0.78))
	k.tri(body, "LoinBorder", 0.1, 1.0, 0.85, B, c(0, -1.2, -0.8) * DOWN * FACE)
	k.tri(body, "Loin", 0.12, 0.85, 0.65, IB, c(0, -1.15, -0.83) * DOWN * FACE)
	k.b(body, "Hips", 1.9, 0.6, 1.3, W, c(0, -1.2, 0))
	for i = 0, 5 do
		local x = (i - 2.5) * 0.4
		k.spike(body, "BackShard", 1.3 - math.abs(x) * 0.2, 0.7, IB, c(x, 0.9, 0.35) * ANG(0.8, 0, -x * 0.4))
	end

	local lg = { up = { 1.0, 0.7, 1.0 }, col = W, w2 = 0.92, d2 = 0.95, paw = { 1.25, 0.45, 1.4, -0.1 }, pawCol = B, toes = 2, toeCol = BD }
	k.leg(body, "LegL", BY, -0.6, -1.4, 0, lg)
	k.leg(body, "LegR", BY, 0.6, -1.4, 0, lg)
	rig.legKind = "biped"

	for _, sd in ipairs(SIDES) do
		local arm = k.arm(body, sd, c(sd * 1.4, 0.55, 0))
		k.b(arm, "Shoulder", 1.25, 0.8, 1.25, W, c(sd * 0.2, 0.2, 0))
		-- big ice-fur mane over the shoulder: crossed shards fanning up and out
		for i = 0, 4 do
			k.spike(arm, "FurShard", 1.3 - math.abs(i - 2) * 0.15, 0.75, (i % 2 == 0) and IB or C("#C4E2F6"),
				c(sd * (0.0 + i * 0.18), 0.55, -0.45 + i * 0.22) * ANG(0.25, 0, -sd * (0.3 + i * 0.22)))
		end
		k.b(arm, "UpperArm", 0.9, 0.9, 0.9, W, c(sd * 0.25, -0.6, 0))
		k.b(arm, "Forearm", 1.25, 1.0, 1.25, WD, c(sd * 0.3, -1.5, -0.05))
		local _, fist = k.b(arm, "Fist", 1.4, 1.1, 1.35, B, c(sd * 0.3, -2.45, -0.1))
		for f = 1, 3 do k.b(fist, "Knuckle", 0.38, 0.34, 0.2, BD, c((f - 2) * 0.42, 0.2, -0.72)) end
	end

	local head = k.head(body, 1.0, 1.0, 0.95, W, c(0, 1.3, -0.2), V3(0, -0.45, 0.1))
	k.b(head, "FacePlate", 0.7, 0.4, 0.08, B, c(0, 0.1, -0.5))
	for _, sd in ipairs(SIDES) do k.eye(head, sd * 0.17, 0.12, -0.55, 0.2, 0.1, EY, sd * 0.25) end
	for i = 0, 2 do
		k.b(head, "Beard", 0.95 - i * 0.22, 0.32, 0.25, (i % 2 == 0) and W or WD, c(0, -0.3 - i * 0.28, -0.5))
	end
	k.tri(head, "BeardTip", 0.2, 0.4, 0.4, W, c(0, -1.25, -0.5) * DOWN * FACE)
	for _, sd in ipairs(SIDES) do
		local pts = { V3(sd * 0.45, 0.3, 0), V3(sd * 0.85, 0.75, 0.05), V3(sd * 0.9, 1.25, 0.15), V3(sd * 0.6, 1.5, 0.05), V3(sd * 0.45, 1.25, -0.15) }
		for i = 1, #pts - 1 do
			k.bar(head, "Horn", pts[i], pts[i + 1], 0.38 - i * 0.05, (i % 2 == 0) and BD or B, nil, nil, V3(0, 0, 1))
		end
	end
end

---------------------------------------------------------------- AURORA FOX (Legendary)
-- Ice-crystal fox: pale-blue body with angular white plates traced by glowing aurora lines, a white
-- spiky ruff with a mint gem, slim legs with aurora bands and white paws, fox head with a long snout,
-- black nose, white cheek spikes, tall ears with mint insides, and three huge flowing aurora ribbon tails.
function M.AuroraFox(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, IB, IBD, AU, N, EY = C("#F6F8FB"), C("#D6E6F4"), C("#BFD4E8"), C("#7FF0C8"), C("#26282E"), C("#4FF0C0")
	local BY = 2.3
	local body = k.body(1.2, 1.15, 2.4, IB, BY)
	for i, x in ipairs({ -0.35, 0, 0.35 }) do
		k.tri(body, "Ruff", 0.12, 1.1 - math.abs(x) * 0.8, 0.5, W, c(x, -0.2, -1.22) * DOWN * FACE)
	end
	k.diamond(body, "RuffGem", 0.4, 0.26, 0.1, AU, c(0, 0.05, -1.3), MAT.Glass)
	for _, sd in ipairs(SIDES) do
		k.b(body, "ShoulderPlate", 0.14, 0.75, 0.9, W, c(sd * 0.62, 0.15, -0.75) * ANG(0.3, 0, 0))
		k.b(body, "HipPlate", 0.14, 0.7, 0.8, W, c(sd * 0.62, 0.15, 0.8) * ANG(-0.3, 0, 0))
		local _, ln = k.bar(body, "AuroraLine", V3(sd * 0.7, -0.15, -0.4), V3(sd * 0.7, 0.2, 0.4), 0.06, AU, MAT.Neon, nil, V3(1, 0, 0))
		k.glow(ln, AU)
		for i = 0, 2 do
			k.tri(body, "BackSpike", 0.1, 0.6, 0.45, W, c(sd * 0.35, 0.6, -0.6 + i * 0.6) * ANG(0.7, 0, -sd * 0.5))
		end
	end

	local lg = { up = { 0.48, 0.85, 0.58 }, col = IB, w2 = 0.38, d2 = 0.48, band = AU, paw = { 0.48, 0.36, 0.58 }, pawCol = W, toes = 2, toeCol = IBD }
	k.leg(body, "LegFL", BY, -0.36, -0.45, -0.92, lg)
	k.leg(body, "LegFR", BY, 0.36, -0.45, -0.92, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.36, -0.45, 0.92, lg)
	k.leg(body, "LegBR", BY, 0.36, -0.45, 0.92, lg)
	rig.legKind = "quad"

	k.b(body, "Neck", 0.65, 1.0, 0.7, W, c(0, 0.75, -1.15) * ANG(-0.35, 0, 0))
	local head = k.head(body, 0.8, 0.72, 0.85, W, c(0, 1.45, -1.5), V3(0, -0.3, 0.3))
	k.w(head, "Snout", 0.5, 0.36, 0.65, IB, c(0, -0.15, -0.72))
	k.b(head, "Nose", 0.16, 0.12, 0.1, N, c(0, -0.27, -1.02))
	k.diamond(head, "ForeheadGem", 0.25, 0.16, 0.06, AU, c(0, 0.22, -0.44), MAT.Glass)
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.22, 0.08, -0.44, 0.2, 0.09, EY, sd * 0.35)
		k.tri(head, "CheekSpike", 0.1, 0.55, 0.35, W, c(sd * 0.5, -0.15, 0.05) * ANG(0, 0, -sd * 1.4))
		local ear = k.ear(head, sd, c(sd * 0.25, 0.35, 0.1) * ANG(0, 0, -sd * 0.15))
		k.tri(ear, "Ear", 0.16, 0.95, 0.5, W, c(0, 0.47, 0) * FACE)
		k.tri(ear, "EarInner", 0.06, 0.62, 0.28, AU, c(0, 0.38, -0.09) * FACE)
	end

	-- three broad ribbons rising up and back, curling upward toward the ends
	for i, d in ipairs({ { -0.55, -0.25, W, 0 }, { -0.25, 0.0, AU, 0.25 }, { 0.05, 0.3, AU, 0.3 } }) do
		local segs = {}
		for j = 1, 4 do
			table.insert(segs, { 0.14, 1.05 - j * 0.05, 0.8, d[3], j == 1 and d[1] or -0.12, j == 1 and d[2] * 0.3 or 0, d[4] > 0 and MAT.Glass or nil, d[4] })
		end
		local rec = k.chain(body, c(d[2] * 0.4, 0.35, 1.15), segs, { name = "AuroraTail", kind = "trail", i = i, amp = 0.15, freq = 1.2, lag = 0.5 })
		k.tri(rec.parts[#rec.parts], "RibbonTip", 0.14, 0.6, 0.8, d[3], c(0, 0, 0.6) * ANG(PI / 2, 0, 0), d[4] > 0 and MAT.Glass or nil, d[4])
	end
end

---------------------------------------------------------------- BLIZZARD BEAR (Legendary)
-- Great white bear: shaggy white body with layered fur shards, ice-blue armour plates with blue
-- chevron stripes on shoulders and back, a blue shield pendant, thick legs with pale-blue bands and
-- clawed paws, heavy head with a white mane, dark nose, glowing blue eyes, round ears and an ice crown.
function M.BlizzardBear(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local W, WD, IB, B, N, EY = C("#F7F9FB"), C("#E3E9F0"), C("#A8D5F5"), C("#4FA8F0"), C("#4A4F58"), C("#3FC8FF")
	local BY = 2.2
	local body = k.body(2.0, 1.7, 2.6, W, BY)
	for _, sd in ipairs(SIDES) do
		local _, sp = k.b(body, "ShoulderArmor", 0.25, 1.0, 1.2, IB, c(sd * 1.05, 0.35, -0.6))
		k.b(sp, "Chevron", 0.06, 0.18, 0.9, B, c(sd * 0.14, 0.1, 0) * ANG(0.35, 0, 0))
		for i = 0, 3 do
			k.tri(body, "Fur", 0.14, 0.9, 0.6, (i % 2 == 0) and W or WD, c(sd * 1.0, -0.55, -0.9 + i * 0.6) * ANG(0, 0, sd * 0.25) * DOWN * FACE)
		end
	end
	local _, back = k.b(body, "BackArmor", 1.4, 0.25, 1.4, IB, c(0, 0.9, 0.3))
	k.b(back, "BackChevron", 1.2, 0.27, 0.18, B, c(0, 0, -0.2))
	for i = 0, 3 do
		k.tri(body, "BackFur", 0.14, 0.8, 0.6, W, c((i - 1.5) * 0.45, 0.95, 1.1) * ANG(0.9, 0, 0))
	end
	k.tri(body, "PendantBorder", 0.1, 1.0, 0.75, B, c(0, -0.35, -1.33) * DOWN * FACE)
	k.tri(body, "Pendant", 0.12, 0.8, 0.55, IB, c(0, -0.32, -1.36) * DOWN * FACE)
	k.diamond(body, "PendantGem", 0.32, 0.2, 0.08, B, c(0, -0.2, -1.42), MAT.Glass)

	local lg = { up = { 0.95, 0.7, 1.0 }, col = W, w2 = 0.85, d2 = 0.9, band = IB, paw = { 1.05, 0.4, 1.2 }, pawCol = W, toes = 3, toeCol = WD }
	k.leg(body, "LegFL", BY, -0.65, -0.6, -0.95, lg)
	k.leg(body, "LegFR", BY, 0.65, -0.6, -0.95, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.65, -0.6, 0.95, lg)
	k.leg(body, "LegBR", BY, 0.65, -0.6, 0.95, lg)
	rig.legKind = "quad"

	local head = k.head(body, 1.3, 1.1, 1.2, W, c(0, 0.6, -1.75), V3(0, -0.4, 0.4))
	k.b(head, "Muzzle", 0.8, 0.5, 0.55, W, c(0, -0.25, -0.8))
	k.b(head, "Nose", 0.36, 0.22, 0.12, N, c(0, -0.12, -1.1))
	local jaw = k.jb(head, "Jaw", 0.7, 0.22, 0.7, WD, c(0, -0.55, -0.6), V3(0, 0, 0.35))
	H.group(rig, "jaws", jaw)
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.55, 0.2, 0.25, WD, c(sd * 0.33, 0.25, -0.6) * ANG(0, 0, sd * 0.3))
		k.eye(head, sd * 0.33, 0.08, -0.61, 0.28, 0.12, EY, sd * 0.3)
		local ear = k.ear(head, sd, c(sd * 0.5, 0.5, 0.2), "round")
		k.b(ear, "Ear", 0.4, 0.38, 0.22, W, c(0, 0.17, 0))
		for i = 0, 2 do
			k.tri(head, "Mane", 0.14, 0.8, 0.5, (i % 2 == 0) and W or WD, c(sd * 0.7, 0.1 - i * 0.35, 0.3) * ANG(0.3, 0, -sd * (1.2 + i * 0.3)))
		end
	end
	k.b(head, "CrownBand", 1.1, 0.16, 1.0, B, c(0, 0.6, 0.05))
	for i = -2, 2 do
		k.tri(head, "CrownSpike", 0.12, (i == 0) and 0.7 or 0.45, 0.28, (i == 0) and B or IB, c(i * 0.22, (i == 0) and 0.98 or 0.86, -0.45) * FACE)
	end
	k.crystal(head, "CrownGem", 0.55, 0.2, B, c(0, 0.65, -0.5), MAT.Glass, 0.1)
end

---------------------------------------------------------------- CRYSTALWING DRAGON (Mythical)
-- Ice dragon: pale-blue body with white armour plates and a blue crystal on the chest, legs with white
-- greaves, blue bands and white claws, white-and-blue neck, horned head crowned with translucent ice
-- crystals, feathered wings (blue leading bar, white blades over translucent crystal blades), a long
-- white/blue tail lined with ice shards ending in a crystal fan.
function M.Crystalwing(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local IB, IBD, W, B, CR, EY = C("#9FD3F2"), C("#86C2E8"), C("#F6F9FC"), C("#4FA8E8"), C("#8FD8FF"), C("#3FC8FF")
	local BY = 2.3
	local body = k.body(1.8, 1.5, 2.4, IB, BY)
	k.b(body, "ChestPlate", 1.5, 1.4, 0.8, W, c(0, 0.05, -1.1))
	k.diamond(body, "ChestCrystal", 0.9, 0.5, 0.16, B, c(0, 0.05, -1.53), MAT.Glass)
	for _, sd in ipairs(SIDES) do
		k.b(body, "SidePlate", 0.14, 0.9, 1.0, W, c(sd * 0.92, 0.1, 0.2) * ANG(0.4, 0, 0))
	end
	for i = 0, 2 do
		k.crystal(body, "BackShard", 0.8 - i * 0.1, 0.2, CR, c(0, 0.75, -0.7 + i * 0.7) * ANG(0.5, 0, 0), MAT.Glass, 0.2)
	end

	local lf = { up = { 0.8, 0.75, 0.9 }, col = IB, w2 = 0.68, d2 = 0.75, band = B, paw = { 0.95, 0.35, 1.1 }, pawCol = W, toes = 3, toeCol = W }
	local function greave(knee) k.b(knee, "Greave", 0.74, 0.5, 0.82, W, c(0, -0.3, 0)) end
	local _, _, k1 = k.leg(body, "LegFL", BY, -0.75, -0.5, -0.8, lf); greave(k1)
	local _, _, k2 = k.leg(body, "LegFR", BY, 0.75, -0.5, -0.8, lf); greave(k2)
	lf.hind = true
	local _, _, k3 = k.leg(body, "LegBL", BY, -0.78, -0.45, 0.85, lf); greave(k3)
	local _, _, k4 = k.leg(body, "LegBR", BY, 0.78, -0.45, 0.85, lf); greave(k4)
	rig.legKind = "quad"

	k.b(body, "Neck1", 0.85, 0.9, 0.8, W, c(0, 0.75, -1.35) * ANG(-0.5, 0, 0))
	k.b(body, "Neck2", 0.75, 0.85, 0.75, IB, c(0, 1.35, -1.6) * ANG(-0.25, 0, 0))
	local head = k.head(body, 1.0, 0.8, 1.2, IB, c(0, 2.0, -1.95), V3(0, -0.3, 0.4))
	k.b(head, "Snout", 0.7, 0.45, 0.7, IB, c(0, -0.12, -0.85))
	k.b(head, "Crest", 1.05, 0.2, 0.7, W, c(0, 0.45, -0.1))
	local jaw = k.jb(head, "Jaw", 0.66, 0.2, 0.9, IBD, c(0, -0.42, -0.55), V3(0, 0, 0.45))
	H.group(rig, "jaws", jaw)
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.3, 0.1, -0.61, 0.24, 0.1, EY, sd * 0.3)
		for i, d in ipairs({ { 0.3, 1.0, 0.7 }, { 0.5, 0.75, 1.2 }, { 0.2, 0.8, 0.3 } }) do
			k.crystal(head, "IceHorn", d[2], 0.2, CR, c(sd * d[1], 0.45, 0.1 + i * 0.12) * ANG(0.6, 0, -sd * d[3]), MAT.Glass, 0.15)
		end
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.75, 0.6, -0.3))
		-- raised wing: leading bar climbs high then runs out, long blades fan outward beneath it
		k.bar(w, "WingBar", V3(0, 0, 0), V3(sd * 1.3, 2.5, 0), 0.42, B)
		k.bar(w, "WingBar", V3(sd * 1.3, 2.5, 0), V3(sd * 4.0, 3.3, 0), 0.34, B)
		local fw = {}
		for i = 0, 6 do
			table.insert(fw, { 0.55 - i * 0.2, 3.1 - math.abs(i - 1) * 0.22, 0.5, (i % 2 == 0) and W or CR })
		end
		local _, ep = k.pv(w, "FeatherRoot", c(sd * 1.1, 2.0, 0.05))
		k.featherWing(ep, sd, { root = 0.1, z = 0.03, feathers = fw })
		k.featherWing(ep, sd, { root = 1.4, z = -0.03, mat = MAT.Glass, tr = 0.25, feathers = {
			{ 0.3, 2.4, 0.48, CR }, { -0.3, 2.1, 0.48, CR } } })
	end

	local segs = {}
	for j = 1, 9 do
		local w = 0.8 - j * 0.06
		table.insert(segs, { w, w * 0.85, 0.55, (j % 2 == 0) and W or IB, j == 1 and 0.3 or -0.05 })
	end
	local rec = k.chain(body, c(0, 0.1, 1.15), segs, { name = "Tail", kind = "spine", i = 1, amp = 0.15, freq = 1.3, lag = 0.55 })
	for j, p in ipairs(rec.parts) do
		if j % 2 == 1 then
			local w = 0.8 - j * 0.06
			k.crystal(p, "TailShard", 0.7 - j * 0.04, 0.16, CR, c(0, w * 0.42, 0) * ANG(0.6, 0, 0), MAT.Glass, 0.2)
		end
	end
	local last = rec.parts[#rec.parts]
	for _, a in ipairs({ -0.5, 0, 0.5 }) do
		k.crystal(last, "TailFan", 1.0 - math.abs(a) * 0.4, 0.22, CR, c(0, 0, 0.3) * ANG(PI / 2, 0, a), MAT.Glass, 0.2)
	end
end

return M
