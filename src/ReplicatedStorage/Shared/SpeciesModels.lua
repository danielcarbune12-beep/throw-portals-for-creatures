-- SpeciesModels: hand-authored, reference-faithful creature models (highest priority path).
-- Location: ReplicatedStorage > Shared > SpeciesModels (ModuleScript)
--
-- Each entry is model(H, rig, vd, s) and must fill the standard rig channels used by
-- CreatureAnimator: bodyEntry/body, headEntry/head, feet (FL, FR, BL, BR — one pivot per leg),
-- legKind, tail (ordered chain entries), ears {e, side}, eyes, groups.
-- Reference: roblox pets/Pets/<World>/<NN>_<Id>.png. Construction notes live above each model.

local M = {}
local PI = math.pi
local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local function C(h) return Color3.fromHex(h) end
local MAT = Enum.Material

---------------------------------------------------------------- PRISM LION (29_PrismLion.png)
-- Low powerful stance, deep chest, four thick column legs with big three-toed boxy paws,
-- boxy skull with heavy brow + projecting angular muzzle + squared jaw, small triangular ears,
-- forehead gem, large two-layer radial crystal mane (purple, cyan tips) + chest bib,
-- white armour plates with purple chevron insets and ankle bands, 5-segment tail curling up
-- to a big crystal cluster.
-- Hierarchy: Root > Body(torso) > {Chest, Hips, ShoulderPlates, NeckPivot > Head > {Muzzle, Jaw,
-- Brow, Ears, Gem, ManePivots}, LegFL/FR/BL/BR > Leg > Paw > Toes, TailRoot > Seg1..5 > Tip}
function M.PrismLion(H, rig, vd, s)
	local white, shade, deep = C("#FBF6FF"), C("#E6DAF2"), C("#CDBDE0")
	local purple, lav, cyan, nose = C("#9D52F2"), C("#C49BFF"), C("#86E4FF"), C("#B4A0D2")
	local SP, GL = MAT.SmoothPlastic, MAT.Glass
	local function v(x, y, z) return V3(x, y, z) * s end
	local function c(x, y, z) return CF(x * s, y * s, z * s) end

	-- faceted gem: flattened prism body + crossed pyramid tip (pointed and solid from every view),
	-- base at cf, tip at +Y; colB tints one tip facet (the cyan glint in the reference)
	local function gem(parent, cf, len, w, colA, colB)
		local L, W = len * s, w * s
		local bodyL = L * 0.58
		H.blk(rig, parent, "Gem", V3(W, bodyL, W * 0.75), colA, cf * CF(0, bodyL / 2, 0), GL, 0.04)
		local tip = cf * CF(0, bodyL + L * 0.21, 0)
		H.tri(rig, parent, "GemTip", W * 0.75, L * 0.42, W, colA, tip * ANG(0, PI / 2, 0), GL, 0.04)
		H.tri(rig, parent, "GemFacet", W * 0.98, L * 0.42, W * 0.75, colB, tip, GL, 0.04)
	end

	---------------------------------------------------------------- torso: long, low, chunky
	local be, body = H.blk(rig, rig.root, "Body", v(2.0, 1.6, 2.9), white, c(0, 2.05, 0.1), SP)
	rig.bodyEntry, rig.body = be, body
	rig.bodyRadius = v(1.0, 0.7, 1.45)
	H.blk(rig, body, "Chest", v(2.2, 2.0, 1.2), white, c(0, 0.05, -1.35), SP)
	H.blk(rig, body, "Belly", v(1.7, 0.3, 2.2), shade, c(0, -0.84, 0.1), SP)
	H.blk(rig, body, "Hips", v(2.0, 1.5, 1.1), white, c(0, 0.0, 1.35), SP)
	H.wdg(rig, body, "Rump", v(1.98, 0.5, 0.6), white, c(0, 0.92, 1.55) * ANG(0, PI, 0), SP)
	H.blk(rig, body, "BackPlate", v(1.2, 0.16, 2.0), shade, c(0, 0.78, 0.2), SP)
	for _, sd in ipairs({ -1, 1 }) do
		-- shoulder armour plate + one slanted purple panel stripe on shoulder and haunch
		H.blk(rig, body, "ShoulderPlate", v(0.2, 1.35, 1.25), shade, c(sd * 1.13, 0.1, -1.15), SP)
		for _, ch in ipairs({ { -1.15, 1 }, { 1.3, -1 } }) do
			H.blk(rig, body, "Stripe", v(0.06, 0.24, 1.15), purple, c(sd * 1.235, 0.12, ch[1]) * ANG(0.75 * ch[2], 0, 0), SP)
		end
	end

	---------------------------------------------------------------- legs: hip pivot -> upper -> knee pivot -> lower + paw
	-- hip is 1.45 above ground; the knee lets crouch/stride bend instead of sinking the paws
	local function leg(name, x, z, hind)
		local pv = H.pivot(rig, body, name, c(x, -0.6, z))
		if hind then
			H.blk(rig, pv.part, "Thigh", v(1.0, 0.95, 1.15), white, c(0, -0.25, 0.05), SP)
		else
			H.blk(rig, pv.part, "Upper", v(0.9, 0.8, 0.95), white, c(0, -0.32, 0), SP)
			H.blk(rig, pv.part, "LegPlate", v(0.66, 0.6, 0.08), shade, c(0, -0.32, -0.5), SP)
		end
		local knee = H.pivot(rig, pv.part, name .. "Knee", c(0, -0.7, 0))
		H.blk(rig, knee.part, "Leg", v(0.8, 0.45, 0.86), white, c(0, -0.18, 0), SP)
		H.blk(rig, knee.part, "AnkleBand", v(0.86, 0.12, 0.92), purple, c(0, -0.38, 0), SP)
		H.blk(rig, knee.part, "Paw", v(1.15, 0.36, 1.3), white, c(0, -0.57, -0.12), SP)
		for t = -1, 1 do
			H.blk(rig, knee.part, "Toe", v(0.32, 0.32, 0.36), shade, c(t * 0.37, -0.59, -0.8), SP)
		end
		pv.knee, pv.upperLen, pv.kneeDir = knee, 0.7 * s, hind and -1 or 1
		table.insert(rig.feet, pv)
	end
	leg("LegFL", -0.82, -1.25, false)
	leg("LegFR", 0.82, -1.25, false)
	leg("LegBL", -0.8, 1.35, true)
	leg("LegBR", 0.8, 1.35, true)
	rig.legKind = "quad"

	---------------------------------------------------------------- neck + big broad head
	local neck = H.pivot(rig, body, "NeckPivot", c(0, 0.55, -1.75))
	H.blk(rig, neck.part, "Neck", v(1.4, 1.2, 0.9), white, c(0, 0.3, -0.1) * ANG(-0.3, 0, 0), SP)
	local he, head = H.blk(rig, neck.part, "Head", v(1.85, 1.55, 1.5), white, c(0, 0.95, -0.75), SP, nil, c(0, -0.5, 0.25))
	rig.headEntry, rig.head = he, head
	rig.headRadius, rig.faceY = v(0.92, 0.78, 0.75), 0
	local fz = -0.75 -- face plane (head local)
	H.wdg(rig, head, "Crest", v(1.3, 0.28, 1.0), shade, c(0, 0.9, 0.15), SP) -- high at the back, slopes to the brow
	H.blk(rig, head, "Forehead", v(0.9, 0.5, 0.2), white, c(0, 0.5, fz + 0.05), SP)
	H.blk(rig, head, "Muzzle", v(1.1, 0.62, 0.8), white, c(0, -0.42, fz - 0.32), SP)
	H.wdg(rig, head, "MuzzleBridge", v(0.6, 0.26, 0.5), white, c(0, -0.04, fz - 0.24) * ANG(0, PI, 0), SP)
	H.wdg(rig, head, "Nose", v(0.42, 0.2, 0.24), nose, c(0, -0.08, fz - 0.62) * ANG(0, PI, 0), SP)
	H.blk(rig, head, "NoseFront", v(0.42, 0.14, 0.08), nose, c(0, -0.18, fz - 0.7), SP)
	H.blk(rig, head, "MouthLine", v(0.62, 0.05, 0.05), deep, c(0, -0.55, fz - 0.71), SP)
	local jaw = H.blk(rig, head, "Jaw", v(0.9, 0.28, 0.65), shade, c(0, -0.76, fz - 0.22), SP, nil, c(0, 0, 0.3))
	H.group(rig, "jaws", jaw)
	for _, sd in ipairs({ -1, 1 }) do
		-- angled brow (inner end lower) gives the stern lion look over the eyes
		H.blk(rig, head, "Brow", v(0.98, 0.26, 0.45), shade, c(sd * 0.46, 0.34, fz - 0.08) * ANG(0.3, 0, sd * 0.2), SP)
		H.wdg(rig, head, "Cheek", v(0.32, 0.85, 0.75), shade, c(sd * 0.95, -0.28, fz + 0.22), SP)
		H.blk(rig, head, "EyeSocket", v(0.48, 0.24, 0.06), deep, c(sd * 0.42, 0.1, fz - 0.02) * ANG(0, 0, sd * 0.22), SP)
		local eye = H.blk(rig, head, "Eye", v(0.4, 0.16, 0.06), purple, c(sd * 0.42, 0.1, fz - 0.05) * ANG(0, 0, sd * 0.22), MAT.Neon)
		table.insert(rig.eyes, eye)
		local ear = H.pivot(rig, head, "EarPivot", c(sd * 0.62, 0.75, 0.15) * ANG(0, 0, -sd * 0.3))
		H.tri(rig, ear.part, "Ear", 0.18 * s, 0.5 * s, 0.5 * s, white, c(0, 0.25, 0), SP)
		H.tri(rig, ear.part, "EarInner", 0.06 * s, 0.32 * s, 0.28 * s, purple, c(0, 0.18, -0.1), SP)
		table.insert(rig.ears, { e = ear, side = sd, kind = "cat" })
	end
	H.diamond(rig, head, "ForeheadGem", 0.5 * s, 0.3 * s, 0.1 * s, purple, c(0, 0.6, fz - 0.06), GL)

	---------------------------------------------------------------- mane: collar of gems round the face + long blades swept back
	-- centred on the back of the head so the front view reads as a sunburst around the face
	local manePivot = H.pivot(rig, neck.part, "ManePivot", c(0, 0.95, -0.05))
	-- collar: gems fanning out round the face (welded straight to the mane pivot)
	for i, deg in ipairs({ -160, -120, -80, -40, 0, 40, 80, 120, 160 }) do
		local a = math.rad(deg)
		gem(manePivot.part, CF(math.sin(a) * 0.88 * s, math.cos(a) * 0.78 * s, 0) * ANG(0.5, 0, -a), 1.9 - math.abs(deg) / 180 * 0.6, 0.95,
			(i % 3 == 0) and lav or purple, (i % 2 == 0) and cyan or lav)
	end
	-- mid ring: fills the neck sides between collar and back sweep
	for i, deg in ipairs({ -130, -75, 75, 130 }) do
		local a = math.rad(deg)
		gem(manePivot.part, CF(math.sin(a) * 0.85 * s, math.cos(a) * 0.8 * s, 0.3 * s) * ANG(0.85, 0, -a), 2.2, 1.0, purple, (i % 2 == 0) and cyan or lav)
	end
	-- back sweep: long blades streaming back over the shoulders, longest on top (each flares on the pounce)
	for i, deg in ipairs({ -120, -80, -40, 0, 40, 80, 120 }) do
		local a = math.rad(deg)
		local pv = H.pivot(rig, manePivot.part, "ManeRoot", CF(math.sin(a) * 0.7 * s, math.cos(a) * 0.7 * s, 0.55 * s) * ANG(1.15, 0, -a))
		gem(pv.part, CF(), 3.0 - math.abs(deg) / 180 * 1.1, 1.05, (i % 3 == 0) and lav or purple, (i % 2 == 1) and cyan or lav)
		pv.openAxis, pv.openAmt = V3(1, 0, 0), -0.2
		H.group(rig, "open", pv)
		H.group(rig, "mane", pv)
	end
	-- chest bib: downward gems under the chin
	for i, x in ipairs({ -0.4, 0, 0.4 }) do
		gem(neck.part, c(x, 0.55, -1.05) * ANG(0, 0, PI) * ANG(-0.15, 0, -x * 0.5), i == 2 and 1.35 or 1.0, 0.7, purple, i == 2 and cyan or lav)
	end

	---------------------------------------------------------------- tail: 5 thick segments curling up + one big crystal
	local prev = body
	local seg = { { 0.6, 0.62, 0 }, { 0.56, 0.6, -0.5 }, { 0.52, 0.56, -0.6 }, { 0.48, 0.54, -0.6 }, { 0.46, 0.5, -0.5 } }
	for i, d in ipairs(seg) do
		local w = d[1] * s
		local c0 = (i == 1) and c(0, 0.45, 1.9) * ANG(0.3, 0, 0) or CF(0, 0, d[2] * s) * ANG(d[3], 0, 0)
		local e, p = H.blk(rig, prev, "TailSeg", V3(w, w, d[2] * s * 1.15), i % 2 == 0 and shade or white, c0, SP, nil, CF(0, 0, -d[2] * s * 0.5))
		table.insert(rig.tail, e)
		prev = p
	end
	local tipPv = H.pivot(rig, prev, "TailTip", CF(0, 0, 0.25 * s) * ANG(PI / 2, 0, 0))
	gem(tipPv.part, CF(), 2.1, 1.1, purple, cyan)
end

return M
