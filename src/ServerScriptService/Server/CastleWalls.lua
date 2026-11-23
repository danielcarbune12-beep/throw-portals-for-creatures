-- CastleWalls: the Portal Sanctuary becomes a fortified castle courtyard.
-- Location: ServerScriptService > Server > CastleWalls (ModuleScript)
--
-- Curtain walls with a battered base, string course, wall-walk and crenellated parapets run along both
-- sides of the hub (just outside the walkable area at |X| = 105), with round flanking towers, a great
-- gatehouse closing the far end, and iron braziers with real fire. All of it is scenery outside the
-- play space: anchored, CanQuery = false, so throws, raycasts and interaction are untouched.

local CollectionService = game:GetService("CollectionService")

local W = {}

local STONE = Color3.fromRGB(138, 134, 126)
local STONE_DARK = Color3.fromRGB(104, 100, 94)
local STONE_LIGHT = Color3.fromRGB(158, 152, 142)
local IRON = Color3.fromRGB(46, 44, 42)
local OAK = Color3.fromRGB(86, 60, 38)

local X = 112 -- wall centreline (both sides)
local Z_BACK = -482
local H = 26 -- wall height to the wall-walk
local T = 8 -- wall thickness

local folder
local function part(name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Material = mat or Enum.Material.Cobblestone
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CastShadow = math.max(size.X, size.Y, size.Z) >= 3
	if shape then p.Shape = shape end
	p.Parent = folder
	return p
end

-- crenellated parapet along a straight run (local X axis of cf), merlons on one face
local function parapet(cf, length, face)
	local merlonW, gap, mh = 2.6, 1.8, 3.2
	part("Parapet", Vector3.new(length, 1.4, 1.2), cf * CFrame.new(0, 0.7, face * (T / 2 - 0.6)), STONE, Enum.Material.Cobblestone)
	local n = math.floor((length + gap) / (merlonW + gap))
	local start = -((n - 1) * (merlonW + gap)) / 2
	for i = 0, n - 1 do
		part("Merlon", Vector3.new(merlonW, mh, 1.3), cf * CFrame.new(start + i * (merlonW + gap), 1.4 + mh / 2, face * (T / 2 - 0.65)), STONE_LIGHT, Enum.Material.Cobblestone)
	end
end

-- one straight curtain wall run between two points on the ground (y = 0)
local function curtain(a, b)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, mid + (b - a).Unit) * CFrame.Angles(0, math.pi / 2, 0) -- local X along the run
	part("WallBatter", Vector3.new(len, 3.2, T + 2.4), cf * CFrame.new(0, 1.6, 0), STONE_DARK, Enum.Material.Rock)
	part("Wall", Vector3.new(len, H - 3.2, T), cf * CFrame.new(0, 3.2 + (H - 3.2) / 2, 0), STONE, Enum.Material.Cobblestone)
	part("StringCourse", Vector3.new(len, 0.9, T + 0.8), cf * CFrame.new(0, H - 4, 0), STONE_LIGHT, Enum.Material.Slate)
	local walk = cf * CFrame.new(0, H, 0)
	part("WallWalk", Vector3.new(len, 0.6, T), walk * CFrame.new(0, 0.3, 0), STONE_DARK, Enum.Material.Slate)
	parapet(walk, len, 1)
	parapet(walk, len, -1)
	return cf
end

local function arrowSlit(cf)
	part("ArrowSlit", Vector3.new(0.5, 3.4, 0.4), cf, Color3.fromRGB(26, 24, 24), Enum.Material.Slate)
	part("SlitCross", Vector3.new(1.6, 0.45, 0.4), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(26, 24, 24), Enum.Material.Slate)
end

-- round flanking tower: plinth, shaft, corbel ring, crenellated crown, banner pole
local function tower(pos, r, h)
	local up = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis = Y
	part("TowerPlinth", Vector3.new(4, r * 2 + 3, r * 2 + 3), up * CFrame.new(2, 0, 0), STONE_DARK, Enum.Material.Rock, Enum.PartType.Cylinder)
	part("TowerShaft", Vector3.new(h, r * 2, r * 2), up * CFrame.new(h / 2, 0, 0), STONE, Enum.Material.Cobblestone, Enum.PartType.Cylinder)
	part("TowerCorbel", Vector3.new(1.6, r * 2 + 2, r * 2 + 2), up * CFrame.new(h - 0.8, 0, 0), STONE_LIGHT, Enum.Material.Slate, Enum.PartType.Cylinder)
	part("TowerFloor", Vector3.new(0.6, r * 2 + 1.6, r * 2 + 1.6), up * CFrame.new(h + 0.3, 0, 0), STONE_DARK, Enum.Material.Slate, Enum.PartType.Cylinder)
	local count = math.max(8, math.floor(r * 1.3))
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2
		local c = CFrame.new(pos + Vector3.new(0, h + 2.2, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -(r + 0.4))
		if i % 2 == 0 then
			part("TowerMerlon", Vector3.new(2.4, 3.4, 1.4), c, STONE_LIGHT, Enum.Material.Cobblestone)
		end
	end
	-- arrow slits on three faces, two levels
	for _, lvl in ipairs({ h * 0.38, h * 0.7 }) do
		for _, a in ipairs({ 0, 2.1, 4.2 }) do
			arrowSlit(CFrame.new(pos + Vector3.new(0, lvl, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r - 0.05))
		end
	end
	-- banner pole with a hanging pennant (sways via WorldFx)
	part("FlagPole", Vector3.new(0.35, 9, 0.35), CFrame.new(pos + Vector3.new(0, h + 5, 0)), IRON, Enum.Material.Metal)
	local flag = part("TowerBanner", Vector3.new(0.12, 4.6, 3.2), CFrame.new(pos + Vector3.new(0, h + 6.8, 1.7)), Color3.fromRGB(42, 52, 86), Enum.Material.Fabric)
	CollectionService:AddTag(flag, "TPFC_Sway")
	flag:SetAttribute("Period", 3.5 + math.random() * 2)
	flag:SetAttribute("Amp", 0.05)
	part("BannerCrest", Vector3.new(0.14, 1.2, 1.2), flag.CFrame * CFrame.new(-0.02, 0.4, 0) * CFrame.Angles(math.rad(45), 0, 0), Color3.fromRGB(214, 176, 92), Enum.Material.Metal)
end

-- iron brazier on the wall-walk with real fire and a warm light
local braziers = 0
local function brazier(pos)
	if braziers >= 16 then return end
	braziers += 1
	part("BrazierStand", Vector3.new(0.5, 2.2, 0.5), CFrame.new(pos + Vector3.new(0, 1.1, 0)), IRON, Enum.Material.Metal)
	local bowl = part("BrazierBowl", Vector3.new(1, 2.4, 2.4), CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
	local fire = Instance.new("Fire")
	fire.Size = 3.2
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 150, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 18
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = bowl
end

-- the great gatehouse closing the far end of the courtyard
local function gatehouse(z)
	local gh = H + 8
	local cf = CFrame.new(0, 0, z)
	-- side wall runs from the corner towers to the gate towers
	local gateHalf = 16
	curtain(Vector3.new(-X, 0, z), Vector3.new(-gateHalf - 6, 0, z))
	curtain(Vector3.new(gateHalf + 6, 0, z), Vector3.new(X, 0, z))
	-- gate block with a pointed arch opening
	-- solid masonry from the arch jambs (|x| = 11) out to the side walls (|x| = 22)
	part("GateBlockL", Vector3.new(11, gh, T + 4), cf * CFrame.new(-16.5, gh / 2, 0), STONE, Enum.Material.Cobblestone)
	part("GateBlockR", Vector3.new(11, gh, T + 4), cf * CFrame.new(16.5, gh / 2, 0), STONE, Enum.Material.Cobblestone)
	part("GateLintel", Vector3.new(gateHalf * 2 + 12, gh - 22, T + 4), cf * CFrame.new(0, 22 + (gh - 22) / 2, 0), STONE, Enum.Material.Cobblestone)
	-- pointed arch voussoirs (two leaning ribs) and a keystone
	for _, sd in ipairs({ -1, 1 }) do
		part("ArchRib", Vector3.new(2.4, 14, T + 4.4), cf * CFrame.new(sd * 6.2, 15.5, 0) * CFrame.Angles(0, 0, sd * math.rad(28)), STONE_LIGHT, Enum.Material.Slate)
		part("Jamb", Vector3.new(2.2, 9.6, T + 4.4), cf * CFrame.new(sd * 9.9, 4.8, 0), STONE_LIGHT, Enum.Material.Slate)
		-- spandrel: fills between the leaning rib and the gate block so the arch reads solid
		part("Spandrel", Vector3.new(3.4, 12.4, T + 4), cf * CFrame.new(sd * 9.3, 15.8, 0), STONE, Enum.Material.Cobblestone)
	end
	part("Keystone", Vector3.new(2.6, 3.2, T + 4.8), cf * CFrame.new(0, 21.6, 0), STONE_LIGHT, Enum.Material.Slate)
	-- recessed oak doors behind a raised iron portcullis
	part("GateDoorL", Vector3.new(9.6, 22, 1), cf * CFrame.new(-4.6, 11, 2.6) * CFrame.Angles(0, math.rad(-18), 0), OAK, Enum.Material.WoodPlanks)
	part("GateDoorR", Vector3.new(9.6, 22, 1), cf * CFrame.new(4.6, 11, 2.6) * CFrame.Angles(0, math.rad(18), 0), OAK, Enum.Material.WoodPlanks)
	for i = -3, 3 do
		part("PortcullisBar", Vector3.new(0.4, 7, 0.4), cf * CFrame.new(i * 2.4, 18.5, -1.4), IRON, Enum.Material.Metal)
	end
	for j = 0, 2 do
		part("PortcullisRail", Vector3.new(16, 0.4, 0.4), cf * CFrame.new(0, 15.6 + j * 2.6, -1.4), IRON, Enum.Material.Metal)
	end
	local walk = cf * CFrame.new(0, gh, 0)
	parapet(walk, gateHalf * 2 + 12, 1)
	parapet(walk, gateHalf * 2 + 12, -1)
	-- gate towers
	tower(Vector3.new(-gateHalf - 8, 0, z - 2), 8, gh + 8)
	tower(Vector3.new(gateHalf + 8, 0, z - 2), 8, gh + 8)
	brazier(Vector3.new(-gateHalf - 1, gh + 0.6, z - 3))
	brazier(Vector3.new(gateHalf + 1, gh + 0.6, z - 3))
end

-- The hub is already bounded by tall limestone terrace blocks (|X| ~ 92..125). Rather than build a second
-- wall into them, they become the castle's curtain: battlements along each block's courtyard-facing
-- top edge, and round towers set half into the terraces.
local function terraceBlocks()
	local list = {}
	local start = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Start")
	if not start then return list end
	for _, p in ipairs(start:GetDescendants()) do
		if p:IsA("Part") and p.Material == Enum.Material.Limestone and p.Transparency < 0.5 and p.CFrame.UpVector.Y > 0.99 then
			local cf, sz = p.CFrame, p.Size
			local half = (cf.RightVector * sz.X / 2):Abs() + (cf.UpVector * sz.Y / 2):Abs() + (cf.LookVector * sz.Z / 2):Abs()
			local x = cf.Position.X
			if math.abs(x) > 92 and math.abs(x) < 125 and half.Y * 2 >= 15 and cf.Position.Z < -10 and cf.Position.Z > -480 then
				table.insert(list, { pos = cf.Position, half = half, side = x > 0 and 1 or -1 })
			end
		end
	end
	return list
end

local function crenellateTerraces(blocks)
	local merlonW, gap, mh = 2.6, 1.8, 3
	for _, b in ipairs(blocks) do
		local top = b.pos.Y + b.half.Y + 2 -- grass caps sit ~2 studs proud on top
		local innerX = b.pos.X - b.side * b.half.X
		local z1, z2 = b.pos.Z - b.half.Z, b.pos.Z + b.half.Z
		local len = z2 - z1
		part("TerraceParapet", Vector3.new(1.3, 1.2, len), CFrame.new(innerX + b.side * 0.65, top + 0.6, (z1 + z2) / 2), STONE, Enum.Material.Cobblestone)
		local n = math.floor((len + gap) / (merlonW + gap))
		local start = (z1 + z2) / 2 - ((n - 1) * (merlonW + gap)) / 2
		for i = 0, n - 1 do
			part("Merlon", Vector3.new(1.4, mh, merlonW), CFrame.new(innerX + b.side * 0.7, top + 1.2 + mh / 2, start + i * (merlonW + gap)), STONE_LIGHT, Enum.Material.Cobblestone)
		end
	end
end

function W.Build(parentFolder)
	local old = (parentFolder or workspace):FindFirstChild("CastleWalls")
	if old then old:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "CastleWalls"
	folder.Parent = parentFolder or workspace
	braziers = 0
	local blocks = terraceBlocks()
	crenellateTerraces(blocks)
	-- towers set into the terraces at intervals; height clears the local terrace top
	for _, sd in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -60, -170, -280, -390 }) do
			local innerX, top = sd * 104, 0
			for _, b in ipairs(blocks) do
				if b.side == sd and math.abs(z - b.pos.Z) <= b.half.Z then
					innerX = b.pos.X - sd * b.half.X
					top = math.max(top, b.pos.Y + b.half.Y)
				end
			end
			if top > 0 then
				tower(Vector3.new(innerX + sd * 4, 0, z), 7.5, top + 12)
				brazier(Vector3.new(innerX + sd * 1.6, top + 2, z + sd * 14))
			end
		end
	end
	gatehouse(Z_BACK)
	-- corner towers where the gatehouse curtain meets the side terraces
	tower(Vector3.new(-X, 0, Z_BACK), 9, H + 10)
	tower(Vector3.new(X, 0, Z_BACK), 9, H + 10)
	return folder
end

return W
