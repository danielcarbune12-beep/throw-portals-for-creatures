-- CreatureBuilder: builds a detailed, rigged, cute 3D creature from CreatureData.
-- Location: ReplicatedStorage > Shared > CreatureBuilder (ModuleScript)
--
-- Every piece is a Part + SpecialMesh (smooth ellipsoids, no blocks) joined with Welds,
-- so CreatureAnimator can bend ears, flap wings, swing tails, blink eyes and squash
-- the body by changing Weld.C0 / SpecialMesh.Scale — no animation assets needed.

local Config = require(script.Parent.Config)
local CreatureData = require(script.Parent.CreatureData)

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

---------------------------------------------------------------------
-- low-level part helpers
---------------------------------------------------------------------
local function newPiece(rig, name, size, color, mat, meshType, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
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
	p.CastShadow = size.Magnitude > 1.2
	local m = Instance.new("SpecialMesh")
	m.MeshType = meshType or Enum.MeshType.Sphere
	m.Parent = p
	p.Parent = rig.model
	return p, m
end

-- attach `part` to `parent`; C0 = where the pivot sits on parent, C1 = pivot inside part
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

local function ell(rig, parent, name, size, color, cf, mat, transp, c1)
	local p, m = newPiece(rig, name, size, color, mat, Enum.MeshType.Sphere, transp)
	return attach(rig, parent, p, m, cf, c1), p
end

local function cyl(rig, parent, name, size, color, cf, mat, transp, c1)
	local p, m = newPiece(rig, name, size, color, mat, Enum.MeshType.Cylinder, transp)
	return attach(rig, parent, p, m, cf, c1), p
end

-- cone made of shrinking ellipsoids along local +Y of `cf`
local function cone(rig, parent, name, cf, len, radius, color, mat, segments)
	segments = segments or 4
	for i = 0, segments - 1 do
		local t = i / segments
		local r = radius * (1 - t * 0.8)
		ell(rig, parent, name, Vector3.new(r * 2, len / segments * 1.6, r * 2), color,
			cf * CFrame.new(0, len * t + len / segments * 0.5, 0), mat)
	end
end

-- point on an ellipsoid surface (front = -Z) + orientation facing outwards
local function surface(r, x, y, side)
	local a, b, c = r.X, r.Y, r.Z
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

---------------------------------------------------------------------
-- FACE
---------------------------------------------------------------------
local function buildEye(rig, head, r, x, y, w, h, def, accent, flip)
	local cf = surface(r, x, y)
	local style = def.eyes
	if style == "sleepy" then
		local e, ep = ell(rig, head, "Eye", Vector3.new(w, h * 0.22, 0.12), DARK, cf * CFrame.new(0, 0, -0.02))
		table.insert(rig.eyes, e)
		return
	end
	local scleraColor = WHITE
	local mat = Enum.Material.SmoothPlastic
	if style == "glow" then scleraColor = lighten(accent, 0.35); mat = Enum.Material.Neon end
	local e, eyePart = ell(rig, head, "Eye", Vector3.new(w, h, 0.18), scleraColor, cf, mat)
	table.insert(rig.eyes, e)
	if style ~= "glow" then
		local irisColor = (style == "sparkle" or style == "fierce") and accent or DARK
		local iris = ell(rig, eyePart, "Pupil", Vector3.new(w * 0.72, h * 0.74, 0.1), irisColor, CFrame.new(0, -h * 0.04, -0.06))
		table.insert(rig.pupils, iris)
		if style == "sparkle" or style == "fierce" then
			ell(rig, iris.part, "PupilCore", Vector3.new(w * 0.38, h * 0.42, 0.06), DARK, CFrame.new(0, 0, -0.03))
		end
		-- glossy highlights = the "alive" look
		ell(rig, iris.part, "Shine", Vector3.new(w * 0.28, h * 0.26, 0.04), WHITE, CFrame.new(-w * 0.14 * flip, h * 0.16, -0.06), Enum.Material.Neon)
		ell(rig, iris.part, "Shine2", Vector3.new(w * 0.13, h * 0.12, 0.04), WHITE, CFrame.new(w * 0.14 * flip, -h * 0.16, -0.06), Enum.Material.Neon)
	else
		ell(rig, eyePart, "Shine", Vector3.new(w * 0.3, h * 0.3, 0.05), WHITE, CFrame.new(-w * 0.15 * flip, h * 0.15, -0.07), Enum.Material.Neon)
	end
	if style == "fierce" then
		local brow = ell(rig, head, "Brow", Vector3.new(w * 1.1, h * 0.16, 0.12), darken(def._p, 0.55),
			surface(r, x, y + h * 0.62) * CFrame.Angles(0, 0, math.rad(-18 * flip)))
	end
end

local function buildFace(rig, head, r, def, yOff, scaleK)
	local accent = def._a
	scaleK = scaleK or 1
	local w, h = r.X * 0.42 * scaleK, r.Y * 0.5 * scaleK
	if def.eyes == "cyclops" then
		buildEye(rig, head, r, 0, yOff + r.Y * 0.05, w * 1.6, h * 1.5, def, accent, 1)
	else
		local sx = r.X * 0.36
		buildEye(rig, head, r, -sx, yOff, w, h, def, accent, 1)
		buildEye(rig, head, r, sx, yOff, w, h, def, accent, -1)
		if def.eyes ~= "fierce" then
			for _, s in ipairs({ -1, 1 }) do
				ell(rig, head, "Cheek", Vector3.new(r.X * 0.3, r.Y * 0.16, 0.08), PINK,
					surface(r, s * r.X * 0.58, yOff - r.Y * 0.32) * CFrame.new(0, 0, -0.01), nil, 0.35)
			end
		end
	end
	-- little smile ("w" mouth made of two arcs)
	local m1 = ell(rig, head, "Mouth", Vector3.new(r.X * 0.2, r.Y * 0.09, 0.07), DARK, surface(r, 0, yOff - r.Y * 0.36))
	rig.mouth = m1
	if table.find(def.extra, "eyepatch") then
		ell(rig, head, "Patch", Vector3.new(w * 1.25, h * 1.2, 0.2), DARK, surface(r, r.X * 0.36, yOff) * CFrame.new(0, 0, -0.06))
	end
end

---------------------------------------------------------------------
-- EARS / HORNS
---------------------------------------------------------------------
local function buildEars(rig, head, r, def)
	local kind = def.ears
	if kind == "none" then return end
	local p, s, a = def._p, def._s, def._a
	for _, side in ipairs({ -1, 1 }) do
		local e
		if kind == "round" then
			e = ell(rig, head, "Ear", Vector3.new(r.X * 0.55, r.X * 0.55, r.X * 0.22), p,
				CFrame.new(side * r.X * 0.62, r.Y * 0.72, 0.1) * CFrame.Angles(0, 0, -side * 0.35), nil, nil, CFrame.new(0, -r.X * 0.2, 0))
			ell(rig, e.part, "EarInner", Vector3.new(r.X * 0.34, r.X * 0.34, r.X * 0.1), PINK, CFrame.new(0, 0, -r.X * 0.07))
		elseif kind == "pointy" or kind == "cat" then
			local len = kind == "cat" and r.Y * 0.7 or r.Y * 0.95
			e = ell(rig, head, "Ear", Vector3.new(r.X * 0.42, len, r.X * 0.2), p,
				CFrame.new(side * r.X * 0.55, r.Y * 0.68, 0.05) * CFrame.Angles(0, 0, -side * 0.38), nil, nil, CFrame.new(0, -len * 0.42, 0))
			ell(rig, e.part, "EarInner", Vector3.new(r.X * 0.24, len * 0.7, r.X * 0.08), lighten(PINK, 0.2), CFrame.new(0, -len * 0.05, -r.X * 0.07))
		elseif kind == "bunny" then
			local len = r.Y * 1.5
			e = ell(rig, head, "Ear", Vector3.new(r.X * 0.36, len, r.X * 0.2), p,
				CFrame.new(side * r.X * 0.36, r.Y * 0.8, 0.1) * CFrame.Angles(-0.15, 0, -side * 0.18), nil, nil, CFrame.new(0, -len * 0.45, 0))
			ell(rig, e.part, "EarInner", Vector3.new(r.X * 0.2, len * 0.75, r.X * 0.08), PINK, CFrame.new(0, 0, -r.X * 0.08))
		elseif kind == "floppy" then
			local len = r.Y * 1.1
			e = ell(rig, head, "Ear", Vector3.new(r.X * 0.42, len, r.X * 0.2), darken(p, 0.12),
				CFrame.new(side * r.X * 0.82, r.Y * 0.25, 0) * CFrame.Angles(0, 0, side * 0.35), nil, nil, CFrame.new(0, len * 0.42, 0))
		elseif kind == "fin" then
			e = ell(rig, head, "Ear", Vector3.new(0.12 * r.X, r.Y * 0.7, r.Z * 0.8), a,
				CFrame.new(side * r.X * 0.92, 0, 0.1) * CFrame.Angles(0, 0, -side * 0.6), nil, 0.1, CFrame.new(0, -r.Y * 0.2, 0))
		end
		if e then table.insert(rig.ears, { e = e, side = side }) end
	end
end

local function buildHorns(rig, head, r, def)
	local kind = def.horns
	if kind == "none" then return end
	local a = def._a
	local hornColor = (kind == "antlers" or kind == "unicorn") and a or lighten(def._s, 0.2)
	local hmat = (kind == "antlers" or def.rarity == "Divine") and Enum.Material.Neon or Enum.Material.SmoothPlastic
	if kind == "unicorn" then
		cone(rig, head, "Horn", CFrame.new(0, r.Y * 0.8, -r.Z * 0.3) * CFrame.Angles(-0.35, 0, 0), r.Y * 1.1, r.X * 0.17, hornColor, hmat, 6)
		return
	end
	for _, side in ipairs({ -1, 1 }) do
		if kind == "small" then
			cone(rig, head, "Horn", CFrame.new(side * r.X * 0.4, r.Y * 0.78, 0) * CFrame.Angles(0, 0, -side * 0.25), r.Y * 0.5, r.X * 0.12, hornColor, hmat, 3)
		elseif kind == "dragon" then
			cone(rig, head, "Horn", CFrame.new(side * r.X * 0.42, r.Y * 0.7, r.Z * 0.2) * CFrame.Angles(0.9, 0, -side * 0.25), r.Y * 0.9, r.X * 0.15, hornColor, hmat, 5)
		elseif kind == "ram" then
			for i = 0, 5 do
				local ang = i / 5 * math.pi * 1.3
				local pos = Vector3.new(side * (r.X * 0.75 + math.sin(ang) * r.X * 0.28), r.Y * 0.5 + math.cos(ang) * r.Y * 0.3, r.Z * 0.15 + math.sin(ang * 0.5) * 0.2)
				local sz = r.X * (0.32 - i * 0.03)
				ell(rig, head, "Horn", Vector3.new(sz, sz, sz), hornColor, CFrame.new(pos))
			end
		elseif kind == "antlers" then
			local base = CFrame.new(side * r.X * 0.4, r.Y * 0.75, 0.1) * CFrame.Angles(0, 0, -side * 0.45)
			cyl(rig, head, "Antler", Vector3.new(0.18, r.Y * 1.1, 0.18), lighten(def._s, 0.1), base * CFrame.new(0, r.Y * 0.55, 0))
			for i = 1, 3 do
				local bcf = base * CFrame.new(0, r.Y * 0.3 * i, 0) * CFrame.Angles(0, 0, side * 0.9) * CFrame.new(0, r.Y * 0.22, 0)
				cyl(rig, head, "Antler", Vector3.new(0.14, r.Y * 0.45, 0.14), lighten(def._s, 0.1), bcf)
				ell(rig, head, "AntlerGlow", Vector3.new(0.28, 0.28, 0.28), a, bcf * CFrame.new(0, r.Y * 0.24, 0), Enum.Material.Neon)
			end
		end
	end
end

---------------------------------------------------------------------
-- TAIL / WINGS
---------------------------------------------------------------------
local function buildTail(rig, body, anchor, def, s)
	local kind = def.tail
	if kind == "none" then return end
	local p, sc, a = def._p, def._s, def._a
	if kind == "fluffy" then
		local e = ell(rig, body, "Tail", Vector3.new(1, 1, 1) * 0.9 * s, sc, anchor, nil, nil, CFrame.new(0, 0, -0.3 * s))
		ell(rig, e.part, "TailFluff", Vector3.new(0.6, 0.6, 0.6) * s, lighten(sc, 0.3), CFrame.new(0, 0.15 * s, 0.25 * s))
		table.insert(rig.tail, e)
		return
	end
	if kind == "fish" then
		local e = ell(rig, body, "Tail", Vector3.new(0.18 * s, 1.5 * s, 1.1 * s), a, anchor * CFrame.new(0, 0, 0.35 * s), nil, 0.05, CFrame.new(0, 0, -0.45 * s))
		table.insert(rig.tail, e)
		return
	end
	if kind == "lollipop" then
		local e = cyl(rig, body, "Tail", Vector3.new(0.18, 1.2, 0.18) * s, WHITE, anchor * CFrame.Angles(-0.7, 0, 0), nil, nil, CFrame.new(0, -0.6 * s, 0))
		local disc = cyl(rig, e.part, "Candy", Vector3.new(1.1, 0.25, 1.1) * s, a, CFrame.new(0, 0.75 * s, 0) * CFrame.Angles(math.pi / 2, 0, 0))
		cyl(rig, disc.part, "Swirl", Vector3.new(0.75, 0.27, 0.75) * s, sc, CFrame.identity)
		cyl(rig, disc.part, "Swirl2", Vector3.new(0.4, 0.29, 0.4) * s, a, CFrame.identity)
		table.insert(rig.tail, e)
		return
	end
	-- chain tails: long / flame / stinger / leaf / aurora
	local n = (kind == "flame") and 3 or 5
	local prev, prevLen = body, 0
	local auroraCols = { a, Color3.fromRGB(120, 255, 220), Color3.fromRGB(140, 160, 255), Color3.fromRGB(255, 140, 240), Color3.fromRGB(255, 255, 255) }
	for i = 1, n do
		local t = i / n
		local rad = (kind == "flame" and 0.75 or 0.5) * s * (1.1 - t * 0.6)
		local col, mat, tr = p, nil, 0
		if kind == "flame" then col = (i == n) and Color3.fromRGB(255, 240, 120) or a:Lerp(Color3.fromRGB(255, 120, 30), t); mat = Enum.Material.Neon end
		if kind == "aurora" then col = auroraCols[i]; mat = Enum.Material.Neon; tr = 0.2 end
		local c0 = (i == 1) and anchor or CFrame.new(0, rad * 0.5, rad * 1.1) * CFrame.Angles(0.28, 0, 0)
		local e, part = ell(rig, prev, "Tail", Vector3.new(rad * 2, rad * 2, rad * 2.4), col, c0, mat, tr)
		table.insert(rig.tail, e)
		prev = part
	end
	if kind == "flame" then
		local f = Instance.new("Fire"); f.Size = 3 * s; f.Heat = 6; f.Color = a; f.SecondaryColor = Color3.fromRGB(255, 230, 120); f.Parent = prev
	elseif kind == "stinger" then
		cone(rig, prev, "Stinger", CFrame.new(0, 0, 0.2 * s) * CFrame.Angles(math.pi / 2, 0, 0), 0.9 * s, 0.22 * s, DARK, nil, 3)
	elseif kind == "leaf" then
		ell(rig, prev, "Leaf", Vector3.new(0.9 * s, 0.12 * s, 1.4 * s), Color3.fromRGB(90, 210, 90), CFrame.new(0, 0, 0.8 * s))
	end
end

local function buildWings(rig, body, r, anchorY, def, s)
	local kind = def.wings
	if kind == "none" then return end
	local p, sc, a = def._p, def._s, def._a
	for _, side in ipairs({ -1, 1 }) do
		local pivot = CFrame.new(side * r.X * 0.75, anchorY, r.Z * 0.15)
		local e
		if kind == "feather" or kind == "angel" then
			local big = kind == "angel" and 1.5 or 1
			local col = kind == "angel" and WHITE or sc
			e = ell(rig, body, "Wing", Vector3.new(1.9 * big * s, 1.1 * big * s, 0.2 * s), col, pivot * CFrame.Angles(0, side * 0.25, side * 0.25), nil, nil,
				CFrame.new(-side * 0.8 * big * s, -0.1 * s, 0))
			for i = 1, 3 do
				ell(rig, e.part, "Feather", Vector3.new(1.3 * big * s * (1 - i * 0.15), 0.5 * big * s, 0.16 * s),
					i == 3 and (kind == "angel" and GOLD or a) or lighten(col, 0.1 * i),
					CFrame.new(side * 0.2 * i * s, -0.35 * i * big * s, 0.02) * CFrame.Angles(0, 0, side * 0.15 * i), i == 3 and kind == "angel" and Enum.Material.Neon or nil)
			end
		elseif kind == "bat" then
			e = ell(rig, body, "Wing", Vector3.new(2.2 * s, 1.3 * s, 0.1 * s), darken(a, 0.1), pivot * CFrame.Angles(0, side * 0.2, side * 0.3), nil, 0.05,
				CFrame.new(-side * 1.0 * s, -0.2 * s, 0))
			for i = -1, 1 do
				cyl(rig, e.part, "Finger", Vector3.new(0.12, 1.4, 0.12) * s, p, CFrame.new(side * 0.15 * s, 0.05, 0) * CFrame.Angles(0, 0, side * (1.2 + i * 0.4)))
			end
		elseif kind == "bug" then
			e = ell(rig, body, "Wing", Vector3.new(1.8 * s, 1.3 * s, 0.06 * s), lighten(a, 0.3), pivot * CFrame.Angles(0, side * 0.3, side * 0.5), Enum.Material.Glass, 0.35,
				CFrame.new(-side * 0.85 * s, -0.3 * s, 0))
			ell(rig, e.part, "WingSpot", Vector3.new(0.6, 0.6, 0.07) * s, sc, CFrame.new(side * 0.2 * s, 0.1 * s, 0), Enum.Material.Neon, 0.2)
			ell(rig, e.part, "WingLow", Vector3.new(1.2 * s, 0.9 * s, 0.06 * s), lighten(a, 0.5), CFrame.new(side * 0.1 * s, -0.8 * s, 0.05), Enum.Material.Glass, 0.4)
		end
		if e then table.insert(rig.wings, { e = e, side = side }) end
	end
end

---------------------------------------------------------------------
-- EXTRAS
---------------------------------------------------------------------
local function ringOf(rig, parent, center, radius, count, size, color, tilt)
	for i = 1, count do
		local ang = i / count * math.pi * 2
		ell(rig, parent, "Ring", Vector3.new(size, size, size), color,
			center * CFrame.Angles(tilt or 0, 0, 0) * CFrame.new(math.cos(ang) * radius, 0, math.sin(ang) * radius), Enum.Material.Neon)
	end
end

local function buildExtras(rig, head, hr, body, br, def, s)
	local p, sc, a = def._p, def._s, def._a
	for _, x in ipairs(def.extra) do
		if x == "leafsprout" then
			local stem = cyl(rig, head, "Sprout", Vector3.new(0.12, 0.5, 0.12) * s, Color3.fromRGB(70, 160, 60), CFrame.new(0, hr.Y * 0.98, 0), nil, nil, CFrame.new(0, -0.25 * s, 0))
			for _, side in ipairs({ -1, 1 }) do
				ell(rig, stem.part, "Leaf", Vector3.new(0.6, 0.1, 0.35) * s, Color3.fromRGB(110, 220, 90), CFrame.new(side * 0.3 * s, 0.25 * s, 0) * CFrame.Angles(0, 0, side * 0.4))
			end
			table.insert(rig.bobbers, stem)
		elseif x == "acorn" then
			ell(rig, head, "AcornCap", Vector3.new(hr.X * 1.3, hr.Y * 0.6, hr.Z * 1.3), Color3.fromRGB(120, 75, 40), CFrame.new(0, hr.Y * 0.78, 0), Enum.Material.Fabric)
			cyl(rig, head, "AcornStem", Vector3.new(0.15, 0.4, 0.15) * s, Color3.fromRGB(90, 55, 30), CFrame.new(0, hr.Y * 1.1, 0))
		elseif x == "flower" then
			local center = CFrame.new(hr.X * 0.55, hr.Y * 0.65, -hr.Z * 0.2) * CFrame.Angles(0, 0, -0.5)
			for i = 1, 5 do
				local ang = i / 5 * math.pi * 2
				ell(rig, head, "Petal", Vector3.new(0.38, 0.12, 0.38) * s, a, center * CFrame.new(math.cos(ang) * 0.25 * s, 0, math.sin(ang) * 0.25 * s))
			end
			ell(rig, head, "FlowerCore", Vector3.new(0.25, 0.16, 0.25) * s, Color3.fromRGB(255, 230, 90), center)
		elseif x == "crown" then
			local base = CFrame.new(0, hr.Y * 0.95, 0)
			cyl(rig, head, "Crown", Vector3.new(hr.X * 0.9, 0.3 * s, hr.X * 0.9), GOLD, base, Enum.Material.Metal)
			for i = 1, 5 do
				local ang = i / 5 * math.pi * 2
				local cf = base * CFrame.new(math.cos(ang) * hr.X * 0.4, 0.25 * s, math.sin(ang) * hr.X * 0.4)
				cone(rig, head, "CrownSpike", cf, 0.45 * s, 0.1 * s, GOLD, Enum.Material.Metal, 2)
				ell(rig, head, "Gem", Vector3.new(0.14, 0.14, 0.14) * s, a, cf * CFrame.new(0, 0.5 * s, 0), Enum.Material.Neon)
			end
		elseif x == "halo" then
			local hp, hm = newPiece(rig, "HaloCore", Vector3.new(0.1, 0.1, 0.1), GOLD, Enum.Material.Neon)
			local e = attach(rig, head, hp, hm, CFrame.new(0, hr.Y * 1.45, 0))
			ringOf(rig, hp, CFrame.identity, hr.X * 0.55, 14, 0.2 * s, Color3.fromRGB(255, 240, 150))
			table.insert(rig.halos, e)
		elseif x == "helmet" then
			ell(rig, head, "Helmet", hr * 2.5, Color3.fromRGB(200, 240, 255), CFrame.new(0, 0.1 * s, 0), Enum.Material.Glass, 0.7)
		elseif x == "crystal" then
			for i = -1, 1 do
				ell(rig, body, "Crystal", Vector3.new(0.35, 1.2 - math.abs(i) * 0.35, 0.35) * s, a,
					CFrame.new(i * br.X * 0.35, br.Y * 0.85, br.Z * 0.15) * CFrame.Angles(0.2, 0, -i * 0.35), Enum.Material.Neon, 0.1)
			end
		elseif x == "mane" then
			for i = 0, 9 do
				local ang = i / 10 * math.pi * 2
				ell(rig, head, "Mane", Vector3.new(0.75, 0.75, 0.75) * s, i % 2 == 0 and sc or a,
					CFrame.new(math.cos(ang) * hr.X * 0.95, math.sin(ang) * hr.Y * 0.95 + 0.05, hr.Z * 0.25))
			end
		elseif x == "spikes" then
			for i = 0, 3 do
				cone(rig, body, "Spike", CFrame.new(0, br.Y * 0.8 - i * 0.1, -br.Z * 0.5 + i * br.Z * 0.38) * CFrame.Angles(0.3, 0, 0), 0.7 * s, 0.2 * s, a, nil, 3)
			end
		elseif x == "antenna" then
			for _, side in ipairs({ -1, 1 }) do
				local st = cyl(rig, head, "Antenna", Vector3.new(0.09, 0.9, 0.09) * s, darken(p, 0.4),
					CFrame.new(side * hr.X * 0.3, hr.Y * 0.85, 0) * CFrame.Angles(0, 0, -side * 0.35), nil, nil, CFrame.new(0, -0.45 * s, 0))
				ell(rig, st.part, "AntennaBall", Vector3.new(0.3, 0.3, 0.3) * s, a, CFrame.new(0, 0.5 * s, 0), Enum.Material.Neon)
				table.insert(rig.ears, { e = st, side = side })
			end
		elseif x == "shell" then
			ell(rig, body, "Shell", br * 2.1, a, CFrame.new(0, br.Y * 0.25, br.Z * 0.1), Enum.Material.Glass, 0.15)
		elseif x == "candy" then
			local cols = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 230, 80), WHITE }
			for i = 1, 10 do
				local ang, h = i * 2.39, (i % 4) * 0.2
				ell(rig, body, "Sprinkle", Vector3.new(0.22, 0.08, 0.08) * s, cols[i % 4 + 1],
					CFrame.new(math.cos(ang) * br.X * 0.75, br.Y * (0.35 + h), math.sin(ang) * br.Z * 0.75) * CFrame.Angles(0, ang, 0.6), Enum.Material.Neon)
			end
		elseif x == "rings" then
			ringOf(rig, body, CFrame.new(0, 0, 0), br.X * 1.45, 22, 0.18 * s, a, 0.35)
		elseif x == "bow" then
			local c = CFrame.new(hr.X * 0.5, hr.Y * 0.75, 0) * CFrame.Angles(0, 0, -0.4)
			ell(rig, head, "Bow", Vector3.new(0.6, 0.45, 0.25) * s, a, c * CFrame.new(-0.3 * s, 0, 0))
			ell(rig, head, "Bow", Vector3.new(0.6, 0.45, 0.25) * s, a, c * CFrame.new(0.3 * s, 0, 0))
			ell(rig, head, "BowKnot", Vector3.new(0.25, 0.25, 0.25) * s, lighten(a, 0.3), c)
		elseif x == "snowcap" then
			ell(rig, head, "Snow", Vector3.new(hr.X * 1.2, hr.Y * 0.5, hr.Z * 1.2), WHITE, CFrame.new(0, hr.Y * 0.8, 0))
		elseif x == "scarf" then
			for i = 0, 11 do
				local ang = i / 12 * math.pi * 2
				ell(rig, head, "Scarf", Vector3.new(0.5, 0.4, 0.5) * s, i % 3 == 0 and WHITE or a,
					CFrame.new(math.cos(ang) * hr.X * 0.88, -hr.Y * 0.65, math.sin(ang) * hr.Z * 0.88))
			end
			ell(rig, head, "ScarfEnd", Vector3.new(0.45, 0.9, 0.2) * s, a, CFrame.new(hr.X * 0.45, -hr.Y * 0.95, -hr.Z * 0.75) * CFrame.Angles(0, 0, 0.2))
		end
	end
end

---------------------------------------------------------------------
-- RARITY EFFECTS
---------------------------------------------------------------------
local FX = {
	sparkle = { tex = SPARKLE, col = nil, rate = 6, speed = 1, size = 0.5 },
	leaves  = { tex = SPARKLE, col = Color3.fromRGB(140, 255, 120), rate = 5, speed = 1, size = 0.45 },
	embers  = { tex = SPARKLE, col = Color3.fromRGB(255, 140, 40), rate = 8, speed = 3, size = 0.35, up = true },
	fire    = { tex = FIRE, col = Color3.fromRGB(255, 130, 40), rate = 18, speed = 3, size = 1.4, up = true },
	snow    = { tex = SPARKLE, col = Color3.fromRGB(220, 245, 255), rate = 8, speed = 1, size = 0.4 },
	stars   = { tex = SPARKLE, col = Color3.fromRGB(255, 240, 160), rate = 10, speed = 1.5, size = 0.6 },
	smoke   = { tex = SMOKE, col = Color3.fromRGB(80, 30, 120), rate = 10, speed = 0.8, size = 2, up = true },
	rainbow = { tex = SPARKLE, col = "rainbow", rate = 14, speed = 1.5, size = 0.55 },
	hearts  = { tex = SPARKLE, col = Color3.fromRGB(255, 120, 170), rate = 5, speed = 1, size = 0.5, up = true },
	holy    = { tex = SPARKLE, col = Color3.fromRGB(255, 240, 170), rate = 16, speed = 2, size = 0.7, up = true },
	glitch  = { tex = SPARKLE, col = "glitch", rate = 25, speed = 4, size = 0.45 },
}

local function addEffects(rig, def, rr, s)
	local body = rig.body
	local fx = def.fx and FX[def.fx]
	local order = Config.Rarities[def.rarity].order
	if fx and order >= 3 then
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = fx.tex
		if fx.col == "rainbow" then
			pe.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 80)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 100, 255)) })
		elseif fx.col == "glitch" then
			pe.Color = ColorSequence.new(Color3.fromRGB(0, 255, 200), Color3.fromRGB(255, 0, 170))
		else
			pe.Color = ColorSequence.new(fx.col or def._a)
		end
		pe.LightEmission = 1
		pe.Rate = fx.rate * (order >= 5 and 1.6 or 1)
		pe.Lifetime = NumberRange.new(0.8, 1.6)
		pe.Speed = NumberRange.new(fx.speed * 0.5, fx.speed)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Acceleration = fx.up and Vector3.new(0, 2, 0) or Vector3.new(0, -0.5, 0)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, fx.size * s), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new(0.1, 1)
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-90, 90)
		pe.Shape = Enum.ParticleEmitterShape.Sphere
		pe.Parent = body
		table.insert(rig.emitters, pe)
	end
	if order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = def.rarity == "Secret" and Color3.fromRGB(0, 255, 200) or lighten(def._a, 0.3)
		light.Range = 8 + order * 2
		light.Brightness = order >= 7 and 3 or 1.6
		light.Parent = body
		rig.light = light
	end
	if order >= 6 then
		-- glowing aura shell + orbiting motes for Mythical / Secret / Divine
		local auraCol = def.rarity == "Secret" and Color3.fromRGB(120, 0, 255) or lighten(def._a, 0.2)
		local aura = ell(rig, body, "Aura", rr * 2.6, auraCol, CFrame.identity, Enum.Material.ForceField, 0.2)
		rig.aura = aura
		local orbit, om = newPiece(rig, "Orbit", Vector3.new(0.1, 0.1, 0.1), auraCol, Enum.Material.Neon, nil, 1)
		local oe = attach(rig, body, orbit, om, CFrame.identity)
		ringOf(rig, orbit, CFrame.identity, rr.X * 1.6, order >= 8 and 8 or 5, 0.3 * s, order >= 8 and GOLD or auraCol)
		table.insert(rig.halos, oe)
	end
end

---------------------------------------------------------------------
-- BODY PLANS
---------------------------------------------------------------------
local function buildBody(rig, def, s)
	local p, sc, a = def._p, def._s, def._a
	local mat = matOf(def.mat)
	local tr = (mat == Enum.Material.Glass) and 0.25 or 0
	local root = rig.root
	local V = function(x, y, z) return Vector3.new(x, y, z) * s end
	local kind = def.body
	local body, head, br, hr, faceY, tailAnchor, wingY

	local function legs(parent, pts, size, col)
		for _, pt in ipairs(pts) do
			local e = ell(rig, parent, "Leg", size, col or darken(p, 0.08), CFrame.new(pt), nil, nil, CFrame.new(0, size.Y * 0.35, 0))
			table.insert(rig.feet, e)
		end
	end

	if kind == "round" then
		br = V(1.2, 1.1, 1.15)
		local e, part = ell(rig, root, "Body", br * 2, p, CFrame.new(0, br.Y + 0.25 * s, 0), mat, tr)
		rig.bodyEntry = e; body = part; head = part; hr = br; faceY = 0.12 * s
		ell(rig, body, "Belly", V(1.5, 1.4, 0.6), lighten(sc, 0.1), CFrame.new(0, -0.25 * s, -br.Z * 0.72))
		legs(body, { V(-0.5, -1.0, -0.45), V(0.5, -1.0, -0.45) }, V(0.7, 0.4, 0.85), darken(p, 0.1))
		for _, side in ipairs({ -1, 1 }) do
			local arm = ell(rig, body, "Arm", V(0.42, 0.6, 0.42), darken(p, 0.05), CFrame.new(side * br.X * 0.92, -0.15 * s, -0.25 * s) * CFrame.Angles(0, 0, side * 0.5), nil, nil, CFrame.new(0, 0.2 * s, 0))
			table.insert(rig.arms, { e = arm, side = side })
		end
		tailAnchor = CFrame.new(0, -0.3 * s, br.Z * 0.95); wingY = 0.25 * s
	elseif kind == "quad" then
		br = V(1.0, 0.85, 1.3)
		local e, part = ell(rig, root, "Body", br * 2, p, CFrame.new(0, 1.45 * s, 0), mat, tr)
		rig.bodyEntry = e; body = part
		ell(rig, body, "Belly", V(1.5, 1.0, 2.0), sc, CFrame.new(0, -0.35 * s, -0.1 * s))
		legs(body, { V(-0.55, -0.66, -0.8), V(0.55, -0.66, -0.8), V(-0.55, -0.66, 0.8), V(0.55, -0.66, 0.8) }, V(0.55, 0.95, 0.55))
		hr = V(0.98, 0.92, 0.92)
		local he, hpart = ell(rig, body, "Head", hr * 2, p, CFrame.new(0, 0.85 * s, -1.25 * s), mat, tr, CFrame.new(0, -0.3 * s, 0.3 * s))
		rig.headEntry = he; head = hpart; faceY = 0.12 * s
		ell(rig, head, "Snout", V(0.9, 0.55, 0.5), lighten(sc, 0.05), CFrame.new(0, -0.38 * s, -hr.Z * 0.82))
		ell(rig, head, "Nose", V(0.28, 0.2, 0.18), DARK, CFrame.new(0, -0.24 * s, -hr.Z * 1.05))
		tailAnchor = CFrame.new(0, 0.3 * s, br.Z * 0.95); wingY = 0.55 * s
	elseif kind == "bird" then
		br = V(1.1, 1.25, 1.05)
		local e, part = ell(rig, root, "Body", br * 2, p, CFrame.new(0, br.Y + 0.35 * s, 0), mat, tr)
		rig.bodyEntry = e; body = part; head = part; hr = br; faceY = 0.4 * s
		ell(rig, body, "Belly", V(1.5, 1.6, 0.6), sc, CFrame.new(0, -0.35 * s, -br.Z * 0.7))
		ell(rig, body, "Beak", V(0.55, 0.32, 0.6), Color3.fromRGB(255, 170, 50), CFrame.new(0, 0.05 * s, -br.Z * 1.0))
		legs(body, { V(-0.45, -1.25, -0.2), V(0.45, -1.25, -0.2) }, V(0.5, 0.35, 0.7), Color3.fromRGB(255, 160, 50))
		ell(rig, body, "Tuft", V(0.4, 0.7, 0.3), a, CFrame.new(0, br.Y * 0.98, -0.2 * s) * CFrame.Angles(-0.3, 0, 0))
		tailAnchor = CFrame.new(0, -0.35 * s, br.Z * 0.95); wingY = 0.1 * s
	elseif kind == "slime" then
		br = V(1.3, 1.0, 1.3)
		local e, part = ell(rig, root, "Body", br * 2, p, CFrame.new(0, 0.8 * s, 0), mat, tr)
		rig.bodyEntry = e; body = part; head = part; hr = br; faceY = 0.15 * s
		if mat == Enum.Material.Glass then
			ell(rig, body, "Core", V(0.9, 0.9, 0.9), a, CFrame.new(0, 0.05 * s, 0.2 * s), Enum.Material.Neon, 0.1)
		end
		ell(rig, body, "Shine", V(0.6, 0.3, 0.45), WHITE, CFrame.new(-0.45 * s, br.Y * 0.62, -0.5 * s) * CFrame.Angles(0, 0, 0.4), Enum.Material.Neon, 0.35)
		ell(rig, body, "Drip", V(0.5, 0.6, 0.5), p, CFrame.new(0.8 * s, -0.5 * s, -0.6 * s), mat, tr)
		tailAnchor = CFrame.new(0, 0, br.Z); wingY = 0.3 * s
	elseif kind == "ghost" then
		br = V(1.1, 1.3, 1.1)
		local e, part = ell(rig, root, "Body", br * 2, p, CFrame.new(0, 2.2 * s, 0), mat, mat == Enum.Material.Glass and 0.3 or 0.08)
		rig.bodyEntry = e; body = part; head = part; hr = br; faceY = 0.3 * s
		for i = -1, 1 do
			local w = ell(rig, body, "Wisp", V(0.7, 0.9, 0.7), lighten(p, 0.1), CFrame.new(i * 0.55 * s, -br.Y * 0.9, 0.1 * s), mat, 0.15, CFrame.new(0, 0.3 * s, 0))
			table.insert(rig.tail, w)
		end
		for _, side in ipairs({ -1, 1 }) do
			local arm = ell(rig, body, "Arm", V(0.4, 0.65, 0.4), p, CFrame.new(side * br.X * 0.95, -0.1 * s, -0.2 * s) * CFrame.Angles(0, 0, side * 0.7), mat, 0.08, CFrame.new(0, 0.25 * s, 0))
			table.insert(rig.arms, { e = arm, side = side })
		end
		tailAnchor = CFrame.new(0, -0.5 * s, br.Z); wingY = 0.4 * s
	elseif kind == "fish" then
		br = V(0.9, 0.95, 1.5)
		local e, part = ell(rig, root, "Body", br * 2, p, CFrame.new(0, 2.0 * s, 0), mat, tr)
		rig.bodyEntry = e; body = part; head = part; hr = br; faceY = 0.15 * s
		ell(rig, body, "Belly", V(1.4, 1.2, 2.4), sc, CFrame.new(0, -0.35 * s, 0))
		local dorsal = ell(rig, body, "Dorsal", V(0.15, 1.0, 1.1), a, CFrame.new(0, br.Y * 0.95, 0.2 * s) * CFrame.Angles(-0.4, 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			local fin = ell(rig, body, "Fin", V(0.9, 0.12, 0.6), a, CFrame.new(side * br.X * 0.95, -0.3 * s, -0.2 * s), nil, 0.05, CFrame.new(-side * 0.4 * s, 0, 0))
			table.insert(rig.wings, { e = fin, side = side })
		end
		tailAnchor = CFrame.new(0, 0, br.Z * 0.95); wingY = 0.2 * s
	elseif kind == "dragon" then
		br = V(1.1, 0.95, 1.5)
		local e, part = ell(rig, root, "Body", br * 2, p, CFrame.new(0, 1.7 * s, 0), mat, tr)
		rig.bodyEntry = e; body = part
		ell(rig, body, "Belly", V(1.6, 1.2, 2.4), sc, CFrame.new(0, -0.38 * s, -0.1 * s))
		legs(body, { V(-0.65, -0.78, -0.9), V(0.65, -0.78, -0.9), V(-0.65, -0.78, 0.9), V(0.65, -0.78, 0.9) }, V(0.6, 1.1, 0.6))
		ell(rig, body, "Neck", V(0.9, 1.4, 0.9), p, CFrame.new(0, 0.85 * s, -1.25 * s) * CFrame.Angles(-0.5, 0, 0), mat, tr)
		hr = V(0.85, 0.75, 0.9)
		local he, hpart = ell(rig, body, "Head", hr * 2, p, CFrame.new(0, 1.7 * s, -1.75 * s), mat, tr, CFrame.new(0, -0.3 * s, 0.3 * s))
		rig.headEntry = he; head = hpart; faceY = 0.2 * s
		ell(rig, head, "Snout", V(1.1, 0.75, 0.95), lighten(p, 0.05), CFrame.new(0, -0.3 * s, -hr.Z * 0.8), mat, tr)
		for _, side in ipairs({ -1, 1 }) do
			ell(rig, head, "Nostril", V(0.14, 0.1, 0.1), DARK, CFrame.new(side * 0.2 * s, -0.15 * s, -hr.Z * 1.25))
		end
		tailAnchor = CFrame.new(0, 0.2 * s, br.Z * 0.95); wingY = 0.75 * s
	elseif kind == "bug" then
		br = V(0.8, 0.75, 0.75)
		local e, part = ell(rig, root, "Body", br * 2, p, CFrame.new(0, 1.3 * s, 0), mat, tr)
		rig.bodyEntry = e; body = part
		ell(rig, body, "Abdomen", V(1.8, 1.7, 2.1), sc, CFrame.new(0, 0.05 * s, 1.35 * s), mat, tr)
		for i = 0, 2 do
			ell(rig, body, "Stripe", V(1.82, 0.25, 0.3), a, CFrame.new(0, 0.05 * s, (0.75 + i * 0.5) * s) * CFrame.Angles(0.3 * (i - 1), 0, 0))
		end
		for i = -1, 1 do
			for _, side in ipairs({ -1, 1 }) do
				local leg = cyl(rig, body, "Leg", V(0.12, 0.9, 0.12), DARK, CFrame.new(side * 0.6 * s, -0.55 * s, i * 0.45 * s) * CFrame.Angles(0, 0, side * 0.6), nil, nil, CFrame.new(0, 0.4 * s, 0))
				table.insert(rig.feet, leg)
			end
		end
		hr = V(0.85, 0.8, 0.8)
		local he, hpart = ell(rig, body, "Head", hr * 2, p, CFrame.new(0, 0.45 * s, -1.05 * s), mat, tr, CFrame.new(0, -0.2 * s, 0.3 * s))
		rig.headEntry = he; head = hpart; faceY = 0.1 * s
		tailAnchor = CFrame.new(0, 0, 2.3 * s); wingY = 0.7 * s
	elseif kind == "golem" then
		br = V(1.5, 1.45, 1.25)
		local e, part = ell(rig, root, "Body", br * 2, p, CFrame.new(0, 2.3 * s, 0), mat, tr)
		rig.bodyEntry = e; body = part
		for i = 1, 4 do
			ell(rig, body, "Crack", V(0.12, 0.9, 0.05), a, surface(br, (i - 2.5) * 0.5 * s, (i % 2) * 0.4 * s - 0.4 * s) * CFrame.Angles(0, 0, i * 0.7), Enum.Material.Neon)
		end
		ell(rig, body, "Chest", V(1.6, 1.3, 0.5), lighten(sc, 0.1), CFrame.new(0, -0.3 * s, -br.Z * 0.82))
		for _, side in ipairs({ -1, 1 }) do
			local arm = ell(rig, body, "Arm", V(1.0, 1.9, 1.0), darken(p, 0.1), CFrame.new(side * br.X * 1.05, 0.2 * s, 0) * CFrame.Angles(0, 0, side * 0.15), mat, tr, CFrame.new(0, 0.75 * s, 0))
			ell(rig, arm.part, "Fist", V(1.15, 0.9, 1.15), sc, CFrame.new(0, -0.95 * s, 0))
			table.insert(rig.arms, { e = arm, side = side })
		end
		legs(body, { V(-0.7, -1.55, 0), V(0.7, -1.55, 0) }, V(1.0, 1.0, 1.0), darken(p, 0.15))
		hr = V(0.85, 0.75, 0.8)
		local he, hpart = ell(rig, body, "Head", hr * 2, p, CFrame.new(0, br.Y * 1.05, -0.25 * s), mat, tr, CFrame.new(0, -0.3 * s, 0))
		rig.headEntry = he; head = hpart; faceY = 0.05 * s
		tailAnchor = CFrame.new(0, -0.5 * s, br.Z); wingY = 0.8 * s
	end

	rig.body, rig.head, rig.bodyRadius, rig.headRadius = body, head, br, hr
	buildFace(rig, head, hr, def, faceY, def.body == "golem" and 0.85 or 1)
	buildEars(rig, head, hr, def)
	buildHorns(rig, head, hr, def)
	buildTail(rig, body, tailAnchor, def, s)
	buildWings(rig, body, br, wingY, def, s)
	buildExtras(rig, head, hr, body, br, def, s)
	addEffects(rig, def, br, s)
end

---------------------------------------------------------------------
-- PUBLIC
---------------------------------------------------------------------
-- Builds a creature model. Returns (model, rig). The model's PrimaryPart is an
-- anchored invisible "Root" at ground level, facing -Z. Move it with model:PivotTo().
function Builder.Build(creatureId: string, sizeMult: number?)
	local def = CreatureData.ById[creatureId]
	assert(def, "Unknown creature " .. tostring(creatureId))
	def._p, def._s, def._a = hex(def.c[1]), hex(def.c[2]), hex(def.c[3])
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
		model = model, root = root, def = def, size = s,
		all = {}, eyes = {}, pupils = {}, ears = {}, wings = {}, tail = {}, feet = {}, arms = {},
		halos = {}, bobbers = {}, emitters = {},
	}
	buildBody(rig, def, s)
	model:SetAttribute("CreatureId", def.id)
	model:SetAttribute("Rarity", def.rarity)
	return model, rig
end

return Builder
