-- Waterfalls: turns the flat water panels in the sanctuary into living waterfalls.
-- Location: ServerScriptService > Server > Waterfalls (ModuleScript)
--
-- For each fall: rocks breaking the lip, a sheet of falling water streaks (particles stretched along
-- their motion), foam and rolling spray where it lands, and for the great back fall a real terrain-water
-- plunge pool with a rock rim. Emitters are tagged TPFC_EnvironmentEmitter so WorldFx switches them off
-- far from the camera and on low graphics. Scenery only: anchored, CanCollide/CanQuery off.

local CollectionService = game:GetService("CollectionService")

local F = {}

local ROCK = Color3.fromRGB(156, 150, 140)
local ROCK_DARK = Color3.fromRGB(128, 124, 116)
local FOAM = Color3.fromRGB(236, 244, 250)
local WATER = Color3.fromRGB(196, 226, 240)

local folder
local function part(name, size, cf, color, mat, transp)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Material = mat or Enum.Material.Rock
	p.Transparency = transp or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CastShadow = (transp or 0) < 0.5 and math.max(size.X, size.Y, size.Z) >= 2
	p.Parent = folder
	return p
end

local function emitter(host, props, baseRate)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do e[k] = v end
	e.Rate = baseRate
	e:SetAttribute("BaseRate", baseRate)
	e.Parent = host
	CollectionService:AddTag(e, "TPFC_EnvironmentEmitter")
	return e
end

-- a few tumbled boulders along an edge (deterministic per fall so it looks authored, not noisy)
local function boulders(center, right, normal, width, count, scale, seed)
	local rng = Random.new(seed)
	for i = 1, count do
		local t = (i - 0.5) / count - 0.5
		local s = scale * (0.7 + rng:NextNumber() * 0.6)
		local pos = center + right * (t * width + rng:NextNumber(-0.4, 0.4) * scale) + normal * rng:NextNumber(-0.2, 0.5) * scale
		local cf = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5))
		part("Boulder", Vector3.new(s * 1.3, s, s * 1.1), cf, rng:NextNumber() < 0.5 and ROCK or ROCK_DARK, Enum.Material.Rock)
	end
end

-- one waterfall described by its top centre, width, drop, and orientation
local function fall(top, width, height, right, normal, big, seed)
	local foot = top - Vector3.new(0, height, 0)
	local face = CFrame.fromMatrix(top, right, Vector3.yAxis, -normal)
	-- falling sheet: streaks emitted along the lip, travelling down the face
	local lip = part("FallLip", Vector3.new(width, 0.4, 0.4), face * CFrame.new(0, -0.2, -0.3), WATER, Enum.Material.SmoothPlastic, 1)
	local speed = big and 42 or 22
	emitter(lip, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(WATER, FOAM),
		LightEmission = 0.15,
		LightInfluence = 0.9,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, big and 1.6 or 0.8), NumberSequenceKeypoint.new(1, big and 3 or 1.4) }),
		Squash = NumberSequence.new(-1.6),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.2, 0.5), NumberSequenceKeypoint.new(0.85, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(height / speed * 0.95, height / speed * 1.05),
		Speed = NumberRange.new(speed * 0.9, speed * 1.1),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(2, 2),
		Shape = Enum.ParticleEmitterShape.Box,
	}, math.floor(width * (big and 4 or 6)))
	-- foam boiling where it lands
	local landing = foot + normal * (big and 3 or 1.5) + Vector3.new(0, big and 1 or 0.6, 0)
	local base = part("FallFoam", Vector3.new(width + 2, 1, big and 6 or 3), CFrame.fromMatrix(landing, right, Vector3.yAxis, -normal), FOAM, Enum.Material.SmoothPlastic, 1)
	emitter(base, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(FOAM),
		LightInfluence = 0.8,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, big and 3 or 1.5), NumberSequenceKeypoint.new(1, big and 9 or 4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 2.2),
		Speed = NumberRange.new(big and 4 or 2, big and 8 or 4),
		SpreadAngle = Vector2.new(50, 50),
		Acceleration = Vector3.new(0, big and 2 or 1, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
		Shape = Enum.ParticleEmitterShape.Box,
	}, big and 28 or 10)
	-- boulders: breaking the lip, and around the landing
	boulders(top + normal * 0.4, right, normal, width + 2, big and 5 or 2, big and 3.2 or 0.9, seed)
	if big then -- small cascades already land in a carved basin; rocks there would hide the water
		boulders(foot + normal * 5, right, normal, width + 10, 7, 3.6, seed + 7)
	end
	return foot, landing
end

-- the great two-tier fall behind the gatehouse gets a real plunge pool
local function plungePool(foot, right, normal, width)
	local center = foot + normal * 9
	local cf = CFrame.fromMatrix(Vector3.new(center.X, -1.5, center.Z), right, Vector3.yAxis, -normal)
	pcall(function()
		workspace.Terrain:FillBlock(cf, Vector3.new(width + 12, 3, 16), Enum.Material.Water)
	end)
	-- rock rim around the open sides of the pool
	local rng = Random.new(91)
	for i = 0, 13 do
		local a = i / 13 * math.pi
		local p = center + right * math.cos(a) * (width / 2 + 7) + normal * math.sin(a) * 8.5
		local s = 2.4 + rng:NextNumber() * 1.4
		part("PoolRim", Vector3.new(s * 1.4, s * 0.8, s), CFrame.new(p.X, 0.2, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)), rng:NextNumber() < 0.5 and ROCK or ROCK_DARK, Enum.Material.Rock)
	end
end

function F.Build(parentFolder)
	local old = (parentFolder or workspace):FindFirstChild("Waterfalls")
	if old then old:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "Waterfalls"
	folder.Parent = parentFolder or workspace
	local start = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Start")
	if not start then return folder end

	-- 1) great fall: tall, flat, blue panels in the outer scenery
	local seed = 10
	for _, p in ipairs(start:GetDescendants()) do
		if p:IsA("BasePart") and p.Size.Y > 30 and p.Transparency < 0.5 then
			local h, s = p.Color:ToHSV()
			if h > 0.5 and h < 0.6 and s > 0.4 and math.min(p.Size.X, p.Size.Z) < 2 then
				local cf = p.CFrame
				local wide = p.Size.X >= p.Size.Z
				local right = wide and cf.RightVector or cf.LookVector
				local width = wide and p.Size.X or p.Size.Z
				local normal = wide and cf.LookVector or cf.RightVector
				if normal:Dot(Vector3.new(0, 0, -150) - cf.Position) < 0 then normal = -normal end -- face the courtyard
				p.Material = Enum.Material.Glass
				p.Color = Color3.fromRGB(150, 196, 214) -- glacier-fed water, not toy blue
				p.Transparency = 0.25
				local top = cf.Position + Vector3.new(0, p.Size.Y / 2, 0) + normal * 0.3
				local foot = fall(top, width, p.Size.Y, right, normal, true, seed)
				seed += 13
				if foot.Y < 4 then
					plungePool(foot, right, normal, width)
				end
			end
		end
	end

	-- 2) small cascades: groups of WaterRibbon strips in the side walls
	local groups = {}
	for _, p in ipairs(start:GetDescendants()) do
		if p:IsA("BasePart") and p.Name == "WaterRibbon" then
			local key = math.floor(p.Position.X / 8) .. "," .. math.floor((p.Position.Z + 2) / 8)
			local g = groups[key] or { parts = {} }
			table.insert(g.parts, p)
			groups[key] = g
		end
	end
	for _, g in pairs(groups) do
		local minZ, maxZ, x, topY, botY = math.huge, -math.huge, 0, -math.huge, math.huge
		for _, p in ipairs(g.parts) do
			minZ = math.min(minZ, p.Position.Z - 0.5)
			maxZ = math.max(maxZ, p.Position.Z + 0.5)
			x = p.Position.X
			topY = math.max(topY, p.Position.Y + p.Size.Y / 2)
			botY = math.min(botY, p.Position.Y - p.Size.Y / 2)
		end
		local normal = Vector3.new(x > 0 and -1 or 1, 0, 0) -- toward the courtyard
		local right = Vector3.new(0, 0, 1)
		local top = Vector3.new(x, topY, (minZ + maxZ) / 2) + normal * 0.25
		fall(top, math.max(3, maxZ - minZ), topY - botY, right, normal, false, seed)
		seed += 13
	end
	return folder
end

return F
