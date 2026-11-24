-- PetGear: puts a pet's sword and armour on its model, and draws its health bar.
-- Location: ReplicatedStorage > Shared > PetGear (ModuleScript). Pure presentation, used by the
-- renderer (followers, garden pets, menu previews) and the battle scene. Gear pieces are attached
-- like the builder's own parts (Weld + rig.all entry + SpecialMesh), so they move, animate and
-- scale with the pet, and UIKit.bakeWelds places them correctly in ViewportFrames.
local PetCombat = require(script.Parent.PetCombat)

local Gear = {}
local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles

local function piece(rig, parent, name, size, color, c0, meshType, glow)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.Anchored = false, false, false, true, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	local m = Instance.new("SpecialMesh")
	m.MeshType = meshType or Enum.MeshType.Brick
	m.Parent = p
	p:SetAttribute("PetGear", true)
	p.Parent = rig.model
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0, w.C1 = parent, p, c0, CFrame.identity
	w.Parent = p
	table.insert(rig.all, { w = w, c0 = c0, c1 = w.C1, mesh = m, part = p })
	return p
end

-- visible extent of a rig part (sphere-mesh pieces use part.Size; FileMeshes report their scale)
local function extent(part)
	local m = part:FindFirstChildOfClass("SpecialMesh")
	if m and m.MeshType == Enum.MeshType.FileMesh then
		return part.Size
	end
	return part.Size * (m and m.Scale or Vector3.one)
end

-- Solve every rig part's pose relative to the root (like UIKit.bakeWelds), without moving anything.
local function solve(rig)
	local cfs = { [rig.root] = CFrame.identity }
	local progress = true
	while progress do
		progress = false
		for _, e in ipairs(rig.all) do
			local w = e.w
			if w and w.Part0 and w.Part1 and cfs[w.Part0] and not cfs[w.Part1] then
				cfs[w.Part1] = cfs[w.Part0] * w.C0 * w.C1:Inverse()
				progress = true
			end
		end
	end
	return cfs
end

-- Bounding box (in `anchor`'s frame) of the visible parts clustered around it: the torso blocks
-- around the body core, or the head blocks around the head. Limbs, wings and tails far from the
-- core are left out so armour hugs the creature's real silhouette.
local function cluster(rig, cfs, anchor, reach, avoid)
	local base = cfs[anchor]
	if not base then return nil end
	local inv = base:Inverse()
	local lo, hi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	local found = false
	for part, cf in pairs(cfs) do
		if part ~= rig.root and part.Transparency < 0.5 and not part:GetAttribute("PetGear") then
			local rel = inv * cf
			local p = rel.Position
			local skip = math.abs(p.X) > reach.X or math.abs(p.Z) > reach.Z or p.Y < -reach.Y or p.Y > reach.Y
			if not skip and avoid then
				local q = (inv * avoid.cf).Position
				skip = (p - q).Magnitude < avoid.r
			end
			if not skip then
				local half = extent(part) / 2
				-- conservative AABB of the rotated part
				local r = rel.Rotation
				local hx = math.abs(r.RightVector.X) * half.X + math.abs(r.UpVector.X) * half.Y + math.abs(r.LookVector.X) * half.Z
				local hy = math.abs(r.RightVector.Y) * half.X + math.abs(r.UpVector.Y) * half.Y + math.abs(r.LookVector.Y) * half.Z
				local hz = math.abs(r.RightVector.Z) * half.X + math.abs(r.UpVector.Z) * half.Y + math.abs(r.LookVector.Z) * half.Z
				lo = V(math.min(lo.X, p.X - hx), math.min(lo.Y, p.Y - hy), math.min(lo.Z, p.Z - hz))
				hi = V(math.max(hi.X, p.X + hx), math.max(hi.Y, p.Y + hy), math.max(hi.Z, p.Z + hz))
				found = true
			end
		end
	end
	if not found then return nil end
	return lo, hi
end

function Gear.Clear(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("PetGear") then
			d:Destroy()
		end
	end
end

-- gear = { wp = "Iron", ar = "Gold" } (a saved creature entry works as is)
function Gear.Apply(model, rig, gear)
	if not (model and rig and rig.body and gear) then return end
	local sword = PetCombat.WeaponById[gear.wp]
	local armour = PetCombat.ArmorById[gear.ar]
	if not sword and not armour then return end
	local body = rig.body
	local b = extent(body)
	local cfs = solve(rig)
	local head = rig.head ~= body and rig.head or nil
	local headAvoid = head and cfs[head] and { cf = cfs[head], r = math.max(extent(head).X, extent(head).Y) * 0.55 } or nil
	-- torso silhouette around the body core (falls back to the core block itself)
	local lo, hi = cluster(rig, cfs, body, b * 0.5 + V(0.05, 0.05, 0.05), headAvoid)
	lo = lo or -b / 2
	hi = hi or b / 2
	local size = hi - lo
	local mid = (lo + hi) / 2
	local s = math.clamp(math.max(size.X, size.Y, size.Z), 0.6, 8)
	if armour then
		local tier = armour.tier
		local t = math.max(0.12, s * 0.06)
		-- saddle-style breastplate over the back, trim band, side plates hanging down the flanks
		piece(rig, body, "ArmourBack", V(size.X * 0.9, t, size.Z * 0.62), armour.color, CF(mid.X, hi.Y + t * 0.3, mid.Z), nil, false)
		piece(rig, body, "ArmourTrim", V(size.X * 0.94, t * 0.6, size.Z * 0.12), armour.trim, CF(mid.X, hi.Y + t * 0.45, mid.Z - size.Z * 0.31), nil, armour.glow)
		for _, sx in { -1, 1 } do
			local x = sx > 0 and hi.X or lo.X
			piece(rig, body, "ArmourSide", V(t, size.Y * 0.5, size.Z * 0.56), armour.color, CF(x + sx * t * 0.3, mid.Y + size.Y * 0.15, mid.Z), nil, false)
			piece(rig, body, "ArmourSideTrim", V(t * 1.05, t * 0.6, size.Z * 0.58), armour.trim, CF(x + sx * t * 0.35, mid.Y - size.Y * 0.1, mid.Z), nil, armour.glow)
			if tier >= 3 then
				piece(rig, body, "ArmourStud", V(t * 1.6, t * 1.6, t * 1.6), armour.trim, CF(x + sx * t * 0.6, mid.Y + size.Y * 0.2, mid.Z), Enum.MeshType.Sphere, armour.glow)
			end
		end
		if head and cfs[head] then
			local h = extent(head)
			local hlo, hhi = cluster(rig, cfs, head, V(h.X * 0.6, h.Y * 0.45, h.Z * 0.6), nil) -- ears/horns sit above and stay out
			hlo, hhi = hlo or -h / 2, hhi or h / 2
			local hs, hm = hhi - hlo, (hlo + hhi) / 2
			local ht = math.max(0.1, math.max(hs.X, hs.Z) * 0.12)
			piece(rig, head, "Helmet", V(hs.X * 0.82, ht, hs.Z * 0.82), armour.color, CF(hm.X, hhi.Y + ht * 0.3, hm.Z), nil, false)
			piece(rig, head, "HelmetBand", V(hs.X * 0.86, ht * 0.55, hs.Z * 0.86), armour.trim, CF(hm.X, hhi.Y - ht * 0.2, hm.Z), nil, armour.glow)
			if tier >= 4 then
				piece(rig, head, "HelmetCrest", V(ht * 0.8, hs.Y * 0.35, hs.Z * 0.55), armour.trim, CF(hm.X, hhi.Y + hs.Y * 0.18, hm.Z), nil, armour.glow)
			end
		end
	end
	if sword then
		-- carried on the right side, blade raised and angled forward
		local len = math.clamp(s * 0.85, 0.8, 7)
		s = math.clamp(s * 0.8, 0.6, 7)
		local hilt = CF(hi.X + s * 0.08, mid.Y, mid.Z - size.Z * 0.15) * ANG(-0.55, 0, -0.18)
		piece(rig, body, "SwordGrip", V(s * 0.09, s * 0.26, s * 0.09), sword.trim, hilt, Enum.MeshType.Cylinder, false)
		piece(rig, body, "SwordGuard", V(s * 0.34, s * 0.07, s * 0.11), sword.trim, hilt * CF(0, s * 0.15, 0), nil, sword.glow)
		piece(rig, body, "SwordBlade", V(s * 0.13, len, s * 0.04), sword.color, hilt * CF(0, s * 0.18 + len / 2, 0), nil, sword.glow)
		piece(rig, body, "SwordTip", V(s * 0.04, s * 0.13, s * 0.13), sword.color, hilt * CF(0, s * 0.18 + len + s * 0.05, 0) * ANG(0, math.pi / 2, 0), Enum.MeshType.Wedge, sword.glow)
	end
end

-- compact health bar + attack for a pet in the world (BillboardGui above the model)
function Gear.HealthBar(adornee, offsetY, hp, maxHp, atk)
	local bb = Instance.new("BillboardGui")
	bb.Name = "PetHealth"
	bb.Size = UDim2.fromOffset(92, 22)
	bb.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.ResetOnSpawn = false
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Position = UDim2.new(0.5, 0, 0, 0)
	back.Size = UDim2.new(1, 0, 0, 9)
	back.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
	back.BorderSizePixel = 0
	back.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(14, 10, 20)
	stroke.Thickness = 1.2
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(96, 214, 110)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	corner:Clone().Parent = fill
	local text = Instance.new("TextLabel")
	text.Name = "Stats"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(0, 9)
	text.Size = UDim2.new(1, 0, 0, 13)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 11
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.35
	text.Parent = bb
	bb.Parent = adornee
	Gear.SetHealth(bb, hp, maxHp, atk)
	return bb
end

function Gear.SetHealth(bb, hp, maxHp, atk)
	if not bb then return end
	local back = bb:FindFirstChild("Back")
	local fill = back and back:FindFirstChild("Fill")
	local frac = (maxHp and maxHp > 0) and math.clamp((hp or maxHp) / maxHp, 0, 1) or 1
	if fill then
		fill.Size = UDim2.fromScale(frac, 1)
		fill.BackgroundColor3 = frac > 0.5 and Color3.fromRGB(96, 214, 110)
			or (frac > 0.25 and Color3.fromRGB(240, 196, 70) or Color3.fromRGB(235, 80, 70))
	end
	local text = bb:FindFirstChild("Stats")
	if text then
		text.Text = string.format("HP %s   ATK %s", Gear.Short(hp or maxHp or 0), Gear.Short(atk or 0))
	end
end

function Gear.Short(n)
	n = math.floor(tonumber(n) or 0)
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

return Gear
