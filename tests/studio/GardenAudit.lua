-- Studio construction review. Pass an isolated BaseBuilder copy. This builds
-- temporary fixtures, never reads profiles, then restores fresh empty plots.
return function(BB)
	local Config = require(game.ReplicatedStorage.Shared.Config)
	local passed, failures = 0, {}
	local function check(ok, message)
		if ok then
			passed += 1
		else
			table.insert(failures, message)
		end
	end
	local function boundsInBase(part, cf)
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local p = cf:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) / 2))
					lo = Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
					hi = Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
				end
			end
		end
		return lo, hi
	end
	local function lifting(model)
		for _, p in model:GetDescendants() do
			local name = string.lower(p.Name)
			for _, word in { "workoutseat", "gympad", "barbell", "dumbbell", "kettlebell", "liftprop", "gravitycore" } do
				if string.find(name, word, 1, true) then
					return true
				end
			end
		end
		return false
	end
	BB.BuildAll()
	check(#BB.Bases == 8 and #workspace.Bases:GetChildren() == 8, "eight generated plots")
	local detailParts, totalParts = 0, 0
	local defaultGround = Color3.fromRGB(108, 161, 76)
	for i, b in BB.Bases do
		local expected = Vector3.new((i <= 4 and -1 or 1) * 63, 0.5, -84 - ((i - 1) % 4) * 76)
		check((b.floor.Position - expected).Magnitude < 0.01, "plot " .. i .. " center")
		check(b.floor.CanCollide and b.floor.CanQuery and b.model.PrimaryPart == b.floor, "plot floor contract")
		check(
			b.floor.Material == Enum.Material.Grass and b.floor.Color == defaultGround,
			"approved green default ground"
		)
		check(
			(b.cf:PointToObjectSpace(b.collect.Position) - Vector3.new(-19, 1.53, -21)).Magnitude < 0.01,
			"collection location"
		)
		check((b.cf:PointToObjectSpace(b.spawnCF.Position) - Vector3.new(0, 4, -28)).Magnitude < 0.01, "spawn location")
		check(b.model:FindFirstChild("Center") ~= nil, "renderer center reference")
		check(#b.slots == 24 and #b.slotFolder:GetChildren() == 48, "all slot references")
		for n, frame in b.slots do
			local a = (n - 1) / 24 * math.pi * 2 + math.pi / 2
			check(
				(b.cf:PointToObjectSpace(frame.Position) - Vector3.new(math.cos(a) * 14, 1.1, math.sin(a) * 14)).Magnitude
					< 0.01,
				"slot anchor " .. i .. "/" .. n
			)
			local pad, ring = b.slotFolder:FindFirstChild("Slot" .. n), b.slotFolder:FindFirstChild("SlotRing" .. n)
			check(pad and pad:GetAttribute("Index") == n, "slot identity " .. i .. "/" .. n)
			check(
				pad
					and ring
					and pad.Shape == Enum.PartType.Cylinder
					and ring.Shape == Enum.PartType.Cylinder
					and math.abs(pad.CFrame.RightVector.Y) > 0.99
					and math.abs(ring.CFrame.RightVector.Y) > 0.99,
				"vertical cylinder slot contract " .. i .. "/" .. n
			)
		end
		local anchor = b.model:FindFirstChild("ExpeditionAnchor")
		check(
			anchor
				and b.expeditionAnchor == anchor
				and (b.cf:PointToObjectSpace(anchor.Position) - Vector3.new(19, 2, -19)).Magnitude < 0.01,
			"expedition interaction anchor"
		)
		check(
			anchor and not anchor.CanCollide and not anchor.CanQuery and not anchor.CanTouch,
			"interaction anchor does not obstruct the table"
		)
		local tableModel = b.model:FindFirstChild("ExpeditionTable")
		local top = tableModel and tableModel:FindFirstChild("MapTableTop")
		check(
			top and top.CanCollide and top.Anchored and top.Size.X >= 8 and top.Size.Z >= 5,
			"solid expedition map table"
		)
		check(b.gymLabel.Text == "Expeditions", "activity label")
		check(not lifting(b.model), "default plot has no retired lifting equipment")
		local detail = b.model:FindFirstChild("SkyforgeDetails")
		check(detail ~= nil, "permanent Skyforge details")
		local safe, bounded, ornamental, entranceClear = true, true, false, true
		local parts, tiles, detailCount = 0, 0, 0
		for _, p in b.model:GetDescendants() do
			local name = string.lower(p.Name)
			for _, word in { "cottage", "pond", "flower", "hedge", "lavender", "lily", "porch", "shutter" } do
				ornamental = ornamental or string.find(name, word, 1, true) ~= nil
			end
			if p:IsA("BasePart") then
				parts += 1
				if p.Name == "VioletRoofTile" then
					tiles += 1
				end
				if p.CanCollide then
					local lo, hi = boundsInBase(p, b.cf)
					if lo.X < 2 and hi.X > -2 and lo.Z < -20 and hi.Z > -38 and lo.Y < 6 and hi.Y > 2 then
						entranceClear = false
					end
				end
			end
		end
		for _, p in detail and detail:GetDescendants() or {} do
			if p:IsA("BasePart") then
				detailCount += 1
				safe = safe and p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch
				local lo, hi = boundsInBase(p, b.cf)
				bounded = bounded and lo.X > -35.5 and hi.X < 35.5 and lo.Z > -35.5 and hi.Z < 35.5
			end
		end
		detailParts += detailCount
		totalParts += parts
		check(safe, "small details cannot block walking, targeting or touch")
		check(bounded, "small details stay within their plot")
		check(detail and detailCount == detail:GetAttribute("PartCount"), "detail accounting")
		check(tiles >= 40, "layered violet roof retains individual tiles")
		check(parts <= 700, "per-plot geometry budget")
		check(entranceClear, "roofless avenue entrance stays open")
		check(not ornamental, "rejected garden ornaments are absent from default plot")
		check(
			b.model:GetAttribute("SanctuaryVersion") == 5 and b.model:GetAttribute("BaseStyle") == "SkyforgeCourtyard",
			"approved base style"
		)
		task.wait()
	end
	local b = BB.Bases[1]
	local data = {
		Decor = {},
		FloorTheme = "Meadow",
		EquipLevel = 5,
		Upgrades = { Training = 0, BaseSlots = 0 },
		ExpeditionRelics = {},
	}
	local details = b.model:FindFirstChild("SkyforgeDetails")
	for _, theme in Config.FloorThemes do
		data.FloorTheme = theme.id
		BB.Refresh(b, data)
		check(
			b.floor.Material == theme.material
				and b.floor.Color == (theme.id == "Meadow" and defaultGround or theme.color),
			"owned floor theme " .. theme.id
		)
		check(b.model:FindFirstChild("SkyforgeDetails") == details, "floor refresh retains permanent details")
	end
	check(not lifting(b.model), "legacy equipment ownership cannot rebuild retired weights")
	data.ExpeditionRelics.Forest = true
	BB.Refresh(b, data)
	local relics = b.model:FindFirstChild("ExpeditionRelics")
	check(
		relics
			and relics:FindFirstChild("BiomeRelic_Forest") ~= nil
			and relics:FindFirstChild("BiomeRelic_Frozen") == nil,
		"earned relic renders on the expedition table"
	)
	check(
		relics and relics:FindFirstChild("RelicSocket_Forest"):GetAttribute("Found") == true,
		"earned relic socket status"
	)
	local relicCount = relics and #relics:GetChildren() or 0
	BB.Refresh(b, data)
	check(#b.model.ExpeditionRelics:GetChildren() == relicCount, "repeated refresh does not duplicate relics")
	for _, id in Config.DecorOrder do
		data.Decor[id] = true
	end
	data.Upgrades.BaseSlots, data.Upgrades.Training = 20, 3
	BB.Refresh(b, data)
	for _, id in Config.DecorOrder do
		check(b.decor:FindFirstChild(id) ~= nil, "owned decor " .. id)
	end
	for n = 1, 24 do
		check(
			b.slotFolder["SlotRing" .. n].Transparency < 0.5 and b.slotFolder["Slot" .. n].Transparency < 0.5,
			"unlocked slot " .. n
		)
	end
	check(
		b.model:FindFirstChild("SkyforgeDetails") == details
			and b.model.ExpeditionRelics:FindFirstChild("BiomeRelic_Forest") ~= nil,
		"purchases preserve permanent details and earned relics"
	)
	local owner = { DisplayName = "Skyforge Review", UserId = 123456 }
	local claimed = BB.Claim(owner)
	check(claimed == b and b.model:GetAttribute("OwnerId") == owner.UserId, "claim contract")
	check(b.signLabels[1].Text == "Skyforge Review's Courtyard", "claimed courtyard label")
	BB.Release(b)
	check(b.owner == nil and b.model:GetAttribute("OwnerId") == nil, "release ownership")
	check(
		b.floor.Material == Enum.Material.Grass and b.floor.Color == defaultGround and #b.decor:GetChildren() == 0,
		"released courtyard resets floor and purchases"
	)
	check(
		b.model.ExpeditionRelics:FindFirstChild("BiomeRelic_Forest") == nil,
		"released courtyard clears the previous owner's relic display"
	)
	check(
		b.slotFolder.SlotRing5.Transparency > 0.8 and b.slotFolder.SlotRing1.Transparency < 0.5,
		"released courtyard resets slot markers"
	)
	check(b.signLabels[1].Text == "Available courtyard" and b.collectLabel.Text == "$0", "released courtyard labels")
	BB.BuildAll()
	return {
		passed = passed,
		failures = failures,
		plots = #BB.Bases,
		detailParts = detailParts,
		totalParts = totalParts,
	}
end
