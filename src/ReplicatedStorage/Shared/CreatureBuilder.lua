-- CreatureBuilder: builds a rigged, procedural creature from CreatureData + SpeciesProfiles.
-- Location: ReplicatedStorage > Shared > CreatureBuilder (ModuleScript)
--
-- Every visible piece is a Part + SpecialMesh (Sphere / Cylinder / Brick / Wedge) joined with
-- Welds, so CreatureAnimator can bend joints by rewriting Weld.C0 from stored bind transforms
-- (no animation assets, no drift). Species anatomy (nine tails, hydra necks, kraken tentacles,
-- wyvern legs, ...) lives in SpeciesAnatomy and is selected by SpeciesProfiles.
--
-- PUBLIC CONTRACT (unchanged): Builder.Build(id, sizeMult) -> model, rig
--   model.PrimaryPart = hidden anchored "Root" at ground level, front = local -Z.
--
-- RIG FIELDS
--   model, root, def (original CreatureData entry, never mutated), vd (visual view: def + overrides),
--   profile (SpeciesProfiles entry), size (s), pal {p,s,a}
--   all      : every weld entry { w, c0, c1, mesh, part, scale? }       (bind transforms)
--   body, head, bodyRadius, headRadius, bodyEntry, headEntry
--   eyes, pupils, lids?, mouths (mouth = mouths[1]), ears {e, side}, wings {e, side, tier}
--   tail (generic tail entries), feet (ordered: FL, FR, BL, BR / bug: 6 / biped: L, R),
--   arms {e, side}, halos, bobbers, emitters, light?
--   chains   : array of { name, kind, entries = {...}, i, n, side, amp, freq, lag, axis, spread }
--   groups   : name -> array of entries (spines, plates, mane, rays, motifs, fragments, heads, ...)
--   core     : optional glowing core entry
--   legKind  : "quad" | "biped" | "bug6" | "none"

local Config = require(script.Parent.Config)
local CreatureData = require(script.Parent.CreatureData)
local Profiles = require(script.Parent.SpeciesProfiles)

local Builder = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function hex(h) return Color3.fromHex(h) end
local function lighten(c, k) return c:Lerp(Color3.new(1, 1, 1), k) end
local function darken(c, k) return c:Lerp(Color3.new(0, 0, 0), k) end
local PINK = Color3.fromRGB(255, 140, 170)
local DARK = Color3.fromRGB(30, 22, 35)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 60)
local PI = math.pi

-- SHARED STYLE TABLE (current art direction: hard-surface BLOCKY family)
--   blocky  : structural pieces are cuboids (Brick meshes) instead of ellipsoids; faces are flat plates
--   squash  : 0 = body volumes never squash/stretch (weight comes from joints + root motion)
--   eyeW/eyeH: narrow rectangular eye aperture (fraction of the round-style eye)
-- Set blocky = false to get the previous rounded construction back (same rigs and channels).
local STYLE = { blocky = true, squash = 0, eyeW = 0.95, eyeH = 0.4, recess = 0.06 }
Builder.Style = STYLE

---------------------------------------------------------------------
-- low-level part helpers (exported as Builder.H for SpeciesAnatomy)
---------------------------------------------------------------------
local function newPiece(rig, name, size, color, mat, meshType, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(math.max(size.X, 0.02), math.max(size.Y, 0.02), math.max(size.Z, 0.02))
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = size.Magnitude > 1.2 and (transparency or 0) < 0.5
	local m = Instance.new("SpecialMesh")
	m.MeshType = meshType or Enum.MeshType.Sphere
	m.Parent = p
	p.Parent = rig.model
	return p, m
end

-- attach `part` to `parent`; C0 = pivot on parent, C1 = pivot inside part
local function attach(rig, parent, part, mesh, c0, c1)
	local w = Instance.new("Weld")
	w.Part0 = parent
	w.Part1 = part
	w.C0 = c0
	w.C1 = c1 or CFrame.identity
	w.Parent = part
	local entry = { w = w, c0 = c0, c1 = w.C1, mesh = mesh, part = part }
	table.insert(rig.all, entry)
	return entry
end

local function piece(meshType)
	return function(rig, parent, name, size, color, cf, mat, transp, c1)
		local p, m = newPiece(rig, name, size, color, mat, meshType, transp)
		return attach(rig, parent, p, m, cf, c1), p
	end
end
local ell = piece(STYLE.blocky and Enum.MeshType.Brick or Enum.MeshType.Sphere) -- structural form
local orb = piece(Enum.MeshType.Sphere) -- intentionally round pieces (cores, motes, bubbles)
local cyl = piece(Enum.MeshType.Cylinder)
local blk = piece(Enum.MeshType.Brick)
local wdg = piece(Enum.MeshType.Wedge)

-- invisible joint used to animate a cluster of welded pieces together
local function pivot(rig, parent, name, cf)
	local p, m = newPiece(rig, name, Vector3.new(0.05, 0.05, 0.05), WHITE, nil, Enum.MeshType.Sphere, 1)
	p.CastShadow = false
	return attach(rig, parent, p, m, cf), p
end

-- straight rod along local +Y of cf (SpecialMesh cylinders run along X, so wrap it in a pivot).
-- Returns the pivot entry: animate it, and parent children to entry.part in Y-up space.
local function rod(rig, parent, name, len, thick, color, cf, mat, tr)
	local pv = pivot(rig, parent, name .. "Pivot", cf)
	cyl(rig, pv.part, name, Vector3.new(len, thick, thick), color, CFrame.new(0, len / 2, 0) * CFrame.Angles(0, 0, PI / 2), mat, tr)
	return pv
end

-- triangular plate: plane YZ (thickness along X), apex +Y, base width along Z, centred on cf
local function tri(rig, parent, name, thick, h, base, color, cf, mat, tr)
	wdg(rig, parent, name, Vector3.new(thick, h, base / 2), color, cf * CFrame.new(0, 0, -base / 4), mat, tr)
	wdg(rig, parent, name, Vector3.new(thick, h, base / 2), color, cf * CFrame.new(0, 0, base / 4) * CFrame.Angles(0, PI, 0), mat, tr)
end

-- faceted rhombus: plane XY (faces -Z), long axis Y, centred on cf
local function diamond(rig, parent, name, len, width, thick, color, cf, mat, tr)
	local R = cf * CFrame.Angles(0, PI / 2, 0)
	tri(rig, parent, name, thick, len / 2, width, color, R * CFrame.new(0, len / 4, 0), mat, tr)
	tri(rig, parent, name, thick, len / 2, width, color, R * CFrame.new(0, -len / 4, 0) * CFrame.Angles(0, 0, PI), mat, tr)
end

-- faceted spike (crossed triangles), base at cf, pointing +Y
local function spike(rig, parent, name, len, base, color, cf, mat, tr)
	tri(rig, parent, name, base * 0.35, len, base, color, cf * CFrame.new(0, len / 2, 0), mat, tr)
	tri(rig, parent, name, base * 0.35, len, base, color, cf * CFrame.new(0, len / 2, 0) * CFrame.Angles(0, PI / 2, 0), mat, tr)
end

-- faceted crystal: square prism + pyramid cap, base at cf, pointing +Y
local function crystal(rig, parent, name, len, w, color, cf, mat, tr)
	local body = len * 0.62
	blk(rig, parent, name, Vector3.new(w, body, w), color, cf * CFrame.new(0, body / 2, 0) * CFrame.Angles(0, PI / 4, 0), mat, tr)
	local capCF = cf * CFrame.new(0, body + len * 0.19, 0)
	tri(rig, parent, name, w * 0.98, len * 0.38, w * 1.41, color, capCF * CFrame.Angles(0, PI / 4, 0), mat, tr)
	tri(rig, parent, name, w * 0.98, len * 0.38, w * 1.41, lighten(color, 0.15), capCF * CFrame.Angles(0, -PI / 4, 0), mat, tr)
end

-- ordered chain of segments; seg(j, n) -> size, color, mat, transparency, c0 (for j > 1)
-- first segment welds to `parent` at `c0first`. Returns the chain record (registered).
local function chain(rig, parent, name, c0first, n, seg, meta)
	local rec = { name = name, entries = {}, parts = {} }
	for k, v in pairs(meta or {}) do rec[k] = v end
	local prev = parent
	for j = 1, n do
		local size, color, mat, tr, c0, c1, meshType = seg(j, n)
		local p, m = newPiece(rig, name, size, color, mat, meshType or Enum.MeshType.Sphere, tr)
		local e = attach(rig, prev, p, m, j == 1 and c0first or c0, c1)
		table.insert(rec.entries, e)
		table.insert(rec.parts, p)
		prev = p
	end
	rec.n = n
	table.insert(rig.chains, rec)
	return rec
end

local function group(rig, name, entry)
	rig.groups[name] = rig.groups[name] or {}
	table.insert(rig.groups[name], entry)
	return entry
end

-- point on the body surface (front = -Z) + orientation facing outwards.
-- Blocky style: the flat face of the cuboid (side = -1 -> back face).
local function surface(r, x, y, side)
	local a, b, c = r.X, r.Y, r.Z
	if STYLE.blocky then
		local sd = side or 1
		local pos = Vector3.new(math.clamp(x, -a * 0.92, a * 0.92), math.clamp(y, -b * 0.92, b * 0.92), -c * sd)
		return CFrame.lookAt(pos, pos + Vector3.new(0, 0, -sd))
	end
	local k = 1 - (x / a) ^ 2 - (y / b) ^ 2
	local z = -c * math.sqrt(math.max(0.04, k)) * (side or 1)
	local pos = Vector3.new(x, y, z)
	local n = Vector3.new(x / (a * a), y / (b * b), z / (c * c)).Unit
	return CFrame.lookAt(pos, pos + n)
end

local function matOf(name)
	if not name then return Enum.Material.SmoothPlastic end
	return Enum.Material[name] or Enum.Material.SmoothPlastic
end

local H = {
	newPiece = newPiece, attach = attach, ell = ell, orb = orb, cyl = cyl, blk = blk, wdg = wdg, pivot = pivot, rod = rod, STYLE = STYLE,
	tri = tri, diamond = diamond, spike = spike, crystal = crystal, chain = chain, group = group,
	surface = surface, matOf = matOf, lighten = lighten, darken = darken,
	PINK = PINK, DARK = DARK, WHITE = WHITE, GOLD = GOLD,
}
Builder.H = H

---------------------------------------------------------------------
-- FACE
---------------------------------------------------------------------
local function buildEye(rig, head, r, x, y, w, h, def, accent, flip)
	local cf = surface(r, x, y)
	local style = def.eyes
	if STYLE.blocky then
		-- recessed narrow rectangular eye: dark socket + luminous slit (same vocabulary for every pet)
		local ew, eh = w * STYLE.eyeW, h * STYLE.eyeH * ((style == "sleepy") and 0.45 or (style == "cyclops" and 1.25 or 1))
		local glowCol = accent
		local lum = accent.R * 0.3 + accent.G * 0.59 + accent.B * 0.11
		if lum < 0.45 then glowCol = lighten(accent, 0.45) end
		if style == "glow" or style == "cyclops" then glowCol = lighten(glowCol, 0.15) end
		if accent.R + accent.G + accent.B < 0.2 then glowCol = Color3.fromRGB(255, 60, 80) end
		blk(rig, head, "EyeSocket", Vector3.new(ew * 1.25, eh * 1.6, 0.1), DARK, cf * CFrame.new(0, 0, STYLE.recess))
		local tilt = (style == "fierce") and math.rad(-14 * flip) or 0
		local e = blk(rig, head, "Eye", Vector3.new(ew, eh, 0.12), glowCol, cf * CFrame.Angles(0, 0, tilt), Enum.Material.Neon)
		if style == "sleepy" then e.sleepy = true end
		table.insert(rig.eyes, e)
		local pupil = blk(rig, e.part, "Pupil", Vector3.new(ew * 0.28, eh * 0.9, 0.06), DARK, CFrame.new(0, 0, -0.04))
		table.insert(rig.pupils, pupil)
		if style == "fierce" then
			local brow = blk(rig, head, "Brow", Vector3.new(ew * 1.4, eh * 0.55, 0.16), darken(def._p, 0.45),
				cf * CFrame.new(0, eh * 1.3, -0.02) * CFrame.Angles(0, 0, math.rad(-18 * flip)))
			group(rig, "brows", brow)
		end
		return
	end
	if style == "sleepy" then
		local e = ell(rig, head, "Eye", Vector3.new(w, h * 0.22, 0.12), DARK, cf * CFrame.new(0, 0, -0.02))
		e.sleepy = true
		table.insert(rig.eyes, e)
		return
	end
	local scleraColor = WHITE
	local mat = Enum.Material.SmoothPlastic
	if style == "glow" then scleraColor = lighten(accent, 0.35); mat = Enum.Material.Neon end
	local e, eyePart = ell(rig, head, "Eye", Vector3.new(w, h, 0.18), scleraColor, cf, mat)
	table.insert(rig.eyes, e)
	-- soft rim so dark-on-dark faces stay readable
	ell(rig, head, "EyeRim", Vector3.new(w * 1.14, h * 1.12, 0.12), darken(def._p, 0.35), cf * CFrame.new(0, 0, 0.03))
	if style ~= "glow" then
		local irisColor = (style == "sparkle" or style == "fierce" or style == "cyclops") and accent or DARK
		local iris = ell(rig, eyePart, "Pupil", Vector3.new(w * 0.72, h * 0.74, 0.1), irisColor, CFrame.new(0, -h * 0.04, -0.06))
		table.insert(rig.pupils, iris)
		if style ~= "big" then
			ell(rig, iris.part, "PupilCore", Vector3.new(w * 0.38, h * 0.42, 0.06), DARK, CFrame.new(0, 0, -0.03))
		end
		ell(rig, iris.part, "Shine", Vector3.new(w * 0.28, h * 0.26, 0.04), WHITE, CFrame.new(-w * 0.14 * flip, h * 0.16, -0.06), Enum.Material.Neon)
		ell(rig, iris.part, "Shine2", Vector3.new(w * 0.13, h * 0.12, 0.04), WHITE, CFrame.new(w * 0.14 * flip, -h * 0.16, -0.06), Enum.Material.Neon)
	else
		ell(rig, eyePart, "Shine", Vector3.new(w * 0.3, h * 0.3, 0.05), WHITE, CFrame.new(-w * 0.15 * flip, h * 0.15, -0.07), Enum.Material.Neon)
	end
	if style == "fierce" then
		local brow = ell(rig, head, "Brow", Vector3.new(w * 1.1, h * 0.16, 0.12), darken(def._p, 0.55),
			surface(r, x, y + h * 0.62) * CFrame.Angles(0, 0, math.rad(-18 * flip)))
		group(rig, "brows", brow)
	end
end

local function buildFace(rig, head, r, def, yOff, scaleK, opts)
	opts = opts or {}
	local accent = def._a
	scaleK = scaleK or 1
	local w, h = r.X * 0.42 * scaleK, r.Y * 0.5 * scaleK
	if def.eyes == "cyclops" then
		buildEye(rig, head, r, 0, yOff + r.Y * 0.05, w * 1.6, h * 1.5, def, accent, 1)
	else
		local sx = r.X * (opts.eyeSpread or 0.36)
		buildEye(rig, head, r, -sx, yOff, w, h, def, accent, 1)
		buildEye(rig, head, r, sx, yOff, w, h, def, accent, -1)
		if def.eyes ~= "fierce" and not opts.noCheeks and not STYLE.blocky then
			for _, side in ipairs({ -1, 1 }) do
				local ch = ell(rig, head, "Cheek", Vector3.new(r.X * 0.3, r.Y * 0.16, 0.08), PINK,
					surface(r, side * r.X * 0.58, yOff - r.Y * 0.32) * CFrame.new(0, 0, -0.01), nil, 0.35)
				group(rig, "cheeks", ch)
			end
		end
	end
	if STYLE.blocky and not opts.noMouth then
		-- angular face plate (muzzle) under the eyes, in the secondary colour
		blk(rig, head, "FacePlate", Vector3.new(r.X * 1.1, r.Y * 0.55, 0.14), def._s, surface(r, 0, yOff - r.Y * 0.42) * CFrame.new(0, 0, -0.02))
	end
	if not opts.noMouth then
		local m1 = ell(rig, head, "Mouth", Vector3.new(r.X * 0.24, r.Y * 0.06, 0.07), DARK, surface(r, 0, yOff - r.Y * (opts.mouthY or 0.42)) * CFrame.new(0, 0, -0.1))
		table.insert(rig.mouths, m1)
		rig.mouth = rig.mouth or m1
	end
	if table.find(def.extra, "eyepatch") then
		local patch = ell(rig, head, "Patch", Vector3.new(w * 1.25, h * 1.2, 0.2), DARK, surface(r, r.X * 0.36, yOff) * CFrame.new(0, 0, -0.08))
		ell(rig, head, "PatchStrap", Vector3.new(r.X * 0.9, r.Y * 0.08, 0.1), DARK, surface(r, -r.X * 0.2, yOff + r.Y * 0.32) * CFrame.Angles(0, 0, -0.35))
		group(rig, "patch", patch)
	end
end

---------------------------------------------------------------------
-- EARS / HORNS
---------------------------------------------------------------------
local function buildEars(rig, head, r, def, prof)
	local kind = def.ears
	if kind == "none" then return end
	local p, a = def._p, def._a
	local earK = (prof.ear and prof.ear.len) or 1
	if STYLE.blocky and not (prof.ear and prof.ear.inner) then
		prof = setmetatable({ ear = { len = earK, inner = lighten(def._s, 0.05) } }, { __index = prof })
	end
	for _, side in ipairs({ -1, 1 }) do
		local e
		if kind == "round" then
			local sz = r.X * 0.55 * earK
			e = ell(rig, head, "Ear", Vector3.new(sz, sz, r.X * 0.22), p,
				CFrame.new(side * r.X * 0.62, r.Y * 0.72, 0.1) * CFrame.Angles(0, 0, -side * 0.35), nil, nil, CFrame.new(0, -sz * 0.36, 0))
			ell(rig, e.part, "EarInner", Vector3.new(sz * 0.62, sz * 0.62, r.X * 0.1), (prof.ear and prof.ear.inner) or PINK, CFrame.new(0, 0, -r.X * 0.07))
		elseif kind == "pointy" or kind == "cat" then
			local len = (kind == "cat" and r.Y * 0.7 or r.Y * 0.95) * earK
			e = ell(rig, head, "Ear", Vector3.new(r.X * 0.42, len, r.X * 0.2), p,
				CFrame.new(side * r.X * 0.55, r.Y * 0.68, 0.05) * CFrame.Angles(0, 0, -side * 0.38), nil, nil, CFrame.new(0, -len * 0.42, 0))
			ell(rig, e.part, "EarInner", Vector3.new(r.X * 0.24, len * 0.7, r.X * 0.08), (prof.ear and prof.ear.inner) or lighten(PINK, 0.2), CFrame.new(0, -len * 0.05, -r.X * 0.07))
		elseif kind == "bunny" then
			local len = r.Y * 1.5 * earK
			e = ell(rig, head, "Ear", Vector3.new(r.X * 0.36, len, r.X * 0.2), p,
				CFrame.new(side * r.X * 0.36, r.Y * 0.8, 0.1) * CFrame.Angles(-0.15, 0, -side * 0.18), nil, nil, CFrame.new(0, -len * 0.45, 0))
			ell(rig, e.part, "EarInner", Vector3.new(r.X * 0.2, len * 0.75, r.X * 0.08), (prof.ear and prof.ear.inner) or PINK, CFrame.new(0, 0, -r.X * 0.08))
		elseif kind == "floppy" then
			local len = r.Y * 1.1 * earK
			e = ell(rig, head, "Ear", Vector3.new(r.X * 0.42, len, r.X * 0.2), darken(p, 0.12),
				CFrame.new(side * r.X * 0.82, r.Y * 0.25, 0) * CFrame.Angles(0, 0, side * 0.35), nil, nil, CFrame.new(0, len * 0.42, 0))
		elseif kind == "fin" then
			e = ell(rig, head, "Ear", Vector3.new(0.12 * r.X, r.Y * 0.7, r.Z * 0.8), a,
				CFrame.new(side * r.X * 0.92, 0, 0.1) * CFrame.Angles(0, 0, -side * 0.6), nil, 0.1, CFrame.new(0, -r.Y * 0.2, 0))
		end
		if e then table.insert(rig.ears, { e = e, side = side, kind = kind }) end
	end
end

local function buildHorns(rig, head, r, def)
	local kind = def.horns
	if kind == "none" then return end
	local a = def._a
	local hornColor = (kind == "antlers" or kind == "unicorn") and a or lighten(def._s, 0.2)
	local hmat = (def.rarity == "Divine") and Enum.Material.Neon or Enum.Material.SmoothPlastic
	if kind == "unicorn" then
		local hp = pivot(rig, head, "HornBase", CFrame.new(0, r.Y * 0.78, -r.Z * 0.32) * CFrame.Angles(-0.35, 0, 0))
		group(rig, "horn", hp)
		local len, rad = r.Y * 1.15, r.X * 0.17
		for i = 0, 5 do
			local t = i / 6
			local col = (i % 2 == 0) and hornColor or lighten(def._s, 0.15)
			cyl(rig, hp.part, "Horn", Vector3.new(len / 6 * 1.05, rad * 2 * (1 - t * 0.75), rad * 2 * (1 - t * 0.75)), col,
				CFrame.new(0, len * t + len / 12, 0) * CFrame.Angles(0, t * 2, PI / 2), hmat)
		end
		spike(rig, hp.part, "HornTip", len * 0.22, rad * 0.6, hornColor, CFrame.new(0, len, 0), hmat)
		return
	end
	for _, side in ipairs({ -1, 1 }) do
		if kind == "small" then
			spike(rig, head, "Horn", r.Y * 0.5, r.X * 0.24, hornColor, CFrame.new(side * r.X * 0.4, r.Y * 0.72, 0) * CFrame.Angles(0, 0, -side * 0.25), hmat)
		elseif kind == "dragon" then
			local base = CFrame.new(side * r.X * 0.42, r.Y * 0.62, r.Z * 0.2) * CFrame.Angles(1.0, 0, -side * 0.25)
			cyl(rig, head, "HornRoot", Vector3.new(r.Y * 0.4, r.X * 0.3, r.X * 0.3), darken(hornColor, 0.1), base * CFrame.new(0, r.Y * 0.18, 0) * CFrame.Angles(0, 0, PI / 2), hmat)
			spike(rig, head, "Horn", r.Y * 0.8, r.X * 0.28, hornColor, base * CFrame.new(0, r.Y * 0.35, 0) * CFrame.Angles(0.25, 0, 0), hmat)
		elseif kind == "ram" then
			for i = 0, 6 do
				local ang = i / 6 * PI * 1.4
				local pos = Vector3.new(side * (r.X * 0.72 + math.sin(ang) * r.X * 0.3), r.Y * 0.5 + math.cos(ang) * r.Y * 0.32, r.Z * 0.12 + math.sin(ang * 0.5) * 0.22)
				local sz = r.X * (0.34 - i * 0.03)
				ell(rig, head, "Horn", Vector3.new(sz, sz, sz * 1.15), i % 2 == 0 and hornColor or darken(hornColor, 0.12), CFrame.new(pos))
			end
		elseif kind == "antlers" then
			local base = CFrame.new(side * r.X * 0.4, r.Y * 0.75, 0.1) * CFrame.Angles(0, 0, -side * 0.45)
			local ap = pivot(rig, head, "AntlerPivot", base)
			group(rig, "antlers", ap)
			local col = lighten(def._s, 0.1)
			if def._p.R + def._p.G + def._p.B > 2.2 then col = Color3.fromRGB(150, 120, 80) end
			rod(rig, ap.part, "Antler", r.Y * 1.1, 0.18, col, CFrame.identity)
			for i = 1, 3 do
				local bcf = CFrame.new(0, r.Y * 0.3 * i, 0) * CFrame.Angles(0, 0, side * 0.9)
				rod(rig, ap.part, "Antler", r.Y * 0.45, 0.14, col, bcf)
				local tip = ell(rig, ap.part, "AntlerGlow", Vector3.new(0.26, 0.26, 0.26), a, bcf * CFrame.new(0, r.Y * 0.47, 0), Enum.Material.Neon)
				group(rig, "tips", tip)
			end
		end
	end
end

---------------------------------------------------------------------
-- TAIL / WINGS
---------------------------------------------------------------------
local AURORA = { Color3.fromRGB(120, 255, 220), Color3.fromRGB(140, 160, 255), Color3.fromRGB(255, 140, 240), Color3.fromRGB(255, 255, 255) }

local function buildTail(rig, body, anchor, def, s, prof)
	local kind = def.tail
	if kind == "none" then return end
	local p, sc, a = def._p, def._s, def._a
	local tk = prof.tailK or 1
	if kind == "fluffy" then
		local e = ell(rig, body, "Tail", Vector3.new(1, 1, 1) * 0.9 * s * tk, sc, anchor, nil, nil, CFrame.new(0, 0, -0.3 * s * tk))
		ell(rig, e.part, "TailFluff", Vector3.new(0.6, 0.6, 0.6) * s * tk, lighten(sc, 0.3), CFrame.new(0, 0.15 * s, 0.25 * s * tk))
		table.insert(rig.tail, e)
		return
	end
	if kind == "fish" then
		local e = ell(rig, body, "Tail", Vector3.new(0.18 * s, 1.5 * s, 1.1 * s) * tk, a, anchor * CFrame.new(0, 0, 0.35 * s), nil, 0.05, CFrame.new(0, 0, -0.45 * s))
		table.insert(rig.tail, e)
		return
	end
	if kind == "lollipop" then
		local e = cyl(rig, body, "Tail", Vector3.new(1.3, 0.16, 0.16) * s, WHITE, anchor * CFrame.Angles(-0.7, 0, 0) * CFrame.Angles(0, 0, PI / 2), nil, nil, CFrame.new(-0.65 * s, 0, 0))
		-- stem runs along the cylinder's X axis; the candy sits at its tip, facing sideways
		local disc = cyl(rig, e.part, "Candy", Vector3.new(0.22, 1.15, 1.15) * s, a, CFrame.new(0.75 * s, 0, 0) * CFrame.Angles(0, PI / 2, 0))
		-- spiral stripes (a real swirl, not two discs)
		for i = 0, 9 do
			local ang = i * 0.9
			local rr = 0.08 + i * 0.045
			ell(rig, disc.part, "Swirl", Vector3.new(0.24, 0.2, 0.2) * s, i % 2 == 0 and sc or WHITE,
				CFrame.new(0, math.cos(ang) * rr * s, math.sin(ang) * rr * s))
		end
		group(rig, "lolli", disc)
		table.insert(rig.tail, e)
		return
	end
	-- chain tails: long / flame / stinger / leaf / aurora
	local n = (kind == "flame") and 3 or 5
	if prof.tailSegs then n = prof.tailSegs end
	local prev = body
	for i = 1, n do
		local t = i / n
		local rad = (kind == "flame" and 0.75 or 0.5) * s * (1.1 - t * 0.6) * tk
		if kind == "aurora" then rad *= 1.25 end
		local col, mat, tr = p, nil, 0
		if kind == "flame" then col = (i == n) and Color3.fromRGB(255, 240, 120) or a:Lerp(Color3.fromRGB(255, 120, 30), t); mat = (i >= n - 1) and Enum.Material.Neon or nil end
		if kind == "aurora" then col = (i == 1) and p or AURORA[(i - 2) % 4 + 1]; mat = (i > 1) and Enum.Material.Neon or nil; tr = (i > 1) and 0.15 or 0 end
		if kind == "long" and i == n and prof.tuft then col = prof.tuft end
		local c0 = (i == 1) and anchor or CFrame.new(0, rad * 0.5, rad * 1.1) * CFrame.Angles(0.28, 0, 0)
		local e, part = ell(rig, prev, "Tail", Vector3.new(rad * 2, rad * 2, rad * 2.4), col, c0, mat, tr)
		table.insert(rig.tail, e)
		prev = part
	end
	if kind == "flame" then
		local f = Instance.new("Fire"); f.Size = 2.4 * s; f.Heat = 5; f.Color = a; f.SecondaryColor = Color3.fromRGB(255, 230, 120); f.Parent = prev
		rig.tailFire = f
	elseif kind == "stinger" then
		spike(rig, prev, "Stinger", 0.9 * s, 0.4 * s, prof.stinger or DARK, CFrame.new(0, 0, 0.25 * s) * CFrame.Angles(PI / 2, 0, 0))
	elseif kind == "leaf" then
		diamond(rig, prev, "Leaf", 1.6 * s, 0.9 * s, 0.1 * s, Color3.fromRGB(90, 210, 90), CFrame.new(0, 0, 0.9 * s) * CFrame.Angles(PI / 2, 0, 0))
	end
end

local function buildWings(rig, body, r, anchorY, def, s, prof)
	local kind = def.wings
	if kind == "none" then return end
	local p, sc, a = def._p, def._s, def._a
	local wk = prof.wingK or 1
	local wz = prof.wingZ or 0.15
	for _, side in ipairs({ -1, 1 }) do
		local pv = CFrame.new(side * r.X * 0.75, anchorY, r.Z * wz)
		local e
		if kind == "feather" or kind == "angel" then
			local big = (kind == "angel" and 1.5 or 1) * wk
			local col = prof.wingCol or (kind == "angel" and WHITE or sc)
			local tip = prof.wingTip or (kind == "angel" and GOLD or a)
			e = ell(rig, body, "Wing", Vector3.new(1.9 * big * s, 1.1 * big * s, 0.2 * s), col, pv * CFrame.Angles(0, side * 0.25, side * 0.25), nil, prof.wingTr,
				CFrame.new(-side * 0.8 * big * s, -0.1 * s, 0))
			-- layered flight feathers as faceted blades
			for i = 1, 4 do
				local fcol = i == 4 and tip or lighten(col, 0.06 * i)
				diamond(rig, e.part, "Feather", 1.25 * big * s * (1 - i * 0.12), 0.42 * big * s, 0.12 * s, fcol,
					CFrame.new(side * (0.35 + 0.22 * i) * big * s, -0.32 * i * big * s, 0.03 * i) * CFrame.Angles(0, 0, side * (0.5 + 0.12 * i)),
					(i == 4 and kind == "angel") and Enum.Material.Neon or nil, prof.wingTr)
			end
		elseif kind == "bat" then
			local mem = prof.membrane or darken(a, 0.1)
			e = ell(rig, body, "Wing", Vector3.new(2.2 * s * wk, 1.3 * s * wk, 0.1 * s), mem, pv * CFrame.Angles(0, side * 0.2, side * 0.3), nil, prof.wingTr or 0.05,
				CFrame.new(-side * 1.0 * s * wk, -0.2 * s, 0))
			for i = -1, 1 do
				cyl(rig, e.part, "Finger", Vector3.new(1.45 * wk, 0.12, 0.12) * s, darken(p, 0.1), CFrame.new(side * 0.15 * s, 0.05, 0) * CFrame.Angles(0, 0, side * (1.2 + i * 0.4) - PI / 2))
			end
			-- scalloped trailing edge
			for i = 1, 3 do
				ell(rig, e.part, "Scallop", Vector3.new(0.7, 0.5, 0.08) * s * wk, mem, CFrame.new(side * (0.1 + i * 0.5) * s * wk, -0.55 * s * wk, 0), nil, prof.wingTr or 0.05)
			end
		elseif kind == "bug" then
			e = ell(rig, body, "Wing", Vector3.new(1.8 * s * wk, 1.3 * s * wk, 0.06 * s), prof.wingCol or lighten(a, 0.3), pv * CFrame.Angles(0, side * 0.3, side * 0.5), Enum.Material.Glass, prof.wingTr or 0.35,
				CFrame.new(-side * 0.85 * s * wk, -0.3 * s, 0))
			cyl(rig, e.part, "Vein", Vector3.new(1.5 * wk, 0.05, 0.05) * s, darken(p, 0.3), CFrame.new(side * 0.1 * s, 0, 0) * CFrame.Angles(0, 0, side * 0.2))
			ell(rig, e.part, "WingSpot", Vector3.new(0.5, 0.5, 0.07) * s * wk, sc, CFrame.new(side * 0.25 * s, 0.1 * s, 0), nil, 0.1)
			local low = ell(rig, e.part, "WingLow", Vector3.new(1.2 * s, 0.9 * s, 0.06 * s) * wk, prof.wingCol2 or lighten(a, 0.5), CFrame.new(side * 0.1 * s, -0.85 * s * wk, 0.05), Enum.Material.Glass, prof.wingTr or 0.4)
			table.insert(rig.wings, { e = low, side = side, tier = 2 })
		end
		if e then table.insert(rig.wings, { e = e, side = side, tier = 1 }) end
	end
end

---------------------------------------------------------------------
-- EXTRAS (shared accessories)
---------------------------------------------------------------------
local function ringOf(rig, parent, center, radius, count, size, color, tilt)
	for i = 1, count do
		local ang = i / count * PI * 2
		ell(rig, parent, "Ring", Vector3.new(size, size, size), color,
			center * CFrame.Angles(tilt or 0, 0, 0) * CFrame.new(math.cos(ang) * radius, 0, math.sin(ang) * radius), Enum.Material.Neon)
	end
end
H.ringOf = ringOf

-- a smooth band (torus-ish) made from short cylinders; returns the pivot entry
local function band(rig, parent, name, cf, radius, thick, color, segments, mat, gap)
	local pv = pivot(rig, parent, name, cf)
	segments = segments or 16
	for i = 1, segments do
		if not (gap and i % gap == 0) then
			local ang = (i - 0.5) / segments * PI * 2
			local len = 2 * PI * radius / segments * 1.08
			cyl(rig, pv.part, name .. "Seg", Vector3.new(len, thick, thick), color,
				CFrame.new(math.cos(ang) * radius, 0, math.sin(ang) * radius) * CFrame.Angles(0, -ang + PI / 2, 0), mat or Enum.Material.Neon)
		end
	end
	return pv
end
H.band = band

local function buildExtras(rig, head, hr, body, br, def, s, prof)
	local p, sc, a = def._p, def._s, def._a
	local skip = prof.skipExtra or {}
	for _, x in ipairs(def.extra) do
		if skip[x] then continue end
		if x == "leafsprout" then
			local stem = rod(rig, head, "Sprout", 0.5 * s, 0.12 * s, Color3.fromRGB(70, 160, 60), CFrame.new(0, hr.Y * 0.95, 0))
			for _, side in ipairs({ -1, 1 }) do
				diamond(rig, stem.part, "Leaf", 0.62 * s, 0.34 * s, 0.07 * s, Color3.fromRGB(110, 220, 90),
					CFrame.new(side * 0.26 * s, 0.48 * s, 0) * CFrame.Angles(PI / 2, 0, 0) * CFrame.Angles(0, 0, side * 1.2))
			end
			table.insert(rig.bobbers, stem)
		elseif x == "acorn" then
			local capPv = pivot(rig, head, "HatPivot", CFrame.new(0, hr.Y * 0.72, 0.05 * s))
			group(rig, "hat", capPv)
			ell(rig, capPv.part, "AcornCap", Vector3.new(hr.X * 1.35, hr.Y * 0.62, hr.Z * 1.35), Color3.fromRGB(120, 75, 40), CFrame.new(0, hr.Y * 0.08, 0), Enum.Material.Fabric)
			for i = 0, 2 do -- scale rings on the cap
				cyl(rig, capPv.part, "CapRing", Vector3.new(0.06 * s, hr.X * (1.3 - i * 0.3), hr.X * (1.3 - i * 0.3)), Color3.fromRGB(95, 58, 30),
					CFrame.new(0, hr.Y * (0.02 + i * 0.14), 0) * CFrame.Angles(0, 0, PI / 2))
			end
			rod(rig, capPv.part, "AcornStem", 0.42 * s, 0.15 * s, Color3.fromRGB(90, 55, 30), CFrame.new(0, hr.Y * 0.36, 0) * CFrame.Angles(0, 0, -0.3))
		elseif x == "flower" then
			local center = CFrame.new(hr.X * 0.55, hr.Y * 0.65, -hr.Z * 0.2) * CFrame.Angles(0, 0, -0.5)
			local fp = pivot(rig, head, "Flower", center)
			group(rig, "flowers", fp)
			for i = 1, 5 do
				local ang = i / 5 * PI * 2
				diamond(rig, fp.part, "Petal", 0.42 * s, 0.26 * s, 0.06 * s, a,
					CFrame.new(math.cos(ang) * 0.2 * s, 0.03 * s, math.sin(ang) * 0.2 * s) * CFrame.Angles(0, -ang, 0) * CFrame.Angles(PI / 2 - 0.25, 0, PI / 2))
			end
			ell(rig, fp.part, "FlowerCore", Vector3.new(0.22, 0.16, 0.22) * s, Color3.fromRGB(255, 230, 90), CFrame.new(0, 0.06 * s, 0))
		elseif x == "crown" then
			local cp = pivot(rig, head, "CrownPivot", CFrame.new(0, hr.Y * (prof.crownY or 0.95), prof.crownZ or 0))
			group(rig, "crown", cp)
			cyl(rig, cp.part, "Crown", Vector3.new(0.3 * s, hr.X * 0.9, hr.X * 0.9), GOLD, CFrame.Angles(0, 0, PI / 2), Enum.Material.Metal)
			for i = 1, 5 do
				local ang = i / 5 * PI * 2
				local cf = CFrame.new(math.cos(ang) * hr.X * 0.38, 0.12 * s, math.sin(ang) * hr.X * 0.38)
				spike(rig, cp.part, "CrownSpike", 0.45 * s, 0.22 * s, GOLD, cf, Enum.Material.Metal)
				local gem = ell(rig, cp.part, "Gem", Vector3.new(0.14, 0.14, 0.14) * s, a, cf * CFrame.new(0, 0.5 * s, 0), Enum.Material.Neon)
				group(rig, "crownGems", gem)
			end
		elseif x == "halo" then
			local e = band(rig, head, "Halo", CFrame.new(0, hr.Y * (prof.haloY or 1.45), prof.haloZ or 0) * CFrame.Angles(prof.haloTilt or 0, 0, 0),
				hr.X * 0.55, 0.14 * s, Color3.fromRGB(255, 236, 150), 14, Enum.Material.Neon, prof.haloGap)
			table.insert(rig.halos, e)
		elseif x == "helmet" then
			local hk = prof.helmetK or 2.5
			ell(rig, head, "Helmet", hr * hk, Color3.fromRGB(200, 240, 255), CFrame.new(0, (prof.helmetY or 0.1) * s, 0), Enum.Material.Glass, 0.72)
			cyl(rig, head, "Collar", Vector3.new(0.3 * s, hr.X * hk * 0.82, hr.X * hk * 0.82), Color3.fromRGB(60, 70, 90),
				CFrame.new(0, -hr.Y * hk * 0.36 + (prof.helmetY or 0.1) * s, 0) * CFrame.Angles(0, 0, PI / 2), Enum.Material.Metal)
		elseif x == "crystal" then
			for i = -1, 1 do
				local c = CFrame.new(i * br.X * 0.35, br.Y * 0.8, br.Z * 0.15) * CFrame.Angles(0.2, 0, -i * 0.35)
				crystal(rig, body, "Crystal", (1.1 - math.abs(i) * 0.3) * s, 0.3 * s, a, c, Enum.Material.Glass, 0.05)
			end
		elseif x == "mane" then
			for i = 0, 9 do
				local ang = i / 10 * PI * 2
				local m = ell(rig, head, "Mane", Vector3.new(0.75, 0.75, 0.6) * s, i % 2 == 0 and sc or a,
					CFrame.new(math.cos(ang) * hr.X * 0.95, math.sin(ang) * hr.Y * 0.95 + 0.05, hr.Z * 0.25))
				group(rig, "mane", m)
			end
		elseif x == "spikes" then
			for i = 0, 3 do
				spike(rig, body, "Spike", 0.75 * s, 0.4 * s, prof.spikeCol or a,
					CFrame.new(0, br.Y * 0.78 - i * 0.08 * s, -br.Z * 0.45 + i * br.Z * 0.36) * CFrame.Angles(0.35, 0, 0))
			end
		elseif x == "antenna" then
			for _, side in ipairs({ -1, 1 }) do
				local st = rod(rig, head, "Antenna", 0.9 * s, 0.09 * s, darken(p, 0.4),
					CFrame.new(side * hr.X * 0.3, hr.Y * 0.8, 0) * CFrame.Angles(0, 0, -side * 0.35))
				local tip = ell(rig, st.part, "AntennaBall", Vector3.new(0.28, 0.28, 0.28) * s, a, CFrame.new(0, 0.92 * s, 0), Enum.Material.Neon)
				group(rig, "antennaTips", tip)
				table.insert(rig.ears, { e = st, side = side, kind = "antenna" })
			end
		elseif x == "shell" then
			ell(rig, body, "Shell", br * 2.1, a, CFrame.new(0, br.Y * 0.25, br.Z * 0.1), Enum.Material.Glass, 0.15)
		elseif x == "candy" then
			local cols = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 230, 80), WHITE }
			for i = 1, 8 do
				local ang, h = i * 2.39, (i % 4) * 0.2
				blk(rig, body, "Sprinkle", Vector3.new(0.24, 0.08, 0.08) * s, cols[i % 4 + 1],
					CFrame.new(math.cos(ang) * br.X * 0.78, br.Y * (0.35 + h), math.sin(ang) * br.Z * 0.78) * CFrame.Angles(0, ang, 0.6))
			end
		elseif x == "rings" then
			local rp = band(rig, body, "OrbitRing", CFrame.Angles(prof.ringTilt or 0.35, 0, 0.15), br.X * (prof.ringR or 1.45), 0.1 * s, a, 22)
			group(rig, "rings", rp)
		elseif x == "bow" then
			local c = prof.bowCF or (CFrame.new(hr.X * 0.5, hr.Y * 0.75, 0) * CFrame.Angles(0, 0, -0.4))
			local bp = pivot(rig, head, "BowPivot", c)
			group(rig, "bow", bp)
			tri(rig, bp.part, "Bow", 0.22 * s, 0.55 * s, 0.5 * s, a, CFrame.new(-0.28 * s, 0, 0) * CFrame.Angles(0, PI / 2, PI / 2))
			tri(rig, bp.part, "Bow", 0.22 * s, 0.55 * s, 0.5 * s, a, CFrame.new(0.28 * s, 0, 0) * CFrame.Angles(0, PI / 2, -PI / 2))
			ell(rig, bp.part, "BowKnot", Vector3.new(0.25, 0.25, 0.25) * s, lighten(a, 0.3), CFrame.identity)
		elseif x == "snowcap" then
			ell(rig, head, "Snow", Vector3.new(hr.X * 1.2, hr.Y * 0.5, hr.Z * 1.2), WHITE, CFrame.new(0, hr.Y * 0.8, 0))
		elseif x == "scarf" then
			for i = 0, 11 do
				local ang = i / 12 * PI * 2
				ell(rig, head, "Scarf", Vector3.new(0.5, 0.4, 0.5) * s, i % 3 == 0 and WHITE or a,
					CFrame.new(math.cos(ang) * hr.X * 0.88, -hr.Y * 0.65, math.sin(ang) * hr.Z * 0.88))
			end
			for _, side in ipairs({ -1, 1 }) do
				local se = ell(rig, head, "ScarfEnd", Vector3.new(0.42, 0.9, 0.18) * s, a,
					CFrame.new(side * hr.X * 0.35, -hr.Y * 0.8, -hr.Z * 0.78) * CFrame.Angles(0, 0, side * 0.2), nil, nil, CFrame.new(0, 0.4 * s, 0))
				ell(rig, se.part, "ScarfStripe", Vector3.new(0.44, 0.12, 0.2) * s, WHITE, CFrame.new(0, -0.25 * s, 0))
				group(rig, "scarfEnds", se)
			end
		end
	end
end

---------------------------------------------------------------------
-- THEMED FX: honest emitters + procedural motifs (no fake leaf/heart textures)
---------------------------------------------------------------------
local EMIT = {
	sparkle = { tex = SPARKLE, rate = 4, speed = 1, size = 0.45 },
	embers  = { tex = SPARKLE, col = Color3.fromRGB(255, 140, 40), rate = 5, speed = 2.5, size = 0.3, up = true },
	fire    = { tex = FIRE, col = Color3.fromRGB(255, 130, 40), rate = 8, speed = 2, size = 1.0, up = true },
	smoke   = { tex = SMOKE, col = Color3.fromRGB(80, 30, 120), rate = 4, speed = 0.6, size = 1.6, up = true, low = true },
	rainbow = { tex = SPARKLE, col = "rainbow", rate = 6, speed = 1.2, size = 0.45 },
	holy    = { tex = SPARKLE, col = Color3.fromRGB(255, 240, 170), rate = 6, speed = 1.2, size = 0.5, up = true },
}
local MOTIF = { leaves = "leaf", hearts = "heart", snow = "snowflake", stars = "star", glitch = "cube" }

local function motifShape(rig, parent, kind, s, col)
	if kind == "leaf" then
		diamond(rig, parent, "MotifLeaf", 0.5 * s, 0.26 * s, 0.05 * s, col, CFrame.identity)
	elseif kind == "heart" then
		ell(rig, parent, "MotifHeart", Vector3.new(0.22, 0.22, 0.1) * s, col, CFrame.new(-0.09 * s, 0.06 * s, 0))
		ell(rig, parent, "MotifHeart", Vector3.new(0.22, 0.22, 0.1) * s, col, CFrame.new(0.09 * s, 0.06 * s, 0))
		tri(rig, parent, "MotifHeart", 0.1 * s, 0.24 * s, 0.34 * s, col, CFrame.new(0, -0.08 * s, 0) * CFrame.Angles(0, PI / 2, PI))
	elseif kind == "snowflake" then
		for i = 0, 2 do
			blk(rig, parent, "MotifSnow", Vector3.new(0.05, 0.5, 0.05) * s, col, CFrame.Angles(0, 0, i * PI / 3), Enum.Material.Neon)
		end
	elseif kind == "star" then
		diamond(rig, parent, "MotifStar", 0.42 * s, 0.14 * s, 0.05 * s, col, CFrame.identity, Enum.Material.Neon)
		diamond(rig, parent, "MotifStar", 0.42 * s, 0.14 * s, 0.05 * s, col, CFrame.Angles(0, 0, PI / 2), Enum.Material.Neon)
	elseif kind == "cube" then
		blk(rig, parent, "MotifCube", Vector3.new(0.18, 0.18, 0.18) * s, col, CFrame.identity, Enum.Material.Neon)
	end
end
H.motifShape = motifShape

local function addEffects(rig, def, rr, s, prof)
	local body = rig.body
	local order = Config.Rarities[def.rarity].order
	local fxKind = prof.fx or def.fx
	local em = fxKind and EMIT[fxKind]
	if em and order >= 3 then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "RarityFx"
		pe.Texture = em.tex
		if em.col == "rainbow" then
			pe.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 80)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 100, 255)) })
		else
			pe.Color = ColorSequence.new(em.col or def._a)
		end
		pe.LightEmission = em.tex == SMOKE and 0 or 1
		pe.Rate = em.rate * (order >= 6 and 1.4 or 1)
		pe.Lifetime = NumberRange.new(0.8, 1.6)
		pe.Speed = NumberRange.new(em.speed * 0.5, em.speed)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Acceleration = em.up and Vector3.new(0, 2, 0) or Vector3.new(0, -0.5, 0)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, em.size * s), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new(em.tex == SMOKE and 0.6 or 0.1, 1)
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-60, 60)
		pe.Shape = Enum.ParticleEmitterShape.Sphere
		pe.Parent = body
		table.insert(rig.emitters, pe)
	end
	local motif = fxKind and MOTIF[fxKind]
	if motif and order >= 3 then
		-- a few real shapes orbiting slowly (animated by CreatureAnimator "motifs" group)
		local col = fxKind == "leaves" and Color3.fromRGB(120, 220, 100) or (fxKind == "hearts" and Color3.fromRGB(255, 120, 170))
			or (fxKind == "snow" and Color3.fromRGB(225, 245, 255)) or (fxKind == "stars" and Color3.fromRGB(255, 236, 150)) or def._a
		local orbit = pivot(rig, body, "MotifOrbit", CFrame.identity)
		group(rig, "motifOrbit", orbit)
		local n = order >= 6 and 4 or 3
		for i = 1, n do
			local ang = i / n * PI * 2
			local m = pivot(rig, orbit.part, "Motif", CFrame.new(math.cos(ang) * rr.X * 1.55, (i % 2) * 0.5 * s, math.sin(ang) * rr.X * 1.55))
			motifShape(rig, m.part, motif, s, fxKind == "glitch" and (i % 2 == 0 and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(255, 0, 170)) or col)
			group(rig, "motifs", m)
		end
	end
	if order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = def.rarity == "Secret" and Color3.fromRGB(0, 255, 200) or lighten(def._a, 0.3)
		light.Range = 8 + order
		light.Brightness = order >= 7 and 1.6 or 1
		light.Shadows = false
		light:SetAttribute("Base", light.Brightness)
		light.Parent = body
		rig.light = light
	end
	if order >= 7 then
		-- a slow, small orbit of motes for Secret / Divine (no full-body force-field shell)
		local orbit, om = newPiece(rig, "Orbit", Vector3.new(0.05, 0.05, 0.05), WHITE, Enum.Material.Neon, nil, 1)
		local oe = attach(rig, body, orbit, om, CFrame.identity)
		ringOf(rig, orbit, CFrame.identity, rr.X * 1.7, 5, 0.22 * s, def.rarity == "Divine" and GOLD or Color3.fromRGB(0, 255, 200))
		table.insert(rig.halos, oe)
	end
end

---------------------------------------------------------------------
-- BODY PLANS
---------------------------------------------------------------------
local Plans = {}

local function legs(rig, parent, pts, size, col, s, foot)
	for _, pt in ipairs(pts) do
		local e = ell(rig, parent, "Leg", size, col, CFrame.new(pt), nil, nil, CFrame.new(0, size.Y * 0.35, 0))
		if foot then foot(e, size) end
		table.insert(rig.feet, e)
	end
end

function Plans.round(rig, def, s, prof)
	local p, sc = def._p, def._s
	local mat = matOf(def.mat)
	local tr = (mat == Enum.Material.Glass) and 0.25 or 0
	local q = prof.q or {}
	local V = function(x, y, z) return Vector3.new(x, y, z) * s end
	local br = V(1.2, 1.1, 1.15) * (q.body or Vector3.one)
	local e, body = ell(rig, rig.root, "Body", br * 2, p, CFrame.new(0, br.Y + 0.25 * s, 0), mat, tr)
	rig.bodyEntry = e
	if not q.noBelly then ell(rig, body, "Belly", V(1.5, 1.4, 0.6) * (q.belly or 1), lighten(sc, 0.1), CFrame.new(0, -0.25 * s, -br.Z * 0.72)) end
	local fk = q.feet or 1
	if fk > 0 then
		legs(rig, body, { Vector3.new(-0.5 * s, -br.Y * 0.91, -0.45 * s), Vector3.new(0.5 * s, -br.Y * 0.91, -0.45 * s) }, V(0.7, 0.4, 0.85) * fk, q.footCol or darken(p, 0.1), s,
			q.pads and function(le, size) ell(rig, le.part, "Pad", Vector3.new(size.X * 0.6, size.Y * 0.3, size.Z * 0.5), q.pads, CFrame.new(0, -size.Y * 0.35, -size.Z * 0.15)) end)
		rig.legKind = "biped"
	end
	local ak = q.arms or 1
	if ak > 0 then
		for _, side in ipairs({ -1, 1 }) do
			local arm = ell(rig, body, "Arm", V(0.42, 0.6, 0.42) * ak, q.armCol or darken(p, 0.05), CFrame.new(side * br.X * 0.92, -0.15 * s, -0.25 * s) * CFrame.Angles(0, 0, side * 0.5), nil, nil, CFrame.new(0, 0.2 * s * ak, 0))
			table.insert(rig.arms, { e = arm, side = side })
		end
	end
	return body, body, br, br, (q.faceY or 0.12) * s, CFrame.new(0, -0.3 * s, br.Z * 0.95), 0.25 * s
end

function Plans.quad(rig, def, s, prof)
	local p, sc = def._p, def._s
	local mat = matOf(def.mat)
	local tr = (mat == Enum.Material.Glass) and 0.2 or 0
	local q = prof.q or {}
	local V = function(x, y, z) return Vector3.new(x, y, z) * s end
	local br = V(1.0, 0.85, 1.3) * (q.body or Vector3.one)
	local legLen = 0.95 * s * (q.leg or 1)
	local legW = 0.55 * s * (q.legW or 1)
	local bodyY = br.Y * 0.78 + legLen * 0.85 + (q.lift or 0) * s
	local e, body = ell(rig, rig.root, "Body", br * 2, p, CFrame.new(0, bodyY, 0), mat, tr)
	rig.bodyEntry = e
	if q.chest then ell(rig, body, "Chest", V(1.4, 1.3, 1.0) * q.chest, p, CFrame.new(0, 0.15 * s, -br.Z * 0.55), mat, tr) end
	ell(rig, body, "Belly", Vector3.new(br.X * 1.5, br.Y * 1.15, br.Z * 1.55), q.bellyCol or sc, CFrame.new(0, -br.Y * 0.4, -0.1 * s), mat, tr)
	local lx, lz = br.X * 0.55, br.Z * 0.62
	local legCol = q.legCol or darken(p, 0.08)
	local foot = function(le, size, front)
		local talons = q.talons
		if q.talonsFront and not front then talons = nil end
		if q.hooves and not talons then
			cyl(rig, le.part, "Hoof", Vector3.new(size.Y * 0.16, size.X * 1.05, size.X * 1.05), q.hooves, CFrame.new(0, -size.Y * 0.47, 0) * CFrame.Angles(0, 0, PI / 2))
		else
			local pk = q.paws or 1
			ell(rig, le.part, "Paw", Vector3.new(size.X * 1.15, size.X * 0.55, size.X * 1.35) * pk, q.pawCol or legCol, CFrame.new(0, -size.Y * 0.44, -size.X * 0.2))
			if q.pads then ell(rig, le.part, "PawPad", Vector3.new(size.X * 0.7, size.X * 0.2, size.X * 0.6) * pk, q.pads, CFrame.new(0, -size.Y * 0.5, -size.X * 0.25)) end
			if talons then
				for t = -1, 1 do spike(rig, le.part, "Talon", size.X * 0.5, size.X * 0.22, talons, CFrame.new(t * size.X * 0.3, -size.Y * 0.47, -size.X * 0.6) * CFrame.Angles(-PI / 2 + 0.4, 0, 0)) end
			end
		end
	end
	local legSize = Vector3.new(legW, legLen, legW)
	local frontSize = q.frontLeg and Vector3.new(legW * q.frontLeg, legLen, legW * q.frontLeg) or legSize
	local pts = { Vector3.new(-lx, -br.Y * 0.78, -lz), Vector3.new(lx, -br.Y * 0.78, -lz), Vector3.new(-lx, -br.Y * 0.78, lz), Vector3.new(lx, -br.Y * 0.78, lz) }
	for i, pt in ipairs(pts) do
		local sz = i <= 2 and frontSize or legSize
		local col = (q.frontCol and i <= 2) and q.frontCol or legCol
		local le = ell(rig, body, "Leg", sz, col, CFrame.new(pt), nil, nil, CFrame.new(0, sz.Y * 0.35, 0))
		foot(le, sz, i <= 2)
		table.insert(rig.feet, le)
	end
	rig.legKind = "quad"
	-- neck + head
	local hk = q.head or 1
	local hr = V(0.98, 0.92, 0.92) * hk * (q.headShape or Vector3.one)
	local neck = q.neck or 0
	local headParent = body
	local headCF = CFrame.new(0, 0.85 * s + neck * 0.6 * s, -br.Z * 0.96 - neck * 0.35 * s)
	if neck > 0 then
		local ne = ell(rig, body, "Neck", V(0.75, 1.1 + neck, 0.75) * (q.neckW or 1), p, CFrame.new(0, br.Y * 0.55, -br.Z * 0.72) * CFrame.Angles(-0.55, 0, 0), mat, tr, CFrame.new(0, -(1.1 + neck) * 0.4 * s, 0))
		rig.neckEntry = ne
		headParent = ne.part
		headCF = CFrame.new(0, (1.1 + neck) * 0.42 * s, -0.05 * s) * CFrame.Angles(0.55, 0, 0)
	end
	local he, head = ell(rig, headParent, "Head", hr * 2, q.headCol or p, headCF, mat, tr, CFrame.new(0, -0.3 * s, 0.3 * s))
	rig.headEntry = he
	local mz = q.muzzle or "snout"
	if mz == "snout" or mz == "broad" then
		local w = mz == "broad" and 1.2 or 1
		ell(rig, head, "Snout", V(0.9 * w, 0.55, 0.5) * hk, lighten(sc, 0.05), CFrame.new(0, -0.38 * s * hk, -hr.Z * 0.82))
		ell(rig, head, "Nose", V(0.28, 0.2, 0.18) * hk, DARK, CFrame.new(0, -0.24 * s * hk, -hr.Z * 1.05))
	elseif mz == "narrow" or mz == "long" then
		local len = mz == "long" and 1.25 or 0.95
		ell(rig, head, "Muzzle", V(0.62, 0.5, len) * hk, q.muzzleCol or lighten(sc, 0.05), CFrame.new(0, -0.32 * s * hk, -hr.Z * (0.75 + len * 0.3)))
		ell(rig, head, "Nose", V(0.24, 0.18, 0.16) * hk, DARK, CFrame.new(0, -0.2 * s * hk, -hr.Z * (0.75 + len * 0.75)))
	elseif mz == "beak" then
		ell(rig, head, "Beak", V(0.55, 0.42, 0.75) * hk, q.beakCol or GOLD, CFrame.new(0, -0.22 * s * hk, -hr.Z * 1.05))
		spike(rig, head, "BeakHook", 0.35 * s * hk, 0.3 * s * hk, q.beakCol or GOLD, CFrame.new(0, -0.32 * s * hk, -hr.Z * 1.35) * CFrame.Angles(PI, 0, 0))
	elseif mz == "cat" then
		for _, side in ipairs({ -1, 1 }) do
			ell(rig, head, "Whisker", V(0.42, 0.32, 0.3) * hk, lighten(sc, 0.05), CFrame.new(side * 0.17 * s * hk, -0.36 * s * hk, -hr.Z * 0.82))
		end
		tri(rig, head, "Nose", 0.12 * s, 0.14 * s * hk, 0.2 * s * hk, q.noseCol or PINK, CFrame.new(0, -0.22 * s * hk, -hr.Z * 0.98) * CFrame.Angles(0, PI / 2, PI))
	end
	local faceY = (q.faceY or 0.12) * s
	return body, head, br, hr, faceY, CFrame.new(0, (q.tailY or 0.3) * s, br.Z * 0.95), 0.55 * s
end

function Plans.bird(rig, def, s, prof)
	local p, sc, a = def._p, def._s, def._a
	local mat = matOf(def.mat)
	local tr = (mat == Enum.Material.Glass) and 0.25 or 0
	local q = prof.q or {}
	local V = function(x, y, z) return Vector3.new(x, y, z) * s end
	local br = V(1.1, 1.25, 1.05) * (q.body or Vector3.one)
	local e, body = ell(rig, rig.root, "Body", br * 2, p, CFrame.new(0, br.Y + 0.35 * s, 0), mat, tr)
	rig.bodyEntry = e
	ell(rig, body, "Belly", V(1.5, 1.6, 0.6), sc, CFrame.new(0, -0.35 * s, -br.Z * 0.7))
	if q.down then -- downy chest lobes
		for i = -1, 1 do ell(rig, body, "Down", V(0.6, 0.55, 0.4), lighten(sc, 0.1), CFrame.new(i * 0.35 * s, -0.55 * s - math.abs(i) * 0.1 * s, -br.Z * 0.86)) end
	end
	local beak = ell(rig, body, "Beak", V(0.55, 0.32, 0.6), q.beakCol or Color3.fromRGB(255, 170, 50), CFrame.new(0, 0.05 * s, -br.Z * 1.0))
	group(rig, "beak", beak)
	legs(rig, body, { V(-0.45, -1.25, -0.2), V(0.45, -1.25, -0.2) }, V(0.5, 0.35, 0.7), q.footCol or Color3.fromRGB(255, 160, 50), s)
	rig.legKind = "biped"
	if not q.noTuft then ell(rig, body, "Tuft", V(0.4, 0.7, 0.3), q.tuftCol or a, CFrame.new(0, br.Y * 0.98, -0.2 * s) * CFrame.Angles(-0.3, 0, 0), q.tuftMat) end
	return body, body, br, br, 0.4 * s, CFrame.new(0, -0.35 * s, br.Z * 0.95), 0.1 * s
end

-- birds with a real neck/head pivot (owls, phoenixes, empress)
function Plans.avian(rig, def, s, prof)
	local p, sc, a = def._p, def._s, def._a
	local mat = matOf(def.mat)
	local tr = (mat == Enum.Material.Glass) and 0.15 or 0
	local q = prof.q or {}
	local V = function(x, y, z) return Vector3.new(x, y, z) * s end
	local br = V(0.95, 1.05, 1.2) * (q.body or Vector3.one)
	local legLen = 0.6 * s * (q.leg or 1)
	local e, body = ell(rig, rig.root, "Body", br * 2, p, CFrame.new(0, br.Y * 0.85 + legLen * 0.8, 0) * CFrame.Angles(q.bodyPitch or 0.25, 0, 0), mat, tr)
	rig.bodyEntry = e
	ell(rig, body, "Breast", Vector3.new(br.X * 1.5, br.Y * 1.4, br.Z * 0.9), q.breastCol or sc, CFrame.new(0, -br.Y * 0.15, -br.Z * 0.45), mat, tr)
	legs(rig, body, { Vector3.new(-br.X * 0.4, -br.Y * 0.85, 0), Vector3.new(br.X * 0.4, -br.Y * 0.85, 0) }, Vector3.new(0.3 * s, legLen, 0.3 * s), q.footCol or Color3.fromRGB(255, 170, 60), s,
		function(le, size)
			for t = -1, 1 do spike(rig, le.part, "Talon", 0.35 * s, 0.14 * s, q.talonCol or DARK, CFrame.new(t * 0.12 * s, -size.Y * 0.45, -0.1 * s) * CFrame.Angles(-PI / 2 + 0.3, t * 0.4, 0)) end
		end)
	rig.legKind = "biped"
	local neck = q.neck or 0.3
	local hr = V(0.78, 0.74, 0.74) * (q.head or 1)
	local ne = ell(rig, body, "Neck", V(0.6, 0.6 + neck * 1.4, 0.6), p, CFrame.new(0, br.Y * 0.7, -br.Z * 0.45) * CFrame.Angles(-0.25, 0, 0), mat, tr, CFrame.new(0, -(0.6 + neck * 1.4) * 0.35 * s, 0))
	rig.neckEntry = ne
	local he, head = ell(rig, ne.part, "Head", hr * 2, q.headCol or p, CFrame.new(0, (0.6 + neck * 1.4) * 0.45 * s + hr.Y * 0.5, 0) * CFrame.Angles(-(q.bodyPitch or 0.25) + 0.25, 0, 0), mat, tr, CFrame.new(0, -hr.Y * 0.5, 0))
	rig.headEntry = he
	-- beak
	local bk = q.beak or "short"
	local beakCol = q.beakCol or Color3.fromRGB(255, 180, 60)
	local beakPv = pivot(rig, head, "BeakPivot", CFrame.new(0, -hr.Y * 0.18, -hr.Z * 0.85))
	group(rig, "beak", beakPv)
	if bk == "hook" then
		ell(rig, beakPv.part, "Beak", V(0.36, 0.32, 0.55) * (q.head or 1), beakCol, CFrame.new(0, 0, -0.18 * s))
		spike(rig, beakPv.part, "BeakHook", 0.3 * s, 0.24 * s, beakCol, CFrame.new(0, -0.05 * s, -0.42 * s) * CFrame.Angles(PI - 0.5, 0, 0))
	else
		spike(rig, beakPv.part, "Beak", (bk == "long" and 0.65 or 0.42) * s, 0.36 * s, beakCol, CFrame.new(0, 0, -0.05 * s) * CFrame.Angles(-PI / 2, 0, 0))
	end
	if q.disc then -- owl facial disc
		for _, side in ipairs({ -1, 1 }) do
			ell(rig, head, "FacialDisc", Vector3.new(hr.X * 0.95, hr.Y * 1.15, 0.12 * s), q.disc, surface(hr, side * hr.X * 0.38, 0.05 * s) * CFrame.new(0, 0, 0.04))
		end
	end
	if q.crest then
		for i = 0, 2 do
			diamond(rig, head, "Crest", (0.9 - i * 0.15) * s * q.crest, 0.28 * s, 0.07 * s, i == 1 and a or sc,
				CFrame.new(0, hr.Y * 0.85, hr.Z * (0.1 + i * 0.25)) * CFrame.Angles(-0.4 - i * 0.35, 0, 0) * CFrame.new(0, 0.35 * s, 0), q.crestMat)
		end
	end
	return body, head, br, hr, (q.faceY or 0.1) * s, CFrame.new(0, -br.Y * 0.25, br.Z * 0.9), 0.35 * s
end

function Plans.slime(rig, def, s, prof)
	local p, a = def._p, def._a
	local mat = matOf(def.mat)
	local tr = (mat == Enum.Material.Glass) and 0.3 or 0
	local q = prof.q or {}
	local V = function(x, y, z) return Vector3.new(x, y, z) * s end
	local br = V(1.3, 1.0, 1.3) * (q.body or Vector3.one)
	local e, body = ell(rig, rig.root, "Body", br * 2, p, CFrame.new(0, br.Y * 0.8, 0), mat, tr)
	rig.bodyEntry = e
	if mat == Enum.Material.Glass and not q.noCore then
		local core = ell(rig, body, "Core", V(0.8, 0.8, 0.8), a, CFrame.new(0, 0.05 * s, 0.2 * s), Enum.Material.Neon, 0.1)
		rig.core = core
	end
	if STYLE.blocky then
		-- faceted elemental construct: stepped crown tier + chamfer wedges instead of a plain crate
		ell(rig, body, "Tier", Vector3.new(br.X * 1.5, br.Y * 0.6, br.Z * 1.5), lighten(p, 0.08), CFrame.new(0, br.Y * 1.15, 0.05 * s), mat, tr)
		for _, side in ipairs({ -1, 1 }) do
			wdg(rig, body, "Chamfer", Vector3.new(br.X * 1.9, br.Y * 0.5, br.Z * 0.35), darken(p, 0.12), CFrame.new(0, br.Y * 0.88, side * br.Z * 0.85) * CFrame.Angles(0, side > 0 and 0 or PI, 0), mat, tr)
		end
	else
		ell(rig, body, "Shine", V(0.6, 0.3, 0.45), WHITE, CFrame.new(-0.45 * s, br.Y * 0.62, -0.5 * s) * CFrame.Angles(0, 0, 0.4), Enum.Material.Neon, 0.35)
	end
	if not q.noDrip then ell(rig, body, "Drip", V(0.5, 0.6, 0.5), p, CFrame.new(0.8 * s, -0.5 * s, -0.6 * s), mat, tr) end
	return body, body, br, br, (q.faceY or 0.15) * s, CFrame.new(0, 0, br.Z), 0.3 * s
end

function Plans.ghost(rig, def, s, prof)
	local p = def._p
	local mat = matOf(def.mat)
	local q = prof.q or {}
	local V = function(x, y, z) return Vector3.new(x, y, z) * s end
	local br = V(1.1, 1.3, 1.1) * (q.body or Vector3.one)
	local tr = q.tr or (mat == Enum.Material.Glass and 0.3 or 0)
	local e, body = ell(rig, rig.root, "Body", br * 2, p, CFrame.new(0, 2.2 * s * (q.height or 1), 0), mat, tr)
	rig.bodyEntry = e
	if q.rim then ell(rig, body, "Rim", br * 2.08, q.rim, CFrame.new(0, 0, 0.04 * s), Enum.Material.SmoothPlastic, 0.55) end
	if STYLE.blocky then
		-- armored spectral form: tapered hood tier + narrower lower hem block
		ell(rig, body, "Hood", Vector3.new(br.X * 1.6, br.Y * 0.55, br.Z * 1.6), darken(p, 0.1), CFrame.new(0, br.Y * 1.1, 0.08 * s), mat, tr)
		ell(rig, body, "HemBlock", Vector3.new(br.X * 1.5, br.Y * 0.5, br.Z * 1.5), lighten(p, 0.06), CFrame.new(0, -br.Y * 1.05, 0), mat, tr)
	end
	local lobes = q.lobes or 3
	for i = 1, lobes do
		local x = (i - (lobes + 1) / 2) / math.max(1, (lobes - 1) / 2) * br.X * 0.55
		local w = ell(rig, body, "Wisp", V(0.7, 0.9, 0.7) * (q.lobeK or 1), q.hemCol or lighten(p, 0.1), CFrame.new(x, -br.Y * 0.9, 0.1 * s), mat, q.hemTr or 0.1, CFrame.new(0, 0.3 * s, 0))
		table.insert(rig.tail, w)
	end
	if (q.arms or 1) > 0 then
		for _, side in ipairs({ -1, 1 }) do
			local arm = ell(rig, body, "Arm", V(0.4, 0.65, 0.4) * (q.arms or 1), q.armCol or p, CFrame.new(side * br.X * 0.95, -0.1 * s, -0.2 * s) * CFrame.Angles(0, 0, side * 0.7), mat, tr, CFrame.new(0, 0.25 * s, 0))
			table.insert(rig.arms, { e = arm, side = side })
		end
	end
	rig.legKind = "none"
	return body, body, br, br, (q.faceY or 0.3) * s, CFrame.new(0, -0.5 * s, br.Z), 0.4 * s
end

function Plans.fish(rig, def, s, prof)
	local p, sc, a = def._p, def._s, def._a
	local mat = matOf(def.mat)
	local tr = (mat == Enum.Material.Glass) and 0.25 or 0
	local q = prof.q or {}
	local V = function(x, y, z) return Vector3.new(x, y, z) * s end
	local br = V(0.9, 0.95, 1.5) * (q.body or Vector3.one)
	local e, body = ell(rig, rig.root, "Body", br * 2, p, CFrame.new(0, 2.0 * s, 0), mat, tr)
	rig.bodyEntry = e
	ell(rig, body, "Belly", Vector3.new(br.X * 1.55, br.Y * 1.25, br.Z * 1.6), sc, CFrame.new(0, -br.Y * 0.37, 0))
	tri(rig, body, "Dorsal", 0.12 * s, 0.9 * s, 1.2 * s, a, CFrame.new(0, br.Y * 1.05, 0.25 * s) * CFrame.Angles(0, 0, 0))
	for _, side in ipairs({ -1, 1 }) do
		local fin = ell(rig, body, "Fin", V(0.9, 0.12, 0.6) * (q.finK or 1), a, CFrame.new(side * br.X * 0.95, -0.3 * s, -0.2 * s) * CFrame.Angles(0, side * 0.5, 0), nil, 0.05, CFrame.new(-side * 0.4 * s, 0, 0))
		table.insert(rig.wings, { e = fin, side = side, tier = 1 })
	end
	rig.legKind = "none"
	return body, body, br, br, 0.15 * s, CFrame.new(0, 0, br.Z * 0.95), 0.2 * s
end

function Plans.dragon(rig, def, s, prof)
	local p, sc = def._p, def._s
	local mat = matOf(def.mat)
	local tr = (mat == Enum.Material.Glass) and 0.15 or 0
	local q = prof.q or {}
	local V = function(x, y, z) return Vector3.new(x, y, z) * s end
	local br = V(1.1, 0.95, 1.5) * (q.body or Vector3.one)
	local legMode = q.legs or "four"
	local bodyY = (legMode == "none") and 2.4 * s or 1.7 * s * (q.lift or 1)
	local e, body = ell(rig, rig.root, "Body", br * 2, p, CFrame.new(0, bodyY, 0), mat, tr)
	rig.bodyEntry = e
	if mat == Enum.Material.Glass then ell(rig, body, "CoreBody", br * 1.6, darken(p, 0.15), CFrame.identity) end
	ell(rig, body, "Belly", Vector3.new(br.X * 1.45, br.Y * 1.25, br.Z * 1.6), sc, CFrame.new(0, -br.Y * 0.4, -0.1 * s))
	if q.chestPlates then
		for i = 0, 3 do
			blk(rig, body, "ChestPlate", V(1.0 - i * 0.1, 0.22, 0.5), q.chestPlates, CFrame.new(0, -br.Y * 0.35 + i * 0.28 * s, -br.Z * 0.88 + i * 0.05 * s) * CFrame.Angles(-0.5, 0, 0))
		end
	end
	local claw = function(le, size)
		if q.claws then for t = -1, 1 do spike(rig, le.part, "Claw", 0.3 * s, 0.14 * s, q.claws, CFrame.new(t * 0.15 * s, -size.Y * 0.45, -0.22 * s) * CFrame.Angles(-PI / 2 + 0.4, 0, 0)) end end
	end
	if legMode == "four" then
		legs(rig, body, { Vector3.new(-br.X * 0.6, -br.Y * 0.82, -br.Z * 0.6), Vector3.new(br.X * 0.6, -br.Y * 0.82, -br.Z * 0.6),
			Vector3.new(-br.X * 0.6, -br.Y * 0.82, br.Z * 0.6), Vector3.new(br.X * 0.6, -br.Y * 0.82, br.Z * 0.6) }, V(0.6, 1.1, 0.6), darken(p, 0.08), s, claw)
		rig.legKind = "quad"
	elseif legMode == "two" then -- wyvern: two powerful hind legs only
		legs(rig, body, { Vector3.new(-br.X * 0.62, -br.Y * 0.7, br.Z * 0.35), Vector3.new(br.X * 0.62, -br.Y * 0.7, br.Z * 0.35) }, V(0.78, 1.35, 0.78), darken(p, 0.08), s, claw)
		rig.legKind = "biped"
	else
		rig.legKind = "none"
	end
	-- neck(s) + head(s)
	local nNecks = q.necks or 1
	local hr = V(0.85, 0.75, 0.9) * (q.head or 1)
	local firstHead, faceY = nil, 0.2 * s
	for ni = 1, nNecks do
		local off = nNecks == 1 and 0 or (ni - (nNecks + 1) / 2)
		local neckSegs = q.neckSegs or 2
		local segLen = (q.neckLen or 1) * 0.75 * s
		local baseCF = CFrame.new(off * br.X * 0.8, br.Y * 0.45, -br.Z * 0.72) * CFrame.Angles(-0.7, 0, off * -0.45)
		local rec = chain(rig, body, "Neck", baseCF, neckSegs, function(j, n)
			local w = (0.95 - j * 0.08) * s * (q.neckW or 1)
			return Vector3.new(w, segLen * 1.6, w), p, mat, tr, CFrame.new(0, segLen * 0.85, 0) * CFrame.Angles(0.22, 0, 0), CFrame.new(0, -segLen * 0.7, 0)
		end, { kind = "neck", i = ni, side = off, amp = 0.12, freq = 1.1, lag = 0.6, axis = "both" })
		group(rig, "neckChains", rec)
		local last = rec.parts[#rec.parts]
		local he, head = ell(rig, last, "Head", hr * 2, p, CFrame.new(0, segLen * 0.75, -0.1 * s) * CFrame.Angles(0.7 - (neckSegs - 1) * 0.22, 0, 0), mat, tr, CFrame.new(0, -0.2 * s, 0.3 * s))
		local sn = ell(rig, head, "Snout", Vector3.new(hr.X * 1.25, hr.Y * 0.95, hr.Z * 1.1), lighten(p, 0.05), CFrame.new(0, -0.28 * s, -hr.Z * 0.8), mat, tr)
		for _, side in ipairs({ -1, 1 }) do
			ell(rig, head, "Nostril", V(0.14, 0.1, 0.1), DARK, CFrame.new(side * 0.2 * s, -0.12 * s, -hr.Z * 1.32))
		end
		-- hinged jaw
		local jaw = ell(rig, head, "Jaw", Vector3.new(hr.X * 1.05, hr.Y * 0.4, hr.Z * 1.0), lighten(sc, 0.05), CFrame.new(0, -hr.Y * 0.55, -hr.Z * 0.35), mat, tr, CFrame.new(0, 0, hr.Z * 0.45))
		group(rig, "jaws", jaw)
		group(rig, "heads", he)
		if q.brow then
			for _, side in ipairs({ -1, 1 }) do blk(rig, head, "BrowRidge", Vector3.new(hr.X * 0.7, 0.16 * s, 0.3 * s), q.brow, CFrame.new(side * hr.X * 0.38, hr.Y * 0.55, -hr.Z * 0.62) * CFrame.Angles(0.3, 0, side * 0.25)) end
		end
		if ni == math.ceil(nNecks / 2) then firstHead = { he = he, head = head } end
		rec.head = he
	end
	rig.headEntry = firstHead.he
	return body, firstHead.head, br, hr, faceY, CFrame.new(0, 0.2 * s, br.Z * 0.95), 0.75 * s
end

function Plans.bug(rig, def, s, prof)
	local p, sc, a = def._p, def._s, def._a
	local mat = matOf(def.mat)
	local tr = (mat == Enum.Material.Glass) and 0.2 or 0
	local q = prof.q or {}
	local V = function(x, y, z) return Vector3.new(x, y, z) * s end
	local br = V(0.8, 0.75, 0.75) * (q.thorax or Vector3.one)
	local e, body = ell(rig, rig.root, "Body", br * 2, p, CFrame.new(0, 1.3 * s, 0), mat, tr)
	rig.bodyEntry = e
	local ab = q.abdomen or Vector3.new(1.8, 1.7, 2.1)
	local abd = ell(rig, body, "Abdomen", ab * s, q.abdomenCol or sc, CFrame.new(0, 0.05 * s, (0.3 + ab.Z * 0.5) * s) * CFrame.Angles(q.abdomenPitch or 0, 0, 0), mat, tr, CFrame.new(0, 0, -ab.Z * 0.45 * s))
	group(rig, "abdomen", abd)
	if q.stripes then
		for i = 0, 2 do
			ell(rig, abd.part, "Stripe", Vector3.new(ab.X * 1.02, 0.25, ab.Z * 0.16) * s, q.stripeCol or a, CFrame.new(0, 0, (-0.35 + i * 0.35) * ab.Z * s))
		end
	end
	local legCol = q.legCol or DARK
	for i = -1, 1 do
		for _, side in ipairs({ -1, 1 }) do
			local leg = cyl(rig, body, "Leg", Vector3.new(0.85, 0.11, 0.11) * s * (q.legK or 1), legCol,
				CFrame.new(side * 0.55 * s, -0.5 * s, i * 0.42 * s) * CFrame.Angles(0, 0, side * 0.6) * CFrame.Angles(0, 0, PI / 2), nil, nil, CFrame.new(0.4 * s * (q.legK or 1), 0, 0))
			cyl(rig, leg.part, "Shin", Vector3.new(0.6, 0.09, 0.09) * s * (q.legK or 1), legCol, CFrame.new(-0.62 * s * (q.legK or 1), side * 0.0, 0) * CFrame.Angles(0, 0, side * -0.9))
			table.insert(rig.feet, leg)
		end
	end
	rig.legKind = "bug6"
	local hr = V(0.85, 0.8, 0.8) * (q.head or 1)
	local he, head = ell(rig, body, "Head", hr * 2, q.headCol or p, CFrame.new(0, 0.45 * s, -1.05 * s), mat, tr, CFrame.new(0, -0.2 * s, 0.3 * s))
	rig.headEntry = he
	return body, head, br, hr, 0.1 * s, CFrame.new(0, 0, (0.3 + ab.Z) * s), 0.7 * s
end

function Plans.golem(rig, def, s, prof)
	local p, sc, a = def._p, def._s, def._a
	local mat = matOf(def.mat)
	local tr = (mat == Enum.Material.Glass) and 0.25 or 0
	local q = prof.q or {}
	local V = function(x, y, z) return Vector3.new(x, y, z) * s end
	local br = V(1.5, 1.45, 1.25) * (q.body or Vector3.one)
	local hover = q.hover and 1.2 * s or 0
	local e, body = ell(rig, rig.root, "Body", br * 2, p, CFrame.new(0, 2.3 * s + hover, 0), mat, tr)
	rig.bodyEntry = e
	if q.cracks ~= false then
		for i = 1, 4 do
			local c = ell(rig, body, "Crack", V(0.12, 0.9, 0.05), a, surface(br, (i - 2.5) * 0.5 * s, (i % 2) * 0.4 * s - 0.4 * s) * CFrame.Angles(0, 0, i * 0.7), Enum.Material.Neon)
			group(rig, "seams", c)
		end
	end
	if q.chest ~= false then ell(rig, body, "Chest", V(1.6, 1.3, 0.5), q.chestCol or lighten(sc, 0.1), CFrame.new(0, -0.3 * s, -br.Z * 0.82), q.chestMat) end
	local ak = q.armK or 1
	for _, side in ipairs({ -1, 1 }) do
		local arm = ell(rig, body, "Arm", V(1.0, 1.9 * ak, 1.0) * (q.armW or 1), q.armCol or darken(p, 0.1), CFrame.new(side * br.X * 1.05, 0.2 * s, 0) * CFrame.Angles(0, 0, side * 0.15), mat, tr, CFrame.new(0, 0.75 * s * ak, 0))
		local fist = ell(rig, arm.part, "Fist", V(1.15, 0.9, 1.15) * (q.fistK or 1), q.fistCol or sc, CFrame.new(0, -0.95 * s * ak, 0), q.fistMat)
		group(rig, "fists", fist)
		table.insert(rig.arms, { e = arm, side = side })
	end
	if not q.hover then
		legs(rig, body, { V(-0.7, -1.55, 0) * Vector3.new(br.X / (1.5 * s), 1, 1), V(0.7, -1.55, 0) * Vector3.new(br.X / (1.5 * s), 1, 1) }, V(1.0, 1.0, 1.0) * (q.legK or 1), q.legCol or darken(p, 0.15), s)
		rig.legKind = "biped"
	else
		rig.legKind = "none"
		for i = 0, 2 do -- tapered statue base
			ell(rig, body, "Plinth", V(1.6 - i * 0.4, 0.5, 1.4 - i * 0.35), lighten(p, 0.02), CFrame.new(0, -br.Y * 0.95 - i * 0.35 * s, 0), mat)
		end
	end
	local hr = V(0.85, 0.75, 0.8) * (q.head or 1)
	local he, head = ell(rig, body, "Head", hr * 2, q.headCol or p, CFrame.new(0, br.Y * 1.05, -0.25 * s), mat, tr, CFrame.new(0, -0.3 * s, 0))
	rig.headEntry = he
	return body, head, br, hr, 0.05 * s, CFrame.new(0, -0.5 * s, br.Z), 0.8 * s
end
Builder.Plans = Plans

---------------------------------------------------------------------
-- BUILD
---------------------------------------------------------------------
local Anatomy -- SpeciesAnatomy (required lazily: it requires this module's H)

local function buildBody(rig, vd, s, prof)
	Anatomy = Anatomy or require(script.Parent.SpeciesAnatomy)
	local planName = prof.plan or vd.body
	local plan = Plans[planName]
	if not plan and Anatomy.Plans[planName] then
		local ap = Anatomy.Plans[planName]
		plan = function(...) return ap(H, ...) end
	end
	plan = plan or Plans.round
	local body, head, br, hr, faceY, tailAnchor, wingY = plan(rig, vd, s, prof)
	rig.body, rig.head, rig.bodyRadius, rig.headRadius = body, head, br, hr
	rig.faceY = faceY
	local heads = rig.groups.heads
	if heads and #heads > 1 then
		for _, he in ipairs(heads) do
			buildFace(rig, he.part, hr, vd, faceY, 0.85, prof.face)
			buildEars(rig, he.part, hr, vd, prof)
			buildHorns(rig, he.part, hr, vd)
		end
	elseif not prof.noFace then
		buildFace(rig, head, hr, vd, faceY, (vd.body == "golem" or prof.plan == "golem") and 0.85 or (prof.faceK or 1), prof.face)
		buildEars(rig, head, hr, vd, prof)
		buildHorns(rig, head, hr, vd)
	end
	if prof.tailAnchor then tailAnchor = prof.tailAnchor(br, s) end
	buildTail(rig, body, tailAnchor, vd, s, prof)
	buildWings(rig, body, br, prof.wingY and prof.wingY * s or wingY, vd, s, prof)
	buildExtras(rig, head, hr, body, br, vd, s, prof)
	if prof.build then
		local fn = Anatomy[prof.build]
		if fn then fn(H, rig, vd, s, prof) end
	end
	addEffects(rig, vd, br, s, prof)
end

---------------------------------------------------------------------
-- SCULPTED MESH PATH (species with generated meshes in PetMeshManifest)
---------------------------------------------------------------------
local MeshManifest = require(script.Parent.PetMeshManifest)
Builder.MeshScale = 0.85 -- generated pets are ~4.2 studs tall; scale toward the procedural sizes

local function meshTemplate(id)
	if not MeshManifest[id] or typeof(game) ~= "Instance" then return nil end
	local rs = game:FindFirstChild("ReplicatedStorage")
	local f = rs and rs:FindFirstChild("PetMeshes")
	local t = f and f:FindFirstChild(id)
	if not t then return nil end
	for _, pd in ipairs(MeshManifest[id].parts) do
		if not t:FindFirstChild(pd.role) then return nil end -- incomplete: use the procedural fallback
	end
	return t
end
Builder.HasMesh = function(id) return meshTemplate(id) ~= nil end

local function buildFromMeshes(rig, tmpl, man, s)
	local k = s * Builder.MeshScale
	local entries, bodyCF = {}, nil
	local function cfOf(pd) return CFrame.new(Vector3.new(pd.pos[1], pd.pos[2], pd.pos[3]) * k) end
	for _, pd in ipairs(man.parts) do if pd.role == "body" then bodyCF = cfOf(pd) end end
	bodyCF = bodyCF or CFrame.new(0, 1.5 * k, 0)
	local function mk(pd, parent, parentCF, pivot)
		local p = tmpl[pd.role]:Clone()
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
		p.CastShadow = true
		local size = Vector3.new(pd.size[1], pd.size[2], pd.size[3]) * k
		p.Size = size
		p.Parent = rig.model
		local cf = cfOf(pd)
		local c1 = pivot and pivot(size) or CFrame.identity
		local e = attach(rig, parent, p, nil, parentCF:ToObjectSpace(cf) * c1, c1)
		e.baseSize = size
		entries[pd.role] = e
		return e, p, size
	end
	local find = function(role) for _, pd in ipairs(man.parts) do if pd.role == role then return pd end end end
	-- body on the root, head on the body, accessories on the head
	local bodyPd = find("body")
	local be, body, bsize = mk(bodyPd, rig.root, CFrame.identity, nil)
	rig.bodyEntry, rig.body = be, body
	rig.bodyRadius = bsize / 2
	local head, hsize = body, bsize
	local headPd = find("head")
	if headPd then
		local he, hp, hs = mk(headPd, body, bodyCF, function(sz) return CFrame.new(0, -sz.Y * 0.35, sz.Z * 0.25) end)
		rig.headEntry, head, hsize = he, hp, hs
	end
	rig.head, rig.headRadius, rig.faceY = head, hsize / 2, 0
	local headCF = headPd and cfOf(headPd) or bodyCF
	local HEAD_ATTACH = { "horn", "antler", "crown", "hat", "crest", "beak", "helmet", "mane", "sprout", "antenna", "tuft", "snout", "jaw", "eye" }
	local function onHead(r)
		for _, k in ipairs(HEAD_ATTACH) do if r:find(k) then return true end end
		return false
	end
	for _, pd in ipairs(man.parts) do
		local r = pd.role
		if r == "body" or r == "head" then continue end
		if r:find("head") then -- extra heads (hydra): independent necks/heads with their own gaze
			local e = mk(pd, body, bodyCF, function(sz) return CFrame.new(0, -sz.Y * 0.4, sz.Z * 0.2) end)
			rig.groups.heads = rig.groups.heads or {}
			table.insert(rig.groups.heads, e)
		elseif r:find("wing") and (r:find("left") or r:find("right")) then
			local side = r:find("left") and -1 or 1
			local e = mk(pd, body, bodyCF, function(sz) return CFrame.new(-side * sz.X * 0.42, 0, 0) end)
			table.insert(rig.wings, { e = e, side = side, tier = 1 })
		elseif r:find("arm") and (r:find("left") or r:find("right")) then
			local side = r:find("left") and -1 or 1
			local e = mk(pd, body, bodyCF, function(sz) return CFrame.new(0, sz.Y * 0.4, 0) end)
			table.insert(rig.arms, { e = e, side = side })
		elseif r:find("tentacle") or r:find("fin") or r:find("tendril") or r:find("skirt") or r:find("robe") then
			table.insert(rig.tail, (mk(pd, body, bodyCF, function(sz) return CFrame.new(0, sz.Y * 0.4, 0) end)))
		elseif r:find("ear") then
			local e = mk(pd, head, headCF, function(sz) return CFrame.new(0, -sz.Y * 0.4, 0) end)
			table.insert(rig.ears, { e = e, side = r:find("left") and -1 or 1, kind = "mesh" })
		elseif onHead(r) then
			local e = mk(pd, head, headCF, function(sz) return CFrame.new(0, -sz.Y * 0.4, 0) end)
			if r:find("sprout") or r:find("antenna") or r:find("tuft") then table.insert(rig.bobbers, e) end
		elseif r == "halo" then
			table.insert(rig.halos, (mk(pd, head, headCF, nil)))
		elseif r:find("leg") then
			local e = mk(pd, body, bodyCF, function(sz) return CFrame.new(0, sz.Y * 0.4, 0) end)
			table.insert(rig.feet, e)
		elseif r:find("tail") then
			local fan = r == "nine tails"
			local e = mk(pd, body, bodyCF, function(sz) return fan and CFrame.new(0, -sz.Y * 0.35, -sz.Z * 0.4) or CFrame.new(0, 0, -sz.Z * 0.45) end)
			table.insert(rig.tail, e)
		elseif r:find("wing") then -- a single combined wing mesh: gentle sway only
			table.insert(rig.bobbers, (mk(pd, body, bodyCF, nil)))
		else
			mk(pd, body, bodyCF, nil)
		end
	end
	rig.legKind = #rig.feet >= 2 and "biped" or "none"
	rig.meshBuilt = true
end

-- Builds a creature model. Returns (model, rig). The model's PrimaryPart is an
-- anchored invisible "Root" at ground level, facing -Z. Move it with model:PivotTo().
function Builder.Build(creatureId: string, sizeMult: number?)
	local def = CreatureData.ById[creatureId]
	assert(def, "Unknown creature " .. tostring(creatureId))
	local prof = Profiles.Get(def.id)
	-- visual view of the definition: overrides never touch the shared CreatureData table
	local vd = setmetatable({}, { __index = def })
	for k, v in pairs(prof.over or {}) do vd[k] = v end
	vd._p, vd._s, vd._a = hex(def.c[1]), hex(def.c[2]), hex(def.c[3])
	local s = Config.Rarities[def.rarity].size * def.scale * (sizeMult or 1)

	local model = Instance.new("Model")
	model.Name = def.id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 0.2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root

	local rig = {
		model = model, root = root, def = def, vd = vd, profile = prof, size = s,
		pal = { p = vd._p, s = vd._s, a = vd._a },
		all = {}, eyes = {}, pupils = {}, ears = {}, wings = {}, tail = {}, feet = {}, arms = {},
		halos = {}, bobbers = {}, emitters = {}, mouths = {}, chains = {}, groups = {}, legKind = "none",
		style = STYLE,
	}
	local Models = require(script.Parent.SpeciesModels)
	local tmpl = (not Models[def.id]) and meshTemplate(def.id)
	if Models[def.id] then
		-- hand-authored, reference-faithful model (highest priority; no particle compensation)
		Models[def.id](H, rig, vd, s)
	elseif tmpl then
		buildFromMeshes(rig, tmpl, MeshManifest[def.id], s)
		addEffects(rig, vd, rig.bodyRadius, s, prof)
	else
		buildBody(rig, vd, s, prof)
	end
	model:SetAttribute("CreatureId", def.id)
	model:SetAttribute("Rarity", def.rarity)
	return model, rig
end

-- Bounding box of the VISIBLE geometry only (ignores invisible pivots, root, effect holders).
function Builder.VisualBounds(model: Model)
	local minV, maxV
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "Root" and d.Name ~= "Orbit" then
			local cf, sz = d.CFrame, d.Size
			local m = d:FindFirstChildOfClass("SpecialMesh")
			if m then sz = sz * m.Scale end
			local half = sz / 2
			-- conservative AABB of the rotated box
			local r = cf.Rotation
			local ex = Vector3.new(
				math.abs(r.XVector.X) * half.X + math.abs(r.YVector.X) * half.Y + math.abs(r.ZVector.X) * half.Z,
				math.abs(r.XVector.Y) * half.X + math.abs(r.YVector.Y) * half.Y + math.abs(r.ZVector.Y) * half.Z,
				math.abs(r.XVector.Z) * half.X + math.abs(r.YVector.Z) * half.Y + math.abs(r.ZVector.Z) * half.Z)
			local lo, hi = cf.Position - ex, cf.Position + ex
			minV = minV and minV:Min(lo) or lo
			maxV = maxV and maxV:Max(hi) or hi
		end
	end
	if not minV then local cf, size = model:GetBoundingBox(); return cf, size end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end

return Builder
