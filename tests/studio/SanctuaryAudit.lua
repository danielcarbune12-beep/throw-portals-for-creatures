-- Run against the actual built lobby in Edit or Play. Returns evidence, never changes player data.
return function()
	local RS = game:GetService("ReplicatedStorage")
	local Config = require(RS.Shared.Config)
	local Portal = require(RS.Shared.PortalBuilder)
	local passed, failures = 0, {}
	local function check(value, message)
		if value then
			passed += 1
		else
			table.insert(failures, message)
		end
	end
	local map, bases = workspace:FindFirstChild("Map"), workspace:FindFirstChild("Bases")
	check(map and map:FindFirstChild("Start"), "lobby exists")
	check(bases and #bases:GetChildren() == 8, "exactly eight gardens")
	if not map or not bases then
		return { passed = passed, failures = failures }
	end
	local start = map.Start
	check(start:GetAttribute("SanctuaryVersion") == 2, "reference sanctuary version")
	local barrier = start:FindFirstChild("Barrier")
	check(
		barrier and barrier.CanCollide and math.abs(barrier.Position.Z - Config.BarrierZ) < 0.01,
		"barrier collision plane unchanged"
	)
	local floor = start:FindFirstChild("HallFloor")
	check(
		floor and floor.CanCollide and math.abs(floor.Size.X - Config.HallHalfWidth * 2) < 0.01,
		"hall floor contract"
	)
	check(start:FindFirstChild("SanctuaryAperture") ~= nil, "architectural portal centerpiece")
	for i = 1, 8 do
		local base = bases:FindFirstChild("Base" .. i)
		check(base ~= nil, "garden " .. i)
		if base then
			local expected = Vector3.new((i <= 4 and -1 or 1) * 63, 0.5, -84 - ((i - 1) % 4) * 76)
			check((base.Floor.Position - expected).Magnitude < 0.01, "garden " .. i .. " center preserved")
			check(
				base:FindFirstChild("CollectPad") and base:FindFirstChild("GymPad") and base:FindFirstChild("Center"),
				"garden " .. i .. " gameplay references"
			)
			for n = 1, 24 do
				check(
					base.Slots:FindFirstChild("Slot" .. n) and base.Slots:FindFirstChild("SlotRing" .. n),
					"garden " .. i .. " slot " .. n
				)
			end
			check(base:FindFirstChild("GardenCrystalFountain") ~= nil, "garden " .. i .. " tiered fountain")
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { start }
	rp.RespectCanCollide = true
	for _, x in ipairs({ -5, 0, 5 }) do
		check(
			workspace:Raycast(Vector3.new(x, 4, -65), Vector3.new(0, 0, 69), rp) == nil,
			"clear avatar passage x=" .. x
		)
	end
	local portalParts = {}
	for _, id in ipairs(Config.PortalOrder) do
		local model, refs = Portal.BuildGate(id, 5)
		local frame = refs.frame.w.C0
		model:ScaleTo(0.05)
		Portal.Spin(refs, 0.1)
		check(
			math.abs(refs.discs[1].w.C0.Position.Z - refs.discs[1].base.Position.Z * 0.05) < 0.001,
			id .. " aperture depth scales with opening"
		)
		model:ScaleTo(1)
		Portal.Spin(refs, 2)
		check((refs.frame.w.C0.Position - frame.Position).Magnitude < 0.001, id .. " frame stays planted")
		local count = 0
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				count += 1
			end
		end
		portalParts[id] = count
		model:Destroy()
	end
	local counts = { parts = 0, lights = 0, emitters = 0 }
	for _, holder in ipairs({ start, bases }) do
		for _, p in ipairs(holder:GetDescendants()) do
			if p:IsA("BasePart") then
				counts.parts += 1
			elseif p:IsA("Light") then
				counts.lights += 1
			elseif p:IsA("ParticleEmitter") then
				counts.emitters += 1
			end
		end
	end
	return { passed = passed, failures = failures, lobby = counts, portalParts = portalParts }
end
