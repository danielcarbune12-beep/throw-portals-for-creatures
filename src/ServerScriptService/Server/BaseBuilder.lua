-- BaseBuilder: builds eight Skyforge courtyards and owned decorations.
-- Location: ServerScriptService > Server > BaseBuilder (ModuleScript)
--
-- Open timber lodge, portal shrine, floating relic pavilion and expedition map table.
-- Original slot, collect-pad and spawn references remain stable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local SkyforgeStyle = require(script.Parent.SkyforgeStyle)
local SkyforgeDetails = require(script.Parent.SkyforgeDetails)

local BaseBuilder = {}
BaseBuilder.Bases = {}

local DECOR_SPOTS = {
	Vector3.new(-30, 0, -4),
	Vector3.new(30, 0, -4),
	Vector3.new(-30, 0, 9),
	Vector3.new(30, 0, 9),
	Vector3.new(-7, 0, 29),
	Vector3.new(7, 0, 29),
	Vector3.new(0, 0, 22),
	Vector3.new(0, 22, 4),
}

---------------------------------------------------------------- helpers
local function part(parent, size, cf, color, mat, collide, shape, transp)
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanQuery, p.CanTouch = false, false
	p.CanCollide = collide ~= false
	p.Transparency = transp or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function sphereMesh(p)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end
local function ball(parent, d, cf, color, mat, collide)
	return sphereMesh(part(parent, Vector3.new(d, d, d), cf, color, mat, collide))
end
local function vcylCF(cf, h, d)
	return cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(h, d, d)
end
local function cyl(parent, cf, h, d, color, mat, collide, transp)
	local c, s = vcylCF(cf, h, d)
	return part(parent, s, c, color, mat, collide, Enum.PartType.Cylinder, transp)
end
local function light(p, color, range, b)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = b or 1.4
	l.Parent = p
	return l
end

---------------------------------------------------------------- one base
local function buildBase(index)
	return require(script.Parent.SanctuaryBase).Build(index)
end

---------------------------------------------------------------- decorations
local DecorBuild = {}
local function D(base, spot)
	return base.cf * CFrame.new(spot)
end

function DecorBuild.FlowerBed(f, cf)
	-- stone border + soil + three distinct flower shapes (tulip, daisy, bell) with leaves
	part(
		f,
		Vector3.new(8.4, 0.8, 4.4),
		cf * CFrame.new(0, 1.3, 0),
		Color3.fromRGB(175, 170, 165),
		Enum.Material.Cobblestone
	)
	part(
		f,
		Vector3.new(7.6, 0.3, 3.6),
		cf * CFrame.new(0, 1.75, 0),
		Color3.fromRGB(95, 65, 45),
		Enum.Material.Ground,
		false
	)
	for i = 1, 9 do
		local x, z = -3 + (i - 1) % 5 * 1.5, i > 5 and 0.9 or -0.9
		local base = cf * CFrame.new(x, 1.9, z)
		part(f, Vector3.new(0.15, 1.1, 0.15), base * CFrame.new(0, 0.55, 0), Color3.fromRGB(70, 150, 60), nil, false)
		ball(
			f,
			1,
			base * CFrame.new(0.25, 0.35, 0) * CFrame.Angles(0, 0, -0.6),
			Color3.fromRGB(90, 180, 70),
			Enum.Material.Grass,
			false
		).Size =
			Vector3.new(0.6, 0.2, 0.35)
		local kind = i % 3
		local col = Color3.fromHSV((i * 0.13) % 1, 0.55, 1)
		if kind == 0 then -- tulip cup
			ball(f, 1, base * CFrame.new(0, 1.25, 0), col, nil, false).Size = Vector3.new(0.55, 0.75, 0.55)
		elseif kind == 1 then -- daisy: petal disc + centre
			part(
				f,
				Vector3.new(0.12, 0.95, 0.95),
				base * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(255, 252, 245),
				nil,
				false,
				Enum.PartType.Cylinder
			)
			ball(f, 0.35, base * CFrame.new(0, 1.28, 0), Color3.fromRGB(255, 210, 60), nil, false)
		else -- bell: drooping bloom
			ball(f, 1, base * CFrame.new(0.2, 1.05, 0), col, nil, false).Size = Vector3.new(0.45, 0.55, 0.45)
		end
	end
end
function DecorBuild.Lanterns(f, cf)
	-- real post + bracket + caged lantern bodies (warm glass inserts); one light per pair
	for s = -1, 1, 2 do
		local base = cf * CFrame.new(s * 2.5, 0, 0)
		part(
			f,
			Vector3.new(1.2, 0.6, 1.2),
			base * CFrame.new(0, 1.3, 0),
			Color3.fromRGB(70, 60, 80),
			Enum.Material.Metal
		)
		part(f, Vector3.new(0.4, 7, 0.4), base * CFrame.new(0, 4.6, 0), Color3.fromRGB(60, 50, 70), Enum.Material.Metal)
		part(
			f,
			Vector3.new(1.6, 0.25, 0.25),
			base * CFrame.new(-s * 0.6, 8, 0),
			Color3.fromRGB(60, 50, 70),
			Enum.Material.Metal,
			false
		)
		local lcf = base * CFrame.new(-s * 1.3, 6.9, 0)
		local glass = part(f, Vector3.new(0.9, 1.3, 0.9), lcf, Color3.fromRGB(255, 190, 110), Enum.Material.Neon, false)
		for _, c in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
			part(
				f,
				Vector3.new(0.12, 1.5, 0.12),
				lcf * CFrame.new(c[1] * 0.5, 0, c[2] * 0.5),
				Color3.fromRGB(45, 38, 50),
				Enum.Material.Metal,
				false
			)
		end
		part(
			f,
			Vector3.new(1.2, 0.3, 1.2),
			lcf * CFrame.new(0, 0.8, 0),
			Color3.fromRGB(45, 38, 50),
			Enum.Material.Metal,
			false
		)
		if s == 1 then
			light(glass, Color3.fromRGB(255, 190, 110), 16)
		end
	end
end
function DecorBuild.MushroomRing(f, cf)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local p = cf * CFrame.new(math.cos(a) * 2.6, 1, math.sin(a) * 2.6)
		part(f, Vector3.new(0.6, 1.6, 0.6), p * CFrame.new(0, 0.8, 0), Color3.fromRGB(245, 235, 220), nil, false)
		ball(f, 1, p * CFrame.new(0, 1.8, 0), Color3.fromHSV(0.8 + i * 0.03, 0.7, 1), Enum.Material.Neon, false).Size =
			Vector3.new(1.8, 1, 1.8)
	end
end
function DecorBuild.Fountain(f, cf)
	cyl(f, cf * CFrame.new(0, 1, 0), 1.6, 7, Color3.fromRGB(220, 220, 235), Enum.Material.Marble, true)
	cyl(f, cf * CFrame.new(0, 2.5, 0), 0.2, 6, Color3.fromRGB(90, 190, 255), Enum.Material.Glass, false, 0.3)
	local orb = ball(f, 2.4, cf * CFrame.new(0, 5.5, 0), Color3.fromRGB(150, 110, 255), Enum.Material.Neon, false)
	light(orb, Color3.fromRGB(150, 110, 255), 16)
end
function DecorBuild.CrystalTree(f, cf)
	part(f, Vector3.new(1.4, 8, 1.4), cf * CFrame.new(0, 5, 0), Color3.fromRGB(230, 230, 255), Enum.Material.Glass)
	local last
	for i = 1, 7 do
		local a = i * 0.9
		last = part(
			f,
			Vector3.new(1, 3.5, 1),
			cf
				* CFrame.new(math.cos(a) * 2, 8 + (i % 3), math.sin(a) * 2)
				* CFrame.Angles(math.cos(a) * 0.6, 0, math.sin(a) * 0.6),
			Color3.fromHSV(0.55 + i * 0.05, 0.6, 1),
			Enum.Material.Neon,
			false
		)
	end
	light(last, Color3.fromRGB(150, 200, 255), 20)
end
function DecorBuild.Statue(f, cf)
	-- an original sitting fox-like creature sculpted from masses, on a plinth with an inscription plate
	local gold = Color3.fromRGB(255, 200, 60)
	part(f, Vector3.new(4.4, 1.6, 4.4), cf * CFrame.new(0, 1.8, 0), Color3.fromRGB(230, 230, 235), Enum.Material.Marble)
	part(f, Vector3.new(3.8, 0.4, 3.8), cf * CFrame.new(0, 2.8, 0), Color3.fromRGB(210, 210, 218), Enum.Material.Marble)
	part(f, Vector3.new(2.2, 0.7, 0.15), cf * CFrame.new(0, 1.9, -2.25), gold, Enum.Material.Metal, false)
	local s = cf * CFrame.new(0, 3, 0)
	ball(f, 1, s * CFrame.new(0, 1.3, 0.3), gold, Enum.Material.Metal).Size = Vector3.new(2.2, 2.4, 2.6) -- seated body
	ball(f, 1, s * CFrame.new(0, 2.9, -0.6), gold, Enum.Material.Metal).Size = Vector3.new(1.7, 1.5, 1.6) -- head
	ball(f, 1, s * CFrame.new(0, 2.6, -1.4), gold, Enum.Material.Metal, false).Size = Vector3.new(0.8, 0.6, 0.9) -- muzzle
	for side = -1, 1, 2 do
		local ear = part(
			f,
			Vector3.new(0.5, 1.1, 0.3),
			s * CFrame.new(side * 0.55, 3.9, -0.5) * CFrame.Angles(0, 0, -side * 0.35),
			gold,
			Enum.Material.Metal,
			false
		)
		ear.Shape = Enum.PartType.Block
		ball(f, 1, s * CFrame.new(side * 0.6, 0.4, -0.9), gold, Enum.Material.Metal, false).Size =
			Vector3.new(0.7, 0.6, 1.1) -- front paws
	end
	ball(f, 1, s * CFrame.new(1.2, 0.7, 1.2) * CFrame.Angles(0, 0.6, 0), gold, Enum.Material.Metal, false).Size =
		Vector3.new(0.9, 0.9, 2.6) -- curled tail
end
function DecorBuild.Rainbow(f, cf)
	-- continuous seven-band arch with cloud feet and neat end caps
	local cols = {
		Color3.fromRGB(255, 80, 80),
		Color3.fromRGB(255, 160, 50),
		Color3.fromRGB(255, 230, 70),
		Color3.fromRGB(90, 220, 110),
		Color3.fromRGB(80, 170, 255),
		Color3.fromRGB(110, 100, 255),
		Color3.fromRGB(200, 100, 255),
	}
	local segs = 14
	for b, col in ipairs(cols) do
		local r = 6.2 - b * 0.42
		for i = 1, segs do
			local a0, a1 = (i - 1) / segs * math.pi, i / segs * math.pi
			local p0 = Vector3.new(math.cos(a0) * r, math.sin(a0) * r, 0)
			local p1 = Vector3.new(math.cos(a1) * r, math.sin(a1) * r, 0)
			local mid = (p0 + p1) / 2
			part(
				f,
				Vector3.new(0.45, (p1 - p0).Magnitude + 0.08, 0.6),
				cf * CFrame.new(0, 1.2, 0) * CFrame.new(mid) * CFrame.Angles(0, 0, (a0 + a1) / 2),
				col,
				Enum.Material.Neon,
				false
			)
		end
	end
	for s = -1, 1, 2 do
		for k = 0, 2 do
			ball(
				f,
				1,
				cf * CFrame.new(s * (4.6 + k * 0.5 - 0.5), 1.4 + (k % 2) * 0.3, (k - 1) * 0.7),
				Color3.fromRGB(255, 255, 255),
				nil,
				false
			).Size =
				Vector3.new(2, 1.4, 1.8)
		end
	end
end
function DecorBuild.FloatingIsland(f, cf)
	ball(f, 1, cf, Color3.fromRGB(120, 90, 70), Enum.Material.Slate, false).Size = Vector3.new(12, 5, 10)
	ball(f, 1, cf * CFrame.new(0, 2, 0), Color3.fromRGB(110, 210, 90), Enum.Material.Grass, false).Size =
		Vector3.new(12, 1.5, 10)
	part(
		f,
		Vector3.new(0.8, 4, 0.8),
		cf * CFrame.new(0, 4.5, 0),
		Color3.fromRGB(120, 80, 50),
		Enum.Material.Wood,
		false
	)
	ball(f, 1, cf * CFrame.new(0, 7, 0), Color3.fromRGB(255, 160, 210), Enum.Material.Grass, false).Size =
		Vector3.new(4.5, 4, 4.5)
end

---------------------------------------------------------------- public API
function BaseBuilder.BuildAll()
	for _, old in ipairs(workspace:GetChildren()) do
		if
			old.Name == "Bases"
			and old:IsA("Folder")
			and (old:GetAttribute("TPFCGenerated") or old:FindFirstChild("Base1"))
		then
			old:Destroy()
		end
	end
	BaseBuilder.Bases = {}
	local f = Instance.new("Folder")
	f.Name = "Bases"
	f.Parent = workspace
	f:SetAttribute("TPFCGenerated", true)
	for i = 1, Config.MaxBases do
		BaseBuilder.Bases[i] = buildBase(i)
		task.wait()
	end
end

function BaseBuilder.Claim(player)
	for _, b in ipairs(BaseBuilder.Bases) do
		if not b.owner then
			b.owner = player
			for _, l in ipairs(b.signLabels) do
				l.Text = player.DisplayName .. "'s Courtyard"
			end
			b.model:SetAttribute("OwnerId", player.UserId)
			return b
		end
	end
	return nil
end

function BaseBuilder.Release(base)
	base.owner = nil
	for _, l in ipairs(base.signLabels) do
		l.Text = "Available courtyard"
	end
	base.model:SetAttribute("OwnerId", nil)
	BaseBuilder.Refresh(
		base,
		{ Decor = {}, FloorTheme = "Meadow", EquipLevel = 1, Upgrades = { Training = 0, BaseSlots = 0 } }
	)
	base.collectLabel.Text = "$0"
	if base.setFill then
		base.setFill(0)
	end
end

-- Refresh owned decorations, floor theme, earned relics and pet slot markers.
function BaseBuilder.Refresh(base, data)
	base.decor:ClearAllChildren()
	for i, id in ipairs(Config.DecorOrder) do
		if data.Decor[id] and DecorBuild[id] then
			local holder = Instance.new("Folder")
			holder.Name = id
			holder.Parent = base.decor
			DecorBuild[id](holder, D(base, DECOR_SPOTS[i]))
		end
	end
	for _, theme in ipairs(Config.FloorThemes) do
		if theme.id == data.FloorTheme then
			base.floor.Color = theme.id == "Meadow" and SkyforgeStyle.grass or theme.color
			base.floor.Material = theme.material
		end
	end
	SkyforgeDetails.RefreshRelics(base, data.ExpeditionRelics or {})
	base.gymLabel.Text = "Expeditions"
	base.crystalLabel.Text = ""
	local slotsOpen = Config.StartSlots + data.Upgrades.BaseSlots
	for i = 1, #base.slots do
		local ring = base.slotFolder:FindFirstChild("SlotRing" .. i)
		local pad = base.slotFolder:FindFirstChild("Slot" .. i)
		local open = i <= slotsOpen
		if ring then
			ring.Color = open and SkyforgeStyle.gold or SkyforgeStyle.stone
			ring.Material = Enum.Material.SmoothPlastic
			ring.Transparency = open and 0.15 or 0.88
		end
		if pad then
			pad.Transparency = open and 0.20 or 0.93
		end
	end
end

return BaseBuilder
