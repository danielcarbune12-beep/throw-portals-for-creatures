-- SpeciesModelsCrystal: hand-authored, reference-faithful models for the Crystal world
-- (Gemmy, Quartz Beetle, Glimmer Bat, Amethyst Eel). Prism Lion lives in SpeciesModels.
-- Location: ReplicatedStorage > Shared > SpeciesModelsCrystal (ModuleScript), merged into SpeciesModels.

local K = require(script.Parent.ModelKit)
local V3, CF, ANG, PI, MAT, C = K.V3, K.CF, K.ANG, K.PI, K.MAT, K.C
local FACE = ANG(0, PI / 2, 0)
local SIDES = { -1, 1 }

local M = {}

---------------------------------------------------------------- GEMMY (Common)
-- Little crystal shell-crab: lavender face frame around a dark visor with glowing slit eyes, a
-- lavender brow plate with a purple gem, faceted purple shell chunks (top and sides lift on the
-- jump), four stubby dark-purple feet.
function M.Gemmy(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUL, LV, DP, EY = C("#A66CF0"), C("#B987F5"), C("#DCCDF8"), C("#6A36C2"), C("#F0E8FF")
	local BY = 1.2
	local body = k.body(1.6, 1.2, 1.5, DP, BY)
	k.b(body, "FaceFrame", 1.75, 0.72, 0.3, LV, c(0, -0.22, -0.72))
	k.b(body, "FaceHole", 1.05, 0.42, 0.1, DP, c(0, -0.2, -0.88))
	k.b(body, "Brow", 0.95, 0.85, 0.3, LV, c(0, 0.55, -0.7))
	k.tri(body, "BrowPeak", 0.3, 0.4, 0.95, LV, c(0, 1.17, -0.7) * FACE)
	k.diamond(body, "Gem", 0.6, 0.4, 0.12, PU, c(0, 0.6, -0.87), MAT.Glass)
	for _, sd in ipairs(SIDES) do
		k.eye(body, sd * 0.27, -0.2, -0.94, 0.28, 0.12, EY, 0)
		k.w(body, "Cheek", 0.3, 0.72, 0.5, LV, c(sd * 0.95, -0.22, -0.55) * ANG(0, -sd * PI / 2, 0))
	end

	local top = k.opener(body, "ShellTop", c(0, 0.6, 0.6), V3(1, 0, 0), 0.25)
	k.b(top, "ShellTopBlock", 1.55, 0.9, 1.45, PU, c(0, 0.45, -0.45) * ANG(0.25, 0, 0))
	for _, sd in ipairs(SIDES) do
		local sp = k.opener(body, "ShellSide", c(sd * 0.6, 0.3, 0), V3(0, 0, 1), sd * 0.3)
		k.b(sp, "ShellSideBlock", 0.95, 1.3, 1.45, PUL, c(sd * 0.35, 0.05, 0.1) * ANG(0, 0, -sd * 0.3))
		k.b(sp, "ShellSideLow", 0.7, 0.6, 1.2, PU, c(sd * 0.45, -0.55, 0.15) * ANG(0, 0, sd * 0.2))
	end
	k.b(body, "ShellBack", 1.4, 1.1, 0.6, PU, c(0, 0.3, 0.75) * ANG(-0.3, 0, 0))

	local lg = { up = { 0.45, 0.25, 0.45 }, col = LV, w2 = 0.42, d2 = 0.45, col2 = DP, paw = { 0.6, 0.25, 0.65 }, pawCol = DP }
	k.leg(body, "LegFL", BY, -0.55, -0.5, -0.4, lg)
	k.leg(body, "LegFR", BY, 0.55, -0.5, -0.4, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.55, -0.5, 0.45, lg)
	k.leg(body, "LegBR", BY, 0.55, -0.5, 0.45, lg)
	rig.legKind = "quad"
end

---------------------------------------------------------------- QUARTZ BEETLE (Uncommon)
-- White-grey stone beetle: wing cases with cyan crystal inlays that swing open on the power move,
-- navy centre ridge topped with a cluster of glowing quartz, navy face band with cyan eyes and
-- mandibles, two jointed antennae with flat navy tips, six splayed legs with navy feet.
function M.QuartzBeetle(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local G, GD, GL, N, CY, EY = C("#E3E6EB"), C("#C7CCD4"), C("#F2F4F7"), C("#394257"), C("#8EDBFF"), C("#6FE4FF")
	local BY = 1.25
	local body = k.body(1.6, 0.75, 2.3, N, BY)
	for _, sd in ipairs(SIDES) do
		local half = k.opener(body, "CaseHinge", c(sd * 0.15, 0.35, 0.2), V3(0, 0, 1), sd * 0.9)
		k.b(half, "Case", 0.95, 0.75, 2.35, G, c(sd * 0.55, 0.3, 0.05))
		k.w(half, "CaseEdge", 2.35, 0.55, 0.4, GD, c(sd * 1.22, 0.0, 0.05) * ANG(0, -sd * PI / 2, 0))
		k.w(half, "CaseFront", 0.95, 0.5, 0.55, GL, c(sd * 0.55, 0.35, -1.45))
		k.b(half, "CaseTop", 0.7, 0.2, 1.4, GL, c(sd * 0.55, 0.75, 0.2))
		k.diamond(half, "Inlay", 0.9, 0.5, 0.1, CY, c(sd * 1.04, 0.3, 0.2) * ANG(0, -sd * PI / 2, 0) * ANG(0, 0, 0.9), MAT.Glass)
	end
	k.b(body, "Ridge", 0.32, 0.9, 1.3, N, c(0, 0.55, -0.35))
	for i, d in ipairs({ { 0, 1.1, 0.42 }, { -0.25, 0.75, 0.3 }, { 0.25, 0.8, 0.3 }, { 0.1, 0.6, 0.25 } }) do
		k.crystal(body, "Quartz", d[2], d[3], CY, c(d[1], 0.95, -0.3 + i * 0.12) * ANG(0, 0, -d[1]), MAT.Glass, 0.1)
	end

	local head = k.head(body, 1.0, 0.7, 0.75, G, c(0, -0.05, -1.45), V3(0, 0, 0.3))
	k.b(head, "FaceBand", 1.02, 0.28, 0.1, N, c(0, 0.0, -0.4))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.25, 0.0, -0.46, 0.22, 0.12, EY, 0)
		k.b(head, "Mandible", 0.22, 0.22, 0.35, N, c(sd * 0.32, -0.35, -0.38))
		local ant = k.ear(head, sd, c(sd * 0.3, 0.3, -0.1), "antenna")
		local p1, p2, p3 = V3(0, 0, 0), V3(sd * 0.35, 0.75, -0.15), V3(sd * 0.55, 1.45, -0.05)
		k.bar(ant, "AntennaSeg", p1, p2, 0.2, G, nil, nil, V3(1, 0, 0))
		k.b(ant, "AntennaJoint", 0.25, 0.25, 0.25, N, c(p2.X, p2.Y, p2.Z))
		k.bar(ant, "AntennaSeg", p2, p3, 0.18, G, nil, nil, V3(1, 0, 0))
		k.b(ant, "AntennaTip", 0.5, 0.2, 0.3, N, c(p3.X + sd * 0.15, p3.Y, p3.Z - 0.1) * ANG(0, 0, sd * 0.3))
	end

	local lg = { up = { 0.32, 0.45, 0.4 }, col = G, w2 = 0.3, d2 = 0.36, col2 = GD, paw = { 0.42, 0.25, 0.5 }, pawCol = N, splay = 0.55 }
	for _, z in ipairs({ -0.75, 0.05, 0.8 }) do
		k.leg(body, "LegL", BY, -0.7, -0.3, z, lg)
		k.leg(body, "LegR", BY, 0.7, -0.3, z, lg)
	end
	rig.legKind = "bug6"
end

---------------------------------------------------------------- GLIMMER BAT (Rare)
-- Dark-purple bat: lavender chest chevron, big head with lavender crest stripe, pig snout, glowing
-- pink eyes, huge pointed ears with pink insides, small hanging feet with pink claws, wide wings with
-- purple bones, lavender leading edge and pink membranes.
function M.GlimmerBat(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUD, LV, PK, EY = C("#5E2E8A"), C("#4A2270"), C("#A57BEA"), C("#F4ACE2"), C("#FFB8F2")
	local BY = 2.3
	local body = k.body(1.0, 1.15, 0.9, PU, BY)
	for _, sd in ipairs(SIDES) do
		k.b(body, "Chevron", 0.5, 0.16, 0.1, LV, c(sd * 0.2, -0.05, -0.47) * ANG(0, 0, sd * 0.5))
	end
	local head = k.head(body, 1.05, 0.9, 0.9, PU, c(0, 1.0, -0.05), V3(0, -0.4, 0.1))
	k.b(head, "Crest", 0.3, 0.3, 0.95, LV, c(0, 0.5, 0.0))
	k.b(head, "Snout", 0.55, 0.35, 0.3, PUD, c(0, -0.2, -0.55))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Nostril", 0.1, 0.1, 0.04, C("#2A1240"), c(sd * 0.12, -0.18, -0.71))
		k.b(head, "Brow", 0.38, 0.14, 0.15, PUD, c(sd * 0.24, 0.17, -0.47) * ANG(0, 0, sd * 0.35))
		k.eye(head, sd * 0.24, 0.05, -0.47, 0.24, 0.12, EY, sd * 0.35)
		local ear = k.ear(head, sd, c(sd * 0.35, 0.45, 0.05) * ANG(0, 0, -sd * 0.2))
		k.tri(ear, "Ear", 0.16, 1.3, 0.75, PU, c(0, 0.65, 0) * FACE)
		k.tri(ear, "EarInner", 0.06, 0.95, 0.45, PK, c(0, 0.55, -0.1) * FACE)
	end

	local lg = { up = { 0.3, 0.3, 0.32 }, col = PU, w2 = 0.24, d2 = 0.26, paw = { 0.35, 0.18, 0.35 }, pawCol = PU, toes = 2, toeCol = PK, lh = 0.3 }
	k.leg(body, "LegL", BY, -0.25, -0.55, 0.05, lg)
	k.leg(body, "LegR", BY, 0.25, -0.55, 0.05, lg)
	rig.legKind = "biped"

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.45, 0.35, 0.05))
		k.batWing(w, sd, { wrist = Vector2.new(1.4, 1.1), bone = PU, mem = PK, boneW = 0.28, cap = LV,
			tips = { Vector2.new(3.4, 0.5), Vector2.new(3.0, -0.7), Vector2.new(2.0, -1.2), Vector2.new(0.9, -1.0) } })
	end
end

---------------------------------------------------------------- AMETHYST EEL (Epic)
-- Purple crystal eel: blocky head with a lavender brow stripe, gaping lavender jaw, glowing pink
-- slit eyes, eight-segment undulating body with a lavender belly and glowing pink side lines,
-- translucent pink crystal fins along the back, lavender pectoral fins, crystal fan tail fin.
function M.AmethystEel(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local PU, PUD, LV, PK, GL = C("#9B4DFF"), C("#7E36DE"), C("#F0D6FF"), C("#FF7AE6"), C("#FF5FD6")
	local BY = 1.5
	local body = k.body(1.15, 1.0, 1.3, PU, BY)
	rig.legKind = "none"
	k.b(body, "Throat", 1.0, 0.3, 1.25, LV, c(0, -0.45, 0))

	local head = k.head(body, 1.3, 0.75, 1.5, PU, c(0, 0.15, -1.25), V3(0, -0.1, 0.55))
	k.b(head, "Brow", 0.5, 0.12, 1.2, LV, c(0, 0.42, -0.05))
	k.b(head, "Mouth", 1.0, 0.15, 1.0, C("#3A1060"), c(0, -0.38, -0.35))
	local jaw = k.jb(head, "Jaw", 1.1, 0.35, 1.3, LV, c(0, -0.62, -0.25), V3(0, 0.1, 0.55))
	H.group(rig, "jaws", jaw)
	k.tri(head, "HeadFin", 0.14, 0.9, 0.6, PK, c(0, 0.75, 0.3) * ANG(0.5, 0, 0), MAT.Glass, 0.2)
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.4, 0.12, -0.76, 0.32, 0.12, GL, sd * 0.3)
		k.b(head, "Cheek", 0.15, 0.5, 0.8, PUD, c(sd * 0.65, -0.05, 0.1))
	end

	local pitches = { 0.12, 0.2, -0.05, -0.3, -0.3, 0.05, 0.25, 0.2 }
	local segs = {}
	for j = 1, 8 do
		local w = 1.05 - j * 0.075
		table.insert(segs, { w, w * 0.9, 0.7, (j % 2 == 0) and PUD or PU, pitches[j] })
	end
	local spine = k.chain(body, c(0, 0, 0.55), segs, { name = "Spine", kind = "spine", i = 1, amp = 0.3, freq = 2.0, lag = 0.65 })
	for j, p in ipairs(spine.parts) do
		local w = 1.05 - j * 0.075
		k.b(p, "Belly", w * 0.85, w * 0.35, 0.72, LV, c(0, -w * 0.35, 0))
		for _, sd in ipairs(SIDES) do
			local _, g = k.b(p, "GlowLine", 0.05, 0.1, 0.45, GL, c(sd * w * 0.5, w * 0.05, 0), MAT.Neon)
			k.glow(g, GL)
		end
		if j <= 6 then
			local fh = 1.2 - j * 0.13
			k.tri(p, "CrystalFin", 0.14, fh, 0.65, PK, c(0, w * 0.45 + fh * 0.45, 0.05) * ANG(0.45, 0, 0), MAT.Glass, 0.2)
		end
	end
	local last = spine.parts[#spine.parts]
	for _, a in ipairs({ -0.75, -0.25, 0.25, 0.75 }) do
		local L = 1.3 - math.abs(a) * 0.4
		k.tri(last, "TailFin", 0.12, L, 0.5, PK, c(0, math.sin(a) * L * 0.5, 0.3 + math.cos(a) * L * 0.5) * ANG(PI / 2 - a, 0, 0), MAT.Glass, 0.25)
	end

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.55, -0.25, 0.1) * ANG(0, -sd * 0.6, 0))
		k.featherWing(w, sd, { root = 0.05, thick = 0.1, feathers = {
			{ -0.3, 1.3, 0.32, LV, PK }, { -0.6, 1.1, 0.3, LV, PK }, { -0.9, 0.9, 0.28, LV, PK } } })
	end
end

return M
