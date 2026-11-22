-- SpeciesModelsForest: hand-authored, reference-faithful models for the Green Forest world
-- (Mossbun, Acornip, Petalfly, Thornhog, Elderstag Sprite, Oak Titan, Bloomwyrm, Sylph Queen).
-- Location: ReplicatedStorage > Shared > SpeciesModelsForest (ModuleScript), merged into SpeciesModels.

local K = require(script.Parent.ModelKit)
local V3, CF, ANG, PI, MAT, C = K.V3, K.CF, K.ANG, K.PI, K.MAT, K.C
local FACE, DOWN = ANG(0, PI / 2, 0), ANG(0, 0, PI)
local SIDES = { -1, 1 }

local M = {}

-- flat kite panel in a wing pivot's XY plane (outward = side * X): O root, L upper corner, T tip, R lower corner
local function kite(k, pv, side, O, L, T, R, col, z, mat, tr)
	local function P(v) return V3(v.X * side, v.Y, z) end
	k.mem(pv, "WingPanel", P(O), P(L), P(R), 0.08, col, mat, tr)
	k.mem(pv, "WingPanel", P(T), P(L), P(R), 0.08, col, mat, tr)
end

---------------------------------------------------------------- MOSSBUN (Common)
-- Green block bunny: big hind haunches, cream paws and muzzle, glowing green slit eyes, very tall ears
-- with cream insides and pointed tips, a two-leaf sprout between the ears, chunky cream tail.
function M.Mossbun(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local G, GD, CR, CRD, DG, EY = C("#8CCB5A"), C("#6FB043"), C("#F2F0D6"), C("#DEDBBE"), C("#3F8F2F"), C("#3DDC3D")
	local BY = 1.4
	local body = k.body(1.5, 1.2, 1.9, G, BY)
	for _, sd in ipairs(SIDES) do
		k.b(body, "Haunch", 0.5, 1.0, 1.1, G, c(sd * 0.72, -0.05, 0.45))
	end
	k.b(body, "Chest", 1.3, 1.1, 0.4, G, c(0, 0.05, -0.95))
	local lf = { up = { 0.45, 0.4, 0.5 }, col = G, w2 = 0.4, d2 = 0.45, paw = { 0.55, 0.25, 0.75 }, pawCol = CR, toes = 2, toeCol = CRD }
	k.leg(body, "LegFL", BY, -0.42, -0.45, -0.7, lf)
	k.leg(body, "LegFR", BY, 0.42, -0.45, -0.7, lf)
	local lh = { up = { 0.5, 0.4, 0.7 }, col = G, w2 = 0.45, d2 = 0.6, paw = { 0.65, 0.3, 1.1 }, pawCol = CR, toes = 2, toeCol = CRD, hind = true }
	k.leg(body, "LegBL", BY, -0.62, -0.45, 0.55, lh)
	k.leg(body, "LegBR", BY, 0.62, -0.45, 0.55, lh)
	rig.legKind = "quad"

	local head = k.head(body, 1.3, 1.15, 1.2, G, c(0, 0.95, -1.15), V3(0, -0.45, 0.35))
	k.b(head, "Muzzle", 1.0, 0.45, 0.3, CR, c(0, -0.35, -0.62))
	k.w(head, "Nose", 0.3, 0.14, 0.12, CRD, c(0, -0.16, -0.8))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Brow", 0.5, 0.16, 0.2, GD, c(sd * 0.33, 0.26, -0.6) * ANG(0, 0, sd * 0.25))
		k.eye(head, sd * 0.33, 0.1, -0.61, 0.32, 0.15, EY, sd * 0.25)
		local ear = k.ear(head, sd, c(sd * 0.35, 0.55, 0.1) * ANG(-0.25, 0, -sd * 0.15), "bunny")
		k.b(ear, "Ear", 0.38, 1.5, 0.3, G, c(0, 0.75, 0))
		k.b(ear, "EarInner", 0.22, 1.2, 0.06, CR, c(0, 0.7, -0.16))
		k.tri(ear, "EarTip", 0.38, 0.35, 0.3, G, c(0, 1.67, 0))
	end
	local se = k.pv(head, "Sprout", c(0, 0.58, 0))
	table.insert(rig.bobbers, se)
	for _, sd in ipairs(SIDES) do
		k.tri(se.part, "Leaf", 0.08, 0.45, 0.3, DG, c(sd * 0.12, 0.2, 0) * ANG(0, 0, -sd * 0.5) * FACE)
	end
	k.tail(body, c(0, 0.35, 0.95), { { 0.8, 0.75, 0.6, -0.4, CR } })
end

---------------------------------------------------------------- ACORNIP (Uncommon)
-- Squirrel in an acorn-cap helmet (stem + leaf), dark eye mask with glowing eyes, tan muzzle and bib,
-- leather strap with an acorn pendant, leaf shoulder pads, dark paws, huge curling tail with a tan inside.
function M.Acornip(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local B, BD, T, CAP, CAPD, LF, EY = C("#C07A45"), C("#8E5530"), C("#EBC895"), C("#7A4A2A"), C("#5E3820"), C("#7FA53A"), C("#FFE9A8")
	local BY = 1.6
	local body = k.body(1.4, 1.3, 1.7, B, BY)
	k.b(body, "Bib", 0.85, 0.95, 0.12, T, c(0, -0.05, -0.86))
	k.bar(body, "Strap", V3(-0.6, 0.55, -0.88), V3(0.35, -0.3, -0.88), 0.14, BD, nil, nil, nil, 0.06)
	k.b(body, "Acorn", 0.3, 0.3, 0.14, T, c(0, 0.0, -0.94))
	k.b(body, "AcornCap", 0.36, 0.14, 0.16, BD, c(0, 0.17, -0.94))
	-- leaf shoulder pads: three broad leaves fanned over each shoulder, tips pointing out and down
	for _, sd in ipairs(SIDES) do
		for _, d in ipairs({ { -0.75, -0.3 }, { -0.35, 0.0 }, { 0.05, 0.3 } }) do
			-- flat leaf lying out from the shoulder (thin in Y), tilted down at the outer end
			local _, pp = k.pv(body, "LeafPad", c(sd * 0.5, 0.5, d[1]) * ANG(0, d[2] * sd, -sd * 0.95))
			k.b(pp, "Leaf", 0.75, 0.1, 0.55, LF, c(sd * 0.38, 0, 0))
			k.tri(pp, "LeafTip", 0.1, 0.4, 0.55, LF, c(sd * 0.95, 0, 0) * ANG(0, 0, -sd * PI / 2))
		end
	end
	local lg = { up = { 0.6, 0.55, 0.7 }, col = B, w2 = 0.52, d2 = 0.6, paw = { 0.66, 0.3, 0.8 }, pawCol = BD, toes = 2, toeCol = BD }
	k.leg(body, "LegFL", BY, -0.45, -0.5, -0.55, lg)
	k.leg(body, "LegFR", BY, 0.45, -0.5, -0.55, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.45, -0.5, 0.55, lg)
	k.leg(body, "LegBR", BY, 0.45, -0.5, 0.55, lg)
	rig.legKind = "quad"

	local head = k.head(body, 1.3, 1.1, 1.15, B, c(0, 1.05, -0.95), V3(0, -0.4, 0.3))
	k.b(head, "Muzzle", 0.75, 0.45, 0.45, T, c(0, -0.3, -0.7))
	k.b(head, "Nose", 0.28, 0.16, 0.12, CAPD, c(0, -0.14, -0.95))
	k.b(head, "Mask", 1.34, 0.3, 1.19, BD, c(0, 0.08, 0))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.3, 0.08, -0.6, 0.3, 0.15, EY, sd * 0.15)
		k.b(head, "Cheek", 0.3, 0.45, 0.5, T, c(sd * 0.55, -0.3, -0.45))
		-- ears poke out of the cap beside the top block
		local ear = k.ear(head, sd, c(sd * 0.62, 0.8, 0.1) * ANG(0, 0, -sd * 0.15))
		k.tri(ear, "Ear", 0.22, 0.65, 0.45, B, c(0, 0.3, 0) * FACE)
		k.tri(ear, "EarInner", 0.07, 0.42, 0.26, T, c(0, 0.24, -0.12) * FACE)
	end
	k.b(head, "Cap", 1.55, 0.45, 1.4, CAP, c(0, 0.62, 0.02))
	k.b(head, "CapBrim", 1.6, 0.14, 0.25, CAPD, c(0, 0.42, -0.7))
	k.b(head, "CapTop", 1.05, 0.3, 0.95, CAPD, c(0, 0.95, 0.02))
	k.b(head, "Stem", 0.16, 0.5, 0.16, CAPD, c(0, 1.3, 0) * ANG(0, 0, 0.2))
	k.tri(head, "CapLeaf", 0.08, 0.6, 0.35, LF, c(0.32, 1.4, 0) * ANG(0, 0, -1.2) * FACE)

	-- big S tail: rises straight up behind, then curls back and down at the top (tan on the inside of the curl)
	local tw = { 0.9, 1.0, 1.0, 0.85 }
	k.tail(body, c(0, 0.3, 0.75), {
		{ tw[1], tw[1], 0.9, -1.35, B }, { tw[2], tw[2], 0.85, 0.15, B }, { tw[3], tw[3], 0.8, 0.75, B }, { tw[4], tw[4], 0.7, 0.75, B } })
	for i, e in ipairs(rig.tail) do
		k.b(e.part, "TailInner", tw[i] * 0.75, 0.1, 0.7, T, c(0, -tw[i] * 0.48, 0))
	end
end

---------------------------------------------------------------- PETALFLY (Rare)
-- Pink petal moth on six legs: pink thorax, pale-yellow belly and tapered abdomen, angular head with a
-- purple mask and glowing eyes, purple-and-yellow crest, four kite wings (pink with yellow centres and
-- purple tips), pink legs with purple bands and feet.
function M.Petalfly(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local P, PD, Y, PU, EY = C("#F48CC4"), C("#E070AE"), C("#F6E7A0"), C("#8A3CC8"), C("#FFF6A0")
	local BY = 1.6
	local body = k.body(0.9, 0.85, 1.0, P, BY)
	k.b(body, "Belly", 0.75, 0.3, 0.85, Y, c(0, -0.38, 0))
	local ae, ap = k.pv(body, "AbdomenPivot", c(0, -0.05, 0.45) * ANG(0.35, 0, 0))
	H.group(rig, "abdomen", ae)
	k.b(ap, "Abdomen", 0.8, 0.7, 0.8, Y, c(0, 0, 0.4))
	k.b(ap, "Abdomen", 0.55, 0.5, 0.7, Y, c(0, -0.02, 1.05))
	k.w(ap, "AbdomenTip", 0.4, 0.35, 0.5, Y, c(0, -0.04, 1.6) * ANG(0, PI, 0))

	local head = k.head(body, 0.85, 0.7, 0.8, P, c(0, 0.45, -0.75), V3(0, -0.2, 0.3))
	k.w(head, "Snout", 0.6, 0.4, 0.4, PD, c(0, -0.1, -0.55))
	k.b(head, "Mask", 0.9, 0.24, 0.1, PU, c(0, 0.04, -0.41))
	for _, sd in ipairs(SIDES) do k.eye(head, sd * 0.22, 0.04, -0.47, 0.2, 0.13, EY, sd * 0.3) end
	k.tri(head, "Crest", 0.14, 0.75, 0.45, PU, c(0, 0.65, 0) * FACE)
	k.tri(head, "CrestInner", 0.15, 0.45, 0.22, Y, c(0, 0.58, -0.02) * FACE)

	local lg = { up = { 0.18, 0.55, 0.18 }, col = P, w2 = 0.16, d2 = 0.16, band = PU, paw = { 0.26, 0.24, 0.3 }, pawCol = PU, splay = 0.6 }
	for _, z in ipairs({ -0.35, 0, 0.35 }) do
		k.leg(body, "LegL", BY, -0.38, -0.35, z, lg)
		k.leg(body, "LegR", BY, 0.38, -0.35, z, lg)
	end
	rig.legKind = "bug6"

	local V2 = Vector2.new
	for _, sd in ipairs(SIDES) do
		for tier, w in ipairs({
			{ V2(0, 0), V2(0.55, 1.9), V2(3.0, 2.8), V2(2.1, 0.35), V2(0.55, 0.5), V2(0.9, 1.6), V2(2.35, 2.2), V2(1.85, 0.75) },
			{ V2(0, 0), V2(1.2, 0.35), V2(2.6, -0.55), V2(1.0, -0.95), V2(0.5, -0.1), V2(1.2, 0.05), V2(2.0, -0.45), V2(1.0, -0.65) },
		}) do
			local pv = k.wing(body, sd, c(sd * 0.4, 0.3, 0.05 + (tier - 1) * 0.15) * ANG(0, -sd * (0.35 + tier * 0.1), 0), tier)
			kite(k, pv, sd, w[1], w[2], w[3], w[4], P, 0)
			kite(k, pv, sd, w[5], w[6], w[7], w[8], Y, -0.06)
			local Tt = V3(w[3].X * sd, w[3].Y, -0.04)
			local Lt = V3(w[2].X * sd, w[2].Y, -0.04)
			local Rt = V3(w[4].X * sd, w[4].Y, -0.04)
			k.bar(pv, "WingTip", Tt, Tt + (Lt - Tt) * 0.35, 0.16, PU)
			k.bar(pv, "WingTip", Tt, Tt + (Rt - Tt) * 0.35, 0.16, PU)
		end
	end
end

---------------------------------------------------------------- THORNHOG (Epic)
-- Armoured boar: tan-brown body with shoulder plates carrying a cream flower badge, glowing green
-- seam lines, a back covered in rows of big green leaf spines (they bristle on the power move), cream
-- pig snout with nostrils, angry brows over glowing green eyes, small ears, cream toes.
function M.Thornhog(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local BR, BRD, T, G, GD, GN = C("#B88A5E"), C("#9A6E46"), C("#F0D4A8"), C("#43AE40"), C("#2F8F30"), C("#5EE04A")
	local BY = 1.55
	local body = k.body(2.1, 1.35, 2.6, BR, BY)
	for _, sd in ipairs(SIDES) do
		local _, plate = k.b(body, "ShoulderPlate", 0.3, 1.1, 1.3, BRD, c(sd * 1.1, 0.1, -0.6))
		for i = 0, 3 do
			local a = i * PI / 2
			k.b(plate, "Petal", 0.06, 0.26, 0.26, T, c(sd * 0.17, math.cos(a) * 0.22, math.sin(a) * 0.22))
		end
		k.b(plate, "FlowerMid", 0.07, 0.26, 0.26, T, c(sd * 0.17, 0, 0))
		k.b(plate, "FlowerCore", 0.08, 0.14, 0.14, G, c(sd * 0.18, 0, 0))
		local _, seam = k.bar(body, "Seam", V3(sd * 1.07, -0.25, -0.1), V3(sd * 1.07, -0.05, 0.8), 0.08, GN, MAT.Neon, nil, V3(1, 0, 0))
		k.glow(seam, GN)
		k.b(body, "HipPlate", 0.25, 0.9, 1.0, BR, c(sd * 1.08, 0.0, 0.85))
	end
	local n = 0
	for row = 0, 2 do
		for col = 0, 3 do
			n += 1
			-- broad leaf blades layered over the back and down the flanks, all sweeping backward
			local x = (col - 1.5) * 0.62
			local z = -0.75 + row * 0.75 + (col % 2) * 0.25
			local pe, pp = k.pv(body, "SpineRoot", c(x, 0.55 - math.abs(x) * 0.15, z) * ANG(1.0, 0, -x * 0.75))
			pe.openAxis, pe.openAmt = V3(1, 0, 0), -0.35
			H.group(rig, "open", pe)
			H.group(rig, "spines", pe)
			k.spike(pp, "LeafSpine", 1.6 - row * 0.1 - math.abs(col - 1.5) * 0.15, 1.05, (n % 3 == 0) and GD or G, CF())
		end
	end

	local lg = { up = { 0.8, 0.5, 0.85 }, col = BR, w2 = 0.72, d2 = 0.78, paw = { 0.9, 0.32, 0.95 }, pawCol = T, toes = 3, toeCol = T }
	k.leg(body, "LegFL", BY, -0.72, -0.5, -0.85, lg)
	k.leg(body, "LegFR", BY, 0.72, -0.5, -0.85, lg)
	lg.hind = true
	k.leg(body, "LegBL", BY, -0.72, -0.5, 0.9, lg)
	k.leg(body, "LegBR", BY, 0.72, -0.5, 0.9, lg)
	rig.legKind = "quad"

	local head = k.head(body, 1.3, 1.0, 1.1, BR, c(0, 0.15, -1.65), V3(0, -0.3, 0.4))
	k.b(head, "Snout", 0.7, 0.5, 0.35, T, c(0, -0.2, -0.68))
	for _, sd in ipairs(SIDES) do
		k.b(head, "Nostril", 0.1, 0.2, 0.04, C("#5A3A22"), c(sd * 0.13, -0.2, -0.86))
		k.b(head, "Brow", 0.55, 0.2, 0.3, BRD, c(sd * 0.36, 0.25, -0.5) * ANG(0, 0, sd * 0.3))
		k.eye(head, sd * 0.36, 0.08, -0.56, 0.3, 0.13, GN, sd * 0.3)
		local ear = k.ear(head, sd, c(sd * 0.5, 0.48, 0.2) * ANG(0, 0, -sd * 0.3))
		k.b(ear, "Ear", 0.35, 0.4, 0.2, BR, c(0, 0.18, 0))
		k.b(ear, "EarInner", 0.2, 0.25, 0.06, T, c(0, 0.16, -0.11))
	end
	k.spike(head, "HeadSpine", 0.8, 0.5, G, c(0, 0.45, 0.1) * ANG(0.5, 0, 0))
end

---------------------------------------------------------------- ELDERSTAG SPRITE (Legendary)
-- Ancient forest stag: beige body under a mantle of green and white leaves with gold edging, white
-- leaf bib with a green chest gem, long legs with white greaves carrying green gems and gold bands,
-- split white hooves, long head with a forehead gem, branching antlers tipped with glowing green
-- crystals, a leaf-plume tail.
function M.Elderstag(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local T, W, G, GO, CR, EY = C("#EDE3C8"), C("#FBFAF5"), C("#5FCB78"), C("#D4A743"), C("#7CFFB0"), C("#7CFFB0")
	local BY = 2.75
	local body = k.body(1.3, 1.3, 2.6, T, BY)
	k.b(body, "ChestFrame", 0.62, 0.62, 0.1, GO, c(0, 0.15, -1.33) * ANG(0, 0, PI / 4))
	k.diamond(body, "ChestGem", 0.75, 0.5, 0.14, CR, c(0, 0.15, -1.37), MAT.Glass)
	-- leaf blade lying along its frame's +X (flat in Y): blade + pointed tip
	local function leaf(cf, L, wd, col)
		k.b(body, "Leaf", L * 0.8, 0.1, wd, col, cf * c(L * 0.4, 0, 0))
		k.tri(body, "LeafTip", 0.1, L * 0.25, wd, col, cf * c(L * 0.92, 0, 0) * ANG(0, 0, -PI / 2))
	end
	-- mantle: leaves draping over both flanks, sweeping back
	for _, sd in ipairs(SIDES) do
		for i = 0, 3 do
			local col = ((i + (sd > 0 and 1 or 0)) % 2 == 0) and G or W
			leaf(c(sd * 0.5, 0.72, -1.0 + i * 0.55) * ANG(0, sd < 0 and PI or 0, 0) * ANG(0, -sd * 0.35, -0.7), 1.4 - i * 0.08, 0.7, col)
		end
	end
	-- along the spine, pointing back
	for i = 0, 2 do
		leaf(c(0, 0.7, -0.7 + i * 0.6) * ANG(0, -PI / 2, -0.25), 1.1, 0.6, (i % 2 == 0) and W or G)
	end
	-- white leaf bib down the chest (green at the outer edges)
	for i, x in ipairs({ -0.46, -0.23, 0, 0.23, 0.46 }) do
		leaf(c(x, 0.45, -1.36 - (0.5 - math.abs(x)) * 0.1) * ANG(0, 0, -PI / 2 - x * 0.5), 1.25 - math.abs(x) * 0.6, 0.32, (i == 1 or i == 5) and G or W)
	end

	local function greave(knee)
		k.b(knee, "Greave", 0.56, 0.55, 0.64, W, c(0, -0.35, 0))
		k.diamond(knee, "GreaveGem", 0.35, 0.22, 0.08, CR, c(0, -0.35, -0.35), MAT.Glass)
	end
	local lg = { up = { 0.6, 1.0, 0.75 }, col = T, w2 = 0.46, d2 = 0.56, band = GO, paw = { 0.58, 0.42, 0.72 }, pawCol = W, toes = 2, toeCol = W }
	local _, _, k1 = k.leg(body, "LegFL", BY, -0.42, -0.5, -1.0, lg); greave(k1)
	local _, _, k2 = k.leg(body, "LegFR", BY, 0.42, -0.5, -1.0, lg); greave(k2)
	lg.hind = true
	local _, _, k3 = k.leg(body, "LegBL", BY, -0.42, -0.5, 1.0, lg); greave(k3)
	local _, _, k4 = k.leg(body, "LegBR", BY, 0.42, -0.5, 1.0, lg); greave(k4)
	rig.legKind = "quad"

	k.b(body, "Neck", 0.6, 1.3, 0.7, T, c(0, 1.0, -1.3) * ANG(-0.35, 0, 0))
	for i = 0, 2 do k.tri(body, "NeckLeaf", 0.12, 0.8, 0.45, (i == 1) and W or G, c(0, 1.35 - i * 0.35, -1.05 + i * 0.12) * ANG(1.0, 0, 0)) end
	local head = k.head(body, 0.65, 0.65, 1.2, T, c(0, 1.85, -1.85), V3(0, -0.2, 0.4))
	k.w(head, "Snout", 0.55, 0.4, 0.5, T, c(0, -0.1, -0.8))
	k.diamond(head, "ForeheadGem", 0.35, 0.22, 0.08, CR, c(0, 0.2, -0.62), MAT.Glass)
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.25, 0.08, -0.61, 0.16, 0.09, EY, sd * 0.3)
		local ear = k.ear(head, sd, c(sd * 0.32, 0.28, 0.25) * ANG(0, 0, -sd * 0.9))
		k.tri(ear, "Ear", 0.12, 0.45, 0.3, T, c(0, 0.22, 0) * FACE)
		-- branching antler: main beam out and up, three tines, crystal tips
		local A = {
			V3(sd * 0.2, 0.3, 0.1), V3(sd * 0.7, 0.95, 0.15), V3(sd * 1.3, 1.25, 0.2),
		}
		k.bar(head, "Antler", A[1], A[2], 0.18, T)
		k.bar(head, "Antler", A[2], A[3], 0.16, T)
		local tines = { { A[2], V3(sd * 0.6, 1.55, 0.15) }, { (A[2] + A[3]) / 2, V3(sd * 1.05, 1.75, 0.18) }, { A[3], V3(sd * 1.6, 1.75, 0.2) } }
		for _, tn in ipairs(tines) do
			k.bar(head, "AntlerTine", tn[1], tn[2], 0.14, GO)
			k.crystal(head, "AntlerCrystal", 0.5, 0.18, CR, k.sc(CF(tn[2])), MAT.Glass, 0.1)
		end
	end

	local tip = k.tail(body, c(0, 0.45, 1.25), { { 0.4, 0.35, 0.5, -0.4, T } })
	for i, a in ipairs({ -0.5, 0, 0.5 }) do
		k.tri(tip, "TailLeaf", 0.12, 1.1, 0.5, (i == 2) and W or G, c(a * 0.3, 0, 0.6) * ANG(PI / 2 - 0.2, a, 0))
	end
end

---------------------------------------------------------------- OAK TITAN (Legendary)
-- Walking oak golem: bark torso with a glowing amber hex core, leaf V panels at the hips, leaf
-- shoulder pads, branches with leafy pads growing from shoulders and head, huge bark fists with
-- glowing amber seams, trunk legs that splay into roots, glowing amber eyes under a heavy brow.
function M.OakTitan(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local BK, BKD, BKL, LF, LFD, GL = C("#7A4E2C"), C("#5E3B20"), C("#8E5E36"), C("#7CCB3E"), C("#5FAE2E"), C("#FFC83A")
	local function branch(parent, a, b, leaf)
		k.bar(parent, "Branch", a, b, 0.22, BKD, nil, nil, V3(0, 0, 1))
		if leaf then k.b(parent, "Canopy", 1.0, 0.25, 0.8, LF, c(b.X, b.Y + 0.1, b.Z)) end
	end
	local BY = 3.4
	local body = k.body(2.2, 2.0, 1.5, BK, BY)
	k.b(body, "CoreFrame", 0.95, 0.95, 0.12, BKD, c(0, 0.2, -0.8) * ANG(0, 0, PI / 4))
	local _, core = k.b(body, "Core", 0.6, 0.6, 0.14, GL, c(0, 0.2, -0.83) * ANG(0, 0, PI / 4), MAT.Neon)
	k.glow(core, GL)
	k.b(body, "Plank", 0.5, 1.2, 0.1, BKL, c(0, -0.6, -0.78))
	for _, sd in ipairs(SIDES) do
		k.tri(body, "HipLeaf", 0.1, 0.8, 0.6, LF, c(sd * 0.6, -0.85, -0.8) * DOWN * FACE)
		local _, seam = k.bar(body, "Seam", V3(sd * 0.5, 0.75, -0.77), V3(sd * 0.85, 0.2, -0.77), 0.07, GL, MAT.Neon, nil, nil, 0.04)
		k.glow(seam, GL)
	end
	k.b(body, "Hips", 1.8, 0.6, 1.3, BKD, c(0, -1.2, 0))

	local lg = { up = { 1.05, 0.8, 1.05 }, col = BK, w2 = 1.0, d2 = 1.0, col2 = BKL, paw = { 1.5, 0.5, 1.5, 0 }, pawCol = BKD }
	for _, sd in ipairs(SIDES) do
		local _, _, knee, lh = k.leg(body, sd < 0 and "LegL" or "LegR", BY, sd * 0.6, -1.4, 0, lg)
		for i = 0, 3 do
			local a = i * PI / 2 + PI / 4
			k.w(knee, "Root", 0.4, 0.45, 0.6, BKD, c(math.sin(a) * 0.85, -lh - 0.27, math.cos(a) * 0.85) * ANG(0, a + PI, 0))
		end
	end
	rig.legKind = "biped"

	for _, sd in ipairs(SIDES) do
		local arm = k.arm(body, sd, c(sd * 1.4, 0.6, 0))
		k.b(arm, "ShoulderLeaf", 1.3, 0.3, 1.2, LF, c(sd * 0.2, 0.55, 0))
		k.b(arm, "Shoulder", 1.1, 0.7, 1.1, BKL, c(sd * 0.2, 0.15, 0))
		k.b(arm, "UpperArm", 0.85, 1.0, 0.85, BK, c(sd * 0.25, -0.65, 0))
		local _, fore = k.b(arm, "Forearm", 1.35, 1.2, 1.35, BK, c(sd * 0.3, -1.6, -0.05))
		local _, ln = k.b(fore, "ForearmGlow", 1.37, 0.08, 1.37, GL, c(0, 0.15, 0), MAT.Neon)
		k.glow(ln, GL)
		k.b(fore, "ForearmLeaf", 0.6, 0.3, 0.8, LF, c(sd * 0.5, 0.55, 0))
		local _, fist = k.b(arm, "Fist", 1.45, 1.15, 1.4, BKL, c(sd * 0.3, -2.75, -0.1))
		for f = 1, 3 do k.b(fist, "Finger", 0.4, 0.4, 0.22, BKD, c((f - 2) * 0.45, 0.15, -0.75)) end
		branch(body, V3(sd * 1.0, 0.95, 0.2), V3(sd * 1.7, 2.0, 0.3), true)
		branch(body, V3(sd * 1.2, 1.4, 0.25), V3(sd * 2.2, 1.7, 0.1), true)
	end

	local head = k.head(body, 0.95, 1.0, 0.9, BK, c(0, 1.4, -0.1), V3(0, -0.45, 0.1))
	k.b(head, "Brow", 1.05, 0.25, 0.3, BKD, c(0, 0.18, -0.4))
	k.b(head, "Jaw", 0.75, 0.25, 0.3, BKD, c(0, -0.35, -0.38))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.22, 0.02, -0.46, 0.24, 0.1, GL, sd * 0.25)
		branch(head, V3(sd * 0.3, 0.45, 0), V3(sd * 0.6, 1.3, 0.05), true)
	end
	branch(head, V3(0, 0.45, 0.1), V3(0, 1.45, 0.25), true)
	k.b(head, "CanopyTop", 0.8, 0.25, 0.7, LFD, c(0, 1.85, 0.25))
end

---------------------------------------------------------------- BLOOMWYRM (Mythical)
-- Flower dragon: green body clad in pink petal plates with a lotus on the chest, green legs with
-- pink claws, segmented pink/green neck, green head with curved pink horns, a lotus crown and pink
-- eyes, huge wings (green arm bones, pink membranes, hot-pink edges), a tail lined with leaf blades.
function M.Bloomwyrm(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local G, GD, PK, HP, EY = C("#5EC25A"), C("#3E9A3E"), C("#F7B0CC"), C("#EE3F8E"), C("#FF3F9E")
	-- upright fan of lotus petals (faces -Z); outer/inner colours
	local function lotus(parent, cf, size, outer, inner)
		for i, a in ipairs({ -0.9, -0.45, 0, 0.45, 0.9 }) do
			k.tri(parent, "Lotus", 0.1, size * (1 - math.abs(a) * 0.25), size * 0.5, (i == 3) and inner or outer, cf * ANG(0, 0, -a) * c(0, size * 0.45, 0) * FACE)
		end
	end
	local BY = 2.3
	local body = k.body(1.8, 1.5, 2.4, G, BY)
	k.b(body, "Chest", 1.6, 1.4, 0.8, PK, c(0, 0.05, -1.1))
	lotus(body, c(0, -0.35, -1.53), 1.1, HP, C("#FF7AB0"))
	for _, sd in ipairs(SIDES) do
		for i = 0, 2 do
			k.diamond(body, "Petal", 0.9, 0.5, 0.1, (i % 2 == 0) and PK or HP, c(sd * 0.92, 0.1, -0.6 + i * 0.6) * ANG(0, -sd * PI / 2, 0) * ANG(0, 0, 0.6))
		end
	end
	for i = 0, 4 do
		k.tri(body, "BackLeaf", 0.14, 0.6, 0.5, (i % 2 == 0) and PK or G, c(0, 0.95, -0.8 + i * 0.45) * ANG(0.5, 0, 0))
	end

	local lf = { up = { 0.8, 0.75, 0.9 }, col = G, w2 = 0.68, d2 = 0.75, col2 = GD, paw = { 0.95, 0.35, 1.1 }, pawCol = G, toes = 3, toeCol = PK, band = PK }
	k.leg(body, "LegFL", BY, -0.75, -0.5, -0.8, lf)
	k.leg(body, "LegFR", BY, 0.75, -0.5, -0.8, lf)
	lf.hind = true
	k.leg(body, "LegBL", BY, -0.78, -0.45, 0.85, lf)
	k.leg(body, "LegBR", BY, 0.78, -0.45, 0.85, lf)
	rig.legKind = "quad"

	k.b(body, "Neck1", 0.85, 0.9, 0.8, PK, c(0, 0.75, -1.35) * ANG(-0.5, 0, 0))
	k.b(body, "Neck2", 0.75, 0.85, 0.75, G, c(0, 1.35, -1.6) * ANG(-0.25, 0, 0))
	local head = k.head(body, 1.0, 0.8, 1.2, G, c(0, 2.0, -1.95), V3(0, -0.3, 0.4))
	k.b(head, "Snout", 0.7, 0.45, 0.7, G, c(0, -0.12, -0.85))
	local jaw = k.jb(head, "Jaw", 0.66, 0.2, 0.9, GD, c(0, -0.42, -0.55), V3(0, 0, 0.45))
	H.group(rig, "jaws", jaw)
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.3, 0.1, -0.61, 0.24, 0.1, EY, sd * 0.3)
		k.spike(head, "Horn", 1.1, 0.3, PK, c(sd * 0.35, 0.35, 0.25) * ANG(0.8, 0, -sd * 0.45))
		k.tri(head, "Frill", 0.1, 0.6, 0.45, PK, c(sd * 0.55, 0.0, 0.3) * ANG(0.6, 0, -sd * 1.2))
	end
	-- lotus crown: two crossed upright petal fans on top of the head
	lotus(head, c(0, 0.38, 0.05), 0.75, PK, HP)
	lotus(head, c(0, 0.38, 0.05) * ANG(0, PI / 2, 0), 0.6, HP, PK)

	for _, sd in ipairs(SIDES) do
		local w = k.wing(body, sd, c(sd * 0.75, 0.6, -0.3))
		k.batWing(w, sd, { wrist = Vector2.new(1.5, 2.3), bone = G, mem = PK, boneW = 0.34, cap = GD,
			tips = { Vector2.new(4.0, 1.1), Vector2.new(3.5, -0.3), Vector2.new(2.5, -1.0), Vector2.new(1.2, -0.9) } })
		k.bar(w, "WingEdge", V3(sd * 4.0, 1.1, 0.1), V3(sd * 3.5, -0.3, 0.1), 0.16, HP)
		k.bar(w, "WingEdge", V3(sd * 3.5, -0.3, 0.1), V3(sd * 2.5, -1.0, 0.1), 0.16, HP)
	end

	local segs = {}
	for j = 1, 8 do
		local w = 0.8 - j * 0.065
		table.insert(segs, { w, w * 0.85, 0.6, (j % 2 == 0) and GD or G, j == 1 and 0.3 or -0.06 })
	end
	local rec = k.chain(body, c(0, 0.1, 1.15), segs, { name = "Tail", kind = "spine", i = 1, amp = 0.16, freq = 1.3, lag = 0.55 })
	for j, p in ipairs(rec.parts) do
		local w = 0.8 - j * 0.065
		for _, sd in ipairs(SIDES) do
			k.tri(p, "TailLeaf", 0.12, 1.0 - j * 0.05, 0.55, (j % 2 == 0) and PK or G, c(sd * (w * 0.5 + 0.25), 0.1, 0) * ANG(0.6, 0, -sd * 1.1))
		end
	end
	k.tri(rec.parts[#rec.parts], "TailTip", 0.12, 0.9, 0.5, PK, c(0, 0, 0.7) * ANG(PI / 2, 0, 0))
end

---------------------------------------------------------------- SYLPH QUEEN (Mythical)
-- Hovering fairy queen: slim mint torso with a pink chest gem and white collar spikes, a layered petal
-- skirt (mint, white, pink) hanging to a point, thin white arms and hands, mint head with a white mask,
-- glowing pink eyes, pink-and-white crown, segmented antennae with pink tips, four long angular mint
-- wings with white borders and pink stripes.
function M.SylphQueen(H, rig, vd, s)
	local k = K.new(H, rig, s)
	local c = k.c
	local MG, MGD, W, P, PD, EY = C("#B8EBB0"), C("#98D890"), C("#F8F8F6"), C("#F282B8"), C("#E05FA0"), C("#FF4FA0")
	local BY = 3.0
	local body = k.body(0.8, 0.9, 0.55, MG, BY)
	rig.legKind = "none"
	k.diamond(body, "ChestGem", 0.4, 0.28, 0.08, P, c(0, 0.1, -0.3), MAT.Glass)
	k.b(body, "Waist", 0.6, 0.35, 0.45, W, c(0, -0.55, 0))
	for _, sd in ipairs(SIDES) do
		k.tri(body, "Collar", 0.12, 0.6, 0.45, W, c(sd * 0.45, 0.45, 0) * ANG(0, 0, -sd * 0.9) * FACE)
	end
	-- full petal skirt: a ring of petals facing outward, flaring a little, longest at the front
	local cols = { MG, W, P, MG, W, MG, P, W, MG, W }
	for i = 0, 9 do
		local a = i / 10 * PI * 2
		local x, z = math.sin(a) * 0.5, -math.cos(a) * 0.4
		local L = 1.9 - math.abs(math.sin(a / 2)) * 0.5
		local te, tp = k.pv(body, "SkirtPivot", c(x, -0.65, z) * ANG(0, math.atan2(x, z), 0) * ANG(-0.4, 0, 0))
		table.insert(rig.tail, te)
		k.tri(tp, "Skirt", 0.12, L, 0.7, cols[i + 1], c(0, -L / 2, 0) * DOWN * FACE)
	end

	for _, sd in ipairs(SIDES) do
		local a = k.arm(body, sd, c(sd * 0.48, 0.3, 0))
		k.b(a, "UpperArm", 0.22, 0.6, 0.22, W, c(sd * 0.05, -0.3, 0))
		k.b(a, "Forearm", 0.2, 0.55, 0.2, W, c(sd * 0.1, -0.85, -0.1) * ANG(-0.3, 0, 0))
		local _, hand = k.b(a, "Hand", 0.24, 0.26, 0.14, W, c(sd * 0.12, -1.22, -0.22))
		for f = 1, 3 do k.b(hand, "Finger", 0.06, 0.2, 0.06, W, c((f - 2) * 0.08, -0.2, 0)) end
	end

	local head = k.head(body, 0.55, 0.6, 0.55, MG, c(0, 0.85, 0), V3(0, -0.3, 0.05))
	k.b(head, "Mask", 0.5, 0.25, 0.08, W, c(0, -0.05, -0.29))
	for _, sd in ipairs(SIDES) do
		k.eye(head, sd * 0.12, 0.08, -0.31, 0.14, 0.07, EY, sd * 0.3)
		k.tri(head, "CrownLeaf", 0.08, 0.5, 0.25, W, c(sd * 0.22, 0.4, 0) * ANG(0, 0, -sd * 0.5) * FACE)
		local ant = k.ear(head, sd, c(sd * 0.15, 0.3, 0.05), "antenna")
		local p1, p2, p3 = V3(0, 0, 0), V3(sd * 0.35, 0.8, 0.1), V3(sd * 0.85, 1.05, 0.0)
		k.bar(ant, "Antenna", p1, p2, 0.08, MG, nil, nil, V3(0, 0, 1))
		k.bar(ant, "Antenna", p2, p3, 0.08, MG, nil, nil, V3(0, 0, 1))
		k.b(ant, "AntennaTip", 0.14, 0.32, 0.14, P, c(p3.X + sd * 0.05, p3.Y - 0.15, p3.Z))
	end
	k.tri(head, "Crown", 0.1, 0.7, 0.3, P, c(0, 0.6, 0) * FACE)
	k.tri(head, "CrownSide", 0.1, 0.45, 0.25, PD, c(0, 0.5, 0.05) * FACE)

	local V2 = Vector2.new
	for _, sd in ipairs(SIDES) do
		for tier, w in ipairs({
			{ V2(0, 0), V2(1.2, 2.0), V2(3.0, 2.6), V2(2.6, 1.0) },
			{ V2(0, 0), V2(1.5, -0.2), V2(2.9, -1.6), V2(1.2, -1.4) },
		}) do
			local pv = k.wing(body, sd, c(sd * 0.35, 0.2, 0.2 + (tier - 1) * 0.12) * ANG(0, -sd * (0.3 + tier * 0.1), 0), tier)
			kite(k, pv, sd, w[1], w[2], w[3], w[4], MG, 0)
			local function P3(v, z) return V3(v.X * sd, v.Y, z or -0.06) end
			k.bar(pv, "WingBorder", P3(w[2]), P3(w[3]), 0.16, W)
			k.bar(pv, "WingBorder", P3(w[3]), P3(w[4]), 0.16, W)
			k.bar(pv, "WingStripe", P3((w[1] + w[2]) / 2), P3((w[3] + w[4]) / 2), 0.14, P)
		end
	end
end

return M
